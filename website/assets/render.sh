#!/bin/bash
# Renders every asset in social.html (elements with data-file) to generated/*.png
# using headless Chrome. Usage: website/assets/render.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/social.html"
OUT="$DIR/generated"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

mkdir -p "$OUT"

perl -ne 'print "$1 $2 $3 $4\n" if /id="([^"]+)" data-file="([^"]+)" style="width:(\d+)px;height:(\d+)px/' "$SRC" |
while read -r id file w h; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --default-background-color=00000000 --virtual-time-budget=10000 \
    --window-size="$w,$h" --screenshot="$OUT/$file" \
    "file://$SRC?only=$id" >/dev/null 2>&1
  echo "$file (${w}x${h})"
done
