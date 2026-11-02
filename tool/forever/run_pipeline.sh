#!/bin/sh
# Rerun after any patch. Read-only on the install; writes only under <work>.
# usage: run_pipeline.sh <install> <work_dir>   (work_dir holds dl/ and out/, and stays outside the repo)
set -eu
INST=$1; W=$2; S=$(cd "$(dirname "$0")" && pwd)
B=$(awk -F'|' 'NR==2{print $13}' "$INST/.build.info")
echo "installed build: $B"
LIVE=$(curl -s https://us.version.battle.net/v2/products/wowf/versions | awk -F'|' '$1=="us"{print $6}')
echo "version server (us): $LIVE"
[ "$B" = "$LIVE" ] || echo "WARNING: install is not on the live build. Patch it first or treat output as stale."
git -C "$W/dl/wowdbdefs" pull -q --ff-only || echo "WARNING: could not update WoWDBDefs"
grep -q "$B" "$W/dl/wowdbdefs/definitions/TraitNode.dbd" || echo "WARNING: WoWDBDefs has no definition for $B yet"
PY="python3 -I"
for loc in enUS; do
  $PY "$S/extract_forever.py" "$S" "$INST" "$W/dl/wowdbdefs/definitions" "$W/dl/listfile/community-listfile.csv" "$W/out" $loc
done
echo "Next: compare_wh.py against a freshly fetched Wowhead file and diff_extracts.py against the previous build's JSON."
