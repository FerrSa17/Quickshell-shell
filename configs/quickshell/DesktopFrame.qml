import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Screen frame + bar share one chrome. Top strip is tall enough to hold the bar;
// the wallpaper hole starts below it so bar and border read as one piece.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      // Side/bottom chrome. Top: nest the floating bar.
      readonly property int thickness: Theme.frameThickness
      readonly property int barPad: Theme.barPad
      readonly property int topChrome: barPad + Theme.barHeight + barPad
      readonly property int rounding: 14

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      color: "transparent"
      aboveWindows: false
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "quickshell-frame"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // Chrome matches the current wallpaper pour (Theme.pourKind + Theme.blendT).
      Item {
        id: chrome
        anchors.fill: parent

        readonly property real t: Math.max(0, Math.min(1, Theme.blendT))
        readonly property real diag: Math.sqrt(width * width + height * height)
        readonly property string kind: Theme.pourKind

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
          maskSource: mask
          maskEnabled: true
          maskInverted: true
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1
        }

        Rectangle {
          anchors.fill: parent
          color: Theme.barBgFrom
        }

        Rectangle {
          anchors.fill: parent
          color: Theme.barBgTo
          opacity: chrome.kind === "fade" ? chrome.t : 0
          visible: chrome.kind === "fade"
        }

        Rectangle {
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          width: Math.ceil(parent.width * chrome.t)
          color: Theme.barBgTo
          visible: chrome.kind === "left"
        }

        Rectangle {
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          width: Math.ceil(parent.width * chrome.t)
          color: Theme.barBgTo
          visible: chrome.kind === "right"
        }

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: Math.ceil(parent.height * chrome.t)
          color: Theme.barBgTo
          visible: chrome.kind === "top"
        }

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Math.ceil(parent.height * chrome.t)
          color: Theme.barBgTo
          visible: chrome.kind === "bottom"
        }

        Rectangle {
          anchors.fill: parent
          color: Theme.barBgTo
          visible: chrome.kind === "outer"
        }

        Rectangle {
          width: chrome.diag * chrome.t
          height: width
          radius: width / 2
          anchors.centerIn: parent
          color: Theme.barBgTo
          visible: chrome.kind === "grow" || chrome.kind === "center"
        }

        Rectangle {
          width: chrome.diag * (1 - chrome.t)
          height: width
          radius: width / 2
          anchors.centerIn: parent
          color: Theme.barBgFrom
          visible: chrome.kind === "outer"
        }
      }

      Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        visible: false

        // Main wallpaper aperture
        Rectangle {
          anchors.fill: parent
          anchors.topMargin: win.topChrome
          anchors.leftMargin: win.thickness
          anchors.rightMargin: win.thickness
          anchors.bottomMargin: win.thickness
          radius: win.rounding
          color: "#ffffff"
        }

        // Circular cutout under the floating Arch orb
        Rectangle {
          x: win.barPad
          y: win.barPad
          width: Theme.barHeight
          height: Theme.barHeight
          radius: width / 2
          color: "#ffffff"
        }
      }
    }
  }
}
