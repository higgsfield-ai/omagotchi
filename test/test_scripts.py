#!/usr/bin/env python3
"""Script-level tests: background repair guards and the avatar archive.

Run: python3 test/test_scripts.py  (needs Pillow + numpy; skips repair
tests without them, the archive tests always run).
"""
from __future__ import annotations

import importlib.util
import json
import os
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

    def test_activate_repoints_a_moved_archive(self):
        """The data dir was renamed: stored paths are stale, the dir is not."""
        arch = self.out / "avatars" / "20260901_1200"
        (arch / "atlas.json").write_text(json.dumps(
            {"file": "/gone/avatars/20260901_1200/spritesheet_16x12.png",
             "frameWidth": 80}))
        code, data = self.run_avatars("activate", "--out", str(self.out),
                                      "--dir", str(arch))
        self.assertEqual(code, 0)
        self.assertTrue(data["ok"])
        # macOS tempdirs live behind a /var -> /private/var symlink and the
        # healer resolves paths, so compare resolved to resolved.
        sheet = str((arch / "spritesheet_16x12.png").resolve())
        self.assertEqual(str(Path(data["atlas"]["file"]).resolve()), sheet)
        self.assertEqual(
            str(Path(json.loads((arch / "atlas.json").read_text())["file"]).resolve()), sheet)
        self.assertEqual(
            str(Path(json.loads((self.out / "atlas.json").read_text())["file"]).resolve()), sheet)

    def test_list_repoints_a_moved_active_atlas(self):
        (self.out / "atlas.json").write_text(json.dumps(
            {"file": "/gone/avatars/20260901_1200/spritesheet_16x12.png"}))
        code, _ = self.run_avatars(
            "list", "--out", str(self.out), "--plugin-root", str(ROOT))
        self.assertEqual(code, 0)
        self.assertEqual(
            str(Path(json.loads((self.out / "atlas.json").read_text())["file"]).resolve()),
            str((self.out / "avatars" / "20260901_1200" / "spritesheet_16x12.png").resolve()))

    def test_activate_refuses_escape(self):
        code, data = self.run_avatars("activate", "--out", str(self.out), "--dir", "/etc")
        self.assertNotEqual(code, 0)
        self.assertFalse(data["ok"])


class RuntimeHardening(unittest.TestCase):
    """runtime.py: pinned digests, constrained downloads, secret-free probe."""

    @classmethod
    def setUpClass(cls):
        cls.rt = load("runtime")
        cls.tmp = Path(tempfile.mkdtemp())

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def stub_cli(self, script: str) -> str:
        path = self.tmp / f"stub_{abs(hash(script))}.sh"
        path.write_text("#!/bin/sh\n" + script + "\n")
        path.chmod(0o755)
        return str(path)

    def test_download_url_guard(self):
        self.rt.check_download_url("https://github.com/x/y/releases/download/v1/a.tar.gz")
        with self.assertRaises(RuntimeError):
            self.rt.check_download_url("http://github.com/x")  # not https
        with self.assertRaises(RuntimeError):
            self.rt.check_download_url("https://evil.example.com/a.tar.gz")

    def test_pinned_digest(self):
        import hashlib
        blob = self.tmp / "cli.tar.gz"
        blob.write_bytes(b"pretend tarball")
        good = hashlib.sha256(b"pretend tarball").hexdigest()
        self.rt.CLI_SHA256["test_plat"] = good
        self.rt.verify_pinned_digest("test_plat", blob)  # matches: no raise
        blob.write_bytes(b"tampered tarball")
        with self.assertRaises(RuntimeError):
            self.rt.verify_pinned_digest("test_plat", blob)
        with self.assertRaises(RuntimeError):
            self.rt.verify_pinned_digest("unknown_plat", blob)

    def test_logged_in_needs_account_json(self):
        help_text = self.stub_cli("echo 'Usage: hf account <command>'; exit 0")
        self.assertFalse(self.rt.logged_in(help_text), "help text is not a session")
        signed_in = self.stub_cli(
            "echo '{\"user\":{\"email\":\"t@t\"},\"credits\":5}'; exit 0")
        self.assertTrue(self.rt.logged_in(signed_in))
        logged_out = self.stub_cli("echo 'Error: Not authenticated' >&2; exit 1")
        self.assertFalse(self.rt.logged_in(logged_out))
        self.assertFalse(self.rt.logged_in(""))

    def test_find_hf_never_uses_path(self):
        fake = self.tmp / "fake_path" ; fake.mkdir(exist_ok=True)
        (fake / "hf").write_text("#!/bin/sh\necho hi\n")
        (fake / "hf").chmod(0o755)
        env_path = os.environ.get("PATH", "")
        os.environ["PATH"] = f"{fake}:{env_path}"
        try:
            self.assertEqual(self.rt.find_hf(self.tmp / "empty_out"), "")
        finally:
            os.environ["PATH"] = env_path


class SpriteDownloadGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gs = load("generate-sprite")
        cls.tmp = Path(tempfile.mkdtemp())

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_rejects_non_https_result(self):
        with self.assertRaises(RuntimeError):
            self.gs.download("http://example.com/a.png", self.tmp / "a.png")

    def test_media_magic(self):
        self.assertTrue(self.gs.looks_like_media(b"\x89PNG\r\n\x1a\n"))
        self.assertTrue(self.gs.looks_like_media(b"\x00\x00\x00 ftypisom"))
        self.assertFalse(self.gs.looks_like_media(b"<!DOCTYPE html>"))

    def test_log_scrubs_signed_urls(self):
        log = self.tmp / "g.log"
        self.gs.append_log(log, "got https://cdn.example.com/a.png?X-Amz-Signature=SECRET&x=1 done")
        text = log.read_text()
        self.assertNotIn("SECRET", text)
        self.assertIn("https://cdn.example.com/a.png?…", text)


if __name__ == "__main__":
    unittest.main(verbosity=1)
