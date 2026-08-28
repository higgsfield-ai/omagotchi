#!/usr/bin/env python3
"""Place the HF chip on the bar when the plugin was enabled as overlay-only.

Omarchy enable/put skip bar placement if the id is already in plugins[].
This plugin started as overlay+service, so existing installs never got a slot.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

PLUGIN_ID = "higgsfield.signals"
SECTION = "right"


def entry_id(entry) -> str:
    if isinstance(entry, dict):
        return str(entry.get("id") or "")
    return str(entry or "")


def main() -> int:
    home = Path(os.environ.get("HOME") or Path.home())
    path = home / ".config" / "omarchy" / "shell.json"
    if not path.is_file():
        print("missing", flush=True)
        return 2

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print("invalid", flush=True)
        return 2
    if not isinstance(data, dict):
        print("invalid", flush=True)
        return 2

    bar = data.setdefault("bar", {})
    if not isinstance(bar, dict):
        print("invalid", flush=True)
        return 2
    layout = bar.setdefault("layout", {})
    if not isinstance(layout, dict):
        layout = {}
        bar["layout"] = layout
    for section in ("left", "center", "right"):
        entries = layout.get(section)
        if not isinstance(entries, list):
            layout[section] = []

    for section in ("left", "center", "right"):
        for entry in layout[section]:
            if entry_id(entry) == PLUGIN_ID:
                print("present", flush=True)
                return 1

    layout[SECTION].append({"id": PLUGIN_ID})

    plugins = data.get("plugins")
    if isinstance(plugins, list):
        data["plugins"] = [
            p for p in plugins
            if not (isinstance(p, dict) and entry_id(p) == PLUGIN_ID)
        ]

    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)
    subprocess.run(["omarchy-shell", "shell", "reloadConfig"], check=False)
    print("placed", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
