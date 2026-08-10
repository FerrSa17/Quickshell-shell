import QtQuick
import Quickshell.Widgets

// Sheet motion: emerge from the nearest DesktopFrame chrome edge.
// Transforms live on ClippingRectangle so rounded corners stay crisp while animating.
Item {
  id: root

  width: implicitWidth
  height: implicitHeight

  property bool open: false
  property bool placed: false
  property real radius: 16
  property real topRadius: radius
  property real bottomRadius: radius
  property real topLeftRadius: topRadius
  property real topRightRadius: topRadius
  property real bottomLeftRadius: bottomRadius
  property real bottomRightRadius: bottomRadius
  // "dropdown" | "center" | "corner" | "flip" | "frameTop" | "frameCorner" | "arch"
  property string motion: "dropdown"

  property real panelT: 0
  property real contentT: 0

  readonly property bool active: panelT > 0.001
  readonly property bool expanded: open && placed
  readonly property bool fromFrame: motion === "frameTop" || motion === "frameCorner"
  // Settings / orb-born panels — grow out of the top-left Arch chrome.
  readonly property bool fromArch: motion === "arch"

  readonly property int openMs: {
    if (root.fromArch)
      return 460
    if (motion === "center")
      return 520
    if (motion === "corner")
      return 380
    if (motion === "flip")
      return 440
    if (motion === "frameTop" || motion === "frameCorner")
      return 380
    return 400
  }

  readonly property int openEase: {
    return Easing.OutCubic
  }

  readonly property int closeMs: {
    if (root.fromFrame)
      return 240
    if (root.fromArch)
      return 280
    if (root.motion === "center")
      return 200
    return 220
  }

  default property alias content: inner.data

  implicitWidth: {
    if (inner.children.length < 1)
      return 0
    return inner.children[0].implicitWidth
  }
  implicitHeight: {
    if (inner.children.length < 1)
      return 0
    return inner.children[0].implicitHeight
  }

  onExpandedChanged: {
    openAnim.stop()
    closeAnim.stop()
    if (expanded) {
      openAnim.start()
    } else if (panelT > 0.001 || contentT > 0.001) {
      closeAnim.start()
    } else {
      panelT = 0
      contentT = 0
    }
  }

  ParallelAnimation {
    id: openAnim
    NumberAnimation {
      target: root
      property: "panelT"
      to: 1
      duration: root.openMs
      easing.type: root.openEase
      easing.overshoot: 1.05
    }
    SequentialAnimation {
      PauseAnimation {
        duration: root.fromFrame ? 30 : (root.fromArch ? 50 : (root.motion === "center" ? 40 : 80))
      }
      NumberAnimation {
        target: root
        property: "contentT"
        to: 1
        duration: root.fromFrame ? 260 : (root.fromArch ? 300 : (root.motion === "corner" ? 280 : 360))
        easing.type: Easing.OutCubic
      }
    }
  }

  ParallelAnimation {
    id: closeAnim
    NumberAnimation {
      target: root
      property: "panelT"
      to: 0
      duration: root.closeMs
      easing.type: Easing.InCubic
    }
    NumberAnimation {
      target: root
      property: "contentT"
      to: 0
      duration: root.fromArch ? 160 : 140
      easing.type: Easing.InCubic
    }
  }

  ClippingRectangle {
    id: chrome
    anchors.top: parent.top
    anchors.right: root.motion === "frameCorner" ? parent.right : undefined
    // fromFrame keeps full bounds so outer flares aren't clipped mid-animation.
    width: root.implicitWidth
    height: root.implicitHeight
    // Sharp clip host for fromFrame (panels round/clip their own body).
    radius: root.fromFrame ? 0 : root.radius
    topLeftRadius: root.fromFrame ? 0 : root.topLeftRadius
    topRightRadius: root.fromFrame ? 0 : root.topRightRadius
    bottomLeftRadius: root.fromFrame ? 0 : root.bottomLeftRadius
    bottomRightRadius: root.fromFrame ? 0 : root.bottomRightRadius
    color: "transparent"
    antialiasing: true
    opacity: root.fromArch ? Math.min(1, root.panelT * 1.35) : 1
    transformOrigin: {
      if (root.fromArch)
        return Item.TopLeft
      if (root.motion === "center")
        return Item.Bottom
      if (root.motion === "corner" || root.motion === "frameCorner")
        return Item.TopRight
      return Item.Top
    }
    scale: {
      if (root.fromFrame)
        return 1
      if (root.fromArch)
        return 0.86 + 0.14 * root.panelT
      if (root.motion === "center")
        return 0.92 + 0.08 * root.panelT
      if (root.motion === "corner")
        return 0.94 + 0.06 * root.panelT
      if (root.motion === "flip")
        return 0.94 + 0.06 * root.panelT
      return 0.96 + 0.04 * root.panelT
    }
    transform: Translate {
      x: {
        if (root.fromFrame)
          return 0
        if (root.fromArch)
          // Pull out of the Arch orb / left chrome.
          return (1 - root.panelT) * -(Theme.frameThickness + Theme.barHeight + 28)
        if (root.motion === "corner")
          return (1 - root.panelT) * (Theme.frameThickness + 36)
        if (root.motion === "flip")
          return (1 - root.panelT) * 8
        return 0
      }
      y: {
        if (root.fromFrame)
          return 0
        const h = Math.max(root.implicitHeight, 48)
        const topChrome = Theme.barPad + Theme.barHeight + Theme.barPad
        if (root.fromArch)
          return (1 - root.panelT) * -(topChrome + 12)
        if (root.motion === "center")
          return (1 - root.panelT) * (Theme.frameThickness + Math.round(h * 0.4))
        if (root.motion === "corner")
          return (1 - root.panelT) * -(topChrome + 8)
        if (root.motion === "flip")
          return (1 - root.panelT) * -(topChrome + Math.round(h * 0.25))
        return (1 - root.panelT) * -(topChrome + Math.round(h * 0.15))
      }
    }

    Item {
      id: inner
      anchors.top: parent.top
      anchors.right: root.motion === "frameCorner" ? parent.right : undefined
      width: root.implicitWidth
      height: root.implicitHeight
      transformOrigin: {
        if (root.fromArch)
          return Item.TopLeft
        if (root.motion === "center")
          return Item.Bottom
        return Item.Top
      }
      scale: root.fromFrame ? 1 : (0.97 + 0.03 * root.contentT)
      opacity: root.fromFrame ? 1 : Math.max(0, Math.min(1, root.contentT * 1.25))
      // Soft settle after the chrome arrives (settings / center panels).
      y: root.fromArch ? Math.round((1 - root.contentT) * 10) : 0
    }
  }
}
