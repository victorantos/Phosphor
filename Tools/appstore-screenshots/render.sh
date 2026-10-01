#!/bin/bash
# Renders the App Store screenshots (iPhone 6.5" 1242x2688, iPad 13" 2064x2752) from the raw Simulator
# captures in raw/. Capture those with the debug-only screenshot mode:
#   SIMCTL_CHILD_PHOSPHOR_ASSUME_SUBSCRIBED=1 SIMCTL_CHILD_PHOSPHOR_SCREENSHOT=<screen> \
#     xcrun simctl launch --terminate-running-process <sim> com.nestclaw.phosphor
#   xcrun simctl io <sim> screenshot raw/<screen>.png
# with <screen> one of welcome, setup, lists, settings.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/out"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
mkdir -p "$OUT"
n=1
for shot in welcome setup lists settings; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=5000 \
    --window-size=1242,2688 --screenshot="$OUT/0$n-$shot.png" \
    "file://$DIR/template.html?shot=$shot" >/dev/null 2>&1
  echo "out/0$n-$shot.png"
  n=$((n+1))
done
# iPad 13" (2064x2752), from raw/ipad-<screen>.png captured on the iPad Pro 13-inch Simulator.
n=1
for shot in lists settings; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=5000 \
    --window-size=2064,2752 --screenshot="$OUT/ipad-0$n-$shot.png" \
    "file://$DIR/template.html?shot=$shot&device=ipad" >/dev/null 2>&1
  echo "out/ipad-0$n-$shot.png"
  n=$((n+1))
done
