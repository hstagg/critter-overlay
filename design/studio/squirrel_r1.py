"""Squirrel, studio round 1: six takes, each a front view and a side view.

The squirrel's own things: a huge bushy tail that is most of its silhouette,
sitting up on its haunches with big hind feet, little hands at the chest,
v2.0's dart-and-freeze and tail flick. Options vary colour, ear tufts, head
size, tail shape and what it holds.

    python design/studio/squirrel_r1.py   ->  design/studio/out/squirrel-r1/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (OL, W, GROUND, EAR_IN, svg, path, ell, line, egg, tufts, eye, blush, shadow,
                    render, HERE)


def fluffy_tail(pts, fill, light, seed=3):
    """A bushy tail as a run of fluffy discs merged into one shape: all the
    outlines first, then all the fills over them, so only the outer edge shows."""
    shapes = []
    for i, (x, y, r) in enumerate(pts):
        f = egg(x, y, r, r)
        shapes.append(tufts(f, 0, 360, max(10, int(r / 2.6)), 0.08, 1.06, 6, 0.02, seed + i, 0.05) + ' Z')
    out = ''.join(path(d, fill, 8) for d in shapes)
    out += ''.join(path(d, fill, 0) for d in shapes)
    # a paler core running down the tail
    core = ' '.join(f'{x:.1f} {y:.1f}' for x, y, r in pts)
    out += f'<polyline points="{core}" fill="none" stroke="{light}" stroke-width="{pts[1][2] * 0.5:.1f}" stroke-linecap="round" stroke-linejoin="round" opacity="0.55"/>'
    return out


def ear(x, y, h, w, lean, p):
    tip = (x + lean, y - h)
    d = f'M{x - w} {y} Q{x - w * 0.6} {y - h * 0.8} {tip[0]} {tip[1]} Q{x + w * 0.7} {y - h * 0.7} {x + w} {y} Z'
    out = path(d, p['fur'], 4)
    out += path(f'M{x - w * 0.5} {y - 2} Q{x - w * 0.3} {y - h * 0.6} {tip[0]:.1f} {tip[1] + h * 0.25:.1f} Q{x + w * 0.4} {y - h * 0.5} {x + w * 0.5} {y - 2} Z', EAR_IN, 0)
    if p.get('tufts'):
        tx, ty = tip
        out += path(f'M{tx - 5} {ty + 6} Q{tx - 8} {ty - 12} {tx - 2} {ty - 18} Q{tx + 2} {ty - 8} {tx + 4} {ty - 16} Q{tx + 7} {ty - 4} {tx + 6} {ty + 6} Z', p['tuft'], 3)
    return out


def face(p, hx, hy, rx, ry, side=False):
    out = ''
    if side:
        # head turned to the left, muzzle out front
        d = (f'M{hx + rx * 0.9:.1f} {hy - ry * 0.3:.1f} C{hx + rx * 0.8:.1f} {hy - ry * 1.05:.1f} {hx - rx * 0.5:.1f} {hy - ry * 1.1:.1f} {hx - rx * 0.8:.1f} {hy - ry * 0.3:.1f} '
             f'C{hx - rx * 1.05:.1f} {hy - ry * 0.05:.1f} {hx - rx * 1.25:.1f} {hy + ry * 0.2:.1f} {hx - rx * 1.15:.1f} {hy + ry * 0.45:.1f} '
             f'C{hx - rx * 1.0:.1f} {hy + ry * 0.75:.1f} {hx - rx * 0.4:.1f} {hy + ry * 0.95:.1f} {hx + rx * 0.2:.1f} {hy + ry * 0.9:.1f} '
             f'C{hx + rx * 0.9:.1f} {hy + ry * 0.8:.1f} {hx + rx * 1.05:.1f} {hy + ry * 0.2:.1f} {hx + rx * 0.9:.1f} {hy - ry * 0.3:.1f} Z')
        out += path(d, p['fur'], 4)
        out += ell(hx - rx * 0.6, hy + ry * 0.45, rx * 0.5, ry * 0.36, p['cream'], 0)
        out += eye(hx - rx * 0.28, hy - ry * 0.12, rx * 0.21, ry * 0.27)
        out += blush(hx + rx * 0.05, hy + ry * 0.38, rx * 0.2, ry * 0.12)
        out += ell(hx - rx * 1.13, hy + ry * 0.32, 6, 4.5, p['nose'], 2.5)
        out += line(f'M{hx - rx * 1.05:.1f} {hy + ry * 0.58:.1f} Q{hx - rx * 0.9:.1f} {hy + ry * 0.68:.1f} {hx - rx * 0.78:.1f} {hy + ry * 0.6:.1f}', OL, 2.6)
        if p.get('stripes'):
            out += line(f'M{hx - rx * 0.62:.1f} {hy - ry * 0.32:.1f} Q{hx - rx * 0.1:.1f} {hy - ry * 0.5:.1f} {hx + rx * 0.5:.1f} {hy - ry * 0.25:.1f}', p['stripe'], 5, 0.8)
        return out
    cheek = p.get('cheek', 1.0)
    d = (f'M{hx:.1f} {hy - ry:.1f} C{hx + rx * 0.75:.1f} {hy - ry:.1f} {hx + rx:.1f} {hy - ry * 0.35:.1f} {hx + rx * cheek:.1f} {hy + ry * 0.15:.1f} '
         f'C{hx + rx * cheek:.1f} {hy + ry * 0.75:.1f} {hx + rx * 0.5:.1f} {hy + ry:.1f} {hx:.1f} {hy + ry:.1f} '
         f'C{hx - rx * 0.5:.1f} {hy + ry:.1f} {hx - rx * cheek:.1f} {hy + ry * 0.75:.1f} {hx - rx * cheek:.1f} {hy + ry * 0.15:.1f} '
         f'C{hx - rx:.1f} {hy - ry * 0.35:.1f} {hx - rx * 0.75:.1f} {hy - ry:.1f} {hx:.1f} {hy - ry:.1f} Z')
    out += path(d, p['fur'], 4)
    out += ell(hx, hy + ry * 0.42, rx * 0.5, ry * 0.42, p['cream'], 0)
    if p.get('stripes'):
        for s in (-1, 1):
            out += line(f'M{hx + s * rx * 0.2:.1f} {hy - ry * 0.85:.1f} Q{hx + s * rx * 0.55:.1f} {hy - ry * 0.3:.1f} {hx + s * rx * 0.85:.1f} {hy - ry * 0.05:.1f}', p['stripe'], 5, 0.8)
    e = rx * 0.4
    er = p.get('eye_k', 1.0)
    out += eye(hx - e, hy - ry * 0.02, rx * 0.17 * er, ry * 0.22 * er) + eye(hx + e, hy - ry * 0.02, rx * 0.17 * er, ry * 0.22 * er)
    out += blush(hx - rx * 0.66, hy + ry * 0.32, rx * 0.17, ry * 0.11) + blush(hx + rx * 0.66, hy + ry * 0.32, rx * 0.17, ry * 0.11)
    out += path(f'M{hx - 6} {hy + ry * 0.24:.1f} Q{hx} {hy + ry * 0.2:.1f} {hx + 6} {hy + ry * 0.24:.1f} Q{hx + 3} {hy + ry * 0.36:.1f} {hx} {hy + ry * 0.37:.1f} Q{hx - 3} {hy + ry * 0.36:.1f} {hx - 6} {hy + ry * 0.24:.1f} Z', p['nose'], 2)
    out += line(f'M{hx - 8} {hy + ry * 0.48:.1f} Q{hx - 4} {hy + ry * 0.56:.1f} {hx} {hy + ry * 0.48:.1f} Q{hx + 4} {hy + ry * 0.56:.1f} {hx + 8} {hy + ry * 0.48:.1f}', OL, 2.6)
    return out


def acorn(x, y, s=1.0):
    return (path(f'M{x - 11 * s} {y - 2 * s} Q{x - 12 * s} {y + 16 * s} {x} {y + 20 * s} Q{x + 12 * s} {y + 16 * s} {x + 11 * s} {y - 2 * s} Z', '#C98B4E', 3)
            + path(f'M{x - 14 * s} {y} Q{x - 14 * s} {y - 12 * s} {x} {y - 13 * s} Q{x + 14 * s} {y - 12 * s} {x + 14 * s} {y} Z', '#8A5A35', 3)
            + line(f'M{x} {y - 13 * s} l2 -6', OL, 3))


def front(p):
    hx, hy, rx, ry = p['head']
    out = shadow(160, 70)
    out += fluffy_tail(p['tail_front'], p['fur'], p['tail_lt'])
    bx, by, brx, bry = p['body']
    out += ell(bx, by, brx, bry, p['fur'], 4)
    out += ell(bx, by + bry * 0.2, brx * 0.62, bry * 0.72, p['cream'], 0)
    if p.get('stripes'):
        out += line(f'M{bx - brx * 0.82:.1f} {by - bry * 0.3:.1f} Q{bx - brx * 0.9:.1f} {by + bry * 0.2:.1f} {bx - brx * 0.7:.1f} {by + bry * 0.6:.1f}', p['stripe'], 5, 0.8)
        out += line(f'M{bx + brx * 0.82:.1f} {by - bry * 0.3:.1f} Q{bx + brx * 0.9:.1f} {by + bry * 0.2:.1f} {bx + brx * 0.7:.1f} {by + bry * 0.6:.1f}', p['stripe'], 5, 0.8)
    # big hind feet, forward
    for x in (bx - brx * 0.55, bx + brx * 0.55):
        out += ell(x, GROUND - 6, 22, 9, p['fur'], 4) + ell(x, GROUND - 5, 13, 5, p['cream'], 0)
    for s in (-1, 1):
        out += ear(hx + s * rx * 0.55, hy - ry * 0.72, p['ear_h'], 16, s * 4, p)
    out += face(p, hx, hy, rx, ry)
    # hands at the chest
    hand_y = by - bry * 0.35
    if p.get('acorn'):
        out += acorn(bx, hand_y + 2, 1.15)
    out += ell(bx - 13, hand_y + 6, 9, 7, p['fur'], 3.5) + ell(bx + 13, hand_y + 6, 9, 7, p['fur'], 3.5)
    return svg(out)


def side(p):
    out = shadow(150, 92)
    out += fluffy_tail(p['tail_side'], p['fur'], p['tail_lt'], 11)
    bx, by, brx, bry = p['side_body']
    # far legs
    out += ell(bx - brx * 0.62, GROUND - 4, 11, 6, p['fur_dk'], 3.5)
    out += ell(bx + brx * 0.55 + 10, GROUND - 4, 18, 6, p['fur_dk'], 3.5)
    out += ell(bx, by, brx, bry, p['fur'], 4)
    out += ell(bx - brx * 0.1, by + bry * 0.45, brx * 0.7, bry * 0.42, p['cream'], 0)
    if p.get('stripes'):
        out += line(f'M{bx - brx * 0.8:.1f} {by - bry * 0.55:.1f} Q{bx:.1f} {by - bry * 0.95:.1f} {bx + brx * 0.85:.1f} {by - bry * 0.4:.1f}', p['stripe'], 6, 0.8)
    # near legs: a slim front leg, a big haunch with a long foot
    fx = bx - brx * 0.62
    out += path(f'M{fx + 7} {by + 4} L{fx + 6} {GROUND - 6} Q{fx + 6} {GROUND} {fx - 2} {GROUND} L{fx - 12} {GROUND} Q{fx - 18} {GROUND} {fx - 14} {GROUND - 7} L{fx - 7} {GROUND - 8} L{fx - 7} {by + 4} Z', p['fur'], 3.5)
    hx2 = bx + brx * 0.55
    out += ell(hx2, by + bry * 0.25, brx * 0.42, bry * 0.75, p['fur'], 4)
    out += path(f'M{hx2 + 14} {GROUND - 12} Q{hx2 + 18} {GROUND} {hx2 + 6} {GROUND} L{hx2 - 26} {GROUND} Q{hx2 - 33} {GROUND} {hx2 - 28} {GROUND - 8} Q{hx2 - 10} {GROUND - 14} {hx2 + 14} {GROUND - 12} Z', p['fur'], 3.5)
    hx, hy, rx, ry = p['side_head']
    out += ear(hx + rx * 0.35, hy - ry * 0.7, p['ear_h'], 15, 6, p)
    out += face(p, hx, hy, rx, ry, side=True)
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


RED = dict(fur='#E0823F', fur_dk='#C66E33', cream='#FFF0DD', tail_lt='#F4B07A', nose='#E7837F', tuft='#D8743A',
           stripe='#8E4E2A')

OPTIONS = {
    'A': dict(RED, name='Red squirrel', note='Orange-red with ear tufts and a cream tummy.', tufts=True,
              head=(150, 112, 60, 52), body=(150, 196, 46, 46), ear_h=30,
              tail_front=[(196, 222, 30), (226, 184, 38), (240, 132, 42), (232, 82, 38), (206, 50, 28)],
              side_body=(170, 192, 58, 38), side_head=(96, 150, 50, 44),
              tail_side=[(228, 200, 28), (258, 160, 36), (264, 108, 40), (244, 64, 34), (214, 46, 24)]),
    'B': dict(RED, fur='#A8A1A6', fur_dk='#8F888D', cream='#FBF8F4', tail_lt='#D4CFD2', tuft='#9A9398',
              name='Grey squirrel', note='Soft grey with a white tummy, rounder ears, no tufts.',
              head=(150, 112, 60, 52), body=(150, 196, 46, 46), ear_h=22,
              tail_front=[(196, 222, 30), (226, 184, 38), (240, 132, 42), (232, 82, 38), (206, 50, 28)],
              side_body=(170, 192, 58, 38), side_head=(96, 150, 50, 44),
              tail_side=[(228, 200, 28), (258, 160, 36), (264, 108, 40), (244, 64, 34), (214, 46, 24)]),
    'C': dict(RED, name='Chibi', note='Big round head, tiny body, the tail bigger than both.', tufts=True,
              head=(148, 116, 70, 60), body=(148, 206, 38, 36), ear_h=28, eye_k=1.2,
              tail_front=[(192, 224, 32), (226, 186, 42), (246, 130, 48), (240, 72, 44), (208, 36, 30)],
              side_body=(176, 200, 46, 32), side_head=(96, 144, 58, 52),
              tail_side=[(222, 206, 30), (258, 164, 40), (268, 106, 46), (248, 56, 38), (214, 36, 26)]),
    'D': dict(RED, fur='#C97A44', fur_dk='#B0683A', tail_lt='#E6A877', acorn=True, cheek=1.12,
              name='Acorn and cheeks', note='Chubby stuffed cheeks, holding an acorn.',
              head=(150, 112, 62, 52), body=(150, 198, 48, 44), ear_h=24,
              tail_front=[(196, 222, 30), (226, 184, 38), (240, 132, 42), (232, 82, 38), (206, 50, 28)],
              side_body=(170, 192, 58, 38), side_head=(96, 150, 52, 44),
              tail_side=[(228, 200, 28), (258, 160, 36), (264, 108, 40), (244, 64, 34), (214, 46, 24)]),
    'E': dict(RED, fur='#C98A55', fur_dk='#B07546', tail_lt='#E8B888', stripes=True, stripe='#7A4A2C',
              name='Striped back', note='Warm brown with dark stripes on its face and back.',
              head=(150, 112, 60, 52), body=(150, 196, 46, 46), ear_h=22,
              tail_front=[(196, 222, 30), (226, 184, 38), (240, 132, 42), (232, 82, 38), (206, 50, 28)],
              side_body=(170, 192, 58, 38), side_head=(96, 150, 50, 44),
              tail_side=[(228, 200, 28), (258, 160, 36), (264, 108, 40), (244, 64, 34), (214, 46, 24)]),
    'F': dict(RED, fur='#E9A06A', fur_dk='#D38B58', tail_lt='#F7CFA6', tufts=True, tuft='#E39560',
              name='Curly tail', note='Pale cinnamon; the tail curls right round over its head.',
              head=(144, 116, 58, 50), body=(144, 198, 44, 44), ear_h=28,
              tail_front=[(188, 226, 28), (222, 194, 34), (244, 148, 38), (240, 96, 36), (212, 62, 30), (178, 56, 24), (166, 74, 18)],
              side_body=(170, 194, 56, 38), side_head=(96, 150, 50, 44),
              tail_side=[(226, 202, 26), (256, 166, 32), (266, 118, 36), (252, 72, 32), (220, 50, 26), (190, 58, 20), (184, 80, 15)]),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', side(o))):
            sp = f'{out_dir}/squirrel-r1-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/squirrel-r1')
