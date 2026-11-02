"""Compare the app's English rank descriptions with an original client's spells.

Usage: python3 -I compare_ranks.py <vanilla|tbc|wotlk> <client Data dir> <ltc_data.db>

Client descriptions are templates such as "Increases damage by $s1%.". Each
template becomes a pattern, so literal text must match exactly. Tokens simple
enough to calculate ($s, $m, $h, $n, $x) are then compared by value.
"""

import os
import re
import sqlite3
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare_talents import LAYOUTS, CLASS_BITS, load_app  # noqa: E402
from mpq import Client, Dbc  # noqa: E402

EFFECTS = {
    "vanilla": dict(die=64, base=76, chance=25, charges=26, chain=100),
    "tbc": dict(die=68, base=80, chance=29, charges=30, chain=104),
    "wotlk": dict(die=74, base=80, chance=35, charges=36, chain=104),
}

TOKEN = re.compile(
    r"""\$(?:
        \{[^}]*\}(?:\.\d)?            # ${expression}, optional decimals
      | l[^:;]*:[^;]*;                # $lsingular:plural;
      | \?[^\[]*\[[^\]]*\]\[[^\]]*\]  # $?condition[a][b]
      | /-?\d+;\d*[A-Za-z]\d?         # $/1000;s1
      | \d*[A-Za-z]\d?                # $s1, $12345s1, $d, $h
    )""",
    re.VERBOSE,
)


def signed(value):
    return value - (1 << 32) if value >= 1 << 31 else value


def simple_value(token, row, fields):
    """The expected text for a token, or None when it isn't simple to calculate."""
    match = re.fullmatch(r"\$([smhnxSMHNX])([123]?)", token)
    if not match:
        return None
    kind, index = match.group(1).lower(), int(match.group(2) or 1) - 1
    if kind == "h":
        return str(row[fields["chance"]])
    if kind == "n":
        return str(row[fields["charges"]])
    if kind == "x":
        return str(row[fields["chain"] + index])
    base = signed(row[fields["base"] + index])
    die = signed(row[fields["die"] + index])
    low = abs(base + 1) if die <= 1 else abs(base + 1)
    if kind == "s" and die > 1:
        return f"{low} to {abs(base + die)}"
    return str(low)


def template_pattern(template):
    parts, tokens, last = [], [], 0
    for match in TOKEN.finditer(template):
        parts.append(re.escape(template[last : match.start()]))
        parts.append("(.*?)")
        tokens.append(match.group(0))
        last = match.end()
    parts.append(re.escape(template[last:]))
    return re.compile("".join(parts) + r"\Z", re.DOTALL), tokens


def clean(text):
    return re.sub(r"\s+", " ", text).strip()


def relaxed(text):
    """Ignore known wording noise, to surface differences that really matter."""
    text = re.sub(r",\s*", ",", clean(text))
    text = re.sub(r"\b(seconds?)\b", "sec", text)
    text = re.sub(r"\b(minutes?)\b", "min", text)
    return re.sub(r"\bsecs?\b", "sec", text)


def main():
    kind, data_dir, db_path = sys.argv[1:4]
    layout, fields = LAYOUTS[kind], EFFECTS[kind]
    client = Client(data_dir)

    tab_dbc = Dbc(client.read("DBFilesClient\\TalentTab.dbc"))
    tabs = {
        r[0]: (r[layout["tab_class"]], tab_dbc.string(r[layout["tab_name"]]))
        for r in tab_dbc.rows()
    }
    spell_dbc = Dbc(client.read("DBFilesClient\\Spell.dbc"))
    spells = {r[0]: r for r in spell_dbc.rows()}

    bits = {bit: code for code, bit in CLASS_BITS.items()}
    client_at = {}
    for r in Dbc(client.read("DBFilesClient\\Talent.dbc")).rows():
        mask, tree = tabs[r[1]]
        client_at[(bits.get(mask), tree, r[2], r[3])] = [s for s in r[4:13] if s]

    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    counts = Counter()
    report = []
    for talent in load_app(kind, db_path).values():
        key = (talent["cls"], talent["tree"], talent["row"], talent["column"])
        ranks = client_at.get(key)
        if ranks is None:
            counts["no_client_talent"] += 1
            continue
        rows = db.execute(
            "SELECT rank, description FROM rank_descriptions "
            "WHERE talentId = ? AND languageCode = 'en' ORDER BY rank",
            (talent["id"],),
        ).fetchall()
        for rank, text in rows:
            counts["ranks"] += 1
            where = f"{key} {talent['name']} rank {rank + 1}"
            if rank >= len(ranks) or ranks[rank] not in spells:
                counts["no_spell"] += 1
                report.append(f"no_spell: {where}")
                continue
            row = spells[ranks[rank]]
            template = relaxed(spell_dbc.string(row[layout["spell_desc"]]))
            pattern, tokens = template_pattern(template)
            match = pattern.match(relaxed(text))
            if not match:
                counts["text"] += 1
                report.append(f"text: {where}\n  client: {template}\n  app:    {relaxed(text)}")
                continue
            counts["text_ok"] += 1
            for token, actual in zip(tokens, match.groups()):
                expected = simple_value(token, row, fields)
                if expected is None:
                    counts["tokens_not_calculated"] += 1
                elif expected == actual:
                    counts["values_ok"] += 1
                else:
                    counts["value"] += 1
                    report.append(
                        f"value: {where} {token} client={expected!r} app={actual!r}\n"
                        f"  client: {template}\n  app:    {relaxed(text)}"
                    )

    print(dict(sorted(counts.items())))
    print("\n".join(report))


if __name__ == "__main__":
    main()
