#!/usr/bin/env python3 -I
"""Extract WoW Forever talents and the Legacy system from a local, read-only install.

usage: python3 -I extract_forever.py <scripts_dir> <install> <dbd_dir> <listfile.csv> <out_dir> [locale] [class ...]

Writes forever_<build>_all_<locale>.json. Reads only, and never starts or evaluates
anything from the client: the Blizzard UI files are read as text for their constants.
Encrypted DB2 sections are skipped and counted. Server hotfixes aren't in the client
files, so they aren't in the extract.

Descriptions reuse tool/classic's renderer, with Forever's value fields on top. What
can't be calculated stays visible as [[?token]] and is listed under "unresolved".
"""
import collections
import json
import os
import re
import struct
import sys
import time
import zlib

sys.path.insert(0, os.path.join(os.path.abspath(sys.argv[1]), "..", "classic"))
import extract_classic as classic  # noqa: E402  (it also puts casc and wdc on the path)
import casc  # noqa: E402
import wdc  # noqa: E402

PRODUCT = "wowf"

TABLES = (
    "SkillLineXTraitTree", "TraitTree", "TraitNode", "TraitNodeEntry", "TraitNodeXTraitNodeEntry",
    "TraitDefinition", "TraitDefinitionEffectPoints", "TraitEdge", "TraitCond", "TraitNodeXTraitCond",
    "TraitNodeEntryXTraitCond", "TraitNodeGroup", "TraitNodeGroupXTraitNode", "TraitNodeGroupXTraitCond",
    "TraitNodeGroupDisplayInfo", "TraitCurrency", "TraitCurrencySource", "TraitCost", "TraitTreeXTraitCost",
    "TraitTreeXTraitCurrency", "TraitNodeXTraitCost", "TraitNodeGroupXTraitCost", "TraitNodeEntryXTraitCost",
    "Curve", "CurvePoint", "TalentTab", "Spell", "SpellName", "SpellMisc", "SpellEffect", "SpellAuraOptions",
    "SpellDuration", "SpellRadius", "SpellCooldowns", "SpellLevels", "SpellTargetRestrictions",
    "SpellXDescriptionVariables", "SpellDescriptionVariables", "SpellClassOptions", "SkillLine",
    "SkillLineAbility", "ManifestInterfaceData", "ChrClasses", "GlobalStrings", "SharedString", "Achievement",
    "Achievement_Category", "UiTextureAtlas", "UiTextureAtlasMember",
)

LEGACY_CONSTANTS = "interface/addons/blizzard_apidocumentationgenerated/legacyconstantsdocumentation.lua"
LEGACY_TREE_DATA = "interface/addons/blizzard_legacysystem/blizzard_legacysystemconstants.lua"
LEGACY_STRINGS = (
    "LEGACY_TREE_TAB_TOOLTIP", "LEGACY_TREE_FRAME_TITLE", "LEGACY_REWARD_TRACK_POINTS",
    "LEGACY_POINTS_SEASONAL_CAP", "LEGACY_MICRO_BUTTON_LOCKED_TOOLTIP", "LEGACY_CHALLENGE_FRAME_TITLE",
    "ERR_LEGACY_WIPE_ERROR_CLASS_POINTS",
)

# TraitConstantsDocumentation.lua in the client.
NODE_TYPES = {0: "single", 1: "tiered", 2: "selection", 3: "subtree_selection"}
EDGE_TYPES = {0: "visual_only", 1: "deprecated_rank", 2: "sufficient", 3: "required", 4: "mutually_exclusive", 5: "deprecated_selection"}
COND_TYPES = {0: "available", 1: "visible", 2: "granted", 3: "increased", 4: "display_error", 5: "ranks_allowed"}
FLAG_NEVER_PURCHASABLE = 2
BLOCKING_EDGES = (2, 3)

# Regular talents: three tab origins with 600 unit cells, 4 columns and 7 rows, in all nine class trees.
TAB_X0 = (1020, 5020, 9080)
GRID_Y0 = 2130
CLASS_NAMES = {1: "warrior", 2: "paladin", 4: "hunter", 8: "rogue", 16: "priest", 64: "shaman", 128: "mage", 256: "warlock", 1024: "druid"}
LEGACY_CELL = 900

# A failed read may mean the launcher is writing to the shared install, so it gets a fresh look.
RETRY_ERRORS = classic.RETRY_ERRORS
ATTEMPTS = 4


def by(table, key):
    out = collections.defaultdict(list)
    for row in table.rows.values():
        out[row[key]].append(row)
    return out


def read_listfile(path):
    tables, files = {}, {}
    with open(path, encoding="utf-8", errors="replace") as lines:
        for line in lines:
            fdid, _, name = line.rstrip().partition(";")
            if name.startswith("dbfilesclient/") and name.endswith(".db2"):
                tables[name.split("/")[-1][:-4]] = int(fdid)
            elif name in (LEGACY_CONSTANTS, LEGACY_TREE_DATA) or name.startswith("interface/icons/"):
                files[int(fdid) if name.startswith("interface/icons/") else name] = (
                    name[len("interface/icons/"):-4] if name.startswith("interface/icons/") else int(fdid)
                )
    return tables, files


class Client:
    def __init__(self, install, dbd_dir, listfile, locale):
        self.locale = locale
        self.casc = casc.Casc(install, PRODUCT)
        self.build = self.casc.info["Version"]
        self.dbd_dir = dbd_dir
        self.fdids, self.files = read_listfile(listfile)
        self.tables_info = {}
        for name in TABLES:
            setattr(self, name, self.load(name))

    def load(self, name):
        table = wdc.load(self.casc, self.dbd_dir, self.fdids[name.lower()], name, self.locale, self.build)
        layout = "%08X" % table.layout_hash
        if layout not in table.dd["layouts"]:
            raise SystemExit(f"{name}: WoWDBDefs has no definition for layout {layout}")
        if len(table.inline) != table.field_count:
            raise SystemExit(f"{name}: {table.field_count} fields, definition has {len(table.inline)}")
        self.tables_info[name] = dict(
            magic=table.magic.decode(),
            layout=layout,
            definition_lists_build=classic.build_listed(self.build, table.dd["builds"]),
            records=table.record_count,
            rows=len(table.rows),
            encrypted_sections=table.encrypted_sections,
            encrypted_records=table.encrypted_records,
            encrypted_blte_chunks=table.enc_chunks,
        )
        return table

    def text_file(self, name):
        return self.casc.read_fdid(self.files[name], self.locale).decode("utf-8", "replace")


class Renderer(classic.Renderer):
    """Classic's template renderer, on Forever's float values and per-rank curves. Spell
    conditions count as false, since a calculator's character has nothing but its talents,
    and a value that grows per level is taken at the top level."""

    def __init__(self, client, locale, top_level):
        super().__init__(client, PRODUCT, locale)
        self.conditions_false = True
        self.top_level = top_level
        self.levels = self._first_by_spell(client.SpellLevels)
        self.curves = by(client.CurvePoint, "CurveID")
        self.effect_points = by(client.TraitDefinitionEffectPoints, "TraitDefinitionID")
        self.definition, self.rank, self.top_spell = None, None, None

    def render_trait(self, template, definition, rank, spell):
        self.definition, self.rank, self.top_spell = definition, rank, spell
        notes = dict(uncalculated=[], assumed_false_conditions=[], level_scaled=[], effect_fallback=[], token_kinds=set())
        text = self._render(template, spell, notes)
        del notes["token_kinds"]
        return clean(text, self.words), notes

    def _curve(self, curve, x):
        points = sorted((p["Pos"][0], p["Pos"][1]) for p in self.curves.get(curve, []))
        if not points:
            return None
        if x <= points[0][0]:
            return points[0][1]
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            if x <= x1:
                return y0 + (y1 - y0) * (x - x0) / (x1 - x0) if x1 != x0 else y1
        return points[-1][1]

    def _effect_index(self, spell, index, notes):
        """Some templates say $s2 or $a2 for a spell left with one effect. That effect is meant."""
        effects = self.effects.get(spell, {})
        if index in effects or len(effects) != 1:
            return index
        notes["effect_fallback"].append(f"effect {index + 1} of {spell}")
        return next(iter(effects))

    def _points(self, spell, index, notes):
        """(lowest, highest) of an effect, signed. A talent's own spell takes its rank's value from the curve."""
        index = self._effect_index(spell, index, notes)
        effect = self.effects.get(spell, {}).get(index)
        if not effect:
            return None
        base = effect["EffectBasePointsF"]
        if spell == self.top_spell:
            for row in self.effect_points.get(self.definition, []):
                if row["EffectIndex"] != index:
                    continue
                value = self._curve(row["CurveID"], self.rank)
                if value is not None and row["OperationType"] == 0:
                    base = value
                elif value is not None and row["OperationType"] == 1:
                    base *= value
        middle = base
        per_level = effect["EffectRealPointsPerLevel"]
        if per_level:
            levels = self.levels.get(spell)
            first = levels["BaseLevel"] if levels else 0
            last = levels["MaxLevel"] if levels and levels["MaxLevel"] else self.top_level
            middle = base + per_level * (max(first, last) - first)
            capped = "" if levels and levels["MaxLevel"] else ", no top level of its own"
            notes["level_scaled"].append(f"effect {index + 1} of {spell}: {round(per_level, 2)} per level{capped}")
        if effect["Variance"]:
            half = abs(base) * effect["Variance"] / 2
            return round(middle - half), round(middle + half)
        return (round(middle), round(middle)) if per_level else (middle, middle)

    def _value(self, kind, spell, number, notes):
        if kind.lower() in "atxeb":
            number = self._effect_index(spell, (number or 1) - 1, notes) + 1
        if kind.lower() == "a":
            # The radius may sit in the effect's second slot.
            effect = self.effects.get(spell, {}).get(number - 1)
            radius = next((i for i in effect["EffectRadiusIndex"] if i), 0) if effect else 0
            return self.radii[radius]["Radius"] if radius in self.radii else None
        return super()._value(kind, spell, number, notes)

    def _only_level_scaling(self, kind, spell, number):
        return False

    def _proc_cooldown(self, spell):
        aura = self.auras.get(spell)
        return aura["ProcCategoryRecovery"] / 1000 if aura and aura["ProcCategoryRecovery"] else None

    def _expression(self, source, spell, notes):
        if "$pl" in source:
            source = re.sub(r"\$pl\b", str(self.top_level), source)
            notes["level_scaled"].append(f"$pl of {spell}: taken at level {self.top_level}")
        if "$proccooldown" in source:
            value = self._proc_cooldown(spell)
            if value is None:
                return None
            source = source.replace("$proccooldown", repr(value))
        return super()._expression(source, spell, notes)

    def _render(self, text, spell, notes):
        """Handles what Classic's templates don't have. Finished text goes in after the
        render through a placeholder, so that its markers aren't read as tokens."""
        pieces = []

        def hold(piece):
            pieces.append(piece)
            return f"\ue000{len(pieces) - 1}\ue001"

        def include(match):
            kind, sid = match.group(1), int(match.group(2))
            name = self.names.get(sid, {}).get("Name_lang")
            if kind == "spellname":
                return hold(name) if name else match.group(0)
            field = "AuraDescription_lang" if kind == "spellaura" else "Description_lang"
            source = self.spells.get(sid, {}).get(field)
            if not source:
                return match.group(0)
            piece = self._render(source, sid, notes)
            return hold(f"{name}: {piece}" if kind == "spelltooltip" and name else piece)

        def gender(match):
            notes["assumed_false_conditions"].append("gender: " + match.group(0))
            return match.group(1)

        def proc_cooldown(match):
            value = self._proc_cooldown(spell)
            return match.group(0) if value is None else hold(self._number(value))

        text = re.sub(r"\$@(spellname|spelldesc|spellaura|spelltooltip)(\d+)", include, text or "")
        text = re.sub(r"\$[gG]([^:;]*):([^;]*);", gender, text)
        # Some templates leave off the semicolon that ends a plural.
        text = re.sub(r"(\$[lL][^\W\d_]+:[^\W\d_]+)(?!;)(?=\W)", r"\1;", text)
        text = re.sub(r"\$proccooldown(?![^{]*\})", proc_cooldown, text)
        out = super()._render(text, spell, notes)
        return re.sub("\ue000(\\d+)\ue001", lambda m: pieces[int(m.group(1))], out)

    def _conditions_are_false(self, conditions):
        return not any("!" in c or re.search(r"\bc\d", c) for c in conditions)


def clean(text, words):
    """UI markup goes, since the app has plain text. A doubled period goes too: a word
    ending in one can meet the template's own, and a few templates have two."""
    text = re.sub(r"\|[cC][0-9a-fA-F]{8}|\|[rR]", "", text)
    text = text.replace("\r\n", "\n").replace("|n", "\n")
    for word in (words["sec"], words["min"], words["hrs"]):
        if word.endswith("."):
            text = text.replace(word + ".", word)
    return re.sub(r"(?<!\.)\.\.(?!\.)", ".", text).strip()


class Extract:
    def __init__(self, client, locale, only):
        self.c = client
        self.locale = locale
        self.only = only
        top_level = max(r["PlayerLevel"] for r in client.TraitCurrencySource.rows.values())
        self.renderer = Renderer(client, locale, top_level)
        self.anomalies = []
        self.unresolved = []
        self.counts = collections.Counter()
        c = client
        self.entries_of = collections.defaultdict(list)
        for row in sorted(c.TraitNodeXTraitNodeEntry.rows.values(), key=lambda r: r["Index"]):
            entry = c.TraitNodeEntry.rows.get(row["TraitNodeEntryID"])
            if entry:
                self.entries_of[row["TraitNodeID"]].append(entry)
        self.groups_of = collections.defaultdict(list)
        self.group_nodes = collections.defaultdict(set)
        for row in c.TraitNodeGroupXTraitNode.rows.values():
            self.groups_of[row["TraitNodeID"]].append(row["TraitNodeGroupID"])
            self.group_nodes[row["TraitNodeGroupID"]].add(row["TraitNodeID"])
        self.group_conds = by(c.TraitNodeGroupXTraitCond, "TraitNodeGroupID")
        self.node_conds = by(c.TraitNodeXTraitCond, "TraitNodeID")
        self.entry_conds = by(c.TraitNodeEntryXTraitCond, "TraitNodeEntryID")
        self.edges_in = by(c.TraitEdge, "RightTraitNodeID")
        self.spell_abilities = by(c.SkillLineAbility, "Spell")
        self.class_options = by(c.SpellClassOptions, "SpellID")
        self.strings = {r["BaseTag"]: r["TagText_lang"] for r in c.GlobalStrings.rows.values()}

    # ---- pieces

    def icon_name(self, fdid):
        row = self.c.ManifestInterfaceData.rows.get(fdid)
        name = re.sub(r"\.blp$", "", row["FileName"], flags=re.I) if row else self.c.files.get(fdid)
        return name.lower().rstrip(".") if name else None

    def definition(self, entry):
        c = self.c
        definition = c.TraitDefinition.rows[entry["TraitDefinitionID"]]
        spell = definition["SpellID"]
        misc = self.renderer.misc.get(spell)
        icon = definition["OverrideIcon"] or (misc["SpellIconFileDataID"] if misc else 0)
        return dict(
            definition=definition,
            spell=spell,
            name=definition["OverrideName_lang"] or c.SpellName.rows.get(spell, {}).get("Name_lang", ""),
            icon=icon,
            template=definition["OverrideDescription_lang"] or c.Spell.rows.get(spell, {}).get("Description_lang", ""),
        )

    def ranks(self, entries, where):
        """Per-rank text. A tiered node's entries are its ranks in order, each with its own values."""
        out = []
        for entry in entries:
            info = self.definition(entry)
            for rank in range(1, entry["MaxRanks"] + 1):
                text, notes = self.renderer.render_trait(info["template"], info["definition"]["ID"], rank, info["spell"])
                out.append(dict(
                    rank=len(out) + 1,
                    entry_id=entry["ID"],
                    definition_id=info["definition"]["ID"],
                    spell_id=info["spell"],
                    description=text,
                    uncalculated=notes["uncalculated"],
                    assumed_false_conditions=notes["assumed_false_conditions"],
                    level_scaled=sorted(set(notes["level_scaled"])),
                    effect_fallback=sorted(set(notes["effect_fallback"])),
                ))
                self.counts["ranks"] += 1
                self.counts["ranks_with_uncalculated"] += bool(notes["uncalculated"])
                self.counts["uncalculated_tokens"] += len(notes["uncalculated"])
                self.counts["ranks_with_assumed_false"] += bool(notes["assumed_false_conditions"])
                self.counts["ranks_level_scaled"] += bool(notes["level_scaled"])
                if info["spell"] not in self.c.Spell.rows:
                    self.anomalies.append(f"{where}: rank {len(out)} spell {info['spell']} has no Spell row")
        tokens = sorted({token for rank in out for token in rank["uncalculated"]})
        for token in tokens:
            self.unresolved.append(dict(where=where, token=token, template=self.definition(entries[0])["template"]))
        return out, tokens

    def condition(self, cond_id, source):
        row = self.c.TraitCond.rows.get(cond_id)
        if not row:
            self.anomalies.append(f"{source}: no TraitCond {cond_id}")
            return None
        out = dict(cond_id=cond_id, type=COND_TYPES.get(row["CondType"], row["CondType"]), source=source)
        for key, name in (
            ("TraitCurrencyID", "currency_id"), ("SpentAmountRequired", "spent_required"),
            ("TraitNodeGroupID", "spent_in_group"), ("TraitNodeID", "node_id"), ("TraitNodeEntryID", "entry_id"),
            ("QuestID", "quest_id"), ("AchievementID", "achievement_id"), ("SpecSetID", "spec_set_id"),
            ("RequiredLevel", "required_level"), ("GrantedRanks", "granted_ranks"), ("Flags", "flags"),
            ("TraitCondAccountElementID", "account_element_id"),
        ):
            if row[key]:
                out[name] = row[key]
        return out

    def conditions(self, node, entries):
        out = []
        for group in self.groups_of[node["ID"]]:
            out += [self.condition(r["TraitCondID"], f"group:{group}") for r in self.group_conds.get(group, [])]
        out += [self.condition(r["TraitCondID"], "node") for r in self.node_conds.get(node["ID"], [])]
        for entry in entries:
            out += [self.condition(r["TraitCondID"], f"entry:{entry['ID']}") for r in self.entry_conds.get(entry["ID"], [])]
        return sorted((c for c in out if c), key=lambda c: c["cond_id"])

    def required_points(self, conditions):
        """The spending gate: an availability condition on the node's group, counting spending
        in another group. A condition naming a node asks about that node, not the tree."""
        return max((c.get("spent_required", 0) for c in conditions
                    if c["type"] == "available" and c.get("currency_id") and "node_id" not in c), default=0)

    def edges(self, node, required, describe):
        """Prerequisites, without edges that can't gate this node: visual ones, and those
        from a node behind a higher spending gate. That node needs this one first."""
        kept, ignored = [], []
        for edge in self.edges_in.get(node["ID"], []):
            left = edge["LeftTraitNodeID"]
            source = describe(left)
            blocking = edge["Type"] in BLOCKING_EDGES
            behind = source is not None and source["required_points"] > required
            item = dict(
                node=left,
                edge_type=edge["Type"],
                edge=EDGE_TYPES.get(edge["Type"], edge["Type"]),
                name=source["name"] if source else None,
                required_rank=source["max_ranks"] if source else None,
            )
            (kept if blocking and not behind else ignored).append(item)
        return kept, ignored

    def describe(self, node_id):
        node = self.c.TraitNode.rows.get(node_id)
        entries = self.entries_of.get(node_id)
        if not node or not entries:
            return None
        return dict(
            name=self.definition(entries[0])["name"],
            max_ranks=self.max_ranks(node, entries),
            required_points=self.required_points(self.conditions(node, entries)),
        )

    @staticmethod
    def max_ranks(node, entries):
        return sum(e["MaxRanks"] for e in entries) if node["Type"] == 1 else entries[0]["MaxRanks"]

    def class_marks(self, spell, conditions):
        marks = sorted({r["ClassMask"] for r in self.spell_abilities.get(spell, []) if r.get("ClassMask")})
        classes = sorted({r["SpellClassSet"] for r in self.class_options.get(spell, []) if r["SpellClassSet"]})
        specs = sorted({c["spec_set_id"] for c in conditions if "spec_set_id" in c})
        return dict(class_masks=marks, spell_class_sets=classes, spec_sets=specs)

    def costs(self, tree, node, entries):
        c = self.c
        links = [r["TraitCostID"] for r in c.TraitTreeXTraitCost.rows.values() if r["TraitTreeID"] == tree]
        links += [r["TraitCostID"] for r in c.TraitNodeXTraitCost.rows.values() if r["TraitNodeID"] == node["ID"]]
        links += [r["TraitCostID"] for r in c.TraitNodeGroupXTraitCost.rows.values()
                  if r["TraitNodeGroupID"] in self.groups_of[node["ID"]]]
        links += [r["TraitCostID"] for r in c.TraitNodeEntryXTraitCost.rows.values()
                  if r["TraitNodeEntryID"] in {e["ID"] for e in entries}]
        out = []
        for link in links:
            row = c.TraitCost.rows.get(link)
            if row:
                out.append(dict(cost_id=link, currency_id=row["TraitCurrencyID"], amount=row["Amount"]))
                if row["CurveID"]:
                    self.anomalies.append(f"node {node['ID']}: cost {link} varies by curve {row['CurveID']}")
        return out

    # ---- regular talents

    def regular(self):
        c = self.c
        classes = {}
        tabs = by(c.TalentTab, "ClassMask")
        tab_groups = collections.defaultdict(dict)
        for row in c.TraitNodeGroupDisplayInfo.rows.values():
            tab_groups[row["TraitTreeID"]][row["OrderIndex"]] = row
        for row in sorted(c.SkillLineXTraitTree.rows.values(), key=lambda r: r["TraitTreeID"]):
            tree_id = row["TraitTreeID"]
            nodes = [n for n in c.TraitNode.rows.values() if n["TraitTreeID"] == tree_id and self.entries_of.get(n["ID"])]
            votes = collections.Counter(
                a["ClassMask"]
                for n in nodes for e in self.entries_of[n["ID"]]
                for a in self.spell_abilities.get(self.definition(e)["spell"], []) if a.get("ClassMask")
            )
            mask = votes.most_common(1)[0][0]
            code = CLASS_NAMES.get(mask)
            if code is None:
                self.anomalies.append(f"tree {tree_id}: unknown class mask {mask}")
                continue
            if self.only and code not in self.only:
                continue
            classes[code] = self.regular_class(tree_id, row["SkillLineID"], mask, code, nodes, tabs[mask], tab_groups[tree_id])
        return classes

    def regular_class(self, tree_id, skill, mask, code, nodes, tabs, groups):
        c = self.c
        placed = {0: [], 1: [], 2: []}
        hidden = []
        for node in nodes:
            spot = None
            for position, x0 in enumerate(TAB_X0):
                column = (node["PosX"] - x0 + 300) // 600
                row = (node["PosY"] - GRID_Y0 + 300) // 600
                if 0 <= column <= 3 and 0 <= row <= 6 and not node["Flags"] & FLAG_NEVER_PURCHASABLE:
                    spot = position
                    break
            (placed[spot] if spot is not None else hidden).append(node)
        info = next((r for r in c.ChrClasses.rows.values() if r["Filename"].lower() == code), {})
        out = dict(
            class_mask=mask, name=code, display_name=info.get("Name_lang"), class_id=info.get("ID"),
            trait_tree_id=tree_id, skill_line_id=skill, trees=[],
        )
        for position in range(3):
            tab = next(t for t in tabs if t["OrderIndex"] == position)
            display = groups.get(position)
            if display:
                strays = {n["ID"] for n in placed[position]} - self.group_nodes[display["TraitNodeGroupID"]]
                if strays:
                    self.anomalies.append(f"{code}/{tab['Name_lang']}: placed nodes outside its display group: {sorted(strays)}")
            else:
                self.anomalies.append(f"{code}/{tab['Name_lang']}: no TraitNodeGroupDisplayInfo row")
            talents = [self.talent(n, TAB_X0[position], code, tab) for n in sorted(placed[position], key=lambda n: (n["PosY"], n["PosX"]))]
            counted = collections.Counter((t["row"], t["column"]) for t in talents)
            for cell, count in counted.items():
                if count > 1:
                    self.anomalies.append(f"{code}/{tab['Name_lang']}: {count} talents at {cell}")
            skill_line = c.SkillLine.rows.get(display["SkillLineID"], {}) if display else {}
            out["trees"].append(dict(
                position=position, talent_tab_id=tab["ID"], name=tab["Name_lang"],
                skill_line=skill_line.get("DisplayName_lang"), skill_line_id=display["SkillLineID"] if display else None,
                order_index=tab["OrderIndex"], background_file=tab["BackgroundFile"], icon_fdid=tab["SpellIconID"],
                icon=self.icon_name(tab["SpellIconID"]),
                points_available=sum(t["max_ranks"] for t in talents), talents=talents,
            ))
            self.counts["talents"] += len(talents)
        out["hidden_nodes"] = [dict(
            node_id=n["ID"], pos=[n["PosX"], n["PosY"]], flags=n["Flags"],
            names=[self.definition(e)["name"] for e in self.entries_of[n["ID"]]],
        ) for n in hidden]
        self.counts["hidden_nodes"] += len(hidden)
        return out

    def talent(self, node, x0, code, tab):
        entries = self.entries_of[node["ID"]]
        first = entries[0]
        info = self.definition(first)
        where = f"{code}/{tab['Name_lang']}/{info['name']}"
        if len(entries) > 1:
            self.anomalies.append(f"{where}: {len(entries)} entries on a regular node, type {node['Type']}")
        if node["Type"] != 0:
            self.anomalies.append(f"{where}: node type {node['Type']}")
        ranks, tokens = self.ranks(entries[:1], where)
        conditions = self.conditions(node, entries)
        required = self.required_points(conditions)
        prerequisites, ignored = self.edges(node, required, self.describe)
        if len(prerequisites) > 1:
            self.anomalies.append(f"{where}: {len(prerequisites)} prerequisites")
        return dict(
            node_id=node["ID"], entry_id=first["ID"], definition_id=info["definition"]["ID"], spell_id=info["spell"],
            visible_spell_id=info["definition"]["VisibleSpellID"], overrides_spell_id=info["definition"]["OverridesSpellID"],
            name=info["name"], icon=self.icon_name(info["icon"]), icon_fdid=info["icon"],
            row=(node["PosY"] - GRID_Y0 + 300) // 600, column=(node["PosX"] - x0 + 300) // 600,
            pos=[node["PosX"], node["PosY"]], node_type=node["Type"], node_flags=node["Flags"],
            entry_type=first["NodeEntryType"], entry_count=len(entries), max_ranks=first["MaxRanks"],
            required_points_in_tree=required, prerequisites=prerequisites, ignored_edges=ignored,
            extra_conditions=[c for c in conditions if "node_id" in c],
            description_template=info["template"], ranks=ranks, unresolved_tokens=tokens,
        )

    def talent_points(self):
        """The regular talent currency: its cap, and what grants it."""
        c = self.c
        links = {r["TraitCurrencyID"] for r in c.TraitTreeXTraitCurrency.rows.values()
                 if r["TraitTreeID"] in {x["TraitTreeID"] for x in c.SkillLineXTraitTree.rows.values()}}
        if len(links) != 1:
            self.anomalies.append(f"class trees use currencies {sorted(links)}")
        currency = min(links)
        sources = sorted((r for r in c.TraitCurrencySource.rows.values() if r["TraitCurrencyID"] == currency),
                         key=lambda r: r["PlayerLevel"])
        return dict(
            currency_id=currency,
            cap=c.TraitCurrency.rows[currency]["SourcedMax"],
            first_level_without_perk=min(r["PlayerLevel"] for r in sources if not r["TraitNodeEntryID"]),
            sources=[dict(level=r["PlayerLevel"], amount=r["Amount"], requires_entry_id=r["TraitNodeEntryID"]) for r in sources],
        )

    # ---- Legacy

    def legacy_constants(self):
        text = self.c.text_file(LEGACY_CONSTANTS)
        return dict(re.findall(r'Name = "(\w+)", Type = "number", Value = (-?\d+)', text))

    def atlas(self, name):
        """The tree icons are atlas parts. The atlas member carries a size suffix, such as -c60."""
        c = self.c
        member = next((r for r in c.UiTextureAtlasMember.rows.values()
                       if r["CommittedName"].lower().startswith(name.lower())), None)
        if not member:
            self.anomalies.append(f"no atlas member for {name}")
            return dict(icon_atlas=name)
        sheet = c.UiTextureAtlas.rows.get(member["UiTextureAtlasID"], {})
        return dict(
            icon_atlas=name,
            atlas_member=member["CommittedName"],
            atlas_file_fdid=sheet.get("FileDataID"),
            atlas_rect=dict(left=member["CommittedLeft"], right=member["CommittedRight"], top=member["CommittedTop"], bottom=member["CommittedBottom"]),
        )

    def legacy(self):
        c = self.c
        constants = self.legacy_constants()
        currency = int(constants["LEGACY_POINTS_TRAIT_CURRENCY_ID"])
        data = self.c.text_file(LEGACY_TREE_DATA)
        layout = re.findall(r"treeID = Constants\.LegacyConsts\.(\w+),\s*iconAtlas = \"([^\"]+)\",\s*name = (\w+),", data)
        if not layout:
            raise SystemExit("no Legacy trees in the client's UI data")
        trees = []
        for order, (constant, atlas, name_key) in enumerate(layout):
            trees.append(self.legacy_tree(int(constants[constant]), order, constant, atlas, name_key, currency))
        row = c.TraitCurrency.rows[currency]
        system_ids = sorted({c.TraitTree.rows[t["tree_id"]]["TraitSystemID"] for t in trees})
        strays = [t for t in c.TraitTree.rows.values()
                  if t["TraitSystemID"] in system_ids and t["ID"] not in {x["tree_id"] for x in trees}]
        return dict(
            trait_system_ids=system_ids,
            other_trees_in_system=[dict(tree_id=t["ID"], nodes=sum(n["TraitTreeID"] == t["ID"] for n in c.TraitNode.rows.values())) for t in strays],
            renown_faction_id=int(constants["LEGACY_REWARD_TRACK_FACTION_ID"]),
            talented_node_id=int(constants["LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID"]),
            currency=dict(
                currency_id=currency,
                name=self.strings.get("LEGACY_REWARD_TRACK_POINTS"),
                cap=row["SourcedMax"],
                icon=self.icon_name(row["Icon"]),
                icon_fdid=row["Icon"],
                total_grantable_by_set=self.legacy_totals(currency),
            ),
            strings={key: self.strings.get(key) for key in LEGACY_STRINGS},
            sources=self.legacy_sources(currency),
            trees=trees,
        )

    def legacy_totals(self, currency):
        totals = collections.Counter()
        for row in self.c.TraitCurrencySource.rows.values():
            if row["TraitCurrencyID"] == currency:
                totals[str(row["SuperDistrictSetID"])] += row["Amount"]
        return dict(sorted(totals.items()))

    def legacy_sources(self, currency):
        c = self.c
        out = []
        for row in sorted(c.TraitCurrencySource.rows.values(), key=lambda r: (r["SuperDistrictSetID"], r["ID"])):
            if row["TraitCurrencyID"] != currency:
                continue
            achievement = c.Achievement.rows.get(row["AchievementID"], {})
            category = c.Achievement_Category.rows.get(achievement.get("Category"), {})
            out.append(dict(
                source_id=row["ID"],
                super_district_set=row["SuperDistrictSetID"],
                amount=row["Amount"],
                requirement=row["Requirement_lang"],
                achievement_id=row["AchievementID"],
                achievement=achievement.get("Title_lang"),
                category_id=achievement.get("Category"),
                category=category.get("Name_lang"),
                quest_id=row["QuestID"],
                player_level=row["PlayerLevel"],
            ))
            if row["AchievementID"] and not achievement:
                self.anomalies.append(f"legacy source {row['ID']}: no Achievement {row['AchievementID']}")
        return out

    def legacy_tree(self, tree_id, order, constant, atlas, name_key, currency):
        c = self.c
        tree = c.TraitTree.rows[tree_id]
        nodes = sorted((n for n in c.TraitNode.rows.values() if n["TraitTreeID"] == tree_id), key=lambda n: (n["PosX"], n["PosY"]))
        name = self.strings.get(name_key)
        if not name:
            self.anomalies.append(f"no global string {name_key}")
        currencies = sorted(r["TraitCurrencyID"] for r in c.TraitTreeXTraitCurrency.rows.values() if r["TraitTreeID"] == tree_id)
        if currencies != [currency]:
            self.anomalies.append(f"legacy tree {tree_id}: currencies {currencies}")
        x0 = min(n["PosX"] for n in nodes)
        y0 = min(n["PosY"] for n in nodes)
        purchasable = {n["ID"] for n in nodes if not n["Flags"] & FLAG_NEVER_PURCHASABLE}
        out_nodes = [self.legacy_node(n, x0, y0, tree_id, name, purchasable) for n in nodes]
        self.counts["legacy_nodes"] += len(out_nodes)
        self.counts["legacy_placeholders"] += sum(n["placeholder"] for n in out_nodes)
        real = [n for n in out_nodes if not n["placeholder"]]
        return dict(
            tree_id=tree_id, order=order, constant=constant, name=name, name_key=name_key,
            trait_system_id=tree["TraitSystemID"], currency_id=currency,
            grid_origin=dict(x=x0, y=y0, cell=LEGACY_CELL),
            gate_thresholds=sorted({n["required_points_in_tree"] for n in real} - {0}),
            ranks_available=sum(n["max_ranks"] for n in real),
            **self.atlas(atlas),
            nodes=out_nodes,
        )

    def legacy_node(self, node, x0, y0, tree_id, tree_name, purchasable):
        entries = self.entries_of.get(node["ID"], [])
        info = self.definition(entries[0])
        where = f"legacy/{tree_name}/{info['name']}/{node['ID']}"
        column, column_off = divmod(node["PosX"] - x0, LEGACY_CELL)
        row, row_off = divmod(node["PosY"] - y0, LEGACY_CELL)
        if column_off or row_off:
            self.anomalies.append(f"{where}: off the {LEGACY_CELL} unit grid at {node['PosX']},{node['PosY']}")
        placeholder = not (node["ID"] in purchasable)
        selection = node["Type"] in (2, 3)
        ranked = entries[:1] if selection else entries
        ranks, tokens = self.ranks(ranked, where)
        conditions = self.conditions(node, entries)
        required = self.required_points(conditions)
        prerequisites, ignored = self.edges(node, required, self.describe)
        for cond in conditions:
            if cond.get("spent_in_group") and self.group_nodes[cond["spent_in_group"]] != purchasable:
                self.anomalies.append(f"{where}: gate counts group {cond['spent_in_group']}, not the whole tree")
        marks = self.class_marks(info["spell"], conditions)
        if selection:
            self.anomalies.append(f"{where}: choice node")
        if not placeholder and not self.groups_of[node["ID"]]:
            self.anomalies.append(f"{where}: purchasable but in no group")
        return dict(
            node_id=node["ID"],
            name=info["name"],
            icon=self.icon_name(info["icon"]),
            icon_fdid=info["icon"],
            pos=dict(x=node["PosX"], y=node["PosY"]),
            grid=dict(column=column, row=row),
            node_type=NODE_TYPES.get(node["Type"], node["Type"]),
            node_flags=node["Flags"],
            placeholder=placeholder,
            class_specific=any(marks.values()),
            class_evidence=marks,
            max_ranks=self.max_ranks(node, entries),
            cost_per_rank=self.costs(tree_id, node, entries),
            required_points_in_tree=required,
            conditions=conditions,
            prerequisites=prerequisites,
            ignored_edges=ignored,
            is_choice=selection,
            choices=[dict(entry_id=e["ID"], name=self.definition(e)["name"]) for e in entries] if selection else [],
            description_template=info["template"],
            ranks=ranks,
            unresolved_tokens=tokens,
        )

    # ---- whole file

    def run(self):
        c = self.c
        info = c.casc.info
        tables = c.tables_info.values()
        classes = self.regular()
        points = self.talent_points()
        legacy = self.legacy()
        self.counts["classes"] = len(classes)
        self.counts["trees"] = sum(len(x["trees"]) for x in classes.values())
        self.counts["unresolved"] = len(self.unresolved)
        return dict(
            source=dict(
                edition="forever", product=info["Product"], build=c.build, build_config=info["Build Key"],
                cdn_config=info["CDN Key"], locale=self.locale, provisional=True,
                hotfixes="not included: the client files don't hold server hotfixes",
                note="Pre-launch client data. Provisional until re-extracted from the live build.",
            ),
            tables=c.tables_info,
            encrypted=dict(
                sections=sum(t["encrypted_sections"] for t in tables),
                records=sum(t["encrypted_records"] for t in tables),
                blte_chunks=sum(t["encrypted_blte_chunks"] for t in tables),
            ),
            counts=dict(sorted(self.counts.items())),
            anomalies=self.anomalies,
            unresolved=self.unresolved,
            talent_points=points,
            classes=classes,
            legacy=legacy,
        )


def main():
    if len(sys.argv) < 6:
        raise SystemExit(__doc__)
    install, dbd, listfile, out_dir = sys.argv[2:6]
    locale = sys.argv[6] if len(sys.argv) > 6 else "enUS"
    only = [x.lower() for x in sys.argv[7:]]
    for attempt in range(ATTEMPTS):
        try:
            result = Extract(Client(install, dbd, listfile, locale), locale, only).run()
            break
        except RETRY_ERRORS as error:
            print(f"read failed ({type(error).__name__}: {error}), attempt {attempt + 1}/{ATTEMPTS}", file=sys.stderr)
            if attempt == ATTEMPTS - 1:
                raise SystemExit(f"{locale} is not readable: {error}")
            time.sleep(30)
    os.makedirs(out_dir, exist_ok=True)
    tag = "_".join(only) if only else "all"
    path = os.path.join(out_dir, f"forever_{result['source']['build']}_{tag}_{locale}.json")
    with open(path, "w", encoding="utf-8") as output:
        json.dump(result, output, ensure_ascii=False, indent=1)
    print(path)
    print(json.dumps(result["counts"], ensure_ascii=False))
    print(json.dumps(result["encrypted"], ensure_ascii=False))
    print(f"anomalies: {len(result['anomalies'])}")
    for line in result["anomalies"]:
        print(" ", line)


if __name__ == "__main__":
    main()
