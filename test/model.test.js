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

test("nextBillboardIndex walks the catalog without repeating the pair", () => {
  assert.equal(Model.nextBillboardIndex(0, 1, 38), 2)
  assert.equal(Model.nextBillboardIndex(36, 37, 38), 0)
  assert.equal(Model.nextBillboardIndex(-1, 4, 38), 5)
})

test("billboardBody wraps and caps the essay", () => {
  const text = Model.billboardBody("We have no investors, no board of directors, no eyes on an exit. We feel a moral obligation to exercise our independence.")
  const lines = text.split("\n")
  assert.ok(lines.length <= 6)
  assert.ok(lines.every((line) => line.length <= 32))
})

test("defaultCar faces left with two wheels", () => {
  const car = Model.defaultCar()
  assert.equal(car.facing, "left")
  assert.equal(car.wheels.length, 2)
  assert.ok(car.wheels[0].r > 40)
})

test("projectTrack recedes toward the vanishing point", () => {
  const far = Model.projectTrack(0, 100, 80, 800, 700)
  const near = Model.projectTrack(1, 100, 80, 800, 700)
  assert.equal(far.x, 100)
  assert.equal(far.y, 80)
  assert.ok(far.scale < near.scale)
  assert.ok(near.x > far.x)
  assert.ok(near.fog > far.fog)
})
