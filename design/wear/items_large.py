"""Large clothes (1,200 berries): hoods, helmets and grand hats. Each draw(m)
takes a species' head metrics (build.py SPECIES) and returns the item's SVG.

Hoods frame the face, so the wearer's own ears (and the duckling's tuft) are
hidden while one is on: HIDES lists them. The rabbit keeps its ears, poking
through."""
import math

from common import LINE, W, svg, top, star


def _hood(m, colour, inner="#FFFFFF", pad=16):
    """A hood round the head with a face opening; returns (svg body, top y)."""
    cx, cy, rx, ry = m["cx"], m["cy"], m["rx"] + pad, m["ry"] + pad
    fx, fy, frx, fry = cx, cy + 12, m["rx"] * 0.8, m["ry"] * 0.74
    d = (f"M{cx - rx:.1f} {cy:.1f} A {rx:.1f} {ry:.1f} 0 1 1 {cx + rx:.1f} {cy:.1f} A {rx:.1f} {ry:.1f} 0 1 1 {cx - rx:.1f} {cy:.1f} Z "
         f"M{fx - frx:.1f} {fy:.1f} A {frx:.1f} {fry:.1f} 0 1 0 {fx + frx:.1f} {fy:.1f} A {frx:.1f} {fry:.1f} 0 1 0 {fx - frx:.1f} {fy:.1f} Z")
    rim = f'<ellipse cx="{fx:.1f}" cy="{fy:.1f}" rx="{frx:.1f}" ry="{fry:.1f}" fill="none" stroke="{inner}" stroke-width="5"/>'
    body = f'<path d="{d}" fill="{colour}" fill-rule="evenodd" stroke="{LINE}" stroke-width="{W}"/>' + rim
    return body, cy - ry


def frog_hood(m):
    body, ty = _hood(m, "#7FCF86", "#B9E9BE")
    cx = m["cx"]
    eyes = "".join(f'<circle cx="{cx + s * m["rx"] * 0.42:.1f}" cy="{ty + 8:.1f}" r="20" fill="#7FCF86" stroke="{LINE}" stroke-width="{W}"/>'
                   f'<circle cx="{cx + s * m["rx"] * 0.42:.1f}" cy="{ty + 6:.1f}" r="11" fill="#FFFFFF" stroke="{LINE}" stroke-width="3"/>'
                   f'<circle cx="{cx + s * m["rx"] * 0.42 + 2:.1f}" cy="{ty + 7:.1f}" r="5.5" fill="#2B2330"/>' for s in (-1, 1))
    cheeks = "".join(f'<ellipse cx="{cx + s * (m["rx"] + 4):.1f}" cy="{m["cy"] + 30:.1f}" rx="9" ry="6" fill="#F59C9C" opacity="0.6"/>' for s in (-1, 1))
    return svg(body + eyes + cheeks)


def dino_hood(m):
    body, ty = _hood(m, "#86C9E8", "#C9E8F5")
    cx = m["cx"]
    spikes = ""
    for i, f in enumerate([-0.5, -0.17, 0.17, 0.5]):
        x = cx + f * (m["rx"] + 16)
        y = top({**m, "rx": m["rx"] + 16, "ry": m["ry"] + 16}, x) + 2
        spikes += f'<path d="M{x - 13:.1f} {y + 6:.1f} L {x:.1f} {y - 22:.1f} L {x + 13:.1f} {y + 6:.1f} Z" fill="#F59A4A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    spots = "".join(f'<circle cx="{cx + dx:.1f}" cy="{m["cy"] + dy:.1f}" r="{r}" fill="#5FA8CF"/>' for dx, dy, r in ((-m["rx"] - 2, -10, 6), (m["rx"] + 4, 0, 5), (-m["rx"] * 0.6, -m["ry"] - 4, 5)))
    return svg(spikes + body + spots)


def bear_hood(m):
    body, ty = _hood(m, "#B98A5A", "#E2C9A6")
    cx = m["cx"]
    ears = "".join(f'<circle cx="{cx + s * m["rx"] * 0.72:.1f}" cy="{ty + 22:.1f}" r="20" fill="#B98A5A" stroke="{LINE}" stroke-width="{W}"/>'
                   f'<circle cx="{cx + s * m["rx"] * 0.72:.1f}" cy="{ty + 22:.1f}" r="10" fill="#E2C9A6"/>' for s in (-1, 1))
    return svg(ears + body)


def astronaut_helmet(m):
    cx, cy = m["cx"], m["cy"] + 8
    r = max(m["rx"], m["ry"]) + 26
    glass = f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="#DDEEFF" fill-opacity="0.28" stroke="{LINE}" stroke-width="{W}"/>'
    shine = f'<path d="M{cx - r * 0.62:.1f} {cy - r * 0.3:.1f} A {r * 0.7:.1f} {r * 0.7:.1f} 0 0 1 {cx - r * 0.1:.1f} {cy - r * 0.7:.1f}" stroke="#FFFFFF" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.85"/>'
    collar = f'<path d="M{cx - r * 0.86:.1f} {cy + r * 0.5:.1f} Q {cx:.1f} {cy + r * 0.9:.1f} {cx + r * 0.86:.1f} {cy + r * 0.5:.1f}" stroke="{LINE}" stroke-width="22" fill="none" stroke-linecap="round"/><path d="M{cx - r * 0.86:.1f} {cy + r * 0.5:.1f} Q {cx:.1f} {cy + r * 0.9:.1f} {cx + r * 0.86:.1f} {cy + r * 0.5:.1f}" stroke="#E8EEF7" stroke-width="14" fill="none" stroke-linecap="round"/>'
    light = f'<circle cx="{cx + r * 0.7:.1f}" cy="{cy + r * 0.55:.1f}" r="6" fill="#E4505C" stroke="{LINE}" stroke-width="2.5"/>'
    return svg(glass + shine + collar + light)


def viking_helmet(m):
    cx = m["cx"]
    y = top(m, cx) + m["ry"] * 0.42
    hw = m["rx"] * 0.82
    horns = "".join(f'<path d="M{cx + s * hw * 0.8:.1f} {y - 18:.1f} C {cx + s * (hw + 30):.1f} {y - 24:.1f} {cx + s * (hw + 30):.1f} {y - 60:.1f} {cx + s * (hw + 10):.1f} {y - 74:.1f} C {cx + s * (hw + 14):.1f} {y - 50:.1f} {cx + s * hw:.1f} {y - 40:.1f} {cx + s * hw * 0.6:.1f} {y - 34:.1f} Z" fill="#FFF4CC" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>' for s in (-1, 1))
    dome = f'<path d="M{cx - hw:.1f} {y:.1f} C {cx - hw:.1f} {y - 62:.1f} {cx + hw:.1f} {y - 62:.1f} {cx + hw:.1f} {y:.1f} Z" fill="#A9B4C2" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    band = f'<rect x="{cx - hw - 4:.1f}" y="{y - 12:.1f}" width="{2 * hw + 8:.1f}" height="16" rx="8" fill="#D9961A" stroke="{LINE}" stroke-width="{W}"/>'
    rivets = "".join(f'<circle cx="{cx + f * hw:.1f}" cy="{y - 4:.1f}" r="2.5" fill="#FFF0C2"/>' for f in (-0.66, -0.33, 0, 0.33, 0.66))
    ridge = f'<path d="M{cx:.1f} {y - 46:.1f} V {y - 12:.1f}" stroke="#D9961A" stroke-width="7"/>'
    return svg(horns + dome + ridge + band + rivets)


def knight_helmet(m):
    cx = m["cx"]
    y = top(m, cx) + m["ry"] * 0.5
    hw = m["rx"] * 0.86
    dome = f'<path d="M{cx - hw:.1f} {y:.1f} C {cx - hw:.1f} {y - 70:.1f} {cx + hw:.1f} {y - 70:.1f} {cx + hw:.1f} {y:.1f} Z" fill="#C5CEDA" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    visor = f'<path d="M{cx - hw * 0.9:.1f} {y - 2:.1f} Q {cx:.1f} {y - 24:.1f} {cx + hw * 0.9:.1f} {y - 2:.1f}" stroke="{LINE}" stroke-width="12" fill="none" stroke-linecap="round"/><path d="M{cx - hw * 0.9:.1f} {y - 2:.1f} Q {cx:.1f} {y - 24:.1f} {cx + hw * 0.9:.1f} {y - 2:.1f}" stroke="#E8EEF7" stroke-width="6" fill="none" stroke-linecap="round"/>'
    plume = "".join(f'<path d="M{cx:.1f} {y - 52:.1f} C {cx + s * 10:.1f} {y - 80:.1f} {cx - 30 + s * 6:.1f} {y - 96:.1f} {cx - 44 + s * 8:.1f} {y - 86:.1f}" stroke="{c}" stroke-width="{w}" fill="none" stroke-linecap="round"/>' for s, c, w in ((0, LINE, 18), (0, "#E4505C", 11), (1, "#F590B4", 5)))
    return svg(plume + dome + visor)


def tricorn(m):
    cx = m["cx"]
    y = top(m, cx) + 16
    w = m["rx"] * 1.0
    hat = (f'<path d="M{cx - w:.1f} {y - 4:.1f} Q {cx - w * 0.5:.1f} {y - 54:.1f} {cx:.1f} {y - 50:.1f} Q {cx + w * 0.5:.1f} {y - 54:.1f} {cx + w:.1f} {y - 4:.1f} Q {cx:.1f} {y - 22:.1f} {cx - w:.1f} {y - 4:.1f} Z" fill="#3B3346" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
           f'<path d="M{cx - w * 0.92:.1f} {y - 8:.1f} Q {cx:.1f} {y - 26:.1f} {cx + w * 0.92:.1f} {y - 8:.1f}" stroke="#D9961A" stroke-width="5" fill="none"/>')
    skull = (f'<circle cx="{cx:.1f}" cy="{y - 34:.1f}" r="9" fill="#FFFFFF" stroke="{LINE}" stroke-width="2.5"/>'
             f'<circle cx="{cx - 3:.1f}" cy="{y - 35:.1f}" r="2" fill="{LINE}"/><circle cx="{cx + 3:.1f}" cy="{y - 35:.1f}" r="2" fill="{LINE}"/>')
    feather = f'<path d="M{cx + w * 0.5:.1f} {y - 40:.1f} q 30 -30 50 -14 q -24 -2 -50 14 Z" fill="#E4505C" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
    return svg(feather + hat + skull)


def top_hat(m):
    cx = m["cx"] + 4
    y = top(m, cx) + 14
    bw, hw, h = m["rx"] * 0.72, m["rx"] * 0.46, 70
    g = f'<g transform="rotate(8 {cx:.1f} {y:.1f})">'
    crown = f'<path d="M{cx - hw:.1f} {y - 4:.1f} L {cx - hw * 0.92:.1f} {y - h:.1f} Q {cx:.1f} {y - h - 8:.1f} {cx + hw * 0.92:.1f} {y - h:.1f} L {cx + hw:.1f} {y - 4:.1f} Z" fill="#3B3346" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    brim = f'<ellipse cx="{cx:.1f}" cy="{y - 2:.1f}" rx="{bw:.1f}" ry="11" fill="#3B3346" stroke="{LINE}" stroke-width="{W}"/>'
    band = f'<path d="M{cx - hw:.1f} {y - 18:.1f} Q {cx:.1f} {y - 12:.1f} {cx + hw:.1f} {y - 18:.1f} L {cx + hw:.1f} {y - 30:.1f} Q {cx:.1f} {y - 24:.1f} {cx - hw:.1f} {y - 30:.1f} Z" fill="#E4505C"/>'
    flower = "".join(f'<circle cx="{cx + hw - 4 + 6 * math.cos(math.radians(a)):.1f}" cy="{y - 24 + 6 * math.sin(math.radians(a)):.1f}" r="5" fill="#FFFFFF" stroke="{LINE}" stroke-width="2"/>' for a in range(0, 360, 72)) + f'<circle cx="{cx + hw - 4:.1f}" cy="{y - 24:.1f}" r="3.5" fill="#FFD84D"/>'
    return svg(g + crown + brim + band + flower + "</g>")


def jester_hat(m):
    cx = m["cx"]
    y = top(m, cx) + m["ry"] * 0.36
    hw = m["rx"] * 0.8
    out = ""
    for s, col in ((-1, "#7C4DD6"), (1, "#F59A4A"), (0, "#86D9B0")):
        tipx = cx + s * (hw + 26)
        tipy = y - 30 if s else y - 72
        out += f'<path d="M{cx - hw * 0.5 + s * hw * 0.5:.1f} {y - 8:.1f} Q {cx + s * hw * 0.7:.1f} {tipy - 10:.1f} {tipx:.1f} {tipy:.1f} Q {cx + s * hw * 0.3:.1f} {y - 30:.1f} {cx + hw * 0.5 + s * hw * 0.5:.1f} {y - 8:.1f} Z" fill="{col}" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
        out += f'<circle cx="{tipx:.1f}" cy="{tipy:.1f}" r="8" fill="#FFD84D" stroke="{LINE}" stroke-width="3"/>'
    band = f'<path d="M{cx - hw:.1f} {y:.1f} Q {cx:.1f} {y - 16:.1f} {cx + hw:.1f} {y:.1f}" stroke="{LINE}" stroke-width="20" fill="none" stroke-linecap="round"/><path d="M{cx - hw:.1f} {y:.1f} Q {cx:.1f} {y - 16:.1f} {cx + hw:.1f} {y:.1f}" stroke="#FFF4CC" stroke-width="12" fill="none" stroke-linecap="round"/>'
    return svg(out + band)


def mortarboard(m):
    cx = m["cx"]
    y = top(m, cx) + m["ry"] * 0.3
    hw = m["rx"] * 0.55
    cap = f'<path d="M{cx - hw:.1f} {y:.1f} Q {cx:.1f} {y + 10:.1f} {cx + hw:.1f} {y:.1f} L {cx + hw:.1f} {y - 22:.1f} L {cx - hw:.1f} {y - 22:.1f} Z" fill="#3B3346" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    board = f'<path d="M{cx:.1f} {y - 44:.1f} L {cx + hw * 1.6:.1f} {y - 26:.1f} L {cx:.1f} {y - 10:.1f} L {cx - hw * 1.6:.1f} {y - 26:.1f} Z" fill="#3B3346" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    tassel = f'<path d="M{cx:.1f} {y - 27:.1f} Q {cx + hw * 1.2:.1f} {y - 26:.1f} {cx + hw * 1.3:.1f} {y + 6:.1f}" stroke="#FFCF5C" stroke-width="3.5" fill="none"/><path d="M{cx + hw * 1.3 - 5:.1f} {y + 4:.1f} h 10 l -2 16 h -6 Z" fill="#FFCF5C" stroke="{LINE}" stroke-width="2"/><circle cx="{cx:.1f}" cy="{y - 27:.1f}" r="4" fill="#FFCF5C"/>'
    return svg(cap + board + tassel)


def flower_bonnet(m):
    cx = m["cx"]
    rx, ry = m["rx"] + 10, m["ry"] + 10
    cy = m["cy"] - 6
    brim = f'<path d="M{cx - rx:.1f} {cy + 20:.1f} C {cx - rx:.1f} {cy - ry - 10:.1f} {cx + rx:.1f} {cy - ry - 10:.1f} {cx + rx:.1f} {cy + 20:.1f} Q {cx:.1f} {cy - ry * 0.55:.1f} {cx - rx:.1f} {cy + 20:.1f} Z" fill="#FFF0C2" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    weave = "".join(f'<path d="M{cx + f * rx:.1f} {cy - ry * 0.9 * (1 - abs(f) ** 2) + 6:.1f} l 0 12" stroke="#E2C27A" stroke-width="3" stroke-linecap="round"/>' for f in (-0.7, -0.35, 0, 0.35, 0.7))
    ribbon = "".join(f'<path d="M{cx + s * rx:.1f} {cy + 20:.1f} q {s * 6:.1f} 30 {s * -6:.1f} 52" stroke="{LINE}" stroke-width="10" fill="none" stroke-linecap="round"/><path d="M{cx + s * rx:.1f} {cy + 20:.1f} q {s * 6:.1f} 30 {s * -6:.1f} 52" stroke="#F7A8C4" stroke-width="5" fill="none" stroke-linecap="round"/>' for s in (-1, 1))
    flowers = ""
    for fx, col in ((-0.45, "#F7A8C4"), (-0.2, "#FFFFFF"), (0.05, "#C8A8FF")):
        x = cx + fx * rx
        y = cy - ry * 0.86 * (1 - fx * fx) + 2
        flowers += "".join(f'<circle cx="{x + 6 * math.cos(math.radians(a)):.1f}" cy="{y + 6 * math.sin(math.radians(a)):.1f}" r="5.5" fill="{col}" stroke="{LINE}" stroke-width="2"/>' for a in range(0, 360, 72)) + f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.5" fill="#FFD84D"/>'
    return svg(ribbon + brim + weave + flowers)


# --- one species --------------------------------------------------------------

def lion_mane(m):
    # Kitten: a fluffy lion's mane all round the face, as one scalloped ring
    # (outer edge in bumps, the face cut out), since the head is under it.
    cx, cy = m["cx"], m["cy"] + 6
    n = 16
    R = lambda a, k: (cx + (m["rx"] + k) * math.cos(a), cy + (m["ry"] + k) * math.sin(a))
    pts = [R(2 * math.pi * i / n, 26) for i in range(n)]
    d = f"M{pts[0][0]:.1f} {pts[0][1]:.1f} "
    for i in range(n):
        x2, y2 = pts[(i + 1) % n]
        d += f"A 15 15 0 0 1 {x2:.1f} {y2:.1f} "
    d += "Z "
    hx, hy, hrx, hry = cx, m["cy"], m["rx"] - 1, m["ry"] - 1
    d += f"M{hx - hrx:.1f} {hy:.1f} A {hrx:.1f} {hry:.1f} 0 1 0 {hx + hrx:.1f} {hy:.1f} A {hrx:.1f} {hry:.1f} 0 1 0 {hx - hrx:.1f} {hy:.1f} Z"
    tufts = "".join(f'<path d="M{R(a, 14)[0]:.1f} {R(a, 14)[1]:.1f} L {R(a, 30)[0]:.1f} {R(a, 30)[1]:.1f}" stroke="#C47A2E" stroke-width="3" stroke-linecap="round"/>'
                    for a in [2 * math.pi * (i + 0.5) / n for i in range(n)])
    return svg(f'<path d="{d}" fill="#E8A04F" fill-rule="evenodd" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>' + tufts)


def garden_hat(m):
    # Rabbit: a wide straw sun hat with two little carrots, ears through.
    cx = m["cx"]
    y = top(m, cx) + 18
    bw = m["rx"] * 1.2
    brim = f'<ellipse cx="{cx:.1f}" cy="{y:.1f}" rx="{bw:.1f}" ry="16" fill="#F2D58A" stroke="{LINE}" stroke-width="{W}"/>'
    crown = f'<path d="M{cx - 44:.1f} {y - 4:.1f} C {cx - 44:.1f} {y - 40:.1f} {cx + 44:.1f} {y - 40:.1f} {cx + 44:.1f} {y - 4:.1f} Z" fill="#F2D58A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    band = f'<path d="M{cx - 43:.1f} {y - 12:.1f} Q {cx:.1f} {y - 6:.1f} {cx + 43:.1f} {y - 12:.1f}" stroke="#86D9B0" stroke-width="8" fill="none"/>'
    weave = "".join(f'<path d="M{cx + dx:.1f} {y + 2:.1f} l 4 8" stroke="#D9B45A" stroke-width="2.5" stroke-linecap="round"/>' for dx in range(-int(bw) + 16, int(bw) - 10, 18))
    carrots = "".join(f'<g transform="rotate({r} {cx + dx:.1f} {y - 14:.1f})"><path d="M{cx + dx - 6:.1f} {y - 14:.1f} h 12 l -6 24 Z" fill="#F59A4A" stroke="{LINE}" stroke-width="2.5" stroke-linejoin="round"/><path d="M{cx + dx:.1f} {y - 15:.1f} q -6 -10 -2 -14 q 4 6 2 14 q 4 -10 10 -10 q -2 8 -10 10" fill="#6CC27A" stroke="{LINE}" stroke-width="2"/></g>' for dx, r in ((28, 30), (40, 60)))
    return svg(brim + weave + crown + band + carrots)


ITEMS = {
    "frog_hood": (frog_hood, "Frog hood", "head", "large"),
    "dino_hood": (dino_hood, "Dino hood", "head", "large"),
    "bear_hood": (bear_hood, "Bear hood", "head", "large"),
    "astronaut_helmet": (astronaut_helmet, "Space helmet", "head", "large"),
    "viking_helmet": (viking_helmet, "Viking helmet", "head", "large"),
    "knight_helmet": (knight_helmet, "Knight's helmet", "head", "large"),
    "tricorn": (tricorn, "Pirate hat", "head", "large"),
    "top_hat": (top_hat, "Top hat", "head", "large"),
    "jester_hat": (jester_hat, "Jester hat", "head", "large"),
    "mortarboard": (mortarboard, "Graduation cap", "head", "large"),
    "flower_bonnet": (flower_bonnet, "Flower bonnet", "head", "large"),
    "lion_mane": (lion_mane, "Lion mane", "head", "large", "kitten"),
    "garden_hat": (garden_hat, "Garden hat", "head", "large", "rabbit"),
}

# Parts of the wearer hidden while an item is on: item -> species -> parts.
HIDES = {
    "frog_hood": {"kitten": ["ears"], "duckling": ["tuft"], "hedgehog": ["ears"], "squirrel": ["ears"], "otter": ["ears"], "panda": ["ears"]},
    "dino_hood": {"kitten": ["ears"], "duckling": ["tuft"], "hedgehog": ["ears"], "squirrel": ["ears"], "otter": ["ears"], "panda": ["ears"]},
    "bear_hood": {"kitten": ["ears"], "duckling": ["tuft"], "hedgehog": ["ears"], "squirrel": ["ears"], "otter": ["ears"], "panda": ["ears"]},
    "flower_bonnet": {"kitten": ["ears"], "duckling": ["tuft"], "hedgehog": ["ears"], "squirrel": ["ears"], "otter": ["ears"], "panda": ["ears"]},
    "lion_mane": {"kitten": ["ears"]},
}
