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
  property bool desktopVisible: false

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
    launcher.command = ["bash", root.filePath("launch.sh"), text]
    launcher.running = false
    launcher.running = true
    return "ok"
  }

  function hide() {
    root.desktopVisible = false
    hideProc.running = false
    hideProc.running = true
    return "ok"
  }

  Process { id: launcher }

  Process {
    id: hideProc
    command: ["bash", "-lc", "pkill -x ttfx 2>/dev/null; pkill -f '[o]rg.omarchy.screensaver' 2>/dev/null; true"]
  }

  // Sprite follows the native screensaver windows, including Super+Esc.
  Timer {
    interval: 250
    running: true
    repeat: true
    onTriggered: {
      presence.running = false
      presence.running = true
    }
  }

  Process {
    id: presence
    command: ["pgrep", "-f", "[o]rg.omarchy.screensaver"]
    onExited: root.desktopVisible = (exitCode === 0)
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
  }
}
