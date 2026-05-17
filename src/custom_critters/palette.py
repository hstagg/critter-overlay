"""
palette.py — Dominant-colour extraction for custom critter frames.

Uses Pillow's quantise to reduce to 8 colours, then filters out
near-greys (low saturation) and returns the top N by pixel count
as hex strings. These are stored in meta.json for future trail use.
"""

from __future__ import annotations

import colorsys

from PIL import Image


def _rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"


def _is_grey(r: int, g: int, b: int, threshold: float = 0.15) -> bool:
    """Return True if the colour has low saturation (near-grey)."""
    _, s, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s < threshold


def extract_palette(img: Image.Image, n: int = 2) -> list[str]:
    """
    Return up to n dominant non-grey colours from an RGBA image as hex strings.
    Falls back to grey colours if not enough colourful ones exist.
    """
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    # Filter to only opaque-ish pixels
    pixels = list(img.getdata())
    rgb_pixels = [(r, g, b) for r, g, b, a in pixels if a > 128]
    if not rgb_pixels:
        return ["#cccccc"]

    # Build a small RGB image from opaque pixels for quantisation
    w = max(1, len(rgb_pixels))
    flat = Image.new("RGB", (w, 1))
    flat.putdata(rgb_pixels)

    # Quantise to 8 colours
    try:
        quantised = flat.quantize(colors=8, method=Image.Quantize.MEDIANCUT)
        palette_raw = quantised.getpalette()       # flat [R,G,B, R,G,B, ...]
        counts = {}
        for idx in quantised.getdata():
            counts[idx] = counts.get(idx, 0) + 1
    except Exception:
        return ["#cccccc"]

    # Build sorted list of (count, R, G, B)
    colour_counts = []
    for idx, count in counts.items():
        r = palette_raw[idx * 3]
        g = palette_raw[idx * 3 + 1]
        b = palette_raw[idx * 3 + 2]
        colour_counts.append((count, r, g, b))
    colour_counts.sort(reverse=True)

    colourful = [
        _rgb_to_hex(r, g, b)
        for _, r, g, b in colour_counts
        if not _is_grey(r, g, b)
    ]

    if len(colourful) >= n:
        return colourful[:n]

    # Pad with grey colours if needed
    greys = [
        _rgb_to_hex(r, g, b)
        for _, r, g, b in colour_counts
        if _is_grey(r, g, b)
    ]
    return (colourful + greys)[:n] or ["#cccccc"]
