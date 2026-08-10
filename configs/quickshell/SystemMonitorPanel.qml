import QtQuick
import Quickshell.Widgets

// Performance dashboard — card grid inspired by the reference layout.
ClippingRectangle {
  id: root
  // Same fill as DesktopFrame / bar — hangs as one chrome piece.
  color: Theme.barBg
  radius: 16
  topLeftRadius: 0
  topRightRadius: 0
  bottomLeftRadius: 16
  bottomRightRadius: 16
  antialiasing: true
  focus: true

  readonly property int pad: 16
  readonly property int gap: 12
  readonly property int cardR: 18
  readonly property int topH: 118
  readonly property int botH: 148
  readonly property int panelW: 720
  readonly property int panelH: pad * 2 + 36 + gap + topH + gap + botH

  implicitWidth: panelW
  implicitHeight: panelH

  HoverHandler {
    id: hover
    onHoveredChanged: root.hovered = hovered
  }
  property bool hovered: false

  // Shared ring painter
  component UsageRing: Item {
    id: ring
    property real value: 0
    property color accent: Theme.text
    property string caption: ""
    property real textOffsetY: 0

    width: 88
    height: 88

    Canvas {
      id: canvas
      anchors.fill: parent
      antialiasing: true
      onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const cx = width / 2
        const cy = height / 2
        const r = Math.min(width, height) / 2 - 7
        const start = -Math.PI / 2
        const span = Math.max(0, Math.min(1, ring.value / 100)) * Math.PI * 2

        ctx.lineWidth = 9
        ctx.lineCap = "round"

        ctx.beginPath()
        ctx.strokeStyle = Qt.rgba(Theme.well.r, Theme.well.g, Theme.well.b, 1)
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.stroke()

        ctx.beginPath()
        ctx.strokeStyle = ring.accent
        ctx.arc(cx, cy, r, start, start + span)
        ctx.stroke()
      }
    }

    onValueChanged: canvas.requestPaint()
    onAccentChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
    Connections {
      target: Theme
      function onPaletteRevChanged() {
        canvas.requestPaint()
      }
    }

    Column {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: ring.textOffsetY
      spacing: 2

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Math.round(ring.value) + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 16
        font.weight: Font.DemiBold
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: ring.caption
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
      }
    }
  }

  component MetricCard: Rectangle {
    id: card
    property string title: ""
    property string subtitle: ""
    property string glyph: ""
    color: Theme.surface
    radius: root.cardR

    default property alias body: bodySlot.data

    Item {
      id: bodySlot
      anchors.fill: parent
      anchors.margins: 14
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: root.pad
    spacing: root.gap

    // Title row (Performance)
    Item {
      width: parent.width
      height: 28

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "Performance"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
      }

      Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: 88
        height: 2
        radius: 1
        color: Theme.text
      }
    }

    // Top row — CPU / GPU
    Row {
      width: parent.width
      spacing: root.gap

      MetricCard {
        width: (parent.width - root.gap) / 2
        height: root.topH
        title: "CPU"

        Item {
          anchors.fill: parent

          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: pctBox.left
            anchors.rightMargin: 12
            spacing: 6

            Row {
              spacing: 8
              Text {
                text: "\uf2db"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 16
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CPU"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
              }
            }

            Text {
              width: parent.width
              text: Stats.cpuModel
              color: Theme.muted
              font.family: Theme.fontFamily
              font.pixelSize: 11
              elide: Text.ElideRight
            }

            Row {
              spacing: 6
              Text {
                text: "\uf2c9"
                color: Theme.sky
                font.family: Theme.fontFamily
                font.pixelSize: 12
              }
              Text {
                text: Math.round(Stats.tempSmooth) + "°C"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 12
              }
            }

            Rectangle {
              width: parent.width
              height: 8
              radius: 4
              color: Theme.well

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, Stats.cpuSmooth / 100))
                radius: parent.radius
                color: Theme.maroon
              }
            }
          }

          Rectangle {
            id: pctBox
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            height: 72
            radius: 22
            color: Theme.well

            Text {
              anchors.centerIn: parent
              text: Math.round(Stats.cpuSmooth) + "%"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 20
              font.weight: Font.DemiBold
            }
          }
        }
      }

      MetricCard {
        width: (parent.width - root.gap) / 2
        height: root.topH

        Item {
          anchors.fill: parent

          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: gpuPct.left
            anchors.rightMargin: 12
            spacing: 6

            Row {
              spacing: 8
              Text {
                text: "\uf11b"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 16
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "GPU"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
              }
            }

            Text {
              width: parent.width
              text: Stats.gpuName
              color: Theme.muted
              font.family: Theme.fontFamily
              font.pixelSize: 11
              elide: Text.ElideRight
              maximumLineCount: 2
              wrapMode: Text.Wrap
            }

            Row {
              spacing: 6
              visible: Stats.gpuTempC > 0
              Text {
                text: "\uf2c9"
                color: Theme.peach
                font.family: Theme.fontFamily
                font.pixelSize: 12
              }
              Text {
                text: Stats.gpuTempC + "°C"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 12
              }
            }

            Rectangle {
              width: parent.width
              height: 8
              radius: 4
              color: Theme.well
              opacity: Stats.gpuReady ? 1 : 0.45

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, Stats.gpuSmooth / 100))
                radius: parent.radius
                color: Theme.green
              }
            }
          }

          Rectangle {
            id: gpuPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            height: 72
            radius: 22
            color: Theme.well

            Text {
              anchors.centerIn: parent
              text: Stats.gpuReady ? (Math.round(Stats.gpuSmooth) + "%") : "—"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Stats.gpuReady ? 20 : 22
              font.weight: Font.DemiBold
            }
          }
        }
      }
    }

    // Bottom row — Storage / Network / Memory
    Row {
      width: parent.width
      spacing: root.gap

      MetricCard {
        width: 200
        height: root.botH

        Column {
          anchors.fill: parent
          spacing: 10

          Row {
            spacing: 8
            Text {
              text: "\uf0a0"
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: 14
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Storage"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 13
              font.weight: Font.DemiBold
            }
          }

          Row {
            spacing: 12
            anchors.horizontalCenter: parent.horizontalCenter

            UsageRing {
              value: Stats.diskPercent
              accent: Theme.sapphire
              caption: "Used"
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 4

              Text {
                text: Stats.diskUsedGiB.toFixed(1) + " / " + Stats.diskTotalGiB.toFixed(0) + " GiB"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 11
              }

              Rectangle {
                radius: 10
                color: Theme.well
                implicitWidth: diskLab.implicitWidth + 16
                implicitHeight: 22

                Text {
                  id: diskLab
                  anchors.centerIn: parent
                  text: Stats.diskDevice
                  color: Theme.muted
                  font.family: Theme.fontFamily
                  font.pixelSize: 10
                }
              }
            }
          }
        }
      }

      MetricCard {
        width: parent.width - 200 - 160 - root.gap * 2
        height: root.botH

        Column {
          anchors.fill: parent
          spacing: 12

          Row {
            spacing: 8
            Text {
              text: "\uf1eb"
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: 14
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Network"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 13
              font.weight: Font.DemiBold
            }
          }

          Grid {
            columns: 2
            columnSpacing: 24
            rowSpacing: 10
            width: parent.width

            Column {
              spacing: 2
              Text {
                text: "Download"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
              }
              Text {
                text: NetworkSpeed.downText
                color: Theme.green
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
              }
            }

            Column {
              spacing: 2
              Text {
                text: "Upload"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
              }
              Text {
                text: NetworkSpeed.upText
                color: Theme.peach
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
              }
            }
          }

          Text {
            text: "Live interface totals"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
            opacity: 0.8
          }
        }
      }

      MetricCard {
        width: 160
        height: root.botH

        Column {
          anchors.fill: parent
          spacing: 8

          Row {
            spacing: 8
            Text {
              text: "\uefc5"
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: 14
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Memory"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 13
              font.weight: Font.DemiBold
            }
          }

          UsageRing {
            anchors.horizontalCenter: parent.horizontalCenter
            value: Stats.memPercent
            accent: Theme.peach
            caption: "Used"
            textOffsetY: -4
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Stats.memSmooth.toFixed(1) + " / " + Stats.memTotalGiB.toFixed(0) + " GiB"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 11
            transform: Translate {
              y: -6
            }
          }
        }
      }
    }
  }
}
