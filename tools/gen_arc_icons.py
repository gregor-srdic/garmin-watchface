"""Generate flat single-color arc metric icons for the watch face.

Draws each silhouette at 8x supersampling, downsamples to 48x48 with
LANCZOS, and fills with the exact arc accent color from the watch face
palette. Output overwrites resources/images/{hr,stress,body,calories}.png.
"""

import math
import os
from PIL import Image, ImageDraw

SS = 8          # supersample factor
SIZE = 48       # final canvas size
OUT = os.path.join(os.path.dirname(__file__), "..", "resources", "images")

# Slot accent colors from ForerunnerWatchFaceView.mc (original design values;
# BRIGHTNESS below must match the dimming applied to the COLOR_ARC_* constants)
BRIGHTNESS = 0.65

COLORS = {
    "hr": (0xFF, 0x4D, 0x4D),        # COLOR_ARC_3 red
    "stress": (0xFF, 0xA0, 0x40),    # COLOR_ARC_0 orange
    "body": (0x4A, 0x9E, 0xFF),      # COLOR_ARC_2 blue
    "calories": (0xFF, 0x7D, 0xA3),  # COLOR_ARC_1 pink
}

COLORS = {k: tuple(int(c * BRIGHTNESS) for c in v) for k, v in COLORS.items()}


def canvas():
    img = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    return img, ImageDraw.Draw(img)


def s(pts):
    """Scale 48-grid coordinates to the supersampled canvas."""
    return [(x * SS, y * SS) for x, y in pts]


def bezier(p0, p1, p2, p3, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def arc_points(cx, cy, r, a0, a1, n=60):
    return [
        (cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
         cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
        for i in range(n + 1)
    ]


def heart():
    img, d = canvas()
    # Classic parametric heart, scaled/centered into the 48 grid
    pts = []
    for i in range(200):
        t = 2 * math.pi * i / 200
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((24 + x * 1.35, 22 - y * 1.35))
    d.polygon(s(pts), fill=255)
    return img


def bolt():
    img, d = canvas()
    # Top edge and shaft kept wide: the icon is drawn at ~20px on the watch,
    # and a thin tip collapses into stray pixels after downscaling.
    pts = [(26, 2), (8, 28), (20, 28), (16, 46), (40, 18), (27, 18), (38, 2)]
    d.polygon(s(pts), fill=255)
    return img


def battery():
    img, d = canvas()
    # Nub + solid body with one knockout slot to read as a charge level
    d.rounded_rectangle(s([(18, 2), (30, 8)])[0] + s([(18, 2), (30, 8)])[1],
                        radius=2 * SS, fill=255)
    d.rounded_rectangle(s([(12, 6), (36, 46)])[0] + s([(12, 6), (36, 46)])[1],
                        radius=5 * SS, fill=255)
    d.rounded_rectangle(s([(16.5, 12), (31.5, 20)])[0] + s([(16.5, 12), (31.5, 20)])[1],
                        radius=2 * SS, fill=0)
    return img


def flame():
    img, d = canvas()
    tip = (27, 2)
    pts = []
    # right edge: tip bulging out to the right side of the bulb
    pts += bezier(tip, (33, 9), (38, 16), (38, 29))
    # bottom bulb: arc from right (0 deg) through bottom to left (180 deg)
    pts += arc_points(24, 29, 14, 0, 180)
    # left edge: S-curve with a kink to read as a flame, back up to the tip
    pts += bezier((10, 29), (7, 19), (20, 24), (16, 13))
    pts += bezier((16, 13), (14, 6), (23, 8), tip)
    d.polygon(s(pts), fill=255)
    # inner knockout flame (teardrop) so it reads as fire, not a droplet
    inner = []
    itip = (24, 24)
    inner += bezier(itip, (28, 29), (30, 31), (30, 35))
    inner += arc_points(24, 35, 6, 0, 180)
    inner += bezier((18, 35), (18, 31), (20, 29), itip)
    d.polygon(s(inner), fill=0)
    return img


def save(name, mask_img):
    mask = mask_img.resize((SIZE, SIZE), Image.LANCZOS)
    r, g, b = COLORS[name]
    out = Image.new("RGBA", (SIZE, SIZE), (r, g, b, 0))
    out.putalpha(mask)
    path = os.path.join(OUT, f"{name}.png")
    out.save(path)
    print("wrote", path)


save("hr", heart())
save("stress", bolt())
save("body", battery())
save("calories", flame())
