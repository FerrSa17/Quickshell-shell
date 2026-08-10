//@ pragma IconTheme Papirus
//@ pragma Env QS_ICON_THEME = Papirus
//@ pragma Env QT_QPA_PLATFORMTHEME = gtk3
import Quickshell
import QtQuick

ShellRoot {
  DesktopFrame {}
  Bar {}
  LeftDashboard {}
  PowerMenu {}
  DesktopClock {}
  NotificationToasts {}
  AppLauncher {}
  ScreenshotArea {}
  LockScreen {}

  // Keep schedule singletons alive (Quickshell loads them lazily on reference).
  QtObject {
    readonly property bool _autoBrightness: AutoBrightness.isDay
    readonly property int _typing: TypingStats.rev
  }
}
