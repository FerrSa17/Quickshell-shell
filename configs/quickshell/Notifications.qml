pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
  id: root

  property bool dnd: false
  // Notification centers open across monitors (Bar Variants).
  property int centerOpenCount: 0
  readonly property bool centerOpen: centerOpenCount > 0
  readonly property bool suppressToasts: dnd || centerOpen
  readonly property int count: historyModel.count
  readonly property alias history: historyModel
  readonly property alias toasts: toastModel
  readonly property int maxToasts: 5
  readonly property int toastH: 72
  readonly property int toastGap: 0
  readonly property int toastStride: toastH + toastGap

  function retainCenter() {
    centerOpenCount++
    if (centerOpenCount === 1)
      toastModel.clear()
  }

  function releaseCenter() {
    centerOpenCount = Math.max(0, centerOpenCount - 1)
  }

  ListModel {
    id: historyModel
  }

  ListModel {
    id: toastModel
  }

  NotificationServer {
    id: server
    keepOnReload: true
    bodySupported: true
    bodyMarkupSupported: false
    imageSupported: true
    actionsSupported: false
    persistenceSupported: true

    onNotification: notification => {
      notification.tracked = true

      const entry = {
        key: String(notification.id) + "-" + Date.now(),
        summary: notification.summary || notification.appName || "Notification",
        body: notification.body || "",
        appName: notification.appName || "",
        at: Date.now()
      }

      historyModel.insert(0, entry)

      // History always; toasts only when center is closed and DND is off.
      if (!root.suppressToasts) {
        toastModel.append({
          key: entry.key,
          summary: entry.summary,
          body: entry.body,
          appName: entry.appName,
          at: entry.at,
          slot: toastModel.count
        })
        while (toastModel.count > root.maxToasts)
          toastModel.remove(0)
        reflowToastSlots()
      }
    }
  }

  function clearAll() {
    historyModel.clear()
    toastModel.clear()
    const values = server.trackedNotifications.values
    for (let i = values.length - 1; i >= 0; i--) {
      try {
        values[i].dismiss()
      } catch (e) {}
    }
  }

  function dismissToast(key) {
    const k = String(key)
    for (let i = toastModel.count - 1; i >= 0; i--) {
      if (String(toastModel.get(i).key) === k) {
        toastModel.remove(i)
        reflowToastSlots()
        return true
      }
    }
    return false
  }

  function reflowToastSlots() {
    for (let i = 0; i < toastModel.count; i++)
      toastModel.setProperty(i, "slot", i)
  }

  function remove(key) {
    dismissToast(key)
    const k = String(key)
    for (let i = historyModel.count - 1; i >= 0; i--) {
      if (String(historyModel.get(i).key) === k) {
        historyModel.remove(i)
        return
      }
    }
  }
}
