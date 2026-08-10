import QtQuick

Rectangle {
  id: root
  color: Theme.pill
  radius: height / 2
  implicitWidth: row.implicitWidth + horizontalPad * 2
  implicitHeight: Theme.barHeight - 8

  property int horizontalPad: 12
  property int spacing: 10
  default property alias data: row.data

  Row {
    id: row
    anchors.centerIn: parent
    spacing: root.spacing
  }
}
