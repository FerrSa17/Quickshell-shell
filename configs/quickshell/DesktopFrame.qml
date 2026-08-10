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

      // Chrome pours left→right when the wallpaper theme blends (Theme.blendT).
      Item {
        anchors.fill: parent

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
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          width: Math.ceil(parent.width * Math.max(0, Math.min(1, Theme.blendT)))
          color: Theme.barBgTo
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
