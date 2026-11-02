"""Write the Classic rows into ltc_data.db.sql, from extract_classic.py's output.

Usage: python3 -I generate_sql.py <ltc_data.db> <ltc_data.db.sql> <vanilla_en> <vanilla_de> <tbc_en> <tbc_de> <wotlk_en> <wotlk_de>

A Classic talent's id is its Original counterpart's id plus a fixed offset, so
ids don't depend on generation order and saved builds keep working. A talent
without a counterpart stops generation, since it needs an id decided by hand.
Reruns replace the block between the markers.
"""

import json
import os
import re
import sqlite3
import sys

BEGIN, END = "-- BEGIN GENERATED CLASSIC DATA", "-- END GENERATED CLASSIC DATA"
LEVELS = {"vanilla": 60, "tbc": 70, "wotlk": 80}
# expansion row, Original row, id offset, era, names.
ROWS = [
    (4, 1, 10000, "vanilla", "classic_vanilla", {"en": "Vanilla", "de": "Vanilla"}),
    (5, 2, 20000, "tbc", "classic_tbc", {"en": "The Burning Crusade", "de": "Der brennende Kreuzzug"}),
    (6, 3, 30000, "wotlk", "classic_wotlk", {"en": "Wrath of the Lich King", "de": "Zorn des Lichkönigs"}),
]
SEAL_MIN, SEAL_MAX = "[[?${0.19*$mw+0.08*$AP+0.13*$SPH}]]", "[[?${0.19*$MW+0.08*$AP+0.13*$SPH}]]"
# Formulas that need a character's stats, written the way the app writes them.
# Their spell values were compared with the 3.4.5 tables.
FORMULAS = {
    "en": [
        ("[[?${$51052m1+2*$AP}]]", "(10000 + 2*Attack Power)"),
        ("[[?${$AP*0.2+$m1}]]", "(0.2*Attack Power + 48)"),
        ("[[?${$RAP*0.1+$m1*5}]]", "(0.1*Ranged Attack Power + 785)"),
        ("[[?${$RAP*0.14+$m1}]]-[[?${$RAP*0.14+$M1}]]", "(0.14*Ranged Attack Power + 144 to 172)"),
        (
            "[[?${$m1+0.07*$SPH+0.07*$AP}]] to [[?${$M1+0.07*$SPH+0.07*$AP}]]",
            "(440 to 536) + 7% of Spell power + 7% of Attack power",
        ),
        ("[[?${0.36*$mw}]] to [[?${0.36*$MW}]]", "36% of Mainhand weapon damage"),
        (f"{SEAL_MIN} to {SEAL_MAX}", "19% of Mainhand weapon damage + 8% of Attack power + 13% of Spell power"),
        ("[[?$Ghe:she;]]", "they"),
        # The spell lost this effect in 3.4.5. Wowhead lists a 15 sec proc cooldown.
        ("[[?$57470s3]]", "15"),
    ],
    "de": [
        ("[[?${$51052m1+2*$AP}]]", "(10000 + 2*Angriffskraft)"),
        ("[[?${$AP*0.2+$m1}]]", "(0,2*Angriffskraft + 48)"),
        ("[[?${$RAP*0.1+$m1*5}]]", "(0,1*Distanzangriffskraft + 785)"),
        ("[[?${$RAP*0.14+$m1}]] bis [[?${$RAP*0.14+$M1}]]", "(0,14*Distanzangriffskraft + 144 bis 172)"),
        (
            "[[?${$m1+0.07*$SPH+0.07*$AP}]] bis [[?${$M1+0.07*$SPH+0.07*$AP}]]",
            "(440 bis 536) + 7% der Zaubermacht + 7% der Angriffskraft",
        ),
        ("[[?${0.36*$mw}]] bis [[?${0.36*$MW}]]", "36% des Waffenschadens der Waffenhand"),
        (f"{SEAL_MIN} bis {SEAL_MAX}", "19% des Waffenschadens der Waffenhand + 8% der Angriffskraft + 13% der Zaubermacht"),
        ("[[?$57470s3]]", "15"),
    ],
}
ATTACK_POWER_SHARES = ("[[?${$AP*$m1/100}]]", "[[?${$m3/100*$AP}]]")
LANGS = {"en": "enUS", "de": "deDE"}


def q(text):
    return "'" + text.replace("'", "''") + "'"


def load(path):
    return json.load(open(path, encoding="utf-8"))["classes"]


def render(rank, lang, era, original_en):
    """The final text of a rank, resolving what the extract couldn't calculate."""
    text = rank["description"].replace("\r\n", "\n").replace("\r", "\n").strip()
    text = text.replace("[[?$]]", "")
    text = text.replace("[[?$19718d]]", "6 sec" if lang == "en" else "6 Sek.")
    if "[[?$s2]]" in text:
        # The base value is 0 and it grows with level. The game truncates.
        per_level = float(re.search(r"(-?[\d.]+) per level", rank["level_scaled"][0]).group(1))
        text = text.replace("[[?$s2]]", str(int(abs(per_level) * LEVELS[era])))
    for token in ATTACK_POWER_SHARES:
        if token in text:
            share = re.search(r"(\d+)% of Attack [Pp]ower", original_en).group(1)
            word = f"({share}% of Attack Power)" if lang == "en" else f"({share}% der Angriffskraft)"
            text = text.replace(token, word)
    for token, word in FORMULAS[lang]:
        text = text.replace(token, word)
    if text.endswith("eine Chance, 10 Sek.."):
        # Era's German Vindication lost its effect to a Season of Discovery condition.
        share = re.search(r"by (\d+)% for", original_en).group(1)
        text = text.replace(
            "eine Chance, 10 Sek..",
            f"eine Chance, die Stärke und Beweglichkeit des Ziels 10 Sek. lang um {share}% zu verringern.",
        )
    # Era's English Vindication has the same problem.
    text = re.sub(r"(\d+%)10 sec\.", r"\1 for 10 sec.", text)
    text = text.replace("Sek.. ", "Sek. ")
    # 0.50 sec reads as 0.5 sec, and 1.0 sec as 1 sec.
    text = re.sub(r"(\d\.\d*?)0+(?= (?:sec|Sek))", r"\1", text)
    text = re.sub(r"(\d)\.(?= (?:sec|Sek))", r"\1", text)
    if "$" in text or "[[" in text:
        raise SystemExit(f"unresolved token: {text}")
    return text


def generate(db, repo, row, extracts):
    expansion, original, offset, era, code, names = row
    classes = {name: cid for cid, name in db.execute("SELECT id, code FROM classes")}
    known = {}
    for tid, cid, tree, r, col, dep in db.execute(
        'SELECT id, classId, talentTreeId, row, "column", dependencyId FROM talents WHERE expansion = ?', (original,)
    ):
        known[(cid, tree, r, col)] = (tid, dep)
    trees_app = {(c, t): icon for c, t, icon in db.execute("SELECT classId, id, icon FROM talent_trees")}

    out = [f"INSERT INTO expansions (id, code, edition, era) VALUES ({expansion}, {q(code)}, 'classic', {q(era)});"]
    for lang, name in names.items():
        out.append(f"INSERT INTO expansion_names (expansionId, languageCode, name) VALUES ({expansion}, {q(lang)}, {q(name)});")

    by_lang = {lang: extracts[lang] for lang in LANGS}
    new_ids, deps = {}, []
    for cls, cdata in by_lang["en"].items():
        cid = classes[cls]
        for tree in cdata["trees"]:
            icon = tree["icon"]
            if icon != trees_app[(cid, tree["order"])]:
                out.append(
                    "INSERT INTO talent_tree_icons (expansionId, classId, talentTreeId, icon) VALUES "
                    f"({expansion}, {cid}, {tree['order']}, {q(icon)});"
                )
            for talent in tree["talents"]:
                key = (cid, tree["order"], talent["row"], talent["column"])
                if key not in known:
                    raise SystemExit(f"{code}: no Original talent at {key} for {talent['name']}")
                new_ids[talent["talent_id"]] = known[key][0] + offset

    for cls, cdata in by_lang["en"].items():
        cid = classes[cls]
        de_trees = {t["tab_id"]: t for t in by_lang["de"][cls]["trees"]}
        for tree in cdata["trees"]:
            de_talents = {t["talent_id"]: t for t in de_trees[tree["tab_id"]]["talents"]}
            for talent in tree["talents"]:
                key = (cid, tree["order"], talent["row"], talent["column"])
                original_id, original_dep = known[key]
                tid = new_ids[talent["talent_id"]]
                prereqs = talent["prerequisites"]
                # 3.4.5 has prerequisites pointing at talents that no longer exist.
                dep = new_ids.get(_prereq_id(prereqs[0])) if prereqs else None
                expected = None if original_dep is None else original_dep + offset
                if dep != expected:
                    raise SystemExit(f"{code}: {talent['name']} dependency {dep}, Original has {expected}")
                icon = talent["icon"]
                if not os.path.exists(os.path.join(repo, "assets/images/icons", f"{icon}.webp")):
                    raise SystemExit(f"missing icon asset: {icon}")
                dep_sql = "NULL" if dep is None else dep
                out.append(
                    'INSERT INTO talents ("classId","talentTreeId","id","row","column","icon","dependencyId","expansion") VALUES '
                    f"({cid}, {tree['order']}, {tid}, {talent['row']}, {talent['column']}, {q(icon)}, {dep_sql}, {expansion});"
                )
                if dep is not None:
                    deps.append((tid, dep))
                de = de_talents[talent["talent_id"]]
                for lang, source in (("en", talent), ("de", de)):
                    out.append(f"INSERT INTO talent_names (talentId, languageCode, name) VALUES ({tid}, {q(lang)}, {q(source['name'])});")
                originals = dict(db.execute(
                    "SELECT rank, description FROM rank_descriptions WHERE talentId = ? AND languageCode = 'en'", (original_id,)
                ))
                if len(talent["ranks"]) != len(originals):
                    raise SystemExit(f"{code}: {talent['name']} has {len(talent['ranks'])} ranks, Original has {len(originals)}")
                for rank_index, rank in enumerate(talent["ranks"]):
                    out.append(f"INSERT INTO ranks (talentId, rank) VALUES ({tid}, {rank_index});")
                    for lang, source in (("en", talent), ("de", de)):
                        text = render(source["ranks"][rank_index], lang, era, originals[rank_index])
                        out.append(
                            f"INSERT INTO rank_descriptions (talentId, rank, languageCode, description) VALUES ({tid}, {rank_index}, {q(lang)}, {q(text)});"
                        )
    for tid, dep in deps:
        out.append(f"INSERT INTO dependencies (talentId, dependencyId) VALUES ({tid}, {dep});")
    return out


def _prereq_id(prereq):
    return prereq["talent_id"] if isinstance(prereq, dict) else prereq


def main():
    db_path, sql_path, *paths = sys.argv[1:]
    repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(sql_path))))
    db = sqlite3.connect(db_path)
    out = [
        BEGIN,
        "DROP TABLE IF EXISTS talent_tree_icons;",
        "CREATE TABLE talent_tree_icons (\n"
        "      expansionId INTEGER NOT NULL,\n"
        "      classId INTEGER NOT NULL,\n"
        "      talentTreeId INTEGER NOT NULL,\n"
        "      icon TEXT NOT NULL,\n"
        "      PRIMARY KEY(expansionId,classId,talentTreeId)\n"
        "    );",
    ]
    for i, row in enumerate(ROWS):
        out += generate(db, repo, row, {"en": load(paths[i * 2]), "de": load(paths[i * 2 + 1])})
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
