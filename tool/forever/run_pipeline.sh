#!/bin/sh
# Rerun after any patch. Read-only on the install; writes only under <work_dir> and <out_dir>.
# usage: run_pipeline.sh <install> <work_dir> [out_dir]
#   work_dir holds dl/ and stays outside the repo. WoWDBDefs and the listfile are downloaded there
#   when missing. out_dir defaults to <work_dir>/out.
set -eu
INST=$1; W=$2; OUT=${3:-$W/out}; S=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$S/../.." && pwd)
PY="python3 -I"
DEFS="$W/dl/wowdbdefs/definitions"; LIST="$W/dl/listfile/community-listfile.csv"

B=$(awk -F'|' 'NR==1{for(i=1;i<=NF;i++){split($i,h,"!");if(h[1]=="Version")v=i;if(h[1]=="Product")p=i};next} $p=="wowf"{print $v}' "$INST/.build.info")
[ -n "$B" ] || { echo "no wowf product in $INST/.build.info"; exit 1; }
echo "installed build: $B"
LIVE=$(curl -s https://us.version.battle.net/v2/products/wowf/versions | awk -F'|' '$1=="us"{print $6}')
echo "version server (us): $LIVE"
[ "$B" = "$LIVE" ] || echo "WARNING: install is not on the live build. Patch it first or treat output as stale."

mkdir -p "$W/dl/listfile" "$OUT"
if [ -d "$W/dl/wowdbdefs/.git" ]; then
  git -C "$W/dl/wowdbdefs" pull -q --ff-only || echo "WARNING: could not update WoWDBDefs"
else
  git clone -q --depth 1 https://github.com/wowdev/WoWDBDefs "$W/dl/wowdbdefs"
fi
[ -f "$LIST" ] || curl -sSfL -o "$LIST" https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv
grep -q "$B" "$DEFS/TraitNode.dbd" || echo "WARNING: WoWDBDefs has no definition for $B yet"

for loc in enUS deDE; do
  $PY "$S/extract_forever.py" "$S" "$INST" "$DEFS" "$LIST" "$OUT" $loc
done
$PY "$S/report.py" "$OUT/forever_${B}_all_enUS.json" "$OUT/forever_${B}_all_deDE.json" "$REPO/assets/images/icons" > "$OUT/report_$B.txt"
echo "wrote $OUT/forever_${B}_all_enUS.json, forever_${B}_all_deDE.json and report_$B.txt"
echo "Next: read the report, then run compare_wh.py against a freshly fetched Wowhead file and diff_extracts.py against the previous build's JSON."
