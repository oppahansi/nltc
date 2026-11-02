"""Write the Forever rows into ltc_data.db.sql, from extract_forever.py's output.

Usage: python3 -I generate_sql.py <ltc_data.db> <ltc_data.db.sql> <extract_en.json> <extract_de.json>

A talent's id is its client node id, which stays the same across patches, so
saved builds keep working when the data is regenerated. Legacy perks are stored
as talents of a pseudo class, laid out as in the game: they read left to right,
gated at 5 points per column. Reruns replace the block between the markers, and
anything unexpected stops generation.
"""

import os
import re
import sqlite3
import json
import sys

BEGIN, END = "-- BEGIN GENERATED FOREVER DATA", "-- END GENERATED FOREVER DATA"
EXPANSION = 7
LEGACY_CLASS = 10
FIRST_LEGACY_TREE = 3
LEGACY_BACKGROUND = "forever_legacy"
TALENT_POINTS, LEGACY_POINTS = 51, 16  # Also in lib/core/game/game_catalog.dart.
# Values that need a character's stats, or that this client can't provide.
FORMULAS = {
    "en": [
        ("[[?$c]] Mana", "55% of your Mana"),
        ("[[?${$s1+($rap*($s4/100))}]]", "(based on Ranged Attack Power)"),
        ("[[?$19718d]]", "6 sec"),
        ("[[?${$s1+($SPFR*0.1)*($11189s3/100+1)}]]", "(based on Spell Power)"),
        ("[[?${($m1+($bh*$bc))*$<mult>}]]", "(based on Bonus Healing)"),
        ("[[?$<minDam>]] to [[?$<maxDam>]]", "(based on Spell Power)"),
    ],
    "de": [
        ("[[?$c]] Mana", "55% Eures Manas"),
        ("[[?${$s1+($rap*($s4/100))}]]", "(basierend auf Distanzangriffskraft)"),
        ("[[?$19718d]]", "6 Sek."),
        ("[[?${$s1+($SPFR*0.1)*($11189s3/100+1)}]]", "(basierend auf Zaubermacht)"),
        ("[[?${($m1+($bh*$bc))*$<mult>}]]", "(basierend auf Heilungsbonus)"),
        ("[[?$<minDam>]] bis [[?$<maxDam>]]", "(basierend auf Zaubermacht)"),
    ],
}


def q(text):
    return "'" + text.replace("'", "''") + "'"


def render(rank, lang):
    text = rank["description"].replace("\r\n", "\n").replace("\r", "\n").strip()
    for token, word in FORMULAS[lang]:
        text = text.replace(token, word)
    if "$" in text or "[[" in text:
        raise SystemExit(f"unresolved token: {text}")
    return text


def talent_rows(class_id, tree_id, row, column, en, de, repo):
    icon = en["icon"]
    if not os.path.exists(os.path.join(repo, "assets/images/icons", f"{icon}.webp")):
        raise SystemExit(f"missing icon asset: {icon}. Run fetch_icons.py")
    tid = en["node_id"]
    prereqs = en["prerequisites"]
    if len(prereqs) > 1:
        raise SystemExit(f"{en['name']} has {len(prereqs)} prerequisites")
    dep = prereqs[0]["node"] if prereqs else None
    out = [
        'INSERT INTO talents ("classId","talentTreeId","id","row","column","icon","dependencyId","expansion") VALUES '
        f"({class_id}, {tree_id}, {tid}, {row}, {column}, {q(icon)}, {'NULL' if dep is None else dep}, {EXPANSION});"
    ]
    if dep is not None:
        out.append(f"INSERT INTO dependencies (talentId, dependencyId) VALUES ({tid}, {dep});")
    for lang, source in (("en", en), ("de", de)):
        out.append(f"INSERT INTO talent_names (talentId, languageCode, name) VALUES ({tid}, {q(lang)}, {q(source['name'])});")
    for index, _ in enumerate(en["ranks"]):
        out.append(f"INSERT INTO ranks (talentId, rank) VALUES ({tid}, {index});")
        for lang, source in (("en", en), ("de", de)):
            text = render(source["ranks"][index], lang)
            out.append(
                f"INSERT INTO rank_descriptions (talentId, rank, languageCode, description) VALUES ({tid}, {index}, {q(lang)}, {q(text)});"
            )
    return out


def generate(db, repo, en, de):
    if en["talent_points"]["cap"] != TALENT_POINTS:
        raise SystemExit(f"talent point cap is now {en['talent_points']['cap']}")
    if en["legacy"]["currency"]["cap"] != LEGACY_POINTS:
        raise SystemExit(f"Legacy point cap is now {en['legacy']['currency']['cap']}")

    out = [
        f"INSERT INTO expansions (id, code, edition, era) VALUES ({EXPANSION}, 'forever', 'forever', NULL);",
        f"INSERT INTO expansion_names (expansionId, languageCode, name) VALUES ({EXPANSION}, 'en', 'Forever');",
        f"INSERT INTO expansion_names (expansionId, languageCode, name) VALUES ({EXPANSION}, 'de', 'Forever');",
    ]
    classes = {name: cid for cid, name in db.execute("SELECT id, code FROM classes")}
    app_trees = {(c, t): (icon, name) for c, t, icon, name in db.execute(
        "SELECT t.classId, t.id, t.icon, n.name FROM talent_trees t JOIN talent_tree_names n "
        "ON n.classId = t.classId AND n.talentTreeId = t.id AND n.languageCode = 'en'"
    )}
    for code, cdata in en["classes"].items():
        cid = classes[code]
        de_trees = {t["talent_tab_id"]: t for t in de["classes"][code]["trees"]}
        for tree in cdata["trees"]:
            tree_id = tree["position"]
            app_icon, app_name = app_trees[(cid, tree_id)]
            if tree["name"] != app_name:
                raise SystemExit(f"{code} tree {tree_id} is {tree['name']}, the app has {app_name}")
            if tree["icon"] != app_icon:
                out.append(
                    "INSERT INTO talent_tree_icons (expansionId, classId, talentTreeId, icon) VALUES "
                    f"({EXPANSION}, {cid}, {tree_id}, {q(tree['icon'])});"
                )
            de_talents = {t["node_id"]: t for t in de_trees[tree["talent_tab_id"]]["talents"]}
            for talent in tree["talents"]:
                if talent["required_points_in_tree"] != talent["row"] * 5:
                    raise SystemExit(f"{talent['name']} doesn't follow the row rule")
                out += talent_rows(cid, tree_id, talent["row"], talent["column"], talent, de_talents[talent["node_id"]], repo)

    de_trees = {t["tree_id"]: t for t in de["legacy"]["trees"]}
    for tree in en["legacy"]["trees"]:
        tree_id = FIRST_LEGACY_TREE + tree["order"]
        slug = tree["name"].lower()
        out.append(
            'INSERT INTO talent_trees ("classId","id","icon","background") VALUES '
            f"({LEGACY_CLASS}, {tree_id}, {q('legacy_' + slug)}, {q(LEGACY_BACKGROUND)});"
        )
        out.append(
            'INSERT INTO talent_tree_names ("classId","talentTreeId","languageCode","name") VALUES '
            f"({LEGACY_CLASS}, {tree_id}, 'en', {q(tree['name'])});"
        )
        out.append(
            'INSERT INTO talent_tree_names ("classId","talentTreeId","languageCode","name") VALUES '
            f"({LEGACY_CLASS}, {tree_id}, 'de', {q(de_trees[tree['tree_id']]['name'])});"
        )
        de_nodes = {n["node_id"]: n for n in de_trees[tree["tree_id"]]["nodes"]}
        real = [n for n in tree["nodes"] if not n["placeholder"]]
        real_ids = {n["node_id"] for n in real}
        for node in real:
            row, column = node["grid"]["row"], node["grid"]["column"]
            if node["required_points_in_tree"] != column * 5:
                raise SystemExit(f"{node['name']} doesn't follow the column rule")
            if any(p["node"] not in real_ids for p in node["prerequisites"]):
                raise SystemExit(f"{node['name']} requires a placeholder")
            if any(c["amount"] != 1 for c in node["cost_per_rank"]) or node["is_choice"]:
                raise SystemExit(f"{node['name']} is no longer a plain perk")
            out += talent_rows(LEGACY_CLASS, tree_id, row, column, node, de_nodes[node["node_id"]], repo)
    return out


def main():
    db_path, sql_path, en_path, de_path = sys.argv[1:]
    repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(sql_path))))
    en, de = (json.load(open(p, encoding="utf-8")) for p in (en_path, de_path))
    out = [BEGIN, f"-- {en['source']['product']} {en['source']['build']}"]
    out += generate(sqlite3.connect(db_path), repo, en, de)
    out.append(END)
    text = open(sql_path, encoding="utf-8").read()
    text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "", text, flags=re.S)
    if not text.rstrip().endswith("COMMIT;"):
        raise SystemExit("expected the SQL file to end with COMMIT;")
    head = text.rstrip()[: -len("COMMIT;")]
    open(sql_path, "w", encoding="utf-8").write(head + "\n".join(out) + "\nCOMMIT;\n")
    print(f"{len(out)} lines written")


if __name__ == "__main__":
    main()
