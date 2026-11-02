"""Extract talent data from a local Classic client (static, read-only), or from
tables downloaded from wago.tools when no client is available.

Usage: python3 -I extract_classic.py <install> <wow_classic_era|wow_anniversary> <dbd_dir> <listfile.csv> <out.json> [locale]
       python3 -I extract_classic.py --csv <csv_dir> <build> <product> <dbd_dir> <out.json> <locale>

The CSV folder holds <Table>_<locale>.csv for each table in TABLES.

Reads CASC storage with mode 'rb' only and never starts anything. Encrypted DB2
sections are skipped and counted, never decrypted. Server hotfixes are not part
of the client files, so they are not in the extract.

Descriptions are rendered from the client's own values at the spell's base
level, in the form the original-client tools use ("45 sec", "141 to 187").
Anything that can't be calculated stays visible as [[?token]] and is counted.
"""

import ast
import collections
import csv
import hashlib
import json
import operator
import os
import re
import struct
import sys
import time
import zlib

csv.field_size_limit(1 << 24)
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "forever"))
import casc  # noqa: E402
import wdc  # noqa: E402

CLASS_BITS = {
    1: "warrior",
    2: "paladin",
    4: "hunter",
    8: "rogue",
    16: "priest",
    32: "deathknight",
    64: "shaman",
    128: "mage",
    256: "warlock",
    1024: "druid",
}

TABLES = (
    "Talent",
    "TalentTab",
    "ChrClasses",
    "Spell",
    "SpellName",
    "SpellMisc",
    "SpellEffect",
    "SpellDuration",
    "SpellRadius",
    "SpellAuraOptions",
    "ManifestInterfaceData",
)

# Only the CSV mode loads these. They're empty or unused in Era and Anniversary.
CSV_ONLY_TABLES = ("SpellDescriptionVariables", "SpellXDescriptionVariables", "SpellTargetRestrictions")

# Words the client takes from its global strings, not from the spell's template.
# deDE matches the original German client text in the app's data.
WORDS = {
    "enUS": dict(to="to", sec="sec", min="min", hrs="hrs", forever="until cancelled", decimal="."),
    "enGB": dict(to="to", sec="sec", min="min", hrs="hrs", forever="until cancelled", decimal="."),
    "deDE": dict(to="bis", sec="Sek.", min="Min.", hrs="Std.", forever="bis Abbruch", decimal=","),
}

# 1.15.9 also runs Season of Discovery. Its tuning passives and runes start here,
# and a Classic Era character never has them.
SEASON_SPELL_MIN = 400000

RETRY_ERRORS = (
    casc.NotLocalError,
    KeyError,
    ValueError,
    AssertionError,
    OSError,
    struct.error,
    zlib.error,
)


def marker(token):
    return f"[[?{token}]]"


def build_listed(build, builds):
    """True when a .dbd BUILD list names this build, singly or in a range."""
    version = tuple(int(part) for part in build.split("."))
    for item in builds:
        low, _, high = item.partition("-")
        if item == build:
            return True
        if high:
            parts = [tuple(int(p) for p in x.split(".")) for x in (low, high)]
            if len(parts[0]) == 4 and parts[0] <= version <= parts[1]:
                return True
    return False


def choose_definition(defs, build):
    """The .dbd definition listing this build, or else the one listing the newest
    build of the same patch. Returns (definition, the build it was chosen by)."""
    for definition in defs:
        if build_listed(build, definition["builds"]):
            return definition, build
    patch = build.rsplit(".", 1)[0] + "."
    best = None
    for definition in defs:
        for item in definition["builds"]:
            listed = item.split("-")[-1]
            if listed.startswith(patch) and (not best or int(listed.rsplit(".", 1)[1]) > int(best[1].rsplit(".", 1)[1])):
                best = (definition, listed)
    if not best:
        raise SystemExit(f"no definition for patch {patch}x")
    return best


class CsvTable:
    """A wago.tools CSV shaped like a wdc.WDC table: rows by ID, arrays as lists."""

    def __init__(self, path, dbd_path, build, name):
        columns, defs = wdc.parse_dbd(dbd_path)
        definition, self.definition_build = choose_definition(defs, build)
        with open(path, encoding="utf-8", newline="") as source:
            reader = csv.reader(source)
            header = next(reader)
            lines = list(reader)
        expected = []
        for field in definition["fields"]:
            count = field["arr"]
            expected += [field["name"]] if count == 1 else [f"{field['name']}_{i}" for i in range(count)]
        self.headers_match = sorted(header) == sorted(expected)
        if not self.headers_match:
            raise SystemExit(f"{name}: columns differ from the definition of {self.definition_build}: "
                             f"{sorted(set(header) ^ set(expected))}")
        self.fields_outside_width = collections.Counter()
        self.rows = {}
        index = {column: i for i, column in enumerate(header)}
        for line in lines:
            row = {}
            for field in definition["fields"]:
                kind = columns.get(field["name"], ("int", None))[0]
                if field["arr"] == 1:
                    row[field["name"]] = self._value(line[index[field["name"]]], kind, field)
                else:
                    row[field["name"]] = [
                        self._value(line[index[f"{field['name']}_{i}"]], kind, field) for i in range(field["arr"])
                    ]
            self.rows[row["ID"]] = row

    def _value(self, text, kind, field):
        if kind in ("string", "locstring"):
            return text
        if kind == "float":
            return float(text)
        value = int(text)
        fitted = wdc.fit_width(value, field["size"])
        if fitted != value:
            self.fields_outside_width[field["name"]] += 1
        return fitted


class CsvClient:
    """Tables downloaded from wago.tools, named <Table>_<locale>.csv."""

    def __init__(self, csv_dir, build, product, dbd_dir, locale):
        self.locale = locale
        self.build = build
        self.product = product
        self.tables_info = {}
        for name in TABLES + CSV_ONLY_TABLES:
            path = os.path.join(csv_dir, f"{name}_{locale}.csv")
            table = CsvTable(path, os.path.join(dbd_dir, f"{name}.dbd"), build, name)
            with open(path, "rb") as source:
                digest = hashlib.sha256(source.read()).hexdigest()
            self.tables_info[name] = dict(
                sha256=digest,
                rows=len(table.rows),
                definition_build=table.definition_build,
                definition_lists_build=table.definition_build == build,
                columns_match_definition=table.headers_match,
                values_outside_width=dict(table.fields_outside_width),
            )
            setattr(self, name, table)
        self.retrieved = time.strftime("%Y-%m-%d", time.gmtime(os.path.getmtime(path)))

    def source_fields(self, product, locale, retries):
        return dict(
            product=product,
            build=self.build,
            locale=locale,
            provider="wago.tools",
            url=f"https://wago.tools/db2/<table>/csv?build={self.build}&locale={locale}",
            retrieved=self.retrieved,
            official_client="no: decoded CSVs, not read from a client on this machine",
            hotfixes="unknown: the hotfixes option was not requested",
        )

    def encrypted_fields(self):
        return dict(sections=None, records=None, blte_chunks=None, note="not visible in a CSV")


class Client:
    def __init__(self, install, product, dbd_dir, fdids, locale):
        self.locale = locale
        self.casc = casc.Casc(install, product)
        self.build = self.casc.info["Version"]
        self.tables_info = {}
        for name in TABLES:
            setattr(self, name, self.load(name, dbd_dir, fdids))

    def load(self, name, dbd_dir, fdids):
        fdid = fdids[name.lower()]
        keys = {entry[2].hex() for entry in self.casc.entries(fdid, self.locale)}
        table = wdc.load(self.casc, dbd_dir, fdid, name, self.locale, self.build)
        layout = "%08X" % table.layout_hash
        if layout not in table.dd["layouts"] or not build_listed(self.build, table.dd["builds"]):
            raise SystemExit(f"{name}: no definition for layout {layout} and build {self.build}")
        if len(table.inline) != table.field_count:
            raise SystemExit(f"{name}: {table.field_count} fields, definition has {len(table.inline)}")
        if len(keys) != 1:
            raise SystemExit(f"{name}: {len(keys)} files for {self.locale} in root")
        self.tables_info[name] = dict(
            fdid=fdid,
            content_key=keys.pop(),
            magic=table.magic.decode(),
            layout=layout,
            definition_lists_build=True,
            records=table.record_count,
            rows=len(table.rows),
            sections=table.section_count,
            encrypted_sections=table.encrypted_sections,
            encrypted_records=table.encrypted_records,
            encrypted_blte_chunks=table.enc_chunks,
        )
        return table

    def source_fields(self, product, locale, retries):
        info = self.casc.info
        return dict(
            product=product,
            build=self.build,
            build_key=info["Build Key"],
            cdn_key=info["CDN Key"],
            locale=locale,
            install_tags=info["Tags"],
            read_retries=retries,
            hotfixes="not included: the client files don't hold server hotfixes",
        )

    def encrypted_fields(self):
        tables = self.tables_info.values()
        return dict(
            sections=sum(t["encrypted_sections"] for t in tables),
            records=sum(t["encrypted_records"] for t in tables),
            blte_chunks=sum(t["encrypted_blte_chunks"] for t in tables),
        )


class Renderer:
    def __init__(self, client, product, locale):
        self.spells = client.Spell.rows
        self.names = client.SpellName.rows
        self.durations = client.SpellDuration.rows
        self.radii = client.SpellRadius.rows
        self.words = WORDS.get(locale)
        if self.words is None:
            raise SystemExit(f"no duration and range words for locale {locale}: add them to WORDS")
        self.season_min = SEASON_SPELL_MIN if product == "wow_classic_era" else None
        # A talent calculator knows no glyphs, and 3.3.5a's text is written as if the
        # character has none of what these conditions ask about.
        self.conditions_false = product == "wow_classic"
        self.targets = {}
        self.variables = collections.defaultdict(list)
        if hasattr(client, "SpellTargetRestrictions"):
            self.targets = self._first_by_spell(client.SpellTargetRestrictions)
            texts = client.SpellDescriptionVariables.rows
            for row in client.SpellXDescriptionVariables.rows.values():
                if row["SpellDescriptionVariablesID"] in texts:
                    self.variables[row["SpellID"]].append(texts[row["SpellDescriptionVariablesID"]]["Variables"])
        self.misc = self._first_by_spell(client.SpellMisc)
        self.auras = self._first_by_spell(client.SpellAuraOptions)
        self.effects = collections.defaultdict(dict)
        for row in sorted(client.SpellEffect.rows.values(), key=lambda r: -r["DifficultyID"]):
            self.effects[row["SpellID"]][row["EffectIndex"]] = row

    @staticmethod
    def _first_by_spell(table):
        out = {}
        for row in sorted(table.rows.values(), key=lambda r: -r["DifficultyID"]):
            out[row["SpellID"]] = row
        return out

    def render_rank(self, spell):
        notes = dict(uncalculated=[], assumed_false_conditions=[], level_scaled=[], token_kinds=set())
        text = self._render(self.spells.get(spell, {}).get("Description_lang", ""), spell, notes)
        notes["token_kinds"] = sorted(notes["token_kinds"])
        return text, notes

    # ---- values

    def _number(self, value):
        if abs(value - round(value)) < 1e-6:
            return str(int(round(value)))
        return f"{round(value, 2):.2f}".rstrip("0").rstrip(".").replace(".", self.words["decimal"])

    def _duration_text(self, spell, notes):
        misc = self.misc.get(spell)
        row = self.durations.get(misc["DurationIndex"]) if misc else None
        if not row:
            return None
        if row["DurationPerLevel"] or row["MaxDuration"] not in (row["Duration"], 0):
            notes["level_scaled"].append(f"$d of {spell}")
        ms = row["Duration"]
        if ms < 0:
            return self.words["forever"]
        if ms == 0:
            return None
        if ms < 60000:
            return f"{self._number(ms / 1000)} {self.words['sec']}"
        if ms < 3600000:
            return f"{self._number(ms / 60000)} {self.words['min']}"
        return f"{self._number(ms / 3600000)} {self.words['hrs']}"

    def _points(self, spell, index, notes):
        """(lowest, highest) the effect rolls, signed, at the spell's base level."""
        effect = self.effects.get(spell, {}).get(index)
        if not effect:
            return None
        if effect["EffectBasePointsF"] or effect["Variance"]:
            return None  # Modern value fields, unused in these clients. Don't guess at them.
        if effect["EffectRealPointsPerLevel"]:
            notes["level_scaled"].append(
                f"effect {index + 1} of {spell}: {round(effect['EffectRealPointsPerLevel'], 2)} per level"
            )
        base, die = effect["EffectBasePoints"], effect["EffectDieSides"]
        return (base + 1, base + die) if die > 0 else (base, base)

    def _value(self, kind, spell, number, notes):
        """A token's signed value, or None when it can't be calculated."""
        index = (number or 1) - 1
        effect = self.effects.get(spell, {}).get(index)
        if kind == "M":
            points = self._points(spell, index, notes)
            return points[1] if points else None
        kind = kind.lower()
        if kind == "i":
            target = self.targets.get(spell)
            return target["MaxTargets"] if target and target["MaxTargets"] else None
        if kind in ("s", "m"):
            points = self._points(spell, index, notes)
            return points[0] if points else None
        if kind == "o":
            points = self._points(spell, index, notes)
            misc = self.misc.get(spell)
            duration = self.durations.get(misc["DurationIndex"]) if misc else None
            if not points or points[0] != points[1] or not duration or not effect:
                return None
            if duration["Duration"] <= 0 or effect["EffectAuraPeriod"] <= 0:
                return None
            return points[0] * (duration["Duration"] // effect["EffectAuraPeriod"])
        if kind == "t":
            return effect["EffectAuraPeriod"] / 1000 if effect and effect["EffectAuraPeriod"] else None
        if kind == "a":
            if not effect:
                return None
            radius = next((i for i in effect["EffectRadiusIndex"] if i), 0)
            return self.radii[radius]["Radius"] if radius in self.radii else None
        if kind == "x":
            return effect["EffectChainTargets"] if effect else None
        if kind == "e":
            return effect["EffectAmplitude"] if effect else None
        if kind == "b":
            return effect["EffectPointsPerResource"] if effect else None
        if kind == "d":
            misc = self.misc.get(spell)
            row = self.durations.get(misc["DurationIndex"]) if misc else None
            return row["Duration"] / 1000 if row and row["Duration"] > 0 else None
        aura = self.auras.get(spell)
        if kind == "h":
            return aura["ProcChance"] if aura else None
        if kind == "n":
            return aura["ProcCharges"] if aura else None
        if kind == "u":
            return aura["CumulativeAura"] if aura else None
        return None

    def _variable(self, name, spell, notes):
        """The value of a $<name> from the spell's description variables, or None."""
        for text in self.variables.get(spell, []):
            for line in text.splitlines():
                match = re.fullmatch(r"\s*\$" + re.escape(name) + r"=(.*?)\s*", line)
                if match:
                    return self._variable_value(match.group(1), spell, notes)
        return None

    def _variable_value(self, source, spell, notes):
        source = source.strip()
        if source.startswith("$?"):
            conditions, _, other, used = split_conditional(source)
            if used != len(source) or not self._conditions_are_false(conditions):
                return None
            notes["assumed_false_conditions"].extend(c.strip() for c in conditions)
            return self._variable_value(other, spell, notes)
        match = re.fullmatch(r"\$\{(.*)\}", source)
        return self._expression(match.group(1) if match else source, spell, notes)

    def _expression(self, source, spell, notes):
        failed = []

        def substitute(match):
            sid = int(match.group(1)) if match.group(1) else spell
            value = self._value(match.group(2), sid, int(match.group(3) or 0), notes)
            if value is None:
                failed.append(match.group(0))
                return "0"
            return f"({float(value)!r})"

        def variable(match):
            value = self._variable(match.group(1), spell, notes)
            if value is None:
                failed.append(match.group(0))
                return "0"
            return f"({float(value)!r})"

        source = re.sub(r"\$<(\w+)>", variable, source)
        if re.search(r"\$[A-Z]{2,}|\$pl\b", source):
            return None  # Character stats such as $AP and $PL.
        replaced = re.sub(r"\$(\d+)?([A-Za-z])(\d?)", substitute, source)
        if failed:
            return None
        try:
            return arithmetic(ast.parse(replaced, mode="eval").body)
        except (SyntaxError, ValueError, ZeroDivisionError):
            return None

    # ---- template

    def _render(self, text, spell, notes):
        out = []
        pos = 0
        while pos < len(text):
            if text[pos] != "$":
                out.append(text[pos])
                pos += 1
                continue
            rest = text[pos:]
            if rest.startswith("$?"):
                piece, used = self._conditional(rest, spell, notes)
                out.append(piece)
                pos += used
                continue
            match = re.match(r"\$\{([^}]*)\}(?:\.(\d))?", rest)
            if match:
                notes["token_kinds"].add("${}")
                value = self._expression(match.group(1), spell, notes)
                if value is None:
                    out.append(self._unknown(match.group(0), notes))
                elif match.group(2):
                    fixed = f"{value:.{int(match.group(2))}f}"
                    out.append(fixed.replace(".", self.words["decimal"]))
                else:
                    out.append(self._number(value))
                pos += match.end()
                continue
            match = re.match(r"\$([/*])(-?\d+(?:\.\d+)?);(\d+)?([A-Za-z])(\d?)", rest)
            if match:
                sid = int(match.group(3)) if match.group(3) else spell
                notes["token_kinds"].add(f"${match.group(1)}{match.group(4).lower()}")
                kind, number = match.group(4), int(match.group(5) or 0)
                factor = float(match.group(2))
                if kind in "sS" and factor:
                    points = self._points(sid, (number or 1) - 1, notes)
                else:
                    points = None
                value = self._value(kind, sid, number, notes)
                if value is None or factor == 0 or self._only_level_scaling(kind, sid, number):
                    out.append(self._unknown(match.group(0), notes))
                else:
                    scale = (lambda v: v / factor) if match.group(1) == "/" else (lambda v: v * factor)
                    if points and points[0] != points[1]:
                        low, high = sorted((abs(scale(points[0])), abs(scale(points[1]))))
                        out.append(f"{self._number(low)} {self.words['to']} {self._number(high)}")
                    else:
                        out.append(self._number(abs(scale(value))))
                pos += match.end()
                continue
            match = re.match(r"\$[lL]([^:;]*):([^;]*);", rest)
            if match:
                notes["token_kinds"].add("$l")
                numbers = re.findall(r"\d+(?:[.,]\d+)?", "".join(out))
                single = numbers and float(numbers[-1].replace(",", ".")) == 1
                out.append(match.group(1) if single else match.group(2))
                pos += match.end()
                continue
            match = re.match(r"\$<(\w+)>", rest)
            if match:
                notes["token_kinds"].add("$<>")
                value = self._variable(match.group(1), spell, notes)
                out.append(self._unknown(match.group(0), notes) if value is None else self._number(abs(value)))
                pos += match.end()
                continue
            match = re.match(r"\$[gG][^:;]*:[^;]*;|\$@\w+|\$[A-Z]{2,}|\$pl\b", rest)
            if match:
                out.append(self._unknown(match.group(0), notes))
                pos += match.end()
                continue
            match = re.match(r"\$(\d+)?([A-Za-z])(\d?)", rest)
            if match:
                sid = int(match.group(1)) if match.group(1) else spell
                out.append(self._plain(match, sid, notes))
                pos += match.end()
                continue
            out.append(self._unknown("$", notes))
            pos += 1
        return "".join(out)

    def _only_level_scaling(self, kind, spell, number):
        """A base value of 0 that grows per level says nothing at the base level."""
        if kind.lower() not in "smo":
            return False
        index = (number or 1) - 1
        effect = self.effects.get(spell, {}).get(index)
        if not effect or not effect["EffectRealPointsPerLevel"]:
            return False
        base, die = effect["EffectBasePoints"], effect["EffectDieSides"]
        return (base + 1 if die > 0 else base) == 0 and die <= 1

    def _plain(self, match, spell, notes):
        kind, number = match.group(2), int(match.group(3) or 0)
        notes["token_kinds"].add("$" + kind.lower())
        if self._only_level_scaling(kind, spell, number):
            self._points(spell, (number or 1) - 1, notes)
            return self._unknown(match.group(0), notes)
        if kind in "dD":
            text = self._duration_text(spell, notes)
            return text if text is not None else self._unknown(match.group(0), notes)
        if kind in "sS":
            points = self._points(spell, (number or 1) - 1, notes)
            if points and points[0] != points[1]:
                low, high = sorted((abs(points[0]), abs(points[1])))
                return f"{low} {self.words['to']} {high}"
        if kind == "M":
            points = self._points(spell, (number or 1) - 1, notes)
            if points:
                return self._number(abs(points[1]))
        value = self._value(kind, spell, number, notes)
        if value is None:
            return self._unknown(match.group(0), notes)
        return self._number(abs(value))

    def _unknown(self, token, notes):
        notes["uncalculated"].append(token)
        return marker(token)

    def _conditional(self, text, spell, notes):
        """Conditions that can be decided are false: Season of Discovery ones on Era, and
        all of them on 3.4.5. Returns (rendered, length)."""
        notes["token_kinds"].add("$?")
        conditions, _, other, used = split_conditional(text)
        if not conditions or not self._conditions_are_false(conditions):
            return self._unknown(text[:used], notes), used
        notes["assumed_false_conditions"].extend(c.strip() for c in conditions)
        return self._render(other, spell, notes), used

    def _conditions_are_false(self, conditions):
        if any("!" in c for c in conditions):
            return False
        if self.conditions_false:
            return True
        return self.season_min is not None and all(
            ids and all(int(i) >= self.season_min for i in ids)
            for ids in (re.findall(r"\d+", c) for c in conditions)
        )


def split_conditional(text):
    """Splits $?cond[then]?cond[then][else]. Returns (conditions, bodies, else, length)."""
    pos = 1
    conditions, bodies = [], []
    while pos < len(text) and text[pos] == "?":
        start = text.find("[", pos)
        if start < 0:
            return [], [], "", pos + 1
        end = closing_bracket(text, start)
        conditions.append(text[pos + 1 : start])
        bodies.append(text[start + 1 : end])
        pos = end + 1
    other = ""
    if pos < len(text) and text[pos] == "[":
        end = closing_bracket(text, pos)
        other = text[pos + 1 : end]
        pos = end + 1
    return conditions, bodies, other, pos


def closing_bracket(text, start):
    depth = 0
    for pos in range(start, len(text)):
        depth += {"[": 1, "]": -1}.get(text[pos], 0)
        if depth == 0:
            return pos
    raise ValueError(f"unbalanced condition: {text[start:start + 60]}")


OPERATORS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
}


def arithmetic(node):
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return float(node.value)
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return -arithmetic(node.operand)
    if isinstance(node, ast.BinOp) and type(node.op) in OPERATORS:
        return OPERATORS[type(node.op)](arithmetic(node.left), arithmetic(node.right))
    raise ValueError("not arithmetic")


def file_name(manifest, fdid):
    row = manifest.rows.get(fdid)
    return re.sub(r"\.blp$", "", row["FileName"], flags=re.I).lower() if row else None


def assemble(client, product, locale, retries):
    renderer = Renderer(client, product, locale)
    manifest = client.ManifestInterfaceData
    class_ids = {r["Filename"].lower(): r["ID"] for r in client.ChrClasses.rows.values()}
    talents = client.Talent.rows
    anomalies = []
    missing_rows = collections.Counter()
    counts = collections.Counter()
    classes = {}
    pet_tabs = [t["ID"] for t in client.TalentTab.rows.values() if not t["ClassMask"]]

    by_tab = collections.defaultdict(list)
    for talent in talents.values():
        by_tab[talent["TabID"]].append(talent)
    orphans = [t["ID"] for t in talents.values() if t["TabID"] not in client.TalentTab.rows]
    if orphans:
        anomalies.append(f"talents with an unknown tab: {orphans}")

    for tab in sorted(client.TalentTab.rows.values(), key=lambda t: (t["ClassMask"], t["OrderIndex"])):
        if not tab["ClassMask"]:
            counts["pet_talents_excluded"] += len(by_tab[tab["ID"]])
            continue
        code = CLASS_BITS.get(tab["ClassMask"])
        if code is None:
            anomalies.append(f"tab {tab['ID']} has class mask {tab['ClassMask']}")
            continue
        entry = classes.setdefault(code, dict(class_id=class_ids.get(code), class_mask=tab["ClassMask"], trees=[]))
        out_talents = []
        for talent in sorted(by_tab[tab["ID"]], key=lambda t: (t["TierID"], t["ColumnIndex"])):
            where = f"{code}/{tab['Name_lang']}/{talent['TierID']},{talent['ColumnIndex']}"
            if talent["ClassID"] not in (0, entry["class_id"]):  # 3.4.5 leaves it at 0.
                anomalies.append(f"{where}: Talent.ClassID {talent['ClassID']} differs from its tab's class")
            spells = [s for s in talent["SpellRank"] if s]
            if spells != talent["SpellRank"][: len(spells)]:
                anomalies.append(f"{where}: gaps in SpellRank {talent['SpellRank']}")
            if not spells:
                anomalies.append(f"{where}: no rank spells")
                continue
            names = {client.SpellName.rows.get(s, {}).get("Name_lang") for s in spells}
            if len(names) > 1:
                anomalies.append(f"{where}: rank spells have different names {sorted(map(str, names))}")
            misc = renderer.misc.get(spells[0])
            icon_fdid = misc["SpellIconFileDataID"] if misc else 0
            icon = file_name(manifest, icon_fdid)
            if icon is None:
                anomalies.append(f"{where}: no manifest row for icon file {icon_fdid}")
            icons = {
                renderer.misc[s]["SpellIconFileDataID"] for s in spells if s in renderer.misc
            }
            if len(icons) > 1:
                anomalies.append(f"{where}: rank spells have different icons {sorted(icons)}")
            prerequisites = []
            for required, rank in zip(talent["PrereqTalent"], talent["PrereqRank"]):
                if not required:
                    continue
                other = talents.get(required)
                if not other:
                    anomalies.append(f"{where}: unknown prerequisite talent {required}")
                    continue
                if other["TabID"] != talent["TabID"]:
                    anomalies.append(f"{where}: prerequisite {required} is in another tree")
                prerequisites.append(
                    dict(
                        talent_id=required,
                        row=other["TierID"],
                        column=other["ColumnIndex"],
                        name=client.SpellName.rows.get(
                            next((s for s in other["SpellRank"] if s), 0), {}
                        ).get("Name_lang"),
                        required_rank=rank + 1,
                    )
                )
            ranks = []
            for number, spell in enumerate(spells, 1):
                for table, rows in (
                    ("Spell", client.Spell.rows),
                    ("SpellName", client.SpellName.rows),
                    ("SpellMisc", renderer.misc),
                    ("SpellEffect", renderer.effects),
                ):
                    if spell not in rows:
                        missing_rows[table] += 1
                        anomalies.append(f"{where}: rank {number} spell {spell} has no {table} row")
                text, notes = renderer.render_rank(spell)
                counts["ranks"] += 1
                counts["uncalculated_tokens"] += len(notes["uncalculated"])
                counts["ranks_with_uncalculated"] += bool(notes["uncalculated"])
                counts["assumed_false_conditions"] += len(notes["assumed_false_conditions"])
                counts["ranks_with_assumed_false"] += bool(notes["assumed_false_conditions"])
                counts["ranks_level_scaled"] += bool(notes["level_scaled"])
                ranks.append(
                    dict(
                        rank=number,
                        spell_id=spell,
                        description=text,
                        template=client.Spell.rows.get(spell, {}).get("Description_lang", ""),
                        **notes,
                    )
                )
            counts["talents"] += 1
            out_talents.append(
                dict(
                    talent_id=talent["ID"],
                    row=talent["TierID"],
                    column=talent["ColumnIndex"],
                    name=client.SpellName.rows.get(spells[0], {}).get("Name_lang"),
                    icon=icon,
                    icon_fdid=icon_fdid,
                    rank_count=len(spells),
                    prerequisites=prerequisites,
                    ranks=ranks,
                )
            )
        positions = collections.Counter((t["row"], t["column"]) for t in out_talents)
        for position, count in positions.items():
            if count > 1:
                anomalies.append(f"{code}/{tab['Name_lang']}: {count} talents at {position}")
        entry["trees"].append(
            dict(
                tab_id=tab["ID"],
                name=tab["Name_lang"],
                order=tab["OrderIndex"],
                icon=file_name(manifest, tab["SpellIconID"]),
                icon_fdid=tab["SpellIconID"],
                background=tab["BackgroundFile"],
                talents=out_talents,
            )
        )

    counts["classes"] = len(classes)
    counts["trees"] = sum(len(c["trees"]) for c in classes.values())
    counts["pet_tabs_excluded"] = len(pet_tabs)
    return dict(
        source=client.source_fields(product, locale, retries),
        tables=client.tables_info,
        encrypted=dict(**client.encrypted_fields(), talent_rank_rows_missing=dict(missing_rows)),
        counts=dict(sorted(counts.items())),
        anomalies=anomalies,
        classes=dict(sorted(classes.items())),
    )


def read_fdids(listfile):
    fdids = {}
    with open(listfile, encoding="utf-8", errors="replace") as lines:
        for line in lines:
            if ";dbfilesclient/" in line and line.rstrip().endswith(".db2"):
                fdid, path = line.rstrip().split(";", 1)
                fdids[path.split("/")[-1][:-4].lower()] = int(fdid)
    return fdids


def write(result, out):
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8") as output:
        json.dump(result, output, ensure_ascii=False, indent=1)
    print(out)
    print(json.dumps(dict(source=result["source"], counts=result["counts"], encrypted=result["encrypted"]), ensure_ascii=False))
    print(f"anomalies: {len(result['anomalies'])}")
    for line in result["anomalies"]:
        print(" ", line)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--csv":
        if len(sys.argv) != 8:
            raise SystemExit(__doc__)
        csv_dir, build, product, dbd, out, locale = sys.argv[2:8]
        write(assemble(CsvClient(csv_dir, build, product, dbd, locale), product, locale, 0), out)
        return
    if len(sys.argv) not in (6, 7):
        raise SystemExit(__doc__)
    install, product, dbd, listfile, out = sys.argv[1:6]
    locale = sys.argv[6] if len(sys.argv) > 6 else "enUS"
    if not os.path.isfile(os.path.join(dbd, "Talent.dbd")):
        raise SystemExit(f"no Talent.dbd in {dbd}")
    fdids = read_fdids(listfile)
    # The launcher may be writing to a shared install, so a failed read gets a fresh
    # look at the indices rather than being taken for missing data.
    attempts = 4
    for attempt in range(attempts):
        try:
            client = Client(install, product, dbd, fdids, locale)
            result = assemble(client, product, locale, attempt)
            break
        except RETRY_ERRORS as error:
            print(f"read failed ({type(error).__name__}: {error}), attempt {attempt + 1}/{attempts}", file=sys.stderr)
            if attempt == attempts - 1:
                raise SystemExit(f"{locale} of {product} is not readable: {error}")
            time.sleep(30)
    write(result, out)


if __name__ == "__main__":
    main()
