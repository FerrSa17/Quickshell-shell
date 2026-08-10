import QtQuick
import Quickshell

// Bar clock — time only. Calendar lives on the left-frame dashboard.
Item {
  id: root
  implicitWidth: frame.implicitWidth
  implicitHeight: frame.implicitHeight

  readonly property string timeText: Qt.formatDateTime(clock.date, "HH:mm")

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Pill {
    id: frame
    horizontalPad: 14
    spacing: 8

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "\uf017"
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      font.weight: Theme.barFontWeight
      font.hintingPreference: Font.PreferFullHinting
      renderType: Text.NativeRendering
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.timeText
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.weight: Theme.barFontWeight
      font.hintingPreference: Font.PreferFullHinting
      renderType: Text.NativeRendering
    }
  }
}
