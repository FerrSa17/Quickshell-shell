import QtQuick

Item {
  id: root
  implicitWidth: 260
  implicitHeight: 28

  property string icon: ""
  property color iconColor: Theme.subtext
  property real value: 0.5
  property real from: 0
  property real to: 1

  signal moved(real value)

  Row {
    anchors.fill: parent
    spacing: 10

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.iconColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
    }

    Item {
      id: trackWrap
      width: root.width - 72
      height: parent.height
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 10
        radius: height / 2
        color: Theme.well

        Rectangle {
          width: Math.max(height, track.width * root.normalized)
          height: parent.height
          radius: height / 2
          color: Theme.text
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
      width: 36
      horizontalAlignment: Text.AlignRight
      text: Math.round(root.normalized * 100) + "%"
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: 12
    }
  }

  readonly property real normalized: {
    const span = root.to - root.from
    if (span <= 0)
      return 0
    return Math.max(0, Math.min(1, (root.value - root.from) / span))
  }

  function setFromX(x) {
    const t = Math.max(0, Math.min(1, x / trackWrap.width))
    const next = root.from + t * (root.to - root.from)
    root.value = next
    root.moved(next)
  }
}
