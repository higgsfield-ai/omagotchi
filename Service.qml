import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Model.js" as Model
import "Catalog.js" as Catalog

Item {
  id: root

  property var shell: null
  property var manifest: null
  property int currentId: -1
  property string currentTitle: ""
  property string currentBody: ""
  property string focusedMonitor: ""
  property string clipKind: ""
  property string lastClipKind: ""
  property double lastClipMs: 0

  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle
    ? shell.shellConfig.idle
    : ({})
  readonly property int screensaverTimeoutSeconds: Model.screensaverSeconds(idleConfig, 150)

  function filePath(name) {
    var url = String(Qt.resolvedUrl(name))
    if (url.indexOf("file://") === 0) url = url.slice(7)
    return decodeURIComponent(url)
  }

  function applySignal(signal) {
    if (!signal) return false
    root.currentId = Number(signal.id)
    root.currentTitle = String(signal.title || "")
    root.currentBody = String(signal.body || "")
    return root.currentTitle.length > 0
  }

  function pickNew() {
    root.applySignal(Catalog.pick(root.currentId))
  }

  function reveal() {
    root.pickNew()
    var text = Model.formatScreensaver(root.currentId, root.currentTitle, root.currentBody)
    launcher.command = ["bash", root.filePath("launch.sh"), text, "write-only"]
    launcher.running = false
    launcher.running = true
    return root.playEvent("screensaver")
  }

  function hide() {
    hideProc.running = false
    hideProc.running = true
    root.clipKind = ""
    return "ok"
  }

  function playEvent(kind) {
    var k = Model.normalizeClipKind(kind)
    if (!k) return "unknown"
    var now = Date.now()
    if (!Model.shouldPlayClip(k, root.lastClipKind, root.lastClipMs, now, 8000))
      return "debounced"
    root.clipKind = k
    root.lastClipKind = k
    root.lastClipMs = now
    clipProc.command = [
      "bash",
      root.filePath("play.sh"),
      k,
      root.filePath(Model.clipFile(k)),
      root.focusedMonitor
    ]
    clipProc.running = false
    clipProc.running = true
    return k
  }

  function applyFocus(monitorsRaw, windowRaw) {
    var focus = Model.focusWindow(monitorsRaw, windowRaw)
    root.focusedMonitor = focus.monitor
  }

  function applyMonitors(raw) {
    root._monRaw = String(raw || "")
    root.applyFocus(root._monRaw, root._winRaw)
  }

  function applyWindow(raw) {
    root._winRaw = String(raw || "")
    root.applyFocus(root._monRaw, root._winRaw)
  }

  property string _monRaw: "[]"
  property string _winRaw: "null"

  Process { id: launcher }

  Process {
    id: hideProc
    command: ["bash", "-lc", "pkill -x ttfx 2>/dev/null; pkill -f '[o]rg.omarchy.screensaver' 2>/dev/null; pkill -f '[m]pv --title=higgsfield-signals-clip' 2>/dev/null; true"]
  }

  Process {
    id: clipProc
    onExited: root.clipKind = ""
  }

  Timer {
    interval: 250
    running: true
    repeat: true
    onTriggered: {
      monProc.running = false
      monProc.running = true
      winProc.running = false
      winProc.running = true
    }
  }

  Process {
    id: monProc
    command: ["hyprctl", "-j", "monitors"]
    stdout: StdioCollector {
      id: monOut
      onStreamFinished: root.applyMonitors(monOut.text)
    }
  }

  Process {
    id: winProc
    command: ["hyprctl", "-j", "activewindow"]
    stdout: StdioCollector {
      id: winOut
      onStreamFinished: root.applyWindow(winOut.text)
    }
  }

  IdleMonitor {
    id: idleMonitor
    timeout: root.screensaverTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      if (idleMonitor.isIdle) root.reveal()
    }
  }

  IpcHandler {
    target: "higgsfield.signals"

    function show(payloadJson: string): string { return root.reveal() }
    function reveal(): string { return root.reveal() }
    function next(): string { return root.reveal() }
    function close(): string { return root.hide() }
    function ping(): string { return "ok" }
    function event(kind: string): string { return root.playEvent(kind) }
  }
}
