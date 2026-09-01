#!/usr/bin/env python3
"""One-off media generation through the Higgsfield CLI.

Prints {"t":"mstatus",...} progress lines, then one result JSON object.
Reuses the sprite pipeline's CLI plumbing (create/wait/download, bounded
waits) by importing the sibling script.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
import time
from pathlib import Path


def load_sibling(filename: str):
    path = Path(__file__).resolve().parent / filename
    name = filename.replace("-", "_").removesuffix(".py")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


gs = load_sibling("generate-sprite.py")


def status(label: str) -> None:
    print(json.dumps({"t": "mstatus", "label": label}), flush=True)


def fail(message: str) -> None:
    print(json.dumps({"ok": False, "error": str(message)[-500:]}), flush=True)
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt", default="")
    parser.add_argument("--image", action="append", default=[])
    parser.add_argument("--kind", default="image", choices=["image", "video"])
    parser.add_argument("--ratio", default="")
    parser.add_argument("--duration", default="")
    parser.add_argument("--out", required=True)
    parser.add_argument("--plugin-root", required=True)
    args = parser.parse_args()

    prompt = args.prompt.strip()
    refs = [r.strip() for r in args.image if r.strip()]
    if not prompt and not refs:
        fail("Add a prompt or a reference image")
    for r in refs:
        if not Path(r).is_file():
            fail(f"reference not found: {r}")

    out_dir = Path(args.out).expanduser()
    media_dir = out_dir / "media"
    media_dir.mkdir(parents=True, exist_ok=True)
    log = media_dir / "generate.log"
    log.write_text(f"# {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

    status("Preparing runtime…")
    runtime = gs.bootstrap(Path(args.plugin_root).resolve(), out_dir)
    hf = runtime.get("hf")
    if not hf:
        fail("could not install Higgsfield CLI")

    status("Selecting workspace…")
    ws_proc = subprocess.run(
        [sys.executable, "-u", str(Path(args.plugin_root) / "scripts" / "runtime.py"),
         "ensure-workspace", "--out", str(out_dir)],
        capture_output=True,
        text=True,
    )
    ws = gs.last_json((ws_proc.stdout or "") + "\n" + (ws_proc.stderr or ""))
    if ws_proc.returncode != 0 or not ws or not ws.get("ok"):
        fail(str((ws or {}).get("error") or ws_proc.stderr or "No Higgsfield workspace selected")[-400:])

    video = args.kind == "video"
    model = "seedance_2_0_mini" if video else "nano_banana_2"
    ratio = args.ratio.strip() or ("16:9" if video else "1:1")
    create_args = ["--prompt", prompt or "a high quality, detailed rendition of the reference",
                   "--aspect_ratio", ratio]
    if video:
        duration = args.duration.strip().rstrip("s") or "4"
        create_args += ["--resolution", "720p", "--duration", duration,
                        "--generate_audio", "false"]
    else:
        create_args += ["--resolution", "1k"]
    for r in refs:
        create_args += ["--image", r]

    status("Submitting…")
    try:
        job_id = gs.start_job(hf, model, create_args, log)
        status("Generating…")
        wait_s = gs.CLIP_WAIT_S if video else gs.IMAGE_WAIT_S
        job = gs.wait_job(hf, job_id, log, timeout_s=wait_s)
        stamp = time.strftime("%Y%m%d_%H%M%S")
        dest = media_dir / (f"media_{stamp}.mp4" if video else f"media_{stamp}.png")
        gs.download(job["url"], dest)
        thumb = dest
        if video:
            # Panel preview only — QML Image cannot render an mp4 frame.
            # Hidden subdir keeps the media folder to actual creations.
            thumb_dir = media_dir / ".thumbs"
            thumb_dir.mkdir(parents=True, exist_ok=True)
            thumb = thumb_dir / f"media_{stamp}.png"
            proc = subprocess.run(
                ["ffmpeg", "-y", "-v", "error", "-i", str(dest),
                 "-frames:v", "1", str(thumb)],
                capture_output=True, text=True, timeout=60,
            )
            if proc.returncode != 0 or not thumb.is_file():
                thumb = dest
    except Exception as exc:  # noqa: BLE001 - surfaced verbatim to the panel
        fail(str(exc))
        return

    (media_dir / "last.json").write_text(json.dumps({
        "path": str(dest),
        "thumb": str(thumb),
        "kind": args.kind,
        "url": str(job.get("url") or ""),
    }, indent=2) + "\n")
    print(json.dumps({"ok": True, "path": str(dest), "thumb": str(thumb),
                      "kind": args.kind, "url": str(job.get("url") or "")}), flush=True)


if __name__ == "__main__":
    main()
