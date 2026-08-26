const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")
const signals = require("../signals.json")

test("catalog has 38 signals", () => {
  assert.equal(signals.length, 38)
  assert.equal(signals[0].slug, "00")
  assert.equal(signals[37].slug, "37")
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

test("screensaverSeconds reads Omarchy idle config", () => {
  assert.equal(Model.screensaverSeconds({ screensaver: 150 }, 150), 150)
  assert.equal(Model.screensaverSeconds({ screensaver: "90" }, 150), 90)
  assert.equal(Model.screensaverSeconds({}, 150), 150)
})
