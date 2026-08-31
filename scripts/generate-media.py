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
    parser.add_argument("--image", default="")
    parser.add_argument("--out", required=True)
    parser.add_argument("--plugin-root", required=True)
    args = parser.parse_args()

    prompt = args.prompt.strip()
    ref = args.image.strip()
    if not prompt and not ref:
        fail("Add a prompt or a reference image")
    if ref and not Path(ref).is_file():
        fail(f"reference not found: {ref}")

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

    create_args = [
        "--prompt", prompt or "a high quality, detailed image based on the reference",
        "--aspect_ratio", "1:1",
        "--resolution", "1k",
    ]
    if ref:
        create_args += ["--image", ref]

    status("Submitting…")
    try:
        job_id = gs.start_job(hf, "nano_banana_2", create_args, log)
        status("Generating…")
        job = gs.wait_job(hf, job_id, log, timeout_s=gs.IMAGE_WAIT_S)
        dest = media_dir / f"media_{time.strftime('%Y%m%d_%H%M%S')}.png"
        gs.download(job["url"], dest)
    except Exception as exc:  # noqa: BLE001 - surfaced verbatim to the panel
        fail(str(exc))
        return

    (media_dir / "last.json").write_text(json.dumps({
        "path": str(dest),
        "url": str(job.get("url") or ""),
    }, indent=2) + "\n")
    print(json.dumps({"ok": True, "path": str(dest), "url": str(job.get("url") or "")}), flush=True)


if __name__ == "__main__":
    main()
