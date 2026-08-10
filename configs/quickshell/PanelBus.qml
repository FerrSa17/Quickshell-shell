pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  signal openSettingsRequested
  signal openWallpapersRequested
  signal openShortcutsRequested
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

  // Height reserved under the top chrome by frameCorner panels (Control / notifs).
  // Toasts dock flush below this so they touch the open panel and the right frame.
  property int controlReserve: 0
  property int notifReserve: 0
  readonly property int frameCornerReserve: Math.max(controlReserve, notifReserve)

  property bool appearanceForceWallpaper: false

  function openSettings() {
    openSettingsRequested()
  }

  function openWallpapers() {
    openWallpapersRequested()
  }

  function openShortcuts() {
    openShortcutsRequested()
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
