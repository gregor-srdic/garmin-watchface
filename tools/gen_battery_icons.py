"""Generate resources/images/battery.png, battery_low.png and battery_charging.png:
flat 32x32 icons matching the weather icons (single flat colour, transparent bg).

battery / battery_low: horizontal battery outline with terminal nub and a solid
inner fill bar (static, not a level). battery_charging: a lightning bolt.

Usage: python tools/gen_battery_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

SS = 8            # supersample factor
SIZE = 32         # final canvas size (same as weather_*.png)

GRAY = (204, 204, 204)
RED = (255, 77, 77)
GOLD = (236, 222, 160)

OUT_DIR = Path(__file__).resolve().parent.parent / "resources" / "images"


def battery_mask() -> Image.Image:
    s = SIZE * SS
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    # Body outline 3..27 x 9..23, 2px stroke, rounded; nub on the right.
    d.rounded_rectangle((3 * SS, 9 * SS, 27 * SS - 1, 23 * SS - 1), radius=3 * SS, fill=255)
    d.rounded_rectangle((5 * SS, 11 * SS, 25 * SS - 1, 21 * SS - 1), radius=1 * SS, fill=0)
    d.rounded_rectangle((27 * SS, 13 * SS, 30 * SS - 1, 19 * SS - 1), radius=1 * SS, fill=255)
    # Inner fill bar.
    d.rounded_rectangle((7 * SS, 13 * SS, 19 * SS - 1, 19 * SS - 1), radius=1 * SS // 2, fill=255)
    return m


def bolt_mask() -> Image.Image:
    s = SIZE * SS
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    pts = [(18.5, 3), (8, 18), (15, 18), (12.5, 29), (24, 13), (17, 13), (20.5, 3)]
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return m


def save(name: str, color, mask: Image.Image) -> None:
    # Downscale the mask alone so the RGB stays exactly the flat colour.
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
    img = Image.new("RGBA", (SIZE, SIZE), color + (0,))
    img.putalpha(mask)
    path = OUT_DIR / name
    img.save(path)
    print(f"wrote {path}")


def main() -> None:
    save("battery.png", GRAY, battery_mask())
    save("battery_low.png", RED, battery_mask())
    save("battery_charging.png", GOLD, bolt_mask())


if __name__ == "__main__":
    main()
