#!/usr/bin/env python3
"""Run the sprite-sheet-8bit pipeline via Higgsfield CLI, then postprocess.

Prints progress lines, then one JSON object on stdout.
"""
from __future__ import annotations

import argparse
import json
import os
import random  # retry jitter only, nothing security-sensitive
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

# The concrete density anchor ("~64 pixels head to feet") is what separates
# a finely drawn sprite from giant duplo blocks — every time it eroded from
# this string, base quality dropped. The zoom/bust side effects it used to
# cause are handled by the numeric guards now, not by softening the anchor.
STYLE = (
    "8-bit pixel art drawn at high pixel density — about 64 pixels of detail "
    "from head to feet, small square pixels (density only: NEVER zoom, NEVER "
    "crop, NEVER enlarge the character), limited NES-era palette (max ~24 "
    "colors), hard pixel edges, no anti-aliasing, no gradients, no blur, "
    "NO visible grid lines, no mesh or checkerboard overlay, flat colors, "
    "1px dark outline, clean readable silhouette"
)

FRAMING_LOCK = (
    "FRAMING RULE — CRITICAL: the character is SMALL in the frame, occupying only "
    "about 60-65% of the frame HEIGHT (never more than 70%), positioned exactly in "
    "the center, with LARGE empty solid-background margins: at least 18% of the frame "
    "height empty ABOVE the head and at least 18% empty BELOW the feet, wide empty "
    "margins left and right, full body visible, nothing cropped at the edges."
)

# One compact lock instead of stacked overlapping rule blocks: past a point,
# more prompt rules dilute each other and the model starts dropping details
# (shoe colors) or shrinking the character.
CHARACTER_LOCK = (
    "CHARACTER LOCK: exactly the same character as the reference — same face, "
    "hair, skin tone, the same outfit in the same colors down to the shoes; "
    "nothing added, removed or recolored. Same size and proportions as the "
    "reference: same head size, same body thickness, same on-screen height — "
    "never smaller, never zoomed, never cropped; full body, head to feet."
)

CAMERA_LOCK = (
    "CAMERA LOCK — ABSOLUTE RULE: the camera is completely frozen for the entire "
    "clip. Frame 1 must be a PIXEL-PERFECT copy of the input start image INCLUDING "
    "all its empty background margins: the character occupies the same small portion "
    "of the frame as in the start image, with the same wide empty margins above the "
    "head, below the feet and on both sides. NEVER zoom in, NEVER enlarge the "
    "character, NEVER push the character toward the frame edges, NEVER recompose or "
    "recrop. The wide empty margins stay visible in EVERY frame; any zoom-in or "
    "tighter framing is a failure."
)

FRAME_MS = 156

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
    "fall": {"row": 7, "start": 0, "count": 16},
    "happy": {"row": 9, "start": 0, "count": 8},
    "watch": {"row": 9, "start": 8, "count": 8},
    "eat": {"row": 10, "start": 0, "count": 8},
    "sick": {"row": 10, "start": 8, "count": 8},
    "wash": {"row": 11, "start": 0, "count": 8},
}

SMOKE_MODES = {
    "walk": {"row": 0, "start": 0, "count": 16},
    "idle": {"row": 0, "start": 0, "count": 16},
    "look": {"row": 0, "start": 0, "count": 16},
    "sleep": {"row": 0, "start": 0, "count": 8},
    "sneak": {"row": 0, "start": 0, "count": 16},
    "happy": {"row": 0, "start": 0, "count": 8},
    "eat": {"row": 0, "start": 0, "count": 8},
    "wash": {"row": 0, "start": 0, "count": 8},
    "dance": {"row": 0, "start": 0, "count": 16},
    "flip": {"row": 0, "start": 0, "count": 16},
    "run": {"row": 0, "start": 0, "count": 16},
    "fall": {"row": 0, "start": 0, "count": 16},
    "collapse": {"row": 0, "start": 0, "count": 1},
    "drag": {"row": 0, "start": 0, "count": 1},
    "greet": {"row": 0, "start": 0, "count": 8},
    "watch": {"row": 0, "start": 0, "count": 8},
    "sick": {"row": 0, "start": 0, "count": 8},
}

CLIPS = [
    {"row": 0, "name": "walk", "frames": 16, "loop": True,
     "pose": "first pose of a side-view walk cycle facing right, mid-stride, full body",
     "spec": "WALK: side-view walk/run cycle facing right, full gait, arms and legs clear, upright then slight forward lean as speed builds"},
    {"row": 1, "name": "idle", "frames": 8, "loop": True,
     "pose": "first pose of a subtle idle bob, facing 3/4 right, standing full body",
     "spec": "IDLE: subtle idle bob/breath facing 3/4 right"},
    {"row": 1, "name": "look", "frames": 8, "loop": True,
     "pose": "first pose of a look-around, standing, head turned slightly right, full body",
     "spec": "LOOK-AROUND: gentle head/torso turns (right, camera, left, back to right) while standing"},
    {"row": 2, "name": "sleep", "frames": 8, "loop": True, "lying": True,
     "pose": "lying flat on his side, body strictly HORIZONTAL across the frame, head and feet at the same height, eyes closed, sleeping, full body visible — NEVER upright, NEVER diagonal, NEVER floating curled",
     "spec": "SLEEP: lying flat on the side, body strictly HORIZONTAL, head and feet at the same height, eyes closed, tiny breathing — never upright, never diagonal"},
    {"row": 2, "name": "collapse", "frames": 8, "loop": True, "lying": True,
     "pose": "flat on stomach or back, body strictly HORIZONTAL across the frame, awake, readable silhouette, full body — NEVER upright, NEVER diagonal",
     "spec": "COLLAPSE/LIE: flat on stomach/back, body strictly HORIZONTAL, minimized pose, awake or half-awake, readable silhouette"},
    {"row": 3, "name": "drag", "frames": 8, "loop": True, "minH": 0.8,
     "pose": "one arm stretched straight up overhead, body and legs dangling relaxed below it as if hanging by that hand, COMPLETELY ALONE in the frame — no rope, no hand holding him, no other characters, full body",
     "spec": "DRAG/HANG: one arm fixed straight overhead, body hanging below it, legs dangling with a light pendulum sway, the raised arm never moves; COMPLETELY ALONE — no rope, no hand holding him, no other characters, no props"},
    {"row": 3, "name": "greet", "frames": 8, "loop": True,
     "pose": "facing camera/3-4, friendly wave, first frame of a hello, full body",
     "spec": "GREET/WAVE: facing camera/3-4, friendly wave or both-hands hello"},
    {"row": 4, "name": "dance", "frames": 16, "loop": True,
     "pose": "facing camera, arms up, first pose of a dance/cheer, full body",
     "spec": "DANCE/CHEER: music celebration facing camera/3-4, arms up, stepping in place, joyful cycle"},
    {"row": 5, "name": "flip", "frames": 16, "loop": True,
     "pose": "aggressive sprint facing right, long stride, strong lean, full body",
     "spec": "DASH/FLIP ENERGY: aggressive sprint facing right, long strides, strong lean, high energy, hype peak"},
    {"row": 6, "name": "sneak", "frames": 16, "loop": True, "minH": 0.5,
     "pose": "deep crouch walk facing right, torso low, first sneak step, full body",
     "spec": "SNEAK: deep crouch walk facing right, torso low, careful steps"},
    {"row": 7, "name": "fall", "frames": 16, "loop": True, "minH": 0.5,
     "pose": "mid-air falling pose facing camera/3-4, arms and legs spread and flailing, clothes lifted by air, no ground visible, full body",
     "spec": "FALL: falling through the air, arms and legs waving and flailing, comic panic tumble, clothes and hair lifted upward, no ground contact, loopable mid-air cycle"},
    {"row": 9, "name": "happy", "frames": 8, "loop": True,
     "pose": "big smile, first happy pose, optional tiny pixel hearts, full body",
     "spec": "HAPPY/LOVE: big smile, optional small pixel hearts above head (clean pixels, no blur)"},
    {"row": 9, "name": "watch", "frames": 8, "loop": True, "minH": 0.45,
     "pose": "sitting on the ground with a small open laptop on his lap, looking at the laptop screen, relaxed, COMPLETELY ALONE, full body",
     "spec": "WATCH: sitting on the ground with a small open laptop on the lap, eyes on the screen, tiny reactions — slight head tilt, occasional smile — COMPLETELY ALONE, no other characters, the laptop is the only prop"},
    {"row": 10, "name": "eat", "frames": 8, "loop": True,
     "pose": "holding a small snack or drink, first chew/sip pose, full body",
     "spec": "EAT/SNACK: holding a small snack/drink, chew or sip cycle"},
    {"row": 10, "name": "sick", "frames": 8, "loop": True,
     "pose": "woozy stance, hand-to-head, light pale/greenish face tint, full body",
     "spec": "SICK/DIZZY: light pale/greenish tint on face only, dizzy swirl or hand-to-head, woozy stance, outfit readable"},
    {"row": 11, "name": "wash", "frames": 8, "loop": True,
     "pose": "standing in his normal full outfit, dabbing his face with a small towel, a few soap bubbles around the head, clean and happy, full body — clothing completely unchanged, NEVER a towel wrap or robe",
     "spec": "WASH/HYGIENE: standing in his normal outfit dabbing his face with a small towel, a few soap bubbles around, clothing completely unchanged — never undressed, never a towel wrap or robe"},
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
    try:
        proc = subprocess.run(
            [hf, "generate", "get", job_id, "--json"],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        return None
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
        # Testing hook, mirrored from runtime.py: hide system-wide CLIs.
        if (Path(out_dir) / "ignore-system-cli").exists():
            return ""
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
    req = urllib.request.Request(url, headers={"User-Agent": "higgsfield-omagotchi-omarchy/0.13"})
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


def hf_with_wait_flags(hf: str, base: list[str], log: Path, timeout_s: int = 900) -> dict:
    global _WAIT_FLAGS
    variants = WAIT_FLAG_VARIANTS
    if _WAIT_FLAGS is not None:
        variants = [_WAIT_FLAGS]
    last_err = "higgsfield wait failed"
    for flags in variants:
        cmd = [*base, *flags]
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s)
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"wait timed out after {timeout_s}s")
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


def poll_job(hf: str, job_id: str, log: Path, timeout_s: int = POLL_SECONDS) -> dict:
    deadline = time.time() + timeout_s
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
    # 503/timeout on create is a burst, not a verdict — a run fires up to 18
    # parallel creates and the API sheds load. Back off with jitter and try
    # again before treating it as a real failure.
    last_err = "higgsfield create failed"
    for attempt in range(3):
        if attempt:
            time.sleep(min(4 * attempt, 8) + random.uniform(0.0, 1.5))
        try:
            proc = subprocess.run(
                [hf, "generate", "create", model, *args, "--json"],
                capture_output=True,
                text=True,
                timeout=180,
            )
        except subprocess.TimeoutExpired:
            last_err = "create timed out"
            time.sleep(2)
            continue
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
        last_err = describe_hf_error(proc.stderr or proc.stdout or "higgsfield create failed")
        if not is_transport_error(blob) or is_hard_failure(blob):
            break
    raise RuntimeError(last_err)


def wait_job(hf: str, job_id: str, log: Path, timeout_s: int = 1200) -> dict:
    # Wait can 503 or print "failed" after the job already completed. Confirm
    # via get. A stuck job must fail within the budget, not hang: an image
    # normally lands in under two minutes, so its short budget turns a dead
    # worker into a quick reroll instead of an hour of silence.
    try:
        data = hf_with_wait_flags(
            hf,
            [hf, "generate", "wait", job_id, "--json"],
            log,
            timeout_s=timeout_s,
        )
        found = job_result(job_id, data)
        if found:
            return found
    except RuntimeError:
        pass
    return poll_job(hf, job_id, log, timeout_s=timeout_s)


IMAGE_WAIT_S = 300
CLIP_WAIT_S = 1200


def run_generate(hf: str, model: str, args: list[str], log: Path, timeout_s: int = 1200) -> dict:
    job_id = start_job(hf, model, args, log)
    return wait_job(hf, job_id, log, timeout_s=timeout_s)


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


def subject_height_frac(path: Path, key: str) -> float:
    """Subject bbox height as a fraction of frame height, on a 64px proxy."""
    try:
        from PIL import Image
        import numpy as np
    except ImportError:
        return 0.0
    try:
        im = Image.open(path).convert("RGB").resize((64, 64))
    except Exception:
        return 0.0
    arr = np.asarray(im).astype(int)
    kr, kg, kb = int(key[1:3], 16), int(key[3:5], 16), int(key[5:7], 16)
    dist = np.abs(arr - np.array([kr, kg, kb])).sum(axis=2)
    ys = np.nonzero(dist >= 180)[0]
    if not len(ys):
        return 0.0
    return float(ys.max() - ys.min() + 1) / arr.shape[0]


def start_frame_ok(clip: dict, path: Path, key: str, base_frac: float = 0.0) -> tuple[bool, str]:
    try:
        from PIL import Image
        import numpy as np
    except ImportError:
        return True, ""
    try:
        im = Image.open(path).convert("RGB").resize((64, 64))
    except Exception:
        return True, ""
    arr = np.asarray(im).astype(int)
    kr, kg, kb = int(key[1:3], 16), int(key[3:5], 16), int(key[5:7], 16)
    dist = np.abs(arr - np.array([kr, kg, kb])).sum(axis=2)
    border = np.concatenate([dist[0], dist[-1], dist[:, 0], dist[:, -1]])
    if float((border < 180).mean()) < 0.85:
        return False, "start frame background is not the key color"
    ys, xs = np.nonzero(dist >= 180)
    if len(ys):
        # A full body with the demanded margins never reaches the frame
        # edge; touching the bottom means a bust/waist-up crop (no legs).
        if ys.max() >= arr.shape[0] - 2:
            return False, "character is cropped at the bottom (no legs)"
        if ys.min() <= 1:
            return False, "character is cropped at the top"
    # Lying rows (sleep, collapse) must actually lie down: the subject box
    # has to be clearly wider than tall, or the pose came out upright/curled.
    if clip.get("lying") and len(xs):
        if (xs.max() - xs.min()) < 1.2 * (ys.max() - ys.min()):
            return False, "lying pose came out upright instead of horizontal"
    # Scale drift: a pose drawn miniature (small head, small body) passes
    # every other check but ruins the sheet. Crouches are legitimately
    # shorter, so each pose carries its own floor against the base sprite.
    if base_frac > 0 and len(ys) and not clip.get("lying"):
        frac = float(ys.max() - ys.min() + 1) / arr.shape[0]
        floor = float(clip.get("minH", 0.6))
        if frac < floor * base_frac:
            return False, "character drawn too small versus the base sprite"
    return True, ""


BG_REASON = "start frame background is not the key color"


def normalize_background(path: Path, key: str) -> tuple[bool, str]:
    """The model reliably delivers a FLAT background but sometimes drops the
    color (black for lying poses, washed-out pink, gray). A uniform wrong
    background is deterministically repairable — flood-recolor it to the key
    instead of burning a reroll on it. Refuses anything non-uniform
    (scenery, gradients), which still needs the reroll path."""
    try:
        from PIL import Image, ImageDraw
        import numpy as np
    except ImportError:
        return False, "no PIL"
    try:
        im = Image.open(path).convert("RGB")
    except Exception as exc:
        return False, str(exc)
    arr = np.asarray(im).astype(int)
    border = np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]])
    med = np.median(border, axis=0).astype(int)
    if float((np.abs(border - med).sum(axis=1) < 60).mean()) < 0.9:
        return False, "background is not a uniform color"
    kr, kg, kb = hex_to_rgb(key)
    if int(np.abs(med - np.array([kr, kg, kb])).sum()) < 60:
        return False, "background is already the key color"
    # If subject colors sit close to the background color (black hair on a
    # black background), the flood cannot tell them apart and would merge
    # them — and neither could the chroma key. Those frames genuinely need
    # the reroll, which may land on a distinguishable background.
    dist = np.abs(arr - med).sum(axis=2)
    if float(((dist >= 25) & (dist < 60)).mean()) > 0.003:
        return False, "subject colors are too close to the background color"
    before = float((dist >= 60).mean())
    w, h = im.size
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    for seed in seeds:
        px = im.getpixel(seed)
        if sum(abs(int(px[i]) - int(med[i])) for i in range(3)) < 60:
            ImageDraw.floodfill(im, seed, (kr, kg, kb), thresh=45)
    out = np.asarray(im).astype(int)
    after = float((np.abs(out - np.array([kr, kg, kb])).sum(axis=2) >= 60).mean())
    if after < max(0.01, before * 0.9) or after > 0.6:
        return False, "recolor would damage the subject"
    im.save(path)
    return True, "recolored #%02x%02x%02x -> %s" % (int(med[0]), int(med[1]), int(med[2]), key)


def checked_start_frame(clip: dict, dest: Path, key: str, base_frac: float,
                        log: Path | None = None) -> tuple[bool, str]:
    """start_frame_ok, with one free repair attempt for wrong-color flat
    backgrounds before the caller spends a reroll."""
    ok, why = start_frame_ok(clip, dest, key, base_frac)
    if ok or why != BG_REASON:
        return ok, why
    fixed, note = normalize_background(dest, key)
    if not fixed:
        return False, f"{why} ({note})"
    if log is not None:
        append_log(log, f"pose {clip.get('name', '?')}: background {note}\n")
    return start_frame_ok(clip, dest, key, base_frac)


def video_prompt(spec: str, key: str, loop: bool) -> str:
    extra = ", seamless loop" if loop else ""
    return (
        f"{spec}, {STYLE}, {CHARACTER_LOCK}, {CAMERA_LOCK}, "
        f"flat solid {key} background staying EXACTLY {key} in every frame — never "
        f"darker, never desaturated, no vignette, no gradient — no cast shadow, no "
        f"ground shadow under the character, no background elements, "
        f"no other characters, no text{extra}"
    )


def base_prompt(key: str, notes: str) -> str:
    extra = (" " + notes.strip()) if notes.strip() else ""
    return (
        f"{STYLE}. Full body, standing, facing right, centered, nothing cropped, "
        f"solid {key} background, no ground plane, no cast shadow. {FRAMING_LOCK} "
        f"Keep the character's recognizable traits (hair, outfit colors, distinctive features) "
        f"translated into 8-bit.{extra}"
    )


def start_prompt(clip: dict, key: str, notes: str) -> str:
    extra = (" " + notes.strip()) if notes.strip() else ""
    pose = clip.get("pose") or clip["spec"]
    return (
        f"{STYLE}. {pose}. {CHARACTER_LOCK} {FRAMING_LOCK} "
        f"Flat solid {key} background filling the ENTIRE frame, no ground plane, "
        f"no cast shadow, no scenery, no props, no other characters — the character "
        f"is completely alone. "
        f"Keep identity, outfit and proportions from the reference sprite.{extra}"
    )


def start_image_args(clip: dict, key: str, base_path: Path, notes: str) -> list[str]:
    return [
        "--prompt", start_prompt(clip, key, notes),
        "--image", str(base_path),
        "--aspect_ratio", "1:1",
        "--resolution", "1k",
    ]


def clip_video_args(clip: dict, key: str, start_path: Path) -> list[str]:
    args = [
        "--prompt", video_prompt(clip["spec"], key, clip["loop"]),
        "--image", str(start_path),
        "--start-image", str(start_path),
        "--aspect_ratio", "1:1",
        "--resolution", "720p",
        "--duration", "4",
        "--generate_audio", "false",
    ]
    if clip["loop"]:
        args += ["--end-image", str(start_path)]
    return args


def hex_to_rgb(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def subject_height_ratio(path: Path, key: str) -> float:
    try:
        from PIL import Image
        import numpy as np
    except ImportError:
        return 0.0
    if not path.is_file():
        return 0.0
    im = Image.open(path).convert("RGB")
    a = np.asarray(im, dtype=np.int32)
    kr, kg, kb = hex_to_rgb(key)
    dist = np.sqrt(((a - np.array((kr, kg, kb), dtype=np.int32)) ** 2).sum(axis=2))
    mask = dist > 110
    ys = np.where(mask.any(axis=1))[0]
    if len(ys) == 0:
        return 0.0
    return float(ys.max() - ys.min() + 1) / float(im.height)


def extract_video_frame(video: Path, dest: Path, at_end: bool = False) -> bool:
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-y", "-v", "error"]
    if at_end:
        cmd += ["-sseof", "-0.12"]
    cmd += ["-i", str(video), "-frames:v", "1", str(dest)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode == 0 and dest.is_file() and dest.stat().st_size > 200


def clip_background_ok(video: Path, key: str) -> bool:
    """The video model likes to dim or desaturate the key background, which
    then survives chroma keying and smears onto the frames. Check a mid-clip
    frame's border against the key color and reroll drifted clips."""
    tmp = video.parent / f".bg_{video.stem}.png"
    cmd = ["ffmpeg", "-y", "-v", "error", "-i", str(video),
           "-vf", "select=gte(n\,24)", "-frames:v", "1", str(tmp)]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0 or not tmp.is_file():
            return True
        try:
            from PIL import Image
            import numpy as np
        except ImportError:
            return True
        arr = np.asarray(Image.open(tmp).convert("RGB").resize((64, 64))).astype(int)
        border = np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]])
        med = np.median(border, axis=0)
        if float((np.abs(border - med).sum(axis=1) < 90).mean()) < 0.85:
            return False
        # postprocess keys on the measured border when it is within 300 of
        # the nominal key (effective_key), so only drift beyond that — or a
        # non-uniform background — actually needs a reroll.
        return int(np.abs(med - np.array(hex_to_rgb(key))).sum()) <= 300
    finally:
        tmp.unlink(missing_ok=True)


def framing_ok(start_path: Path, video: Path, key: str, one_shot: bool) -> bool:
    if one_shot:
        return True
    tmp = video.parent / f".frame_{video.stem}.png"
    if not extract_video_frame(video, tmp, at_end=False):
        return True
    start_h = subject_height_ratio(start_path, key)
    first_h = subject_height_ratio(tmp, key)
    tmp.unlink(missing_ok=True)
    if start_h <= 0 or first_h <= 0:
        return True
    return first_h <= start_h + 0.10


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
        "fps": max(1, round(1000 / FRAME_MS)),
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
    total = 2 + 2 * len(jobs)  # base + start frames + clips + postprocess
    starts_dir = work_dir / "starts"
    starts_dir.mkdir(parents=True, exist_ok=True)

    progress("Drawing the base sprite…", phase="base", step=0, steps=total)
    try:
        base_job = run_generate(hf, "nano_banana_2", [
            "--prompt", base_prompt(key, args.notes),
            "--image", str(image),
            "--aspect_ratio", "1:1",
            "--resolution", "1k",
        ], log, timeout_s=IMAGE_WAIT_S)
    except Exception as exc:
        fail(str(exc), {"reason": str(exc), "job_id": extract_uuid(str(exc)), "log": str(log)})
    base_path = work_dir / "base.png"
    download(base_job["url"], base_path)
    fixed, note = normalize_background(base_path, key)
    if fixed:
        append_log(log, f"base sprite: background {note}\n")
    base_frac = subject_height_frac(base_path, key)
    progress("Base sprite ready", phase="base", step=1, steps=total)

    start_paths: dict[str, Path] = {}
    start_errors: list[str] = []
    CLIP_STOP.clear()
    progress(
        f"Posing {len(jobs)} start frames…",
        phase="start",
        step=1,
        steps=total,
    )

    def create_start(clip: dict) -> tuple[dict, str, Path]:
        if CLIP_STOP.is_set():
            raise RuntimeError(f"{clip['name']}: skipped after a billing failure")
        dest = starts_dir / f"{clip['name']}.png"
        job_id = start_job(hf, "nano_banana_2", start_image_args(clip, key, base_path, args.notes), log)
        return clip, job_id, dest

    start_submitted: list[tuple[dict, str, Path]] = []
    start_pool = ThreadPoolExecutor(max_workers=min(CREATE_WORKERS, len(jobs)))
    start_futs = [start_pool.submit(create_start, clip) for clip in jobs]
    try:
        for fut in as_completed(start_futs):
            try:
                clip, job_id, dest = fut.result()
                start_submitted.append((clip, job_id, dest))
                progress(
                    f"Submitted poses {len(start_submitted)}/{len(jobs)} · {clip['name']}",
                    phase="start",
                    step=1,
                    steps=total,
                )
            except Exception as exc:
                err = str(exc)
                start_errors.append(err)
                if is_hard_failure(err):
                    CLIP_STOP.set()
                    start_pool.shutdown(wait=False, cancel_futures=True)
                    fail(err, {"reason": err, "job_id": extract_uuid(err), "log": str(log)})
        start_pool.shutdown(wait=True)
    except Exception as exc:
        CLIP_STOP.set()
        start_pool.shutdown(wait=False, cancel_futures=True)
        fail(str(exc), {"reason": str(exc), "job_id": extract_uuid(str(exc)), "log": str(log)})

    if not start_submitted:
        err = start_errors[0] if start_errors else "no start-frame jobs submitted"
        fail(err, {"reason": err, "job_id": extract_uuid(err), "log": str(log)})

    start_wait_errors: list[str] = []

    def wait_start(item: tuple[dict, str, Path]) -> tuple[dict, Path]:
        clip, job_id, dest = item
        job = wait_job(hf, job_id, log, timeout_s=IMAGE_WAIT_S)
        download(job["url"], dest)
        ok, why = checked_start_frame(clip, dest, key, base_frac, log)
        if not ok:
            raise RuntimeError(why)
        return clip, dest

    start_wait_pool = ThreadPoolExecutor(max_workers=min(WAIT_WORKERS, len(start_submitted)))
    start_wait_futs = {start_wait_pool.submit(wait_start, item): item for item in start_submitted}
    for fut in as_completed(start_wait_futs):
        clip = start_wait_futs[fut][0]
        try:
            clip, dest = fut.result()
            start_paths[clip["name"]] = dest
            progress(
                f"{len(start_paths)}/{len(jobs)} poses ready · {clip['name']}",
                phase="start",
                step=1 + len(start_paths),
                steps=total,
            )
        except Exception as exc:
            err = f"pose {clip['name']}: {exc}"
            append_log(log, err + "\n")
            if is_hard_failure(str(exc)):
                CLIP_STOP.set()
                start_wait_pool.shutdown(wait=False, cancel_futures=True)
                fail(err, {"reason": err, "job_id": extract_uuid(str(exc)), "log": str(log)})
    start_wait_pool.shutdown(wait=True)

    # Out of 18 parallel image jobs one flake is routine, and it used to sink
    # the whole run after every job was already paid for. Reroll every pose
    # still missing — whether its submission or its wait died — before giving
    # up, and fail only on what is still absent afterwards.
    for clip in [c for c in jobs if c["name"] not in start_paths]:
        last_err = ""
        for attempt in range(2):
            progress(
                f"Rerolling pose · {clip['name']}",
                phase="start",
                step=1 + len(start_paths),
                steps=total,
            )
            try:
                job_id = start_job(hf, "nano_banana_2", start_image_args(clip, key, base_path, args.notes), log)
                job = wait_job(hf, job_id, log, timeout_s=IMAGE_WAIT_S)
                dest = starts_dir / f"{clip['name']}.png"
                download(job["url"], dest)
                ok, why = checked_start_frame(clip, dest, key, base_frac, log)
                if not ok:
                    raise RuntimeError(why)
                start_paths[clip["name"]] = dest
                break
            except Exception as exc:
                last_err = str(exc)
                append_log(log, f"pose rescue {attempt + 1} failed for {clip['name']}: {last_err}\n")
                if is_hard_failure(last_err):
                    fail(f"pose {clip['name']}: {last_err}",
                         {"reason": last_err, "job_id": extract_uuid(last_err), "log": str(log)})
        else:
            start_wait_errors.append(f"pose {clip['name']} failed 3 times: {last_err}")

    if len(start_paths) < len(jobs):
        err = (start_wait_errors or start_errors or ["missing start frames"])[0]
        fail(err, {"reason": err, "job_id": extract_uuid(err), "log": str(log)})

    plan_rows = {}
    completed = {"n": 0}
    finished = {}
    CLIP_STOP.clear()
    clip_base = 1 + len(jobs)
    progress(
        f"Submitting {len(jobs)} clip jobs…",
        phase="clip",
        step=clip_base,
        steps=total,
    )

    submitted: list[tuple[dict, str, Path]] = []
    create_errors: list[str] = []

    def create_one(clip: dict) -> tuple[dict, str, Path]:
        if CLIP_STOP.is_set():
            raise RuntimeError(f"{clip['name']}: skipped after a billing failure")
        dest = clips_dir / f"r{clip['row']:02d}_{clip['name']}.mp4"
        start = start_paths[clip["name"]]
        job_id = start_job(hf, "seedance_2_0_mini", clip_video_args(clip, key, start), log)
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
                    step=clip_base,
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
        step=clip_base,
        steps=total,
    )

    wait_errors: list[str] = []

    def wait_one(item: tuple[dict, str, Path]) -> tuple[dict, Path]:
        clip, job_id, dest = item
        start = start_paths[clip["name"]]
        last = ""
        for attempt in range(2):
            try:
                if attempt:
                    append_log(log, f"clip reroll {clip['name']} after: {last}\n")
                    job_id = start_job(hf, "seedance_2_0_mini", clip_video_args(clip, key, start), log)
                job = wait_job(hf, job_id, log)
                download(job["url"], dest)
                break
            except Exception as exc:
                last = str(exc)
                if is_hard_failure(last):
                    raise RuntimeError(f"clip {clip['name']}: {last}")
        else:
            raise RuntimeError(f"clip {clip['name']} failed twice: {last}")
        try:
            if not framing_ok(start, dest, key, not clip["loop"]) or not clip_background_ok(dest, key):
                append_log(log, f"quality reroll {clip['name']}\n")
                job_id = start_job(hf, "seedance_2_0_mini", clip_video_args(clip, key, start), log)
                job = wait_job(hf, job_id, log)
                download(job["url"], dest)
        except Exception as exc:
            raise RuntimeError(f"clip {clip['name']}: {exc}")
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
                step=clip_base + n,
                steps=total,
            )
        except Exception as exc:
            wait_errors.append(str(exc))
            append_log(log, str(exc) + "\n")
    wait_pool.shutdown(wait=True)

    # Same tolerance as the poses: resubmit whatever is still missing —
    # clips whose creation 503'd never reached the wait pool at all.
    for clip in [c for c in jobs if id(c) not in finished]:
        dest = clips_dir / f"r{clip['row']:02d}_{clip['name']}.mp4"
        last_err = ""
        for attempt in range(2):
            progress(
                f"Rerolling clip · {clip['name']}",
                phase="clip",
                step=clip_base + completed["n"],
                steps=total,
            )
            try:
                append_log(log, f"clip resubmit {clip['name']} (attempt {attempt + 1})\n")
                job_id = start_job(hf, "seedance_2_0_mini", clip_video_args(clip, key, start_paths[clip["name"]]), log)
                job = wait_job(hf, job_id, log, timeout_s=CLIP_WAIT_S)
                download(job["url"], dest)
                finished[id(clip)] = dest
                completed["n"] += 1
                break
            except Exception as exc:
                last_err = str(exc)
                append_log(log, f"clip rescue {attempt + 1} failed for {clip['name']}: {last_err}\n")
                if is_hard_failure(last_err):
                    fail(f"clip {clip['name']}: {last_err}",
                         {"reason": last_err, "job_id": extract_uuid(last_err), "log": str(log)})
        else:
            wait_errors.append(f"clip {clip['name']} failed repeatedly: {last_err}")

    if len(finished) < len(jobs):
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
        "frame_ms": FRAME_MS,
        "out_dir": str(work_dir / "sheet"),
        "rows": [plan_rows[k] for k in sorted(plan_rows)],
    }
    plan_path = work_dir / "plan.json"
    plan_path.write_text(json.dumps(plan, indent=2) + "\n")

    progress("Cutting frames…", phase="post", step=total - 1, steps=total)
    # A stale sheet from a previous run must never masquerade as this run's
    # output: postprocess writes into work/sheet, so start it empty.
    shutil.rmtree(work_dir / "sheet", ignore_errors=True)
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
    timings_src = work_dir / "sheet" / "timings.json"
    if timings_src.is_file():
        shutil.copy2(timings_src, out_dir / "timings.json")
    actions_src = work_dir / "sheet" / "actions"
    if actions_src.is_dir():
        actions_dest = out_dir / "actions"
        if actions_dest.exists():
            shutil.rmtree(actions_dest)
        shutil.copytree(actions_src, actions_dest)

    atlas_path, atlas_spec = write_atlas(out_dir, sheet_dest, 1 if args.smoke else 12, args.frame_size, args.smoke)

    # Archive the finished avatar so the panel can switch back to it later.
    archive_dir = ""
    if not args.smoke:
        try:
            arch = out_dir / "avatars" / time.strftime("%Y%m%d_%H%M%S")
            arch.mkdir(parents=True, exist_ok=True)
            shutil.copy2(sheet_dest, arch / "spritesheet_16x12.png")
            arch_spec = dict(atlas_spec)
            arch_spec["file"] = str(arch / "spritesheet_16x12.png")
            (arch / "atlas.json").write_text(json.dumps(arch_spec, indent=2) + "\n")
            thumb_proc = subprocess.run(
                ["ffmpeg", "-y", "-v", "error", "-i", str(arch / "spritesheet_16x12.png"),
                 "-vf", "crop=80:80:0:80", str(arch / "thumb.png")],
                capture_output=True, text=True, timeout=60,
            )
            if thumb_proc.returncode != 0 and base_path.is_file():
                shutil.copy2(base_path, arch / "thumb.png")
            archive_dir = str(arch)
        except Exception as exc:  # noqa: BLE001 - archiving must never fail the run
            append_log(log, f"avatar archive failed: {exc}\n")

    progress("Tamagotchi ready", phase="done", step=total, steps=total)
    print(json.dumps({
        "ok": True,
        "path": str(sheet_dest),
        "atlas": str(atlas_path),
        "atlas_spec": atlas_spec,
        "archive": archive_dir,
        "base": str(base_path),
        "smoke": bool(args.smoke),
        "model": "seedance_2_0_mini",
    }), flush=True)


if __name__ == "__main__":
    main()
