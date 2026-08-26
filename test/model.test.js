const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

test("resolveMode prefers override, then lock, hurry, dance, idle", () => {
  assert.equal(Model.resolveMode({ override: "wave" }), "wave")
  assert.equal(Model.resolveMode({ locked: true, mediaPlaying: true }), "sleep")
  assert.equal(Model.resolveMode({ keysPerSec: 12, mediaPlaying: true }), "hurry")
  assert.equal(Model.resolveMode({ mediaPlaying: true }), "dance")
  assert.equal(Model.resolveMode({}), "idle")
})

test("unknown override is ignored", () => {
  assert.equal(Model.resolveMode({ override: "explode" }), "idle")
})

test("rowForMode follows atlas.json order", () => {
  assert.equal(Model.rowForMode("idle"), 0)
  assert.equal(Model.rowForMode("hurry"), 1)
  assert.equal(Model.rowForMode("dance"), 2)
  assert.equal(Model.rowForMode("wave"), 6)
  assert.equal(Model.rowForMode("nope"), 0)
})

test("one-shots vs loops", () => {
  assert.equal(Model.isOneShot("wave"), true)
  assert.equal(Model.isOneShot("angry"), true)
  assert.equal(Model.isLoop("dance"), true)
  assert.equal(Model.isLoop("wave"), false)
})

test("normalizePlacement defaults to focus", () => {
  assert.equal(Model.normalizePlacement("focus"), "focus")
  assert.equal(Model.normalizePlacement("pointer"), "pointer")
  assert.equal(Model.normalizePlacement("pin"), "pin")
  assert.equal(Model.normalizePlacement("true"), "pointer")
  assert.equal(Model.normalizePlacement(""), "focus")
  assert.equal(Model.isClickThrough("focus"), true)
  assert.equal(Model.isClickThrough("pin"), false)
})

test("focusAnchor sits inside the bottom-right of the active window", () => {
  const box = Model.parseActiveWindow(
    JSON.stringify({ at: [100, 40], size: [800, 600] })
  )
  assert.deepEqual(box, { x: 100, y: 40, w: 800, h: 600 })
  assert.deepEqual(Model.focusAnchor(box, 96, 12), { x: 792, y: 532 })
  assert.equal(Model.parseActiveWindow("Invalid"), null)
})
