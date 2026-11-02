"""Correct rank descriptions in ltc_data.db.sql using the original clients' text.

Usage:
  python3 -I fix_descriptions.py <sql file> <vanilla en dir> <tbc en dir> <tbc de dir> \
      <wotlk dir> [--write]

Each description is rebuilt from the client's template, keeping the app's values.
A rebuilt description is only accepted if it holds exactly the same numbers. Any
other description only gets mechanical cleanup, and is listed for manual review.
Vanilla German has no client to compare against, so it also only gets cleanup.
"""

import os
import re
import sqlite3
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare_ranks import (  # noqa: E402
    EFFECTS,
    TOKEN,
    signed,
    localized,
    relaxed,
    relaxed_de,
    template_pattern,
)
from compare_talents import CLASS_BITS, LAYOUTS  # noqa: E402
from mpq import Client, Dbc  # noqa: E402

# Reviewed by hand: the client's wording, where its template depends on player
# state and so can't be rebuilt automatically.
MANUAL_TEXT = [
    ("the casterfor ", "the caster for "),
    ("Cause a corpse or your ghoul to explode", "Cause a corpse to explode"),
    ("einen Leichnam oder Euren Ghul zum Bersten", "einen Leichnam zum Bersten"),
]

# Reviewed by hand: the app's numbers were wrong, so trust the client's own values.
TRUST_CLIENT = {
    ("wotlk", "en", ("warlock", "Demonology", 9, 1)),
    ("wotlk", "de", ("warlock", "Demonology", 9, 1)),
    ("tbc", "de", ("paladin", "Retribution", 5, 1)),
    ("tbc", "de", ("warrior", "Protection", 8, 1)),
}

# Stack sizes, for "$u" tokens. The Spell field isn't mapped here.
STACKS = {20050: 3, 20052: 3, 20053: 3, 20054: 3, 20055: 3, 20056: 3}

NUMBER = re.compile(r"\d+(?:[.,]\d+)?")
MARKUP = re.compile(r"<!--|<br|\$")


def cleanup(text, lang):
    """Fixes that are safe without a client."""
    # Glyph text from a later expansion, wrapped in Wowhead markup.
    text = re.sub(r"\s*<span class='q2'>.*?</span>\s*<span class='q9'>.*?</span>", "", text, flags=re.S)
    text = re.sub(r"</?span[^>]*>", "", text)
    # A scaled value: <!--ppl<spell>:<levels>:<base>:<scale>-->shown. Keep the base.
    text = re.sub(r"<!--ppl\d+:\d+:\d+:(\d+):\d+(?::\d+)?-->\d+", r"\1", text)
    text = re.sub(r"<!--.*?-->", "", text)
    text = re.sub(r"\s*<br\s*/?>\s*", "\n", text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r",(?=[^\s\d])", ", ", text)
    text = re.sub(r"\b(Sek|sec|Min|min)\.\.+", r"\1.", text)
    for wrong, right in MANUAL_TEXT:
        text = text.replace(wrong, right)
    if lang == "de":
        text = re.sub(r"(\d) sec\b\.?", r"\1 Sek.", text)
        text = re.sub(r"(\d) min\b\.?", r"\1 Min.", text)
        text = re.sub(r"(\d) to (\d)", r"\1 bis \2", text)
    return text.strip()


def tidy(text, lang):
    """The last pass over any result, however it was produced."""
    text = re.sub(r"\.{2,}", ".", text)
    text = re.sub(
        r"reduces your global cooldown by (\d+)% when casting Lifebloom",
        r"reduces the base cooldown of your Lifebloom spell by \1%",
        text,
    )
    if lang == "de":
        text = re.sub(r"\b(Sek|Min)(?=\s)", r"\1.", text)
    return text


def fmt(value):
    return f"{value:g}" if value == int(value) else f"{value:.2f}".rstrip("0")


class Renderer:
    """Calculates a client description from its spell's own values."""

    def __init__(self, kind, client, spells, spell_dbc, layout, lang):
        self.spells, self.dbc, self.layout, self.lang = spells, spell_dbc, layout, lang
        self.fields = EFFECTS[kind]
        table = Dbc(client.read("DBFilesClient\\SpellDuration.dbc"))
        self.durations = {r[0]: signed(r[1]) for r in table.rows()}

    def duration(self, row):
        ms = self.durations.get(row[self.fields["duration"]], 0)
        return ms if ms > 0 else None

    def effect(self, row, index):
        base = signed(row[self.fields["base"] + index])
        die = signed(row[self.fields["die"] + index])
        return abs(base + 1), abs(base + die) if die > 1 else None

    def value(self, row, kind, index):
        """One token's number, or None when it depends on the player."""
        low, high = self.effect(row, index)
        if kind == "m":
            return low
        if kind == "s":
            return (low, high) if high else low
        if kind == "h":
            return row[self.fields["chance"]]
        if kind == "n":
            return row[self.fields["charges"]]
        if kind == "x":
            return row[self.fields["chain"] + index]
        if kind == "t":
            return row[self.fields["amplitude"] + index] / 1000
        if kind == "o":
            ms, amp = self.duration(row), row[self.fields["amplitude"] + index]
            return low * (ms // amp) if ms and amp else None
        if kind == "d":
            return self.duration(row)
        return None

    def render_token(self, row, token):
        match = re.fullmatch(r"\$(?:([/*])(-?\d+);)?(\d*)([A-Za-z])([123]?)", token)
        if not match:
            return None
        op, by, spell, kind, index = match.groups()
        source = self.spells.get(int(spell)) if spell else row
        if source is None:
            return None
        kind, index = kind.lower(), int(index or 1) - 1
        if kind == "u":
            return str(STACKS.get(source[0], 5))
        number = self.value(source, kind, index)
        if number is None:
            return None
        if kind == "d":
            sec = number / 1000
            words = ("sec", "min") if self.lang == "en" else ("Sek.", "Min.")
            return f"{fmt(sec / 60)} {words[1]}" if sec >= 60 else f"{fmt(sec)} {words[0]}"
        if isinstance(number, tuple):
            word = "to" if self.lang == "en" else "bis"
            return f"{number[0]} {word} {number[1]}"
        if op == "/":
            number = abs(number / int(by))
        elif op == "*":
            number = abs(number * int(by))
        text = fmt(number)
        return text.replace(".", ",") if self.lang == "de" else text

    def render(self, row):
        raw = localized(self.dbc, row, self.layout["spell_desc"])
        raw = raw.replace("\r\n", "\n").replace("\r", "\n").strip()

        def plural(match):
            return match.group(2)

        failed = []

        def replace(match):
            token = match.group(0)
            if token.startswith("$l"):
                return token[2:].split(":")[-1].rstrip(";")
            value = self.render_token(row, token)
            if value is None:
                failed.append(token)
                return token
            return value

        rendered = TOKEN.sub(replace, raw)
        return None if failed else rendered


def rebuild(raw_template, text, normalize, lang):
    """The client's wording with the app's values, or None if they don't line up."""
    template = normalize(raw_template)
    pattern, _ = template_pattern(template)
    match = pattern.match(normalize(text))
    if not match:
        return None
    values = iter(match.groups())

    def value(token):
        captured = re.sub(r",(?=[^\s\d])", ", ", next(values)).strip()
        # The German normalizer drops the period that "$d" renders with.
        following = token.string[token.end() : token.end() + 1]
        if lang == "de" and following != "." and re.fullmatch(r"\$\d*d\d?", token.group(0)):
            captured = re.sub(r"\bSek$", "Sek.", captured)
        return captured

    rendered = TOKEN.sub(value, raw_template.replace("\r\n", "\n").replace("\r", "\n"))
    return rendered.strip()


def load_client(kind, en_dir, lang, lang_dir):
    layout = LAYOUTS[kind]
    en = Client(en_dir, "enGB" if kind == "wotlk" else None)
    source = en if lang == "en" else Client(lang_dir, "deDE")
    tab_dbc = Dbc(en.read("DBFilesClient\\TalentTab.dbc"))
    tabs = {
        r[0]: (r[layout["tab_class"]], tab_dbc.string(r[layout["tab_name"]]))
        for r in tab_dbc.rows()
    }
    spell_dbc = Dbc(source.read("DBFilesClient\\Spell.dbc"))
    spells = {r[0]: r for r in spell_dbc.rows()}
    bits = {bit: code for code, bit in CLASS_BITS.items()}
    talents = {}
    for r in Dbc(en.read("DBFilesClient\\Talent.dbc")).rows():
        mask, tree = tabs[r[1]]
        talents[(bits.get(mask), tree, r[2], r[3])] = [s for s in r[4:13] if s]
    return talents, spells, spell_dbc, layout, Renderer(kind, source, spells, spell_dbc, layout, lang)


def split_statements(sql):
    """Split SQL into statements, respecting quoted strings."""
    out, start, quoted = [], 0, False
    for i, ch in enumerate(sql):
        if ch == "'":
            quoted = not quoted
        elif ch == ";" and not quoted:
            out.append(sql[start : i + 1])
            start = i + 1
    return out, sql[start:]


def main():
    args = [a for a in sys.argv[1:] if a != "--write"]
    write = "--write" in sys.argv
    sql_path, vanilla_dir, tbc_dir, tbc_de_dir, wotlk_dir = args
    with open(sql_path, encoding="utf-8", newline="") as f:
        sql = f.read()

    db = sqlite3.connect(":memory:")
    db.executescript(sql)
    trees = {
        (c, t): n
        for c, t, n in db.execute(
            "SELECT classId, talentTreeId, name FROM talent_tree_names WHERE languageCode = 'en'"
        )
    }
    classes = {i: c.lower() for i, c in db.execute("SELECT id, code FROM classes")}
    talents = {
        row[0]: row[1:]
        for row in db.execute('SELECT id, classId, talentTreeId, "row", "column", expansion FROM talents')
    }
    kinds = {1: "vanilla", 2: "tbc", 3: "wotlk"}
    sources = {
        ("vanilla", "en"): (vanilla_dir, None),
        ("tbc", "en"): (tbc_dir, None),
        ("tbc", "de"): (tbc_dir, tbc_de_dir),
        ("wotlk", "en"): (wotlk_dir, None),
        ("wotlk", "de"): (wotlk_dir, wotlk_dir),
    }
    loaded = {
        key: load_client(key[0], en_dir, key[1], lang_dir)
        for key, (en_dir, lang_dir) in sources.items()
    }

    counts = Counter()
    review = []
    rows = db.execute(
        'SELECT talentId, "rank", languageCode, description FROM rank_descriptions'
    ).fetchall()
    # English first: German is checked against the verified English numbers.
    rows.sort(key=lambda r: r[2] != "en")
    english = {}
    updated = []
    for talent_id, rank, lang, text in rows:
        class_id, tree, row, column, expansion = talents[talent_id]
        if expansion not in kinds:  # Only the Original edition has these clients.
            continue
        kind = kinds[expansion]
        fixed = cleanup(text, lang)
        new = None
        key = (classes[class_id], trees[(class_id, tree)], row, column)
        if (kind, lang) in loaded:
            client_talents, spells, spell_dbc, layout, renderer = loaded[(kind, lang)]
            ranks = client_talents.get(key, [])
            if rank < len(ranks) and ranks[rank] in spells:
                raw = localized(spell_dbc, spells[ranks[rank]], layout["spell_desc"])
                normalize = relaxed if lang == "en" else relaxed_de
                new = rebuild(raw, fixed, normalize, lang)
                if new and sorted(NUMBER.findall(new)) != sorted(NUMBER.findall(fixed)):
                    counts[f"{kind}_{lang}_rejected"] += 1
                    new = None
                if new is None:
                    rendered = renderer.render(spells[ranks[rank]])
                    # Accept calculated text only if it shows the same numbers.
                    numbers = sorted(NUMBER.findall(rendered or ""))
                    same_as_app = numbers == sorted(NUMBER.findall(fixed))
                    same_as_english = lang == "de" and [n.replace(",", ".") for n in numbers] == sorted(
                        n.replace(",", ".") for n in NUMBER.findall(english.get((talent_id, rank), ""))
                    )
                    trusted = (kind, lang, key) in TRUST_CLIENT
                    if rendered and (same_as_app or same_as_english or trusted):
                        new = rendered
                        counts[f"{kind}_{lang}_rendered"] += 1
                    elif rendered:
                        print(f"NUMBERS {kind} {lang} {key} rank {rank + 1}\n  app:    {fixed}\n  client: {rendered}")
        if new is None:
            counts[f"{kind}_{lang}_cleanup_only"] += 1
            if (kind, lang) in loaded:
                review.append((kind, lang, key, rank, fixed))
            result = fixed
        elif MARKUP.search(new):
            counts[f"{kind}_{lang}_rejected"] += 1
            review.append((kind, lang, key, rank, f"{fixed}\n    rejected: {new}"))
            result = fixed
        else:
            counts[f"{kind}_{lang}_rebuilt"] += 1
            result = new
        result = tidy(result, lang)
        if result != text:
            counts["changed"] += 1
        if lang == "en":
            english[(talent_id, rank)] = result
        updated.append((talent_id, rank, lang, result))

    print(dict(sorted(counts.items())))
    for kind, lang, key, rank, text in review:
        print(f"REVIEW {kind} {lang} {key} rank {rank + 1}: {text}")

    if not write:
        return

    statements, tail = split_statements(sql)
    head = 'INSERT INTO "rank_descriptions" ("talentId","rank","languageCode","description") VALUES\r\n'
    values = ",\r\n".join(
        "({}, {}, {}, {})".format(
            t, r, db.execute("SELECT quote(?)", (lang,)).fetchone()[0],
            db.execute("SELECT quote(?)", (d,)).fetchone()[0],
        )
        for t, r, lang, d in updated
    )
    replaced = False
    output = []
    for statement in statements:
        if statement.lstrip().startswith('INSERT INTO "rank_descriptions"'):
            if not replaced:
                output.append("\r\n" + head + values + ";")
                replaced = True
            continue
        output.append(statement)
    with open(sql_path, "w", encoding="utf-8", newline="") as f:
        f.write("".join(output) + tail)


if __name__ == "__main__":
    main()
