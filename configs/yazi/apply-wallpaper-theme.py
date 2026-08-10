#!/usr/bin/env python3
"""Extract wallpaper colors and write ~/.config/yazi/theme.toml.

Own extractor (GdkPixbuf, no Pillow/wallust). Image: CLI arg, else awww.
On theme change, morphs colors over ~1.4s (matches Quickshell/awww/Starship fade),
then tells open Yazi instances to reload via `ya emit-to 0 app:theme`.

Usage:
  python3 apply-wallpaper-theme.py [IMAGE] [dark|light]
  python3 apply-wallpaper-theme.py [IMAGE] [dark|light] --instant
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

DIR = Path.home() / ".config" / "yazi"
OUT = DIR / "theme.toml"
PALETTE_JSON = DIR / "palette.json"
TOKEN = DIR / ".anim_token"
ICON_BASE = DIR / "icon-base.toml"

_HEX_FG_RE = re.compile(r'(fg\s*=\s*")(#[0-9a-fA-F]{6})(")')
_ICON_BASE_CACHE: str | None = None
_ICON_UNIQUE_HEXES: list[str] | None = None
_YAZI_LIVE: bool | None = None

ANIM_DURATION = 1.0
ANIM_FRAMES = 16
# Default icon theme is Material-ish cyan/blue; rotate relative to wallpaper accent.
_ICON_REF_HUE = 0.58

PALETTE_KEYS = (
    "bg",
    "surface",
    "surface2",
    "overlay",
    "fg",
    "muted",
    "subtle",
    "accent",
    "accent_fg",
    "secondary",
    "tertiary",
    "green",
    "yellow",
    "red",
    "cyan",
    "magenta",
    "copied",
    "cut",
    "marked",
    "selected",
    "black",
    "white",
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
    return (0.10, 0.10, 0.10) if rel_luma(*bg) > 0.55 else (0.94, 0.93, 0.91)


def smoothstep(t: float) -> float:
    t = clamp(t)
    return t * t * (3.0 - 2.0 * t)


def hue_dist(a: float, b: float) -> float:
    d = abs(a - b) % 1.0
    return min(d, 1.0 - d)


def load_icon_base() -> tuple[str, list[str]]:
    global _ICON_BASE_CACHE, _ICON_UNIQUE_HEXES
    if _ICON_BASE_CACHE is not None and _ICON_UNIQUE_HEXES is not None:
        return _ICON_BASE_CACHE, _ICON_UNIQUE_HEXES
    if not ICON_BASE.is_file():
        return "", []
    text = ICON_BASE.read_text(encoding="utf-8")
    seen: dict[str, None] = {}
    for m in _HEX_FG_RE.finditer(text):
        seen.setdefault(m.group(2).lower(), None)
    _ICON_BASE_CACHE = text
    _ICON_UNIQUE_HEXES = list(seen.keys())
    return text, _ICON_UNIQUE_HEXES


def remap_icon_hex(src: str, p: dict[str, str]) -> str:
    """Recolor a preset icon hex so the whole icon set tracks wallpaper hue."""
    r, g, b = hex_to_rgb(src)
    h, s, l = rgb_to_hsl(r, g, b)

    if s < 0.08:
        if l > 0.85:
            return p["fg"]
        if l > 0.55:
            return p["muted"]
        if l > 0.30:
            return p["subtle"]
        return p["overlay"]

    accent_h, accent_s, _accent_l = rgb_to_hsl(*hex_to_rgb(p["accent"]))
    secondary_h, secondary_s, _ = rgb_to_hsl(*hex_to_rgb(p["secondary"]))
    tertiary_h, tertiary_s, _ = rgb_to_hsl(*hex_to_rgb(p["tertiary"]))

    # Rotate the whole Material palette with the wallpaper primary.
    rotated = (h + (accent_h - _ICON_REF_HUE)) % 1.0

    # Pull toward secondary/tertiary when the original hue was far from blue,
    # so the set stays varied instead of monochrome.
    spread = hue_dist(h, _ICON_REF_HUE)
    if spread > 0.18:
        alt_h, alt_s = (tertiary_h, tertiary_s) if spread > 0.33 else (secondary_h, secondary_s)
        # Blend rotated primary-shift with alt accent hue.
        t = clamp((spread - 0.18) / 0.25)
        # Circular blend toward alt
        dh = ((alt_h - rotated + 0.5) % 1.0) - 0.5
        rotated = (rotated + dh * t) % 1.0
        out_s = clamp(max(s, accent_s, alt_s) * 0.9, 0.28, 0.92)
    else:
        out_s = clamp(max(s * 0.45, accent_s * 0.95), 0.28, 0.92)

    out_l = clamp(l * 0.35 + 0.42, 0.30, 0.78)
    return rgb_to_hex(*hsl_to_rgb(rotated, out_s, out_l))


def render_icon_section(p: dict[str, str]) -> str:
    base, unique = load_icon_base()
    if not base:
        return ""
    mapping = {h: remap_icon_hex(h, p) for h in unique}

    def repl(m: re.Match[str]) -> str:
        src = m.group(2).lower()
        return f"{m.group(1)}{mapping.get(src, m.group(2))}{m.group(3)}"

    return _HEX_FG_RE.sub(repl, base)


def yazi_dds_live() -> bool:
    """True if a Yazi DDS socket accepts connections (cached per run)."""
    global _YAZI_LIVE
    if _YAZI_LIVE is not None:
        return _YAZI_LIVE

    import socket

    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    for sock_path in runtime.glob("yazi+*/.dds.sock"):
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(0.1)
            sock.connect(str(sock_path))
            sock.close()
            _YAZI_LIVE = True
            return True
        except Exception:
            continue
    _YAZI_LIVE = False
    return False


def notify_yazi() -> None:
    """Ask all live Yazi instances to reload theme.toml (app:theme actor)."""
    global _YAZI_LIVE
    if not yazi_dds_live():
        return
    try:
        r = subprocess.run(
            ["ya", "emit-to", "0", "app:theme"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=0.4,
            check=False,
        )
        if r.returncode != 0:
            _YAZI_LIVE = False
    except Exception:
        _YAZI_LIVE = False


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


def pick_distinct(colors, count: int = 3, min_hue_dist: float = 0.14):
    picked = []
    for c in colors:
        if c["s"] < 0.10 and picked:
            continue
        ok = True
        for p in picked:
            d = abs(c["h"] - p["h"])
            d = min(d, 1.0 - d)
            if d < min_hue_dist:
                ok = False
                break
        if ok:
            picked.append(c)
        if len(picked) >= count:
            break
    while len(picked) < count:
        base = picked[0] if picked else {
            "rgb": (0.55, 0.65, 0.55),
            "h": 0.35,
            "s": 0.35,
            "l": 0.55,
            "w": 1,
            "score": 1,
        }
        h = (base["h"] + (0.28 * len(picked))) % 1.0
        rgb = hsl_to_rgb(h, clamp(base["s"], 0.25, 0.7), clamp(base["l"], 0.4, 0.65))
        picked.append({"rgb": rgb, "h": h, "s": base["s"], "l": base["l"], "w": 1, "score": 1})
    return picked[:count]


def build_yazi_palette(
    pixels: list[tuple[float, float, float]], mode: str = "dark"
) -> dict[str, str]:
    colors = quantize(pixels)
    primary_c, secondary_c, tertiary_c = pick_distinct(colors, 3)

    primary = tone(
        primary_c["rgb"],
        s=clamp(primary_c["s"] * 1.15 + 0.05, 0.2, 0.85),
        l=clamp(primary_c["l"], 0.35, 0.72),
    )
    secondary = tone(
        secondary_c["rgb"],
        s=clamp(secondary_c["s"] * 1.05 + 0.04, 0.15, 0.75),
        l=clamp(secondary_c["l"], 0.35, 0.7),
    )
    tertiary = tone(
        tertiary_c["rgb"],
        s=clamp(tertiary_c["s"] * 1.05 + 0.04, 0.15, 0.75),
        l=clamp(tertiary_c["l"], 0.35, 0.7),
    )

    ar = sum(p[0] for p in pixels) / max(1, len(pixels))
    ag = sum(p[1] for p in pixels) / max(1, len(pixels))
    ab = sum(p[2] for p in pixels) / max(1, len(pixels))
    avg = (ar, ag, ab)

    dark = mode != "light"
    if dark:
        base = mix(avg, (0.08, 0.08, 0.07), 0.82)
        bg = tone(mix(base, primary, 0.08), s=0.08, l=0.09)
        surface = tone(mix(base, primary, 0.10), s=0.07, l=0.14)
        surface2 = tone(mix(base, primary, 0.12), s=0.08, l=0.18)
        overlay = tone(mix(base, primary, 0.16), s=0.10, l=0.24)
        fg = (0.90, 0.89, 0.87)
        muted = (0.55, 0.54, 0.50)
        subtle = (0.40, 0.39, 0.36)
        accent = tone(primary, s=clamp(primary_c["s"] * 1.1 + 0.06, 0.3, 0.85), l=0.58)
        green = tone(secondary, s=0.55, l=0.55)
        yellow = tone(mix(primary, tertiary, 0.45), s=0.65, l=0.62)
        red = tone(mix(tertiary, (0.9, 0.2, 0.2), 0.55), s=0.7, l=0.58)
        cyan = tone(secondary, s=0.55, l=0.62)
        magenta = tone(tertiary, s=0.6, l=0.62)
        black = tone(bg, s=0.05, l=0.05)
        white = (0.93, 0.92, 0.90)
        copied = tone(green, s=0.55, l=0.72)
        cut = tone(red, s=0.65, l=0.68)
        marked = tone(cyan, s=0.55, l=0.72)
        selected = tone(yellow, s=0.6, l=0.72)
    else:
        base = mix(avg, (0.96, 0.95, 0.93), 0.75)
        bg = tone(mix(base, primary, 0.06), s=0.06, l=0.94)
        surface = tone(mix(base, primary, 0.08), s=0.06, l=0.90)
        surface2 = tone(mix(base, primary, 0.10), s=0.07, l=0.86)
        overlay = tone(mix(base, primary, 0.12), s=0.08, l=0.80)
        fg = (0.14, 0.13, 0.12)
        muted = (0.45, 0.44, 0.42)
        subtle = (0.58, 0.57, 0.54)
        accent = tone(primary, s=clamp(primary_c["s"] * 1.05 + 0.05, 0.25, 0.8), l=0.45)
        green = tone(secondary, s=0.5, l=0.40)
        yellow = tone(mix(primary, tertiary, 0.45), s=0.55, l=0.42)
        red = tone(mix(tertiary, (0.85, 0.15, 0.12), 0.55), s=0.65, l=0.42)
        cyan = tone(secondary, s=0.5, l=0.42)
        magenta = tone(tertiary, s=0.55, l=0.42)
        black = tone(overlay, s=0.08, l=0.22)
        white = (0.12, 0.12, 0.11)
        copied = tone(green, s=0.45, l=0.55)
        cut = tone(red, s=0.55, l=0.55)
        marked = tone(cyan, s=0.45, l=0.55)
        selected = tone(yellow, s=0.5, l=0.55)

    accent_fg = contrast_on(accent)

    return {
        "bg": rgb_to_hex(*bg),
        "surface": rgb_to_hex(*surface),
        "surface2": rgb_to_hex(*surface2),
        "overlay": rgb_to_hex(*overlay),
        "fg": rgb_to_hex(*fg),
        "muted": rgb_to_hex(*muted),
        "subtle": rgb_to_hex(*subtle),
        "accent": rgb_to_hex(*accent),
        "accent_fg": rgb_to_hex(*accent_fg),
        "secondary": rgb_to_hex(*secondary),
        "tertiary": rgb_to_hex(*tertiary),
        "green": rgb_to_hex(*green),
        "yellow": rgb_to_hex(*yellow),
        "red": rgb_to_hex(*red),
        "cyan": rgb_to_hex(*cyan),
        "magenta": rgb_to_hex(*magenta),
        "copied": rgb_to_hex(*copied),
        "cut": rgb_to_hex(*cut),
        "marked": rgb_to_hex(*marked),
        "selected": rgb_to_hex(*selected),
        "black": rgb_to_hex(*black),
        "white": rgb_to_hex(*white),
    }


def render_toml(
    p: dict[str, str],
    *,
    include_icons: bool = True,
    icon_section: str | None = None,
) -> str:
    if icon_section is not None:
        icons = icon_section
    elif include_icons:
        icons = render_icon_section(p)
    else:
        icons = ""
    return f"""\
# Auto-generated by ~/.config/yazi/apply-wallpaper-theme.py — do not edit colors by hand.
# Re-run that script (or change wallpaper) to refresh the palette.
#:schema https://yazi-rs.github.io/schemas/theme.json

[flavor]
dark  = ""
light = ""

[mgr]
cwd = {{ fg = "{p['accent']}" }}

find_keyword  = {{ fg = "{p['yellow']}", bold = true, italic = true, underline = true }}
find_position = {{ fg = "{p['magenta']}", bg = "reset", bold = true, italic = true }}

symlink_target = {{ fg = "{p['subtle']}", italic = true }}

marker_copied   = {{ fg = "{p['copied']}",  bg = "{p['copied']}" }}
marker_cut      = {{ fg = "{p['cut']}",     bg = "{p['cut']}" }}
marker_marked   = {{ fg = "{p['marked']}",  bg = "{p['marked']}" }}
marker_selected = {{ fg = "{p['selected']}", bg = "{p['selected']}" }}
marker_symbol   = "│"

count_copied   = {{ fg = "{p['black']}", bg = "{p['green']}" }}
count_cut      = {{ fg = "{p['white']}", bg = "{p['red']}" }}
count_selected = {{ fg = "{p['black']}", bg = "{p['yellow']}" }}

border_symbol = "│"
border_style  = {{ fg = "{p['subtle']}" }}

syntect_theme = ""

[tabs]
active   = {{ fg = "{p['accent_fg']}", bg = "{p['accent']}", bold = true }}
inactive = {{ fg = "{p['accent']}", bg = "{p['surface2']}" }}
sep_inner = {{ open = "", close = "" }}
sep_outer = {{ open = "", close = "" }}

[mode]
normal_main = {{ fg = "{p['accent_fg']}", bg = "{p['accent']}", bold = true }}
normal_alt  = {{ fg = "{p['accent']}", bg = "{p['surface2']}" }}
select_main = {{ fg = "{p['white']}", bg = "{p['red']}", bold = true }}
select_alt  = {{ fg = "{p['red']}", bg = "{p['surface2']}" }}
unset_main  = {{ fg = "{p['white']}", bg = "{p['magenta']}", bold = true }}
unset_alt   = {{ fg = "{p['magenta']}", bg = "{p['surface2']}" }}

[indicator]
parent  = {{ reversed = true }}
current = {{ reversed = true }}
preview = {{ underline = true }}
padding = {{ open = "", close = "" }}

[status]
overall   = {{}}
sep_left  = {{ open = "", close = "" }}
sep_right = {{ open = "", close = "" }}
perm_sep   = {{ fg = "{p['subtle']}" }}
perm_type  = {{ fg = "{p['green']}" }}
perm_read  = {{ fg = "{p['yellow']}" }}
perm_write = {{ fg = "{p['red']}" }}
perm_exec  = {{ fg = "{p['cyan']}" }}
progress_label  = {{ bold = true }}
progress_normal = {{ fg = "{p['green']}", bg = "{p['black']}" }}
progress_error  = {{ fg = "{p['yellow']}", bg = "{p['red']}" }}

[which]
cols            = 3
mask            = {{ bg = "{p['bg']}" }}
cand            = {{ fg = "{p['cyan']}" }}
rest            = {{ fg = "{p['subtle']}" }}
desc            = {{ fg = "{p['magenta']}" }}
separator       = "  "
separator_style = {{ fg = "{p['subtle']}" }}

[confirm]
border     = {{ fg = "{p['accent']}" }}
title      = {{ fg = "{p['accent']}" }}
body       = {{ fg = "{p['fg']}" }}
list       = {{ fg = "{p['muted']}" }}
btn_yes    = {{ reversed = true }}
btn_no     = {{}}
btn_labels = [ "  [Y]es  ", "  (N)o  " ]

[spot]
border   = {{ fg = "{p['accent']}" }}
title    = {{ fg = "{p['accent']}" }}
tbl_col  = {{ fg = "{p['accent']}" }}
tbl_cell = {{ fg = "{p['yellow']}", reversed = true }}

[notify]
title_info  = {{ fg = "{p['green']}" }}
title_warn  = {{ fg = "{p['yellow']}" }}
title_error = {{ fg = "{p['red']}" }}
icon_info  = ""
icon_warn  = ""
icon_error = ""

[pick]
border   = {{ fg = "{p['accent']}" }}
active   = {{ fg = "{p['magenta']}", bold = true }}
inactive = {{ fg = "{p['muted']}" }}

[input]
border   = {{ fg = "{p['accent']}" }}
title    = {{ fg = "{p['fg']}" }}
value    = {{ fg = "{p['fg']}" }}
selected = {{ reversed = true }}

[cmp]
border   = {{ fg = "{p['accent']}" }}
active   = {{ reversed = true }}
inactive = {{ fg = "{p['muted']}" }}
icon_file    = ""
icon_folder  = ""
icon_command = ""

[tasks]
border  = {{ fg = "{p['accent']}" }}
title   = {{ fg = "{p['fg']}" }}
hovered = {{ fg = "{p['magenta']}", bold = true }}

[help]
on      = {{ fg = "{p['cyan']}" }}
run     = {{ fg = "{p['magenta']}" }}
desc    = {{ fg = "{p['muted']}" }}
hovered = {{ reversed = true, bold = true }}
footer  = {{ fg = "{p['black']}", bg = "{p['white']}" }}

[filetype]
rules = [
	{{ mime = "image/*", fg = "{p['yellow']}" }},
	{{ mime = "{{audio,video}}/*", fg = "{p['magenta']}" }},
	{{ mime = "application/{{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}}", fg = "{p['red']}" }},
	{{ mime = "application/{{pdf,doc,rtf}}", fg = "{p['cyan']}" }},
	{{ mime = "vfs/{{absent,stale}}", fg = "{p['muted']}" }},
	{{ url = "*", is = "orphan", bg = "{p['red']}" }},
	{{ url = "*", is = "exec", fg = "{p['green']}" }},
	{{ url = "*", is = "dummy", bg = "{p['red']}" }},
	{{ url = "*/", is = "dummy", bg = "{p['red']}" }},
	{{ url = "*/", fg = "{p['accent']}" }},
]

{icons}
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
    if not PALETTE_JSON.is_file():
        return None
    try:
        data = json.loads(PALETTE_JSON.read_text(encoding="utf-8"))
        if all(k in data for k in PALETTE_KEYS):
            return {k: str(data[k]) for k in PALETTE_KEYS}
    except Exception:
        pass
    return None


def save_palette(pal: dict[str, str]) -> None:
    PALETTE_JSON.write_text(json.dumps(pal, indent=2) + "\n", encoding="utf-8")


def lerp_palette(a: dict[str, str], b: dict[str, str], t: float) -> dict[str, str]:
    t = smoothstep(t)
    out: dict[str, str] = {}
    for k in PALETTE_KEYS:
        out[k] = rgb_to_hex(*mix(hex_to_rgb(a[k]), hex_to_rgb(b[k]), t))
    return out


def write_toml(
    path: Path,
    pal: dict[str, str],
    *,
    include_icons: bool = True,
    icon_section: str | None = None,
    reload: bool = True,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Atomic-ish replace so Yazi's reload sees a complete file.
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(
        render_toml(pal, include_icons=include_icons, icon_section=icon_section),
        encoding="utf-8",
    )
    tmp.replace(path)
    if reload:
        notify_yazi()


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
        new_anim_token()
        write_toml(path, pal, include_icons=True, reload=True)
        save_palette(pal)
        return

    token = new_anim_token()
    frame_dt = ANIM_DURATION / max(1, ANIM_FRAMES - 1)
    t0 = time.monotonic()

    # Recolor icons once to the target palette (visible immediately), morph chrome.
    final_icons = render_icon_section(pal)

    for i in range(ANIM_FRAMES):
        if not anim_token_ok(token):
            return
        t = i / max(1, ANIM_FRAMES - 1)
        frame = lerp_palette(animate_from, pal, t)
        write_toml(
            path,
            frame,
            icon_section=final_icons,
            reload=(i % 2 == 0) or (i + 1 == ANIM_FRAMES),
        )
        if i + 1 < ANIM_FRAMES:
            target = t0 + (i + 1) * frame_dt
            delay = target - time.monotonic()
            if delay > 0:
                time.sleep(delay)

    if not anim_token_ok(token):
        return
    write_toml(path, pal, icon_section=final_icons, reload=True)
    save_palette(pal)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", nargs="?", help="Wallpaper path (default: awww)")
    parser.add_argument(
        "mode",
        nargs="?",
        default="dark",
        help="dark or light (default: dark)",
    )
    parser.add_argument(
        "--instant",
        "-i",
        action="store_true",
        help="Skip color morph animation",
    )
    args = parser.parse_args()

    img = args.image or current_wallpaper()
    mode = args.mode if args.mode in ("dark", "light") else "dark"

    if not img or not os.path.isfile(img):
        print(f"apply-wallpaper-theme: no image ({img!r})", file=sys.stderr)
        return 0

    try:
        pixels = load_pixels(img, 64)
        pal = build_yazi_palette(pixels, mode)
    except Exception as e:
        print(f"apply-wallpaper-theme: {e}", file=sys.stderr)
        return 1

    DIR.mkdir(parents=True, exist_ok=True)
    prev = None if args.instant else load_saved_palette()
    apply_palette(OUT, pal, animate_from=None if args.instant else prev)

    print(OUT)
    for k in ("accent", "bg", "surface", "fg", "green", "red", "yellow"):
        print(f"  {k}: {pal[k]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
