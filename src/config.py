"""
config.py — Settings management for Critter Overlay App
Loads/saves JSON config from AppData. Merges with defaults on load.
"""

import json
import os
import copy
from pathlib import Path

# ---------------------------------------------------------------------------
# Default configuration
# ---------------------------------------------------------------------------

_SPECIES_PERSONALITY = {
    "speed_multiplier": 1.0,
    "idle_rate":        0.018,
    "trail_style":      "none",
}

DEFAULT_CONFIG = {
    "animals": {
        "kitten":   {"enabled": True, "weight": 3.0, "sound": True, **_SPECIES_PERSONALITY},
        "turtle":   {"enabled": True, "weight": 1.0, "sound": True, **_SPECIES_PERSONALITY},
        "duck":     {"enabled": True, "weight": 1.0, "sound": True, **_SPECIES_PERSONALITY},
        "rabbit":   {"enabled": True, "weight": 1.0, "sound": True, **_SPECIES_PERSONALITY},
        "hedgehog": {"enabled": True, "weight": 1.0, "sound": True, **_SPECIES_PERSONALITY},
        "squirrel": {"enabled": True, "weight": 1.0, "sound": True, **_SPECIES_PERSONALITY},
        "otter":    {"enabled": True, "weight": 1.0, "sound": True, **_SPECIES_PERSONALITY},
        "panda":    {"enabled": True, "weight": 1.0, "sound": True, **_SPECIES_PERSONALITY},
    },
    "spawn": {
        "primary_interval_min": 5,    # minutes between group spawns
        "primary_count_min": 5,       # min animals per group spawn
        "primary_count_max": 10,      # max animals per group spawn
        "solo_enabled": True,
        "solo_interval_min": 10,      # minutes between solo perimeter walkers
    },
    "visual": {
        "animal_size": 120,           # pixels (80–200)
        "opacity": 100,               # 50–100%
        "animation_detail": "detailed",  # "simple" or "detailed"
    },
    "audio": {
        "sound_enabled": True,
        "volume": 50,                 # 0–100
    },
    "system": {
        "auto_launch": True,
        "hotkey_pause": "ctrl+shift+p",
    },
    "custom_animals": {},   # keyed by critter_id; entries added by import pipeline
}

# ---------------------------------------------------------------------------
# Config file path
# ---------------------------------------------------------------------------

def get_config_path() -> Path:
    appdata = os.environ.get("APPDATA", os.path.expanduser("~"))
    config_dir = Path(appdata) / "CritterOverlay"
    config_dir.mkdir(parents=True, exist_ok=True)
    return config_dir / "settings.json"


# ---------------------------------------------------------------------------
# Deep merge helpers
# ---------------------------------------------------------------------------

def _deep_merge(base: dict, override: dict) -> dict:
    """Return a new dict with override values merged into base (recursive)."""
    result = copy.deepcopy(base)
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = _deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def load_config() -> dict:
    """Load settings from disk, merging with defaults for any missing keys."""
    path = get_config_path()
    if path.exists():
        try:
            with open(path, "r", encoding="utf-8") as f:
                saved = json.load(f)
            return _deep_merge(DEFAULT_CONFIG, saved)
        except Exception as e:
            print(f"[config] Failed to load settings ({e}), using defaults.")
    return copy.deepcopy(DEFAULT_CONFIG)


def save_config(config: dict) -> None:
    """Save settings to disk."""
    path = get_config_path()
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
    except Exception as e:
        print(f"[config] Failed to save settings: {e}")


def reset_to_defaults() -> dict:
    """Return a clean copy of the default config and save it."""
    config = copy.deepcopy(DEFAULT_CONFIG)
    save_config(config)
    return config


def get_enabled_animals(config: dict) -> list:
    """Return list of enabled animal species names."""
    return [
        species for species, cfg in config["animals"].items()
        if cfg.get("enabled", True)
    ]


def get_animal_weights(config: dict) -> dict:
    """Return {species: weight} for all enabled animals."""
    return {
        species: cfg.get("weight", 1.0)
        for species, cfg in config["animals"].items()
        if cfg.get("enabled", True)
    }
