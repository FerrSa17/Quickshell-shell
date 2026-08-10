#!/usr/bin/env python3
"""Extract wallpaper colors and write ~/.config/starship/starship.toml.

Keeps the existing powerline layout; only the hex palette changes.
Image source: CLI arg, else current awww wallpaper.
Decoder: GdkPixbuf (no Pillow).

On theme change, morphs colors over ~1.4s (matches Quickshell/awww fade)
and nudges open fish sessions to repaint each frame.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

DIR = Path.home() / ".config" / "starship"
OUT = DIR / "starship.toml"
PALETTE_JSON = DIR / "palette.json"
TOKEN = DIR / ".anim_token"

# Match Quickshell Theme.qml color transition (~awww fade).
ANIM_DURATION = 1.4
ANIM_FRAMES = 28
PALETTE_KEYS = (
    "os_bg",
    "os_fg",
    "dir_bg",
    "dir_fg",
    "git_bg",
    "lang_bg",
    "time_bg",
    "accent",
    "time_fg",
)


def clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if x < lo else hi if x > hi else x


def rgb_to_hex(r: float, g: float, b: float) -> str:
    def byte(v: float) -> int:
        return max(0, min(255, int(round(v * 255.0))))

    return f"#{byte(r):02x}{byte(g):02x}{byte(b):02x}"


def hex_to_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return (
        int(h[0:2], 16) / 255.0,
        int(h[2:4], 16) / 255.0,
        int(h[4:6], 16) / 255.0,
    )


def rgb_to_hsl(r: float, g: float, b: float) -> tuple[float, float, float]:
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2.0
    if mx == mn:
        return 0.0, 0.0, l
    d = mx - mn
    s = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        h = (g - b) / d + (6.0 if g < b else 0.0)
    elif mx == g:
        h = (b - r) / d + 2.0
    else:
        h = (r - g) / d + 4.0
    return (h / 6.0) % 1.0, s, l


def hsl_to_rgb(h: float, s: float, l: float) -> tuple[float, float, float]:
    if s <= 1e-9:
        return l, l, l

    def hue2rgb(p: float, q: float, t: float) -> float:
        if t < 0:
            t += 1
        if t > 1:
            t -= 1
        if t < 1 / 6:
            return p + (q - p) * 6 * t
        if t < 1 / 2:
            return q
        if t < 2 / 3:
            return p + (q - p) * (2 / 3 - t) * 6
        return p

    q = l * (1 + s) if l < 0.5 else l + s - l * s
    p = 2 * l - q
    return (
        hue2rgb(p, q, h + 1 / 3),
        hue2rgb(p, q, h),
        hue2rgb(p, q, h - 1 / 3),
    )


def mix(
    a: tuple[float, float, float], b: tuple[float, float, float], t: float
) -> tuple[float, float, float]:
    t = clamp(t)
    return (
        a[0] * (1 - t) + b[0] * t,
        a[1] * (1 - t) + b[1] * t,
        a[2] * (1 - t) + b[2] * t,
    )


def rel_luma(r: float, g: float, b: float) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def tone(
    rgb: tuple[float, float, float], s: float | None = None, l: float | None = None
) -> tuple[float, float, float]:
    h, cs, cl = rgb_to_hsl(*rgb)
    if s is not None:
        cs = clamp(s)
    if l is not None:
        cl = clamp(l)
    return hsl_to_rgb(h, cs, cl)


def contrast_on(bg: tuple[float, float, float]) -> tuple[float, float, float]:
    return (0.08, 0.09, 0.09) if rel_luma(*bg) > 0.55 else (0.93, 0.93, 0.92)


def smoothstep(t: float) -> float:
    t = clamp(t)
    return t * t * (3.0 - 2.0 * t)


def load_pixels(path: str, size: int = 64) -> list[tuple[float, float, float]]:
    import gi

    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import GdkPixbuf

    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, size, size, True)
    if pb is None:
        raise RuntimeError(f"failed to load image: {path}")

    w, h = pb.get_width(), pb.get_height()
    n = pb.get_n_channels()
    rowstride = pb.get_rowstride()
    data = bytes(pb.get_pixels())
    out: list[tuple[float, float, float]] = []
    for y in range(h):
        row = y * rowstride
        for x in range(w):
            i = row + x * n
            out.append((data[i] / 255.0, data[i + 1] / 255.0, data[i + 2] / 255.0))
    return out


def score_pixel(rgb: tuple[float, float, float]) -> float:
    h, s, l = rgb_to_hsl(*rgb)
    if l < 0.08 or l > 0.92:
        return 0.0
    if s < 0.08:
        return s * 0.15
    return s * (1.0 - abs(l - 0.45) * 1.4)


def quantize(pixels: list[tuple[float, float, float]], buckets: int = 24):
    acc = [[0.0, 0.0, 0.0, 0.0] for _ in range(buckets)]
    for rgb in pixels:
        sc = score_pixel(rgb)
        if sc <= 0:
            sc = 0.05
        h, s, _l = rgb_to_hsl(*rgb)
        bi = int(h * buckets) % buckets
        w = sc * (0.35 + s)
        acc[bi][0] += rgb[0] * w
        acc[bi][1] += rgb[1] * w
        acc[bi][2] += rgb[2] * w
        acc[bi][3] += w

    colors = []
    for r, g, b, w in acc:
        if w < 1e-6:
            continue
        rgb = (r / w, g / w, b / w)
        h, s, l = rgb_to_hsl(*rgb)
        colors.append(
            {
                "rgb": rgb,
                "h": h,
                "s": s,
                "l": l,
                "w": w,
                "score": w * (0.4 + s),
            }
        )
    colors.sort(key=lambda c: c["score"], reverse=True)
    return colors


def pick_primary(colors):
    if not colors:
        return {
            "rgb": (0.46, 0.62, 0.94),
            "h": 0.62,
            "s": 0.55,
            "l": 0.55,
            "w": 1,
            "score": 1,
        }
    for c in colors:
        if c["s"] >= 0.12:
            return c
    return colors[0]


def build_starship_palette(pixels: list[tuple[float, float, float]]) -> dict[str, str]:
    colors = quantize(pixels)
    primary_c = pick_primary(colors)
    primary = tone(
        primary_c["rgb"],
        s=clamp(primary_c["s"] * 1.2 + 0.08, 0.25, 0.85),
        l=clamp(primary_c["l"], 0.38, 0.68),
    )

    ar = sum(p[0] for p in pixels) / max(1, len(pixels))
    ag = sum(p[1] for p in pixels) / max(1, len(pixels))
    ab = sum(p[2] for p in pixels) / max(1, len(pixels))
    avg = (ar, ag, ab)
    base = mix(avg, (0.07, 0.08, 0.10), 0.78)

    os_bg = tone(primary, s=clamp(primary_c["s"] * 0.45 + 0.12, 0.18, 0.55), l=0.78)
    dir_bg = tone(primary, s=clamp(primary_c["s"] * 1.05 + 0.05, 0.3, 0.8), l=0.58)
    git_bg = tone(mix(base, primary, 0.22), s=0.22, l=0.28)
    lang_bg = tone(mix(base, primary, 0.14), s=0.14, l=0.18)
    time_bg = tone(mix(base, primary, 0.08), s=0.10, l=0.13)

    os_fg = contrast_on(os_bg)
    dir_fg = contrast_on(dir_bg)
    accent_on_dark = tone(
        dir_bg, s=clamp(primary_c["s"] * 0.9 + 0.1, 0.35, 0.75), l=0.62
    )
    time_fg = tone(os_bg, s=0.25, l=0.72)

    return {
        "os_bg": rgb_to_hex(*os_bg),
        "os_fg": rgb_to_hex(*os_fg),
        "dir_bg": rgb_to_hex(*dir_bg),
        "dir_fg": rgb_to_hex(*dir_fg),
        "git_bg": rgb_to_hex(*git_bg),
        "lang_bg": rgb_to_hex(*lang_bg),
        "time_bg": rgb_to_hex(*time_bg),
        "accent": rgb_to_hex(*accent_on_dark),
        "time_fg": rgb_to_hex(*time_fg),
    }


def render_toml(p: dict[str, str]) -> str:
    return f"""\
"$schema" = 'https://starship.rs/config-schema.json'

# Auto-generated by ~/.config/starship/apply-colors.py — do not edit colors by hand.
# Re-run that script (or change wallpaper) to refresh the palette.

format = \"\"\"
[]({p['os_bg']})\\
$os\\
[](bg:{p['dir_bg']} fg:{p['os_bg']})\\
$directory\\
[](fg:{p['dir_bg']} bg:{p['git_bg']})\\
$git_branch\\
$git_status\\
[](fg:{p['git_bg']} bg:{p['lang_bg']})\\
$package\\
$nodejs\\
$bun\\
$python\\
$rust\\
$golang\\
$php\\
[](fg:{p['lang_bg']} bg:{p['time_bg']})\\
$time\\
[ ](fg:{p['time_bg']})\\
\\n$status$character\"\"\"

right_format = \"\"\"$cmd_duration\"\"\"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[status]
disabled = false
symbol = "󰅗"
style = "bold red"
format = "[$symbol $status ]($style)"

[directory]
style = "fg:{p['dir_fg']} bg:{p['dir_bg']}"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "󰈙 "
"Downloads" = " "
"Music" = " "
"Pictures" = " "

[git_branch]
symbol = ""
style = "bg:{p['git_bg']}"
format = '[[ $symbol $branch ](fg:{p['accent']} bg:{p['git_bg']})]($style)'

[git_status]
style = "bg:{p['git_bg']}"
format = '[[($all_status$ahead_behind )](fg:{p['accent']} bg:{p['git_bg']})]($style)'

[package]
symbol = "󰏗"
style = "bg:{p['lang_bg']}"
format = '[[ $symbol $version ](fg:{p['accent']} bg:{p['lang_bg']})]($style)'

[nodejs]
symbol = ""
style = "bg:{p['lang_bg']}"
format = '[[ $symbol ($version) ](fg:{p['accent']} bg:{p['lang_bg']})]($style)'

[bun]
symbol = ""
style = "bg:{p['lang_bg']}"
format = '[[ $symbol ($version) ](fg:{p['accent']} bg:{p['lang_bg']})]($style)'

[python]
symbol = ""
style = "bg:{p['lang_bg']}"
format = '[[ $symbol ($version)(\\($virtualenv\\)) ](fg:{p['accent']} bg:{p['lang_bg']})]($style)'
detect_extensions = ["py", "ipynb"]
detect_files = [
  "requirements.txt",
  "pyproject.toml",
  ".python-version",
  "Pipfile",
  "tox.ini",
  "setup.py",
  "__init__.py",
]
detect_folders = [".venv", "venv"]

[rust]
symbol = ""
style = "bg:{p['lang_bg']}"
format = '[[ $symbol ($version) ](fg:{p['accent']} bg:{p['lang_bg']})]($style)'

[golang]
symbol = ""
style = "bg:{p['lang_bg']}"
format = '[[ $symbol ($version) ](fg:{p['accent']} bg:{p['lang_bg']})]($style)'

[php]
symbol = ""
style = "bg:{p['lang_bg']}"
format = '[[ $symbol ($version) ](fg:{p['accent']} bg:{p['lang_bg']})]($style)'

[time]
disabled = false
time_format = "%R"
style = "bg:{p['time_bg']}"
format = '[[  $time ](fg:{p['time_fg']} bg:{p['time_bg']})]($style)'

[cmd_duration]
min_time = 500
show_milliseconds = false
style = "fg:{p['accent']}"
format = "[](fg:{p['time_bg']})[  $duration ](fg:{p['time_fg']} bg:{p['time_bg']})[](fg:{p['time_bg']})"

[os]
style = "bg:{p['os_bg']} fg:{p['os_fg']}"
format = "[ $symbol ]($style)"
disabled = false

[os.symbols]
Windows = "󰍲"
Ubuntu = "󰕈"
SUSE = ""
Raspbian = "󰐿"
Mint = "󰣭"
Macos = "󰀵"
Manjaro = ""
Linux = "󰌽"
Gentoo = "󰣨"
Fedora = "󰣛"
Alpine = ""
Amazon = ""
Android = ""
AOSC = ""
Arch = "󰣇"
Artix = "󰣇"
EndeavourOS = ""
CentOS = ""
Debian = "󰣚"
Redhat = "󱄛"
RedHatEnterprise = "󱄛"
Pop = ""
"""


def current_wallpaper() -> str:
    try:
        out = subprocess.check_output(
            ["awww", "query"], text=True, stderr=subprocess.DEVNULL
        )
    except Exception:
        return ""
    for line in out.splitlines():
        if "image:" in line:
            return line.split("image:", 1)[1].strip()
    return ""


def load_saved_palette() -> dict[str, str] | None:
    if PALETTE_JSON.is_file():
        try:
            data = json.loads(PALETTE_JSON.read_text(encoding="utf-8"))
            if all(k in data for k in PALETTE_KEYS):
                return {k: str(data[k]) for k in PALETTE_KEYS}
        except Exception:
            pass
    if not OUT.is_file():
        return None
    text = OUT.read_text(encoding="utf-8")
    # Fall back: scrape first occurrence of each role from generated toml.
    found: dict[str, str] = {}
    patterns = {
        "os_bg": r"\[\]\((#[0-9a-fA-F]{6})\)",
        "dir_bg": r"bg:(#[0-9a-fA-F]{6}) fg:#[0-9a-fA-F]{6}\)\\?\s*\$directory",
        "git_bg": r"fg:#[0-9a-fA-F]{6} bg:(#[0-9a-fA-F]{6})\)\\?\s*\$git_branch",
        "lang_bg": r"fg:#[0-9a-fA-F]{6} bg:(#[0-9a-fA-F]{6})\)\\?\s*\$nodejs",
        "time_bg": r"fg:#[0-9a-fA-F]{6} bg:(#[0-9a-fA-F]{6})\)\\?\s*\$time",
        "dir_fg": r'\[directory\]\s*style = "fg:(#[0-9a-fA-F]{6})',
        "os_fg": r'\[os\]\s*style = "bg:#[0-9a-fA-F]{6} fg:(#[0-9a-fA-F]{6})',
        "accent": r"\$symbol \$branch \]\(fg:(#[0-9a-fA-F]{6})",
        "time_fg": r" \$time \]\(fg:(#[0-9a-fA-F]{6})",
    }
    for key, pat in patterns.items():
        m = re.search(pat, text, re.MULTILINE)
        if m:
            found[key] = m.group(1).lower()
    if all(k in found for k in PALETTE_KEYS):
        return found
    return None


def save_palette(pal: dict[str, str]) -> None:
    PALETTE_JSON.write_text(
        json.dumps(pal, indent=2) + "\n", encoding="utf-8"
    )


def lerp_palette(a: dict[str, str], b: dict[str, str], t: float) -> dict[str, str]:
    t = smoothstep(t)
    out: dict[str, str] = {}
    for k in PALETTE_KEYS:
        out[k] = rgb_to_hex(*mix(hex_to_rgb(a[k]), hex_to_rgb(b[k]), t))
    return out


def write_toml(path: Path, pal: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render_toml(pal), encoding="utf-8")


def notify_fish_repaint(session: subprocess.Popen | None = None) -> subprocess.Popen | None:
    """Bump fish universal var so open sessions repaint.

    Reuses a single long-lived `fish` stdin session during an animation so we
    do not pay process-startup cost on every frame.
    """
    rev = str(time.time_ns())
    if session is not None and session.poll() is None and session.stdin is not None:
        try:
            session.stdin.write(rev + "\n")
            session.stdin.flush()
            return session
        except Exception:
            try:
                session.kill()
            except Exception:
                pass
            session = None

    try:
        session = subprocess.Popen(
            [
                "fish",
                "-c",
                "while read -l rev; set -U __starship_palette_rev $rev; end",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        assert session.stdin is not None
        session.stdin.write(rev + "\n")
        session.stdin.flush()
        return session
    except Exception:
        return None


def close_notify_session(session: subprocess.Popen | None) -> None:
    if session is None:
        return
    try:
        if session.stdin is not None:
            session.stdin.close()
        session.wait(timeout=0.5)
    except Exception:
        try:
            session.kill()
        except Exception:
            pass


def new_anim_token() -> str:
    token = f"{time.time_ns()}:{os.getpid()}"
    TOKEN.write_text(token, encoding="utf-8")
    return token


def anim_token_ok(token: str) -> bool:
    try:
        return TOKEN.read_text(encoding="utf-8").strip() == token
    except Exception:
        return False


def apply_palette(
    path: Path, pal: dict[str, str], *, animate_from: dict[str, str] | None
) -> None:
    if not animate_from or animate_from == pal:
        new_anim_token()  # cancel any in-flight morph
        write_toml(path, pal)
        save_palette(pal)
        session = notify_fish_repaint()
        close_notify_session(session)
        return

    token = new_anim_token()
    frame_dt = ANIM_DURATION / max(1, ANIM_FRAMES - 1)
    t0 = time.monotonic()
    session: subprocess.Popen | None = None

    try:
        for i in range(ANIM_FRAMES):
            if not anim_token_ok(token):
                return
            t = i / max(1, ANIM_FRAMES - 1)
            frame = lerp_palette(animate_from, pal, t)
            write_toml(path, frame)
            session = notify_fish_repaint(session)
            if i + 1 < ANIM_FRAMES:
                target = t0 + (i + 1) * frame_dt
                delay = target - time.monotonic()
                if delay > 0:
                    time.sleep(delay)

        if not anim_token_ok(token):
            return
        write_toml(path, pal)
        save_palette(pal)
        session = notify_fish_repaint(session)
    finally:
        close_notify_session(session)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", nargs="?", help="Wallpaper path (default: awww)")
    parser.add_argument(
        "output",
        nargs="?",
        default=str(OUT),
        help=f"Output starship.toml (default: {OUT})",
    )
    parser.add_argument(
        "--instant",
        "-i",
        action="store_true",
        help="Skip color morph animation",
    )
    args = parser.parse_args()

    img = args.image or current_wallpaper()
    out_path = Path(args.output).expanduser()

    if not img or not os.path.isfile(img):
        print(f"apply-colors: no image ({img!r})", file=sys.stderr)
        return 0

    try:
        pixels = load_pixels(img, 64)
        pal = build_starship_palette(pixels)
    except Exception as e:
        print(f"apply-colors: {e}", file=sys.stderr)
        return 1

    DIR.mkdir(parents=True, exist_ok=True)
    prev = None if args.instant else load_saved_palette()
    apply_palette(out_path, pal, animate_from=None if args.instant else prev)

    print(out_path)
    for k, v in pal.items():
        print(f"  {k}: {v}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
