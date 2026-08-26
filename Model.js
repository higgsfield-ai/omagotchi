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

if (typeof module !== "undefined") {
  module.exports = {
    loadSignals: loadSignals,
    formatNumber: formatNumber,
    pickRandom: pickRandom,
    wrapLine: wrapLine,
    formatScreensaver: formatScreensaver,
    screensaverSeconds: screensaverSeconds
  }
}
