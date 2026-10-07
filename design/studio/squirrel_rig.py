"""Split the approved squirrel into rig parts: godot/art/squirrel/*.svg.

Approved 2026-10-07: studio round 2, option 2 (chibi, stuffed cheeks, curly
tail, red). It sits up facing you with its tail curling up behind and walks
side-on with its head in profile (critters/two_head.gd). The tail is its own
part in each pose so it can flick on a spring. Parts are drawn in the rig's
300 x 280 frame facing left; the studio frame is wrapped in translate(-14 24).

    python design/studio/squirrel_rig.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, GROUND, path, ell, line, eye
from squirrel_r1 import fluffy_tail, ear, face
from squirrel_r2 import OPTIONS

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art', 'squirrel'))
P = OPTIONS['2']
EYE_RE = r'<ellipse[^>]*fill="#2B2330"[^>]*/><circle[^>]*/><circle[^>]*/>'


def part(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
            f'<g transform="translate(-14 24)">{body}</g></svg>')


def no_eyes(s):
    return re.sub(EYE_RE, '', s)


def build():
    os.makedirs(OUT, exist_ok=True)
    hx, hy, rx, ry = P['head']
    bx, by, brx, bry = P['body']
    er = P['eye_k']
    parts = {}
    # --- sitting
    parts['tail'] = fluffy_tail(P['tail_front'], P['fur'], P['tail_lt'])
    parts['body'] = ell(bx, by, brx, bry, P['fur'], 4) + ell(bx, by + bry * 0.2, brx * 0.62, bry * 0.72, P['cream'], 0)
    for name, s in (('foot-l', -1), ('foot-r', 1)):
        x = bx + s * brx * 0.55
        parts[name] = ell(x, GROUND - 6, 22, 9, P['fur'], 4) + ell(x, GROUND - 5, 13, 5, P['cream'], 0)
    hand_y = by - bry * 0.35
    parts['paws'] = ell(bx - 13, hand_y + 6, 9, 7, P['fur'], 3.5) + ell(bx + 13, hand_y + 6, 9, 7, P['fur'], 3.5)
    parts['groom-paws'] = ell(hx - 12, hy + ry * 0.52, 9, 7, P['fur'], 3.5) + ell(hx + 12, hy + ry * 0.52, 9, 7, P['fur'], 3.5)
    for name, s in (('ear-l', -1), ('ear-r', 1)):
        parts[name] = ear(hx + s * rx * 0.55, hy - ry * 0.72, P['ear_h'], 16, s * 4, P)
    parts['head'] = no_eyes(face(P, hx, hy, rx, ry))
    e = rx * 0.4
    parts['eyes'] = eye(hx - e, hy - ry * 0.02, rx * 0.17 * er, ry * 0.22 * er) + eye(hx + e, hy - ry * 0.02, rx * 0.17 * er, ry * 0.22 * er)
    parts['eyes-closed'] = line(''.join(f'M{x - 12:.1f} {hy:.1f} Q{x:.1f} {hy + 10:.1f} {x + 12:.1f} {hy:.1f} ' for x in (hx - e, hx + e)), OL, 3)
    parts['mouth-open'] = path(f'M{hx - 7} {hy + ry * 0.47:.1f} Q{hx} {hy + ry * 0.44:.1f} {hx + 7} {hy + ry * 0.47:.1f} '
                               f'Q{hx + 6} {hy + ry * 0.66:.1f} {hx} {hy + ry * 0.68:.1f} Q{hx - 6} {hy + ry * 0.66:.1f} {hx - 7} {hy + ry * 0.47:.1f} Z', '#C9706B', 2.4)
    # --- walking
    sx, sy, srx, sry = P['side_body']
    parts['tail-side'] = fluffy_tail(P['tail_side'], P['fur'], P['tail_lt'], 11)
    parts['walk-body'] = (ell(sx, sy, srx, sry, P['fur'], 4) + ell(sx - srx * 0.1, sy + sry * 0.45, srx * 0.7, sry * 0.42, P['cream'], 0)
                          + ell(sx + srx * 0.55, sy + sry * 0.25, srx * 0.42, sry * 0.75, P['fur'], 4))

    def front_leg(x, top, fill):
        return path(f'M{x + 7} {top} L{x + 6} {GROUND - 6} Q{x + 6} {GROUND} {x - 2} {GROUND} L{x - 12} {GROUND} '
                    f'Q{x - 18} {GROUND} {x - 14} {GROUND - 7} L{x - 7} {GROUND - 8} L{x - 7} {top} Z', fill, 3.5)

    def back_leg(x, top, fill):
        return path(f'M{x + 12} {top} L{x + 14} {GROUND - 10} Q{x + 18} {GROUND} {x + 6} {GROUND} L{x - 26} {GROUND} '
                    f'Q{x - 33} {GROUND} {x - 28} {GROUND - 8} Q{x - 10} {GROUND - 12} {x - 6} {top} Z', fill, 3.5)

    fx, kx = sx - srx * 0.62, sx + srx * 0.55
    parts['leg-front'] = front_leg(fx, sy + 4, P['fur'])
    parts['leg-front-far'] = front_leg(fx + 10, sy + 4, P['fur_dk'])
    parts['leg-back'] = back_leg(kx, sy + 22, P['fur'])
    parts['leg-back-far'] = back_leg(kx + 10, sy + 22, P['fur_dk'])
    shx, shy, srx2, sry2 = P['side_head']
    parts['head-side'] = ear(shx + srx2 * 0.35, shy - sry2 * 0.7, P['ear_h'], 15, 6, P) + no_eyes(face(P, shx, shy, srx2, sry2, side=True))
    ex, ey = shx - srx2 * 0.28, shy - sry2 * 0.12
    parts['eye-side'] = eye(ex, ey, srx2 * 0.21, sry2 * 0.27)
    parts['eye-side-closed'] = line(f'M{ex - 11:.1f} {ey + 1:.1f} Q{ex:.1f} {ey + 9:.1f} {ex + 11:.1f} {ey + 1:.1f}', OL, 3)
    # --- napping: curled up, the tail wrapped right over it
    lx, ly = 100, 216
    loaf = ell(156, 218, 56, 30, P['fur'], 4)
    loaf += ell(lx + 6, ly + 4, 40, 32, P['fur'], 4) + ell(lx - 10, ly + 14, 22, 15, P['cream'], 0)
    loaf += ear(lx + 14, ly - 24, 22, 13, 6, P)
    loaf += ell(lx - 30, ly + 10, 5.5, 4.5, P['nose'], 2.4) + ell(lx + 6, ly + 14, 9, 5, '#F59C9C', 0, 'opacity="0.55"')
    loaf += fluffy_tail([(214, 230, 26), (222, 198, 30), (200, 168, 30), (164, 160, 28), (132, 170, 22)], P['fur'], P['tail_lt'], 21)
    parts['loaf-body'] = loaf
    parts['loaf-eyes'] = eye(lx - 10, ly - 2, 9, 10.5)
    parts['loaf-eyes-closed'] = line(f'M{lx - 19} {ly - 1} Q{lx - 10} {ly + 6} {lx - 1} {ly - 1}', OL, 3)
    for k, v in parts.items():
        with open(os.path.join(OUT, k + '.svg'), 'w') as fh:
            fh.write(part(v))
    print(len(parts), 'parts ->', OUT)


if __name__ == '__main__':
    build()
