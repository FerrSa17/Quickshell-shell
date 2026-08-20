# Quickshell-shell rice repository

## Goal

Public-ready monorepo with Hyprland + Quickshell + kitty + yazi + fish + starship.
Arch install via `./install.sh`: packages, services, configs, wallpapers from GitHub Release.

## Layout

```
Quickshell-shell/
  README.md
  install.sh
  configs/
    quickshell/   # includes scripts/ (bt-pair, wallpaper theme, screenshot, …)
    hypr/
    kitty/
    yazi/
    fish/
    starship/
  assets/screenshots/
  pack-wallpapers.sh
```

## Install flow

1. Clone repo
2. `./install.sh` (packages + NetworkManager/bluetooth + configs + wallpapers)
3. Reboot → Hyprland autostarts `qs` + lock

## Runtime deps (beyond Hyprland/qs)

- cliphist + wl-clipboard — clipboard history on the bar  
- NetworkManager (`nmcli`) — Wi‑Fi Control panel  
- bluez / bluez-utils + python-dbus + python-gobject — Bluetooth + PIN pair agent  
- awww — wallpapers; apply-wallpaper-theme.sh builds colors.json  

## Wallpapers

Not in git. `pack-wallpapers.sh` → upload `wallpapers.tar.zst` as Release asset.
`install.sh` defaults `WALLPAPERS_URL` to this repo’s latest release download URL.
