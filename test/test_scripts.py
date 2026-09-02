#!/usr/bin/env python3
"""Script-level tests: background repair guards and the avatar archive.

Run: python3 test/test_scripts.py  (needs Pillow + numpy; skips repair
tests without them, the archive tests always run).
"""
from __future__ import annotations

import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


try:
    from PIL import Image
    import numpy as np
    HAVE_PIL = True
except ImportError:
    HAVE_PIL = False

KEY = "#FF00FF"


def char_on(bg, hair=(10, 10, 12), w=512, h=512):
    im = Image.new("RGB", (w, h), bg)
    px = im.load()
    for y in range(120, 420):
        for x in range(200, 312):
            px[x, y] = (90, 90, 100)  # gray hoodie
    for y in range(80, 130):
        for x in range(210, 300):
            px[x, y] = hair
    return im


@unittest.skipUnless(HAVE_PIL, "Pillow/numpy not installed")
class BackgroundRepair(unittest.TestCase):
    """normalize_background: repair flat wrong backgrounds, refuse the rest."""

    @classmethod
    def setUpClass(cls):
        cls.gs = load("generate-sprite")
        cls.tmp = Path(tempfile.mkdtemp())

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def frame(self, name, bg, hair=(10, 10, 12)):
        p = self.tmp / f"{name}.png"
        char_on(bg, hair).save(p)
        return p

    def subject_alive(self, path):
        arr = np.asarray(Image.open(path).convert("RGB")).astype(int)
        return int((np.abs(arr - [90, 90, 100]).sum(axis=2) < 20).sum()) > 20000

    def test_repairs_uniform_wrong_backgrounds(self):
        for name, bg in (("black", (0, 0, 0)), ("pink", (240, 200, 210)), ("gray", (128, 128, 130))):
            p = self.frame(name, bg, hair=(70, 45, 25))
            fixed, note = self.gs.normalize_background(p, KEY)
            self.assertTrue(fixed, f"{name}: {note}")
            ok, why = self.gs.start_frame_ok({"name": name}, p, KEY, 0.0)
            self.assertTrue(ok, f"{name}: {why}")
            self.assertTrue(self.subject_alive(p), f"{name}: subject damaged")

    def test_refuses_color_collision(self):
        # near-black hair on a black background: nothing can separate them
        p = self.frame("collision", (0, 0, 0), hair=(10, 10, 12))
        fixed, note = self.gs.normalize_background(p, KEY)
        self.assertFalse(fixed)
        self.assertIn("too close", note)

    def test_refuses_gradient(self):
        p = self.tmp / "gradient.png"
        im = Image.new("RGB", (128, 128))
        for y in range(128):
            for x in range(128):
                im.putpixel((x, y), (x * 2, 30, y * 2))
        im.save(p)
        fixed, note = self.gs.normalize_background(p, KEY)
        self.assertFalse(fixed)
        self.assertIn("uniform", note)

    def test_leaves_correct_background_alone(self):
        p = self.frame("magenta", (255, 0, 255))
        fixed, note = self.gs.normalize_background(p, KEY)
        self.assertFalse(fixed)
        self.assertIn("already", note)


class AvatarArchive(unittest.TestCase):
    """avatars.py: listing includes the permanent default, activation guards."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.out = self.tmp / "out"
        arch = self.out / "avatars" / "20260901_1200"
        arch.mkdir(parents=True)
        shutil.copy2(ROOT / "default-sheet.png", arch / "spritesheet_16x12.png")
        (arch / "atlas.json").write_text(json.dumps(
            {"file": str(arch / "spritesheet_16x12.png"), "frameWidth": 80}))
        (self.out / "atlas.json").write_text("{}")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_avatars(self, *args):
        proc = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "avatars.py"), *args],
            capture_output=True, text=True, timeout=120)
        return proc.returncode, json.loads(proc.stdout.strip() or "{}")

    def test_list_includes_archive_and_default(self):
        code, data = self.run_avatars(
            "list", "--out", str(self.out), "--plugin-root", str(ROOT))
        self.assertEqual(code, 0)
        self.assertTrue(data["ok"])
        dirs = [a["dir"] for a in data["avatars"]]
        self.assertIn("default", dirs)
        self.assertTrue(any(d.endswith("20260901_1200") for d in dirs))
        default = next(a for a in data["avatars"] if a["dir"] == "default")
        self.assertEqual(default["sheet"], "default-sheet.png")

    def test_activate_default_clears_override(self):
        code, data = self.run_avatars("activate", "--out", str(self.out), "--dir", "default")
        self.assertEqual(code, 0)
        self.assertTrue(data["ok"] and data["default"])
        self.assertFalse((self.out / "atlas.json").exists())

    def test_activate_refuses_escape(self):
        code, data = self.run_avatars("activate", "--out", str(self.out), "--dir", "/etc")
        self.assertNotEqual(code, 0)
        self.assertFalse(data["ok"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
