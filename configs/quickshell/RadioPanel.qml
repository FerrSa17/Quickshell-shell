import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

// Wi-Fi / Bluetooth picker — same open style as WallpaperPicker (center overlay).
Item {
  id: root
  implicitWidth: 0
  implicitHeight: 0

  // "wifi" | "bluetooth"
  property string kind: "wifi"
  property Item externalAnchor: null
  property bool open: false

  ExclusivePopup {
    popupId: root.kind
    host: root
  }

  readonly property Item popupAnchor: externalAnchor
  readonly property bool modeWifi: kind === "wifi"
  readonly property string title: modeWifi ? "Wi-Fi" : "Bluetooth"
  readonly property bool powered: modeWifi ? NetRadio.wifiEnabled : BtRadio.powered
  readonly property bool busy: modeWifi ? NetRadio.busy : BtRadio.busy
  readonly property string statusText: modeWifi ? NetRadio.statusText : BtRadio.statusText
  readonly property bool canToggle: {
    if (busy)
      return false
    if (modeWifi)
      return statusText !== "No adapter"
    return BtRadio.hasAdapter
  }
  readonly property var listModel: modeWifi ? NetRadio.networks : BtRadio.devices

  property bool promptOpen: false
  property string promptSsid: ""
  property string promptAddress: ""
  property string promptPassword: ""
  property bool showPassword: false
  property bool promptSecured: false
  property bool promptKnown: false

  property bool detailsOpen: false
  property string detailsSsid: ""
  property string detailsSecurity: ""
  property int detailsSignal: 0
  property bool forgetPending: false

  readonly property bool canJoin: {
    if (!root.modeWifi)
      return BtRadio.joinState !== "connecting"
    return root.promptPassword.length > 0
        || !root.promptSecured
        || root.promptKnown
  }
  readonly property string pairState: root.modeWifi ? NetRadio.joinState : BtRadio.joinState
  readonly property string pairError: root.modeWifi ? NetRadio.joinError : BtRadio.joinError
  readonly property bool overlayOpen: root.promptOpen || root.detailsOpen
  readonly property string detailsSecurityLabel: {
    const s = String(root.detailsSecurity || "").trim()
    if (!s || s === "--" || s.toLowerCase() === "none" || s.toLowerCase() === "open")
      return "Open"
    return s
  }

  function closePanel() {
    root.cancelPrompt()
    root.closeDetails()
    root.open = false
  }

  function showDetails(ssid, security, signal) {
    const name = String(ssid || "")
    if (!name.length)
      return
    root.cancelPrompt()
    root.detailsSsid = name
    root.detailsSecurity = String(security || "")
    root.detailsSignal = Number(signal || 0)
    root.forgetPending = false
    root.detailsOpen = true
    NetRadio.refreshDetails()
  }

  function closeDetails() {
    root.detailsOpen = false
    root.detailsSsid = ""
    root.detailsSecurity = ""
    root.detailsSignal = 0
    root.forgetPending = false
  }

  function confirmForget() {
    if (!root.detailsSsid.length)
      return
    if (!root.forgetPending) {
      root.forgetPending = true
      return
    }
    NetRadio.forget(root.detailsSsid)
    root.closeDetails()
  }

  function askJoin(ssid, security) {
    const name = String(ssid || "")
    if (!name.length)
      return
    root.closeDetails()
    root.promptSsid = name
    root.promptPassword = ""
    root.showPassword = false
    root.promptSecured = NetRadio.isSecured(security)
    root.promptKnown = NetRadio.isKnown(name)
    root.promptOpen = true
    NetRadio.joinState = ""
    NetRadio.joinError = ""
    NetRadio.joinPasswordFail = false
    Qt.callLater(() => wifiPassField.forceActiveFocus())
  }

  function askBtConnect(name, address) {
    const addr = String(address || "")
    if (!addr.length)
      return
    root.closeDetails()
    root.promptSsid = String(name || addr)
    root.promptAddress = addr
    root.promptPassword = ""
    root.showPassword = false
    root.promptSecured = true
    root.promptKnown = false
    root.promptOpen = true
    BtRadio.joinState = ""
    BtRadio.joinError = ""
    BtRadio.joinPinFail = false
    Qt.callLater(() => wifiPassField.forceActiveFocus())
  }

  function cancelPrompt() {
    if (root.modeWifi && NetRadio.joinState === "connecting") {
      root.promptOpen = false
      return
    }
    if (!root.modeWifi)
      BtRadio.cancelPair()
    root.promptOpen = false
    root.promptSsid = ""
    root.promptAddress = ""
    root.promptPassword = ""
    root.showPassword = false
    root.promptSecured = false
    root.promptKnown = false
    if (NetRadio.joinState !== "connecting") {
      NetRadio.joinState = ""
      NetRadio.joinError = ""
      NetRadio.joinPasswordFail = false
    }
  }

  function submitPassword() {
    if (root.modeWifi) {
      if (!root.promptSsid.length)
        return
      if (root.promptSecured && !root.promptPassword.length && !root.promptKnown)
        return
      if (root.promptPassword.length)
        NetRadio.connectWithPassword(root.promptSsid, root.promptPassword)
      else
        NetRadio.connect(root.promptSsid)
      return
    }
    if (!root.promptAddress.length)
      return
    BtRadio.pairConnect(root.promptAddress, root.promptPassword)
  }

  Connections {
    target: NetRadio
    function onJoinStateChanged() {
      if (!root.modeWifi || !root.promptOpen)
        return
      if (NetRadio.joinState === "ok")
        joinedClose.restart()
    }
  }

  Connections {
    target: BtRadio
    function onJoinStateChanged() {
      if (root.modeWifi || !root.promptOpen)
        return
      if (BtRadio.joinState === "ok")
        joinedClose.restart()
    }
  }

  Timer {
    id: joinedClose
    interval: 900
    repeat: false
    onTriggered: root.cancelPrompt()
  }

  onOpenChanged: {
    if (open) {
      root.cancelPrompt()
      root.closeDetails()
      if (modeWifi)
        NetRadio.refreshScan()
      else
        BtRadio.startWatch()
      Qt.callLater(() => panel.forceActiveFocus())
    } else {
      root.cancelPrompt()
      root.closeDetails()
      if (!modeWifi)
        BtRadio.stopWatch()
    }
  }

  LayerPopup {
    id: popup
    visible: root.open || sheet.active
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    anchorItem: root.popupAnchor
    barWindow: root.QsWindow.window
    placement: "center"
    screenPad: 24
    gap: 18

    Shortcut {
      sequence: "Escape"
      enabled: root.open || sheet.active
      context: Qt.WindowShortcut
      onActivated: {
        if (root.promptOpen)
          root.cancelPrompt()
        else if (root.detailsOpen)
          root.closeDetails()
        else
          root.closePanel()
      }
    }

    PopupSheet {
      id: sheet
      open: root.open
      placed: popup.placed
      motion: "center"

      Rectangle {
        id: panel
        focus: true
        color: Theme.windowBg
        radius: 16
        implicitWidth: 420
        implicitHeight: 480

        Keys.onEscapePressed: event => {
          if (root.promptOpen)
            root.cancelPrompt()
          else if (root.detailsOpen)
            root.closeDetails()
          else
            root.closePanel()
          event.accepted = true
        }

        Text {
          id: title
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.topMargin: 16
          anchors.leftMargin: 18
          text: root.title
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
        }

        Rectangle {
          id: powerRow
          anchors.top: title.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: 14
          anchors.leftMargin: 18
          anchors.rightMargin: 18
          height: 40
          radius: 8
          color: Theme.well

          Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: {
                if (root.modeWifi && NetRadio.connectingSsid.length)
                  return "Connecting to " + NetRadio.connectingSsid + "…"
                if (root.modeWifi && NetRadio.activeSsid.length)
                  return NetRadio.activeSsid
                if (!root.modeWifi && BtRadio.connectingAddress.length && BtRadio.joinState === "connecting")
                  return "Connecting…"
                return root.busy ? "Loading…" : root.statusText
              }
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: 13
              elide: Text.ElideRight
              width: parent.width - toggleBtn.width - 10
            }

            Rectangle {
              id: toggleBtn
              width: 64
              height: 26
              radius: 13
              anchors.verticalCenter: parent.verticalCenter
              color: root.powered ? Theme.sapphire : Theme.pill
              opacity: root.canToggle ? 1 : 0.5

              Text {
                anchors.centerIn: parent
                text: root.powered ? "On" : "Off"
                color: root.powered ? Theme.onNotifBadge : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 12
              }

              MouseArea {
                anchors.fill: parent
                enabled: root.canToggle
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.modeWifi)
                    NetRadio.setWifiEnabled(!root.powered)
                  else
                    BtRadio.setPowered(!root.powered)
                }
              }
            }
          }
        }

        ListView {
          id: list
          anchors.top: powerRow.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.topMargin: 12
          anchors.leftMargin: 18
          anchors.rightMargin: 18
          anchors.bottomMargin: 18
          clip: true
          spacing: 8
          visible: count > 0
          model: ScriptModel {
            objectProp: root.modeWifi ? "ssid" : "address"
            values: {
              const _ = root.modeWifi ? NetRadio.rev : BtRadio.rev
              return root.listModel
            }
          }

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
          }

          delegate: Rectangle {
            required property int index
            required property var modelData
            width: list.width
            height: 40
            radius: 8

            readonly property var net: {
              const rows = root.listModel
              if (Array.isArray(rows) && index >= 0 && index < rows.length)
                return rows[index]
              return modelData
            }
            readonly property string netSsid: String((net && net.ssid) || (net && net.name) || "")
            readonly property string netSecurity: String((net && net.security) || "")
            readonly property bool netActive: !!(net && net.active)
            readonly property int netSignal: Number((net && net.signal) || 0)
            readonly property bool isConnecting: root.modeWifi
              ? NetRadio.connectingSsid === netSsid
              : !!(net && net.address && BtRadio.connectingAddress === net.address)
            readonly property bool isActive: root.modeWifi
              ? (netActive || (NetRadio.activeSsid === netSsid && netSsid.length > 0))
              : !!(net && net.connected)
            color: isActive ? Qt.rgba(Theme.sapphire.r, Theme.sapphire.g, Theme.sapphire.b, 0.28) : Theme.well

            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 8

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: netSsid
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
                width: parent.width - meta.width - 8
              }

              Text {
                id: meta
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  if (root.modeWifi) {
                    if (isConnecting)
                      return "Connecting…"
                    if (isActive)
                      return "Connected"
                    const lock = NetRadio.isSecured(netSecurity) ? "\uf023 " : ""
                    return lock + netSignal + "%"
                  }
                  return isConnecting ? "Connecting…" : ((net && net.connected) ? "Connected" : ((net && net.paired) ? "Paired" : ""))
                }
                color: (isActive || isConnecting) ? Theme.sapphire : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 12
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.modeWifi) {
                  if (isActive)
                    root.showDetails(netSsid, netSecurity, netSignal)
                  else
                    root.askJoin(netSsid, netSecurity)
                } else {
                  const addr = String((net && net.address) || "")
                  if (!addr.length)
                    return
                  if (net && net.connected)
                    return
                  root.askBtConnect(netSsid, addr)
                }
              }
            }
          }
        }

        Rectangle {
          anchors.top: powerRow.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.topMargin: 12
          anchors.leftMargin: 18
          anchors.rightMargin: 18
          anchors.bottomMargin: 18
          radius: 8
          color: Theme.well
          visible: list.count === 0 && !root.overlayOpen

          Text {
            anchors.centerIn: parent
            text: root.busy ? "Loading…" : root.statusText
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 13
          }
        }

        Rectangle {
          anchors.fill: parent
          visible: root.promptOpen
          z: 20
          color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.82)
          radius: 16

          MouseArea {
            anchors.fill: parent
            onClicked: root.cancelPrompt()
          }

          Rectangle {
            anchors.centerIn: parent
            width: parent.width - 48
            height: promptCol.implicitHeight + 32
            radius: 16
            color: Theme.surface

            MouseArea {
              anchors.fill: parent
            }

            Column {
              id: promptCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: 18
              anchors.rightMargin: 18
              spacing: 12

              Text {
                width: parent.width
                text: {
                  if (root.pairState === "connecting")
                    return "Connecting…"
                  if (root.pairState === "ok")
                    return "Connected"
                  if (root.pairState === "fail" && !root.modeWifi)
                    return "Connect"
                  return root.modeWifi ? "Join network" : "Connect"
                }
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: 8

                Text {
                  width: parent.width - (promptFail.visible ? promptFail.implicitWidth + 8 : 0)
                  text: root.promptSsid
                  color: Theme.subtext
                  font.family: Theme.fontFamily
                  font.pixelSize: 13
                  elide: Text.ElideRight
                  wrapMode: Text.NoWrap
                }

                Text {
                  id: promptFail
                  visible: root.pairState === "fail"
                  text: {
                    if (root.modeWifi)
                      return NetRadio.joinPasswordFail ? "Passwd failed" : "Failed"
                    return BtRadio.joinPinFail ? "Passwd failed" : "Failed"
                  }
                  color: Theme.red
                  font.family: Theme.fontFamily
                  font.pixelSize: 12
                }
              }

              Rectangle {
                width: parent.width
                height: 40
                radius: 10
                color: Theme.pill
                border.width: wifiPassField.activeFocus ? 1 : 0
                border.color: Theme.sapphire
                visible: root.pairState !== "ok"

                TextInput {
                  id: wifiPassField
                  anchors.fill: parent
                  anchors.leftMargin: 12
                  anchors.rightMargin: 36
                  text: root.promptPassword
                  onTextChanged: root.promptPassword = text
                  echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                  color: Theme.text
                  font.family: Theme.fontFamily
                  font.pixelSize: 13
                  verticalAlignment: TextInput.AlignVCenter
                  clip: true
                  selectByMouse: true

                  Text {
                    anchors.fill: parent
                    text: {
                      if (root.modeWifi)
                        return root.promptSecured ? "Password" : "No password needed"
                      return "PIN"
                    }
                    color: Theme.muted
                    font: wifiPassField.font
                    verticalAlignment: Text.AlignVCenter
                    visible: !wifiPassField.text && !wifiPassField.activeFocus
                  }

                  Keys.onReturnPressed: root.submitPassword()
                  Keys.onEnterPressed: root.submitPassword()
                  Keys.onEscapePressed: event => {
                    root.cancelPrompt()
                    event.accepted = true
                  }
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: 10
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.showPassword ? "\uf070" : "\uf06e"
                  color: Theme.subtext
                  font.family: Theme.fontFamily
                  font.pixelSize: 13
                  visible: root.promptSecured

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showPassword = !root.showPassword
                  }
                }
              }

              Text {
                width: parent.width
                visible: !root.modeWifi && root.pairState !== "ok" && root.pairState !== "connecting"
                text: "Leave empty if the device has no PIN"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
              }

              Row {
                width: parent.width
                spacing: 8
                layoutDirection: Qt.RightToLeft
                visible: root.pairState !== "ok"

                Rectangle {
                  width: 88
                  height: 34
                  radius: 10
                  color: Theme.pill

                  Text {
                    anchors.centerIn: parent
                    text: root.pairState === "connecting" ? "Wait" : "Connect"
                    color: root.canJoin ? Theme.text : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }

                  MouseArea {
                    anchors.fill: parent
                    enabled: root.canJoin && root.pairState !== "connecting"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitPassword()
                  }
                }

                Rectangle {
                  width: 80
                  height: 34
                  radius: 10
                  color: Theme.pill

                  Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelPrompt()
                  }
                }
              }
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          visible: root.detailsOpen
          z: 21
          color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.82)
          radius: 16

          MouseArea {
            anchors.fill: parent
            onClicked: root.closeDetails()
          }

          Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 72, 280)
            height: detailsCol.implicitHeight + 28
            radius: 16
            color: Theme.surface

            MouseArea {
              anchors.fill: parent
            }

            Column {
              id: detailsCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              spacing: 10

              Text {
                width: parent.width
                text: root.detailsSsid
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                elide: Text.ElideRight
              }

              Column {
                width: parent.width
                spacing: 6

                Row {
                  width: parent.width
                  spacing: 8
                  Text {
                    width: 72
                    text: "Status"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                  Text {
                    text: "Connected"
                    color: Theme.sapphire
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                }

                Row {
                  width: parent.width
                  spacing: 8
                  Text {
                    width: 72
                    text: "Signal"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                  Text {
                    text: root.detailsSignal + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                }

                Row {
                  width: parent.width
                  spacing: 8
                  Text {
                    width: 72
                    text: "Security"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                  Text {
                    width: parent.width - 80
                    text: root.detailsSecurityLabel
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                  }
                }

                Row {
                  width: parent.width
                  spacing: 8
                  visible: NetRadio.ipv4.length > 0
                  Text {
                    width: 72
                    text: "IP"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                  Text {
                    text: NetRadio.ipv4
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                }
              }

              Rectangle {
                width: parent.width
                height: 34
                radius: 10
                color: root.forgetPending ? Theme.red : Theme.pill

                Text {
                  anchors.centerIn: parent
                  text: root.forgetPending ? "Confirm forget" : "Forget this network"
                  color: root.forgetPending ? Theme.onNotifBadge : Theme.red
                  font.family: Theme.fontFamily
                  font.pixelSize: 12
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.confirmForget()
                }
              }
            }
          }
        }
      }
    }
  }
}
