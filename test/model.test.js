const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")
const Catalog = require("../Catalog.js")
const signals = require("../signals.json")

test("Catalog.pick returns a full essay", () => {
  const first = Catalog.pick(-1)
  assert.ok(first.title.length > 0)
  assert.ok(first.body.length > 20)
  const second = Catalog.pick(first.id)
  assert.notEqual(second.id, first.id)
})

test("catalog has 38 signals", () => {
  assert.equal(signals.length, 38)
  assert.equal(Catalog.all().length, 38)
  assert.equal(signals[0].slug, "00")
  assert.equal(signals[37].slug, "37")
})

test("bodies are the full website paragraphs", () => {
  assert.match(signals[0].body, /Have fun/)
  assert.match(signals[16].body, /Henry Ford/)
  assert.match(signals[21].body, /Yes” is no to a lot of things/)
  assert.match(signals[37].body, /remain unexplained/)
  for (const signal of signals) {
    assert.ok(signal.title.length > 0, signal.slug)
    assert.ok(signal.body.length > 20, signal.slug)
    assert.equal(signal.url, `https://37signals.com/${signal.slug}`)
  }
})

test("formatNumber pads ids", () => {
  assert.equal(Model.formatNumber(1), "01")
  assert.equal(Model.formatNumber(37), "37")
})

test("pickRandom never returns the excluded id when others exist", () => {
  const first = Model.pickRandom(signals, null)
  assert.ok(first)
  for (let i = 0; i < 20; i++) {
    const next = Model.pickRandom(signals, first.id)
    assert.notEqual(next.id, first.id)
  }
})

test("loadSignals accepts array-like objects from QML", () => {
  const like = { 0: signals[4], 1: signals[5], length: 2 }
  assert.equal(Model.loadSignals(like).length, 2)
  const picked = Model.pickRandom(like, 4)
  assert.equal(picked.id, 5)
})

test("formatScreensaver wraps the essay for ttfx", () => {
  const page = Model.formatScreensaver(1, "An obligation to independence", "We have no investors, no board of directors, no eyes on an exit.")
  assert.match(page, /^37signals\n/)
  assert.match(page, /^01\.\n/m)
  assert.match(page, /An obligation to independence/)
  assert.match(page, /no investors/)
  const wrapped = Model.wrapLine("one two three four five six seven eight nine ten", 12)
  assert.ok(wrapped.split("\n").every((line) => line.length <= 12))
})

test("screensaverSeconds reads Omarchy idle config", () => {
  assert.equal(Model.screensaverSeconds({ screensaver: 150 }, 150), 150)
  assert.equal(Model.screensaverSeconds({ screensaver: "90" }, 150), 90)
  assert.equal(Model.screensaverSeconds({}, 150), 150)
})

test("atlas walk cycle is the full top row", () => {
  const frames = Model.framesForMode(null, "walk")
  assert.equal(frames.frameX, 0)
  assert.equal(frames.frameY, 0)
  assert.equal(frames.frameCount, 13)
  assert.equal(frames.frameWidth, 80)
  assert.equal(frames.frameHeight, 98)
  assert.equal(frames.displayWidth, 80)
  assert.equal(frames.displayHeight, 98)
})

test("idle and collapse use dedicated rows", () => {
  const idle = Model.framesForMode(null, "idle")
  assert.equal(idle.frameY, 98)
  assert.equal(idle.frameX, 7 * 80)
  assert.equal(idle.frameCount, 4)
  const collapse = Model.framesForMode(null, "collapse")
  assert.equal(collapse.frameY, 98)
  assert.equal(collapse.frameX, 6 * 80)
})

test("resolveMode prefers collapse, then drag, then keys, then loud music", () => {
  assert.equal(Model.resolveMode({ collapsed: true, keysRecent: true, mediaPlaying: true, audioPeak: 1 }), "collapse")
  assert.equal(Model.resolveMode({ dragging: true, keysRecent: true }), "drag")
  assert.equal(Model.resolveMode({ keysRecent: true, mediaPlaying: true, audioPeak: 1 }), "walk")
  assert.equal(Model.resolveMode({ keysRecent: false, mediaPlaying: true, audioPeak: 0.8 }), "flip")
  assert.equal(Model.resolveMode({ keysRecent: false, mediaPlaying: true, audioPeak: 0.1 }), "dance")
  assert.equal(Model.resolveMode({ keysRecent: false, mediaPlaying: false, audioPeak: 0 }), "idle")
})

test("clampPetX stays inside the focused window", () => {
  assert.equal(Model.clampPetX(-10, 80, 400), 0)
  assert.equal(Model.clampPetX(900, 80, 400), 320)
  assert.equal(Model.clampPetX(40, 80, 60), 0)
  assert.equal(Model.petBottomY(98, 400, 4), 298)
})

test("focusWindow maps activewindow into screen-local coords", () => {
  const mons = JSON.stringify([
    { id: 0, name: "eDP-1", x: 0, y: 0, width: 1920, height: 1080, focused: false },
    { id: 1, name: "HDMI-A-1", x: 1920, y: 0, width: 2560, height: 1440, focused: true }
  ])
  const win = JSON.stringify({ monitor: 1, at: [2000, 80], size: [800, 600] })
  const focus = Model.focusWindow(mons, win)
  assert.equal(focus.monitor, "HDMI-A-1")
  assert.equal(focus.x, 80)
  assert.equal(focus.y, 80)
  assert.equal(focus.w, 800)
  assert.equal(focus.h, 600)
})

test("clipWindowRect keeps the stage on the overlay screen", () => {
  const clipped = Model.clipWindowRect({ x: -20, y: 10, w: 200, h: 100 }, 1920, 1080)
  assert.equal(clipped.x, 0)
  assert.equal(clipped.y, 10)
  assert.equal(clipped.w, 180)
})

test("danceFps follows the waveform peak", () => {
  assert.equal(Model.danceFps(0), 7)
  assert.equal(Model.danceFps(1), 23)
})
