#!/usr/bin/env python3
"""Run the sprite-sheet-8bit pipeline via Higgsfield CLI, then postprocess.

Prints progress lines, then one JSON object on stdout.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

STYLE = (
    "8-bit pixel art, chunky low-resolution pixels on a coarse pixel grid, "
    "limited NES-era palette (max ~24 colors), hard pixel edges, no anti-aliasing, "
    "no gradients, no blur, flat colors, 1px dark outline, clean readable silhouette"
)

# Pet overlay currently plays these six names. The sheet still contains all 12 rows.
PET_MODES = {
    "walk": {"row": 0, "start": 0, "count": 16},
    "idle": {"row": 1, "start": 0, "count": 8},
    "dance": {"row": 4, "start": 0, "count": 16},
    "flip": {"row": 5, "start": 0, "count": 16},
    "collapse": {"row": 2, "start": 8, "count": 8},
    "drag": {"row": 3, "start": 0, "count": 8},
}

SMOKE_MODES = {
    "walk": {"row": 0, "start": 0, "count": 16},
    "idle": {"row": 0, "start": 0, "count": 16},
    "dance": {"row": 0, "start": 0, "count": 16},
    "flip": {"row": 0, "start": 0, "count": 16},
    "collapse": {"row": 0, "start": 0, "count": 1},
    "drag": {"row": 0, "start": 0, "count": 1},
}

CLIPS = [
    {"row": 0, "name": "walk", "frames": 16, "loop": True,
     "spec": "WALK: side-view walk/run cycle facing right, full gait, arms and legs clear, upright then slight forward lean as speed builds"},
    {"row": 1, "name": "idle", "frames": 8, "loop": True,
     "spec": "IDLE: subtle idle bob/breath facing 3/4 right"},
    {"row": 1, "name": "look", "frames": 8, "loop": True,
     "spec": "LOOK-AROUND: gentle head/torso turns (right, camera, left, back to right) while standing"},
    {"row": 2, "name": "sleep", "frames": 8, "loop": True,
     "spec": "SLEEP: lying on side or curled, eyes closed, tiny breathing"},
    {"row": 2, "name": "collapse", "frames": 8, "loop": True,
     "spec": "COLLAPSE/LIE: flat on stomach/back minimized pose, awake or half-awake, readable silhouette"},
    {"row": 3, "name": "drag", "frames": 8, "loop": True,
     "spec": "DRAG/CARRIED: tucked knees mid-air hold/jump pose variations"},
    {"row": 3, "name": "greet", "frames": 8, "loop": True,
     "spec": "GREET/WAVE: facing camera/3-4, friendly wave or both-hands hello"},
    {"row": 4, "name": "dance", "frames": 16, "loop": True,
     "spec": "DANCE/CHEER: music celebration facing camera/3-4, arms up, stepping in place, joyful cycle"},
    {"row": 5, "name": "flip", "frames": 16, "loop": True,
     "spec": "DASH/FLIP ENERGY: aggressive sprint facing right, long strides, strong lean, high energy, hype peak"},
    {"row": 6, "name": "sneak", "frames": 16, "loop": True,
     "spec": "SNEAK: deep crouch walk facing right, torso low, careful steps"},
    {"row": 7, "name": "crawl", "frames": 16, "loop": True,
     "spec": "CRAWL: on all fours facing right, crawling loop"},
    {"row": 8, "name": "trip", "frames": 16, "loop": False,
     "spec": "TRIP/FACEPLANT one-shot: stumble then fall forward then hit ground then briefly flat, clear progression"},
    {"row": 9, "name": "happy", "frames": 8, "loop": True,
     "spec": "HAPPY/LOVE: big smile, optional small pixel hearts above head (clean pixels, no blur)"},
    {"row": 9, "name": "grumpy", "frames": 8, "loop": True,
     "spec": "GRUMPY/ANGRY: frown, crossed arms or dismissive gesture, same character"},
    {"row": 10, "name": "eat", "frames": 8, "loop": True,
     "spec": "EAT/SNACK: holding a small snack/drink, chew or sip cycle"},
    {"row": 10, "name": "sick", "frames": 8, "loop": True,
     "spec": "SICK/DIZZY: light pale/greenish tint on face only, dizzy swirl or hand-to-head, woozy stance, outfit readable"},
    {"row": 11, "name": "wash", "frames": 8, "loop": True,
     "spec": "WASH/HYGIENE: soap bubbles or towel wipe, clean and happy"},
    {"row": 11, "name": "night", "frames": 8, "loop": True,
     "spec": "NIGHT/RAINCOAT: same character in a simple darker jacket or tiny hood/coat variant, optional pixel raindrops, standing/idle poses — cosmetic outfit only, identity unchanged"},
]


def progress(msg: str) -> None:
    print(msg, flush=True)


def fail(msg: str, extra: dict | None = None) -> None:
    payload = {"ok": False, "error": msg}
    if extra:
        payload.update(extra)
    print(json.dumps(payload), flush=True)
    sys.exit(1)


def find_hf() -> str:
    for name in ("higgsfield", "hf"):
        found = shutil.which(name)
        if found:
            return found
    home = Path.home()
    for path in (
        home / ".local/bin/higgsfield",
        Path("/usr/local/bin/higgsfield"),
        Path("/opt/homebrew/bin/higgsfield"),
    ):
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
    return ""


def extract_url(node) -> str:
    if node is None:
        return ""
    if isinstance(node, str):
        return node if node.startswith("http") else ""
    if isinstance(node, list):
        for item in node:
            url = extract_url(item)
            if url:
                return url
        return ""
    if isinstance(node, dict):
        for key in ("result_url", "url", "output_url", "image_url", "video_url"):
            val = node.get(key)
            if isinstance(val, str) and val.startswith("http"):
                return val
        for key in ("results", "output", "outputs", "assets", "data", "job", "jobs", "media", "images", "files"):
            if key in node:
                url = extract_url(node.get(key))
                if url:
                    return url
    return ""


def parse_job(raw: str):
    text = raw.strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("http://") or line.startswith("https://"):
                return {"result_url": line}
    return None


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "higgsfield.signals-omarchy/0.13"})
    with urllib.request.urlopen(req, timeout=180) as resp, open(dest, "wb") as fh:
        while True:
            chunk = resp.read(1024 * 256)
            if not chunk:
                break
            fh.write(chunk)


def run_generate(hf: str, model: str, args: list[str], log: Path) -> dict:
    cmd = [hf, "generate", "create", model, *args, "--wait", "--json", "--wait-timeout", "15m"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    with log.open("a") as fh:
        fh.write(proc.stderr or "")
        fh.write(proc.stdout or "")
        fh.write("\n")
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "higgsfield generate failed").strip()[-800:]
        raise RuntimeError(err)
    data = parse_job(proc.stdout or "")
    if not data:
        raise RuntimeError("could not parse CLI JSON")
    url = extract_url(data)
    if not url:
        raise RuntimeError("no result URL in CLI JSON")
    return {"url": url, "raw": data}


def pick_key_color(path: Path) -> str:
    try:
        from PIL import Image
        import numpy as np
    except ImportError:
        return "#FF00FF"
    im = Image.open(path).convert("RGB").resize((48, 48))
    arr = np.asarray(im).astype("int32")
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    magenta = ((r > 140) & (b > 140) & (g < 0.7 * np.minimum(r, b))).mean()
    green = ((g > 140) & (g > 1.4 * np.maximum(r, b))).mean()
    if magenta > 0.08 and green > 0.08:
        return "#0000FF"
    if magenta > 0.08:
        return "#00FF00"
    return "#FF00FF"


def video_prompt(spec: str, key: str, loop: bool) -> str:
    extra = ", seamless loop" if loop else ""
    return (
        f"{spec}, {STYLE}, locked static camera, character centered and fully in "
        f"frame, flat solid {key} background that never changes, no camera motion, "
        f"no zoom, no background elements, no text{extra}"
    )


def base_prompt(key: str, notes: str) -> str:
    extra = (" " + notes.strip()) if notes.strip() else ""
    return (
        f"{STYLE}. Full body, standing, facing right, centered, nothing cropped, "
        f"solid {key} background, no ground plane, no cast shadow. Keep the "
        f"character's recognizable traits (hair, outfit colors, distinctive features) "
        f"translated into 8-bit.{extra}"
    )


def write_atlas(out_dir: Path, sheet: Path, rows: int, frame_size: int, smoke: bool) -> Path:
    atlas = {
        "file": str(sheet),
        "cellWidth": frame_size,
        "cellHeight": frame_size,
        "columns": 16,
        "rows": rows,
        "fps": 10,
        "scale": 1,
        "modes": SMOKE_MODES if smoke else PET_MODES,
    }
    path = out_dir / "atlas.json"
    path.write_text(json.dumps(atlas, indent=2) + "\n")
    return path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument("--notes", default="")
    parser.add_argument("--plugin-root", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--frame-size", type=int, default=80)
    args = parser.parse_args()

    image = Path(os.path.expanduser(args.image)).resolve()
    if not image.is_file():
        fail(f"image not found: {image}")

    plugin_root = Path(args.plugin_root).resolve()
    post = plugin_root / "skill/sprite-sheet-8bit/scripts/postprocess.py"
    if not post.is_file():
        fail(f"postprocess.py missing at {post}")

    for bin_name in ("ffmpeg", "ffprobe"):
        if not shutil.which(bin_name):
            fail(f"{bin_name} not found. Install: pacman -S ffmpeg")

    try:
        import numpy  # noqa: F401
        from PIL import Image  # noqa: F401
    except ImportError:
        fail("python deps missing. Install: pacman -S python-pillow python-numpy")

    hf = find_hf()
    if not hf:
        fail("higgsfield CLI not found. Install it and run: higgsfield auth login")

    out_dir = Path(os.path.expanduser(args.out)).resolve()
    clips_dir = out_dir / "clips"
    work_dir = out_dir / "work"
    out_dir.mkdir(parents=True, exist_ok=True)
    clips_dir.mkdir(parents=True, exist_ok=True)
    work_dir.mkdir(parents=True, exist_ok=True)
    log = out_dir / "generate.log"
    log.write_text(f"# {time.strftime('%Y-%m-%d %H:%M:%S')}\nimage={image}\n")

    key = pick_key_color(image)
    jobs = CLIPS[:1] if args.smoke else CLIPS

    progress(f"Base sprite ({key})…")
    try:
        base_job = run_generate(hf, "nano_banana_2", [
            "--prompt", base_prompt(key, args.notes),
            "--image", str(image),
            "--aspect_ratio", "1:1",
            "--resolution", "1k",
        ], log)
    except Exception as exc:
        fail(str(exc))
    base_path = work_dir / "base.png"
    download(base_job["url"], base_path)

    plan_rows = {}
    for i, clip in enumerate(jobs, start=1):
        progress(f"Clip {i}/{len(jobs)}: {clip['name']}…")
        video_args = [
            "--prompt", video_prompt(clip["spec"], key, clip["loop"]),
            "--image", str(base_path),
            "--start-image", str(base_path),
            "--aspect_ratio", "1:1",
            "--resolution", "480p",
            "--duration", "5",
            "--generate_audio", "false",
        ]
        if clip["loop"]:
            video_args += ["--end-image", str(base_path)]
        last_err = ""
        dest = clips_dir / f"r{clip['row']:02d}_{clip['name']}.mp4"
        for attempt in range(2):
            try:
                job = run_generate(hf, "seedance_2_0_mini", video_args, log)
                download(job["url"], dest)
                last_err = ""
                break
            except Exception as exc:
                last_err = str(exc)
                progress(f"Retry {clip['name']} ({attempt + 1}/2)…")
        if last_err:
            fail(f"{clip['name']}: {last_err}")
        plan_rows.setdefault(clip["row"], {"row": clip["row"], "name": clip["name"], "one_shot": not clip["loop"], "clips": []})
        plan_rows[clip["row"]]["clips"].append({
            "path": str(dest),
            "frames": clip["frames"],
            "name": clip["name"],
        })
        # Row display name: first clip name unless split
        if len(plan_rows[clip["row"]]["clips"]) == 1:
            plan_rows[clip["row"]]["name"] = clip["name"]

    plan = {
        "frame_size": args.frame_size,
        "max_colors": 0,
        "key_color": key,
        "key_tolerance": 110,
        "out_dir": str(work_dir / "sheet"),
        "rows": [plan_rows[k] for k in sorted(plan_rows)],
    }
    plan_path = work_dir / "plan.json"
    plan_path.write_text(json.dumps(plan, indent=2) + "\n")

    progress("Post-process…")
    proc = subprocess.run([sys.executable, str(post), str(plan_path)], capture_output=True, text=True)
    with log.open("a") as fh:
        fh.write(proc.stdout or "")
        fh.write(proc.stderr or "")
    if proc.returncode != 0:
        fail((proc.stderr or proc.stdout or "postprocess failed").strip()[-800:])

    sheet_src = work_dir / "sheet" / "spritesheet_16x12.png"
    if not sheet_src.is_file():
        fail("postprocess did not write spritesheet_16x12.png")
    sheet_dest = out_dir / "spritesheet_16x12.png"
    shutil.copy2(sheet_src, sheet_dest)
    actions_src = work_dir / "sheet" / "actions"
    if actions_src.is_dir():
        actions_dest = out_dir / "actions"
        if actions_dest.exists():
            shutil.rmtree(actions_dest)
        shutil.copytree(actions_src, actions_dest)

    atlas_path = write_atlas(out_dir, sheet_dest, 1 if args.smoke else 12, args.frame_size, args.smoke)
    progress("Saved " + str(sheet_dest))
    print(json.dumps({
        "ok": True,
        "path": str(sheet_dest),
        "atlas": str(atlas_path),
        "base": str(base_path),
        "smoke": bool(args.smoke),
        "model": "seedance_2_0_mini",
    }), flush=True)


if __name__ == "__main__":
    main()
