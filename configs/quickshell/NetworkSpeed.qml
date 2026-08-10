pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property real downBps: 0
  property real upBps: 0
  property var prev: ({ rx: 0, tx: 0, t: 0 })

  readonly property string downText: formatRate(downBps)
  readonly property string upText: formatRate(upBps)

  function formatRate(bps) {
    if (bps < 1024)
      return Math.round(bps) + " B/s"
    if (bps < 1024 * 1024)
      return (bps / 1024).toFixed(1) + " KiB/s"
    return (bps / 1024 / 1024).toFixed(1) + " MiB/s"
  }

  function refresh() {
    speedProc.running = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: speedProc
    command: ["sh", "-c", "awk 'NR>2 && $1!=\"lo:\" {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev"]
    stdout: StdioCollector {
      onStreamFinished: {
        const parts = text.trim().split(/\s+/)
        if (parts.length < 2)
          return
        const rx = parseInt(parts[0])
        const tx = parseInt(parts[1])
        const now = Date.now()
        if (isNaN(rx) || isNaN(tx))
          return
        if (root.prev.t > 0) {
          const dt = (now - root.prev.t) / 1000
          if (dt > 0) {
            root.downBps = Math.max(0, (rx - root.prev.rx) / dt)
            root.upBps = Math.max(0, (tx - root.prev.tx) / dt)
          }
        }
        root.prev = { rx: rx, tx: tx, t: now }
      }
    }
  }
}
