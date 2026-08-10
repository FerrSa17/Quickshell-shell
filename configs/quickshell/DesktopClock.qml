import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Large clock + Russian date — bottom center of each screen.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      readonly property int hPad: 36
      readonly property int vPad: 20
      readonly property int bottomPad: 48
      readonly property int panelW: Math.max(timeLabel.implicitWidth, dateLabel.implicitWidth) + hPad * 2
      readonly property int panelH: col.implicitHeight + vPad * 2

      anchors {
        bottom: true
        left: true
      }

      margins {
        bottom: bottomPad
        left: Math.max(0, Math.round((modelData.width - panelW) / 2))
      }

      implicitWidth: panelW
      implicitHeight: panelH
      color: "transparent"
      aboveWindows: false
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "quickshell-desktop"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      mask: Region {
        item: panel
      }

      SystemClock {
        id: clock
        precision: SystemClock.Seconds
      }

      readonly property string timeText: Qt.formatDateTime(clock.date, "HH:mm")
      readonly property string dateText: {
        const loc = Qt.locale("ru_RU")
        const day = loc.dayName(clock.date.getDay(), Locale.LongFormat)
        const date = clock.date.toLocaleDateString(loc, "d MMMM")
        return day + ", " + date
      }

      ClippingRectangle {
        id: panel
        anchors.fill: parent
        radius: 16
        color: Theme.windowBg

        Column {
          id: col
          anchors.centerIn: parent
          spacing: 10

          Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: win.timeText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 96
            font.weight: Font.Medium
            font.letterSpacing: 2
          }

          Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: win.dateText
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.weight: Font.Medium
          }
        }
      }
    }
  }
}
