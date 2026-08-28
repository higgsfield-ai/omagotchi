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
  property var pluginRegistry: null
  property string focusedMonitor: ""
  property real winX: 0
  property real winY: 0
  property real winW: 0
  property real winH: 0
  property bool collapsed: false
  property int nowMs: 0
  property string wander: "idle"
  property int greetUntil: 0
  property int grumpyUntil: 0
  property int sickUntil: 0
  property int lastClickMs: 0
  property int clickBurst: 0
  property real audioPeak: 0
  property bool generating: false
  property string generateStatus: ""
  property string generateModel: "nano_banana_2"
  property string lastPrompt: ""
  property string lastResultPath: ""
  property string lastResultUrl: ""
  property string lastError: ""
  property var atlasSpec: null
  property string photoPath: ""
  property bool picking: false
  property int generateStep: 0
  property int generateSteps: 0
  property int generatePercent: 0
  property int atlasRev: 0
  property bool loggedIn: false
  property bool loggingIn: false
  property bool runtimeReady: false
  property string hfPath: ""
  property bool pendingLogin: false
  property bool hasGeneratedPet: false

  readonly property string photoName: Model.fileBaseName(root.photoPath)

  readonly property bool petVisible: root.hasGeneratedPet
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
  readonly property string mode: Model.resolveMode({
    sick: root.nowMs < root.sickUntil,
    grumpy: root.nowMs < root.grumpyUntil,
    greet: root.nowMs < root.greetUntil,
    mediaPlaying: root.mediaPlaying,
    audioPeak: root.audioPeak,
    wander: root.wander
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

  function applyGeneratedSheet(path, spec) {
    var file = Model.fileUrlToPath(path)
    if (!file || file.charAt(0) !== "/") return false
    var atlas = spec && typeof spec === "object" && spec.file
      ? spec
      : Model.generatedAtlas(file)
    if (String(atlas.file || "").charAt(0) !== "/")
      atlas = Model.generatedAtlas(file)
    root.lastResultPath = file
    root.atlasSpec = atlas
    root.hasGeneratedPet = true
    root.atlasRev += 1
    return true
  }

  function loadAtlas() {
    atlasReadProc.command = ["cat", root.dataDir() + "/atlas.json"]
    atlasReadProc.running = false
    atlasReadProc.running = true
  }

  function applyAtlasText(text) {
    var raw = String(text || "").replace(/^\s+|\s+$/g, "")
    if (raw) {
      try {
        var generated = JSON.parse(raw)
        if (generated && generated.file && String(generated.file).charAt(0) === "/") {
          root.atlasSpec = generated
          root.hasGeneratedPet = true
          root.atlasRev += 1
          return
        }
      } catch (e) {}
    }
    if (root.lastResultPath) {
      root.applyGeneratedSheet(root.lastResultPath)
      return
    }
    root.hasGeneratedPet = false
    root.atlasSpec = root.readJsonFile(Qt.resolvedUrl("atlas.json"))
  }

  function applyRuntime(raw) {
    var parsed = Model.parseGenLine(raw)
    var data = null
    try {
      data = JSON.parse(parsed.kind === "result" ? parsed.raw : String(raw || "").replace(/^\s+|\s+$/g, ""))
    } catch (e) {
      data = null
    }
    if (!data) return
    if (data.hf) root.hfPath = String(data.hf)
    if (data.ok) root.runtimeReady = true
    if (typeof data.logged_in === "boolean") root.loggedIn = data.logged_in
  }

  function ensureRuntime() {
    ensureProc.command = ["python3", "-u", root.filePath("scripts/runtime.py"), "ensure", "--out", root.dataDir()]
    ensureProc.running = false
    ensureProc.running = true
  }

  function checkAuth() {
    authProc.command = ["python3", "-u", root.filePath("scripts/runtime.py"), "auth-status", "--out", root.dataDir()]
    authProc.running = false
    authProc.running = true
  }

  function login() {
    if (root.loggingIn) return "busy"
    if (!root.hfPath) {
      root.pendingLogin = true
      root.ensureRuntime()
      root.generateStatus = "Installing Higgsfield…"
      return "setup"
    }
    root.loggingIn = true
    root.generateStatus = "Waiting for browser login…"
    loginProc.command = [root.hfPath, "auth", "login"]
    loginProc.running = false
    loginProc.running = true
    return "started"
  }

  function setPhoto(path) {
    var p = Model.fileUrlToPath(Model.trimPrompt(path))
    if (!p) return "empty"
    root.photoPath = p
    root.lastError = ""
    root.generateStatus = ""
    return "ok"
  }

  function pickPhoto() {
    if (!root.loggedIn) return "login"
    if (root.picking || root.generating) return "busy"
    root.picking = true
    root.lastError = ""
    pickProc.command = ["bash", root.filePath("scripts/pick-image.sh")]
    pickProc.running = false
    pickProc.running = true
    return "started"
  }

  function onPickedPhoto(code, stdout, stderr) {
    root.picking = false
    var path = Model.fileUrlToPath(Model.trimPrompt(stdout))
    if (path) {
      root.setPhoto(path)
      return
    }
    var err = Model.trimPrompt(stderr)
    if (Number(code) !== 0 && err) {
      root.lastError = err
      root.generateStatus = err
    }
  }

  function onPetClicked() {
    var next = Model.nextClickState({
      lastClickMs: root.lastClickMs,
      clickBurst: root.clickBurst,
      greetUntil: root.greetUntil,
      grumpyUntil: root.grumpyUntil
    }, Date.now())
    root.lastClickMs = next.lastClickMs
    root.clickBurst = next.clickBurst
    root.greetUntil = next.greetUntil
    root.grumpyUntil = next.grumpyUntil
    return root.nowMs < root.grumpyUntil ? "grumpy" : "greet"
  }

  function onDroppedFromHeight() {
    root.sickUntil = Date.now() + 4500
    return "sick"
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
    if (!root.loggedIn) return "login"
    if (root.generating) return "busy"
    var n = Model.trimPrompt(notes)
    root.generating = true
    root.generateStatus = smoke ? "Walk test…" : "Starting…"
    root.generateStep = 0
    root.generateSteps = smoke ? 3 : 20
    root.generatePercent = 0
    root.lastPrompt = img
    root.photoPath = img
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
      root.generateStatus = "Tamagotchi ready"
      root.generatePercent = 100
      root.applyGeneratedSheet(parsed.path, parsed.atlasSpec)
      return
    }
    var err = parsed.error || ("generate failed (" + code + ")")
    root.lastError = err
    root.generateStatus = ""
    root.generatePercent = 0
  }

  function retryGenerate() {
    if (root.generating) return "busy"
    if (!root.photoPath) return "empty"
    return root.generateSprite(root.photoPath, "", false)
  }

  function onGenLine(line) {
    var parsed = Model.parseGenLine(line)
    if (parsed.kind === "progress") {
      root.generateStatus = parsed.label
      root.generateStep = parsed.step
      root.generateSteps = parsed.steps
      root.generatePercent = parsed.percent
      return
    }
    if (parsed.kind === "result") {
      root.onGenerateFinished(0, parsed.raw)
      return
    }
    if (parsed.text) root.generateStatus = parsed.text
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
    id: wanderTimer
    interval: 2800
    running: root.petVisible
    repeat: true
    onTriggered: {
      root.wander = Model.pickWander(Math.random())
      wanderTimer.interval = 1800 + Math.floor(Math.random() * 2800)
    }
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

  PwObjectTracker { objects: root.sinkList }

  PwNodePeakMonitor {
    id: peakMon
    node: Pipewire.defaultAudioSink
    enabled: root.mediaPlaying && root.petVisible
    onPeakChanged: root.audioPeak = peakMon.peak
  }

  Process {
    id: ensureProc
    stdout: SplitParser {
      onRead: function(line) { root.applyRuntime(line) }
    }
    onExited: function() {
      if (root.pendingLogin && root.hfPath) {
        root.pendingLogin = false
        root.login()
      }
    }
  }

  Process {
    id: authProc
    stdout: SplitParser {
      onRead: function(line) { root.applyRuntime(line) }
    }
  }

  Process {
    id: loginProc
    onExited: function() {
      root.loggingIn = false
      root.checkAuth()
    }
  }

  Timer {
    interval: 4000
    running: root.runtimeReady && !root.loggedIn && !root.loggingIn
    repeat: true
    onTriggered: root.checkAuth()
  }

  Process {
    id: pickProc
    stdout: StdioCollector {
      id: pickOut
    }
    stderr: StdioCollector {
      id: pickErr
    }
    onExited: function(exitCode) {
      root.onPickedPhoto(exitCode, pickOut.text, pickErr.text)
    }
  }

  Process {
    id: atlasReadProc
    stdout: StdioCollector {
      id: atlasReadOut
      waitForEnd: true
    }
    onExited: root.applyAtlasText(atlasReadOut.text)
  }

  Process {
    id: genProc
    stdout: SplitParser {
      onRead: function(line) {
        root.onGenLine(line)
      }
    }
    onExited: function(exitCode) {
      if (Number(exitCode) === 0) {
        var sheet = root.lastResultPath || (root.dataDir() + "/spritesheet_16x12.png")
        root.applyGeneratedSheet(sheet)
        if (root.generating) {
          root.generating = false
          root.generateStatus = "Tamagotchi ready"
          root.generatePercent = 100
          root.lastError = ""
        }
        return
      }
      if (!root.generating) return
      root.onGenerateFinished(exitCode, '{"ok":false,"error":"generate failed (' + exitCode + ')"}')
    }
  }

  function ensureBarChip() {
    if (root.pluginRegistry && typeof root.pluginRegistry.inBar === "function") {
      try {
        if (root.pluginRegistry.inBar("higgsfield.signals")) return
      } catch (e) {}
    }
    barChipProc.command = ["python3", "-u", root.filePath("scripts/ensure-bar-chip.py")]
    barChipProc.running = false
    barChipProc.running = true
  }

  Process {
    id: barChipProc
  }

  Timer {
    interval: 400
    running: true
    repeat: false
    onTriggered: root.ensureBarChip()
  }

  Component.onCompleted: {
    root.wander = Model.pickWander(Math.random())
    root.loadAtlas()
    root.ensureRuntime()
  }

  IpcHandler {
    target: "higgsfield.signals"

    function ping(): string { return "ok" }
    function collapse(): string { return root.toggleCollapsed() }
    function generate(prompt: string): string { return root.generate(prompt) }
    function generateSprite(imagePath: string): string { return root.generateSprite(imagePath, "", false) }
    function generateSpriteSmoke(imagePath: string): string { return root.generateSprite(imagePath, "", true) }
    function pickPhoto(): string { return root.pickPhoto() }
    function setPhoto(path: string): string { return root.setPhoto(path) }
    function login(): string { return root.login() }
    function retry(): string { return root.retryGenerate() }
  }
}
