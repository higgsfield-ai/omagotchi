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

var PLACEMENTS = ["pointer", "focus", "pin"]

function normalizePlacement(value) {
  var name = String(value === undefined || value === null ? "" : value)
  if (name === "true" || name === "pointer") return "pointer"
  if (name === "false" || name === "pin") return "pin"
  if (name === "focus") return "focus"
  return "focus"
}

function isClickThrough(placement) {
  var name = normalizePlacement(placement)
  return name === "pointer" || name === "focus"
}

function parseActiveWindow(jsonText) {
  var raw = String(jsonText === undefined || jsonText === null ? "" : jsonText).trim()
  if (!raw || raw.charAt(0) !== "{") return null
  var win
  try {
    win = JSON.parse(raw)
  } catch (e) {
    return null
  }
  if (!win || !win.at || !win.size) return null
  var x = Number(win.at[0])
  var y = Number(win.at[1])
  var width = Number(win.size[0])
  var height = Number(win.size[1])
  if (!isFinite(x) || !isFinite(y) || !isFinite(width) || !isFinite(height)) return null
  if (width <= 0 || height <= 0) return null
  return { x: x, y: y, w: width, h: height }
}

function focusAnchor(box, petSize, inset) {
  var size = Number(petSize)
  var pad = Number(inset)
  if (!isFinite(size) || size <= 0) size = 96
  if (!isFinite(pad) || pad < 0) pad = 12
  if (!box) return { x: 0, y: 0 }
  return {
    x: box.x + box.w - size - pad,
    y: box.y + box.h - size - pad
  }
}

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
    PLACEMENTS: PLACEMENTS,
    normalizePlacement: normalizePlacement,
    isClickThrough: isClickThrough,
    parseActiveWindow: parseActiveWindow,
    focusAnchor: focusAnchor,
    normalizeAtlas: normalizeAtlas,
    isKnownMode: isKnownMode,
    isOneShot: isOneShot,
    isLoop: isLoop,
    rowForMode: rowForMode,
    resolveMode: resolveMode
  }
}
