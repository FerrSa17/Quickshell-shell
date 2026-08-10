import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
  id: root

  IpcHandler {
    target: "sysmon"
    function toggle(): void {
      PanelBus.toggleSysMon()
    }
    function open(): void {
      PanelBus.openSysMon()
    }
    function close(): void {
      PanelBus.closeSysMon()
    }
  }

  Variants {
    model: Quickshell.screens

    Scope {
      id: monitorScope
      required property var modelData

      // Floating Arch circle — separate from the bar
      PanelWindow {
        id: archOrb
        screen: monitorScope.modelData

        anchors {
          top: true
          left: true
        }

        margins {
          top: Theme.barPad
          left: Theme.barPad
        }

        implicitWidth: Theme.barHeight
        implicitHeight: Theme.barHeight
        color: "transparent"
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell"

        ArchLogo {
          anchors.centerIn: parent
          width: parent.width
          height: parent.height
        }
      }

      PanelWindow {
        id: panel
        screen: monitorScope.modelData
        visible: ShellPrefs.panelTaskbar

        readonly property int archGap: 8
        readonly property int archSize: Theme.barHeight

        anchors {
          top: true
          left: true
          right: true
        }

        margins {
          top: Theme.barPad
          left: Theme.barPad + archSize + archGap
          right: Theme.barPad + 10
        }

        implicitHeight: Theme.barHeight
        color: "transparent"
        aboveWindows: true
        exclusionMode: ExclusionMode.Auto
        WlrLayershell.namespace: "quickshell"

        // Transparent — chrome comes from DesktopFrame so bar + border are one surface.
        Item {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10

          // LEFT — workspaces + active window
          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Workspaces {
              anchors.verticalCenter: parent.verticalCenter
            }

            // Cube-flip between mini player and active window (not for window title changes)
            Item {
              id: infoSlot
              anchors.verticalCenter: parent.verticalCenter
              clip: true

              readonly property bool mediaOn: nowPlaying.active
              property bool showingMedia: false
              property bool flipReady: false
              property bool flipping: false
              property bool queuedMedia: false
              property bool hasQueue: false

              readonly property real targetWidth: {
                if (mediaOn)
                  return nowPlaying.contentWidth
                if (activeWindow.hasLabel)
                  return activeWindow.contentWidth
                return 0
              }

              width: targetWidth
              height: Math.max(nowPlaying.implicitHeight, activeWindow.implicitHeight, 1)

              Behavior on width {
                enabled: infoSlot.flipReady
                NumberAnimation {
                  duration: 320
                  easing.type: Easing.OutCubic
                }
              }

              Component.onCompleted: {
                showingMedia = mediaOn
                Qt.callLater(() => {
                  infoSlot.flipReady = true
                })
              }

              onMediaOnChanged: {
                if (!flipReady) {
                  showingMedia = mediaOn
                  return
                }
                if (flipping) {
                  queuedMedia = mediaOn
                  hasQueue = true
                  return
                }
                if (mediaOn === showingMedia)
                  return
                startFlip(mediaOn)
              }

              function startFlip(toMedia) {
                flipping = true
                // To player: flip one way; back to window: the opposite way
                flipAnim.dir = toMedia ? 1 : -1
                flipAnim.toMedia = toMedia
                flipAnim.start()
              }

              SequentialAnimation {
                id: flipAnim
                property int dir: 1
                property bool toMedia: false

                NumberAnimation {
                  target: cubeRot
                  property: "angle"
                  to: flipAnim.dir * 90
                  duration: 170
                  easing.type: Easing.InCubic
                }
                ScriptAction {
                  script: {
                    infoSlot.showingMedia = flipAnim.toMedia
                    cubeRot.angle = -flipAnim.dir * 90
                  }
                }
                NumberAnimation {
                  target: cubeRot
                  property: "angle"
                  to: 0
                  duration: 210
                  easing.type: Easing.OutCubic
                }
                onStopped: {
                  infoSlot.flipping = false
                  cubeRot.angle = 0
                  if (infoSlot.hasQueue) {
                    infoSlot.hasQueue = false
                    if (infoSlot.queuedMedia !== infoSlot.showingMedia)
                      infoSlot.startFlip(infoSlot.queuedMedia)
                  }
                }
              }

              Item {
                id: face
                width: Math.max(nowPlaying.contentWidth, activeWindow.contentWidth, 1)
                height: parent.height
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                transformOrigin: Item.Center

                transform: Rotation {
                  id: cubeRot
                  origin.x: face.width / 2
                  origin.y: face.height / 2
                  axis.x: 1
                  axis.y: 0
                  axis.z: 0
                  angle: 0
                }

                NowPlaying {
                  id: nowPlaying
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  visible: infoSlot.showingMedia
                }

                ActiveWindow {
                  id: activeWindow
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  forceHidden: infoSlot.showingMedia
                  visible: !infoSlot.showingMedia && hasLabel
                }
              }
            }
          }

          // CENTER — temp / mem / cpu (click opens monitor)
          SystemMonitor {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
          }

          // RIGHT — grouped wells: machine | clock | actions | control | tray
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Pill {
              horizontalPad: 12
              spacing: 14

              Battery {}

              AudioControls {
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Text {
              id: layoutLabel
              anchors.verticalCenter: parent.verticalCenter
              text: Keyboard.layout
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              font.hintingPreference: Font.PreferFullHinting
              renderType: Text.NativeRendering

              MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Keyboard.cycle()
              }
            }

            Clock {}

            NotificationCenter {
              anchors.verticalCenter: parent.verticalCenter
            }

            SystemMenu {}

            Tray {
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }
}
