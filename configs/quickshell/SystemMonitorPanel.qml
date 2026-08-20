import QtQuick
import Quickshell.Widgets

// Performance dashboard hanging from the top chrome.
ClippingRectangle {
  id: root
  color: Theme.barBg
  radius: 16
  topLeftRadius: 0
  topRightRadius: 0
  bottomLeftRadius: 16
  bottomRightRadius: 16
  antialiasing: true
  focus: true

  // 4-based rhythm: tight stacks, generous card gaps, quieter outer pad.
  readonly property int space2: 4
  readonly property int space3: 8
  readonly property int space4: 12
  readonly property int space5: 16
  readonly property int pad: 20
  readonly property int gap: 12
  readonly property int cardPad: 16
  readonly property int cardR: 16
  readonly property int headerH: 20
  readonly property int topH: 124
  readonly property int botH: 184
  readonly property int panelW: 700
  readonly property int panelH: pad * 2 + headerH + gap + topH + gap + botH
  readonly property int innerW: panelW - pad * 2
  readonly property int topCardW: (innerW - gap) / 2
  readonly property int botCardW: (innerW - gap * 2) / 3
  readonly property int wellSize: 64
  readonly property int ringSize: 72

  implicitWidth: panelW
  implicitHeight: panelH

  HoverHandler {
    id: hover
    onHoveredChanged: root.hovered = hovered
  }
  property bool hovered: false

  component CardHead: Row {
    id: head
    spacing: 8
    property string glyph: ""
    property string label: ""
    property color glyphColor: Theme.subtext

    Text {
      text: head.glyph
      color: head.glyphColor
      font.family: Theme.fontFamily
      font.pixelSize: 14
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: head.label
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: 13
      font.weight: Font.DemiBold
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  component UsageRing: Item {
    id: ring
    property real value: 0
    property color accent: Theme.text
    property string caption: ""

    width: root.ringSize
    height: root.ringSize

    Canvas {
      id: canvas
      anchors.fill: parent
      antialiasing: true
      onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const cx = width / 2
        const cy = height / 2
        const r = Math.min(width, height) / 2 - 6
        const start = -Math.PI / 2
        const span = Math.max(0, Math.min(1, ring.value / 100)) * Math.PI * 2

        ctx.lineWidth = 7
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
      spacing: 1

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Math.round(ring.value) + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: ring.caption
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 9
      }
    }
  }

  component PercentWell: Rectangle {
    property string valueText: "—"
    width: root.wellSize
    height: root.wellSize
    radius: 16
    color: Theme.well

    Text {
      anchors.centerIn: parent
      text: parent.valueText
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: valueText === "—" ? 20 : 18
      font.weight: Font.DemiBold
    }
  }

  component UsageBar: Rectangle {
    property real fill: 0
    property color fillColor: Theme.text
    property real dim: 1
    width: parent.width
    height: 6
    radius: 3
    color: Theme.well
    opacity: dim

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * Math.max(0, Math.min(1, parent.fill))
      radius: parent.radius
      color: parent.fillColor
    }
  }

  component MetricCard: Rectangle {
    color: Theme.surface
    radius: root.cardR
    default property alias body: bodySlot.data

    Item {
      id: bodySlot
      anchors.fill: parent
      anchors.margins: root.cardPad
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: root.pad
    spacing: root.gap

    Item {
      width: parent.width
      height: root.headerH

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "Performance"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
      }
    }

    Row {
      width: parent.width
      spacing: root.gap

      MetricCard {
        width: root.topCardW
        height: root.topH

        Column {
          anchors.fill: parent
          spacing: root.space4

          Row {
            width: parent.width
            spacing: root.space4

            Column {
              width: parent.width - root.wellSize - root.space4
              spacing: root.space3
              anchors.verticalCenter: parent.verticalCenter

              CardHead {
                glyph: "\uf2db"
                label: "CPU"
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
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: Math.round(Stats.tempSmooth) + "°C"
                  color: Theme.subtext
                  font.family: Theme.fontFamily
                  font.pixelSize: 12
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            PercentWell {
              anchors.verticalCenter: parent.verticalCenter
              valueText: Math.round(Stats.cpuSmooth) + "%"
            }
          }

          UsageBar {
            fill: Stats.cpuSmooth / 100
            fillColor: Theme.maroon
          }
        }
      }

      MetricCard {
        width: root.topCardW
        height: root.topH

        Column {
          anchors.fill: parent
          spacing: root.space4

          Row {
            width: parent.width
            spacing: root.space4

            Column {
              width: parent.width - root.wellSize - root.space4
              spacing: root.space3
              anchors.verticalCenter: parent.verticalCenter

              CardHead {
                glyph: "\uf11b"
                label: "GPU"
              }

              Text {
                width: parent.width
                text: Stats.gpuName
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
              }

              Row {
                spacing: 6
                visible: Stats.gpuTempC > 0
                Text {
                  text: "\uf2c9"
                  color: Theme.peach
                  font.family: Theme.fontFamily
                  font.pixelSize: 12
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: Stats.gpuTempC + "°C"
                  color: Theme.subtext
                  font.family: Theme.fontFamily
                  font.pixelSize: 12
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            PercentWell {
              anchors.verticalCenter: parent.verticalCenter
              valueText: Stats.gpuReady ? (Math.round(Stats.gpuSmooth) + "%") : "—"
            }
          }

          UsageBar {
            fill: Stats.gpuSmooth / 100
            fillColor: Theme.green
            dim: Stats.gpuReady ? 1 : 0.4
          }
        }
      }
    }

    Row {
      width: parent.width
      spacing: root.gap

      MetricCard {
        width: root.botCardW
        height: root.botH

        Item {
          anchors.fill: parent

          CardHead {
            id: storageHead
            anchors.top: parent.top
            anchors.left: parent.left
            glyph: "\uf0a0"
            label: "Storage"
          }

          Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Math.round((storageHead.height + root.space4) / 2)
            spacing: root.space3

            UsageRing {
              anchors.horizontalCenter: parent.horizontalCenter
              value: Stats.diskPercent
              accent: Theme.sapphire
              caption: "Used"
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Stats.diskUsedGiB.toFixed(1) + " / " + Stats.diskTotalGiB.toFixed(0) + " GiB"
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: 11
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              radius: 8
              color: Theme.well
              implicitWidth: diskLab.implicitWidth + 12
              implicitHeight: 20

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

      MetricCard {
        width: root.botCardW
        height: root.botH

        Item {
          anchors.fill: parent

          CardHead {
            id: memHead
            anchors.top: parent.top
            anchors.left: parent.left
            glyph: "\uefc5"
            label: "Memory"
          }

          Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Math.round((memHead.height + root.space4) / 2)
            spacing: root.space3

            UsageRing {
              anchors.horizontalCenter: parent.horizontalCenter
              value: Stats.memPercent
              accent: Theme.peach
              caption: "Used"
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Stats.memSmooth.toFixed(1) + " / " + Stats.memTotalGiB.toFixed(0) + " GiB"
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: 11
            }
          }
        }
      }

      MetricCard {
        width: root.botCardW
        height: root.botH

        Item {
          anchors.fill: parent

          CardHead {
            id: netHead
            anchors.top: parent.top
            anchors.left: parent.left
            glyph: "\uf1eb"
            label: "Network"
          }

          Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Math.round((netHead.height + root.space4) / 2)
            spacing: root.space5

            Column {
              width: parent.width
              spacing: 2
              Text {
                text: "Download"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
              }
              Text {
                text: NetworkSpeed.downText
                color: Theme.sapphire
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.Medium
              }
            }

            Column {
              width: parent.width
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
                font.pixelSize: 16
                font.weight: Font.Medium
              }
            }
          }
        }
      }
    }
  }
}
