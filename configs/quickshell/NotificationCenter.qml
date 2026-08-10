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

  function relativeTime(at) {
    const t = Number(at) || 0
    if (t <= 0)
      return ""
    const sec = Math.max(0, Math.floor((Date.now() - t) / 1000))
    if (sec < 45)
      return "now"
    if (sec < 3600)
      return Math.floor(sec / 60) + "m"
    if (sec < 86400)
      return Math.floor(sec / 3600) + "h"
    return Math.floor(sec / 86400) + "d"
  }

  function closeCenter() {
    root.open = false
  }

  IconButton {
    id: button
    icon: "\uf0f3"
    iconColor: Notifications.dnd
                 ? Theme.muted
                 : (Notifications.count > 0 ? Theme.sapphire : Theme.subtext)
    onClicked: root.open = !root.open
  }

  Rectangle {
    visible: Notifications.count > 0
    anchors.right: button.right
    anchors.top: button.top
    anchors.rightMargin: -2
    anchors.topMargin: -2
    width: Math.max(14, badgeText.implicitWidth + 6)
    height: 14
    radius: 7
    color: Theme.notifBlue

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: Notifications.count > 99 ? "99+" : "" + Notifications.count
      color: Theme.onNotifBadge
      font.family: Theme.fontFamily
      font.pixelSize: 9
      font.bold: true
    }
  }

  onOpenChanged: {
    if (open) {
      Notifications.retainCenter()
      root.pendingClear = false
      Qt.callLater(() => panel.forceActiveFocus())
    } else {
      Notifications.releaseCenter()
      root.pendingClear = false
    }
    PanelBus.notifReserve = open ? sheet.implicitHeight : 0
  }

  Component.onDestruction: {
    if (root.open)
      Notifications.releaseCenter()
    PanelBus.notifReserve = 0
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
      onActivated: root.closeCenter()
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

      // Same concave chrome lips as Control (top-left + bottom-right / power menu).
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
          // Stay solid through open/close; drop only when the panel is gone.
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
                // Power-menu bottom flare: peels down along the right chrome.
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

        // Reveal grows from the top-right; flares ride the reveal edges
        // so corners are visible through the whole animation.
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

          // —— Messages ——
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 160
            radius: 0
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 0
            bottomRightRadius: 0
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
                text: Notifications.count === 0
                        ? "No notifications"
                        : (Notifications.count + (Notifications.count === 1 ? " notification" : " notifications"))
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
                  spacing: 0
                  model: Notifications.history
                  boundsBehavior: Flickable.StopAtBounds
                  ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                  }

                  add: Transition {
                    ParallelAnimation {
                      NumberAnimation {
                        property: "scale"
                        from: 0.94
                        to: 1
                        duration: 400
                        easing.type: Easing.OutCubic
                      }
                      NumberAnimation {
                        property: "y"
                        from: ViewTransition.destination.y - Math.round(64 * 0.35)
                        to: ViewTransition.destination.y
                        duration: 400
                        easing.type: Easing.OutCubic
                      }
                    }
                  }

                  populate: Transition {
                    SequentialAnimation {
                      PauseAnimation {
                        duration: Math.min(ViewTransition.index * 45, 360)
                      }
                      ParallelAnimation {
                        NumberAnimation {
                          property: "scale"
                          from: 0.94
                          to: 1
                          duration: 400
                          easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                          property: "y"
                          from: ViewTransition.destination.y - Math.round(64 * 0.35)
                          to: ViewTransition.destination.y
                          duration: 400
                          easing.type: Easing.OutCubic
                        }
                      }
                    }
                  }

                  addDisplaced: Transition {
                    NumberAnimation {
                      properties: "y"
                      duration: 320
                      easing.type: Easing.OutCubic
                    }
                  }

                  remove: Transition {
                    ParallelAnimation {
                      NumberAnimation {
                        property: "scale"
                        to: 0.94
                        duration: 220
                        easing.type: Easing.InCubic
                      }
                      NumberAnimation {
                        property: "y"
                        to: ViewTransition.item.y - Math.round(64 * 0.35)
                        duration: 220
                        easing.type: Easing.InCubic
                      }
                    }
                  }

                  removeDisplaced: Transition {
                    NumberAnimation {
                      properties: "y"
                      duration: 280
                      easing.type: Easing.OutCubic
                    }
                  }

                  displaced: Transition {
                    NumberAnimation {
                      properties: "y"
                      duration: 280
                      easing.type: Easing.OutCubic
                    }
                  }

                  delegate: Item {
                    id: nrow
                    required property string key
                    required property string summary
                    required property string body
                    required property string appName
                    required property var at

                    width: list.width
                    height: 64
                    scale: 1
                    transformOrigin: Item.Top

                    Rectangle {
                      anchors.fill: parent
                      radius: 18
                      color: Theme.pill

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 12

                        Rectangle {
                          width: 36
                          height: 36
                          radius: 18
                          color: Theme.notifBlue
                          anchors.verticalCenter: parent.verticalCenter

                          Text {
                            anchors.centerIn: parent
                            text: {
                              const name = (nrow.appName || nrow.summary || "?").trim()
                              return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
                            }
                            color: Theme.onNotifBadge
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                          }
                        }

                        Column {
                          width: parent.width - 36 - 12 - chevronBtn.implicitWidth - 8
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: 2

                          Text {
                            width: parent.width
                            text: {
                              const s = nrow.summary && nrow.summary.length ? nrow.summary : "Notification"
                              const t = root.relativeTime(nrow.at)
                              return s + " • " + (t.length ? t : "now")
                            }
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            maximumLineCount: 1
                          }

                          Text {
                            width: parent.width
                            visible: nrow.body && nrow.body.length > 0
                            text: nrow.body
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            maximumLineCount: 1
                          }
                        }

                        Text {
                          id: chevronBtn
                          anchors.verticalCenter: parent.verticalCenter
                          text: "\uf078"
                          color: Theme.muted
                          font.family: Theme.fontFamily
                          font.pixelSize: 12

                          MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onContainsMouseChanged: chevronBtn.color = containsMouse ? Theme.red : Theme.muted
                            onClicked: Notifications.remove(nrow.key)
                          }
                        }
                      }
                    }
                  }
                }

                Text {
                  anchors.centerIn: parent
                  visible: Notifications.count === 0
                  text: "You're all caught up"
                  color: Theme.muted
                  font.family: Theme.fontFamily
                  font.pixelSize: 12
                }
              }
            }
          }

          // —— Actions ——
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: actionsRow.implicitHeight + 20
            radius: 16
            color: Theme.well

            RowLayout {
              id: actionsRow
              anchors.fill: parent
              anchors.margins: 10
              spacing: 10

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 12
                color: Notifications.dnd ? Theme.sapphire : Theme.pill

                Row {
                  anchors.centerIn: parent
                  spacing: 8

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifications.dnd ? "\uf1f6" : "\uf0f3"
                    color: Notifications.dnd ? Theme.windowBg : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Do Not Disturb"
                    color: Notifications.dnd ? Theme.windowBg : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Notifications.dnd = !Notifications.dnd
                }
              }

              Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: root.pendingClear ? Theme.red : Theme.pill
                opacity: Notifications.count > 0 ? 1 : 0.4

                Text {
                  anchors.centerIn: parent
                  text: root.pendingClear ? "\uf00d" : "\uf0c9"
                  color: root.pendingClear ? Theme.windowBg : Theme.subtext
                  font.family: Theme.fontFamily
                  font.pixelSize: 14
                }

                MouseArea {
                  anchors.fill: parent
                  enabled: Notifications.count > 0
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.pendingClear) {
                      Notifications.clearAll()
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

        // Top chrome lip + bottom-right power-menu lip.
        OuterFillet {
          topJoin: true
          anchors.right: reveal.left
          anchors.top: reveal.top
          z: 3
        }

        OuterFillet {
          topJoin: false
          // Inset to the inner right chrome so the flare's right edge kisses the frame.
          anchors.right: reveal.right
          anchors.rightMargin: Theme.frameThickness
          anchors.top: reveal.bottom
          z: 3
        }
      }
    }
  }
}
