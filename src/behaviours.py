"""
behaviours.py — Behaviour catalogue and evaluator for Critter Overlay App.

Behaviours are short-lived named states layered on top of the locomotion
state machine. The evaluator runs every ~1s (not every frame) and picks at
most one new pair-interaction per tick.

Behaviour entries are data; adding behaviour #45 is a registry entry only.

Pair interactions:  two animals stop, face each other, run for the behaviour
                    duration, then both resume WALKING.
Solo idles:         one animal stops for the behaviour duration, then resumes.

States SCATTERED, dragged, thrown, and POPPING suppress behaviour entry.
Any behaviour is cancelled immediately if the animal is scattered or dragged.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from animals import Animal


# ---------------------------------------------------------------------------
# Behaviour definition
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class BehaviourDef:
    name: str
    duration: tuple[float, float]       # (min_s, max_s)
    is_pair: bool = False
    # Solo: which species can perform this (empty = universal)
    species_whitelist: frozenset = field(default_factory=frozenset)
    # Pair: required species involved (empty = any two)
    pair_species_a: frozenset = field(default_factory=frozenset)
    pair_species_b: frozenset = field(default_factory=frozenset)
    sleep_bias_weight: float = 0.0   # extra weight when sleep_bias is high
    cooldown: float = 30.0           # per-critter cooldown before same behaviour repeats
    particles: bool = False          # emit a small puff particle on entry


# ---------------------------------------------------------------------------
# Behaviour registry
# ---------------------------------------------------------------------------

_U = frozenset()   # empty = universal

REGISTRY: dict[str, BehaviourDef] = {
    # ── Universal solo idles ───────────────────────────────────────────────
    "stretch":       BehaviourDef("stretch",       (1.0, 1.5),  cooldown=45.0),
    "yawn":          BehaviourDef("yawn",           (0.7, 1.0),  sleep_bias_weight=0.3, cooldown=60.0),
    "sit_and_look":  BehaviourDef("sit_and_look",   (2.0, 4.0),  sleep_bias_weight=0.2, cooldown=30.0),
    "nap":           BehaviourDef("nap",             (5.0, 15.0), sleep_bias_weight=1.0, cooldown=120.0),
    "wake_up":       BehaviourDef("wake_up",         (0.5, 0.8),  cooldown=5.0),
    "groom_self":    BehaviourDef("groom_self",      (2.0, 3.0),  sleep_bias_weight=0.3, cooldown=40.0),
    "scratch":       BehaviourDef("scratch",         (1.2, 2.0),  cooldown=35.0),
    "ear_flick":     BehaviourDef("ear_flick",       (0.25, 0.4), cooldown=8.0),
    "tail_swish":    BehaviourDef("tail_swish",      (0.4, 0.6),  cooldown=6.0),
    "sneeze":        BehaviourDef("sneeze",          (0.4, 0.6),  particles=True, cooldown=30.0),
    "shake_off":     BehaviourDef("shake_off",       (0.6, 1.0),  cooldown=60.0),
    "look_at_cursor":BehaviourDef("look_at_cursor",  (1.0, 2.0),  cooldown=15.0),
    "listen":        BehaviourDef("listen",          (0.8, 1.3),  cooldown=20.0),

    # ── Species-flavoured idles ────────────────────────────────────────────
    "hunt_pose":     BehaviourDef("hunt_pose",   (1.5, 3.0),  species_whitelist=frozenset({"kitten"}), cooldown=45.0),
    "chase_tail":    BehaviourDef("chase_tail",  (1.0, 2.0),  species_whitelist=frozenset({"kitten"}), cooldown=90.0),
    "preen":         BehaviourDef("preen",       (2.0, 3.5),  species_whitelist=frozenset({"duck"}),   sleep_bias_weight=0.2, cooldown=40.0),
    "peck_ground":   BehaviourDef("peck_ground", (0.8, 1.5),  species_whitelist=frozenset({"duck"}),   cooldown=25.0),
    "nose_twitch":   BehaviourDef("nose_twitch", (0.3, 0.6),  species_whitelist=frozenset({"rabbit"}), cooldown=5.0),
    "stand_lookout": BehaviourDef("stand_lookout",(1.5, 3.0), species_whitelist=frozenset({"rabbit","squirrel"}), cooldown=40.0),
    "snuffle_pause": BehaviourDef("snuffle_pause",(1.0, 2.0), species_whitelist=frozenset({"hedgehog"}), cooldown=30.0),
    "ball_up":       BehaviourDef("ball_up",     (2.0, 4.0),  species_whitelist=frozenset({"hedgehog"}), sleep_bias_weight=0.5, cooldown=120.0),
    "chitter":       BehaviourDef("chitter",     (0.8, 1.5),  species_whitelist=frozenset({"squirrel"}), particles=True, cooldown=35.0),
    "belly_roll":    BehaviourDef("belly_roll",  (2.0, 3.5),  species_whitelist=frozenset({"otter"}),    cooldown=90.0),
    "head_tuck":     BehaviourDef("head_tuck",   (2.0, 4.0),  species_whitelist=frozenset({"turtle"}),   sleep_bias_weight=0.4, cooldown=120.0),
    "bamboo_sit":    BehaviourDef("bamboo_sit",  (3.0, 6.0),  species_whitelist=frozenset({"panda"}),    sleep_bias_weight=0.3, cooldown=90.0),
    "panda_roll":    BehaviourDef("panda_roll",  (2.0, 3.5),  species_whitelist=frozenset({"panda"}),    cooldown=180.0),

    # ── Two-critter pair interactions (generic) ────────────────────────────
    "sniff":         BehaviourDef("sniff",        (0.8, 1.5),  is_pair=True, cooldown=25.0),
    "mutual_groom":  BehaviourDef("mutual_groom", (2.5, 4.0),  is_pair=True, sleep_bias_weight=0.2, cooldown=60.0),
    "play_bow":      BehaviourDef("play_bow",     (1.0, 2.0),  is_pair=True, cooldown=45.0),
    "stare_contest": BehaviourDef("stare_contest",(2.0, 4.0),  is_pair=True, cooldown=60.0),
    "bump_recoil":   BehaviourDef("bump_recoil",  (0.4, 0.7),  is_pair=True, cooldown=10.0),
    "apology_bow":   BehaviourDef("apology_bow",  (0.8, 1.2),  is_pair=True, cooldown=30.0),
    "sit_together":  BehaviourDef("sit_together", (3.0, 6.0),  is_pair=True, sleep_bias_weight=0.4, cooldown=90.0),

    # ── Species-pair interactions ──────────────────────────────────────────
    "predator_near_miss": BehaviourDef(
        "predator_near_miss", (1.5, 2.5), is_pair=True,
        pair_species_a=frozenset({"kitten"}), pair_species_b=frozenset({"rabbit"}),
        cooldown=120.0),
    "splash_play": BehaviourDef(
        "splash_play", (2.0, 3.0), is_pair=True, particles=True,
        pair_species_a=frozenset({"otter"}), pair_species_b=frozenset({"duck"}),
        cooldown=90.0),
    "hedgehog_defence": BehaviourDef(
        "hedgehog_defence", (2.0, 3.5), is_pair=True,
        pair_species_a=frozenset({"hedgehog"}), pair_species_b=frozenset({"kitten"}),
        cooldown=90.0),
    "panda_snuggle": BehaviourDef(
        "panda_snuggle", (3.0, 5.0), is_pair=True, sleep_bias_weight=0.3,
        pair_species_a=frozenset({"panda"}), pair_species_b=_U,
        cooldown=120.0),
    "kitten_tussle": BehaviourDef(
        "kitten_tussle", (1.5, 3.0), is_pair=True, particles=True,
        pair_species_a=frozenset({"kitten"}), pair_species_b=frozenset({"kitten"}),
        cooldown=60.0),
}

# Solo idle names for fast lookup
_SOLO_NAMES = frozenset(name for name, b in REGISTRY.items() if not b.is_pair)
_PAIR_NAMES  = frozenset(name for name, b in REGISTRY.items() if b.is_pair)

# Universal solo idles (no whitelist restriction)
_UNIVERSAL_SOLO = frozenset(
    name for name, b in REGISTRY.items()
    if not b.is_pair and not b.species_whitelist
)


# ---------------------------------------------------------------------------
# Helper: can an animal perform a solo idle?
# ---------------------------------------------------------------------------

def _eligible_solo(animal: "Animal", sleep_bias: float) -> list[tuple[str, float]]:
    """Return [(name, weight)] of behaviours this animal can currently do."""
    species  = getattr(animal, "SPECIES", "")
    whitelist = getattr(animal, "IDLE_WHITELIST", None)

    out: list[tuple[str, float]] = []
    for name, bdef in REGISTRY.items():
        if bdef.is_pair:
            continue
        # Species restriction
        if bdef.species_whitelist and species not in bdef.species_whitelist:
            continue
        # Per-species whitelist on the animal class
        if whitelist is not None and name not in whitelist:
            continue
        # Cooldown
        if animal._behaviour_cooldowns.get(name, 0.0) > 0.0:
            continue
        weight = 1.0 + bdef.sleep_bias_weight * sleep_bias
        out.append((name, weight))
    return out


# ---------------------------------------------------------------------------
# Helper: can two animals perform a pair interaction?
# ---------------------------------------------------------------------------

def _species_matches(sp: str, required: frozenset) -> bool:
    return not required or sp in required


def _eligible_pair(a: "Animal", b: "Animal") -> list[tuple[str, float]]:
    """Return [(name, weight)] of pair behaviours compatible with species a & b."""
    sp_a = getattr(a, "SPECIES", "")
    sp_b = getattr(b, "SPECIES", "")
    out: list[tuple[str, float]] = []
    for name, bdef in REGISTRY.items():
        if not bdef.is_pair:
            continue
        if a._behaviour_cooldowns.get(name, 0.0) > 0.0:
            continue
        if b._behaviour_cooldowns.get(name, 0.0) > 0.0:
            continue
        # Check species compatibility (either ordering)
        ok_ab = (_species_matches(sp_a, bdef.pair_species_a) and
                 _species_matches(sp_b, bdef.pair_species_b))
        ok_ba = (_species_matches(sp_b, bdef.pair_species_a) and
                 _species_matches(sp_a, bdef.pair_species_b))
        if not (ok_ab or ok_ba):
            continue
        out.append((name, 1.0))
    return out


# ---------------------------------------------------------------------------
# Enter/exit helpers (called by evaluator; animal state managed by Animal)
# ---------------------------------------------------------------------------

def enter_solo(animal: "Animal", name: str) -> None:
    bdef     = REGISTRY[name]
    duration = random.uniform(*bdef.duration)
    animal.enter_behaviour(name, duration)


def enter_pair(a: "Animal", b: "Animal", name: str) -> None:
    bdef     = REGISTRY[name]
    duration = random.uniform(*bdef.duration)
    # Face each other
    if b.x > a.x:
        a.direction =  1
        b.direction = -1
    else:
        a.direction = -1
        b.direction =  1
    a.enter_behaviour(name, duration, partner=b)
    b.enter_behaviour(name, duration, partner=a)


# ---------------------------------------------------------------------------
# Evaluator
# ---------------------------------------------------------------------------

_PROXIMITY = 90   # pixels — pair-interaction trigger radius
_MAX_BEHAVING_FRACTION = 0.25


class BehaviourEvaluator:
    """Runs once per second; picks new solo idles and pair interactions."""

    def __init__(self) -> None:
        self._acc = 0.0   # seconds since last evaluation

    def tick(self, dt: float, animals: list["Animal"],
             activity_scalar: float, sleep_bias: float, config: dict) -> None:
        self._acc += dt
        if self._acc < 1.0:
            return
        self._acc = 0.0
        self._evaluate(animals, activity_scalar, sleep_bias, config)

    def _evaluate(self, animals: list["Animal"],
                  activity_scalar: float, sleep_bias: float, config: dict) -> None:
        if not animals:
            return

        behaviour_cfg  = config.get("behaviour", {})
        freq_mult      = float(behaviour_cfg.get("behaviour_frequency", 1.0))
        interactions   = behaviour_cfg.get("interactions_enabled", True)

        # Advance cooldowns (1s per tick)
        for a in animals:
            _tick_cooldowns(a, 1.0)

        # Count currently behaving animals
        behaving = sum(
            1 for a in animals
            if getattr(a, "behaviour_name", None) is not None
        )
        max_behaving = max(1, int(len(animals) * _MAX_BEHAVING_FRACTION))

        # ── Solo idle evaluation ──────────────────────────────────────────
        # base_chance: 0.05 per tick modified by activity scalar and frequency
        base_chance = 0.05 * activity_scalar * freq_mult

        for a in animals:
            if not _can_enter_behaviour(a):
                continue
            if behaving >= max_behaving:
                break
            if random.random() > base_chance:
                continue
            options = _eligible_solo(a, sleep_bias)
            if not options:
                continue
            names, weights = zip(*options)
            chosen = random.choices(names, weights=weights, k=1)[0]
            enter_solo(a, chosen)
            behaving += 1

        # ── Pair interaction evaluation ───────────────────────────────────
        if not interactions:
            return
        if behaving >= max_behaving:
            return

        # Scan alive, non-behaving critters for proximity pairs
        candidates = [a for a in animals if _can_enter_behaviour(a)]
        # Shuffle so the same pair doesn't always win
        random.shuffle(candidates)

        picked_this_tick: set[int] = set()
        for i, a in enumerate(candidates):
            if id(a) in picked_this_tick:
                continue
            for b in candidates[i + 1:]:
                if id(b) in picked_this_tick:
                    continue
                dist = math.hypot(a.x - b.x, a.y - b.y)
                if dist > _PROXIMITY:
                    continue
                options = _eligible_pair(a, b)
                if not options:
                    continue
                names, weights = zip(*options)
                chosen = random.choices(names, weights=weights, k=1)[0]
                enter_pair(a, b, chosen)
                picked_this_tick.add(id(a))
                picked_this_tick.add(id(b))
                behaving += 2
                if behaving >= max_behaving:
                    return
                break   # a is paired; move to next candidate


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _can_enter_behaviour(a: "Animal") -> bool:
    """True if the animal is free to start a new behaviour."""
    if not a.alive:
        return False
    if a.being_dragged or a.thrown:
        return False
    behaving_state = getattr(a, "BEHAVING", "behaving")
    scattered_state = getattr(a, "SCATTERED", "scattered")
    popping_state   = getattr(a, "POPPING", "popping")
    if a.state in (behaving_state, scattered_state, popping_state):
        return False
    if getattr(a, "behaviour_name", None) is not None:
        return False
    return True


def _tick_cooldowns(a: "Animal", dt: float) -> None:
    cds = getattr(a, "_behaviour_cooldowns", None)
    if cds is None:
        return
    to_remove = [k for k, v in cds.items() if v <= dt]
    for k in to_remove:
        del cds[k]
    for k in list(cds):
        cds[k] -= dt
