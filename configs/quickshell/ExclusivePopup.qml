import QtQuick

// Bind a popup's `open` flag to PanelBus so only one exclusive popup is up.
// A newly claimed panel stays closed until the previous close animation ends.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  required property string popupId
  required property var host
  property bool applying: false

  function setHostOpen(v) {
    if (!root.host || root.host.open === v)
      return
    root.applying = true
    root.host.open = v
    root.applying = false
  }

  Connections {
    target: root.host
    function onOpenChanged() {
      if (root.applying)
        return
      if (root.host.open) {
        if (!PanelBus.claim(root.popupId))
          root.setHostOpen(false)
      } else {
        PanelBus.release(root.popupId)
      }
    }
  }

  Connections {
    target: PanelBus
    function onExclusiveChanged(id) {
      if (id === root.popupId) {
        root.setHostOpen(true)
        return
      }
      if (id === "") {
        if (PanelBus.pendingId === root.popupId)
          return
        root.setHostOpen(false)
        return
      }
      root.setHostOpen(false)
    }
  }

  Component.onCompleted: {
    if (root.host && root.host.open)
      PanelBus.claim(root.popupId)
  }
}
