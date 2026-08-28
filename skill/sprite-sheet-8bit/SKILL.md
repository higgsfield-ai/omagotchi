---
name: sprite-sheet-8bit
description: |
  Turns ONE user-supplied character image (photo, drawing, render) into a complete
  8-bit pixel-art sprite sheet with a FIXED 12-row action set (192 frames total,
  16 columns x 12 rows). Animation is video-driven: every action is generated as a
  short video clip from an approved 8-bit base sprite, frames are sampled from the
  clip, keyed and assembled into per-action strips. Character only — props are
  never generated as standalone assets. Fires when the user asks for a sprite
  sheet / sprite animations / 8-bit character from their image.
---

# 8-bit character sprite sheet from one image (video-driven)

Produce a full 12-row sprite sheet of ONE character derived from the user's image.
The action set is FIXED (see the row table) and is ALWAYS generated in full — never
ask which rows to include, never add rows. Tiny hand-held items (snack, towel,
raincoat) exist only inside their row's frames; no standalone prop assets.

## Required input

- Exactly ONE user image of the character. If missing, ask for it (one question,
  `kind: files`).
- Optional overrides: output mode (default **native resolution** — no crop, no
  downscale; `frame_size` > 0 in the plan switches to a small pixel-grid mode),
  key color (default auto), frames per full row (default **16**; half-rows 8+8).

## Hard style rule

The character is ALWAYS 8-bit pixel art. Fixed style string — verbatim in EVERY
image AND video prompt of this skill:

`8-bit pixel art, chunky low-resolution pixels on a coarse pixel grid, limited NES-era palette (max ~24 colors), hard pixel edges, no anti-aliasing, no gradients, no blur, flat colors, 1px dark outline, clean readable silhouette`

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

## Step 2 — base sprite (cheap gate, checkpoint)

Upload the user image (`higgsfield_upload`) and generate ONE base sprite with
**`nano_banana_2`** — FIXED, the only image model of this skill, never substitute
without explicit user consent (image-to-image, 1:1, 1k): full body, standing, facing right,
centered, nothing cropped, style string verbatim, solid key-color background, no
ground plane, no cast shadow. Keep the character's recognizable traits (hair, outfit
colors, distinctive features) translated into 8-bit.

SHOW the base sprite to the user and get approval BEFORE any video generation —
all clips depend on it. On rejection: max 2 rerolls, then ask what to change.

## Step 3 — clip plan (the video-driven core)

Every action is ONE short video clip generated FROM the approved base sprite
(base sprite = start frame). Frames are then sampled evenly from the clip — so
clip length vs frame count sets the playback feel: same frame count over a longer
clip = choppier motion. Keep clips SHORT (video is billed per second).

- Full 16-frame row → one clip, ~3-4 s.
- Split row (8+8) → TWO clips, ~2 s each (one per half-action).
- Total per run: **18 clips** (6 full rows + 6 split rows x 2). Say the cost
  estimate to the user before submitting (18 short clips + 1-3 images).

Model: **`seedance_2_0_mini`** — FIXED, for every clip. Never substitute another
model without explicit user consent; before the first batch, check its current
allowed durations/resolutions with `higgsfield_generate_models_explore`
(action=get, model_id=seedance_2_0_mini) and snap the clip plan to them.
Loop rule: a looping action must end on the frame it started on — the model takes
`start_image` AND `end_image`, so for loop rows pass the base sprite (or the
half-action's key pose) as BOTH start and end frame; additionally append
`seamless loop` to the prompt. Row 8 is the only one-shot: start frame only,
clear progression, no loop clause.

Video prompt skeleton (one motion per clip, describe the MOTION, not the end state;
name direction, moving body parts, speed):

`<ROW SPEC>, <STYLE STRING>, locked static camera, character centered and fully in
frame, flat solid <KEY HEX> background that never changes, no camera motion, no
zoom, no background elements, no text`

Submission: batch all 18 requests in ONE `higgsfield_generate_video` call
(max 10 per call → two calls), lowest workable resolution, shortest allowed
duration, `count: 1`. Poll in batch with `higgsfield_job_status`.

## Row table (canonical — generate all 12, this exact order)

| Row | Frames | Spec | Loop |
|---|---|---|---|
| 0 | 16 | WALK: side-view walk/run cycle facing right, full gait, arms and legs clear, upright then slight forward lean as speed builds | loop |
| 1 | 8+8 | IDLE: subtle idle bob/breath facing 3/4 right · LOOK-AROUND: gentle head/torso turns (right, camera, left, back to right) while standing | loop each |
| 2 | 8+8 | SLEEP: lying on side or curled, eyes closed, tiny breathing · COLLAPSE/LIE: flat on stomach/back "minimized" pose, awake or half-awake, readable silhouette | loop each |
| 3 | 8+8 | DRAG/CARRIED: tucked knees mid-air hold/jump pose variations · GREET/WAVE: facing camera/3-4, friendly wave or both-hands hello | loop each |
| 4 | 16 | DANCE/CHEER: music celebration facing camera/3-4, arms up, stepping in place, joyful cycle | loop |
| 5 | 16 | DASH/FLIP ENERGY: aggressive sprint facing right, long strides, strong lean, high energy, hype peak | loop |
| 6 | 16 | SNEAK: deep crouch walk facing right, torso low, careful steps | loop |
| 7 | 16 | CRAWL: on all fours facing right, crawling loop | loop |
| 8 | 16 | TRIP/FACEPLANT one-shot: stumble → fall forward → hit ground → briefly flat, clear progression | ONE-SHOT |
| 9 | 8+8 | HAPPY/LOVE: big smile, optional small pixel hearts above head (clean pixels, no blur) · GRUMPY/ANGRY: frown, crossed arms or dismissive gesture, same character | loop each |
| 10 | 8+8 | EAT/SNACK: holding a small snack/drink, chew or sip cycle · SICK/DIZZY: light pale/greenish tint on face only, dizzy swirl or hand-to-head, woozy stance, outfit readable | loop each |
| 11 | 8+8 | WASH/HYGIENE: soap bubbles or towel wipe, clean and happy · NIGHT/RAINCOAT: same character in a simple darker jacket or tiny hood/coat variant, optional pixel raindrops, standing/idle poses — cosmetic outfit only, identity unchanged | loop each |

## Step 4 — QC and regen budget

Glance-check each finished clip (batched): character matches the base, motion
matches the row spec, background stayed flat key color, camera static.
Regen budget: **2 attempts per clip** (reroll same prompt for drift; edit the spec
only when the CONTENT is wrong). Re-sampling different frames from an existing
clip is free — always try that before regenerating. Never regenerate the full set
over point feedback.

## Step 5 — post-process and assembly (local, `scripts/postprocess.py`)

Download the clips, write a `plan.json` (see the script header), run the script.
It does per clip: even frame sampling (ffmpeg) → chroma-key by hex distance
including enclosed regions → despill (rim + global soft pass) → assembly at
NATIVE clip resolution (default: no crop, no downscale, no quantization —
`frame_size`/`max_colors` in plan.json opt into the small pixel-grid mode),
ONE IMAGE PER ACTION:
- a horizontal strip PNG for every action (N frames side by side at clip
  resolution), transparent background, named `rowNN[a|b]_<action>.png`;
- a preview GIF per action (~10 fps, composited on a neutral dark backdrop;
  Row 8 plays once);
- the combined 16x12 master sheet as an optional extra — the per-action strips
  are the primary deliverable.

## Step 6 — deliver

Upload the per-action strips, their GIFs and the optional master sheet in one
`higgsfield_upload` batch; show 2-3 representative GIFs. State frame size, per-action
strip sizes and the action map (action → frames → loop/one-shot) so it can be wired
into an engine.

## Limitations (state honestly when relevant)

- Video models smooth motion; the 8-bit look lives in the base sprite carried
  through every clip — expect a reroll on 1-3 clips per run.
- Background may drift mid-clip (shadows, gradient); keying tolerance handles mild
  drift, heavy drift = reroll.
- Slight identity drift across 18 clips is possible; base-sprite-as-start-frame
  minimizes it.
- Cost: ~18 short clips + 1-3 images per run; video bills per second — never
  request longer clips than the plan needs.
