pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Lightweight prefs for Shell Settings (JSON under ~/.cache/quickshell).
Singleton {
  id: root

  property bool transparency: false
  property bool darkTheme: true
  // "light" | "calm" | "dark" — Control slider; drives fixed vs extracted bar theme.
  property string appearanceMode: "calm"
  property bool panelDashboard: true
  property bool panelTaskbar: true
  property bool panelLauncher: true
  property bool panelSidebar: true
  property string uiLanguage: "ru"

  readonly property string prefsPath: (Quickshell.env("HOME") || "/home/user")
                                      + "/.cache/quickshell/shell-prefs.json"

  readonly property bool extractTheme: appearanceMode === "calm"

  function save() {
    const data = {
      transparency: root.transparency,
      darkTheme: root.darkTheme,
      appearanceMode: root.appearanceMode,
      panelDashboard: root.panelDashboard,
      panelTaskbar: root.panelTaskbar,
      panelLauncher: root.panelLauncher,
      panelSidebar: root.panelSidebar,
      uiLanguage: root.uiLanguage
    }
    saveProc.command = [
      "sh", "-c",
      "mkdir -p \"$(dirname '" + root.prefsPath + "')\" && cat > '" + root.prefsPath + "' <<'EOF'\n"
          + JSON.stringify(data, null, 2) + "\nEOF"
    ]
    saveProc.running = true
  }

  function applyLoaded(text) {
    try {
      const d = JSON.parse(text)
      if (typeof d.transparency === "boolean")
        root.transparency = d.transparency
      if (typeof d.darkTheme === "boolean")
        root.darkTheme = d.darkTheme
      if (typeof d.appearanceMode === "string"
          && (d.appearanceMode === "light" || d.appearanceMode === "calm"
              || d.appearanceMode === "dark"))
        root.appearanceMode = d.appearanceMode
      if (typeof d.panelDashboard === "boolean")
        root.panelDashboard = d.panelDashboard
      if (typeof d.panelTaskbar === "boolean")
        root.panelTaskbar = d.panelTaskbar
      if (typeof d.panelLauncher === "boolean")
        root.panelLauncher = d.panelLauncher
      if (typeof d.panelSidebar === "boolean")
        root.panelSidebar = d.panelSidebar
      if (typeof d.uiLanguage === "string")
        root.uiLanguage = d.uiLanguage
    } catch (e) {}
  }

  Process {
    id: saveProc
  }

  Process {
    id: loadProc
    command: ["sh", "-c", "cat '" + root.prefsPath + "' 2>/dev/null || true"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim().length)
          root.applyLoaded(text)
      }
    }
  }

  function persistSoon() {
    persistTimer.restart()
  }

  Timer {
    id: persistTimer
    interval: 200
    repeat: false
    onTriggered: root.save()
  }
}
