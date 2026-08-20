pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property int fontSize: 15
  readonly property int iconSize: 15
  // Slightly heavier than regular for bar labels/icons.
  readonly property int barFontWeight: Font.DemiBold
  readonly property int barHeight: 34
  // DesktopFrame side/bottom chrome — popups/toasts align to this edge.
  readonly property int frameThickness: 8
  // Shared chrome-join size (top lip only — one language across Control/toasts).
  readonly property int filletS: 28
  readonly property int barPad: 8

  // Live palette from matugen (colors.json). Empty → Gruvbox fallbacks below.
  property var palette: ({})
  // Bumped when the target palette changes so color bindings re-evaluate.
  property int paletteRev: 0
  // path → palette; used only when a wallpaper is actually applied.
  property var paletteCache: ({})
  property string pendingWallpaper: ""

  // Smooth pour: colors lerp from blendFrom → blendTo over blendT.
  property var blendFrom: ({})
  property var blendTo: ({})
  property real blendT: 1
  property bool animateColors: false
  property real pourStart: 0
  property string pourKind: "left"
  readonly property var pourKinds: ["fade", "left", "right", "top", "bottom", "grow", "center", "outer"]
  readonly property int pourMs: 1400
  readonly property string pourBezier: "0.65,0.0,0.35,1.0"

  readonly property string colorsPath: (Quickshell.env("HOME") || "/home/user")
                                       + "/.config/quickshell/colors.json"
  readonly property string cachePath: (Quickshell.env("HOME") || "/home/user")
                                      + "/.cache/quickshell/wallpaper-palettes.json"
  readonly property string themeScript: (Quickshell.env("HOME") || "/home/user")
                                        + "/.config/quickshell/scripts/apply-wallpaper-theme.sh"

  function mixHex(a, b, t) {
    const ca = Qt.color(a)
    const cb = Qt.color(b)
    const u = Math.max(0, Math.min(1, t))
    const r = ca.r * (1 - u) + cb.r * u
    const g = ca.g * (1 - u) + cb.g * u
    const bl = ca.b * (1 - u) + cb.b * u
    const toByte = x => {
      const n = Math.max(0, Math.min(255, Math.round(x * 255)))
      const h = n.toString(16)
      return h.length < 2 ? "0" + h : h
    }
    return "#" + toByte(r) + toByte(g) + toByte(bl)
  }

  function cubicBez(s, a, b) {
    const is = 1 - s
    return 3 * is * is * s * a + 3 * is * s * s * b + s * s * s
  }

  function easePour(t) {
    const p = String(root.pourBezier || "").split(",")
    const x1 = Number(p[0]) || 0.65
    const y1 = Number(p[1]) || 0
    const x2 = Number(p[2]) || 0.35
    const y2 = Number(p[3]) || 1
    const u = Math.max(0, Math.min(1, t))
    let lo = 0
    let hi = 1
    let s = u
    for (let i = 0; i < 14; i++) {
      const x = root.cubicBez(s, x1, x2)
      if (x < u)
        lo = s
      else
        hi = s
      s = (lo + hi) / 2
    }
    return root.cubicBez(s, y1, y2)
  }

  function palettesMatch(a, b) {
    if (!a || !b)
      return false
    const keys = ["windowBg", "pill", "sapphire", "bg", "text"]
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i]
      if (String(a[k] || "") !== String(b[k] || ""))
        return false
    }
    return true
  }

  function pickPour() {
    const kinds = root.pourKinds
    const n = kinds.length
    if (n < 1)
      return root.pourKind
    let k = kinds[Math.floor(Math.random() * n)]
    if (n > 1) {
      for (let i = 0; i < 8 && k === root.pourKind; i++)
        k = kinds[Math.floor(Math.random() * n)]
    }
    root.pourKind = k
    return k
  }

  function hex(key, fallback) {
    // Touch rev + blendT so bindings track both target changes and the pour.
    const _ = root.paletteRev
    const __ = root.blendT
    const from = (typeof root.blendFrom[key] === "string" && root.blendFrom[key].length)
                   ? root.blendFrom[key] : fallback
    const to = (typeof root.blendTo[key] === "string" && root.blendTo[key].length)
                 ? root.blendTo[key] : fallback
    if (root.blendT >= 0.999)
      return to
    if (root.blendT <= 0.001)
      return from
    return root.mixHex(from, to, root.blendT)
  }

  function solidFromPalette(pal, key, fallback, tintAmount) {
    const raw = (pal && typeof pal[key] === "string" && pal[key].length) ? pal[key] : fallback
    const tintKey = "sapphire"
    const tintRaw = (pal && typeof pal[tintKey] === "string" && pal[tintKey].length)
                      ? pal[tintKey] : "#83a598"
    const b = Qt.color(raw)
    const tint = Qt.color(tintRaw)
    const a = Math.max(0, Math.min(1, tintAmount))
    return Qt.rgba(
      b.r * (1 - a) + tint.r * a,
      b.g * (1 - a) + tint.g * a,
      b.b * (1 - a) + tint.b * a,
      1
    )
  }

  function chromeFromPalette(pal) {
    return chromeSolid(pal)
  }

  // Hand-authored chrome — used when appearanceMode is light/dark (no wallpaper extract).
  readonly property var fixedLightPalette: ({
    bg: "#f7f7f8",
    windowBg: "#ffffff",
    surface: "#ececef",
    pill: "#e2e2e6",
    well: "#ebebee",
    text: "#161618",
    subtext: "#4a4a50",
    muted: "#8b8b93",
    arch: "#3b6ea5",
    sapphire: "#3b6ea5",
    blue: "#5a8fc4",
    notifBlue: "#3b6ea5",
    onNotifBadge: "#ffffff",
    rosewater: "#5c5c64",
    sky: "#4a7fb0",
    teal: "#3d8f7a",
    green: "#3f8f5a",
    yellow: "#b08920",
    lavender: "#6b5b8c",
    mauve: "#7a5f8f",
    pink: "#b06080",
    flamingo: "#c07050",
    peach: "#c08040",
    red: "#c04545",
    maroon: "#a03030",
    white: "#161618"
  })

  readonly property var fixedDarkPalette: ({
    bg: "#050506",
    windowBg: "#0c0c0e",
    surface: "#18181b",
    pill: "#222226",
    well: "#1a1a1e",
    text: "#f2f2f4",
    subtext: "#a8a8b0",
    muted: "#6e6e76",
    arch: "#6b9fd4",
    sapphire: "#6b9fd4",
    blue: "#7aa8d8",
    notifBlue: "#6b9fd4",
    onNotifBadge: "#0c0c0e",
    rosewater: "#c8c8d0",
    sky: "#7aade0",
    teal: "#5cb89a",
    green: "#6bc07a",
    yellow: "#d4b040",
    lavender: "#9a8ab8",
    mauve: "#a88ab8",
    pink: "#d080a0",
    flamingo: "#d09070",
    peach: "#d0a050",
    red: "#e06060",
    maroon: "#c04040",
    white: "#f2f2f4"
  })

  function applyFixedPalette(mode, animate) {
    const pal = mode === "light" ? root.fixedLightPalette : root.fixedDarkPalette
    applyPalette(clonePalette(pal), animate !== false)
  }

  function syncAppearancePalette(animate) {
    const mode = ShellPrefs.appearanceMode
    if (mode === "light")
      root.applyFixedPalette("light", animate)
    else if (mode === "dark")
      root.applyFixedPalette("dark", animate)
  }

  // Snapshot of the currently displayed palette (mid-blend safe).
  function visualPalette() {
    if (root.blendT >= 0.999)
      return clonePalette(root.blendTo)
    if (root.blendT <= 0.001)
      return clonePalette(root.blendFrom)
    const out = ({})
    const seen = ({})
    const addKeys = src => {
      if (!src)
        return
      const keys = Object.keys(src)
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i]
        if (seen[k])
          continue
        seen[k] = true
        const a = root.blendFrom[k]
        const b = root.blendTo[k]
        if (typeof a === "string" && typeof b === "string")
          out[k] = root.mixHex(a, b, root.blendT)
        else if (typeof b === "string")
          out[k] = b
        else if (typeof a === "string")
          out[k] = a
      }
    }
    addKeys(root.blendFrom)
    addKeys(root.blendTo)
    return out
  }

  // Blend wallpaper primary into surfaces. Material surface_* barely moves between
  // wallpapers; primary_container (pill) / secondary_container (well) do — then we
  // still pull a bit of primary so chrome tracks the wallpaper clearly.
  function tintPrimary(base, amount) {
    const _ = root.paletteRev
    const __ = root.blendT
    const b = Qt.color(base)
    const tint = Qt.color(hex("sapphire", "#83a598"))
    const a = Math.max(0, Math.min(1, amount))
    return Qt.rgba(
      b.r * (1 - a) + tint.r * a,
      b.g * (1 - a) + tint.g * a,
      b.b * (1 - a) + tint.b * a,
      1
    )
  }

  function dim(c, amount) {
    const a = Math.max(0, Math.min(1, amount))
    return Qt.rgba(c.r * (1 - a), c.g * (1 - a), c.b * (1 - a), c.a)
  }

  // Gruvbox Dark fallbacks when colors.json is missing
  readonly property color bg: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("bg", "#1d2021"))
  }
  // Same chrome as bar/frame — do not retint separately (was 0.28 vs bar 0.36).
  readonly property color windowBg: barBg
  readonly property color surface: {
    const _ = root.paletteRev
    const __ = root.blendT
    const ___ = ShellPrefs.appearanceMode
    const raw = hex("surface", "#3c3836")
    return ShellPrefs.extractTheme ? tintPrimary(raw, 0.32) : Qt.color(raw)
  }
  readonly property color pill: {
    const _ = root.paletteRev
    const __ = root.blendT
    const ___ = ShellPrefs.appearanceMode
    const raw = hex("pill", "#504945")
    const c = ShellPrefs.extractTheme ? tintPrimary(raw, 0.18) : Qt.color(raw)
    return dim(c, 0.2)
  }
  // Same fill as bar pills — insets/cards/tracks used to pick up a separate purple.
  readonly property color well: pill
  readonly property color text: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("text", "#ebdbb2"))
  }
  readonly property color subtext: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("subtext", "#d5c4a1"))
  }
  readonly property color muted: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("muted", "#928374"))
  }

  // Single chrome fill for DesktopFrame / bar / panels / clock.
  readonly property color barBg: {
    const _ = root.paletteRev
    const __ = root.blendT
    const ___ = ShellPrefs.transparency
    const ____ = ShellPrefs.appearanceMode
    const raw = hex("windowBg", "#282828")
    const base = ShellPrefs.extractTheme ? tintPrimary(raw, 0.36) : Qt.color(raw)
    const a = ShellPrefs.transparency ? 0.9 : 1.0
    return Qt.rgba(base.r, base.g, base.b, a)
  }

  function chromeSolid(pal) {
    const raw = (pal && typeof pal.windowBg === "string" && pal.windowBg.length)
                  ? pal.windowBg : "#282828"
    const base = ShellPrefs.extractTheme
                   ? solidFromPalette(pal, "windowBg", "#282828", 0.36)
                   : Qt.color(raw)
    const a = ShellPrefs.transparency ? 0.9 : 1.0
    return Qt.rgba(base.r, base.g, base.b, a)
  }

  // Endpoints for DesktopFrame left→right pour (not mid-lerp).
  readonly property color barBgFrom: {
    const _ = root.paletteRev
    const __ = ShellPrefs.transparency
    const ___ = ShellPrefs.appearanceMode
    return chromeSolid(root.blendFrom)
  }
  readonly property color barBgTo: {
    const _ = root.paletteRev
    const __ = ShellPrefs.transparency
    const ___ = ShellPrefs.appearanceMode
    return chromeSolid(root.blendTo)
  }

  readonly property color arch: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("arch", "#83a598"))
  }
  readonly property color rosewater: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("rosewater", "#fbf1c7"))
  }
  readonly property color flamingo: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("flamingo", "#fe8019"))
  }
  readonly property color pink: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("pink", "#d3869b"))
  }
  readonly property color mauve: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("mauve", "#d3869b"))
  }
  readonly property color red: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("red", "#fb4934"))
  }
  readonly property color maroon: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("maroon", "#cc241d"))
  }
  readonly property color peach: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("peach", "#fe8019"))
  }
  readonly property color yellow: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("yellow", "#fabd2f"))
  }
  readonly property color green: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("green", "#b8bb26"))
  }
  readonly property color teal: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("teal", "#8ec07c"))
  }
  readonly property color sky: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("sky", "#83a598"))
  }
  readonly property color sapphire: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("sapphire", "#83a598"))
  }
  readonly property color blue: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("blue", "#458588"))
  }
  readonly property color lavender: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("lavender", "#b16286"))
  }
  readonly property color white: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("white", "#fbf1c7"))
  }

  readonly property color notifBlue: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("notifBlue", "#83a598"))
  }
  readonly property color onNotifBadge: {
    const _ = root.paletteRev
    const __ = root.blendT
    return Qt.color(hex("onNotifBadge", "#1d2021"))
  }
  readonly property color notifBlueDim: {
    const _ = root.paletteRev
    const __ = root.blendT
    const c = notifBlue
    return Qt.rgba(c.r, c.g, c.b, 0.28)
  }

  readonly property var workspaceColors: {
    const _ = root.paletteRev
    const __ = root.blendT
    return [sapphire, red, teal, green, mauve]
  }

  function clonePalette(src) {
    const out = ({})
    if (!src || typeof src !== "object")
      return out
    const keys = Object.keys(src)
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i]
      const v = src[k]
      if (typeof v === "string")
        out[k] = v
    }
    return out
  }

  function applyPalette(parsed, animate) {
    const next = parsed && typeof parsed === "object" ? clonePalette(parsed) : ({})
    if (Object.keys(next).length < 1 && Object.keys(root.blendTo).length > 0)
      return

    const doAnim = animate === true && root.animateColors
    if (doAnim && root.palettesMatch(next, root.blendTo) && pourTick.running)
      return
    if (doAnim && root.palettesMatch(next, root.visualPalette()) && !pourTick.running)
      return

    if (!doAnim) {
      pourTick.stop()
      root.blendFrom = next
      root.blendTo = next
      root.palette = next
      root.blendT = 1
      root.paletteRev++
      return
    }

    root.blendFrom = root.visualPalette()
    root.blendTo = next
    root.palette = next
    root.blendT = 0
    root.paletteRev++
    root.pourStart = Date.now()
    pourTick.restart()
  }

  Timer {
    id: pourTick
    interval: 16
    repeat: true
    onTriggered: {
      const elapsed = Date.now() - root.pourStart
      const u = Math.max(0, Math.min(1, elapsed / root.pourMs))
      root.blendT = root.easePour(u)
      root.paletteRev++
      if (u >= 1) {
        stop()
        root.blendFrom = root.clonePalette(root.blendTo)
        root.blendT = 1
        root.paletteRev++
      }
    }
  }

  function reloadPalette() {
    try {
      const raw = colorsFile.text()
      if (!raw || raw.length < 2)
        return
      applyPalette(JSON.parse(raw), root.animateColors)
    } catch (e) {}
  }

  function rememberPendingPalette() {
    const path = root.pendingWallpaper
    if (!path || path.length < 1)
      return
    if (!root.palette || Object.keys(root.palette).length < 1)
      return
    const next = Object.assign({}, root.paletteCache)
    next[path] = clonePalette(root.palette)
    root.paletteCache = next
    saveCache()
  }

  function saveCache() {
    try {
      Quickshell.execDetached([
        "bash", "-c",
        "mkdir -p \"$(dirname \"$1\")\"",
        "mkdir",
        root.cachePath
      ])
      cacheFile.setText(JSON.stringify(root.paletteCache))
    } catch (e) {}
  }

  function loadCache() {
    try {
      const raw = cacheFile.text()
      if (!raw || raw.length < 2)
        return
      const parsed = JSON.parse(raw)
      if (parsed && typeof parsed === "object")
        root.paletteCache = parsed
    } catch (e) {}
  }

  // Apply theme for an applied wallpaper only (never on hover).
  function applyFromWallpaper(path) {
    root.pendingWallpaper = path && path.length ? path : ""

    if (!ShellPrefs.extractTheme) {
      root.syncAppearancePalette(true)
      return
    }

    if (path && root.paletteCache[path])
      applyPalette(clonePalette(root.paletteCache[path]), true)

    const mode = ShellPrefs.darkTheme ? "dark" : "light"
    themeProc.command = path && path.length
      ? ["bash", root.themeScript, path, mode]
      : ["bash", root.themeScript, "", mode]
    themeProc.running = false
    themeProc.running = true
  }

  function ingestColorsText(raw) {
    try {
      if (!raw || raw.length < 2)
        return false
      applyPalette(JSON.parse(raw), true)
      rememberPendingPalette()
      return true
    } catch (e) {
      return false
    }
  }

  function reloadFromDisk() {
    colorsFile.reload()
  }

  Process {
    id: themeProc
    onExited: code => {
      // Read immediately — FileView watch can lag after matugen exits.
      colorsCat.running = false
      colorsCat.running = true
    }
  }

  Process {
    id: colorsCat
    command: ["cat", root.colorsPath]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.ingestColorsText(text.trim()))
          root.reloadFromDisk()
      }
    }
  }

  FileView {
    id: cacheFile
    path: root.cachePath
    blockLoading: false
    watchChanges: false
  }

  FileView {
    id: colorsFile
    path: root.colorsPath
    blockLoading: true
    watchChanges: true
    Component.onCompleted: {
      Quickshell.execDetached([
        "bash", "-c", "mkdir -p \"$HOME/.cache/quickshell\""
      ])
      root.loadCache()
      root.animateColors = false
      if (ShellPrefs.extractTheme)
        root.reloadPalette()
      else
        root.syncAppearancePalette(false)
      root.animateColors = true
      if (ShellPrefs.extractTheme)
        root.applyFromWallpaper("")
    }
    onFileChanged: colorsFile.reload()
    onLoaded: {
      if (!ShellPrefs.extractTheme)
        return
      if (themeProc.running)
        return
      root.reloadPalette()
      root.rememberPendingPalette()
    }
  }

  Connections {
    target: ShellPrefs
    function onAppearanceModeChanged() {
      if (!ShellPrefs.extractTheme)
        root.syncAppearancePalette(true)
    }
  }
}
