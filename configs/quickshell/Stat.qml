import QtQuick

Item {
  id: root
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property string icon: ""
  property color iconColor: Theme.text
  property string value: ""
  property color valueColor: Theme.text
  property int spacing: 6
  property bool scrollable: false
  property bool clickable: false
  property int scrollStep: 5

  signal scrolled(int delta)
  signal clicked

  Behavior on iconColor {
    ColorAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  Row {
    id: row
    spacing: root.spacing

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.iconColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      font.weight: Theme.barFontWeight
      font.hintingPreference: Font.PreferFullHinting
      renderType: Text.NativeRendering
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.value
      color: root.valueColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.weight: Theme.barFontWeight
      font.hintingPreference: Font.PreferFullHinting
      renderType: Text.NativeRendering
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: root.clickable ? Qt.LeftButton : Qt.NoButton
    enabled: root.scrollable || root.clickable
    cursorShape: {
      if (root.scrollable)
        return Qt.SizeVerCursor
      if (root.clickable)
        return Qt.PointingHandCursor
      return Qt.ArrowCursor
    }
    onClicked: {
      if (root.clickable)
        root.clicked()
    }
    onWheel: event => {
      if (!root.scrollable)
        return
      const delta = event.angleDelta.y > 0 ? root.scrollStep : -root.scrollStep
      root.scrolled(delta)
      event.accepted = true
    }
  }
}
