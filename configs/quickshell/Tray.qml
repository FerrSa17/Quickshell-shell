import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
  id: root
  implicitWidth: row.implicitWidth + (showBg ? horizontalPad * 2 : 0)
  implicitHeight: showBg ? Theme.barHeight - 8 : Math.max(row.implicitHeight, 18)

  readonly property int maxVisible: 4
  readonly property int trayCount: SystemTray.items.values.length
  readonly property bool hasOverflow: trayCount > maxVisible
  readonly property bool showBg: ShellPrefs.appearanceMode === "light" && trayCount > 0
  readonly property int horizontalPad: 10

  property bool open: false

  function trayClick(item, event, host) {
    if (!item)
      return
    if (event.button === Qt.LeftButton) {
      item.activate()
    } else if (event.button === Qt.MiddleButton) {
      item.secondaryActivate()
    } else if (event.button === Qt.RightButton && item.hasMenu) {
      item.display(QsWindow.window, host.width / 2, host.height)
    }
  }

  function hiddenValues() {
    const all = SystemTray.items.values
    const out = []
    for (let i = root.maxVisible; i < all.length; i++)
      out.push(all[i])
    return out
  }

  Rectangle {
    anchors.fill: parent
    visible: root.showBg
    color: Theme.pill
    radius: height / 2
  }

  Row {
    id: row
    spacing: 8
    anchors.centerIn: parent

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: trayItem
        required property var modelData
        required property int index
        visible: index < root.maxVisible
        implicitWidth: visible ? 22 : 0
        implicitHeight: 22

        IconImage {
          anchors.fill: parent
          source: modelData.icon
          asynchronous: true
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          cursorShape: Qt.PointingHandCursor
          onClicked: event => root.trayClick(modelData, event, trayItem)
        }
      }
    }

    Item {
      id: overflowBtn
      visible: root.hasOverflow
      implicitWidth: visible ? 22 : 0
      implicitHeight: 22

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.open ? Theme.notifBlue : (root.showBg ? Theme.well : Theme.pill)

        Text {
          anchors.centerIn: parent
          text: "\uf141"
          color: root.open ? Theme.white : Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: 12
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
      }
    }
  }

  LayerPopup {
    id: popup
    visible: root.open || sheet.active
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    anchorItem: overflowBtn
    barWindow: root.QsWindow.window
    align: "right"
    gap: 18

    Shortcut {
      sequence: "Escape"
      enabled: root.open || sheet.active
      context: Qt.WindowShortcut
      onActivated: root.open = false
    }

    PopupSheet {
      id: sheet
      open: root.open
      placed: popup.placed

      Rectangle {
        id: overflowPanel
        color: Theme.windowBg
        radius: 16
        implicitWidth: Math.max(120, overflowGrid.implicitWidth + 24)
        implicitHeight: overflowGrid.implicitHeight + 24

        Grid {
          id: overflowGrid
          anchors.centerIn: parent
          columns: Math.min(4, Math.max(1, root.trayCount - root.maxVisible))
          rowSpacing: 10
          columnSpacing: 10

          Repeater {
            model: ScriptModel {
              objectProp: "id"
              values: {
                const _ = root.trayCount
                return root.hiddenValues()
              }
            }

            delegate: Item {
              id: hiddenItem
              required property var modelData
              implicitWidth: 22
              implicitHeight: 22

              IconImage {
                anchors.fill: parent
                source: modelData.icon
                asynchronous: true
              }

              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: event => root.trayClick(modelData, event, hiddenItem)
              }
            }
          }
        }
      }
    }
  }

  onHasOverflowChanged: {
    if (!hasOverflow)
      open = false
  }
}
