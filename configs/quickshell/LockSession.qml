pragma Singleton

import Quickshell
import QtQuick
import "QuotesRu.js" as QuotesRu

Singleton {
  id: root

  property bool locked: false
  property string quoteText: ""
  property string quoteAuthor: ""

  readonly property int quoteCount: QuotesRu.count()

  function lock() {
    pickQuote()
    locked = true
  }

  function unlock() {
    locked = false
  }

  Component.onDestruction: {
    // Release ext_session_lock before qs dies — otherwise Hyprland can crash.
    if (locked)
      locked = false
  }

  function pickQuote() {
    const q = QuotesRu.randomQuote() || ({})
    quoteText = q.t || ""
    quoteAuthor = q.a || ""
  }

  Component.onCompleted: pickQuote()
}
