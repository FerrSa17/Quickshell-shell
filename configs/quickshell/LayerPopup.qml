import QtQuick
import Quickshell
import Quickshell.Wayland

// Same layer namespace as the bar.
PanelWindow {
  id: root

  property Item anchorItem
  // Must be the *bar* PanelWindow (not this popup). Prefer parent.QsWindow —
  // bare QsWindow.window here would resolve to the popup itself.
  property var barWindow: null
  property real gap: 18
  // "right" | "center" | "left" — used when placement is "anchor"
  property string align: "right"
  // "anchor" | "center" | "topRight" | "frameDrop" | "frameCorner"
  property string placement: "anchor"
  property int screenPad: Theme.frameThickness + 4
  // Hide until the first successful place — avoids a flash/slide from (0,0).
  property bool placed: false

  color: "transparent"
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  focusable: true
  WlrLayershell.namespace: "quickshell"
  // OnDemand: other apps stay usable; Escape still works while the popup is focused.
  WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  anchors {
    top: true
    // frameCorner pins to the right chrome; everything else uses left.
    left: root.placement !== "frameCorner"
    right: root.placement === "frameCorner"
  }

  // PanelWindow has no opacity — hide children until anchored.
  Binding {
    target: root.contentItem
    property: "opacity"
    value: root.visible && root.placed ? 1 : 0
    when: root.contentItem !== null
  }

  function resolveScreen() {
    if (barWindow && barWindow.screen)
      screen = barWindow.screen
    return root.screen
  }

  function placeCenter() {
    if (!resolveScreen())
      return false
    if (root.implicitWidth < 8 || root.implicitHeight < 8)
      return false

    const left = Math.max(root.screenPad, Math.round((root.screen.width - root.implicitWidth) / 2))
    const top = Math.max(root.screenPad, Math.round((root.screen.height - root.implicitHeight) / 2))
    root.margins.top = top
    root.margins.left = left
    root.placed = true
    return true
  }

  function placeTopRight() {
    if (!resolveScreen())
      return false
    if (root.implicitWidth < 8)
      return false

    // Sit below the floating bar chrome.
    const top = Math.max(root.screenPad, Theme.barPad + Theme.barHeight + root.gap)
    const left = Math.max(root.screenPad, Math.round(root.screen.width - root.implicitWidth - root.screenPad))
    root.margins.top = top
    root.margins.left = left
    root.placed = true
    return true
  }

  // Attach to the inner top edge of DesktopFrame (bottom of the top chrome strip).
  // Open/close height reveal starts and ends on that edge.
  function placeFrameDrop() {
    if (!root.anchorItem)
      return false
    if (!resolveScreen())
      return false
    if (root.implicitWidth < 8)
      return false

    const g = root.anchorItem.mapToGlobal(0, 0)
    const relX = g.x - root.screen.x
    const relY = g.y - root.screen.y

    if (relX < -32 || relY < -32 || relX > root.screen.width + 32 || relY > root.screen.height + 32)
      return false

    const barPad = Theme.barPad
    const topChrome = barPad + Theme.barHeight + barPad
    let left = relX + root.anchorItem.width / 2 - root.implicitWidth / 2
    left = Math.max(Theme.frameThickness, Math.min(left, root.screen.width - root.implicitWidth - Theme.frameThickness))

    root.margins.top = topChrome
    root.margins.left = Math.round(left)
    root.placed = true
    return true
  }

  // Attach to the top-right corner of the DesktopFrame.
  // Overlap the right chrome (margin 0) and sit on the top chrome edge so
  // barBg panel + frame read as one continuous surface.
  function placeFrameCorner() {
    if (!resolveScreen())
      return false
    if (root.implicitWidth < 8)
      return false

    const barPad = Theme.barPad
    const topChrome = barPad + Theme.barHeight + barPad

    // Only write margins when they change — repeated assigns jitter the layer.
    if (root.margins.top !== topChrome)
      root.margins.top = topChrome
    if (root.margins.right !== 0)
      root.margins.right = 0
    if (root.margins.left !== 0)
      root.margins.left = 0
    root.placed = true
    return true
  }

  function placeAnchor() {
    if (!root.anchorItem)
      return false

    if (!resolveScreen())
      return false

    // Wait for popup size — right/center align is wrong while width is 0.
    if (root.implicitWidth < 8)
      return false

    // PanelWindow has no x/y — use global coords of the anchor in the bar.
    const g = root.anchorItem.mapToGlobal(0, 0)
    const relX = g.x - root.screen.x
    const relY = g.y - root.screen.y

    // Not mapped yet (common on the first visible frame).
    if (relX < -32 || relY < -32 || relX > root.screen.width + 32 || relY > root.screen.height + 32)
      return false

    const top = relY + root.anchorItem.height + root.gap
    let left = relX

    if (root.align === "right")
      left = left + root.anchorItem.width - root.implicitWidth
    else if (root.align === "center")
      left = left + root.anchorItem.width / 2 - root.implicitWidth / 2

    left = Math.max(0, Math.round(left))
    const topM = Math.max(0, Math.round(top))

    // Keep unplaced if right-aligned chrome would still sit on the far left —
    // that almost always means the anchor mapping was not ready yet.
    if (root.align === "right" && left < 24 && relX > root.screen.width * 0.35)
      return false

    root.margins.top = topM
    root.margins.left = left
    root.placed = true
    return true
  }

  function reposition() {
    if (root.placement === "center")
      return placeCenter()
    if (root.placement === "topRight")
      return placeTopRight()
    if (root.placement === "frameDrop")
      return placeFrameDrop()
    if (root.placement === "frameCorner")
      return placeFrameCorner()
    return placeAnchor()
  }

  onVisibleChanged: {
    if (visible) {
      placed = false
      if (!reposition())
        Qt.callLater(retryPlace)
    } else {
      placed = false
    }
  }

  function retryPlace() {
    if (!root.visible || root.placed)
      return
    if (!reposition())
      Qt.callLater(retryPlace)
  }

  onImplicitWidthChanged: {
    // frameCorner is pinned to the right chrome — width changes don't move it.
    if (visible && placement !== "frameCorner")
      reposition()
  }

  onImplicitHeightChanged: {
    // frameCorner / frameDrop sit on the top chrome; height growth must not
    // reconfigure the layer every frame (Shot submenu used to shake Control).
    if (visible && (placement === "center" || placement === "topRight"))
      reposition()
  }

  // Don't reposition on height changes for anchored popups — growing confirm panels would jitter.

  Timer {
    interval: 50
    running: root.visible && !root.placed
    repeat: true
    onTriggered: root.reposition()
  }

  // Occasional follow while open (monitor / bar move).
  // Skip frame-pinned placements — fixed to chrome; reconfigure spam shakes them.
  Timer {
    interval: 200
    running: root.visible && root.placed && root.placement !== "frameCorner" && root.placement !== "frameDrop"
    repeat: true
    onTriggered: root.reposition()
  }
}
