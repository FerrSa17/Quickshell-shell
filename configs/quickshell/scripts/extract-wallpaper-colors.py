#!/usr/bin/env python3
"""Extract a Quickshell palette from a wallpaper image (local extractor).

Uses GdkPixbuf (already on GTK systems) to decode common image formats,
then builds a dark/light chrome palette matching colors.json keys.
"""
from __future__ import annotations

import json
import math
import os
import sys


def clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if x < lo else hi if x > hi else x


def rgb_to_hex(r: float, g: float, b: float) -> str:
    def byte(v: float) -> str:
        n = max(0, min(255, int(round(v * 255.0))))
        return f"{n:02x}"

    return f"#{byte(r)}{byte(g)}{byte(b)}"


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


def mix(a: tuple[float, float, float], b: tuple[float, float, float], t: float):
    t = clamp(t)
    return (
        a[0] * (1 - t) + b[0] * t,
        a[1] * (1 - t) + b[1] * t,
        a[2] * (1 - t) + b[2] * t,
    )


def rel_luma(r: float, g: float, b: float) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


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
            # RGB or RGBA — ignore alpha
            out.append((data[i] / 255.0, data[i + 1] / 255.0, data[i + 2] / 255.0))
    return out


def score_pixel(rgb: tuple[float, float, float]) -> float:
    h, s, l = rgb_to_hsl(*rgb)
    # Prefer saturated mid-tones (wallpaper accents)
    if l < 0.08 or l > 0.92:
        return 0.0
    if s < 0.08:
        return s * 0.15
    return s * (1.0 - abs(l - 0.45) * 1.4)


def quantize(pixels: list[tuple[float, float, float]], buckets: int = 24):
    # Hue buckets weighted by chroma score
    acc = [[0.0, 0.0, 0.0, 0.0] for _ in range(buckets)]  # r,g,b,w
    for rgb in pixels:
        sc = score_pixel(rgb)
        if sc <= 0:
            # still count neutrals lightly for surface tones
            sc = 0.05
        h, s, l = rgb_to_hsl(*rgb)
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
    # Synthesize missing accents by rotating hue of primary
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


def tone(rgb, s=None, l=None):
    h, cs, cl = rgb_to_hsl(*rgb)
    if s is not None:
        cs = clamp(s)
    if l is not None:
        cl = clamp(l)
    return hsl_to_rgb(h, cs, cl)


def contrast_on(bg: tuple[float, float, float]) -> tuple[float, float, float]:
    return (0.12, 0.12, 0.11) if rel_luma(*bg) > 0.55 else (0.93, 0.92, 0.90)


def build_palette(pixels: list[tuple[float, float, float]], mode: str = "dark") -> dict:
    colors = quantize(pixels)
    primary_c, secondary_c, tertiary_c = pick_distinct(colors, 3)

    # Boost saturation slightly for accents
    primary = tone(primary_c["rgb"], s=clamp(primary_c["s"] * 1.15 + 0.05, 0.2, 0.85), l=clamp(primary_c["l"], 0.35, 0.72))
    secondary = tone(secondary_c["rgb"], s=clamp(secondary_c["s"] * 1.05 + 0.04, 0.15, 0.75), l=clamp(secondary_c["l"], 0.35, 0.7))
    tertiary = tone(tertiary_c["rgb"], s=clamp(tertiary_c["s"] * 1.05 + 0.04, 0.15, 0.75), l=clamp(tertiary_c["l"], 0.35, 0.7))

    # Average wallpaper for surface tint
    ar = sum(p[0] for p in pixels) / max(1, len(pixels))
    ag = sum(p[1] for p in pixels) / max(1, len(pixels))
    ab = sum(p[2] for p in pixels) / max(1, len(pixels))
    avg = (ar, ag, ab)

    dark = mode != "light"
    if dark:
        base = mix(avg, (0.08, 0.08, 0.07), 0.82)
        bg = tone(mix(base, primary, 0.08), s=0.08, l=0.09)
        window_bg = tone(mix(base, primary, 0.1), s=0.07, l=0.14)
        surface = tone(mix(base, primary, 0.12), s=0.08, l=0.18)
        pill = tone(primary, s=clamp(primary_c["s"] * 0.55 + 0.12, 0.18, 0.55), l=0.22)
        well = tone(secondary, s=clamp(secondary_c["s"] * 0.4 + 0.08, 0.1, 0.4), l=0.28)
        text = (0.90, 0.89, 0.87)
        subtext = (0.72, 0.71, 0.68)
        muted = (0.55, 0.54, 0.50)
        on_primary = contrast_on(primary)
        primary_fixed = tone(primary, s=0.35, l=0.82)
        primary_fixed_dim = tone(primary, s=0.4, l=0.65)
        secondary_fixed = tone(secondary, s=0.3, l=0.82)
        secondary_fixed_dim = tone(secondary, s=0.35, l=0.62)
        tertiary_fixed = tone(tertiary, s=0.3, l=0.82)
        tertiary_fixed_dim = tone(tertiary, s=0.35, l=0.62)
        error = (1.0, 0.71, 0.67)
        error_container = (0.58, 0.0, 0.04)
        on_bg = text
    else:
        base = mix(avg, (0.96, 0.95, 0.93), 0.75)
        bg = tone(mix(base, primary, 0.06), s=0.06, l=0.94)
        window_bg = tone(mix(base, primary, 0.08), s=0.06, l=0.90)
        surface = tone(mix(base, primary, 0.1), s=0.07, l=0.86)
        pill = tone(primary, s=clamp(primary_c["s"] * 0.45 + 0.1, 0.15, 0.45), l=0.85)
        well = tone(secondary, s=clamp(secondary_c["s"] * 0.35 + 0.08, 0.1, 0.35), l=0.80)
        text = (0.14, 0.13, 0.12)
        subtext = (0.35, 0.34, 0.32)
        muted = (0.50, 0.49, 0.46)
        on_primary = contrast_on(primary)
        primary_fixed = tone(primary, s=0.4, l=0.35)
        primary_fixed_dim = tone(primary, s=0.45, l=0.45)
        secondary_fixed = tone(secondary, s=0.35, l=0.35)
        secondary_fixed_dim = tone(secondary, s=0.4, l=0.45)
        tertiary_fixed = tone(tertiary, s=0.35, l=0.35)
        tertiary_fixed_dim = tone(tertiary, s=0.4, l=0.45)
        error = (0.73, 0.15, 0.12)
        error_container = (1.0, 0.86, 0.84)
        on_bg = text

    return {
        "bg": rgb_to_hex(*bg),
        "windowBg": rgb_to_hex(*window_bg),
        "surface": rgb_to_hex(*surface),
        "pill": rgb_to_hex(*pill),
        "well": rgb_to_hex(*well),
        "text": rgb_to_hex(*text),
        "subtext": rgb_to_hex(*subtext),
        "muted": rgb_to_hex(*muted),
        "arch": rgb_to_hex(*primary),
        "sapphire": rgb_to_hex(*primary),
        "blue": rgb_to_hex(*primary_fixed_dim),
        "notifBlue": rgb_to_hex(*primary),
        "onNotifBadge": rgb_to_hex(*on_primary),
        "rosewater": rgb_to_hex(*primary_fixed),
        "sky": rgb_to_hex(*secondary),
        "teal": rgb_to_hex(*secondary_fixed),
        "green": rgb_to_hex(*secondary),
        "yellow": rgb_to_hex(*secondary_fixed_dim),
        "lavender": rgb_to_hex(*tertiary),
        "mauve": rgb_to_hex(*tertiary),
        "pink": rgb_to_hex(*tertiary_fixed),
        "flamingo": rgb_to_hex(*tertiary),
        "peach": rgb_to_hex(*tertiary_fixed_dim),
        "red": rgb_to_hex(*error),
        "maroon": rgb_to_hex(*error_container),
        "white": rgb_to_hex(*on_bg),
    }


def current_wallpaper() -> str:
    import subprocess

    try:
        out = subprocess.check_output(["awww", "query"], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return ""
    for line in out.splitlines():
        if "image:" in line:
            return line.split("image:", 1)[1].strip()
    return ""


def main() -> int:
    img = sys.argv[1] if len(sys.argv) > 1 else ""
    mode = sys.argv[2] if len(sys.argv) > 2 else "dark"
    out_path = sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser(
        "~/.config/quickshell/colors.json"
    )

    if not img:
        img = current_wallpaper()
    if not img or not os.path.isfile(img):
        print(f"extract-wallpaper-colors: no image ({img!r})", file=sys.stderr)
        return 0

    if mode not in ("dark", "light"):
        mode = "dark"

    try:
        pixels = load_pixels(img, 64)
        pal = build_palette(pixels, mode)
    except Exception as e:
        print(f"extract-wallpaper-colors: {e}", file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(pal, f, indent=2)
        f.write("\n")
    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
