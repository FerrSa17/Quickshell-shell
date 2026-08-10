#!/usr/bin/env bash
# Generate Quickshell colors.json + Starship/Yazi palettes from a wallpaper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT="${SCRIPT_DIR}/extract-wallpaper-colors.py"
OUT="${HOME}/.config/quickshell/colors.json"
STARSHIP_APPLY="${HOME}/.config/starship/apply-colors.py"
YAZI_APPLY="${HOME}/.config/yazi/apply-wallpaper-theme.py"

IMG="${1:-}"
MODE="${2:-dark}"

if [ -z "$IMG" ]; then
  IMG="$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1 || true)"
fi

if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  echo "apply-wallpaper-theme: no image" >&2
  exit 0
fi

case "$MODE" in
  light|dark) ;;
  *) MODE=dark ;;
esac

python3 "$EXTRACT" "$IMG" "$MODE" "$OUT"
if [ -f "$STARSHIP_APPLY" ]; then
  # Animate in background so Quickshell theme can start in parallel.
  python3 "$STARSHIP_APPLY" "$IMG" >/dev/null 2>&1 &
fi
if [ -f "$YAZI_APPLY" ]; then
  python3 "$YAZI_APPLY" "$IMG" "$MODE" >/dev/null 2>&1 &
fi
