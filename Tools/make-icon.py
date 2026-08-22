#!/usr/bin/env python3
"""Draws the Rotation app icon – a record – without any image library.

Pure standard library: the pixels are computed here and written as a PNG by
hand, so the repository needs no build dependency to regenerate the icon.

    python3 Tools/make-icon.py
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

SIZE = 1024
SUPERSAMPLE = 3          # drawn at 3× and averaged down, for clean edges

BACKGROUND = (10, 10, 15)
GROOVE = (58, 58, 74)
HOLE = (10, 10, 15)

# One icon per accent, so the app on the home screen wears the colour the app
# wears inside. The names match the palettes in Appearance.swift.
ACCENTS = {
    "": (255, 90, 60),          # sunset – the default AppIcon
    "Mint": (42, 212, 164),
    "Violet": (160, 107, 255),
    "Ocean": (63, 157, 255),
    "Gold": (240, 180, 41),
    "Rose": (255, 93, 143),
}
ACCENT = ACCENTS[""]

# Radii as a fraction of half the icon: grooves, then the label in the middle.
GROOVES = [0.86, 0.74, 0.62, 0.50]
GROOVE_WIDTH = 0.018
LABEL = 0.30
HOLE_RADIUS = 0.075
DISC = 0.88


def colour_at(x: float, y: float, accent: tuple[int, int, int]) -> tuple[int, int, int]:
    """The colour of one point, in units where the icon spans -1 … 1."""
    radius = (x * x + y * y) ** 0.5
    if radius > DISC:
        return BACKGROUND
    if radius < HOLE_RADIUS:
        return HOLE
    if radius < LABEL:
        return accent
    for groove in GROOVES:
        if abs(radius - groove) < GROOVE_WIDTH:
            return GROOVE
    # The vinyl itself: a touch lighter than the surround, so the disc reads
    # as an object rather than a hole in the background.
    return (18, 18, 26)


def render(size: int, accent: tuple[int, int, int]) -> bytes:
    rows = []
    step = 2.0 / (size * SUPERSAMPLE)
    for row in range(size):
        line = bytearray()
        for column in range(size):
            red = green = blue = 0
            for sub_y in range(SUPERSAMPLE):
                y = -1.0 + (row * SUPERSAMPLE + sub_y + 0.5) * step
                for sub_x in range(SUPERSAMPLE):
                    x = -1.0 + (column * SUPERSAMPLE + sub_x + 0.5) * step
                    pixel = colour_at(x, y, accent)
                    red += pixel[0]
                    green += pixel[1]
                    blue += pixel[2]
            samples = SUPERSAMPLE * SUPERSAMPLE
            line += bytes((red // samples, green // samples, blue // samples))
        rows.append(bytes(line))
    return b"".join(b"\x00" + row for row in rows)


def write_png(path: Path, size: int, accent: tuple[int, int, int]) -> None:
    raw = render(size, accent)

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", header)
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    path.write_bytes(png)


CONTENTS = (
    '{\n  "images" : [\n    {\n      "filename" : "icon-1024.png",\n'
    '      "idiom" : "universal",\n      "platform" : "ios",\n'
    '      "size" : "1024x1024"\n    }\n  ],\n'
    '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'
)


if __name__ == "__main__":
    here = Path(__file__).resolve().parent.parent
    catalogue = here / "Resources/Assets.xcassets"
    for suffix, accent in ACCENTS.items():
        name = "AppIcon" + (f"-{suffix}" if suffix else "")
        target = catalogue / f"{name}.appiconset"
        target.mkdir(parents=True, exist_ok=True)
        write_png(target / "icon-1024.png", SIZE, accent)
        (target / "Contents.json").write_text(CONTENTS, encoding="utf-8")
        print(f"wrote {target}/icon-1024.png")
