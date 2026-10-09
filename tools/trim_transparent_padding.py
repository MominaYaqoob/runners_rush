"""Trim transparent padding from hero/portrait PNGs (keep ~8px margin).

Overwrites:
  assets/images/home_male_hero.png
  assets/images/home_female_hero.png
  assets/images/shop_male_portrait.png
  assets/images/shop_female_portrait.png
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "assets" / "images"
MARGIN = 8
TARGETS = [
    "home_male_hero.png",
    "home_female_hero.png",
    "shop_male_portrait.png",
    "shop_female_portrait.png",
]


def trim(path: Path, margin: int = MARGIN) -> None:
    im = Image.open(path).convert("RGBA")
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        print(f"skip empty: {path.name}")
        return
    left, top, right, bottom = bbox
    left = max(0, left - margin)
    top = max(0, top - margin)
    right = min(im.width, right + margin)
    bottom = min(im.height, bottom + margin)
    cropped = im.crop((left, top, right, bottom))
    before = path.stat().st_size
    cropped.save(path, optimize=True)
    after = path.stat().st_size
    print(
        f"{path.name}: {im.size[0]}x{im.size[1]} -> "
        f"{cropped.size[0]}x{cropped.size[1]}  "
        f"({before:,} -> {after:,} bytes)"
    )


def main() -> None:
    for name in TARGETS:
        path = IMAGES / name
        if not path.exists():
            print(f"missing: {name}")
            continue
        trim(path)


if __name__ == "__main__":
    main()
