"""Generate resources/images/weather_moon.png: a flat crescent moon matching the
32x32 style of the other weather icons (single flat colour, transparent bg).

Usage: python tools/gen_moon_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

SS = 8            # supersample factor
SIZE = 32         # final canvas size (same as weather_sun.png)
COLOR = (236, 222, 160, 255)  # pale moonlight yellow

OUT = Path(__file__).resolve().parent.parent / "resources" / "images" / "weather_moon.png"


def main() -> None:
    s = SIZE * SS
    moon = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(moon)
    # Full disc, then cut a second disc offset up-right to leave a crescent.
    r = 12.5 * SS
    c = s / 2
    d.ellipse((c - r, c - r, c + r, c + r), fill=255)
    cut = Image.new("L", (s, s), 0)
    dc = ImageDraw.Draw(cut)
    ox, oy, rc = c + 6.5 * SS, c - 4.5 * SS, 11 * SS
    dc.ellipse((ox - rc, oy - rc, ox + rc, oy + rc), fill=255)
    mask = Image.composite(Image.new("L", (s, s), 0), moon, cut)

    img = Image.new("RGBA", (s, s), COLOR[:3] + (0,))
    img.putalpha(mask)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
