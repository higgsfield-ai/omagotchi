#!/usr/bin/env python3
"""
sprite-sheet-8bit post-processor.

Turns per-action video clips into per-action sprite strips. DEFAULT pipeline:
  sample frames evenly -> chroma-key (enclosed regions included) -> despill
  (rim + global soft pass) -> NATIVE clip resolution, untouched geometry ->
  per-action strip PNG + preview GIF + optional combined master sheet.
No crop, no downscale, no quantization by default.

Opt-in extras via plan.json:
  "frame_ms": ms       uniform per-frame duration (default 156 -> 16-frame
                       action cycles in ~2.5 s, 8-frame half in ~1.25 s);
  "hold_frames": H     (> 1) hold-based timing instead of uniform: key poses
                       picked by motion (~H grid frames per pose), holds baked
                       into the strip as repeats, variable GIF durations;
  "frame_size": N      (> 0) pixel-grid mode: ONE fixed crop box per clip,
                       BOX downscale to NxN;
  "max_colors": M      (> 0) snap each action to ONE shared MEDIANCUT palette.

Usage:
    python3 postprocess.py plan.json

plan.json:
{
  "frame_size": 0,               // 0 = native (default)
  "max_colors": 0,               // 0 = no palette quantization (default)
  "key_color": "#FF00FF",
  "key_tolerance": 110,          // 0-441, euclidean RGB distance
  "out_dir": "out",
  "rows": [
    {"row": 0, "name": "walk", "one_shot": false,
     "clips": [{"path": "clips/r00_walk.mp4", "frames": 16, "name": "walk"}]},
    {"row": 1, "name": "idle_look", "one_shot": false,
     "clips": [{"path": "clips/r01a_idle.mp4", "frames": 8, "name": "idle"},
               {"path": "clips/r01b_look.mp4", "frames": 8, "name": "look"}]}
    // ... 16 frames per row total
  ]
}

Deps: ffmpeg/ffprobe on PATH, Pillow, numpy.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

COLS = 16
MAX_COLORS = 24
FRAME_MS = 156  # uniform per-frame ms; a 16-frame action cycles in ~2.5 s


def hex_to_rgb(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def clip_duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True).stdout.strip()
    return float(out)


def sample_frames(path, n, tmpdir):
    """Extract n evenly spaced frames as PNGs, return list of paths."""
    dur = clip_duration(path)
    paths = []
    for i in range(n):
        t = min(dur * (i + 0.5) / n, max(dur - 0.05, 0))
        p = Path(tmpdir) / f"{Path(path).stem}_{i:02d}.png"
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-ss", f"{t:.3f}", "-i", str(path),
             "-frames:v", "1", str(p)], check=True)
        paths.append(p)
    return paths


def chroma_key(img, key_rgb, tol):
    """Key color -> transparent (enclosed regions included) + rim despill."""
    a = np.asarray(img.convert("RGB"), dtype=np.int32)
    dist = np.sqrt(((a - np.array(key_rgb, dtype=np.int32)) ** 2).sum(axis=2))
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    kr, kg, kb = key_rgb
    key_like = np.zeros(dist.shape, dtype=bool)
    if kr > 200 and kb > 200 and kg < 60:        # magenta key
        bright = (r > 110) & (b > 110) & (g < 0.6 * np.minimum(r, b))
        shadow = (r > 60) & (b > 60) & (g < 0.45 * np.minimum(r, b))
        key_like = bright | shadow
    elif kg > 200 and kr < 60 and kb < 60:       # green key
        key_like = (g > 110) & (g > 1.6 * np.maximum(r, b))
    elif kb > 200 and kr < 60 and kg < 60:       # blue key
        key_like = (b > 110) & (b > 1.6 * np.maximum(r, g))
    alpha = np.where((dist <= tol) | key_like, 0, 255).astype(np.uint8)
    # Despill the opaque rim (~2px around keyed area): edge pixels blended
    # with the key (pink-hair syndrome) get the key tint suppressed.
    trans = alpha == 0
    rim_src = Image.fromarray((trans * 255).astype(np.uint8))
    rim = (np.asarray(rim_src.filter(ImageFilter.MaxFilter(5))) > 0) & ~trans
    if kr > 200 and kb > 200 and kg < 60 and rim.any():
        excess = np.clip(np.minimum(r, b) - g, 0, None)
        a[..., 0] = np.where(rim, np.clip(r - excess, 0, 255), a[..., 0])
        a[..., 2] = np.where(rim, np.clip(b - excess, 0, 255), a[..., 2])
    # Global SOFT despill: the magenta backdrop acts as a colored light source
    # in the generated video, tinting highlights (hair!) across the whole
    # subject, not just the rim. Neutralize WEAK magenta excess everywhere;
    # strongly saturated pink (excess > 70, e.g. intentional pixel hearts)
    # is left alone.
    if kr > 200 and kb > 200 and kg < 60:
        r2, g2, b2 = a[..., 0], a[..., 1], a[..., 2]
        excess = np.clip(np.minimum(r2, b2) - g2, 0, None)
        soft = (~trans) & (excess > 8) & (excess <= 70)
        a[..., 0] = np.where(soft, np.clip(r2 - excess, 0, 255), r2)
        a[..., 2] = np.where(soft, np.clip(b2 - excess, 0, 255), b2)
    rgba = np.dstack([a.astype(np.uint8), alpha])
    return Image.fromarray(rgba, "RGBA")


def effective_key(img, key_rgb):
    """The video model sometimes dims or desaturates the key background.
    When the measured border color is recognizably the drifted key, key on
    the measurement instead of the nominal hex."""
    arr = np.asarray(img.convert("RGB"))
    border = np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]])
    med = np.median(border, axis=0)
    if np.abs(med - np.array(key_rgb)).sum() <= 300:
        return tuple(int(v) for v in med)
    return key_rgb


def union_box(frames):
    """One bbox covering the subject in EVERY frame of the clip."""
    x0 = y0 = 10 ** 9
    x1 = y1 = -1
    for f in frames:
        alpha = np.asarray(f)[:, :, 3]
        ys, xs = np.nonzero(alpha)
        if len(xs) == 0:
            continue
        x0, y0 = min(x0, xs.min()), min(y0, ys.min())
        x1, y1 = max(x1, xs.max()), max(y1, ys.max())
    return None if x1 < 0 else (int(x0), int(y0), int(x1), int(y1))


def crop_anchored(img, box, side):
    """One square size for EVERY action: horizontally centered on the
    subject, BOTTOM-anchored so lying and standing poses share one floor
    line and one scale across the whole sheet. A per-action square zoomed
    lying poses (short, wide bbox) up and floated them mid-cell."""
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    pad = int(side * 0.04)
    left = cx - side // 2
    bottom = min(y1 + pad, img.height)
    top = bottom - side
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    bx = (max(left, 0), max(top, 0),
          min(left + side, img.width), min(bottom, img.height))
    if bx[2] <= bx[0] or bx[3] <= bx[1]:
        return canvas
    region = img.crop(bx)
    canvas.paste(region, (bx[0] - left, bx[1] - top))
    return canvas


def finalize_native(frames, magenta_key=False):
    """Native-resolution path (default): NO crop, NO downscale.

    Keyed frames pass through at the clip's own resolution; only a light
    despill on remaining key tint and RGB zeroing under transparency.
    """
    out = []
    for f in frames:
        q = np.asarray(f).astype(int)
        if magenta_key:
            r, g, b = q[..., 0], q[..., 1], q[..., 2]
            ex = np.clip(np.minimum(r, b) - g, 0, None)
            soft = (q[..., 3] > 0) & (ex > 4) & (ex <= 70)
            q[..., 0] = np.where(soft, np.clip(r - ex, 0, 255), r)
            q[..., 2] = np.where(soft, np.clip(b - ex, 0, 255), b)
        q[q[..., 3] == 0] = 0
        out.append(Image.fromarray(q.astype(np.uint8), "RGBA"))
    return out


def pixelize_action(frames, frame_size, max_colors=0, magenta_key=False):
    """Downscale a whole action. NO quantization by default.

    BOX-average down to the pixel grid (clean cells from noisy video frames),
    then a light despill on the averaged pixels (kills residual key tint that
    survives averaging). max_colors > 0 optionally snaps all frames to one
    shared MEDIANCUT palette for a strict retro look — OFF unless asked.
    """
    small = [f.resize((frame_size, frame_size), Image.BOX) for f in frames]
    if magenta_key:
        cleaned = []
        for f in small:
            q = np.asarray(f).astype(int)
            r, g, b = q[..., 0], q[..., 1], q[..., 2]
            ex = np.clip(np.minimum(r, b) - g, 0, None)
            soft = (q[..., 3] > 0) & (ex > 4) & (ex <= 70)
            q[..., 0] = np.where(soft, np.clip(r - ex, 0, 255), r)
            q[..., 2] = np.where(soft, np.clip(b - ex, 0, 255), b)
            cleaned.append(Image.fromarray(q.astype(np.uint8), "RGBA"))
        small = cleaned
    pal = None
    if max_colors:
        combo = Image.new("RGB", (frame_size * len(small), frame_size))
        for i, f in enumerate(small):
            combo.paste(f.convert("RGB"), (i * frame_size, 0))
        pal = combo.quantize(colors=max_colors, method=Image.MEDIANCUT)
    out = []
    for f in small:
        rgb = f.convert("RGB")
        if pal is not None:
            rgb = rgb.quantize(palette=pal,
                               dither=Image.Dither.NONE).convert("RGB")
        alpha = f.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
        q = np.dstack([np.asarray(rgb), np.asarray(alpha)])
        q[q[..., 3] == 0] = 0  # zero RGB under transparency
        out.append(Image.fromarray(q, "RGBA"))
    return out


def frame_diff(a, b):
    """Mean abs RGB difference (0-255) over the subject area, on small proxies."""
    sa = a.resize((96, 96), Image.BOX)
    sb = b.resize((96, 96), Image.BOX)
    na = np.asarray(sa).astype(int)
    nb = np.asarray(sb).astype(int)
    mask = (na[..., 3] > 0) | (nb[..., 3] > 0)
    if not mask.any():
        return 0.0
    d = np.abs(na[..., :3] - nb[..., :3]).mean(axis=2)
    return float(d[mask].mean())


def dedupe_holds(frames, k):
    """Impose classic hold-based animation timing on smooth video frames.

    Generated video moves continuously (no natural holds), so key poses are
    CHOSEN, not detected: walk the candidates accumulating frame-to-frame
    motion and start a new pose every equal share of the total motion. Slow
    stretches collapse into long holds, fast stretches get more poses.
    Returns (unique_frames, ticks): ticks[i] = candidates the pose covers.
    """
    if len(frames) < 2 or k <= 1:
        return frames[:1], [len(frames)]
    diffs = [frame_diff(frames[i - 1], frames[i]) for i in range(1, len(frames))]
    total = sum(diffs)
    if total <= 0:
        return frames[:1], [len(frames)]
    step = total / k
    uniq, ticks, acc = [frames[0]], [1], 0.0
    for f, d in zip(frames[1:], diffs):
        acc += d
        if acc >= step * len(uniq) and len(uniq) < k:
            uniq.append(f)
            ticks.append(1)
        else:
            ticks[-1] += 1
    return uniq, ticks


def expand_to_grid(uniq, ticks, n):
    """Bake holds into a fixed n-column strip: repeat each unique pose
    proportionally to its hold length; total is exactly n frames."""
    if len(uniq) >= n:  # too many poses: pick n evenly, no repeats
        idx = [round(i * (len(uniq) - 1) / (n - 1)) for i in range(n)]
        return [uniq[i] for i in idx], [1] * n
    total = sum(ticks)
    reps = [max(1, round(t / total * n)) for t in ticks]
    while sum(reps) > n:
        i = max(range(len(reps)), key=lambda j: reps[j])
        reps[i] -= 1
    while sum(reps) < n:
        i = max(range(len(ticks)), key=lambda j: ticks[j] / reps[j])
        reps[i] += 1
    out = []
    for f, r in zip(uniq, reps):
        out += [f] * r
    return out, reps


def save_gif(frames, path, one_shot, fs, durations=None):
    """Preview GIF: neutral dark backdrop; NEAREST upscale only for tiny
    pixel-grid frames. `durations` = per-frame ms (variable animation timing)."""
    scale = max(1, 256 // fs) if fs and fs < 256 else 1
    gif = []
    for f in frames:
        bg = Image.new("RGBA", f.size, (34, 34, 46, 255))
        bg.alpha_composite(f)
        big = bg.convert("RGB").resize(
            (f.width * scale, f.height * scale), Image.NEAREST)
        gif.append(big.convert("P", palette=Image.ADAPTIVE, colors=64))
    gif[0].save(path, save_all=True, append_images=gif[1:],
                duration=durations or FRAME_MS,
                loop=1 if one_shot else 0)


def main():
    plan = json.loads(Path(sys.argv[1]).read_text())
    fs = int(plan.get("frame_size", 0))  # 0 = NATIVE: no crop, no downscale
    max_colors = int(plan.get("max_colors", 0))  # quantization OFF by default
    # DEFAULT timing (variant A, final): every grid frame unique, uniform
    # frame_ms per frame -> 16-frame cycle ~2.5 s. hold_frames > 1 opts into
    # hold-based timing (key poses by motion, baked repeats).
    hold_frames = float(plan.get("hold_frames", 1))
    frame_ms = int(plan.get("frame_ms", FRAME_MS))
    key = hex_to_rgb(plan["key_color"])
    tol = int(plan.get("key_tolerance", 110))
    out_dir = Path(plan.get("out_dir", "out"))
    (out_dir / "actions").mkdir(parents=True, exist_ok=True)
    (out_dir / "gifs").mkdir(parents=True, exist_ok=True)

    rows = sorted(plan["rows"], key=lambda r: r["row"])
    magenta = key[0] > 200 and key[2] > 200
    sheet_rows = []
    timings = {}

    with tempfile.TemporaryDirectory() as tmp:
        # Pass 1: sample every clip and measure its subject box on cheap
        # quarter-scale proxies, so pass 2 can crop every action with ONE
        # shared square size (single scale + single floor line sheet-wide).
        prepared = []
        for r in rows:
            for ci, clip in enumerate(r["clips"]):
                n = clip["frames"]
                uniform = hold_frames <= 1
                # uniform mode samples exactly n frames; hold mode samples
                # DENSER (2x) so pose selection has material to collapse
                count = n if uniform else n * 2
                paths = sample_frames(clip["path"], count, tmp)
                box = None
                if fs:
                    proxies = []
                    for pth in paths:
                        im = Image.open(pth)
                        im = im.resize((max(1, im.width // 4),
                                        max(1, im.height // 4)))
                        proxies.append(chroma_key(im, effective_key(im, key), tol))
                    b = union_box(proxies)
                    if b is not None:
                        box = tuple(v * 4 for v in b)
                prepared.append({"r": r, "ci": ci, "clip": clip,
                                 "paths": paths, "box": box,
                                 "uniform": uniform, "n": n})

        global_side = 0
        for item in prepared:
            if item["box"] is None:
                continue
            x0, y0, x1, y1 = item["box"]
            side = max(x1 - x0, y1 - y0)
            global_side = max(global_side, side + 2 * int(side * 0.05))

        frames_by_row = {}
        for item in prepared:
            r, ci, clip = item["r"], item["ci"], item["clip"]
            aname = clip.get("name") or r["name"]
            n = item["n"]
            uniform = item["uniform"]
            keyed = []
            for pth in item["paths"]:
                im = Image.open(pth)
                keyed.append(chroma_key(im, effective_key(im, key), tol))
            if fs:  # opt-in pixel-grid mode
                if item["box"] is None or global_side <= 0:
                    print(f"[warn] {aname}: empty after keying, skipped")
                    continue
                cropped = [crop_anchored(f, item["box"], global_side)
                           for f in keyed]
                cand = pixelize_action(cropped, fs, max_colors,
                                       magenta_key=magenta)
            else:   # default: native resolution, untouched geometry
                cand = finalize_native(keyed, magenta_key=magenta)
                if uniform:  # variant A (default): all frames unique
                    uniq, ticks = cand, [1] * len(cand)
                    frames, reps = cand, [1] * len(cand)
                else:
                    # B: key poses chosen by motion, ~hold_frames per pose
                    k = max(2, round(n / hold_frames))
                    uniq, ticks = dedupe_holds(cand, k)
                    # C: bake the holds into the fixed n-column strip
                    frames, reps = expand_to_grid(uniq, ticks, n)
                cw, ch = frames[0].size
                strip = Image.new("RGBA", (len(frames) * cw, ch), (0, 0, 0, 0))
                for i, f in enumerate(frames):
                    strip.paste(f, (i * cw, 0))
                tag = (f"row{r['row']:02d}"
                       f"{chr(97 + ci) if len(r['clips']) > 1 else ''}_{aname}")
                strip.save(out_dir / "actions" / f"{tag}.png")
                cycle_ms = round(n * frame_ms)
                total = sum(ticks)
                durations = ([frame_ms] * len(uniq) if uniform else
                             [max(60, round(cycle_ms * t / total))
                              for t in ticks])
                save_gif(uniq, out_dir / "gifs" / f"{tag}.gif",
                         r.get("one_shot"), cw, durations)
                timings[tag] = {
                    "frames_in_strip": n,
                    "unique_poses": len(uniq),
                    "strip_repeats": reps,
                    "durations_ms": durations,
                    "cycle_ms": cycle_ms,
                    "loop": not r.get("one_shot", False),
                }
                frames_by_row.setdefault(r["row"], []).extend(frames)

        for r in rows:
            row_frames = frames_by_row.get(r["row"], [])
            if len(row_frames) != COLS:
                print(f"[warn] row {r['row']} has {len(row_frames)} frames, "
                      f"expected {COLS}")
            sheet_rows.append((r["row"], row_frames))

    (out_dir / "timings.json").write_text(json.dumps(timings, indent=1))

    # optional combined master sheet (uniform cell = the largest frame)
    cell = max((f.width for _, fr in sheet_rows for f in fr), default=0)
    if cell:
        max_row = max(row_idx for row_idx, _ in sheet_rows)
        sheet = Image.new("RGBA", (COLS * cell, (max_row + 1) * cell),
                          (0, 0, 0, 0))
        for ri, (row_idx, fr) in enumerate(sheet_rows):
            for i, f in enumerate(fr[:COLS]):
                sheet.paste(f, (i * cell + (cell - f.width) // 2,
                                row_idx * cell + (cell - f.height) // 2))
        sheet.save(out_dir / "spritesheet_16x12.png")
    print(f"done -> per-action strips in {out_dir}/actions "
          f"({'native resolution' if not fs else f'{fs}px grid'}), "
          f"optional master {out_dir}/spritesheet_16x12.png")


if __name__ == "__main__":
    main()
