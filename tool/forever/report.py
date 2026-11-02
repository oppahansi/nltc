"""Quality report for a pair of Forever extracts.

usage: python3 -I report.py <en.json> <de.json> <icons_dir>

Prints counts, the Legacy layout, icons with no file, unresolved tokens, text defects
and en/de structure differences. Exits 0 whatever it finds: read the output.
"""
import collections
import json
import os
import re
import sys

MARKER = re.compile(r"\[\[\?.*?\]\]", re.S)
LETTER = "A-Za-zÄÖÜäöüß"
DEFECTS = (
    ("digit_digit", re.compile(r"\d%\d|\d %\d")),
    ("digit_word", re.compile(rf"\d[{LETTER}]{{2,}}")),
    ("word_digit", re.compile(rf"[{LETTER}]\d")),
    ("percent_word", re.compile(rf"%[{LETTER}]")),
    ("leftover_token", re.compile(r"\$|\|[cCrRnT]|\?\?")),
    ("double_period", re.compile(r"\.\.")),
    ("zero_value", re.compile(r"(?<![\d.,])0(?![\d.,])")),
)


def walk(extract):
    """Yields (where, node) for every regular talent and Legacy node."""
    for code, entry in extract["classes"].items():
        for tree in entry["trees"]:
            for talent in tree["talents"]:
                yield f"{code}/{tree['talent_tab_id']}/{talent['node_id']}", talent
    for tree in extract["legacy"]["trees"]:
        for node in tree["nodes"]:
            yield f"legacy/{tree['tree_id']}/{node['node_id']}", node


def icons(extract):
    found = {}
    for entry in extract["classes"].values():
        for tree in entry["trees"]:
            found[tree["icon_fdid"]] = (tree["icon"], "tree " + tree["name"])
            for talent in tree["talents"]:
                found[talent["icon_fdid"]] = (talent["icon"], talent["name"])
    currency = extract["legacy"]["currency"]
    found[currency["icon_fdid"]] = (currency["icon"], "Legacy currency")
    for tree in extract["legacy"]["trees"]:
        for node in tree["nodes"]:
            found[node["icon_fdid"]] = (node["icon"], "Legacy " + node["name"])
    return found


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    en, de = [json.load(open(path, encoding="utf-8")) for path in sys.argv[1:3]]
    print("build", en["source"]["build"], de["source"]["build"], "provisional", en["source"]["provisional"])
    print("encrypted en", en["encrypted"], "de", de["encrypted"])
    print("anomalies en", en["anomalies"], "de", de["anomalies"])
    stale = sorted(k for k, t in en["tables"].items() if not t["definition_lists_build"])
    print("tables whose WoWDBDefs entry doesn't name this build:", stale)

    print("\n== regular talents: class, tree, talents, ranks")
    for code, entry in sorted(en["classes"].items()):
        for tree in entry["trees"]:
            print(f"{code:8} {tree['name']:16} {len(tree['talents']):3} {tree['points_available']:3}")
        print(f"{code:8} hidden: {[(n['node_id'], n['names'], n['pos']) for n in entry['hidden_nodes']]}")
    points = en["talent_points"]
    print("points: cap", points["cap"], "first level", points["first_level_without_perk"],
          "perk levels", [(s["level"], s["requires_entry_id"]) for s in points["sources"] if s["requires_entry_id"]])

    print("\n== Legacy")
    legacy, legacy_de = en["legacy"], de["legacy"]
    print("currency", {k: v for k, v in legacy["currency"].items()}, "| de name", legacy_de["currency"]["name"])
    print("other trees in the system", legacy["other_trees_in_system"])
    for tree, tree_de in zip(legacy["trees"], legacy_de["trees"]):
        real = [n for n in tree["nodes"] if not n["placeholder"]]
        print(f"{tree['tree_id']} {tree['name']} / {tree_de['name']}: {len(real)} perks, {tree['ranks_available']} ranks, "
              f"{len(tree['nodes']) - len(real)} placeholders, gates {tree['gate_thresholds']}")
        for node, node_de in zip(tree["nodes"], tree_de["nodes"]):
            print(f"  c{node['grid']['column']} r{node['grid']['row']} {node['name']} / {node_de['name']} ({node['node_type']}) "
                  f"ranks {node['max_ranks']} gate {node['required_points_in_tree']} "
                  f"needs {[p['name'] for p in node['prerequisites']]}{' PLACEHOLDER' if node['placeholder'] else ''}")
    sets = collections.defaultdict(list)
    for source in legacy["sources"]:
        sets[source["super_district_set"]].append(source)
    for number, rows in sorted(sets.items()):
        print(f"source set {number}: {len(rows)} rows, {sum(r['amount'] for r in rows)} points")

    print("\n== icons with no file in", sys.argv[3])
    for fdid, (name, used_by) in sorted(icons(en).items(), key=lambda item: str(item[1][0])):
        if not name or not os.path.isfile(os.path.join(sys.argv[3], f"{name}.webp")):
            print(f"{name}\t{fdid}\t{used_by}")
    for tree in legacy["trees"]:
        print(f"atlas {tree['icon_atlas']}\t{tree.get('atlas_file_fdid')}\t{tree.get('atlas_rect')}\tLegacy tree {tree['name']}")

    for label, extract in (("en", en), ("de", de)):
        print(f"\n== unresolved tokens, {label}")
        for item in extract["unresolved"]:
            print(f"{item['where']}\t{item['token']}\t{item['template']!r}")

    for label, extract in (("en", en), ("de", de)):
        print(f"\n== text defects, {label}")
        for where, node in walk(extract):
            for rank in node["ranks"]:
                text = MARKER.sub("", rank["description"])
                if not rank["description"]:
                    print(f"empty\t{where}\t{node['name']}\trank {rank['rank']}")
                for kind, pattern in DEFECTS:
                    match = pattern.search(text)
                    if match:
                        start = max(0, match.start() - 25)
                        print(f"{kind}\t{where}\t{node['name']}\trank {rank['rank']}\t{text[start:match.end() + 25]!r}")

    print("\n== German under 75% of the English length")
    german = dict(walk(de))
    for where, node in walk(en):
        other = german.get(where)
        if not other:
            print("missing in de", where)
            continue
        for rank, rank_de in zip(node["ranks"], other["ranks"]):
            a, b = len(rank["description"]), len(rank_de["description"])
            if a and b / a < 0.75:
                print(f"{where}\t{node['name']} / {other['name']}\trank {rank['rank']}\t{b}/{a}\t{rank_de['description']!r}")

    print("\n== en/de structure")
    same = 0
    for where, node in walk(en):
        other = german.get(where)
        fields = ("node_id", "icon_fdid", "max_ranks", "required_points_in_tree")
        differs = [f for f in fields if other and node[f] != other[f]]
        differs += ["prerequisites"] if other and [p["node"] for p in node["prerequisites"]] != [p["node"] for p in other["prerequisites"]] else []
        differs += ["ranks"] if other and len(node["ranks"]) != len(other["ranks"]) else []
        if differs:
            print(where, node["name"], differs)
        else:
            same += 1
    print("same structure:", same, "of", sum(1 for _ in walk(en)))
    copies = [(where, node["name"]) for where, node in walk(en) if german.get(where) and node["name"] == german[where]["name"] and not node.get("placeholder")]
    print("names identical in en and de:", copies)
    untranslated = [(where, node["name"]) for where, node in walk(en) for r, r2 in [(node["ranks"][0], german[where]["ranks"][0])] if german.get(where) and r["description"] == r2["description"] and r["description"]]
    print("rank 1 text identical in en and de:", untranslated)


if __name__ == "__main__":
    main()
