#!/bin/sh
# Renders scene.html into ../demo.gif: 100 frames, 8 s loop. Needs Chrome and ImageMagick.
set -e
cd "$(dirname "$0")"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT=$(mktemp -d)
for i in $(seq 0 99); do
  t=$(echo "$i * 0.08" | bc)
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=2 --window-size=960,600 --virtual-time-budget=800 \
    --screenshot="$OUT/$(printf %03d "$i").png" "file://$PWD/scene.html#$t" 2>/dev/null
done
magick -delay 8 "$OUT"/*.png -resize 800x500 -loop 0 -layers Optimize -fuzz 1% -colors 160 ../demo.gif
echo "✓ Wrote assets/demo.gif (frames in $OUT)"
