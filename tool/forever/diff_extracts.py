"""Diff two extract_forever JSON files. usage: python3 -I diff_extracts.py old.json new.json. Exit 1 when different."""
import json,sys
a,b=[json.load(open(p,encoding='utf-8')) for p in sys.argv[1:3]]
print("builds",a['source']['build'],"->",b['source']['build'])
def idx(x):
    o={}
    for c,cc in x['classes'].items():
        for tr in cc['trees']:
            for t in tr['talents']:
                o[t['node_id']]=dict(cls=c,tree=tr['name'],name=t['name'],icon=t['icon'],row=t['row'],column=t['column'],max_ranks=t['max_ranks'],prereq=sorted(p['node'] for p in t['prerequisites']),texts=[r['description'] for r in t['ranks']])
    for tr in x.get('legacy',{}).get('trees',[]):
        for t in tr['nodes']:
            o['legacy:%d'%t['node_id']]=dict(cls='legacy',tree=tr['name'],name=t['name'],icon=t['icon'],row=t['grid']['row'],column=t['grid']['column'],max_ranks=t['max_ranks'],required=t['required_points_in_tree'],placeholder=t['placeholder'],cost=[c['amount'] for c in t['cost_per_rank']],prereq=sorted(p['node'] for p in t['prerequisites']),texts=[r['description'] for r in t['ranks']])
    return o
A,B=idx(a),idx(b); n=0
for key in ('cap',):
    u,v=[x.get('legacy',{}).get('currency',{}).get(key) for x in (a,b)]
    if u!=v: print("CHANGED legacy currency",key,u,"->",v); n+=1
for k in sorted(set(A)-set(B),key=str): print("REMOVED",k,A[k]['cls'],A[k]['name']); n+=1
for k in sorted(set(B)-set(A),key=str): print("ADDED",k,B[k]['cls'],B[k]['name']); n+=1
for k in sorted(set(A)&set(B),key=str):
    for f in A[k]:
        if A[k][f]!=B[k][f]: print("CHANGED",k,A[k]['cls'],A[k]['name'],f,A[k][f],"->",B[k][f]); n+=1
print("differences",n); sys.exit(1 if n else 0)
