"""usage: python3 -I compare_wh.py <scripts_dir> <extract.json> <wowhead talents-classic.js> [class]"""
import sys,json,re,collections
sys.path.insert(0,sys.argv[1]); import wh
x=json.load(open(sys.argv[2],encoding='utf-8')); w=wh.load(sys.argv[3]); only=sys.argv[4] if len(sys.argv)>4 else None
norm=lambda s:re.sub(r'\s+',' ',re.sub(r'\|c[0-9a-fA-F]{8}|\|r|<[^>]+>','',s or '')).strip()
tot=collections.Counter(); diffs=[]; wmap={t['id']:(int(tab),t) for tab,ts in w['talents'].items() for t in ts.values()}
seen=set()
for cn,c in x['classes'].items():
    if only and cn!=only: continue
    for tr in c['trees']:
        for t in tr['talents']:
            tot['local']+=1; seen.add(t['node_id'])
            wt=wmap.get(t['node_id'])
            if not wt: tot['not_in_wh']+=1; diffs.append(('not_in_wh',cn,tr['name'],t['name'],t['node_id'])); continue
            tab,w_=wt
            for k,a,b in (('tab',tr['talent_tab_id'],tab),('name',t['name'],w_['name']),('row',t['row'],w_['row']),('col',t['column'],w_['col']),('ranks',t['max_ranks'],len(w_['ranks'])),('reqpts',t['required_points_in_tree'],w_['requiredPoints']),('icon',t['icon'],w_['icon'])):
                tot['checked_'+k]+=1
                if a!=b: tot['diff_'+k]+=1; diffs.append((k,cn,tr['name'],t['name'],a,b))
            pre=sorted(p['node'] for p in t['prerequisites']); wr=sorted(r['id'] for r in w_['requires'])
            tot['checked_prereq']+=1
            if pre!=wr: tot['diff_prereq']+=1; diffs.append(('prereq',cn,tr['name'],t['name'],pre,wr))
            for r in t['ranks']:
                tot['checked_desc']+=1
                a=norm(r['description']); b=norm(w_['descriptions'].get(str(r['rank'])))
                if a!=b: tot['diff_desc']+=1; diffs.append(('desc',cn,t['name'],r['rank'],a,b))
for nid,(tab,w_) in wmap.items():
    if nid not in seen and (not only or any(str(tr['talent_tab_id'])==str(tab) for tr in x['classes'].get(only,{}).get('trees',[]))):
        tot['wh_only']+=1; diffs.append(('wh_only',tab,w_['name'],nid,w_['row'],w_['col'],w_['ranks'],w_['requiredPoints']))
print(dict(tot))
k=collections.Counter(d[0] for d in diffs); print(k)
for d in diffs[:int(sys.argv[5]) if len(sys.argv)>5 else 60]: print(d)
