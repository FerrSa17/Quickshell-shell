pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property bool hasAdapter: false
  property bool powered: false
  property bool busy: false
  property bool scanning: false
  property bool watch: false
  property var devices: []
  property string statusText: "No adapter"
  property int rev: 0
  property bool pairing: false
  property string connectingAddress: ""
  property string joinState: ""
  property string joinError: ""
  property bool joinPinFail: false
  property bool joinUsedPin: false
  readonly property string pairScript: (Quickshell.env("HOME") || "/home/user")
                                       + "/.config/quickshell/scripts/bt-pair.py"

  function refresh() {
    if (root.scanning)
      return
    if (!root.hasAdapter)
      root.busy = true
    adapterProc.running = true
  }

  function startWatch() {
    root.watch = true
    root.refresh()
  }

  function stopWatch() {
    root.watch = false
    root.cancelPair()
  }

  function setPowered(on) {
    if (!root.hasAdapter)
      return
    Quickshell.execDetached([
      "bash",
      "-c",
      on ? "timeout 3s bluetoothctl power on" : "timeout 3s bluetoothctl power off"
    ])
    powerWait.restart()
  }

  function connect(address) {
    root.pairConnect(address, "")
  }

  function pairConnect(address, pin) {
    const addr = String(address || "")
    if (!addr.length)
      return
    root.pairing = true
    root.scanning = false
    scanProc.running = false
    root.connectingAddress = addr
    root.joinState = "connecting"
    root.joinError = ""
    root.joinPinFail = false
    root.joinUsedPin = String(pin || "").length > 0
    root.rev++
    pairProc.command = [
      "python3",
      root.pairScript,
      "--address",
      addr,
      "--pin",
      String(pin || "")
    ]
    pairProc.running = true
  }

  function cancelPair() {
    pairProc.running = false
    root.pairing = false
    root.connectingAddress = ""
    if (root.joinState === "connecting") {
      root.joinState = ""
      root.joinError = ""
      root.joinPinFail = false
    }
    root.rev++
  }

  function bumpStatus() {
    if (!root.hasAdapter)
      root.statusText = "No adapter"
    else if (!root.powered)
      root.statusText = "Off"
    else if (root.scanning)
      root.statusText = "Scanning…"
    else if (root.devices.some(d => d.connected))
      root.statusText = "Connected"
    else if (root.devices.length)
      root.statusText = "On"
    else
      root.statusText = "No devices"
    root.rev++
  }

  function section(raw, name) {
    const tag = "---" + name + "---"
    const start = (raw || "").indexOf(tag)
    if (start < 0)
      return ""
    const from = start + tag.length
    const next = raw.indexOf("---", from)
    return next < 0 ? raw.slice(from) : raw.slice(from, next)
  }

  function applySnapshot(raw) {
    root.parseDeviceLines(
      root.section(raw, "DEVICES"),
      root.parseAddrSet(root.section(raw, "PAIRED")),
      root.parseAddrSet(root.section(raw, "CONNECTED"))
    )
  }

  function parseDeviceLines(raw, pairedSet, connectedSet) {
    const lines = (raw || "").trim().split("\n")
    const seen = {}
    const out = []
    for (let i = 0; i < lines.length; i++) {
      const m = lines[i].match(/^Device\s+([0-9A-Fa-f:]{11,})\s+(.*)$/)
      if (!m)
        continue
      const address = m[1]
      if (seen[address])
        continue
      seen[address] = true
      const connected = !!(connectedSet && connectedSet[address])
      const paired = connected || !!(pairedSet && pairedSet[address])
      out.push({
        address: address,
        name: (m[2] || address).trim() || address,
        connected: connected,
        paired: paired
      })
    }
    out.sort((a, b) => {
      if (a.connected !== b.connected)
        return a.connected ? -1 : 1
      if (a.paired !== b.paired)
        return a.paired ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    root.devices = out
    root.bumpStatus()
  }

  function parseAddrSet(raw) {
    const set = {}
    const lines = (raw || "").trim().split("\n")
    for (let i = 0; i < lines.length; i++) {
      const m = lines[i].match(/^Device\s+([0-9A-Fa-f:]{11,})/)
      if (m)
        set[m[1]] = true
    }
    return set
  }

  Component.onCompleted: refresh()

  Timer {
    id: powerWait
    interval: 900
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: connectWait
    interval: 2200
    repeat: false
    onTriggered: {
      if (!root.scanning)
        devicesProc.running = true
    }
  }

  Timer {
    interval: 9000
    running: root.watch && root.hasAdapter && root.powered && !root.scanning && !root.pairing
    repeat: true
    onTriggered: scanProc.running = true
  }

  Timer {
    interval: 2500
    running: root.watch && !root.hasAdapter && !root.busy
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: adapterProc
    command: [
      "bash",
      "-c",
      "timeout 2s bluetoothctl list 2>/dev/null | awk '/Controller/{print; exit}'"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        const found = text.trim().indexOf("Controller") >= 0
        root.hasAdapter = found
        if (!found) {
          root.powered = false
          root.devices = []
          root.scanning = false
          root.busy = false
          root.bumpStatus()
          return
        }
        powerProc.running = true
      }
    }
  }

  Process {
    id: powerProc
    command: [
      "bash",
      "-c",
      "timeout 2s bluetoothctl show 2>/dev/null | awk -F': ' '/Powered/ {print $2; found=1; exit} END { if(!found) print \"no\" }'"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        root.powered = text.trim().toLowerCase() === "yes"
        if (!root.powered) {
          root.devices = []
          root.scanning = false
          root.busy = false
          root.bumpStatus()
          return
        }
        devicesProc.running = true
      }
    }
  }

  Process {
    id: devicesProc
    command: [
      "bash",
      "-c",
      "echo '---DEVICES---'; timeout 2s bluetoothctl devices 2>/dev/null || true; "
        + "echo '---PAIRED---'; timeout 2s bluetoothctl devices Paired 2>/dev/null || true; "
        + "echo '---CONNECTED---'; timeout 2s bluetoothctl devices Connected 2>/dev/null || true"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        root.applySnapshot(text)
        root.busy = false
        if (root.powered && root.watch && !root.scanning && !root.pairing)
          scanProc.running = true
      }
    }
  }

  Process {
    id: scanProc
    command: [
      "bash",
      "-c",
      "timeout 8s bluetoothctl --timeout 6 scan on >/dev/null 2>&1 || true; "
        + "echo '---DEVICES---'; timeout 2s bluetoothctl devices 2>/dev/null || true; "
        + "echo '---PAIRED---'; timeout 2s bluetoothctl devices Paired 2>/dev/null || true; "
        + "echo '---CONNECTED---'; timeout 2s bluetoothctl devices Connected 2>/dev/null || true"
    ]
    onRunningChanged: {
      if (running) {
        if (root.pairing) {
          running = false
          return
        }
        root.scanning = true
        root.bumpStatus()
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.scanning = false
        if (!root.pairing)
          root.applySnapshot(text)
        root.busy = false
      }
    }
  }

  Process {
    id: pairProc
    stdout: StdioCollector {
      id: pairOut
    }
    stderr: StdioCollector {
      id: pairErr
    }
    onExited: code => {
      root.pairing = false
      if (code === 0) {
        root.joinState = "ok"
        root.joinError = ""
        root.joinPinFail = false
      } else {
        const err = (pairErr.text || pairOut.text || "").trim()
        root.joinState = "fail"
        root.joinError = ""
        root.joinPinFail = root.joinUsedPin || /auth|pin|passkey|secret/.test(String(err).toLowerCase())
        root.connectingAddress = ""
      }
      root.rev++
      if (root.watch && !root.scanning)
        devicesProc.running = true
    }
  }
}
