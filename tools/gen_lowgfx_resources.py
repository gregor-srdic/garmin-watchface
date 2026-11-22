"""Pre-scaled, pre-flattened bitmaps for watches without enhanced graphics.

Some AMOLED watches (FR165/165M, FR70, vivoactive 5, Instinct 3 AMOLED) have
"enhancedGraphicSupport": false in their device profile. On those:

- Dc.drawScaledBitmap doesn't exist, so ArchesWatchFaceView.drawScaledBitmap()
  falls back to dc.drawBitmap(), which draws a bitmap at its native size; and
- soft alpha edges are reduced to on/off pixels with a dither, so edges look
  jagged.

This writes copies of every time digit and icon that are (1) resized to exactly
the size the view asks for on that watch, so the fallback draws them right, and
(2) blended onto black and saved opaque, so edges stay smooth. That works
because every one of these bitmaps is drawn over the black background. It also
writes a drawables.xml that overrides the ids. Point only those devices at the
folder in monkey.jungle.

Sizes mirror the view's math:
  digits    onLayout()/drawTime(), from the screen width
  arc icons drawArcLabels(): int(Gfx.getFontHeight(FONT_TINY) * 0.8)
  row icons drawInfoRow():   Gfx.getFontHeight(FONT_XTINY)
Font heights are per device; measure them in the simulator.

    python tools/gen_lowgfx_resources.py <name> <screen_w> <tiny_h> <xtiny_h>
    python tools/gen_lowgfx_resources.py fr165 390 35 30   # -> resources-lowgfx-fr165/

Rerun after any source digit or icon changes. The commands for every
group are in monkey.jungle.
"""

import os
import re
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC_IMG = os.path.join(ROOT, "resources", "images")
SRC_XML = os.path.join(ROOT, "resources", "drawables", "drawables.xml")


def digit_sizes(screen_w: int):
    """Monkey C toNumber() truncates, as int() does here."""
    scale = screen_w / 454.0
    render_h = int(108.0 * scale)
    dw_full = int(60.0 * (render_h / 90.0))
    dw_colon = int(dw_full * 0.55)
    return dw_full, dw_colon, render_h


def flatten_on_black(img: Image.Image, size) -> Image.Image:
    # Resize in premultiplied alpha (no dark/bright fringes), then composite
    # onto black and drop the alpha.
    img = img.convert("RGBA").convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    bg = Image.new("RGBA", size, (0, 0, 0, 255))
    return Image.alpha_composite(bg, img)


def main() -> None:
    name, screen_w, tiny_h, xtiny_h = sys.argv[1], *map(int, sys.argv[2:5])
    dw_full, dw_colon, render_h = digit_sizes(screen_w)
    arc_icon = int(tiny_h * 0.8)
    row_icon = xtiny_h

    out = os.path.join(ROOT, f"resources-lowgfx-{name}")
    os.makedirs(os.path.join(out, "images"), exist_ok=True)
    os.makedirs(os.path.join(out, "drawables"), exist_ok=True)

    entries = re.findall(
        r'<bitmap id="(\w+)"\s+filename="\.\./images/([\w.]+)"/>',
        open(SRC_XML, encoding="utf-8").read(),
    )
    picked = []
    for rid, fname in entries:
        if rid == "DigitColon":
            size = (dw_colon, render_h)
        elif rid.startswith("Digit"):
            size = (dw_full, render_h)
        elif rid.startswith("Weather") or rid.startswith("IconBattery"):
            size = (row_icon, row_icon)
        elif rid.startswith("Icon"):
            size = (arc_icon, arc_icon)
        else:
            continue  # LauncherIcon: handled by resources-iconNN
        src = Image.open(os.path.join(SRC_IMG, fname))
        flatten_on_black(src, size).save(os.path.join(out, "images", fname))
        picked.append((rid, fname))
    assert len(picked) == 41 + 4 + 11 + 3, len(picked)

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<resources>",
        f"    <!-- {name}: no enhanced graphics. Pre-scaled and flattened on black",
        "         by tools/gen_lowgfx_resources.py; overrides resources/. -->",
    ]
    lines += [f'    <bitmap id="{rid}" filename="../images/{f}"/>' for rid, f in picked]
    lines.append("</resources>")
    with open(os.path.join(out, "drawables", "drawables.xml"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

    print(
        f"wrote {os.path.normpath(out)}: digits {dw_full}x{render_h}, colon "
        f"{dw_colon}x{render_h}, arc icons {arc_icon}, row icons {row_icon}"
    )


if __name__ == "__main__":
    main()
