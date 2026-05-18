"""
bg_removal.py — Simple corner-based background removal for JPG/opaque images.

Samples the four corner pixels, picks the most common colour as the background,
then flood-fills from all four corners with a colour tolerance. Pixels inside
the fill become transparent; everything else is kept.

Works well for clean studio photos or flat-colour backgrounds.
Fails for complex or gradient backgrounds — in those cases the UI asks the
user to try a transparent PNG instead.
"""

from __future__ import annotations

from collections import deque

from PIL import Image


def remove_background(img: Image.Image, tolerance: int = 30) -> Image.Image:
    """
    Return an RGBA image with the background made transparent.
    tolerance: per-channel distance threshold for flood fill.
    """
    rgb = img.convert("RGB")
    w, h = rgb.size
    pixels = rgb.load()

    # Sample corners
    corners = [
        pixels[0, 0],
        pixels[w - 1, 0],
        pixels[0, h - 1],
        pixels[w - 1, h - 1],
    ]
    bg_colour = _most_common(corners)

    # Flood fill from all four corners
    filled = _flood_fill(pixels, w, h, bg_colour, tolerance)

    # Build RGBA output
    rgba = img.convert("RGBA")
    data = rgba.load()
    for y in range(h):
        for x in range(w):
            if filled[y * w + x]:
                r, g, b, _ = data[x, y]
                data[x, y] = (r, g, b, 0)

    return rgba


def _most_common(colours: list[tuple]) -> tuple:
    counts: dict[tuple, int] = {}
    for c in colours:
        counts[c] = counts.get(c, 0) + 1
    return max(counts, key=counts.get)


def _colour_distance(a: tuple, b: tuple) -> int:
    return max(abs(a[i] - b[i]) for i in range(3))


def _flood_fill(pixels, w: int, h: int,
                bg: tuple, tolerance: int) -> list[bool]:
    filled = [False] * (w * h)
    queue: deque[tuple[int, int]] = deque()

    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for sx, sy in seeds:
        idx = sy * w + sx
        if not filled[idx] and _colour_distance(pixels[sx, sy], bg) <= tolerance:
            filled[idx] = True
            queue.append((sx, sy))

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                idx = ny * w + nx
                if not filled[idx] and _colour_distance(pixels[nx, ny], bg) <= tolerance:
                    filled[idx] = True
                    queue.append((nx, ny))

    return filled
