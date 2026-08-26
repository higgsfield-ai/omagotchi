import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool stayAwake: false

  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle
    ? shell.shellConfig.idle
    : ({})
  readonly property int screensaverTimeoutSeconds: Model.screensaverSeconds(idleConfig, 150)

  function overlayItem() {
    if (!root.shell || !root.shell.panelLoaders) return null
    var loader = root.shell.panelLoaders["higgsfield.signals"]
    return loader && loader.item ? loader.item : null
  }

  function show() {
    var item = overlayItem()
    if (item && typeof item.open === "function") {
      item.open("{}")
      return "ok"
    }
    if (root.shell && typeof root.shell.summon === "function")
      return root.shell.summon("higgsfield.signals", "{}") ? "ok" : "unknown"
    return "no-overlay"
  }

  function hide() {
    var item = overlayItem()
    if (item && typeof item.close === "function") {
      item.close()
      return "ok"
    }
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide("higgsfield.signals")
      return "ok"
    }
    return "no-overlay"
  }

  function next() {
    var item = overlayItem()
    if (item && typeof item.open === "function") {
      item.open("{}")
      return "ok"
    }
    return root.show()
  }

  IdleMonitor {
    id: idleMonitor
    enabled: !root.stayAwake
    timeout: root.screensaverTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      // Mapping the overlay can look like activity. Only auto-show on idle;
      // the overlay dismisses itself on key, click, or pointer motion.
      if (idleMonitor.isIdle) root.show()
    }
  }

  Process {
    id: stayAwakeProbe
    command: ["bash", "-c", "if [[ -f $HOME/.local/state/omarchy/indicators/stay-awake ]]; then echo yes; else echo no; fi"]
    stdout: SplitParser {
      onRead: function(line) {
        var enabled = String(line).trim() === "yes"
        if (root.stayAwake === enabled) return
        root.stayAwake = enabled
        if (enabled) root.hide()
      }
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/indicators"
    watchChanges: true
    printErrors: false
    onFileChanged: {
      stayAwakeProbe.running = false
      stayAwakeProbe.running = true
    }
  }

  Component.onCompleted: stayAwakeProbe.running = true

  IpcHandler {
    target: "higgsfield.signals"

    function show(): string { return root.show() }
    function hide(): string { return root.hide() }
    function next(): string { return root.next() }
    function ping(): string { return "ok" }
  }
}
