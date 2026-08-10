# Quickshell-shell rice repository

## Goal

Public-ready monorepo at `~/Quickshell-shell` with Hyprland + Quickshell + kitty + yazi + fish + starship, Arch install steps, wallpapers via GitHub Release download.

## Layout

```
Quickshell-shell/
  README.md
  install.sh
  configs/
    quickshell/
    hypr/
    kitty/
    yazi/
    fish/
    starship/
  assets/screenshots/
  pack-wallpapers.sh   # builds wallpapers.tar.zst for Release
```

## Install flow

1. Clone repo
2. Run numbered commands from README / `./install.sh`
3. Script: packages, backup configs, copy configs, download wallpapers to `~/Wallpaper`
4. Reboot → Hyprland autostarts qs + lock

## Wallpapers

Not in git. `pack-wallpapers.sh` → upload `wallpapers.tar.zst` as Release asset `wallpapers`.
`install.sh` downloads from `WALLPAPERS_URL` (default GitHub release URL template).
