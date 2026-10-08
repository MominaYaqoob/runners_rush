#!/usr/bin/env python3
"""One-off: fill transparent fringe on background_evening.png and export RGB.

Fills transparent (and near-transparent) pixels with the nearest opaque colour
via scipy.ndimage.distance_transform_edt, crops the 6 fully-transparent rows at
top and bottom, converts to RGB. Resizes to 1024x572 only when the cropped
aspect is already within 2% of that target (avoids distorting the art).
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "images" / "background_evening.png"
TARGET_SIZE = (1024, 572)
TOP_CROP = 6
BOTTOM_CROP = 6
OPAQUE_ALPHA = 250
ASPECT_TOLERANCE = 0.02


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    arr = np.asarray(img).copy()
    h, w = arr.shape[:2]
    print(f"input: {w}x{h} mode=RGBA path={SRC}")

    alpha = arr[:, :, 3]
    opaque = alpha >= OPAQUE_ALPHA
    opaque_count = int(opaque.sum())
    print(f"opaque pixels (a>={OPAQUE_ALPHA}): {opaque_count}/{h * w}")

    if opaque_count == 0:
        raise SystemExit("No opaque pixels found — cannot fill transparency.")

    # Nearest opaque colour for every transparent/near-transparent pixel.
    _, (iy, ix) = distance_transform_edt(~opaque, return_indices=True)
    filled = arr.copy()
    filled[~opaque] = arr[iy[~opaque], ix[~opaque]]
    filled[:, :, 3] = 255

    # Crop the known fully-transparent bands (rows 0-5 and h-6..h-1).
    y0 = TOP_CROP
    y1 = h - BOTTOM_CROP
    if y1 <= y0:
        raise SystemExit("Crop removed the entire image.")
    cropped = filled[y0:y1, :, :3]
    ch, cw = cropped.shape[:2]
    print(f"after crop: {cw}x{ch}")

    out = Image.fromarray(cropped, mode="RGB")
    target_aspect = TARGET_SIZE[0] / TARGET_SIZE[1]
    current_aspect = cw / ch
    aspect_delta = abs(current_aspect - target_aspect) / target_aspect
    if aspect_delta <= ASPECT_TOLERANCE:
        out = out.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
        print(f"resized to {TARGET_SIZE[0]}x{TARGET_SIZE[1]} (aspect delta {aspect_delta:.3%})")
    else:
        print(
            f"left at {cw}x{ch} (aspect delta {aspect_delta:.3%} > "
            f"{ASPECT_TOLERANCE:.0%} — would distort if forced to {TARGET_SIZE[0]}x{TARGET_SIZE[1]})"
        )

    out.save(SRC, format="PNG", optimize=True)
    print(f"wrote {SRC} size={out.size} mode={out.mode}")


if __name__ == "__main__":
    main()
