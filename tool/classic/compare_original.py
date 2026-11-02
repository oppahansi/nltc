"""Compare a Classic extract with the matching Legacy expansion in the app's database.

Usage: python3 -I compare_original.py <extract.json> <ltc_data.db> [report.json] [images_dir]

Reads both inputs only. Legacy differing from Classic is expected, so this lists
what differs rather than judging it. Exit status is always 0 unless it can't run.

Rank descriptions fall into one of these, using the app's language for the locale:
  identical       same text once whitespace is collapsed
  format          same after ignoring comma spacing, decimal commas and "sec"/"second" wording
  numbers         only the numbers differ. origin says whether the template's literal
                  text matches Legacy ("token": the value comes from the spell's data)
                  or not ("literal": a number written in the template differs)
  text            the words differ
  uncalculated    matches apart from a [[?token]] the extractor couldn't calculate
"""

import collections
import json
import os
import re
import sqlite3
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "legacy"))
from compare_ranks import clean, relaxed, relaxed_de, template_pattern  # noqa: E402

EXPANSIONS = {"wow_classic_era": 1, "wow_anniversary": 2}
LANGUAGES = {"enUS": "en", "enGB": "en", "deDE": "de"}
MARKER = re.compile(r"\[\[\?.*?\]\]", re.DOTALL)
NUMBER = re.compile(r"\d+(?:[.,]\d+)?")


def load_app(db_path, expansion, language):
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    classes = dict(db.execute("SELECT id, code FROM classes"))
    trees = {}
    for class_id, tree_id, icon, background in db.execute(
        "SELECT classId, id, icon, background FROM talent_trees"
    ):
        trees[(class_id, tree_id)] = dict(
            cls=classes[class_id].lower(), order=tree_id, icon=icon, background=background, name=None
        )
    for class_id, tree_id, name in db.execute(
        "SELECT classId, talentTreeId, name FROM talent_tree_names WHERE languageCode = ?", (language,)
    ):
        trees[(class_id, tree_id)]["name"] = name
    talents = {}
    for tid, class_id, tree_id, row, column, icon, dep, name in db.execute(
        """SELECT t.id, t.classId, t.talentTreeId, t.row, t.column, t.icon, t.dependencyId, n.name
           FROM talents t LEFT JOIN talent_names n ON n.talentId = t.id AND n.languageCode = ?
           WHERE t.expansion = ?""",
        (language, expansion),
    ):
        talents[tid] = dict(
            id=tid, tree=(class_id, tree_id), row=row, column=column, icon=icon, dep=dep, name=name, ranks={}
        )
    for tid, rank, text in db.execute(
        "SELECT talentId, rank, description FROM rank_descriptions WHERE languageCode = ?", (language,)
    ):
        if tid in talents:
            talents[tid]["ranks"][rank] = text
    rank_counts = dict(db.execute("SELECT talentId, COUNT(*) FROM ranks GROUP BY talentId"))
    for tid, talent in talents.items():
        talent["rank_count"] = rank_counts.get(tid, 0)
    used = {t["tree"] for t in talents.values()}
    return {k: v for k, v in trees.items() if k in used}, talents


def relax_de(text):
    return re.sub(r"(\d),(\d)", r"\1.\2", relaxed_de(text))


def mask_numbers(text, language):
    word = "to" if language == "en" else "bis"
    return NUMBER.sub("#", re.sub(rf"\d+(?:[.,]\d+)? {word} \d+(?:[.,]\d+)?", "#", text))


def classify_rank(rank, legacy, language):
    """Returns (category, details) for one rank of a talent found on both sides."""
    relax = relaxed if language == "en" else relax_de
    classic = rank["description"]
    if clean(classic) == clean(legacy):
        return "identical", {}
    if relax(classic) == relax(legacy):
        return "format", {}
    if MARKER.search(classic):
        parts = [re.escape(p) for p in MARKER.split(relax(classic))]
        if re.fullmatch("(.*?)".join(parts), relax(legacy), re.DOTALL):
            return "uncalculated", {}
    if mask_numbers(relax(classic), language) == mask_numbers(relax(legacy), language):
        pattern, _ = template_pattern(relax(rank["template"]))
        origin = "token" if pattern.match(relax(legacy)) else "literal"
        return "numbers", dict(
            origin=origin,
            classic_numbers=NUMBER.findall(relax(classic)),
            legacy_numbers=NUMBER.findall(relax(legacy)),
        )
    # Sorted, because a differently worded sentence can list the same numbers in another order.
    return "text", dict(numbers_differ=sorted(NUMBER.findall(relax(classic))) != sorted(NUMBER.findall(relax(legacy))))


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    extract_path, db_path = sys.argv[1:3]
    report_path = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None
    images = sys.argv[4] if len(sys.argv) > 4 else os.path.join(os.path.dirname(os.path.abspath(db_path)), "..", "images")
    with open(extract_path, encoding="utf-8") as source:
        extract = json.load(source)
    product, locale = extract["source"]["product"], extract["source"]["locale"]
    expansion, language = EXPANSIONS[product], LANGUAGES[locale]
    app_trees, app_talents = load_app(db_path, expansion, language)
    print(f"{product} {extract['source']['build']} {locale} vs Legacy expansion {expansion} ({language})")

    structural = collections.defaultdict(list)

    def note(category, text):
        structural[category].append(text)

    # ---- trees. Same name first, and otherwise the same order, so a renamed tree
    # still has its talents compared.
    matched_trees = {}
    classic_tree_list = []
    for code, cls in extract["classes"].items():
        for tree in cls["trees"]:
            classic_tree_list.append((code, tree))
    remaining = dict(app_trees)
    for code, tree in classic_tree_list:
        key = next((k for k, a in remaining.items() if a["cls"] == code and a["name"] == tree["name"]), None)
        if key is not None:
            matched_trees[(code, tree["tab_id"])] = key
            del remaining[key]
    for code, tree in classic_tree_list:
        if (code, tree["tab_id"]) in matched_trees:
            continue
        key = next((k for k, a in remaining.items() if a["cls"] == code and a["order"] == tree["order"]), None)
        if key is None:
            note("tree_classic_only", f"{code} {tree['name']!r}")
            continue
        matched_trees[(code, tree["tab_id"])] = key
        del remaining[key]
        note("tree_name", f"{code} order {tree['order']}: classic={tree['name']!r} legacy={app_trees[key]['name']!r}")
    for key in remaining:
        note("tree_legacy_only", f"{app_trees[key]['cls']} {app_trees[key]['name']!r}")
    background_pairs = []
    for code, tree in classic_tree_list:
        key = matched_trees.get((code, tree["tab_id"]))
        if key is None:
            continue
        app_tree = app_trees[key]
        where = f"{code}/{tree['name']}"
        if tree["order"] != app_tree["order"]:
            note("tree_order", f"{where}: classic={tree['order']} legacy={app_tree['order']}")
        if (tree["icon"] or "") != app_tree["icon"].lower():
            note("tree_icon", f"{where}: classic={tree['icon']} legacy={app_tree['icon']}")
        squeezed = re.sub(r"[^a-z0-9]", "", tree["background"].lower())
        if squeezed != re.sub(r"[^a-z0-9]", "", app_tree["background"].lower()):
            note("tree_background_name", f"{where}: classic={tree['background']} legacy={app_tree['background']}")
        background_pairs.append((where, tree["background"], app_tree["background"]))

    # ---- talents, keyed by tree and position
    classic_at = {}
    classic_by_id = {}
    for code, tree in classic_tree_list:
        key = matched_trees.get((code, tree["tab_id"]))
        for talent in tree["talents"]:
            classic_by_id[talent["talent_id"]] = talent
            if key is not None:
                classic_at[(key, talent["row"], talent["column"])] = (code, tree, talent)
    app_at = {(t["tree"], t["row"], t["column"]): t for t in app_talents.values()}

    def label(key):
        tree = app_trees[key[0]]
        return f"{tree['cls']}/{tree['name']} r{key[1]} c{key[2]}"

    classic_only = sorted(set(classic_at) - set(app_at), key=str)
    legacy_only = sorted(set(app_at) - set(classic_at), key=str)
    pairs = [(k, k) for k in sorted(set(classic_at) & set(app_at), key=str)]
    for c_key in list(classic_only):  # The same talent at another position in its tree.
        name = classic_at[c_key][2]["name"]
        other = next((k for k in legacy_only if k[0] == c_key[0] and app_at[k]["name"] == name), None)
        if other is not None:
            note("moved", f"{label(c_key)} {name!r}: legacy has it at r{other[1]} c{other[2]}")
            classic_only.remove(c_key)
            legacy_only.remove(other)
            pairs.append((c_key, other))
    for key in classic_only:
        talent = classic_at[key][2]
        note("classic_only", f"{label(key)} {talent['name']!r} ({talent['rank_count']} ranks)")
    for key in legacy_only:
        talent = app_at[key]
        note("legacy_only", f"{label(key)} {talent['name']!r} ({talent['rank_count']} ranks)")

    rank_rows = []
    missing_icons = collections.defaultdict(set)
    for c_key, a_key in pairs:
        code, tree, classic = classic_at[c_key]
        legacy = app_at[a_key]
        where = f"{label(c_key)} {classic['name']!r}"
        if classic["name"] != legacy["name"]:
            note("name", f"{label(c_key)}: classic={classic['name']!r} legacy={legacy['name']!r}")
        if classic["rank_count"] != legacy["rank_count"]:
            note("rank_count", f"{where}: classic={classic['rank_count']} legacy={legacy['rank_count']}")
        if (classic["icon"] or "") != legacy["icon"].lower():
            note("icon", f"{where}: classic={classic['icon']} legacy={legacy['icon']}")
        prerequisites = classic["prerequisites"]
        if len(prerequisites) > 1:
            note("multi_prereq", f"{where}: {prerequisites}")
        first = prerequisites[0] if prerequisites else None
        dep = app_talents.get(legacy["dep"]) if legacy["dep"] is not None else None
        classic_pos = (first["row"], first["column"]) if first else None
        legacy_pos = (dep["row"], dep["column"]) if dep else None
        if classic_pos != legacy_pos:
            note(
                "prereq",
                f"{where}: classic={first and first['name']}{classic_pos} legacy={dep and dep['name']}{legacy_pos}",
            )
        if first:  # The app always requires every rank of the prerequisite.
            other = classic_by_id.get(first["talent_id"])
            needed = other["rank_count"] if dep is None else dep["rank_count"]
            if first["required_rank"] != needed:
                note(
                    "prereq_rank",
                    f"{where}: classic needs {first['required_rank']} of {first['name']}, "
                    f"the app requires all {needed}",
                )
        for number, rank in enumerate(classic["ranks"]):
            text = legacy["ranks"].get(number)
            if text is None:
                rank_rows.append(dict(cls=code, tree=tree["name"], talent=classic["name"], rank=number + 1, category="classic_rank_only"))
                continue
            category, details = classify_rank(rank, text, language)
            rank_rows.append(
                dict(
                    cls=code,
                    tree=tree["name"],
                    talent=classic["name"],
                    rank=number + 1,
                    category=category,
                    classic=clean(rank["description"]),
                    legacy=clean(text),
                    template=clean(rank["template"]),
                    token_kinds=rank.get("token_kinds", []),
                    assumed_false=bool(rank.get("assumed_false_conditions")),
                    level_scaled=rank.get("level_scaled", []),
                    **details,
                )
            )
        for number in sorted(set(legacy["ranks"]) - set(range(len(classic["ranks"])))):
            rank_rows.append(dict(cls=code, tree=tree["name"], talent=classic["name"], rank=number + 1, category="legacy_rank_only"))

    # ---- art the app doesn't have
    if os.path.isdir(images):
        for code, tree in classic_tree_list:
            names = [(tree["icon"], f"{code}/{tree['name']} tree")]
            names += [(t["icon"], f"{code}/{tree['name']}/{t['name']}") for t in tree["talents"]]
            for icon, user in names:
                if icon and not os.path.exists(os.path.join(images, "icons", f"{icon}.webp")):
                    missing_icons[icon].add(user)
        for where, _, app_bg in background_pairs:
            if not os.path.exists(os.path.join(images, "bgs", f"{app_bg}.webp")):
                note("background_asset_missing", f"{where}: {app_bg}.webp")
    else:
        print(f"no images folder at {images}: art was not checked")

    # ---- report
    counts = collections.Counter(r["category"] for r in rank_rows)
    by_class = collections.defaultdict(collections.Counter)
    for row in rank_rows:
        by_class[row["cls"]][row["category"]] += 1
    origins = collections.Counter(r.get("origin") for r in rank_rows if r["category"] == "numbers")
    text_numbers = sum(1 for r in rank_rows if r.get("numbers_differ"))
    kinds = collections.defaultdict(collections.Counter)
    for row in rank_rows:
        for kind in row.get("token_kinds", []):
            kinds[kind]["agree" if row["category"] in ("identical", "format") else row["category"]] += 1

    print(f"classic talents {len(classic_at)}, legacy talents {len(app_talents)}, matched {len(pairs)}")
    print(f"ranks compared {len(rank_rows)}: {dict(sorted(counts.items()))}; numbers origin {dict(origins)}; text ranks whose numbers also differ {text_numbers}")
    print("by class:")
    for code in sorted(by_class):
        print(f"  {code}: {dict(sorted(by_class[code].items()))}")
    print("by token kind (a rank counts for every kind it uses):")
    for kind in sorted(kinds):
        print(f"  {kind}: {dict(sorted(kinds[kind].items()))}")
    print("structural:", json.dumps({k: len(v) for k, v in sorted(structural.items())}))
    for category in sorted(structural):
        for line in structural[category]:
            print(f"{category}: {line}")
    print(f"icons not in {images}/icons: {len(missing_icons)}")
    for icon in sorted(missing_icons):
        print(f"  {icon}: {', '.join(sorted(missing_icons[icon]))}")

    if report_path:
        with open(report_path, "w", encoding="utf-8") as output:
            json.dump(
                dict(
                    source=extract["source"],
                    rank_counts=counts,
                    by_class=by_class,
                    structural=structural,
                    missing_icons={k: sorted(v) for k, v in missing_icons.items()},
                    ranks=[r for r in rank_rows if r["category"] != "identical"],
                ),
                output,
                ensure_ascii=False,
                indent=1,
            )
        print(f"report: {report_path}")


if __name__ == "__main__":
    main()
