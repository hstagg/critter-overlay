"""Critter Overlay v3 focus economy: a Monte Carlo balance model.

Simulates light, medium and heavy players minute by minute over many weeks
and reports what the game design rules (docs/v3-launch-plan.md, G1) target:
how long the 24 everyday Collection slots and the 10 Legendary colours take,
when the first Legendary comes, berries per week, and how much focus each
shop price costs.

The game's numbers are read from the game itself (godot/economy.gd, wear.gd,
settings.gd and the visitors' VARIANTS), so the model cannot drift from it.
Overrides for trying changes before making them:

    python tools/economy_sim.py
    python tools/economy_sim.py --seeds 40 --weeks 104
    python tools/economy_sim.py --set legendary=0.002 --set roll_every=6
    python tools/economy_sim.py --set variants=flat     # every colour equally likely

What it leaves out: Spawn now and treats (both cost berries), the lucky
charm (bought late, it shortens only the tail), timer mode, and presents
brought by visitors.
"""
from __future__ import annotations

import argparse
import random
import re
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "godot"


def _const(text: str, name: str) -> str:
    m = re.search(rf"^const {name}\s*:?=\s*(.+?)(?:\s*#.*)?$", text, re.M)
    if not m:
        raise SystemExit(f"economy_sim: no const {name}")
    return m.group(1).strip()


def _num(text: str, name: str) -> float:
    # A number constant, which may be a little sum like 5 * 60.
    expr = _const(text, name)
    if not re.fullmatch(r"[\d.\s*+/-]+", expr):
        raise SystemExit(f"economy_sim: {name} is not a number: {expr}")
    return float(eval(expr, {"__builtins__": {}}))


def _variants(path: Path) -> list[tuple[str, float]]:
    text = path.read_text(encoding="utf-8")
    m = re.search(r"const VARIANTS := \[(.*?)\n\]|const VARIANTS := \[(.*?)\]$", text, re.S | re.M)
    body = m.group(1) or m.group(2)
    return [(n, float(w)) for n, w in re.findall(r'\["(\w+)",\s*([\d.]+)\]', body)]


def load_game() -> dict:
    eco = (ROOT / "economy.gd").read_text(encoding="utf-8")
    wear = (ROOT / "wear.gd").read_text(encoding="utf-8")
    sett = (ROOT / "settings.gd").read_text(encoding="utf-8")
    main = (ROOT / "main.gd").read_text(encoding="utf-8")
    odds = dict(re.findall(r'"(\w+)":\s*([\d.]+)', _const(eco, "BASE_ODDS")))
    focus = re.search(r'"focus": \{(.*?)\}', sett, re.S).group(1)
    fset = {k: float(v) for k, v in re.findall(r'"(\w+)":\s*([\d.]+)', focus)}
    return {
        "odds": {k: float(v) for k, v in odds.items()},
        "first_bonus": {k: float(v) for k, v in re.findall(r'"(\w+)":\s*([\d.]+)', _const(eco, "FIRST_BONUS_ODDS"))},
        "berries_per_min": _num(eco, "BERRIES_PER_MIN"),
        "daily_full_min": _num(eco, "DAILY_FULL_MIN"),
        "daily_taper": _num(eco, "DAILY_TAPER"),
        "first_session": _num(eco, "FIRST_SESSION_BERRIES"),
        "gifts": [[float(a), float(b)] for a, b, _ in re.findall(r"\[(\d+), (\d+), ([\d.]+)\]", _const(eco, "GIFTS"))],
        "welcome": _num(eco, "WELCOME_BERRIES"),
        "welcome_min": _num(eco, "WELCOME_MIN_S") / 60.0,
        "session_end_min": _num(eco, "SESSION_END_S") / 60.0,
        "luck_max": _num(eco, "LUCK_MAX"),
        "luck_full_min": _num(eco, "LUCK_FULL_MIN"),
        "luck_kept": _num(eco, "LUCK_KEPT"),
        "first_find": {k: float(v) for k, v in re.findall(r'"(\w+)":\s*(\d+)', _const(eco, "FIRST_FIND"))},
        "row_bonus": _num(eco, "ROW_BONUS"),
        "roll_every": _num(eco, "ROLL_EVERY_MIN"),
        "roll_max": _num(eco, "ROLL_BANK_MAX"),
        "spawn_price": _num(eco, "SPAWN_PRICE"),
        "rare_hour_boost": 2.0,
        "rare_hour_start": float(re.search(r'"rare_hour_start":\s*(\d+)', sett).group(1)),
        "prices": {k: float(v) for k, v in re.findall(r'"(\w+)":\s*(\d+)', _const(wear, "PRICES"))},
        "dye": _num(wear, "DYE_PRICE"),
        "treat": _num(wear, "TREAT_PRICE"),
        "gather_every": fset["gather_every_min"],
        "solo_every": fset["solo_every_min"],
        "max_out": fset["max_out"],
        "start_with": fset["start_with"],
        "stay": (_num(main, "STAY_MIN") / 60.0, _num(main, "STAY_MAX") / 60.0),
        "species": ["kitten", "rabbit", "duckling", "hedgehog", "turtle", "squirrel", "otter", "panda"],
        "visits": {"kitten": 3.0},  # Settings.VISITS: kitten "often" (3), the rest "normal" (1)
        "visitors": {"unicorn": _variants(ROOT / "critters" / "unicorn.gd"),
                     "golden_kitten": _variants(ROOT / "critters" / "golden_kitten.gd")},
    }


# Who plays: focus hours a day, days a week.
PROFILES = {"light": (1.5, 4), "medium": (4.0, 5), "heavy": (7.0, 6)}


def simulate(g: dict, hours: float, days: int, weeks: int, rng: random.Random) -> dict:
    tiers = ["common", "rare", "epic", "legendary"]
    everyday = {f"{sp}:{t}" for sp in g["species"] for t in tiers[:3]}
    colours = {f"{v}:{n}" for v, vs in g["visitors"].items() for n, _ in vs}
    found: set[str] = set()
    berries = 0.0
    bank = 1.0
    t_everyday = t_colours = t_first_leg = None
    focus_total = 0.0
    late_berries = late_focus = 0.0   # after week 8: the steady rate, past the first-find burst
    week_of = lambda d: d / 7.0
    afford_at: dict[str, float] = {}
    goals = {**{k: v for k, v in g["prices"].items()}, "dye": g["dye"], "treat": g["treat"], "spawn": g["spawn_price"]}
    weights = [g["visits"].get(sp, 1.0) for sp in g["species"]]

    def roll(luck: float, rare_hour: bool, first: bool) -> tuple[str, str]:
        if first:
            r, acc, tier = rng.random(), 0.0, "legendary"
            for t, p in g["first_bonus"].items():
                acc += p
                if r < acc:
                    tier = t
                    break
        else:
            lk = luck * (g["rare_hour_boost"] if rare_hour else 1.0)
            p = {t: g["odds"][t] * lk for t in tiers[1:]}
            r, acc, tier = rng.random(), 0.0, "common"
            for t in ("legendary", "epic", "rare"):
                acc += p[t]
                if r < acc:
                    tier = t
                    break
        if tier == "legendary":
            v = rng.choice(list(g["visitors"]))
            names, ws = zip(*g["visitors"][v])
            return v, f"legendary:{rng.choices(names, ws)[0]}"
        sp = rng.choices(g["species"], weights)[0] if tier == "common" else rng.choice(g["species"])
        return sp, tier

    for day in range(weeks * 7):
        if day % 7 >= days:
            continue
        start_berries = berries
        # The day: focus blocks of 45-90 min, short breaks of 5-15 min, one
        # lunch of 40-60 min near the middle; starting at nine.
        minute = 9 * 60.0
        left = hours * 60.0
        session = 0.0
        next_gift = 0
        day_min = 0.0
        paid_first = False
        desk: list[float] = []
        next_arrival = g["gather_every"]
        next_solo = g["solo_every"]
        focus_today = 0.0
        lunch_done = hours < 3.0
        first_roll = True

        def arrive(sp_tier=None):
            nonlocal bank, first_roll, t_everyday, t_colours, t_first_leg, berries
            if bank >= 1.0:
                bank -= 1.0
                rare_hour = g["rare_hour_start"] * 60 <= minute < g["rare_hour_start"] * 60 + 60
                luck = 1.0 + (g["luck_max"] - 1.0) * (1.0 - (1.0 - min(session / g["luck_full_min"], 1.0)) ** 2)
                sp, tier = roll(luck, rare_hour, first_roll)
                first_roll = False
            else:
                sp, tier = rng.choices(g["species"], weights)[0], "common"
            key = f"{sp}:{tier}"
            if key not in found:
                found.add(key)
                berries += g["first_find"]["legendary" if tier.startswith("legendary") else tier]
                if sp in g["visitors"]:
                    if all(f"{sp}:legendary:{n}" in found for n, _ in g["visitors"][sp]):
                        berries += g["row_bonus"]
                    if t_first_leg is None:
                        t_first_leg = week_of(day)
                elif all(f"{sp}:{t}" in found for t in tiers[:3]):
                    berries += g["row_bonus"]
            if t_everyday is None and everyday <= found:
                t_everyday = week_of(day)
            if t_colours is None and colours <= {k.replace(":legendary", "") for k in found if ":legendary:" in k}:
                t_colours = week_of(day)
            desk.append(rng.uniform(*g["stay"]))

        while left > 0:
            block = min(left, rng.uniform(45, 90))
            for _ in range(int(block)):
                if not paid_first:
                    paid_first = True
                    berries += g["first_session"]
                    for _i in range(int(g["start_with"])):
                        arrive()
                rate = g["berries_per_min"] if day_min < g["daily_full_min"] else g["berries_per_min"] * g["daily_taper"]
                berries += rate
                day_min += 1.0
                session += 1.0 if day_min < g["daily_full_min"] else g["daily_taper"]
                bank = min(g["roll_max"], bank + 1.0 / g["roll_every"])
                while next_gift < len(g["gifts"]) and session >= g["gifts"][next_gift][0]:
                    berries += g["gifts"][next_gift][1]
                    next_gift += 1
                desk[:] = [s - 1.0 for s in desk if s > 1.0]
                focus_today += 1.0
                if focus_today >= next_arrival:
                    next_arrival += g["gather_every"]
                    if len(desk) < g["max_out"]:
                        arrive()
                if focus_today >= next_solo:
                    next_solo += g["solo_every"]
                    if len(desk) < g["max_out"]:
                        arrive()
                minute += 1.0
                focus_total += 1.0
                if day >= 56:
                    late_focus += 1.0
                for k, price in goals.items():
                    if k not in afford_at and berries >= price:
                        afford_at[k] = focus_total / 60.0
            left -= block
            if left <= 0:
                break
            brk = rng.uniform(40, 60) if not lunch_done and minute >= 12 * 60 else rng.uniform(5, 15)
            if brk >= 40:
                lunch_done = True
            minute += brk
            if brk >= g["session_end_min"]:
                session *= g["luck_kept"]
            elif brk >= g["welcome_min"]:
                berries += g["welcome"]
        if day >= 56:
            late_berries += berries - start_berries
    return {"everyday": t_everyday, "colours": t_colours, "first_leg": t_first_leg,
            "berries_week": berries / weeks, "afford_h": afford_at, "focus_h_week": focus_total / 60.0 / weeks,
            "steady_per_h": late_berries / max(late_focus / 60.0, 1e-9)}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--seeds", type=int, default=30)
    ap.add_argument("--weeks", type=int, default=104)
    ap.add_argument("--set", action="append", default=[], help="key=value: odds rare/epic/legendary, roll_every, variants=flat")
    a = ap.parse_args()
    g = load_game()
    for kv in a.set:
        k, v = kv.split("=")
        if k in ("rare", "epic", "legendary"):
            g["odds"][k] = float(v)
        elif k == "variants" and v == "flat":
            g["visitors"] = {n: [(c, 1.0) for c, _ in vs] for n, vs in g["visitors"].items()}
        elif k == "variants":
            # e.g. variants=sqrt: weights to the power 0.5, flattening the tail
            g["visitors"] = {n: [(c, w ** float(v)) for c, w in vs] for n, vs in g["visitors"].items()}
        else:
            g[k] = float(v)
    print(f"odds {g['odds']}, a roll per {g['roll_every']} focus min (bank {g['roll_max']:.0f}), "
          f"spawn {g['spawn_price']:.0f}, prices {g['prices']}, dye {g['dye']:.0f}, treat {g['treat']:.0f}")
    def med(xs, cap):
        xs = [x if x is not None else cap + 1 for x in xs]
        q = statistics.quantiles(xs, n=10) if len(xs) > 2 else xs
        fmt = lambda x: f">{cap}" if x > cap else f"{x:.1f}"
        return f"{fmt(statistics.median(xs))} (p10 {fmt(q[0])}, p90 {fmt(q[-1])})"
    for name, (hours, days) in PROFILES.items():
        runs = [simulate(g, hours, days, a.weeks, random.Random(s)) for s in range(a.seeds)]
        print(f"\n{name}: {hours} h/day, {days} days/week ({statistics.mean(r['focus_h_week'] for r in runs):.0f} focus h/week)")
        print(f"  24 everyday slots, weeks:   {med([r['everyday'] for r in runs], a.weeks)}")
        print(f"  10 Legendary colours, weeks: {med([r['colours'] for r in runs], a.weeks)}")
        print(f"  first Legendary, weeks:      {med([r['first_leg'] for r in runs], a.weeks)}")
        print(f"  berries a week:              {statistics.median(r['berries_week'] for r in runs):.0f}")
        rate = statistics.median(r["steady_per_h"] for r in runs)
        fh = statistics.mean(r["focus_h_week"] for r in runs)
        goals = {**g["prices"], "dye": g["dye"], "treat": g["treat"], "spawn": g["spawn_price"]}
        print(f"  steady berries per focus h:  {rate:.0f}")
        print("  steady cost (focus h, weeks): " + ", ".join(
            f"{k} {v / rate:.1f}h/{v / rate / fh:.1f}w" for k, v in sorted(goals.items(), key=lambda kv: kv[1])))


if __name__ == "__main__":
    main()
