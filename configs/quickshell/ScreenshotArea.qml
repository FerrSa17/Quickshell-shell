import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Area screenshot: freeze → select → edit (move/resize/annotate) → save/cancel.
Scope {
  id: root

  property bool active: false
  // "select" | "brush" | "rect" | "ellipse" | "arrow" | "eraser"
  property string tool: "select"
  readonly property int cornerRadius: 12
  readonly property int handleSize: 10
  readonly property color ink: Theme.red
  readonly property real inkWidth: 3
  readonly property real brushWidth: 4

  property string saveDir: (Quickshell.env("HOME") || "/home/user") + "/Pictures/Screenshots"

  Connections {
    target: PanelBus
    function onScreenshotAreaRequested() {
      root.tool = "select"
      root.active = true
    }
  }

  IpcHandler {
    target: "screenshot"
    function area(): void {
      PanelBus.openScreenshotArea()
    }
  }

  function cancel() {
    root.active = false
    root.tool = "select"
  }

  function pad2(n) {
    return n < 10 ? "0" + n : "" + n
  }

  function stampName() {
    const d = new Date()
    return "shot-"
      + d.getFullYear()
      + root.pad2(d.getMonth() + 1)
      + root.pad2(d.getDate())
      + "-"
      + root.pad2(d.getHours())
      + root.pad2(d.getMinutes())
      + root.pad2(d.getSeconds())
      + ".png"
  }

  component ToolBtn: Rectangle {
    id: tb
    property string glyph: ""
    property string toolId: ""
    property bool activeTool: root.tool === toolId
    signal activated

    width: 36
    height: 36
    radius: width / 2
    color: activeTool ? Theme.notifBlueDim : Theme.surface
    border.width: activeTool ? 2 : 0
    border.color: Theme.sapphire

    Text {
      anchors.centerIn: parent
      text: tb.glyph
      color: tb.activeTool ? Theme.sapphire : Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: 15
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.tool = tb.toolId
        tb.activated()
      }
    }
  }

  component ActionBtn: Rectangle {
    id: ab
    property string label: ""
    property color bg: Theme.surface
    property color fg: Theme.text
    signal activated

    width: Math.max(72, lab.implicitWidth + 20)
    height: 34
    radius: 8
    color: bg

    Text {
      id: lab
      anchors.centerIn: parent
      text: ab.label
      color: ab.fg
      font.family: Theme.fontFamily
      font.pixelSize: 13
      font.bold: true
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: ab.activated()
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      visible: root.active
      color: "transparent"
      aboveWindows: true
      focusable: true
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "quickshell-screenshot"
      WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      readonly property string freezePath: "/tmp/qs-shot-freeze-" + modelData.name + ".png"
      property url freezeUrl: ""
      property bool freezeReady: false

      // "selecting" | "editing"
      property string phase: "selecting"
      property bool chromeVisible: true
      property bool saving: false

      property real selX: 0
      property real selY: 0
      property real selW: 0
      property real selH: 0

      property real anchorX: 0
      property real anchorY: 0
      property real pressX: 0
      property real pressY: 0
      property real origX: 0
      property real origY: 0
      property real origW: 0
      property real origH: 0

      property string gesture: "" // "" | "create" | "move" | "resize" | "draw"
      property string resizeHandle: ""
      property real drawX1: 0
      property real drawY1: 0
      property real drawX2: 0
      property real drawY2: 0
      property var draftPts: []

      // [{t,x1,y1,x2,y2} | {t:"brush", pts:[[x,y],...]}]
      property var shapes: []

      readonly property bool hasSel: selW >= 8 && selH >= 8
      readonly property real cornerR: Math.min(root.cornerRadius, selW / 2, selH / 2)

      function resetSession() {
        freezeReady = false
        freezeUrl = ""
        phase = "selecting"
        chromeVisible = true
        saving = false
        selX = 0
        selY = 0
        selW = 0
        selH = 0
        gesture = ""
        resizeHandle = ""
        shapes = []
        draftPts = []
        dimCanvas.requestPaint()
        shapeCanvas.requestPaint()
      }

      function clampSel() {
        let x = selX
        let y = selY
        let w = selW
        let h = selH
        if (w < 8) w = 8
        if (h < 8) h = 8
        x = Math.max(0, Math.min(x, width - w))
        y = Math.max(0, Math.min(y, height - h))
        w = Math.min(w, width - x)
        h = Math.min(h, height - y)
        selX = x
        selY = y
        selW = w
        selH = h
      }

      function normalizeRect(x1, y1, x2, y2) {
        return {
          x: Math.min(x1, x2),
          y: Math.min(y1, y2),
          w: Math.abs(x2 - x1),
          h: Math.abs(y2 - y1)
        }
      }

      function handleAt(px, py) {
        if (phase !== "editing" || !hasSel)
          return ""
        const hs = root.handleSize
        const hit = hs + 4
        const pts = {
          "nw": [selX, selY],
          "n": [selX + selW / 2, selY],
          "ne": [selX + selW, selY],
          "e": [selX + selW, selY + selH / 2],
          "se": [selX + selW, selY + selH],
          "s": [selX + selW / 2, selY + selH],
          "sw": [selX, selY + selH],
          "w": [selX, selY + selH / 2]
        }
        const keys = ["nw", "ne", "se", "sw", "n", "s", "e", "w"]
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i]
          const p = pts[k]
          if (Math.abs(px - p[0]) <= hit && Math.abs(py - p[1]) <= hit)
            return k
        }
        return ""
      }

      function insideSel(px, py) {
        return px >= selX && px <= selX + selW && py >= selY && py <= selY + selH
      }

      function applyResize(hx, hy) {
        let x = origX
        let y = origY
        let w = origW
        let h = origH
        const dx = hx - pressX
        const dy = hy - pressY
        if (resizeHandle.indexOf("e") >= 0)
          w = origW + dx
        if (resizeHandle.indexOf("s") >= 0)
          h = origH + dy
        if (resizeHandle.indexOf("w") >= 0) {
          x = origX + dx
          w = origW - dx
        }
        if (resizeHandle.indexOf("n") >= 0) {
          y = origY + dy
          h = origH - dy
        }
        if (w < 0) {
          x = x + w
          w = -w
        }
        if (h < 0) {
          y = y + h
          h = -h
        }
        selX = x
        selY = y
        selW = w
        selH = h
        clampSel()
      }

      function shapeHit(lx, ly) {
        const thresh = 10
        for (let i = shapes.length - 1; i >= 0; i--) {
          const s = shapes[i]
          if (s.t === "brush" && s.pts && s.pts.length) {
            const pts = s.pts
            for (let j = 0; j < pts.length; j++) {
              if (Math.hypot(lx - pts[j][0], ly - pts[j][1]) <= thresh + root.brushWidth)
                return i
              if (j + 1 < pts.length) {
                const x1 = pts[j][0], y1 = pts[j][1]
                const x2 = pts[j + 1][0], y2 = pts[j + 1][1]
                const A = lx - x1, B = ly - y1, C = x2 - x1, D = y2 - y1
                const len2 = C * C + D * D
                let t = len2 > 0 ? (A * C + B * D) / len2 : 0
                t = Math.max(0, Math.min(1, t))
                const px = x1 + t * C, py = y1 + t * D
                if (Math.hypot(lx - px, ly - py) <= thresh + root.brushWidth * 0.5)
                  return i
              }
            }
          } else if (s.t === "rect" || s.t === "ellipse") {
            const r = normalizeRect(s.x1, s.y1, s.x2, s.y2)
            const nearBorder =
              (lx >= r.x - thresh && lx <= r.x + r.w + thresh
               && ly >= r.y - thresh && ly <= r.y + r.h + thresh)
              && !(lx >= r.x + thresh && lx <= r.x + r.w - thresh
                   && ly >= r.y + thresh && ly <= r.y + r.h - thresh)
            const inside = lx >= r.x && lx <= r.x + r.w && ly >= r.y && ly <= r.y + r.h
            if (nearBorder || inside)
              return i
          } else if (s.t === "arrow") {
            const x1 = s.x1, y1 = s.y1, x2 = s.x2, y2 = s.y2
            const A = lx - x1, B = ly - y1, C = x2 - x1, D = y2 - y1
            const len2 = C * C + D * D
            let t = len2 > 0 ? (A * C + B * D) / len2 : 0
            t = Math.max(0, Math.min(1, t))
            const px = x1 + t * C, py = y1 + t * D
            if (Math.hypot(lx - px, ly - py) <= thresh)
              return i
          }
        }
        return -1
      }

      function eraseAt(lx, ly) {
        const idx = shapeHit(lx, ly)
        if (idx < 0)
          return
        const next = shapes.slice()
        next.splice(idx, 1)
        shapes = next
        shapeCanvas.requestPaint()
      }

      function commitDraw() {
        const dx = Math.abs(drawX2 - drawX1)
        const dy = Math.abs(drawY2 - drawY1)
        if (dx < 3 && dy < 3)
          return
        const next = shapes.slice()
        next.push({
          t: root.tool,
          x1: drawX1,
          y1: drawY1,
          x2: drawX2,
          y2: drawY2
        })
        shapes = next
        shapeCanvas.requestPaint()
      }

      function commitBrush() {
        if (!draftPts || draftPts.length < 2)
          return
        const next = shapes.slice()
        next.push({ t: "brush", pts: draftPts.slice() })
        shapes = next
        draftPts = []
        shapeCanvas.requestPaint()
      }

      function paintShapes(ctx, w, h, includeDraft) {
        ctx.reset()
        ctx.clearRect(0, 0, w, h)
        ctx.strokeStyle = root.ink
        ctx.fillStyle = "rgba(0,0,0,0)"
        ctx.lineWidth = root.inkWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        function drawBrush(pts, width) {
          if (!pts || pts.length < 1)
            return
          ctx.save()
          ctx.lineWidth = width
          ctx.beginPath()
          ctx.moveTo(pts[0][0], pts[0][1])
          for (let i = 1; i < pts.length; i++)
            ctx.lineTo(pts[i][0], pts[i][1])
          if (pts.length === 1) {
            ctx.arc(pts[0][0], pts[0][1], width / 2, 0, Math.PI * 2)
            ctx.fillStyle = root.ink
            ctx.fill()
            ctx.fillStyle = "rgba(0,0,0,0)"
          } else {
            ctx.stroke()
          }
          ctx.restore()
        }

        function drawOne(s) {
          if (s.t === "brush") {
            drawBrush(s.pts, root.brushWidth)
          } else if (s.t === "rect") {
            const r = normalizeRect(s.x1, s.y1, s.x2, s.y2)
            ctx.strokeRect(r.x + 0.5, r.y + 0.5, Math.max(0, r.w - 1), Math.max(0, r.h - 1))
          } else if (s.t === "ellipse") {
            const r = normalizeRect(s.x1, s.y1, s.x2, s.y2)
            if (r.w < 1 || r.h < 1)
              return
            ctx.beginPath()
            ctx.save()
            ctx.translate(r.x + r.w / 2, r.y + r.h / 2)
            ctx.scale(r.w / 2, r.h / 2)
            ctx.arc(0, 0, 1, 0, Math.PI * 2)
            ctx.restore()
            ctx.stroke()
          } else if (s.t === "arrow") {
            const x1 = s.x1, y1 = s.y1, x2 = s.x2, y2 = s.y2
            ctx.beginPath()
            ctx.moveTo(x1, y1)
            ctx.lineTo(x2, y2)
            ctx.stroke()
            const ang = Math.atan2(y2 - y1, x2 - x1)
            const head = 12
            ctx.beginPath()
            ctx.moveTo(x2, y2)
            ctx.lineTo(x2 - head * Math.cos(ang - 0.4), y2 - head * Math.sin(ang - 0.4))
            ctx.lineTo(x2 - head * Math.cos(ang + 0.4), y2 - head * Math.sin(ang + 0.4))
            ctx.closePath()
            ctx.fillStyle = root.ink
            ctx.fill()
            ctx.fillStyle = "rgba(0,0,0,0)"
          }
        }

        for (let i = 0; i < shapes.length; i++)
          drawOne(shapes[i])

        if (includeDraft && gesture === "draw") {
          drawOne({
            t: root.tool,
            x1: drawX1,
            y1: drawY1,
            x2: drawX2,
            y2: drawY2
          })
        }
        if (includeDraft && gesture === "brush")
          drawBrush(draftPts, root.brushWidth)
      }

      function refreshChrome() {
        dimCanvas.requestPaint()
        shapeCanvas.requestPaint()
      }

      function doSave() {
        if (!hasSel || saving || !freezeReady)
          return
        saving = true
        chromeVisible = false
        refreshChrome()
        Qt.callLater(() => {
          exportBox.grabToImage(result => {
            const path = root.saveDir + "/" + root.stampName()
            Quickshell.execDetached(["mkdir", "-p", root.saveDir])
            if (!result.saveToFile(path)) {
              saving = false
              chromeVisible = true
              refreshChrome()
              return
            }
            Quickshell.execDetached([
              "bash", "-c",
              "wl-copy --type image/png < " + JSON.stringify(path)
            ])
            root.cancel()
          }, Qt.size(Math.round(selW), Math.round(selH)))
        })
      }

      Process {
        id: freezeProc
        command: ["grim", "-o", win.modelData.name, win.freezePath]
        onExited: code => {
          if (!root.active)
            return
          if (code !== 0) {
            root.cancel()
            return
          }
          win.freezeUrl = "file://" + win.freezePath + "?t=" + Date.now()
          win.freezeReady = true
          win.refreshChrome()
        }
      }

      Connections {
        target: root
        function onActiveChanged() {
          if (root.active) {
            win.resetSession()
            freezeProc.running = true
          } else {
            freezeProc.running = false
            win.resetSession()
          }
        }
      }

      Shortcut {
        sequence: "Escape"
        enabled: root.active
        context: Qt.WindowShortcut
        onActivated: root.cancel()
      }

      Shortcut {
        sequence: "Return"
        enabled: root.active && win.phase === "editing" && win.hasSel
        context: Qt.WindowShortcut
        onActivated: win.doSave()
      }

      // Frozen desktop
      Image {
        anchors.fill: parent
        visible: win.freezeReady
        source: win.freezeUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
      }

      Rectangle {
        anchors.fill: parent
        visible: !win.freezeReady
        color: "#80000000"
        Text {
          anchors.centerIn: parent
          text: "…"
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: 28
        }
      }

      // Dim with rounded hole (must sit above exportBox so corners stay darkened)
      Canvas {
        id: dimCanvas
        anchors.fill: parent
        z: 10
        enabled: false
        visible: win.freezeReady
        renderStrategy: Canvas.Cooperative
        onPaint: {
          const ctx = getContext("2d")
          ctx.reset()
          ctx.clearRect(0, 0, width, height)
          ctx.fillStyle = "rgba(0, 0, 0, 0.5)"
          ctx.fillRect(0, 0, width, height)
          if (!win.hasSel && win.gesture !== "create")
            return

          const x = win.selX
          const y = win.selY
          const w = win.selW
          const h = win.selH
          if (w < 1 || h < 1)
            return
          const r = Math.min(root.cornerRadius, w / 2, h / 2)
          ctx.globalCompositeOperation = "destination-out"
          pathRoundRect(ctx, x, y, w, h, r)
          ctx.fill()
          ctx.globalCompositeOperation = "source-over"
          if (win.chromeVisible) {
            ctx.strokeStyle = Theme.hex("sapphire", "#83a598")
            ctx.lineWidth = 2
            pathRoundRect(ctx, x + 1, y + 1, Math.max(0, w - 2), Math.max(0, h - 2), Math.max(0, r - 1))
            ctx.stroke()
          }
        }

        function pathRoundRect(ctx, x, y, w, h, r) {
          ctx.beginPath()
          if (r <= 0.5) {
            ctx.rect(x, y, w, h)
            return
          }
          // quadraticCurveTo — more reliable than arcTo in Qt Canvas
          ctx.moveTo(x + r, y)
          ctx.lineTo(x + w - r, y)
          ctx.quadraticCurveTo(x + w, y, x + w, y + r)
          ctx.lineTo(x + w, y + h - r)
          ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
          ctx.lineTo(x + r, y + h)
          ctx.quadraticCurveTo(x, y + h, x, y + h - r)
          ctx.lineTo(x, y + r)
          ctx.quadraticCurveTo(x, y, x + r, y)
          ctx.closePath()
        }
      }

      // Export / annotation host — always rounded so corners aren't squared over the hole
      ClippingRectangle {
        id: exportBox
        x: win.selX
        y: win.selY
        width: Math.max(0, win.selW)
        height: Math.max(0, win.selH)
        z: 5
        visible: win.freezeReady && win.hasSel
        radius: win.cornerR
        color: "transparent"

        Image {
          id: cropImg
          x: -win.selX
          y: -win.selY
          width: win.width
          height: win.height
          source: win.freezeUrl
          asynchronous: false
          cache: false
        }

        Canvas {
          id: shapeCanvas
          anchors.fill: parent
          renderStrategy: Canvas.Cooperative
          onPaint: win.paintShapes(getContext("2d"), width, height, true)
        }
      }

      // Resize handles
      Repeater {
        model: win.phase === "editing" && win.chromeVisible && win.hasSel
               ? ["nw", "n", "ne", "e", "se", "s", "sw", "w"]
               : []

        Rectangle {
          required property string modelData
          width: root.handleSize
          height: root.handleSize
          radius: 2
          color: Theme.sapphire
          border.color: Theme.bg
          border.width: 1
          z: 20

          x: {
            const h = modelData
            if (h === "nw" || h === "w" || h === "sw")
              return win.selX - width / 2
            if (h === "ne" || h === "e" || h === "se")
              return win.selX + win.selW - width / 2
            return win.selX + win.selW / 2 - width / 2
          }
          y: {
            const h = modelData
            if (h === "nw" || h === "n" || h === "ne")
              return win.selY - height / 2
            if (h === "sw" || h === "s" || h === "se")
              return win.selY + win.selH - height / 2
            return win.selY + win.selH / 2 - height / 2
          }
        }
      }

      // Size label
      Rectangle {
        visible: win.freezeReady && win.hasSel && win.chromeVisible
        z: 21
        x: Math.min(win.width - width - 8, Math.max(8, win.selX))
        y: {
          const above = win.selY - height - 8
          return above >= 8 ? above : Math.min(win.height - height - 8, win.selY + 8)
        }
        width: dimLabel.implicitWidth + 12
        height: dimLabel.implicitHeight + 8
        radius: 6
        color: Theme.surface

        Text {
          id: dimLabel
          anchors.centerIn: parent
          text: Math.round(win.selW) + " × " + Math.round(win.selH)
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: 12
        }
      }

      MouseArea {
        id: area
        z: 5
        anchors.fill: parent
        enabled: win.freezeReady && !win.saving
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: {
          if (!win.freezeReady)
            return Qt.ArrowCursor
          if (win.phase === "selecting" || (win.phase === "editing" && root.tool === "select" && !win.insideSel(mouseX, mouseY) && !win.handleAt(mouseX, mouseY)))
            return Qt.CrossCursor
          const h = win.handleAt(mouseX, mouseY)
          if (h === "n" || h === "s")
            return Qt.SizeVerCursor
          if (h === "e" || h === "w")
            return Qt.SizeHorCursor
          if (h === "nw" || h === "se")
            return Qt.SizeFDiagCursor
          if (h === "ne" || h === "sw")
            return Qt.SizeBDiagCursor
          if (win.phase === "editing" && root.tool === "select" && win.insideSel(mouseX, mouseY))
            return Qt.SizeAllCursor
          if (root.tool === "eraser")
            return Qt.PointingHandCursor
          return Qt.CrossCursor
        }

        function overChrome(mx, my) {
          function hit(item) {
            if (!item.visible)
              return false
            return mx >= item.x && mx <= item.x + item.width
                && my >= item.y && my <= item.y + item.height
          }
          return hit(toolsBar) || hit(actionBar)
        }

        onPressed: event => {
          if (event.button === Qt.RightButton) {
            root.cancel()
            return
          }
          if (overChrome(event.x, event.y))
            return

          win.pressX = event.x
          win.pressY = event.y

          if (win.phase === "editing") {
            const h = win.handleAt(event.x, event.y)
            if (h !== "" && root.tool === "select") {
              win.gesture = "resize"
              win.resizeHandle = h
              win.origX = win.selX
              win.origY = win.selY
              win.origW = win.selW
              win.origH = win.selH
              return
            }

            if (win.insideSel(event.x, event.y)) {
              if (root.tool === "select") {
                win.gesture = "move"
                win.origX = win.selX
                win.origY = win.selY
                return
              }
              if (root.tool === "eraser") {
                win.eraseAt(event.x - win.selX, event.y - win.selY)
                return
              }
              if (root.tool === "brush") {
                const lx = Math.max(0, Math.min(win.selW, event.x - win.selX))
                const ly = Math.max(0, Math.min(win.selH, event.y - win.selY))
                win.gesture = "brush"
                win.draftPts = [[lx, ly]]
                shapeCanvas.requestPaint()
                return
              }
              if (root.tool === "rect" || root.tool === "ellipse" || root.tool === "arrow") {
                win.gesture = "draw"
                win.drawX1 = event.x - win.selX
                win.drawY1 = event.y - win.selY
                win.drawX2 = win.drawX1
                win.drawY2 = win.drawY1
                shapeCanvas.requestPaint()
                return
              }
            }

            // Outside: new selection with select tool
            if (root.tool === "select") {
              win.shapes = []
              win.phase = "selecting"
              win.gesture = "create"
              win.anchorX = event.x
              win.anchorY = event.y
              win.selX = event.x
              win.selY = event.y
              win.selW = 0
              win.selH = 0
              win.refreshChrome()
              return
            }
            return
          }

          // selecting phase
          win.gesture = "create"
          win.anchorX = event.x
          win.anchorY = event.y
          win.selX = event.x
          win.selY = event.y
          win.selW = 0
          win.selH = 0
          win.refreshChrome()
        }

        onPositionChanged: event => {
          if (win.gesture === "")
            return

          if (win.gesture === "create") {
            const r = win.normalizeRect(win.anchorX, win.anchorY, event.x, event.y)
            win.selX = r.x
            win.selY = r.y
            win.selW = r.w
            win.selH = r.h
            win.clampSel()
            dimCanvas.requestPaint()
            return
          }

          if (win.gesture === "move") {
            win.selX = win.origX + (event.x - win.pressX)
            win.selY = win.origY + (event.y - win.pressY)
            win.clampSel()
            win.refreshChrome()
            return
          }

          if (win.gesture === "resize") {
            win.applyResize(event.x, event.y)
            win.refreshChrome()
            return
          }

          if (win.gesture === "draw") {
            win.drawX2 = Math.max(0, Math.min(win.selW, event.x - win.selX))
            win.drawY2 = Math.max(0, Math.min(win.selH, event.y - win.selY))
            shapeCanvas.requestPaint()
            return
          }

          if (win.gesture === "brush") {
            const lx = Math.max(0, Math.min(win.selW, event.x - win.selX))
            const ly = Math.max(0, Math.min(win.selH, event.y - win.selY))
            const pts = win.draftPts.slice()
            const last = pts.length ? pts[pts.length - 1] : null
            if (!last || Math.hypot(lx - last[0], ly - last[1]) >= 1.5) {
              pts.push([lx, ly])
              win.draftPts = pts
              shapeCanvas.requestPaint()
            }
          }
        }

        onReleased: event => {
          if (event.button !== Qt.LeftButton)
            return

          if (win.gesture === "create") {
            win.gesture = ""
            if (win.hasSel) {
              win.phase = "editing"
              root.tool = "select"
            } else {
              win.selW = 0
              win.selH = 0
            }
            win.refreshChrome()
            return
          }

          if (win.gesture === "draw") {
            win.commitDraw()
            win.gesture = ""
            shapeCanvas.requestPaint()
            return
          }

          if (win.gesture === "brush") {
            win.commitBrush()
            win.gesture = ""
            return
          }

          if (win.gesture === "move" || win.gesture === "resize") {
            win.gesture = ""
            win.resizeHandle = ""
            win.refreshChrome()
          }
        }
      }

      // Drawing tools — left of selection; inside when there's no room outside.
      // Outside exportBox + hidden via chromeVisible on save → never in the PNG.
      Column {
        id: toolsBar
        visible: win.phase === "editing" && win.chromeVisible && win.hasSel
        z: 30
        spacing: 8

        readonly property int gap: 10
        readonly property int pad: 12
        readonly property bool placeInside: win.selX < (implicitWidth + gap + 8)

        x: placeInside
           ? win.selX + pad
           : win.selX - implicitWidth - gap
        y: {
          const top = placeInside ? win.selY + pad : win.selY
          const maxY = placeInside
                       ? win.selY + win.selH - height - pad
                       : win.height - height - 8
          return Math.max(placeInside ? win.selY + pad : 8, Math.min(top, maxY))
        }

        ToolBtn {
          glyph: "\uf047"
          toolId: "select"
        }
        ToolBtn {
          glyph: "\uf1fc"
          toolId: "brush"
        }
        ToolBtn {
          glyph: "\uf0c8"
          toolId: "rect"
        }
        ToolBtn {
          glyph: "\uf111"
          toolId: "ellipse"
        }
        ToolBtn {
          glyph: "\uf061"
          toolId: "arrow"
        }
        ToolBtn {
          glyph: "\uf12d"
          toolId: "eraser"
        }
      }

      // Save / Cancel — below selection, or inside bottom when fullscreen
      Row {
        id: actionBar
        visible: win.phase === "editing" && win.chromeVisible && win.hasSel
        z: 30
        spacing: 8

        readonly property int gap: 10
        readonly property int pad: 12
        readonly property bool placeInside: (win.selY + win.selH + gap + height) > (win.height - 8)

        x: {
          const prefer = win.selX + (placeInside ? pad : 0)
          return Math.min(win.width - width - 8, Math.max(8, prefer))
        }
        y: {
          if (placeInside)
            return Math.max(win.selY + pad, win.selY + win.selH - height - pad)
          const below = win.selY + win.selH + gap
          if (below + height <= win.height - 8)
            return below
          return Math.max(8, win.selY - height - gap)
        }

        ActionBtn {
          label: "Cancel"
          bg: Theme.surface
          fg: Theme.text
          onActivated: root.cancel()
        }
        ActionBtn {
          label: "Save"
          bg: Theme.sapphire
          fg: Theme.bg
          onActivated: win.doSave()
        }
      }
    }
  }
}
