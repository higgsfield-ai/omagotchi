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
  property real nowMs: 0
  property string wander: "idle"
  property real greetUntil: 0
  property real grumpyUntil: 0
  property real sickUntil: 0
  property real happyUntil: 0
  property real eatUntil: 0
  property real washUntil: 0
  property real lastClickMs: 0
  property int clickBurst: 0
  property real lastActiveMs: 0
  property real lastEatMs: 0
  property real lastWashMs: 0
  property real careHunger: 82
  property real careHygiene: 82
  property real careMood: 82
  property real careEnergy: 78
  property real careHealth: 88
  property real careAttention: 70
  property real careBond: 8
  property real careWeight: 50
  property real careBornMs: 0
  property real careUpdatedMs: 0
  property real lastDragCareMs: 0
  property string petActivity: "walking"
  property real stunUntil: 0
  // Speech bubble over the pet: say() sets a timed line; while the plugin
  // is generating, the bubble narrates that instead.
  property string sayText: ""
  property real sayUntil: 0
  readonly property string bubbleText: {
    if (root.nowMs < root.sayUntil && root.sayText !== "") return root.sayText
    if (root.mediaBusy || root.generating) return "Generating…"
    return ""
  }
  property bool mediaBusy: false
  property string mediaStatus: ""
  property string mediaError: ""
  property var mediaRefs: []
  property string mediaRatioImage: "1:1"
  property string mediaRatioVideo: "16:9"
  property string mediaDuration: "5s"
  property string lastMediaPath: ""
  property string lastMediaThumb: ""
  property int lastMediaRev: 0
  property string mediaKind: "image"
  property int mediaPrice: -1
  property bool mediaPicking: false
  property int credits: -1
  property bool pendingWash: false
  property string lastTrackKey: ""
  property real audioPeak: 0
  property bool careDirty: false
  // Nothing is written until the saved stats are back from disk: the read is a
  // process, and a save landing first would bury them under a newborn default.
  property bool careLoaded: false
  property int careSaveTicks: 0
  property bool generating: false
  property int failStreak: 0
  // Archived avatars the user can switch between (scripts/avatars.py).
  property var avatarList: []
  property bool avatarSwitching: false
  property string generateStatus: ""
  property string lastResultPath: ""
  property string lastError: ""
  property var atlasSpec: null
  property string photoPath: ""
  property bool picking: false
  property bool capturing: false
  property int photoRev: 0
  property int generateStep: 0
  property int generateSteps: 0
  property int generatePercent: 0
  property int atlasRev: 0
  property bool loggedIn: false
  property bool loggingIn: false
  property bool runtimeReady: false
  property string hfPath: ""
  onHfPathChanged: {
    if (!root.hfPath) return
    root.refreshCredits()
    if (root.mediaPrice < 0) root.refreshMediaPrice()
  }
  property bool pendingLogin: false
  // The user replaced the bundled sheet with their own generated one.
  property bool hasCustomAvatar: false
  property bool petDocked: false
  property bool petRecalling: false
  property bool petReleasing: false

  readonly property string generateLog: root.dataDir() + "/generate.log"

  readonly property bool petOnDesktop: Model.desktopPetVisible({
    docked: root.petDocked,
    recalling: root.petRecalling,
    releasing: root.petReleasing
  })
  readonly property var media: shell && shell.serviceFor ? shell.serviceFor("omarchy.media") : null
  readonly property bool mediaPlaying: {
    // The shell's active player may be a stale, paused one — never let it
    // veto a browser that is actually playing. Any playing player counts.
    if (root.media && root.media.activePlayer && root.media.activePlayer.isPlaying)
      return true
    var list = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].isPlaying) return true
    }
    return false
  }
  onMediaPlayingChanged: {
    if (!root.mediaPlaying) {
      root.audioPeak = 0
      root.playingStoppedMs = Date.now()
    } else {
      root.touchActivity()
    }
  }
  readonly property string mediaTrackKey: {
    var player = null
    if (root.media && root.media.activePlayer && root.media.activePlayer.isPlaying)
      player = root.media.activePlayer
    if (!player) {
      var list = Mpris.players ? Mpris.players.values : []
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].isPlaying) {
          player = list[i]
          break
        }
      }
    }
    if (!player) return ""
    var title = String(player.trackTitle || player.title || "")
    var artist = String(player.trackArtist || player.artists || player.artist || "")
    if (!title && !artist) return ""
    return title + "|" + artist
  }
  property real playingStoppedMs: 0

  onMediaTrackKeyChanged: {
    var key = root.mediaTrackKey
    if (key && root.lastTrackKey && key !== root.lastTrackKey && root.mediaPlaying) {
      root.applyCareStats(Model.applyCareAction(root.careSnapshot(), "track", Date.now(), root.careEnv()), true)
      root.saveCare()
      root.celebrate()
    }
    if (key) root.lastTrackKey = key
  }
  readonly property var careLive: ({
    hunger: root.careHunger,
    hygiene: root.careHygiene,
    mood: root.careMood,
    energy: root.careEnergy,
    health: root.careHealth,
    attention: root.careAttention,
    bond: root.careBond,
    weight: root.careWeight,
    bornMs: root.careBornMs,
    updatedMs: root.careUpdatedMs,
    activity: root.petActivity
  })
  readonly property var careFlags: Model.careFlags(root.careLive)
  readonly property string mode: Model.resolveMode({
    sick: root.nowMs < root.sickUntil,
    filthy: !!root.careFlags.filthy,
    unhealthy: !!root.careFlags.ill,
    stunned: root.nowMs < root.stunUntil,
    grumpy: root.nowMs < root.grumpyUntil,
    greet: root.nowMs < root.greetUntil,
    happy: root.nowMs < root.happyUntil,
    wash: root.nowMs < root.washUntil,
    eat: root.nowMs < root.eatUntil,
    lowMood: !!root.careFlags.sad,
    neglected: !!root.careFlags.neglected,
    lonely: !!root.careFlags.lonely,
    exhausted: !!root.careFlags.criticalTired,
    sleep: root.lastActiveMs > 0 && (root.nowMs - root.lastActiveMs) >= Model.sleepAfterMsFor(root.careLive),
    sneak: Model.sneakWindow(root.winW, root.winH),
    night: Model.isNightHour(new Date(root.nowMs || Date.now())),
    mediaPlaying: root.mediaPlaying
      || (root.playingStoppedMs > 0 && root.nowMs - root.playingStoppedMs < 2000),
    working: root.mediaBusy || root.generating,
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
    return home + "/.local/share/higgsfield-omagotchi"
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
    root.hasCustomAvatar = true
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
          root.hasCustomAvatar = true
          root.atlasRev += 1
          return
        }
      } catch (e) {}
    }
    if (root.lastResultPath) {
      root.applyGeneratedSheet(root.lastResultPath)
      return
    }
    root.hasCustomAvatar = false
    // No generated sheet: fall back to the bundled one, which normalizeAtlas
    // supplies from Model.defaultAtlas().
    root.atlasSpec = null
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
    root.refreshCredits()
    root.refreshAvatars()
    if (root.mediaPrice < 0) root.refreshMediaPrice()
    authProc.command = ["python3", "-u", root.filePath("scripts/runtime.py"), "auth-status", "--out", root.dataDir()]
    authProc.running = false
    authProc.running = true
  }

  function login() {
    if (root.loggingIn) return "busy"
    if (!root.hfPath) {
      root.pendingLogin = true
      root.loggingIn = true
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
    root.photoRev += 1
    root.lastError = ""
    root.generateStatus = ""
    return "ok"
  }

  function pickPhoto() {
    if (root.picking || root.generating || root.capturing) return "busy"
    root.picking = true
    root.lastError = ""
    pickProc.command = ["bash", root.filePath("scripts/pick-image.sh")]
    pickProc.running = false
    pickProc.running = true
    return "started"
  }

  function captureWebcam() {
    if (root.picking || root.generating || root.capturing) return "busy"
    root.capturing = true
    root.lastError = ""
    root.generateStatus = "Smile…"
    captureProc.command = [
      "python3", "-u", root.filePath("scripts/capture-webcam.py"),
      "--out", root.dataDir() + "/webcam.jpg"
    ]
    captureProc.running = false
    captureProc.running = true
    return "started"
  }

  function onCapturedPhoto(code, stdout, stderr) {
    root.capturing = false
    root.generateStatus = ""
    root.onPickedPhoto(code, stdout, stderr)
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
      root.generateStatus = ""
    }
  }

  function touchActivity() {
    root.lastActiveMs = Date.now()
  }

  function careSnapshot() {
    return {
      hunger: root.careHunger,
      hygiene: root.careHygiene,
      mood: root.careMood,
      energy: root.careEnergy,
      health: root.careHealth,
      attention: root.careAttention,
      bond: root.careBond,
      weight: root.careWeight,
      bornMs: root.careBornMs,
      updatedMs: root.careUpdatedMs,
      docked: root.petDocked,
      activity: root.petActivity
    }
  }

  function careEnv() {
    var now = Date.now()
    return {
      sleeping: root.mode === "sleep",
      night: Model.isNightHour(new Date(root.nowMs || now)),
      mediaPlaying: root.mediaPlaying,
      sneakWindow: Model.sneakWindow(root.winW, root.winH),
      audioPeak: root.audioPeak,
      active: root.lastActiveMs > 0 && (now - root.lastActiveMs) < 20000
    }
  }

  function applyCareStats(stats, persist) {
    var s = Model.normalizeCareStats(stats, Date.now())
    root.careHunger = s.hunger
    root.careHygiene = s.hygiene
    root.careMood = s.mood
    root.careEnergy = s.energy
    root.careHealth = s.health
    root.careAttention = s.attention
    root.careBond = s.bond
    root.careWeight = s.weight
    root.careBornMs = s.bornMs
    root.careUpdatedMs = s.updatedMs
    if (s.activity) root.petActivity = s.activity
    if (!root.petRecalling && !root.petReleasing)
      root.petDocked = !!s.docked
    if (persist) root.careDirty = true
  }

  function saveCare() {
    if (!root.careLoaded) return
    if (!root.careDirty) return
    root.careDirty = false
    var payload = JSON.stringify(root.careSnapshot())
    careSaveProc.command = [
      "python3", "-c",
      "import json,sys\nfrom pathlib import Path\np = Path(sys.argv[1])\np.parent.mkdir(parents=True, exist_ok=True)\np.write_text(json.dumps(json.loads(sys.argv[2]), indent=2) + '\\n')\n",
      root.dataDir() + "/care.json",
      payload
    ]
    careSaveProc.running = false
    careSaveProc.running = true
  }

  function loadCare() {
    careReadProc.command = ["cat", root.dataDir() + "/care.json"]
    careReadProc.running = false
    careReadProc.running = true
  }

  function applyCareText(text) {
    var data = null
    try {
      data = JSON.parse(String(text || "").replace(/^\s+|\s+$/g, ""))
    } catch (e) {
      data = null
    }
    var now = Date.now()
    var s = Model.reviveCareStats(Model.decayCareStats(data || Model.defaultCareStats(now), now, {
      night: Model.isNightHour(new Date(now)),
      mediaPlaying: false,
      sneakWindow: false,
      active: false
    }), now)
    root.applyCareStats(s, false)
    root.petDocked = !!s.docked
    root.sickUntil = 0
    root.stunUntil = 0
    root.pendingWash = false
    root.careDirty = false
    root.careLoaded = true
  }

  function say(text, ms) {
    root.sayText = String(text || "")
    var dur = Number(ms)
    if (!isFinite(dur) || dur <= 0) dur = 4000
    root.sayUntil = Date.now() + dur
  }

  function celebrate(ms) {
    root.touchActivity()
    var dur = Number(ms)
    if (!isFinite(dur) || dur <= 0) dur = Model.happyDurationMs(root.careSnapshot())
    root.happyUntil = Date.now() + dur
  }

  function feedPet() {
    root.applyCareStats(Model.applyCareAction(root.careSnapshot(), "feed", Date.now(), root.careEnv()), true)
    root.eatUntil = Date.now() + Model.careDurationMs()
    root.touchActivity()
    root.saveCare()
    return "eat"
  }

  function washPet() {
    root.applyCareStats(Model.applyCareAction(root.careSnapshot(), "wash", Date.now(), root.careEnv()), true)
    root.washUntil = Date.now() + Model.careDurationMs()
    root.pendingWash = false
    root.touchActivity()
    root.saveCare()
    return "wash"
  }

  function playPet() {
    root.applyCareStats(Model.applyCareAction(root.careSnapshot(), "play", Date.now(), root.careEnv()), true)
    root.celebrate(Model.happyDurationMs(root.careSnapshot()))
    root.saveCare()
    return "play"
  }

  function tickCare() {
    var now = Date.now()
    root.applyCareStats(Model.decayCareStats(root.careSnapshot(), now, root.careEnv()), false)
    if (root.pendingWash && root.nowMs >= root.sickUntil && root.nowMs >= root.stunUntil
        && root.nowMs >= root.washUntil && root.nowMs >= root.eatUntil) {
      root.pendingWash = false
      root.washUntil = now + Model.careDurationMs()
      root.touchActivity()
    }
    root.careSaveTicks += 1
    if (root.careSaveTicks >= 60) {
      root.careSaveTicks = 0
      root.careDirty = true
      root.saveCare()
    }
  }

  function onPetClicked() {
    root.touchActivity()
    root.applyCareStats(Model.applyCareAction(root.careSnapshot(), "pet", Date.now(), root.careEnv()), true)
    root.saveCare()
    var next = Model.nextClickState({
      lastClickMs: root.lastClickMs,
      clickBurst: root.clickBurst,
      greetUntil: root.greetUntil,
      grumpyUntil: root.grumpyUntil
    }, Date.now(), root.careSnapshot())
    root.lastClickMs = next.lastClickMs
    root.clickBurst = next.clickBurst
    root.greetUntil = next.greetUntil
    root.grumpyUntil = next.grumpyUntil
    return root.nowMs < root.grumpyUntil ? "grumpy" : "greet"
  }

  function onPetDragged() {
    root.touchActivity()
    var now = Date.now()
    if (now - root.lastDragCareMs < 1500) return "drag"
    root.lastDragCareMs = now
    root.applyCareStats(Model.applyCareAction(root.careSnapshot(), "drag", now, root.careEnv()), true)
    root.saveCare()
    return "drag"
  }

  function onLanded(dropPx) {
    root.touchActivity()
    root.applyCareStats(Model.applyCareAction(root.careSnapshot(), "mess", Date.now(), root.careEnv()), true)
    root.saveCare()
    var drop = Number(dropPx)
    if (!isFinite(drop)) drop = 0
    if (drop >= Model.tripDropPx()) {
      var hitMs = Date.now()
      root.stunUntil = hitMs + 2200
      root.sickUntil = hitMs + 4700
      root.pendingWash = true
      return "collapse"
    }
    if (drop >= 8) {
      root.sickUntil = Date.now() + 4500
      root.pendingWash = true
      return "sick"
    }
    return root.mode
  }

  function onDroppedFromHeight() {
    return root.onLanded(Model.tripDropPx())
  }

  function recallPet() {
    if (root.petDocked && !root.petReleasing) return "docked"
    if (root.petRecalling) return "busy"
    root.petReleasing = false
    root.petRecalling = true
    return "recall"
  }

  function finishRecall() {
    if (!root.petRecalling && root.petDocked) return "docked"
    root.petRecalling = false
    root.petReleasing = false
    root.petDocked = true
    root.careDirty = true
    root.saveCare()
    return "docked"
  }

  function releasePet() {
    if (!root.petDocked && !root.petRecalling && !root.petReleasing) return "desktop"
    root.petRecalling = false
    root.petDocked = false
    root.petReleasing = true
    root.careDirty = true
    root.saveCare()
    return "release"
  }

  function finishRelease() {
    root.petReleasing = false
    root.petDocked = false
    return "desktop"
  }

  function setActivity(mode) {
    var next = String(mode || "").toLowerCase()
    if (next !== "standing" && next !== "walking" && next !== "running") return "unknown activity"
    root.petActivity = next
    root.careDirty = true
    root.saveCare()
    root.wander = Model.pickWander(Math.random(), root.careSnapshot())
    return next
  }

  function toggleDock() {
    if (root.petDocked || root.petRecalling) return root.releasePet()
    return root.recallPet()
  }

  function toggleCollapsed() {
    root.collapsed = !root.collapsed
    return root.collapsed ? "collapsed" : "expanded"
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
    root.generateSteps = smoke ? 4 : 38
    root.generatePercent = 0
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
      root.lastError = ""
      root.generateStatus = "Avatar ready"
      root.generatePercent = 100
      root.failStreak = 0
      root.applyGeneratedSheet(parsed.path, parsed.atlasSpec)
      root.refreshAvatars()
      root.celebrate(4000)
      return
    }
    var err = parsed.error || ("generate failed (" + code + ")")
    root.failStreak += 1
    root.lastError = err
    root.generateStatus = ""
    root.generatePercent = 0
  }

  function generateMedia(prompt) {
    if (root.mediaBusy) return "busy"
    if (!root.loggedIn) {
      root.mediaError = root.hfPath
        ? "Log in in the browser window that just opened, then press Generate again."
        : "Setting up the Higgsfield CLI — the login browser opens when it finishes."
      root.login()
      return "login"
    }
    if (root.mediaPrice < 0) root.refreshMediaPrice()
    var p = String(prompt || "").trim()
    var refs = Array.isArray(root.mediaRefs) ? root.mediaRefs.slice() : []
    if (!p && refs.length === 0) {
      root.mediaError = "Add a prompt or a reference image"
      return "empty"
    }
    root.mediaError = ""
    root.mediaBusy = true
    root.mediaStatus = "Submitting…"
    var ratio = root.mediaKind === "video" ? root.mediaRatioVideo : root.mediaRatioImage
    var cmd = ["python3", "-u", root.filePath("scripts/generate-media.py"),
               "--out", root.dataDir(), "--plugin-root", root.pluginRoot(),
               "--kind", root.mediaKind, "--prompt", p, "--ratio", ratio]
    if (root.mediaKind === "video") cmd = cmd.concat(["--duration", root.mediaDuration])
    for (var i = 0; i < refs.length; i++) cmd = cmd.concat(["--image", refs[i]])
    mediaProc.command = cmd
    mediaProc.running = false
    mediaProc.running = true
    return "started"
  }

  function setMediaOption(name, value) {
    var v = String(value || "")
    if (name === "ratio") {
      if (root.mediaKind === "video") root.mediaRatioVideo = v
      else root.mediaRatioImage = v
    } else if (name === "duration") {
      root.mediaDuration = v
    } else {
      return "unknown"
    }
    root.mediaPrice = -1
    root.refreshMediaPrice()
    return v
  }

  function removeMediaRef(index) {
    var i = Number(index)
    var next = Array.isArray(root.mediaRefs) ? root.mediaRefs.slice() : []
    if (!isFinite(i) || i < 0 || i >= next.length) return "bad index"
    next.splice(i, 1)
    root.mediaRefs = next
    return "ok"
  }

  function clearMediaRefs() {
    root.mediaRefs = []
    return "ok"
  }

  function cancelMedia() {
    if (!root.mediaBusy) return "idle"
    root.mediaBusy = false
    mediaProc.running = false
    root.mediaStatus = ""
    root.mediaError = ""
    return "canceled"
  }

  function onMediaLine(line) {
    var parsed = null
    try { parsed = JSON.parse(String(line || "")) } catch (e) { return }
    if (!parsed) return
    if (parsed.t === "mstatus") {
      root.mediaStatus = String(parsed.label || "")
      return
    }
    if (parsed.ok === true && parsed.path) {
      root.mediaBusy = false
      root.mediaStatus = ""
      root.lastMediaPath = String(parsed.path)
      root.lastMediaThumb = String(parsed.thumb || parsed.path)
      root.lastMediaRev += 1
      root.refreshCredits()
      root.celebrate(4000)
      root.say("Generation is ready", 4000)
      return
    }
    if (parsed.ok === false) {
      root.mediaBusy = false
      root.mediaStatus = ""
      var classified = Model.classifyGenerateError(String(parsed.error || ""))
      root.mediaError = classified.message || "generate failed"
    }
  }

  function pickMediaRef() {
    if (root.mediaPicking || root.mediaBusy) return "busy"
    root.mediaPicking = true
    mediaRefProc.command = ["bash", root.filePath("scripts/pick-image.sh")]
    mediaRefProc.running = false
    mediaRefProc.running = true
    return "started"
  }

  function openMediaFolder() {
    openMediaProc.command = ["xdg-open", root.dataDir() + "/media"]
    openMediaProc.running = false
    openMediaProc.running = true
    return "ok"
  }

  function refreshCredits() {
    if (!root.hfPath) return
    creditsProc.command = [root.hfPath, "account", "status", "--json"]
    creditsProc.running = false
    creditsProc.running = true
  }

  function setMediaKind(kind) {
    var next = String(kind || "").toLowerCase()
    if (next !== "image" && next !== "video") return "unknown"
    if (root.mediaKind !== next) {
      root.mediaKind = next
      root.mediaPrice = -1
      root.refreshMediaPrice()
    }
    return next
  }

  // Ask the CLI what the selected generation would cost, without creating
  // a job. The placeholder prompt only shapes the estimate request.
  function refreshMediaPrice() {
    if (!root.hfPath) return
    var cmd = [root.hfPath, "generate", "cost"]
    if (root.mediaKind === "video")
      cmd = cmd.concat(["seedance_2_0_mini", "--prompt", "estimate",
                        "--aspect_ratio", root.mediaRatioVideo, "--resolution", "720p",
                        "--duration", String(root.mediaDuration).replace(/s$/, "") || "5",
                        "--generate_audio", "false"])
    else
      cmd = cmd.concat(["nano_banana_2", "--prompt", "estimate",
                        "--aspect_ratio", root.mediaRatioImage, "--resolution", "1k"])
    cmd.push("--json")
    priceProc.command = cmd
    priceProc.running = false
    priceProc.running = true
  }

  function refreshAvatars() {
    avatarsListProc.command = ["python3", "-u", root.filePath("scripts/avatars.py"),
                               "list", "--out", root.dataDir(),
                               "--plugin-root", root.pluginRoot()]
    avatarsListProc.running = false
    avatarsListProc.running = true
  }

  function setAvatar(dir) {
    var d = String(dir || "")
    if (!d || root.avatarSwitching || root.generating) return "busy"
    root.avatarSwitching = true
    avatarActivateProc.command = ["python3", "-u", root.filePath("scripts/avatars.py"),
                                  "activate", "--out", root.dataDir(), "--dir", d]
    avatarActivateProc.running = false
    avatarActivateProc.running = true
    return "started"
  }

  function cancelGenerate() {
    if (root.loggingIn || root.pendingLogin) {
      root.pendingLogin = false
      root.loggingIn = false
      loginProc.running = false
      root.generateStatus = ""
      return "canceled"
    }
    if (!root.generating) return "idle"
    // Flip the flag first so genProc.onExited treats the kill as silence,
    // not as a failed run.
    root.generating = false
    genProc.running = false
    root.generateStatus = ""
    root.generatePercent = 0
    root.generateStep = 0
    root.generateSteps = 0
    root.lastError = ""
    return "canceled"
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
    if (parsed.text) {
      var low = parsed.text.toLowerCase()
      if (low.indexOf("ended with status") >= 0 || low.indexOf("error") >= 0)
        return
      root.generateStatus = parsed.text
    }
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
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.tickCare()
  }

  Timer {
    interval: 1400
    running: root.petRecalling
    repeat: false
    onTriggered: if (root.petRecalling) root.finishRecall()
  }

  Timer {
    interval: 1600
    running: root.petReleasing
    repeat: false
    onTriggered: if (root.petReleasing) root.finishRelease()
  }

  Timer {
    interval: 80
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    id: wanderTimer
    interval: 2800
    running: root.petOnDesktop && !root.petRecalling
    repeat: true
    onTriggered: {
      if (root.mode === "sleep") {
        root.wander = "idle"
        wanderTimer.interval = 4000
        return
      }
      root.wander = Model.pickWander(Math.random(), root.careSnapshot())
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
    enabled: root.mediaPlaying && root.petOnDesktop
    onPeakChanged: root.audioPeak = peakMon.peak
  }

  Process {
    id: ensureProc
    stdout: SplitParser {
      onRead: function(line) { root.applyRuntime(line) }
    }
    onExited: function() {
      if (!root.pendingLogin) return
      root.pendingLogin = false
      root.loggingIn = false
      if (root.hfPath) {
        root.login()
      } else {
        root.generateStatus = ""
        root.lastError = "Could not install the Higgsfield CLI — check your network and retry."
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
    id: captureProc
    stdout: StdioCollector {
      id: captureOut
    }
    stderr: StdioCollector {
      id: captureErr
    }
    onExited: function(exitCode) {
      root.onCapturedPhoto(exitCode, captureOut.text, captureErr.text)
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
    id: careSaveProc
  }

  Process {
    id: careReadProc
    stdout: StdioCollector {
      id: careReadOut
      waitForEnd: true
    }
    onExited: root.applyCareText(careReadOut.text)
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
          root.generateStatus = "Avatar ready"
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
        if (root.pluginRegistry.inBar("higgsfield-omagotchi")) return
      } catch (e) {}
    }
    barChipProc.command = ["python3", "-u", root.filePath("scripts/ensure-bar-chip.py")]
    barChipProc.running = false
    barChipProc.running = true
  }

  Process {
    id: barChipProc
  }

  Process {
    id: avatarsListProc
    stdout: StdioCollector {
      id: avatarsListOut
    }
    onExited: function() {
      var parsed = null
      try { parsed = JSON.parse(String(avatarsListOut.text || "").trim()) } catch (e) { return }
      if (parsed && parsed.ok && Array.isArray(parsed.avatars))
        root.avatarList = parsed.avatars
    }
  }

  Process {
    id: avatarActivateProc
    stdout: StdioCollector {
      id: avatarActivateOut
    }
    onExited: function() {
      root.avatarSwitching = false
      var parsed = null
      try { parsed = JSON.parse(String(avatarActivateOut.text || "").trim()) } catch (e) { return }
      if (!parsed || !parsed.ok) return
      if (parsed.default) {
        root.atlasSpec = null
        root.lastResultPath = ""
        root.hasCustomAvatar = false
        root.atlasRev += 1
        return
      }
      if (parsed.atlas && parsed.atlas.file) {
        root.atlasSpec = parsed.atlas
        root.lastResultPath = String(parsed.atlas.file)
        root.hasCustomAvatar = true
        root.atlasRev += 1
      }
    }
  }

  Process {
    id: mediaProc
    stdout: SplitParser {
      onRead: function(line) { root.onMediaLine(line) }
    }
    onExited: function(exitCode) {
      if (!root.mediaBusy) return
      root.mediaBusy = false
      root.mediaStatus = ""
      if (root.mediaError === "")
        root.mediaError = "generate failed (" + exitCode + ")"
    }
  }

  Process {
    id: mediaRefProc
    stdout: StdioCollector {
      id: mediaRefOut
    }
    onExited: function() {
      root.mediaPicking = false
      var path = String(mediaRefOut.text || "").trim().split("\n").pop() || ""
      if (Model.isImagePath(path)) {
        var next = Array.isArray(root.mediaRefs) ? root.mediaRefs.slice() : []
        if (next.indexOf(path) < 0 && next.length < 50) next.push(path)
        root.mediaRefs = next
        root.mediaError = ""
      }
    }
  }

  Process {
    id: openMediaProc
  }

  Process {
    id: priceProc
    stdout: StdioCollector {
      id: priceOut
    }
    onExited: function() {
      var found = Model.costFromBlob(priceOut.text)
      if (found >= 0) root.mediaPrice = found
    }
  }

  Process {
    id: creditsProc
    stdout: StdioCollector {
      id: creditsOut
    }
    onExited: function() {
      var found = Model.creditsFromBlob(creditsOut.text)
      if (found >= 0) root.credits = found
    }
  }

  Timer {
    interval: 400
    running: true
    repeat: false
    onTriggered: root.ensureBarChip()
  }

  // Keyboard presses are the pet's pulse: they hold off sleep, mark the
  // desktop as active for care decay, and send him walking while you type.
  // watch-keys.py needs the user in the `input` group; without it the
  // script just idles and the pet lives by media and panel clicks alone.
  function onKeyActivity() {
    var now = Date.now()
    if (now - root.lastActiveMs < 400) return
    root.lastActiveMs = now
    if (!Model.isMoveMode(root.wander)) root.wander = "walk"
  }

  Process {
    id: keysProc
    command: ["python3", "-u", root.filePath("scripts/watch-keys.py")]
    stdout: SplitParser {
      onRead: function() { root.onKeyActivity() }
    }
  }

  // The watcher never exits on its own, so an exit means it died (missing
  // python3, revoked device access). Nudge it back up, gently.
  Timer {
    interval: 15000
    running: !keysProc.running
    repeat: true
    onTriggered: keysProc.running = true
  }

  // Before the omagotchi rename the plugin id was higgsfield.signals, and the
  // data directory is named after the id: every avatar, clip and care file on
  // this machine sits under the old name. Move it across once, and hold the
  // rest of startup until that exits, so loadAtlas() and friends look in the
  // right place on the very first run after an update.
  Process {
    id: migrateProc
    command: ["sh", "-c",
      "old=\"$HOME/.local/share/higgsfield.signals\"; "
      + "new=\"$HOME/.local/share/higgsfield-omagotchi\"; "
      + "if [ -d \"$old\" ] && [ ! -e \"$new\" ]; then mv \"$old\" \"$new\"; fi; "
      + "exit 0"]
    onExited: function() { root.startup() }
  }

  Component.onCompleted: migrateProc.running = true

  function startup() {
    var now = Date.now()
    root.touchActivity()
    root.lastEatMs = now
    root.lastWashMs = now
    root.loadAtlas()
    root.loadCare()
    var lastMedia = root.readJsonFile("file://" + root.dataDir() + "/media/last.json")
    if (lastMedia && String(lastMedia.path || "").charAt(0) === "/") {
      root.lastMediaPath = String(lastMedia.path)
      root.lastMediaThumb = String(lastMedia.thumb || lastMedia.path)
    }
    root.wander = Model.pickWander(Math.random(), root.careSnapshot())
    root.ensureRuntime()
    root.refreshAvatars()
    keysProc.running = true
  }

  IpcHandler {
    target: "higgsfield-omagotchi"

    function ping(): string { return "ok" }
    function collapse(): string { return root.toggleCollapsed() }
    function generateSprite(imagePath: string): string { return root.generateSprite(imagePath, "", false) }
    function generateSpriteSmoke(imagePath: string): string { return root.generateSprite(imagePath, "", true) }
    function pickPhoto(): string { return root.pickPhoto() }
    function captureWebcam(): string { return root.captureWebcam() }
    function setPhoto(path: string): string { return root.setPhoto(path) }
    function login(): string { return root.login() }
    function retry(): string { return root.retryGenerate() }
    function feed(): string { return root.feedPet() }
    function wash(): string { return root.washPet() }
    function play(): string { return root.playPet() }
    function hide(): string { return root.recallPet() }
    function release(): string { return root.releasePet() }
    function toggleDock(): string { return root.toggleDock() }
    function setActivity(mode: string): string { return root.setActivity(mode) }
    function cancel(): string { return root.cancelGenerate() }
    function generateMedia(prompt: string): string { return root.generateMedia(prompt) }
    function setMediaKind(kind: string): string { return root.setMediaKind(kind) }
    function openMedia(): string { return root.openMediaFolder() }
    function setAvatar(dir: string): string { return root.setAvatar(dir) }
    function cancelMedia(): string { return root.cancelMedia() }
  }
}
