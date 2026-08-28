import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
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
  property bool generating: false
  property string generateStatus: ""
  property string generateModel: "nano_banana_2"
  property string lastPrompt: ""
  property string lastResultPath: ""
  property string lastResultUrl: ""
  property string lastError: ""
  property var atlasSpec: null

  readonly property bool petVisible: true
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
  readonly property var sinkList: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
  readonly property var atlas: Model.normalizeAtlas(root.atlasSpec)

  function filePath(name) {
    var url = String(Qt.resolvedUrl(name))
    if (url.indexOf("file://") === 0) url = url.slice(7)
    return decodeURIComponent(url)
  }

  function pluginRoot() {
    var p = root.filePath("scripts/generate-sprite.py")
    var i = p.lastIndexOf("/scripts/")
    if (i >= 0) return p.slice(0, i)
    return root.filePath(".")
  }

  function dataDir() {
    var home = ""
    try {
      home = String(Quickshell.env("HOME") || "")
    } catch (e) {
      home = ""
    }
    if (!home) home = "/tmp"
    return home + "/.local/share/higgsfield.signals"
  }

  function readJsonFile(url) {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", url, false)
    xhr.send()
    if (xhr.status !== 200 && xhr.status !== 0) return null
    try {
      return JSON.parse(xhr.responseText)
    } catch (e) {
      return null
    }
  }

  function loadAtlas() {
    var generated = root.readJsonFile("file://" + root.dataDir() + "/atlas.json")
    if (generated && generated.file) {
      root.atlasSpec = generated
      return
    }
    root.atlasSpec = root.readJsonFile(Qt.resolvedUrl("atlas.json"))
  }

  function onKey() {
    root.keyCount += 1
    root.lastKeyMs = Date.now()
  }

  function toggleCollapsed() {
    root.collapsed = !root.collapsed
    return root.collapsed ? "collapsed" : "expanded"
  }

  function generate(prompt, model) {
    var p = Model.trimPrompt(prompt)
    if (!p) return "empty"
    if (root.generating) return "busy"
    var m = Model.trimPrompt(model)
    if (!m) m = root.generateModel
    root.generating = true
    root.generateStatus = "Generating…"
    root.lastPrompt = p
    root.lastError = ""
    genProc.command = ["bash", root.filePath("generate.sh"), p, m]
    genProc.running = false
    genProc.running = true
    return "started"
  }

  function generateSprite(imagePath, notes, smoke) {
    var img = Model.trimPrompt(imagePath)
    if (!img) return "empty"
    if (root.generating) return "busy"
    var n = Model.trimPrompt(notes)
    root.generating = true
    root.generateStatus = smoke ? "Smoke test: walk clip…" : "Starting sprite pipeline…"
    root.lastPrompt = img
    root.lastError = ""
    var cmd = [
      "python3", "-u", root.filePath("scripts/generate-sprite.py"),
      "--image", img,
      "--plugin-root", root.pluginRoot(),
      "--out", root.dataDir()
    ]
    if (n) {
      cmd.push("--notes")
      cmd.push(n)
    }
    if (smoke) cmd.push("--smoke")
    genProc.command = cmd
    genProc.running = false
    genProc.running = true
    return "started"
  }

  function onGenerateFinished(code, stdout) {
    var parsed = Model.parseGenerateResult(stdout)
    root.generating = false
    if (parsed.ok && parsed.path) {
      root.lastResultPath = parsed.path
      root.lastResultUrl = parsed.url
      root.lastError = ""
      root.generateStatus = "Saved " + parsed.path
      root.loadAtlas()
      return
    }
    var err = parsed.error || ("generate failed (" + code + ")")
    root.lastError = err
    root.generateStatus = err
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

  Process {
    id: genProc
    stdout: SplitParser {
      onRead: function(line) {
        var s = String(line || "")
        if (s.indexOf("{") === 0) {
          root.onGenerateFinished(0, s)
          return
        }
        if (s) root.generateStatus = s
      }
    }
    onExited: function(exitCode) {
      if (!root.generating) return
      root.onGenerateFinished(exitCode, '{"ok":false,"error":"generate failed (' + exitCode + ')"}')
    }
  }

  Component.onCompleted: root.loadAtlas()

  IpcHandler {
    target: "higgsfield.signals"

    function ping(): string { return "ok" }
    function collapse(): string { return root.toggleCollapsed() }
    function generate(prompt: string): string { return root.generate(prompt) }
    function generateSprite(imagePath: string): string { return root.generateSprite(imagePath, "", false) }
    function generateSpriteSmoke(imagePath: string): string { return root.generateSprite(imagePath, "", true) }
  }
}
