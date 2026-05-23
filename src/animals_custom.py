"""
animals_custom.py — CustomAnimal class for user-imported critters.

Inherits all movement, physics, drag/throw, idle, and pop logic from Animal.
Overrides only draw(), hit_test(), and emit_trail().

Frames are stored facing right. When direction == -1 (left), the surface
is flipped horizontally for rendering and the mask lookup mirrors x.
"""

from __future__ import annotations

import math

import numpy as np
import pygame

from animals import Animal
from constants import TRAIL_PRESETS
from custom_critters.registry import CustomCritterRecord


class CustomAnimal(Animal):
    SPECIES    = "custom"
    BASE_SPEED = 50
    LEAVES_TRAIL = False

    # Populated per-instance from metadata
    TRAIL_PALETTE: tuple = ()
    TRAIL_RATE    = 0
    TRAIL_SIZE    = 4
    TRAIL_LIFE    = 0.6
    TRAIL_STAR    = False

    def __init__(self, x: float, y: float, size: int,
                 screen_w: int, screen_h: int,
                 record: CustomCritterRecord,
                 direction: int | None = None,
                 perimeter_walker: bool = False):

        self._record      = record
        self.frames       = record.frames    # list[pygame.Surface] — canonical size
        self.masks        = record.masks     # list[np.ndarray] — bool, dilated
        self.meta         = record.meta

        # Override SPECIES so sounds.py and settings can address this critter
        self.SPECIES = f"custom:{record.id}"

        # Particle colours from trail_palette (or neutral grey)
        palette_hex = self.meta.get("trail_palette") or []
        self.PARTICLE_COLORS = [self._hex_to_rgb(c) for c in palette_hex] or [(200, 200, 200)]

        # Per-critter personality (v1.9) — applied before super().__init__ so
        # the base class reads the overridden BASE_SPEED when computing initial vx/vy
        speed_mult = float(self.meta.get("speed_multiplier", 1.0))
        self.BASE_SPEED = max(1, int(CustomAnimal.BASE_SPEED * speed_mult))

        size_mult = float(self.meta.get("size_multiplier", 1.0))
        size = max(30, int(size * size_mult))

        super().__init__(x, y, size, screen_w, screen_h,
                         direction=direction, perimeter_walker=perimeter_walker)

        # Instance-level overrides set after super().__init__
        self.IDLE_RATE    = float(self.meta.get("idle_rate", 0.018))
        self.loco_profile = self.meta.get("locomotion", "classic")

        trail_style = self.meta.get("trail_style", "none")
        if trail_style != "none" and self.PARTICLE_COLORS:
            self.LEAVES_TRAIL  = True
            self.TRAIL_PALETTE = self.PARTICLE_COLORS
            particle_style, rate, size, life = TRAIL_PRESETS.get(trail_style, ("dot", 15, 6, 0.9))
            self.TRAIL_STYLE = particle_style
            self.TRAIL_RATE  = rate
            self.TRAIL_SIZE  = size
            self.TRAIL_LIFE  = life

        self._frame_count = len(self.frames)
        # Cache: (frame_idx, size, flip) -> pygame.Surface
        self._scale_cache: dict[tuple, pygame.Surface] = {}

    # ------------------------------------------------------------------
    # Draw
    # ------------------------------------------------------------------

    def draw(self, surface: pygame.Surface, anim_t: float) -> None:
        if not self.frames:
            return

        idx   = self._frame_idx()
        flip  = (self.direction == -1)
        sprite = self._get_scaled(idx, flip)

        bob = int(self._bob())
        rect = sprite.get_rect(center=(int(self.x + self._loco_x_offset), int(self.y) + bob))
        surface.blit(sprite, rect)

    def _get_scaled(self, idx: int, flip: bool) -> pygame.Surface:
        key = (idx, self.size, flip)
        if key not in self._scale_cache:
            base    = self.frames[idx]
            scaled  = pygame.transform.smoothscale(base, (self.size, self.size))
            if flip:
                scaled = pygame.transform.flip(scaled, True, False)
            self._scale_cache[key] = scaled
        return self._scale_cache[key]

    def clear_cache(self) -> None:
        self._scale_cache.clear()

    def _frame_idx(self) -> int:
        if self._frame_count <= 1:
            return 0
        return int(self.walk_phase * self._frame_count / (2 * math.pi)) % self._frame_count

    # ------------------------------------------------------------------
    # Hit detection — per-pixel alpha mask
    # ------------------------------------------------------------------

    def hit_test(self, mx: int, my: int) -> bool:
        half = self.size / 2

        # Fast bounding-box reject
        if not (self.x - half <= mx <= self.x + half and
                self.y - half <= my <= self.y + half):
            return False

        if not self.masks:
            # Fallback: circle
            return math.hypot(mx - self.x, my - self.y) <= self.hit_radius

        idx  = self._frame_idx()
        mask = self.masks[idx] if idx < len(self.masks) else self.masks[0]
        mh, mw = mask.shape

        local_x = (mx - (self.x - half)) * (mw / self.size)
        local_y = (my - (self.y - half)) * (mh / self.size)

        if self.direction == -1:  # flipped
            local_x = mw - 1 - local_x

        ix, iy = int(local_x), int(local_y)
        if 0 <= ix < mw and 0 <= iy < mh:
            return bool(mask[iy, ix])
        return False

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
        s = hex_str.lstrip("#")
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
