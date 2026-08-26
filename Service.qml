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
  readonly property string stayAwakePath: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"

  function show() {
    if (root.stayAwake) return
    if (root.shell && typeof root.shell.summon === "function")
      root.shell.summon("higgsfield.signals", "{}")
  }

  function hide() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide("higgsfield.signals")
  }

  function next() {
    if (root.stayAwake) return
    if (root.shell && typeof root.shell.summon === "function")
      root.shell.summon("higgsfield.signals", "{}")
  }

  onStayAwakeChanged: if (root.stayAwake) root.hide()

  IdleMonitor {
    id: idleMonitor
    enabled: !root.stayAwake
    timeout: root.screensaverTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      if (idleMonitor.isIdle) root.show()
      else root.hide()
    }
  }

  FileView {
    path: root.stayAwakePath
    watchChanges: true
    printErrors: false
    onLoaded: root.stayAwake = true
    onLoadFailed: root.stayAwake = false
  }

  IpcHandler {
    target: "higgsfield.signals"

    function show(): string { root.show(); return "ok" }
    function hide(): string { root.hide(); return "ok" }
    function next(): string { root.next(); return "ok" }
    function ping(): string { return "ok" }
  }
}
