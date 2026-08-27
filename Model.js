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

function normalizeClipKind(kind) {
  var k = String(kind || "").trim().toLowerCase()
  if (k === "commit" || k === "ok" || k === "success") return "commit"
  if (k === "fail" || k === "error" || k === "failed") return "fail"
  if (k === "screensaver" || k === "idle" || k === "reveal") return "screensaver"
  return ""
}

function clipFile(kind) {
  var k = normalizeClipKind(kind)
  if (!k) return ""
  return "clips/" + k + ".mp4"
}

function shouldPlayClip(kind, lastKind, lastMs, nowMs, cooldownMs) {
  var k = normalizeClipKind(kind)
  if (!k) return false
  if (k === "screensaver") return true
  var cool = Number(cooldownMs)
  if (!isFinite(cool) || cool < 0) cool = 8000
  var last = String(lastKind || "")
  var then = Number(lastMs)
  var now = Number(nowMs)
  if (!isFinite(then) || !isFinite(now)) return true
  if (k === last && (now - then) < cool) return false
  return true
}

if (typeof module !== "undefined") {
  module.exports = {
    loadSignals: loadSignals,
    formatNumber: formatNumber,
    pickRandom: pickRandom,
    wrapLine: wrapLine,
    formatScreensaver: formatScreensaver,
    screensaverSeconds: screensaverSeconds,
    focusWindow: focusWindow,
    normalizeClipKind: normalizeClipKind,
    clipFile: clipFile,
    shouldPlayClip: shouldPlayClip
  }
}
