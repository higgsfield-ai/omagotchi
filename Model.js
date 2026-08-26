// Pure mode + atlas math. Qt-free so it can be tested under node.

var DEFAULT_ATLAS = {
  cell: 64,
  columns: 8,
  fps: 8,
  placeholder: true,
  modes: {
    idle: 0,
    hurry: 1,
    dance: 2,
    sleep: 3,
    happy: 4,
    angry: 5,
    wave: 6
  }
}

var MODE_ORDER = ["idle", "hurry", "dance", "sleep", "happy", "angry", "wave"]

var LOOP_MODES = {
  idle: true,
  hurry: true,
  dance: true,
  sleep: true,
  happy: true
}

var ONESHOT_MODES = {
  angry: true,
  wave: true
}

var HURRY_KEYS_PER_SEC = 4

function normalizeAtlas(raw) {
  var src = raw && typeof raw === "object" ? raw : {}
  var modes = {}
  var srcModes = src.modes && typeof src.modes === "object" ? src.modes : DEFAULT_ATLAS.modes
  for (var i = 0; i < MODE_ORDER.length; i++) {
    var name = MODE_ORDER[i]
    var row = Number(srcModes[name])
    modes[name] = isFinite(row) && row >= 0 ? Math.floor(row) : DEFAULT_ATLAS.modes[name]
  }
  var cell = Number(src.cell)
  var columns = Number(src.columns)
  var fps = Number(src.fps)
  return {
    cell: isFinite(cell) && cell > 0 ? Math.floor(cell) : DEFAULT_ATLAS.cell,
    columns: isFinite(columns) && columns > 0 ? Math.floor(columns) : DEFAULT_ATLAS.columns,
    fps: isFinite(fps) && fps > 0 ? fps : DEFAULT_ATLAS.fps,
    placeholder: src.placeholder === true,
    modes: modes
  }
}

function isKnownMode(mode) {
  return MODE_ORDER.indexOf(String(mode || "")) !== -1
}

function isOneShot(mode) {
  return ONESHOT_MODES[String(mode || "")] === true
}

function isLoop(mode) {
  return LOOP_MODES[String(mode || "")] === true
}

function rowForMode(mode, atlas) {
  var sheet = normalizeAtlas(atlas)
  var name = isKnownMode(mode) ? String(mode) : "idle"
  return sheet.modes[name]
}

function resolveMode(signals) {
  var s = signals && typeof signals === "object" ? signals : {}
  if (isKnownMode(s.override)) return String(s.override)
  if (s.locked === true) return "sleep"
  var rate = Number(s.keysPerSec)
  if (isFinite(rate) && rate >= HURRY_KEYS_PER_SEC) return "hurry"
  if (s.mediaPlaying === true) return "dance"
  return "idle"
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULT_ATLAS: DEFAULT_ATLAS,
    MODE_ORDER: MODE_ORDER,
    HURRY_KEYS_PER_SEC: HURRY_KEYS_PER_SEC,
    normalizeAtlas: normalizeAtlas,
    isKnownMode: isKnownMode,
    isOneShot: isOneShot,
    isLoop: isLoop,
    rowForMode: rowForMode,
    resolveMode: resolveMode
  }
}
