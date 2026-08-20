import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

ClippingRectangle {
  id: root
  // Same fill as DesktopFrame — flush to top + right chrome as one piece.
  color: Theme.barBg
  border.width: 0
  radius: 16
  topLeftRadius: 0
  topRightRadius: 0
  bottomLeftRadius: 16
  bottomRightRadius: 0
  antialiasing: true

  readonly property int contentWidth: 280

  implicitWidth: contentWidth + 28
  implicitHeight: col.implicitHeight + 28

  function runScreenshot(mode) {
    PanelBus.takeScreenshot(mode)
  }

  component SessionTile: Rectangle {
    id: tile
    property string glyph: ""
    property string label: ""
    property color glyphColor: Theme.text
    property int glyphSize: Theme.iconSize
    signal activated

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.fillHeight: true
    radius: 8
    color: Theme.pill

    Column {
      anchors.centerIn: parent
      spacing: 4

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: tile.glyph
        color: tile.glyphColor
        font.family: Theme.fontFamily
        font.pixelSize: tile.glyphSize
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: tile.label
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: 10
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: tile.enabled
      cursorShape: tile.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: tile.activated()
    }
  }

  Column {
    id: col
    anchors.centerIn: parent
    width: root.contentWidth
    spacing: 14

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Control"
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
    }

    Column {
      width: parent.width
      spacing: 8

      RowLayout {
        width: parent.width
        height: 56
        spacing: 10

        SessionTile {
          glyph: "\uf03e"
          label: "Wall"
          glyphColor: Theme.sapphire
          onActivated: PanelBus.openWallpapers()
        }

        SessionTile {
          glyph: String.fromCodePoint(0xf18f4)
          label: "Shot"
          glyphColor: Theme.sapphire
          onActivated: root.runScreenshot("area")
        }

        SessionTile {
          glyph: "\uf11c"
          label: "Shortcuts"
          glyphColor: Theme.sapphire
          onActivated: PanelBus.openShortcuts()
        }
      }

      RowLayout {
        width: parent.width
        height: 56
        spacing: 14

        SessionTile {
          glyph: "\uf1eb"
          label: "Wi-Fi"
          glyphColor: NetRadio.linkMode === "wired" ? Theme.muted : Theme.sapphire
          opacity: NetRadio.linkMode === "wired" ? 0.55 : 1
          enabled: NetRadio.linkMode !== "wired"
          onActivated: PanelBus.openWifi()
        }

        Item {
          id: linkSlot
          property real switchAnim: NetRadio.canSwitch ? 1 : 0

          Behavior on switchAnim {
            NumberAnimation {
              duration: 240
              easing.type: Easing.OutCubic
            }
          }

          visible: switchAnim > 0.001
          opacity: switchAnim
          clip: true
          Layout.preferredWidth: 112 * switchAnim
          Layout.minimumWidth: 0
          Layout.maximumWidth: 112
          Layout.fillWidth: false
          Layout.fillHeight: true

          Rectangle {
            id: linkSwitch
            width: 112
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 8
            color: Theme.pill
            enabled: NetRadio.canSwitch

          readonly property real modePos: NetRadio.linkMode === "wired" ? 1 : 0
          property real dragPos: 0
          property real shownPos: modePos
          property bool dragging: false

          onModePosChanged: {
            if (!dragging)
              shownPos = modePos
          }

          function setMode(mode) {
            if (mode !== "wired" && mode !== "wifi")
              return
            shownPos = mode === "wired" ? 1 : 0
            if (NetRadio.linkMode !== mode)
              NetRadio.setLinkMode(mode)
          }

          function toggleMode() {
            setMode(NetRadio.linkMode === "wired" ? "wifi" : "wired")
          }

          function commitFromPos(p) {
            setMode(p < 0.5 ? "wifi" : "wired")
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf1eb"
            color: NetRadio.linkMode === "wifi" ? Theme.sapphire : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            z: 2

            MouseArea {
              anchors.fill: parent
              anchors.margins: -10
              cursorShape: Qt.PointingHandCursor
              onClicked: linkSwitch.setMode("wifi")
            }
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf0e8"
            color: NetRadio.linkMode === "wired" ? Theme.sapphire : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            z: 2

            MouseArea {
              anchors.fill: parent
              anchors.margins: -10
              cursorShape: Qt.PointingHandCursor
              onClicked: linkSwitch.setMode("wired")
            }
          }

          Item {
            id: linkTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 34
            anchors.rightMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            height: 22

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              height: 4
              radius: 2
              color: Theme.barBg
            }

            Rectangle {
              id: linkThumb
              readonly property real travel: Math.max(0, linkTrack.width - width)
              width: 16
              height: 16
              radius: 8
              color: Theme.sapphire
              anchors.verticalCenter: parent.verticalCenter
              x: {
                const p = linkSwitch.dragging ? linkSwitch.dragPos : linkSwitch.shownPos
                return p * travel
              }

              Behavior on x {
                enabled: !linkSwitch.dragging
                NumberAnimation {
                  duration: 160
                  easing.type: Easing.OutCubic
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              anchors.topMargin: -18
              anchors.bottomMargin: -18
              cursorShape: Qt.PointingHandCursor
              preventStealing: true
              property real pressX: 0
              property bool moved: false

              function posAt(mx) {
                const w = Math.max(1, linkTrack.width - linkThumb.width)
                return Math.max(0, Math.min(1, (mx - linkThumb.width / 2) / w))
              }

              onPressed: event => {
                pressX = event.x
                moved = false
              }
              onPositionChanged: event => {
                if (Math.abs(event.x - pressX) < 6)
                  return
                moved = true
                linkSwitch.dragging = true
                linkSwitch.dragPos = posAt(event.x)
              }
              onReleased: {
                if (!moved)
                  linkSwitch.toggleMode()
                else
                  linkSwitch.commitFromPos(linkSwitch.dragPos)
                linkSwitch.dragging = false
                moved = false
              }
              onCanceled: {
                linkSwitch.dragging = false
                moved = false
              }
            }
          }
          }
        }

        SessionTile {
          glyph: "\uf294"
          label: "BT"
          glyphColor: Theme.sapphire
          onActivated: PanelBus.openBluetooth()
        }
      }

      Rectangle {
        width: parent.width
        height: 44
        radius: 8
        color: Theme.pill

        Row {
          anchors.centerIn: parent
          spacing: 18

          Text {
            text: "\uf063 " + NetworkSpeed.downText
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 12
          }

          Text {
            text: "\uf062 " + NetworkSpeed.upText
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 12
          }
        }
      }

      Rectangle {
        id: appearanceRow
        width: parent.width
        height: 44
        radius: 8
        color: Theme.pill

        readonly property real modePos: {
          const m = ShellPrefs.appearanceMode
          if (m === "light")
            return 0
          if (m === "dark")
            return 1
          return 0.5
        }
        property real dragPos: modePos
        property bool dragging: false

        function posFromMode(mode) {
          if (mode === "light")
            return 0
          if (mode === "dark")
            return 1
          return 0.5
        }

        function snapMode(p) {
          if (p < 0.33)
            return "light"
          if (p > 0.67)
            return "dark"
          return "calm"
        }

        function commitFromPos(p) {
          const mode = appearanceRow.snapMode(p)
          appearanceRow.dragPos = appearanceRow.posFromMode(mode)
          if (ShellPrefs.appearanceMode !== mode)
            PanelBus.setAppearanceMode(mode)
        }

        Text {
          id: lightLabel
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: "Light"
          color: ShellPrefs.appearanceMode === "light" ? Theme.text : Theme.muted
          font.family: Theme.fontFamily
          font.pixelSize: 12
        }

        Text {
          id: darkLabel
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: "Dark"
          color: ShellPrefs.appearanceMode === "dark" ? Theme.text : Theme.muted
          font.family: Theme.fontFamily
          font.pixelSize: 12
        }

        Item {
          id: track
          anchors.left: lightLabel.right
          anchors.right: darkLabel.left
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          height: 22

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            radius: 2
            color: Theme.barBg
          }

          Repeater {
            model: 3
            Rectangle {
              required property int index
              width: 4
              height: 4
              radius: 2
              color: Theme.muted
              anchors.verticalCenter: track.verticalCenter
              x: index * (track.width - 4) / 2
            }
          }

          Rectangle {
            id: thumb
            readonly property real travel: Math.max(0, track.width - width)
            width: 18
            height: 18
            radius: 9
            color: Theme.sapphire
            anchors.verticalCenter: parent.verticalCenter
            x: {
              const p = appearanceRow.dragging
                         ? appearanceRow.dragPos
                         : appearanceRow.modePos
              return p * travel
            }

            Behavior on x {
              enabled: !appearanceRow.dragging
              NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            anchors.topMargin: -8
            anchors.bottomMargin: -8
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function posAt(mx) {
              const w = Math.max(1, track.width - thumb.width)
              return Math.max(0, Math.min(1, (mx - thumb.width / 2) / w))
            }

            onPressed: event => {
              appearanceRow.dragging = true
              appearanceRow.dragPos = posAt(event.x)
            }
            onPositionChanged: event => {
              if (!appearanceRow.dragging)
                return
              appearanceRow.dragPos = posAt(event.x)
            }
            onReleased: {
              if (!appearanceRow.dragging)
                return
              appearanceRow.dragging = false
              appearanceRow.commitFromPos(appearanceRow.dragPos)
            }
          }
        }
      }
    }
  }
}
