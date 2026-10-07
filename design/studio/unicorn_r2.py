"""Unicorn, studio round 2: Harrison kept A, B, C and E, loved B (lavender),
and asked for much more effort ("it's a legendary"). His idea for later:
about seven colour variants, each with its own secret rarity within
Legendary. So this round settles the base design, all in B's lavender; the
variants come once the shape is chosen.

Every option: chibi foal proportions (C), sparkly eyes with a coloured iris
and lashes, a two-tone spiral horn with a gold ring and a glint, a full mane
(a cap over the head, curtains to the shoulders, bangs that stop above the
eyes) and tail in pastel stripes with light strands, fluffy fetlock tufts
over little hooves, and floating sparkles. The four differ in mane and tail.

    python design/studio/unicorn_r2.py   ->  design/studio/out/unicorn-r2/
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, W, GROUND, EAR_IN, EYE, svg, path, ell, line, blush, shadow, render, HERE

LAV = dict(coat='#EEE4FA', coat_dk='#DCCFF0', muzzle='#F9EAF5', hoof='#B9A6D3', fetlock='#FFFFFF',
           horn='#F4F1FA', horn_band='#D9CCF2', ring='#F2C14E', iris='#9B6FE0',
           mane=['#F5A6C8', '#C69CF0', '#F8C3DD', '#A98BE6'])

_uid = [0]


def uid():
    _uid[0] += 1
    return f'u{_uid[0]}'


def striped(d, colours, angle=-35, band=13, sw=3.5, strands=()):
    """Fill a shape with diagonal pastel stripes, outline it, add light strands."""
    i = uid()
    out = f'<clipPath id="{i}"><path d="{d}"/></clipPath><g clip-path="url(#{i})">'
    out += f'<rect x="-400" y="-400" width="1200" height="1200" fill="{colours[0]}"/>'
    out += f'<g transform="rotate({angle} 160 130)">'
    for k in range(-30, 40):
        out += f'<rect x="-400" y="{k * band}" width="1200" height="{band / 2 + 0.5:.1f}" fill="{colours[k % len(colours)]}"/>'
    out += '</g>'
    for s in strands:
        out += f'<path d="{s}" stroke="#FFFFFF" stroke-width="2.6" fill="none" stroke-linecap="round" opacity="0.55"/>'
    out += '</g>' + path(d, 'none', sw)
    return out


def bez(pts, t):
    while len(pts) > 1:
        pts = [tuple(a + (b - a) * t for a, b in zip(p, q)) for p, q in zip(pts, pts[1:])]
    return pts[0]


def band(ctrl, w0, w1, wave=0.0, waves=3, side=1, curl=0.0, n=30):
    """A tapered band along a Bezier centreline; `side` puts the waves on one
    edge only (+1 left of travel, -1 right). curl rolls the tip into a ringlet.
    Returns (path d, centreline points)."""
    pts = [bez(ctrl, i / n) for i in range(n + 1)]
    if curl:
        (x0, y0), (x1, y1) = pts[-2], pts[-1]
        tx, ty = x1 - x0, y1 - y0
        tl = math.hypot(tx, ty) or 1
        nx, ny = -ty / tl * curl, tx / tl * curl
        r = abs(curl) * 9
        cx, cy = x1 + nx * 9, y1 + ny * 9
        a0 = math.atan2(y1 - cy, x1 - cx)
        for k in range(1, 10):
            a = a0 + k * 0.62 * (1 if curl > 0 else -1)
            rr = r * (1 - k / 13)
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    m = len(pts) - 1
    L, R = [], []
    for i, (x, y) in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, m)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        tl = math.hypot(tx, ty) or 1
        u = i / m
        w = (w0 + (w1 - w0) * u) * 0.5
        wv = wave * math.sin(u * math.pi * waves * 2) * (1 - u * 0.5)
        wl = w + (wv if side > 0 else 0)
        wr = w + (wv if side < 0 else 0)
        L.append((x - ty / tl * wl, y + tx / tl * wl))
        R.append((x + ty / tl * wr, y - tx / tl * wr))
    poly = L + R[::-1]
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in poly) + ' Z', pts


def strand(pts, a=0.15, b=0.7):
    m = len(pts) - 1
    seg = pts[int(m * a):int(m * b)]
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in seg)


def sparkle(x, y, r, colour='#FFE58A', sw=1.6):
    return path(f'M{x} {y - r} Q{x + r * 0.18} {y - r * 0.18} {x + r} {y} Q{x + r * 0.18} {y + r * 0.18} {x} {y + r} '
                f'Q{x - r * 0.18} {y + r * 0.18} {x - r} {y} Q{x - r * 0.18} {y - r * 0.18} {x} {y - r} Z', colour, sw)


def puffs(pts, colour, sw=6):
    out = ''.join(ell(x, y, r, r, colour, sw) for x, y, r in pts)
    out += ''.join(ell(x, y, r, r, colour, 0) for x, y, r in pts)
    out += ''.join(f'<path d="M{x - r * 0.5:.1f} {y - r * 0.15:.1f} q{r * 0.3:.1f} {-r * 0.45:.1f} {r * 0.75:.1f} {-r * 0.25:.1f}" stroke="#FFFFFF" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.6"/>'
                   for x, y, r in pts)
    return out


def ringlet(x, y, r, colour):
    """A round curl: a disc with a spiral line in it."""
    sp = f'M{x + r * 0.55:.1f} {y:.1f} A{r * 0.55:.1f} {r * 0.55:.1f} 0 1 1 {x:.1f} {y - r * 0.55:.1f} A{r * 0.3:.1f} {r * 0.3:.1f} 0 1 1 {x - r * 0.1:.1f} {y + r * 0.2:.1f}'
    return ell(x, y, r, r, colour, 3.2) + line(sp, OL, 2.2, 0.5)


def u_eye(cx, cy, rx, ry, iris, side=1):
    out = ell(cx, cy, rx, ry, EYE, 0)
    out += ell(cx, cy + ry * 0.3, rx * 0.74, ry * 0.52, iris, 0)
    out += f'<circle cx="{cx - rx * 0.35:.1f}" cy="{cy - ry * 0.42:.1f}" r="{rx * 0.42:.1f}" fill="#FFFFFF"/>'
    out += f'<circle cx="{cx + rx * 0.42:.1f}" cy="{cy + ry * 0.36:.1f}" r="{rx * 0.17:.1f}" fill="#FFFFFF"/>'
    out += sparkle(cx + rx * 0.32, cy - ry * 0.02, rx * 0.24, '#FFFFFF', 0)
    d = ''
    for ax, ay, lx, ly in ((-0.8, -0.62, -7, -4), (-0.3, -0.98, -4, -8), (0.3, -1.0, 1, -9)):
        sx, sy = cx + ax * rx * side, cy + ay * ry
        d += f'M{sx:.1f} {sy:.1f} q{lx * side * 0.35:.1f} {ly * 0.65:.1f} {lx * side:.1f} {ly:.1f} '
    return out + line(d, OL, 2.6)


def horn(x, y, h, w, lean, p):
    tip = (x + lean, y - h)
    cone = f'M{x - w / 2:.1f} {y:.1f} L{tip[0]:.1f} {tip[1]:.1f} L{x + w / 2:.1f} {y:.1f} Q{x:.1f} {y + 5:.1f} {x - w / 2:.1f} {y:.1f} Z'
    out = ''
    if p.get('glow'):
        out += f'<circle cx="{tip[0] * 0.7 + x * 0.3:.1f}" cy="{y - h * 0.65:.1f}" r="{h * 0.55:.1f}" fill="#FFF3B8" opacity="0.35"/>'
    i = uid()
    out += path(cone, p['horn'], 3.5)
    out += f'<clipPath id="{i}"><path d="{cone}"/></clipPath><g clip-path="url(#{i})">'
    ang = math.degrees(math.atan2(lean, h))
    out += f'<g transform="rotate({ang:.1f} {x} {y})">'
    for k in range(5):
        y0 = y - h * (0.1 + 0.19 * k)
        out += f'<path d="M{x - w:.1f} {y0 + 5:.1f} L{x + w:.1f} {y0 - 5:.1f} L{x + w:.1f} {y0 - 11:.1f} L{x - w:.1f} {y0 - 1:.1f} Z" fill="{p["horn_band"]}"/>'
    out += '</g></g>' + path(cone, 'none', 3.5)
    out += path(f'M{x - w / 2 - 3:.1f} {y + 1:.1f} Q{x:.1f} {y + 7:.1f} {x + w / 2 + 3:.1f} {y + 1:.1f} L{x + w / 2 + 2:.1f} {y - 5:.1f} Q{x:.1f} {y + 1:.1f} {x - w / 2 - 2:.1f} {y - 5:.1f} Z', p['ring'], 2.6)
    out += sparkle(tip[0] + 8, tip[1] + 9, 6, '#FFFFFF')
    return out


def hoof_leg(x, top, w, coat, p):
    y = GROUND
    out = path(f'M{x - w / 2:.1f} {top:.1f} L{x - w * 0.44:.1f} {y - 10:.1f} L{x + w * 0.44:.1f} {y - 10:.1f} L{x + w / 2:.1f} {top:.1f} Z', coat, 3.5)
    out += path(f'M{x - w / 2 - 1:.1f} {y - 11:.1f} L{x + w / 2 + 1:.1f} {y - 11:.1f} Q{x + w / 2 + 4:.1f} {y:.1f} {x + w / 2:.1f} {y:.1f} L{x - w / 2:.1f} {y:.1f} Q{x - w / 2 - 4:.1f} {y:.1f} {x - w / 2 - 1:.1f} {y - 11:.1f} Z', p['hoof'], 3.2)
    pts = [(x - w * 0.45, y - 14, 6), (x - w * 0.08, y - 16, 7), (x + w * 0.32, y - 15, 6.5), (x + w * 0.6, y - 13, 5)]
    return out + puffs(pts, p['fetlock'], 5)


# --- Mane, bangs and tail by style ------------------------------------------------

def mane_front(p, hx, hy, rx, ry):
    st, m = p['style'], p['mane']
    if st == 'cloud':
        side = [(-1.0, -0.35, 22), (-1.08, 0.15, 21), (-1.0, 0.65, 19), (-0.85, 1.08, 16)]
        out = puffs([(hx + a * rx, hy + b * ry, r) for a, b, r in side], m[0])
        out += puffs([(hx - a * rx, hy + b * ry, r) for a, b, r in side], m[1])
        out += puffs([(hx - rx * 0.55, hy - ry * 0.92, 20), (hx, hy - ry * 1.08, 22), (hx + rx * 0.55, hy - ry * 0.92, 20)], m[2])
        return out
    flow = st == 'flowing'
    drop = 1.75 if flow else 1.35
    # a cap over the head and curtains down to the shoulders
    d = (f'M{hx - rx * 0.95:.1f} {hy + ry * 0.2:.1f} C{hx - rx * 1.18:.1f} {hy - ry * 0.65:.1f} {hx - rx * 0.62:.1f} {hy - ry * 1.25:.1f} {hx:.1f} {hy - ry * 1.16:.1f} '
         f'C{hx + rx * 0.62:.1f} {hy - ry * 1.25:.1f} {hx + rx * 1.18:.1f} {hy - ry * 0.65:.1f} {hx + rx * 0.95:.1f} {hy + ry * 0.2:.1f} '
         f'C{hx + rx * 1.2:.1f} {hy + ry * 0.75:.1f} {hx + rx * 1.12:.1f} {hy + ry * (drop - 0.25):.1f} {hx + rx * 1.28:.1f} {hy + ry * drop:.1f} '
         f'C{hx + rx * 1.0:.1f} {hy + ry * (drop - 0.1):.1f} {hx + rx * 0.78:.1f} {hy + ry * 0.95:.1f} {hx + rx * 0.68:.1f} {hy + ry * 0.55:.1f} '
         f'L{hx - rx * 0.68:.1f} {hy + ry * 0.55:.1f} '
         f'C{hx - rx * 0.78:.1f} {hy + ry * 0.95:.1f} {hx - rx * 1.0:.1f} {hy + ry * (drop - 0.1):.1f} {hx - rx * 1.28:.1f} {hy + ry * drop:.1f} '
         f'C{hx - rx * 1.12:.1f} {hy + ry * (drop - 0.25):.1f} {hx - rx * 1.2:.1f} {hy + ry * 0.75:.1f} {hx - rx * 0.95:.1f} {hy + ry * 0.2:.1f} Z')
    strands = [f'M{hx + s * rx * 1.02:.1f} {hy:.1f} Q{hx + s * rx * 1.12:.1f} {hy + ry * 0.6:.1f} {hx + s * rx * 1.12:.1f} {hy + ry * (drop - 0.2):.1f}' for s in (-1, 1)]
    out = striped(d, m, strands=strands)
    if st in ('curly', 'starlit'):
        for s in (-1, 1):
            for j, (a, b, r) in enumerate(((1.2, 0.55, 13), (1.22, 0.95, 12), (1.3, 1.32, 11))):
                out += ringlet(hx + s * rx * a, hy + ry * b, r, m[(j + (s > 0)) % len(m)])
    return out


def bangs(p, hx, hy, rx, ry, side=False):
    st, m = p['style'], p['mane']
    if st == 'cloud':
        if side:
            return puffs([(hx - rx * 0.05, hy - ry * 0.98, 13), (hx + rx * 0.3, hy - ry * 1.02, 14)], m[2])
        return ''
    curl = 1.0 if st in ('curly', 'starlit') else 0.0
    if side:
        d, pts = band([(hx + rx * 0.3, hy - ry * 1.02), (hx - rx * 0.2, hy - ry * 1.15), (hx - rx * 0.55, hy - ry * 0.55)], 26, 6, curl=-curl)
        return striped(d, m[1:] + m[:1], strands=[strand(pts)])
    # the main swoop, from beside the horn down to the left, stopping above the eye
    d, pts = band([(hx + 10, hy - ry * 1.02), (hx - rx * 0.35, hy - ry * 1.12), (hx - rx * 0.82, hy - ry * 0.42)], 30, 6, curl=-curl)
    out = striped(d, m[1:] + m[:1], strands=[strand(pts)])
    d, pts = band([(hx + 14, hy - ry * 1.0), (hx + rx * 0.45, hy - ry * 1.08), (hx + rx * 0.72, hy - ry * 0.5)], 22, 5, curl=curl * 0.8)
    out += striped(d, m[2:] + m[:2], strands=[strand(pts)])
    return out


def tail_shape(p, root, s, length):
    st, m = p['style'], p['mane']
    x, y = root
    if st == 'cloud':
        return puffs([(x + s * 8, y + 4, 15), (x + s * 22, y + 20, 17), (x + s * 30, y + 42, 15), (x + s * 26, y + 60, 12)], m[1])
    curl = 1.3 if st in ('curly', 'starlit') else 0.0
    wave = 0.0 if st != 'flowing' else 4.0
    d, pts = band([(x, y), (x + s * length * 0.55, y - length * 0.1), (x + s * length * 0.7, y + length * 0.85)],
                  30, 8, wave=wave, waves=2, side=s, curl=s * curl)
    return striped(d, m, angle=55, strands=[strand(pts, 0.1, 0.8)])


def face_front(p, hx, hy, rx, ry):
    out = ''
    for s in (-1, 1):
        ex, ey = hx + s * rx * 0.62, hy - ry * 0.78
        out += path(f'M{ex - 12:.1f} {ey + 14:.1f} Q{ex - 4 * s:.1f} {ey - 16:.1f} {ex + s * 5:.1f} {ey - 25:.1f} Q{ex + 13:.1f} {ey - 2:.1f} {ex + 12:.1f} {ey + 14:.1f} Z', p['coat'], 3.5)
        out += path(f'M{ex - 5:.1f} {ey + 10:.1f} Q{ex:.1f} {ey - 6:.1f} {ex + s * 3:.1f} {ey - 14:.1f} Q{ex + 6:.1f} {ey:.1f} {ex + 5:.1f} {ey + 10:.1f} Z', EAR_IN, 0)
    out += ell(hx, hy, rx, ry, p['coat'], 4)
    out += ell(hx, hy + ry * 0.57, rx * 0.38, ry * 0.25, p['muzzle'], 0)
    out += f'<circle cx="{hx - 7:.1f}" cy="{hy + ry * 0.52:.1f}" r="2" fill="{OL}" opacity="0.5"/><circle cx="{hx + 7:.1f}" cy="{hy + ry * 0.52:.1f}" r="2" fill="{OL}" opacity="0.5"/>'
    out += line(f'M{hx - 7:.1f} {hy + ry * 0.67:.1f} Q{hx:.1f} {hy + ry * 0.77:.1f} {hx + 7:.1f} {hy + ry * 0.67:.1f}', OL, 2.6)
    for s in (-1, 1):
        out += u_eye(hx + s * rx * 0.4, hy + ry * 0.04, rx * 0.19, ry * 0.25, p['iris'], s)
    out += blush(hx - rx * 0.7, hy + ry * 0.36, rx * 0.15, ry * 0.09) + blush(hx + rx * 0.7, hy + ry * 0.36, rx * 0.15, ry * 0.09)
    return out


def stars_on(p, pts):
    if p['style'] != 'starlit':
        return ''
    return ''.join(sparkle(x, y, r, '#FFFFFF', 0) for x, y, r in pts)


def front(p):
    out = shadow(160, 70)
    out += tail_shape(p, (192, 188), 1, 58)
    out += hoof_leg(138, 200, 16, p['coat_dk'], p)
    out += hoof_leg(182, 200, 16, p['coat_dk'], p)
    out += ell(160, 196, 46, 30, p['coat'], 4)
    out += hoof_leg(148, 192, 18, p['coat'], p)
    out += hoof_leg(172, 192, 18, p['coat'], p)
    out += ell(160, 181, 31, 24, p['coat'], 4)
    out += stars_on(p, [(140, 199, 4), (178, 188, 3.5), (156, 208, 3)])
    hx, hy, rx, ry = 160, 106, 64, 56
    out += mane_front(p, hx, hy, rx, ry)
    out += face_front(p, hx, hy, rx, ry)
    out += stars_on(p, [(hx - rx * 0.6, hy - ry * 0.45, 3.5), (hx + rx * 0.62, hy + ry * 0.08, 3)])
    out += horn(hx, hy - ry * 0.9, 44, 17, 0, p)
    out += bangs(p, hx, hy, rx, ry)
    for x, y, r in ((52, 64, 7), (268, 96, 6), (250, 26, 5), (70, 170, 5)):
        out += sparkle(x, y, r)
    return svg(out)


def side(p):
    out = shadow(170, 84)
    bx, by, brx, bry = 184, 194, 54, 32
    hx, hy, rx, ry = 104, 128, 50, 44
    out += tail_shape(p, (bx + brx * 0.88, by - bry * 0.55), 1, 62)
    out += hoof_leg(bx - brx * 0.5 + 12, by, 15, p['coat_dk'], p)
    out += hoof_leg(bx + brx * 0.55 + 12, by, 15, p['coat_dk'], p)
    # a real neck from under the jaw to the chest and the withers
    neck = (f'M{hx + rx * 0.45:.1f} {hy + ry * 0.75:.1f} C{hx + rx * 0.7:.1f} {by - bry * 0.1:.1f} {bx - brx * 0.95:.1f} {by:.1f} {bx - brx * 0.9:.1f} {by + bry * 0.35:.1f} '
            f'L{bx - brx * 0.2:.1f} {by - bry * 0.85:.1f} C{bx - brx * 0.55:.1f} {by - bry * 1.25:.1f} {hx + rx * 1.15:.1f} {hy + ry * 0.35:.1f} {hx + rx * 0.8:.1f} {hy - ry * 0.35:.1f} Z')
    out += path(neck, p['coat'], 4)
    out += ell(bx, by, brx, bry, p['coat'], 4)
    out += path(neck, p['coat'], 0)
    out += hoof_leg(bx - brx * 0.5, by + bry * 0.3, 17, p['coat'], p)
    out += hoof_leg(bx + brx * 0.55, by + bry * 0.3, 17, p['coat'], p)
    out += stars_on(p, [(bx - 8, by - 6, 4), (bx + 26, by + 8, 3.5), (bx - 30, by + 10, 3)])
    # mane: down the crest of the neck, flowing back
    st, m = p['style'], p['mane']
    if st == 'cloud':
        out += puffs([(hx + rx * 0.62, hy - ry * 0.75, 17), (hx + rx * 1.0, hy - ry * 0.3, 17), (hx + rx * 1.28, hy + ry * 0.25, 16),
                      (hx + rx * 1.5, hy + ry * 0.8, 14), (bx - brx * 0.45, by - bry * 0.95, 12)], m[0])
    else:
        curl = 1.1 if st in ('curly', 'starlit') else 0.0
        wave = 5.0 if st == 'flowing' else 3.0
        width = 44 if st == 'flowing' else 38
        d, pts = band([(hx + rx * 0.2, hy - ry * 1.0), (hx + rx * 1.35, hy - ry * 0.75), (bx - brx * 0.3, by - bry * 0.95)],
                      width, 18, wave=wave, waves=3, side=-1, curl=0)
        out += striped(d, m, angle=60, strands=[strand(pts, 0.1, 0.9)])
        if curl:
            n = len(pts) - 1
            for j, u in enumerate((0.42, 0.68, 0.9)):
                x, y = pts[int(n * u)]
                out += ringlet(x + 16 - j * 3, y + 6, 11 - j, m[(j + 1) % len(m)])
    # ear, head, muzzle, face
    ex, ey = hx + rx * 0.32, hy - ry * 0.84
    out += path(f'M{ex - 10:.1f} {ey + 12:.1f} Q{ex - 4:.1f} {ey - 16:.1f} {ex + 4:.1f} {ey - 24:.1f} Q{ex + 12:.1f} {ey - 2:.1f} {ex + 12:.1f} {ey + 12:.1f} Z', p['coat'], 3.5)
    out += path(f'M{ex - 3:.1f} {ey + 8:.1f} Q{ex:.1f} {ey - 6:.1f} {ex + 4:.1f} {ey - 13:.1f} Q{ex + 7:.1f} {ey:.1f} {ex + 5:.1f} {ey + 8:.1f} Z', EAR_IN, 0)
    out += ell(hx, hy, rx, ry, p['coat'], 4)
    out += ell(hx - rx * 0.7, hy + ry * 0.44, rx * 0.44, ry * 0.36, p['muzzle'], 3.2)
    out += f'<circle cx="{hx - rx * 1.02:.1f}" cy="{hy + ry * 0.32:.1f}" r="2.3" fill="{OL}" opacity="0.55"/>'
    out += line(f'M{hx - rx * 1.0:.1f} {hy + ry * 0.6:.1f} Q{hx - rx * 0.88:.1f} {hy + ry * 0.7:.1f} {hx - rx * 0.72:.1f} {hy + ry * 0.62:.1f}', OL, 2.5)
    out += u_eye(hx - rx * 0.16, hy - ry * 0.02, rx * 0.22, ry * 0.27, p['iris'], 1)
    out += blush(hx + rx * 0.24, hy + ry * 0.38, rx * 0.18, ry * 0.1)
    out += stars_on(p, [(hx + rx * 0.45, hy + ry * 0.05, 3.5)])
    out += horn(hx - rx * 0.2, hy - ry * 0.88, 44, 16, -16, p)
    out += bangs(p, hx, hy, rx, ry, side=True)
    for x, y, r in ((36, 58, 6), (200, 112, 5), (276, 148, 6)):
        out += sparkle(x, y, r)
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


OPTIONS = {
    '1': dict(LAV, style='curly', name='Curly foal',
              note='Striped mane with ringlet curls down each side, curly tail, fluffy hoof tufts.'),
    '2': dict(LAV, style='flowing', name='Flowing foal',
              note='A long striped mane to its shoulders and a wavy tail streaming behind.'),
    '3': dict(LAV, style='cloud', glow=True, name='Cloud foal',
              note='Mane and tail like soft pastel clouds; the horn glows.'),
    '4': dict(LAV, style='starlit', glow=True, name='Starlit curly foal',
              note='As 1, with tiny stars twinkling in its coat and a glowing horn.'),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', side(o))):
            sp = f'{out_dir}/unicorn-r2-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/unicorn-r2')
