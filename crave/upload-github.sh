#!/bin/bash
# Upload build outputs from a Crave build node to a new GitHub pre-release.
# WHY: `crave pull` cannot reach Crave's transfer tunnel from Shade's network, and Crave
# clears out/ after a job; so the build job uploads its own outputs before it ends.
# Usage: GH_TOKEN=... BRANCH=<branch> bash upload-github.sh <tag-prefix> <file>...
# GH_TOKEN: fine-grained token with Contents read/write on $REPO.
REPO=${REPO:-Shaheddan/android_device_huawei_hwjdn}
BRANCH=${BRANCH:-main}
API=${API:-https://api.github.com}
UPLOADS=${UPLOADS:-https://uploads.github.com}
PREFIX=$1
shift

[ -n "${GH_TOKEN:-}" ] || { echo "!! GH_TOKEN is not set"; exit 1; }
[ -n "$PREFIX" ] && [ $# -gt 0 ] || { echo "!! usage: upload-github.sh <tag-prefix> <file>..."; exit 1; }
for f in "$@"; do
  [ -f "$f" ] || { echo "!! missing file: $f"; exit 1; }
done

# Date and time in the tag, so two builds on the same day get separate releases.
TAG=$PREFIX-$(date -u +%Y%m%d-%H%M)
SUMS=/tmp/$TAG-SHA256SUMS.txt
: > "$SUMS"
for f in "$@"; do
  ls -la "$f"
  ( cd "$(dirname "$f")" && sha256sum "$(basename "$f")" ) >> "$SUMS"
done
cat "$SUMS"

AUTH=(-H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
json() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$1') or '')"; }

BODY=$(python3 -c "import json,sys; print(json.dumps({'tag_name': sys.argv[1], 'target_commitish': sys.argv[2], 'name': sys.argv[1], 'prerelease': True, 'body': 'Test build from branch ' + sys.argv[2] + ', built on crave.io. Not for daily use.'}))" "$TAG" "$BRANCH")
RESP=$(curl -sS "${AUTH[@]}" -X POST "$API/repos/$REPO/releases" -d "$BODY")
ID=$(echo "$RESP" | json id)
[ -n "$ID" ] || { echo "!! could not create release: $RESP"; exit 1; }
echo "release $TAG (id $ID)"

for f in "$@" "$SUMS"; do
  echo "uploading $(basename "$f") ($(stat -c %s "$f") bytes) ..."
  # -T streams the file instead of loading it into memory.
  RESP=$(curl -sS "${AUTH[@]}" -X POST -H "Content-Type: application/octet-stream" \
    -T "$f" "$UPLOADS/repos/$REPO/releases/$ID/assets?name=$(basename "$f")")
  URL=$(echo "$RESP" | json browser_download_url)
  [ -n "$URL" ] || { echo "!! upload failed: $RESP"; exit 1; }
  echo "DOWNLOAD: $URL"
done
