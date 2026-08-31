// Tamagotchi helpers. Qt-free so it can be tested under node.

// The sheet that ships with the plugin. Same 16x12 layout the generator
// writes, so a fresh install already has a pet to put on the desktop.
function defaultAtlas() {
  return generatedAtlas("default-sheet.png")
}

function generatedModeMap() {
  return {
    walk: { row: 0, start: 0, count: 16 },
    idle: { row: 1, start: 0, count: 8 },
    look: { row: 1, start: 8, count: 8 },
    sleep: { row: 2, start: 0, count: 8 },
    collapse: { row: 2, start: 8, count: 8 },
    drag: { row: 3, start: 0, count: 8 },
    greet: { row: 3, start: 8, count: 8 },
    dance: { row: 4, start: 0, count: 16 },
    flip: { row: 5, start: 0, count: 16 },
    run: { row: 5, start: 0, count: 16 },
    sneak: { row: 6, start: 0, count: 16 },
    fall: { row: 7, start: 0, count: 16 },
    happy: { row: 9, start: 0, count: 8 },
    watch: { row: 9, start: 8, count: 8 },
    eat: { row: 10, start: 0, count: 8 },
    sick: { row: 10, start: 8, count: 8 },
    wash: { row: 11, start: 0, count: 8 }
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
    fps: 6,
    scale: 1,
    modes: {
      walk: modes.walk,
      idle: modes.idle,
      look: modes.look,
      sleep: modes.sleep,
      collapse: modes.collapse,
      drag: modes.drag,
      greet: modes.greet,
      dance: modes.dance,
      flip: modes.flip,
      run: modes.run,
      sneak: modes.sneak,
      fall: modes.fall,
      happy: modes.happy,
      watch: modes.watch,
      eat: modes.eat,
      sick: modes.sick,
      wash: modes.wash
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
  var fb = d.modes
  return {
    file: String(raw.file || d.file),
    cellWidth: isFinite(cellW) && cellW > 0 ? Math.floor(cellW) : d.cellWidth,
    cellHeight: isFinite(cellH) && cellH > 0 ? Math.floor(cellH) : d.cellHeight,
    columns: isFinite(columns) && columns > 0 ? Math.floor(columns) : d.columns,
    rows: isFinite(rows) && rows > 0 ? Math.floor(rows) : d.rows,
    fps: isFinite(fps) && fps > 0 ? Math.floor(fps) : d.fps,
    scale: isFinite(scale) && scale > 0 ? scale : d.scale,
    modes: {
      walk: cloneMode(modes.walk, fb.walk),
      idle: cloneMode(modes.idle, fb.idle),
      look: cloneMode(modes.look, fb.look || fb.idle),
      sleep: cloneMode(modes.sleep, fb.sleep || fb.collapse),
      collapse: cloneMode(modes.collapse, fb.collapse),
      drag: cloneMode(modes.drag, fb.drag),
      greet: cloneMode(modes.greet, fb.greet || fb.idle),
      dance: cloneMode(modes.dance, fb.dance),
      flip: cloneMode(modes.flip, fb.flip),
      run: cloneMode(modes.run, fb.run || fb.flip),
      sneak: cloneMode(modes.sneak, fb.sneak || fb.walk),
      fall: cloneMode(modes.fall, fb.fall || fb.drag),
      trip: cloneMode(modes.trip, fb.trip || fb.sick || fb.idle),
      happy: cloneMode(modes.happy, fb.happy || fb.greet || fb.idle),
      grumpy: cloneMode(modes.grumpy, fb.grumpy || fb.idle),
      watch: cloneMode(modes.watch, fb.watch || fb.look || fb.idle),
      eat: cloneMode(modes.eat, fb.eat || fb.idle),
      sick: cloneMode(modes.sick, fb.sick || fb.idle),
      wash: cloneMode(modes.wash, fb.wash || fb.idle)
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
  return mode === "walk" || mode === "run" || mode === "sneak"
}

function movePace(mode, stats) {
  var pace
  if (mode === "sneak") pace = { step: 4, interval: 120 }
  else if (mode === "run") pace = { step: 14, interval: 48 }
  else pace = { step: 8, interval: 90 }
  if (!stats) return pace
  var s = normalizeCareStats(stats)
  var step = pace.step
  var interval = pace.interval
  if (s.weight > 70) {
    step = Math.max(2, step - 3)
    interval += 28
  } else if (s.weight < 35) {
    step += 2
    interval = Math.max(40, interval - 10)
  }
  if (s.energy < 25) {
    step = Math.max(2, Math.round(step * 0.65))
    interval += 36
  } else if (s.energy > 80 && mode === "run") {
    step += 2
    interval = Math.max(36, interval - 8)
  }
  if (s.health < 25) {
    step = Math.max(2, step - 2)
    interval += 20
  }
  return { step: step, interval: interval }
}

function sleepAfterMs() {
  return 60000
}

function tripDropPx() {
  return 120
}

function eatEveryMs() {
  return 25 * 60 * 1000
}

function washEveryMs() {
  return 3 * 60 * 60 * 1000
}

function happyDurationMs(stats) {
  var base = 3200
  if (!stats) return base
  var s = normalizeCareStats(stats)
  return Math.round(base + s.bond * 16)
}

function careDurationMs() {
  return 4500
}

function clampStat(n) {
  var v = Number(n)
  if (!isFinite(v)) return 0
  if (v < 0) return 0
  if (v > 100) return 100
  return v
}

function defaultCareStats(nowMs) {
  var now = Number(nowMs)
  if (!isFinite(now) || now <= 0) now = Date.now()
  return {
    hunger: 82,
    hygiene: 82,
    mood: 82,
    energy: 78,
    health: 88,
    attention: 70,
    bond: 8,
    weight: 50,
    bornMs: now,
    updatedMs: now,
    docked: false,
    activity: "walking"
  }
}

// A saved timestamp more than ~400 days behind now, or ahead of it, is
// corruption rather than history — int32 wrap-around used to fold saved
// epochs back to the 1970s, and one such value reads as maximum decay on
// every tick. Fall back instead of decaying against it.
function saneEpochMs(value, nowMs, fallback) {
  var n = Number(value)
  var now = Number(nowMs)
  if (!isFinite(n) || n <= 0) return fallback
  if (n > now + 60000) return fallback
  if (now - n > 34560000000) return fallback
  return n
}

function normalizeCareStats(raw, nowMs) {
  var d = defaultCareStats(nowMs)
  if (!raw || typeof raw !== "object") return d
  var born = saneEpochMs(raw.bornMs, nowMs, 0)
  if (born <= 0) {
    born = saneEpochMs(raw.updatedMs, nowMs, d.bornMs)
  }
  return {
    hunger: clampStat(raw.hunger != null ? raw.hunger : d.hunger),
    hygiene: clampStat(raw.hygiene != null ? raw.hygiene : d.hygiene),
    mood: clampStat(raw.mood != null ? raw.mood : d.mood),
    energy: clampStat(raw.energy != null ? raw.energy : d.energy),
    health: clampStat(raw.health != null ? raw.health : d.health),
    attention: clampStat(raw.attention != null ? raw.attention : d.attention),
    bond: clampStat(raw.bond != null ? raw.bond : d.bond),
    weight: clampStat(raw.weight != null ? raw.weight : d.weight),
    bornMs: born,
    updatedMs: saneEpochMs(raw.updatedMs, nowMs, d.updatedMs),
    docked: !!(raw.docked),
    activity: raw.activity === "standing" || raw.activity === "running" ? raw.activity : "walking"
  }
}

function careDecayRates() {
  return {
    hunger: 8.5,
    hygiene: 5.5,
    mood: 6.5,
    energyAwake: 7,
    energySleep: 48,
    energyNight: 24,
    healthHurt: 10,
    healthRest: 8,
    healthIdle: 2,
    attentionIdle: 9,
    attentionActive: 4,
    attentionMusic: 6,
    bond: 0.12,
    weightDrift: 0.8
  }
}

function decayCareStats(stats, nowMs, env) {
  var now = Number(nowMs)
  if (!isFinite(now) || now <= 0) now = Date.now()
  var s = normalizeCareStats(stats, now)
  var prev = Number(s.updatedMs)
  if (!isFinite(prev) || prev <= 0) prev = now
  var dtH = (now - prev) / 3600000
  if (dtH <= 0) {
    s.updatedMs = now
    return s
  }
  if (dtH > 48) dtH = 48
  var e = env || {}
  var sleeping = !!e.sleeping
  var night = !!e.night
  var playing = !!e.mediaPlaying
  var active = !!e.active
  var peak = Number(e.audioPeak)
  if (!isFinite(peak) || peak < 0) peak = 0
  var rates = careDecayRates()
  var hunger = clampStat(s.hunger - rates.hunger * dtH)
  var hygiene = clampStat(s.hygiene - rates.hygiene * dtH)
  var moodDrain = playing ? rates.mood * 0.55 : rates.mood
  var mood = clampStat(s.mood - moodDrain * dtH)
  var energy = s.energy
  if (sleeping) energy += rates.energySleep * dtH
  else if (night) energy += rates.energyNight * dtH
  else {
    energy -= rates.energyAwake * dtH
    if (playing && peak > 0.4) energy -= 3 * dtH
  }
  energy = clampStat(energy)
  var health = s.health
  if (hunger < 12 || hygiene < 12) health -= rates.healthHurt * dtH
  else if (hunger > 50 && hygiene > 60) {
    if (sleeping || night) health += rates.healthRest * dtH
    else health += rates.healthIdle * dtH
  }
  health = clampStat(health)
  var attention = s.attention
  if (active) attention += rates.attentionActive * dtH
  else if (sleeping) attention -= rates.attentionIdle * 0.35 * dtH
  else attention -= rates.attentionIdle * dtH
  if (playing) attention += rates.attentionMusic * dtH
  attention = clampStat(attention)
  var bond = clampStat(s.bond + rates.bond * dtH)
  var weight = s.weight
  if (weight > 50) weight -= rates.weightDrift * dtH
  else if (weight < 50) weight += rates.weightDrift * 0.5 * dtH
  weight = clampStat(weight)
  return {
    hunger: hunger,
    hygiene: hygiene,
    mood: mood,
    energy: energy,
    health: health,
    attention: attention,
    bond: bond,
    weight: weight,
    bornMs: s.bornMs,
    updatedMs: now,
    docked: !!s.docked,
    activity: s.activity
  }
}

function applyCareAction(stats, action, nowMs, env) {
  var now = Number(nowMs)
  if (!isFinite(now) || now <= 0) now = Date.now()
  var s = decayCareStats(stats, now, env)
  var act = String(action || "")
  if (act === "feed") {
    var stuffed = s.hunger >= 75
    s.hunger = clampStat(s.hunger + 30)
    s.mood = clampStat(s.mood + 8)
    s.weight = clampStat(s.weight + (stuffed ? 10 : 5))
    s.energy = clampStat(s.energy + 4)
    s.health = clampStat(s.health + 2)
    s.bond = clampStat(s.bond + 2)
  } else if (act === "wash") {
    s.hygiene = clampStat(s.hygiene + 34)
    s.mood = clampStat(s.mood + 6)
    s.health = clampStat(s.health + 12)
    s.bond = clampStat(s.bond + 2)
  } else if (act === "play") {
    s.mood = clampStat(s.mood + 28)
    s.hunger = clampStat(s.hunger - 5)
    s.hygiene = clampStat(s.hygiene - 4)
    s.energy = clampStat(s.energy - 10)
    s.attention = clampStat(s.attention + 18)
    s.weight = clampStat(s.weight - 5)
    s.health = clampStat(s.health + 2)
    s.bond = clampStat(s.bond + 3)
  } else if (act === "pet") {
    s.mood = clampStat(s.mood + 10)
    s.attention = clampStat(s.attention + 12)
    s.bond = clampStat(s.bond + 1)
  } else if (act === "mess") {
    s.hygiene = clampStat(s.hygiene - 10)
    s.mood = clampStat(s.mood - 6)
    s.health = clampStat(s.health - 8)
    s.attention = clampStat(s.attention - 4)
  } else if (act === "drag") {
    s.attention = clampStat(s.attention + 6)
    s.energy = clampStat(s.energy - 2)
  } else if (act === "track") {
    s.attention = clampStat(s.attention + 10)
    s.mood = clampStat(s.mood + 4)
  }
  s.updatedMs = now
  return s
}

function careFlags(stats) {
  var s = normalizeCareStats(stats)
  return {
    hungry: s.hunger < 30,
    dirty: s.hygiene < 30,
    sad: s.mood < 30,
    filthy: s.hygiene < 12,
    starving: s.hunger < 12,
    tired: s.energy < 40,
    exhausted: s.energy < 18,
    criticalTired: s.energy < 8,
    energetic: s.energy > 78,
    ill: s.health < 22,
    critical: s.health < 12,
    lonely: s.attention < 28,
    neglected: s.attention < 12,
    loved: s.attention > 75,
    heavy: s.weight > 70,
    light: s.weight < 35,
    bonded: s.bond >= 65
  }
}

function sleepAfterMsFor(stats) {
  var flags = careFlags(stats)
  if (flags.criticalTired || flags.exhausted) return 8000
  if (flags.starving || flags.sad || flags.neglected) return 28000
  if (flags.hungry || flags.dirty || flags.tired || flags.lonely) return 42000
  if (flags.bonded) return 78000
  return sleepAfterMs()
}

function ageLabel(bornMs, nowMs) {
  var born = Number(bornMs)
  var now = Number(nowMs)
  if (!isFinite(born) || born <= 0) return "newborn"
  if (!isFinite(now) || now <= 0) now = Date.now()
  var ms = now - born
  if (ms < 0) ms = 0
  var hours = Math.floor(ms / 3600000)
  if (hours < 1) {
    var mins = Math.max(0, Math.floor(ms / 60000))
    return mins < 3 ? "newborn" : mins + "m"
  }
  if (hours < 24) return hours + "h"
  var days = Math.floor(hours / 24)
  return days + "d " + (hours % 24) + "h"
}

function flipPeak(stats) {
  return 0.55
}

function dancePeak(stats) {
  // The stat-gated threshold (0.12 for a neglected pet) plus a silent peak
  // monitor meant "nothing happens" when music played. Playing media is
  // reason enough to dance; peaks only decide dance vs flip.
  return 0
}

function isNightHour(input) {
  var h
  if (typeof input === "number" && isFinite(input)) h = Math.floor(input)
  else if (input && typeof input.getHours === "function") h = input.getHours()
  else h = new Date().getHours()
  if (!isFinite(h)) h = 0
  return h >= 21 || h < 7
}

function sneakWindow(w, h) {
  var width = Number(w)
  var height = Number(h)
  if (!isFinite(width) || !isFinite(height) || width <= 0 || height <= 0) return false
  return width < 520 || height < 380 || (width * height) < 280000
}

function resolveMode(opts) {
  var o = opts || {}
  var playing = !!o.mediaPlaying
  var peak = Number(o.audioPeak)
  if (!isFinite(peak) || peak < 0) peak = 0
  var flipAt = Number(o.flipPeak)
  if (!isFinite(flipAt)) flipAt = 0.55
  var danceAt = Number(o.dancePeak)
  if (!isFinite(danceAt) || danceAt < 0) danceAt = 0
  if (o.dragging) return "drag"
  if (o.falling) return "fall"
  if (o.stunned) return "collapse"
  if (o.sick) return "sick"
  if (o.grumpy) return "grumpy"
  if (o.greet) return "greet"
  if (o.happy) return "happy"
  if (o.wash) return "wash"
  if (o.eat) return "eat"
  if (o.unhealthy || o.filthy) return "sick"
  if (o.neglected || o.lowMood) return "grumpy"
  if ((o.sleep || o.exhausted) && !playing) return "sleep"
  // Media preempts wandering. Music means the dance row, full stop — the
  // flip row is drawn as a sprint and kept reading as "running in place"
  // whenever loudness routed to it. Speech sits him down with the laptop.
  if (playing && o.speech) return "watch"
  if (playing) return "dance"
  var wander = String(o.wander || "idle")
  if (isMoveMode(wander)) {
    if (o.sneak) return "sneak"
    return wander
  }
  if (wander === "look") return "look"
  if (o.lonely) return "look"
  return "idle"
}

function wanderWeights(stats) {
  var walk = 30
  var run = 24
  var idle = 20
  var look = 16
  if (!stats) return { walk: walk, run: run, idle: idle, look: look }
  var s = normalizeCareStats(stats)
  if (s.energy < 30) {
    run = 0
    idle += 18
    walk = Math.max(4, walk - 8)
  } else if (s.energy > 78) {
    run += 16
    idle = Math.max(4, idle - 6)
  }
  if (s.weight > 70) {
    run = Math.max(0, run - 14)
    idle += 12
    walk = Math.max(4, walk - 4)
  } else if (s.weight < 35) {
    run += 10
  }
  if (s.health < 30) {
    run = 0
    idle += 12
  }
  if (s.attention < 28) {
    look += 18
    walk = Math.max(4, walk - 8)
  }
  // The user-picked activity level bounds how mobile he gets: standing
  // never moves, walking never runs, running does it all.
  if (s.activity === "standing") {
    idle += walk + Math.round(run / 2)
    look += Math.round(run / 2)
    walk = 0
    run = 0
  } else if (s.activity === "walking") {
    walk += Math.round(run / 2)
    idle += Math.round(run / 2)
    run = 0
  }
  return { walk: walk, run: run, idle: idle, look: look }
}

function pickWander(rand, stats) {
  var r = Number(rand)
  if (!isFinite(r) || r < 0) r = 0
  if (r > 1) r = 1
  if (!stats) {
    if (r < 0.34) return "walk"
    if (r < 0.64) return "run"
    if (r < 0.84) return "idle"
    return "look"
  }
  var w = wanderWeights(stats)
  var total = w.walk + w.run + w.idle + w.look
  if (total <= 0) return "idle"
  var x = r * total
  if (x < w.walk) return "walk"
  x -= w.walk
  if (x < w.run) return "run"
  x -= w.run
  if (x < w.idle) return "idle"
  return "look"
}

// Beat detection on the peak envelope: a beat is the level jumping well
// above its own running average, with a 250ms refractory so 16th-note
// noise cannot machine-gun the frames (~240bpm ceiling).
function beatStep(state, peak, nowMs) {
  var st = state || {}
  var ema = isFinite(Number(st.ema)) ? Number(st.ema) : 0
  var last = isFinite(Number(st.lastBeatMs)) ? Number(st.lastBeatMs) : 0
  var now = Number(nowMs) || 0
  var p = Number(peak)
  if (!isFinite(p) || p < 0) p = 0
  var beat = false
  if (p > 0.06 && p > ema * 1.35 && now - last > 250) {
    beat = true
    last = now
  }
  return { ema: ema * 0.88 + p * 0.12, lastBeatMs: last, beat: beat }
}

// Speech vs music from raw peak samples: talk is bursty (syllable and
// sentence pauses collapse the level constantly), music sustains energy.
// The gap ratio over a rolling window separates them without any FFT.
// Hysteresis (enter 0.30 / exit 0.20) keeps him from flip-flopping, and a
// silent monitor (p90 ~ 0) reads as "unknown" -> music -> dance, which
// preserves the old behavior when peaks are unavailable.
function speechLike(samples, wasSpeech) {
  var arr = []
  for (var i = 0; i < (samples || []).length; i++) {
    var v = Number(samples[i])
    if (isFinite(v) && v >= 0) arr.push(v)
  }
  if (arr.length < 20) return !!wasSpeech
  var sorted = arr.slice().sort(function(a, b) { return a - b })
  var p90 = sorted[Math.floor(0.9 * (sorted.length - 1))]
  if (p90 < 0.03) return false
  var gapThresh = p90 * 0.18
  var gaps = 0
  for (var j = 0; j < arr.length; j++) {
    if (arr[j] < gapThresh) gaps++
  }
  var ratio = gaps / arr.length
  return wasSpeech ? ratio > 0.2 : ratio > 0.3
}

function podcastMeta(title, album) {
  var blob = (String(title || "") + " " + String(album || "")).toLowerCase()
  if (!blob.trim()) return false
  return /podcast|episode\b|\bep\.? ?\d|interview|audiobook|talk show|lecture/.test(blob)
}

function isVideoPlayerId(blob) {
  var low = String(blob || "").toLowerCase()
  if (!low) return false
  var tokens = [
    "mpv", "vlc", "celluloid", "haruna", "totem", "kodi", "jellyfin",
    "stremio"
  ]
  for (var i = 0; i < tokens.length; i++) {
    if (low.indexOf(tokens[i]) !== -1) return true
  }
  return false
}

function isBrowserPlayerId(blob) {
  var low = String(blob || "").toLowerCase()
  if (!low) return false
  var tokens = [
    "firefox", "chromium", "chrome", "brave", "vivaldi", "librewolf",
    "zen", "edge", "epiphany", "opera"
  ]
  for (var i = 0; i < tokens.length; i++) {
    if (low.indexOf(tokens[i]) !== -1) return true
  }
  return false
}

function nextClickState(state, nowMs, stats) {
  var last = Number(state && state.lastClickMs) || 0
  var burst = Number(state && state.clickBurst) || 0
  var now = Number(nowMs)
  if (!isFinite(now)) now = 0
  if (now - last < 550) burst += 1
  else burst = 1
  var greetMs = 1800
  var burstLimit = 3
  if (stats) {
    var s = normalizeCareStats(stats)
    greetMs = Math.round(1800 + s.bond * 14)
    if (s.bond >= 65) burstLimit = 4
  }
  if (burst >= burstLimit) {
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
    greetUntil: now + greetMs,
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

function levitateDurationMs(rise) {
  var d = Number(rise)
  if (!isFinite(d) || d < 0) d = 0
  var ms = Math.round(420 + Math.sqrt(d) * 28)
  if (ms < 520) ms = 520
  if (ms > 1100) ms = 1100
  return ms
}

function nestMode(mode) {
  var m = String(mode || "idle")
  if (isMoveMode(m) || m === "trip" || m === "drag" || m === "fall" || m === "collapse") return "idle"
  return m
}

// The pet always exists — bundled sheet until the user generates their own —
// so only the panel nest can take it off the desktop.
function desktopPetVisible(opts) {
  var o = opts || {}
  if (o.recalling || o.releasing) return true
  return !o.docked
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

function reviveCareStats(stats, nowMs) {
  var s = normalizeCareStats(stats, nowMs)
  if (s.health < 40) s.health = 72
  if (s.hygiene < 25) s.hygiene = 72
  if (s.hunger < 25) s.hunger = 72
  if (s.mood < 25) s.mood = 72
  if (s.energy < 20) s.energy = 70
  return s
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

function danceFps(peak, stats) {
  var p = Number(peak)
  if (!isFinite(p) || p < 0) p = 0
  if (p > 1) p = 1
  var fps = Math.round(7 + p * 16)
  if (fps > 26) fps = 26
  return fps
}

function numberFromBlob(raw, keys) {
  var data = parseJsonBlob(String(raw || ""))
  function dig(node, depth) {
    if (node == null || depth > 4) return -1
    if (typeof node !== "object") return -1
    for (var i = 0; i < keys.length; i++) {
      var v = node[keys[i]]
      if (typeof v === "number" && isFinite(v) && v >= 0) return Math.floor(v)
      if (typeof v === "string" && v !== "" && isFinite(Number(v))) return Math.floor(Number(v))
      if (v && typeof v === "object") {
        var inner = dig(v, depth + 1)
        if (inner >= 0) return inner
      }
    }
    for (var k in node) {
      if (node[k] && typeof node[k] === "object") {
        var found = dig(node[k], depth + 1)
        if (found >= 0) return found
      }
    }
    return -1
  }
  return dig(data, 0)
}

function creditsFromBlob(raw) {
  return numberFromBlob(raw, ["credits", "credit_balance", "balance", "credits_remaining", "remaining_credits"])
}

function costFromBlob(raw) {
  return numberFromBlob(raw, ["cost", "credits", "credit_cost", "price", "estimated_cost", "estimate", "total"])
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

function collapseErrorMessage(text) {
  var drop = /^(service unavailable|bad gateway|internal server error|error|failed|generate failed\.?)$/i
  var lines = String(text || "").split(/\n+/).map(function(s) {
    return s.replace(/^\s+|\s+$/g, "")
  }).filter(function(s) {
    return s && !drop.test(s)
  })
  var out = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    var low = line.toLowerCase()
    var skip = false
    for (var j = 0; j < out.length; j++) {
      var prev = out[j].toLowerCase()
      if (prev === low || prev.indexOf(low) >= 0 || low.indexOf(prev) >= 0) skip = true
    }
    if (!skip) out.push(line)
  }
  return out.join(" ").replace(/\s+/g, " ").trim()
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
    message = (typeof data.reason === "string" && data.reason)
      ? data.reason
      : (errorTextFromNode(errObj) || errorTextFromNode(detail) || errorTextFromNode(data))
    actionTypes = actionTypesFromNode(data).concat(actionTypesFromNode(errObj), actionTypesFromNode(detail))
    if (typeof data.error === "string" && !message) message = data.error
  }
  if (!message) message = text
  message = collapseErrorMessage(message)
  var blob = (kindToken + " " + actionTypes.join(" ") + " " + message + " " + text).toLowerCase()
  var kind = "retry"
  var title = "Generate failed"
  var actions = ["retry"]
  if (/failed twice|pose [a-z]+:|clip [a-z]+:/.test(blob)) {
    title = "Some frames failed"
    message = "Some frames failed to generate — " + message +
      ". Retry runs the whole flow again, starting from the base sprite."
  }
  if (/upgrade_plan|upgrade plan|\bupgrade\b|minimum_.*plan|higher .{0,24}plan|requires a higher/.test(blob)) {
    kind = "upgrade"
    title = "Upgrade required"
    if (!message || /^[a-z0-9_]+$/i.test(message) || /ended with status|upgrade_plan/i.test(message))
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
    message = "The plugin lost contact while waiting. The job may already be finished on higgsfield.ai."
  } else if (/unknown flag|unknown shorthand/.test(blob)) {
    kind = "cli"
    title = "CLI mismatch"
    message = "This Higgsfield CLI build rejected a wait flag. Update the plugin and retry."
  } else if (/ended with status|status ["']failed["']/.test(blob)) {
    kind = "job"
    title = "Generation failed"
    if (!message || /ended with status|status ["']failed["']/.test(String(message).toLowerCase()))
      message = "Higgsfield's model failed this run. Open generate.log for the job payload, or retry."
  } else if (!message || message === "[object Object]") {
    message = "Generate failed. Retry, or upgrade your plan if Higgsfield asked for that."
    actions = ["retry", "upgrade"]
  }
  message = collapseErrorMessage(message)
  if (message.length > 280) message = message.slice(0, 280)
  return {
    kind: kind,
    title: title,
    message: message,
    actions: actions,
    showUpgrade: kind === "upgrade" || kind === "credits",
    showTitle: false,
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
    return {
      ok: false,
      error: classified.message || "generate failed",
      path: "",
      url: ""
    }
  } catch (e) {
    return { ok: false, error: collapseErrorMessage(last).slice(0, 400), path: "", url: "" }
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
    sleepAfterMs: sleepAfterMs,
    tripDropPx: tripDropPx,
    eatEveryMs: eatEveryMs,
    washEveryMs: washEveryMs,
    happyDurationMs: happyDurationMs,
    careDurationMs: careDurationMs,
    clampStat: clampStat,
    defaultCareStats: defaultCareStats,
    normalizeCareStats: normalizeCareStats,
    careDecayRates: careDecayRates,
    decayCareStats: decayCareStats,
    reviveCareStats: reviveCareStats,
    applyCareAction: applyCareAction,
    careFlags: careFlags,
    sleepAfterMsFor: sleepAfterMsFor,
    ageLabel: ageLabel,
    flipPeak: flipPeak,
    dancePeak: dancePeak,
    isNightHour: isNightHour,
    sneakWindow: sneakWindow,
    isMoveMode: isMoveMode,
    isVideoPlayerId: isVideoPlayerId,
    isBrowserPlayerId: isBrowserPlayerId,
    creditsFromBlob: creditsFromBlob,
    costFromBlob: costFromBlob,
    speechLike: speechLike,
    beatStep: beatStep,
    podcastMeta: podcastMeta,
    movePace: movePace,
    pickWander: pickWander,
    nextClickState: nextClickState,
    shouldFall: shouldFall,
    stepFall: stepFall,
    fallDurationMs: fallDurationMs,
    levitateDurationMs: levitateDurationMs,
    nestMode: nestMode,
    desktopPetVisible: desktopPetVisible,
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
