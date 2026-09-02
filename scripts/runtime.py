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
UA = "higgsfield-omagotchi-omarchy/0.15"

# Exact CLI release this plugin installs, with digests embedded HERE — in the
# reviewed tree — so verification does not trust the same channel the archive
# comes from. Bump tag + digests together (dev/relock-deps.py prints them).
CLI_TAG = "v1.1.24"
CLI_SHA256 = {
    "linux_amd64": "626ce7fbfec2df737ec1e5a8643431479fa0d2d2376d6a52b7d7467051754862",
    "linux_arm64": "7f54234362688b460122a6ae7d42152b16d62781f8366bf8f8d078ab566a5604",
    "darwin_arm64": "cf23707ea8f437c93102d891125c10318c5812233f60b4c3bfda2d1d5334fe4b",
}
DOWNLOAD_HOSTS = {"github.com", "api.github.com", "objects.githubusercontent.com",
                  "release-assets.githubusercontent.com", "codeload.github.com"}
MAX_DOWNLOAD_BYTES = 200 * 1024 * 1024

# Everything this plugin writes is owner-only: photos, generated likenesses,
# CLI auth state and logs all live under the data dir.
os.umask(0o077)


def check_download_url(url: str) -> None:
    from urllib.parse import urlparse
    parsed = urlparse(url)
    if parsed.scheme != "https":
        raise RuntimeError(f"refusing non-https download: {url}")
    host = (parsed.hostname or "").lower()
    if host not in DOWNLOAD_HOSTS:
        raise RuntimeError(f"refusing download from unexpected host: {host}")


def secure_dir(path: Path) -> Path:
    """Create the data dir owner-only and refuse to operate through links."""
    if path.is_symlink():
        raise RuntimeError(f"data dir is a symlink, refusing: {path}")
    path.mkdir(parents=True, exist_ok=True)
    os.chmod(path, 0o700)
    return path


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
    """Only the binary this plugin installed and digest-verified. A
    higgsfield/hf found on PATH is somebody else's executable — never run it."""
    bundled = out_dir / "bin" / "higgsfield"
    if bundled.is_file() and not bundled.is_symlink() and os.access(bundled, os.X_OK):
        return str(bundled)
    return ""



def http_download(url: str, dest: Path) -> None:
    """https-only, allowlisted hosts (including after redirects), byte-capped,
    written to a private temp file and published atomically."""
    check_download_url(url)
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    tmp = dest.parent / (dest.name + ".part")
    total = 0
    try:
        with urllib.request.urlopen(req, timeout=180) as resp, open(tmp, "wb") as fh:
            check_download_url(resp.geturl())
            while True:
                chunk = resp.read(1024 * 256)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_DOWNLOAD_BYTES:
                    raise RuntimeError("download exceeds the size cap")
                fh.write(chunk)
        os.replace(tmp, dest)
    finally:
        tmp.unlink(missing_ok=True)


def verify_pinned_digest(platform_key: str, archive: Path) -> None:
    """The expected sha256 ships in this reviewed file, not in the release
    channel the archive comes from — replacing the release cannot also
    replace the digest it must match."""
    expected = CLI_SHA256.get(platform_key, "")
    if not expected:
        raise RuntimeError(f"no pinned digest for {platform_key}")
    digest = hashlib.sha256()
    with open(archive, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    if digest.hexdigest().lower() != expected:
        raise RuntimeError("CLI digest does not match the pinned release — download discarded")


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

    tag = CLI_TAG
    ver = tag[1:] if tag.startswith("v") else tag
    platform_key = f"{os_key}_{arch}"
    tarball = f"hf_{ver}_{platform_key}.tar.gz"
    url = f"https://github.com/{REPO}/releases/download/{tag}/{tarball}"
    bin_dir = out_dir / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / tarball
        http_download(url, archive)
        verify_pinned_digest(platform_key, archive)
        with tarfile.open(archive) as tar:
            # The 'data' filter rejects absolute paths, traversal, links and
            # device nodes. A Python too old to have it does not get a
            # fallback to unfiltered extraction.
            try:
                tar.extractall(tmp, filter="data")
            except TypeError as exc:
                raise RuntimeError("Python 3.12+ required for safe extraction") from exc
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
        lock = Path(__file__).resolve().parent / "requirements.lock"
        subprocess.run(
            [str(py), "-m", "pip", "install", "--quiet", "--require-hashes",
             "--only-binary", ":all:", "-r", str(lock)],
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

    # Selecting a workspace changes account state, so it is never guessed:
    # with exactly one workspace there is nothing to choose and it is set;
    # with several, the user picks once via `higgsfield workspace select`.
    if len(listed) == 1:
        workspace_id = workspace_id_of(listed[0])
        if workspace_id and set_workspace(hf, workspace_id):
            return {
                "ok": True,
                "workspace_id": workspace_id,
                "workspace_name": workspace_name_of(listed[0]),
            }
    if listed:
        return {"ok": False, "error":
                "Several Higgsfield workspaces on this account — run "
                "`higgsfield workspace select <name>` once, then retry"}
    err = last_blob[-400:] if last_blob else "no workspace selected"
    if "not authenticated" in err.lower() or "please login" in err.lower():
        return {"ok": False, "error": "Log in to Higgsfield first"}
    return {"ok": False, "error": "No Higgsfield workspace on this account"}


def logged_in(hf: str) -> bool:
    """A non-secret status probe: the token itself must never enter this
    process. Help text exits 0 too, so success requires actual account JSON —
    parseable and carrying an account-shaped field — not just a zero exit."""
    if not hf:
        return False
    proc = subprocess.run([hf, "account", "status", "--json"],
                          capture_output=True, text=True)
    text = ((proc.stdout or "") + "\n" + (proc.stderr or "")).lower()
    if "not authenticated" in text or "session expired" in text or "please login" in text:
        return False
    if proc.returncode != 0:
        return False
    data = last_json(proc.stdout or "")
    if not isinstance(data, dict):
        return False
    return any(k in data for k in ("user", "email", "credits", "account", "plan", "workspace"))


def cmd_ensure(out_dir: Path) -> None:
    secure_dir(out_dir)
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
