"""Split the approved otter into rig parts: godot/art/otter/*.svg.

Approved 2026-10-07: studio round 2, option 4 (chubby, three-quarter head
when walking, tail tip lifted). It sits up facing you and walks low and long
with its head turned two-thirds towards you (critters/two_head.gd). Its
special, v2.0's belly roll, floats it on its back (the "float" part).
Parts are drawn in the rig's 300 x 280 frame facing left; the studio frame
is wrapped in translate(-16 24).

    python design/studio/otter_rig.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, W, GROUND, path, ell, line, eye, blush
from otter_r1 import head_front
from otter_r2 import OPTIONS, head_three_quarter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art', 'otter'))
P = OPTIONS['4']
EYE_RE = r'<ellipse[^>]*fill="#2B2330"[^>]*/><circle[^>]*/><circle[^>]*/>'


def part(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
            f'<g transform="translate(-16 24)">{body}</g></svg>')


def no_eyes(s):
    return re.sub(EYE_RE, '', s)


def closed(xs, y, w=12):
    return line(''.join(f'M{x - w:.1f} {y:.1f} Q{x:.1f} {y + w * 0.75:.1f} {x + w:.1f} {y:.1f} ' for x in xs), OL, 3)


def build():
    os.makedirs(OUT, exist_ok=True)
    parts = {}
    bx, by, brx, bry = P['body']
    hx, hy, rx, ry = P['head']
    fur, face = P['fur'], P['face']
    # --- sitting
    parts['tail'] = path(f'M{bx + brx * 0.3:.1f} {GROUND - 44} C{bx + brx + 30:.1f} {GROUND - 6} {bx + brx + 70:.1f} {GROUND - 2} {bx + brx + 76:.1f} {GROUND - 30} '
                         f'C{bx + brx + 78:.1f} {GROUND - 16} {bx + brx + 50:.1f} {GROUND + 2} {bx + brx * 0.4:.1f} {GROUND - 2} Z', fur, 4)
    parts['body'] = ell(bx, by, brx, bry, fur, 4) + ell(bx, by + bry * 0.1, brx * 0.64, bry * 0.8, face, 0)
    for name, s in (('foot-l', -1), ('foot-r', 1)):
        fx = bx + s * brx * 0.5
        parts[name] = (path(f'M{fx - 16} {GROUND} Q{fx - 18} {GROUND - 12} {fx} {GROUND - 13} Q{fx + 18} {GROUND - 12} {fx + 16} {GROUND} Z', fur, 3.5)
                       + line(f'M{fx - 6} {GROUND - 1} l0 -6 M{fx + 6} {GROUND - 1} l0 -6', OL, 2, 0.55))
    cy = by - bry * 0.45
    parts['paws'] = ell(bx - 13, cy + 8, 9, 8, fur, 3.5) + ell(bx + 13, cy + 8, 9, 8, fur, 3.5)
    parts['groom-paws'] = ell(hx - 13, hy + ry * 0.62, 9, 8, fur, 3.5) + ell(hx + 13, hy + ry * 0.62, 9, 8, fur, 3.5)
    full = head_front(P, hx, hy, rx, ry)
    ears = re.findall(r'<ellipse cx="[\d.]+" cy="[\d.]+" rx="(?:13.0|6.5)"[^>]*/>', full)
    for name, pair in (('ear-l', ears[0:2]), ('ear-r', ears[2:4])):
        parts[name] = ''.join(pair)
    head = full
    for e in ears:
        head = head.replace(e, '', 1)
    parts['head'] = no_eyes(head)
    e = rx * 0.42
    k = P.get('eye_k', 1.0) * 1.35
    parts['eyes'] = eye(hx - e, hy - ry * 0.08, rx * 0.15 * k, ry * 0.2 * k) + eye(hx + e, hy - ry * 0.08, rx * 0.15 * k, ry * 0.2 * k)
    parts['eyes-closed'] = closed((hx - e, hx + e), hy - ry * 0.06)
    parts['mouth-open'] = path(f'M{hx - 7} {hy + ry * 0.72:.1f} Q{hx} {hy + ry * 0.7:.1f} {hx + 7} {hy + ry * 0.72:.1f} '
                               f'Q{hx + 6} {hy + ry * 0.92:.1f} {hx} {hy + ry * 0.94:.1f} Q{hx - 6} {hy + ry * 0.92:.1f} {hx - 7} {hy + ry * 0.72:.1f} Z', '#C9706B', 2.4)
    # --- walking
    wx, wy, wrx, wry = P['walk_body']
    tx = wx + wrx * 0.85
    lift = P.get('tail_lift', 10)
    parts['tail-side'] = path(f'M{tx:.1f} {wy - wry * 0.55:.1f} C{tx + 34:.1f} {wy - wry * 0.3:.1f} {tx + 52:.1f} {wy + 4:.1f} {min(W - 8, tx + 64):.1f} {wy - lift:.1f} '
                              f'C{tx + 56:.1f} {wy + 18:.1f} {tx + 26:.1f} {wy + wry * 0.85:.1f} {tx - 6:.1f} {wy + wry * 0.7:.1f} Z', fur, 4)
    d = (f'M{wx - wrx:.1f} {wy + wry * 0.25:.1f} C{wx - wrx:.1f} {wy - wry * 0.8:.1f} {wx - wrx * 0.3:.1f} {wy - wry * 1.05:.1f} {wx + wrx * 0.25:.1f} {wy - wry * 1.1:.1f} '
         f'C{wx + wrx * 0.85:.1f} {wy - wry * 1.0:.1f} {wx + wrx * 1.05:.1f} {wy - wry * 0.3:.1f} {wx + wrx:.1f} {wy + wry * 0.3:.1f} '
         f'C{wx + wrx * 0.9:.1f} {wy + wry:.1f} {wx - wrx * 0.8:.1f} {wy + wry:.1f} {wx - wrx:.1f} {wy + wry * 0.25:.1f} Z')
    chest = (wx - wrx * 0.78, wy - wry * 0.2, wrx * 0.36, wry * 1.1)
    belly = path(f'M{wx - wrx * 0.92:.1f} {wy + wry * 0.35:.1f} C{wx - wrx * 0.5:.1f} {wy + wry * 0.95:.1f} {wx + wrx * 0.4:.1f} {wy + wry * 0.95:.1f} {wx + wrx * 0.6:.1f} {wy + wry * 0.75:.1f} '
                 f'C{wx:.1f} {wy + wry * 0.55:.1f} {wx - wrx * 0.6:.1f} {wy + wry * 0.4:.1f} {wx - wrx * 0.92:.1f} {wy + wry * 0.35:.1f} Z', face, 0)

    def walk_body(dy=0):
        g = f'<g transform="translate(0 {dy})">'
        return g + ell(*chest, fur, 4) + path(d, fur, 4) + ell(*chest, fur, 0) + belly + '</g>'

    parts['walk-body'] = walk_body()

    def leg(lx, fill):
        return (path(f'M{lx + 9:.1f} {wy + wry * 0.4:.1f} L{lx + 8:.1f} {GROUND - 5} Q{lx + 8:.1f} {GROUND} {lx + 1:.1f} {GROUND} L{lx - 13:.1f} {GROUND} '
                     f'Q{lx - 19:.1f} {GROUND} {lx - 15:.1f} {GROUND - 7} L{lx - 8:.1f} {GROUND - 8} L{lx - 9:.1f} {wy + wry * 0.4:.1f} Z', fill, 3.5)
                + line(f'M{lx - 9:.1f} {GROUND - 1} l0 -4 M{lx - 3:.1f} {GROUND - 1} l0 -4', OL, 1.8, 0.55))

    fx, kx = wx - wrx * 0.5, wx + wrx * 0.6
    parts['leg-front'] = leg(fx, fur)
    parts['leg-back'] = leg(kx, fur)
    parts['leg-front-far'] = leg(fx + 12, P['fur_dk'])
    parts['leg-back-far'] = leg(kx + 12, P['fur_dk'])
    shx, shy, srx, sry = P['walk_head']
    parts['head-side'] = no_eyes(head_three_quarter(P, shx, shy, srx, sry))
    k3 = 1.3
    parts['eye-side'] = (eye(shx - srx * 0.62, shy - sry * 0.06, srx * 0.13 * k3, sry * 0.19 * k3)
                         + eye(shx + srx * 0.12, shy - sry * 0.08, srx * 0.15 * k3, sry * 0.2 * k3))
    parts['eye-side-closed'] = closed((shx - srx * 0.62, shx + srx * 0.12), shy - sry * 0.04, 10)
    # --- napping: lying low, legs tucked, the head resting forward
    parts['loaf-body'] = parts['tail-side'].replace('<path', f'<path transform="translate(0 10)"', 1) + walk_body(10)
    # --- floating on its back (v2.0's belly roll)
    fl = ell(160, 214, 74, 28, fur, 4) + ell(162, 204, 58, 16, face, 0)
    fl = path(f'M226 206 C252 196 266 180 270 166 C276 182 262 214 230 222 Z', fur, 4) + fl        # tail up at the back
    fl += ell(214, 184, 13, 10, fur, 3.5) + ell(196, 182, 12, 10, fur, 3.5)                      # back feet up
    fl += f'<g transform="rotate(-18 92 186)">{head_front(dict(P, eye_k=1.0), 92, 186, 46, 38)}</g>'
    fl += ell(142, 194, 9, 8, fur, 3.5) + ell(160, 192, 9, 8, fur, 3.5)                          # paws on its chest
    # happy closed eyes over the open ones
    fl = re.sub(EYE_RE, '', fl)
    fl += f'<g transform="rotate(-18 92 186)">{closed((92 - 19, 92 + 19), 182, 9)}</g>'
    parts['float'] = fl
    for k, v in parts.items():
        with open(os.path.join(OUT, k + '.svg'), 'w') as fh:
            fh.write(part(v))
    print(len(parts), 'parts ->', OUT)


if __name__ == '__main__':
    build()
