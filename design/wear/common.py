"""Shared drawing helpers for the clothes generator (build.py)."""
import math

LINE = "#6B4A3A"
W = 4  # outline width, as the critter art


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


def heart(cx, cy, s, fill, rot=0, opacity=1.0, stroke=LINE, sw=3):
    d = (f"M{cx:.1f} {cy + s * 0.9:.1f} C {cx - s * 1.25:.1f} {cy + s * 0.1:.1f} {cx - s * 0.9:.1f} {cy - s * 0.95:.1f} {cx:.1f} {cy - s * 0.35:.1f} "
         f"C {cx + s * 0.9:.1f} {cy - s * 0.95:.1f} {cx + s * 1.25:.1f} {cy + s * 0.1:.1f} {cx:.1f} {cy + s * 0.9:.1f} Z")
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    return f'<path d="{d}" fill="{fill}"{op} stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" transform="rotate({rot} {cx:.1f} {cy:.1f})"/>'


def clip_at(m, side, k=0.45):
    """Where a hair clip sits: up on one side of the head."""
    x = m["cx"] + side * m["rx"] * k
    return x, top(m, x) + 12


def neck_arc(m, colour, width=12, spread=0.55, dip=16):
    """A band under the chin, outlined."""
    cx, y = m["cx"], m["chin"] - 6
    half = m["rx"] * spread
    d = f"M{cx - half:.1f} {y - 6:.1f} Q {cx} {y + dip:.1f} {cx + half:.1f} {y - 6:.1f}"
    return (f'<path d="{d}" stroke="{LINE}" stroke-width="{width + 2 * W}" fill="none" stroke-linecap="round"/>'
            f'<path d="{d}" stroke="{colour}" stroke-width="{width}" fill="none" stroke-linecap="round"/>')
