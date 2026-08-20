import QtQuick
import Quickshell
import Quickshell.Widgets

// Mic + volume bar widgets; hover opens brightness/volume/mic sliders
// from the top chrome (same motion + side flares as system monitor).
Item {
  id: root
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property bool open: false
  property bool barHovered: false
  property bool panelHovered: false

  readonly property bool wantOpen: barHovered || panelHovered

  onWantOpenChanged: {
    if (wantOpen) {
      closeDelay.stop()
      root.open = true
    } else {
      closeDelay.restart()
    }
  }

  Timer {
    id: closeDelay
    interval: 280
    repeat: false
    onTriggered: {
      if (!root.wantOpen)
        root.open = false
    }
  }

  Row {
    id: row
    spacing: 14

    Stat {
      anchors.verticalCenter: parent.verticalCenter
      icon: Audio.micMuted ? "\uf131" : "\uf130"
      iconColor: {
        if (root.open)
          return Theme.sapphire
        return Audio.micMuted ? Theme.red : Theme.subtext
      }
      value: Audio.micDisplay
      valueColor: Audio.micMuted ? Theme.muted : Theme.text
      scrollable: true
      clickable: true
      onScrolled: d => Audio.adjustMic(d)
      onClicked: Audio.toggleMicMute()
    }

    Stat {
      anchors.verticalCenter: parent.verticalCenter
      icon: Audio.muted ? "\uf026" : "\uf028"
      iconColor: {
        if (root.open)
          return Theme.sapphire
        return Audio.muted ? Theme.red : Theme.subtext
      }
      value: Audio.display
      valueColor: Audio.muted ? Theme.muted : Theme.text
      scrollable: true
      clickable: true
      onScrolled: d => Audio.adjust(d)
      onClicked: Audio.toggleMute()
    }
  }

  HoverHandler {
    id: barHover
    onHoveredChanged: root.syncBarHover()
  }

  Item {
    anchors.left: row.left
    anchors.right: row.right
    anchors.top: row.bottom
    height: 16

    HoverHandler {
      id: bridgeHover
      onHoveredChanged: root.syncBarHover()
    }
  }

  function syncBarHover() {
    root.barHovered = barHover.hovered || bridgeHover.hovered
  }

  LayerPopup {
    id: popup
    visible: root.open || sheet.active
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    anchorItem: row
    barWindow: root.QsWindow.window
    align: "center"
    placement: "frameDrop"

    Shortcut {
      sequence: "Escape"
      enabled: root.open || sheet.active
      context: Qt.WindowShortcut
      onActivated: {
        root.barHovered = false
        root.panelHovered = false
        root.open = false
      }
    }

    PopupSheet {
      id: sheet
      open: root.open
      placed: popup.placed
      motion: "frameTop"
      radius: 16
      topRadius: 0
      bottomRadius: 16

      Item {
        id: wrap
        readonly property int filletS: Theme.filletS
        implicitWidth: panel.implicitWidth + 2 * filletS
        implicitHeight: panel.implicitHeight

        component OuterFillet: Item {
          id: fillet
          property bool leftSide: true
          property int s: wrap.filletS
          width: s
          height: s
          opacity: 1
          visible: sheet.panelT > 0.001
          z: 3

          Canvas {
            id: filletCanvas
            anchors.fill: parent
            antialiasing: true
            onPaint: {
              const ctx = getContext("2d")
              ctx.reset()
              const c = Theme.barBg
              const s = fillet.s
              ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, c.a)
              ctx.fillRect(0, 0, s, s)
              ctx.globalCompositeOperation = "destination-out"
              ctx.beginPath()
              if (fillet.leftSide)
                ctx.arc(0, s, s, 0, Math.PI * 2)
              else
                ctx.arc(s, s, s, 0, Math.PI * 2)
              ctx.fill()
            }
            Component.onCompleted: requestPaint()
            Connections {
              target: Theme
              function onPaletteRevChanged() {
                filletCanvas.requestPaint()
              }
            }
            Connections {
              target: sheet
              function onPanelTChanged() {
                if (sheet.panelT > 0.001)
                  filletCanvas.requestPaint()
              }
            }
          }
        }

        OuterFillet {
          leftSide: true
          x: 0
          y: 0
        }

        OuterFillet {
          leftSide: false
          x: wrap.filletS + panel.implicitWidth
          y: 0
        }

        Item {
          id: reveal
          x: wrap.filletS
          y: 0
          width: panel.implicitWidth
          height: Math.max(1, Math.round(panel.implicitHeight * sheet.panelT))
          clip: true

          ClippingRectangle {
            id: panel
            anchors.left: parent.left
            anchors.top: parent.top
            focus: true
            color: Theme.barBg
            radius: 16
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 16
            bottomRightRadius: 16
            antialiasing: true
            implicitWidth: 340
            implicitHeight: col.implicitHeight + 28

            HoverHandler {
              onHoveredChanged: root.panelHovered = hovered
            }

            Keys.onEscapePressed: event => {
              root.barHovered = false
              root.panelHovered = false
              root.open = false
              event.accepted = true
            }

            Column {
              id: col
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.topMargin: 14
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 14

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Output"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.barFontWeight
              }

              OsdBar {
                width: parent.width
                icon: "\uf185"
                iconColor: Theme.subtext
                value: Brightness.percent / 100
                onMoved: v => Brightness.setNormalized(v)
              }

              OsdBar {
                width: parent.width
                icon: Audio.muted ? "\uf026" : "\uf028"
                iconColor: Audio.muted ? Theme.red : Theme.subtext
                value: Math.min(1, Audio.volume / 100)
                onMoved: v => {
                  if (!Audio.sink || !Audio.sink.audio)
                    return
                  Audio.sink.audio.volume = Math.min(1, v)
                  if (v > 0 && Audio.sink.audio.muted)
                    Audio.sink.audio.muted = false
                }
                onIconClicked: Audio.toggleMute()
              }

              OsdBar {
                width: parent.width
                icon: Audio.micMuted ? "\uf131" : "\uf130"
                iconColor: Audio.micMuted ? Theme.red : Theme.subtext
                value: Math.min(1, Audio.micVolume / 100)
                onMoved: v => {
                  if (!Audio.source || !Audio.source.audio)
                    return
                  Audio.source.audio.volume = Math.min(1, v)
                  if (v > 0 && Audio.source.audio.muted)
                    Audio.source.audio.muted = false
                }
                onIconClicked: Audio.toggleMicMute()
              }
            }
          }
        }
      }
    }
  }

  onOpenChanged: {
    if (open)
      Qt.callLater(() => panel.forceActiveFocus())
  }
}
