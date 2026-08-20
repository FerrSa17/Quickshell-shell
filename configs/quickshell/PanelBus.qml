pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  signal openSettingsRequested
  signal openWallpapersRequested
  signal openShortcutsRequested
  signal openWifiRequested
  signal openBluetoothRequested
  // mode: "light" | "calm" | "dark"
  signal appearanceModeRequested(string mode)
  // mode: "area" | "full" | "window"
  signal screenshotRequested(string mode)
  signal screenshotAreaRequested
  signal lockRequested
  signal toggleDashboardRequested
  signal openDashboardRequested
  signal closeDashboardRequested
  signal togglePowerMenuRequested
  signal openPowerMenuRequested
  signal closePowerMenuRequested
  signal toggleSysMonRequested
  signal openSysMonRequested
  signal closeSysMonRequested

  property int controlReserve: 0
  property int notifReserve: 0
  property int clipboardReserve: 0
  readonly property int frameCornerReserve: Math.max(controlReserve, notifReserve, clipboardReserve)

  signal closeNotificationsRequested
  signal closeClipboardRequested

  // Only one named popup at a time. A new claim waits until the previous
  // close animation finishes before the next panel is allowed to open.
  property string exclusiveId: ""
  property string pendingId: ""
  property bool animatingClose: false
  signal exclusiveChanged(string id)

  readonly property int popupHandoffMs: 290

  property bool appearanceForceWallpaper: false

  function claim(id) {
    if (!id)
      return true
    if (id === "screenshot") {
      pendingId = ""
      animatingClose = false
      handoff.stop()
      exclusiveId = id
      exclusiveChanged(id)
      return true
    }
    if (exclusiveId === id && !animatingClose)
      return true
    if (animatingClose || (exclusiveId.length && exclusiveId !== id)) {
      pendingId = id
      if (exclusiveId.length) {
        exclusiveId = ""
        animatingClose = true
        exclusiveChanged("")
      }
      handoff.restart()
      return false
    }
    pendingId = ""
    exclusiveId = id
    exclusiveChanged(id)
    return true
  }

  function release(id) {
    if (exclusiveId !== id)
      return
    exclusiveId = ""
    animatingClose = true
    handoff.restart()
  }

  function closeAllPopups() {
    pendingId = ""
    animatingClose = false
    handoff.stop()
    exclusiveId = ""
    exclusiveChanged("")
  }

  function finishClose() {
    animatingClose = false
    if (!pendingId.length)
      return
    const next = pendingId
    pendingId = ""
    exclusiveId = next
    exclusiveChanged(next)
  }

  Timer {
    id: handoff
    interval: root.popupHandoffMs
    repeat: false
    onTriggered: root.finishClose()
  }

  function openSettings() {
    openSettingsRequested()
  }

  function openWallpapers() {
    openWallpapersRequested()
  }

  function openShortcuts() {
    openShortcutsRequested()
  }

  function openWifi() {
    openWifiRequested()
  }

  function openBluetooth() {
    openBluetoothRequested()
  }

  function setAppearanceMode(mode, forceWallpaper) {
    appearanceForceWallpaper = forceWallpaper === true
    appearanceModeRequested(mode)
  }

  function takeScreenshot(mode) {
    screenshotRequested(mode)
  }

  function openScreenshotArea() {
    screenshotAreaRequested()
  }

  function lock() {
    lockRequested()
  }

  function toggleDashboard() {
    toggleDashboardRequested()
  }

  function openDashboard() {
    openDashboardRequested()
  }

  function closeDashboard() {
    closeDashboardRequested()
  }

  function togglePowerMenu() {
    togglePowerMenuRequested()
  }

  function openPowerMenu() {
    openPowerMenuRequested()
  }

  function closePowerMenu() {
    closePowerMenuRequested()
  }

  function toggleSysMon() {
    toggleSysMonRequested()
  }

  function openSysMon() {
    openSysMonRequested()
  }

  function closeSysMon() {
    closeSysMonRequested()
  }
}
