"""
locomotion.py — Species locomotion profiles for Critter Overlay App.

Each profile shapes the *texture* of movement in the WALKING state.
Speed-multiplier, direction, and wall bouncing are unchanged from v1.
The profile only drives: speed scalar (applied before position update),
y draw-offset (visual arc/bob), and x draw-offset (visual sway).

Profile update runs per-frame; outputs stored on animal as:
    _loco_speed_scalar  float  default 1.0
    _loco_y_offset      float  pixels (negative = up)
    _loco_x_offset      float  pixels

All offsets are zero when the animal is not in WALKING state.
"""

from __future__ import annotations

import math
import random

# ---------------------------------------------------------------------------
# Profile implementations  (phase: 0.0 → cycle_duration, wraps)
# ---------------------------------------------------------------------------

# Pounce constants
_POUNCE_CYCLE   = 1.0   # seconds
_POUNCE_BURST   = 0.40  # burst phase duration
_POUNCE_DECEL   = 0.08  # deceleration ramp at burst→hold boundary

# Hop constants
_HOP_CYCLE  = 0.80
_HOP_LAUNCH = 0.50   # arc phase (ground-to-ground)
_HOP_HOLD   = 0.30   # ground hold

# Dart constants
_DART_CYCLE = 0.65
_DART_RUN   = 0.25
_DART_HOLD  = 0.40
_DART_DECEL = 0.08  # deceleration ramp at run→freeze boundary

# Slide constants (otter)
_SLIDE_CYCLE  = 5.0
_SLIDE_WALK   = 3.8   # classic walk portion
_SLIDE_GLIDE  = 1.2   # belly-slide portion

# Lumber standing-pause: managed with a separate timer
_LUMBER_PAUSE_CYCLE = 8.0   # average time between pauses


def _pounce(phase: float, size: float) -> tuple[float, float, float]:
    if phase < _POUNCE_BURST:
        t    = phase / _POUNCE_BURST
        yoff = -size * 0.04 * math.sin(math.pi * t)   # small bob during burst
        return 1.6, yoff, 0.0
    else:
        hold_t = phase - _POUNCE_BURST
        if hold_t < _POUNCE_DECEL:
            # Smooth deceleration ramp: 1.6 → 0 over 0.08s
            spd = 1.6 * (1.0 - hold_t / _POUNCE_DECEL)
            return spd, 0.0, 0.0
        # Creeping/slinking phase (not frozen — cat is sneaking)
        t    = min(1.0, (hold_t - _POUNCE_DECEL) / 0.15)
        yoff = -size * 0.03 * t   # slight head-down crouch
        return 0.35, yoff, 0.0


def _hop(phase: float, size: float) -> tuple[float, float, float]:
    if phase < _HOP_LAUNCH:
        t    = phase / _HOP_LAUNCH
        yoff = -size * 0.28 * math.sin(math.pi * t)   # arc up then down
        return 1.0, yoff, 0.0
    else:
        # Ground hold — barely moving
        return 0.15, 0.0, 0.0


def _waddle(phase: float, size: float) -> tuple[float, float, float]:
    # 1.5 Hz side-to-side sway over the cycle
    xoff = size * 0.055 * math.sin(2 * math.pi * 1.5 * phase / 0.67)
    yoff = size * 0.025 * abs(math.sin(2 * math.pi * 1.0 * phase / 0.67))
    return 1.0, yoff, xoff


def _plod(phase: float, size: float) -> tuple[float, float, float]:
    # Exaggerated slow head-bob, slight 1-frame stutter handled via low base speed
    yoff = -size * 0.06 * abs(math.sin(2 * math.pi * phase / 1.0))
    return 0.85, yoff, 0.0


def _dart(phase: float, size: float) -> tuple[float, float, float]:
    if phase < _DART_RUN:
        return 2.0, 0.0, 0.0
    else:
        hold_t = phase - _DART_RUN
        if hold_t < _DART_DECEL:
            # Smooth deceleration ramp: 2.0 → 0 over 0.08s
            spd = 2.0 * (1.0 - hold_t / _DART_DECEL)
            return spd, 0.0, 0.0
        # Freeze-and-look — slight alert tuck
        t    = min(1.0, (hold_t - _DART_DECEL) / 0.15)
        yoff = -size * 0.03 * t
        return 0.0, yoff, 0.0


def _slide(phase: float, size: float) -> tuple[float, float, float]:
    if phase < _SLIDE_WALK:
        # Normal walk with standard bob; locomotion contributes nothing extra
        return 1.0, 0.0, 0.0
    else:
        # Belly-slide: fast, low, no bob
        t = (phase - _SLIDE_WALK) / _SLIDE_GLIDE
        # Ease in/out
        spd  = 1.3 * math.sin(math.pi * t) + 0.8 * (1.0 - math.sin(math.pi * t))
        # Flatten the critter slightly by raising y (closer to ground)
        yoff = size * 0.06 * math.sin(math.pi * t)
        return spd, yoff, 0.0


def _snuffle(phase: float, size: float) -> tuple[float, float, float]:
    # Slow, low head-bob with a gentle side-sweep
    yoff = size * 0.05 * abs(math.sin(2 * math.pi * phase / 1.0))
    xoff = size * 0.02 * math.sin(4 * math.pi * phase / 1.0)
    return 0.65, yoff, xoff


def _lumber(phase: float, size: float) -> tuple[float, float, float]:
    # Slow heavy weight-shift: long-period horizontal sway
    yoff = size * 0.03 * math.sin(2 * math.pi * phase / 2.0)
    xoff = size * 0.04 * math.sin(2 * math.pi * 0.5 * phase / 2.0)
    return 0.45, yoff, xoff


# ---------------------------------------------------------------------------
# Cycle durations per profile
# ---------------------------------------------------------------------------

_CYCLE = {
    "classic": 1.0,
    "pounce":  _POUNCE_CYCLE,
    "hop":     _HOP_CYCLE,
    "waddle":  0.67,
    "plod":    1.0,
    "dart":    _DART_CYCLE,
    "slide":   _SLIDE_CYCLE,
    "snuffle": 1.0,
    "lumber":  2.0,
}

_FN = {
    "pounce":  _pounce,
    "hop":     _hop,
    "waddle":  _waddle,
    "plod":    _plod,
    "dart":    _dart,
    "slide":   _slide,
    "snuffle": _snuffle,
    "lumber":  _lumber,
}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def update_locomotion(animal, dt: float) -> None:
    """
    Advance animal.loco_phase and update locomotion output fields.
    Only active in WALKING state — resets outputs otherwise.
    """
    # Import here to avoid circular import (animals imports locomotion)
    walking = getattr(animal, "WALKING", "walking")

    if animal.state != walking or animal.being_dragged or animal.thrown:
        animal._loco_speed_scalar = 1.0
        animal._loco_y_offset     = 0.0
        animal._loco_x_offset     = 0.0
        return

    profile = getattr(animal, "loco_profile", "classic")
    cycle   = _CYCLE.get(profile, 1.0)
    fn      = _FN.get(profile)

    # Advance phase
    animal.loco_phase = (animal.loco_phase + dt) % cycle

    if fn is None:
        # classic
        animal._loco_speed_scalar = 1.0
        animal._loco_y_offset     = 0.0
        animal._loco_x_offset     = 0.0
        return

    spd, yoff, xoff = fn(animal.loco_phase, float(animal.size))
    animal._loco_speed_scalar = spd
    animal._loco_y_offset     = yoff
    animal._loco_x_offset     = xoff
