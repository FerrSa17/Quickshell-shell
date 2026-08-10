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

  // "" | "screenshot"
  property string pendingAction: ""
  property real shotT: 0

  readonly property bool choosingShot: pendingAction === "screenshot"
  readonly property int sessionH: sessionCol.implicitHeight
  readonly property int shotH: shotInner.implicitHeight + 24
  // Window size snaps to the target once — animating it every frame shakes the layer.
  property int slotH: sessionH

  implicitWidth: contentWidth + 28
  implicitHeight: col.implicitHeight + 28

  onSessionHChanged: {
    if (!root.choosingShot)
      root.slotH = root.sessionH
  }

  function cancelAction() {
    pendingAction = ""
  }

  function runScreenshot(mode) {
    pendingAction = ""
    PanelBus.takeScreenshot(mode)
  }

  onChoosingShotChanged: {
    if (choosingShot) {
      shrinkDelay.stop()
      slotH = shotH
      shotT = 1
    } else {
      shotT = 0
      shrinkDelay.restart()
    }
  }

  Behavior on shotT {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  Timer {
    id: shrinkDelay
    interval: 220
    repeat: false
    onTriggered: {
      if (!root.choosingShot)
        root.slotH = root.sessionH
    }
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
    color: Theme.well

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
      cursorShape: Qt.PointingHandCursor
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

    Item {
      id: sessionSlot
      width: parent.width
      height: root.slotH
      clip: true

      Column {
        id: sessionCol
        width: parent.width
        spacing: 8
        opacity: 1 - root.shotT
        visible: opacity > 0.01
        enabled: root.pendingAction === ""
        transformOrigin: Item.Top
        scale: 1 - 0.04 * root.shotT

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
            onActivated: root.pendingAction = "screenshot"
          }

          SessionTile {
            glyph: "\uf11c"
            label: "Shortcuts"
            glyphColor: Theme.sapphire
            onActivated: PanelBus.openShortcuts()
          }
        }

        Rectangle {
          width: parent.width
          height: 44
          radius: 8
          color: Theme.well

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
          color: Theme.well

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
            // Wallpaper only when landing on a new snap (left / center / right).
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
              color: Theme.pill
            }

            // Snap markers
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

        Rectangle {
        id: shotPanel
        width: parent.width
        height: root.sessionH + Math.max(0, root.shotH - root.sessionH) * root.shotT
        anchors.top: parent.top
        radius: 8
        color: Theme.well
        opacity: root.shotT
        visible: root.shotT > 0.001
        transformOrigin: Item.Top
        scale: 0.94 + 0.06 * root.shotT
        clip: true

        Column {
          id: shotInner
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: 12
          width: parent.width - 20
          spacing: 10
          opacity: Math.max(0, (root.shotT - 0.12) / 0.88)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Screenshot"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
          }

          RowLayout {
            width: parent.width
            height: 52
            spacing: 8

            SessionTile {
              glyph: "\uf065"
              label: "Area"
              glyphColor: Theme.sapphire
              onActivated: root.runScreenshot("area")
            }

            SessionTile {
              glyph: "\uf108"
              label: "Full"
              glyphColor: Theme.sapphire
              onActivated: root.runScreenshot("full")
            }
          }

          Rectangle {
            width: parent.width
            height: 32
            radius: 8
            color: Theme.surface

            Text {
              anchors.centerIn: parent
              text: "Back"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 13
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.cancelAction()
            }
          }
        }
      }
    }
  }
}
