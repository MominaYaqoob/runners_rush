from pathlib import Path

p = Path(r"d:\runners_rush\assets\images")
try:
    from PIL import Image
except ImportError:
    print("NO_PIL")
    raise SystemExit(0)

for name in ["male_run.jfif", "male_jump.jfif", "male_fall.jfif"]:
    path = p / name
    im = Image.open(path)
    print(f"{name}: format={im.format} mode={im.mode} size={im.size}")
    # Sample corners and a few interior pixels to detect baked checkerboard
    w, h = im.size
    rgb = im.convert("RGB")
    samples = [
        ("tl", rgb.getpixel((0, 0))),
        ("tr", rgb.getpixel((w - 1, 0))),
        ("bl", rgb.getpixel((0, h - 1))),
        ("br", rgb.getpixel((w - 1, h - 1))),
        ("center", rgb.getpixel((w // 2, h // 2))),
        ("near_tl_8", rgb.getpixel((8, 8))),
        ("near_tl_16", rgb.getpixel((16, 16))),
    ]
    print("  samples:", samples)
    extrema = rgb.getextrema()
    print("  extrema:", extrema)
