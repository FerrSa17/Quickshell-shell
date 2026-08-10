import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Mini player: spinning disc + track progress + title. Shown only while media plays.
Item {
  id: root

  property var player: null

  readonly property bool active: player !== null && player.isPlaying
  readonly property string trackName: {
    if (!player)
      return ""
    const t = (player.trackTitle || "").trim()
    if (t.length > 0)
      return t
    return player.identity || "Playing"
  }
  readonly property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

  // Quickshell exposes seconds. Guard against rare raw microsecond leaks.
  function toSeconds(v) {
    const n = Number(v)
    if (!isFinite(n) || n < 0)
      return 0
    if (n > 86400)
      return n / 1000000
    return n
  }

  // When lengthSupported is false, Quickshell mirrors length ← position,
  // which makes progress always look finished. Treat that as unknown.
  function resolvedLengthSec(pos) {
    if (!player)
      return 0
    if (player.lengthSupported === false)
      return 0
    const len = toSeconds(player.length)
    if (!(len > 0))
      return 0
    return len
  }

  property real lengthSec: 0
  property real positionSec: 0
  property real progressSmooth: 0

  readonly property real progress: lengthSec > 0
    ? Math.max(0, Math.min(1, positionSec / lengthSec))
    : 0

  Behavior on progressSmooth {
    NumberAnimation {
      duration: 180
      easing.type: Easing.Linear
    }
  }

  function refreshPlayer() {
    const list = Mpris.players.values
    for (let i = 0; i < list.length; i++) {
      const p = list[i]
      if (p && p.isPlaying) {
        if (player !== p)
          player = p
        return
      }
    }
    player = null
    lengthSec = 0
    positionSec = 0
    progressSmooth = 0
  }

  // Read position/length into our own props. Do NOT call positionChanged() —
  // emitting it from a poll loop can recurse until the stack blows and the
  // bar freezes at the minimum mark.
  function pollPosition() {
    if (!player)
      return

    const pos = toSeconds(player.position)
    const len = resolvedLengthSec(pos)

    lengthSec = len
    positionSec = pos
    progressSmooth = lengthSec > 0 ? Math.max(0, Math.min(1, pos / lengthSec)) : 0
  }

  property string shownTrack: ""
  property real contentWidth: layout.implicitWidth > 0 ? Math.min(260, layout.implicitWidth) : 0

  function syncTrack(immediate) {
    if (immediate || shownTrack.length === 0 || trackName === shownTrack) {
      shownTrack = trackName
      titleFade.opacity = 1
      return
    }
    trackSwap.restart()
  }

  Component.onCompleted: {
    refreshPlayer()
    shownTrack = trackName
    pollPosition()
  }

  onTrackNameChanged: syncTrack(false)
  onActiveChanged: {
    if (active)
      pollPosition()
    else
      progressSmooth = 0
  }

  Connections {
    target: Mpris.players
    function onValuesChanged() {
      root.refreshPlayer()
    }
  }

  Connections {
    target: root.player
    function onIsPlayingChanged() {
      root.refreshPlayer()
      root.pollPosition()
    }
    function onPlaybackStateChanged() {
      root.refreshPlayer()
      root.pollPosition()
    }
    function onTrackTitleChanged() {
      root.syncTrack(false)
      root.pollPosition()
    }
    function onLengthChanged() {
      root.pollPosition()
    }
    function onLengthSupportedChanged() {
      root.pollPosition()
    }
    function onUniqueIdChanged() {
      root.pollPosition()
    }
  }

  Timer {
    interval: 800
    running: true
    repeat: true
    onTriggered: root.refreshPlayer()
  }

  // Polling reads always return the live D-Bus position.
  Timer {
    interval: 250
    running: root.active && root.player
    repeat: true
    triggeredOnStart: true
    onTriggered: root.pollPosition()
  }

  opacity: 1
  implicitWidth: contentWidth
  implicitHeight: layout.implicitHeight
  clip: true

  SequentialAnimation {
    id: trackSwap
    NumberAnimation {
      target: titleFade
      property: "opacity"
      to: 0
      duration: 120
      easing.type: Easing.OutCubic
    }
    ScriptAction {
      script: root.shownTrack = root.trackName
    }
    NumberAnimation {
      target: titleFade
      property: "opacity"
      to: 1
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  Row {
    id: layout
    spacing: 8
    anchors.verticalCenter: parent.verticalCenter

    ClippingRectangle {
      width: 22
      height: 22
      radius: 11
      color: "#1e1e2e"
      border.width: 0
      border.color: "transparent"
      antialiasing: true
      anchors.verticalCenter: parent.verticalCenter

      Item {
        anchors.fill: parent
        transformOrigin: Item.Center

        RotationAnimation on rotation {
          from: 0
          to: 360
          duration: 3500
          loops: Animation.Infinite
          running: root.active
        }

        Image {
          id: art
          anchors.fill: parent
          source: root.artUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          visible: status === Image.Ready
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.width * 0.72
          height: width
          radius: width / 2
          color: "transparent"
          border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.5)
          border.width: 1
          visible: art.status !== Image.Ready
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.width * 0.42
          height: width
          radius: width / 2
          color: "transparent"
          border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.35)
          border.width: 1
          visible: art.status !== Image.Ready
        }

        Rectangle {
          anchors.centerIn: parent
          width: 6
          height: 6
          radius: 3
          color: Theme.notifBlue
        }
      }
    }

    Column {
      spacing: 3
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        id: progressTrack
        width: Math.max(48, titleText.width * 0.85)
        height: 4
        radius: 2
        color: Theme.well
        clip: true
        opacity: root.lengthSec > 0 ? 1 : 0.35

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          // Avoid forcing a "minimum thumb" that looks stuck at the start.
          width: parent.width * root.progressSmooth
          radius: parent.radius
          color: Theme.notifBlue
        }
      }

      Item {
        id: titleFade
        width: titleText.width
        height: titleText.height
        opacity: 1

        Text {
          id: titleText
          text: root.shownTrack
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: 11
          elide: Text.ElideRight
          maximumLineCount: 1
          width: Math.min(200, Math.max(72, implicitWidth))
        }
      }
    }
  }
}
