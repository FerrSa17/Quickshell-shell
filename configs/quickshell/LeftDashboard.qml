import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets

// Left overview dashboard (clock, calendar, stats, media).
// Hotkey only: Super+A (qs ipc call dashboard toggle).
Scope {
  id: root

  IpcHandler {
    target: "dashboard"
    function toggle(): void {
      PanelBus.toggleDashboard()
    }
    function open(): void {
      PanelBus.openDashboard()
    }
    function close(): void {
      PanelBus.closeDashboard()
    }
  }

  Variants {
    model: Quickshell.screens

    Scope {
      id: monitorScope
      required property var modelData

      property bool open: false
      property bool edgeHovered: false
      property bool panelHovered: false
      property real panelT: 0
      property real contentT: 0
      property string uptimeText: "up …"
      property real mouseSensitivity: 0
      property string weatherTemp: "—"
      property string weatherDesc: "Weather"
      property string weatherGlyph: "\ue30d"
      property string weatherHumidity: "—"
      property string weatherFeels: "—"
      property string weatherWind: "—"
      property string weatherSunrise: "—"
      property string weatherSunset: "—"
      property string weatherCity: "Санкт-Петербург"
      property string weatherDateLabel: ""
      property bool weatherCardHovered: false
      property bool weatherOverlayHovered: false
      readonly property bool weatherExpanded: weatherCardHovered || weatherOverlayHovered
      property real weatherExpandT: 0
      property bool typingCardHovered: false
      property bool typingOverlayHovered: false
      readonly property bool typingExpanded: typingCardHovered || typingOverlayHovered
      property real typingExpandT: 0
      property date viewDate: new Date()

      ListModel {
        id: forecastModel
      }

      onWeatherExpandedChanged: weatherExpandT = weatherExpanded ? 1 : 0
      Behavior on weatherExpandT {
        NumberAnimation {
          duration: 240
          easing.type: Easing.OutCubic
        }
      }
      onTypingExpandedChanged: typingExpandT = typingExpanded ? 1 : 0
      Behavior on typingExpandT {
        NumberAnimation {
          duration: 240
          easing.type: Easing.OutCubic
        }
      }

      // Hotkey only (Super+A) — frame edge hover does not open.
      readonly property bool drawerActive: panelT > 0.001
      readonly property int panelW: 980
      readonly property int panelHMax: 480
      readonly property int barPad: Theme.barPad
      readonly property int topChrome: barPad + Theme.barHeight + barPad
      readonly property int edgeHit: Theme.frameThickness
      readonly property int hitBandH: 96
      readonly property string userName: Quickshell.env("USER") || "user"

      // Fit inside the wallpaper aperture (below top chrome, inside side/bottom frame).
      readonly property int apertureH: {
        const scr = modelData
        if (!scr)
          return panelHMax
        return Math.max(200, scr.height - topChrome - Theme.frameThickness)
      }
      readonly property int panelH: Math.min(panelHMax, apertureH - 8)

      SystemClock {
        id: clock
        precision: SystemClock.Seconds
      }


      function closeDash() {
        monitorScope.edgeHovered = false
        monitorScope.panelHovered = false
        monitorScope.weatherCardHovered = false
        monitorScope.weatherOverlayHovered = false
        monitorScope.typingCardHovered = false
        monitorScope.typingOverlayHovered = false
        monitorScope.open = false
      }

      Connections {
        target: PanelBus
        function onToggleDashboardRequested() {
          if (!ShellPrefs.panelDashboard)
            return
          const screens = Quickshell.screens
          if (screens && screens.length && monitorScope.modelData !== screens[0])
            return
          if (monitorScope.open)
            monitorScope.closeDash()
          else
            monitorScope.open = true
        }
        function onOpenDashboardRequested() {
          if (!ShellPrefs.panelDashboard)
            return
          const screens = Quickshell.screens
          if (screens && screens.length && monitorScope.modelData !== screens[0])
            return
          monitorScope.open = true
        }
        function onCloseDashboardRequested() {
          monitorScope.closeDash()
        }
      }

      function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate()
      }

      function startOffset(y, m) {
        const d = new Date(y, m, 1).getDay()
        return (d + 6) % 7
      }

      function buildCells() {
        const y = viewDate.getFullYear()
        const m = viewDate.getMonth()
        const dim = daysInMonth(y, m)
        const off = startOffset(y, m)
        const cells = []
        for (let i = 0; i < off; i++)
          cells.push({ day: 0 })
        for (let d = 1; d <= dim; d++)
          cells.push({ day: d })
        while (cells.length % 7 !== 0)
          cells.push({ day: 0 })
        return cells
      }

      function isToday(day) {
        if (!day)
          return false
        const n = clock.date
        return day === n.getDate() && viewDate.getMonth() === n.getMonth() && viewDate.getFullYear() === n.getFullYear()
      }

      function wmoGlyph(code) {
        // JetBrainsMono NF ships Weather Icons (E3xx), not all FA5 weather glyphs.
        const c = Number(code)
        if (c === 0)
          return "\ue30d" // day-sunny
        if (c === 1)
          return "\ue302" // day-cloudy
        if (c === 2)
          return "\ue302"
        if (c === 3)
          return "\ue312" // cloudy
        if (c === 45 || c === 48)
          return "\ue313" // fog
        if (c >= 51 && c <= 67)
          return "\ue318" // rain
        if (c >= 71 && c <= 77)
          return "\ue31a" // snow
        if (c >= 80 && c <= 82)
          return "\ue318"
        if (c >= 85 && c <= 86)
          return "\ue31a"
        if (c >= 95)
          return "\ue31d" // thunderstorm
        return "\ue312"
      }

      function wmoLabel(code) {
        const c = Number(code)
        if (c === 0)
          return "Ясно"
        if (c === 1)
          return "Преим. ясно"
        if (c === 2)
          return "Переменная"
        if (c === 3)
          return "Пасмурно"
        if (c === 45 || c === 48)
          return "Туман"
        if (c >= 51 && c <= 55)
          return "Морось"
        if (c >= 56 && c <= 57)
          return "Ледяная морось"
        if (c >= 61 && c <= 65)
          return "Дождь"
        if (c >= 66 && c <= 67)
          return "Ледяной дождь"
        if (c >= 71 && c <= 75)
          return "Снег"
        if (c === 77)
          return "Снежные зёрна"
        if (c >= 80 && c <= 82)
          return "Ливень"
        if (c >= 85 && c <= 86)
          return "Снегопад"
        if (c >= 95)
          return "Гроза"
        return "Погода"
      }

      function fmtHm(iso) {
        const m = String(iso || "").match(/T(\d{2}:\d{2})/)
        return m ? m[1] : "—"
      }

      function applyWeatherJson(raw) {
        try {
          const d = JSON.parse(raw)
          const cur = d.current || ({})
          const daily = d.daily || ({})
          const code = cur.weather_code
          monitorScope.weatherTemp = (cur.temperature_2m != null)
              ? (Math.round(cur.temperature_2m) + "°C")
              : "—"
          monitorScope.weatherDesc = monitorScope.wmoLabel(code)
          monitorScope.weatherGlyph = monitorScope.wmoGlyph(code)
          monitorScope.weatherHumidity = (cur.relative_humidity_2m != null)
              ? (cur.relative_humidity_2m + "%")
              : "—"
          monitorScope.weatherFeels = (cur.apparent_temperature != null)
              ? (Math.round(cur.apparent_temperature) + "°C")
              : "—"
          monitorScope.weatherWind = (cur.wind_speed_10m != null)
              ? (Number(cur.wind_speed_10m).toFixed(1) + " km/h")
              : "—"
          const sunr = (daily.sunrise && daily.sunrise[0]) || ""
          const suns = (daily.sunset && daily.sunset[0]) || ""
          monitorScope.weatherSunrise = monitorScope.fmtHm(sunr)
          monitorScope.weatherSunset = monitorScope.fmtHm(suns)

          const loc = Qt.locale("ru_RU")
          const now = clock.date
          monitorScope.weatherDateLabel = loc.dayName(now.getDay(), Locale.LongFormat)
              + ", " + now.toLocaleDateString(loc, "d MMMM")

          forecastModel.clear()
          const times = daily.time || []
          const codes = daily.weather_code || []
          const maxes = daily.temperature_2m_max || []
          const mins = daily.temperature_2m_min || []
          const n = Math.min(7, times.length)
          for (let i = 0; i < n; i++) {
            const dt = new Date(times[i] + "T12:00:00")
            const dayLabel = i === 0
                ? "Сегодня"
                : loc.dayName(dt.getDay(), Locale.ShortFormat)
            const dateLabel = dt.toLocaleDateString(loc, "d MMM")
            const hi = maxes[i] != null ? Number(maxes[i]).toFixed(1) : "—"
            const lo = mins[i] != null ? Number(mins[i]).toFixed(1) : "—"
            forecastModel.append({
              dayLabel: dayLabel,
              dateLabel: dateLabel,
              glyph: monitorScope.wmoGlyph(codes[i]),
              range: hi + "° / " + lo + "°"
            })
          }
        } catch (e) {
          monitorScope.weatherTemp = "—"
          monitorScope.weatherDesc = "Offline"
          monitorScope.weatherGlyph = "\ue312"
          forecastModel.clear()
        }
      }

      function refreshMeta() {
        uptimeProc.running = true
        weatherProc.running = true
        sensProc.running = true
      }

      function setMouseSensitivity(v) {
        const next = Math.max(-1, Math.min(1, v))
        monitorScope.mouseSensitivity = next
        const n = next.toFixed(2)
        Quickshell.execDetached([
          "hyprctl", "eval",
          "hl.config({ input = { sensitivity = " + n + " } })"
        ])
      }

      Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p 2>/dev/null | sed 's/^up //'"]
        stdout: StdioCollector {
          onStreamFinished: {
            const t = text.trim()
            monitorScope.uptimeText = t.length ? ("up " + t) : "up …"
          }
        }
      }

      Process {
        id: sensProc
        command: ["hyprctl", "getoption", "input:sensitivity", "-j"]
        stdout: StdioCollector {
          onStreamFinished: {
            try {
              const d = JSON.parse(text.trim())
              if (typeof d.float === "number")
                monitorScope.mouseSensitivity = Math.max(-1, Math.min(1, d.float))
            } catch (e) {}
          }
        }
      }

      Process {
        id: weatherProc
        command: [
          "curl", "-fsS", "--max-time", "5",
          "https://api.open-meteo.com/v1/forecast?latitude=59.93&longitude=30.31&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=Europe%2FMoscow&forecast_days=7"
        ]
        stdout: StdioCollector {
          onStreamFinished: {
            const raw = text.trim()
            if (!raw.length) {
              monitorScope.weatherTemp = "—"
              monitorScope.weatherDesc = "Offline"
              return
            }
            monitorScope.applyWeatherJson(raw)
          }
        }
      }

      Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: monitorScope.refreshMeta()
      }

      onOpenChanged: {
        openAnim.stop()
        closeAnim.stop()
        if (open) {
          monitorScope.viewDate = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
          monitorScope.refreshMeta()
          openAnim.start()
          Qt.callLater(() => panel.forceActiveFocus())
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
          target: monitorScope
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
            target: monitorScope
            property: "contentT"
            to: 1
            duration: 260
            easing.type: Easing.OutCubic
          }
        }
      }

      ParallelAnimation {
        id: closeAnim
        NumberAnimation {
          target: monitorScope
          property: "panelT"
          to: 0
          duration: 240
          easing.type: Easing.InCubic
        }
        NumberAnimation {
          target: monitorScope
          property: "contentT"
          to: 0
          duration: 140
          easing.type: Easing.InCubic
        }
      }

      // Mid-left hit strip — disabled; open via Super+A only.
      PanelWindow {
        screen: monitorScope.modelData
        color: "transparent"
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        visible: false
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
          top: true
          bottom: true
          left: true
        }

        margins {
          top: screen ? Math.max(0, Math.round((screen.height - monitorScope.hitBandH) / 2)) : 0
          bottom: screen ? Math.max(0, Math.round((screen.height - monitorScope.hitBandH) / 2)) : 0
          left: 0
        }

        implicitWidth: monitorScope.edgeHit

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
          onContainsMouseChanged: monitorScope.edgeHovered = containsMouse
        }
      }

      PanelWindow {
        id: drawer
        screen: monitorScope.modelData
        visible: ShellPrefs.panelDashboard && monitorScope.drawerActive
        color: "transparent"
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.keyboardFocus: monitorScope.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors {
          top: true
          bottom: true
          left: true
        }

        // Pin under top chrome; sit on the aperture's left edge so outer
        // flares can wrap chrome away from the dashboard (up / down).
        margins {
          top: monitorScope.topChrome
          bottom: Theme.frameThickness
          left: Theme.frameThickness
        }

        implicitWidth: monitorScope.panelW

        Shortcut {
          sequence: "Escape"
          enabled: monitorScope.open
          onActivated: monitorScope.closeDash()
        }

        Item {
          anchors.fill: parent
          clip: false

          // Chrome flares that peel AWAY from the dashboard:
          // top flare goes up, bottom flare goes down (opposite directions).
          component OuterFillet: Item {
            id: fillet
            property bool topSide: true
            property int s: 32
            width: s
            height: s
            // Stay solid through open/close; drop only when the panel is gone.
            opacity: 1
            visible: monitorScope.panelT > 0.001
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
                // Cut a quarter open toward the panel so chrome flares
                // away from the dashboard (up on top, down on bottom).
                ctx.globalCompositeOperation = "destination-out"
                ctx.beginPath()
                if (fillet.topSide)
                  ctx.arc(s, 0, s, 0, Math.PI * 2) // X restored, then mirrored on Y
                else
                  ctx.arc(s, s, s, 0, Math.PI * 2)
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
                target: monitorScope
                function onPanelTChanged() {
                  if (monitorScope.panelT > 0.001)
                    filletCanvas.requestPaint()
                }
              }
            }
          }

          OuterFillet {
            topSide: true
            anchors.left: panel.left
            anchors.bottom: panel.top
          }

          OuterFillet {
            topSide: false
            anchors.left: panel.left
            anchors.top: panel.bottom
          }

          ClippingRectangle {
            id: panel
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Math.max(1, Math.round(monitorScope.panelW * monitorScope.panelT))
            height: monitorScope.panelH
            focus: true
            color: Theme.barBg
            antialiasing: true
            // Sharp left edge so the outer flares own the join; round free edge.
            radius: 0
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: 16
            bottomRightRadius: 16

            HoverHandler {
              onHoveredChanged: monitorScope.panelHovered = hovered
            }

            Keys.onEscapePressed: event => {
              monitorScope.closeDash()
              event.accepted = true
            }

            // Full-size content, revealed by width clip from the left.
            Item {
              anchors.left: parent.left
              anchors.top: parent.top
              width: monitorScope.panelW
              height: monitorScope.panelH
              opacity: 0.35 + 0.65 * monitorScope.contentT

              component DashCard: Rectangle {
                radius: 18
                color: Theme.well
              }

              component MiniRing: Item {
                id: mring
                property real value: 0
                property color accent: Theme.sapphire
                property string glyph: ""

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1

                readonly property int side: Math.max(40, Math.floor(Math.min(width, height)))
                readonly property real stroke: Math.max(6, side * 0.09)

                Canvas {
                  id: c
                  anchors.centerIn: parent
                  width: mring.side
                  height: mring.side
                  antialiasing: true
                  onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2
                    const cy = height / 2
                    const r = Math.min(width, height) / 2 - mring.stroke
                    ctx.lineWidth = mring.stroke
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.strokeStyle = Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 1)
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.strokeStyle = mring.accent
                    const span = Math.max(0, Math.min(1, mring.value / 100)) * Math.PI * 2
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + span)
                    ctx.stroke()
                  }
                }
                onValueChanged: c.requestPaint()
                onAccentChanged: c.requestPaint()
                onSideChanged: c.requestPaint()
                onStrokeChanged: c.requestPaint()
                Component.onCompleted: c.requestPaint()
                Connections {
                  target: Theme
                  function onPaletteRevChanged() {
                    c.requestPaint()
                  }
                }

                Text {
                  anchors.centerIn: parent
                  text: mring.glyph
                  color: Theme.text
                  font.family: Theme.fontFamily
                  font.pixelSize: Math.max(16, Math.round(mring.side * 0.24))
                }
              }

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // —— Top row: weather + identity ——
                RowLayout {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 84
                  Layout.maximumHeight: 84
                  spacing: 12

                  DashCard {
                    id: weatherCard
                    Layout.preferredWidth: 150
                    Layout.fillHeight: true

                    HoverHandler {
                      onHoveredChanged: monitorScope.weatherCardHovered = hovered
                    }

                    Row {
                      anchors.centerIn: parent
                      spacing: 10

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: monitorScope.weatherGlyph
                        color: Theme.peach
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                      }

                      Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                          text: monitorScope.weatherTemp
                          color: Theme.text
                          font.family: Theme.fontFamily
                          font.pixelSize: 18
                          font.bold: true
                        }

                        Text {
                          text: monitorScope.weatherDesc
                          color: Theme.muted
                          font.family: Theme.fontFamily
                          font.pixelSize: 11
                          elide: Text.ElideRight
                          width: 90
                        }

                        Text {
                          text: monitorScope.weatherCity
                          color: Theme.muted
                          font.family: Theme.fontFamily
                          font.pixelSize: 9
                          elide: Text.ElideRight
                          width: 90
                        }
                      }
                    }
                  }

                  DashCard {
                    Layout.preferredWidth: 168
                    Layout.maximumWidth: 168
                    Layout.fillWidth: false
                    Layout.fillHeight: true

                    Row {
                      anchors.fill: parent
                      anchors.margins: 10
                      spacing: 10

                      Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: Theme.notifBlue
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          anchors.centerIn: parent
                          text: monitorScope.userName.charAt(0).toUpperCase()
                          color: Theme.onNotifBadge
                          font.family: Theme.fontFamily
                          font.pixelSize: 16
                          font.bold: true
                        }
                      }

                      Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 50
                        spacing: 4

                        Row {
                          spacing: 6

                          Rectangle {
                            width: Math.min(tag.implicitWidth + 12, parent.parent.width - 34)
                            height: 20
                            radius: 10
                            color: Theme.pill
                            clip: true

                            Text {
                              id: tag
                              anchors.centerIn: parent
                              text: "# Hyprland"
                              color: Theme.sapphire
                              font.family: Theme.fontFamily
                              font.pixelSize: 10
                              font.bold: true
                            }
                          }

                          Rectangle {
                            width: 24
                            height: 20
                            radius: 10
                            color: Theme.notifBlue

                            Text {
                              anchors.centerIn: parent
                              text: "01"
                              color: Theme.onNotifBadge
                              font.family: Theme.fontFamily
                              font.pixelSize: 9
                              font.bold: true
                            }
                          }
                        }

                        Text {
                          width: parent.width
                          text: monitorScope.uptimeText
                          color: Theme.muted
                          font.family: Theme.fontFamily
                          font.pixelSize: 10
                          elide: Text.ElideRight
                        }
                      }
                    }
                  }

                  DashCard {
                    id: typingCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 200
                    Layout.minimumWidth: 160

                    HoverHandler {
                      onHoveredChanged: monitorScope.typingCardHovered = hovered
                    }

                    Column {
                      anchors.centerIn: parent
                      spacing: 2

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Typing Speed"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                      }

                      Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Text {
                          text: Math.round(TypingStats.currentWpm)
                          color: Theme.text
                          font.family: Theme.fontFamily
                          font.pixelSize: 22
                          font.bold: true
                        }

                        Text {
                          anchors.bottom: parent.bottom
                          anchors.bottomMargin: 3
                          text: "WPM"
                          color: Theme.sapphire
                          font.family: Theme.fontFamily
                          font.pixelSize: 11
                          font.bold: true
                        }
                      }

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Today avg " + Math.round(TypingStats.todayWpm)
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                      }
                    }
                  }

                  DashCard {
                    Layout.preferredWidth: 280
                    Layout.maximumWidth: 280
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignRight

                    Column {
                      anchors.fill: parent
                      anchors.margins: 12
                      spacing: 8

                      Item {
                        width: parent.width
                        height: Math.max(sensTitle.implicitHeight, sensResetBtn.height)

                        Text {
                          id: sensTitle
                          anchors.left: parent.left
                          anchors.verticalCenter: parent.verticalCenter
                          text: "Mouse Sensitivity"
                          color: Theme.text
                          font.family: Theme.fontFamily
                          font.pixelSize: 12
                          font.bold: true
                        }

                        Text {
                          id: sensValue
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          text: {
                            const v = Math.round(monitorScope.mouseSensitivity * 10) / 10
                            if (Math.abs(v) < 0.05)
                              return "0.0"
                            return (v > 0 ? "+" : "") + v.toFixed(1)
                          }
                          color: Theme.sapphire
                          font.family: Theme.fontFamily
                          font.pixelSize: 12
                          font.bold: true
                        }

                        Rectangle {
                          id: sensResetBtn
                          anchors.right: sensValue.left
                          anchors.rightMargin: 8
                          anchors.verticalCenter: parent.verticalCenter
                          width: sensResetLabel.implicitWidth + 12
                          height: 20
                          radius: 8
                          color: Theme.pill

                          Text {
                            id: sensResetLabel
                            anchors.centerIn: parent
                            text: "Reset"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                          }

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: monitorScope.setMouseSensitivity(0)
                            onContainsMouseChanged: {
                              sensResetBtn.color = containsMouse ? Theme.surface : Theme.pill
                              sensResetLabel.color = containsMouse ? Theme.text : Theme.subtext
                            }
                            hoverEnabled: true
                          }
                        }
                      }

                      Item {
                        id: sensTrackWrap
                        width: parent.width
                        height: 22

                        readonly property real t: (monitorScope.mouseSensitivity + 1) / 2
                        readonly property real thumbX: Math.max(0, Math.min(width, width * t))
                        readonly property real midX: width / 2

                        Rectangle {
                          anchors.verticalCenter: parent.verticalCenter
                          width: parent.width
                          height: 10
                          radius: 5
                          color: Theme.pill
                        }

                        Rectangle {
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.verticalCenter: parent.verticalCenter
                          width: 2
                          height: 14
                          radius: 1
                          color: Theme.muted
                        }

                        Rectangle {
                          anchors.verticalCenter: parent.verticalCenter
                          x: Math.min(sensTrackWrap.midX, sensTrackWrap.thumbX)
                          width: Math.abs(sensTrackWrap.thumbX - sensTrackWrap.midX)
                          height: 10
                          radius: 5
                          color: Theme.sapphire
                        }

                        Rectangle {
                          anchors.verticalCenter: parent.verticalCenter
                          x: sensTrackWrap.thumbX - width / 2
                          width: 3
                          height: 14
                          radius: 1.5
                          color: Theme.text
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          function apply(mx) {
                            const t = Math.max(0, Math.min(1, mx / Math.max(1, sensTrackWrap.width)))
                            monitorScope.setMouseSensitivity(t * 2 - 1)
                          }
                          onPressed: event => apply(event.x)
                          onPositionChanged: event => {
                            if (pressed)
                              apply(event.x)
                          }
                        }
                      }
                    }
                  }
                }

                // —— Main row ——
                RowLayout {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  spacing: 12

                  // Vertical clock
                  DashCard {
                    Layout.preferredWidth: 88
                    Layout.fillHeight: true

                    Column {
                      anchors.centerIn: parent
                      spacing: 6

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "hh")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 36
                        font.bold: true
                      }

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "···"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                      }

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "mm")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 36
                        font.bold: true
                      }

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "AP")
                        color: Theme.sapphire
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                      }
                    }
                  }

                  // Calendar — stretch day grid to fill the card
                  DashCard {
                    id: calCard
                    Layout.fillWidth: true
                    Layout.preferredWidth: 280
                    Layout.minimumWidth: 220
                    Layout.maximumWidth: 360
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 12
                      spacing: 8

                      Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().standaloneMonthName(monitorScope.viewDate.getMonth()) + " " + monitorScope.viewDate.getFullYear()
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                      }

                      Row {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        Repeater {
                          model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                          delegate: Text {
                            required property string modelData
                            width: parent.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                          }
                        }
                      }

                      Grid {
                        id: dayGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 0

                        readonly property int rowCount: Math.max(1, Math.ceil(monitorScope.buildCells().length / 7))
                        readonly property real cellW: width / 7
                        readonly property real cellH: height / rowCount
                        readonly property real daySize: Math.max(22, Math.min(cellW, cellH) - 4)

                        Repeater {
                          model: monitorScope.buildCells()
                          delegate: Item {
                            required property var modelData
                            width: dayGrid.cellW
                            height: dayGrid.cellH

                            Rectangle {
                              anchors.centerIn: parent
                              width: dayGrid.daySize
                              height: dayGrid.daySize
                              radius: width / 2
                              color: monitorScope.isToday(modelData.day) ? Theme.notifBlue : "transparent"

                              Text {
                                anchors.centerIn: parent
                                text: modelData.day > 0 ? ("" + modelData.day) : ""
                                color: monitorScope.isToday(modelData.day) ? Theme.onNotifBadge : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(11, Math.round(dayGrid.daySize * 0.42))
                                font.bold: monitorScope.isToday(modelData.day)
                              }
                            }
                          }
                        }
                      }
                    }
                  }

                  // Rings — stretch to fill the card column
                  DashCard {
                    Layout.preferredWidth: 120
                    Layout.minimumWidth: 110
                    Layout.maximumWidth: 140
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 10
                      spacing: 6

                      MiniRing {
                        value: Stats.cpuSmooth
                        accent: Theme.maroon
                        glyph: "\uf2db"
                      }

                      MiniRing {
                        value: Stats.memPercent
                        accent: Theme.peach
                        glyph: "\uefc5"
                      }

                      MiniRing {
                        value: Stats.diskPercent
                        accent: Theme.sapphire
                        glyph: "\uf0a0"
                      }
                    }
                  }

                  // Media player — art + visualizer | meta, wave progress, controls
                  DashCard {
                    id: mediaCard
                    Layout.fillWidth: true
                    Layout.preferredWidth: 340
                    Layout.minimumWidth: 280
                    Layout.fillHeight: true
                    clip: true

                    property var player: null
                    property real lengthSec: 0
                    property real positionSec: 0
                    property real vizTick: 0
                    property int artRev: 0

                    readonly property bool playing: !!(player && player.isPlaying)
                    readonly property real progress: lengthSec > 0
                      ? Math.max(0, Math.min(1, positionSec / lengthSec))
                      : 0
                    readonly property int artOuter: Math.min(150, Math.max(96, Math.floor(height - 28)))
                    readonly property int artInner: Math.round(artOuter * 0.72)

                    // Normalize MPRIS art URLs (file paths, http, data).
                    readonly property string artSource: {
                      const _ = artRev
                      if (!player)
                        return ""
                      const u = (player.trackArtUrl || "").trim()
                      if (!u.length)
                        return ""
                      if (u.indexOf("http://") === 0 || u.indexOf("https://") === 0
                          || u.indexOf("file://") === 0 || u.indexOf("data:") === 0)
                        return u
                      if (u.charAt(0) === "/")
                        return "file://" + u
                      return u
                    }

                    readonly property string appIconSource: {
                      if (!player)
                        return ""
                      const de = (player.desktopEntry || "").trim()
                      if (de.length) {
                        const p = Quickshell.iconPath(de, "")
                        if (p && ("" + p).length)
                          return p
                      }
                      const id = (player.identity || player.dbusName || "").toLowerCase()
                      if (id.indexOf("firefox") >= 0)
                        return Quickshell.iconPath("firefox", "applications-multimedia")
                      if (id.indexOf("spotify") >= 0)
                        return Quickshell.iconPath("spotify", "applications-multimedia")
                      if (id.indexOf("chromium") >= 0 || id.indexOf("chrome") >= 0)
                        return Quickshell.iconPath("chromium", "applications-multimedia")
                      if (id.indexOf("mpv") >= 0)
                        return Quickshell.iconPath("mpv", "applications-multimedia")
                      if (id.indexOf("vlc") >= 0)
                        return Quickshell.iconPath("vlc", "applications-multimedia")
                      return Quickshell.iconPath("audio-x-generic", "applications-multimedia")
                    }

                    readonly property bool artReady: artImage.status === Image.Ready && artSource.length > 0

                    function toSeconds(v) {
                      const n = Number(v)
                      if (!isFinite(n) || n < 0)
                        return 0
                      if (n > 86400)
                        return n / 1000000
                      return n
                    }

                    // Quickshell mirrors length←position when unsupported → fake 100%.
                    function resolvedLengthSec(pos) {
                      if (!player)
                        return 0
                      if (player.lengthSupported === false)
                        return 0
                      const len = toSeconds(player.length)
                      if (!(len > 0))
                        return 0
                      return len
                    }

                    function fmtTime(sec) {
                      const s = Math.max(0, Math.floor(sec))
                      const m = Math.floor(s / 60)
                      const r = s % 60
                      return m + ":" + (r < 10 ? "0" : "") + r
                    }

                    function refreshPlayer() {
                      const list = Mpris.players.values
                      let fallback = null
                      for (let i = 0; i < list.length; i++) {
                        const p = list[i]
                        if (!p)
                          continue
                        if (p.isPlaying) {
                          if (mediaCard.player !== p) {
                            mediaCard.player = p
                            mediaCard.artRev++
                          }
                          mediaCard.pollPosition()
                          return
                        }
                        if (!fallback)
                          fallback = p
                      }
                      if (fallback) {
                        if (mediaCard.player !== fallback) {
                          mediaCard.player = fallback
                          mediaCard.artRev++
                        }
                        mediaCard.pollPosition()
                        return
                      }
                      mediaCard.player = null
                      mediaCard.lengthSec = 0
                      mediaCard.positionSec = 0
                    }

                    function pollPosition() {
                      if (!player)
                        return
                      const pos = toSeconds(player.position)
                      lengthSec = resolvedLengthSec(pos)
                      positionSec = pos
                    }

                    function seekToSec(sec) {
                      if (!player)
                        return
                      const t = Math.max(0, lengthSec > 0 ? Math.min(lengthSec, sec) : Math.max(0, sec))
                      // Quickshell MprisPlayer.position is seconds (writable when canSeek).
                      try {
                        player.position = t
                      } catch (e) {
                        try {
                          if (player.seek)
                            player.seek(t - positionSec)
                        } catch (e2) {}
                      }
                      positionSec = t
                      Qt.callLater(() => mediaCard.pollPosition())
                    }

                    function seekRatio(r) {
                      if (!player || lengthSec <= 0)
                        return
                      seekToSec(Math.max(0, Math.min(1, r)) * lengthSec)
                    }

                    // Restart current track from the beginning.
                    function restartTrack() {
                      if (!player)
                        return
                      seekToSec(0)
                      if (!player.isPlaying) {
                        try {
                          player.play()
                        } catch (e) {
                          try {
                            player.togglePlaying()
                          } catch (e2) {}
                        }
                      }
                    }

                    function goPrevious() {
                      if (!player)
                        return
                      // Mid-track: start over (common player UX).
                      if (positionSec > 2) {
                        restartTrack()
                        return
                      }
                      try {
                        player.previous()
                      } catch (e) {}
                    }

                    Component.onCompleted: refreshPlayer()
                    Connections {
                      target: Mpris.players
                      function onValuesChanged() {
                        mediaCard.refreshPlayer()
                      }
                    }
                    Connections {
                      target: mediaCard.player
                      function onIsPlayingChanged() {
                        mediaCard.pollPosition()
                      }
                      function onLengthChanged() {
                        mediaCard.pollPosition()
                      }
                      function onLengthSupportedChanged() {
                        mediaCard.pollPosition()
                      }
                      function onTrackArtUrlChanged() {
                        mediaCard.artRev++
                      }
                      function onPostTrackChanged() {
                        // Art often arrives slightly after track change.
                        mediaCard.artRev++
                        mediaCard.pollPosition()
                      }
                      function onTrackChanged() {
                        mediaCard.artRev++
                      }
                    }

                    Timer {
                      interval: 900
                      running: monitorScope.open
                      repeat: true
                      onTriggered: mediaCard.refreshPlayer()
                    }
                    Timer {
                      interval: 250
                      running: monitorScope.open && mediaCard.playing
                      repeat: true
                      triggeredOnStart: true
                      onTriggered: mediaCard.pollPosition()
                    }
                    Timer {
                      interval: 80
                      running: monitorScope.open && mediaCard.playing
                      repeat: true
                      onTriggered: {
                        mediaCard.vizTick += 0.18
                        vizCanvas.requestPaint()
                      }
                    }

                    // Soft decorative blobs (theme-tinted)
                    Rectangle {
                      width: 90
                      height: 70
                      radius: 35
                      rotation: -18
                      color: Qt.rgba(Theme.sapphire.r, Theme.sapphire.g, Theme.sapphire.b, 0.14)
                      anchors.right: parent.right
                      anchors.rightMargin: 24
                      anchors.top: parent.top
                      anchors.topMargin: 18
                    }
                    Rectangle {
                      width: 70
                      height: 56
                      radius: 28
                      rotation: 22
                      color: Qt.rgba(Theme.peach.r, Theme.peach.g, Theme.peach.b, 0.12)
                      anchors.right: parent.right
                      anchors.rightMargin: 90
                      anchors.bottom: parent.bottom
                      anchors.bottomMargin: 28
                    }

                    Row {
                      anchors.fill: parent
                      anchors.margins: 14
                      spacing: 14

                      // —— Art + radial visualizer ——
                      Item {
                        width: mediaCard.artOuter
                        height: mediaCard.artOuter
                        anchors.verticalCenter: parent.verticalCenter

                        Canvas {
                          id: vizCanvas
                          anchors.fill: parent
                          antialiasing: true
                          onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const cx = width / 2
                            const cy = height / 2
                            const inner = mediaCard.artInner / 2 + 4
                            const bars = 48
                            const playing = mediaCard.playing
                            const tick = mediaCard.vizTick
                            for (let i = 0; i < bars; i++) {
                              const a = (i / bars) * Math.PI * 2 - Math.PI / 2
                              let amp = 0.35
                              if (playing) {
                                amp = 0.25 + 0.75 * Math.abs(Math.sin(tick + i * 0.55))
                                amp *= 0.55 + 0.45 * Math.abs(Math.sin(tick * 0.7 + i * 0.2))
                              }
                              const len = 3 + amp * Math.max(6, (width - mediaCard.artInner) / 2 - 6)
                              const x0 = cx + Math.cos(a) * inner
                              const y0 = cy + Math.sin(a) * inner
                              const x1 = cx + Math.cos(a) * (inner + len)
                              const y1 = cy + Math.sin(a) * (inner + len)
                              ctx.beginPath()
                              ctx.strokeStyle = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, playing ? 0.85 : 0.28)
                              ctx.lineWidth = 2
                              ctx.lineCap = "round"
                              ctx.moveTo(x0, y0)
                              ctx.lineTo(x1, y1)
                              ctx.stroke()
                            }
                          }
                          Component.onCompleted: requestPaint()
                          Connections {
                            target: Theme
                            function onPaletteRevChanged() {
                              vizCanvas.requestPaint()
                            }
                          }
                        }

                        ClippingRectangle {
                          anchors.centerIn: parent
                          width: mediaCard.artInner
                          height: mediaCard.artInner
                          radius: width / 2
                          color: Theme.pill
                          antialiasing: true

                          Image {
                            id: artImage
                            anchors.fill: parent
                            source: mediaCard.artSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            // Bust stale cache when the same player swaps covers.
                            sourceSize.width: mediaCard.artInner * 2
                            sourceSize.height: mediaCard.artInner * 2
                          }

                          // App / generic icon when MPRIS has no cover (e.g. Firefox).
                          IconImage {
                            anchors.centerIn: parent
                            width: parent.width * 0.52
                            height: width
                            visible: !mediaCard.artReady
                            source: mediaCard.appIconSource
                          }

                          Text {
                            anchors.centerIn: parent
                            visible: !mediaCard.artReady && !(mediaCard.appIconSource && ("" + mediaCard.appIconSource).length)
                            text: "\uf001"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(mediaCard.artInner * 0.28)
                          }
                        }
                      }

                      // —— Meta + progress + controls ——
                      Column {
                        width: Math.max(120, parent.width - mediaCard.artOuter - 14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Column {
                          width: parent.width
                          spacing: 2

                          Text {
                            width: parent.width
                            text: {
                              if (!mediaCard.player)
                                return "Not playing"
                              const t = (mediaCard.player.trackTitle || "").trim()
                              return t.length ? t : (mediaCard.player.identity || "Playing")
                            }
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                          }

                          Text {
                            width: parent.width
                            text: mediaCard.player
                                    ? ((mediaCard.player.trackArtist || "").trim() || "Unknown artist")
                                    : "Open a player"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                          }

                          Text {
                            width: parent.width
                            text: mediaCard.player
                                    ? ((mediaCard.player.trackAlbum || "").trim() || "—")
                                    : ""
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            visible: text.length > 0
                          }
                        }

                        Column {
                          width: parent.width
                          spacing: 4

                          Row {
                            width: parent.width
                            Text {
                              text: mediaCard.fmtTime(mediaCard.positionSec)
                              color: Theme.muted
                              font.family: Theme.fontFamily
                              font.pixelSize: 10
                            }
                            Item {
                              width: parent.width - 72
                              height: 1
                            }
                            Text {
                              text: mediaCard.lengthSec > 0
                                      ? mediaCard.fmtTime(mediaCard.lengthSec)
                                      : "—"
                              color: Theme.muted
                              font.family: Theme.fontFamily
                              font.pixelSize: 10
                            }
                          }

                          Item {
                            id: seekTrack
                            width: parent.width
                            height: 18

                            Canvas {
                              id: waveCanvas
                              anchors.fill: parent
                              antialiasing: true
                              onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                const h = height
                                const mid = h / 2
                                const w = width
                                const known = mediaCard.lengthSec > 0
                                const p = known ? mediaCard.progress : 0
                                const cut = Math.max(0, Math.min(w, w * p))

                                // Full/remaining solid track
                                ctx.beginPath()
                                ctx.strokeStyle = Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, known ? 1 : 0.55)
                                ctx.lineWidth = 5
                                ctx.lineCap = "round"
                                ctx.moveTo(known ? cut : 0, mid)
                                ctx.lineTo(w, mid)
                                ctx.stroke()

                                if (!known)
                                  return

                                // Played wavy segment
                                if (cut > 2) {
                                  ctx.beginPath()
                                  ctx.strokeStyle = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.9)
                                  ctx.lineWidth = 2.2
                                  ctx.lineCap = "round"
                                  ctx.lineJoin = "round"
                                  const amp = 4
                                  const step = 3
                                  ctx.moveTo(0, mid)
                                  for (let x = 0; x <= cut; x += step) {
                                    const y = mid + Math.sin(x * 0.35) * amp
                                    ctx.lineTo(x, y)
                                  }
                                  ctx.stroke()
                                }

                                // Playhead — vertical stick slider
                                const stickH = Math.min(h - 2, 14)
                                const stickW = 3
                                ctx.beginPath()
                                ctx.fillStyle = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 1)
                                const sx = cut - stickW / 2
                                const sy = mid - stickH / 2
                                const r = 1.5
                                ctx.moveTo(sx + r, sy)
                                ctx.lineTo(sx + stickW - r, sy)
                                ctx.quadraticCurveTo(sx + stickW, sy, sx + stickW, sy + r)
                                ctx.lineTo(sx + stickW, sy + stickH - r)
                                ctx.quadraticCurveTo(sx + stickW, sy + stickH, sx + stickW - r, sy + stickH)
                                ctx.lineTo(sx + r, sy + stickH)
                                ctx.quadraticCurveTo(sx, sy + stickH, sx, sy + stickH - r)
                                ctx.lineTo(sx, sy + r)
                                ctx.quadraticCurveTo(sx, sy, sx + r, sy)
                                ctx.fill()
                              }
                              Connections {
                                target: mediaCard
                                function onProgressChanged() {
                                  waveCanvas.requestPaint()
                                }
                                function onPositionSecChanged() {
                                  waveCanvas.requestPaint()
                                }
                                function onLengthSecChanged() {
                                  waveCanvas.requestPaint()
                                }
                              }
                              Connections {
                                target: Theme
                                function onPaletteRevChanged() {
                                  waveCanvas.requestPaint()
                                }
                              }
                              Component.onCompleted: requestPaint()
                            }

                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              enabled: !!mediaCard.player && mediaCard.lengthSec > 0
                              onClicked: event => mediaCard.seekRatio(event.x / width)
                              onPositionChanged: event => {
                                if (pressed)
                                  mediaCard.seekRatio(event.x / width)
                              }
                            }
                          }
                        }

                        Row {
                          anchors.horizontalCenter: parent.horizontalCenter
                          spacing: 8

                          // Prev
                          Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Theme.surface
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              anchors.centerIn: parent
                              text: "\uf048"
                              color: Theme.subtext
                              font.family: Theme.fontFamily
                              font.pixelSize: 13
                            }
                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              enabled: !!mediaCard.player
                              onClicked: mediaCard.goPrevious()
                            }
                          }

                          // Play / Pause
                          Rectangle {
                            width: 54
                            height: 36
                            radius: 12
                            color: Theme.notifBlue
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              anchors.centerIn: parent
                              text: mediaCard.playing ? "\uf04c" : "\uf04b"
                              color: Theme.onNotifBadge
                              font.family: Theme.fontFamily
                              font.pixelSize: 14
                            }
                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              enabled: !!mediaCard.player
                              onClicked: mediaCard.player && mediaCard.player.togglePlaying()
                            }
                          }

                          // Next
                          Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Theme.surface
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                              anchors.centerIn: parent
                              text: "\uf051"
                              color: Theme.subtext
                              font.family: Theme.fontFamily
                              font.pixelSize: 13
                            }
                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              enabled: !!mediaCard.player
                              onClicked: mediaCard.player && mediaCard.player.next()
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Weather expand overlay — covers the dashboard content on hover.
              Rectangle {
                id: weatherOverlay
                anchors.fill: parent
                anchors.margins: 16
                z: 50
                radius: 18
                color: Theme.barBg
                opacity: monitorScope.weatherExpandT
                visible: monitorScope.weatherExpandT > 0.01
                scale: 0.98 + 0.02 * monitorScope.weatherExpandT
                transformOrigin: Item.TopLeft
                clip: true

                HoverHandler {
                  onHoveredChanged: monitorScope.weatherOverlayHovered = hovered
                }

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 18
                  spacing: 14

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Column {
                      Layout.fillWidth: true
                      spacing: 4

                      Text {
                        text: monitorScope.weatherCity
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                      }

                      Text {
                        text: monitorScope.weatherDateLabel
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                      }
                    }

                    Column {
                      spacing: 8

                      Row {
                        spacing: 8
                        anchors.right: parent.right

                        Text {
                          text: "\uf185"
                          color: Theme.peach
                          font.family: Theme.fontFamily
                          font.pixelSize: 14
                        }

                        Text {
                          text: "Sunrise " + monitorScope.weatherSunrise
                          color: Theme.subtext
                          font.family: Theme.fontFamily
                          font.pixelSize: 12
                        }
                      }

                      Row {
                        spacing: 8
                        anchors.right: parent.right

                        Text {
                          text: "\uf186"
                          color: Theme.sapphire
                          font.family: Theme.fontFamily
                          font.pixelSize: 14
                        }

                        Text {
                          text: "Sunset " + monitorScope.weatherSunset
                          color: Theme.subtext
                          font.family: Theme.fontFamily
                          font.pixelSize: 12
                        }
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    radius: 16
                    color: Theme.well

                    Row {
                      anchors.centerIn: parent
                      spacing: 20

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: monitorScope.weatherGlyph
                        color: Theme.peach
                        font.family: Theme.fontFamily
                        font.pixelSize: 42
                      }

                      Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                          text: monitorScope.weatherTemp
                          color: Theme.text
                          font.family: Theme.fontFamily
                          font.pixelSize: 36
                          font.bold: true
                        }

                        Text {
                          text: monitorScope.weatherDesc
                          color: Theme.muted
                          font.family: Theme.fontFamily
                          font.pixelSize: 14
                        }
                      }
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                      model: [
                        {
                          glyph: "\uf043",
                          label: "Humidity",
                          value: monitorScope.weatherHumidity
                        },
                        {
                          glyph: "\uf2c9",
                          label: "Feels Like",
                          value: monitorScope.weatherFeels
                        },
                        {
                          glyph: "\ue31e",
                          label: "Wind",
                          value: monitorScope.weatherWind
                        }
                      ]

                      Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 14
                        color: Theme.well

                        Row {
                          anchors.centerIn: parent
                          spacing: 10

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.glyph
                            color: Theme.sapphire
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                          }

                          Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                              text: modelData.label
                              color: Theme.muted
                              font.family: Theme.fontFamily
                              font.pixelSize: 11
                            }

                            Text {
                              text: modelData.value
                              color: Theme.text
                              font.family: Theme.fontFamily
                              font.pixelSize: 14
                              font.bold: true
                            }
                          }
                        }
                      }
                    }
                  }

                  Text {
                    text: "7-Day Forecast"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Repeater {
                      model: forecastModel

                      Rectangle {
                        required property string dayLabel
                        required property string dateLabel
                        required property string glyph
                        required property string range

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        radius: 14
                        color: Theme.well

                        Column {
                          anchors.centerIn: parent
                          spacing: 6

                          Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayLabel
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                          }

                          Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dateLabel
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                          }

                          Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: glyph
                            color: Theme.sapphire
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                          }

                          Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: range
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Typing speed weekly overlay — same hover pattern as weather.
              Rectangle {
                id: typingOverlay
                anchors.fill: parent
                anchors.margins: 16
                z: 51
                radius: 18
                color: Theme.barBg
                opacity: monitorScope.typingExpandT
                visible: monitorScope.typingExpandT > 0.01
                scale: 0.98 + 0.02 * monitorScope.typingExpandT
                transformOrigin: Item.TopLeft
                clip: true

                HoverHandler {
                  onHoveredChanged: monitorScope.typingOverlayHovered = hovered
                }

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 18
                  spacing: 14

                  RowLayout {
                    Layout.fillWidth: true

                    Column {
                      Layout.fillWidth: true
                      spacing: 4

                      Text {
                        text: "Typing Speed"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                      }

                      Text {
                        text: "Weekly average WPM"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                      }
                    }

                    Column {
                      spacing: 2

                      Text {
                        anchors.right: parent.right
                        text: Math.round(TypingStats.currentWpm) + " WPM"
                        color: Theme.sapphire
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                      }

                      Text {
                        anchors.right: parent.right
                        text: "Today avg " + Math.round(TypingStats.todayWpm)
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                      }
                    }
                  }

                  Item {
                    id: weekChart
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property var days: TypingStats.week
                    readonly property real maxWpm: {
                      const _ = TypingStats.rev
                      let m = 1
                      const list = weekChart.days
                      if (!list)
                        return 40
                      for (let i = 0; i < list.length; i++) {
                        const v = Number(list[i].wpm) || 0
                        if (v > m)
                          m = v
                      }
                      return Math.max(40, Math.ceil(m / 10) * 10)
                    }

                    Row {
                      anchors.fill: parent
                      anchors.topMargin: 8
                      anchors.bottomMargin: 4
                      spacing: 10

                      Repeater {
                        model: weekChart.days

                        Item {
                          required property var modelData
                          width: Math.max(28, (weekChart.width - 60) / 7)
                          height: parent.height

                          readonly property real wpm: Number(modelData.wpm) || 0
                          readonly property real barH: {
                            const maxH = Math.max(40, height - 36)
                            return Math.max(4, maxH * (wpm / weekChart.maxWpm))
                          }

                          Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: dayLabel.top
                            anchors.bottomMargin: 8
                            width: Math.min(36, parent.width - 8)
                            height: parent.barH
                            radius: 8
                            color: Theme.sapphire
                            opacity: parent.wpm > 0 ? 1 : 0.28
                          }

                          Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: dayLabel.top
                            anchors.bottomMargin: parent.barH + 12
                            text: parent.wpm > 0 ? Math.round(parent.wpm) : ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                          }

                          Text {
                            id: dayLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: modelData.label || ""
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      HyprlandFocusGrab {
        active: monitorScope.open
        windows: [drawer]
        onCleared: monitorScope.closeDash()
      }

    }
  }
}
