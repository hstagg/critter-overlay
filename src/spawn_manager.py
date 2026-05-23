"""
spawn_manager.py — Spawn timing for Critter Overlay App
"""

import random
import time
from typing import Callable

from animals import create_animal, Animal
from animals_custom import CustomAnimal
from config import get_animal_weights
from custom_critters.registry import CustomCritterRegistry

# First spawn fires 30 seconds after launch so users see it's working immediately
FIRST_SPAWN_DELAY = 30.0

# Fixed rarities for super-rare species. These rolls are PER-INDIVIDUAL spawn
# (so a 5–10 critter group gets that many independent chances), bypassing the
# normal weighted pool entirely.
RARITY_GOLDEN_KITTEN = 1.0 / 1000.0  # legendary
RARITY_UNICORN       = 1.0 / 100.0   # super rare


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

    def _roll_entry(self, fallback: str) -> str:
        """Roll super-rares first; fall back to a pool-picked entry."""
        r = random.random()
        if r < RARITY_GOLDEN_KITTEN:
            return "golden_kitten"
        if r < RARITY_GOLDEN_KITTEN + RARITY_UNICORN:
            return "unicorn"
        return fallback

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

    # Map config trail_style names → (TrailParticle style, rate, size, life)
    _TRAIL_PRESETS = {
        "dots":     ("dot",     15, 6, 0.9),
        "stars":    ("star",    15, 6, 0.9),
        "sparkles": ("sparkle", 25, 4, 0.5),
        "bubbles":  ("bubble",  12, 7, 1.4),
        "glitter":  ("glitter", 40, 2, 0.25),
        "hearts":   ("heart",   12, 6, 0.9),
    }

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
            preset = self._TRAIL_PRESETS.get(trail_style)
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

    def tick(self, dt: float, paused: bool = False) -> None:
        if paused:
            self._primary_next += dt
            self._solo_next    += dt
            return

        now = time.monotonic()

        if now >= self._primary_next:
            self._spawn_primary()
            self._primary_next = now + self._primary_interval()

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
        animals = []
        for _ in range(count):
            entry = self._roll_entry(base_entry)
            x, y  = self._random_pos()
            a = self._make_animal(entry, x, y)
            if a is not None:
                animals.append(a)
        if animals:
            self.on_spawn(animals)

    def _spawn_solo(self) -> None:
        base_entry = self._pick_from_pool()
        if not base_entry:
            return
        entry = self._roll_entry(base_entry)
        x, y, direction = self._edge_pos()
        perimeter = entry not in ("unicorn", "golden_kitten")
        a = self._make_animal(entry, x, y, direction=direction, perimeter_walker=perimeter)
        if a is not None:
            self.on_spawn([a])

    def force_spawn(self) -> None:
        self._spawn_primary()

    def force_solo(self) -> None:
        self._spawn_solo()
