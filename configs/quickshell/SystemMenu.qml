import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
  id: root
  implicitWidth: frame.implicitWidth
  implicitHeight: frame.implicitHeight

  property bool open: false
  property bool returnToControl: false
  property string pendingReturn: ""

  function toggle() {
    root.open = !root.open
  }

  function closeMenu() {
    panel.pendingAction = ""
    root.open = false
  }

  function openChild(kind) {
    root.pendingReturn = kind
    root.returnToControl = true
    root.open = false
    if (kind === "wallpapers")
      wallpapers.open = true
    else if (kind === "shortcuts")
      shortcuts.open = true
  }

  function maybeReturn(kind) {
    if (root.pendingReturn !== kind)
      return
    root.pendingReturn = ""
    root.returnToControl = false
    Qt.callLater(() => {
      root.open = true
    })
  }

  Connections {
    target: PanelBus
    function onOpenSettingsRequested() {
      root.open = true
    }
    function onOpenWallpapersRequested() {
      root.openChild("wallpapers")
    }
    function onOpenShortcutsRequested() {
      root.openChild("shortcuts")
    }
    function onScreenshotRequested(mode) {
      // Close Control so the picker / grim aren't blocked by the popup.
      panel.pendingAction = ""
      root.open = false
      Qt.callLater(() => {
        if (mode === "area") {
          PanelBus.openScreenshotArea()
          return
        }
        const script = (Quickshell.env("HOME") || "/home/user")
                       + "/.config/quickshell/scripts/screenshot.sh"
        Quickshell.execDetached(["bash", script, mode])
      })
    }
  }

  Connections {
    target: wallpapers
    function onOpenChanged() {
      if (!wallpapers.open)
        root.maybeReturn("wallpapers")
    }
  }

  Connections {
    target: shortcuts
    function onOpenChanged() {
      if (!shortcuts.open)
        root.maybeReturn("shortcuts")
    }
  }

  Pill {
    id: frame
    horizontalPad: 12
    spacing: 10

    NetworkStatus {
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "\uf013"
      color: root.open ? Theme.sapphire : Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      font.weight: Theme.barFontWeight
      font.hintingPreference: Font.PreferFullHinting
      renderType: Text.NativeRendering
    }
  }

  // Click only — no hover open.
  MouseArea {
    anchors.fill: frame
    anchors.margins: -4
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle()
  }

  LayerPopup {
    id: popup
    visible: root.open || sheet.active
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    anchorItem: frame
    barWindow: root.QsWindow.window
    placement: "frameCorner"

    Shortcut {
      sequence: "Escape"
      enabled: root.open || sheet.active
      context: Qt.WindowShortcut
      onActivated: root.closeMenu()
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

      // Top-left lip + bottom-right lip (same language as Power Menu).
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
                // Peels left along the top chrome.
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

        Item {
          id: reveal
          anchors.right: parent.right
          anchors.top: parent.top
          width: Math.max(1, Math.round(panel.implicitWidth * sheet.panelT))
          height: Math.max(1, Math.round(panel.implicitHeight * sheet.panelT))
          clip: true
          z: 1

          SettingsPanel {
            id: panel
            anchors.right: parent.right
            anchors.top: parent.top
            focus: true

            Keys.onEscapePressed: event => {
              if (panel.pendingAction !== "") {
                panel.cancelAction()
                event.accepted = true
                return
              }
              root.closeMenu()
              event.accepted = true
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
          // Inset to the inner right chrome so the flare's right edge kisses the frame.
          anchors.right: reveal.right
          anchors.rightMargin: Theme.frameThickness
          anchors.top: reveal.bottom
          z: 3
        }
      }
    }
  }

  WallpaperPicker {
    id: wallpapers
    showButton: false
    externalAnchor: frame
  }

  ShortcutsOverlay {
    id: shortcuts
    externalAnchor: frame
  }

  HyprlandFocusGrab {
    active: root.open
    windows: [popup]
    onCleared: {
      if (!root.returnToControl)
        root.closeMenu()
    }
  }

  onOpenChanged: {
    if (open)
      Qt.callLater(() => panel.forceActiveFocus())
    else
      panel.pendingAction = ""
    PanelBus.controlReserve = open ? sheet.implicitHeight : 0
  }

  Connections {
    target: sheet
    function onImplicitHeightChanged() {
      if (root.open)
        PanelBus.controlReserve = sheet.implicitHeight
    }
  }

  Component.onDestruction: PanelBus.controlReserve = 0
}
