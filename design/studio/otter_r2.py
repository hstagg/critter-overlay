"""Otter, studio round 2: Harrison kept A (river otter) and C (chubby); his
note on A: "walk profile needs work". The references that work (chibi otter
art) walk with the big head turned to you on a low side-on body, as the
approved kitten does, so the walks here put the head face-on or three-quarter.

    python design/studio/otter_r2.py   ->  design/studio/out/otter-r2/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, W, GROUND, EAR_IN, svg, path, ell, line, eye, blush, shadow, render, HERE
from otter_r1 import OPTIONS as R1, front, head_front, whiskers, NOSE

A, C = R1['A'], R1['C']


def head_three_quarter(p, hx, hy, rx, ry):
    """The head turned two-thirds towards the viewer, looking left."""
    out = ell(hx + rx * 0.55, hy - ry * 0.68, 12, 11, p['fur'], 3.5) + ell(hx + rx * 0.55, hy - ry * 0.66, 6, 5.5, EAR_IN, 0)
    out += ell(hx - rx * 0.62, hy - ry * 0.72, 9, 9, p['fur'], 3.5) + ell(hx - rx * 0.62, hy - ry * 0.7, 4.5, 4.5, EAR_IN, 0)
    out += ell(hx, hy, rx, ry, p['fur'], 4)
    mx = hx - rx * 0.32
    out += ell(mx, hy + ry * 0.5, rx * 0.6, ry * 0.42, p['face'], 0)
    k = 1.3
    out += eye(hx - rx * 0.62, hy - ry * 0.06, rx * 0.13 * k, ry * 0.19 * k)
    out += eye(hx + rx * 0.12, hy - ry * 0.08, rx * 0.15 * k, ry * 0.2 * k)
    out += blush(hx + rx * 0.5, hy + ry * 0.28, rx * 0.15, ry * 0.1)
    for s in (-1, 1):
        out += ell(mx + s * 9, hy + ry * 0.5, 11, 9, p['face'], 2, 'stroke-opacity="0.45"')
    out += whiskers(mx - 20, hy + ry * 0.5, 1, -1) + whiskers(mx + 20, hy + ry * 0.5, 0.8, 1)
    out += path(f'M{mx - 8:.1f} {hy + ry * 0.3:.1f} Q{mx:.1f} {hy + ry * 0.22:.1f} {mx + 8:.1f} {hy + ry * 0.3:.1f} Q{mx + 5:.1f} {hy + ry * 0.45:.1f} {mx:.1f} {hy + ry * 0.47:.1f} Q{mx - 5:.1f} {hy + ry * 0.45:.1f} {mx - 8:.1f} {hy + ry * 0.3:.1f} Z', NOSE, 2)
    out += line(f'M{mx - 6:.1f} {hy + ry * 0.73:.1f} Q{mx:.1f} {hy + ry * 0.83:.1f} {mx + 6:.1f} {hy + ry * 0.73:.1f}', OL, 2.6)
    return out


def walk(p):
    """Low, long body side-on, humped; thick tail with an upturned tip; the head
    on the front of the body turned to you."""
    out = shadow(176, 100)
    bx, by, brx, bry = p['walk_body']
    # far legs
    out += ell(bx - brx * 0.5 + 12, GROUND - 4, 13, 6, p['fur_dk'], 3.5)
    out += ell(bx + brx * 0.6 + 12, GROUND - 4, 13, 6, p['fur_dk'], 3.5)
    # tail: thick root, tapering, the tip lifting
    tx = bx + brx * 0.85
    lift = p.get('tail_lift', 10)
    out += path(f'M{tx:.1f} {by - bry * 0.55:.1f} C{tx + 34:.1f} {by - bry * 0.3:.1f} {tx + 52:.1f} {by + 4:.1f} {min(W - 8, tx + 64):.1f} {by - lift:.1f} '
                f'C{tx + 56:.1f} {by + 18:.1f} {tx + 26:.1f} {by + bry * 0.85:.1f} {tx - 6:.1f} {by + bry * 0.7:.1f} Z', p['fur'], 4)
    # body: low and long with a soft hump over the hips
    d = (f'M{bx - brx:.1f} {by + bry * 0.25:.1f} C{bx - brx:.1f} {by - bry * 0.8:.1f} {bx - brx * 0.3:.1f} {by - bry * 1.05:.1f} {bx + brx * 0.25:.1f} {by - bry * 1.1:.1f} '
         f'C{bx + brx * 0.85:.1f} {by - bry * 1.0:.1f} {bx + brx * 1.05:.1f} {by - bry * 0.3:.1f} {bx + brx:.1f} {by + bry * 0.3:.1f} '
         f'C{bx + brx * 0.9:.1f} {by + bry:.1f} {bx - brx * 0.8:.1f} {by + bry:.1f} {bx - brx:.1f} {by + bry * 0.25:.1f} Z')
    chest = (bx - brx * 0.78, by - bry * 0.2, brx * 0.36, bry * 1.1)
    out += ell(*chest, p['fur'], 4)
    out += path(d, p['fur'], 4)
    out += ell(*chest, p['fur'], 0)
    out += path(f'M{bx - brx * 0.92:.1f} {by + bry * 0.35:.1f} C{bx - brx * 0.5:.1f} {by + bry * 0.95:.1f} {bx + brx * 0.4:.1f} {by + bry * 0.95:.1f} {bx + brx * 0.6:.1f} {by + bry * 0.75:.1f} '
                f'C{bx:.1f} {by + bry * 0.55:.1f} {bx - brx * 0.6:.1f} {by + bry * 0.4:.1f} {bx - brx * 0.92:.1f} {by + bry * 0.35:.1f} Z', p['face'], 0)
    # near legs: short, with webbed feet
    for lx in (bx - brx * 0.5, bx + brx * 0.6):
        out += path(f'M{lx + 9:.1f} {by + bry * 0.4:.1f} L{lx + 8:.1f} {GROUND - 5} Q{lx + 8:.1f} {GROUND} {lx + 1:.1f} {GROUND} L{lx - 13:.1f} {GROUND} '
                    f'Q{lx - 19:.1f} {GROUND} {lx - 15:.1f} {GROUND - 7} L{lx - 8:.1f} {GROUND - 8} L{lx - 9:.1f} {by + bry * 0.4:.1f} Z', p['fur'], 3.5)
        out += line(f'M{lx - 9:.1f} {GROUND - 1} l0 -4 M{lx - 3:.1f} {GROUND - 1} l0 -4', OL, 1.8, 0.55)
    hx, hy, rx, ry = p['walk_head']
    if p.get('three_quarter'):
        out += head_three_quarter(p, hx, hy, rx, ry)
    else:
        out += head_front(p, hx, hy, rx, ry)
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


RIVER = dict(A)
CHUB = dict(C)

OPTIONS = {
    '1': dict(RIVER, name='River otter, face-on walk', note='A, walking with its big head turned to you.',
              walk_body=(186, 210, 72, 30), walk_head=(126, 160, 48, 41)),
    '2': dict(CHUB, name='Chubby, face-on walk', note='C, rounder body, the same walk.',
              walk_body=(184, 206, 70, 36), walk_head=(126, 154, 54, 46)),
    '3': dict(RIVER, three_quarter=True, name='River otter, three-quarter walk',
              note='A, head turned partly towards where it is going.',
              walk_body=(186, 210, 72, 30), walk_head=(122, 162, 48, 41)),
    '4': dict(CHUB, three_quarter=True, tail_lift=22, name='Chubby, three-quarter, tail up',
              note='C, head three-quarter, the tail tip lifted.',
              walk_body=(184, 206, 70, 36), walk_head=(122, 156, 54, 46)),
    '5': dict(CHUB, fur=A['fur'], fur_dk=A['fur_dk'], face=A['face'], eye_k=1.1,
              name='A and C merged', note='A’s glossy brown on C’s chubbier body; face-on walk.',
              walk_body=(184, 208, 70, 33), walk_head=(126, 157, 52, 44)),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', walk(o))):
            sp = f'{out_dir}/otter-r2-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/otter-r2')
