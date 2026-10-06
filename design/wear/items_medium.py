"""Medium clothes (400 berries): hats, headbands and neckwear. Each draw(m)
takes a species' head metrics (build.py SPECIES) and returns the item's SVG."""
import math

from common import LINE, W, svg, top, star, heart, neck_arc


def _crown_y(m):
    return top(m, m["cx"])


def baseball_cap(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.32
    hw = m["rx"] * 0.74
    dome = (f'<path d="M{cx - hw:.1f} {y:.1f} C {cx - hw:.1f} {y - 50:.1f} {cx + hw:.1f} {y - 50:.1f} {cx + hw:.1f} {y:.1f} Z" fill="#E4505C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
            f'<path d="M{cx:.1f} {y - 37:.1f} V {y:.1f}" stroke="#B83A45" stroke-width="3"/>'
            f'<circle cx="{cx:.1f}" cy="{y - 38:.1f}" r="5" fill="#E4505C" stroke="{LINE}" stroke-width="3"/>')
    peak = f'<path d="M{cx + hw * 0.2:.1f} {y - 4:.1f} Q {cx + hw + 30:.1f} {y - 8:.1f} {cx + hw + 34:.1f} {y + 6:.1f} Q {cx + hw * 0.6:.1f} {y + 12:.1f} {cx + hw * 0.1:.1f} {y + 4:.1f} Z" fill="#FFFFFF" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    return svg(dome + peak + star(cx - 12, y - 18, 8, "#FFFFFF", sw=2.5))


def bucket_hat(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.36
    hw = m["rx"] * 0.66
    brim = f'<path d="M{cx - hw - 20:.1f} {y + 6:.1f} Q {cx:.1f} {y + 22:.1f} {cx + hw + 20:.1f} {y + 6:.1f} L {cx + hw:.1f} {y - 6:.1f} L {cx - hw:.1f} {y - 6:.1f} Z" fill="#9ED7A8" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    crown = f'<path d="M{cx - hw:.1f} {y - 4:.1f} C {cx - hw + 4:.1f} {y - 44:.1f} {cx + hw - 4:.1f} {y - 44:.1f} {cx + hw:.1f} {y - 4:.1f} Z" fill="#9ED7A8" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    dots = "".join(f'<circle cx="{cx + dx:.1f}" cy="{y + dy:.1f}" r="4" fill="#FFFFFF"/>' for dx, dy in ((-hw * 0.5, -20), (0, -30), (hw * 0.5, -18), (-hw * 0.2, -10), (hw * 0.25, -6)))
    return svg(brim + crown + dots)


def flower_crown(m):
    cx = m["cx"]
    y0 = _crown_y(m) + 16
    out = ""
    cols = ["#F7A8C4", "#FFFFFF", "#FFD84D", "#C8A8FF", "#F7A8C4", "#FFFFFF", "#FFD84D"]
    for i, f in enumerate([-0.66, -0.44, -0.22, 0, 0.22, 0.44, 0.66]):
        x = cx + f * m["rx"]
        y = top(m, x) + 12
        out += f'<path d="M{x - 10:.1f} {y + 4:.1f} q 4 -10 12 -6" fill="#6CC27A" stroke="{LINE}" stroke-width="2.5"/>'
        out += "".join(f'<circle cx="{x + 6 * math.cos(math.radians(a)):.1f}" cy="{y + 6 * math.sin(math.radians(a)):.1f}" r="5.5" fill="{cols[i]}" stroke="{LINE}" stroke-width="2.5"/>' for a in range(0, 360, 72))
        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.5" fill="#F59A4A"/>'
    return svg(out)


def headphones(m):
    cx = m["cx"]
    y = _crown_y(m) - 6
    rx = m["rx"] * 0.98
    band = f'<path d="M{cx - rx:.1f} {m["cy"]:.1f} C {cx - rx:.1f} {y - 10:.1f} {cx + rx:.1f} {y - 10:.1f} {cx + rx:.1f} {m["cy"]:.1f}" stroke="{LINE}" stroke-width="16" fill="none" stroke-linecap="round"/><path d="M{cx - rx:.1f} {m["cy"]:.1f} C {cx - rx:.1f} {y - 10:.1f} {cx + rx:.1f} {y - 10:.1f} {cx + rx:.1f} {m["cy"]:.1f}" stroke="#B59AF0" stroke-width="9" fill="none" stroke-linecap="round"/>'
    cups = "".join(f'<rect x="{cx + s * rx - 13:.1f}" y="{m["cy"] - 14:.1f}" width="26" height="40" rx="12" fill="#7C4DD6" stroke="{LINE}" stroke-width="{W}"/>'
                   f'<rect x="{cx + s * rx - 7:.1f}" y="{m["cy"] - 6:.1f}" width="14" height="24" rx="7" fill="#C8A8FF"/>' for s in (-1, 1))
    return svg(band + cups)


def pirate_bandana(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.42
    hw = m["rx"] * 0.86
    cap = f'<path d="M{cx - hw:.1f} {y:.1f} C {cx - hw:.1f} {y - 52:.1f} {cx + hw:.1f} {y - 52:.1f} {cx + hw:.1f} {y:.1f} Q {cx:.1f} {y + 10:.1f} {cx - hw:.1f} {y:.1f} Z" fill="#E4505C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    dots = "".join(f'<circle cx="{cx + dx:.1f}" cy="{y + dy:.1f}" r="4.5" fill="#FFFFFF"/>' for dx, dy in ((-hw * 0.55, -16), (-hw * 0.1, -32), (hw * 0.4, -24), (hw * 0.15, -8), (-hw * 0.35, -2)))
    knot = f'<path d="M{cx + hw - 6:.1f} {y - 4:.1f} l 22 -4 l -4 14 Z M{cx + hw - 6:.1f} {y - 4:.1f} l 18 14 l -12 6 Z" fill="#E4505C" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
    return svg(cap + dots + knot)


def cowboy_hat(m):
    cx = m["cx"]
    y = _crown_y(m) + 12
    bw = m["rx"] * 1.05
    brim = f'<path d="M{cx - bw:.1f} {y - 12:.1f} Q {cx - bw * 0.6:.1f} {y + 12:.1f} {cx:.1f} {y + 10:.1f} Q {cx + bw * 0.6:.1f} {y + 12:.1f} {cx + bw:.1f} {y - 12:.1f} Q {cx + bw * 0.7:.1f} {y + 2:.1f} {cx:.1f} {y:.1f} Q {cx - bw * 0.7:.1f} {y + 2:.1f} {cx - bw:.1f} {y - 12:.1f} Z" fill="#C88A4E" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    crown = f'<path d="M{cx - 38:.1f} {y + 2:.1f} C {cx - 42:.1f} {y - 40:.1f} {cx - 20:.1f} {y - 50:.1f} {cx:.1f} {y - 40:.1f} C {cx + 20:.1f} {y - 50:.1f} {cx + 42:.1f} {y - 40:.1f} {cx + 38:.1f} {y + 2:.1f} Z" fill="#D99A5B" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    band = f'<path d="M{cx - 38:.1f} {y - 8:.1f} Q {cx:.1f} {y - 2:.1f} {cx + 38:.1f} {y - 8:.1f}" stroke="#7A4A2A" stroke-width="7" fill="none"/>' + star(cx, y - 8, 6, "#FFCF5C", sw=2)
    return svg(crown + brim + band)


def alice_band(m):
    cx = m["cx"]
    rx = m["rx"] * 0.86
    y = _crown_y(m) + 14
    band = f'<path d="M{cx - rx:.1f} {y + 34:.1f} Q {cx:.1f} {y - 30:.1f} {cx + rx:.1f} {y + 34:.1f}" stroke="{LINE}" stroke-width="15" fill="none" stroke-linecap="round"/><path d="M{cx - rx:.1f} {y + 34:.1f} Q {cx:.1f} {y - 30:.1f} {cx + rx:.1f} {y + 34:.1f}" stroke="#F590B4" stroke-width="8" fill="none" stroke-linecap="round"/>'
    bx, by = cx + rx * 0.5, y + 4
    bow = (f'<path d="M{bx:.1f} {by:.1f} C {bx - 12:.1f} {by - 16:.1f} {bx - 28:.1f} {by - 12:.1f} {bx - 26:.1f} {by:.1f} C {bx - 28:.1f} {by + 12:.1f} {bx - 12:.1f} {by + 14:.1f} {bx:.1f} {by:.1f} Z M{bx:.1f} {by:.1f} C {bx + 12:.1f} {by - 16:.1f} {bx + 28:.1f} {by - 12:.1f} {bx + 26:.1f} {by:.1f} C {bx + 28:.1f} {by + 12:.1f} {bx + 12:.1f} {by + 14:.1f} {bx:.1f} {by:.1f} Z" fill="#F590B4" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
           f'<circle cx="{bx:.1f}" cy="{by:.1f}" r="6" fill="#E07BA0" stroke="{LINE}" stroke-width="3"/>')
    return svg(band + bow)


def tiara(m):
    cx = m["cx"]
    y = _crown_y(m) + 14
    w = m["rx"] * 0.5
    pts = f"{cx - w:.1f},{y:.1f} {cx - w * 0.7:.1f},{y - 12:.1f} {cx - w * 0.35:.1f},{y - 6:.1f} {cx:.1f},{y - 26:.1f} {cx + w * 0.35:.1f},{y - 6:.1f} {cx + w * 0.7:.1f},{y - 12:.1f} {cx + w:.1f},{y:.1f}"
    return svg(f'<polygon points="{pts}" fill="#E8EEF7" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
               f'<path d="M{cx - w:.1f} {y:.1f} Q {cx:.1f} {y + 6:.1f} {cx + w:.1f} {y:.1f}" stroke="{LINE}" stroke-width="3" fill="none"/>'
               f'<circle cx="{cx:.1f}" cy="{y - 12:.1f}" r="5" fill="#F590B4" stroke="{LINE}" stroke-width="2"/>'
               + "".join(f'<circle cx="{cx + s * w * 0.62:.1f}" cy="{y - 4:.1f}" r="3.2" fill="#7FBCF5" stroke="{LINE}" stroke-width="2"/>' for s in (-1, 1)))


def chef_hat(m):
    cx = m["cx"]
    y = _crown_y(m) + 14
    hw = m["rx"] * 0.42
    band = f'<rect x="{cx - hw:.1f}" y="{y - 18:.1f}" width="{2 * hw:.1f}" height="22" rx="4" fill="#FFFFFF" stroke="{LINE}" stroke-width="{W}"/>'
    puffs = "".join(f'<circle cx="{cx + dx:.1f}" cy="{y - 18 - dy:.1f}" r="{r}" fill="#FFFFFF" stroke="{LINE}" stroke-width="{W}"/>' for dx, dy, r in ((-hw * 0.7, 18, 20), (hw * 0.7, 18, 20), (0, 30, 24)))
    cover = f'<rect x="{cx - hw + 3:.1f}" y="{y - 40:.1f}" width="{2 * hw - 6:.1f}" height="24" fill="#FFFFFF"/>'
    lines = "".join(f'<path d="M{cx + dx:.1f} {y - 14:.1f} v 14" stroke="#E3DCD3" stroke-width="2.5"/>' for dx in (-hw * 0.5, 0, hw * 0.5))
    return svg(puffs + cover + band + lines)


def bow_tie(m):
    cx, y = m["cx"], m["chin"] - 2
    return svg(f'<path d="M{cx:.1f} {y:.1f} L {cx - 26:.1f} {y - 13:.1f} Q {cx - 30:.1f} {y:.1f} {cx - 26:.1f} {y + 13:.1f} Z M{cx:.1f} {y:.1f} L {cx + 26:.1f} {y - 13:.1f} Q {cx + 30:.1f} {y:.1f} {cx + 26:.1f} {y + 13:.1f} Z" fill="#E4505C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
               f'<rect x="{cx - 7:.1f}" y="{y - 8:.1f}" width="14" height="16" rx="5" fill="#C93C48" stroke="{LINE}" stroke-width="3"/>'
               + "".join(f'<circle cx="{cx + s * dx:.1f}" cy="{y + dy:.1f}" r="2.2" fill="#FFFFFF"/>' for s in (-1, 1) for dx, dy in ((14, -4), (19, 5))))


def sweatband(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.38
    hw = m["rx"] * 0.9
    d = f"M{cx - hw:.1f} {y:.1f} Q {cx:.1f} {y - 22:.1f} {cx + hw:.1f} {y:.1f}"
    return svg(f'<path d="{d}" stroke="{LINE}" stroke-width="26" fill="none" stroke-linecap="round"/>'
               f'<path d="{d}" stroke="#FFFFFF" stroke-width="18" fill="none" stroke-linecap="round"/>'
               f'<path d="{d}" stroke="#7FBCF5" stroke-width="6" fill="none" stroke-linecap="round"/>')


def bee_antennae(m):
    cx = m["cx"]
    y = _crown_y(m) + 16
    out = f'<path d="M{cx - 40:.1f} {y + 4:.1f} Q {cx:.1f} {y - 18:.1f} {cx + 40:.1f} {y + 4:.1f}" stroke="{LINE}" stroke-width="10" fill="none" stroke-linecap="round"/><path d="M{cx - 40:.1f} {y + 4:.1f} Q {cx:.1f} {y - 18:.1f} {cx + 40:.1f} {y + 4:.1f}" stroke="#2B2330" stroke-width="5" fill="none" stroke-linecap="round"/>'
    for s in (-1, 1):
        x0, y0 = cx + s * 20, y - 8
        out += f'<path d="M{x0:.1f} {y0:.1f} q {s * 4:.1f} -30 {s * 18:.1f} -40" stroke="{LINE}" stroke-width="4" fill="none" stroke-linecap="round"/>'
        out += f'<circle cx="{x0 + s * 18:.1f}" cy="{y0 - 42:.1f}" r="9" fill="#FFD84D" stroke="{LINE}" stroke-width="{W}"/><path d="M{x0 + s * 18 - 8:.1f} {y0 - 42:.1f} h 16" stroke="{LINE}" stroke-width="3.5"/>'
    return svg(out)


def devil_horns(m):
    cx = m["cx"]
    out = ""
    for s in (-1, 1):
        x = cx + s * m["rx"] * 0.3
        y = top(m, x) + 8
        out += f'<path d="M{x - 11:.1f} {y:.1f} Q {x + s * 4:.1f} {y - 20:.1f} {x + s * 14:.1f} {y - 32:.1f} Q {x + s * 10:.1f} {y - 12:.1f} {x + 11:.1f} {y:.1f} Z" fill="#E4505C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    return svg(out)


def halo(m):
    cx = m["cx"]
    y = _crown_y(m) - 22
    rx = m["rx"] * 0.55
    return svg(f'<ellipse cx="{cx:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="12" fill="none" stroke="{LINE}" stroke-width="14"/>'
               f'<ellipse cx="{cx:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="12" fill="none" stroke="#FFE07A" stroke-width="8"/>'
               f'<path d="M{cx - rx * 0.5:.1f} {y - 9:.1f} q {rx * 0.3:.1f} -4 {rx * 0.6:.1f} -2" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>')


def visor(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.36
    hw = m["rx"] * 0.88
    band = f'<path d="M{cx - hw:.1f} {y:.1f} Q {cx:.1f} {y - 22:.1f} {cx + hw:.1f} {y:.1f}" stroke="{LINE}" stroke-width="18" fill="none" stroke-linecap="round"/><path d="M{cx - hw:.1f} {y:.1f} Q {cx:.1f} {y - 22:.1f} {cx + hw:.1f} {y:.1f}" stroke="#86D9B0" stroke-width="10" fill="none" stroke-linecap="round"/>'
    peak = f'<path d="M{cx - hw * 0.6:.1f} {y - 6:.1f} Q {cx:.1f} {y + 26:.1f} {cx + hw * 0.6:.1f} {y - 6:.1f} Q {cx:.1f} {y + 4:.1f} {cx - hw * 0.6:.1f} {y - 6:.1f} Z" fill="#86D9B0" fill-opacity="0.85" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    return svg(band + peak)


def lei(m):
    cx, y = m["cx"], m["chin"] - 2
    half = m["rx"] * 0.58
    out = ""
    cols = ["#F7A8C4", "#FFD84D", "#FFFFFF", "#F59A4A", "#C8A8FF"]
    for i in range(10):
        f = i / 9
        x = cx - half + 2 * half * f
        yy = y - 6 + 22 * (1 - (2 * f - 1) ** 2)
        out += "".join(f'<ellipse cx="{x + 6 * math.cos(math.radians(a)):.1f}" cy="{yy + 6 * math.sin(math.radians(a)):.1f}" rx="6" ry="4.5" transform="rotate({a} {x + 6 * math.cos(math.radians(a)):.1f} {yy + 6 * math.sin(math.radians(a)):.1f})" fill="{cols[i % 5]}" stroke="{LINE}" stroke-width="2"/>' for a in range(0, 360, 72))
        out += f'<circle cx="{x:.1f}" cy="{yy:.1f}" r="2.6" fill="#F59A4A"/>'
    return svg(out)


def necktie(m):
    cx, y = m["cx"], m["chin"] - 6
    return svg(neck_arc(m, "#FFFFFF", 8)
               + f'<path d="M{cx - 8:.1f} {y + 6:.1f} L {cx + 8:.1f} {y + 6:.1f} L {cx + 5:.1f} {y + 14:.1f} L {cx + 12:.1f} {y + 48:.1f} L {cx:.1f} {y + 58:.1f} L {cx - 12:.1f} {y + 48:.1f} L {cx - 5:.1f} {y + 14:.1f} Z" fill="#5B8FD6" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
               + "".join(f'<path d="M{cx - 8:.1f} {y + k:.1f} l 16 -6" stroke="#FFCF5C" stroke-width="3.5" stroke-linecap="round"/>' for k in (26, 38, 50)))


def mushroom_hat(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.3
    hw = m["rx"] * 0.95
    cap = f'<path d="M{cx - hw:.1f} {y:.1f} C {cx - hw:.1f} {y - 66:.1f} {cx + hw:.1f} {y - 66:.1f} {cx + hw:.1f} {y:.1f} Q {cx:.1f} {y + 12:.1f} {cx - hw:.1f} {y:.1f} Z" fill="#E4505C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    spots = "".join(f'<ellipse cx="{cx + dx:.1f}" cy="{y + dy:.1f}" rx="{r}" ry="{r * 0.8:.1f}" fill="#FFFFFF"/>' for dx, dy, r in ((-hw * 0.55, -16, 9), (-hw * 0.1, -38, 11), (hw * 0.45, -24, 10), (hw * 0.1, -10, 6), (-hw * 0.32, -34, 5)))
    return svg(cap + spots)


def santa_hat(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.35
    hw = m["rx"] * 0.74
    body = f'<path d="M{cx - hw:.1f} {y:.1f} C {cx - hw * 0.6:.1f} {y - 60:.1f} {cx + hw * 0.4:.1f} {y - 80:.1f} {cx + hw + 22:.1f} {y - 40:.1f} Q {cx + hw * 0.6:.1f} {y - 40:.1f} {cx + hw:.1f} {y:.1f} Z" fill="#E4505C" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    trim = f'<rect x="{cx - hw - 6:.1f}" y="{y - 12:.1f}" width="{2 * hw + 12:.1f}" height="22" rx="11" fill="#FFFFFF" stroke="{LINE}" stroke-width="{W}"/>'
    pom = f'<circle cx="{cx + hw + 24:.1f}" cy="{y - 38:.1f}" r="12" fill="#FFFFFF" stroke="{LINE}" stroke-width="{W}"/>'
    return svg(body + trim + pom)


def pumpkin_hat(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.36
    hw = m["rx"] * 0.82
    lobes = "".join(f'<ellipse cx="{cx + dx * hw:.1f}" cy="{y - 22:.1f}" rx="{hw * 0.42:.1f}" ry="30" fill="#F59A4A" stroke="{LINE}" stroke-width="{W}"/>' for dx in (-0.55, 0.55, -0.2, 0.2))
    mid = f'<ellipse cx="{cx:.1f}" cy="{y - 22:.1f}" rx="{hw * 0.34:.1f}" ry="31" fill="#F7A85A" stroke="{LINE}" stroke-width="{W}"/>'
    stem = f'<path d="M{cx - 5:.1f} {y - 50:.1f} q 2 -16 12 -18" stroke="{LINE}" stroke-width="10" fill="none" stroke-linecap="round"/><path d="M{cx - 5:.1f} {y - 50:.1f} q 2 -16 12 -18" stroke="#6CC27A" stroke-width="5" fill="none" stroke-linecap="round"/>'
    return svg(lobes + mid + stem)


def propeller_cap(m):
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.3
    hw = m["rx"] * 0.7
    segs = ["#E4505C", "#FFD84D", "#5B8FD6", "#6CC27A"]
    out = ""
    for i in range(4):
        a0 = math.pi + i * math.pi / 4
        a1 = a0 + math.pi / 4
        out += f'<path d="M{cx:.1f} {y:.1f} L {cx + hw * math.cos(a0):.1f} {y + 44 * math.sin(a0):.1f} A {hw:.1f} 44 0 0 1 {cx + hw * math.cos(a1):.1f} {y + 44 * math.sin(a1):.1f} Z" fill="{segs[i]}" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
    out += f'<path d="M{cx - hw:.1f} {y:.1f} H {cx + hw:.1f}" stroke="{LINE}" stroke-width="{W}" stroke-linecap="round"/>'
    out += f'<path d="M{cx:.1f} {y - 44:.1f} v -10" stroke="{LINE}" stroke-width="4"/>'
    out += f'<path d="M{cx - 30:.1f} {y - 58:.1f} Q {cx:.1f} {y - 50:.1f} {cx + 30:.1f} {y - 58:.1f} Q {cx:.1f} {y - 64:.1f} {cx - 30:.1f} {y - 58:.1f} Z" fill="#7FBCF5" stroke="{LINE}" stroke-width="3"/><circle cx="{cx:.1f}" cy="{y - 56:.1f}" r="4" fill="#FFD84D" stroke="{LINE}" stroke-width="2"/>'
    return svg(out)


# --- one species --------------------------------------------------------------

def daisy_chain(m):
    # Rabbit: a chain of daisies round the neck.
    cx, y = m["cx"], m["chin"] - 2
    half = m["rx"] * 0.58
    out = f'<path d="M{cx - half:.1f} {y - 6:.1f} Q {cx:.1f} {y + 26:.1f} {cx + half:.1f} {y - 6:.1f}" stroke="#6CC27A" stroke-width="4" fill="none"/>'
    for i in range(7):
        f = i / 6
        x = cx - half + 2 * half * f
        yy = y - 6 + 16 * (1 - (2 * f - 1) ** 2)
        out += "".join(f'<ellipse cx="{x + 7 * math.cos(math.radians(a)):.1f}" cy="{yy + 7 * math.sin(math.radians(a)):.1f}" rx="5.5" ry="3.6" transform="rotate({a} {x + 7 * math.cos(math.radians(a)):.1f} {yy + 7 * math.sin(math.radians(a)):.1f})" fill="#FFFFFF" stroke="{LINE}" stroke-width="2"/>' for a in range(0, 360, 45))
        out += f'<circle cx="{x:.1f}" cy="{yy:.1f}" r="4" fill="#FFD84D" stroke="{LINE}" stroke-width="2"/>'
    return svg(out)


def rain_hat(m):
    # Duckling: a sky-blue sou'wester with a long back brim.
    cx = m["cx"]
    y = _crown_y(m) + m["ry"] * 0.34
    hw = m["rx"] * 0.72
    brim = f'<path d="M{cx - hw - 26:.1f} {y + 2:.1f} Q {cx:.1f} {y + 18:.1f} {cx + hw + 16:.1f} {y - 4:.1f} Q {cx + hw:.1f} {y - 12:.1f} {cx:.1f} {y - 8:.1f} Q {cx - hw:.1f} {y - 8:.1f} {cx - hw - 26:.1f} {y + 2:.1f} Z" fill="#7FBCF5" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    crown = f'<path d="M{cx - hw:.1f} {y - 6:.1f} C {cx - hw:.1f} {y - 50:.1f} {cx + hw:.1f} {y - 50:.1f} {cx + hw:.1f} {y - 6:.1f} Z" fill="#7FBCF5" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
    seam = f'<path d="M{cx - hw * 0.7:.1f} {y - 26:.1f} Q {cx:.1f} {y - 40:.1f} {cx + hw * 0.7:.1f} {y - 26:.1f}" stroke="#4F8FD0" stroke-width="3" fill="none" stroke-dasharray="5 4"/>'
    drop = f'<path d="M{cx + hw * 0.4:.1f} {y - 30:.1f} q 6 8 0 12 q -6 -4 0 -12 Z" fill="#FFFFFF" opacity="0.85"/>'
    return svg(brim + crown + seam + drop)


ITEMS = {
    "baseball_cap": (baseball_cap, "Baseball cap", "head", "medium"),
    "bucket_hat": (bucket_hat, "Bucket hat", "head", "medium"),
    "flower_crown": (flower_crown, "Flower crown", "head", "medium"),
    "headphones": (headphones, "Headphones", "head", "medium"),
    "pirate_bandana": (pirate_bandana, "Pirate bandana", "head", "medium"),
    "cowboy_hat": (cowboy_hat, "Cowboy hat", "head", "medium"),
    "alice_band": (alice_band, "Alice band", "head", "medium"),
    "tiara": (tiara, "Tiara", "head", "medium"),
    "chef_hat": (chef_hat, "Chef hat", "head", "medium"),
    "bow_tie": (bow_tie, "Bow tie", "neck", "medium"),
    "sweatband": (sweatband, "Sweatband", "head", "medium"),
    "bee_antennae": (bee_antennae, "Bee antennae", "head", "medium"),
    "devil_horns": (devil_horns, "Little horns", "head", "medium"),
    "halo": (halo, "Halo", "head", "medium"),
    "visor": (visor, "Sun visor", "head", "medium"),
    "lei": (lei, "Flower lei", "neck", "medium"),
    "necktie": (necktie, "Necktie", "neck", "medium"),
    "mushroom_hat": (mushroom_hat, "Mushroom hat", "head", "medium"),
    "santa_hat": (santa_hat, "Santa hat", "head", "medium"),
    "pumpkin_hat": (pumpkin_hat, "Pumpkin hat", "head", "medium"),
    "propeller_cap": (propeller_cap, "Propeller cap", "head", "medium"),
    "daisy_chain": (daisy_chain, "Daisy chain", "neck", "medium", "rabbit"),
    "rain_hat": (rain_hat, "Rain hat", "head", "medium", "duckling"),
}
