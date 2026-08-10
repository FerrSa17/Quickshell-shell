import QtQuick
import Quickshell
import Quickshell.Hyprland

// Short active-window app name, shown right of workspaces.
Item {
  id: root

  // When mini player is active, fade out (parent also crossfades)
  property bool forceHidden: false

  readonly property string labelText: ActiveApp.label
  readonly property string appIcon: ActiveApp.icon
  readonly property bool hasLabel: true
  readonly property bool shown: !forceHidden
  readonly property bool isDesktop: ActiveApp.isDesktop

  // Displayed values (crossfade on change)
  property string shownLabel: ""
  property string shownIcon: ""

  readonly property real contentWidth: row.implicitWidth > 0 ? Math.min(220, row.implicitWidth) : 0

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  implicitWidth: contentWidth
  implicitHeight: label.implicitHeight
  clip: true

  function syncLabel(immediate) {
    if (immediate || shownLabel.length === 0 || (labelText === shownLabel && appIcon === shownIcon)) {
      shownLabel = labelText
      shownIcon = appIcon
      row.opacity = 1
      return
    }
    if (forceHidden) {
      shownLabel = labelText
      shownIcon = appIcon
      return
    }
    labelSwap.restart()
  }

  onLabelTextChanged: syncLabel(false)
  onAppIconChanged: {
    if (shownIcon !== appIcon)
      syncLabel(false)
  }

  Component.onCompleted: {
    shownLabel = labelText
    shownIcon = appIcon
  }

  SequentialAnimation {
    id: labelSwap
    NumberAnimation {
      target: row
      property: "opacity"
      to: 0
      duration: 120
      easing.type: Easing.OutCubic
    }
    ScriptAction {
      script: {
        root.shownLabel = root.labelText
        root.shownIcon = root.appIcon
      }
    }
    NumberAnimation {
      target: row
      property: "opacity"
      to: 1
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  Row {
    id: row
    spacing: 8
    anchors.verticalCenter: parent.verticalCenter
    opacity: 1

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.shownIcon
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      font.weight: Theme.barFontWeight
      font.hintingPreference: Font.PreferFullHinting
      renderType: Text.NativeRendering
    }

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, 200)
      text: root.shownLabel
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.weight: Theme.barFontWeight
      font.hintingPreference: Font.PreferFullHinting
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }
}
