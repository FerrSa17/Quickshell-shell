import QtQuick

// Toast card — merges with DesktopFrame chrome (flat on top/right when docked).
Rectangle {
  id: root
  width: parent ? parent.width : 360
  height: Notifications.toastH
  color: Theme.barBg
  // Corner radii are driven by NotificationToasts (chrome join vs rounded).
  topLeftRadius: 16
  topRightRadius: 16
  bottomLeftRadius: 16
  bottomRightRadius: 16
  clip: true

  property string toastKey: ""
  property string summary: ""
  property string body: ""
  property string appName: ""
  property var at: 0
  property int durationMs: 5000
  property bool stackTop: true
  property bool stackBottom: true

  signal dismissRequested

  readonly property string timeLabel: {
    const t = Number(root.at) || 0
    if (t <= 0)
      return "now"
    const sec = Math.max(0, Math.floor((Date.now() - t) / 1000))
    if (sec < 45)
      return "now"
    if (sec < 3600)
      return Math.floor(sec / 60) + "m"
    if (sec < 86400)
      return Math.floor(sec / 3600) + "h"
    return Math.floor(sec / 86400) + "d"
  }

  readonly property string titleLine: {
    const s = root.summary && root.summary.length ? root.summary : "Notification"
    return s
  }

  readonly property string glyph: {
    const name = (root.appName || root.summary || "?").trim()
    return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
  }

  function closeToast() {
    root.dismissRequested()
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    anchors.topMargin: 12
    anchors.bottomMargin: 12
    spacing: 12

    // App mark — wallpaper primary disc
    Item {
      width: 40
      height: 40
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.centerIn: parent
        width: 40
        height: 40
        radius: 20
        color: Theme.notifBlueDim
      }

      Rectangle {
        anchors.centerIn: parent
        width: 32
        height: 32
        radius: 16
        color: Theme.notifBlue

        Text {
          anchors.centerIn: parent
          text: root.glyph
          color: Theme.onNotifBadge
          font.family: Theme.fontFamily
          font.pixelSize: 14
          font.bold: true
        }
      }
    }

    Column {
      width: parent.width - 40 - 12 - dismissBtn.implicitWidth - 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3

      Row {
        spacing: 8
        width: parent.width

        Text {
          width: Math.min(implicitWidth, parent.width - timeText.implicitWidth - 8)
          text: root.titleLine
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: 13
          font.bold: true
          elide: Text.ElideRight
          wrapMode: Text.NoWrap
          maximumLineCount: 1
        }

        Text {
          id: timeText
          text: root.timeLabel
          color: Theme.muted
          font.family: Theme.fontFamily
          font.pixelSize: 11
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Text {
        width: parent.width
        visible: root.body.length > 0
        text: root.body
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        maximumLineCount: 1
      }
    }

    Text {
      id: dismissBtn
      anchors.verticalCenter: parent.verticalCenter
      text: "\uf00d"
      color: Theme.muted
      font.family: Theme.fontFamily
      font.pixelSize: 12
      opacity: 0.7

      MouseArea {
        anchors.fill: parent
        anchors.margins: -10
        cursorShape: Qt.PointingHandCursor
        onClicked: root.closeToast()
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    z: -1
    cursorShape: Qt.PointingHandCursor
    onClicked: root.closeToast()
  }

  Timer {
    id: lifeTimer
    interval: root.durationMs
    running: true
    repeat: false
    onTriggered: root.closeToast()
  }

  Component.onCompleted: lifeTimer.start()
}
