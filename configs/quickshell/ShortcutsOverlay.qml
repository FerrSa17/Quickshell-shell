import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "KeybindsData.js" as KeybindsData

Item {
  id: root
  implicitWidth: 0
  implicitHeight: 0

  property Item externalAnchor: null
  property bool open: false
  property string lang: ShellPrefs.uiLanguage === "en" ? "en" : "ru"

  ExclusivePopup {
    popupId: "shortcuts"
    host: root
  }

  readonly property Item popupAnchor: externalAnchor
  readonly property var sections: KeybindsData.sections

  LayerPopup {
    id: popup
    visible: root.open || sheet.active
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    anchorItem: root.popupAnchor
    barWindow: root.QsWindow.window
    placement: "center"
    screenPad: 24
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
      motion: "center"

      Rectangle {
        id: panel
        focus: true
        color: Theme.windowBg
        radius: 16
        implicitWidth: 640
        implicitHeight: 560

        Keys.onEscapePressed: event => {
          root.open = false
          event.accepted = true
        }

        Text {
          id: title
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.topMargin: 16
          anchors.leftMargin: 18
          text: "Shortcuts"
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
        }

        Row {
          id: langRow
          anchors.top: parent.top
          anchors.topMargin: 12
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 6

          Repeater {
            model: ["EN", "RU"]

            Rectangle {
              id: langChip
              required property string modelData
              readonly property string code: modelData.toLowerCase()
              readonly property bool active: root.lang === code
              width: 40
              height: 28
              radius: 8
              color: langChip.active ? Theme.sapphire : Theme.well

              Text {
                anchors.centerIn: parent
                text: langChip.modelData
                color: langChip.active ? Theme.onNotifBadge : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.lang = langChip.code
              }
            }
          }
        }

        Rectangle {
          id: closeBtn
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: 12
          anchors.rightMargin: 14
          width: 28
          height: 28
          radius: 8
          color: Theme.well

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 14
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onContainsMouseChanged: {
              closeBtn.color = containsMouse ? Theme.surface : Theme.well
            }
            onClicked: root.open = false
          }
        }

        ListView {
          id: list
          anchors {
            top: title.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 16
            leftMargin: 18
            rightMargin: 10
            bottomMargin: 16
          }
          clip: true
          spacing: 14
          model: root.sections

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
          }

          delegate: Column {
            id: secCol
            required property var modelData
            width: list.width - 12
            spacing: 8

            Text {
              text: KeybindsData.sectionTitle(secCol.modelData, root.lang)
              color: Theme.sapphire
              font.family: Theme.fontFamily
              font.pixelSize: 13
              font.bold: true
            }

            Repeater {
              model: secCol.modelData.binds

              Rectangle {
                id: row
                required property var modelData
                width: parent.width
                height: 34
                radius: 8
                color: Theme.well

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: 12
                  anchors.verticalCenter: parent.verticalCenter
                  text: row.modelData.keys
                  color: Theme.text
                  font.family: Theme.fontFamily
                  font.pixelSize: 12
                  font.bold: true
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: 12
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width * 0.52
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideRight
                  text: KeybindsData.bindLabel(row.modelData, root.lang)
                  color: Theme.subtext
                  font.family: Theme.fontFamily
                  font.pixelSize: 12
                }
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
