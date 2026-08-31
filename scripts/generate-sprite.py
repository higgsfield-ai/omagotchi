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
    "sleep": {"row": 2, "start": 0, "count": 8},
    "collapse": {"row": 2, "start": 8, "count": 8},
    "drag": {"row": 3, "start": 0, "count": 8},
    "greet": {"row": 3, "start": 8, "count": 8},
    "dance": {"row": 4, "start": 0, "count": 16},
    "flip": {"row": 5, "start": 0, "count": 16},
    "run": {"row": 5, "start": 0, "count": 16},
    "sneak": {"row": 6, "start": 0, "count": 16},
    "crawl": {"row": 7, "start": 0, "count": 16},
    "trip": {"row": 8, "start": 0, "count": 16},
    "happy": {"row": 9, "start": 0, "count": 8},
    "grumpy": {"row": 9, "start": 8, "count": 8},
    "eat": {"row": 10, "start": 0, "count": 8},
    "sick": {"row": 10, "start": 8, "count": 8},
    "wash": {"row": 11, "start": 0, "count": 8},
    "night": {"row": 11, "start": 8, "count": 8},
}

SMOKE_MODES = {
    "walk": {"row": 0, "start": 0, "count": 16},
    "idle": {"row": 0, "start": 0, "count": 16},
    "look": {"row": 0, "start": 0, "count": 16},
    "sleep": {"row": 0, "start": 0, "count": 8},
    "sneak": {"row": 0, "start": 0, "count": 16},
    "trip": {"row": 0, "start": 0, "count": 16},
    "happy": {"row": 0, "start": 0, "count": 8},
    "eat": {"row": 0, "start": 0, "count": 8},
    "wash": {"row": 0, "start": 0, "count": 8},
    "night": {"row": 0, "start": 0, "count": 8},
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


JOB_ID_RE = re.compile(
    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
    re.I,
)


def extract_uuid(text: str) -> str:
    found = JOB_ID_RE.search(text or "")
    return found.group(0) if found else ""


JOB_OK = frozenset({"completed", "complete", "succeeded", "success", "done", "finished"})
JOB_BAD = frozenset({"failed", "cancelled", "canceled", "rejected"})


def is_generic_job_status(text: str) -> bool:
    low = (text or "").lower()
    return "ended with status" in low or low in ("failed", "error", "cancelled", "canceled")


def is_transport_error(text: str) -> bool:
    low = (text or "").lower()
    return any(tok in low for tok in (
        "503",
        "502",
        "504",
        "service unavailable",
        "bad gateway",
        "gateway timeout",
        "timed out",
        "timeout",
        "temporar",
        "try again",
        "econnreset",
        "connection reset",
        "connection refused",
        "broken pipe",
    ))


def extract_status(node, depth: int = 0) -> str:
    if node is None or depth > 8:
        return ""
    if isinstance(node, list):
        for item in node:
            found = extract_status(item, depth + 1)
            if found:
                return found
        return ""
    if not isinstance(node, dict):
        return ""
    for key in ("status", "state", "job_status"):
        val = node.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip().lower()
    for key in ("job", "data", "result", "results"):
        if key in node:
            found = extract_status(node.get(key), depth + 1)
            if found:
                return found
    return ""


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
    blob = (proc.stderr or "") + (proc.stdout or "")
    append_log(log, blob)
    data = parse_job(proc.stdout or "") or last_json(proc.stdout or "") or last_json(blob)
    if data and is_transport_payload(data):
        return None
    return data


def explain_job_failure(hf: str, job_id: str, fallback: str, log: Path) -> str:
    data = fetch_job(hf, job_id, log) if job_id else None
    if data and is_transport_payload(data):
        data = None
    reason = job_reason_from_node(data) if data else ""
    if reason and is_transport_error(reason) and not extract_status(data or {}):
        reason = ""
    parts = []
    if job_id:
        parts.append("job " + job_id)
    if reason:
        parts.append(reason)
    elif fallback and not is_generic_job_status(fallback) and not is_transport_error(fallback):
        parts.append(fallback)
    elif fallback and not is_generic_job_status(fallback):
        parts.append("lost contact while waiting — job may still be finished on higgsfield.ai")
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


def looks_like_media_url(url: str) -> bool:
    low = (url or "").lower()
    path = low.split("?")[0]
    if re.search(r"\.(png|jpe?g|webp|gif|mp4|webm|mov|m4v)$", path):
        return True
    if re.search(r"https?://(www\.)?higgsfield\.ai(/|$)", low):
        return False
    return any(tok in low for tok in (
        "cdn.", "s3.", "storage.", "cloudfront", "blob.", "/media",
        "googleapis", "x-amz", "r2.", "files.", "fal.", "higgsfield",
    ))


INPUT_KEYS = frozenset({
    "input", "image", "start_image", "end_image", "start-image", "end-image",
    "init_image", "prompt", "thumbnail", "thumb", "preview", "source",
    "reference", "ref", "photo", "params", "parameters", "request",
})
OUTPUT_URL_KEYS = (
    "result_url", "output_url", "video_url", "download_url", "signed_url",
    "file_url", "media_url", "asset_url", "raw_url", "playable_url",
    "mp4_url", "webm_url",
)
OUTPUT_CONTAINERS = (
    "results", "result", "output", "outputs", "assets", "media", "files",
    "videos", "images", "video",
)
PENDING = frozenset({
    "queued", "pending", "running", "processing", "in_progress", "waiting",
    "created", "submitted", "started",
})


def extract_url(node, depth: int = 0) -> str:
    if node is None or depth > 8:
        return ""
    if isinstance(node, str):
        return node if node.startswith("http") and looks_like_media_url(node) else ""
    if isinstance(node, list):
        for item in node:
            url = extract_url(item, depth + 1)
            if url:
                return url
        return ""
    if not isinstance(node, dict):
        return ""
    for key in OUTPUT_URL_KEYS:
        val = node.get(key)
        if isinstance(val, str) and val.startswith("http"):
            return val
    val = node.get("url")
    if isinstance(val, str) and val.startswith("http") and looks_like_media_url(val):
        return val
    for key in OUTPUT_CONTAINERS:
        if key in node:
            url = extract_url(node.get(key), depth + 1)
            if url:
                return url
    if depth > 0:
        val = node.get("url")
        if isinstance(val, str) and val.startswith("http") and looks_like_media_url(val):
            return val
    for key, val in node.items():
        if key in INPUT_KEYS or key in OUTPUT_URL_KEYS or key in OUTPUT_CONTAINERS:
            continue
        if isinstance(val, (dict, list)):
            url = extract_url(val, depth + 1)
            if url:
                return url
    return ""


def job_result(job_id: str, data) -> dict | None:
    if not data:
        return None
    status = extract_status(data)
    if status in JOB_BAD or status in PENDING:
        return None
    url = extract_url(data)
    if not url:
        return None
    return {"url": url, "raw": data, "id": job_id}


def is_transport_payload(data) -> bool:
    if not isinstance(data, dict):
        return False
    if extract_status(data) or extract_url(data) or extract_job_id(data):
        return False
    return is_transport_error(json.dumps(data))


def is_hard_failure(text: str) -> bool:
    low = (text or "").lower()
    return any(tok in low for tok in (
        "upgrade_plan",
        "not_enough_credits",
        "credits_exhausted",
        "out_of_credits",
        "not enough credits",
    ))


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


def is_unknown_flag_error(text: str) -> bool:
    low = (text or "").lower()
    return "unknown flag" in low or "unknown shorthand" in low or "flag provided but not defined" in low


WAIT_FLAG_VARIANTS = (
    [],
    ["--timeout", "15m"],
    ["--wait-timeout", "15m"],
)
_WAIT_FLAGS = None


def hf_with_wait_flags(hf: str, base: list[str], log: Path) -> dict:
    global _WAIT_FLAGS
    variants = WAIT_FLAG_VARIANTS
    if _WAIT_FLAGS is not None:
        variants = [_WAIT_FLAGS]
    last_err = "higgsfield wait failed"
    for flags in variants:
        cmd = [*base, *flags]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        blob = (proc.stderr or "") + "\n" + (proc.stdout or "")
        append_log(log, blob)
        if proc.returncode != 0 and is_unknown_flag_error(blob):
            last_err = describe_hf_error(blob)
            continue
        if proc.returncode != 0:
            raise RuntimeError(describe_hf_error(blob))
        data = parse_job(proc.stdout or "")
        if not data:
            raise RuntimeError("could not parse CLI JSON")
        _WAIT_FLAGS = flags
        return data
    raise RuntimeError(last_err)


POLL_SECONDS = 20 * 60


def poll_job(hf: str, job_id: str, log: Path) -> dict:
    deadline = time.time() + POLL_SECONDS
    delay = 2.0
    last_good = None
    status = ""
    while time.time() < deadline:
        data = fetch_job(hf, job_id, log)
        if data is not None:
            last_good = data
            status = extract_status(data)
            if status in JOB_BAD:
                raise RuntimeError(explain_job_failure(hf, job_id, status, log))
            found = job_result(job_id, data)
            if found:
                return found
        extra = 0.0
        try:
            extra = (int(job_id.replace("-", "")[:4], 16) % 800) / 1000.0
        except ValueError:
            extra = (hash(job_id) % 800) / 1000.0
        time.sleep(delay + extra)
        delay = min(delay * 1.4, 10)
    if last_good is not None:
        found = job_result(job_id, last_good)
        if found:
            return found
        status = extract_status(last_good)
    if status in JOB_OK:
        raise RuntimeError(explain_job_failure(hf, job_id, "completed but no media URL", log))
    raise RuntimeError(explain_job_failure(
        hf, job_id, "lost contact while waiting — job may still be finished on higgsfield.ai", log,
    ))


# One Higgsfield create per call. Failures surface to the panel; only Retry starts again.
def start_job(hf: str, model: str, args: list[str], log: Path) -> str:
    proc = subprocess.run(
        [hf, "generate", "create", model, *args, "--json"],
        capture_output=True,
        text=True,
    )
    blob = (proc.stdout or "") + "\n" + (proc.stderr or "")
    append_log(log, blob)
    data = parse_job(proc.stdout or "") or last_json(blob)
    job_id = extract_job_id(data)
    if not job_id and proc.returncode == 0:
        job_id = extract_uuid(blob)
    if job_id and proc.returncode == 0:
        return job_id
    if extract_job_id(data) and is_transport_error(blob):
        return extract_job_id(data)
    raise RuntimeError(describe_hf_error(proc.stderr or proc.stdout or "higgsfield create failed"))


def wait_job(hf: str, job_id: str, log: Path) -> dict:
    # Wait can 503 or print "failed" after the job already completed. Confirm via get.
    try:
        data = hf_with_wait_flags(
            hf,
            [hf, "generate", "wait", job_id, "--json"],
            log,
        )
        found = job_result(job_id, data)
        if found:
            return found
    except RuntimeError:
        pass
    return poll_job(hf, job_id, log)


def run_generate(hf: str, model: str, args: list[str], log: Path) -> dict:
    job_id = start_job(hf, model, args, log)
    return wait_job(hf, job_id, log)


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


CLIP_STOP = threading.Event()
CREATE_WORKERS = 6
WAIT_WORKERS = 8


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
    CLIP_STOP.clear()
    progress(
        f"Submitting {len(jobs)} clip jobs…",
        phase="clip",
        step=1,
        steps=total,
    )

    submitted: list[tuple[dict, str, Path]] = []
    create_errors: list[str] = []

    def create_one(clip: dict) -> tuple[dict, str, Path]:
        if CLIP_STOP.is_set():
            raise RuntimeError(f"{clip['name']}: skipped after a billing failure")
        dest = clips_dir / f"r{clip['row']:02d}_{clip['name']}.mp4"
        job_id = start_job(hf, "seedance_2_0_mini", clip_video_args(clip, key, base_path), log)
        return clip, job_id, dest

    create_pool = ThreadPoolExecutor(max_workers=min(CREATE_WORKERS, len(jobs)))
    create_futs = [create_pool.submit(create_one, clip) for clip in jobs]
    try:
        for fut in as_completed(create_futs):
            try:
                clip, job_id, dest = fut.result()
                submitted.append((clip, job_id, dest))
                progress(
                    f"Submitted {len(submitted)}/{len(jobs)} · {clip['name']}",
                    phase="clip",
                    step=1,
                    steps=total,
                )
            except Exception as exc:
                err = str(exc)
                create_errors.append(err)
                if is_hard_failure(err):
                    CLIP_STOP.set()
                    create_pool.shutdown(wait=False, cancel_futures=True)
                    fail(err, {"reason": err, "job_id": extract_uuid(err), "log": str(log)})
        create_pool.shutdown(wait=True)
    except Exception as exc:
        CLIP_STOP.set()
        create_pool.shutdown(wait=False, cancel_futures=True)
        fail(str(exc), {"reason": str(exc), "job_id": extract_uuid(str(exc)), "log": str(log)})

    if not submitted:
        err = create_errors[0] if create_errors else "no clip jobs submitted"
        fail(err, {"reason": err, "job_id": extract_uuid(err), "log": str(log)})

    progress(
        f"Waiting for {len(submitted)} clips…",
        phase="clip",
        step=1,
        steps=total,
    )

    wait_errors: list[str] = []

    def wait_one(item: tuple[dict, str, Path]) -> tuple[dict, Path]:
        clip, job_id, dest = item
        job = wait_job(hf, job_id, log)
        download(job["url"], dest)
        return clip, dest

    wait_pool = ThreadPoolExecutor(max_workers=min(WAIT_WORKERS, len(submitted)))
    wait_futs = [wait_pool.submit(wait_one, item) for item in submitted]
    for fut in as_completed(wait_futs):
        try:
            clip, dest = fut.result()
            finished[id(clip)] = dest
            completed["n"] += 1
            n = completed["n"]
            progress(
                f"{n}/{len(submitted)} clips ready · {clip['name']}",
                phase="clip",
                step=1 + n,
                steps=total,
            )
        except Exception as exc:
            wait_errors.append(str(exc))
    wait_pool.shutdown(wait=True)

    if wait_errors or len(finished) < len(jobs) or create_errors:
        err = (wait_errors or create_errors or ["missing clips"])[0]
        fail(err, {"reason": err, "job_id": extract_uuid(err), "log": str(log)})

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
