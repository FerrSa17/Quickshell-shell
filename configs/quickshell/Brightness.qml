pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property int percent: 100
  property int maxValue: 100
  property int pending: -1
  property real percentSmooth: 100

  Behavior on percentSmooth {
    NumberAnimation {
      duration: 1400
      easing.type: Easing.OutCubic
    }
  }

  readonly property string display: Math.round(percentSmooth) + "%"

  onPercentChanged: percentSmooth = percent

  function refresh() {
    getProc.running = true
  }

  function adjust(delta) {
    setPercent(percent + delta)
  }

  function setPercent(p) {
    const next = Math.max(0, Math.min(100, Math.round(p)))
    percent = next
    pending = next
    setTimer.restart()
  }

  function setNormalized(v) {
    setPercent(v * 100)
  }

  Component.onCompleted: {
    percentSmooth = percent
    refresh()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: {
      if (root.pending < 0)
        root.refresh()
    }
  }

  Timer {
    id: setTimer
    interval: 150
    onTriggered: {
      if (root.pending < 0)
        return
      const raw = Math.round(root.pending / 100.0 * root.maxValue)
      setProc.command = ["ddcutil", "setvcp", "10", String(raw)]
      setProc.running = true
      root.pending = -1
    }
  }

  Process {
    id: getProc
    command: ["ddcutil", "--brief", "getvcp", "10"]
    stdout: StdioCollector {
      onStreamFinished: {
        // VCP 10 C <current> <max>
        const parts = text.trim().split(/\s+/)
        if (parts.length < 4)
          return
        const cur = parseInt(parts[2])
        const max = parseInt(parts[3])
        if (isNaN(cur) || isNaN(max) || max <= 0)
          return
        root.maxValue = max
        if (root.pending < 0)
          root.percent = Math.round(cur / max * 100)
      }
    }
  }

  Process {
    id: setProc
  }
}
