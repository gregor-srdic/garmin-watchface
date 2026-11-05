"""Generate the launcher icon at a device's native size, so the SDK doesn't
rescale (and blur) it.

Geometry is proportional to the canvas and was measured from the original
65x65 resources/images/launcher_icon.png: black rounded square, four arcs in
the face's original (undimmed) accent colours with round caps and gaps at the
cardinal points, and a purple centre dot.

Usage:
  python tools/gen_launcher_icon.py 60 resources-icon60/images/launcher_icon.png
  python tools/gen_launcher_icon.py 70 resources-icon70/images/launcher_icon.png
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SS = 8  # supersample factor

# Measurements from the 65 px original, as fractions of the canvas size.
CORNER = 10 / 65        # rounded-square corner radius
ARC_R = 24.5 / 65       # arc centreline radius
STROKE = 6.5 / 65       # arc stroke width
DOT_R = 4.2 / 65        # centre dot radius
ARC_SPAN = (9.5, 80.5)  # arc body within each quadrant, degrees (caps extend it)

# PIL angles: 0 = east, clockwise. Quadrant start angle -> colour.
ARCS = [
    (270, (255, 160, 64)),   # top-right, orange
    (0, (255, 125, 163)),    # bottom-right, pink
    (90, (74, 158, 255)),    # bottom-left, blue
    (180, (255, 77, 77)),    # top-left, red
]
DOT = (200, 128, 255)


def render(size: int) -> Image.Image:
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, s - 1, s - 1), radius=CORNER * s, fill=(0, 0, 0, 255))

    c = s / 2
    r = ARC_R * s
    w = STROKE * s
    for start, colour in ARCS:
        a0, a1 = start + ARC_SPAN[0], start + ARC_SPAN[1]
        d.arc((c - r - w / 2, c - r - w / 2, c + r + w / 2, c + r + w / 2),
              a0, a1, fill=colour, width=round(w))
        for a in (a0, a1):  # round caps
            x = c + r * math.cos(math.radians(a))
            y = c + r * math.sin(math.radians(a))
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=colour)

    dr = DOT_R * s
    d.ellipse((c - dr, c - dr, c + dr, c + dr), fill=DOT)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    size, out = int(sys.argv[1]), Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    render(size).save(out)
    print(f"wrote {out} ({size}x{size})")


if __name__ == "__main__":
    main()
