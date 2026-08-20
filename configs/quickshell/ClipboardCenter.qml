import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
  id: root
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property bool open: false
  property bool pendingClear: false
  readonly property int panelW: 380
  readonly property int panelH: 520

  function closeCenter() {
    root.open = false
  }

  ExclusivePopup {
    popupId: "clipboard"
    host: root
  }

  IconButton {
    id: button
    icon: "\uf0ea"
    iconColor: root.open ? Theme.sapphire : Theme.subtext
    onClicked: root.open = !root.open
  }

  onOpenChanged: {
    if (open) {
      PanelBus.closeNotificationsRequested()
      ClipboardHistory.refresh()
      root.pendingClear = false
      Qt.callLater(() => panel.forceActiveFocus())
    } else {
      root.pendingClear = false
    }
    PanelBus.clipboardReserve = open ? sheet.implicitHeight : 0
  }

  Component.onDestruction: PanelBus.clipboardReserve = 0

  Connections {
    target: PanelBus
    function onCloseClipboardRequested() {
      root.open = false
    }
  }

  LayerPopup {
    id: popup
    visible: root.open || sheet.active
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    anchorItem: button
    barWindow: root.QsWindow.window
    placement: "frameCorner"

    Shortcut {
      sequence: "Escape"
      enabled: root.open || sheet.active
      context: Qt.WindowShortcut
      onActivated: {
        if (root.pendingClear) {
          root.pendingClear = false
          return
        }
        root.closeCenter()
      }
    }

    PopupSheet {
      id: sheet
      open: root.open
      placed: popup.placed
      motion: "frameCorner"
      radius: 16
      topLeftRadius: 0
      topRightRadius: 0
      bottomLeftRadius: 16
      bottomRightRadius: 0

      Item {
        id: wrap
        readonly property int filletS: Theme.filletS
        implicitWidth: panel.implicitWidth + filletS
        implicitHeight: panel.implicitHeight + filletS

        component OuterFillet: Item {
          id: fillet
          property bool topJoin: false
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
              if (fillet.topJoin)
                ctx.arc(0, s, s, 0, Math.PI * 2)
              else
                ctx.arc(0, s, s, 0, Math.PI * 2)
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

        Item {
          id: reveal
          anchors.right: parent.right
          anchors.top: parent.top
          width: Math.max(1, Math.round(panel.implicitWidth * sheet.panelT))
          height: Math.max(1, Math.round(panel.implicitHeight * sheet.panelT))
          clip: true
          z: 1

          ClippingRectangle {
            id: panel
            anchors.right: parent.right
            anchors.top: parent.top
            focus: true
            color: Theme.barBg
            radius: 16
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 16
            bottomRightRadius: 0
            antialiasing: true
            implicitWidth: root.panelW
            implicitHeight: root.panelH

            Keys.onEscapePressed: event => {
              if (root.pendingClear) {
                root.pendingClear = false
                event.accepted = true
                return
              }
              root.closeCenter()
              event.accepted = true
            }

            ColumnLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.bottomMargin: 14
              anchors.topMargin: 0
              anchors.rightMargin: 0
              spacing: 0

              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 160
                radius: 0
                color: "transparent"

                ColumnLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 14
                  anchors.rightMargin: 14
                  anchors.topMargin: 14
                  anchors.bottomMargin: 10
                  spacing: 10

                  Text {
                    Layout.fillWidth: true
                    text: ClipboardHistory.entries.length === 0
                            ? "No clipboard history"
                            : (ClipboardHistory.entries.length + (ClipboardHistory.entries.length === 1 ? " item" : " items"))
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }

                  Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                      id: list
                      anchors.fill: parent
                      clip: true
                      spacing: 6
                      boundsBehavior: Flickable.StopAtBounds
                      ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                      }

                      model: ScriptModel {
                        objectProp: "key"
                        values: {
                          const _ = ClipboardHistory.rev
                          return ClipboardHistory.entries
                        }
                      }

                      delegate: Rectangle {
                        required property var modelData
                        width: list.width
                        height: 52
                        radius: 8
                        color: Theme.well

                        Rectangle {
                          visible: modelData.pinned
                          width: 3
                          height: parent.height - 12
                          radius: 2
                          color: Theme.sapphire
                          anchors.left: parent.left
                          anchors.leftMargin: 4
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                          anchors.fill: parent
                          anchors.leftMargin: modelData.pinned ? 14 : 10
                          anchors.rightMargin: 44
                          anchors.topMargin: 10
                          anchors.bottomMargin: 10
                          text: modelData.preview
                          color: Theme.text
                          elide: Text.ElideRight
                          wrapMode: Text.NoWrap
                          verticalAlignment: Text.AlignVCenter
                          font.family: Theme.fontFamily
                          font.pixelSize: 12
                        }

                        MouseArea {
                          anchors.fill: parent
                          anchors.rightMargin: 40
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            ClipboardHistory.copyEntry(modelData)
                            root.closeCenter()
                          }
                        }

                        MouseArea {
                          id: pinBtn
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          width: 40
                          height: parent.height
                          cursorShape: Qt.PointingHandCursor
                          hoverEnabled: true
                          onClicked: ClipboardHistory.togglePin(modelData)

                          Text {
                            anchors.centerIn: parent
                            text: "\uf08d"
                            color: modelData.pinned ? Theme.sapphire : (pinBtn.containsMouse ? Theme.text : Theme.muted)
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                          }

                          ToolTip.visible: pinBtn.containsMouse
                          ToolTip.delay: 400
                          ToolTip.text: modelData.pinned ? "Unpin" : "Pin"
                        }
                      }
                    }
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: actionsRow.implicitHeight + 20
                radius: 16
                color: Theme.barBg

                RowLayout {
                  id: actionsRow
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 10

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: root.pendingClear ? Theme.red : Theme.pill
                    opacity: ClipboardHistory.hasUnpinned ? 1 : 0.4

                    Row {
                      anchors.centerIn: parent
                      spacing: 8

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pendingClear ? "\uf00d" : "\uf1f8"
                        color: root.pendingClear ? Theme.windowBg : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pendingClear ? "Confirm" : "Clear"
                        color: root.pendingClear ? Theme.windowBg : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      enabled: ClipboardHistory.hasUnpinned
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.pendingClear) {
                          ClipboardHistory.wipe()
                          root.pendingClear = false
                        } else {
                          root.pendingClear = true
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        OuterFillet {
          topJoin: true
          anchors.right: reveal.left
          anchors.top: reveal.top
          z: 3
        }

        OuterFillet {
          topJoin: false
          anchors.right: reveal.right
          anchors.rightMargin: Theme.frameThickness
          anchors.top: reveal.bottom
          z: 3
        }
      }
    }
  }
}
