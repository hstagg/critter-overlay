"""Critter Overlay focus economy: Monte Carlo balance model.

Simulates players with different working patterns over many weeks and reports
the numbers the design targets: time to first coin purchase, coins per hour,
how long the shop and the collection take, rare and legendary sighting rates,
and how much a break costs (it should cost nothing, or pay).

All tunables live in PARAMS so a beta can be refit from telemetry.
"""
from __future__ import annotations

import json
import random
import statistics
import sys
from dataclasses import dataclass, field

PARAMS = {
    # Presence
    "away_after_min": 3,          # idle minutes before critters nap
    "session_ends_after_min": 30, # away this long closes the session (banked, never lost)
    "luck_kept_after_long_break": 0.5,  # luck decays, never zeroes
    # Coins
    "coins_per_min": 1.0,
    "daily_full_rate_min": 300,   # full rate for the first 5 h of focus a day
    "daily_taper_rate": 0.25,     # then a quarter rate (anti-farm, anti-overwork)
    # Session gifts (minutes of session focus): coins and a chance of an item
    "gifts": [[25, 15, 0.10], [50, 30, 0.20], [90, 60, 0.35], [150, 90, 0.50]],
    "gift_pity": 6,               # an item is guaranteed by the 6th gift without one
    "rested_bonus_coins": 5,      # coming back from a 5 to 30 min break
    "first_session_of_day_coins": 10,
    # Luck: a multiplier on rare+ odds, rising with session focus time
    "luck_start": 1.0,
    "luck_max": 3.0,
    "luck_minutes_to_max": 120,
    # Arrivals
    "arrival_every_min": 12,      # a new visitor (and a rarity roll) every 12 min; visitors stay ~40 min then leave
    "max_out": 8,
    # Rarity base odds per arrival (v2.0's table)
    "tiers": {"common": 0.904, "uncommon": 0.07, "rare": 0.02, "epic": 0.005, "legendary": 0.001},
    "species": 10,
    "capped_species": 2,          # turtle and panda stop at epic
    # Shop
    "shop": {"small": [20, 50], "medium": [30, 400], "large": [15, 1200], "showpiece": [6, 4000]},
    "gift_item_pool": 40,         # items only found in gifts
}

PLAYERS = {
    # name: (work days per week, focus hours per work day (mean, sd), mean break every N min, break length min (lo, hi))
    "light":  (4, (1.5, 0.7), 40, (5, 20)),
    "medium": (5, (4.0, 1.0), 50, (5, 25)),
    "heavy":  (6, (7.0, 1.2), 70, (5, 30)),
}


@dataclass
class State:
    coins: float = 0.0
    spent: float = 0.0
    owned_shop: int = 0
    gift_items: set = field(default_factory=set)
    seen: set = field(default_factory=set)       # (species, tier)
    first_purchase_min: float | None = None
    total_focus_min: float = 0.0
    rares: int = 0
    legendaries: int = 0
    gifts_since_item: int = 0


def luck(p, session_min: float) -> float:
    f = min(1.0, session_min / p["luck_minutes_to_max"])
    # ease-out: most of the gain in the first hour
    f = 1 - (1 - f) ** 2
    return p["luck_start"] + (p["luck_max"] - p["luck_start"]) * f


def roll_tier(p, rng, lk: float) -> str:
    base = p["tiers"]
    boosted = {t: v * (lk if t in ("rare", "epic", "legendary") else 1.0) for t, v in base.items()}
    rest = sum(v for t, v in boosted.items() if t != "common")
    boosted["common"] = max(0.0, 1.0 - rest)
    r = rng.random()
    acc = 0.0
    for t, v in boosted.items():
        acc += v
        if r < acc:
            return t
    return "common"


def shop_prices(p):
    out = []
    for _, (n, price) in p["shop"].items():
        out += [price] * n
    return sorted(out)


def simulate(p, player, weeks: int, rng) -> State:
    days_per_week, (h_mu, h_sd), break_every, (b_lo, b_hi) = PLAYERS[player]
    s = State()
    prices = shop_prices(p)
    collectable = p["species"] * 5 - p["capped_species"]
    for week in range(weeks):
        for day in range(7):
            if day >= days_per_week:
                continue
            focus_today = max(0.25, rng.gauss(h_mu, h_sd)) * 60
            done_today = 0.0
            session = 0.0   # overnight
            next_gift = 0
            first = True
            while focus_today - done_today >= 1:
                block = max(1.0, min(rng.expovariate(1 / break_every), focus_today - done_today))
                for _ in range(int(block)):
                    rate = p["coins_per_min"] if done_today < p["daily_full_rate_min"] else p["coins_per_min"] * p["daily_taper_rate"]
                    s.coins += rate
                    done_today += 1
                    session += 1
                    s.total_focus_min += 1
                    if first:
                        s.coins += p["first_session_of_day_coins"]
                        first = False
                    if int(session) % p["arrival_every_min"] == 0:
                        lk = luck(p, session) if done_today < p["daily_full_rate_min"] else 1.0 + (luck(p, session) - 1.0) * p["daily_taper_rate"]
                        t = roll_tier(p, rng, lk)
                        sp = rng.randrange(p["species"])
                        if sp < p["capped_species"] and t == "legendary":
                            t = "epic"
                        s.seen.add((sp, t))
                        s.rares += t in ("rare", "epic", "legendary")
                        s.legendaries += t == "legendary"
                    while next_gift < len(p["gifts"]) and session >= p["gifts"][next_gift][0]:
                        _, c, chance = p["gifts"][next_gift]
                        s.coins += c
                        s.gifts_since_item += 1
                        if rng.random() < chance or s.gifts_since_item >= p["gift_pity"]:
                            s.gift_items.add(rng.randrange(p["gift_item_pool"]))
                            s.gifts_since_item = 0
                        next_gift += 1
                    # buy the cheapest thing not yet owned when affordable
                    while s.owned_shop < len(prices) and s.coins >= prices[s.owned_shop]:
                        s.coins -= prices[s.owned_shop]
                        s.spent += prices[s.owned_shop]
                        s.owned_shop += 1
                        if s.first_purchase_min is None:
                            s.first_purchase_min = s.total_focus_min
                brk = rng.uniform(b_lo, b_hi)
                if brk >= p["session_ends_after_min"]:
                    session = session * p["luck_kept_after_long_break"]
                    next_gift = 0
                    while next_gift < len(p["gifts"]) and session >= p["gifts"][next_gift][0]:
                        next_gift += 1
                elif brk >= 5:
                    s.coins += p["rested_bonus_coins"]
    s.collectable = collectable
    return s


def report(p, runs=30, weeks=12, seed=1):
    rng = random.Random(seed)
    out = {}
    total_shop = sum(n * c for n, c in p["shop"].values())
    n_shop = sum(n for n, _ in p["shop"].values())
    for player in PLAYERS:
        res = [simulate(p, player, weeks, rng) for _ in range(runs)]
        hours = statistics.mean(r.total_focus_min for r in res) / 60
        out[player] = {
            "focus_h_per_week": round(hours / weeks, 1),
            "first_purchase_min": round(statistics.median(r.first_purchase_min or 1e9 for r in res)),
            "coins_per_focus_h": round(statistics.mean((r.spent + r.coins) / (r.total_focus_min / 60) for r in res), 1),
            f"shop_owned_after_{weeks}w": f"{statistics.mean(r.owned_shop for r in res):.0f}/{n_shop}",
            f"gift_items_after_{weeks}w": f"{statistics.mean(len(r.gift_items) for r in res):.0f}/{p['gift_item_pool']}",
            f"collection_after_{weeks}w": f"{statistics.mean(len(r.seen) for r in res):.0f}/{res[0].collectable}",
            "rares_per_week": round(statistics.mean(r.rares for r in res) / weeks, 1),
            "legendaries_per_month": round(statistics.mean(r.legendaries for r in res) / weeks * 4.33, 2),
        }
    out["_shop_total_coins"] = total_shop
    return out


if __name__ == "__main__":
    p = dict(PARAMS)
    if len(sys.argv) > 1:
        p.update(json.loads(open(sys.argv[1]).read()))
    print(json.dumps(report(p), indent=1))
