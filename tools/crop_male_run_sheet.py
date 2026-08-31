"""Split male_run_sheet.png into a 2x2 grid of PNG frames, keeping alpha.

If the sheet is a JPEG with a baked checkerboard (no alpha), edge-connected
gray squares are punched to transparent so Flame can composite the runner.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "assets" / "images"
SHEET = IMAGES / "male_run_sheet.png"

FRAMES = (
    ("male_run_1.png", 0, 0),  # top-left
    ("male_run_2.png", 1, 0),  # top-right
    ("male_run_3.png", 0, 1),  # bottom-left
    ("male_run_4.png", 1, 1),  # bottom-right
)


def _is_checker(r: int, g: int, b: int, a: int) -> bool:
    if a == 0:
        return True
    chroma = max(r, g, b) - min(r, g, b)
    avg = (r + g + b) // 3
    return chroma <= 45 and 52 <= avg <= 230


def punch_checkerboard(image: Image.Image) -> Image.Image:
    """Clear edge-connected checkerboard pixels; keep interior sprite pixels."""
    img = image.convert("RGBA")
    width, height = img.size
    px = img.load()
    marked = [False] * (width * height)

    def at(x: int, y: int) -> tuple[int, int, int, int]:
        return px[x, y]

    for y in range(height):
        for x in range(width):
            r, g, b, a = at(x, y)
            if _is_checker(r, g, b, a):
                marked[y * width + x] = True

    kill = [False] * (width * height)
    queue: deque[int] = deque()

    def try_push(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= width or y >= height:
            return
        idx = y * width + x
        if not marked[idx] or kill[idx]:
            return
        kill[idx] = True
        queue.append(idx)

    for x in range(width):
        try_push(x, 0)
        try_push(x, height - 1)
    for y in range(height):
        try_push(0, y)
        try_push(width - 1, y)

    while queue:
        idx = queue.popleft()
        x, y = idx % width, idx // width
        try_push(x - 1, y)
        try_push(x + 1, y)
        try_push(x, y - 1)
        try_push(x, y + 1)
        try_push(x - 1, y - 1)
        try_push(x + 1, y - 1)
        try_push(x - 1, y + 1)
        try_push(x + 1, y + 1)

    for y in range(height):
        for x in range(width):
            if kill[y * width + x]:
                px[x, y] = (0, 0, 0, 0)

    return img


def crop_sheet(sheet_path: Path = SHEET) -> list[Path]:
    if not sheet_path.exists():
        raise FileNotFoundError(f"Sprite sheet not found: {sheet_path}")

    image = Image.open(sheet_path).convert("RGBA")
    extrema = image.getextrema()
    has_alpha = len(extrema) == 4 and extrema[3][0] < 255
    width, height = image.size
    cell_w, cell_h = width // 2, height // 2
    saved: list[Path] = []

    for name, col, row in FRAMES:
        left = col * cell_w
        top = row * cell_h
        frame = image.crop((left, top, left + cell_w, top + cell_h))
        if not has_alpha:
            frame = punch_checkerboard(frame)
        out_path = IMAGES / name
        frame.save(out_path, format="PNG")
        saved.append(out_path)
        print(
            f"saved {out_path.name}  {frame.size[0]}x{frame.size[1]}  "
            f"mode={frame.mode}"
        )

    return saved


if __name__ == "__main__":
    crop_sheet()
