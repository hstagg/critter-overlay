"""
masks.py — Alpha-mask generation for custom critter frames.

For each RGBA frame:
  1. Extract alpha channel as uint8
  2. Threshold at > 32
  3. Dilate by 2 pixels (numpy-only, no scipy)
  4. Save as .npy

The dilated mask gives a slightly forgiving click target without
any runtime cost — lookup is a single array index.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


def _dilate(mask: np.ndarray, iterations: int = 2) -> np.ndarray:
    """2D boolean dilation using axis-aligned shifts. No scipy required."""
    out = mask.copy()
    for _ in range(iterations):
        out = (
            out
            | np.roll(out,  1, axis=0)
            | np.roll(out, -1, axis=0)
            | np.roll(out,  1, axis=1)
            | np.roll(out, -1, axis=1)
        )
    return out


def generate_mask(frame: Image.Image) -> np.ndarray:
    """Return a dilated boolean mask from an RGBA PIL Image."""
    if frame.mode != "RGBA":
        frame = frame.convert("RGBA")
    alpha = np.array(frame)[:, :, 3]   # uint8
    mask = alpha > 32
    return _dilate(mask)


def save_mask(mask: np.ndarray, path: Path) -> None:
    np.save(str(path), mask)


def load_mask(path: Path) -> np.ndarray | None:
    try:
        return np.load(str(path))
    except Exception as e:
        print(f"[masks] Failed to load {path}: {e}")
        return None


def generate_and_save_masks(frames: list[Image.Image], masks_dir: Path) -> list[np.ndarray]:
    """Generate, save, and return masks for a list of PIL frames."""
    masks_dir.mkdir(parents=True, exist_ok=True)
    result = []
    for i, frame in enumerate(frames):
        mask = generate_mask(frame)
        save_mask(mask, masks_dir / f"mask_{i}.npy")
        result.append(mask)
    return result
