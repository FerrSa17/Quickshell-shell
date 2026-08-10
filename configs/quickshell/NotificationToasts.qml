import QtQuick
import Quickshell
import Quickshell.Wayland

// Toasts hang from the top-right DesktopFrame corner — same surface language as Control.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: toastWindow
      required property var modelData
      screen: modelData

      readonly property int toastW: 360
      readonly property int filletS: Theme.filletS
      readonly property int topChrome: Theme.barPad + Theme.barHeight + Theme.barPad
      readonly property int stride: Notifications.toastStride
      readonly property int maxN: Notifications.maxToasts
      readonly property int stackH: Notifications.toasts.count * stride
      // Top toast's horizontal reveal progress (0→1) — top fillet rides this edge.
      property real topPanelT: 1
      // Y of the current top toast — fillet stays glued to the top card.
      property real topFilletY: 0
      // 0→1 recreate of the top chrome lip (plays after the slide-up finishes).
      // Only when flush under the top frame — not while Control/notif reserves the corner.
      property real topCornerT: 1
      readonly property bool flushToFrame: PanelBus.frameCornerReserve === 0

      NumberAnimation {
        id: topCornerAnim
        target: toastWindow
        property: "topCornerT"
        duration: 110
        easing.type: Easing.OutCubic
      }

      function snapTopCorner(v) {
        topCornerAnim.stop()
        topCornerT = v
      }

      function growTopCorner() {
        if (!toastWindow.flushToFrame) {
          snapTopCorner(0)
          return
        }
        topCornerAnim.stop()
        topCornerT = 0
        topCornerAnim.from = 0
        topCornerAnim.to = 1
        topCornerAnim.start()
      }

      Connections {
        target: PanelBus
        function onFrameCornerReserveChanged() {
          if (PanelBus.frameCornerReserve !== 0)
            toastWindow.snapTopCorner(0)
          else if (Notifications.toasts.count > 0)
            toastWindow.growTopCorner()
        }
      }

      Connections {
        target: Notifications.toasts
        function onCountChanged() {
          // After the stack empties, topCornerT can stay 0 from a mid-rise dismiss.
          // Restore the chrome lip so the next toast isn't missing its top corner.
          if (Notifications.toasts.count === 0)
            toastWindow.snapTopCorner(1)
          else if (toastWindow.flushToFrame && toastWindow.topCornerT < 0.05)
            toastWindow.growTopCorner()
        }
      }

      anchors {
        top: true
        right: true
      }

      margins {
        // Flush under top chrome (or under an open Control/notif panel) and to the right chrome.
        top: topChrome + PanelBus.frameCornerReserve
        right: 0
      }

      implicitWidth: toastW + filletS
      implicitHeight: maxN * stride
      color: "transparent"
      aboveWindows: true
      exclusionMode: ExclusionMode.Ignore
      visible: Notifications.toasts.count > 0
      WlrLayershell.namespace: "quickshell"

      // key → settled; bumped so radius bindings re-evaluate mid-entrance.
      property var settledKeys: ({})
      property int settleRev: 0

      function markSettled(key) {
        if (!key || settledKeys[key])
          return
        const next = Object.assign({}, settledKeys)
        next[key] = true
        settledKeys = next
        settleRev++
      }

      function clearSettled(key) {
        if (!key || !settledKeys[key])
          return
        const next = Object.assign({}, settledKeys)
        delete next[key]
        settledKeys = next
        settleRev++
      }

      function isSettledSlot(slot) {
        const _ = settleRev
        if (slot < 0 || slot >= Notifications.toasts.count)
          return true
        const row = Notifications.toasts.get(slot)
        if (!row)
          return true
        return !!settledKeys[String(row.key)]
      }

      // True while no fully-entered toast sits below `slot` — keep bottom rounding.
      function isVisualStackBottom(slot) {
        const _ = settleRev
        const n = Notifications.toasts.count
        if (slot >= n - 1)
          return true
        return !isSettledSlot(slot + 1)
      }

      Connections {
        target: Notifications.toasts
        function onCountChanged() {
          // Drop settled flags for removed keys.
          const live = ({})
          for (let i = 0; i < Notifications.toasts.count; i++) {
            const k = String(Notifications.toasts.get(i).key)
            if (toastWindow.settledKeys[k])
              live[k] = true
          }
          toastWindow.settledKeys = live
          toastWindow.settleRev++
        }
      }

      // Control-style chrome flares for the toast stack.
      component OuterFillet: Item {
        id: fillet
        property bool topJoin: false
        property int s: toastWindow.filletS
        width: s
        height: s
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
            // Match chrome; keep opaque so the lip stays visible over wallpaper.
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, c.a)
            ctx.fillRect(0, 0, s, s)
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            // Concave join: peels left along the top chrome.
            ctx.arc(0, s, s, 0, Math.PI * 2)
            ctx.fill()
          }
          Component.onCompleted: requestPaint()
          Connections {
            target: Theme
            function onPaletteRevChanged() {
              filletCanvas.requestPaint()
            }
            function onBlendTChanged() {
              filletCanvas.requestPaint()
            }
          }
        }
      }

      OuterFillet {
        id: topFillet
        topJoin: true
        // Left edge of the top toast; Y tracks the card (0 once the slide settles).
        // Only while flush to the top frame — under Control/notif there is no join.
        x: Math.round((1 - toastWindow.topPanelT) * toastWindow.toastW)
        y: toastWindow.topFilletY
        opacity: toastWindow.topCornerT
        visible: Notifications.toasts.count > 0
                 && toastWindow.flushToFrame
                 && toastWindow.topCornerT > 0.001
        onVisibleChanged: {
          if (visible)
            Qt.callLater(() => {
              // Canvas can stay blank after the window was hidden.
              for (let i = 0; i < children.length; i++) {
                if (children[i].requestPaint)
                  children[i].requestPaint()
              }
            })
        }
      }

      Repeater {
        model: Notifications.toasts

        delegate: Item {
          id: wrap
          required property string key
          required property string summary
          required property string body
          required property string appName
          required property var at
          required property int slot

          width: toastWindow.toastW
          height: Notifications.toastH
          // Grow out of the top-right corner; stacked flush (no gap).
          // Offset by filletS so the left chrome lip can sit beside the stack.
          x: toastWindow.filletS + Math.round((1 - wrap.panelT) * toastWindow.toastW)
          y: slot * toastWindow.stride
          clip: true
          z: 1

          property real panelT: 0
          property real contentT: 0
          property int prevSlot: -1
          property bool risingToTop: false
          property bool exiting: false
          readonly property bool visualBottom: toastWindow.isVisualStackBottom(wrap.slot)

          function syncTopReveal() {
            if (wrap.slot === 0) {
              toastWindow.topPanelT = wrap.panelT
              toastWindow.topFilletY = wrap.y
            }
          }

          function claimTopCorner() {
            // Became the new top after the one above left — keep body rounding
            // through the slide-up, then grow the chrome lip only if flush to frame.
            wrap.risingToTop = true
            toastWindow.snapTopCorner(0)
            riseTopTimer.restart()
          }

          function beginDismiss() {
            if (wrap.exiting)
              return
            wrap.exiting = true
            riseTopTimer.stop()
            enterAnim.stop()
            // Keep the chrome lip attached while the top toast slides away
            // (fillet tracks panelT via syncTopReveal). Non-top: just slide.
            exitAnim.start()
          }

          onPanelTChanged: {
            wrap.syncTopReveal()
            if (wrap.exiting)
              return
            if (panelT >= 0.999) {
              toastWindow.markSettled(String(wrap.key))
              // First / only toast: ensure the top chrome lip is present.
              if (wrap.slot === 0 && toastWindow.flushToFrame
                  && toastWindow.topCornerT < 0.5 && !wrap.risingToTop)
                toastWindow.growTopCorner()
            }
          }

          onYChanged: wrap.syncTopReveal()

          onSlotChanged: {
            if (wrap.exiting)
              return
            if (wrap.prevSlot > 0 && wrap.slot === 0)
              wrap.claimTopCorner()
            wrap.syncTopReveal()
            wrap.prevSlot = wrap.slot
          }

          Timer {
            id: riseTopTimer
            interval: 280
            repeat: false
            onTriggered: {
              wrap.risingToTop = false
              toastWindow.growTopCorner()
            }
          }

          Component.onCompleted: {
            wrap.prevSlot = wrap.slot
            wrap.syncTopReveal()
          }
          Component.onDestruction: {
            toastWindow.clearSettled(String(wrap.key))
            if (wrap.risingToTop)
              wrap.risingToTop = false
            if (!wrap.exiting && (wrap.slot === 0 || wrap.prevSlot === 0)
                && Notifications.toasts.count > 0) {
              // Top toast left without exit anim — drop the chrome lip.
              toastWindow.snapTopCorner(0)
            }
          }

          // Reveal width from the right edge of the frame.
          Item {
            anchors.right: parent.right
            anchors.top: parent.top
            width: Math.max(1, Math.round(toastWindow.toastW * wrap.panelT))
            height: parent.height
            clip: true

            NotificationToast {
              anchors.right: parent.right
              anchors.top: parent.top
              width: toastWindow.toastW
              height: Notifications.toastH
              toastKey: wrap.key
              summary: wrap.summary
              body: wrap.body
              appName: wrap.appName
              at: wrap.at
              enabled: !wrap.exiting
              stackTop: wrap.slot === 0 && !wrap.risingToTop && !wrap.exiting
                         && (toastWindow.topCornerT > 0.95 || !toastWindow.flushToFrame)
              stackBottom: wrap.visualBottom
              // Chrome lip only when flush to the top frame. Under an open
              // Control/notif panel the card stays fully rounded on the top-left.
              topLeftRadius: {
                if (wrap.slot !== 0)
                  return 0
                if (!toastWindow.flushToFrame || wrap.risingToTop)
                  return 16
                // While exiting, keep the sharp join so the fillet rides out with the card.
                return Math.round(16 * (1 - toastWindow.topCornerT))
              }
              topRightRadius: 0
              bottomLeftRadius: wrap.visualBottom ? 16 : 0
              bottomRightRadius: 0
              opacity: 0.85 + 0.15 * wrap.contentT

              onDismissRequested: wrap.beginDismiss()

              Behavior on bottomLeftRadius {
                NumberAnimation {
                  duration: 180
                  easing.type: Easing.OutCubic
                }
              }
            }
          }

          Behavior on y {
            enabled: !wrap.exiting
            NumberAnimation {
              duration: 280
              easing.type: Easing.OutCubic
            }
          }

          ParallelAnimation {
            id: enterAnim
            running: true
            NumberAnimation {
              target: wrap
              property: "panelT"
              from: 0
              to: 1
              duration: 380
              easing.type: Easing.OutCubic
            }
            SequentialAnimation {
              PauseAnimation {
                duration: 30
              }
              NumberAnimation {
                target: wrap
                property: "contentT"
                from: 0
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
              }
            }
          }

          // Slide back into the frame; top fillet tracks panelT (same path as entrance).
          ParallelAnimation {
            id: exitAnim
            NumberAnimation {
              target: wrap
              property: "panelT"
              to: 0
              duration: 320
              easing.type: Easing.InCubic
            }
            NumberAnimation {
              target: wrap
              property: "contentT"
              to: 0
              duration: 200
              easing.type: Easing.InCubic
            }
            onFinished: {
              if (wrap.slot === 0)
                toastWindow.snapTopCorner(0)
              Notifications.dismissToast(wrap.key)
            }
          }
        }
      }
    }
  }
}
