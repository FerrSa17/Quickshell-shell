pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property bool wifiEnabled: false
  property bool busy: false
  property bool hasWifiAdapter: false
  property bool hasEthernet: false
  property bool wifiConnected: false
  property bool ethernetConnected: false
  property string wifiDevice: ""
  property string ethernetDevice: ""
  property string lastWifiSsid: ""
  property bool wantRescan: false
  property var networks: []
  property var knownSsids: []
  property string statusText: "Off"
  property string activeSsid: ""
  property string connectingSsid: ""
  property string joinState: ""
  property string joinError: ""
  property bool joinPasswordFail: false
  property bool joinUsedPassword: false
  property string ipv4: ""
  property string forgetSsid: ""
  property int rev: 0
  property bool wantWifiList: false
  property string preferredLink: ""

  readonly property bool canSwitch: hasWifiAdapter && hasEthernet
  readonly property string linkMode: {
    const _ = root.rev
    if (root.preferredLink === "wifi") {
      if (root.hasWifiAdapter)
        return "wifi"
      if (root.hasEthernet)
        return "wired"
      return "wifi"
    }
    if (root.preferredLink === "wired") {
      if (root.hasEthernet)
        return "wired"
      if (root.hasWifiAdapter)
        return "wifi"
      return "wired"
    }
    return root.ethernetConnected ? "wired" : "wifi"
  }

  function refresh() {
    root.wantRescan = false
    root.wantWifiList = true
    if (root.networks.length === 0)
      busy = true
    deviceProc.running = true
  }

  function refreshScan() {
    root.wantRescan = true
    root.wantWifiList = true
    if (root.networks.length === 0)
      busy = true
    deviceProc.running = true
  }

  function refreshDevices() {
    root.wantWifiList = false
    deviceProc.running = true
  }

  function setWifiEnabled(on) {
    Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
    Qt.callLater(() => root.refresh())
  }

  function setLinkMode(mode) {
    if (mode !== "wired" && mode !== "wifi")
      return
    if (!root.ethernetDevice.length && !root.wifiDevice.length)
      return
    root.preferredLink = mode
    root.rev++
    if (mode === "wifi") {
      const ssid = root.lastWifiSsid.length ? root.lastWifiSsid : root.activeSsid
      if (ssid.length)
        root.connectingSsid = ssid
    } else if (root.activeSsid.length) {
      root.lastWifiSsid = root.activeSsid
    }
    root.applyLinkMode()
    linkReapply.restart()
  }

  function recoverLink() {
    if (!root.preferredLink.length)
      return
    root.applyLinkMode()
    linkReapply.restart()
  }

  function applyLinkMode() {
    const mode = root.preferredLink
    if (mode !== "wired" && mode !== "wifi")
      return
    const wifiMetric = mode === "wifi" ? "50" : "700"
    const ethMetric = mode === "wired" ? "50" : "700"
    const ssid = root.lastWifiSsid.length ? root.lastWifiSsid : root.activeSsid
    Quickshell.execDetached([
      "bash", "-c",
      'eth="$1"; wifi="$2"; ssid="$3"; eth_m="$4"; wifi_m="$5"; mode="$6"; '
      + 'apply_metric() { '
      + '  local dev="$1" m="$2" con; '
      + '  [ -z "$dev" ] && return 0; '
      + '  nmcli device modify "$dev" ipv4.route-metric "$m" ipv6.route-metric "$m" >/dev/null 2>&1 || true; '
      + '  con=$(nmcli -t -g GENERAL.CONNECTION device show "$dev" 2>/dev/null || true); '
      + '  if [ -n "$con" ] && [ "$con" != "--" ]; then '
      + '    nmcli connection modify "$con" ipv4.route-metric "$m" ipv6.route-metric "$m" connection.autoconnect yes >/dev/null 2>&1 || true; '
      + '  fi; '
      + '}; '
      + 'if [ -n "$eth" ]; then '
      + '  nmcli device connect "$eth" >/dev/null 2>&1 || true; '
      + '  apply_metric "$eth" "$eth_m"; '
      + 'fi; '
      + 'if [ -n "$wifi" ]; then '
      + '  nmcli radio wifi on >/dev/null 2>&1 || true; '
      + '  nmcli device set "$wifi" autoconnect yes >/dev/null 2>&1 || true; '
      + '  if [ "$mode" = "wifi" ] && [ -n "$ssid" ]; then '
      + '    nmcli -w 20 connection up id "$ssid" >/dev/null 2>&1 '
      + '      || nmcli -w 20 device wifi connect "$ssid" >/dev/null 2>&1 '
      + '      || nmcli device connect "$wifi" >/dev/null 2>&1 || true; '
      + '  else '
      + '    nmcli device connect "$wifi" >/dev/null 2>&1 || true; '
      + '  fi; '
      + '  apply_metric "$wifi" "$wifi_m"; '
      + 'fi',
      "linkMode",
      root.ethernetDevice,
      root.wifiDevice,
      ssid,
      ethMetric,
      wifiMetric,
      mode
    ])
    linkRefresh.restart()
  }

  onHasWifiAdapterChanged: root.recoverLink()
  onHasEthernetChanged: root.recoverLink()

  function isPasswordFail(err) {
    const s = String(err || "").toLowerCase()
    return /secret|psk|password|wireless-security|802-1x/.test(s)
  }

  function isSecured(security) {
    const s = String(security || "").trim().toLowerCase()
    if (!s || s === "--" || s === "none" || s === "open")
      return false
    return true
  }

  function isKnown(ssid) {
    return root.knownSsids.indexOf(ssid) >= 0
  }

  function needsPassword(ssid, security) {
    if (!ssid || ssid.length === 0)
      return false
    return root.isSecured(security)
  }

  function markActive(ssid) {
    const name = String(ssid || "")
    root.activeSsid = name
    root.lastWifiSsid = name.length ? name : root.lastWifiSsid
    root.connectingSsid = ""
    if (name.length && root.knownSsids.indexOf(name) < 0)
      root.knownSsids = root.knownSsids.concat([name])
    const src = root.networks
    const next = []
    for (let i = 0; i < src.length; i++) {
      const n = src[i]
      next.push({
        ssid: n.ssid,
        signal: n.signal,
        active: n.ssid === name,
        security: n.security
      })
    }
    root.networks = next
    root.statusText = name.length ? name : (root.wifiEnabled ? "On" : "Off")
    root.rev++
  }

  function startJoin(ssid, password) {
    const name = String(ssid || "")
    if (!name.length)
      return
    root.connectingSsid = name
    root.joinState = "connecting"
    root.joinError = ""
    root.joinPasswordFail = false
    root.joinUsedPassword = !!(password && String(password).length)
    root.rev++
    if (password && password.length)
      joinProc.command = [
        "nmcli", "-w", "20", "device", "wifi", "connect", name, "password", password
      ]
    else
      joinProc.command = ["nmcli", "-w", "20", "device", "wifi", "connect", name]
    joinProc.running = true
  }

  function connect(ssid) {
    root.startJoin(ssid, "")
  }

  function connectWithPassword(ssid, password) {
    root.startJoin(ssid, password)
  }

  function refreshDetails() {
    root.ipv4 = ""
    if (!root.wifiDevice.length)
      return
    ipProc.command = [
      "nmcli", "-t", "-e", "yes", "-f", "IP4.ADDRESS", "device", "show", root.wifiDevice
    ]
    ipProc.running = true
  }

  function forget(ssid) {
    const name = String(ssid || "")
    if (!name.length)
      return
    root.forgetSsid = name
    forgetProc.command = ["nmcli", "connection", "delete", "id", name]
    forgetProc.running = true
  }

  function splitTerse(line) {
    const parts = []
    let cur = ""
    let esc = false
    for (let i = 0; i < line.length; i++) {
      const ch = line[i]
      if (esc) {
        cur += ch
        esc = false
        continue
      }
      if (ch === "\\") {
        esc = true
        continue
      }
      if (ch === ":") {
        parts.push(cur)
        cur = ""
        continue
      }
      cur += ch
    }
    parts.push(cur)
    return parts
  }

  function parseWifiList(raw) {
    const lines = (raw || "").trim().split("\n").filter(s => s.length > 0)
    const out = []
    for (let i = 0; i < lines.length; i++) {
      // ACTIVE:SSID:SIGNAL:SECURITY (values may be backslash-escaped by nmcli)
      const p = root.splitTerse(lines[i])
      if (p.length < 2)
        continue
      const active = p[0] === "yes" || p[0] === "*"
      const ssid = p[1]
      if (!ssid || ssid === "--")
        continue
      out.push({
        ssid: ssid,
        signal: Number(p[2] || 0),
        active: active,
        security: p[3] || ""
      })
    }
    if (out.length === 0 && root.networks.length > 0 && !root.wantRescan) {
      rev++
      busy = false
      return
    }
    networks = out
    let live = ""
    for (let i = 0; i < out.length; i++) {
      if (out[i].active) {
        live = out[i].ssid
        break
      }
    }
    root.activeSsid = live.length ? live : (root.wifiEnabled && root.wifiConnected ? root.activeSsid : "")
    statusText = wifiEnabled
               ? (root.activeSsid.length ? root.activeSsid : "On")
               : "Off"
    if (wifiEnabled && out.length === 0)
      statusText = "No networks"
    rev++
    busy = false
  }

  Component.onCompleted: refresh()

  Timer {
    id: linkRefresh
    interval: 1600
    repeat: false
    onTriggered: root.refreshDevices()
  }

  Timer {
    id: linkReapply
    interval: 2800
    repeat: false
    onTriggered: {
      if (root.preferredLink.length)
        root.applyLinkMode()
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: {
      if (!root.busy)
        root.refreshDevices()
    }
  }

  Process {
    id: deviceProc
    command: ["nmcli", "-t", "-e", "yes", "-f", "DEVICE,TYPE,STATE", "device", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        let wifiDev = ""
        let ethDev = ""
        let wifiUp = false
        let ethUp = false
        let ethIdle = false
        const lines = (text || "").trim().split("\n").filter(s => s.length > 0)
        for (let i = 0; i < lines.length; i++) {
          const p = root.splitTerse(lines[i])
          if (p.length < 3)
            continue
          const dev = p[0]
          const type = String(p[1] || "").toLowerCase()
          const state = String(p[2] || "").toLowerCase()
          const up = state === "connected" || state === "connecting"
          if (type === "wifi") {
            if (!wifiDev.length)
              wifiDev = dev
            if (up)
              wifiUp = true
          } else if (type === "ethernet") {
            if (!ethDev.length)
              ethDev = dev
            if (up)
              ethUp = true
            if (state === "disconnected")
              ethIdle = true
          }
        }
        root.hasWifiAdapter = wifiDev.length > 0
        root.hasEthernet = ethDev.length > 0
        root.wifiDevice = wifiDev
        root.ethernetDevice = ethDev
        root.wifiConnected = wifiUp
        root.ethernetConnected = ethUp
        root.rev++
        if (ethIdle && ethDev.length) {
          Quickshell.execDetached(["nmcli", "device", "connect", ethDev])
        }
        if (!root.hasWifiAdapter) {
          if (lines.length > 0) {
            root.wifiEnabled = false
            root.networks = []
            root.statusText = "No adapter"
          }
          root.busy = false
          return
        }
        if (root.wantWifiList && root.hasWifiAdapter)
          wifiStateProc.running = true
      }
    }
  }

  Process {
    id: wifiStateProc
    command: ["nmcli", "-t", "-f", "WIFI", "radio"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.wifiEnabled = text.trim().toLowerCase() === "enabled"
        if (!root.wifiEnabled) {
          root.networks = []
          root.statusText = "Off"
          root.rev++
          root.busy = false
          return
        }
        knownProc.running = true
      }
    }
  }

  Process {
    id: knownProc
    command: ["nmcli", "-t", "-e", "yes", "-f", "NAME,TYPE", "connection", "show"]
    stdout: StdioCollector {
      onStreamFinished: {
        const names = []
        const lines = (text || "").trim().split("\n").filter(s => s.length > 0)
        for (let i = 0; i < lines.length; i++) {
          const p = root.splitTerse(lines[i])
          if (p.length < 2)
            continue
          const type = String(p[1] || "").toLowerCase()
          if (type === "wifi" || type === "802-11-wireless")
            names.push(p[0])
        }
        root.knownSsids = names
        wifiListProc.running = true
      }
    }
  }

  Process {
    id: joinProc
    stdout: StdioCollector {
      id: joinOut
    }
    stderr: StdioCollector {
      id: joinErr
    }
    onExited: code => {
      const ssid = root.connectingSsid
      if (code === 0) {
        root.joinState = "ok"
        root.joinError = ""
        root.joinPasswordFail = false
        root.markActive(ssid)
        root.wantRescan = false
        root.wantWifiList = true
        deviceProc.running = true
      } else {
        const err = (joinErr.text || joinOut.text || "").trim()
        root.joinState = "fail"
        root.joinError = err.length ? err.split("\n")[0] : "Couldn't join"
        root.joinPasswordFail = root.joinUsedPassword || root.isPasswordFail(err)
        root.connectingSsid = ""
        root.rev++
      }
    }
  }

  Process {
    id: wifiListProc
    command: {
      const cmd = [
        "nmcli",
        "-t",
        "-e",
        "yes",
        "-f",
        "ACTIVE,SSID,SIGNAL,SECURITY",
        "device",
        "wifi",
        "list"
      ]
      if (root.wantRescan)
        cmd.push("--rescan", "yes")
      return cmd
    }
    stdout: StdioCollector {
      onStreamFinished: root.parseWifiList(text)
    }
  }

  Process {
    id: ipProc
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = (text || "").trim().split("\n")
        let addr = ""
        for (let i = 0; i < lines.length; i++) {
          const p = root.splitTerse(lines[i])
          if (p.length < 2)
            continue
          const key = String(p[0] || "")
          if (key.indexOf("IP4.ADDRESS") !== 0)
            continue
          addr = String(p[1] || "").split("/")[0]
          if (addr.length)
            break
        }
        root.ipv4 = addr
        root.rev++
      }
    }
  }

  Process {
    id: forgetProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: code => {
      const name = root.forgetSsid
      root.forgetSsid = ""
      if (code !== 0) {
        root.refreshScan()
        return
      }
      const known = []
      for (let i = 0; i < root.knownSsids.length; i++) {
        if (root.knownSsids[i] !== name)
          known.push(root.knownSsids[i])
      }
      root.knownSsids = known
      if (root.activeSsid === name) {
        root.activeSsid = ""
        root.wifiConnected = false
        root.statusText = root.wifiEnabled ? "On" : "Off"
      }
      if (root.lastWifiSsid === name)
        root.lastWifiSsid = ""
      root.ipv4 = ""
      root.rev++
      root.refreshScan()
    }
  }
}

