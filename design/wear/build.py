"""Clothes for the critters: one SVG per item per species, fitted to each
head, written to godot/art/wear/<item>/<species>.svg.

Every file is drawn in the species' own 300 x 280 part frame (the same
coordinates as its head.svg), so the rig hangs it on the head pivot and it
rides every pose. Run: python design/wear/build.py
"""
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from common import LINE, W, svg, top, star, heart, clip_at, neck_arc  # noqa: E402
import items_small  # noqa: E402
import items_medium  # noqa: E402
import items_large  # noqa: E402
import items_perk  # noqa: E402

OUT = pathlib.Path(__file__).resolve().parents[2] / "godot" / "art" / "wear"
# Head metrics in SVG units (from each species' head.svg, eyes.svg, ears).
SPECIES = {
    "kitten": dict(cx=150, cy=122, rx=92, ry=74, eye_y=124, eye_dx=38, eye_r=18, chin=196,
                   gap=(122, 178), side=1.0),
    "rabbit": dict(cx=150, cy=142, rx=78, ry=62, eye_y=142, eye_dx=28, eye_r=16, chin=204,
                   gap=(142, 158), side=0.9),
    "duckling": dict(cx=150, cy=128, rx=72, ry=72, eye_y=132, eye_dx=30, eye_r=17, chin=200,
                     gap=(132, 168), side=0.85),
    # The sitting face (round-1 G): the heart-shaped mask, quills above it.
    "hedgehog": dict(cx=150, cy=136, rx=80, ry=58, eye_y=140, eye_dx=28, eye_r=12, chin=194,
                     gap=(140, 170), side=0.85),
    "turtle": dict(cx=162, cy=184, rx=52, ry=48, eye_y=181, eye_dx=22, eye_r=12, chin=232,
                   gap=(181, 210), side=0.8),
    "squirrel": dict(cx=134, cy=140, rx=70, ry=60, eye_y=139, eye_dx=28, eye_r=15, chin=194,
                     gap=(139, 170), side=0.9),
    "otter": dict(cx=124, cy=128, rx=60, ry=50, eye_y=124, eye_dx=25, eye_r=15, chin=174,
                  gap=(124, 160), side=0.9),
    "panda": dict(cx=150, cy=130, rx=72, ry=60, eye_y=127, eye_dx=29, eye_r=11, chin=181,
                  gap=(127, 166), side=1.0),
    "unicorn": dict(cx=150, cy=130, rx=64, ry=56, eye_y=132, eye_dx=26, eye_r=14, chin=183,
                    gap=(132, 168), side=0.9),
    "golden_kitten": dict(cx=150, cy=122, rx=92, ry=74, eye_y=124, eye_dx=38, eye_r=18, chin=196,
                          gap=(122, 178), side=1.0),
}


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


# --- One species only (Harrison, 2026-10-06): sold only once that species has
# been met, and only for critters whose design is final.

def fish_bowtie(m):
    # Kitten: a bow tie in the shape of two little fish, nose to nose.
    cx, y = m["cx"], m["chin"] - 2
    fish = ""
    for s in (-1, 1):
        x0 = cx + s * 6
        fish += (f'<path d="M{x0} {y} C {x0 + s * 10} {y - 14} {x0 + s * 28} {y - 12} {x0 + s * 34} {y} '
                 f'C {x0 + s * 28} {y + 12} {x0 + s * 10} {y + 14} {x0} {y} Z" fill="#7FBCF5" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
                 f'<path d="M{x0 + s * 32} {y} l {s * 12} -10 l 0 20 Z" fill="#7FBCF5" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
                 f'<circle cx="{x0 + s * 9}" cy="{y - 2}" r="2.6" fill="{LINE}"/>'
                 f'<path d="M{x0 + s * 16} {y - 6} q {s * 4} 6 0 12 M{x0 + s * 22} {y - 6} q {s * 4} 6 0 12" stroke="#4F8FD0" stroke-width="2.5" fill="none" stroke-linecap="round"/>')
    knot = f'<circle cx="{cx}" cy="{y}" r="7" fill="#F590B4" stroke="{LINE}" stroke-width="{W}"/>'
    return svg(fish + knot)


def paw_beret(m):
    # Kitten: a soft berry-coloured beret between the ears, a paw print on it.
    cx = m["cx"] + 4
    base = top(m, cx) + 18
    beret = (f'<path d="M{cx - 58} {base} C {cx - 70} {base - 40} {cx - 10} {base - 56} {cx + 30} {base - 44} '
             f'C {cx + 70} {base - 34} {cx + 62} {base - 4} {cx + 50} {base + 2} Q {cx} {base + 10} {cx - 58} {base} Z" '
             f'fill="#C9506A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
             f'<path d="M{cx + 2} {base - 50} q 2 -8 8 -10" stroke="{LINE}" stroke-width="{W + 1}" fill="none" stroke-linecap="round"/>')
    px, py = cx + 14, base - 22
    paw = (f'<ellipse cx="{px}" cy="{py + 4}" rx="9" ry="7" fill="#FCD9E6"/>'
           + "".join(f'<circle cx="{px + dx}" cy="{py + dy}" r="3.4" fill="#FCD9E6"/>' for dx, dy in ((-10, -5), (-4, -10), (4, -10), (10, -5))))
    return svg(beret + paw)


def carrot_clip(m):
    # Rabbit: a little carrot hair clip at the foot of the right ear.
    x, y = m["cx"] + 26, top(m, m["cx"] + 26) + 6
    return svg(f'<g transform="rotate(-35 {x} {y})">'
               f'<path d="M{x - 9} {y - 4} Q {x} {y - 10} {x + 9} {y - 4} L {x + 2} {y + 30} Q {x} {y + 34} {x - 2} {y + 30} Z" fill="#F59A4A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
               f'<path d="M{x - 5} {y + 6} l 5 1 M{x - 3} {y + 15} l 5 1" stroke="#C96F2A" stroke-width="2.5" stroke-linecap="round"/>'
               f'<path d="M{x} {y - 6} q -10 -14 -6 -20 q 6 4 6 20 q 4 -16 12 -18 q 0 10 -12 18" fill="#6CC27A" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/></g>')


def carrot_scarf(m):
    # Rabbit: an orange knitted scarf with leafy green tassels.
    cx, y = m["cx"], m["chin"] - 4
    half = m["rx"] * 0.62
    wrap = (f'<path d="M{cx - half:.1f} {y - 10:.1f} Q {cx} {y + 22:.1f} {cx + half:.1f} {y - 10:.1f} L {cx + half - 4:.1f} {y + 8:.1f} '
            f'Q {cx} {y + 40:.1f} {cx - half + 4:.1f} {y + 8:.1f} Z" fill="#F59A4A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    ribs = "".join(f'<path d="M{cx + dx:.1f} {y + 10:.1f} l 3 -12" stroke="#E07F2E" stroke-width="3" stroke-linecap="round"/>'
                   for dx in (-half * 0.7, -half * 0.35, 0, half * 0.35, half * 0.7))
    tx = cx - half * 0.45
    tail = (f'<path d="M{tx - 12:.1f} {y + 18:.1f} L {tx + 12:.1f} {y + 18:.1f} L {tx + 6:.1f} {y + 54:.1f} L {tx - 14:.1f} {y + 52:.1f} Z" '
            f'fill="#F59A4A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
            f'<path d="M{tx - 10:.1f} {y + 54:.1f} q -4 10 -10 12 q 8 -2 12 -10 M{tx - 2:.1f} {y + 54:.1f} q 0 10 4 14 q 0 -8 -2 -14" fill="#6CC27A" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>')
    return svg(tail + wrap + ribs)


def sailor_hat(m):
    # Duckling: a little white sailor cap, blue band, tipped back over the tuft.
    cx = m["cx"]
    base = top(m, cx) + 10
    hat = (f'<g transform="rotate(-8 {cx} {base})">'
           f'<path d="M{cx - 50} {base} C {cx - 52} {base - 30} {cx - 28} {base - 46} {cx} {base - 46} C {cx + 28} {base - 46} {cx + 52} {base - 30} {cx + 50} {base} Z" fill="#FFFFFF" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
           f'<rect x="{cx - 54}" y="{base - 12}" width="108" height="18" rx="9" fill="#3E6FC2" stroke="{LINE}" stroke-width="{W}"/>'
           f'<path d="M{cx + 40} {base + 4} l 10 18 l 6 -12 Z" fill="#3E6FC2" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
           f'{star(cx, base - 26, 8, "#FFCF5C")}</g>')
    return svg(hat)


def swim_ring(m):
    # Duckling: a red and white striped swim ring just under the chin.
    cx, y = m["cx"], m["chin"] + 8
    rx, ry, t = m["rx"] * 0.86, 15, 18
    per = 2 * math.pi * math.sqrt((rx * rx + ry * ry) / 2)
    dash = per / 8
    tube = (f'<ellipse cx="{cx}" cy="{y}" rx="{rx:.1f}" ry="{ry}" fill="none" stroke="{LINE}" stroke-width="{t + 2 * W}"/>'
            f'<ellipse cx="{cx}" cy="{y}" rx="{rx:.1f}" ry="{ry}" fill="none" stroke="#FFFFFF" stroke-width="{t}"/>'
            f'<ellipse cx="{cx}" cy="{y}" rx="{rx:.1f}" ry="{ry}" fill="none" stroke="#E2554F" stroke-width="{t}" stroke-dasharray="{dash:.1f} {dash:.1f}"/>'
            f'<path d="M{cx - rx * 0.55:.1f} {y + ry - 2:.1f} q {rx * 0.25:.1f} 6 {rx * 0.5:.1f} 4" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>')
    return svg(tube)


def quill_apple(m):
    # Hedgehog: a little red apple caught on the quills, up on the right,
    # the storybook hedgehog's favourite thing.
    x = m["cx"] + m["rx"] * 0.62
    y = top(m, x) - 20
    apple = (f'<g transform="rotate(14 {x:.1f} {y:.1f})">'
             f'<path d="M{x:.1f} {y - 12:.1f} C {x - 8:.1f} {y - 18:.1f} {x - 20:.1f} {y - 12:.1f} {x - 19:.1f} {y + 1:.1f} '
             f'C {x - 18:.1f} {y + 14:.1f} {x - 8:.1f} {y + 20:.1f} {x:.1f} {y + 16:.1f} C {x + 8:.1f} {y + 20:.1f} {x + 18:.1f} {y + 14:.1f} {x + 19:.1f} {y + 1:.1f} '
             f'C {x + 20:.1f} {y - 12:.1f} {x + 8:.1f} {y - 18:.1f} {x:.1f} {y - 12:.1f} Z" fill="#E2554F" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
             f'<path d="M{x - 11:.1f} {y - 6:.1f} q 3 -5 8 -5" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.7"/>'
             f'<path d="M{x:.1f} {y - 12:.1f} q 1 -8 4 -12" stroke="{LINE}" stroke-width="3" fill="none" stroke-linecap="round"/>'
             f'<path d="M{x + 3:.1f} {y - 20:.1f} q 12 -8 18 -1 q -9 8 -18 1 Z" fill="#6CC27A" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/></g>')
    return svg(apple)


def autumn_leaves(m):
    # Hedgehog: two autumn leaves stuck in the quills on the left, as if it
    # has just come out of a leaf pile.
    def leaf(cx, cy, rot, fill, vein):
        return (f'<g transform="rotate({rot} {cx:.1f} {cy:.1f})">'
                f'<path d="M{cx:.1f} {cy - 18:.1f} C {cx + 12:.1f} {cy - 10:.1f} {cx + 12:.1f} {cy + 8:.1f} {cx:.1f} {cy + 16:.1f} '
                f'C {cx - 12:.1f} {cy + 8:.1f} {cx - 12:.1f} {cy - 10:.1f} {cx:.1f} {cy - 18:.1f} Z" fill="{fill}" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
                f'<path d="M{cx:.1f} {cy - 12:.1f} L {cx:.1f} {cy + 22:.1f} M{cx:.1f} {cy - 2:.1f} l -6 -5 M{cx:.1f} {cy + 6:.1f} l 6 -5" '
                f'stroke="{vein}" stroke-width="2.4" fill="none" stroke-linecap="round"/></g>')
    x = m["cx"] - m["rx"] * 0.55
    y = top(m, x) - 16
    return svg(leaf(x - 10, y + 4, -40, "#F2994A", "#C2692A") + leaf(x + 8, y - 4, 12, "#F6C453", "#C9962E"))


def leaf_umbrella(m):
    # Turtle: a big round leaf held over its head like an umbrella.
    cx, y = m["cx"] + 6, top(m, m["cx"]) - 18
    leaf = (f'<path d="M{cx - 46} {y + 6} Q{cx - 40} {y - 30} {cx} {y - 34} Q{cx + 40} {y - 30} {cx + 46} {y + 6} '
            f'Q{cx + 30} {y - 2} {cx + 16} {y + 6} Q{cx} {y - 4} {cx - 16} {y + 6} Q{cx - 30} {y - 2} {cx - 46} {y + 6} Z" '
            f'fill="#7CC36A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
            f'<path d="M{cx} {y - 30} L{cx} {y + 2} M{cx} {y - 18} l-20 10 M{cx} {y - 18} l20 10" stroke="#4F9A45" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
            f'<path d="M{cx} {y + 2} L{cx + 2} {y + 26}" stroke="#4F9A45" stroke-width="4" stroke-linecap="round"/>')
    return svg(leaf)


def bubble_scarf(m):
    # Turtle: a sea-blue scarf with a row of little bubbles.
    out = neck_arc(m, "#5FB7D9", 14)
    cx, y = m["cx"], m["chin"] - 2
    for i, dx in enumerate((-22, -8, 8, 22)):
        out += f'<circle cx="{cx + dx}" cy="{y + 4 + abs(dx) * -0.2:.1f}" r="{3 + i % 2}" fill="#FFFFFF" opacity="0.85"/>'
    return svg(out)


def acorn_cap(m):
    # Squirrel: an acorn cup worn as a cap, stalk on top.
    cx, base = m["cx"], top(m, m["cx"]) + 12
    cap = (f'<path d="M{cx - 38} {base} Q{cx - 38} {base - 38} {cx} {base - 40} Q{cx + 38} {base - 38} {cx + 38} {base} Z" '
           f'fill="#8A5A35" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    cap += ''.join(f'<path d="M{cx + dx - 6} {base - 8 - k * 9} l6 -6 l6 6" stroke="#6E4528" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
                   for k in range(3) for dx in (-20, 0, 20) if abs(dx) < 34 - k * 8)
    cap += f'<path d="M{cx} {base - 40} q2 -10 8 -12" stroke="{LINE}" stroke-width="4" fill="none" stroke-linecap="round"/>'
    return svg(cap)


def acorn_pendant(m):
    # Squirrel: its acorn, on a cord round its neck (the acorn it held in the studio).
    cx, y = m["cx"], m["chin"] + 6
    cord = f'<path d="M{cx - 34} {y - 14} Q{cx} {y + 6} {cx + 34} {y - 14}" stroke="#B9874F" stroke-width="3" fill="none"/>'
    nut = (f'<path d="M{cx - 9} {y + 2} Q{cx - 10} {y + 18} {cx} {y + 22} Q{cx + 10} {y + 18} {cx + 9} {y + 2} Z" fill="#C98B4E" stroke="{LINE}" stroke-width="3"/>'
           f'<path d="M{cx - 12} {y + 4} Q{cx - 12} {y - 6} {cx} {y - 7} Q{cx + 12} {y - 6} {cx + 12} {y + 4} Z" fill="#8A5A35" stroke="{LINE}" stroke-width="3"/>')
    return svg(cord + nut)


def shell_clip(m):
    # Otter: a pink scallop shell clipped by one ear.
    x, y = clip_at(m, -1, 0.5)
    d = f'M{x - 14} {y + 6} Q{x - 16} {y - 12} {x} {y - 14} Q{x + 16} {y - 12} {x + 14} {y + 6} Z'
    rays = ' '.join(f'M{x} {y + 6} L{x + dx} {y - 10}' for dx in (-9, -3, 3, 9))
    return svg(f'<path d="{d}" fill="#F7C9C0" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
               f'<path d="{rays}" stroke="#D99A8E" stroke-width="2" fill="none"/>')


def kelp_scarf(m):
    # Otter: a ribbon of kelp, wavy green ends trailing.
    out = neck_arc(m, "#4E9A6A", 12)
    cx, y = m["cx"] + m["rx"] * 0.3, m["chin"] + 4
    out += (f'<path d="M{cx} {y} q8 10 0 20 q-8 10 2 20" stroke="{LINE}" stroke-width="{12 + 2 * W}" fill="none" stroke-linecap="round"/>'
            f'<path d="M{cx} {y} q8 10 0 20 q-8 10 2 20" stroke="#4E9A6A" stroke-width="12" fill="none" stroke-linecap="round"/>')
    return svg(out)


def bamboo_hat(m):
    # Panda: a woven conical hat.
    cx, base = m["cx"], top(m, m["cx"]) + 14
    w = m["rx"] * 0.95
    hat = (f'<path d="M{cx - w:.1f} {base} L{cx} {base - 46} L{cx + w:.1f} {base} Q{cx} {base + 10} {cx - w:.1f} {base} Z" '
           f'fill="#E6C27A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    hat += ''.join(f'<path d="M{cx} {base - 46} L{cx + dx:.1f} {base + 2}" stroke="#C49A4E" stroke-width="2" opacity="0.8"/>'
                   for dx in (-w * 0.6, -w * 0.2, w * 0.2, w * 0.6))
    hat += f'<path d="M{cx - w * 0.5:.1f} {base - 20} Q{cx} {base - 14} {cx + w * 0.5:.1f} {base - 20}" stroke="#B5463C" stroke-width="5" fill="none"/>'
    return svg(hat)


def bamboo_sprig(m):
    # Panda: a little sprig of bamboo leaves tucked by one ear.
    x, y = clip_at(m, 1, 0.55)
    return svg(f'<path d="M{x} {y + 10} L{x + 4} {y - 16}" stroke="#7DB352" stroke-width="5" stroke-linecap="round"/>'
               f'<path d="M{x + 3} {y - 8} q18 -12 26 -2 q-12 8 -26 2 Z" fill="#9CCB6B" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
               f'<path d="M{x + 2} {y - 14} q-16 -14 -24 -6 q10 10 24 6 Z" fill="#B8E082" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>')


def cloud_scarf(m):
    # Unicorn: a puffy cloud wrapped round its neck.
    cx, y = m["cx"], m["chin"] - 2
    pts = [(cx - 34, y - 6, 12), (cx - 16, y + 2, 14), (cx + 4, y + 4, 14), (cx + 22, y, 13), (cx + 36, y - 8, 11)]
    out = ''.join(f'<circle cx="{x}" cy="{yy}" r="{r}" fill="#FFFFFF" stroke="{LINE}" stroke-width="7"/>' for x, yy, r in pts)
    out += ''.join(f'<circle cx="{x}" cy="{yy}" r="{r}" fill="#FFFFFF"/>' for x, yy, r in pts)
    return svg(out)


def rainbow_bow(m):
    # Unicorn: a striped rainbow bow beside its horn.
    x, y = clip_at(m, -1, 0.42)
    stripes = ''.join(f'<path d="M{x} {y} L{x - 22} {y - 12 + i * 5} L{x - 22} {y - 8 + i * 5} Z M{x} {y} L{x + 22} {y - 12 + i * 5} L{x + 22} {y - 8 + i * 5} Z" fill="{c}"/>'
                      for i, c in enumerate(("#F7A8B8", "#FFD59A", "#B9E8B0", "#A9D4F5", "#C9B6F2")))
    outline = (f'<path d="M{x} {y} L{x - 22} {y - 14} L{x - 22} {y + 14} Z M{x} {y} L{x + 22} {y - 14} L{x + 22} {y + 14} Z" '
               f'fill="none" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>')
    return svg(stripes + outline + f'<circle cx="{x}" cy="{y}" r="6" fill="#F7A8B8" stroke="{LINE}" stroke-width="3"/>')


# id: (draw, name, slot, tier) or (draw, name, slot, tier, only species)
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
    "fish_bowtie": (fish_bowtie, "Fishbone bow tie", "neck", "medium", "kitten"),
    "paw_beret": (paw_beret, "Paw-print beret", "head", "large", "kitten"),
    "carrot_clip": (carrot_clip, "Carrot hair clip", "head", "small", "rabbit"),
    "carrot_scarf": (carrot_scarf, "Carrot scarf", "neck", "medium", "rabbit"),
    "sailor_hat": (sailor_hat, "Sailor hat", "head", "medium", "duckling"),
    "swim_ring": (swim_ring, "Swim ring", "neck", "large", "duckling"),
    "quill_apple": (quill_apple, "Apple on the quills", "head", "medium", "hedgehog"),
    "autumn_leaves": (autumn_leaves, "Autumn leaves", "head", "small", "hedgehog"),
    "leaf_umbrella": (leaf_umbrella, "Leaf umbrella", "head", "medium", "turtle"),
    "bubble_scarf": (bubble_scarf, "Bubble scarf", "neck", "small", "turtle"),
    "acorn_cap": (acorn_cap, "Acorn cap", "head", "medium", "squirrel"),
    "acorn_pendant": (acorn_pendant, "Acorn on a cord", "neck", "small", "squirrel"),
    "shell_clip": (shell_clip, "Seashell clip", "head", "small", "otter"),
    "kelp_scarf": (kelp_scarf, "Kelp scarf", "neck", "medium", "otter"),
    "bamboo_hat": (bamboo_hat, "Bamboo hat", "head", "medium", "panda"),
    "bamboo_sprig": (bamboo_sprig, "Bamboo sprig", "head", "small", "panda"),
    "cloud_scarf": (cloud_scarf, "Cloud scarf", "neck", "large", "unicorn"),
    "rainbow_bow": (rainbow_bow, "Rainbow bow", "head", "medium", "unicorn"),
}


ITEMS.update(items_small.ITEMS)
ITEMS.update(items_medium.ITEMS)
ITEMS.update(items_large.ITEMS)
ITEMS.update(items_perk.ITEMS)


# Where the first coloured fill is not the item's main colour.
MAIN = {"bell_collar": "#E2554F", "beanie": "#7FB3E8", "scarf": "#E86A5C", "carrot_scarf": "#F59A4A",
        "heart_tag": "#7C4DD6", "headphones": "#7C4DD6", "sweatband": "#7FBCF5", "visor": "#86D9B0",
        "alice_band": "#F590B4", "halo": "#FFE07A", "tiara": "#E8EEF7", "flower_crown": "#F7A8C4",
        "bead_necklace": "#F590B4", "lei": "#F7A8C4", "pearl_necklace": "#FBF7F0", "wizard_hat": "#6A5AD0",
        "swim_ring": "#E2554F", "lion_mane": "#E8A04F", "bee_antennae": "#FFD84D", "chef_hat": "#FFFFFF",
        "tricorn": "#3B3346", "top_hat": "#3B3346", "mortarboard": "#3B3346", "viking_helmet": "#A9B4C2",
        "knight_helmet": "#C5CEDA", "astronaut_helmet": "#E8EEF7", "garden_hat": "#F2D58A",
        "flower_bonnet": "#FFF0C2", "sailor_hat": "#3E6FC2", "strawberry_hat": "#F2575D", "star_clip": "#FFD84D",
        "monocle": "#D9961A", "plaster": "#F7D3B0", "clover_clip": "#6CC27A", "lily_pad": "#6CC27A",
        "dino_hood": "#86C9E8", "cowboy_hat": "#D99A5B"}
# No dyes where the main colour is white (it would recolour every highlight).
NO_DYE = {"chef_hat", "flower_clip", "daisy_chain", "glasses", "sunglasses"}


def main():
    for item, (draw, *rest) in ITEMS.items():
        d = OUT / item
        d.mkdir(parents=True, exist_ok=True)
        only = rest[3] if len(rest) > 3 else None
        for sp, m in SPECIES.items():
            if only is None or sp == only:
                (d / f"{sp}.svg").write_text(draw(m), encoding="utf-8")
    # The catalogue the game reads (wear.gd): id -> [name, slot, tier, (species)].
    import json
    cat = {k: list(v[1:]) for k, v in ITEMS.items()}
    # Each item's main colour, which a dye replaces: the commonest fill that
    # is not the outline, white or near-white.
    import re
    from collections import Counter
    mains = {}
    for k, v in ITEMS.items():
        sp = (v[4] if len(v) > 4 else "kitten")
        text = v[0](SPECIES[sp])
        fills = [f.upper() for f in re.findall(r'fill="(#[0-9A-Fa-f]{6})"', text)]
        skip = {"#FFFFFF", "#6B4A3A", "#2B2330", "#FBF7F0", "#FFF4CC", "#FFF0C2", "#E8EEF7", "#DDEEFF",
                "#F3F7FC", "#C9D8EA", "#FFB3BA", "#E3DCD3", "#FFD84D", "#FFCF5C", "#6CC27A", "#F59C9C"}
        firsts = [f for f in fills if f not in skip]
        main = MAIN.get(k) or (firsts[0] if firsts else None)
        if main and k not in NO_DYE:
            mains[k] = main
    (OUT / "dyes.json").write_text(json.dumps(mains, indent=1), encoding="utf-8")
    (OUT / "catalogue.json").write_text(json.dumps(cat, indent=1), encoding="utf-8")
    (OUT / "hides.json").write_text(json.dumps(items_large.HIDES, indent=1), encoding="utf-8")
    print(f"{len(ITEMS)} items x {len(SPECIES)} species -> {OUT}")


if __name__ == "__main__":
    main()
