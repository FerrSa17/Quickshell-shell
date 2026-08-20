#!/usr/bin/env bash
# Quickshell-shell installer — Arch-first, backups configs, fetches wallpapers from Release.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="$REPO_DIR/configs"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.config-backup-quickshell-shell-$(date +%Y%m%d-%H%M%S)}"

# Default: GitHub Release asset from this repo.
WALLPAPERS_URL="${WALLAPERS_URL:-https://github.com/FerrSa17/Quickshell-shell/releases/latest/download/wallpapers.tar.zst}"
WALLPAPERS_DIR="${WALLPAPERS_DIR:-$HOME/Wallpaper}"

PAC_PKGS=(
  # Desktop / shell
  hyprland
  quickshell
  kitty
  yazi
  fish
  starship
  awww
  # Capture / clipboard
  grim
  slurp
  wl-clipboard
  cliphist
  file
  # Network / Bluetooth (Control panel Wi‑Fi & BT)
  networkmanager
  bluez
  bluez-utils
  # Audio / media / brightness
  pipewire
  wireplumber
  playerctl
  brightnessctl
  ddcutil
  # Theming / icons / fonts / cursors deps
  ttf-jetbrains-mono-nerd
  papirus-icon-theme
  gdk-pixbuf2
  # Python stack used by scripts (wallpaper colors, BT pair agent)
  python
  python-dbus
  python-gobject
  # CLI helpers
  jq
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
  bibata-cursor-theme-bin
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
  elif ((${#AUR_PKGS[@]})) && command -v paru >/dev/null 2>&1; then
    log "Installing AUR packages with paru"
    paru -S --needed --noconfirm "${AUR_PKGS[@]}"
  elif ((${#AUR_PKGS[@]})); then
    warn "AUR helper not found; skip: ${AUR_PKGS[*]}"
    warn "Install Bibata cursors manually or install yay/paru and re-run --packages-only"
  fi
}

enable_services() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return 0
  fi
  log "Enable NetworkManager + bluetooth (sudo)"
  sudo systemctl enable --now NetworkManager.service 2>/dev/null || warn "Could not enable NetworkManager"
  sudo systemctl enable --now bluetooth.service 2>/dev/null || warn "Could not enable bluetooth"
}

install_configs() {
  [[ -d "$CONFIGS" ]] || die "configs/ missing — run from repo root"

  mkdir -p "$HOME/.config" "$HOME/.local/state/quickshell" "$HOME/.cache/quickshell"

  # Full-tree installs (rsync --delete keeps rice clean).
  local pairs=(
    "quickshell:$HOME/.config/quickshell"
    "hypr:$HOME/.config/hypr"
    "kitty:$HOME/.config/kitty"
    "yazi:$HOME/.config/yazi"
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
      --exclude '.backup*/' \
      --exclude '.restored*/' \
      "$CONFIGS/$name/" "$dest/"
  done

  # fish: only ship config.fish — never wipe fish_variables / functions
  if [[ -f "$CONFIGS/fish/config.fish" ]]; then
    mkdir -p "$HOME/.config/fish"
    backup_path "$HOME/.config/fish/config.fish"
    log "Install fish/config.fish"
    cp -f "$CONFIGS/fish/config.fish" "$HOME/.config/fish/config.fish"
  fi

  # Ensure helper scripts are executable
  if [[ -d "$HOME/.config/quickshell/scripts" ]]; then
    chmod +x "$HOME/.config/quickshell/scripts/"*.sh 2>/dev/null || true
    chmod +x "$HOME/.config/quickshell/scripts/"*.py 2>/dev/null || true
  fi
  if [[ -f "$HOME/.config/starship/apply-colors.py" ]]; then
    chmod +x "$HOME/.config/starship/apply-colors.py"
  fi
  if [[ -f "$HOME/.config/yazi/apply-wallpaper-theme.py" ]]; then
    chmod +x "$HOME/.config/yazi/apply-wallpaper-theme.py"
  fi
}

install_wallpapers() {
  mkdir -p "$WALLPAPERS_DIR"/{Light,Dark,Calm}

  local url="$WALLPAPERS_URL"
  if [[ -z "$url" ]]; then
    if [[ -f "$REPO_DIR/dist/wallpapers.tar.zst" ]]; then
      url="file://$REPO_DIR/dist/wallpapers.tar.zst"
    else
      warn "WALLPAPERS_URL empty and dist/wallpapers.tar.zst missing."
      return 0
    fi
  fi

  # Prefer local archive when present (offline / maintainer test).
  if [[ -f "$REPO_DIR/dist/wallpapers.tar.zst" && "$url" == https://* ]]; then
    warn "Using local dist/wallpapers.tar.zst instead of remote URL"
    url="file://$REPO_DIR/dist/wallpapers.tar.zst"
  fi

  local tmp archive
  tmp="$(mktemp -d)"
  archive="$tmp/wallpapers.tar.zst"
  log "Download wallpapers from $url"
  if [[ "$url" == file://* ]]; then
    cp "${url#file://}" "$archive"
  else
    curl -fL --progress-bar -o "$archive" "$url" \
      || die "Wallpaper download failed. Set WALLPAPERS_URL or place dist/wallpapers.tar.zst"
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

verify_install() {
  log "Quick self-check"
  local missing=0
  local f
  for f in \
    "$HOME/.config/quickshell/shell.qml" \
    "$HOME/.config/quickshell/Bar.qml" \
    "$HOME/.config/quickshell/NetRadio.qml" \
    "$HOME/.config/quickshell/BtRadio.qml" \
    "$HOME/.config/quickshell/ClipboardHistory.qml" \
    "$HOME/.config/quickshell/scripts/bt-pair.py" \
    "$HOME/.config/quickshell/scripts/apply-wallpaper-theme.sh" \
    "$HOME/.config/hypr/hyprland.lua" \
    "$HOME/.config/hypr/modules/autostart.lua"
  do
    if [[ ! -e "$f" ]]; then
      warn "Missing: $f"
      missing=1
    fi
  done

  for f in qs awww grim slurp wl-copy cliphist nmcli bluetoothctl python3; do
    if ! command -v "$f" >/dev/null 2>&1; then
      warn "Command not on PATH: $f"
      missing=1
    fi
  done

  if ((missing == 0)); then
    log "Self-check OK"
  else
    warn "Self-check found gaps — see warnings above"
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

Features on the bar Control panel:
  Wi‑Fi / Bluetooth / clipboard history / wallpapers / shortcuts

Optional plugins: hyprglass via hyprpm (see configs/hypr/modules/plugins.lua)

If wallpapers were skipped, set WALLPAPERS_URL and run:
  ./install.sh --wallpapers-only
────────────────────────────────────────
EOF
}

usage() {
  cat <<EOF
Usage: ./install.sh [options]

  (default)          packages + services + configs + wallpapers
  --packages-only    only pacman/AUR packages (+ enable services)
  --configs-only     only copy configs (backup first)
  --wallpapers-only  only fetch/extract wallpapers
  -h, --help         this help

Env:
  WALLPAPERS_URL   URL or file:// path to wallpapers.tar.zst
                  (default: GitHub latest release asset)
  WALLPAPERS_DIR   default: \$HOME/Wallpaper
  BACKUP_ROOT     where existing configs are copied before overwrite
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
    packages)
      install_arch_packages
      enable_services
      ;;
    configs)
      install_configs
      setup_shell
      verify_install
      ;;
    wallpapers)
      install_wallpapers
      ;;
    all)
      install_arch_packages
      enable_services
      install_configs
      setup_shell
      install_wallpapers
      verify_install
      ;;
  esac

  print_next
}

main "$@"
