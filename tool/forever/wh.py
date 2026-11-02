import json,re
def load(p):
    s=open(p,encoding='utf-8').read()
    i=s.index(',{')+1
    dec=json.JSONDecoder(); d,_=dec.raw_decode(s[i:]); return d
