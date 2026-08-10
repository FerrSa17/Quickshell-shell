import QtQuick
import Quickshell

// Arch glyph only — chrome is DesktopFrame underneath (one surface with the bar).
Item {
  id: root
  implicitWidth: Theme.barHeight
  implicitHeight: Theme.barHeight

  Text {
    anchors.centerIn: parent
    text: "\uf303"
    color: "#1793d1"
    font.family: Theme.fontFamily
    font.pixelSize: 20
    font.weight: Font.DemiBold
  }
}
