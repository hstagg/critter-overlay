"""
auras.py — Aura render functions for rarity tiers.

Auras are drawn before the sprite so the critter floats on top.
No alpha compositing — the overlay uses chroma-key transparency, so every
pixel is either fully visible or fully transparent (magenta). Glow effects
are approximated with concentric outline circles and dot rings.
"""

import math
import pygame

from rarity import RarityTier


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def draw_aura(surface: pygame.Surface, x: int, y: int,
              size: int, tier: RarityTier, anim_t: float) -> None:
    """Draw the aura for the given tier. No-op for COMMON."""
    _STYLE_FNS = {
        RarityTier.UNCOMMON:  _soft_glow,
        RarityTier.RARE:      _bright_glow,
        RarityTier.EPIC:      _shimmer,
        RarityTier.LEGENDARY: _rainbow_pulse,
    }
    fn = _STYLE_FNS.get(tier)
    if fn:
        fn(surface, x, y, size, anim_t)


# ---------------------------------------------------------------------------
# Aura styles
# ---------------------------------------------------------------------------

def _soft_glow(surface: pygame.Surface, x: int, y: int,
               size: int, anim_t: float) -> None:
    """Subtle cool-white halo for Uncommon. Three concentric thin rings."""
    base_r = int(size * 0.52)
    pulse  = int(3 * math.sin(anim_t * 2.0))
    color  = (200, 210, 255)
    for i in range(3):
        r = base_r + pulse + i * 3
        if r > 0:
            pygame.draw.circle(surface, color, (x, y), r, 1)


def _bright_glow(surface: pygame.Surface, x: int, y: int,
                 size: int, anim_t: float) -> None:
    """Warm pulsing halo for Rare. Three concentric rings, warm-gold palette."""
    base_r = int(size * 0.54)
    pulse  = int(5 * math.sin(anim_t * 3.0))
    colors = [(255, 255, 180), (255, 230, 130), (240, 200, 80)]
    for i, color in enumerate(colors):
        r = base_r + pulse + i * 4
        if r > 0:
            pygame.draw.circle(surface, color, (x, y), r, max(1, 2 - i))


def _shimmer(surface: pygame.Surface, x: int, y: int,
             size: int, anim_t: float) -> None:
    """Rotating dot-ring for Epic. 12 marks alternating cool/warm/violet."""
    base_r = int(size * 0.56)
    n      = 12
    rot    = anim_t * 0.8
    palette = [
        (180, 220, 255),   # cool blue
        (255, 220, 180),   # warm gold
        (220, 180, 255),   # violet
    ]
    for i in range(n):
        angle = (2 * math.pi * i / n) + rot
        px = int(x + base_r * math.cos(angle))
        py = int(y + base_r * math.sin(angle))
        color = palette[i % 3]
        r = 3 if i % 2 == 0 else 2
        pygame.draw.circle(surface, color, (px, py), r)


def _rainbow_pulse(surface: pygame.Surface, x: int, y: int,
                   size: int, anim_t: float) -> None:
    """Full rainbow rotating halo for Legendary. Outer + inner dot rings."""
    base_r = int(size * 0.58)
    n      = 24
    rot    = anim_t * 1.5

    # Outer ring
    for i in range(n):
        angle = (2 * math.pi * i / n) + rot
        hue   = (i / n + anim_t * 0.3) % 1.0
        color = _hsv_to_rgb(hue, 1.0, 1.0)
        px = int(x + base_r * math.cos(angle))
        py = int(y + base_r * math.sin(angle))
        pygame.draw.circle(surface, color, (px, py), 4)

    # Inner ring, phase-offset
    inner_r = base_r - 6
    for i in range(n // 2):
        angle = (2 * math.pi * i / (n // 2)) + rot + (math.pi / n)
        hue   = (i / (n // 2) + anim_t * 0.3 + 0.5) % 1.0
        color = _hsv_to_rgb(hue, 0.8, 1.0)
        px = int(x + inner_r * math.cos(angle))
        py = int(y + inner_r * math.sin(angle))
        pygame.draw.circle(surface, color, (px, py), 2)


# ---------------------------------------------------------------------------
# Colour helper
# ---------------------------------------------------------------------------

def _hsv_to_rgb(h: float, s: float, v: float) -> tuple[int, int, int]:
    """HSV (0–1 each) → RGB (0–255 each). Never returns chroma-key magenta."""
    if s == 0.0:
        val = int(v * 255)
        return (val, val, val)
    i = int(h * 6) % 6
    f = h * 6 - int(h * 6)
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    r, g, b = (
        (v, t, p), (q, v, p), (p, v, t),
        (p, q, v), (t, p, v), (v, p, q),
    )[i]
    rgb = (int(r * 255), int(g * 255), int(b * 255))
    # Guard against exact chroma-key colour (255, 0, 255)
    if rgb == (255, 0, 255):
        rgb = (255, 1, 255)
    return rgb
