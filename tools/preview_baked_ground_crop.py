#!/usr/bin/env python3
"""Static layout previews: cropped sky + ground strip band (no double path).

Reads background_morning.png, crops the bottom bakedGroundFraction (0.28),
cover-scales into three phone landscape sizes, and paints an opaque ground
band over the bottom 16.5% (PlayerComponent.groundHeightRatio).
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "images" / "background_morning.png"
OUT_DIR = ROOT / "tools" / "screenshots"
BAKED_GROUND_FRACTION = 0.28
GROUND_HEIGHT_RATIO = 0.165
SIZES = [(800, 360), (844, 390), (915, 412)]


def cover_paste(sky: Image.Image, canvas_w: int, canvas_h: int, ground_top: int) -> Image.Image:
    """BoxFit.cover sky into the area above the ground strip."""
    sw, sh = sky.size
    scale = max(canvas_w / sw, ground_top / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    resized = sky.resize((nw, nh), Image.Resampling.LANCZOS)
    offset_y = ground_top - nh
    canvas = Image.new("RGB", (canvas_w, canvas_h), (20, 10, 30))
    canvas.paste(resized, (0, offset_y))
    # Tile one mirrored copy if needed for width (visual seam check).
    if nw < canvas_w:
        mirrored = resized.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        canvas.paste(mirrored, (nw, offset_y))
    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    full = Image.open(SRC).convert("RGB")
    w, h = full.size
    crop_h = int(round(h * (1.0 - BAKED_GROUND_FRACTION)))
    sky = full.crop((0, 0, w, crop_h))
    print(f"source {w}x{h} -> sky crop {sky.size[0]}x{sky.size[1]}")

    for cw, ch in SIZES:
        ground_top = int(round(ch * (1.0 - GROUND_HEIGHT_RATIO)))
        frame = cover_paste(sky, cw, ch, ground_top)
        draw = ImageDraw.Draw(frame)
        # Opaque ground band (stand-in for GroundStripComponent).
        draw.rectangle((0, ground_top, cw, ch), fill=(72, 54, 38))
        # Thin highlight at the join for inspection.
        draw.line((0, ground_top, cw, ground_top), fill=(255, 220, 120), width=2)
        out = OUT_DIR / f"bg_morning_{cw}x{ch}.png"
        frame.save(out)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
