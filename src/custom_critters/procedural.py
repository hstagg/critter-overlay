"""
procedural.py — Split-image walk-cycle generator for custom critter sprites.

Splits the sprite at the waist (~58% down) and applies per-frame:
  - Whole body : vertical bob  +  rotational lean
  - Bottom half: horizontal shear that grows toward the feet,
                 blended seamlessly at the join line

4-frame cycle (phase = i × π/2):

  Frame   bob   lean    stride-shear
    0      0    right      right
    1     up      –          –
    2      0    left       left
    3     up      –          –

The shear uses PIL's AFFINE inverse mapping so the join line is always
pixel-perfect: at dest_y=0 (waist) shift=0, at dest_y=bh (feet) shift≈±10px.
A power-curve gradient blends the stride layer in so there is no hard seam.
"""

from __future__ import annotations

import math

import numpy as np
from PIL import Image

SPLIT_FRAC = 0.58   # waist as fraction of total height
BOB_AMP    = 4      # px; body rises this many pixels mid-stride
LEAN_AMP   = 5.0    # degrees; body leans into the stride direction
STRIDE_K   = 0.20   # shear coefficient; max foot offset ≈ STRIDE_K × leg_height


def generate_frames(source: Image.Image, n_frames: int = 4) -> list[Image.Image]:
    """Return n_frames RGBA walk-cycle frames from a single RGBA source image."""
    if source.mode != "RGBA":
        source = source.convert("RGBA")

    w, h   = source.size
    split_y = max(4, int(h * SPLIT_FRAC))

    frames = []
    for i in range(n_frames):
        phase  = 2 * math.pi * i / n_frames
        bob    = -round(abs(math.sin(phase)) * BOB_AMP)   # 0,-4,0,-4  (negative = up)
        lean   = math.cos(phase) * LEAN_AMP               # +5,0,-5,0  degrees
        stride = math.cos(phase) * STRIDE_K               # +k,0,-k,0
        frames.append(_build_frame(source, w, h, split_y, bob, lean, stride))

    return frames


# ---------------------------------------------------------------------------
# Frame composition
# ---------------------------------------------------------------------------

def _build_frame(source: Image.Image, w: int, h: int,
                 split_y: int, bob: int,
                 lean: float, stride: float) -> Image.Image:

    # ── 1. Lean the whole body ───────────────────────────────────────────────
    # PIL rotate: positive angle = CCW.  lean>0 (right) needs CW = negative PIL angle.
    leaned = (source.rotate(-lean, center=(w // 2, h // 2),
                            resample=Image.BICUBIC, expand=False)
              if lean != 0.0 else source.copy())

    # ── 2. Bob — paste leaned body onto canvas with vertical offset ──────────
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(leaned, (0, bob), leaned)

    # ── 3. Stride shear on the bottom section ────────────────────────────────
    if abs(stride) > 0.005:
        bh = h - split_y
        if bh < 2:
            return canvas

        bottom = leaned.crop((0, split_y, w, h))

        # AFFINE inverse mapping: src_x = 1·dest_x + stride·dest_y + 0
        #                         src_y = 0·dest_x + 1·dest_y    + 0
        # → at dest_y=0  (join): zero shift          (seamless with body above)
        # → at dest_y=bh (feet): stride×bh px shift  (maximum leg spread)
        sheared = bottom.transform(
            (w, bh), Image.AFFINE,
            (1, stride, 0,   0, 1, 0),
            resample=Image.BICUBIC,
        )

        # Power-curve gradient: 0 at waist → 1 at feet (kicks in quickly)
        t    = np.arange(bh, dtype=np.float32) / max(bh - 1, 1)
        grad = (t ** 0.6)[:, np.newaxis]           # shape (bh, 1)

        sheared_arr          = np.array(sheared, dtype=np.float32)   # (bh, w, 4)
        sheared_arr[:, :, 3] = sheared_arr[:, :, 3] * grad           # fade in by gradient

        # Paste position tracks the bob so waist stays joined
        paste_y  = max(0, min(h - 1, split_y + bob))
        region_h = min(bh, h - paste_y)

        if region_h > 0:
            canvas_arr = np.array(canvas, dtype=np.float32)
            src = sheared_arr[:region_h]                 # (region_h, w, 4)
            dst = canvas_arr[paste_y: paste_y + region_h]

            # Standard Porter-Duff source-over composite
            sa     = src[:, :, 3:4] / 255.0
            da     = dst[:, :, 3:4] / 255.0
            oa     = sa + da * (1.0 - sa)
            safe   = np.where(oa > 0, oa, 1.0)
            oc     = (src[:, :, :3] * sa + dst[:, :, :3] * da * (1.0 - sa)) / safe

            canvas_arr[paste_y: paste_y + region_h, :, :3] = np.clip(oc,        0, 255)
            canvas_arr[paste_y: paste_y + region_h, :,  3] = np.clip(oa[:, :, 0] * 255, 0, 255)
            canvas = Image.fromarray(canvas_arr.astype(np.uint8), "RGBA")

    return canvas
