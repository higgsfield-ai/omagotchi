import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "Model.js" as Model
import "Catalog.js" as Catalog

Item {
  id: root

  property var shell: null
  property var manifest: null
  property int currentId: -1
  property string currentTitle: ""
  property string currentBody: ""
  property bool screensaverActive: false
  property string focusedMonitor: ""
  property real winX: 0
  property real winY: 0
  property real winW: 0
  property real winH: 0
  property bool collapsed: false
  property int keyCount: 0
  property double lastKeyMs: 0
  property int nowMs: 0
  property real audioPeak: 0

  readonly property bool petVisible: !root.screensaverActive
  readonly property var media: shell && shell.serviceFor ? shell.serviceFor("omarchy.media") : null
  readonly property bool mediaPlaying: {
    if (root.media && root.media.activePlayer)
      return !!root.media.activePlayer.isPlaying
    var list = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].isPlaying) return true
    }
    return false
  }
  onMediaPlayingChanged: if (!root.mediaPlaying) root.audioPeak = 0
  readonly property bool keysRecent: (root.nowMs - root.lastKeyMs) < 500
  readonly property string mode: Model.resolveMode({
    collapsed: root.collapsed,
    keysRecent: root.keysRecent,
    mediaPlaying: root.mediaPlaying,
    audioPeak: root.audioPeak
  })
  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle
    ? shell.shellConfig.idle
    : ({})
  readonly property int screensaverTimeoutSeconds: Model.screensaverSeconds(idleConfig, 150)
  readonly property var sinkList: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []

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
    hideProc.running = false
    hideProc.running = true
    return "ok"
  }

  function onKey() {
    root.keyCount += 1
    root.lastKeyMs = Date.now()
  }

  function toggleCollapsed() {
    root.collapsed = !root.collapsed
    return root.collapsed ? "collapsed" : "expanded"
  }

  function applyFocus(monitorsRaw, windowRaw) {
    var focus = Model.focusWindow(monitorsRaw, windowRaw)
    root.focusedMonitor = focus.monitor
    root.winX = focus.x
    root.winY = focus.y
    root.winW = focus.w
    root.winH = focus.h
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
    command: ["bash", "-lc", "pkill -x ttfx 2>/dev/null; pkill -f '[o]rg.omarchy.screensaver' 2>/dev/null; true"]
  }

  Timer {
    interval: 80
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    interval: 250
    running: true
    repeat: true
    onTriggered: {
      presence.running = false
      presence.running = true
      monProc.running = false
      monProc.running = true
      winProc.running = false
      winProc.running = true
    }
  }

  Process {
    id: presence
    command: ["pgrep", "-f", "[o]rg.omarchy.screensaver"]
    onExited: root.screensaverActive = (exitCode === 0)
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

  Process {
    id: keyWatch
    command: ["python3", "-u", root.filePath("watch-keys.py")]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line).indexOf("k") !== -1) root.onKey()
      }
    }
  }

  PwObjectTracker { objects: root.sinkList }

  PwNodePeakMonitor {
    id: peakMon
    node: Pipewire.defaultAudioSink
    enabled: root.mediaPlaying && root.petVisible
    onPeakChanged: root.audioPeak = peakMon.peak
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
