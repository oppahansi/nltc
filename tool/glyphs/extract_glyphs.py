"""Extract WotLK glyphs to one JSON per source and language.

Usage:
  python3 -I extract_glyphs.py original <Data dir> <out_dir>
  python3 -I extract_glyphs.py classic <build> <dbd_dir> <out_dir> <csv_dir> [<csv_dir> ...]
  python3 -I extract_glyphs.py compare <original_enUS.json> <classic_enUS.json> [<icons_dir>]

"original" reads a 3.3.5a client's MPQs (enGB and deDE). "classic" reads wago.tools
CSVs named <Table>_<locale>.csv: the tables extract_classic.py needs, plus
GlyphProperties, GlyphSlot, Item, ItemSparse, ItemEffect, SkillLineAbility,
SpellClassOptions and GlobalStrings. Client files and downloads are only read, never run.

A glyph is kept only if a class 16 item for it has an Inscription recipe listed in
SkillLineAbility, in both sources. See tool/README.md for what that rule rests on.
"""

import collections
import csv
import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "classic"))
sys.path.insert(0, os.path.join(HERE, "..", "original"))
from extract_classic import CsvClient, Renderer, file_name  # noqa: E402
from mpq import Client, Dbc  # noqa: E402

csv.field_size_limit(1 << 24)

# The app's class ids.
CLASS_IDS = dict(
    druid=0, hunter=1, mage=2, paladin=3, priest=4, rogue=5, shaman=6, warlock=7, warrior=8, deathknight=9
)
ITEM_SUBCLASS = {
    1: "warrior", 2: "paladin", 3: "hunter", 4: "rogue", 5: "priest",
    6: "deathknight", 7: "shaman", 8: "mage", 9: "warlock", 11: "druid",
}
SPELL_FAMILY = {
    3: "mage", 4: "warrior", 5: "warlock", 6: "priest", 7: "druid",
    8: "rogue", 9: "hunter", 10: "paladin", 11: "shaman", 15: "deathknight",
}
ALLOWABLE_CLASS = {
    1: "warrior", 2: "paladin", 4: "hunter", 8: "rogue", 16: "priest",
    32: "deathknight", 64: "shaman", 128: "mage", 256: "warlock", 1024: "druid",
}
INSCRIPTION = 773
GLYPH_ITEM_CLASS = 16
EFFECT_CREATE_ITEM = 24
EFFECT_APPLY_GLYPH = 74
# Recipe names that say nothing about the glyph. They also create real glyph items.
PLACEHOLDER_RECIPE = re.compile(r"^(Unused|.* Glyph \d+)$")
LOCALES = {"enUS": "en", "deDE": "de"}

# 3.3.5a has no item-to-spell link, so its items join on recipe name = the glyph
# spell's name. These recipes are named differently. Each pair matches 3.4.5's ItemEffect.
ORIGINAL_NAME_LINKS = {
    41538: 227,  # recipe "Glyph of Mana Tide Totem", spell "Glyph of Mana Tide"
    40899: 163,  # recipe "Glyph of Growl", spell "Glyph of Growling"
    43392: 480,  # recipe "Glyph of Curse of Exhaustion", spell "Glyph of Curse of Exhausion"
}

# Spell.dbc field indexes in 3.3.5a. Each string is 17 fields long.
S = dict(
    caster_aura=24, exclude_caster_aura=26, level=39, duration=40, stack=49, proc_chance=35, proc_charges=36,
    effect=71, die=74, per_level=77, base=80, radius=92, period=98, multiple=101, chain=104, item_type=107,
    misc=110, per_combo=119, icon=133, name=136, desc=170, family=208, max_targets=212, variables=232,
)
TO_FLOAT = struct.Struct("<I"), struct.Struct("<f")


def as_float(value):
    return TO_FLOAT[1].unpack(TO_FLOAT[0].pack(value))[0]


def signed(value):
    return value - (1 << 32) if value >= 1 << 31 else value


def loc_string(dbc, row, start):
    for slot in range(16):
        text = dbc.string(row[start + slot])
        if text:
            return text
    return ""


class Rows:
    def __init__(self, rows):
        self.rows = rows


class DbcSpells:
    """Spell tables from a 3.3.5a client, in the shape extract_classic's Renderer reads."""

    def __init__(self, client):
        def table(name):
            return Dbc(client.read(f"DBFilesClient\\{name}.dbc"))

        spell = table("Spell")
        self.spell_rows = {r[0]: r for r in spell.rows()}
        self.spell_dbc = spell
        spells, names, misc, auras, targets, effects, links = {}, {}, {}, {}, {}, {}, {}
        for sid, r in self.spell_rows.items():
            spells[sid] = dict(ID=sid, Description_lang=loc_string(spell, r, S["desc"]))
            names[sid] = dict(ID=sid, Name_lang=loc_string(spell, r, S["name"]))
            misc[sid] = dict(SpellID=sid, DifficultyID=0, DurationIndex=r[S["duration"]])
            auras[sid] = dict(
                SpellID=sid, DifficultyID=0, ProcChance=r[S["proc_chance"]],
                ProcCharges=r[S["proc_charges"]], CumulativeAura=r[S["stack"]],
            )
            targets[sid] = dict(SpellID=sid, DifficultyID=0, MaxTargets=r[S["max_targets"]])
            if r[S["variables"]]:
                links[sid] = dict(SpellID=sid, SpellDescriptionVariablesID=r[S["variables"]])
            # Every slot, even with no effect type: glyph text reads values from such slots.
            for i in range(3):
                effects[(sid, i)] = dict(
                    SpellID=sid, DifficultyID=0, EffectIndex=i, EffectBasePointsF=0, Variance=0,
                    EffectBasePoints=signed(r[S["base"] + i]), EffectDieSides=signed(r[S["die"] + i]),
                    EffectRealPointsPerLevel=as_float(r[S["per_level"] + i]),
                    EffectAuraPeriod=r[S["period"] + i], EffectRadiusIndex=[r[S["radius"] + i], 0],
                    EffectChainTargets=r[S["chain"] + i], EffectAmplitude=as_float(r[S["multiple"] + i]),
                    EffectPointsPerResource=as_float(r[S["per_combo"] + i]),
                )
        self.Spell, self.SpellName, self.SpellMisc = Rows(spells), Rows(names), Rows(misc)
        self.SpellAuraOptions, self.SpellTargetRestrictions = Rows(auras), Rows(targets)
        self.SpellEffect, self.SpellXDescriptionVariables = Rows(effects), Rows(links)
        self.SpellDuration = Rows({
            r[0]: dict(Duration=signed(r[1]), DurationPerLevel=signed(r[2]), MaxDuration=signed(r[3]))
            for r in table("SpellDuration").rows()
        })
        self.SpellRadius = Rows({r[0]: dict(Radius=as_float(r[1])) for r in table("SpellRadius").rows()})
        variables = table("SpellDescriptionVariables")
        self.SpellDescriptionVariables = Rows({
            r[0]: dict(Variables=variables.string(r[1])) for r in variables.rows()
        })


def make_renderer(client, locale):
    renderer = Renderer(client, "wow_classic", locale)
    # Unlike talents, a glyph's condition may be about the glyph's own target, so
    # every $? stays visible as a marker rather than being assumed false.
    renderer.conditions_false = False
    return renderer


def render(renderer, spell_id):
    text, notes = renderer.render_rank(spell_id)
    raw = renderer.spells.get(spell_id, {}).get("Description_lang", "")
    text = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    tidied = re.sub(r" {2,}", " ", re.sub(r"\.{2,}", ".", text))
    return tidied, raw, notes


def text_defects(text):
    found = []
    text = re.sub(r"\[\[\?.*?\]\]", "?", text)
    if not text.strip():
        found.append("empty")
    # Text run into a number, like "5%10 sec." or "10sec", but not "4th".
    if re.search(r"\d%[^\W_]|\d(?!st\b|nd\b|rd\b|th\b)[^\W\d_]|[^\W\d_]\d", text):
        found.append("digit-adjacent")
    if re.search(r"\s[.,;:]|  |\$|<|>|,[^\s\d]", text):
        found.append("punctuation")
    return found


def glyph_type(flags):
    return {0: "major", 1: "minor"}.get(flags)


def slot_list(rows, level_strings):
    """rows: (id, type, tooltip). Keeps rows the UI's six tooltips refer to."""
    slots = []
    for slot_id, kind, tooltip in sorted(rows, key=lambda r: r[2]):
        if tooltip:
            text = level_strings.get(f"GLYPH_SLOT_TOOLTIP{tooltip}", "")
            level = re.search(r"\d+", text)
            slots.append(dict(
                slot_id=slot_id, type=glyph_type(kind), tooltip=tooltip,
                unlock_level=int(level.group()) if level else None,
            ))
    return slots


def finish(result):
    """Adds everything derived from the glyph list."""
    glyphs = sorted(result["glyphs"], key=lambda g: (g["class_id"], g["type"], g["name"]))
    result["glyphs"] = glyphs
    counts = collections.defaultdict(lambda: dict(major=0, minor=0))
    for glyph in glyphs:
        counts[glyph["class"]][glyph["type"]] += 1
    result["counts"] = {name: counts[name] for name in sorted(counts, key=CLASS_IDS.get)}
    result["total"] = len(glyphs)
    result["unresolved"] = [
        dict(id=g["id"], name=g["name"], tokens=g["unresolved"], template=g["template"])
        for g in glyphs if g["unresolved"]
    ]
    result["text_defects"] = [
        dict(id=g["id"], name=g["name"], defects=d, description=g["description"])
        for g in glyphs for d in [text_defects(g["description"])] if d
    ]


def write(result, out_dir, name):
    path = os.path.join(out_dir, name)
    with open(path, "w", encoding="utf-8") as out:
        json.dump(result, out, ensure_ascii=False, indent=1)
        out.write("\n")
    print(path)
    return path


def glyph_entry(gid, cls, kind, name, description, spell, apply_spell, item, recipe, icon, socket_icon, level, raw, notes):
    return dict(
        id=gid, class_id=CLASS_IDS[cls], **{"class": cls}, type=kind, name=name, description=description,
        spell_id=spell, apply_spell_id=apply_spell, item_id=item, recipe_spell_id=recipe,
        icon=icon, socket_icon=socket_icon, required_level=level, template=raw,
        unresolved=notes["uncalculated"], level_scaled=notes["level_scaled"],
    )


def german_check(en, de):
    """Rows where the two languages disagree in shape, or the German looks cut short."""
    english = {g["id"]: g for g in en["glyphs"]}
    short, numbers = [], []
    for g in de["glyphs"]:
        other = english.get(g["id"])
        if not other:
            continue
        if len(g["description"]) < 0.75 * len(other["description"]):
            short.append(dict(id=g["id"], name=g["name"], en=other["description"], de=g["description"]))
        pattern = r"\d+(?:[.,]\d+)?"
        a = sorted(n.replace(",", ".") for n in re.findall(pattern, other["description"]))
        b = sorted(n.replace(",", ".") for n in re.findall(pattern, g["description"]))
        if a != b:
            numbers.append(dict(id=g["id"], name=g["name"], en=other["description"], de=g["description"]))
    return dict(german_under_75_percent=short, number_mismatches=numbers)


# ---- Original


def original_strings(client):
    text = client.read("Interface\\FrameXML\\GlobalStrings.lua").decode("utf-8", "replace")
    return {m.group(1): m.group(2) for m in re.finditer(r'^(\w+) = "(.*)";\s*$', text, re.M)}


def extract_original(data_dir, out_dir):
    results = {}
    # Links are worked out on the English names, then reused for German.
    links = None
    for locale, folder in (("enUS", "enGB"), ("deDE", "deDE")):
        results[locale], links = original_one(Client(data_dir, folder), locale, folder, links)
    checks = german_check(results["enUS"], results["deDE"])
    results["deDE"].update(checks)
    for locale, result in results.items():
        write(result, out_dir, f"glyphs_original_3.3.5a_{locale}.json")


def original_one(client, locale, folder, links):
    def table(name):
        return Dbc(client.read(f"DBFilesClient\\{name}.dbc"))

    spells = DbcSpells(client)
    rows, dbc = spells.spell_rows, spells.spell_dbc
    renderer = make_renderer(spells, locale)

    def name(sid):
        return loc_string(dbc, rows[sid], S["name"]) if sid in rows else None

    properties = {r[0]: dict(id=r[0], spell=r[1], flags=r[2], icon=r[3]) for r in table("GlyphProperties").rows()}
    icon_table = table("SpellIcon")
    spell_icons = {r[0]: icon_table.string(r[1]) for r in icon_table.rows()}
    display_table = table("ItemDisplayInfo")
    displays = {r[0]: display_table.string(r[5]) for r in display_table.rows()}
    items = {r[0]: dict(id=r[0], subclass=r[2], display=r[5]) for r in table("Item").rows() if r[1] == GLYPH_ITEM_CLASS}
    abilities = {r[2] for r in table("SkillLineAbility").rows() if r[1] == INSCRIPTION}

    apply_spells = collections.defaultdict(list)
    creators = collections.defaultdict(list)
    for sid, r in rows.items():
        for i in range(3):
            if r[S["effect"] + i] == EFFECT_APPLY_GLYPH:
                apply_spells[r[S["misc"] + i]].append(sid)
            elif r[S["effect"] + i] == EFFECT_CREATE_ITEM and r[S["item_type"] + i] in items:
                creators[r[S["item_type"] + i]].append(sid)

    # item -> recipe -> glyph
    recipes = {}
    for item_id, spell_ids in creators.items():
        listed = sorted(s for s in spell_ids if s in abilities)
        if listed:
            recipes[item_id] = listed

    unlinked = []
    glyph_of_item = links
    if glyph_of_item is None:
        glyph_of_item, unlinked = link_items(recipes, items, properties, apply_spells, rows, name)
    items_of_glyph = collections.defaultdict(list)
    for item_id, gid in glyph_of_item.items():
        items_of_glyph[gid].append(item_id)

    glyphs, dropped, class_checks = [], [], []
    for gid, prop in sorted(properties.items()):
        reason = None
        sid = prop["spell"]
        if not sid or sid not in rows:
            reason = "no spell"
        elif glyph_type(prop["flags"]) is None:
            reason = f"type flags {prop['flags']} are not major (0) or minor (1)"
        elif gid not in apply_spells:
            reason = "no spell applies this row (SpellEffect 74)"
        elif gid not in items_of_glyph:
            reason = "no class 16 item with an Inscription recipe in SkillLineAbility links to this row"
        if reason:
            dropped.append(dict(id=gid, spell_id=sid, name=name(sid), flags=prop["flags"], reason=reason))
            continue
        item_id = items_of_glyph[gid][0]
        item = items[item_id]
        listed = recipes[item_id]
        recipe = next((s for s in listed if not is_placeholder(name(s))), listed[0])
        cls = ITEM_SUBCLASS[item["subclass"]]
        family = rows[sid][S["family"]]
        icon = displays.get(item["display"], "").lower()
        checks = dict(
            spell_family=SPELL_FAMILY.get(family, f"family {family}"),
            icon=next((c for c in CLASS_IDS if c in icon), None),
        )
        for source, value in checks.items():
            if value != cls:
                class_checks.append(dict(id=gid, name=name(recipe), item_subclass=cls, source=source, value=value))
        icon_kind = "minor" if "minor" in icon else "major" if "major" in icon else None
        if icon_kind != glyph_type(prop["flags"]):
            class_checks.append(dict(id=gid, name=name(recipe), type_flag=glyph_type(prop["flags"]), icon=icon))
        description, raw, notes = render(renderer, sid)
        carrier = sid
        if not raw.strip():
            for candidate in apply_spells[gid]:
                description, raw, notes = render(renderer, candidate)
                carrier = candidate
                if raw.strip():
                    break
        entry = glyph_entry(
            gid, cls, glyph_type(prop["flags"]), name(recipe), description, carrier, apply_spells[gid][0], item_id,
            recipe, icon, spell_icons.get(prop["icon"], "").split("\\")[-1].lower(),
            rows[apply_spells[gid][0]][S["level"]] or None, raw, notes,
        )
        entry["aura_spell_name"] = name(sid)
        glyphs.append(entry)

    strings = original_strings(client)
    slot_rows = [(r[0], r[1], r[2]) for r in table("GlyphSlot").rows()]
    result = dict(
        source=dict(edition="original", version="3.3.5a", build=12340, locale=locale, client_folder=folder),
        slots=slot_list(slot_rows, strings),
        slot_rows_unused=[list(r) for r in slot_rows if not r[2]],
        slot_strings={k: v for k, v in strings.items() if k.startswith("GLYPH_SLOT_TOOLTIP") or k == "SPELL_FAILED_UNIQUE_GLYPH"},
        glyphs=glyphs,
        dropped=dropped,
        dropped_items=[
            dict(
                item_id=i, subclass=items[i]["subclass"], icon=displays.get(items[i]["display"], "").lower(),
                creating_spells=[dict(id=s, name=name(s), in_skill_line=s in abilities) for s in creators.get(i, [])],
                reason="no recipe in SkillLineAbility" if i not in recipes else "recipe did not link",
            )
            for i in sorted(items) if i not in glyph_of_item
        ],
        unlinked_items=unlinked,
        class_checks=class_checks,
        apply_spell_restrictions=[
            dict(id=g["id"], name=g["name"], caster_aura=rows[g["apply_spell_id"]][S["caster_aura"]],
                 exclude_caster_aura=rows[g["apply_spell_id"]][S["exclude_caster_aura"]])
            for g in glyphs
            if rows[g["apply_spell_id"]][S["caster_aura"]] or rows[g["apply_spell_id"]][S["exclude_caster_aura"]]
        ],
    )
    finish(result)
    return result, glyph_of_item


def link_items(recipes, items, properties, apply_spells, rows, name):
    """item -> glyph, by recipe name = the glyph spell's name, within the class if that's unique."""
    by_spell_name = collections.defaultdict(list)
    for gid, prop in properties.items():
        if gid in apply_spells and prop["spell"] in rows:
            spell_name = name(prop["spell"]).casefold()
            by_spell_name[(SPELL_FAMILY.get(rows[prop["spell"]][S["family"]]), spell_name)].append(gid)
            by_spell_name[(None, spell_name)].append(gid)
    glyph_of_item, unlinked = {}, []
    for item_id, listed in sorted(recipes.items()):
        if item_id in ORIGINAL_NAME_LINKS:
            glyph_of_item[item_id] = ORIGINAL_NAME_LINKS[item_id]
            continue
        cls = ITEM_SUBCLASS.get(items[item_id]["subclass"])
        keys = {name(s).casefold() for s in listed if not is_placeholder(name(s))}
        found = {g for k in keys for g in by_spell_name.get((cls, k), [])}
        if len(found) != 1:
            found = {g for k in keys for g in by_spell_name.get((None, k), [])}
        if len(found) == 1:
            glyph_of_item[item_id] = found.pop()
        else:
            unlinked.append(dict(item_id=item_id, recipes=[name(s) for s in listed], candidates=sorted(found)))
    return glyph_of_item, unlinked


def is_placeholder(text):
    return bool(PLACEHOLDER_RECIPE.match(text or ""))


# ---- Classic


def read_table(csv_dirs, name, locale):
    for folder in csv_dirs:
        path = os.path.join(folder, f"{name}_{locale}.csv")
        if os.path.exists(path):
            with open(path, encoding="utf-8", newline="") as source:
                return list(csv.DictReader(source))
    raise SystemExit(f"missing {name}_{locale}.csv in {csv_dirs}")


def spell_csv_dir(csv_dirs, locale):
    for folder in csv_dirs:
        if os.path.exists(os.path.join(folder, f"SpellEffect_{locale}.csv")):
            return folder
    raise SystemExit("no folder holds SpellEffect")


def extract_classic(build, dbd_dir, out_dir, csv_dirs):
    results = {}
    for locale in LOCALES:
        results[locale] = classic_one(build, dbd_dir, csv_dirs, locale)
    results["deDE"].update(german_check(results["enUS"], results["deDE"]))
    for locale, result in results.items():
        write(result, out_dir, f"glyphs_classic_{build}_{locale}.json")


def classic_one(build, dbd_dir, csv_dirs, locale):
    client = CsvClient(spell_csv_dir(csv_dirs, locale), build, "wow_classic", dbd_dir, locale)
    renderer = make_renderer(client, locale)

    def table(name):
        return read_table(csv_dirs, name, locale)

    def name(sid):
        return client.SpellName.rows.get(sid, {}).get("Name_lang")

    properties = {
        int(r["ID"]): dict(
            id=int(r["ID"]), spell=int(r["SpellID"]), flags=int(r["GlyphSlotFlags"]),
            exclusive=int(r["GlyphExclusiveCategoryID"]), icon=int(r["SpellIconFileDataID"]),
        )
        for r in table("GlyphProperties")
    }
    items = {
        int(r["ID"]): dict(id=int(r["ID"]), subclass=int(r["SubclassID"]), icon=int(r["IconFileDataID"]))
        for r in table("Item") if int(r["ClassID"]) == GLYPH_ITEM_CLASS
    }
    sparse = {int(r["ID"]): r for r in table("ItemSparse") if int(r["ID"]) in items}
    item_spells = collections.defaultdict(list)
    for r in table("ItemEffect"):
        if int(r["ParentItemID"]) in items:
            item_spells[int(r["ParentItemID"])].append(int(r["SpellID"]))
    abilities = {int(r["Spell"]) for r in table("SkillLineAbility") if int(r["SkillLine"]) == INSCRIPTION}

    families = {int(r["SpellID"]): int(r["SpellClassSet"]) for r in table("SpellClassOptions")}

    apply_glyph, creators = {}, collections.defaultdict(list)
    for r in client.SpellEffect.rows.values():
        if r["Effect"] == EFFECT_APPLY_GLYPH:
            apply_glyph[r["SpellID"]] = r["EffectMiscValue"][0]
        elif r["Effect"] == EFFECT_CREATE_ITEM and r["EffectItemType"] in items:
            creators[r["EffectItemType"]].append(r["SpellID"])

    def icon_name(fdid):
        found = file_name(client.ManifestInterfaceData, fdid) if fdid else None
        return found.lower() if found else (f"fdid:{fdid}" if fdid else "")

    glyph_of_item = {}
    for item_id, spell_ids in item_spells.items():
        linked = [apply_glyph[s] for s in spell_ids if s in apply_glyph]
        if linked:
            glyph_of_item[item_id] = linked[0]

    recipes = {i: sorted(s for s in creators.get(i, []) if s in abilities) for i in items}
    items_of_glyph = collections.defaultdict(list)
    for item_id, gid in glyph_of_item.items():
        if recipes[item_id]:
            items_of_glyph[gid].append(item_id)

    glyphs, dropped, class_checks = [], [], []
    for gid, prop in sorted(properties.items()):
        reason, sid = None, prop["spell"]
        if not sid or sid not in client.SpellName.rows:
            reason = "no spell"
        elif glyph_type(prop["flags"]) is None:
            reason = f"type flags {prop['flags']} are not major (0) or minor (1)"
        elif gid not in glyph_of_item.values():
            reason = "no class 16 item's ItemEffect applies this row"
        elif gid not in items_of_glyph:
            reason = "its items have no Inscription recipe in SkillLineAbility"
        if reason:
            dropped.append(dict(id=gid, spell_id=sid, name=name(sid), flags=prop["flags"], reason=reason))
            continue
        item_id = items_of_glyph[gid][0]
        item, row = items[item_id], sparse[item_id]
        cls = ITEM_SUBCLASS[item["subclass"]]
        icon = icon_name(item["icon"])
        checks = dict(
            allowable_class=ALLOWABLE_CLASS.get(int(row["AllowableClass"]), row["AllowableClass"]),
            spell_family=SPELL_FAMILY.get(families.get(sid, 0), f"family {families.get(sid, 0)}"),
            icon=next((c for c in CLASS_IDS if c in icon), None),
        )
        for source, value in checks.items():
            if value != cls:
                class_checks.append(dict(id=gid, name=row["Display_lang"], item_subclass=cls, source=source, value=value))
        icon_kind = "minor" if "minor" in icon else "major" if "major" in icon else None
        if icon_kind != glyph_type(prop["flags"]):
            class_checks.append(dict(id=gid, name=row["Display_lang"], type_flag=glyph_type(prop["flags"]), icon=icon))
        description, raw, notes = render(renderer, sid)
        spell_of_item = next(s for s in item_spells[item_id] if s in apply_glyph)
        carrier = sid
        if not raw.strip():
            description, raw, notes = render(renderer, spell_of_item)
            carrier = spell_of_item
        entry = glyph_entry(
            gid, cls, glyph_type(prop["flags"]), row["Display_lang"], description, carrier, spell_of_item, item_id,
            next((s for s in recipes[item_id] if not is_placeholder(name(s))), recipes[item_id][0]),
            icon, icon_name(prop["icon"]), int(row["RequiredLevel"]) or None, raw, notes,
        )
        entry["aura_spell_name"] = name(sid)
        entry["item_flags"] = int(row["Flags_0"])
        glyphs.append(entry)

    strings = {r["BaseTag"]: r["TagText_lang"] for r in table("GlobalStrings")}
    slot_rows = [(int(r["ID"]), int(r["Type"]), int(r["Tooltip"])) for r in table("GlyphSlot")]
    kept_items = {g["item_id"] for g in glyphs}
    result = dict(
        source=dict(edition="classic", version="3.4.5", build=build, locale=locale, provider="wago.tools"),
        slots=slot_list(slot_rows, strings),
        slot_rows_unused=[list(r) for r in slot_rows if not r[2]],
        slot_strings={
            k: v for k, v in strings.items()
            if k.startswith("GLYPH_SLOT_TOOLTIP") or k in ("SPELL_FAILED_UNIQUE_GLYPH", "CHOOSE_GLYPHS_HELP")
        },
        exclusive_categories=sorted({p["exclusive"] for p in properties.values() if p["exclusive"]}),
        item_requirements=dict(
            required_ability=dict(collections.Counter(r["RequiredAbility"] for r in sparse.values())),
            required_skill=dict(collections.Counter(r["RequiredSkill"] for r in sparse.values())),
        ),
        glyphs=glyphs,
        dropped=dropped,
        dropped_items=[
            dict(
                item_id=i, subclass=items[i]["subclass"], name=sparse[i]["Display_lang"],
                item_flags=int(sparse[i]["Flags_0"]), spells=item_spells.get(i, []), icon=icon_name(items[i]["icon"]),
                creating_spells=[dict(id=s, name=name(s), in_skill_line=s in abilities) for s in sorted(set(creators.get(i, [])))],
                reason="no recipe in SkillLineAbility" if not recipes[i] else "recipe's item applies no glyph",
            )
            for i in sorted(items) if i not in kept_items
        ],
        class_checks=class_checks,
    )
    finish(result)
    return result


# ---- Compare


def compare(first, second, icons_dir):
    a = json.load(open(first, encoding="utf-8"))
    b = json.load(open(second, encoding="utf-8"))
    ga, gb = {g["id"]: g for g in a["glyphs"]}, {g["id"]: g for g in b["glyphs"]}
    print(f"{a['source']['version']}: {len(ga)}  {b['source']['version']}: {len(gb)}")
    for label, ids, side in (("only in first", ga.keys() - gb.keys(), ga), ("only in second", gb.keys() - ga.keys(), gb)):
        print(f"\n{label}:")
        for gid in sorted(ids):
            g = side[gid]
            print(f"  {gid} {g['class']} {g['type']} {g['name']} (item {g['item_id']}): {g['description']}")
    for field in ("class", "type", "name", "item_id", "spell_id", "apply_spell_id", "recipe_spell_id", "icon", "socket_icon", "required_level", "description"):
        differing = [i for i in sorted(ga.keys() & gb.keys()) if ga[i][field] != gb[i][field]]
        print(f"\n{field} differs: {len(differing)}")
        for i in differing:
            print(f"  {i} {ga[i]['class']} {ga[i]['name']}\n    A: {ga[i][field]}\n    B: {gb[i][field]}")
    if icons_dir:
        have = {f[:-5] for f in os.listdir(icons_dir) if f.endswith(".webp")}
        for result in (a, b):
            for field in ("icon", "socket_icon"):
                missing = sorted({g[field] for g in result["glyphs"]} - have - {""})
                print(f"\n{result['source']['version']} {field} with no file: {len(missing)}: {missing}")


def main():
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == "original":
        os.makedirs(args[2], exist_ok=True)
        extract_original(args[1], args[2])
    elif len(args) >= 5 and args[0] == "classic":
        os.makedirs(args[3], exist_ok=True)
        extract_classic(args[1], args[2], args[3], args[4:])
    elif len(args) in (3, 4) and args[0] == "compare":
        compare(args[1], args[2], args[3] if len(args) == 4 else None)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
