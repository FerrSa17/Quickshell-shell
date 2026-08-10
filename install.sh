#!/usr/bin/env bash
# Quickshell-shell installer — Arch-first, backups configs, fetches wallpapers from Release.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="$REPO_DIR/configs"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.config-backup-quickshell-shell-$(date +%Y%m%d-%H%M%S)}"

# Override after first GitHub Release publish, e.g.:
#   https://github.com/<user>/Quickshell-shell/releases/latest/download/wallpapers.tar.zst
WALLPAPERS_URL="${WALLPAPERS_URL:-}"
WALLPAPERS_DIR="${WALLPAPERS_DIR:-$HOME/Wallpaper}"

PAC_PKGS=(
  hyprland
  quickshell
  kitty
  yazi
  fish
  starship
  awww
  grim
  slurp
  ddcutil
  playerctl
  wireplumber
  pipewire
  ttf-jetbrains-mono-nerd
  papirus-icon-theme
  python
  zoxide
  lsd
  bat
  duf
  fd
  btop
  git
  curl
  rsync
  zstd
)

AUR_PKGS=(
  # optional extras used by fish aliases / polish
  # wipeclean
)

log() { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

backup_path() {
  local src="$1"
  local name
  name="$(basename "$src")"
  if [[ -e "$src" || -L "$src" ]]; then
    mkdir -p "$BACKUP_ROOT"
    log "Backup $src → $BACKUP_ROOT/$name"
    rm -rf "$BACKUP_ROOT/$name"
    cp -a "$src" "$BACKUP_ROOT/$name"
  fi
}

install_arch_packages() {
  if ! command -v pacman >/dev/null 2>&1; then
    warn "Not Arch/pacman — install packages manually (see README), then re-run with --configs-only"
    return 0
  fi

  log "Installing packages with pacman (sudo)"
  sudo pacman -Syu --needed --noconfirm "${PAC_PKGS[@]}"

  if ((${#AUR_PKGS[@]})) && command -v yay >/dev/null 2>&1; then
    log "Installing AUR packages with yay"
    yay -S --needed --noconfirm "${AUR_PKGS[@]}"
  elif ((${#AUR_PKGS[@]})); then
    warn "AUR helper not found; skip: ${AUR_PKGS[*]}"
  fi
}

install_configs() {
  [[ -d "$CONFIGS" ]] || die "configs/ missing — run from repo root"

  mkdir -p "$HOME/.config" "$HOME/.local/state/quickshell" "$HOME/.cache/quickshell"

  local pairs=(
    "quickshell:$HOME/.config/quickshell"
    "hypr:$HOME/.config/hypr"
    "kitty:$HOME/.config/kitty"
    "yazi:$HOME/.config/yazi"
    "fish:$HOME/.config/fish"
    "starship:$HOME/.config/starship"
  )

  local pair name dest
  for pair in "${pairs[@]}"; do
    name="${pair%%:*}"
    dest="${pair#*:}"
    [[ -d "$CONFIGS/$name" ]] || die "Missing $CONFIGS/$name"
    backup_path "$dest"
    mkdir -p "$(dirname "$dest")"
    log "Install $name → $dest"
    mkdir -p "$dest"
    rsync -a --delete \
      --exclude '.git/' \
      --exclude '__pycache__/' \
      --exclude '*.pyc' \
      --exclude 'colors.json' \
      "$CONFIGS/$name/" "$dest/"
  done

  # fish: only ship config.fish (keep user's fish_variables if present)
  if [[ -f "$CONFIGS/fish/config.fish" ]]; then
    mkdir -p "$HOME/.config/fish"
    backup_path "$HOME/.config/fish/config.fish"
    cp -f "$CONFIGS/fish/config.fish" "$HOME/.config/fish/config.fish"
  fi
}

install_wallpapers() {
  mkdir -p "$WALLPAPERS_DIR"/{Light,Dark,Calm}

  if [[ -z "$WALLPAPERS_URL" ]]; then
    if [[ -f "$REPO_DIR/dist/wallpapers.tar.zst" ]]; then
      WALLPAPERS_URL="file://$REPO_DIR/dist/wallpapers.tar.zst"
    else
      warn "WALLPAPERS_URL not set and dist/wallpapers.tar.zst missing."
      warn "Pack with ./pack-wallpapers.sh, upload Release asset, then:"
      warn "  WALLPAPERS_URL=https://github.com/<USER>/Quickshell-shell/releases/latest/download/wallpapers.tar.zst ./install.sh --wallpapers-only"
      return 0
    fi
  fi

  local tmp archive
  tmp="$(mktemp -d)"
  archive="$tmp/wallpapers.tar.zst"
  log "Download wallpapers from $WALLPAPERS_URL"
  if [[ "$WALLPAPERS_URL" == file://* ]]; then
    cp "${WALLPAPERS_URL#file://}" "$archive"
  else
    curl -fL --progress-bar -o "$archive" "$WALLPAPERS_URL"
  fi
  log "Extract → $WALLPAPERS_DIR"
  tar --zstd -xf "$archive" -C "$WALLPAPERS_DIR" --strip-components=1 2>/dev/null \
    || tar --zstd -xf "$archive" -C "$WALLPAPERS_DIR"
  rm -rf "$tmp"
}

setup_shell() {
  if command -v fish >/dev/null 2>&1; then
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish)" ]]; then
      log "Set fish as login shell (may ask password)"
      chsh -s "$(command -v fish)" || warn "chsh failed — set shell manually"
    fi
  fi
}

print_next() {
  cat <<EOF

────────────────────────────────────────
Done. Backups (if any): $BACKUP_ROOT

Next:
  1) Log out / reboot
  2) Start Hyprland session
  3) Quickshell starts via hypr autostart (bar + lock)

Optional plugins: hyprglass via hyprpm (see configs/hypr/modules/plugins.lua)

If wallpapers were skipped, set WALLPAPERS_URL and run:
  ./install.sh --wallpapers-only
────────────────────────────────────────
EOF
}

usage() {
  cat <<EOF
Usage: ./install.sh [options]

  (default)          packages + configs + wallpapers
  --packages-only    only pacman packages
  --configs-only     only copy configs (backup first)
  --wallpapers-only  only fetch/extract wallpapers
  -h, --help         this help

Env:
  WALLPAPERS_URL   URL or file:// path to wallpapers.tar.zst
  WALLPAPERS_DIR   default: \$HOME/Wallpaper
EOF
}

main() {
  local mode=all
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --packages-only) mode=packages ;;
    --configs-only) mode=configs ;;
    --wallpapers-only) mode=wallpapers ;;
    "") mode=all ;;
    *) die "Unknown option: $1 (see --help)" ;;
  esac

  need_cmd rsync
  need_cmd curl

  case "$mode" in
    packages) install_arch_packages ;;
    configs) install_configs; setup_shell ;;
    wallpapers) install_wallpapers ;;
    all)
      install_arch_packages
      install_configs
      setup_shell
      install_wallpapers
      ;;
  esac

  print_next
}

main "$@"
