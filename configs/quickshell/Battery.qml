import QtQuick
import Quickshell
import Quickshell.Io

// Sysfs-backed battery (no UPower dependency — avoids startup errors when upower is absent).
Item {
  id: root

  property int pct: 0
  property bool show: false

  implicitWidth: show ? content.implicitWidth : 0
  implicitHeight: content.implicitHeight
  visible: show

  function refresh() {
    batProc.running = true
  }

  Process {
    id: batProc
    command: [
      "sh",
      "-c",
      "for d in /sys/class/power_supply/BAT* /sys/class/power_supply/BAT[0-9]*; do\n"
        + "  [ -r \"$d/capacity\" ] || continue\n"
        + "  cat \"$d/capacity\"\n"
        + "  exit 0\n"
        + "done\n"
        + "exit 1\n"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const t = text.trim()
        if (!t.length) {
          root.show = false
          return
        }
        const n = parseInt(t, 10)
        if (isNaN(n)) {
          root.show = false
          return
        }
        root.pct = Math.max(0, Math.min(100, n))
        root.show = true
      }
    }

    onExited: code => {
      if (code !== 0)
        root.show = false
    }
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Stat {
    id: content
    icon: "\uf240"
    iconColor: root.pct <= 20 ? Theme.red : (root.pct <= 40 ? Theme.yellow : Theme.subtext)
    value: root.pct + "%"
    valueColor: Theme.text
  }
}
