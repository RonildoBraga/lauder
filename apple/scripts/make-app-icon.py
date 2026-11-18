#!/usr/bin/env python3
"""Draw Lauder's placeholder app icon: the trio in a wedge, in their in-game colours.

Simple shapes only, standing in until icon art is assigned. Writes an opaque 1024 x 1024 PNG,
as App Store Connect requires, using only the standard library. Run from the repository root:

    python3 apple/scripts/make-app-icon.py
"""

from pathlib import Path
import math
import struct
import zlib

SIZE = 1024
OUTPUT = Path("apple/sources/app/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

# Colours from SceneStyle and the HUD.
BACKGROUND = (19, 33, 36)
GROUND = (34, 54, 56)
HEAD = (166, 173, 140)
WARM = (255, 191, 102)
MIKI = (64, 166, 150)
LAURA = (230, 156, 74)
TOM = (97, 130, 207)


def rounded_rectangle(cx, cy, width, height, radius):
    half_x, half_y = width / 2 - radius, height / 2 - radius

    def distance(x, y):
        qx, qy = abs(x - cx) - half_x, abs(y - cy) - half_y
        outside = math.hypot(max(qx, 0), max(qy, 0))
        return outside + min(max(qx, qy), 0) - radius

    return distance


def ellipse(cx, cy, rx, ry):
    def distance(x, y):
        # Approximate signed distance, accurate enough at the edge for anti-aliasing.
        dx, dy = (x - cx) / rx, (y - cy) / ry
        return (math.hypot(dx, dy) - 1) * min(rx, ry)

    return distance


def ring(cx, cy, rx, ry, thickness):
    outer = ellipse(cx, cy, rx, ry)
    inner = ellipse(cx, cy, rx - thickness, ry - thickness)
    return lambda x, y: max(outer(x, y), -inner(x, y))


def figure(cx, top, body_width, colour):
    """A head above a rounded body, like the in-game stand-ins."""
    return [
        (rounded_rectangle(cx, top + 205, body_width, 270, 34), colour),
        (ellipse(cx, top + 62, 62, 62), HEAD),
    ]


SHAPES = (
    [(ellipse(512, 640, 400, 200), GROUND), (ring(512, 728, 132, 44, 18), WARM)]
    + figure(300, 268, 129, LAURA)
    + figure(724, 268, 204, TOM)
    + figure(512, 378, 158, MIKI)
)


def pixel(x, y):
    colour = BACKGROUND
    for distance, fill in SHAPES:
        coverage = min(max(0.5 - distance(x + 0.5, y + 0.5), 0), 1)
        if coverage > 0:
            colour = tuple(round(c + (f - c) * coverage) for c, f in zip(colour, fill))
    return colour


def png(width, height, rows):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    raw = b"".join(b"\x00" + bytes(channel for rgb in row for channel in rgb) for row in rows)
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB, no alpha
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def main():
    rows = [[pixel(x, y) for x in range(SIZE)] for y in range(SIZE)]
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(png(SIZE, SIZE, rows))
    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
