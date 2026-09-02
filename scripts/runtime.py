#!/usr/bin/env python3
"""Install the Higgsfield CLI + Python deps into the plugin data dir (no sudo)."""
from __future__ import annotations

import argparse
import hashlib
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
    ff = shutil.which("ffmpeg") or ""
    probe = shutil.which("ffprobe") or ""
    return ff if ff and probe else ff


def find_hf(out_dir: Path) -> str:
    bundled = out_dir / "bin" / "higgsfield"
    if bundled.is_file() and os.access(bundled, os.X_OK):
        return str(bundled)
    # Testing hook: `touch <data>/ignore-system-cli` simulates a machine
    # with no Higgsfield CLI even when a system-wide one is installed.
    if (out_dir / "ignore-system-cli").exists():
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


def verify_checksum(tag: str, tarball: str, archive: Path) -> None:
    """Refuse a CLI tarball whose sha256 does not match the release's
    checksums.txt. A tampered or truncated download must never become the
    binary this plugin trusts with the user's account."""
    checks = Path(archive).parent / "checksums.txt"
    http_download(f"https://github.com/{REPO}/releases/download/{tag}/checksums.txt", checks)
    expected = ""
    for line in checks.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[-1].strip("*") == tarball:
            expected = parts[0].lower()
            break
    if not expected:
        raise RuntimeError(f"no checksum published for {tarball}")
    digest = hashlib.sha256()
    with open(archive, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    if digest.hexdigest().lower() != expected:
        raise RuntimeError(f"checksum mismatch for {tarball} — download discarded")


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
        verify_checksum(tag, tarball, archive)
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


def last_json(text: str):
    for line in reversed((text or "").splitlines()):
        line = line.strip()
        if line.startswith("{") or line.startswith("["):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    blob = (text or "").strip()
    if blob.startswith("{") or blob.startswith("["):
        try:
            return json.loads(blob)
        except json.JSONDecodeError:
            return None
    return None


def hf_run(hf: str, args: list[str]) -> tuple[subprocess.CompletedProcess, object, str]:
    proc = subprocess.run([hf, *args], capture_output=True, text=True)
    blob = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip()
    return proc, last_json(blob), blob


def workspace_id_of(node) -> str:
    if node is None:
        return ""
    if isinstance(node, str):
        return node.strip()
    if isinstance(node, dict):
        # workspace_id first: an object that carries one (a folder, a project,
        # a job) is content INSIDE a workspace, and its own `id` is the wrong
        # thing to select. CLI 1.1.24 started answering workspace probes with
        # folder objects, which made `id` pick a folder and fail every run.
        for key in ("workspace_id", "workspaceId", "id", "slug"):
            val = node.get(key)
            if val:
                return str(val).strip()
        for key in ("workspace", "current", "selected", "active", "data"):
            found = workspace_id_of(node.get(key))
            if found:
                return found
    return ""


def workspace_name_of(node) -> str:
    if isinstance(node, dict):
        for key in ("name", "title", "slug"):
            val = node.get(key)
            if val:
                return str(val).strip()
    return ""


def iter_workspaces(data) -> list:
    if isinstance(data, list):
        return [item for item in data if item is not None]
    if isinstance(data, dict):
        for key in ("workspaces", "items", "data", "results", "folders", "projects"):
            val = data.get(key)
            if isinstance(val, list):
                return [item for item in val if item is not None]
        if workspace_id_of(data):
            return [data]
    return []


def selected_workspace(data) -> dict | None:
    items = iter_workspaces(data)
    for item in items:
        if not isinstance(item, dict):
            continue
        if item.get("selected") or item.get("current") or item.get("active"):
            return item
        if item.get("is_selected") or item.get("is_current") or item.get("is_default") or item.get("default"):
            return item
    if isinstance(data, dict):
        for key in ("current", "selected", "active", "workspace"):
            node = data.get(key)
            if workspace_id_of(node):
                return node if isinstance(node, dict) else {"id": workspace_id_of(node)}
    return None


def pick_workspace(items: list) -> dict | None:
    selected = selected_workspace(items)
    if selected:
        return selected
    ranked = []
    for item in items:
        if isinstance(item, str) and item.strip():
            ranked.append((0, {"id": item.strip()}))
            continue
        if not isinstance(item, dict):
            continue
        blob = json.dumps(item).lower()
        score = 0
        if item.get("default") or item.get("is_default"):
            score += 3
        if "personal" in blob:
            score += 2
        if "owner" in blob:
            score += 1
        ranked.append((score, item))
    if not ranked:
        return None
    ranked.sort(key=lambda row: row[0], reverse=True)
    return ranked[0][1]


def set_workspace(hf: str, workspace_id: str) -> bool:
    if not workspace_id:
        return False
    for verb in ("set", "select", "use"):
        for extra in ([], ["--json"]):
            proc, _, blob = hf_run(hf, ["workspace", verb, workspace_id, *extra])
            if proc.returncode == 0 and "no workspace" not in blob.lower() and "now workspace" not in blob.lower():
                return True
    return False


def ensure_workspace(hf: str) -> dict:
    if not hf:
        return {"ok": False, "error": "Higgsfield CLI missing"}
    current = None
    listed = []
    last_blob = ""
    for args in (
        ["workspace", "list", "--json"],
        ["workspace", "--json"],
        ["workspace", "current", "--json"],
        ["workspace", "get", "--json"],
        ["workspace", "list"],
    ):
        proc, data, blob = hf_run(hf, args)
        last_blob = blob
        if data is None:
            continue
        listed = iter_workspaces(data) or listed
        current = selected_workspace(data) or current
        if listed or current:
            break

    if current and workspace_id_of(current):
        return {
            "ok": True,
            "workspace_id": workspace_id_of(current),
            "workspace_name": workspace_name_of(current),
        }

    chosen = pick_workspace(listed)
    candidates = [chosen] + [item for item in listed if item is not chosen]
    tried = []
    for cand in candidates:
        workspace_id = workspace_id_of(cand)
        if not workspace_id or workspace_id in tried:
            continue
        tried.append(workspace_id)
        if set_workspace(hf, workspace_id):
            return {
                "ok": True,
                "workspace_id": workspace_id,
                "workspace_name": workspace_name_of(cand),
            }
        name = workspace_name_of(cand)
        if name and name != workspace_id and name not in tried:
            tried.append(name)
            if set_workspace(hf, name):
                return {
                    "ok": True,
                    "workspace_id": name,
                    "workspace_name": name,
                }

    if not tried:
        err = last_blob[-400:] if last_blob else "no workspace selected"
        if "not authenticated" in err.lower() or "please login" in err.lower():
            return {"ok": False, "error": "Log in to Higgsfield first"}
        return {"ok": False, "error": "No Higgsfield workspace on this account"}
    return {"ok": False, "error": f"Could not select workspace {tried[0]}"}


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
    signed_in = logged_in(hf)
    workspace = ensure_workspace(hf) if signed_in else {}
    out({
        "ok": True,
        "hf": hf,
        "python": py,
        "ffmpeg": ff,
        "logged_in": signed_in,
        "ffmpeg_ok": bool(shutil.which("ffmpeg") and shutil.which("ffprobe")),
        "workspace_id": workspace.get("workspace_id", ""),
        "workspace_name": workspace.get("workspace_name", ""),
    })


def cmd_auth_status(out_dir: Path) -> None:
    hf = find_hf(out_dir)
    signed_in = logged_in(hf)
    workspace = ensure_workspace(hf) if signed_in else {}
    out({
        "ok": True,
        "hf": hf,
        "logged_in": signed_in,
        "workspace_id": workspace.get("workspace_id", ""),
        "workspace_name": workspace.get("workspace_name", ""),
    })


def cmd_ensure_workspace(out_dir: Path) -> None:
    hf = find_hf(out_dir)
    result = ensure_workspace(hf)
    result["hf"] = hf
    out(result)
    if not result.get("ok"):
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("ensure", "auth-status", "ensure-workspace"))
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    out_dir = Path(os.path.expanduser(args.out)).resolve()
    try:
        if args.command == "ensure":
            cmd_ensure(out_dir)
        elif args.command == "ensure-workspace":
            cmd_ensure_workspace(out_dir)
        else:
            cmd_auth_status(out_dir)
    except Exception as exc:
        out({"ok": False, "error": str(exc), "logged_in": False})
        sys.exit(1)


if __name__ == "__main__":
    main()
