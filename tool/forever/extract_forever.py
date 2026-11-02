#!/usr/bin/env python3 -I
"""Extract WoW Forever talent data from a local, read-only install.

usage: python3 -I extract_forever.py <scripts_dir> <install> <dbd_dir> <listfile.csv> <out_dir> [locale] [class ...]

Reads only. Encrypted DB2 sections are skipped and counted. Output carries the
build number so a rerun after a patch produces a comparable, diffable artifact.
"""
import json, os, re, sys, collections, math

sys.path.insert(0, sys.argv[1])
import casc, wdc  # noqa: E402

INSTALL, DBD, LF, OUT = sys.argv[2:6]
LOCALE = sys.argv[6] if len(sys.argv) > 6 else "enUS"
ONLY = [x.lower() for x in sys.argv[7:]]

c = casc.Casc(INSTALL)
BUILD = c.info["Version"]
names = {}
for line in open(LF, encoding="utf-8", errors="replace"):
    if ";dbfilesclient/" in line and line.rstrip().endswith(".db2"):
        i, p = line.rstrip().split(";", 1)
        names[p.split("/")[-1][:-4].lower()] = int(i)

ENC = {}


def L(n, locale=None):
    t = wdc.load(c, DBD, names[n.lower()], n, locale or LOCALE, BUILD)
    ENC[n] = {"records": t.record_count, "rows": len(t.rows),
              "encrypted_sections": t.encrypted_sections,
              "encrypted_records": t.encrypted_records,
              "layout": "%08X" % t.layout_hash, "magic": t.magic.decode()}
    return t


Sx, N, NE, NX, TD, EP, E, TC, NC, G, GN, GC, Cur, CP, TCur, TCS = [L(x) for x in (
    "SkillLineXTraitTree", "TraitNode", "TraitNodeEntry", "TraitNodeXTraitNodeEntry",
    "TraitDefinition", "TraitDefinitionEffectPoints", "TraitEdge", "TraitCond",
    "TraitNodeXTraitCond", "TraitNodeGroup", "TraitNodeGroupXTraitNode",
    "TraitNodeGroupXTraitCond", "Curve", "CurvePoint", "TraitCurrency", "TraitCurrencySource")]
Tab, Tal = L("TalentTab"), L("Talent")
Sp, SN, SM, SE, SAO, SD, SR, SCd, SLv, SXV, SDV, SL, SLA, Man, CC = [L(x) for x in (
    "Spell", "SpellName", "SpellMisc", "SpellEffect", "SpellAuraOptions", "SpellDuration",
    "SpellRadius", "SpellCooldowns", "SpellLevels", "SpellXDescriptionVariables",
    "SpellDescriptionVariables", "SkillLine", "SkillLineAbility", "ManifestInterfaceData", "ChrClasses")]


def by(t, key):
    m = collections.defaultdict(list)
    for r in t.rows.values():
        m[r[key]].append(r)
    return m


misc = by(SM, "SpellID")
effs = by(SE, "SpellID")
auras = by(SAO, "SpellID")
cds = by(SCd, "SpellID")
lvls = by(SLv, "SpellID")
xvar = by(SXV, "SpellID")
curve_pts = by(CP, "CurveID")
sla_by_spell = by(SLA, "Spell")
ep_by_def = by(EP, "TraitDefinitionID")


def d0(rows):
    if not rows:
        return None
    return next((r for r in rows if r.get("DifficultyID", 0) == 0), rows[0])


def effect(spell, idx):
    for r in effs.get(spell, []):
        if r["EffectIndex"] == idx and r.get("DifficultyID", 0) == 0:
            return r
    for r in effs.get(spell, []):
        if r["EffectIndex"] == idx:
            return r
    return None


def curve_eval(cid, x):
    pts = sorted(curve_pts.get(cid, []), key=lambda p: (p["OrderIndex"] if "OrderIndex" in p else 0))
    pts = sorted([(p["Pos"][0], p["Pos"][1]) for p in pts])
    if not pts:
        return None
    if x <= pts[0][0]:
        return pts[0][1]
    for (a, b), (e, f) in zip(pts, pts[1:]):
        if x <= e:
            return b + (f - b) * (x - a) / (e - a) if e != a else f
    return pts[-1][1]


def fmt(v):
    if v is None:
        return "?"
    v = round(v, 2)
    if abs(v - round(v)) < 1e-6:
        return str(int(round(v)))
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return s


def dur_text(ms):
    if ms is None or ms <= 0:
        return "until cancelled"
    s = ms / 1000
    if s < 60:
        return fmt(s) + " sec"
    if s < 3600:
        return fmt(s / 60) + " min"
    return fmt(s / 3600) + " hrs"


class Unresolved(Exception):
    pass


def base_value(spell, idx, tdef, rank, top_spell):
    e = effect(spell, idx)
    if e is None:
        return None
    val = e["EffectBasePointsF"]
    # Per-rank scaling: curves apply only to the talent's own spell
    if tdef and spell == top_spell:
        for ep in ep_by_def.get(tdef, []):
            if ep["EffectIndex"] == idx:
                cv = curve_eval(ep["CurveID"], rank)
                if cv is not None:
                    if ep["OperationType"] == 0:
                        val = cv
                    elif ep["OperationType"] == 1:
                        val = val * cv
    return val


def scaled(spell, idx, v):
    """Applies EffectRealPointsPerLevel at the spell's MaxLevel."""
    e = effect(spell, idx)
    lv = d0(lvls.get(spell))
    if e and lv and e["EffectRealPointsPerLevel"] and lv["MaxLevel"] > lv["BaseLevel"]:
        v = v + e["EffectRealPointsPerLevel"] * (lv["MaxLevel"] - lv["BaseLevel"])
    return v


def s_range(spell, idx, tdef, rank, top_spell):
    """Returns 'a to b' for effects with Variance, else None."""
    e = effect(spell, idx)
    if not e or not e["Variance"]:
        return None
    b = base_value(spell, idx, tdef, rank, top_spell)
    mid = scaled(spell, idx, b)
    half = abs(b) * e["Variance"] / 2
    return "%d to %d" % (round(abs(mid) - half), round(abs(mid) + half))


def tok_value(ch, spell, n, tdef, rank, top_spell, unresolved):
    ch_l = ch.lower()
    idx = (n - 1) if n else 0
    e = effect(spell, idx)
    if ch_l in ("s", "m"):
        v = base_value(spell, idx, tdef, rank, top_spell)
        return abs(scaled(spell, idx, v)) if v is not None else None
    if ch_l == "o":
        v = base_value(spell, idx, tdef, rank, top_spell)
        m = d0(misc.get(spell))
        if v is None or not m or not e or not e["EffectAuraPeriod"]:
            return None
        dr = SD.rows.get(m["DurationIndex"], {}).get("Duration", 0)
        return abs(v) * (dr / e["EffectAuraPeriod"])
    if ch_l == "t":
        return e["EffectAuraPeriod"] / 1000 if e and e["EffectAuraPeriod"] else None
    if ch_l == "a":
        if not e:
            return None
        ri = e["EffectRadiusIndex"][0]
        return SR.rows.get(ri, {}).get("Radius")
    if ch_l == "x":
        return e["EffectChainTargets"] if e else None
    if ch_l == "e":
        return e["EffectAmplitude"] if e else None
    if ch_l == "b":
        return e["EffectPointsPerResource"] if e else None
    if ch_l == "h":
        a = d0(auras.get(spell))
        return a["ProcChance"] if a else None
    if ch_l == "n":
        a = d0(auras.get(spell))
        return a["ProcCharges"] if a else None
    if ch_l == "u":
        a = d0(auras.get(spell))
        return a["CumulativeAura"] if a else None
    return None


TOKEN = re.compile(r"\$(?:(\d+))?(?:\*?)([a-zA-Z])(\d?)")


def render(text, tdef, rank, top_spell, unresolved, depth=0):
    """Render a Blizzard spell description template for a rank."""
    if text is None:
        return ""
    out = []
    i = 0
    n = len(text)

    def scalar(spell, ch, num):
        if ch.lower() == "d":
            m = d0(misc.get(spell))
            if not m:
                return None, None
            return dur_text(SD.rows.get(m["DurationIndex"], {}).get("Duration", 0)), "text"
        if ch == "s":
            rng = s_range(spell, (int(num) - 1) if num else 0, tdef, rank, top_spell)
            if rng:
                return rng, "text"
        v = tok_value(ch, spell, int(num) if num else 0, tdef, rank, top_spell, unresolved)
        return v, "num"

    while i < n:
        ch = text[i]
        if ch != "$":
            out.append(ch)
            i += 1
            continue
        rest = text[i:]
        # ${expr}
        if rest.startswith("${"):
            end = text.find("}", i)
            expr = text[i + 2:end]
            dec = None
            m = re.search(r"\.(\d)$", text[end + 1:end + 3] or "") if False else None
            val = eval_expr(expr, tdef, rank, top_spell, unresolved)
            j = end + 1
            mm = re.match(r"\.(\d)", text[j:])
            if mm:
                dec = int(mm.group(1))
                j += 2
            if val is not None:
                val = abs(val)
            if val is None:
                unresolved.append(rest[:40])
                out.append("?")
            elif dec is not None:
                out.append(("%." + str(dec) + "f") % val)
            else:
                out.append(fmt(val))
            i = j
            continue
        # $/1000;S1, $*10;s1, optionally with explicit spell id: $/1000;12345S1
        m = re.match(r"\$([*/])(\d+(?:\.\d+)?);(\d+)?([a-zA-Z])(\d?)", rest)
        if m:
            sid = int(m.group(3)) if m.group(3) else top_spell
            v, kind = scalar(sid, m.group(4), m.group(5))
            if v is None or kind != "num":
                unresolved.append(m.group(0))
                out.append("?")
            else:
                f = float(m.group(2))
                out.append(fmt(abs(v / f if m.group(1) == "/" else v * f)))
            i += m.end()
            continue
        # $?condition[a][b] : take else-branch for class/spell conditions we cannot evaluate statically
        if rest.startswith("$?"):
            j = i + 2
            while j < n and text[j] != "[":
                j += 1
            depth_b = 0
            k = j
            parts = []
            while k < n and text[k] == "[":
                st = k + 1
                d_ = 0
                k2 = k
                while k2 < n:
                    if text[k2] == "[":
                        d_ += 1
                    elif text[k2] == "]":
                        d_ -= 1
                        if d_ == 0:
                            break
                    k2 += 1
                parts.append(text[st:k2])
                k = k2 + 1
                # 2nd branch may be another "?cond[" chain
                if k < n and text[k] == "?":
                    while k < n and text[k] != "[":
                        k += 1
            pick = parts[-1] if parts else ""
            unresolved.append("cond:" + text[i:j])
            out.append(render(pick, tdef, rank, top_spell, unresolved, depth + 1))
            i = k
            continue
        # gender / plural:  $lx:y;  $gx:y;
        m = re.match(r"\$([lLgG])([^:;]*):([^;]*);", rest)
        if m:
            if m.group(1).lower() == "l":
                prior = re.findall(r"(\d+(?:\.\d+)?)", "".join(out))
                out.append(m.group(2) if prior and float(prior[-1]) == 1 else m.group(3))
            else:
                out.append(m.group(2))
            i += m.end()
            continue
        # spell-desc include
        m = re.match(r"\$@(spelldesc|spellaura|spellname|spellicon)(\d+)", rest)
        if m:
            sid = int(m.group(2))
            if m.group(1) == "spellname":
                out.append(SN.rows.get(sid, {}).get("Name_lang", "?"))
            elif m.group(1) == "spelldesc":
                out.append(render(Sp.rows.get(sid, {}).get("Description_lang", ""), None, rank, sid, unresolved, depth + 1))
            else:
                out.append(render(Sp.rows.get(sid, {}).get("AuraDescription_lang", ""), None, rank, sid, unresolved, depth + 1))
            i += m.end()
            continue
        # <var>
        m = re.match(r"\$<(\w+)>", rest)
        if m:
            v = var_lookup(m.group(1), top_spell, tdef, rank, unresolved, depth)
            if v is None:
                unresolved.append(m.group(0))
                out.append("?")
            else:
                out.append(fmt(v))
            i += m.end()
            continue
        m = re.match(r"\$(\d+)?([a-zA-Z])(\d?)", rest)
        if m:
            sid = int(m.group(1)) if m.group(1) else top_spell
            v, kind = scalar(sid, m.group(2), m.group(3))
            if v is None:
                unresolved.append(m.group(0))
                out.append("?")
            elif kind == "text":
                out.append(v)
            else:
                out.append(fmt(v))
            i += m.end()
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def var_lookup(name, spell, tdef, rank, unresolved, depth):
    if depth > 3:
        return None
    for x in xvar.get(spell, []):
        v = SDV.rows.get(x["SpellDescriptionVariablesID"], {}).get("Variables", "")
        for line in v.splitlines():
            m = re.match(r"\$" + re.escape(name) + r"=(.*)", line.strip())
            if m:
                e = m.group(1).strip()
                if e.startswith("${") and e.endswith("}"):
                    e = e[2:-1]
                return eval_expr(e, tdef, rank, spell, unresolved)
    return None


SAFE = re.compile(r"^[0-9+\-*/(). ]+$")


def eval_expr(expr, tdef, rank, top_spell, unresolved):
    sub_fail = []

    def rep(m):
        sid = int(m.group(1)) if m.group(1) else top_spell
        if m.group(2).lower() == "d":
            mm = d0(misc.get(sid))
            return str(SD.rows.get(mm["DurationIndex"], {}).get("Duration", 0) / 1000) if mm else "0"
        v = tok_value(m.group(2), sid, int(m.group(3)) if m.group(3) else 0, tdef, rank, top_spell, unresolved)
        if v is None:
            sub_fail.append(m.group(0))
            return "0"
        return repr(float(v))
    e = re.sub(r"\$(\d+)?([a-zA-Z])(\d?)", rep, expr)
    if sub_fail or not SAFE.match(e):
        return None
    try:
        return float(eval(e, {"__builtins__": {}}, {}))  # expression validated to arithmetic only
    except Exception:
        return None


# ---------------- assemble
CLASS_BY_MASK = {r["ID"]: r for r in CC.rows.values()}
SKILL_TO_CLASS = {}
out_classes = {}
nx_by_node = by(NX, "TraitNodeID")
groups_of_node = collections.defaultdict(list)
members = collections.defaultdict(list)
for r in GN.rows.values():
    groups_of_node[r["TraitNodeID"]].append(r["TraitNodeGroupID"])
    members[r["TraitNodeGroupID"]].append(r["TraitNodeID"])
gc = by(GC, "TraitNodeGroupID")
edges_in = collections.defaultdict(list)
for e in E.rows.values():
    edges_in[e["RightTraitNodeID"]].append(e)

# tab assignment: a talent spell's SkillLineAbility row names the class skill line,
# and TalentTab has the class and tree name. TraitTree comes from SkillLineXTraitTree.
TREE_TO_SKILL = {r["TraitTreeID"]: r["SkillLineID"] for r in Sx.rows.values()}
tabs_by_mask = collections.defaultdict(list)
for t in Tab.rows.values():
    tabs_by_mask[t["ClassMask"]].append(t)


def node_spell(nid):
    es = nx_by_node.get(nid, [])
    res = []
    for x in sorted(es, key=lambda r: r["Index"]):
        ent = NE.rows.get(x["TraitNodeEntryID"])
        if ent:
            res.append(ent)
    return res


# Position based tab split inside a class tree: three clusters of PosX
def clusters(xs):
    xs = sorted(set(xs))
    gaps = sorted([(b - a, i) for i, (a, b) in enumerate(zip(xs, xs[1:]))], reverse=True)[:2]
    cuts = sorted(i for _, i in gaps)
    return [xs[cuts[0]], xs[cuts[1]]]


result = {"source": {"product": c.info["Product"], "build": BUILD,
                     "build_config": c.info["Build Key"], "cdn_config": c.info["CDN Key"],
                     "locale": LOCALE, "provisional": True,
                     "note": "Pre-launch client data without server-delivered hotfixes. Provisional until re-extracted from the live build."},
          "tables": ENC, "classes": {}}

TAB_X0 = (1020, 5020, 9080)
GRID_Y0 = 2130
CLASS_NAMES = {1: "warrior", 2: "paladin", 4: "hunter", 8: "rogue", 16: "priest", 64: "shaman", 128: "mage", 256: "warlock", 1024: "druid"}
sm_by_tree = {}
unres_total = 0
for tree_id, skill in sorted(TREE_TO_SKILL.items()):
    nodes = [n for n in N.rows.values() if n["TraitTreeID"] == tree_id and n["ID"] in nx_by_node]
    # class detected from the skill line's name in TalentTab plus spell family
    votes = collections.Counter()
    for n in nodes:
        for ent in node_spell(n["ID"]):
            sp = TD.rows.get(ent["TraitDefinitionID"], {}).get("SpellID")
            for ra in sla_by_spell.get(sp, []):
                if ra.get("ClassMask"):
                    votes[ra["ClassMask"]] += 1
    mask = votes.most_common(1)[0][0]
    cname = CLASS_NAMES[mask]
    if ONLY and cname not in ONLY:
        continue
    # Fixed grid observed in all nine trees: three tab origins, 600 unit cells, 4x7.
    per_tab = {0: [], 1: [], 2: []}
    hidden = []
    for n in nodes:
        placed = False
        for pos, x0 in enumerate(TAB_X0):
            cx = (n["PosX"] - x0 + 300) // 600
            ry = (n["PosY"] - GRID_Y0 + 300) // 600
            if 0 <= cx <= 3 and 0 <= ry <= 6 and n["Flags"] != 10:
                per_tab[pos].append(n)
                placed = True
                break
        if not placed:
            hidden.append(n)
    tree_tabs = sorted(tabs_by_mask[mask], key=lambda t: t["OrderIndex"])
    cout = {"class_mask": mask, "name": cname, "trait_tree_id": tree_id, "skill_line_id": skill, "trees": []}
    for pos in range(3):
        tns = per_tab[pos]
        x0 = TAB_X0[pos]
        # tab name by skill-line vote: which TalentTab does the cluster's first spell's skill line match
        talents = []
        votes_skill = collections.Counter()
        for n in sorted(tns, key=lambda n: (n["PosY"], n["PosX"])):
            ents = node_spell(n["ID"])
            if not ents:
                continue
            ent = ents[0]
            td = TD.rows[ent["TraitDefinitionID"]]
            spell = td["SpellID"]
            for ra in sla_by_spell.get(spell, []):
                votes_skill[ra["SkillLine"]] += 1
            name = td["OverrideName_lang"] or SN.rows.get(spell, {}).get("Name_lang", "")
            mm = d0(misc.get(spell))
            icon_id = td["OverrideIcon"] or (mm["SpellIconFileDataID"] if mm else 0)
            man = Man.rows.get(icon_id)
            icon = man["FileName"][:-4].lower() if man else None
            desc_t = td["OverrideDescription_lang"] or Sp.rows.get(spell, {}).get("Description_lang", "")
            ranks = []
            un = []
            for rk in range(1, ent["MaxRanks"] + 1):
                ranks.append({"rank": rk, "description": render(desc_t, td["ID"], rk, spell, un)})
            prereq = [{"node": ee["LeftTraitNodeID"], "edge_type": ee["Type"]} for ee in edges_in.get(n["ID"], []) if ee["Type"] == 2]
            spent = 0
            for g in groups_of_node[n["ID"]]:
                for x in gc.get(g, []):
                    co = TC.rows.get(x["TraitCondID"])
                    if co and co["TraitCurrencyID"] == 3820 and co["CondType"] == 0:
                        spent = max(spent, co["SpentAmountRequired"])
            cleaned = sorted(set(u for u in un))
            unres_total += len(cleaned)
            talents.append({
                "node_id": n["ID"], "entry_id": ent["ID"], "definition_id": td["ID"], "spell_id": spell,
                "visible_spell_id": td["VisibleSpellID"], "overrides_spell_id": td["OverridesSpellID"],
                "name": name, "icon": icon, "icon_fdid": icon_id,
                "row": (n["PosY"] - GRID_Y0 + 300) // 600, "column": (n["PosX"] - x0 + 300) // 600,
                "pos": [n["PosX"], n["PosY"]], "node_type": n["Type"], "node_flags": n["Flags"],
                "entry_type": ent["NodeEntryType"], "entry_count": len(ents),
                "max_ranks": ent["MaxRanks"], "required_points_in_tree": spent,
                "prerequisites": prereq, "description_template": desc_t, "ranks": ranks,
                "unresolved_tokens": cleaned,
            })
        # match TalentTab via skill line display name
        top_skill = votes_skill.most_common(1)[0][0] if votes_skill else None
        sk_name = SL.rows.get(top_skill, {}).get("DisplayName_lang")
        tab = next(t for t in tree_tabs if t["OrderIndex"] == pos)
        cout["trees"].append({
            "position": pos, "talent_tab_id": tab["ID"], "name": tab["Name_lang"], "skill_line": sk_name,
            "order_index": tab["OrderIndex"], "background_file": tab["BackgroundFile"],
            "icon_fdid": tab["SpellIconID"],
            "icon": (Man.rows.get(tab["SpellIconID"], {}).get("FileName", "")[:-4].lower() or None),
            "points_available": sum(t["max_ranks"] for t in talents), "talents": talents})
    cout["hidden_nodes"] = [{"node_id": n["ID"], "pos": [n["PosX"], n["PosY"]], "flags": n["Flags"],
        "names": [SN.rows.get(TD.rows[e["TraitDefinitionID"]]["SpellID"], {}).get("Name_lang") for e in node_spell(n["ID"])]} for n in hidden]
    cout["trees"].sort(key=lambda t: t["order_index"])
    result["classes"][cname] = cout

os.makedirs(OUT, exist_ok=True)
tag = "_".join(ONLY) if ONLY else "all"
path = os.path.join(OUT, "forever_%s_%s_%s.json" % (BUILD, tag, LOCALE))
with open(path, "w", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, indent=1)
print(path, "classes", list(result["classes"]), "unresolved tokens", unres_total)
print({k: v for k, v in ENC.items() if v["encrypted_sections"]})
