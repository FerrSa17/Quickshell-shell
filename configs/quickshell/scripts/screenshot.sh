#!/usr/bin/env bash
# Capture screen via grim. Modes: area | full | window
# area [geometry] [radius] — geometry as "x,y WxH"; radius rounds PNG corners (ffmpeg)
set -euo pipefail

MODE="${1:-area}"
DIR="${HOME}/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="${DIR}/shot-$(date +%Y%m%d-%H%M%S).png"

save_and_copy() {
  local src="$1"
  cp "$src" "$FILE"
  wl-copy --type image/png < "$FILE"
}

round_corners() {
  local src="$1"
  local dst="$2"
  local r="$3"
  if [ "$r" -le 0 ]; then
    cp "$src" "$dst"
    return
  fi
  ffmpeg -hide_banner -loglevel error -y -i "$src" -update true -frames:v 1 \
    -filter_complex "format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='if(gt(abs(W/2-X),W/2-${r})*gt(abs(H/2-Y),H/2-${r}),if(lte(hypot(${r}-(W/2-abs(W/2-X)),${r}-(H/2-abs(H/2-Y))),${r}),alpha(X,Y),0),alpha(X,Y))'" \
    "$dst"
}

case "$MODE" in
  area)
    GEO="${2:-}"
    RADIUS="${3:-0}"
    if [ -z "$GEO" ]; then
      GEO="$(slurp)" || exit 0
    fi
    TMP="$(mktemp --suffix=.png)"
    ROUND="$(mktemp --suffix=.png)"
    trap 'rm -f "$TMP" "$ROUND"' EXIT
    grim -g "$GEO" "$TMP"
    round_corners "$TMP" "$ROUND" "$RADIUS"
    save_and_copy "$ROUND"
    ;;
  full)
    grim - | tee "$FILE" | wl-copy --type image/png
    ;;
  window)
    GEO="$(hyprctl activewindow -j | python3 -c '
import json, sys
w = json.load(sys.stdin)
if not w or "at" not in w:
    sys.exit(1)
print("%d,%d %dx%d" % (w["at"][0], w["at"][1], w["size"][0], w["size"][1]))
')" || exit 0
    grim -g "$GEO" - | tee "$FILE" | wl-copy --type image/png
    ;;
  *)
    echo "usage: $0 area [geometry] [radius] | full | window" >&2
    exit 2
    ;;
esac
