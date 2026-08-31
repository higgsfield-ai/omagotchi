#!/usr/bin/env python3
"""Grab one webcam frame and print its path."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def fail(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def run(cmd: list[str], timeout: float = 20) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def ffmpeg_bin() -> str | None:
    return shutil.which("ffmpeg")


def video_nodes() -> list[Path]:
    devs = sorted(Path("/dev").glob("video*"), key=lambda p: (len(p.name), p.name))
    return [p for p in devs if p.exists()]


def ok_file(dest: Path) -> bool:
    return dest.is_file() and dest.stat().st_size > 1000


def capture_ffmpeg_v4l2(dev: Path, dest: Path) -> bool:
    ff = ffmpeg_bin()
    if not ff:
        return False
    attempts = [
        [
            ff, "-y", "-hide_banner", "-loglevel", "error",
            "-f", "v4l2", "-input_format", "mjpeg", "-video_size", "1280x720",
            "-i", str(dev), "-ss", "1.2", "-frames:v", "1", str(dest),
        ],
        [
            ff, "-y", "-hide_banner", "-loglevel", "error",
            "-f", "v4l2", "-i", str(dev), "-ss", "1.0", "-frames:v", "1", str(dest),
        ],
    ]
    for cmd in attempts:
        try:
            proc = run(cmd, timeout=18)
        except subprocess.TimeoutExpired:
            dest.unlink(missing_ok=True)
            continue
        if proc.returncode == 0 and ok_file(dest):
            return True
        dest.unlink(missing_ok=True)
    return False


def capture_fswebcam(dev: Path, dest: Path) -> bool:
    binary = shutil.which("fswebcam")
    if not binary:
        return False
    cmd = [
        binary, "-d", str(dev), "-r", "1280x720",
        "--no-banner", "--jpeg", "90", "-D", "1", str(dest),
    ]
    try:
        proc = run(cmd, timeout=18)
    except subprocess.TimeoutExpired:
        return False
    return proc.returncode == 0 and ok_file(dest)


def capture_avfoundation(dest: Path) -> bool:
    ff = ffmpeg_bin()
    if not ff:
        return False
    cmd = [
        ff, "-y", "-hide_banner", "-loglevel", "error",
        "-f", "avfoundation", "-framerate", "30", "-i", "0:none",
        "-ss", "1.0", "-frames:v", "1", str(dest),
    ]
    try:
        proc = run(cmd, timeout=20)
    except subprocess.TimeoutExpired:
        return False
    return proc.returncode == 0 and ok_file(dest)


def capture_imagesnap(dest: Path) -> bool:
    binary = shutil.which("imagesnap")
    if not binary:
        return False
    try:
        proc = run([binary, "-w", "1.2", str(dest)], timeout=18)
    except subprocess.TimeoutExpired:
        return False
    return proc.returncode == 0 and ok_file(dest)


def notify(text: str) -> None:
    for cmd in (
        ["notify-send", "-t", "2500", "Tamagotchi", text],
        ["hyprctl", "notify", "1", "2500", "rgb(ffffff)", text],
    ):
        if not shutil.which(cmd[0]):
            continue
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
        except Exception:
            pass
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    dest = Path(args.out).expanduser()
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.unlink(missing_ok=True)
    notify("Look at the camera…")

    if sys.platform == "darwin":
        if capture_avfoundation(dest) or capture_imagesnap(dest):
            print(str(dest), flush=True)
            return
        fail("Could not capture from the Mac camera. Allow camera access for ffmpeg.")

    nodes = video_nodes()
    if not nodes:
        fail("No webcam found at /dev/video*")
    if not ffmpeg_bin() and not shutil.which("fswebcam"):
        fail("Install ffmpeg to take a webcam photo")

    for dev in nodes:
        if capture_ffmpeg_v4l2(dev, dest) or capture_fswebcam(dev, dest):
            print(str(dest), flush=True)
            return

    fail("Could not capture from the webcam. Check that a camera is connected and not in use.")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:
        fail(str(exc)[-400:])
