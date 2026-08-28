// Tamagotchi helpers. Qt-free so it can be tested under node.

function defaultAtlas() {
  return {
    file: "atlas.png",
    cellWidth: 80,
    cellHeight: 98,
    columns: 13,
    rows: 6,
    fps: 10,
    scale: 1,
    modes: {
      walk: { row: 0, start: 0, count: 13 },
      idle: { row: 1, start: 7, count: 4 },
      dance: { row: 2, start: 8, count: 3 },
      flip: { row: 4, start: 0, count: 6 },
      collapse: { row: 1, start: 6, count: 1 },
      drag: { row: 2, start: 1, count: 1 }
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
    scale: isFinite(scale) && scale > 0 ? scale : d.scale,
    modes: {
      walk: cloneMode(modes.walk, d.modes.walk),
      idle: cloneMode(modes.idle, d.modes.idle),
      dance: cloneMode(modes.dance, d.modes.dance),
      flip: cloneMode(modes.flip, d.modes.flip),
      collapse: cloneMode(modes.collapse, d.modes.collapse),
      drag: cloneMode(modes.drag, d.modes.drag)
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
    displayWidth: Math.round(spec.cellWidth * spec.scale),
    displayHeight: Math.round(spec.cellHeight * spec.scale)
  }
}

function resolveMode(opts) {
  var keysRecent = !!(opts && opts.keysRecent)
  var playing = !!(opts && opts.mediaPlaying)
  var peak = Number(opts && opts.audioPeak)
  if (!isFinite(peak) || peak < 0) peak = 0
  if (opts && opts.collapsed) return "collapse"
  if (opts && opts.dragging) return "drag"
  if (keysRecent) return "walk"
  if (playing && peak > 0.55) return "flip"
  if (playing) return "dance"
  return "idle"
}

function clamp(n, lo, hi) {
  var v = Number(n)
  var a = Number(lo)
  var b = Number(hi)
  if (!isFinite(v)) v = 0
  if (!isFinite(a)) a = 0
  if (!isFinite(b)) b = 0
  if (b < a) {
    var swap = a
    a = b
    b = swap
  }
  if (v < a) return a
  if (v > b) return b
  return v
}

function clampPetX(x, petW, winW) {
  var w = Number(petW)
  var box = Number(winW)
  if (!isFinite(w) || w < 0) w = 0
  if (!isFinite(box) || box < 0) box = 0
  return clamp(x, 0, Math.max(0, box - w))
}

function petBottomY(petH, winH, pad) {
  var p = Number(pad)
  var h = Number(petH)
  var box = Number(winH)
  if (!isFinite(p)) p = 4
  if (!isFinite(h)) h = 0
  if (!isFinite(box)) box = 0
  return Math.max(0, box - h - p)
}

function clipWindowRect(win, screenW, screenH) {
  var x = Number(win && win.x)
  var y = Number(win && win.y)
  var w = Number(win && win.w)
  var h = Number(win && win.h)
  var sw = Number(screenW)
  var sh = Number(screenH)
  if (!isFinite(x)) x = 0
  if (!isFinite(y)) y = 0
  if (!isFinite(w)) w = 0
  if (!isFinite(h)) h = 0
  if (!isFinite(sw) || sw < 0) sw = 0
  if (!isFinite(sh) || sh < 0) sh = 0
  var x1 = Math.max(0, x)
  var y1 = Math.max(0, y)
  var x2 = Math.min(x + w, sw)
  var y2 = Math.min(y + h, sh)
  return {
    x: x1,
    y: y1,
    w: Math.max(0, x2 - x1),
    h: Math.max(0, y2 - y1)
  }
}

function asList(raw) {
  if (!raw) return []
  if (Array.isArray(raw)) return raw
  var n = Number(raw.length)
  if (!isFinite(n) || n <= 0) return []
  var out = []
  for (var i = 0; i < n; i++) {
    if (raw[i] !== undefined) out.push(raw[i])
  }
  return out
}

function pickMonitor(mons, win) {
  var list = asList(mons)
  var i
  if (win) {
    for (i = 0; i < list.length; i++) {
      if (Number(list[i].id) === Number(win.monitor) || String(list[i].name) === String(win.monitor))
        return list[i]
    }
  }
  for (i = 0; i < list.length; i++) {
    if (list[i] && list[i].focused) return list[i]
  }
  return list[0] || null
}

function focusWindow(monitorsRaw, windowRaw) {
  var mons = []
  try {
    mons = asList(JSON.parse(monitorsRaw || "[]"))
  } catch (e) {
    mons = []
  }
  var win = null
  try {
    var parsed = JSON.parse(windowRaw || "null")
    if (parsed && typeof parsed === "object" && parsed.at && parsed.size) win = parsed
  } catch (e) {
    win = null
  }
  var mon = pickMonitor(mons, win)
  if (!mon) return { monitor: "", x: 0, y: 0, w: 0, h: 0 }
  var mx = Number(mon.x) || 0
  var my = Number(mon.y) || 0
  var mw = Number(mon.width) || 0
  var mh = Number(mon.height) || 0
  var name = String(mon.name || "")
  if (win) {
    return {
      monitor: name,
      x: Number(win.at[0]) - mx,
      y: Number(win.at[1]) - my,
      w: Number(win.size[0]),
      h: Number(win.size[1])
    }
  }
  return { monitor: name, x: 0, y: 0, w: mw, h: mh }
}

function danceFps(peak) {
  var p = Number(peak)
  if (!isFinite(p) || p < 0) p = 0
  if (p > 1) p = 1
  return Math.round(7 + p * 16)
}

function trimPrompt(raw) {
  return String(raw || "").replace(/^\s+|\s+$/g, "")
}

function parseGenerateResult(raw) {
  var text = String(raw || "").replace(/^\s+|\s+$/g, "")
  if (!text) return { ok: false, error: "empty output", path: "", url: "" }
  var lines = text.split(/\n/)
  var last = lines[lines.length - 1]
  try {
    var data = JSON.parse(last)
    if (data && data.ok) {
      return {
        ok: true,
        path: String(data.path || ""),
        url: String(data.url || ""),
        atlas: String(data.atlas || ""),
        model: String(data.model || ""),
        error: ""
      }
    }
    return {
      ok: false,
      error: String((data && data.error) || "generate failed"),
      path: "",
      url: ""
    }
  } catch (e) {
    return { ok: false, error: last.slice(0, 400), path: "", url: "" }
  }
}

function isImagePath(path) {
  var p = String(path || "").toLowerCase().split("?")[0]
  return /\.(png|jpe?g|webp|gif)$/.test(p)
}

function atlasImageSource(file) {
  var f = String(file || "")
  if (!f) return ""
  if (f.indexOf("file://") === 0) return f
  if (f.charAt(0) === "/") return "file://" + f
  return f
}

function fileUrlToPath(url) {
  var s = String(url || "")
  if (s.indexOf("file://") === 0) s = s.slice(7)
  return decodeURIComponent(s)
}

function fileBaseName(path) {
  var p = String(path || "").replace(/\\/g, "/")
  var i = p.lastIndexOf("/")
  return i >= 0 ? p.slice(i + 1) : p
}

function parseGenLine(raw) {
  var s = String(raw || "")
  if (s.charAt(0) !== "{") return { kind: "text", text: s }
  try {
    var data = JSON.parse(s)
    if (data && data.t === "progress") {
      var steps = Number(data.steps) || 0
      var step = Number(data.step) || 0
      var percent = Number(data.percent)
      if (!isFinite(percent) || percent < 0) {
        percent = steps > 0 ? Math.round(100 * step / steps) : 0
      }
      if (percent > 100) percent = 100
      return {
        kind: "progress",
        phase: String(data.phase || ""),
        step: step,
        steps: steps,
        percent: percent,
        label: String(data.label || "")
      }
    }
    if (data && typeof data.ok === "boolean") {
      return { kind: "result", raw: s }
    }
  } catch (e) {}
  return { kind: "text", text: s }
}

if (typeof module !== "undefined") {
  module.exports = {
    defaultAtlas: defaultAtlas,
    normalizeAtlas: normalizeAtlas,
    framesForMode: framesForMode,
    resolveMode: resolveMode,
    danceFps: danceFps,
    clamp: clamp,
    clampPetX: clampPetX,
    petBottomY: petBottomY,
    clipWindowRect: clipWindowRect,
    focusWindow: focusWindow,
    trimPrompt: trimPrompt,
    parseGenerateResult: parseGenerateResult,
    isImagePath: isImagePath,
    atlasImageSource: atlasImageSource,
    fileBaseName: fileBaseName,
    fileUrlToPath: fileUrlToPath,
    parseGenLine: parseGenLine
  }
}
