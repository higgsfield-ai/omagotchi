#!/usr/bin/env python3
"""Install the Higgsfield CLI + Python deps into the plugin data dir (no sudo)."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

REPO = "higgsfield-ai/cli"
UA = "higgsfield.signals-omarchy/0.15"


def out(obj) -> None:
    print(json.dumps(obj), flush=True)


def data_paths(out_dir: Path) -> dict:
    return {
        "out": out_dir,
        "bin": out_dir / "bin",
        "hf": out_dir / "bin" / "higgsfield",
        "venv": out_dir / "venv",
        "venv_python": out_dir / "venv" / "bin" / "python",
    }


def find_ffmpeg() -> str:
    for name in ("ffmpeg", "ffprobe"):
        pass
    ff = shutil.which("ffmpeg") or ""
    probe = shutil.which("ffprobe") or ""
    if ff and probe:
        return ff
    return ff


def find_hf(out_dir: Path) -> str:
    bundled = out_dir / "bin" / "higgsfield"
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


def http_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def http_download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=180) as resp, open(dest, "wb") as fh:
        while True:
            chunk = resp.read(1024 * 256)
            if not chunk:
                break
            fh.write(chunk)


def install_cli(out_dir: Path) -> str:
    existing = find_hf(out_dir)
    if existing:
        return existing
    os_name = sys.platform
    if os_name.startswith("linux"):
        os_key = "linux"
    elif os_name == "darwin":
        os_key = "darwin"
    else:
        raise RuntimeError("unsupported OS for Higgsfield CLI")
    arch = os.uname().machine
    if arch in ("x86_64", "amd64"):
        arch = "amd64"
    elif arch in ("arm64", "aarch64"):
        arch = "arm64"
    else:
        raise RuntimeError(f"unsupported arch: {arch}")

    rel = http_json(f"https://api.github.com/repos/{REPO}/releases/latest")
    tag = rel.get("tag_name") or ""
    if not tag:
        raise RuntimeError("could not resolve Higgsfield CLI release")
    ver = tag[1:] if tag.startswith("v") else tag
    tarball = f"hf_{ver}_{os_key}_{arch}.tar.gz"
    url = f"https://github.com/{REPO}/releases/download/{tag}/{tarball}"
    bin_dir = out_dir / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / tarball
        http_download(url, archive)
        with tarfile.open(archive) as tar:
            try:
                tar.extractall(tmp, filter="data")
            except TypeError:
                tar.extractall(tmp)
        src = Path(tmp) / "hf"
        if not src.is_file():
            matches = list(Path(tmp).rglob("hf"))
            src = matches[0] if matches else src
        dest = bin_dir / "higgsfield"
        shutil.copy2(src, dest)
        dest.chmod(0o755)
    return str(dest)


def venv_has_deps(py: Path) -> bool:
    if not py.is_file():
        return False
    proc = subprocess.run(
        [str(py), "-c", "import PIL, numpy"],
        capture_output=True,
        text=True,
    )
    return proc.returncode == 0


def install_venv(out_dir: Path) -> str:
    venv_dir = out_dir / "venv"
    py = venv_dir / "bin" / "python"
    if not py.is_file():
        subprocess.run([sys.executable, "-m", "venv", str(venv_dir)], check=True)
    if not venv_has_deps(py):
        subprocess.run(
            [str(py), "-m", "pip", "install", "--quiet", "pillow", "numpy"],
            check=True,
        )
    return str(py)


def add_venv_site(out_dir: Path) -> None:
    lib = out_dir / "venv" / "lib"
    if not lib.is_dir():
        return
    for site in lib.glob("python*/site-packages"):
        sys.path.insert(0, str(site))


def logged_in(hf: str) -> bool:
    if not hf:
        return False
    for args in (
        [hf, "account", "status", "--json"],
        [hf, "account", "--json"],
        [hf, "auth", "--json"],
    ):
        proc = subprocess.run(args, capture_output=True, text=True)
        text = ((proc.stdout or "") + "\n" + (proc.stderr or "")).lower()
        if proc.returncode == 0 and "not authenticated" not in text and "session expired" not in text:
            return True
        if "not authenticated" in text or "session expired" in text or "please login" in text:
            return False
    return False


def cmd_ensure(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    hf = install_cli(out_dir)
    py = install_venv(out_dir)
    ff = find_ffmpeg()
    out({
        "ok": True,
        "hf": hf,
        "python": py,
        "ffmpeg": ff,
        "logged_in": logged_in(hf),
        "ffmpeg_ok": bool(shutil.which("ffmpeg") and shutil.which("ffprobe")),
    })


def cmd_auth_status(out_dir: Path) -> None:
    hf = find_hf(out_dir)
    out({"ok": True, "hf": hf, "logged_in": logged_in(hf)})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("ensure", "auth-status"))
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    out_dir = Path(os.path.expanduser(args.out)).resolve()
    try:
        if args.command == "ensure":
            cmd_ensure(out_dir)
        else:
            cmd_auth_status(out_dir)
    except Exception as exc:
        out({"ok": False, "error": str(exc), "logged_in": False})
        sys.exit(1)


if __name__ == "__main__":
    main()
