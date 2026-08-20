import QtQuick
import Quickshell

// Temp / mem / CPU bar widgets. Dashboard opens only via hotkey (Super+Shift+A).
Item {
  id: root
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property bool open: false

  ExclusivePopup {
    popupId: "sysmon"
    host: root
  }

  function toggle() {
    root.open = !root.open
  }

  function closeDash() {
    root.open = false
  }

  Connections {
    target: PanelBus
    function onToggleSysMonRequested() {
      root.toggle()
    }
    function onOpenSysMonRequested() {
      root.open = true
    }
    function onCloseSysMonRequested() {
      root.closeDash()
    }
  }

  Row {
    id: row
    spacing: 18

    Stat {
      icon: "\uf2dc"
      iconColor: root.open ? Theme.sky : Theme.text
      value: Math.round(Stats.tempSmooth) + "°C"
      valueColor: Theme.text
    }

    Stat {
      icon: "\uefc5"
      iconColor: root.open ? Theme.peach : Theme.text
      value: Stats.memSmooth.toFixed(2) + " GiB"
      valueColor: Theme.text
    }

    Stat {
      icon: String.fromCodePoint(0xf035b)
      iconColor: root.open ? Theme.maroon : Theme.text
      value: Math.round(Stats.cpuSmooth) + "%"
      valueColor: Theme.text
    }
  }

  LayerPopup {
    id: popup
    visible: root.open || sheet.active
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    anchorItem: root
    barWindow: root.QsWindow.window
    align: "center"
    placement: "frameDrop"

    Shortcut {
      sequence: "Escape"
      enabled: root.open || sheet.active
      context: Qt.WindowShortcut
      onActivated: root.closeDash()
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

          SystemMonitorPanel {
            id: panel
            anchors.left: parent.left
            anchors.top: parent.top
            focus: true

            Keys.onEscapePressed: event => {
              root.closeDash()
              event.accepted = true
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
