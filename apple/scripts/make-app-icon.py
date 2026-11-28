#!/usr/bin/env python3
"""Draw Lauder's placeholder app icon: the trio in a wedge, in their in-game colours.

Simple shapes only, standing in until icon art is assigned. Writes an opaque 1024 x 1024 PNG,
as App Store Connect requires, using only the standard library. Run from the repository root:

    python3 apple/scripts/make-app-icon.py            # write the icon
    python3 apple/scripts/make-app-icon.py --check    # confirm the committed icon matches
"""

from pathlib import Path
import argparse
import math
import struct
import sys
import zlib

SIZE = 1024
# Another platform's maths may round a pixel's edge a step differently; anything more is a change.
TOLERANCE = 2
OUTPUT = Path("apple/sources/app/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

# The party's colours are SceneStyle's; the night ground, the head and the warm light are the icon's.
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


def committed_rows(path):
    """The committed icon's pixel rows, as this script writes them: 8-bit RGB, no row filter."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    position, image, size = 8, b"", None
    while position < len(data):
        (length,) = struct.unpack(">I", data[position:position + 4])
        kind = data[position + 4:position + 8]
        body = data[position + 8:position + 8 + length]
        position += 12 + length
        if kind == b"IHDR":
            size = struct.unpack(">II", body[:8])
        elif kind == b"IDAT":
            image += body
    if size != (SIZE, SIZE):
        raise ValueError(f"{path} is {size}, not {SIZE} x {SIZE}")
    raw = zlib.decompress(image)
    stride = 1 + SIZE * 3
    if len(raw) != stride * SIZE or any(raw[y * stride] for y in range(SIZE)):
        raise ValueError(f"{path} was not written by this script")
    return [raw[y * stride + 1:(y + 1) * stride] for y in range(SIZE)]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check", action="store_true", help="compare the committed icon instead of writing it")
    arguments = parser.parse_args()
    rows = [[pixel(x, y) for x in range(SIZE)] for y in range(SIZE)]
    if not arguments.check:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(png(SIZE, SIZE, rows))
        print(f"Wrote {OUTPUT}")
        return 0
    try:
        committed = committed_rows(OUTPUT)
    except (OSError, ValueError, zlib.error) as error:
        print(f"The app icon can't be checked: {error}")
        return 1
    worst = max(
        abs(made - kept)
        for row, kept_row in zip(rows, committed)
        for made, kept in zip((channel for rgb in row for channel in rgb), kept_row))
    if worst > TOLERANCE:
        print(f"{OUTPUT} differs from what the script makes, by up to {worst} in a channel.")
        return 1
    print(f"{OUTPUT} matches the script.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
