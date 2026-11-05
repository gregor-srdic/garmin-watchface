"""Tint the time-digit PNGs with one continuous horizontal gradient.

Keeps each PNG's alpha channel and refills RGB with the slot's segment of a
pink -> purple -> blue gradient spanning the whole HH:MM layout, so colors
match at slot joins. Idempotent: only alpha is read.

    python tools/gen_digit_gradient.py          # regenerate
    python tools/gen_digit_gradient.py --check  # verify vs git HEAD alpha
"""

import io
import os
import subprocess
import sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
IMG = os.path.join(ROOT, "resources", "images")

# Layout at the 454 reference, mirroring ArchesWatchFaceView.drawTime():
# dwFull = 60 * 108/90 = 72, dwColon = int(0.55 * dwFull) = 39, kern = 2.
# Slots: h1, h2, colon, m1, m2.
SLOT_W = [72, 72, 39, 72, 72]
KERN = 2
OFFSETS = [0, 74, 148, 189, 263]
TOTAL = 335  # sum(SLOT_W) + 4 * KERN

STOPS = [(0.0, (0xFF, 0x8F, 0xA3)), (0.5, (0xB4, 0x8C, 0xFF)), (1.0, (0x6A, 0xA8, 0xFF))]

SLOT_FILES = (
    [(0, f"h1_{d}") for d in range(10)]
    + [(1, f"h2_{d}") for d in range(10)]
    + [(2, "colon_colon")]
    + [(3, f"m1_{d}") for d in range(10)]
    + [(4, f"m2_{d}") for d in range(10)]
)


def gradient(t):
    t = min(1.0, max(0.0, t))
    for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(int(round(a + (b - a) * f)) for a, b in zip(c0, c1))
    return STOPS[-1][1]


def column_colors(slot, width):
    return [
        gradient((OFFSETS[slot] + (c + 0.5) / width * SLOT_W[slot]) / TOTAL)
        for c in range(width)
    ]


def path(name):
    return os.path.join(IMG, name + ".png")


def generate():
    for slot, name in SLOT_FILES:
        im = Image.open(path(name)).convert("RGBA")
        w, h = im.size
        cols = column_colors(slot, w)
        alpha = im.getchannel("A").tobytes()
        out = Image.new("RGBA", (w, h))
        px = out.load()
        for y in range(h):
            for x in range(w):
                px[x, y] = cols[x] + (alpha[y * w + x],)
        out.save(path(name))
    print(f"wrote {len(SLOT_FILES)} digit PNGs")


def head_alpha(name):
    data = subprocess.check_output(
        ["git", "show", f"HEAD:resources/images/{name}.png"], cwd=ROOT
    )
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    return im.size, im.getchannel("A").tobytes()


def check():
    errors = []
    for slot, name in SLOT_FILES:
        if not os.path.exists(path(name)):
            errors.append(f"{name}: missing")
            continue
        im = Image.open(path(name)).convert("RGBA")
        size, a_head = head_alpha(name)
        if im.size != size:
            errors.append(f"{name}: size {im.size} != HEAD {size}")
            continue
        if im.getchannel("A").tobytes() != a_head:
            errors.append(f"{name}: alpha differs from HEAD")
            continue
        w, h = im.size
        cols = column_colors(slot, w)
        px = im.load()
        for y in range(h):
            for x in range(w):
                p = px[x, y]
                if p[3] > 0 and any(abs(p[i] - cols[x][i]) > 2 for i in range(3)):
                    errors.append(f"{name}: color off at ({x},{y})")
                    break
            else:
                continue
            break
    if errors:
        print("FAIL: " + "; ".join(errors[:5]) + (f" (+{len(errors)-5} more)" if len(errors) > 5 else ""))
        return 1
    print(f"OK: {len(SLOT_FILES)} digit PNGs match HEAD alpha and gradient")
    return 0


if __name__ == "__main__":
    if "--check" in sys.argv[1:]:
        sys.exit(check())
    generate()
