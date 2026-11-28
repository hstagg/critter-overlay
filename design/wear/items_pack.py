"""Supporter Pack clothes (docs/codes-plan.md): a hat, a neck item and a face
item on one theme, and the creator hat. Tier "pack": never sold, owned only
through a code (godot/codes.gd lists what each pack holds).

The Supporter Pack is the Starlight set (moon nightcap, starry capelet, star
glasses); the creator hat is the director's beret. Only the picks are drawn
here.
"""
import math

from common import LINE, W, svg, top, star


# --- The Supporter Pack: Starlight (navy and gold) ------------------------------------------

def moon_nightcap(m):
    # A floppy navy sleeping cap whose long tip flops over to the right and
    # hangs beside the head, a gold star on the end; a crescent moon and stars.
    cx = m["cx"]
    hw = m["rx"] * 0.8
    brim_y = top(m, cx) + m["ry"] * 0.36
    crown = top(m, cx) - 34
    tip_x, tip_y = cx + hw * 1.22, brim_y - 2
    cap = (f'<path d="M{cx - hw:.1f} {brim_y:.1f} C {cx - hw:.1f} {crown - 10:.1f} {cx + hw * 0.5:.1f} {crown - 34:.1f} {cx + hw * 0.95:.1f} {crown + 2:.1f} '
           f'C {cx + hw * 1.12:.1f} {crown + 18:.1f} {tip_x + 4:.1f} {tip_y - 20:.1f} {tip_x:.1f} {tip_y:.1f} '
           f'C {tip_x - 14:.1f} {tip_y - 18:.1f} {cx + hw * 0.86:.1f} {crown + 26:.1f} {cx + hw * 0.7:.1f} {crown + 22:.1f} '
           f'C {cx + hw * 0.86:.1f} {brim_y - 20:.1f} {cx + hw:.1f} {brim_y - 10:.1f} {cx + hw:.1f} {brim_y:.1f} Z" '
           f'fill="#4B4C9A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    mx, my = cx - hw * 0.3, crown + 24
    moon = (f'<path d="M{mx + 4:.1f} {my - 13:.1f} A 13 13 0 1 0 {mx + 4:.1f} {my + 13:.1f} A 10 10 0 1 1 {mx + 4:.1f} {my - 13:.1f} Z" '
            f'fill="#FFE58A" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>')
    dots = star(cx + hw * 0.18, crown + 10, 6, "#FFD45C", sw=2) + star(cx + hw * 0.5, crown + 30, 4.5, "#FFF0C2", sw=2, rot=15)
    brim = f'<rect x="{cx - hw - 6:.1f}" y="{brim_y - 12:.1f}" width="{2 * hw + 12:.1f}" height="22" rx="11" fill="#E9E4F7" stroke="{LINE}" stroke-width="{W}"/>'
    tassel = star(tip_x + 2, tip_y + 10, 14, "#FFD45C", sw=W - 1, rot=10)
    return svg(cap + moon + dots + brim + tassel)


def star_cape(m):
    # A navy capelet round the neck, scattered with stars, a gold star clasp.
    cx, y = m["cx"], m["chin"] - 4
    half = m["rx"] * 0.6
    cape = (f'<path d="M{cx - half:.1f} {y - 10:.1f} Q {cx} {y + 18:.1f} {cx + half:.1f} {y - 10:.1f} '
            f'L {cx + half + 16:.1f} {y + 30:.1f} Q {cx + half * 0.5:.1f} {y + 44:.1f} {cx:.1f} {y + 40:.1f} '
            f'Q {cx - half * 0.5:.1f} {y + 44:.1f} {cx - half - 16:.1f} {y + 30:.1f} Z" '
            f'fill="#4B4C9A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    collar = (f'<path d="M{cx - half:.1f} {y - 10:.1f} Q {cx} {y + 18:.1f} {cx + half:.1f} {y - 10:.1f}" '
              f'stroke="#E9E4F7" stroke-width="7" fill="none" stroke-linecap="round"/>')
    dots = "".join(star(cx + dx * half, y + dy, r, "#FFF0C2", sw=1.6, rot=dx * 40)
                   for dx, dy, r in ((-0.85, 22, 4.5), (-0.4, 30, 3.5), (0.45, 28, 4), (0.9, 20, 3.5)))
    clasp = star(cx, y + 12, 11, "#FFD45C", sw=3)
    return svg(cape + collar + dots + clasp)


def star_glasses(m):
    # Gold star-shaped glasses; the eyes show through the lenses.
    y = m["eye_y"]
    r = m["eye_r"] + 15
    lx, rx_ = m["cx"] - m["eye_dx"], m["cx"] + m["eye_dx"]

    def pts(x):
        out = []
        for i in range(10):
            a = math.radians(-90 + i * 36)
            rr = r if i % 2 == 0 else r * 0.58
            out.append(f"{x + rr * math.cos(a):.1f},{y + 2 + rr * math.sin(a):.1f}")
        return " ".join(out)
    lens = "".join(f'<polygon points="{pts(x)}" fill="#FFF3B0" fill-opacity="0.28" stroke="{LINE}" stroke-width="{W + 5}" stroke-linejoin="round"/>'
                   f'<polygon points="{pts(x)}" fill="none" stroke="#FFC93C" stroke-width="{W}" stroke-linejoin="round"/>' for x in (lx, rx_))
    bridge = (f'<path d="M{lx + r * 0.5:.1f} {y - 4:.1f} Q {m["cx"]} {y - 12:.1f} {rx_ - r * 0.5:.1f} {y - 4:.1f}" stroke="{LINE}" stroke-width="{W + 3}" fill="none" stroke-linecap="round"/>'
              f'<path d="M{lx + r * 0.5:.1f} {y - 4:.1f} Q {m["cx"]} {y - 12:.1f} {rx_ - r * 0.5:.1f} {y - 4:.1f}" stroke="#FFC93C" stroke-width="3" fill="none" stroke-linecap="round"/>')
    shine = "".join(f'<path d="M{x - r * 0.35:.1f} {y - r * 0.2:.1f} l 5 -6" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>' for x in (lx, rx_))
    return svg(bridge + lens + shine)


# --- The creator hat ------------------------------------------------------

def director_beret(m):
    # A black beret tilted to one side, a little clapperboard pinned on.
    cx = m["cx"] - 4
    base = top(m, cx) + 18
    beret = (f'<path d="M{cx - 58} {base} C {cx - 72} {base - 40} {cx - 8} {base - 58} {cx + 34} {base - 46} '
             f'C {cx + 72} {base - 36} {cx + 64} {base - 4} {cx + 52} {base + 2} Q {cx} {base + 10} {cx - 58} {base} Z" '
             f'fill="#3B3346" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
             f'<path d="M{cx + 2} {base - 52} q 2 -8 8 -10" stroke="{LINE}" stroke-width="{W + 1}" fill="none" stroke-linecap="round"/>'
             f'<path d="M{cx - 40} {base - 30} q 20 -16 48 -16" stroke="#57506A" stroke-width="4" fill="none" stroke-linecap="round"/>')
    px, py = cx + 22, base - 26
    clap = (f'<g transform="rotate(-12 {px} {py})">'
            f'<rect x="{px - 16}" y="{py - 6}" width="32" height="22" rx="3" fill="#FFFFFF" stroke="{LINE}" stroke-width="3"/>'
            f'<path d="M{px - 14} {py + 4} H {px + 14} M{px - 14} {py + 10} H {px + 6}" stroke="#C9C2D6" stroke-width="2.4" stroke-linecap="round"/>'
            f'<g transform="rotate(-16 {px - 16} {py - 6})"><rect x="{px - 16}" y="{py - 14}" width="32" height="8" rx="2" fill="#2B2330" stroke="{LINE}" stroke-width="2.5"/>'
            + "".join(f'<path d="M{px - 12 + i * 8} {py - 14} l 4 8" stroke="#FFFFFF" stroke-width="3"/>' for i in range(4))
            + '</g></g>')
    return svg(beret + clap)


# id: (draw, name, slot, tier). Picked by the developer on 2026-11-26 from
# three themes (Starlight, Sweet shop, Little hero) and three creator hats.
ITEMS = {
    "moon_nightcap": (moon_nightcap, "Moon nightcap", "head", "pack"),
    "star_cape": (star_cape, "Starry capelet", "neck", "pack"),
    "star_glasses": (star_glasses, "Star glasses", "face", "pack"),
    "director_beret": (director_beret, "Director's beret", "head", "pack"),
}
