"""
preview_renderer.py — Render pygame animal walk cycles for the settings window.

Must be called after pygame.init() (i.e. after Overlay.__init__).
Returns {species: [base64_png, ...]} compatible with settings_window's
_ANIMAL_FRAMES format.
"""
from __future__ import annotations

import base64
import io
import math

import pygame
from PIL import Image

# Card background — must match CARD_BG in settings_window.py
_CARD_RGB = (30, 30, 53)


def render_all(species_list: list[str],
               size: int = 96,
               n_frames: int = 8) -> dict[str, list[str]]:
    """
    Render n_frames walk-cycle poses for each species.
    The animal is drawn centred on a (size×size) card-coloured surface.
    Returns {species: [base64_png_str, ...]}.
    """
    from animals import create_animal

    dummy = size * 10
    result: dict[str, list[str]] = {}

    for species in species_list:
        b64_frames: list[str] = []
        try:
            animal = create_animal(species, size // 2, size // 2,
                                   size, dummy, dummy)
            for i in range(n_frames):
                surf = pygame.Surface((size, size))
                surf.fill(_CARD_RGB)

                phase = i * 2 * math.pi / n_frames
                animal.walk_phase = phase
                animal.anim_t     = 0.0   # keep blink suppressed
                animal.x          = size / 2
                animal.y          = size / 2
                animal.being_dragged = False
                animal.thrown        = False

                animal.draw(surf, 0.0)

                raw = pygame.image.tostring(surf, "RGB")
                pil = Image.frombuffer("RGB", (size, size), raw)

                buf = io.BytesIO()
                pil.save(buf, format="PNG")
                b64_frames.append(base64.b64encode(buf.getvalue()).decode())

        except Exception as e:
            print(f"[preview] {species}: {e}")

        if b64_frames:
            result[species] = b64_frames

    return result
