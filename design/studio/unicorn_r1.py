"""Unicorn, studio round 1: six takes, each a front view and a side view.

The unicorn is a special visitor (Legendary-capable, never in groups): a
chibi foal with a spiral horn, a flowing mane and tail and little hooves.
Options vary coat and mane colours, head size and the extra sparkle.

    python design/studio/unicorn_r1.py   ->  design/studio/out/unicorn-r1/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (OL, W, GROUND, EAR_IN, svg, path, ell, line, eye, blush, shadow, render, HERE)


def lashes(x, y, rx, ry, side=1):
    d = ''
    for i, (dx, dy) in enumerate(((-0.6, -0.9), (-0.1, -1.1), (0.45, -0.95))):
        sx, sy = x + dx * rx * side, y + dy * ry
        d += f'M{sx:.1f} {sy:.1f} l{-4 * side + i * 3 * side:.1f} -6 '
    return line(d, OL, 2.4)


def horn(x, y, h, w, lean, p):
    tip = (x + lean, y - h)
    d = f'M{x - w / 2} {y} L{tip[0]} {tip[1]} L{x + w / 2} {y} Q{x} {y + 5} {x - w / 2} {y} Z'
    out = path(d, p['horn'], 3.5)
    bands = ''
    for k in (0.25, 0.5, 0.72):
        bx = x + lean * k
        by = y - h * k
        ww = w * (1 - k) * 0.55
        bands += f'M{bx - ww:.1f} {by + 3:.1f} Q{bx:.1f} {by - 2:.1f} {bx + ww:.1f} {by - 3:.1f} '
    out += line(bands, p['horn_ln'], 2.4, 0.8)
    if p.get('glow'):
        out = f'<circle cx="{tip[0]:.1f}" cy="{tip[1] + 6:.1f}" r="16" fill="{p["horn"]}" opacity="0.35"/>' + out
    return out


def locks(base, colours, w, lean=1):
    """A run of mane locks: each a teardrop curl, one colour per lock."""
    out = ''
    for i, ((x, y, ln, ang), c) in enumerate(zip(base, colours * 4)):
        d = (f'M{x - w / 2:.1f} {y:.1f} C{x - w:.1f} {y + ln * 0.5:.1f} {x + ang:.1f} {y + ln * 0.8:.1f} {x + ang * 1.3:.1f} {y + ln:.1f} '
             f'C{x + ang * 0.4 + w * 0.2:.1f} {y + ln * 0.7:.1f} {x + w * 0.8:.1f} {y + ln * 0.4:.1f} {x + w / 2:.1f} {y:.1f} Z')
        out += path(d, c, 3.5)
    return out


def sparkles(pts, colour):
    out = ''
    for x, y, r in pts:
        out += path(f'M{x} {y - r} Q{x + r * 0.2} {y - r * 0.2} {x + r} {y} Q{x + r * 0.2} {y + r * 0.2} {x} {y + r} '
                    f'Q{x - r * 0.2} {y + r * 0.2} {x - r} {y} Q{x - r * 0.2} {y - r * 0.2} {x} {y - r} Z', colour, 0)
    return out


def leg(x, top, w, coat, hoof):
    y = GROUND
    out = path(f'M{x - w / 2} {top} L{x - w / 2} {y - 6} L{x + w / 2} {y - 6} L{x + w / 2} {top} Z', coat, 3.5)
    out += path(f'M{x - w / 2 - 2} {y - 12} L{x + w / 2 + 2} {y - 12} L{x + w / 2 + 3} {y} L{x - w / 2 - 3} {y} Z', hoof, 3.5)
    return out


def front(p):
    out = shadow(160, 70)
    m = p['mane']
    # tail, behind, to one side
    out += locks([(200, 172, 70, 30), (212, 168, 64, 40), (192, 178, 62, 22)], m, 30)
    # back legs, then body, then front legs
    out += leg(134, 200, 18, p['coat_dk'], p['hoof'])
    out += leg(186, 200, 18, p['coat_dk'], p['hoof'])
    out += ell(160, 188, 46, 34, p['coat'], 4)
    out += leg(146, 196, 20, p['coat'], p['hoof'])
    out += leg(174, 196, 20, p['coat'], p['hoof'])
    out += ell(160, 176, 32, 26, p['coat'], 4)
    hx, hy, rx, ry = p['head']
    # mane hanging behind the head on both sides
    out += locks([(hx - rx * 0.55, hy - ry * 0.75, ry * 1.5, -12), (hx - rx * 0.78, hy - ry * 0.4, ry * 1.35, -18), (hx - rx * 0.92, hy, ry * 1.1, -16)], m, 36)
    out += locks([(hx + rx * 0.55, hy - ry * 0.75, ry * 1.5, 12), (hx + rx * 0.78, hy - ry * 0.4, ry * 1.35, 18), (hx + rx * 0.92, hy, ry * 1.1, 16)], m[1:] + m[:1], 36)
    for s in (-1, 1):
        ex, ey = hx + s * rx * 0.62, hy - ry * 0.78
        out += path(f'M{ex - 12} {ey + 14} Q{ex - 4 * s} {ey - 18} {ex + s * 4} {ey - 24} Q{ex + 12} {ey - 4} {ex + 12} {ey + 14} Z', p['coat'], 3.5)
        out += path(f'M{ex - 5} {ey + 10} Q{ex} {ey - 8} {ex + s * 3} {ey - 14} Q{ex + 6} {ey} {ex + 5} {ey + 10} Z', EAR_IN, 0)
    out += ell(hx, hy, rx, ry, p['coat'], 4)
    out += ell(hx, hy + ry * 0.56, rx * 0.4, ry * 0.27, p['muzzle'], 0)
    out += f'<circle cx="{hx - 7}" cy="{hy + ry * 0.5:.1f}" r="2" fill="{OL}" opacity="0.55"/><circle cx="{hx + 7}" cy="{hy + ry * 0.5:.1f}" r="2" fill="{OL}" opacity="0.55"/>'
    out += line(f'M{hx - 7} {hy + ry * 0.66:.1f} Q{hx} {hy + ry * 0.75:.1f} {hx + 7} {hy + ry * 0.66:.1f}', OL, 2.6)
    e = rx * 0.42
    k = p.get('eye_k', 1.0)
    for s in (-1, 1):
        out += eye(hx + s * e, hy - ry * 0.04, rx * 0.15 * k, ry * 0.2 * k)
        out += lashes(hx + s * e, hy - ry * 0.04, rx * 0.15 * k, ry * 0.2 * k, s)
    out += blush(hx - rx * 0.7, hy + ry * 0.3, rx * 0.14, ry * 0.09) + blush(hx + rx * 0.7, hy + ry * 0.3, rx * 0.14, ry * 0.09)
    # forelock and horn
    out += horn(hx, hy - ry * 0.82, p['horn_h'], 16, 0, p)
    out += locks([(hx - 16, hy - ry * 0.9, ry * 0.55, -14), (hx + 2, hy - ry * 0.95, ry * 0.5, -4), (hx + 16, hy - ry * 0.9, ry * 0.45, 14)], m[2:] + m[:2], 24)
    if p.get('star'):
        out += sparkles([(hx + rx * 0.68, hy + ry * 0.1, 7)], p['star'])
    if p.get('sparkle'):
        out += sparkles(p['sparkle'], p.get('sparkle_c', '#FFE58A'))
    return svg(out)


def side(p):
    out = shadow(164, 92)
    m = p['mane']
    bx, by, brx, bry = p['side_body']
    # tail flowing back and down
    out += locks([(bx + brx * 0.9, by - bry * 0.6, 78, 30), (bx + brx * 0.98, by - bry * 0.35, 70, 40), (bx + brx * 0.86, by - bry * 0.2, 64, 18)], m, 30)
    # far legs
    out += leg(bx - brx * 0.5 + 12, by, 16, p['coat_dk'], p['hoof'])
    out += leg(bx + brx * 0.55 + 12, by, 16, p['coat_dk'], p['hoof'])
    hx, hy, rx, ry = p['side_head']
    # a thick neck up to the head, merged into the body
    import math
    ax, ay = bx - brx * 0.62, by - bry * 0.35
    zx, zy = hx + rx * 0.55, hy + ry * 0.55
    nx, ny = (ax + zx) / 2, (ay + zy) / 2
    ln = math.hypot(zx - ax, zy - ay)
    rot = math.degrees(math.atan2(zy - ay, zx - ax)) - 90
    neck = f'<ellipse cx="{nx:.1f}" cy="{ny:.1f}" rx="25" ry="{ln / 2 + 14:.1f}" transform="rotate({rot:.1f} {nx:.1f} {ny:.1f})" fill="{p["coat"]}" '
    out += neck + f'stroke="{OL}" stroke-width="4"/>'
    out += ell(bx, by, brx, bry, p['coat'], 4)
    out += neck + '/>'
    out += leg(bx - brx * 0.5, by + bry * 0.3, 18, p['coat'], p['hoof'])
    out += leg(bx + brx * 0.55, by + bry * 0.3, 18, p['coat'], p['hoof'])
    # mane down the back of the neck
    out += locks([(hx + rx * 0.7, hy - ry * 0.6, 50, 16), (hx + rx * 1.0, hy - ry * 0.1, 50, 18),
                  (hx + rx * 1.2, hy + ry * 0.45, 48, 18), (hx + rx * 1.35, hy + ry * 1.0, 40, 16)], m, 32)
    # ear, head, muzzle
    ex, ey = hx + rx * 0.4, hy - ry * 0.8
    out += path(f'M{ex - 10} {ey + 12} Q{ex - 4} {ey - 16} {ex + 4} {ey - 22} Q{ex + 12} {ey - 2} {ex + 12} {ey + 12} Z', p['coat'], 3.5)
    out += ell(hx, hy, rx, ry, p['coat'], 4)
    out += ell(hx - rx * 0.72, hy + ry * 0.42, rx * 0.5, ry * 0.4, p['muzzle'], 3.5)
    out += f'<circle cx="{hx - rx * 1.12:.1f}" cy="{hy + ry * 0.3:.1f}" r="2.6" fill="{OL}" opacity="0.6"/>'
    out += line(f'M{hx - rx * 1.1:.1f} {hy + ry * 0.62:.1f} Q{hx - rx * 0.95:.1f} {hy + ry * 0.74:.1f} {hx - rx * 0.78:.1f} {hy + ry * 0.66:.1f}', OL, 2.5)
    k = p.get('eye_k', 1.0)
    out += eye(hx - rx * 0.2, hy - ry * 0.08, rx * 0.2 * k, ry * 0.25 * k)
    out += lashes(hx - rx * 0.2, hy - ry * 0.08, rx * 0.2 * k, ry * 0.25 * k, 1)
    out += blush(hx + rx * 0.2, hy + ry * 0.38, rx * 0.18, ry * 0.11)
    out += horn(hx - rx * 0.25, hy - ry * 0.82, p['horn_h'], 15, -14, p)
    out += locks([(hx - rx * 0.05, hy - ry * 0.95, ry * 0.5, -12)], m[2:] + m[:2], 20)
    if p.get('star'):
        out += sparkles([(hx + rx * 0.35, hy + ry * 0.12, 6)], p['star'])
    if p.get('sparkle'):
        out += sparkles([(x, y, r) for x, y, r in p['sparkle']], p.get('sparkle_c', '#FFE58A'))
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


RAINBOW = ['#F7A8B8', '#FFD59A', '#FFF1A6', '#B9E8B0', '#A9D4F5', '#C9B6F2']

OPTIONS = {
    'A': dict(name='Pastel rainbow', note='White coat, pastel rainbow mane and tail, gold horn.',
              coat='#FFFDF9', coat_dk='#EDE7E4', muzzle='#FBE3E6', hoof='#E8C99A', horn='#F6D77A', horn_ln='#D4A848',
              mane=RAINBOW, horn_h=44, head=(160, 104, 58, 50), side_body=(178, 176, 58, 34), side_head=(92, 114, 40, 36)),
    'B': dict(name='Lavender', note='Lilac coat, pink and violet mane, silver horn.',
              coat='#E9DDF7', coat_dk='#D6C8EA', muzzle='#F7E6F3', hoof='#B9A6D3', horn='#E6E9F0', horn_ln='#A9AEBD',
              mane=['#F5A6C8', '#C69CF0', '#F8C3DD', '#A98BE6'], horn_h=44,
              head=(160, 104, 58, 50), side_body=(178, 176, 58, 34), side_head=(92, 114, 40, 36)),
    'C': dict(name='Chibi foal', note='Huge head, tiny body, a star on its cheek.', eye_k=1.25,
              coat='#FFFDF9', coat_dk='#EDE7E4', muzzle='#FBE3E6', hoof='#E8C99A', horn='#F6D77A', horn_ln='#D4A848',
              mane=RAINBOW, star='#F6C453', horn_h=38,
              head=(160, 110, 70, 60), side_body=(184, 192, 46, 28), side_head=(92, 112, 52, 46)),
    'D': dict(name='Starry night', note='Midnight coat with little stars, silver mane, glowing horn.', glow=True,
              coat='#3E4B86', coat_dk='#334072', muzzle='#5A68A6', hoof='#C9CFE6', horn='#FFF3B8', horn_ln='#E3C766',
              mane=['#DCE3F7', '#B7C3EC', '#F2F4FC'], horn_h=46, sparkle_c='#FFE58A',
              sparkle=[(120, 196, 5), (196, 184, 4), (150, 168, 3.5), (178, 206, 4)],
              head=(160, 104, 58, 50), side_body=(178, 176, 58, 34), side_head=(92, 114, 40, 36)),
    'E': dict(name='Cotton candy', note='Pink coat, sky-blue and white curls.',
              coat='#FFD9E6', coat_dk='#F5C3D5', muzzle='#FFEAF1', hoof='#F2A7C1', horn='#FFFFFF', horn_ln='#F2B6CB',
              mane=['#A9D9F7', '#FFFFFF', '#C7E7FB'], horn_h=44,
              head=(160, 104, 58, 50), side_body=(178, 176, 58, 34), side_head=(92, 114, 40, 36)),
    'F': dict(name='Golden mane', note='Cream coat, a long golden mane, pearl horn.',
              coat='#FFF6E6', coat_dk='#F1E4CC', muzzle='#FCE6DA', hoof='#D9B57C', horn='#FBF3F6', horn_ln='#D7C3CF',
              mane=['#F6C453', '#FFDA7A', '#E9A93A'], horn_h=48,
              head=(160, 104, 58, 50), side_body=(178, 176, 58, 34), side_head=(92, 114, 40, 36)),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', side(o))):
            sp = f'{out_dir}/unicorn-r1-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/unicorn-r1')
