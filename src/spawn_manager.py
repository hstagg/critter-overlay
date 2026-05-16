"""
spawn_manager.py — Spawn timing for Critter Overlay App
"""

import random
import time
import math
from typing import Callable

from animals import create_animal, Animal
from config import get_animal_weights

# First spawn fires 30 seconds after launch so users see it's working immediately
FIRST_SPAWN_DELAY = 30.0

# Fixed rarities for super-rare species. These rolls are PER-INDIVIDUAL spawn
# (so a 5–10 critter group gets that many independent chances), bypassing the
# normal weighted pool entirely.
RARITY_GOLDEN_KITTEN = 1.0 / 1000.0  # legendary
RARITY_UNICORN       = 1.0 / 100.0   # super rare


class SpawnManager:

    def __init__(self, screen_w: int, screen_h: int, config: dict,
                 on_spawn: Callable[[list], None]):
        self.screen_w = screen_w
        self.screen_h = screen_h
        self.config = config
        self.on_spawn = on_spawn

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

    def _pick_species(self):
        weights = get_animal_weights(self.config)
        if not weights:
            return None
        return random.choices(list(weights.keys()), weights=list(weights.values()), k=1)[0]

    def _roll_species(self, fallback):
        """Roll super-rares first; fall back to a normally-picked species."""
        r = random.random()
        # Check the rarer one first so it isn't shadowed
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
        m = int(self._animal_size() * 0.85)  # matches perimeter walk margin
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
    # Tick — call every frame with dt
    # ------------------------------------------------------------------

    def tick(self, dt: float, paused: bool = False) -> None:
        if paused:
            # Freeze the countdown — push targets forward by dt
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

    def apply_config(self, config: dict) -> None:
        self.config = config

    # ------------------------------------------------------------------
    # Spawn actions
    # ------------------------------------------------------------------

    def _spawn_primary(self) -> None:
        base_species = self._pick_species()
        if not base_species:
            return
        count = random.randint(
            self.config["spawn"].get("primary_count_min", 5),
            self.config["spawn"].get("primary_count_max", 10),
        )
        size = self._animal_size()
        animals = []
        for _ in range(count):
            # Each individual independently rolls for a super-rare appearance,
            # otherwise it joins the rest of the group (same base species).
            species = self._roll_species(base_species)
            x, y = self._random_pos()
            animals.append(create_animal(
                species, x, y, size, self.screen_w, self.screen_h,
            ))
        if animals:
            self.on_spawn(animals)

    def _spawn_solo(self) -> None:
        base_species = self._pick_species()
        if not base_species:
            return
        species = self._roll_species(base_species)
        x, y, direction = self._edge_pos()
        # Super-rares roam free instead of patrolling the perimeter so their
        # trail effect is more visible and they feel different.
        perimeter = species not in ("unicorn", "golden_kitten")
        animal = create_animal(species, x, y, self._animal_size(),
                               self.screen_w, self.screen_h,
                               direction=direction, perimeter_walker=perimeter)
        self.on_spawn([animal])

    def force_spawn(self) -> None:
        self._spawn_primary()

    def force_solo(self) -> None:
        self._spawn_solo()
