import QtQuick

Item {
  id: root
  implicitWidth: 320
  implicitHeight: 44

  property string icon: ""
  property color iconColor: Theme.subtext
  property real value: 0.5
  property real from: 0
  property real to: 1

  signal moved(real value)
  signal iconClicked

  readonly property real normalized: {
    const span = root.to - root.from
    if (span <= 0)
      return 0
    return Math.max(0, Math.min(1, (root.value - root.from) / span))
  }

  function setFromX(x) {
    const t = Math.max(0, Math.min(1, x / Math.max(1, trackWrap.width)))
    const next = root.from + t * (root.to - root.from)
    root.value = next
    root.moved(next)
  }

  Row {
    anchors.fill: parent
    spacing: 12

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: 28
      horizontalAlignment: Text.AlignHCenter
      text: root.icon
      color: root.iconColor
      font.family: Theme.fontFamily
      font.pixelSize: 22

      MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.iconClicked()
      }
    }

    Item {
      id: trackWrap
      width: root.width - 88
      height: parent.height
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 16
        radius: 8
        color: Theme.well

        Rectangle {
          width: Math.max(height, track.width * root.normalized)
          height: parent.height
          radius: height / 2
          color: Theme.sapphire
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: event => root.setFromX(event.x)
        onPositionChanged: event => {
          if (pressed)
            root.setFromX(event.x)
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: 40
      horizontalAlignment: Text.AlignRight
      text: Math.round(root.normalized * 100) + "%"
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: 13
    }
  }
}
