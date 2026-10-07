"""Otter, studio round 1: six takes, each a front view and a side view.

The otter's own things: a long body that humps when it walks, short legs with
webbed feet, a thick tapering tail, a small round head with tiny ears and big
whisker pads. Its specials (v2.0): the belly slide, floating on its back and
splashing. Options vary colour, head size, body length and what it holds.

    python design/studio/otter_r1.py   ->  design/studio/out/otter-r1/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (OL, W, GROUND, EAR_IN, svg, path, ell, line, eye, blush, shadow, render, HERE)

NOSE = '#4A3632'


def whiskers(x, y, s, side=1):
    d = ''
    for k in (-1, 0, 1):
        d += f'M{x:.1f} {y + k * 4:.1f} l{side * 18 * s:.1f} {k * 5 - 1:.1f} '
    return line(d, OL, 1.8, 0.55)


def pebble(x, y):
    return ell(x, y, 13, 9, '#B9C3CC', 3) + ell(x - 4, y - 3, 4, 2, '#FFFFFF', 0, 'opacity="0.6"')


def shell_item(x, y):
    d = f'M{x - 14} {y + 6} Q{x - 16} {y - 12} {x} {y - 14} Q{x + 16} {y - 12} {x + 14} {y + 6} Z'
    rays = ' '.join(f'M{x} {y + 6} L{x + dx} {y - 10}' for dx in (-9, -3, 3, 9))
    return path(d, '#F7C9C0', 3) + line(rays, '#D99A8E', 2)


def head_front(p, hx, hy, rx, ry):
    out = ''
    for s in (-1, 1):
        ex, ey = hx + s * rx * 0.78, hy - ry * 0.62
        out += ell(ex, ey, 13, 12, p['fur'], 3.5) + ell(ex, ey + 1, 6.5, 6, EAR_IN, 0)
    out += ell(hx, hy, rx, ry, p['fur'], 4)
    if p.get('mask'):
        out += ell(hx, hy + ry * 0.05, rx * 0.86, ry * 0.8, p['face'], 0)
    out += ell(hx, hy + ry * 0.55, rx * 0.62, ry * 0.42, p['face'], 0)
    e = rx * 0.42
    k = p.get('eye_k', 1.0) * 1.35
    out += eye(hx - e, hy - ry * 0.08, rx * 0.15 * k, ry * 0.2 * k) + eye(hx + e, hy - ry * 0.08, rx * 0.15 * k, ry * 0.2 * k)
    out += blush(hx - rx * 0.66, hy + ry * 0.3, rx * 0.15, ry * 0.1) + blush(hx + rx * 0.66, hy + ry * 0.3, rx * 0.15, ry * 0.1)
    # whisker pads, nose, mouth
    for s in (-1, 1):
        out += ell(hx + s * 10, hy + ry * 0.5, 12, 9.5, p['face'], 2, 'stroke-opacity="0.45"')
        for i in range(3):
            out += f'<circle cx="{hx + s * (7 + i * 5):.1f}" cy="{hy + ry * 0.48 + (i % 2) * 4:.1f}" r="1.4" fill="{OL}" opacity="0.5"/>'
        out += whiskers(hx + s * 22, hy + ry * 0.5, 1, s)
    out += path(f'M{hx - 9} {hy + ry * 0.3:.1f} Q{hx} {hy + ry * 0.22:.1f} {hx + 9} {hy + ry * 0.3:.1f} Q{hx + 6} {hy + ry * 0.46:.1f} {hx} {hy + ry * 0.48:.1f} Q{hx - 6} {hy + ry * 0.46:.1f} {hx - 9} {hy + ry * 0.3:.1f} Z', NOSE, 2)
    out += line(f'M{hx - 6} {hy + ry * 0.74:.1f} Q{hx} {hy + ry * 0.84:.1f} {hx + 6} {hy + ry * 0.74:.1f}', OL, 2.6)
    return out


def front(p):
    out = shadow(160, 76)
    bx, by, brx, bry = p['body']
    # tail lying on the ground, curling up at the tip
    t = (f'M{bx + brx * 0.3:.1f} {GROUND - 44} C{bx + brx + 30:.1f} {GROUND - 6} {bx + brx + 70:.1f} {GROUND - 2} {bx + brx + 76:.1f} {GROUND - 30} '
         f'C{bx + brx + 78:.1f} {GROUND - 16} {bx + brx + 50:.1f} {GROUND + 2} {bx + brx * 0.4:.1f} {GROUND - 2} Z')
    out += path(t, p['fur'], 4)
    out += ell(bx, by, brx, bry, p['fur'], 4)
    out += ell(bx, by + bry * 0.1, brx * 0.64, bry * 0.8, p['face'], 0)
    for s in (-1, 1):
        fx = bx + s * brx * 0.5
        out += path(f'M{fx - 16} {GROUND} Q{fx - 18} {GROUND - 12} {fx} {GROUND - 13} Q{fx + 18} {GROUND - 12} {fx + 16} {GROUND} Z', p['fur'], 3.5)
        out += line(f'M{fx - 6} {GROUND - 1} l0 -6 M{fx + 6} {GROUND - 1} l0 -6', OL, 2, 0.55)
    hx, hy, rx, ry = p['head']
    out += head_front(p, hx, hy, rx, ry)
    cy = by - bry * 0.45
    if p.get('item') == 'pebble':
        out += pebble(bx, cy + 4)
    elif p.get('item') == 'shell':
        out += shell_item(bx, cy + 4)
    out += ell(bx - 13, cy + 8, 9, 8, p['fur'], 3.5) + ell(bx + 13, cy + 8, 9, 8, p['fur'], 3.5)
    return svg(out)


def side(p):
    out = shadow(170, 104)
    bx, by, brx, bry = p['side_body']
    # far legs
    out += ell(bx - brx * 0.55 + 12, GROUND - 4, 14, 6, p['fur_dk'], 3.5)
    out += ell(bx + brx * 0.55 + 12, GROUND - 4, 14, 6, p['fur_dk'], 3.5)
    # tail: thick at the root, tapering to a point
    tx = bx + brx * 0.85
    tl = min(78, W - 10 - tx)
    out += path(f'M{tx:.1f} {by - bry * 0.45:.1f} C{tx + 40:.1f} {by - 6:.1f} {tx + 60:.1f} {by + 14:.1f} {tx + tl:.1f} {GROUND - 18} '
                f'C{tx + tl * 0.72:.1f} {GROUND - 12} {tx + 30:.1f} {by + bry * 0.8:.1f} {tx - 6:.1f} {by + bry * 0.6:.1f} Z', p['fur'], 4)
    # long humped body
    d = (f'M{bx - brx:.1f} {by + bry * 0.2:.1f} C{bx - brx:.1f} {by - bry * 0.9:.1f} {bx - brx * 0.2:.1f} {by - bry * 1.25:.1f} {bx + brx * 0.3:.1f} {by - bry * 1.05:.1f} '
         f'C{bx + brx * 0.9:.1f} {by - bry * 0.85:.1f} {bx + brx * 1.05:.1f} {by - bry * 0.2:.1f} {bx + brx:.1f} {by + bry * 0.3:.1f} '
         f'C{bx + brx * 0.9:.1f} {by + bry:.1f} {bx - brx * 0.8:.1f} {by + bry:.1f} {bx - brx:.1f} {by + bry * 0.2:.1f} Z')
    # head on a thick neck, merged into the body: outline under the body, fill over the join
    hx, hy, rx, ry = p['side_head']
    neck = (f'M{hx + rx * 0.3:.1f} {hy - ry * 0.8:.1f} C{hx + rx * 1.4:.1f} {hy - ry * 0.7:.1f} {bx - brx * 0.6:.1f} {by - bry * 0.9:.1f} {bx - brx * 0.4:.1f} {by - bry * 0.5:.1f} '
            f'L{bx - brx * 0.85:.1f} {by + bry * 0.5:.1f} C{hx + rx:.1f} {hy + ry * 1.2:.1f} {hx:.1f} {hy + ry:.1f} {hx:.1f} {hy + ry * 0.6:.1f} Z')
    out += path(neck, p['fur'], 4)
    out += path(d, p['fur'], 4)
    out += path(neck, p['fur'], 0)
    out += path(f'M{bx - brx * 0.95:.1f} {by + bry * 0.3:.1f} C{bx - brx * 0.5:.1f} {by + bry * 0.95:.1f} {bx + brx * 0.4:.1f} {by + bry * 0.95:.1f} {bx + brx * 0.6:.1f} {by + bry * 0.75:.1f} '
                f'C{bx:.1f} {by + bry * 0.55:.1f} {bx - brx * 0.6:.1f} {by + bry * 0.4:.1f} {bx - brx * 0.95:.1f} {by + bry * 0.3:.1f} Z', p['face'], 0)
    # near legs, webbed feet forward
    for lx in (bx - brx * 0.55, bx + brx * 0.55):
        out += path(f'M{lx + 9:.1f} {by + bry * 0.5:.1f} L{lx + 8:.1f} {GROUND - 6} Q{lx + 8:.1f} {GROUND} {lx:.1f} {GROUND} L{lx - 14:.1f} {GROUND} '
                    f'Q{lx - 20:.1f} {GROUND} {lx - 16:.1f} {GROUND - 7} L{lx - 8:.1f} {GROUND - 9} L{lx - 9:.1f} {by + bry * 0.5:.1f} Z', p['fur'], 3.5)
    out += ell(hx + rx * 0.45, hy - ry * 0.72, 11, 10, p['fur'], 3.5) + ell(hx + rx * 0.45, hy - ry * 0.7, 5.5, 5, EAR_IN, 0)
    out += ell(hx, hy, rx, ry, p['fur'], 4)
    if p.get('mask'):
        out += ell(hx - rx * 0.1, hy + ry * 0.05, rx * 0.85, ry * 0.8, p['face'], 0)
    out += ell(hx - rx * 0.72, hy + ry * 0.32, rx * 0.5, ry * 0.42, p['face'], 3)
    out += ell(hx - rx * 1.12, hy + ry * 0.12, 7.5, 6, NOSE, 2.5)
    for i in range(3):
        out += f'<circle cx="{hx - rx * (0.95 - i * 0.14):.1f}" cy="{hy + ry * (0.3 + (i % 2) * 0.1):.1f}" r="1.4" fill="{OL}" opacity="0.5"/>'
    out += whiskers(hx - rx * 0.8, hy + ry * 0.35, 1.1, -1)
    k = p.get('eye_k', 1.0) * 1.2
    out += eye(hx - rx * 0.25, hy - ry * 0.15, rx * 0.2 * k, ry * 0.26 * k)
    out += blush(hx + rx * 0.15, hy + ry * 0.35, rx * 0.2, ry * 0.12)
    out += line(f'M{hx - rx * 1.0:.1f} {hy + ry * 0.62:.1f} Q{hx - rx * 0.85:.1f} {hy + ry * 0.72:.1f} {hx - rx * 0.7:.1f} {hy + ry * 0.62:.1f}', OL, 2.5)
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


RIVER = dict(fur='#9A6B4B', fur_dk='#82593E', face='#F3E1C8')

OPTIONS = {
    'A': dict(RIVER, name='River otter', note='Glossy brown with a cream throat and whisker pads.',
              body=(140, 186, 44, 56), head=(140, 104, 52, 44),
              side_body=(170, 200, 76, 34), side_head=(76, 168, 38, 32)),
    'B': dict(RIVER, fur='#6F5243', fur_dk='#5C4337', face='#EFE4D6', mask=True, item='shell',
              name='Sea otter', note='Dark body, pale fluffy face, holding a shell.',
              body=(140, 188, 48, 54), head=(140, 104, 54, 46),
              side_body=(170, 200, 74, 36), side_head=(76, 166, 40, 34)),
    'C': dict(RIVER, fur='#A8744E', fur_dk='#8F6141', name='Chubby', eye_k=1.2,
              note='Round body and a bigger head: the cuddliest.',
              body=(140, 192, 54, 50), head=(140, 104, 60, 50),
              side_body=(172, 198, 70, 40), side_head=(76, 160, 44, 38)),
    'D': dict(RIVER, fur='#C08A5E', fur_dk='#A7754E', face='#FBEBD6', item='pebble',
              name='Pebble keeper', note='Caramel, with its favourite pebble at its chest.',
              body=(140, 188, 46, 54), head=(140, 104, 54, 46),
              side_body=(170, 200, 76, 34), side_head=(76, 168, 38, 32)),
    'E': dict(RIVER, fur='#8C6247', fur_dk='#755139', name='Noodle',
              note='Extra long and slinky; small head, long tail.',
              body=(140, 180, 38, 64), head=(140, 100, 46, 40),
              side_body=(166, 206, 92, 28), side_head=(60, 180, 34, 29)),
    'F': dict(RIVER, fur='#5E4A44', fur_dk='#4D3C37', face='#F5E9DC', mask=True, eye_k=1.1,
              name='Cocoa with a cream face', note='Deep cocoa body, a big cream face patch.',
              body=(140, 188, 46, 54), head=(140, 104, 56, 46),
              side_body=(170, 200, 76, 34), side_head=(76, 166, 40, 34)),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', side(o))):
            sp = f'{out_dir}/otter-r1-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/otter-r1')
