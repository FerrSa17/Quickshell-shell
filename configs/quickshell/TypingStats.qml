pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string statsPath: (Quickshell.env("HOME") || "/home/user")
                                      + "/.local/state/quickshell/typing-stats.json"
  readonly property string monitorScript: (Quickshell.env("HOME") || "/home/user")
                                          + "/.config/quickshell/scripts/typing-speed-monitor.py"

  property real currentWpm: 0
  property real todayWpm: 0
  property var week: []
  property int rev: 0

  function ensureMonitor() {
    Quickshell.execDetached([
      "bash", "-c",
      "mkdir -p \"$HOME/.local/state/quickshell\"; "
      + "python3 \"" + root.monitorScript + "\" >/dev/null 2>&1 &"
    ])
  }

  function applyText(raw) {
    try {
      if (!raw || raw.length < 2)
        return
      const d = JSON.parse(raw)
      root.currentWpm = typeof d.currentWpm === "number" ? d.currentWpm : 0
      root.todayWpm = typeof d.todayWpm === "number" ? d.todayWpm : 0
      root.week = Array.isArray(d.week) ? d.week : []
      root.rev++
    } catch (e) {}
  }

  function reload() {
    statsFile.reload()
  }

  FileView {
    id: statsFile
    path: root.statsPath
    blockLoading: false
    watchChanges: true
    onFileChanged: statsFile.reload()
    onLoaded: root.applyText(text())
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.reload()
  }

  Component.onCompleted: {
    root.ensureMonitor()
    root.reload()
  }
}
