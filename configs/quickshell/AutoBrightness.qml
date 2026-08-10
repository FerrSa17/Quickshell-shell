pragma Singleton

import Quickshell
import QtQuick

// Time-based brightness: 100% 07:00–21:30, 50% 21:30–07:00.
// Applies only on period change (and once at startup) so Output can override until then.
Singleton {
  id: root

  readonly property int dayStartMin: 7 * 60
  readonly property int nightStartMin: 21 * 60 + 30

  property int tick: 0
  property bool lastIsDay: true
  property bool ready: false

  readonly property bool isDay: {
    const _ = root.tick
    const d = new Date()
    const mins = d.getHours() * 60 + d.getMinutes()
    return mins >= root.dayStartMin && mins < root.nightStartMin
  }

  function targetPercent() {
    return root.isDay ? 100 : 50
  }

  function applyNow() {
    root.lastIsDay = root.isDay
    Brightness.setPercent(root.targetPercent())
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: {
      root.tick++
      if (!root.ready)
        return
      if (root.isDay !== root.lastIsDay)
        root.applyNow()
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: false
    onTriggered: {
      root.tick++
      root.ready = true
      root.applyNow()
    }
  }
}
