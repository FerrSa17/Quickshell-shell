pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property real cpuPercent: 0
  property real memUsedGiB: 0
  property real memTotalGiB: 0
  property int tempC: 0
  property var prevCpu: ({ total: 0, idle: 0 })

  property string cpuModel: "CPU"
  property string gpuName: "GPU"
  property real gpuPercent: 0
  property int gpuTempC: 0
  property bool gpuReady: false

  property real diskUsedGiB: 0
  property real diskTotalGiB: 0
  property string diskDevice: "disk"

  // Smoothed values for UI (lerp toward latest sample)
  property real cpuSmooth: 0
  property real memSmooth: 0
  property real tempSmooth: 0
  property real gpuSmooth: 0
  property real diskSmooth: 0

  Behavior on cpuSmooth {
    NumberAnimation {
      duration: 1400
      easing.type: Easing.OutCubic
    }
  }
  Behavior on memSmooth {
    NumberAnimation {
      duration: 1400
      easing.type: Easing.OutCubic
    }
  }
  Behavior on tempSmooth {
    NumberAnimation {
      duration: 1400
      easing.type: Easing.OutCubic
    }
  }
  Behavior on gpuSmooth {
    NumberAnimation {
      duration: 1400
      easing.type: Easing.OutCubic
    }
  }
  Behavior on diskSmooth {
    NumberAnimation {
      duration: 1400
      easing.type: Easing.OutCubic
    }
  }

  readonly property real memPercent: {
    if (memTotalGiB <= 0)
      return 0
    return Math.min(100, Math.round(memUsedGiB / memTotalGiB * 100))
  }

  readonly property real diskPercent: {
    if (diskTotalGiB <= 0)
      return 0
    return Math.min(100, Math.round(diskUsedGiB / diskTotalGiB * 100))
  }

  function setCpu(v) {
    cpuPercent = v
    cpuSmooth = v
  }

  function setMem(used, total) {
    memUsedGiB = used
    memTotalGiB = total
    memSmooth = used
  }

  function setTemp(v) {
    tempC = v
    tempSmooth = v
  }

  function setGpu(pct, temp) {
    gpuReady = true
    gpuPercent = pct
    gpuSmooth = pct
    if (temp > 0)
      gpuTempC = temp
  }

  function setDisk(used, total, device) {
    diskUsedGiB = used
    diskTotalGiB = total
    if (device && device.length)
      diskDevice = device
    diskSmooth = diskPercent
  }

  function refresh() {
    cpuProc.running = true
    memProc.running = true
    tempProc.running = true
    diskProc.running = true
    gpuProc.running = true
  }

  Component.onCompleted: {
    metaProc.running = true
    refresh()
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // One-shot hardware names
  Process {
    id: metaProc
    command: [
      "sh", "-c",
      "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //; s/(R)//g; s/(TM)//g; s/ CPU.*//');\n"
        + "gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3- | sed 's/^ //');\n"
        + "echo \"$cpu\"; echo \"$gpu\"\n"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const lines = text.trim().split("\n")
        if (lines.length > 0 && lines[0].length)
          root.cpuModel = lines[0].trim()
        if (lines.length > 1 && lines[1].length)
          root.gpuName = lines[1].trim()
      }
    }
  }

  Process {
    id: cpuProc
    command: ["cat", "/proc/stat"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
          if (!lines[i].startsWith("cpu "))
            continue
          const parts = lines[i].trim().split(/\s+/)
          const idle = parseInt(parts[4])
          let total = 0
          for (let j = 1; j < parts.length; j++)
            total += parseInt(parts[j])
          if (root.prevCpu.total > 0 && total > root.prevCpu.total) {
            const dt = total - root.prevCpu.total
            const di = idle - root.prevCpu.idle
            root.setCpu(Math.round((dt - di) / dt * 100))
          }
          root.prevCpu = {
            total: total,
            idle: idle
          }
          break
        }
      }
    }
  }

  Process {
    id: memProc
    command: ["cat", "/proc/meminfo"]
    stdout: StdioCollector {
      onStreamFinished: {
        let mt = 0
        let ma = 0
        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
          const parts = lines[i].split(/\s+/)
          if (lines[i].startsWith("MemTotal:"))
            mt = parseInt(parts[1])
          if (lines[i].startsWith("MemAvailable:"))
            ma = parseInt(parts[1])
        }
        if (mt > 0)
          root.setMem((mt - ma) / 1024 / 1024, mt / 1024 / 1024)
      }
    }
  }

  Process {
    id: tempProc
    command: ["cat", "/sys/class/thermal/thermal_zone2/temp"]
    stdout: StdioCollector {
      onStreamFinished: {
        const raw = parseInt(text.trim())
        if (!isNaN(raw))
          root.setTemp(Math.round(raw / 1000))
      }
    }
  }

  Process {
    id: diskProc
    command: [
      "sh", "-c",
      "df -B1 --output=source,used,size / | awk 'NR==2 {print $1,$2,$3}'"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        const parts = text.trim().split(/\s+/)
        if (parts.length < 3)
          return
        const src = parts[0].replace(/^\/dev\//, "")
        const used = parseInt(parts[1])
        const size = parseInt(parts[2])
        if (isNaN(used) || isNaN(size) || size <= 0)
          return
        root.setDisk(used / 1024 / 1024 / 1024, size / 1024 / 1024 / 1024, src)
      }
    }
  }

  // Best-effort GPU busy: amdgpu sysfs, else nvidia-smi, else leave unset.
  Process {
    id: gpuProc
    command: [
      "sh", "-c",
      "for p in /sys/class/drm/card*/device/gpu_busy_percent; do\n"
        + "  [ -r \"$p\" ] || continue\n"
        + "  busy=$(cat \"$p\")\n"
        + "  temp=0\n"
        + "  for t in \"$(dirname \"$p\")\"/hwmon/hwmon*/temp*_input; do\n"
        + "    [ -r \"$t\" ] || continue\n"
        + "    temp=$(($(cat \"$t\")/1000))\n"
        + "    break\n"
        + "  done\n"
        + "  echo \"$busy $temp\"\n"
        + "  exit 0\n"
        + "done\n"
        + "if command -v nvidia-smi >/dev/null 2>&1; then\n"
        + "  nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '\n"
        + "  exit 0\n"
        + "fi\n"
        + "exit 1\n"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const parts = text.trim().replace(/,/g, " ").split(/\s+/)
        if (parts.length < 1 || !parts[0].length)
          return
        const busy = parseInt(parts[0])
        const temp = parts.length > 1 ? parseInt(parts[1]) : 0
        if (!isNaN(busy))
          root.setGpu(Math.max(0, Math.min(100, busy)), isNaN(temp) ? 0 : temp)
      }
    }
  }
}
