"""
spawn_manager.py — Spawn timing for Critter Overlay App
"""

import random
import time
from typing import Callable

from animals import create_animal, Animal
from animals_custom import CustomAnimal
from behaviours import BehaviourEvaluator
from config import get_animal_weights, save_config
from constants import TRAIL_PRESETS
from custom_critters.registry import CustomCritterRegistry
from rarity import (
    RarityTier, get_modifier, roll_tier,
    check_first_spawn_of_day, record_sighting,
)
from time_of_day import get_time_of_day_state

# First spawn fires 30 seconds after launch so users see it's working immediately
FIRST_SPAWN_DELAY = 30.0


class SpawnManager:

    def __init__(self, screen_w: int, screen_h: int, config: dict,
                 on_spawn: Callable[[list], None],
                 registry: CustomCritterRegistry | None = None):
        self.screen_w = screen_w
        self.screen_h = screen_h
        self.config   = config
        self.on_spawn = on_spawn
        self.registry = registry or CustomCritterRegistry()

        now = time.monotonic()
        self._primary_next = now + FIRST_SPAWN_DELAY
        self._solo_next    = now + self._solo_interval()

        # Behaviour evaluator and time-of-day state
        self._behaviour_evaluator = BehaviourEvaluator()
        self._time_state_acc      = 0.0   # seconds since last time-of-day refresh
        self._activity_scalar     = 1.0
        self._spawn_rate_scalar   = 1.0
        self._sleep_bias          = 0.0

    # ------------------------------------------------------------------
    # Config helpers
    # ------------------------------------------------------------------

    def _primary_interval(self) -> float:
        minutes = self.config["spawn"].get("primary_interval_min", 5)
        return minutes * 60.0 * random.uniform(0.85, 1.15)

    def _solo_interval(self) -> float:
        minutes = self.config["spawn"].get("solo_interval_min", 10)
        return minutes * 60.0 * random.uniform(0.85, 1.15)

    def _build_pool(self) -> dict[str, float]:
        """
        Return {entry_key: weight} combining built-in and custom animals.
        Built-in keys are species strings; custom keys are 'custom:<id>'.
        """
        pool = get_animal_weights(self.config)

        custom_cfg = self.config.get("custom_animals", {})
        for record in self.registry.all():
            cid = record.id
            entry = custom_cfg.get(cid, {})
            if entry.get("enabled", True):
                pool[f"custom:{cid}"] = float(entry.get("weight", 1.0))

        return pool

    def _pick_from_pool(self) -> str | None:
        pool = self._build_pool()
        if not pool:
            return None
        keys    = list(pool.keys())
        weights = list(pool.values())
        return random.choices(keys, weights=weights, k=1)[0]

    def _animal_size(self) -> int:
        return self.config["visual"].get("animal_size", 120)

    def _random_pos(self):
        margin = 120
        return (
            random.uniform(margin, self.screen_w - margin),
            random.uniform(margin, self.screen_h - margin),
        )

    def _edge_pos(self):
        m = int(self._animal_size() * 0.85)
        edge = random.choice(["top", "bottom", "left", "right"])
        if edge == "top":
            return random.uniform(m, self.screen_w - m), float(m), random.choice([-1, 1])
        elif edge == "bottom":
            return random.uniform(m, self.screen_w - m), float(self.screen_h - m), random.choice([-1, 1])
        elif edge == "left":
            return float(m), random.uniform(m, self.screen_h - m), 1
        else:
            return float(self.screen_w - m), random.uniform(m, self.screen_h - m), -1

    # ------------------------------------------------------------------
    # Rarity helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _species_from_entry(entry: str) -> str | None:
        """Return the species name for built-ins, None for custom critters."""
        return None if entry.startswith("custom:") else entry

    def _roll_tier_for_entry(self, entry: str) -> RarityTier:
        """Roll a rarity tier, respecting custom critter rarity_strategy."""
        if entry.startswith("custom:"):
            critter_id = entry[len("custom:"):]
            record = self.registry.get(critter_id)
            if record:
                strategy = record.meta.get("rarity_strategy", "auto")
                if strategy == "common_only":
                    return RarityTier.COMMON
                if strategy.startswith("fixed:"):
                    from rarity import parse_tier
                    return parse_tier(strategy[len("fixed:"):])
        return roll_tier(self.config, self._species_from_entry(entry))

    def _apply_rarity(self, animal: Animal, tier: RarityTier) -> None:
        """Attach rarity tier to an animal and apply visual modifiers."""
        animal.rarity = tier
        mod = get_modifier(tier)

        # Speed variance for this tier
        lo, hi = mod.speed_range
        if lo != hi or lo != 1.0:
            mult = random.uniform(lo, hi)
            animal.vx *= mult
            animal.vy *= mult

        # Apply rarity trail if the animal has no species-configured trail
        if not animal.LEAVES_TRAIL and mod.trail_style_default != "none":
            preset = TRAIL_PRESETS.get(mod.trail_style_default)
            if preset:
                particle_style, rate, sz, life = preset
                animal.LEAVES_TRAIL  = True
                animal.TRAIL_PALETTE = list(animal.PARTICLE_COLORS) or [(220, 220, 255)]
                animal.TRAIL_STYLE   = particle_style
                animal.TRAIL_RATE    = rate
                animal.TRAIL_SIZE    = sz
                animal.TRAIL_LIFE    = life

        # Seen log — fire and forget (persisted on next settings save)
        species = getattr(animal, "SPECIES", "unknown")
        record_sighting(self.config, species, tier)

    def _make_animal(self, entry: str, x: float, y: float,
                     direction: int | None = None,
                     perimeter_walker: bool = False) -> Animal | None:
        """Instantiate a built-in or custom animal from a pool entry key."""
        size = self._animal_size()
        if entry.startswith("custom:"):
            critter_id = entry[len("custom:"):]
            record = self.registry.get(critter_id)
            if record is None:
                return None
            # Per-critter size override
            custom_cfg = self.config.get("custom_animals", {}).get(critter_id, {})
            sz = custom_cfg.get("size_override") or size
            return CustomAnimal(x, y, sz, self.screen_w, self.screen_h,
                                record=record, direction=direction,
                                perimeter_walker=perimeter_walker)

        animal = create_animal(entry, x, y, size, self.screen_w, self.screen_h,
                               direction=direction, perimeter_walker=perimeter_walker)
        if animal is None:
            return None

        # Apply per-species personality from config (v1.10)
        species_cfg = self.config.get("animals", {}).get(entry, {})
        speed_mult = float(species_cfg.get("speed_multiplier", 1.0))
        if speed_mult != 1.0:
            animal.vx *= speed_mult
            animal.vy *= speed_mult

        idle_rate = float(species_cfg.get("idle_rate", animal.IDLE_RATE))
        animal.IDLE_RATE = idle_rate

        trail_style = species_cfg.get("trail_style", "none")
        # Super-rares manage their own trail config — don't override
        if trail_style != "none" and entry not in ("unicorn", "golden_kitten"):
            preset = TRAIL_PRESETS.get(trail_style)
            if preset:
                particle_style, rate, sz, life = preset
                animal.LEAVES_TRAIL = True
                animal.TRAIL_PALETTE = list(animal.PARTICLE_COLORS)
                animal.TRAIL_STYLE   = particle_style
                animal.TRAIL_RATE    = rate
                animal.TRAIL_SIZE    = sz
                animal.TRAIL_LIFE    = life

        return animal

    # ------------------------------------------------------------------
    # Tick — call every frame with dt
    # ------------------------------------------------------------------

    def tick(self, dt: float, paused: bool = False,
             animals: list | None = None) -> None:
        # Update time-of-day state every second regardless of pause
        self._time_state_acc += dt
        if self._time_state_acc >= 1.0:
            self._time_state_acc = 0.0
            act, spn, slp = get_time_of_day_state(self.config)
            self._activity_scalar   = act
            self._spawn_rate_scalar = spn
            self._sleep_bias        = slp

        # Tick behaviour evaluator (always runs, even while paused — critters
        # can still behave when spawning is paused)
        if animals:
            self._behaviour_evaluator.tick(
                dt, animals,
                self._activity_scalar, self._sleep_bias, self.config,
            )

        if paused:
            self._primary_next += dt
            self._solo_next    += dt
            return

        now = time.monotonic()

        # Apply spawn-rate scalar to the primary interval cap
        # (scalar already embedded in _primary_interval via the next-event calc)
        if now >= self._primary_next:
            self._spawn_primary()
            interval = self._primary_interval()
            # Night/dawn slow down spawns; morning speeds them up
            interval /= max(0.1, self._spawn_rate_scalar)
            self._primary_next = now + interval

        if self.config["spawn"].get("solo_enabled", True) and now >= self._solo_next:
            self._spawn_solo()
            self._solo_next = now + self._solo_interval()

    def apply_config(self, config: dict, registry: CustomCritterRegistry | None = None) -> None:
        self.config = config
        if registry is not None:
            self.registry = registry

    # ------------------------------------------------------------------
    # Spawn actions
    # ------------------------------------------------------------------

    def _spawn_primary(self) -> None:
        base_entry = self._pick_from_pool()
        if not base_entry:
            return
        count = random.randint(
            self.config["spawn"].get("primary_count_min", 5),
            self.config["spawn"].get("primary_count_max", 10),
        )

        # First-spawn-of-day bonus applies to the first animal in the group
        bonus_tier = check_first_spawn_of_day(self.config)
        if bonus_tier is not None:
            save_config(self.config)  # persist the date immediately

        animals = []
        for i in range(count):
            x, y = self._random_pos()
            a = self._make_animal(base_entry, x, y)
            if a is not None:
                tier = bonus_tier if (i == 0 and bonus_tier is not None) \
                       else self._roll_tier_for_entry(base_entry)
                self._apply_rarity(a, tier)
                animals.append(a)
        if animals:
            self.on_spawn(animals)

    def _spawn_solo(self) -> None:
        base_entry = self._pick_from_pool()
        if not base_entry:
            return
        x, y, direction = self._edge_pos()
        a = self._make_animal(base_entry, x, y, direction=direction, perimeter_walker=True)
        if a is not None:
            tier = self._roll_tier_for_entry(base_entry)
            self._apply_rarity(a, tier)
            self.on_spawn([a])

    def force_spawn(self) -> None:
        self._spawn_primary()

    def force_solo(self) -> None:
        self._spawn_solo()
