"""
procedural.py — Generate a 4-frame walk-cycle from a single static RGBA image.

Frame transforms (applied to a canonical-size RGBA image):
  0 — neutral (no transform)
  1 — squash + lean forward  (scale x=1.03 y=0.95, rotate -2°, shift y+2)
  2 — stretch + rise          (scale x=0.97 y=1.05, rotate  0°, shift y-3)
  3 — squash + lean back      (scale x=1.03 y=0.95, rotate +2°, shift y+2)

All ops use Pillow so no additional deps are needed.
Output: list of 4 RGBA PIL Images at the same dimensions as the input.
"""

from __future__ import annotations

from PIL import Image


# (scale_x, scale_y, rotate_deg, translate_y)
_FRAME_PARAMS = [
    (1.00,  1.00,  0.0,  0),
    (1.03,  0.95, -2.0, +2),
    (0.97,  1.05,  0.0, -3),
    (1.03,  0.95, +2.0, +2),
]


def generate_frames(source: Image.Image) -> list[Image.Image]:
    """
    Return 4 RGBA frames from a single RGBA source image.
    The source must already be cropped/fitted to the canonical canvas size.
    """
    if source.mode != "RGBA":
        source = source.convert("RGBA")

    w, h = source.size
    frames = []

    for sx, sy, angle, ty in _FRAME_PARAMS:
        frame = _transform_frame(source, w, h, sx, sy, angle, ty)
        frames.append(frame)

    return frames


def _transform_frame(src: Image.Image, w: int, h: int,
                     sx: float, sy: float,
                     angle: float, ty: int) -> Image.Image:
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # Scale
    new_w = max(1, int(w * sx))
    new_h = max(1, int(h * sy))
    scaled = src.resize((new_w, new_h), Image.LANCZOS)

    # Rotate (in-place, expand=False keeps the canvas size stable)
    if angle != 0.0:
        scaled = scaled.rotate(angle, resample=Image.BICUBIC, expand=False)

    # Centre + translate
    paste_x = (w - new_w) // 2
    paste_y = (h - new_h) // 2 + ty

    canvas.paste(scaled, (paste_x, paste_y), scaled)
    return canvas
