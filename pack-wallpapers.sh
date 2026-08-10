#!/usr/bin/env bash
# Pack ~/Wallpaper into dist/wallpapers.tar.zst for GitHub Release upload.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${WALLPAPERS_SRC:-$HOME/Wallpaper}"
OUT_DIR="$REPO_DIR/dist"
OUT="$OUT_DIR/wallpapers.tar.zst"

[[ -d "$SRC" ]] || { echo "Missing $SRC"; exit 1; }
mkdir -p "$OUT_DIR"

echo "Packing $SRC → $OUT"
# Archive so extract yields Light/ Dark/ Calm/ under Wallpaper/
tar --zstd -cf "$OUT" -C "$(dirname "$SRC")" "$(basename "$SRC")"
ls -lh "$OUT"
echo "Upload this file as a GitHub Release asset named: wallpapers.tar.zst"
