pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
  id: root

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource

  readonly property real volume: {
    if (!sink || !sink.audio)
      return 0
    return Math.round(sink.audio.volume * 100)
  }
  readonly property bool muted: sink?.audio?.muted ?? false

  readonly property real micVolume: {
    if (!source || !source.audio)
      return 0
    return Math.round(source.audio.volume * 100)
  }
  readonly property bool micMuted: source?.audio?.muted ?? false

  property real volumeSmooth: 0
  property real micVolumeSmooth: 0

  Behavior on volumeSmooth {
    NumberAnimation {
      duration: 1400
      easing.type: Easing.OutCubic
    }
  }
  Behavior on micVolumeSmooth {
    NumberAnimation {
      duration: 1400
      easing.type: Easing.OutCubic
    }
  }

  readonly property string display: muted ? "mute" : Math.round(volumeSmooth) + "%"
  readonly property string micDisplay: micMuted ? "mute" : Math.round(micVolumeSmooth) + "%"

  onVolumeChanged: volumeSmooth = volume
  onMicVolumeChanged: micVolumeSmooth = micVolume
  Component.onCompleted: {
    volumeSmooth = volume
    micVolumeSmooth = micVolume
  }

  function toggleMute() {
    if (!sink || !sink.audio)
      return
    sink.audio.muted = !sink.audio.muted
  }

  function toggleMicMute() {
    if (!source || !source.audio)
      return
    source.audio.muted = !source.audio.muted
  }

  function adjust(delta) {
    if (!sink || !sink.audio)
      return
    const next = Math.max(0, Math.min(1, sink.audio.volume + delta / 100))
    sink.audio.volume = next
    if (next > 0 && sink.audio.muted)
      sink.audio.muted = false
  }

  function adjustMic(delta) {
    if (!source || !source.audio)
      return
    const next = Math.max(0, Math.min(1, source.audio.volume + delta / 100))
    source.audio.volume = next
    if (next > 0 && source.audio.muted)
      source.audio.muted = false
  }

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
  }
}
