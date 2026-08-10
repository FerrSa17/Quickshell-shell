pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Shared active-window + per-workspace client icons for the bar.
Singleton {
  id: root

  property string appClass: ""
  property string winTitle: ""
  // wsId -> [{ cls, title, icon }, ...]
  property var clientsByWs: ({})
  property int clientsRev: 0

  readonly property bool isDesktop: !(root.appClass || "").trim().length

  readonly property string label: {
    const name = root.displayName(root.appClass, root.winTitle)
    return name.length > 0 ? name : "Desktop"
  }

  readonly property string icon: root.iconFor(root.appClass, root.winTitle)

  function displayName(appClass, winTitle) {
    const c = (appClass || "").toLowerCase()
    const t = (winTitle || "").toLowerCase()
    if (!c && !t)
      return ""

    if (c === "kitty" || c === "alacritty" || c === "wezterm" || c === "foot" || c === "ghostty")
      return "Terminal"
    if (c.indexOf("terminal") >= 0)
      return "Terminal"
    if (c === "firefox" || c.indexOf("firefox") >= 0)
      return "Firefox"
    if (c === "vscodium" || c === "codium" || c.indexOf("vscodium") >= 0 || c.indexOf("codium") >= 0)
      return "VSCodium"
    if (c === "cursor" || c.indexOf("cursor") >= 0)
      return "Cursor"
    if (c === "obs" || c.indexOf("obsproject") >= 0)
      return "OBS"
    if (c === "obsidian")
      return "Obsidian"
    if (c === "chromium" || c.indexOf("chrom") >= 0)
      return "Chrome"
    if (c === "code" || c === "code-oss")
      return "VS Code"
    if (c === "thunar" || c === "nautilus" || c === "dolphin" || c === "pcmanfm")
      return "Files"
    if (c.indexOf("telegram") >= 0)
      return "Telegram"
    if (c.indexOf("discord") >= 0)
      return "Discord"
    if (c.indexOf("spotify") >= 0)
      return "Spotify"
    if (c.indexOf("steam") >= 0)
      return "Steam"

    const raw = (appClass || "").trim()
    if (!raw.length)
      return ""
    const parts = raw.split(/[.]/)
    let base = parts[parts.length - 1] || raw
    base = base.replace(/-?[0-9]+$/, "")
    if (!base.length)
      base = raw
    return base.charAt(0).toUpperCase() + base.slice(1)
  }

  function iconFor(appClass, winTitle) {
    const c = (appClass || "").toLowerCase()
    const t = (winTitle || "").toLowerCase()
    if (!c.trim().length)
      return String.fromCodePoint(0xf0379)

    const hay = c + " " + t

    if (c === "kitty" || c === "alacritty" || c === "wezterm" || c === "foot"
        || c === "ghostty" || c.indexOf("terminal") >= 0 || hay.indexOf("kitty") >= 0)
      return String.fromCodePoint(0xe795)

    if (c === "firefox" || c.indexOf("firefox") >= 0)
      return String.fromCodePoint(0xf0239)

    if (c === "vscodium" || c === "codium" || c.indexOf("vscodium") >= 0 || c.indexOf("codium") >= 0)
      return String.fromCodePoint(0xf372)

    if (c === "cursor" || c.indexOf("cursor") >= 0)
      return String.fromCodePoint(0xf01c0)

    if (c === "obs" || c.indexOf("obsproject") >= 0)
      return String.fromCodePoint(0xeba7)

    if (c === "obsidian" || hay.indexOf("obsidian") >= 0)
      return String.fromCodePoint(0xf219)

    return String.fromCodePoint(0xf2d0)
  }

  function clientsOn(wsId) {
    const _ = root.clientsRev
    const list = root.clientsByWs[wsId] || root.clientsByWs["" + wsId]
    return list || []
  }

  function refresh() {
    activeProc.running = true
    clientsProc.running = true
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name
      if (n === "activewindow" || n === "activewindowv2" || n === "windowtitle"
          || n === "openwindow" || n === "closewindow" || n === "focusedmon"
          || n === "workspace" || n === "workspacev2" || n === "movewindow"
          || n === "movewindowv2")
        root.refresh()
    }
    function onActiveToplevelChanged() {
      root.refresh()
    }
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: activeProc
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const raw = text.trim()
          if (!raw.length || raw[0] !== "{") {
            root.appClass = ""
            root.winTitle = ""
            return
          }
          const w = JSON.parse(raw)
          if (!w || !w.class || w.address === "0x0") {
            root.appClass = ""
            root.winTitle = ""
            return
          }
          root.appClass = "" + (w.class || w.initialClass || "")
          root.winTitle = "" + (w.title || "")
        } catch (e) {
          // keep previous
        }
      }
    }
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const raw = text.trim()
          if (!raw.length || raw[0] !== "[")
            return
          const clients = JSON.parse(raw)
          const by = ({})
          for (let i = 0; i < clients.length; i++) {
            const c = clients[i]
            if (!c || c.mapped === false || c.hidden === true)
              continue
            const ws = c.workspace
            const wid = ws && ws.id !== undefined ? ws.id : null
            if (wid === null || wid < 1)
              continue
            const cls = "" + (c.class || c.initialClass || "")
            if (!cls.length)
              continue
            const title = "" + (c.title || "")
            const entry = {
              cls: cls,
              title: title,
              icon: root.iconFor(cls, title)
            }
            if (!by[wid])
              by[wid] = []
            by[wid].push(entry)
          }
          root.clientsByWs = by
          root.clientsRev++
        } catch (e) {
          // keep previous
        }
      }
    }
  }

  Component.onCompleted: root.refresh()
}
