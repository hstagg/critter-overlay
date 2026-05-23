"""
time_of_day.py — Day/night cycle for Critter Overlay App.

Returns behavioural scalars driven by system clock. Called once per second
from spawn_manager; never touched by the draw path. No visual tinting —
the overlay stays pixel-identical at every hour.

Six buckets with 10-minute linear interpolation across boundaries.
"""

from __future__ import annotations

from datetime import datetime


# ---------------------------------------------------------------------------
# Bucket definitions  (hour_start, activity_scalar, spawn_rate_scalar, sleep_bias)
# sleep_bias: 0.0 = no sleep bias, 1.0 = strongly prefer nap/sit idles
# ---------------------------------------------------------------------------

_BUCKETS = [
    # (start_hour, activity, spawn_rate, sleep_bias)
    ( 5, 0.90, 0.80, 0.15),   # Dawn        05:00–08:00
    ( 8, 1.10, 1.20, 0.05),   # Morning     08:00–11:00
    (11, 1.00, 1.00, 0.10),   # Midday      11:00–15:00
    (15, 1.00, 1.00, 0.10),   # Afternoon   15:00–18:00
    (18, 0.80, 0.90, 0.45),   # Evening     18:00–21:00
    (21, 0.50, 0.50, 0.85),   # Night       21:00–05:00 (wraps midnight)
]

# Transition window in hours at each bucket boundary
_TRANSITION_HOURS = 10 / 60  # 10 minutes


def _hour_now() -> float:
    """Current local time as fractional hours (0.0–24.0)."""
    now = datetime.now()
    return now.hour + now.minute / 60.0 + now.second / 3600.0


def _bucket_at(hour: float) -> tuple[float, float, float]:
    """Return (activity_scalar, spawn_rate_scalar, sleep_bias) for a given hour."""
    n = len(_BUCKETS)
    # Find which bucket we're in
    active_idx = 0
    for i, (start_h, *_) in enumerate(_BUCKETS):
        if i == n - 1:
            # Last bucket (Night) wraps midnight: covers 21:00–05:00
            next_start = _BUCKETS[0][0] + 24  # 5 + 24 = 29 (wraps)
            if hour >= start_h or hour < _BUCKETS[0][0]:
                active_idx = i
                break
        else:
            next_start = _BUCKETS[i + 1][0]
            if start_h <= hour < next_start:
                active_idx = i
                break

    # Values for active bucket
    _, a0, s0, b0 = _BUCKETS[active_idx]
    next_idx = (active_idx + 1) % n
    _, a1, s1, b1 = _BUCKETS[next_idx]

    # Check if we're within the transition window at the END of this bucket
    _, next_start_h, *_ = (*_BUCKETS[next_idx],)
    next_start_h = _BUCKETS[next_idx][0]
    # Convert to a comparable scale
    if next_idx == 0:
        # Transition to Dawn wraps: next start is 5:00, but bucket ends at 5:00
        # Edge of Night → Dawn is at hour 5.0
        hours_to_end = (_BUCKETS[0][0] + 24 - hour) if hour >= 21 else (_BUCKETS[0][0] - hour)
    else:
        hours_to_end = next_start_h - hour
        if hours_to_end < 0:
            hours_to_end += 24

    if hours_to_end < _TRANSITION_HOURS:
        t = 1.0 - hours_to_end / _TRANSITION_HOURS  # 0→1 as we approach boundary
        return (
            _lerp(a0, a1, t),
            _lerp(s0, s1, t),
            _lerp(b0, b1, t),
        )

    # Check if we're within the transition window at the START of this bucket
    prev_idx = (active_idx - 1) % n
    prev_start = _BUCKETS[active_idx][0]
    if active_idx == n - 1:
        hours_from_start = (hour - prev_start) if hour >= prev_start else (hour + 24 - prev_start)
    else:
        hours_from_start = hour - _BUCKETS[active_idx][0]

    if hours_from_start < _TRANSITION_HOURS:
        _, pa, ps, pb = _BUCKETS[prev_idx]
        t = hours_from_start / _TRANSITION_HOURS  # 0→1 as we move away from boundary
        return (
            _lerp(pa, a0, t),
            _lerp(ps, s0, t),
            _lerp(pb, b0, t),
        )

    return a0, s0, b0


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def get_time_of_day_state(config: dict) -> tuple[float, float, float]:
    """
    Return (activity_scalar, spawn_rate_scalar, sleep_bias) for the current time.

    If day_night_enabled is False, returns baseline (1.0, 1.0, 0.0).
    """
    if not config.get("behaviour", {}).get("day_night_enabled", True):
        return 1.0, 1.0, 0.0

    hour = _hour_now()
    return _bucket_at(hour)
