const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

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

test("resolveMode prefers drag, then sick, then click moods, then sleep, then locomotion", () => {
  assert.equal(Model.resolveMode({ dragging: true, wander: "walk" }), "drag")
  assert.equal(Model.resolveMode({ falling: true, wander: "walk" }), "sick")
  assert.equal(Model.resolveMode({ sick: true, wander: "walk" }), "sick")
  assert.equal(Model.resolveMode({ grumpy: true, greet: true, wander: "walk" }), "grumpy")
  assert.equal(Model.resolveMode({ greet: true, wander: "walk" }), "greet")
  assert.equal(Model.resolveMode({ sleep: true, wander: "walk" }), "sleep")
  assert.equal(Model.resolveMode({ sleep: true, mediaPlaying: true, wander: "idle" }), "dance")
  assert.equal(Model.resolveMode({ wander: "walk", mediaPlaying: true, audioPeak: 1 }), "walk")
  assert.equal(Model.resolveMode({ wander: "crawl" }), "crawl")
  assert.equal(Model.resolveMode({ wander: "run" }), "run")
  assert.equal(Model.resolveMode({ wander: "look" }), "look")
  assert.equal(Model.resolveMode({ wander: "idle", mediaPlaying: true, audioPeak: 0.8 }), "flip")
  assert.equal(Model.resolveMode({ wander: "idle", mediaPlaying: true, audioPeak: 0.1 }), "dance")
  assert.equal(Model.resolveMode({ wander: "idle" }), "idle")
  assert.equal(Model.resolveMode({ keysRecent: true, wander: "idle" }), "idle")
  assert.equal(Model.sleepAfterMs(), 60000)
})

test("generated atlas maps sleep onto row 2", () => {
  const sleep = Model.framesForMode(Model.generatedAtlas("/tmp/sheet.png"), "sleep")
  assert.equal(sleep.frameY, 160)
  assert.equal(sleep.frameX, 0)
  assert.equal(sleep.frameCount, 8)
})

test("pickWander mixes walk, crawl, run, idle, and look", () => {
  assert.equal(Model.pickWander(0), "walk")
  assert.equal(Model.pickWander(0.25), "walk")
  assert.equal(Model.pickWander(0.26), "crawl")
  assert.equal(Model.pickWander(0.45), "crawl")
  assert.equal(Model.pickWander(0.46), "run")
  assert.equal(Model.pickWander(0.67), "run")
  assert.equal(Model.pickWander(0.68), "idle")
  assert.equal(Model.pickWander(0.83), "idle")
  assert.equal(Model.pickWander(0.84), "look")
  assert.equal(Model.pickWander(1), "look")
})

test("nextClickState greets once and turns grumpy on a click burst", () => {
  const first = Model.nextClickState({ clickBurst: 0, lastClickMs: 0 }, 1000)
  assert.equal(first.clickBurst, 1)
  assert.equal(first.greetUntil, 2800)
  assert.equal(first.grumpyUntil, 0)
  const second = Model.nextClickState(first, 1300)
  assert.equal(second.clickBurst, 2)
  assert.equal(second.greetUntil, 3100)
  const third = Model.nextClickState(second, 1600)
  assert.equal(third.clickBurst, 0)
  assert.equal(third.greetUntil, 0)
  assert.equal(third.grumpyUntil, 4400)
  const later = Model.nextClickState(third, 3000)
  assert.equal(later.clickBurst, 1)
  assert.equal(later.greetUntil, 4800)
})

test("stepFall accelerates until the floor", () => {
  assert.equal(Model.shouldFall(40, 200, 12), true)
  assert.equal(Model.shouldFall(195, 200, 12), false)
  const mid = Model.stepFall(40, 0, 200, 1.35, 24)
  assert.equal(mid.landed, false)
  assert.ok(mid.pos > 40)
  assert.ok(mid.vel > 0)
  const land = Model.stepFall(199, 24, 200, 1.35, 24)
  assert.equal(land.landed, true)
  assert.equal(land.pos, 200)
  assert.equal(land.vel, 0)
  assert.ok(Model.fallDurationMs(400) > Model.fallDurationMs(40))
  assert.equal(Model.movePace("crawl").step, 3)
  assert.equal(Model.movePace("run").step, 14)
  assert.equal(Model.isMoveMode("crawl"), true)
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

test("parseGenerateResult reads the last JSON line", () => {
  const ok = Model.parseGenerateResult('noise\n{"ok":true,"path":"/tmp/a.png","url":"https://x"}')
  assert.equal(ok.ok, true)
  assert.equal(ok.path, "/tmp/a.png")
  assert.equal(ok.url, "https://x")
  const fail = Model.parseGenerateResult('{"ok":false,"error":"higgsfield CLI not found"}')
  assert.equal(fail.ok, false)
  assert.match(fail.error, /not found/)
  assert.equal(Model.trimPrompt("  hello  "), "hello")
  assert.equal(Model.isImagePath("/tmp/a.PNG"), true)
  assert.equal(Model.isImagePath("/tmp/a.mp4"), false)
})

test("generatedAtlas builds the 16x12 overlay spec", () => {
  const spec = Model.generatedAtlas("/tmp/spritesheet_16x12.png")
  assert.equal(spec.columns, 16)
  assert.equal(spec.rows, 12)
  assert.equal(spec.cellHeight, 80)
  const walk = Model.framesForMode(spec, "walk")
  assert.equal(walk.frameCount, 16)
  const look = Model.framesForMode(spec, "look")
  assert.equal(look.frameCount, 8)
  assert.equal(look.frameY, 80)
  const greet = Model.framesForMode(spec, "greet")
  assert.equal(greet.frameY, 240)
  const crawl = Model.framesForMode(spec, "crawl")
  assert.equal(crawl.frameY, 560)
  assert.equal(crawl.frameCount, 16)
  const run = Model.framesForMode(spec, "run")
  assert.equal(run.frameY, 400)
  const parsed = Model.parseGenerateResult('{"ok":true,"path":"/tmp/sheet.png","atlas_spec":{"file":"/tmp/sheet.png","columns":16}}')
  assert.equal(parsed.ok, true)
  assert.equal(parsed.atlasSpec.file, "/tmp/sheet.png")
})

test("generated 16x12 atlas maps pet modes onto skill rows", () => {
  const spec = {
    file: "/tmp/spritesheet_16x12.png",
    cellWidth: 80,
    cellHeight: 80,
    columns: 16,
    rows: 12,
    fps: 10,
    scale: 1,
    modes: {
      walk: { row: 0, start: 0, count: 16 },
      idle: { row: 1, start: 0, count: 8 },
      dance: { row: 4, start: 0, count: 16 },
      flip: { row: 5, start: 0, count: 16 },
      collapse: { row: 2, start: 8, count: 8 },
      drag: { row: 3, start: 0, count: 8 }
    }
  }
  const walk = Model.framesForMode(spec, "walk")
  assert.equal(walk.frameCount, 16)
  assert.equal(walk.frameWidth, 80)
  assert.equal(walk.frameY, 0)
  const collapse = Model.framesForMode(spec, "collapse")
  assert.equal(collapse.frameY, 160)
  assert.equal(collapse.frameX, 640)
  const look = Model.framesForMode(spec, "look")
  assert.equal(look.frameY, 80)
  assert.equal(look.frameX, 640)
  assert.equal(look.frameCount, 8)
  const greet = Model.framesForMode(spec, "greet")
  assert.equal(greet.frameY, 240)
  assert.equal(greet.frameX, 640)
  const grumpy = Model.framesForMode(spec, "grumpy")
  assert.equal(grumpy.frameY, 720)
  assert.equal(grumpy.frameX, 640)
  const sick = Model.framesForMode(spec, "sick")
  assert.equal(sick.frameY, 800)
  assert.equal(sick.frameX, 640)
  assert.equal(Model.atlasImageSource("/tmp/a.png"), "file:///tmp/a.png")
})

test("parseGenLine splits progress JSON from the final result", () => {
  const prog = Model.parseGenLine('{"t":"progress","phase":"clip","step":4,"steps":20,"label":"Animating walk","percent":20}')
  assert.equal(prog.kind, "progress")
  assert.equal(prog.step, 4)
  assert.equal(prog.steps, 20)
  assert.equal(prog.percent, 20)
  assert.match(prog.label, /walk/)
  const done = Model.parseGenLine('{"ok":true,"path":"/tmp/sheet.png"}')
  assert.equal(done.kind, "result")
  assert.equal(Model.fileBaseName("/home/x/Pictures/cat.png"), "cat.png")
  assert.equal(Model.fileUrlToPath("file:///home/x/Pictures/cat.png"), "/home/x/Pictures/cat.png")
})

test("classifyGenerateError turns upgrade_plan into retry + upgrade actions", () => {
  const raw = Model.classifyGenerateError('{"type":"upgrade_plan","actions":[{"type":"upgrade_plan"}]}')
  assert.equal(raw.kind, "upgrade")
  assert.equal(raw.showUpgrade, true)
  assert.equal(raw.actions.includes("retry"), true)
  assert.equal(raw.actions.includes("upgrade"), true)
  assert.match(raw.message, /plan/i)
  const nested = Model.classifyGenerateError('{"ok":false,"error":{"type":"upgrade_plan","message":"Upgrade your plan"}}')
  assert.equal(nested.kind, "upgrade")
  const credits = Model.classifyGenerateError("not_enough_credits: add credits")
  assert.equal(credits.kind, "credits")
  assert.equal(credits.showUpgrade, true)
  const parsed = Model.parseGenerateResult('{"ok":false,"error":{"type":"upgrade_plan"}}')
  assert.equal(parsed.ok, false)
  assert.match(parsed.error, /plan/i)
  const down = Model.classifyGenerateError("Higgsfield API error - request failed with status 503\nService Unavailable")
  assert.equal(down.kind, "unavailable")
  assert.equal(down.showUpgrade, false)
  assert.equal(down.showTitle, false)
  assert.match(down.title, /busy/i)
  const jobFail = Model.classifyGenerateError('job abc123 ended with status "failed"')
  assert.equal(jobFail.kind, "job")
  assert.equal(jobFail.showTitle, false)
  assert.match(jobFail.message, /retry/i)
  assert.doesNotMatch(jobFail.message, /abc123/)
  const withReason = Model.classifyGenerateError('{"ok":false,"error":"job x ended with status \\"failed\\"","reason":"job x: nsfw"}')
  assert.match(withReason.message, /nsfw/i)
  const dup = Model.classifyGenerateError("Higgsfield API error - request failed with status 503\nService Unavailable")
  assert.doesNotMatch(dup.message, /Service Unavailable/i)
  assert.equal(dup.message.includes("\n"), false)
})
