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
    """Uncommon: scattered faint dots that twinkle independently.
    Fixed positions, irregular spacing, each dot blinks at its own rate."""
    base_r = int(size * 0.52)
    color  = (215, 225, 255)

    # (angle_rad, radius_offset, dot_radius, blink_phase, blink_speed)
    # Angles are irregular so it never reads as a perfect ring.
    # (angle_rad, radius_offset, dot_radius, blink_phase, blink_speed, colour)
    _DOTS = [
        (0.00,  0,  1, 0.0,  3.2, (210, 225, 255)),  # cool white
        (0.55, -3,  2, 1.7,  2.7, (255, 225, 200)),  # warm peach
        (1.20,  2,  1, 3.1,  3.8, (210, 225, 255)),
        (1.85, -2,  1, 0.8,  2.5, (225, 210, 255)),  # soft violet
        (2.50,  3,  2, 2.4,  3.5, (210, 225, 255)),
        (3.00, -4,  1, 1.2,  4.0, (255, 225, 200)),
        (3.70,  1,  1, 3.8,  2.9, (225, 210, 255)),
        (4.30, -1,  1, 0.5,  3.3, (210, 225, 255)),
        (4.90,  3,  2, 2.1,  2.6, (255, 225, 200)),
        (5.40, -2,  1, 1.5,  3.7, (210, 225, 255)),
        (5.90,  2,  1, 3.5,  3.1, (225, 210, 255)),
        (0.30, -3,  1, 2.8,  2.8, (210, 225, 255)),
    ]

    for angle, r_off, dot_r, phase, speed, col in _DOTS:
        if math.sin(anim_t * speed + phase) > 0:
            r  = base_r + r_off
            px = int(x + r * math.cos(angle))
            py = int(y + r * math.sin(angle))
            pygame.draw.circle(surface, col, (px, py), dot_r)


def _bright_glow(surface: pygame.Surface, x: int, y: int,
                 size: int, anim_t: float) -> None:
    """Rare: gold cross-sparkles mixed with plain dots, all independently blinking.
    Cross shapes read as sparkles rather than circles — clearly above Uncommon."""
    base_r = int(size * 0.54)

    # Cross-sparkles: (angle_rad, r_off, arm_len, blink_phase, blink_speed, colour)
    _CROSSES = [
        (0.30,  0,  2, 0.0,  2.8, (255, 235, 140)),
        (1.80, -3,  2, 2.1,  3.4, (255, 210, 90)),
        (3.20,  2,  2, 1.0,  2.5, (255, 235, 140)),
        (4.70, -2,  2, 3.3,  3.1, (255, 210, 90)),
        (5.50,  3,  2, 1.7,  2.9, (255, 235, 140)),
    ]

    # Plain dots: (angle_rad, r_off, dot_r, blink_phase, blink_speed, colour)
    _DOTS = [
        (0.90,  2,  1, 1.4,  3.6, (255, 200, 80)),
        (2.50, -4,  2, 0.5,  2.7, (255, 240, 160)),
        (3.80,  3,  1, 2.8,  3.9, (255, 200, 80)),
        (5.00, -1,  1, 0.2,  2.4, (255, 240, 160)),
        (1.20,  1,  2, 3.1,  3.2, (255, 220, 110)),
        (4.20, -3,  1, 1.9,  2.6, (255, 200, 80)),
    ]

    # Occasional shooting stars — fire outward in a randomised direction each cycle
    # (period, duration, phase_offset, colour)
    _STARS = [
        (2.5, 0.30, 0.0,  (255, 245, 180)),
        (3.2, 0.25, 1.1,  (255, 230, 130)),
        (2.8, 0.30, 2.4,  (255, 245, 180)),
        (3.5, 0.25, 0.7,  (255, 230, 130)),
    ]
    # Golden angle step — spreads successive firing directions evenly around the circle
    _GOLDEN = 2.3999632  # radians ≈ 137.5°
    for period, dur, offset, col in _STARS:
        t_cycle = (anim_t + offset) % period
        if t_cycle < dur:
            cycle    = int((anim_t + offset) / period)
            angle    = (cycle * _GOLDEN) % (2 * math.pi)
            progress = t_cycle / dur
            head_r   = base_r + int(progress * 14)
            tail_r   = max(base_r - 2, head_r - 6)
            hx = int(x + head_r * math.cos(angle))
            hy = int(y + head_r * math.sin(angle))
            tx = int(x + tail_r * math.cos(angle))
            ty = int(y + tail_r * math.sin(angle))
            pygame.draw.line(surface, col, (tx, ty), (hx, hy), 1)

    for angle, r_off, arm, phase, speed, col in _CROSSES:
        if math.sin(anim_t * speed + phase) > 0:
            r  = base_r + r_off
            px = int(x + r * math.cos(angle))
            py = int(y + r * math.sin(angle))
            pygame.draw.line(surface, col, (px - arm, py), (px + arm, py), 1)
            pygame.draw.line(surface, col, (px, py - arm), (px, py + arm), 1)

    for angle, r_off, dot_r, phase, speed, col in _DOTS:
        if math.sin(anim_t * speed + phase) > 0:
            r  = base_r + r_off
            px = int(x + r * math.cos(angle))
            py = int(y + r * math.sin(angle))
            pygame.draw.circle(surface, col, (px, py), dot_r)


def _shimmer(surface: pygame.Surface, x: int, y: int,
             size: int, anim_t: float) -> None:
    """Epic: breathing halo + 12 orbiting tricolor dots + a comet that laps them."""
    base_r = int(size * 0.56)

    # Breathing base halo
    halo_r = base_r + int(2 * math.sin(anim_t * 1.2))
    if halo_r > 0:
        pygame.draw.circle(surface, (160, 200, 255), (x, y), halo_r, 1)

    # Orbiting dot ring
    n   = 12
    rot = anim_t * 0.8
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
        dot_r = 3 if i % 2 == 0 else 2
        pygame.draw.circle(surface, color, (px, py), dot_r)

    # Three comets 120° apart, each with its oscillation phase offset by 120° so
    # they take turns swinging in/out — three-way helix weave.
    _OB_SPEED = 2.2
    _OSC_FREQ = 4.4
    _OSC_AMP  = 3
    _BASE_CR  = base_r + 6
    _LAG_T    = [0.18, 0.32, 0.44]
    _TRAIL_SZ = [2, 1, 1]

    # (orbit phase, oscillation phase, head colour, trail colours)
    _COMETS = [
        (0.0,              0.0,              (235, 220, 255), [(175, 150, 220), (110, 90, 155), (60, 45, 95)]),
        (2 * math.pi / 3,  2 * math.pi / 3, (255, 210, 190), [(200, 150, 130), (135, 95,  80), (75, 50, 42)]),
        (4 * math.pi / 3,  4 * math.pi / 3, (190, 240, 255), [(130, 185, 210), ( 80, 125, 150), (45, 70, 90)]),
    ]

    for orb_phase, osc_phase, head_col, trail_cols in _COMETS:
        a = anim_t * _OB_SPEED + orb_phase
        r = _BASE_CR + _OSC_AMP * math.sin(anim_t * _OSC_FREQ + osc_phase)
        pygame.draw.circle(surface, head_col,
                           (int(x + r * math.cos(a)), int(y + r * math.sin(a))), 3)
        for lag, tsz, tcol in zip(_LAG_T, _TRAIL_SZ, trail_cols):
            pt = anim_t - lag
            pa = pt * _OB_SPEED + orb_phase
            pr = _BASE_CR + _OSC_AMP * math.sin(pt * _OSC_FREQ + osc_phase)
            pygame.draw.circle(surface, tcol,
                               (int(x + pr * math.cos(pa)), int(y + pr * math.sin(pa))), tsz)


def _rainbow_pulse(surface: pygame.Surface, x: int, y: int,
                   size: int, anim_t: float) -> None:
    """Legendary: jewel gems + slow halo + rainbow comets + stately ripple pulse."""
    base_r = int(size * 0.58)

    # 1. Slow rainbow halo — single dot-ring, gently breathing, quiet foundation
    halo_r   = base_r - 4 + int(2 * math.sin(anim_t * 0.7))
    halo_rot = anim_t * 0.25
    for i in range(36):
        angle = (2 * math.pi * i / 36) + halo_rot
        hue   = (i / 36 + anim_t * 0.08) % 1.0
        col   = _hsv_to_rgb(hue, 0.55, 0.9)
        pygame.draw.circle(surface, col,
                           (int(x + halo_r * math.cos(angle)),
                            int(y + halo_r * math.sin(angle))), 1)

    # 2. Jewel gems — 8 chosen colours orbiting slowly, each with a small
    #    blinking sparkle cross nearby that rewards a closer look
    _GEMS = [
        (220,  55,  80),  # ruby
        ( 60, 110, 230),  # sapphire
        ( 50, 185, 100),  # emerald
        (180,  80, 220),  # amethyst
        (225, 175,  40),  # topaz
        ( 40, 200, 180),  # teal
        (240, 120, 160),  # rose
        (170, 215, 255),  # ice
    ]
    gem_r   = base_r + 9
    gem_rot = anim_t * 0.55
    for i, gem_col in enumerate(_GEMS):
        angle = (2 * math.pi * i / len(_GEMS)) + gem_rot
        gx = int(x + gem_r * math.cos(angle))
        gy = int(y + gem_r * math.sin(angle))
        pygame.draw.circle(surface, gem_col, (gx, gy), 3)
        if math.sin(anim_t * 2.8 + i * 1.3) > 0.25:
            sx = gx + int(6 * math.cos(angle + 0.8))
            sy = gy + int(6 * math.sin(angle + 0.8))
            pygame.draw.line(surface, gem_col, (sx - 1, sy), (sx + 1, sy), 1)
            pygame.draw.line(surface, gem_col, (sx, sy - 1), (sx, sy + 1), 1)

    # 3. Five rainbow comets on eccentric elliptical orbits.
    # Each ellipse is tilted 72° from the last; all precess slowly so the
    # pentagonal pattern continuously evolves.
    _OB_SPEED = 1.8
    _A        = base_r + 24   # semi-major axis
    _B        = base_r - 20   # semi-minor axis  (eccentricity ≈ 0.88)
    _PREC     = 0.09          # ellipse precession speed (rad/s)
    _LAG_T    = [0.18, 0.32, 0.44]
    _TRAIL_SZ = [2, 1, 1]

    def _epos(t, ellipse_rot):
        angle  = t * _OB_SPEED          # same orbital angle for all comets
        ex     = _A * math.cos(angle)
        ey     = _B * math.sin(angle)
        cr, sr = math.cos(ellipse_rot), math.sin(ellipse_rot)
        return ex * cr - ey * sr, ex * sr + ey * cr

    for ci in range(5):
        tilt        = 2 * math.pi * ci / 5   # ellipse tilt only — not orbital phase
        ellipse_rot = tilt + anim_t * _PREC
        ex, ey = _epos(anim_t, ellipse_rot)
        hue    = (ci / 5 + anim_t * 0.35) % 1.0
        pygame.draw.circle(surface, _hsv_to_rgb(hue, 1.0, 1.0),
                           (int(x + ex), int(y + ey)), 3)
        for lag, tsz in zip(_LAG_T, _TRAIL_SZ):
            pt  = anim_t - lag
            er  = tilt + pt * _PREC
            tex, tey = _epos(pt, er)
            th  = (ci / 5 + pt * 0.35) % 1.0
            pygame.draw.circle(surface, _hsv_to_rgb(th, 0.8, 0.6),
                               (int(x + tex), int(y + tey)), tsz)

    # 4. Layered ripple — 3 concentric rings staggered in time, expanding together
    _RIPPLE_LAYERS = [
        (0.0,  1.4, 32, 24, 0.65),  # (time_offset, duration, max_expand, n_dots, saturation)
        (0.3,  1.4, 19, 18, 0.55),
        (0.6,  1.4,  9, 14, 0.45),
    ]
    period = 7.0
    t_base = anim_t % period
    for t_off, dur, max_exp, n_dots, sat in _RIPPLE_LAYERS:
        t_layer = t_base - t_off
        if 0 < t_layer < dur:
            progress = t_layer / dur
            pulse_r  = base_r + int(progress * max_exp)
            dot_r    = max(1, 2 - int(progress * 1.8))
            for i in range(n_dots):
                angle = (2 * math.pi * i / n_dots) + anim_t * 0.2
                hue   = (i / n_dots + anim_t * 0.15) % 1.0
                pygame.draw.circle(surface, _hsv_to_rgb(hue, sat, 1.0),
                                   (int(x + pulse_r * math.cos(angle)),
                                    int(y + pulse_r * math.sin(angle))), dot_r)


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
