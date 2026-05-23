"""
rarity.py — Rarity tier system for Critter Overlay App.

Every spawned critter rolls a hidden tier at spawn time. The tier drives
aura visuals, trail defaults, and (in Phase 2) behaviour frequency. The
system is purely opt-in: rarity.enabled=false returns COMMON for every roll.
"""

from __future__ import annotations

import random
from dataclasses import dataclass
from datetime import date, datetime
from enum import Enum


# ---------------------------------------------------------------------------
# Tier definitions
# ---------------------------------------------------------------------------

class RarityTier(Enum):
    COMMON    = "common"
    UNCOMMON  = "uncommon"
    RARE      = "rare"
    EPIC      = "epic"
    LEGENDARY = "legendary"


_TIER_ORDER: list[RarityTier] = [
    RarityTier.COMMON,
    RarityTier.UNCOMMON,
    RarityTier.RARE,
    RarityTier.EPIC,
    RarityTier.LEGENDARY,
]

_NAME_TO_TIER: dict[str, RarityTier] = {t.value: t for t in RarityTier}


def parse_tier(name: str) -> RarityTier:
    """Convert a string like 'rare' to RarityTier.RARE. Defaults to COMMON."""
    return _NAME_TO_TIER.get(name, RarityTier.COMMON)


# ---------------------------------------------------------------------------
# Per-tier modifier dataclass
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class RarityModifier:
    tier:                RarityTier
    aura_style:          str              # "none"|"soft_glow"|"bright_glow"|"shimmer"|"rainbow"
    trail_style_default: str              # TRAIL_PRESETS key or "none"
    speed_range:         tuple[float, float]  # (min_mult, max_mult)
    behaviour_mult:      float            # multiplier on behaviour_chance (Phase 2)


_MODIFIERS: dict[RarityTier, RarityModifier] = {
    RarityTier.COMMON:    RarityModifier(RarityTier.COMMON,    "none",        "none",     (0.80, 1.00), 0.30),
    RarityTier.UNCOMMON:  RarityModifier(RarityTier.UNCOMMON,  "soft_glow",   "dots",     (0.90, 1.10), 0.50),
    RarityTier.RARE:      RarityModifier(RarityTier.RARE,      "bright_glow", "sparkles", (0.95, 1.05), 0.70),
    RarityTier.EPIC:      RarityModifier(RarityTier.EPIC,      "shimmer",     "glitter",  (1.00, 1.00), 0.85),
    RarityTier.LEGENDARY: RarityModifier(RarityTier.LEGENDARY, "rainbow",     "hearts",   (1.00, 1.00), 1.00),
}


def get_modifier(tier: RarityTier) -> RarityModifier:
    return _MODIFIERS[tier]


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _clamp_tier(tier: RarityTier, min_name: str, max_name: str) -> RarityTier:
    min_t = parse_tier(min_name)
    max_t = parse_tier(max_name)
    idx   = _TIER_ORDER.index(tier)
    idx   = max(idx, _TIER_ORDER.index(min_t))
    idx   = min(idx, _TIER_ORDER.index(max_t))
    return _TIER_ORDER[idx]


def _default_dist() -> dict[str, float]:
    return {"common": 0.60, "uncommon": 0.25, "rare": 0.10, "epic": 0.04, "legendary": 0.01}


def _build_weights(dist: dict, boost: float = 1.0) -> tuple[list[RarityTier], list[float]]:
    """Return (tiers, weights). If boost > 1, rare+ odds increase at expense of common."""
    d = {**_default_dist(), **dist}

    if boost > 1.0:
        rare_pool = d.get("rare", 0) + d.get("epic", 0) + d.get("legendary", 0)
        if rare_pool > 0:
            boosted = min(rare_pool * boost, 0.80)
            scale   = boosted / rare_pool
            d["rare"]      = d.get("rare", 0) * scale
            d["epic"]      = d.get("epic", 0) * scale
            d["legendary"] = d.get("legendary", 0) * scale
            total = sum(d.values())
            if total > 0:
                d = {k: v / total for k, v in d.items()}

    weights = [d.get(t.value, 0.0) for t in _TIER_ORDER]
    return _TIER_ORDER, weights


def _in_rare_hour(rare_hour_cfg: dict) -> bool:
    if not rare_hour_cfg.get("enabled", True):
        return False
    now_h   = datetime.now().hour
    start   = rare_hour_cfg.get("start_hour", 21)
    dur_min = rare_hour_cfg.get("duration_minutes", 60)
    end_h   = (start + dur_min // 60) % 24
    if start < end_h:
        return start <= now_h < end_h
    return now_h >= start or now_h < end_h   # wraps midnight


def _today_str() -> str:
    return date.today().isoformat()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def roll_tier(config: dict, species: str | None = None) -> RarityTier:
    """Roll a rarity tier for a new spawn, applying rare-hour boost and species limits."""
    rarity_cfg = config.get("rarity", {})
    if not rarity_cfg.get("enabled", True):
        return RarityTier.COMMON

    # Dev override: force every spawn to a specific tier for design iteration
    forced = rarity_cfg.get("debug_force_tier", "")
    if forced:
        return parse_tier(forced)

    dist  = rarity_cfg.get("distribution", {})
    boost = 1.0
    if _in_rare_hour(rarity_cfg.get("rare_hour", {})):
        boost = float(rarity_cfg.get("rare_hour", {}).get("rare_tier_boost", 2.0))

    tiers, weights = _build_weights(dist, boost)
    tier = random.choices(tiers, weights=weights, k=1)[0]

    if species:
        sp_cfg = config.get("animals", {}).get(species, {})
        tier = _clamp_tier(
            tier,
            sp_cfg.get("rarity_min", "common"),
            sp_cfg.get("rarity_max", "legendary"),
        )

    return tier


def check_first_spawn_of_day(config: dict) -> RarityTier | None:
    """
    If today's first-spawn bonus hasn't fired yet, return a Rare-or-better tier
    and mark today as spent (in config in-memory only — caller persists).
    Returns None when the bonus doesn't apply or is disabled.
    """
    rarity_cfg = config.get("rarity", {})
    if not rarity_cfg.get("first_spawn_of_day_bonus", True):
        return None
    today = _today_str()
    if rarity_cfg.get("last_first_spawn_date") == today:
        return None
    config.setdefault("rarity", {})["last_first_spawn_date"] = today
    # Guaranteed Rare+, elevated Legendary odds
    tiers, weights = _build_weights({"rare": 0.70, "epic": 0.20, "legendary": 0.10})
    return random.choices(tiers, weights=weights, k=1)[0]


def record_sighting(config: dict, species: str, tier: RarityTier) -> bool:
    """
    Log a sighting of (species, tier) in the seen_log. Returns True on first sighting.
    Mutates config in-memory; caller persists when appropriate.
    """
    rarity_cfg = config.get("rarity", {})
    if not rarity_cfg.get("seen_log_enabled", True):
        return False
    seen    = config.setdefault("rarity", {}).setdefault("seen_log", {})
    sp_log  = seen.setdefault(species, {})
    tier_key = tier.value
    if tier_key not in sp_log:
        sp_log[tier_key] = 1
        return True
    sp_log[tier_key] += 1
    return False
