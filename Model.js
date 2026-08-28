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

function generatedModeMap() {
  return {
    walk: { row: 0, start: 0, count: 16 },
    idle: { row: 1, start: 0, count: 8 },
    look: { row: 1, start: 8, count: 8 },
    collapse: { row: 2, start: 8, count: 8 },
    drag: { row: 3, start: 0, count: 8 },
    greet: { row: 3, start: 8, count: 8 },
    dance: { row: 4, start: 0, count: 16 },
    flip: { row: 5, start: 0, count: 16 },
    run: { row: 5, start: 0, count: 16 },
    crawl: { row: 7, start: 0, count: 16 },
    grumpy: { row: 9, start: 8, count: 8 },
    sick: { row: 10, start: 8, count: 8 }
  }
}

function generatedAtlas(file) {
  var modes = generatedModeMap()
  return {
    file: String(file || ""),
    cellWidth: 80,
    cellHeight: 80,
    columns: 16,
    rows: 12,
    fps: 10,
    scale: 1,
    modes: {
      walk: modes.walk,
      idle: modes.idle,
      look: modes.look,
      collapse: modes.collapse,
      drag: modes.drag,
      greet: modes.greet,
      dance: modes.dance,
      flip: modes.flip,
      run: modes.run,
      crawl: modes.crawl,
      grumpy: modes.grumpy,
      sick: modes.sick
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
  var gen = generatedModeMap()
  var bundled = d.modes
  var useGen = isFinite(rows) && rows >= 12
  var fb = useGen ? gen : bundled
  return {
    file: String(raw.file || d.file),
    cellWidth: isFinite(cellW) && cellW > 0 ? Math.floor(cellW) : d.cellWidth,
    cellHeight: isFinite(cellH) && cellH > 0 ? Math.floor(cellH) : d.cellHeight,
    columns: isFinite(columns) && columns > 0 ? Math.floor(columns) : d.columns,
    rows: isFinite(rows) && rows > 0 ? Math.floor(rows) : d.rows,
    fps: isFinite(fps) && fps > 0 ? Math.floor(fps) : d.fps,
    scale: isFinite(scale) && scale > 0 ? scale : d.scale,
    modes: {
      walk: cloneMode(modes.walk, fb.walk || bundled.walk),
      idle: cloneMode(modes.idle, fb.idle || bundled.idle),
      look: cloneMode(modes.look, fb.look || bundled.idle),
      collapse: cloneMode(modes.collapse, fb.collapse || bundled.collapse),
      drag: cloneMode(modes.drag, fb.drag || bundled.drag),
      greet: cloneMode(modes.greet, fb.greet || bundled.idle),
      dance: cloneMode(modes.dance, fb.dance || bundled.dance),
      flip: cloneMode(modes.flip, fb.flip || bundled.flip),
      run: cloneMode(modes.run, fb.run || fb.flip || bundled.flip),
      crawl: cloneMode(modes.crawl, fb.crawl || bundled.walk),
      grumpy: cloneMode(modes.grumpy, fb.grumpy || bundled.idle),
      sick: cloneMode(modes.sick, fb.sick || bundled.idle)
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

function isMoveMode(mode) {
  return mode === "walk" || mode === "crawl" || mode === "run"
}

function movePace(mode) {
  if (mode === "crawl") return { step: 3, interval: 140 }
  if (mode === "run") return { step: 14, interval: 48 }
  return { step: 8, interval: 90 }
}

function resolveMode(opts) {
  var o = opts || {}
  var playing = !!o.mediaPlaying
  var peak = Number(o.audioPeak)
  if (!isFinite(peak) || peak < 0) peak = 0
  if (o.dragging) return "drag"
  if (o.falling || o.sick) return "sick"
  if (o.grumpy) return "grumpy"
  if (o.greet) return "greet"
  var wander = String(o.wander || "idle")
  if (isMoveMode(wander) || wander === "look") return wander
  if (playing && peak > 0.55) return "flip"
  if (playing) return "dance"
  return "idle"
}

function pickWander(rand) {
  var r = Number(rand)
  if (!isFinite(r) || r < 0) r = 0
  if (r > 1) r = 1
  if (r < 0.26) return "walk"
  if (r < 0.46) return "crawl"
  if (r < 0.68) return "run"
  if (r < 0.84) return "idle"
  return "look"
}

function nextClickState(state, nowMs) {
  var last = Number(state && state.lastClickMs) || 0
  var burst = Number(state && state.clickBurst) || 0
  var now = Number(nowMs)
  if (!isFinite(now)) now = 0
  if (now - last < 550) burst += 1
  else burst = 1
  if (burst >= 3) {
    return {
      clickBurst: 0,
      lastClickMs: now,
      greetUntil: 0,
      grumpyUntil: now + 2800
    }
  }
  return {
    clickBurst: burst,
    lastClickMs: now,
    greetUntil: now + 1800,
    grumpyUntil: Number(state && state.grumpyUntil) || 0
  }
}

function shouldFall(petY, floorY, minDrop) {
  var y = Number(petY)
  var floor = Number(floorY)
  var min = Number(minDrop)
  if (!isFinite(y) || !isFinite(floor)) return false
  if (!isFinite(min) || min < 0) min = 12
  return floor - y > min
}

function stepFall(y, vel, floorY, gravity, maxVel) {
  var g = Number(gravity)
  var cap = Number(maxVel)
  if (!isFinite(g) || g <= 0) g = 1.35
  if (!isFinite(cap) || cap <= 0) cap = 24
  var v = Number(vel)
  if (!isFinite(v)) v = 0
  v += g
  if (v > cap) v = cap
  var ny = Number(y)
  if (!isFinite(ny)) ny = 0
  ny += v
  var floor = Number(floorY)
  if (!isFinite(floor)) floor = 0
  if (ny >= floor) {
    return { pos: floor, vel: 0, landed: true }
  }
  return { pos: ny, vel: v, landed: false }
}

function fallDurationMs(drop) {
  var d = Number(drop)
  if (!isFinite(d) || d < 0) d = 0
  var ms = Math.round(240 + Math.sqrt(d) * 38)
  if (ms < 280) ms = 280
  if (ms > 1100) ms = 1100
  return ms
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

function parseJsonBlob(raw) {
  var text = String(raw || "").replace(/^\s+|\s+$/g, "")
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch (e) {}
  var start = text.indexOf("{")
  var end = text.lastIndexOf("}")
  if (start >= 0 && end > start) {
    try {
      return JSON.parse(text.slice(start, end + 1))
    } catch (e2) {}
  }
  return null
}

function errorTextFromNode(node) {
  if (node == null) return ""
  if (typeof node === "string") return node
  if (typeof node !== "object") return String(node)
  var msg = node.message || node.error || node.detail || node.reason || ""
  if (typeof msg === "string" && msg) return msg
  if (msg && typeof msg === "object") return errorTextFromNode(msg)
  var kind = node.error_type || node.type || node.code || ""
  return kind ? String(kind) : ""
}

function actionTypesFromNode(node) {
  var out = []
  if (!node || typeof node !== "object") return out
  var lists = [node.actions, node.input && node.input.actions]
  for (var i = 0; i < lists.length; i++) {
    var list = lists[i]
    if (!list || typeof list.length !== "number") continue
    for (var j = 0; j < list.length; j++) {
      var t = list[j] && list[j].type
      if (t) out.push(String(t))
    }
  }
  return out
}

function classifyGenerateError(raw) {
  var text = String(raw || "")
  var data = parseJsonBlob(text)
  var errObj = data && typeof data.error === "object" ? data.error : null
  var detail = data && typeof data.detail === "object" ? data.detail : null
  var kindToken = ""
  var message = ""
  var actionTypes = []
  if (data) {
    kindToken = String(data.error_type || data.type || (errObj && (errObj.error_type || errObj.type)) || (detail && detail.error_type) || "")
    message = errorTextFromNode(errObj) || errorTextFromNode(detail) || errorTextFromNode(data)
    actionTypes = actionTypesFromNode(data).concat(actionTypesFromNode(errObj), actionTypesFromNode(detail))
    if (typeof data.error === "string" && !message) message = data.error
  }
  if (!message) message = text
  var blob = (kindToken + " " + actionTypes.join(" ") + " " + message + " " + text).toLowerCase()
  var kind = "retry"
  var title = "Generate failed"
  var actions = ["retry"]
  if (/upgrade_plan|upgrade plan|\bupgrade\b|minimum_.*plan|higher .{0,24}plan|requires a higher/.test(blob)) {
    kind = "upgrade"
    title = "Upgrade required"
    if (!message || /^[a-z0-9_]+$/i.test(message))
      message = "This generation needs a higher Higgsfield plan."
    actions = ["retry", "upgrade"]
  } else if (/not_enough_credits|out_of_credits|credits_exhausted|not enough credits|out of credits/.test(blob)) {
    kind = "credits"
    title = "Out of credits"
    message = "Not enough credits for this generate. Top up or upgrade, then retry."
    actions = ["retry", "upgrade"]
  } else if (/rate_limit|429|too many/.test(blob)) {
    kind = "rate"
    title = "Rate limited"
    message = "Higgsfield asked us to wait. Retry in a moment."
  } else if (/503|502|504|service unavailable|bad gateway|higgsfield api error/.test(blob)) {
    kind = "unavailable"
    title = "Higgsfield is busy"
    message = "The Higgsfield API is temporarily unavailable. Retry in a moment."
  } else if (/ended with status|status ["']failed["']/.test(blob)) {
    kind = "job"
    title = "Generation failed"
    message = "Higgsfield's model failed this run. Retry — failed jobs usually refund credits."
  } else if (!message || message === "[object Object]") {
    message = "Generate failed. Retry, or upgrade your plan if Higgsfield asked for that."
    actions = ["retry", "upgrade"]
  }
  if (message.length > 280) message = message.slice(0, 280)
  return {
    kind: kind,
    title: title,
    message: message,
    actions: actions,
    showUpgrade: kind === "upgrade" || kind === "credits",
    showTitle: kind === "upgrade" || kind === "credits" || kind === "unavailable",
    pricingUrl: "https://higgsfield.ai/pricing"
  }
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
        atlasSpec: data.atlas_spec && typeof data.atlas_spec === "object" ? data.atlas_spec : null,
        model: String(data.model || ""),
        error: ""
      }
    }
    var classified = classifyGenerateError(last)
    var err = typeof data.error === "string" && data.error
      ? data.error
      : (classified.kind !== "retry" ? classified.kind + ": " + classified.message : classified.message)
    return {
      ok: false,
      error: err || "generate failed",
      path: "",
      url: ""
    }
  } catch (e) {
    return { ok: false, error: last.slice(0, 400), path: "", url: "" }
  }
}

function isImagePath(path) {
  var p = String(path || "").toLowerCase().split("?")[0]
  return /\.(png|jpe?g|webp|gif|bmp)$/.test(p)
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
    isMoveMode: isMoveMode,
    movePace: movePace,
    pickWander: pickWander,
    nextClickState: nextClickState,
    shouldFall: shouldFall,
    stepFall: stepFall,
    fallDurationMs: fallDurationMs,
    danceFps: danceFps,
    clamp: clamp,
    clampPetX: clampPetX,
    petBottomY: petBottomY,
    clipWindowRect: clipWindowRect,
    focusWindow: focusWindow,
    trimPrompt: trimPrompt,
    parseGenerateResult: parseGenerateResult,
    classifyGenerateError: classifyGenerateError,
    generatedAtlas: generatedAtlas,
    isImagePath: isImagePath,
    atlasImageSource: atlasImageSource,
    fileBaseName: fileBaseName,
    fileUrlToPath: fileUrlToPath,
    parseGenLine: parseGenLine
  }
}
