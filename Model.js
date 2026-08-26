// 37signals catalog helpers. Qt-free so it can be tested under node.

function loadSignals(raw) {
  if (!raw) return []
  if (Array.isArray(raw)) return raw
  // QML JSON.parse can yield an array-like object that fails Array.isArray.
  var n = Number(raw.length)
  if (!isFinite(n) || n <= 0) return []
  var out = []
  for (var i = 0; i < n; i++) {
    if (raw[i] !== undefined) out.push(raw[i])
  }
  return out
}

function formatNumber(id) {
  var n = Number(id)
  if (!isFinite(n) || n < 0) return "00"
  return (n < 10 ? "0" : "") + String(Math.floor(n))
}

function pickRandom(signals, exceptId) {
  var list = loadSignals(signals)
  var filtered = []
  var except = exceptId === undefined || exceptId === null ? undefined : Number(exceptId)
  for (var i = 0; i < list.length; i++) {
    if (except !== undefined && Number(list[i].id) === except) continue
    filtered.push(list[i])
  }
  if (filtered.length === 0) filtered = list
  if (filtered.length === 0) return null
  return filtered[Math.floor(Math.random() * filtered.length)]
}

function wrapLine(text, width) {
  var max = Number(width)
  if (!isFinite(max) || max < 8) max = 52
  var words = String(text || "").replace(/\s+/g, " ").trim().split(" ")
  if (words.length === 1 && words[0] === "") return ""
  var lines = []
  var line = ""
  for (var i = 0; i < words.length; i++) {
    var word = words[i]
    var next = line ? line + " " + word : word
    if (next.length > max && line) {
      lines.push(line)
      line = word
    } else {
      line = next
    }
  }
  if (line) lines.push(line)
  return lines.join("\n")
}

function formatScreensaver(id, title, body) {
  return [
    "37signals",
    "",
    formatNumber(id) + ".",
    String(title || ""),
    "",
    wrapLine(body, 52)
  ].join("\n")
}

function screensaverSeconds(config, fallback) {
  var n = Number(config && config.screensaver)
  if (isFinite(n) && n > 0) return Math.floor(n)
  var fb = Number(fallback)
  return isFinite(fb) && fb > 0 ? Math.floor(fb) : 150
}

// Default DHH racing-suit sheet. A generator later overwrites atlas.png + atlas.json.
function defaultAtlas() {
  return {
    file: "atlas.png",
    cellWidth: 64,
    cellHeight: 87,
    columns: 16,
    rows: 5,
    fps: 10,
    scale: 3,
    modes: {
      walk: { row: 0, start: 0, count: 16 },
      idle: { row: 1, start: 8, count: 8 },
      dance: { row: 2, start: 11, count: 4 },
      flip: { row: 3, start: 7, count: 4 }
    }
  }
}

function cloneMode(mode, fallback) {
  var src = mode || fallback || { row: 0, start: 0, count: 8 }
  var row = Number(src.row)
  var start = Number(src.start)
  var count = Number(src.count)
  return {
    row: isFinite(row) && row >= 0 ? Math.floor(row) : 0,
    start: isFinite(start) && start >= 0 ? Math.floor(start) : 0,
    count: isFinite(count) && count > 0 ? Math.floor(count) : 8
  }
}

function normalizeAtlas(raw) {
  var d = defaultAtlas()
  if (!raw) return d
  var cellW = Number(raw.cellWidth || raw.cell)
  var cellH = Number(raw.cellHeight || raw.cell)
  var columns = Number(raw.columns)
  var rows = Number(raw.rows)
  var fps = Number(raw.fps)
  var scale = Number(raw.scale)
  var modes = raw.modes || {}
  return {
    file: String(raw.file || d.file),
    cellWidth: isFinite(cellW) && cellW > 0 ? Math.floor(cellW) : d.cellWidth,
    cellHeight: isFinite(cellH) && cellH > 0 ? Math.floor(cellH) : d.cellHeight,
    columns: isFinite(columns) && columns > 0 ? Math.floor(columns) : d.columns,
    rows: isFinite(rows) && rows > 0 ? Math.floor(rows) : d.rows,
    fps: isFinite(fps) && fps > 0 ? Math.floor(fps) : d.fps,
    scale: isFinite(scale) && scale > 0 ? Math.floor(scale) : d.scale,
    modes: {
      walk: cloneMode(modes.walk, d.modes.walk),
      idle: cloneMode(modes.idle, d.modes.idle),
      dance: cloneMode(modes.dance, d.modes.dance),
      flip: cloneMode(modes.flip, d.modes.flip)
    }
  }
}

function framesForMode(atlas, modeName) {
  var spec = normalizeAtlas(atlas)
  var key = String(modeName || "idle")
  var mode = spec.modes[key] || spec.modes.idle
  return {
    frameX: mode.start * spec.cellWidth,
    frameY: mode.row * spec.cellHeight,
    frameCount: mode.count,
    frameWidth: spec.cellWidth,
    frameHeight: spec.cellHeight,
    frameRate: spec.fps,
    displayWidth: spec.cellWidth * spec.scale,
    displayHeight: spec.cellHeight * spec.scale
  }
}

function resolveMode(opts) {
  var keysRecent = !!(opts && opts.keysRecent)
  var playing = !!(opts && opts.mediaPlaying)
  var peak = Number(opts && opts.audioPeak)
  if (!isFinite(peak) || peak < 0) peak = 0
  if (keysRecent) return "walk"
  if (playing && peak > 0.55) return "flip"
  if (playing) return "dance"
  return "idle"
}

function danceFps(peak) {
  var p = Number(peak)
  if (!isFinite(p) || p < 0) p = 0
  if (p > 1) p = 1
  return Math.round(7 + p * 16)
}

if (typeof module !== "undefined") {
  module.exports = {
    loadSignals: loadSignals,
    formatNumber: formatNumber,
    pickRandom: pickRandom,
    wrapLine: wrapLine,
    formatScreensaver: formatScreensaver,
    screensaverSeconds: screensaverSeconds,
    defaultAtlas: defaultAtlas,
    normalizeAtlas: normalizeAtlas,
    framesForMode: framesForMode,
    resolveMode: resolveMode,
    danceFps: danceFps
  }
}
