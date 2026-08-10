import QtQuick

Item {
  id: root
  implicitWidth: Theme.barHeight - 8
  implicitHeight: Theme.barHeight - 8

  property string icon: ""
  property color iconColor: Theme.text
  property int iconSize: Theme.iconSize

  signal clicked

  Text {
    anchors.centerIn: parent
    text: root.icon
    color: root.iconColor
    font.family: Theme.fontFamily
    font.pixelSize: root.iconSize
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.NativeRendering
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
