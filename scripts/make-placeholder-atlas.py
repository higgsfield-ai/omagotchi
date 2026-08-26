#!/usr/bin/env python3
"""Write atlas.png — 7 color rows × 8 cells. No AI, stdlib only."""

from __future__ import annotations

import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ATLAS_JSON = ROOT / "atlas.json"
ATLAS_PNG = ROOT / "atlas.png"

# Distinct rows so a mode change is obvious before a real sheet exists.
ROW_COLORS = {
    "idle": (0x88, 0x88, 0x88),
    "hurry": (0xF9, 0x90, 0x00),
    "dance": (0x33, 0xCC, 0x33),
    "sleep": (0x33, 0x66, 0xFF),
    "happy": (0xFF, 0xCC, 0x00),
    "angry": (0xFF, 0x33, 0x33),
    "wave": (0xEE, 0xEE, 0xEE),
}


def png_rgba(width: int, height: int, pixels: bytes) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def shade(rgb: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(c * t))) for c in rgb)


def build(cell: int, columns: int, modes: dict[str, int]) -> bytes:
    rows = max(modes.values()) + 1
    width = cell * columns
    height = cell * rows
    pixels = bytearray(width * height * 4)

    by_row = {row: name for name, row in modes.items()}
    for row in range(rows):
        rgb = ROW_COLORS.get(by_row.get(row, "idle"), (0x44, 0x44, 0x44))
        for col in range(columns):
            # Darken across the row so the loop is visible on a placeholder.
            t = 0.45 + (col / max(columns - 1, 1)) * 0.55
            r, g, b = shade(rgb, t)
            x0, y0 = col * cell, row * cell
            for y in range(y0, y0 + cell):
                for x in range(x0, x0 + cell):
                    i = (y * width + x) * 4
                    pixels[i : i + 4] = bytes((r, g, b, 255))
            # Frame index pip in the corner.
            pip = min(cell - 2, 6)
            for y in range(y0 + 2, y0 + 2 + pip):
                for x in range(x0 + 2, x0 + 2 + pip):
                    i = (y * width + x) * 4
                    pixels[i : i + 4] = bytes((20, 20, 20, 255))

    return png_rgba(width, height, bytes(pixels))


def main() -> None:
    spec = json.loads(ATLAS_JSON.read_text())
    png = build(int(spec["cell"]), int(spec["columns"]), spec["modes"])
    ATLAS_PNG.write_bytes(png)
    print(f"wrote {ATLAS_PNG} ({len(png)} bytes)")


if __name__ == "__main__":
    main()
