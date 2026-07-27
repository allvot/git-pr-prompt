#!/usr/bin/env bash
# Rasterize one of the assets/*.svg to a 2x PNG.
#
#   tools/svg2png.sh assets/presets-dark.svg
#
# Why a PNG at all, when the other assets stay SVG: the `nerdfont` preset's
# glyphs live in the Private Use Area, so SVG *text* only renders them for a
# reader who happens to have a Nerd Font installed — everyone else sees boxes,
# which is exactly the problem the image is meant to solve. Rasterizing here,
# on a machine that has the font, bakes the shapes in for every reader.
#
# Uses headless Chrome because it honors installed fonts and color emoji, and
# takes an exact viewport (qlmanage pads the output to a square).
set -euo pipefail

svg=${1:?usage: svg2png.sh <file.svg>}
png=${svg%.svg}.png

CHROME=${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}
[[ -x $CHROME ]] || {
  echo "svg2png: no Chrome at '$CHROME' — set CHROME=/path/to/chrome" >&2
  exit 1
}

# Viewport from the SVG's own width/height, so nothing is cropped or padded.
read -r w h < <(sed -n '1s/.*width="\([0-9]*\)".*height="\([0-9]*\)".*/\1 \2/p' "$svg")
[[ -n ${w:-} && -n ${h:-} ]] || { echo "svg2png: no width/height in $svg" >&2; exit 1; }

"$CHROME" --headless --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=2 --default-background-color=00000000 \
  --window-size="$w,$h" --screenshot="$png" "file://$(cd "$(dirname "$svg")" && pwd)/$(basename "$svg")" \
  >/dev/null 2>&1

echo "$png  ($((w * 2))x$((h * 2)))"
