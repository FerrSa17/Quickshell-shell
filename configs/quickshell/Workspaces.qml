import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspace pills — instant focus switch (no slide / scale animation).
Item {
  id: root
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  readonly property int focusedWs: Hyprland.focusedWorkspace?.id ?? 1
  readonly property int pillH: Theme.barHeight - 8

  Row {
    id: row
    spacing: 8

    Repeater {
      model: 5

      delegate: Rectangle {
        id: wsPill
        required property int index
        readonly property int wsId: index + 1

        readonly property bool focused: root.focusedWs === wsId
        readonly property var windows: ActiveApp.clientsOn(wsId)
        readonly property bool occupied: windows.length > 0
        readonly property color accent: Theme.workspaceColors[index]

        height: root.pillH
        radius: height / 2
        color: accent
        opacity: focused ? 1 : (occupied ? 0.85 : 0.45)
        implicitWidth: Math.max(height, contentRow.implicitWidth + 16)

        Row {
          id: contentRow
          anchors.centerIn: parent
          spacing: 6

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xf0baf)
            color: Theme.bg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            font.weight: Theme.barFontWeight
            visible: wsPill.focused
          }

          Repeater {
            model: wsPill.windows

            Text {
              required property var modelData
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.icon
              color: Theme.bg
              font.family: Theme.fontFamily
              font.pixelSize: Theme.iconSize
              font.weight: Theme.barFontWeight
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "" + wsPill.wsId
            color: Theme.bg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Theme.barFontWeight
            visible: !wsPill.focused && !wsPill.occupied
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsPill.wsId + " })")
        }
      }
    }
  }
}
