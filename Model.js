// 37signals catalog helpers. Qt-free so it can be tested under node.

function loadSignals(raw) {
  return Array.isArray(raw) ? raw : []
}

function formatNumber(id) {
  var n = Number(id)
  if (!isFinite(n) || n < 0) return "00"
  return (n < 10 ? "0" : "") + String(Math.floor(n))
}

function pickRandom(signals, exceptId) {
  var list = loadSignals(signals)
  var filtered = []
  for (var i = 0; i < list.length; i++) {
    if (exceptId === undefined || list[i].id !== exceptId) filtered.push(list[i])
  }
  if (filtered.length === 0) filtered = list
  if (filtered.length === 0) return null
  return filtered[Math.floor(Math.random() * filtered.length)]
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
    screensaverSeconds: screensaverSeconds
  }
}
