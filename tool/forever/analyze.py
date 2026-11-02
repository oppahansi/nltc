"""usage: analyze.py scripts extract.json wowhead.js appdb wago_spot_dir install dbd listfile"""
import sys,json,re,collections,csv,sqlite3
sys.path.insert(0,sys.argv[1]); import wh, casc, wdc
J,WH,APP,SPOT,INST,DBD,LF=sys.argv[2:9]
x=json.load(open(J,encoding='utf-8')); w=wh.load(WH)
wn={t['id']:(int(tab),t) for tab,ts in w['talents'].items() for t in ts.values()}
tab2cls={tr['talent_tab_id']:c for c,cc in x['classes'].items() for tr in cc['trees']}
# per class diff
d=collections.defaultdict(collections.Counter); localmax={}
for cn,cc in x['classes'].items():
    for tr in cc['trees']:
        for t in tr['talents']:
            localmax[t['node_id']]=t['max_ranks']
            if t['node_id'] not in wn: d[cn]['local_only']+=1; continue
            tab,wt=wn[t['node_id']]
            if t['name']!=wt['name']: d[cn]['name']+=1
            if (t['row'],t['column'],tr['talent_tab_id'])!=(wt['row'],wt['col'],tab): d[cn]['pos']+=1
            if t['max_ranks']!=len(wt['ranks']): d[cn]['ranks']+=1
for i,(tab,wt) in wn.items():
    if i not in localmax: d[tab2cls[tab]]['wh_only']+=1
print("structural diff per class",{k:dict(v) for k,v in d.items()})
print("client totals",{c:(sum(len(t['talents']) for t in cc['trees']),sum(t['points_available'] for t in cc['trees'])) for c,cc in x['classes'].items()})
wtot=collections.Counter(); wpts=collections.Counter()
for tab,ts in w['talents'].items():
    c=tab2cls[int(tab)]; wtot[c]+=len(ts); wpts[c]+=sum(len(t['ranks']) for t in ts.values())
print("wowhead totals",{c:(wtot[c],wpts[c]) for c in wtot})
qty=collections.Counter(); rowrule=collections.Counter(); samerow=[]; multi=[]; nonmax=[]
for i,(tab,t) in wn.items():
    rowrule[t['requiredPoints']==t['row']*5]+=1
    if len(t['requires'])>1: multi.append((t['name'],t['requires']))
    for r in t['requires']:
        q=wn.get(r['id'])
        if q:
            qty[r['qty']==len(q[1]['ranks'])]+=1
            if r['qty']!=len(q[1]['ranks']): nonmax.append((t['name'],q[1]['name'],r['qty'],len(q[1]['ranks'])))
            if q[1]['row']>=t['row']: samerow.append((t['name'],q[1]['name'],q[1]['row'],t['row'],q[1]['col'],t['col']))
            if q[0]!=tab: print("cross-tab",t['name'])
print("WH requiredPoints==row*5",rowrule,"prereq qty==max",qty,"nonmax",nonmax[:10],"multi",multi[:10],"same-or-lower row",samerow[:12])
lm=[(t['name']) for c in x['classes'].values() for tr in c['trees'] for t in tr['talents'] if len(t['prerequisites'])>1]; print("client multi-prereq",lm)
ls=[]
byid={t['node_id']:t for c in x['classes'].values() for tr in c['trees'] for t in tr['talents']}
for t in byid.values():
    for p in t['prerequisites']:
        q=byid.get(p['node'])
        if not q: ls.append(('dangling',t['name'],p['node']))
        elif q['row']>=t['row']: ls.append((t['name'],q['name'],q['row'],t['row'],q['column'],t['column']))
print("client non-upward/dangling prereqs",ls[:20])
print("client required_points==row*5",collections.Counter(t['required_points_in_tree']==t['row']*5 for t in byid.values()),[ (t['name'],t['row'],t['required_points_in_tree']) for t in byid.values() if t['required_points_in_tree']!=t['row']*5][:10])
dup=collections.Counter()
for c,cc in x['classes'].items():
    n=collections.Counter(t['name'] for tr in cc['trees'] for t in tr['talents'])
    dd=[k for k,v in n.items() if v>1]
    if dd: dup[c]=dd
print("duplicate talent names within class",dict(dup))
wd={}
for tab,ts in w['talents'].items():
    n=collections.Counter(t['name'] for t in ts.values()); 
print("rank-1 by row",collections.Counter((t['row']) for t in byid.values() if t['max_ranks']==1))
print("single ranks count",sum(1 for t in byid.values() if t['max_ranks']==1))
print("unresolved",collections.Counter(u for t in byid.values() for u in t['unresolved_tokens']).most_common(25))
print("no-spell/no-icon",[t['name'] for t in byid.values() if not t['icon']][:20])
mage=[t for tr in x['classes']['mage']['trees'] for t in tr['talents']]
print("mage flags",collections.Counter((t['node_flags'],t['entry_type'],t['entry_count']) for t in mage))
print("mage ranks",[(tr['name'],sum(t['max_ranks'] for t in tr['talents'])) for tr in x['classes']['mage']['trees']])
for g in ("Ice Lance","Ice Block","Cold Snap","Arcane Blast","Missile Barrage","Burning Soul","Heating Up"):
    t=next(t for t in mage if t['name']==g); print(g,'row',t['row'],'col',t['column'],'ranks',t['max_ranks'],'req',t['required_points_in_tree'],'pre',t['prerequisites'])
print("Piercing Ice present",any(t['name']=='Piercing Ice' for t in mage),"Elemental Precision",[(t['name'],t['max_ranks']) for t in mage if 'Precision' in t['name']])
# App data spot check vs Classic tables
db=sqlite3.connect(f"file:{APP}?mode=ro",uri=True)
cls={1024:0,4:1,128:2,2:3,16:4,8:5,64:6,256:7,1:8,32:9}
csv.field_size_limit(10**8)
for exp,b in ((1,"1.15.9.70576"),(2,"2.5.6.70577"),(3,"3.80.2.70522")):
    T=list(csv.DictReader(open(f"{SPOT}/Talent_{b}.csv",encoding='utf-8'))); Tab={r['ID']:r for r in csv.DictReader(open(f"{SPOT}/TalentTab_{b}.csv",encoding='utf-8'))}; S={r['ID']:r['Name_lang'] for r in csv.DictReader(open(f"{SPOT}/SpellName_{b}.csv",encoding='utf-8'))}
    app={(r[0],r[1],r[2],r[3]):r[4:] for r in db.execute("select t.classId,t.talentTreeId,t.row,t.column,n.name,(select count(*) from ranks r where r.talentId=t.id) from talents t join talent_names n on n.talentId=t.id where t.expansion=? and n.languageCode='en'",(exp,))}
    same=diffn=diffr=miss=0; ex=[]
    for r in T:
        tb=Tab.get(r['TabID']); 
        if not tb or int(tb['ClassMask']) not in cls: continue
        k=(cls[int(tb['ClassMask'])],int(tb['OrderIndex']),int(r['TierID']),int(r['ColumnIndex']))
        rk=[r[f'SpellRank_{i}'] for i in range(9) if r.get(f'SpellRank_{i}','0') not in('0','')]
        nm=S.get(rk[0]) if rk else None
        a=app.get(k)
        if not a: miss+=1; ex.append(('missing',k,nm,len(rk)));continue
        if a[0]!=nm: diffn+=1; ex.append(('name',k,a[0],nm))
        elif a[1]!=len(rk): diffr+=1; ex.append(('ranks',k,a[0],a[1],len(rk)))
        else: same+=1
    print(f"exp {exp} vs {b}: Classic rows {len(T)} app rows {len(app)} same {same} namediff {diffn} rankdiff {diffr} nomatchcell {miss}"); print("   ",ex[:10])
# Currency, legacy trees
c=casc.Casc(INST); B="1.60.1.70707"
names={}
for line in open(LF,encoding='utf-8',errors='replace'):
    if ';dbfilesclient/' in line and line.rstrip().endswith('.db2'):
        i,p=line.rstrip().split(';',1); names[p.split('/')[-1][:-4].lower()]=int(i)
L=lambda n: wdc.load(c,DBD,names[n.lower()],n,"enUS",B)
CS=L("TraitCurrencySource"); print("currency src 3820",sorted({(r['PlayerLevel'],r['Amount'],r['QuestID'],r['AchievementID'],r['TraitNodeEntryID']) for r in CS.rows.values() if r['TraitCurrencyID']==3820})[:6],len([r for r in CS.rows.values() if r['TraitCurrencyID']==3820]),"sum",sum(r['Amount'] for r in CS.rows.values() if r['TraitCurrencyID']==3820))
oth=[r for r in CS.rows.values() if r['TraitCurrencyID']!=3820]; print("currency others",collections.Counter(r['TraitCurrencyID'] for r in oth),oth[:3])
srcs=[r for r in CS.rows.values() if r['TraitCurrencyID']==3820 and not r['PlayerLevel']]; print("3820 non-level",srcs[:4],len(srcs))
print("levels",sorted(r['PlayerLevel'] for r in CS.rows.values() if r['TraitCurrencyID']==3820)[:3],max(r['PlayerLevel'] for r in CS.rows.values() if r['TraitCurrencyID']==3820))
NAT=L("NumTalentsAtLevel"); print("NumTalentsAtLevel sample",[(i,r) for i,r in sorted(NAT.rows.items()) if i in(9,10,11,60,61,70)])
N=L("TraitNode");NX=L("TraitNodeXTraitNodeEntry");NE=L("TraitNodeEntry");TD=L("TraitDefinition");SN=L("SpellName");TC=L("TraitTreeXTraitCurrency")
for tid in (1058,1066,1081,1083,1187):
    ns=[n for n in N.rows.values() if n['TraitTreeID']==tid][:40]
    nm=[]
    for n in ns:
        for r in NX.rows.values():
            if r['TraitNodeID']==n['ID']:
                nm.append(SN.rows.get(TD.rows[NE.rows[r['TraitNodeEntryID']]['TraitDefinitionID']]['SpellID'],{}).get('Name_lang'))
    print("tree",tid,len(ns),"currency",[r['TraitCurrencyID'] for r in TC.rows.values() if r['TraitTreeID']==tid],nm[:14])
