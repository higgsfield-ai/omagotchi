#!/usr/bin/env python3
"""
sprite-sheet-8bit post-processor.

Turns per-action video clips into per-action sprite strips. DEFAULT pipeline:
  sample frames evenly -> chroma-key (enclosed regions included) -> despill
  (rim + global soft pass) -> NATIVE clip resolution, untouched geometry ->
  per-action strip PNG + preview GIF + optional combined master sheet.
No crop, no downscale, no quantization by default.

Opt-in extras via plan.json:
  "frame_size": N   (> 0) pixel-grid mode: ONE fixed crop box per clip,
                    BOX downscale to NxN;
  "max_colors": M   (> 0) snap each action to ONE shared MEDIANCUT palette.

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
GIF_FPS = 10


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


def crop_fixed_square(img, box, pad_ratio=0.05):
    """Crop the SAME padded square in every frame -> stable position/scale."""
    x0, y0, x1, y1 = box
    side = max(x1 - x0, y1 - y0)
    side += 2 * int(side * pad_ratio)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    half = side // 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    bx = (max(cx - half, 0), max(cy - half, 0),
          min(cx + half, img.width), min(cy + half, img.height))
    region = img.crop(bx)
    canvas.paste(region, ((side - region.width) // 2,
                          (side - region.height) // 2))
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


def save_gif(frames, path, one_shot, fs):
    """Preview GIF: neutral dark backdrop; NEAREST upscale only for tiny
    pixel-grid frames (native-resolution frames go out as-is)."""
    scale = max(1, 256 // fs) if fs and fs < 256 else 1
    gif = []
    for f in frames:
        bg = Image.new("RGBA", f.size, (34, 34, 46, 255))
        bg.alpha_composite(f)
        big = bg.convert("RGB").resize(
            (f.width * scale, f.height * scale), Image.NEAREST)
        gif.append(big.convert("P", palette=Image.ADAPTIVE, colors=64))
    gif[0].save(path, save_all=True, append_images=gif[1:],
                duration=int(1000 / GIF_FPS), loop=1 if one_shot else 0)


def main():
    plan = json.loads(Path(sys.argv[1]).read_text())
    fs = int(plan.get("frame_size", 0))  # 0 = NATIVE: no crop, no downscale
    max_colors = int(plan.get("max_colors", 0))  # quantization OFF by default
    key = hex_to_rgb(plan["key_color"])
    tol = int(plan.get("key_tolerance", 110))
    out_dir = Path(plan.get("out_dir", "out"))
    (out_dir / "actions").mkdir(parents=True, exist_ok=True)
    (out_dir / "gifs").mkdir(parents=True, exist_ok=True)

    rows = sorted(plan["rows"], key=lambda r: r["row"])
    magenta = key[0] > 200 and key[2] > 200
    sheet_rows = []

    with tempfile.TemporaryDirectory() as tmp:
        for r in rows:
            row_frames = []
            for ci, clip in enumerate(r["clips"]):
                aname = clip.get("name") or r["name"]
                keyed = [chroma_key(Image.open(p), key, tol)
                         for p in sample_frames(clip["path"], clip["frames"],
                                                tmp)]
                if fs:  # opt-in pixel-grid mode
                    box = union_box(keyed)
                    if box is None:
                        print(f"[warn] {aname}: empty after keying, skipped")
                        continue
                    cropped = [crop_fixed_square(f, box) for f in keyed]
                    frames = pixelize_action(cropped, fs, max_colors,
                                             magenta_key=magenta)
                else:   # default: native resolution, untouched geometry
                    frames = finalize_native(keyed, magenta_key=magenta)
                cw, ch = frames[0].size
                strip = Image.new("RGBA", (len(frames) * cw, ch), (0, 0, 0, 0))
                for i, f in enumerate(frames):
                    strip.paste(f, (i * cw, 0))
                tag = (f"row{r['row']:02d}"
                       f"{chr(97 + ci) if len(r['clips']) > 1 else ''}_{aname}")
                strip.save(out_dir / "actions" / f"{tag}.png")
                save_gif(frames, out_dir / "gifs" / f"{tag}.gif",
                         r.get("one_shot"), cw)
                row_frames += frames
            if len(row_frames) != COLS:
                print(f"[warn] row {r['row']} has {len(row_frames)} frames, "
                      f"expected {COLS}")
            sheet_rows.append((r["row"], row_frames))

    # optional combined master sheet (uniform cell = the largest frame)
    cell = max((f.width for _, fr in sheet_rows for f in fr), default=0)
    if cell:
        sheet = Image.new("RGBA", (COLS * cell, len(sheet_rows) * cell),
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
