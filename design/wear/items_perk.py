"""Perk clothes (8,000 berries): each gives the critter wearing it something
extra (Harrison, 2026-10-06). What they do lives in the game (wear.gd PERKS):
disco headphones dance, the aviator cap takes off and floats, the confetti
crown celebrates, the lucky charm makes that species' visitors luckier."""
import math

from common import LINE, W, svg, top, star, heart


def disco_headphones(m):
    cx = m["cx"]
    y = top(m, cx) - 6
    rx = m["rx"] * 0.98
    band = (f'<path d="M{cx - rx:.1f} {m["cy"]:.1f} C {cx - rx:.1f} {y - 10:.1f} {cx + rx:.1f} {y - 10:.1f} {cx + rx:.1f} {m["cy"]:.1f}" stroke="{LINE}" stroke-width="18" fill="none" stroke-linecap="round"/>'
            f'<path d="M{cx - rx:.1f} {m["cy"]:.1f} C {cx - rx:.1f} {y - 10:.1f} {cx + rx:.1f} {y - 10:.1f} {cx + rx:.1f} {m["cy"]:.1f}" stroke="#FFCF5C" stroke-width="10" fill="none" stroke-linecap="round"/>')
    cups = "".join(f'<circle cx="{cx + s * rx:.1f}" cy="{m["cy"] + 4:.1f}" r="22" fill="#F590B4" stroke="{LINE}" stroke-width="{W}"/>'
                   f'<circle cx="{cx + s * rx:.1f}" cy="{m["cy"] + 4:.1f}" r="12" fill="#FFCF5C" stroke="{LINE}" stroke-width="3"/>'
                   + star(cx + s * rx, m["cy"] + 4, 7, "#FFFFFF", sw=2) for s in (-1, 1))
    notes = (f'<path d="M{cx + rx + 20:.1f} {m["cy"] - 40:.1f} v -22 l 14 -4 v 22" stroke="{LINE}" stroke-width="3.5" fill="none"/>'
             f'<ellipse cx="{cx + rx + 16:.1f}" cy="{m["cy"] - 40:.1f}" rx="6" ry="4.5" fill="#7C4DD6" stroke="{LINE}" stroke-width="2.5"/>'
             f'<ellipse cx="{cx + rx + 30:.1f}" cy="{m["cy"] - 44:.1f}" rx="6" ry="4.5" fill="#7C4DD6" stroke="{LINE}" stroke-width="2.5"/>')
    return svg(band + cups + notes)


def aviator_cap(m):
    cx = m["cx"]
    y = top(m, cx) + m["ry"] * 0.45
    hw = m["rx"] * 0.9
    cap = (f'<path d="M{cx - hw:.1f} {y + 18:.1f} C {cx - hw - 4:.1f} {y - 60:.1f} {cx + hw + 4:.1f} {y - 60:.1f} {cx + hw:.1f} {y + 18:.1f} '
           f'Q {cx + hw - 10:.1f} {y + 34:.1f} {cx + hw - 22:.1f} {y + 30:.1f} L {cx + hw - 20:.1f} {y + 4:.1f} Q {cx:.1f} {y - 6:.1f} {cx - hw + 20:.1f} {y + 4:.1f} L {cx - hw + 22:.1f} {y + 30:.1f} Q {cx - hw + 10:.1f} {y + 34:.1f} {cx - hw:.1f} {y + 18:.1f} Z" '
           f'fill="#B98A5A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>')
    seam = f'<path d="M{cx:.1f} {y - 40:.1f} V {y - 4:.1f}" stroke="#8C6440" stroke-width="3" stroke-dasharray="5 4"/>'
    goggles = "".join(f'<circle cx="{cx + s * 24:.1f}" cy="{y - 18:.1f}" r="15" fill="#9FD6F0" stroke="{LINE}" stroke-width="{W + 1}"/>'
                      f'<circle cx="{cx + s * 24:.1f}" cy="{y - 18:.1f}" r="15" fill="none" stroke="#D9961A" stroke-width="3"/>'
                      f'<path d="M{cx + s * 24 - 7:.1f} {y - 24:.1f} q 4 -4 9 -3" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>' for s in (-1, 1))
    strap = f'<path d="M{cx - 9:.1f} {y - 18:.1f} H {cx + 9:.1f}" stroke="{LINE}" stroke-width="6"/>'
    return svg(cap + seam + goggles + strap)


def confetti_crown(m):
    cx = m["cx"]
    y = top(m, cx) + 14
    w = m["rx"] * 0.55
    pts = f"{cx - w:.1f},{y:.1f} {cx - w:.1f},{y - 30:.1f} {cx - w * 0.5:.1f},{y - 14:.1f} {cx:.1f},{y - 38:.1f} {cx + w * 0.5:.1f},{y - 14:.1f} {cx + w:.1f},{y - 30:.1f} {cx + w:.1f},{y:.1f}"
    crown = f'<polygon points="{pts}" fill="#FFCF5C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    band = f'<rect x="{cx - w:.1f}" y="{y - 10:.1f}" width="{2 * w:.1f}" height="10" fill="#F590B4" stroke="{LINE}" stroke-width="3"/>'
    gems = "".join(f'<circle cx="{cx + f * w:.1f}" cy="{y - 5:.1f}" r="3.5" fill="{c}" stroke="{LINE}" stroke-width="1.5"/>' for f, c in ((-0.6, "#7FBCF5"), (0, "#86D9B0"), (0.6, "#C8A8FF")))
    bits = ""
    cols = ["#F590B4", "#7FBCF5", "#86D9B0", "#FFCF5C", "#C8A8FF"]
    for i, (dx, dy, r) in enumerate(((-w - 16, -40, 20), (w + 14, -46, -25), (-10, -62, 35), (22, -58, 10), (-w + 4, -56, -15))):
        bits += f'<rect x="{cx + dx - 4:.1f}" y="{y + dy - 2:.1f}" width="8" height="4" rx="1" fill="{cols[i % 5]}" transform="rotate({r} {cx + dx:.1f} {y + dy:.1f})"/>'
    return svg(bits + crown + band + gems)


def lucky_charm(m):
    cx, y = m["cx"], m["chin"] - 6
    half = m["rx"] * 0.5
    chain = "".join(f'<circle cx="{cx - half + 2 * half * i / 10:.1f}" cy="{y - 4 + 16 * (1 - (2 * i / 10 - 1) ** 2):.1f}" r="2.6" fill="#FFCF5C" stroke="{LINE}" stroke-width="1.2"/>' for i in range(11))
    py = y + 26
    disc = f'<circle cx="{cx:.1f}" cy="{py:.1f}" r="14" fill="#FFE07A" stroke="{LINE}" stroke-width="{W}"/>'
    leaves = "".join(heart(cx + 5.5 * math.cos(math.radians(a)), py + 5.5 * math.sin(math.radians(a)), 5.5, "#6CC27A", rot=a + 90, sw=1.8) for a in (-90, 0, 90, 180))
    shine = f'<path d="M{cx - 9:.1f} {py - 6:.1f} q 3 -5 8 -6" stroke="#FFFFFF" stroke-width="2.5" fill="none" stroke-linecap="round"/>'
    return svg(chain + disc + leaves + shine)


ITEMS = {
    "disco_headphones": (disco_headphones, "Disco headphones", "head", "perk"),
    "aviator_cap": (aviator_cap, "Aviator cap", "head", "perk"),
    "confetti_crown": (confetti_crown, "Confetti crown", "head", "perk"),
    "lucky_charm": (lucky_charm, "Lucky charm", "neck", "perk"),
}
