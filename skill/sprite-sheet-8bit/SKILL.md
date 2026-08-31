---
name: sprite-sheet-8bit
description: |
  Turns ONE user-supplied character image (photo, drawing, render) into a complete
  8-bit pixel-art sprite sheet with a FIXED 12-row action set (192 frames total,
  16 columns x 12 rows). Animation is video-driven: every action is generated as a
  short video clip from the 8-bit base sprite, frames are sampled from the
  clip, keyed and assembled into per-action strips. Character only — props are
  never generated as standalone assets. Fires when the user asks for a sprite
  sheet / sprite animations / 8-bit character from their image.
---

# 8-bit character sprite sheet from one image (video-driven)

Produce a full 12-row sprite sheet of ONE character derived from the user's image.
The action set is FIXED (see the row table) and is ALWAYS generated in full — never
ask which rows to include, never add rows. Tiny hand-held items (snack, towel)
exist only inside their row's frames; no standalone prop assets.

## Required input

- Exactly ONE user image of the character. If missing, ask for it (one question,
  `kind: files`).
- Optional overrides: output mode (default **native resolution** — no crop, no
  downscale; `frame_size` > 0 in the plan switches to a small pixel-grid mode),
  key color (default auto), frames per full row (default **16**; half-rows 8+8).

## Hard style rule

The character is ALWAYS 8-bit pixel art. Fixed style string — verbatim in EVERY
image AND video prompt of this skill:

`8-bit pixel art drawn at high pixel density — about 64 pixels of detail from head to feet, small square pixels (density only: NEVER zoom, NEVER crop, NEVER enlarge the character), limited NES-era palette (max ~24 colors), hard pixel edges, no anti-aliasing, no gradients, no blur, NO visible grid lines, no mesh or checkerboard overlay, flat colors, 1px dark outline, clean readable silhouette`

Never say the art sits "on a pixel grid" — the model draws literal grid lines over the frame.

## Prerequisites

Before generating, load via `skill_view` (unless already in context this session):
`image-generation` (for the base sprite) and `video-generation` (for the clips).
Follow their model and approval rules.

## Step 1 — key color

Inspect the user's image (`image_analyze` if needed) and pick the keying background:
- default: bright magenta `#FF00FF`;
- character is pink/magenta/purple: bright green `#00FF00`;
- both conflict: bright blue `#0000FF`.
The same hex goes into every prompt AND into `scripts/postprocess.py`. Keying must
clear enclosed background regions (holes between limbs), not only edge-connected area.

## Step 2 — base sprite (fully automatic, ONE generation, NO approval)

Upload the user image (`higgsfield_upload`) and generate ONE base sprite with
**`nano_banana_2`** — FIXED, the only image model of this skill, never substitute
without explicit user consent (image-to-image, 1:1, 1k): full body, standing, facing right,
centered, nothing cropped, style string verbatim, solid key-color background, no
ground plane, no cast shadow. Keep the character's recognizable traits (hair, outfit
colors, distinctive features) translated into 8-bit.

FRAMING LOCK — HARD RULE, include this block verbatim in the base prompt EVERY
time, identical on every run:
`FRAMING RULE — CRITICAL: the character is SMALL in the frame, occupying only
about 60-65% of the frame HEIGHT (never more than 70%), positioned exactly in
the center, with LARGE empty solid-background margins: at least 18% of the frame
height empty ABOVE the head and at least 18% empty BELOW the feet, wide empty
margins left and right, full body visible, nothing cropped at the edges.`

ZERO-TOUCH RULE: do NOT show the base to the user, do NOT ask for approval, do
NOT reroll. One generation, accept the result as-is (a free numeric framing
measurement may be logged, but a miss does not trigger a regeneration), and
proceed immediately to Step 3. The entire pipeline runs start-to-finish with no
user questions: the user drops one image and receives all finished animations.

## Step 3 — per-action START FRAMES (16 images)

Immediately after the base completes, generate ONE image PER ACTION (16 total: walk, idle,
look, sleep, collapse, drag, greet, dance, dash, sneak, fall, happy, watch,
eat, sick, wash) — the FIRST pose of that action (walk: mid-stride facing
right; sleep: lying flat on the side, strictly horizontal; fall: mid-air, arms and legs spread flailing;
dance: facing camera arms up; etc., derived from the row table). `nano_banana_2`, 1:1, 1k, the BASE sprite passed as reference
media in every request, style string verbatim, same key-color background.

CHARACTER LOCK — HARD RULE, include verbatim in EVERY start-frame AND clip
prompt (ONE compact block; stacking more overlapping rule blocks dilutes them
all and the model starts dropping details or shrinking the character). The
style string's concrete density anchor (~64 pixels head to feet) is
load-bearing for quality — never soften it to vague wording:
`CHARACTER LOCK: exactly the same character as the reference — same face,
hair, skin tone, the same outfit in the same colors down to the shoes; nothing
added, removed or recolored. Same size and proportions as the reference: same
head size, same body thickness, same on-screen height — never smaller, never
zoomed, never cropped; full body, head to feet.`
Pose specs must never invite a wardrobe change (wash means dabbing with a
small towel in the normal outfit, never a towel wrap or robe).

Submit in two batched calls (10 + 6). QC all 16 in ONE batched `image_analyze`
pass (identity, pose, scale vs base, clean key background). Additionally verify
each start frame's BORDER is ≥85% key color, and for the lying rows (sleep,
collapse) that the subject box is clearly WIDER than tall, and for every frame that the
subject touches neither the top nor bottom frame edge (a touch means a bust or
waist-up crop — no legs). All cheap numeric checks; a frame with invented
scenery, an upright sleeper, or a cropped body fails and gets rerolled. Regen
budget: 2 per start frame. Never describe an off-screen agent in a pose prompt
("held by a hand from above") — the model will draw it; describe only the
character's own body and state "completely alone in the frame".

## Step 4 — clip plan (the video-driven core)

Every action is ONE short video clip. The action's own START FRAME image from
Step 3 is passed as `start_image` — NEVER as a generic reference-only input:
- LOOP rows: the SAME start-frame image goes in as BOTH `start_image` AND
  `end_image` — first frame = last frame, guaranteed seamless loop.
Frames are then sampled evenly from the clip — so clip length vs frame count sets
the playback feel. Keep clips SHORT (video is billed per second).

- Full 16-frame row → one clip, 4 s. Split row (8+8) → TWO clips, 4 s each
  (model minimum), one per half-action.
- Resolution: **720p — FIXED.**
- Total per run: **16 clips** (5 full rows + 5 split rows x 2 + row 11's single
  half-row; row 8 stays empty). Every row LOOPS — there are no one-shot rows.
  16 keeps the whole batch well under an 18-job concurrency shed. Do NOT stop
  to discuss cost or ask anything — the run is zero-touch end-to-end (1 base +
  16 start-frame images + 16 clips of 4 s at 720p; platform-level generation
  approval is the only gate).

Model: **`seedance_2_0_mini`** — FIXED, for every clip. Never substitute another
model without explicit user consent; before the first batch, check its current
allowed durations/resolutions with `higgsfield_generate_models_explore`
(action=get, model_id=seedance_2_0_mini) and snap the clip plan to them.
Loop rule: a looping action must end on the frame it started on — the model takes
`start_image` AND `end_image`, so for every loop clip pass that action's Step-3
start frame as BOTH; additionally append `seamless loop` to the prompt.
Every video prompt ALSO carries the CHARACTER LOCK verbatim (same wording as
Step 3) so identity and size never drift mid-clip.

Video prompt skeleton (one motion per clip, describe the MOTION, not the end state;
name direction, moving body parts, speed):

`<ROW SPEC>, <STYLE STRING>, <CAMERA LOCK>, flat solid <KEY HEX> background
staying EXACTLY <KEY HEX> in every frame — never darker, never desaturated, no
vignette — no cast shadow, no ground shadow, no background elements, no other
characters, no text`

After download, check a mid-clip frame's border against the key color the same
way start frames are checked — a clip whose background drifted (dimmed,
desaturated, or replaced) rerolls once before assembly.

CAMERA LOCK — HARD RULE, include this block VERBATIM in EVERY clip prompt (the
model tends to zoom in on featureless backgrounds; this is the counterweight):

`CAMERA LOCK — ABSOLUTE RULE: the camera is completely frozen for the entire
clip. Frame 1 must be a PIXEL-PERFECT copy of the input start image INCLUDING
all its empty background margins: the character occupies the same small portion
of the frame as in the start image, with the same wide empty margins above the
head, below the feet and on both sides. NEVER zoom in, NEVER enlarge the
character, NEVER push the character toward the frame edges, NEVER recompose or
recrop. The wide empty margins stay visible in EVERY frame; any zoom-in or
tighter framing is a failure.`

After each batch, VERIFY framing numerically (free): extract frame 1 and the
last frame of each clip, measure the subject bbox vs the start frame (key-color
mask); if the subject height grew by more than ~10 percentage points of frame
height, the clip is a framing failure — reroll it automatically (within the
2-attempt budget) before assembly.

Submission: batch all 16 requests in ONE `higgsfield_generate_video` call
(max 10 per call → two calls), resolution **720p**, duration 4 s, `count: 1`. Poll in batch with `higgsfield_job_status`.

## Row table (canonical — generate all 12, this exact order)

| Row | Frames | Spec | Loop |
|---|---|---|---|
| 0 | 16 | WALK: side-view walk/run cycle facing right, full gait, arms and legs clear, upright then slight forward lean as speed builds | loop |
| 1 | 8+8 | IDLE: subtle idle bob/breath facing 3/4 right · LOOK-AROUND: gentle head/torso turns (right, camera, left, back to right) while standing | loop each |
| 2 | 8+8 | SLEEP: lying flat on the side, body strictly HORIZONTAL, head and feet at the same height, eyes closed, tiny breathing — never upright, never diagonal · COLLAPSE/LIE: flat on stomach/back, body strictly HORIZONTAL, minimized pose, awake or half-awake, readable silhouette | loop each |
| 3 | 8+8 | DRAG/HANG: one arm fixed straight overhead, body hanging below it, legs dangling with a light pendulum sway, the raised arm never moves; COMPLETELY ALONE — no rope, no hand holding him, no other characters, no props · GREET/WAVE: facing camera/3-4, friendly wave or both-hands hello | loop each |
| 4 | 16 | DANCE/CHEER: music celebration facing camera/3-4, arms up, stepping in place, joyful cycle | loop |
| 5 | 16 | DASH/FLIP ENERGY: aggressive sprint facing right, long strides, strong lean, high energy, hype peak | loop |
| 6 | 16 | SNEAK: deep crouch walk facing right, torso low, careful steps | loop |
| 7 | 16 | FALL: falling through the air, arms and legs waving and flailing, comic panic tumble, clothes and hair lifted upward, no ground contact, loopable mid-air cycle | loop |
| 8 | — | (empty — reserved; hard landings reuse row 2 COLLAPSE instantly) | — |
| 9 | 8+8 | HAPPY/LOVE: big smile, optional small pixel hearts above head (clean pixels, no blur) · WATCH: sitting on the ground with a small open laptop on the lap, eyes on the screen, tiny reactions, COMPLETELY ALONE, the laptop is the only prop | loop each |
| 10 | 8+8 | EAT/SNACK: holding a small snack/drink, chew or sip cycle · SICK/DIZZY: light pale/greenish tint on face only, dizzy swirl or hand-to-head, woozy stance, outfit readable | loop each |
| 11 | 8 | WASH/HYGIENE: standing in his normal outfit dabbing his face with a small towel, a few soap bubbles around, clothing completely unchanged — never undressed, never a towel wrap or robe (first half-row; the second half of row 11 stays empty) | loop |

## Step 5 — QC and regen budget

Glance-check each finished clip (batched): character matches the base, motion
matches the row spec, background stayed flat key color, camera static.
Regen budget: **2 attempts per clip** (reroll same prompt for drift; edit the spec
only when the CONTENT is wrong). Re-sampling different frames from an existing
clip is free — always try that before regenerating. Never regenerate the full set
over point feedback.

## Step 6 — post-process and assembly (local, `scripts/postprocess.py`)

Download the clips, write a `plan.json` (see the script header), run the script.
Per clip: even frame sampling (ffmpeg) → chroma-key by hex distance including
enclosed regions → despill (rim + global soft pass). In pixel-grid mode every
action is cropped with ONE shared square (sized by the largest subject across
ALL actions) and BOTTOM-anchored, so a lying pose keeps the same scale as a
standing one and rests on the shared floor line instead of floating zoomed-in
mid-cell → otherwise NATIVE clip resolution
(default: no crop, no downscale, no quantization — `frame_size`/`max_colors` in
plan.json opt into the small pixel-grid mode) → TIMING (FINAL DEFAULT, variant A):
every grid frame is unique and holds a uniform **156 ms** → a 16-frame action
cycles in **~2.5 s** (8-frame half: ~1.25 s). `frame_ms` in plan.json changes the
tempo; `hold_frames` > 1 opts into hold-based timing instead (key poses picked by
motion, holds baked as repeats). Assembly, ONE IMAGE PER ACTION:
- a horizontal strip PNG per action (N unique frames side by side at clip
  resolution), transparent background, named `rowNN[a|b]_<action>.png`;
- a preview GIF per action (uniform 156 ms/frame by default; Row 8 plays once);
- `timings.json`: per action — frame count, per-frame durations in ms, cycle
  length, loop flag (for engines that consume timing);
- the combined 16x12 master sheet as an optional extra — the per-action strips
  are the primary deliverable.

## Step 7 — deliver

Upload the per-action strips, their GIFs and the optional master sheet in one
`higgsfield_upload` batch; show 2-3 representative GIFs. State frame size, per-action
strip sizes and the action map (action → frames → loop/one-shot) so it can be wired
into an engine.

## Limitations (state honestly when relevant)

- Video models smooth motion; the 8-bit look lives in the base sprite carried
  through every clip — expect a reroll on 1-3 clips per run.
- Background may drift mid-clip (shadows, gradient); keying tolerance handles mild
  drift, heavy drift = reroll.
- Slight identity drift across 16 clips is possible; base-sprite-as-start-frame
  minimizes it.
- Cost: ~16 short clips + 1-3 images per run; video bills per second — never
  request longer clips than the plan needs.
