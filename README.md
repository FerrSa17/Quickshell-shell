<p align="center">
  <img src="assets/screenshots/00-hero.png" alt="Quickshell-shell" width="100%"/>
</p>

<h1 align="center">Quickshell-shell</h1>

<p align="center">
  <b>Hyprland rice</b> with a polished <b>Quickshell</b> bar, lock screen, dashboard,<br/>
  plus <b>Kitty</b>, <b>Yazi</b>, <b>Fish</b> &amp; <b>Starship</b> — install, reboot, enjoy.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Arch-first-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch"/>
  <img src="https://img.shields.io/badge/Hyprland-Wayland-58E1A0?style=flat-square" alt="Hyprland"/>
  <img src="https://img.shields.io/badge/Quickshell-QML-C764FF?style=flat-square" alt="Quickshell"/>
</p>

---

## Preview

<p align="center">
  <img src="assets/screenshots/preview-desktop.png" alt="Desktop preview" width="100%"/>
</p>

| Layer | What you get |
|--------|----------------|
| **Hyprland** | Binds, autostart, decorations, window rules |
| **Quickshell** | Top bar, Control panel, dashboard, launcher, lock (no hyprlock), wallpapers + theme |
| **Kitty** | Terminal + wallpaper-linked colors |
| **Yazi** | File manager theme hooks |
| **Fish + Starship** | Shell + prompt (palette can follow wallpaper) |

> Wallpapers (~550 MB) ship as a **GitHub Release** asset — not inside the git clone — so the repo stays light.

---

## Requirements

- **Arch Linux** (recommended) with `sudo` + internet  
- Wayland session capable of running **Hyprland**  
- On other distros: install the same packages yourself, then use `./install.sh --configs-only`

Optional: [hyprglass](https://github.com/) via `hyprpm` (config already guards with `if hl.plugin.hyprglass`).

---

## Install (follow in order)

### 1) Clone

```bash
cd ~
git clone https://github.com/FerrSa17/Quickshell-shell.git
cd Quickshell-shell
```

### 2) Packages + configs + wallpapers

After you publish the wallpaper Release asset, set the URL (once):

```bash
export WALLPAPERS_URL="https://github.com/FerrSa17/Quickshell-shell/releases/latest/download/wallpapers.tar.zst"
```

Then:

```bash
./install.sh
```

What it does:

1. `pacman` installs Hyprland, Quickshell, Kitty, Yazi, Fish, Starship, awww, fonts, tools…  
2. Backs up existing `~/.config/{quickshell,hypr,kitty,yazi,fish,starship}`  
3. Copies rice configs in place  
4. Downloads & extracts wallpapers into `~/Wallpaper/{Light,Dark,Calm}`  
5. Offers to set **fish** as your login shell  

Step-by-step alternatives:

```bash
./install.sh --packages-only
./install.sh --configs-only
./install.sh --wallpapers-only
```

### 3) Reboot

```bash
systemctl reboot
```

Log into **Hyprland**. Quickshell starts from Hyprland autostart (bar + session lock).

---

## First minutes after reboot

| Action | Binding |
|--------|---------|
| Dashboard | `Super + A` |
| App launcher | `Super + W` |
| Power menu | `Super + P` |
| Screenshot | `Super + S` |
| Terminal | `Super + Return` |
| Control panel | gear on the bar |
| Shortcuts cheatsheet | Control → **Shortcuts** |

Unlock the lock screen with your **Linux user password** (PAM `login` — **hyprlock package not required**).

---

## Publishing wallpapers (maintainer)

On the machine that has `~/Wallpaper`:

```bash
./pack-wallpapers.sh
# → dist/wallpapers.tar.zst
```

Create a GitHub **Release** and upload `dist/wallpapers.tar.zst` as asset name:

```text
wallpapers.tar.zst
```

Then point installers at:

```text
https://github.com/FerrSa17/Quickshell-shell/releases/latest/download/wallpapers.tar.zst
```

For local testing without GitHub:

```bash
WALLPAPERS_URL="file://$HOME/Quickshell-shell/dist/wallpapers.tar.zst" ./install.sh --wallpapers-only
```

---

## Other distros

1. Install equivalents of the Arch packages listed in `install.sh` (`PAC_PKGS`).  
2. Run `./install.sh --configs-only`  
3. Fetch wallpapers with `WALLPAPERS_URL=... ./install.sh --wallpapers-only`  
4. Enable Hyprland in your display manager / `~/.bash_profile` as you usually do  

---

## Layout

```text
Quickshell-shell/
├── README.md
├── install.sh
├── pack-wallpapers.sh
├── assets/screenshots/
├── configs/
│   ├── quickshell/
│   ├── hypr/
│   ├── kitty/
│   ├── yazi/
│   ├── fish/
│   └── starship/
└── dist/                  # local wallpaper archive (gitignored)
```

---

## Notes

- Existing configs are copied to `~/.config-backup-quickshell-shell-<timestamp>/` before overwrite.  
- `colors.json` is generated at runtime from wallpapers — not shipped.  
- Brightness uses **ddcutil** (external monitors). Laptop backlight may need `brightnessctl` binds already in Hyprland.  
- Add more screenshots under `assets/screenshots/` anytime (`02-dashboard.png`, `03-lock.png`, …) and link them in this README.

---

<p align="center">
  <sub>Built for daily driving Arch + Hyprland. PRs and rice tweaks welcome.</sub>
</p>
