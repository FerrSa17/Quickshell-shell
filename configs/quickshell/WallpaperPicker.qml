import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Wallpaper grid popup. Optional bar trigger; usually opened from Control.
Item {
  id: root
  implicitWidth: showButton ? button.implicitWidth : 0
  implicitHeight: showButton ? button.implicitHeight : 0

  property bool showButton: false
  property Item externalAnchor: null

  readonly property string wallpaperDir: (Quickshell.env("HOME") || "/home/user") + "/Wallpaper"
  readonly property var allGroups: ["Light", "Dark", "Calm"]
  readonly property var groups: {
    const mode = ShellPrefs.appearanceMode
    if (mode === "light")
      return ["Light"]
    if (mode === "dark")
      return ["Dark"]
    return root.allGroups
  }
  property string activeGroup: "Calm"
  readonly property string transition: "fade"
  readonly property Item popupAnchor: externalAnchor || button

  property bool open: false
  property string currentPath: ""

  function groupFolder(name) {
    return "file://" + root.wallpaperDir + "/" + name
  }

  function folderForMode(mode) {
    if (mode === "light")
      return "Light"
    if (mode === "dark")
      return "Dark"
    return "Calm"
  }

  function syncGroupToMode() {
    const allowed = root.groups
    const prefer = root.folderForMode(ShellPrefs.appearanceMode)
    if (allowed.indexOf(root.activeGroup) === -1)
      root.activeGroup = prefer
    else if (ShellPrefs.appearanceMode !== "calm")
      root.activeGroup = prefer
  }

  function setWallpaper(path) {
    // Theme only for the chosen wallpaper (no hover preview); blends with awww fade.
    Theme.applyFromWallpaper(path)
    Quickshell.execDetached([
      "awww", "img", path,
      "--transition-type", root.transition,
      "--transition-duration", "1.5"
    ])
    currentPath = path
    open = false
  }

  function setRandomWallpaper() {
    const n = folderModel.count
    if (n < 1)
      return

    let idx = Math.floor(Math.random() * n)
    if (n > 1) {
      for (let tries = 0; tries < 8; tries++) {
        const path = folderModel.get(idx, "filePath")
        if (path && path !== root.currentPath)
          break
        idx = Math.floor(Math.random() * n)
      }
    }

    const path = folderModel.get(idx, "filePath")
    if (path)
      root.setWallpaper(path)
  }

  function setAppearanceMode(mode, forceWallpaper) {
    if (mode !== "light" && mode !== "calm" && mode !== "dark")
      return
    const changed = ShellPrefs.appearanceMode !== mode
    if (!changed && !forceWallpaper)
      return

    if (changed) {
      ShellPrefs.appearanceMode = mode
      ShellPrefs.darkTheme = mode !== "light"
      ShellPrefs.persistSoon()
    }
    root.activeGroup = root.folderForMode(mode)
    if (mode === "light")
      Theme.applyFixedPalette("light", true)
    else if (mode === "dark")
      Theme.applyFixedPalette("dark", true)
    randomPick.command = [
      "bash", "-c",
      "find \"" + root.wallpaperDir + "/" + root.folderForMode(mode) + "\" -type f "
      + "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' "
      + "-o -iname '*.gif' -o -iname '*.bmp' \\) 2>/dev/null | shuf -n1"
    ]
    randomPick.running = false
    randomPick.running = true
  }

  Process {
    id: randomPick
    stdout: StdioCollector {
      onStreamFinished: {
        const path = text.trim()
        if (path.length)
          root.setWallpaper(path)
        else if (!ShellPrefs.extractTheme)
          Theme.syncAppearancePalette(true)
      }
    }
  }

  Connections {
    target: PanelBus
    function onAppearanceModeRequested(mode) {
      const force = PanelBus.appearanceForceWallpaper
      PanelBus.appearanceForceWallpaper = false
      root.setAppearanceMode(mode, force)
    }
  }

  Connections {
    target: ShellPrefs
    function onAppearanceModeChanged() {
      root.syncGroupToMode()
    }
  }

  function refreshCurrent() {
    queryProc.running = true
  }

  function syncGroupFromCurrent() {
    const path = root.currentPath || ""
    for (let i = 0; i < root.groups.length; i++) {
      const g = root.groups[i]
      if (path.indexOf("/Wallpaper/" + g + "/") !== -1) {
        root.activeGroup = g
        return
      }
    }
  }

  Process {
    id: queryProc
    command: ["awww", "query"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/image:\s*(\S+)/)
        if (m && m[1]) {
          root.currentPath = m[1]
          root.syncGroupFromCurrent()
        }
      }
    }
  }

  Component.onCompleted: refreshCurrent()

  IconButton {
    id: button
    visible: root.showButton
    icon: "\uf03e"
    iconColor: root.open ? Theme.sapphire : Theme.subtext
    onClicked: root.open = !root.open
  }

  FolderListModel {
    id: folderModel
    folder: root.groupFolder(root.activeGroup)
    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.PNG", "*.JPG", "*.JPEG"]
    showDirs: false
    showDotAndDotDot: false
    sortField: FolderListModel.Name
  }

  LayerPopup {
    id: popup
    visible: root.open || sheet.active
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    anchorItem: root.popupAnchor
    barWindow: root.QsWindow.window
    placement: "center"
    screenPad: 24
    gap: 18

    Shortcut {
      sequence: "Escape"
      enabled: root.open || sheet.active
      context: Qt.WindowShortcut
      onActivated: root.open = false
    }

    PopupSheet {
      id: sheet
      open: root.open
      placed: popup.placed
      motion: "center"

      Rectangle {
        id: panel
        focus: true
        color: Theme.windowBg
        radius: 16
        implicitWidth: 640
        implicitHeight: 520

        Keys.onEscapePressed: event => {
          root.open = false
          event.accepted = true
        }

        Text {
          id: title
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.topMargin: 14
          anchors.leftMargin: 14
          text: "Wallpapers"
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
        }

        Rectangle {
          id: randomBtn
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: 10
          anchors.rightMargin: 14
          width: randomRow.implicitWidth + 16
          height: 28
          radius: 8
          color: Theme.well
          visible: folderModel.count > 0

          Row {
            id: randomRow
            anchors.centerIn: parent
            spacing: 6

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf074"
              color: Theme.sapphire
              font.family: Theme.fontFamily
              font.pixelSize: Theme.iconSize
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Random"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: 12
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setRandomWallpaper()
          }
        }

        Row {
          id: groupRow
          anchors.top: title.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: root.groups.length > 1 ? 12 : 0
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          spacing: 8
          height: root.groups.length > 1 ? 28 : 0
          visible: root.groups.length > 1

          Repeater {
            model: root.groups

            Rectangle {
              id: tab
              required property string modelData
              readonly property bool active: root.activeGroup === modelData
              width: tabLabel.implicitWidth + 16
              height: 28
              radius: 8
              color: tab.active ? Theme.sapphire : Theme.well

              Text {
                id: tabLabel
                anchors.centerIn: parent
                text: tab.modelData
                color: tab.active ? Theme.windowBg : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 12
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeGroup = tab.modelData
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: folderModel.count === 0
          text: "No wallpapers in " + root.activeGroup
          color: Theme.muted
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
        }

        GridView {
          id: grid
          visible: folderModel.count > 0
          anchors {
            top: groupRow.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 12
            leftMargin: 14
            rightMargin: 14
            bottomMargin: 14
          }
          clip: true
          cellWidth: 150
          cellHeight: 100
          model: folderModel
          keyNavigationEnabled: true
          Keys.onEscapePressed: event => {
            root.open = false
            event.accepted = true
          }

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
          }

          delegate: Item {
            id: cell
            required property string filePath
            required property string fileName
            required property url fileUrl
            width: grid.cellWidth - 8
            height: grid.cellHeight - 8

            readonly property bool selected: cell.filePath === root.currentPath

            ClippingRectangle {
              anchors.fill: parent
              radius: 8
              color: Theme.pill

              Image {
                anchors.fill: parent
                source: cell.fileUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 300
                sourceSize.height: 200
              }

              Rectangle {
                anchors.fill: parent
                radius: 8
                color: "transparent"
                border.width: cell.selected || hover.containsMouse ? 2 : 0
                border.color: cell.selected ? Theme.green : Theme.sapphire
              }

              MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setWallpaper(cell.filePath)
              }
            }
          }
        }
      }
    }
  }

  onOpenChanged: {
    if (open) {
      root.syncGroupToMode()
      refreshCurrent()
      Qt.callLater(() => panel.forceActiveFocus())
    }
  }
}
