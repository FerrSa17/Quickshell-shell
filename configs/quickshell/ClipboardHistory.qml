pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property int rev: 0
  property var entries: []
  property var pins: []
  property var lastClip: []
  property var pinQueue: []
  property var pendingPin: null
  readonly property bool hasUnpinned: {
    const _ = root.rev
    const list = root.entries
    if (!list || !list.length)
      return false
    for (let i = 0; i < list.length; i++) {
      if (!list[i].pinned)
        return true
    }
    return false
  }
  readonly property string pinsPath: Quickshell.statePath("clipboard-pins.json")
  readonly property string pinsDir: (Quickshell.env("HOME") || "/home/user")
                                    + "/.local/state/quickshell/clipboard-pins"

  function refresh() {
    listProc.running = true
  }

  function wipe() {
    Quickshell.execDetached(["cliphist", "wipe"])
    root.lastClip = []
    root.rebuild([])
  }

  function isPinnedClip(clipId) {
    const id = String(clipId || "")
    for (let i = 0; i < root.pins.length; i++) {
      if (String(root.pins[i].clipId) === id)
        return true
    }
    return false
  }

  function togglePin(entry) {
    if (!entry)
      return
    if (entry.pinned)
      root.unpin(entry.pinKey || entry.key)
    else
      root.pin(entry)
  }

  function unpin(pinKey) {
    const key = String(pinKey || "")
    if (!key.length)
      return
    const next = []
    for (let i = 0; i < root.pins.length; i++) {
      const p = root.pins[i]
      if (String(p.pinKey) === key) {
        if (p.path)
          Quickshell.execDetached(["rm", "-f", String(p.path)])
        continue
      }
      next.push(p)
    }
    root.pins = next
    root.savePins()
    root.rebuild(root.lastClip)
    root.refresh()
  }

  function pin(entry) {
    const clipId = String((entry && entry.id) || "")
    if (!clipId.length)
      return
    if (root.isPinnedClip(clipId))
      return
    const item = {
      clipId: clipId,
      preview: String((entry && entry.preview) || ""),
      isImage: !!(entry && entry.isImage)
    }
    if (item.isImage) {
      root.pinImage(item)
      return
    }
    const q = root.pinQueue.slice()
    q.push(item)
    root.pinQueue = q
    root.pumpPin()
  }

  function pinImage(item) {
    const pinKey = String(Date.now()) + "-" + item.clipId
    const path = root.pinsDir + "/" + pinKey + ".bin"
    Quickshell.execDetached([
      "bash", "-c",
      'mkdir -p "$1"; cliphist decode "$2" > "$3"',
      "pinImg",
      root.pinsDir,
      item.clipId,
      path
    ])
    root.prependPin({
      pinKey: pinKey,
      clipId: item.clipId,
      preview: "Image",
      isImage: true,
      path: path,
      text: ""
    })
  }

  function pumpPin() {
    if (decodeProc.running || root.pendingPin)
      return
    if (!root.pinQueue.length)
      return
    const q = root.pinQueue.slice()
    const next = q.shift()
    root.pinQueue = q
    if (root.isPinnedClip(next.clipId)) {
      Qt.callLater(() => root.pumpPin())
      return
    }
    root.pendingPin = next
    decodeProc.command = ["cliphist", "decode", next.clipId]
    decodeProc.running = true
  }

  function prependPin(pin) {
    const next = [pin]
    for (let i = 0; i < root.pins.length; i++)
      next.push(root.pins[i])
    root.pins = next
    root.savePins()
    root.rebuild(root.lastClip)
  }

  function copyEntry(entry) {
    if (!entry)
      return
    if (entry.pinned) {
      if (entry.isImage && entry.path) {
        Quickshell.execDetached([
          "bash", "-c",
          't=$(file -b --mime-type "$1" 2>/dev/null || echo application/octet-stream); wl-copy --type "$t" < "$1"',
          "copyPinImg",
          String(entry.path)
        ])
        return
      }
      if (entry.text && String(entry.text).length) {
        Quickshell.execDetached([
          "bash", "-c",
          'printf %s "$1" | wl-copy',
          "copyPin",
          String(entry.text)
        ])
        return
      }
    }
    const id = String(entry.id || "")
    if (!id.length)
      return
    Quickshell.execDetached([
      "bash", "-c",
      "cliphist decode \"$1\" | wl-copy",
      "copyEntry",
      id
    ])
  }

  function parseList(raw) {
    const lines = (raw || "").split("\n").filter(s => s.length > 0)
    const clip = []
    const n = Math.min(50, lines.length)
    for (let i = 0; i < n; i++) {
      const line = lines[i]
      const tab = line.indexOf("\t")
      const id = tab >= 0 ? line.slice(0, tab) : line
      const preview = tab >= 0 ? line.slice(tab + 1) : ""
      const isImage = /\[\[?\s*binary.*(png|jpe?g|gif|webp)/i.test(preview)
                    || /^\[\[ binary data/i.test(preview)
      clip.push({
        id: id,
        preview: isImage ? "Image" : preview,
        isImage: isImage
      })
    }
    root.lastClip = clip
    root.rebuild(clip)
  }

  function rebuild(clipRows) {
    const rows = clipRows || []
    const pinnedIds = {}
    const pinnedText = {}
    const top = []
    for (let i = 0; i < root.pins.length; i++) {
      const p = root.pins[i]
      pinnedIds[String(p.clipId)] = true
      if (p.preview)
        pinnedText[String(p.preview)] = true
      top.push({
        key: p.pinKey,
        pinKey: p.pinKey,
        id: p.clipId,
        preview: p.preview,
        isImage: !!p.isImage,
        path: p.path || "",
        text: p.text || "",
        pinned: true
      })
    }
    const rest = []
    for (let i = 0; i < rows.length; i++) {
      const e = rows[i]
      if (pinnedIds[String(e.id)])
        continue
      if (!e.isImage && pinnedText[String(e.preview)])
        continue
      rest.push({
        key: "c-" + e.id,
        pinKey: "",
        id: e.id,
        preview: e.preview,
        isImage: !!e.isImage,
        path: "",
        text: "",
        pinned: false
      })
    }
    root.entries = top.concat(rest)
    root.rev++
  }

  function loadPins() {
    try {
      const raw = pinsFile.text()
      if (!raw || raw.length < 2) {
        root.pins = []
        return
      }
      const parsed = JSON.parse(raw)
      root.pins = Array.isArray(parsed) ? parsed : []
    } catch (e) {
      root.pins = []
    }
  }

  function savePins() {
    try {
      pinsFile.setText(JSON.stringify(root.pins))
    } catch (e) {}
  }

  FileView {
    id: pinsFile
    path: root.pinsPath
    blockLoading: true
    watchChanges: false
    Component.onCompleted: {
      root.loadPins()
      root.rebuild(root.lastClip)
    }
    onLoaded: {
      root.loadPins()
      root.rebuild(root.lastClip)
    }
  }

  Process {
    id: decodeProc
    stdout: StdioCollector {
      onStreamFinished: {
        const decoded = text
        const pending = root.pendingPin
        root.pendingPin = null
        if (!pending) {
          Qt.callLater(() => root.pumpPin())
          return
        }
        root.prependPin({
          pinKey: String(Date.now()) + "-" + pending.clipId,
          clipId: pending.clipId,
          preview: pending.preview || String(decoded).replace(/\s+/g, " ").slice(0, 200),
          isImage: false,
          path: "",
          text: String(decoded)
        })
        Qt.callLater(() => root.pumpPin())
      }
    }
  }

  Process {
    id: listProc
    command: ["cliphist", "list"]
    stdout: StdioCollector {
      onStreamFinished: root.parseList(text)
    }
  }

  Process {
    id: watchProc
    running: true
    command: ["wl-paste", "--watch", "cliphist", "store"]
    onExited: watchRestart.restart()
  }

  Timer {
    id: watchRestart
    interval: 800
    repeat: false
    onTriggered: watchProc.running = true
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
