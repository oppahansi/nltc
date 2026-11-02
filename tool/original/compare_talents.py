"""Compare the app's bundled talents with an original client's DBC files.

Usage: python3 -I compare_talents.py <vanilla|tbc|wotlk> <client Data dir> <ltc_data.db>

Reads the client and the database only. Prints one line per difference.
"""

import json
import os
import sqlite3
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import Client, Dbc  # noqa: E402

# Field indexes. Localized strings occupy a whole array, so the next string
# starts one array length later.
LAYOUTS = {
    "vanilla": dict(
        expansion=1,
        tab_name=1,
        tab_class=12,
        talent_extra=0,
        spell_name=120,
        spell_desc=138,
    ),
    "tbc": dict(
        expansion=2,
        tab_name=1,
        tab_class=20,
        talent_extra=0,
        spell_name=127,
        spell_desc=161,
    ),
    "wotlk": dict(
        expansion=3,
        tab_name=1,
        tab_class=20,
        talent_extra=0,
        spell_name=136,
        spell_desc=170,
    ),
}

CLASS_BITS = {
    "warrior": 1,
    "paladin": 2,
    "hunter": 4,
    "rogue": 8,
    "priest": 16,
    "deathknight": 32,
    "shaman": 64,
    "mage": 128,
    "warlock": 256,
    "druid": 1024,
}


def load_client(kind, data_dir):
    layout = LAYOUTS[kind]
    client = Client(data_dir, "enGB" if kind == "wotlk" else None)
    sources = {
        name: os.path.basename(client.provider(f"DBFilesClient\\{name}.dbc").path)
        for name in ("Talent", "TalentTab", "Spell")
    }

    tabs = {}
    tab_dbc = Dbc(client.read("DBFilesClient\\TalentTab.dbc"))
    for row in tab_dbc.rows():
        tabs[row[0]] = (row[layout["tab_class"]], tab_dbc.string(row[layout["tab_name"]]))

    spell_dbc = Dbc(client.read("DBFilesClient\\Spell.dbc"))
    spells = {
        row[0]: (
            spell_dbc.string(row[layout["spell_name"]]),
            spell_dbc.string(row[layout["spell_desc"]]),
        )
        for row in spell_dbc.rows()
    }

    talents = {}
    for row in Dbc(client.read("DBFilesClient\\Talent.dbc")).rows():
        if not tabs[row[1]][0]:  # Pet talent trees have no class, and the app omits them.
            continue
        ranks = [spell for spell in row[4:13] if spell]
        talents[row[0]] = dict(
            id=row[0],
            tab=row[1],
            row=row[2],
            column=row[3],
            ranks=ranks,
            prereqs=[(row[13 + i], row[16 + i]) for i in range(3) if row[13 + i]],
            name=spells.get(ranks[0], ("?", ""))[0] if ranks else "?",
        )
    return tabs, talents, spells, sources


def load_app(kind, db_path):
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    expansion = LAYOUTS[kind]["expansion"]
    trees = {
        (class_id, tree_id): name
        for class_id, tree_id, name in db.execute(
            "SELECT classId, talentTreeId, name FROM talent_tree_names WHERE languageCode = 'en'"
        )
    }
    classes = dict(db.execute("SELECT id, code FROM classes"))
    talents = {}
    query = """
        SELECT t.id, t.classId, t.talentTreeId, t.row, t.column, t.dependencyId, n.name,
               (SELECT COUNT(*) FROM ranks r WHERE r.talentId = t.id)
        FROM talents t JOIN talent_names n ON n.talentId = t.id AND n.languageCode = 'en'
        WHERE t.expansion = ?
    """
    for tid, cid, tree, row, col, dep, name, ranks in db.execute(query, (expansion,)):
        talents[tid] = dict(
            id=tid,
            cls=classes[cid].lower(),
            tree=trees[(cid, tree)],
            row=row,
            column=col,
            dep=dep,
            name=name,
            ranks=ranks,
        )
    return talents


def main():
    kind, data_dir, db_path = sys.argv[1:4]
    tabs, client, _, sources = load_client(kind, data_dir)
    app = load_app(kind, db_path)
    print(f"sources: {sources}")
    print(f"client talents: {len(client)}, app talents: {len(app)}")

    bit_class = {bit: code for code, bit in CLASS_BITS.items()}
    for talent in client.values():
        mask, tree = tabs[talent["tab"]]
        talent["cls"], talent["tree"] = bit_class.get(mask, f"mask{mask}"), tree

    key = lambda t: (t["cls"], t["tree"], t["row"], t["column"])  # noqa: E731
    client_at = {key(t): t for t in client.values()}
    app_at = {key(t): t for t in app.values()}

    diffs = Counter()
    report = []

    def note(category, text):
        diffs[category] += 1
        report.append(f"{category}: {text}")

    for k in sorted(set(client_at) - set(app_at)):
        t = client_at[k]
        note("client_only", f"{k} {t['name']} ({len(t['ranks'])} ranks)")
    for k in sorted(set(app_at) - set(client_at)):
        t = app_at[k]
        note("app_only", f"{k} {t['name']} ({t['ranks']} ranks)")

    for k in sorted(set(client_at) & set(app_at)):
        c, a = client_at[k], app_at[k]
        if c["name"] != a["name"]:
            note("name", f"{k} client={c['name']!r} app={a['name']!r}")
        if len(c["ranks"]) != a["ranks"]:
            note("ranks", f"{k} {c['name']} client={len(c['ranks'])} app={a['ranks']}")
        if len(c["prereqs"]) > 1:
            note("multi_prereq", f"{k} {c['name']} {c['prereqs']}")
        if c["prereqs"] and c["prereqs"][0][0] not in client:
            note("prereq_unknown", f"{k} {c['name']} -> Talent.dbc id {c['prereqs'][0][0]}")
            continue
        client_dep = client[c["prereqs"][0][0]] if c["prereqs"] else None
        app_dep = app.get(a["dep"]) if a["dep"] is not None else None
        c_pos = (client_dep["row"], client_dep["column"]) if client_dep else None
        a_pos = (app_dep["row"], app_dep["column"]) if app_dep else None
        if c_pos != a_pos:
            note(
                "prereq",
                f"{k} {c['name']} client={client_dep and client_dep['name']}{c_pos} "
                f"app={app_dep and app_dep['name']}{a_pos}",
            )
        if client_dep:
            needed = c["prereqs"][0][1] + 1
            if needed != len(client_dep["ranks"]):
                note(
                    "partial_prereq",
                    f"{k} {c['name']} needs {needed}/{len(client_dep['ranks'])} "
                    f"of {client_dep['name']}",
                )

    print(f"matched positions: {len(set(client_at) & set(app_at))}")
    print(f"differences: {json.dumps(diffs, sort_keys=True)}")
    print("\n".join(report))


if __name__ == "__main__":
    main()
