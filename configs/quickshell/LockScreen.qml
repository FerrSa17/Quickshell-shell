import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Item {
  id: root

  property bool lockOnStartup: false
  property bool startupDone: false
  property string password: ""
  property string statusMessage: ""
  property real shakeX: 0

  readonly property string userName: {
    const u = Quickshell.env("USER") || "user"
    return u
  }

  function requestLock() {
    PanelBus.closeAllPopups()
    root.password = ""
    root.statusMessage = ""
    root.shakeX = 0
    LockSession.lock()
  }

  function tryUnlock() {
    root.statusMessage = ""
    if (pam.active) {
      if (pam.responseRequired)
        pam.respond(root.password)
      return
    }
    if (!pam.start()) {
      root.statusMessage = "failed to start login"
      return
    }
    if (pam.responseRequired)
      pam.respond(root.password)
  }

  function authFailed() {
    root.statusMessage = "wrong password"
    root.password = ""
    shakePass.restart()
  }

  Connections {
    target: PanelBus
    function onLockRequested() {
      root.requestLock()
    }
  }

  Timer {
    // Disabled: locking on every qs start/reload kills the session lock
    // client mid-flight and can crash Hyprland. Login lock stays in
    // hyprland autostart via `qs ipc call lock lock`.
    interval: 700
    running: false
    repeat: false
    onTriggered: {
      if (root.startupDone)
        return
      root.startupDone = true
      root.requestLock()
    }
  }

  IpcHandler {
    target: "lock"
    function lock(): void {
      root.requestLock()
    }
    function unlock(): void {
      root.password = ""
      root.statusMessage = ""
      LockSession.unlock()
    }
  }

  PamContext {
    id: pam
    config: "login"
    user: root.userName

    onResponseRequiredChanged: {
      if (responseRequired)
        respond(root.password)
    }

    onCompleted: result => {
      if (result === PamResult.Success) {
        root.statusMessage = ""
        root.password = ""
        LockSession.unlock()
      } else {
        root.authFailed()
      }
    }

    onError: _ => {
      root.statusMessage = "login error"
      root.password = ""
    }
  }

  SequentialAnimation {
    id: shakePass
    NumberAnimation {
      target: root
      property: "shakeX"
      to: 12
      duration: 45
    }
    NumberAnimation {
      target: root
      property: "shakeX"
      to: -12
      duration: 90
    }
    NumberAnimation {
      target: root
      property: "shakeX"
      to: 8
      duration: 60
    }
    NumberAnimation {
      target: root
      property: "shakeX"
      to: 0
      duration: 45
    }
  }

  WlSessionLock {
    id: sessionLock
    locked: LockSession.locked

    WlSessionLockSurface {
      id: lockSurface
      color: "transparent"

      Rectangle {
        anchors.fill: parent
        color: Theme.bg

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop {
              position: 0.0
              color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.28)
            }
            GradientStop {
              position: 0.24
              color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.18)
            }
            GradientStop {
              position: 0.50
              color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.10)
            }
            GradientStop {
              position: 0.76
              color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.24)
            }
            GradientStop {
              position: 1.0
              color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.42)
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.20)
        }

        Item {
          anchors.right: parent.right
          anchors.rightMargin: Math.max(Theme.frameThickness + 8, Math.round(parent.width * 0.02))
          anchors.verticalCenter: parent.verticalCenter
          width: 220
          height: 120
          opacity: 0.9
          z: 40

          Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\u2192"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 40
            }

            Text {
              width: 190
              horizontalAlignment: Text.AlignHCenter
              text: "Hover here for power menu"
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: 13
              wrapMode: Text.WordWrap
            }
          }
        }

        SystemClock {
          id: clock
          precision: SystemClock.Minutes
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 48
          spacing: 0

          Column {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(lockSurface.height * 0.08)
            spacing: 10

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Qt.formatDateTime(clock.date, "HH:mm")
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 96
              font.weight: Font.Light
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: {
                const d = clock.date
                const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                const months = ["January", "February", "March", "April", "May", "June",
                                "July", "August", "September", "October", "November", "December"]
                return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
              }
              color: Theme.muted
              font.family: Theme.fontFamily
              font.pixelSize: 16
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
              anchors.centerIn: parent
              width: Math.min(560, parent.width * 0.72)
              spacing: 14

              Text {
                width: parent.width
                text: LockSession.quoteText.length ? ("«" + LockSession.quoteText + "»") : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.italic: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.92
              }

              Text {
                width: parent.width
                visible: LockSession.quoteAuthor.length > 0
                text: "— " + LockSession.quoteAuthor
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }

          Column {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Math.round(lockSurface.height * 0.08)
            spacing: 16

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.userName
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 18
              font.bold: true
            }

            Rectangle {
              id: passPill
              anchors.horizontalCenter: parent.horizontalCenter
              width: 320
              height: 48
              radius: height / 2
              color: Theme.well
              border.width: passwordField.activeFocus ? 1 : 0
              border.color: Theme.sapphire
              transform: Translate {
                x: root.shakeX
              }

              TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                text: root.password
                onTextChanged: root.password = text
                echoMode: TextInput.Password
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                focus: LockSession.locked
                enabled: !pam.active || pam.responseRequired

                Text {
                  anchors.fill: parent
                  text: "password"
                  color: Theme.muted
                  font: parent.font
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  visible: !passwordField.text && !passwordField.activeFocus
                }

                Keys.onReturnPressed: root.tryUnlock()
                Keys.onEnterPressed: root.tryUnlock()
                Keys.onEscapePressed: {
                  root.password = ""
                  passwordField.text = ""
                }
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.statusMessage
              color: Theme.red
              font.family: Theme.fontFamily
              font.pixelSize: 12
              opacity: root.statusMessage.length ? 1 : 0
            }
          }
        }

        Connections {
          target: LockSession
          function onLockedChanged() {
            if (LockSession.locked) {
              root.password = ""
              root.statusMessage = ""
              Qt.callLater(() => passwordField.forceActiveFocus())
            } else {
              powerMenu.closeMenu()
              if (pam.active)
                pam.abort()
            }
          }
        }

        // Mid-right edge → same power/session menu as the unlocked shell.
        PowerMenuSession {
          id: powerMenu
          anchors.fill: parent
          z: 50

          onOpenChanged: {
            if (!open && LockSession.locked)
              Qt.callLater(() => passwordField.forceActiveFocus())
          }
        }
      }
    }
  }
}
