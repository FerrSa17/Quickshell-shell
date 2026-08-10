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
      root.statusMessage = "не удалось начать вход"
      return
    }
    if (pam.responseRequired)
      pam.respond(root.password)
  }

  function authFailed() {
    root.statusMessage = "неверный пароль"
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
      root.statusMessage = "ошибка входа"
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
              color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.35)
            }
            GradientStop {
              position: 0.45
              color: "transparent"
            }
            GradientStop {
              position: 1.0
              color: Qt.rgba(Theme.windowBg.r, Theme.windowBg.g, Theme.windowBg.b, 0.55)
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
                const days = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
                const months = ["января", "февраля", "марта", "апреля", "мая", "июня",
                                "июля", "августа", "сентября", "октября", "ноября", "декабря"]
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
                  text: "пароль"
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
          showLockTile: true
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
