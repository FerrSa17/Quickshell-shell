import QtQuick
import Quickshell
import Quickshell.Widgets

// Power / session strip for surfaces that aren't a layer-shell PanelWindow
// (e.g. the lock screen). Hover the mid-right edge to open — same language
// as the normal-mode PowerMenu.
Item {
  id: root
  anchors.fill: parent

  property bool edgeHovered: false
  property bool panelHovered: false
  property bool open: false
  property string pendingAction: ""
  property real panelT: 0
  property real contentT: 0

  readonly property bool wantOpen: edgeHovered || panelHovered
  readonly property bool drawerActive: panelT > 0.001
  readonly property int panelW: 120
  readonly property int tileSize: 80
  readonly property int edgeHit: Theme.frameThickness + 10
  readonly property int hitBandH: 320

  readonly property string userName: {
    const u = Quickshell.env("USER") || "user"
    return u
  }

  onWantOpenChanged: {
    if (wantOpen) {
      closeDelay.stop()
      root.open = true
    } else {
      closeDelay.restart()
    }
  }

  Timer {
    id: closeDelay
    interval: 280
    repeat: false
    onTriggered: {
      if (!root.wantOpen) {
        root.pendingAction = ""
        root.open = false
      }
    }
  }

  function closeMenu() {
    root.pendingAction = ""
    root.edgeHovered = false
    root.panelHovered = false
    root.open = false
  }

  function run(action) {
    root.closeMenu()
    if (action === "logout")
      Quickshell.execDetached(["loginctl", "terminate-user", root.userName])
    else if (action === "poweroff")
      Quickshell.execDetached(["systemctl", "poweroff"])
    else if (action === "suspend")
      Quickshell.execDetached(["systemctl", "suspend"])
    else if (action === "reboot")
      Quickshell.execDetached(["systemctl", "reboot"])
    else if (action === "lock")
      PanelBus.lock()
  }

  function requestDanger(action) {
    if (root.pendingAction === action) {
      root.run(action)
      return
    }
    root.pendingAction = action
  }

  onOpenChanged: {
    openAnim.stop()
    closeAnim.stop()
    if (open) {
      openAnim.start()
      Qt.callLater(() => panel.forceActiveFocus())
    } else {
      root.pendingAction = ""
      if (panelT > 0.001 || contentT > 0.001)
        closeAnim.start()
      else {
        panelT = 0
        contentT = 0
      }
    }
  }

  ParallelAnimation {
    id: openAnim
    NumberAnimation {
      target: root
      property: "panelT"
      to: 1
      duration: 380
      easing.type: Easing.OutCubic
    }
    SequentialAnimation {
      PauseAnimation {
        duration: 30
      }
      NumberAnimation {
        target: root
        property: "contentT"
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
      }
    }
  }

  ParallelAnimation {
    id: closeAnim
    NumberAnimation {
      target: root
      property: "panelT"
      to: 0
      duration: 240
      easing.type: Easing.InCubic
    }
    NumberAnimation {
      target: root
      property: "contentT"
      to: 0
      duration: 140
      easing.type: Easing.InCubic
    }
  }

  // Invisible mid-right hit strip.
  MouseArea {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: root.edgeHit
    height: root.hitBandH
    z: 20
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onContainsMouseChanged: root.edgeHovered = containsMouse
  }

  // Drawer — rounded floating card on the lock surface (no frame-chrome flares).
  Item {
    anchors.fill: parent
    anchors.margins: Theme.frameThickness
    visible: root.drawerActive
    z: 21
    clip: false

    ClippingRectangle {
      id: panel
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: parent.right
      width: Math.max(1, Math.round(root.panelW * root.panelT))
      height: col.implicitHeight + 36
      focus: true
      color: Theme.barBg
      antialiasing: true
      radius: 16
      topLeftRadius: 16
      bottomLeftRadius: 16
      topRightRadius: 16
      bottomRightRadius: 16

      HoverHandler {
        onHoveredChanged: root.panelHovered = hovered
      }

      Keys.onEscapePressed: event => {
        if (root.pendingAction !== "") {
          root.pendingAction = ""
          event.accepted = true
          return
        }
        root.closeMenu()
        event.accepted = true
      }

      component PowerTile: Rectangle {
        id: tile
        property string glyph: ""
        property color glyphColor: Theme.text
        property bool confirm: false
        property bool avatar: false
        signal activated

        width: root.tileSize
        height: root.tileSize
        radius: 20
        color: {
          if (tile.confirm)
            return Theme.red
          if (hover.containsMouse)
            return Theme.pill
          return Theme.well
        }

        Behavior on color {
          ColorAnimation {
            duration: 120
          }
        }

        Text {
          visible: !tile.avatar
          anchors.centerIn: parent
          text: tile.glyph
          color: tile.confirm ? Theme.windowBg : tile.glyphColor
          font.family: Theme.fontFamily
          font.pixelSize: 28
        }

        Rectangle {
          visible: tile.avatar
          anchors.centerIn: parent
          width: 52
          height: 52
          radius: 26
          color: Theme.sapphire

          Text {
            anchors.centerIn: parent
            text: root.userName.charAt(0).toUpperCase()
            color: Theme.windowBg
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.bold: true
          }
        }

        MouseArea {
          id: hover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: tile.activated()
        }
      }

      Item {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.panelW
        height: col.implicitHeight

        Column {
          id: col
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: 14
          opacity: root.contentT

          PowerTile {
            glyph: "\uf023"
            onActivated: root.run("lock")
          }

          PowerTile {
            glyph: "\u23fb"
            glyphColor: root.pendingAction === "poweroff" ? Theme.windowBg : Theme.red
            confirm: root.pendingAction === "poweroff"
            onActivated: root.requestDanger("poweroff")
          }

          PowerTile {
            glyph: "\uf2f9"
            glyphColor: root.pendingAction === "reboot" ? Theme.windowBg : Theme.peach
            confirm: root.pendingAction === "reboot"
            onActivated: root.requestDanger("reboot")
          }
        }
      }
    }
  }
}
