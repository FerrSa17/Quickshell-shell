import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight

  property bool online: false
  property bool wifi: false

  function refresh() {
    netProc.running = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: netProc
    command: ["sh", "-c", "ip -br link | awk '$2==\"UP\" && $1!=\"lo\" {print $1}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        const ifaces = text.trim().split("\n").filter(s => s.length > 0)
        root.online = ifaces.length > 0
        root.wifi = ifaces.some(n => n.indexOf("wl") === 0 || n.indexOf("wlan") === 0)
      }
    }
  }

  Text {
    id: icon
    text: {
      const _ = NetRadio.rev
      if (NetRadio.canSwitch && NetRadio.linkMode === "wifi")
        return "\uf1eb"
      if (NetRadio.canSwitch && NetRadio.linkMode === "wired")
        return "\uf0e8"
      if (!root.online)
        return "\uf127"
      if (root.wifi)
        return "\uf1eb"
      return "\uf0e8"
    }
    color: {
      const _ = NetRadio.rev
      if (NetRadio.canSwitch && NetRadio.linkMode === "wifi")
        return NetRadio.wifiConnected ? Theme.text : Theme.muted
      if (NetRadio.canSwitch && NetRadio.linkMode === "wired")
        return NetRadio.ethernetConnected ? Theme.text : Theme.muted
      return root.online ? Theme.text : Theme.muted
    }
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    font.weight: Theme.barFontWeight
  }
}
