"""Clothes for the critters: one SVG per item per species, fitted to each
head, written to godot/art/wear/<item>/<species>.svg.

Every file is drawn in the species' own 300 x 280 part frame (the same
coordinates as its head.svg), so the rig hangs it on the head pivot and it
rides every pose. Run: python design/wear/build.py
"""
import math
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[2] / "godot" / "art" / "wear"
LINE = "#6B4A3A"
W = 4  # outline width, as the critter art

# Head metrics in SVG units (from each species' head.svg, eyes.svg, ears).
SPECIES = {
    "kitten": dict(cx=150, cy=122, rx=92, ry=74, eye_y=124, eye_dx=38, eye_r=18, chin=196,
                   gap=(122, 178), side=1.0),
    "rabbit": dict(cx=150, cy=142, rx=78, ry=62, eye_y=142, eye_dx=28, eye_r=16, chin=204,
                   gap=(142, 158), side=0.9),
    "duckling": dict(cx=150, cy=128, rx=72, ry=72, eye_y=132, eye_dx=30, eye_r=17, chin=200,
                     gap=(132, 168), side=0.85),
}


def svg(body):
    # 120 units of headroom above the part frame, for tall hats (the rig
    # offsets by the same, see critter.gd wear()).
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -120 300 400" width="300" height="400">'
            + body + '</svg>')


def top(m, x):
    """y of the head's outline at x (upper half of its ellipse)."""
    dx = (x - m["cx"]) / m["rx"]
    return m["cy"] - m["ry"] * math.sqrt(max(0.0, 1 - dx * dx))


def star(cx, cy, r, fill, stroke=LINE, sw=3, rot=0):
    pts = []
    for i in range(10):
        a = math.radians(rot - 90 + i * 36)
        rr = r if i % 2 == 0 else r * 0.45
        pts.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return f'<polygon points="{" ".join(pts)}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>'


# --- Items -----------------------------------------------------------------------

def bow(m):
    # A pink ribbon bow on the right of the head, tilted.
    x = m["cx"] + m["rx"] * 0.42
    y = top(m, x) + 10
    return svg(f'<g transform="translate({x:.1f} {y:.1f}) rotate(18)">'
               f'<path d="M0 0 C -14 -18 -34 -16 -32 0 C -34 16 -14 18 0 0 Z" fill="#F7A8C4" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
               f'<path d="M0 0 C 14 -18 34 -16 32 0 C 34 16 14 18 0 0 Z" fill="#F7A8C4" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
               f'<path d="M-22 -4 C -16 -6 -10 -4 -6 -1 M22 -4 C 16 -6 10 -4 6 -1" stroke="#E07BA0" stroke-width="3" fill="none" stroke-linecap="round"/>'
               f'<circle cx="0" cy="0" r="8" fill="#F28DB2" stroke="{LINE}" stroke-width="{W}"/></g>')


def bell_collar(m):
    # A red band under the chin, curving with it, and a gold bell.
    cx, y = m["cx"], m["chin"] - 6
    half = m["rx"] * 0.55
    band = (f'<path d="M{cx - half:.1f} {y - 6:.1f} Q {cx} {y + 16:.1f} {cx + half:.1f} {y - 6:.1f}" '
            f'stroke="{LINE}" stroke-width="{14 + 2 * W}" fill="none" stroke-linecap="round"/>'
            f'<path d="M{cx - half:.1f} {y - 6:.1f} Q {cx} {y + 16:.1f} {cx + half:.1f} {y - 6:.1f}" '
            f'stroke="#E2554F" stroke-width="14" fill="none" stroke-linecap="round"/>')
    by = y + 14
    bell = (f'<circle cx="{cx}" cy="{by}" r="11" fill="#FFCF5C" stroke="{LINE}" stroke-width="{W}"/>'
            f'<path d="M{cx - 7} {by + 2} H {cx + 7}" stroke="{LINE}" stroke-width="3" stroke-linecap="round"/>'
            f'<circle cx="{cx}" cy="{by + 6}" r="2.5" fill="{LINE}"/>'
            f'<circle cx="{cx - 4}" cy="{by - 4}" r="2.5" fill="#FFF4CC"/>')
    return svg(band + bell)


def flower_clip(m):
    # A white daisy with a yellow middle, on the left of the head.
    x = m["cx"] - m["rx"] * 0.46
    y = top(m, x) + 12
    petals = "".join(
        f'<ellipse cx="{x + 13 * math.cos(math.radians(a)):.1f}" cy="{y + 13 * math.sin(math.radians(a)):.1f}" rx="9" ry="7" '
        f'transform="rotate({a} {x + 13 * math.cos(math.radians(a)):.1f} {y + 13 * math.sin(math.radians(a)):.1f})" '
        f'fill="#FFFFFF" stroke="{LINE}" stroke-width="3"/>' for a in range(-90, 270, 72))
    return svg(petals + f'<circle cx="{x:.1f}" cy="{y:.1f}" r="8" fill="#FFD84D" stroke="{LINE}" stroke-width="3"/>')


def glasses(m):
    # Round glasses over the eyes, thin arms to the sides of the head.
    y = m["eye_y"]
    r = m["eye_r"] + 9
    lx, rx_ = m["cx"] - m["eye_dx"], m["cx"] + m["eye_dx"]
    lens = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#DDEEFF" fill-opacity="0.35" stroke="{LINE}" stroke-width="{W + 1}"/>'
                   f'<path d="M{x - r * 0.45:.1f} {y - r * 0.5:.1f} q {r * 0.25:.1f} {-r * 0.18:.1f} {r * 0.5:.1f} {-r * 0.12:.1f}" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>'
                   for x in (lx, rx_))
    bridge = f'<path d="M{lx + r:.1f} {y - 2} Q {m["cx"]} {y - 10} {rx_ - r:.1f} {y - 2}" stroke="{LINE}" stroke-width="{W}" fill="none" stroke-linecap="round"/>'
    arms = (f'<path d="M{lx - r:.1f} {y - 4} L {m["cx"] - m["rx"] + 6:.1f} {y - 10}" stroke="{LINE}" stroke-width="{W}" stroke-linecap="round"/>'
            f'<path d="M{rx_ + r:.1f} {y - 4} L {m["cx"] + m["rx"] - 6:.1f} {y - 10}" stroke="{LINE}" stroke-width="{W}" stroke-linecap="round"/>')
    return svg(arms + bridge + lens)


def beanie(m):
    # A knitted dome over the top of the head, ribbed brim, pompom.
    cx = m["cx"]
    hw = m["rx"] * 0.78
    brim_y = top(m, cx) + m["ry"] * 0.38
    dome_top = top(m, cx) - 22
    dome = (f'<path d="M{cx - hw:.1f} {brim_y:.1f} C {cx - hw:.1f} {dome_top + 6:.1f} {cx - hw * 0.4:.1f} {dome_top:.1f} {cx} {dome_top:.1f} '
            f'C {cx + hw * 0.4:.1f} {dome_top:.1f} {cx + hw:.1f} {dome_top + 6:.1f} {cx + hw:.1f} {brim_y:.1f} Z" '
            f'fill="#7FB3E8" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    knit = "".join(f'<path d="M{cx + dx:.1f} {brim_y - 4:.1f} Q {cx + dx * 0.9:.1f} {dome_top + 18:.1f} {cx + dx * 0.4:.1f} {dome_top + 6:.1f}" stroke="#5E95CF" stroke-width="3" fill="none" stroke-linecap="round"/>'
                   for dx in (-hw * 0.55, -hw * 0.18, hw * 0.18, hw * 0.55))
    brim = (f'<rect x="{cx - hw - 6:.1f}" y="{brim_y - 12:.1f}" width="{2 * hw + 12:.1f}" height="22" rx="11" fill="#F3F7FC" stroke="{LINE}" stroke-width="{W}"/>'
            + "".join(f'<path d="M{x:.1f} {brim_y - 7:.1f} v 12" stroke="#C9D8EA" stroke-width="3" stroke-linecap="round"/>'
                      for x in [cx - hw + i * (2 * hw) / 9 for i in range(1, 9)]))
    pom = f'<circle cx="{cx}" cy="{dome_top - 6:.1f}" r="14" fill="#F3F7FC" stroke="{LINE}" stroke-width="{W}"/>'
    return svg(dome + knit + brim + pom)


def scarf(m):
    # A striped knitted scarf round the neck with one tail hanging.
    cx, y = m["cx"], m["chin"] - 4
    half = m["rx"] * 0.62
    wrap = (f'<path d="M{cx - half:.1f} {y - 10:.1f} Q {cx} {y + 22:.1f} {cx + half:.1f} {y - 10:.1f} L {cx + half - 4:.1f} {y + 8:.1f} '
            f'Q {cx} {y + 40:.1f} {cx - half + 4:.1f} {y + 8:.1f} Z" fill="#E86A5C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    stripes = "".join(f'<path d="M{cx + dx:.1f} {y + 4 + abs(dx) * -0.12 + 10:.1f} l 4 -14" stroke="#FFF1E2" stroke-width="5" stroke-linecap="round"/>'
                      for dx in (-half * 0.6, -half * 0.2, half * 0.2, half * 0.6))
    tx = cx + half * 0.45
    tail = (f'<path d="M{tx - 12:.1f} {y + 18:.1f} L {tx + 12:.1f} {y + 18:.1f} L {tx + 16:.1f} {y + 58:.1f} L {tx - 6:.1f} {y + 60:.1f} Z" '
            f'fill="#E86A5C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
            f'<path d="M{tx - 9:.1f} {y + 34:.1f} H {tx + 13:.1f}" stroke="#FFF1E2" stroke-width="5" stroke-linecap="round"/>'
            f'<path d="M{tx - 6:.1f} {y + 60:.1f} l -2 7 M{tx + 2:.1f} {y + 60:.1f} l 0 8 M{tx + 10:.1f} {y + 59:.1f} l 2 7" stroke="{LINE}" stroke-width="3" stroke-linecap="round"/>')
    return svg(tail + wrap + stripes)


def party_hat(m):
    # A striped cone, tilted a little, with a pompom.
    cx = m["cx"] + 6
    base = top(m, cx) + 8
    h, w = 74 * m["side"], 34 * m["side"]
    g = f'<g transform="rotate(-10 {cx} {base:.1f})">'
    cone = f'<path d="M{cx - w:.1f} {base:.1f} L {cx} {base - h:.1f} L {cx + w:.1f} {base:.1f} Q {cx} {base + 10:.1f} {cx - w:.1f} {base:.1f} Z" fill="#B59AF0" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    stripes = "".join(f'<path d="M{cx - w * f:.1f} {base - h * (1 - f):.1f} L {cx + w * f * 0.2:.1f} {base - h * (1 - f) - 6:.1f}" stroke="#FFCF5C" stroke-width="7" stroke-linecap="round"/>'
                      for f in (0.35, 0.62, 0.88))
    pom = f'<circle cx="{cx}" cy="{base - h - 4:.1f}" r="10" fill="#F590B4" stroke="{LINE}" stroke-width="{W}"/>'
    return svg(g + cone + stripes + pom + "</g>")


def bandana(m):
    # A blue kerchief tied under the chin, white polka dots.
    cx, y = m["cx"], m["chin"] - 8
    half = m["rx"] * 0.6
    tri = (f'<path d="M{cx - half:.1f} {y:.1f} Q {cx} {y + 12:.1f} {cx + half:.1f} {y:.1f} L {cx + 4:.1f} {y + 52:.1f} Q {cx} {y + 56:.1f} {cx - 4:.1f} {y + 52:.1f} Z" '
           f'fill="#5B8FD6" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    dots = "".join(f'<circle cx="{cx + dx:.1f}" cy="{y + dy:.1f}" r="3.6" fill="#FFFFFF"/>'
                   for dx, dy in ((-half * 0.5, 12), (-half * 0.1, 18), (half * 0.35, 12), (-half * 0.25, 32), (half * 0.15, 34), (0, 46)))
    knot = (f'<path d="M{cx + half - 6:.1f} {y - 2:.1f} l 16 -10 l 2 12 Z M{cx + half - 6:.1f} {y - 2:.1f} l 14 10 l -10 6 Z" '
            f'fill="#5B8FD6" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>')
    return svg(tri + dots + knot)


def strawberry_hat(m):
    # A red strawberry cap with seeds and a green leafy crown.
    cx = m["cx"]
    hw = m["rx"] * 0.82
    rim = top(m, cx) + m["ry"] * 0.42
    tip = top(m, cx) - 30
    cap = (f'<path d="M{cx - hw:.1f} {rim:.1f} C {cx - hw - 4:.1f} {tip + 18:.1f} {cx - hw * 0.4:.1f} {tip:.1f} {cx} {tip:.1f} '
           f'C {cx + hw * 0.4:.1f} {tip:.1f} {cx + hw + 4:.1f} {tip + 18:.1f} {cx + hw:.1f} {rim:.1f} Q {cx} {rim + 12:.1f} {cx - hw:.1f} {rim:.1f} Z" '
           f'fill="#F2575D" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    seeds = ""
    for i, (fx, fy) in enumerate(((-0.55, 0.62), (-0.2, 0.5), (0.2, 0.55), (0.55, 0.65), (-0.38, 0.85), (0.02, 0.8), (0.4, 0.86), (-0.05, 0.3), (0.32, 0.32), (-0.35, 0.36))):
        sx, sy = cx + fx * hw, tip + fy * (rim - tip)
        seeds += f'<ellipse cx="{sx:.1f}" cy="{sy:.1f}" rx="2.6" ry="4" fill="#FFE07A" transform="rotate({fx * 30:.0f} {sx:.1f} {sy:.1f})"/>'
    leaves = "".join(
        f'<path d="M{cx} {tip + 6:.1f} Q {cx + dx * 0.5:.1f} {tip - 18:.1f} {cx + dx:.1f} {tip - 4:.1f} Q {cx + dx * 0.6:.1f} {tip + 6:.1f} {cx} {tip + 6:.1f} Z" '
        f'fill="#6CC27A" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>' for dx in (-34, -16, 16, 34))
    stem = f'<path d="M{cx} {tip - 2:.1f} q 2 -14 10 -18" stroke="{LINE}" stroke-width="{W + 3}" fill="none" stroke-linecap="round"/><path d="M{cx} {tip - 2:.1f} q 2 -14 10 -18" stroke="#6CC27A" stroke-width="4" fill="none" stroke-linecap="round"/>'
    return svg(cap + seeds + stem + leaves)


def wizard_hat(m):
    # A tall indigo hat with a wide brim, a bent tip and gold stars.
    cx = m["cx"]
    brim_y = top(m, cx) + 14
    bw = m["rx"] * 0.95
    h = 96 * m["side"]
    brim = f'<ellipse cx="{cx}" cy="{brim_y:.1f}" rx="{bw:.1f}" ry="15" fill="#5A4BB8" stroke="{LINE}" stroke-width="{W}"/>'
    cone = (f'<path d="M{cx - 36:.1f} {brim_y - 2:.1f} C {cx - 26:.1f} {brim_y - h * 0.5:.1f} {cx - 8:.1f} {brim_y - h * 0.8:.1f} {cx + 6:.1f} {brim_y - h:.1f} '
            f'Q {cx + 30:.1f} {brim_y - h - 6:.1f} {cx + 34:.1f} {brim_y - h + 12:.1f} '
            f'Q {cx + 20:.1f} {brim_y - h + 8:.1f} {cx + 14:.1f} {brim_y - h * 0.7:.1f} C {cx + 22:.1f} {brim_y - h * 0.4:.1f} {cx + 30:.1f} {brim_y - 20:.1f} {cx + 36:.1f} {brim_y - 2:.1f} Z" '
            f'fill="#6A5AD0" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    band = f'<path d="M{cx - 34:.1f} {brim_y - 10:.1f} Q {cx} {brim_y - 2:.1f} {cx + 34:.1f} {brim_y - 10:.1f}" stroke="#FFCF5C" stroke-width="8" fill="none" stroke-linecap="round"/>'
    stars = star(cx - 8, brim_y - h * 0.38, 9, "#FFCF5C") + star(cx + 12, brim_y - h * 0.62, 6, "#FFF0C2", rot=15) + star(cx + 34, brim_y - h + 14, 5, "#FFCF5C")
    return svg(brim + cone + band + stars)


# id: (draw, name, slot, tier)
ITEMS = {
    "bow": (bow, "Ribbon bow", "head", "small"),
    "bell_collar": (bell_collar, "Bell collar", "neck", "small"),
    "flower_clip": (flower_clip, "Daisy clip", "head", "small"),
    "glasses": (glasses, "Round glasses", "face", "small"),
    "beanie": (beanie, "Bobble beanie", "head", "medium"),
    "scarf": (scarf, "Knitted scarf", "neck", "medium"),
    "party_hat": (party_hat, "Party hat", "head", "medium"),
    "bandana": (bandana, "Spotty bandana", "neck", "medium"),
    "strawberry_hat": (strawberry_hat, "Strawberry hat", "head", "large"),
    "wizard_hat": (wizard_hat, "Wizard hat", "head", "large"),
}


def main():
    for item, (draw, *_rest) in ITEMS.items():
        d = OUT / item
        d.mkdir(parents=True, exist_ok=True)
        for sp, m in SPECIES.items():
            (d / f"{sp}.svg").write_text(draw(m), encoding="utf-8")
    print(f"{len(ITEMS)} items x {len(SPECIES)} species -> {OUT}")


if __name__ == "__main__":
    main()
