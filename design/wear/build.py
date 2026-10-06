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

OUT = pathlib.Path(__file__).resolve().parents[2] / "godot" / "art" / "wear"
# Head metrics in SVG units (from each species' head.svg, eyes.svg, ears).
SPECIES = {
    "kitten": dict(cx=150, cy=122, rx=92, ry=74, eye_y=124, eye_dx=38, eye_r=18, chin=196,
                   gap=(122, 178), side=1.0),
    "rabbit": dict(cx=150, cy=142, rx=78, ry=62, eye_y=142, eye_dx=28, eye_r=16, chin=204,
                   gap=(142, 158), side=0.9),
    "duckling": dict(cx=150, cy=128, rx=72, ry=72, eye_y=132, eye_dx=30, eye_r=17, chin=200,
                     gap=(132, 168), side=0.85),
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
}


ITEMS.update(items_small.ITEMS)
ITEMS.update(items_medium.ITEMS)
ITEMS.update(items_large.ITEMS)


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
