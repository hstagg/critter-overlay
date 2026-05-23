"""
constants.py — Shared constants for Critter Overlay App.
"""

# Trail preset mappings: config name → (TrailParticle style, emit_rate, size_px, lifetime_s)
TRAIL_PRESETS: dict[str, tuple[str, int, int, float]] = {
    "dots":     ("dot",     15, 6, 0.9),
    "stars":    ("star",    15, 6, 0.9),
    "sparkles": ("sparkle", 25, 4, 0.5),
    "bubbles":  ("bubble",  12, 7, 1.4),
    "glitter":  ("glitter", 40, 2, 0.25),
    "hearts":   ("heart",   12, 6, 0.9),
}
