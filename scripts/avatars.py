#!/usr/bin/env python3
"""List and activate archived avatars.

Every successful generation archives its sheet under
<data>/avatars/<stamp>/ (sheet + atlas.json + thumb.png). `list` prints the
archive as JSON — importing the currently active sheet once if the archive
is empty — and `activate` makes an archived avatar the live one by copying
its atlas spec over <data>/atlas.json.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def out(obj) -> None:
    print(json.dumps(obj), flush=True)


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def make_thumb(sheet: Path, dest: Path) -> None:
    """Crop the first idle frame (row 1) — transparent, tile-friendly."""
    proc = subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(sheet),
         "-vf", "crop=80:80:0:80", str(dest)],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0 or not dest.is_file():
        shutil.copy2(sheet, dest)


def archive_entry(d: Path):
    atlas = read_json(d / "atlas.json")
    sheet = d / "spritesheet_16x12.png"
    if not atlas or not sheet.is_file():
        return None
    thumb = d / "thumb.png"
    if not thumb.is_file():
        make_thumb(sheet, thumb)
    return {
        "dir": str(d),
        "name": d.name,
        "sheet": str(sheet),
        "thumb": str(thumb) if thumb.is_file() else str(sheet),
    }


def import_current(out_dir: Path, av_dir: Path):
    """First run with an existing avatar: bring it into the archive."""
    sheet = out_dir / "spritesheet_16x12.png"
    atlas = read_json(out_dir / "atlas.json")
    if not sheet.is_file() or not atlas:
        return
    stamp = time.strftime("%Y%m%d_%H%M%S")
    dest = av_dir / f"imported_{stamp}"
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(sheet, dest / "spritesheet_16x12.png")
    spec = dict(atlas)
    spec["file"] = str(dest / "spritesheet_16x12.png")
    (dest / "atlas.json").write_text(json.dumps(spec, indent=2) + "\n")
    make_thumb(dest / "spritesheet_16x12.png", dest / "thumb.png")


def default_entry(out_dir: Path, plugin_root: str):
    """The bundled pet is a permanent carousel entry, never archived: its
    sheet lives in the plugin dir (which moves on updates), so the atlas
    references it by the relative name the shell resolves at load time."""
    if not plugin_root:
        return None
    sheet = Path(plugin_root) / "default-sheet.png"
    if not sheet.is_file():
        return None
    thumb = out_dir / "default-thumb.png"
    if not thumb.is_file():
        make_thumb(sheet, thumb)
    return {
        "dir": "default",
        "name": "default",
        "sheet": "default-sheet.png",
        "thumb": str(thumb) if thumb.is_file() else str(sheet),
    }


def cmd_list(out_dir: Path, plugin_root: str) -> None:
    av_dir = out_dir / "avatars"
    av_dir.mkdir(parents=True, exist_ok=True)
    dirs = sorted([d for d in av_dir.iterdir() if d.is_dir()], reverse=True)
    if not dirs:
        import_current(out_dir, av_dir)
        dirs = sorted([d for d in av_dir.iterdir() if d.is_dir()], reverse=True)
    rows = [e for e in (archive_entry(d) for d in dirs) if e]
    default = default_entry(out_dir, plugin_root)
    if default:
        rows.append(default)
    out({"ok": True, "avatars": rows})


def cmd_activate(out_dir: Path, target: str) -> None:
    if target == "default":
        # Reverting to the bundled pet = removing the generated-atlas
        # override; the shell falls back to the built-in spec.
        (out_dir / "atlas.json").unlink(missing_ok=True)
        out({"ok": True, "default": True, "atlas": None})
        return
    d = Path(target).expanduser().resolve()
    av_root = (out_dir / "avatars").resolve()
    if av_root not in d.parents:
        out({"ok": False, "error": "not an archived avatar"})
        sys.exit(1)
    atlas = read_json(d / "atlas.json")
    if not atlas or not Path(str(atlas.get("file") or "")).is_file():
        out({"ok": False, "error": "archive is missing its sheet"})
        sys.exit(1)
    (out_dir / "atlas.json").write_text(json.dumps(atlas, indent=2) + "\n")
    out({"ok": True, "atlas": atlas})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["list", "activate"])
    parser.add_argument("--out", required=True)
    parser.add_argument("--dir", default="")
    parser.add_argument("--plugin-root", default="")
    args = parser.parse_args()
    out_dir = Path(args.out).expanduser()
    if args.command == "list":
        cmd_list(out_dir, args.plugin_root)
    else:
        if not args.dir:
            out({"ok": False, "error": "activate needs --dir"})
            sys.exit(1)
        cmd_activate(out_dir, args.dir)


if __name__ == "__main__":
    main()
