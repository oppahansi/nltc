"""Convert talent icons and tree backgrounds to WebP for review. Read-only on the install.
usage: <venv>/bin/python -I extract_art.py <scripts_dir> <install> <dbd> <listfile> <extract.json> <out_dir> <class>"""
import sys,os,io,json
sys.path.insert(0,sys.argv[1]); import casc,wdc
from PIL import Image
INST,DBD,LF,J,OUT,CL=sys.argv[2:8]
c=casc.Casc(INST); B=c.info["Version"]
fd=None
for line in open(LF,encoding='utf-8',errors='replace'):
    if line.endswith(";dbfilesclient/manifestinterfacedata.db2\n"): fd=int(line.split(';')[0]); break
Man=wdc.load(c,DBD,fd,"ManifestInterfaceData","enUS",B)
x=json.load(open(J,encoding='utf-8'))['classes'][CL]
os.makedirs(OUT+"/icons",exist_ok=True); os.makedirs(OUT+"/bgs",exist_ok=True)
def blp(fid):
    return Image.open(io.BytesIO(c.read_fdid(fid,"enUS"))).convert("RGBA")
done=0; failed=[]
icons={(t['icon'],t['icon_fdid']) for tr in x['trees'] for t in tr['talents']}|{(tr['icon'],tr['icon_fdid']) for tr in x['trees']}
for name,fid in sorted(icons):
    try:
        im=blp(fid); im.resize((128,128),Image.LANCZOS).save(f"{OUT}/icons/{name}.webp",quality=85); done+=1
    except Exception as e: failed.append((name,fid,type(e).__name__,str(e)[:80]))
print("icons",done,"failed",failed[:10])
byname={r['FileName'].lower():i for i,r in Man.rows.items() if 'talentframe' in r['FilePath'].lower()}
for tr in x['trees']:
    bf=tr['background_file']
    parts={p:blp(byname[f"{bf}-{p}.blp".lower()]) for p in ("TopLeft","TopRight","BottomLeft","BottomRight")}
    print(bf,{p:i.size for p,i in parts.items()})
    tl,tr_,bl,br=[parts[p] for p in ("TopLeft","TopRight","BottomLeft","BottomRight")]
    W=tl.width+tr_.width; H=tl.height+bl.height
    im=Image.new("RGBA",(W,H)); im.paste(tl,(0,0)); im.paste(tr_,(tl.width,0)); im.paste(bl,(0,tl.height)); im.paste(br,(tl.width,tl.height))
    im=im.convert("RGB"); fn=f"{CL}_{tr['name'].lower().replace(' ','_')}.webp"; im.save(f"{OUT}/bgs/{fn}",quality=85); print("  ",fn,im.size)
