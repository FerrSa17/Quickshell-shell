pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Daily time spent at this PC. Survives reboot via JSON on disk.
Singleton {
  id: root

  readonly property string statsPath: (Quickshell.env("HOME") || "/home/user")
                                      + "/.local/state/quickshell/screen-time.json"
  readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

  property var days: ({})
  property real lastTick: 0
  property real bootMs: 0
  property bool ready: false
  property bool loadDone: false
  property bool bootDone: false
  property var week: []
  property real todayMs: 0
  property string todayText: "0m"
  property int rev: 0

  function dayKey(ms) {
    const d = new Date(ms)
    const y = d.getFullYear()
    const m = String(d.getMonth() + 1).padStart(2, "0")
    const day = String(d.getDate()).padStart(2, "0")
    return y + "-" + m + "-" + day
  }

  function fmtMs(ms) {
    const tot = Math.max(0, Math.round(Number(ms) / 60000))
    const h = Math.floor(tot / 60)
    const m = tot % 60
    if (h > 0)
      return h + "h " + m + "m"
    return m + "m"
  }

  function rebuildWeek() {
    const now = Date.now()
    const out = []
    for (let i = 6; i >= 0; i--) {
      const ms = now - i * 86400000
      const k = root.dayKey(ms)
      const v = Number((root.days && root.days[k]) || 0)
      const d = new Date(ms)
      out.push({
        date: k,
        label: root.dayNames[d.getDay()],
        ms: v,
        text: root.fmtMs(v)
      })
    }
    const today = root.dayKey(now)
    root.todayMs = Number((root.days && root.days[today]) || 0)
    root.todayText = root.fmtMs(root.todayMs)
    root.week = out
    root.rev++
  }

  function prune(map) {
    const keep = {}
    const now = Date.now()
    for (let i = 0; i < 21; i++) {
      const k = root.dayKey(now - i * 86400000)
      if (map[k])
        keep[k] = map[k]
    }
    return keep
  }

  function addChunk(map, startMs, amount) {
    let remaining = amount
    let cursor = startMs
    while (remaining > 0) {
      const d = new Date(cursor)
      const nextMidnight = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime()
      const chunk = Math.min(remaining, Math.max(1, nextMidnight - cursor))
      const k = root.dayKey(cursor)
      map[k] = (Number(map[k]) || 0) + chunk
      cursor += chunk
      remaining -= chunk
    }
  }

  function tick() {
    if (!root.ready)
      return
    const now = Date.now()
    if (!root.lastTick || root.lastTick <= 0) {
      root.lastTick = now
      root.rebuildWeek()
      root.save()
      return
    }
    const gap = now - root.lastTick
    if (gap <= 0) {
      root.lastTick = now
      return
    }
    // Sleep / shutdown / long pause — do not count time the PC was off.
    if (gap > 120000) {
      root.lastTick = now
      root.save()
      return
    }
    const map = Object.assign({}, root.days)
    root.addChunk(map, root.lastTick, gap)
    root.days = root.prune(map)
    root.lastTick = now
    root.rebuildWeek()
    root.save()
  }

  function seedFromBoot() {
    if (root.bootMs <= 0)
      return
    const now = Date.now()
    if (now < root.bootMs)
      return
    const bootDay = root.dayKey(root.bootMs)
    const today = root.dayKey(now)
    if (bootDay !== today)
      return
    if (root.lastTick > 0 && root.lastTick >= root.bootMs)
      return
    const map = Object.assign({}, root.days)
    const extra = Math.min(now - root.bootMs, 24 * 3600 * 1000)
    map[today] = (Number(map[today]) || 0) + extra
    root.days = root.prune(map)
    root.lastTick = now
  }

  function applyLoaded(raw) {
    try {
      const d = JSON.parse(raw)
      if (d && typeof d.days === "object" && d.days)
        root.days = d.days
      if (typeof d.lastTick === "number")
        root.lastTick = d.lastTick
    } catch (e) {
      root.days = ({})
      root.lastTick = 0
    }
  }

  function save() {
    const data = {
      days: root.days,
      lastTick: root.lastTick
    }
    saveProc.command = [
      "sh", "-c",
      "mkdir -p \"$(dirname '" + root.statsPath + "')\" && cat > '" + root.statsPath + "' <<'EOF'\n"
          + JSON.stringify(data) + "\nEOF"
    ]
    saveProc.running = true
  }

  function maybeReady() {
    if (root.ready)
      return
    if (!root.loadDone || !root.bootDone)
      return
    root.seedFromBoot()
    root.ready = true
    root.rebuildWeek()
    root.save()
  }

  Process {
    id: saveProc
  }

  Process {
    id: loadProc
    command: ["sh", "-c", "cat '" + root.statsPath + "' 2>/dev/null || true"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim().length)
          root.applyLoaded(text)
        root.loadDone = true
        root.maybeReady()
      }
    }
  }

  Process {
    id: bootProc
    command: ["awk", "/btime/ {print $2}", "/proc/stat"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const n = Number(text.trim())
        if (n > 0)
          root.bootMs = n * 1000
        root.bootDone = true
        root.maybeReady()
      }
    }
  }

  Timer {
    interval: 5000
    running: root.ready
    repeat: true
    triggeredOnStart: true
    onTriggered: root.tick()
  }

  Connections {
    target: Qt.application
    function onAboutToQuit() {
      root.tick()
      root.save()
    }
  }
}
