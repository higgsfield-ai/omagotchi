#!/usr/bin/env python3
"""Run the sprite-sheet-8bit pipeline via Higgsfield CLI, then postprocess.

Prints progress lines, then one JSON object on stdout.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

LOG_LOCK = threading.Lock()
PROGRESS_LOCK = threading.Lock()

STYLE = (
    "8-bit pixel art, chunky low-resolution pixels on a coarse pixel grid, "
    "limited NES-era palette (max ~24 colors), hard pixel edges, no anti-aliasing, "
    "no gradients, no blur, flat colors, 1px dark outline, clean readable silhouette"
)

# Overlay plays these names from the 16x12 sheet (look / greet / grumpy / sick included).
PET_MODES = {
    "walk": {"row": 0, "start": 0, "count": 16},
    "idle": {"row": 1, "start": 0, "count": 8},
    "look": {"row": 1, "start": 8, "count": 8},
    "collapse": {"row": 2, "start": 8, "count": 8},
    "drag": {"row": 3, "start": 0, "count": 8},
    "greet": {"row": 3, "start": 8, "count": 8},
    "dance": {"row": 4, "start": 0, "count": 16},
    "flip": {"row": 5, "start": 0, "count": 16},
    "run": {"row": 5, "start": 0, "count": 16},
    "crawl": {"row": 7, "start": 0, "count": 16},
    "grumpy": {"row": 9, "start": 8, "count": 8},
    "sick": {"row": 10, "start": 8, "count": 8},
}

SMOKE_MODES = {
    "walk": {"row": 0, "start": 0, "count": 16},
    "idle": {"row": 0, "start": 0, "count": 16},
    "look": {"row": 0, "start": 0, "count": 16},
    "dance": {"row": 0, "start": 0, "count": 16},
    "flip": {"row": 0, "start": 0, "count": 16},
    "run": {"row": 0, "start": 0, "count": 16},
    "crawl": {"row": 0, "start": 0, "count": 16},
    "collapse": {"row": 0, "start": 0, "count": 1},
    "drag": {"row": 0, "start": 0, "count": 1},
    "greet": {"row": 0, "start": 0, "count": 8},
    "grumpy": {"row": 0, "start": 0, "count": 8},
    "sick": {"row": 0, "start": 0, "count": 8},
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


def progress(msg: str, *, phase: str = "", step: int = 0, steps: int = 0) -> None:
    payload = json.dumps({
        "t": "progress",
        "phase": phase,
        "step": step,
        "steps": steps,
        "label": msg,
        "percent": int(round(100.0 * step / steps)) if steps else 0,
    })
    with PROGRESS_LOCK:
        print(payload, flush=True)


def fail(msg: str, extra: dict | None = None) -> None:
    payload = {"ok": False, "error": msg}
    if extra:
        payload.update(extra)
    if "reason" not in payload:
        payload["reason"] = msg
    print(json.dumps(payload), flush=True)
    sys.exit(1)


def last_json(text: str):
    for line in reversed((text or "").splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def describe_hf_error(text: str) -> str:
    data = last_json(text)
    if not isinstance(data, dict):
        blob = (text or "higgsfield generate failed").strip()
        return blob[-800:] if blob else "higgsfield generate failed"
    err = data.get("error")
    err_obj = err if isinstance(err, dict) else {}
    detail = data.get("detail") if isinstance(data.get("detail"), dict) else {}
    kind = (
        data.get("error_type")
        or err_obj.get("error_type")
        or err_obj.get("type")
        or detail.get("error_type")
        or data.get("type")
        or ""
    )
    msg = ""
    if isinstance(err, str):
        msg = err
    else:
        msg = str(err_obj.get("message") or detail.get("message") or data.get("message") or "")
    actions = []
    for node in (data, err_obj, detail, data.get("input") if isinstance(data.get("input"), dict) else {}):
        raw = node.get("actions") if isinstance(node, dict) else None
        if isinstance(raw, list):
            for item in raw:
                if isinstance(item, dict) and item.get("type"):
                    actions.append(str(item["type"]))
    if not kind and actions:
        kind = actions[0]
    parts = []
    if kind:
        parts.append(str(kind))
    if msg and msg != kind:
        parts.append(msg)
    if actions and kind not in actions:
        parts.append("actions=" + ",".join(actions))
    if parts:
        return ": ".join(parts)[-800:]
    blob = (text or "higgsfield generate failed").strip()
    return blob[-800:]


def is_transient_hf_error(text: str) -> bool:
    low = (text or "").lower()
    return any(token in low for token in (
        "503",
        "502",
        "504",
        "service unavailable",
        "bad gateway",
        "gateway timeout",
        "429",
        "rate limit",
        "too many",
        "timeout",
        "temporar",
        "try again",
        "connection reset",
        "econnreset",
        "ended with status",
        'status "failed"',
        "status 'failed'",
    ))


def is_policy_hf_error(text: str) -> bool:
    low = (text or "").lower()
    return "nsfw" in low or "ip_detected" in low or "content policy" in low


def retry_progress(err: str) -> None:
    if is_job_failed_error(err):
        progress("That generation failed, retrying…", phase="retry")
    else:
        progress("Higgsfield is busy, retrying…", phase="retry")


def is_job_failed_error(text: str) -> bool:
    low = (text or "").lower()
    return "ended with status" in low or 'status "failed"' in low or "status 'failed'" in low


JOB_ID_RE = re.compile(
    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
    re.I,
)


def extract_uuid(text: str) -> str:
    found = JOB_ID_RE.search(text or "")
    return found.group(0) if found else ""


def is_generic_job_status(text: str) -> bool:
    low = (text or "").lower()
    return "ended with status" in low or low in ("failed", "error", "cancelled", "canceled")


def job_reason_from_node(node, depth: int = 0) -> str:
    if node is None or depth > 8:
        return ""
    if isinstance(node, str):
        s = node.strip()
        if s and not is_generic_job_status(s):
            return s[:400]
        return ""
    if isinstance(node, list):
        for item in node:
            found = job_reason_from_node(item, depth + 1)
            if found:
                return found
        return ""
    if not isinstance(node, dict):
        return ""
    for key in (
        "failure_reason",
        "fail_reason",
        "error_message",
        "error_msg",
        "status_reason",
        "reason",
        "message",
        "detail",
        "error",
    ):
        val = node.get(key)
        if isinstance(val, str) and val.strip() and not is_generic_job_status(val):
            return val.strip()[:400]
        if isinstance(val, dict) or isinstance(val, list):
            found = job_reason_from_node(val, depth + 1)
            if found:
                return found
    for flag in ("nsfw", "ip_detected", "moderation"):
        val = node.get(flag)
        if val is True or str(val).lower() in ("true", "1", "yes"):
            return flag
    for key in ("job", "data", "result", "results", "output"):
        if key in node:
            found = job_reason_from_node(node.get(key), depth + 1)
            if found:
                return found
    return ""


def fetch_job(hf: str, job_id: str, log: Path):
    if not hf or not job_id:
        return None
    proc = subprocess.run(
        [hf, "generate", "get", job_id, "--json"],
        capture_output=True,
        text=True,
    )
    append_log(log, (proc.stderr or "") + (proc.stdout or ""))
    return last_json((proc.stdout or "") + "\n" + (proc.stderr or ""))


def explain_job_failure(hf: str, job_id: str, fallback: str, log: Path) -> str:
    data = fetch_job(hf, job_id, log) if job_id else None
    reason = job_reason_from_node(data) if data else ""
    parts = []
    if job_id:
        parts.append("job " + job_id)
    if reason:
        parts.append(reason)
    elif fallback and not is_generic_job_status(fallback):
        parts.append(fallback)
    else:
        parts.append('ended with status "failed"')
    return ": ".join(parts)[-800:]


def bootstrap(plugin_root: Path, out_dir: Path) -> dict:
    runtime = plugin_root / "scripts" / "runtime.py"
    progress("Preparing Higgsfield…", phase="setup", step=0, steps=1)
    proc = subprocess.run(
        [sys.executable, "-u", str(runtime), "ensure", "--out", str(out_dir)],
        capture_output=True,
        text=True,
    )
    data = last_json((proc.stdout or "") + "\n" + (proc.stderr or ""))
    if proc.returncode != 0 or not data or not data.get("ok"):
        err = (data or {}).get("error") or (proc.stderr or proc.stdout or "runtime setup failed")
        fail(str(err)[-800:])
    return data


def find_hf(out_dir: Path | None = None) -> str:
    if out_dir:
        bundled = Path(out_dir) / "bin" / "higgsfield"
        if bundled.is_file() and os.access(bundled, os.X_OK):
            return str(bundled)
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


def append_log(log: Path, text: str) -> None:
    with LOG_LOCK:
        with log.open("a") as fh:
            fh.write(text or "")
            if text and not text.endswith("\n"):
                fh.write("\n")


def extract_job_id(node) -> str:
    if node is None:
        return ""
    if isinstance(node, str):
        s = node.strip()
        if s and " " not in s and len(s) >= 8:
            return s
        return ""
    if isinstance(node, list) and node:
        return extract_job_id(node[0])
    if isinstance(node, dict):
        for key in ("id", "job_id", "jobId", "request_id"):
            val = node.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()
        for key in ("job", "jobs", "data", "result", "results"):
            if key in node:
                found = extract_job_id(node.get(key))
                if found:
                    return found
    return ""


def run_hf(hf: str, cmd: list[str], log: Path) -> dict:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    append_log(log, (proc.stderr or "") + (proc.stdout or ""))
    if proc.returncode != 0:
        err = describe_hf_error(proc.stderr or proc.stdout or "higgsfield generate failed")
        raise RuntimeError(err)
    data = parse_job(proc.stdout or "")
    if not data:
        raise RuntimeError("could not parse CLI JSON")
    return data


def start_job(hf: str, model: str, args: list[str], log: Path) -> str:
    last_err = "higgsfield create failed"
    for delay in (0, 2, 5, 12):
        if delay:
            time.sleep(delay)
        proc = subprocess.run(
            [hf, "generate", "create", model, *args, "--json"],
            capture_output=True,
            text=True,
        )
        append_log(log, (proc.stderr or "") + (proc.stdout or ""))
        lines = (proc.stdout or "").strip().splitlines()
        data = parse_job(proc.stdout or "")
        job_id = extract_job_id(data)
        if not job_id and lines:
            job_id = extract_job_id(lines[-1])
        if proc.returncode == 0 and job_id:
            return job_id
        last_err = describe_hf_error(proc.stderr or proc.stdout or last_err) or last_err
        if proc.returncode == 0 and not job_id:
            last_err = "no job id from higgsfield create"
        low = last_err.lower()
        if is_transient_hf_error(last_err):
            progress("Higgsfield is busy, retrying…", phase="retry")
            continue
        if "upgrade_plan" in low or "not_enough_credits" in low or "credits_exhausted" in low:
            raise RuntimeError(last_err)
        if proc.returncode != 0:
            raise RuntimeError(last_err)
    raise RuntimeError(last_err)


def wait_job(hf: str, job_id: str, log: Path) -> dict:
    try:
        data = run_hf(
            hf,
            [hf, "generate", "wait", job_id, "--json", "--wait-timeout", "15m"],
            log,
        )
    except RuntimeError as exc:
        raise RuntimeError(explain_job_failure(hf, job_id, str(exc), log)) from exc
    url = extract_url(data)
    if url:
        return {"url": url, "raw": data, "id": job_id}
    raise RuntimeError(explain_job_failure(hf, job_id, "no result URL in CLI JSON", log))


def run_generate(hf: str, model: str, args: list[str], log: Path) -> dict:
    last_err = "higgsfield generate failed"
    for delay in (0, 2, 5, 12):
        if delay:
            time.sleep(delay)
            progress("Higgsfield is busy, retrying…", phase="retry")
        try:
            data = run_hf(
                hf,
                [hf, "generate", "create", model, *args, "--wait", "--json", "--wait-timeout", "15m"],
                log,
            )
            url = extract_url(data)
            if not url:
                raise RuntimeError("no result URL in CLI JSON")
            return {"url": url, "raw": data}
        except Exception as exc:
            last_err = str(exc)
            jid = extract_uuid(last_err)
            if jid:
                last_err = explain_job_failure(hf, jid, last_err, log)
            if is_transient_hf_error(last_err) or is_job_failed_error(last_err):
                continue
            raise RuntimeError(last_err) from exc
    raise RuntimeError(last_err)


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


def clip_video_args(clip: dict, key: str, base_path: Path) -> list[str]:
    args = [
        "--prompt", video_prompt(clip["spec"], key, clip["loop"]),
        "--image", str(base_path),
        "--start-image", str(base_path),
        "--aspect_ratio", "1:1",
        "--resolution", "480p",
        "--duration", "5",
        "--generate_audio", "false",
    ]
    if clip["loop"]:
        args += ["--end-image", str(base_path)]
    return args


def generate_clip(hf: str, clip: dict, key: str, base_path: Path, dest: Path, log: Path) -> Path:
    last_err = ""
    video_args = clip_video_args(clip, key, base_path)
    for attempt in range(3):
        try:
            job_id = start_job(hf, "seedance_2_0_mini", video_args, log)
            job = wait_job(hf, job_id, log)
            download(job["url"], dest)
            return dest
        except Exception as exc:
            last_err = str(exc)
            low = last_err.lower()
            if "upgrade_plan" in low or "not_enough_credits" in low or "credits_exhausted" in low:
                break
            if attempt < 2:
                progress("Higgsfield is busy, retrying…", phase="retry")
                time.sleep(4 + attempt * 6)
    raise RuntimeError(f"{clip['name']}: {last_err}")


def write_atlas(out_dir: Path, sheet: Path, rows: int, frame_size: int, smoke: bool) -> tuple[Path, dict]:
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
    return path, atlas


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
    out_dir = Path(os.path.expanduser(args.out)).resolve()
    post = plugin_root / "skill/sprite-sheet-8bit/scripts/postprocess.py"
    if not post.is_file():
        fail(f"postprocess.py missing at {post}")

    runtime = bootstrap(plugin_root, out_dir)
    hf = runtime.get("hf") or find_hf(out_dir)
    venv_py = runtime.get("python") or sys.executable
    if not hf:
        fail("could not install Higgsfield CLI")
    if not runtime.get("ffmpeg_ok"):
        fail("ffmpeg not found. Omarchy should ship ffmpeg; install it from the Omarchy menu if video tools are missing.")

    progress("Selecting workspace…", phase="setup", step=0, steps=1)
    ws_proc = subprocess.run(
        [sys.executable, "-u", str(plugin_root / "scripts" / "runtime.py"), "ensure-workspace", "--out", str(out_dir)],
        capture_output=True,
        text=True,
    )
    ws = last_json((ws_proc.stdout or "") + "\n" + (ws_proc.stderr or ""))
    if ws_proc.returncode != 0 or not ws or not ws.get("ok"):
        fail(str((ws or {}).get("error") or ws_proc.stderr or ws_proc.stdout or "No Higgsfield workspace selected")[-800:])

    try:
        sys.path.insert(0, str(Path(venv_py).resolve().parent.parent / "lib"))
        for site in (out_dir / "venv" / "lib").glob("python*/site-packages"):
            sys.path.insert(0, str(site))
        import numpy  # noqa: F401
        from PIL import Image  # noqa: F401
    except ImportError:
        fail("could not load Pillow/numpy after setup")
    clips_dir = out_dir / "clips"
    work_dir = out_dir / "work"
    out_dir.mkdir(parents=True, exist_ok=True)
    clips_dir.mkdir(parents=True, exist_ok=True)
    work_dir.mkdir(parents=True, exist_ok=True)
    log = out_dir / "generate.log"
    log.write_text(f"# {time.strftime('%Y-%m-%d %H:%M:%S')}\nimage={image}\n")

    key = pick_key_color(image)
    jobs = CLIPS[:1] if args.smoke else CLIPS
    total = 2 + len(jobs)  # base + clips + postprocess

    progress("Drawing the base sprite…", phase="base", step=0, steps=total)
    try:
        base_job = run_generate(hf, "nano_banana_2", [
            "--prompt", base_prompt(key, args.notes),
            "--image", str(image),
            "--aspect_ratio", "1:1",
            "--resolution", "1k",
        ], log)
    except Exception as exc:
        fail(str(exc), {"reason": str(exc), "job_id": extract_uuid(str(exc)), "log": str(log)})
    base_path = work_dir / "base.png"
    download(base_job["url"], base_path)
    progress("Base sprite ready", phase="base", step=1, steps=total)

    plan_rows = {}
    completed = {"n": 0}
    finished = {}
    progress(
        f"Starting {len(jobs)} clips together…",
        phase="clip",
        step=1,
        steps=total,
    )

    def run_one(clip: dict) -> tuple[dict, Path]:
        dest = clips_dir / f"r{clip['row']:02d}_{clip['name']}.mp4"
        generate_clip(hf, clip, key, base_path, dest, log)
        return clip, dest

    try:
        with ThreadPoolExecutor(max_workers=max(1, len(jobs))) as pool:
            futures = [pool.submit(run_one, clip) for clip in jobs]
            for fut in as_completed(futures):
                clip, dest = fut.result()
                finished[id(clip)] = dest
                completed["n"] += 1
                n = completed["n"]
                progress(
                    f"{n}/{len(jobs)} clips ready · {clip['name']}",
                    phase="clip",
                    step=1 + n,
                    steps=total,
                )
    except Exception as exc:
        fail(str(exc), {"reason": str(exc), "job_id": extract_uuid(str(exc)), "log": str(log)})

    for clip in jobs:
        dest = finished[id(clip)]
        plan_rows.setdefault(clip["row"], {
            "row": clip["row"],
            "name": clip["name"],
            "one_shot": not clip["loop"],
            "clips": [],
        })
        plan_rows[clip["row"]]["clips"].append({
            "path": str(dest),
            "frames": clip["frames"],
            "name": clip["name"],
        })
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

    progress("Cutting frames…", phase="post", step=total - 1, steps=total)
    proc = subprocess.run([venv_py, str(post), str(plan_path)], capture_output=True, text=True)
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

    atlas_path, atlas_spec = write_atlas(out_dir, sheet_dest, 1 if args.smoke else 12, args.frame_size, args.smoke)
    progress("Tamagotchi ready", phase="done", step=total, steps=total)
    print(json.dumps({
        "ok": True,
        "path": str(sheet_dest),
        "atlas": str(atlas_path),
        "atlas_spec": atlas_spec,
        "base": str(base_path),
        "smoke": bool(args.smoke),
        "model": "seedance_2_0_mini",
    }), flush=True)


if __name__ == "__main__":
    main()
