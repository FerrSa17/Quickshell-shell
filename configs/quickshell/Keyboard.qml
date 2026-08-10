pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string layout: "us"
  property string deviceName: ""

  function mapLayout(name) {
    const n = (name || "").toLowerCase()
    if (n.indexOf("russian") >= 0 || n === "ru")
      return "ru"
    if (n.indexOf("english") >= 0 || n.indexOf("us") >= 0 || n === "us")
      return "us"
    if (n.length <= 3)
      return n
    return n.slice(0, 2)
  }

  function refresh() {
    layoutProc.running = true
  }

  function cycle() {
    // `all` flips every keyboard that shares the session layout list.
    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
    Qt.callLater(root.refresh)
  }

  Component.onCompleted: refresh()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activelayout") {
        const parts = event.data.split(",")
        if (parts.length >= 2)
          root.layout = root.mapLayout(parts[parts.length - 1])
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: layoutProc
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          const keyboards = data.keyboards || []
          let main = null
          for (let i = 0; i < keyboards.length; i++) {
            if (keyboards[i].main) {
              main = keyboards[i]
              break
            }
          }
          if (!main && keyboards.length > 0)
            main = keyboards[0]
          if (main) {
            root.layout = root.mapLayout(main.active_keymap)
            root.deviceName = main.name || ""
          }
        } catch (e) {}
      }
    }
  }
}
