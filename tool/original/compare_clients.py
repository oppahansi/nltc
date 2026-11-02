"""Find data differences between two clients of the same game version.

Usage: python3 -I compare_clients.py <vanilla|tbc> <reference Data dir> <other Data dir>

Compares every Talent, TalentTab and Spell row, ignoring localized text, so a
translated client only differs here if its game data was changed.
"""

import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import Client, Dbc  # noqa: E402

# Field ranges holding string offsets, which differ between any two builds of a table.
TEXT_FIELDS = {
    "vanilla": {
        "Talent": [],
        "TalentTab": [(1, 10), (14, 15)],
        "Spell": [(120, 156)],
    },
    "tbc": {
        "Talent": [],
        "TalentTab": [(1, 18), (22, 23)],
        "Spell": [(127, 195)],
    },
}


def numeric(row, ranges):
    return tuple(
        value
        for index, value in enumerate(row)
        if not any(start <= index < end for start, end in ranges)
    )


def main():
    kind, reference_dir, other_dir = sys.argv[1:4]
    reference, other = Client(reference_dir), Client(other_dir)
    print("reference archives:", [os.path.basename(a.path) for a in reference.archives])
    print("other archives:    ", [os.path.basename(a.path) for a in other.archives])

    talent_spells = set()
    for name, ranges in TEXT_FIELDS[kind].items():
        path = f"DBFilesClient\\{name}.dbc"
        a, b = Dbc(reference.read(path)), Dbc(other.read(path))
        print(
            f"\n{name}: reference {a.count} rows ({os.path.basename(reference.provider(path).path)}), "
            f"other {b.count} rows ({os.path.basename(other.provider(path).path)})"
        )
        rows_a, rows_b = {r[0]: r for r in a.rows()}, {r[0]: r for r in b.rows()}
        if name == "Talent":
            talent_spells = {s for r in rows_a.values() for s in r[4:13] if s}
            talent_spells |= {s for r in rows_b.values() for s in r[4:13] if s}
        only_a, only_b = set(rows_a) - set(rows_b), set(rows_b) - set(rows_a)
        print(f"  ids only in reference: {len(only_a)} {sorted(only_a)[:10]}")
        print(f"  ids only in other:     {len(only_b)} {sorted(only_b)[:10]}")
        if a.fields != b.fields:
            print(f"  different field counts: {a.fields} vs {b.fields}")
            continue
        changed = [
            i for i in rows_a.keys() & rows_b.keys()
            if numeric(rows_a[i], ranges) != numeric(rows_b[i], ranges)
        ]
        print(f"  rows with changed data: {len(changed)}")
        if name == "Spell":
            talent_changed = sorted(set(changed) & talent_spells)
            print(f"  of which talent rank spells: {len(talent_changed)} {talent_changed[:20]}")
        columns = Counter()
        for i in changed:
            na, nb = numeric(rows_a[i], ranges), numeric(rows_b[i], ranges)
            columns.update(c for c, (x, y) in enumerate(zip(na, nb)) if x != y)
        if columns:
            print(f"  most changed non-text columns: {columns.most_common(8)}")


if __name__ == "__main__":
    main()
