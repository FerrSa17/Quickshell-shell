import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Power menu: hover the mid-right frame chrome to open (after a short pause).
// Hotkey only: Super+P (qs ipc call powermenu toggle). Arrow keys move selection.
Scope {
  id: root

  IpcHandler {
    target: "powermenu"
    function toggle(): void {
      PanelBus.togglePowerMenu()
    }
    function open(): void {
      PanelBus.openPowerMenu()
    }
    function close(): void {
      PanelBus.closePowerMenu()
    }
  }

  Variants {
    model: Quickshell.screens

    Scope {
      id: monitorScope
      required property var modelData

      property bool open: false
      property bool edgeHovered: false
      property bool panelHovered: false
      property string pendingAction: ""
      property real panelT: 0
      property real contentT: 0

      // Hotkey only (Super+P) — frame edge hover does not open.
      readonly property bool drawerActive: panelT > 0.001
      readonly property int panelW: 120
      readonly property int tileSize: 72
      readonly property int edgeHit: Theme.frameThickness
      readonly property int hitBandH: 96
      // Keyboard selection: 0 lock, 1 poweroff, 2 logout, 3 reboot
      property int selectedIndex: 0
      readonly property var actionKeys: ["lock", "poweroff", "logout", "reboot"]

      readonly property string userName: {
        const u = Quickshell.env("USER") || "user"
        return u
      }


      function closeMenu() {
        monitorScope.pendingAction = ""
        monitorScope.edgeHovered = false
        monitorScope.panelHovered = false
        monitorScope.open = false
        monitorScope.selectedIndex = 0
      }

      function moveSelection(delta) {
        const n = monitorScope.actionKeys.length
        monitorScope.selectedIndex = (monitorScope.selectedIndex + delta + n) % n
        monitorScope.pendingAction = ""
      }

      function activateSelection() {
        const action = monitorScope.actionKeys[monitorScope.selectedIndex]
        if (action === "poweroff" || action === "reboot")
          monitorScope.requestDanger(action)
        else
          monitorScope.run(action)
      }

      Connections {
        target: PanelBus
        function onTogglePowerMenuRequested() {
          if (!ShellPrefs.panelSidebar)
            return
          const screens = Quickshell.screens
          if (screens && screens.length && monitorScope.modelData !== screens[0])
            return
          if (monitorScope.open)
            monitorScope.closeMenu()
          else {
            monitorScope.selectedIndex = 0
            monitorScope.open = true
          }
        }
        function onOpenPowerMenuRequested() {
          if (!ShellPrefs.panelSidebar)
            return
          const screens = Quickshell.screens
          if (screens && screens.length && monitorScope.modelData !== screens[0])
            return
          monitorScope.selectedIndex = 0
          monitorScope.open = true
        }
        function onClosePowerMenuRequested() {
          monitorScope.closeMenu()
        }
      }

      function run(action) {
        monitorScope.closeMenu()
        if (action === "logout")
          Quickshell.execDetached(["loginctl", "terminate-user", monitorScope.userName])
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
        if (monitorScope.pendingAction === action) {
          monitorScope.run(action)
          return
        }
        monitorScope.pendingAction = action
      }

      onOpenChanged: {
        openAnim.stop()
        closeAnim.stop()
        if (open) {
          openAnim.start()
          Qt.callLater(() => panel.forceActiveFocus())
        } else {
          monitorScope.pendingAction = ""
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
          target: monitorScope
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
            target: monitorScope
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
          target: monitorScope
          property: "panelT"
          to: 0
          duration: 240
          easing.type: Easing.InCubic
        }
        NumberAnimation {
          target: monitorScope
          property: "contentT"
          to: 0
          duration: 140
          easing.type: Easing.InCubic
        }
      }

      // Invisible mid-right hit strip — disabled; open via Super+P only.
      PanelWindow {
        id: hotEdge
        screen: monitorScope.modelData
        color: "transparent"
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        visible: false
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
          top: true
          bottom: true
          right: true
        }

        margins {
          top: screen ? Math.max(0, Math.round((screen.height - monitorScope.hitBandH) / 2)) : 0
          bottom: screen ? Math.max(0, Math.round((screen.height - monitorScope.hitBandH) / 2)) : 0
          right: 0
        }

        implicitWidth: monitorScope.edgeHit

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
          onContainsMouseChanged: monitorScope.edgeHovered = containsMouse
        }
      }

      // Power strip — flush to the right chrome, grows left from that edge.
      PanelWindow {
        id: drawer
        screen: monitorScope.modelData
        visible: ShellPrefs.panelSidebar && monitorScope.drawerActive
        color: "transparent"
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.keyboardFocus: monitorScope.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors {
          top: true
          bottom: true
          right: true
        }

        margins {
          top: Theme.frameThickness
          bottom: Theme.frameThickness
          right: Theme.frameThickness
        }

        implicitWidth: monitorScope.panelW

        Shortcut {
          sequence: "Escape"
          enabled: monitorScope.open
          onActivated: monitorScope.closeMenu()
        }

        Item {
          anchors.fill: parent
          clip: false

          // Same chrome flares as the left dashboard, X-mirrored for the right edge:
          // top flare goes up, bottom flare goes down.
          component OuterFillet: Item {
            id: fillet
            property bool topSide: true
            property int s: 32
            width: s
            height: s
            // Stay solid through open/close; drop only when the panel is gone.
            opacity: 1
            visible: monitorScope.panelT > 0.001
            z: 3

            Canvas {
              id: filletCanvas
              anchors.fill: parent
              antialiasing: true
              onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const c = Theme.barBg
                const s = fillet.s
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, c.a)
                ctx.fillRect(0, 0, s, s)
                ctx.globalCompositeOperation = "destination-out"
                ctx.beginPath()
                // Left-dashboard arcs mirrored on X for a right-edge join.
                if (fillet.topSide)
                  ctx.arc(0, 0, s, 0, Math.PI * 2)
                else
                  ctx.arc(0, s, s, 0, Math.PI * 2)
                ctx.fill()
              }
              Component.onCompleted: requestPaint()
              Connections {
                target: Theme
                function onPaletteRevChanged() {
                  filletCanvas.requestPaint()
                }
              }
              Connections {
                target: monitorScope
                function onPanelTChanged() {
                  if (monitorScope.panelT > 0.001)
                    filletCanvas.requestPaint()
                }
              }
            }
          }

          OuterFillet {
            topSide: true
            anchors.right: panel.right
            anchors.bottom: panel.top
          }

          OuterFillet {
            topSide: false
            anchors.right: panel.right
            anchors.top: panel.bottom
          }

          ClippingRectangle {
            id: panel
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            // Grow width leftward from the right frame edge.
            width: Math.max(1, Math.round(monitorScope.panelW * monitorScope.panelT))
            height: col.implicitHeight + 36
            focus: true
            color: Theme.barBg
            antialiasing: true
            // Sharp right edge so the outer flares own the join; round free edge.
            radius: 0
            topLeftRadius: 16
            bottomLeftRadius: 16
            topRightRadius: 0
            bottomRightRadius: 0

            HoverHandler {
              onHoveredChanged: monitorScope.panelHovered = hovered
            }

            Keys.onEscapePressed: event => {
              if (monitorScope.pendingAction !== "") {
                monitorScope.pendingAction = ""
                event.accepted = true
                return
              }
              monitorScope.closeMenu()
              event.accepted = true
            }

            Keys.onPressed: event => {
              if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                monitorScope.moveSelection(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                monitorScope.moveSelection(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                monitorScope.activateSelection()
                event.accepted = true
              }
            }

            component PowerTile: Rectangle {
              id: tile
              property string glyph: ""
              property color glyphColor: Theme.text
              property bool confirm: false
              property bool avatar: false
              property bool selected: false
              signal activated

              width: monitorScope.tileSize
              height: monitorScope.tileSize
              radius: 20
              color: {
                if (tile.confirm)
                  return Theme.red
                if (tile.selected || hover.containsMouse)
                  return Theme.pill
                return Theme.well
              }
              border.width: tile.selected ? 2 : 0
              border.color: Theme.sapphire

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
                  text: monitorScope.userName.charAt(0).toUpperCase()
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
                onContainsMouseChanged: {
                  if (containsMouse)
                    monitorScope.selectedIndex = tileIndex
                }
              }
              // Set by each tile instance
              property int tileIndex: 0
            }

            Item {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: monitorScope.panelW
              height: col.implicitHeight

              Column {
                id: col
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                opacity: monitorScope.contentT

                PowerTile {
                  tileIndex: 0
                  selected: monitorScope.selectedIndex === 0
                  glyph: "\uf023"
                  onActivated: {
                    monitorScope.selectedIndex = 0
                    monitorScope.run("lock")
                  }
                }

                PowerTile {
                  tileIndex: 1
                  selected: monitorScope.selectedIndex === 1
                  glyph: "\u23fb"
                  glyphColor: monitorScope.pendingAction === "poweroff" ? Theme.windowBg : Theme.red
                  confirm: monitorScope.pendingAction === "poweroff"
                  onActivated: {
                    monitorScope.selectedIndex = 1
                    monitorScope.requestDanger("poweroff")
                  }
                }

                PowerTile {
                  tileIndex: 2
                  selected: monitorScope.selectedIndex === 2
                  avatar: true
                  onActivated: {
                    monitorScope.selectedIndex = 2
                    monitorScope.run("logout")
                  }
                }

                PowerTile {
                  tileIndex: 3
                  selected: monitorScope.selectedIndex === 3
                  glyph: "\uf2f9"
                  glyphColor: monitorScope.pendingAction === "reboot" ? Theme.windowBg : Theme.peach
                  confirm: monitorScope.pendingAction === "reboot"
                  onActivated: {
                    monitorScope.selectedIndex = 3
                    monitorScope.requestDanger("reboot")
                  }
                }
              }
            }
          }
        }
      }

      HyprlandFocusGrab {
        active: monitorScope.open
        windows: [drawer]
        onCleared: monitorScope.closeMenu()
      }
    }
  }
}
