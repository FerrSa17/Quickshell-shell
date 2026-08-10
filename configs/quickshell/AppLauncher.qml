import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Bottom app launcher — searchable vertical list. Bind Win+W yourself, e.g.:
//   qs ipc call launcher toggle
Scope {
  id: root

  property bool open: false
  property real panelT: 0
  property real contentT: 0
  property bool animBusy: false
  property bool hasQueued: false
  property bool queuedOpen: false
  property bool panelHovered: false

  // Hotkey only: Super+W (qs ipc call launcher toggle).
  readonly property int edgeHitH: Theme.frameThickness + 4
  readonly property int edgeHitW: 280

  // Full filtered+sorted list; view shows a sliding window of rows
  property var fullList: []
  property int cursor: 0
  property int windowStart: 0
  // id -> { count, last }
  property var recents: ({})

  readonly property int rowH: 48
  readonly property int listRowSpacing: 4
  readonly property int visibleRows: 9
  readonly property int searchH: 44
  readonly property int panelPad: 28
  readonly property int panelGap: 14
  readonly property int maxListH: rowH * visibleRows + listRowSpacing * (visibleRows - 1)
  readonly property int maxPanelH: panelPad + searchH + panelGap + maxListH
  readonly property int selectedInWindow: cursor - windowStart
  readonly property int windowSize: visibleRows

  readonly property var hiddenNameSubstrings: [
    "avahi",
    "hardware locality",
    "все приложения",
    "all applications",
    "mpv",
    "yazi"
  ]
  readonly property var hiddenNameExact: [
    "cmake",
    "htop",
    "kitty",
    "neovim",
    "btop++",
    "uuctl",
    "rofi",
    "vim"
  ]
  readonly property var hiddenIdSubstrings: [
    "avahi",
    "lstopo",
    "bssh",
    "bvnc",
    "xfce4-appfinder",
    "cmake",
    "mpv",
    "kitty",
    "nvim",
    "btop",
    "openjdk",
    "uuctl",
    "rofi",
    "yazi",
    "pinentry-qt",
    "qdbusviewer",
    "qv4l2",
    "qvidcap"
  ]
  readonly property var hiddenIds: [
    "htop",
    "vim",
    "assistant",
    "designer",
    "linguist"
  ]

  // Entrance: grow up from the bottom frame chrome (same surface as DesktopFrame).
  ParallelAnimation {
    id: openAnim
    NumberAnimation {
      target: root
      property: "panelT"
      to: 1
      duration: 380
      easing.type: Easing.OutCubic
    }
    SequentialAnimation {
      PauseAnimation {
        duration: 30
      }
      NumberAnimation {
        target: root
        property: "contentT"
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
      }
    }
    onStopped: root.onAnimStopped()
  }

  ParallelAnimation {
    id: closeAnim
    NumberAnimation {
      target: root
      property: "panelT"
      to: 0
      duration: 240
      easing.type: Easing.InCubic
    }
    NumberAnimation {
      target: root
      property: "contentT"
      to: 0
      duration: 140
      easing.type: Easing.InCubic
    }
    onStopped: root.onAnimStopped()
  }

  function onAnimStopped() {
    animBusy = false
    if (!hasQueued)
      return
    hasQueued = false
    setOpen(queuedOpen)
  }

  FileView {
    id: recentsFile
    path: Quickshell.statePath("launcher-recents.json")
    blockLoading: true
    watchChanges: true

    Component.onCompleted: root.loadRecents()
    onLoaded: root.loadRecents()
    onFileChanged: root.loadRecents()
  }

  function loadRecents() {
    try {
      const raw = recentsFile.text()
      if (!raw || raw.length < 2) {
        recents = ({})
        return
      }
      const parsed = JSON.parse(raw)
      recents = parsed && typeof parsed === "object" ? parsed : ({})
    } catch (e) {
      recents = ({})
    }
    if (open)
      rebuildList()
  }

  function saveRecents() {
    try {
      recentsFile.setText(JSON.stringify(recents, null, 2))
    } catch (e) {
      // ignore write errors
    }
  }

  function bumpRecent(id) {
    if (!id)
      return
    const cur = recents[id] || { count: 0, last: 0 }
    const next = Object.assign({}, recents)
    next[id] = {
      count: (cur.count || 0) + 1,
      last: Date.now()
    }
    recents = next
    saveRecents()
  }

  function recentScore(id) {
    const r = recents[id]
    if (!r)
      return 0
    // Prefer last-used, break ties with launch count
    return (Number(r.last) || 0) * 1000 + (Number(r.count) || 0)
  }

  function isHidden(entry) {
    const name = (entry.name || "").toLowerCase()
    const id = (entry.id || "").toLowerCase().replace(/\.desktop$/, "")

    if (name.startsWith("qt "))
      return true

    for (let e = 0; e < hiddenNameExact.length; e++) {
      if (name === hiddenNameExact[e])
        return true
    }
    for (let h = 0; h < hiddenIds.length; h++) {
      if (id === hiddenIds[h])
        return true
    }
    for (let i = 0; i < hiddenNameSubstrings.length; i++) {
      if (name.indexOf(hiddenNameSubstrings[i]) !== -1)
        return true
    }
    for (let j = 0; j < hiddenIdSubstrings.length; j++) {
      if (id.indexOf(hiddenIdSubstrings[j]) !== -1)
        return true
    }
    return false
  }

  function displayName(entry) {
    const name = entry && entry.name ? entry.name : ""
    // "LibreOffice Writer" → "Writer"; bare "LibreOffice" stays
    const stripped = name.replace(/^libreoffice\s+/i, "")
    return stripped.length ? stripped : name
  }

  function matchesQuery(entry, q) {
    if (!q)
      return true
    if (entry.name && entry.name.toLowerCase().includes(q))
      return true
    if (root.displayName(entry).toLowerCase().includes(q))
      return true
    if (entry.genericName && entry.genericName.toLowerCase().includes(q))
      return true
    if (entry.comment && entry.comment.toLowerCase().includes(q))
      return true
    const keys = entry.keywords || []
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] && keys[i].toLowerCase().includes(q))
        return true
    }
    return false
  }

  function ensureVisible() {
    if (fullList.length === 0) {
      windowStart = 0
      cursor = 0
      return
    }
    if (cursor < 0)
      cursor = 0
    if (cursor >= fullList.length)
      cursor = fullList.length - 1
    if (cursor < windowStart)
      windowStart = cursor
    else if (cursor >= windowStart + windowSize)
      windowStart = cursor - windowSize + 1
  }

  function rebuildList() {
    const q = searchField.text.trim().toLowerCase()
    let list = DesktopEntries.applications.values.filter(d => {
      if (!d || d.noDisplay)
        return false
      if (root.isHidden(d))
        return false
      return root.matchesQuery(d, q)
    })

    list.sort((a, b) => {
      const sa = root.recentScore(a.id)
      const sb = root.recentScore(b.id)
      if (sa !== sb)
        return sb - sa
      const an = root.displayName(a).toLowerCase()
      const bn = root.displayName(b).toLowerCase()
      if (q) {
        const as = an.startsWith(q)
        const bs = bn.startsWith(q)
        if (as && !bs)
          return -1
        if (!as && bs)
          return 1
      }
      return an.localeCompare(bn)
    })

    fullList = list
    ensureVisible()
  }

  function moveCursor(delta) {
    if (fullList.length < 1)
      return
    cursor = Math.max(0, Math.min(fullList.length - 1, cursor + delta))
    ensureVisible()
  }

  function setOpen(wantOpen) {
    if (animBusy) {
      hasQueued = true
      queuedOpen = wantOpen
      return
    }

    const atOpen = panelT >= 0.999 && contentT >= 0.999
    const atClosed = panelT <= 0.001
    if (wantOpen && open && atOpen)
      return
    if (!wantOpen && !open && atClosed)
      return

    animBusy = true
    open = wantOpen
    openAnim.stop()
    closeAnim.stop()
    if (wantOpen)
      openAnim.start()
    else
      closeAnim.start()
  }

  function toggle() {
    if (animBusy) {
      const endState = hasQueued ? queuedOpen : open
      hasQueued = true
      queuedOpen = !endState
      return
    }
    setOpen(!open)
  }

  function close() {
    setOpen(false)
  }

  function launch(entry) {
    if (!entry)
      return
    bumpRecent(entry.id)
    const id = (entry.id || "").toLowerCase().replace(/\.desktop$/, "")
    // Menu launches Foot via start-fish so the session always lands in fish @ $HOME.
    if (id === "foot" || id === "org.codeberg.dnkl.foot") {
      Quickshell.execDetached([
        "foot", "-D", Quickshell.env("HOME") || "/home/user",
        "/home/user/.config/foot/start-fish.sh"
      ])
      close()
      return
    }
    entry.execute()
    close()
  }

  function launchSelected() {
    if (fullList.length < 1)
      return
    launch(fullList[cursor])
  }

  function resolveScreen() {
    const mon = Hyprland.focusedMonitor
    const screens = Quickshell.screens
    if (!screens || screens.length === 0)
      return null
    if (mon) {
      for (let i = 0; i < screens.length; i++) {
        if (screens[i].name === mon.name)
          return screens[i]
      }
    }
    return screens[0]
  }

  IpcHandler {
    target: "launcher"

    function toggle(): void {
      root.toggle()
    }

    function open(): void {
      root.setOpen(true)
    }

    function close(): void {
      root.setOpen(false)
    }
  }


  ScriptModel {
    id: apps
    objectProp: "id"
    values: root.fullList.slice(root.windowStart, root.windowStart + root.windowSize)
  }

  // Mid-bottom hit strip over the frame chrome (per screen).
  // Hidden while the launcher is open so it doesn't steal hover / clear focus grab.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      // Edge hover disabled — launcher is hotkey-only (Super+W).
      visible: false
      color: "transparent"
      aboveWindows: true
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "quickshell"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        left: true
        right: true
        bottom: true
      }

      margins {
        left: screen ? Math.max(0, Math.round((screen.width - root.edgeHitW) / 2)) : 0
        right: screen ? Math.max(0, Math.round((screen.width - root.edgeHitW) / 2)) : 0
        bottom: 0
      }

      implicitHeight: root.edgeHitH

      MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.NoButton
      }
    }
  }

  PanelWindow {
    id: win
    visible: ShellPrefs.panelLauncher && root.panelT > 0.001
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int filletS: Theme.filletS

    anchors {
      left: true
      right: true
      bottom: true
    }

    margins {
      // Sit on the bottom chrome; side room for frame fillets.
      bottom: 8
      left: screen ? Math.max(Theme.frameThickness, Math.round((screen.width - (panel.implicitWidth + 2 * filletS)) / 2)) : 0
      right: screen ? Math.max(Theme.frameThickness, Math.round((screen.width - (panel.implicitWidth + 2 * filletS)) / 2)) : 0
    }

    implicitHeight: root.maxPanelH
    implicitWidth: panel.implicitWidth + 2 * filletS

    Item {
      anchors.fill: parent
      clip: false

      // Bottom-frame join — same language as System Monitor top fillets, mirrored.
      component OuterFillet: Item {
        id: fillet
        property bool leftSide: true
        property int s: win.filletS
        width: s
        height: s
        opacity: 1
        visible: root.panelT > 0.001
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
            if (fillet.leftSide)
              ctx.arc(0, 0, s, 0, Math.PI * 2)
            else
              ctx.arc(s, 0, s, 0, Math.PI * 2)
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
            target: root
            function onPanelTChanged() {
              if (root.panelT > 0.001)
                filletCanvas.requestPaint()
            }
          }
        }
      }

      OuterFillet {
        leftSide: true
        anchors.left: parent.left
        anchors.bottom: parent.bottom
      }

      OuterFillet {
        leftSide: false
        anchors.right: parent.right
        anchors.bottom: parent.bottom
      }

      ClippingRectangle {
        id: panel
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: 420
        height: Math.max(1, Math.round(root.maxPanelH * root.panelT))
        // Flush to bottom frame; round the free top edge — same as sysmon, mirrored.
        radius: 16
        topLeftRadius: 16
        topRightRadius: 16
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: Theme.barBg
        antialiasing: true

        HoverHandler {
          onHoveredChanged: root.panelHovered = hovered
        }

        Column {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottomMargin: 14
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          height: root.maxPanelH - 28
          spacing: root.panelGap

          Row {
            width: parent.width
            height: root.searchH
            spacing: 10
            opacity: Math.max(0, Math.min(1, root.contentT * 1.6))
            transform: Translate {
              y: (1 - Math.max(0, Math.min(1, root.contentT * 1.6))) * 14
            }

            Text {
              id: searchLoupe
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf002"
              color: Theme.muted
              font.family: Theme.fontFamily
              font.pixelSize: Theme.iconSize
            }

            Rectangle {
              width: parent.width - searchLoupe.width - parent.spacing
              height: root.searchH
              radius: 10
              color: Theme.pill

              TextInput {
                id: searchField
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                selectByMouse: true
                clip: true

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  text: "Search apps..."
                  color: Theme.muted
                  font: searchField.font
                  visible: !searchField.text && !searchField.activeFocus
                }

                onTextChanged: {
                  root.cursor = 0
                  root.windowStart = 0
                  root.rebuildList()
                }

                Keys.onEscapePressed: root.close()

                Keys.onPressed: event => {
                  if (root.fullList.length < 1)
                    return

                  if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    root.moveCursor(1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                    root.moveCursor(-1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_PageDown) {
                    root.moveCursor(root.visibleRows)
                    event.accepted = true
                  } else if (event.key === Qt.Key_PageUp) {
                    root.moveCursor(-root.visibleRows)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.launchSelected()
                    event.accepted = true
                  }
                }
              }
            }
          }

          Item {
            id: listHost
            width: parent.width
            height: root.maxListH

            function moveSelectionTo(item) {
              if (!item)
                return
              const p = item.mapToItem(listHost, 0, 0)
              selectionRing.x = p.x
              selectionRing.y = p.y
              selectionRing.width = item.width
              selectionRing.height = item.height
              selectionRing.ready = true
            }

            Rectangle {
              id: selectionRing
              property bool ready: false
              width: listHost.width
              height: root.rowH
              radius: 12
              color: Theme.pill
              z: 0
              opacity: ready && root.contentT > 0.2 && root.fullList.length > 0
                     && root.selectedInWindow >= 0 && root.selectedInWindow < root.windowSize ? 1 : 0
              visible: opacity > 0.01

              Behavior on y {
                enabled: selectionRing.ready && root.contentT >= 0.999
                NumberAnimation {
                  duration: 220
                  easing.type: Easing.OutCubic
                }
              }
              Behavior on opacity {
                NumberAnimation {
                  duration: 140
                }
              }
            }

            Column {
              id: listCol
              width: parent.width
              spacing: root.listRowSpacing
              z: 1

              Repeater {
                model: apps

                delegate: Item {
                  id: row
                  required property var modelData
                  required property int index

                  width: listCol.width
                  height: root.rowH

                  readonly property bool selected: root.selectedInWindow === row.index
                  readonly property real enter: Math.max(0, Math.min(1, root.contentT * 1.45 - row.index * 0.04))

                  opacity: 0.2 + 0.8 * enter
                  transform: Translate {
                    y: (1 - enter) * 10
                  }

                  onSelectedChanged: {
                    if (selected)
                      listHost.moveSelectionTo(row)
                  }
                  onEnterChanged: {
                    if (selected)
                      listHost.moveSelectionTo(row)
                  }

                  Component.onCompleted: {
                    if (row.selected)
                      Qt.callLater(() => listHost.moveSelectionTo(row))
                  }

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: 36
                      height: 36
                      radius: 10
                      color: row.selected ? Theme.surface : Theme.well

                      IconImage {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: Quickshell.iconPath(row.modelData.icon || "", "application-x-executable")
                        asynchronous: true
                      }
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - 48
                      text: root.displayName(row.modelData)
                      color: Theme.text
                      font.family: Theme.fontFamily
                      font.pixelSize: Theme.fontSize
                      elide: Text.ElideRight
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.cursor = root.windowStart + row.index
                    onClicked: root.launch(row.modelData)
                  }
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: root.fullList.length === 0
              text: "No apps found"
              color: Theme.muted
              font.family: Theme.fontFamily
              font.pixelSize: 13
              z: 2
            }
          }
        }
      }
    }
  }

  onOpenChanged: {
    if (open) {
      selectionRing.ready = false
      const s = resolveScreen()
      if (s)
        win.screen = s
      searchField.text = ""
      cursor = 0
      windowStart = 0
      rebuildList()
      Qt.callLater(() => searchField.forceActiveFocus())
    } else {
      selectionRing.ready = false
      root.panelHovered = false
    }
  }

  Component.onCompleted: rebuildList()

  HyprlandFocusGrab {
    active: root.open
    windows: [win]
    onCleared: root.close()
  }
}
