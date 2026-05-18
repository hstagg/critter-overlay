"""
preview_renderer.py — Render pygame animal walk cycles for the settings window.

Must be called after pygame.init() (i.e. after Overlay.__init__).
Returns {species: [base64_png, ...]} compatible with settings_window's
_ANIMAL_FRAMES format.

Render strategy:
  - Draw each frame onto a 2× canvas so ears/tails have room to breathe
  - Auto-crop to the actual content bounding box (ImageChops.difference vs bg)
  - Scale the crop to fit in the target square, centred on card background
  - Crop box is computed once from the neutral frame so all frames align
"""
from __future__ import annotations

import base64
import io
import math

import pygame
from PIL import Image, ImageChops

# Card background — must match CARD_BG in settings_window.py
_CARD_RGB = (30, 30, 53)
_MARGIN   = 10   # px of extra padding around the auto-cropped content


def render_all(species_list: list[str],
               size: int = 96,
               n_frames: int = 8) -> dict[str, list[str]]:
    """
    Render n_frames walk-cycle poses for each species.
    Returns {species: [base64_png_str, ...]}.
    """
    from animals import create_animal

    render_size = size * 2      # 2× canvas so nothing clips
    dummy       = render_size * 5

    result: dict[str, list[str]] = {}

    for species in species_list:
        b64_frames: list[str] = []
        try:
            animal = create_animal(
                species,
                render_size // 2, render_size // 2,
                size, dummy, dummy,
            )

            # ── Determine crop box from the neutral (frame-0) pose ──────────
            # Using a fixed crop box keeps all animation frames spatially stable.
            surf0 = pygame.Surface((render_size, render_size))
            surf0.fill(_CARD_RGB)
            animal.walk_phase = 0.0
            animal.anim_t     = 0.0
            animal.x          = render_size / 2
            animal.y          = render_size / 2
            animal.being_dragged = False
            animal.thrown        = False
            animal.draw(surf0, 0.0)

            raw0  = pygame.image.tostring(surf0, "RGB")
            pil0  = Image.frombuffer("RGB", (render_size, render_size), raw0)
            bg_im = Image.new("RGB", (render_size, render_size), _CARD_RGB)
            diff  = ImageChops.difference(pil0, bg_im)
            bbox  = diff.getbbox()

            if bbox:
                l, t, r, b = bbox
                l = max(0, l - _MARGIN)
                t = max(0, t - _MARGIN)
                r = min(render_size, r + _MARGIN)
                b = min(render_size, b + _MARGIN)
                crop_box: tuple | None = (l, t, r, b)
            else:
                crop_box = None

            # ── Render each walk-cycle frame ─────────────────────────────────
            for i in range(n_frames):
                surf = pygame.Surface((render_size, render_size))
                surf.fill(_CARD_RGB)

                phase             = i * 2 * math.pi / n_frames
                animal.walk_phase = phase
                animal.anim_t     = 0.0
                animal.x          = render_size / 2
                animal.y          = render_size / 2
                animal.draw(surf, 0.0)

                raw = pygame.image.tostring(surf, "RGB")
                pil = Image.frombuffer("RGB", (render_size, render_size), raw)

                if crop_box:
                    pil = pil.crop(crop_box)

                # Scale to fit inside size×size, centred on card background
                pil.thumbnail((size, size), Image.LANCZOS)
                out = Image.new("RGB", (size, size), _CARD_RGB)
                ox  = (size - pil.width)  // 2
                oy  = (size - pil.height) // 2
                out.paste(pil, (ox, oy))

                buf = io.BytesIO()
                out.save(buf, format="PNG")
                b64_frames.append(base64.b64encode(buf.getvalue()).decode())

        except Exception as e:
            print(f"[preview] {species}: {e}")

        if b64_frames:
            result[species] = b64_frames

    return result
