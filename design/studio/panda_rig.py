"""Split the approved panda into rig parts: godot/art/panda/*.svg.

Approved 2026-10-07: studio round 3, option 1 (classic, rounder), walking
face-on (round 2's walks). One head for every pose, as the kitten: walking it
rides the front of the side-on body, a little smaller. Parts are drawn in the
rig's 300 x 280 frame facing left; the studio frame is wrapped in translate(-10 24).

    python design/studio/panda_rig.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, GROUND, EYE, path, ell, line, blush
from panda_r1 import blob, PAD
from panda_r2 import leg
from panda_r3 import OPTIONS

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art', 'panda'))
P = OPTIONS['1']


def part(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
            f'<g transform="translate(-10 24)">{body}</g></svg>')


HX, HY, RX, RY = P['head']
PRX, PRY, ROT = P['patch']
DX = RX * P.get('patch_dx', 0.4)
PCY = HY - RY * 0.02
ER = min(PRX, PRY) * 0.62 * P.get('eye_k', 1.0)
EY = PCY - PRY * 0.08


def head():
    out = blob(HX, HY, RX, RY, P['white'], P, 4, 3)
    for s, rot in ((-1, ROT), (1, -ROT)):
        cx = HX + s * DX
        out += f'<ellipse cx="{cx:.1f}" cy="{PCY:.1f}" rx="{PRX}" ry="{PRY}" transform="rotate({rot} {cx:.1f} {PCY:.1f})" fill="{P["black"]}"/>'
    out += ell(HX, HY + RY * 0.4, RX * 0.3, RY * 0.24, P['muzzle'], 0)
    out += path(f'M{HX - 8} {HY + RY * 0.26:.1f} Q{HX} {HY + RY * 0.2:.1f} {HX + 8} {HY + RY * 0.26:.1f} Q{HX + 5} {HY + RY * 0.4:.1f} {HX} {HY + RY * 0.42:.1f} Q{HX - 5} {HY + RY * 0.4:.1f} {HX - 8} {HY + RY * 0.26:.1f} Z', P['black'], 2)
    out += line(f'M{HX - 8} {HY + RY * 0.52:.1f} Q{HX - 4} {HY + RY * 0.6:.1f} {HX} {HY + RY * 0.52:.1f} Q{HX + 4} {HY + RY * 0.6:.1f} {HX + 8} {HY + RY * 0.52:.1f}', OL, 2.6)
    out += blush(HX - RX * 0.68, HY + RY * 0.36, RX * 0.15, RY * 0.1) + blush(HX + RX * 0.68, HY + RY * 0.36, RX * 0.15, RY * 0.1)
    return out


def eyes():
    out = ''
    for s in (-1, 1):
        ex = HX + s * DX
        out += f'<circle cx="{ex:.1f}" cy="{EY:.1f}" r="{ER + 2.2:.1f}" fill="#FFFFFF" opacity="0.92"/>'
        out += f'<circle cx="{ex:.1f}" cy="{EY:.1f}" r="{ER:.1f}" fill="{EYE}"/>'
        out += f'<circle cx="{ex - ER * 0.35:.1f}" cy="{EY - ER * 0.38:.1f}" r="{ER * 0.42:.1f}" fill="#FFFFFF"/>'
        out += f'<circle cx="{ex + ER * 0.4:.1f}" cy="{EY + ER * 0.36:.1f}" r="{ER * 0.18:.1f}" fill="#FFFFFF"/>'
    return out


def eyes_closed():
    return line(''.join(f'M{HX + s * DX - 9:.1f} {EY:.1f} Q{HX + s * DX:.1f} {EY + 7:.1f} {HX + s * DX + 9:.1f} {EY:.1f} ' for s in (-1, 1)), '#FFFFFF', 3)


def build():
    os.makedirs(OUT, exist_ok=True)
    parts = {}
    bx, by, brx, bry = P['body']
    blk = P['black']
    # --- sitting
    parts['body'] = (ell(bx, by - bry * 0.62, brx * 0.98, bry * 0.42, blk, 4) + blob(bx, by, brx, bry, P['white'], P, 4, 7)
                     + ''.join(f'<ellipse cx="{bx + s * brx * 0.6:.1f}" cy="{by - bry * 0.1:.1f}" rx="{brx * 0.26:.1f}" ry="{bry * 0.55:.1f}" '
                               f'transform="rotate({-s * 18} {bx + s * brx * 0.6:.1f} {by - bry * 0.1:.1f})" fill="{blk}" stroke="{OL}" stroke-width="4"/>' for s in (-1, 1)))
    for name, s in (('foot-l', -1), ('foot-r', 1)):
        lx = bx + s * brx * 0.62
        parts[name] = (ell(lx, GROUND - 20, 24, 21, blk, 4) + ell(lx, GROUND - 18, 11, 10, PAD, 0)
                       + ''.join(f'<circle cx="{lx + i * 9:.1f}" cy="{GROUND - 33:.1f}" r="3.4" fill="{PAD}"/>' for i in (-1, 0, 1)))
    for name, s in (('ear-l', -1), ('ear-r', 1)):
        parts[name] = ell(HX + s * RX * 0.8, HY - RY * 0.78, P['ear'], P['ear'], blk, 4)
    parts['head'] = head()
    parts['eyes'] = eyes()
    parts['eyes-closed'] = eyes_closed()
    parts['mouth-open'] = path(f'M{HX - 7} {HY + RY * 0.5:.1f} Q{HX} {HY + RY * 0.47:.1f} {HX + 7} {HY + RY * 0.5:.1f} '
                               f'Q{HX + 6} {HY + RY * 0.7:.1f} {HX} {HY + RY * 0.72:.1f} Q{HX - 6} {HY + RY * 0.7:.1f} {HX - 7} {HY + RY * 0.5:.1f} Z', '#D9776F', 2.4)
    parts['groom-paws'] = ell(HX - 16, HY + RY * 0.48, 13, 11, blk, 4) + ell(HX + 16, HY + RY * 0.48, 13, 11, blk, 4)
    # --- walking (round 2's body: shoulder hump, saddle into the front legs, black thighs)
    wx, wy, wrx, wry = P['walk_body']
    body = (f'M{wx - wrx:.1f} {wy + wry * 0.4:.1f} C{wx - wrx * 1.05:.1f} {wy - wry * 0.8:.1f} {wx - wrx * 0.55:.1f} {wy - wry * 1.25:.1f} {wx - wrx * 0.1:.1f} {wy - wry * 1.12:.1f} '
            f'C{wx + wrx * 0.5:.1f} {wy - wry * 1.02:.1f} {wx + wrx * 1.05:.1f} {wy - wry * 0.7:.1f} {wx + wrx:.1f} {wy + wry * 0.2:.1f} '
            f'C{wx + wrx * 0.95:.1f} {wy + wry * 1.0:.1f} {wx - wrx * 0.8:.1f} {wy + wry * 1.05:.1f} {wx - wrx:.1f} {wy + wry * 0.4:.1f} Z')

    def walk_body(dy=0):
        band = (f'M{wx - wrx * 0.66:.1f} {wy - wry * 1.5:.1f} L{wx - wrx * 0.08:.1f} {wy - wry * 1.5:.1f} '
                f'L{wx - wrx * 0.22:.1f} {wy + wry * 1.3:.1f} L{wx - wrx * 0.95:.1f} {wy + wry * 1.3:.1f} Z')
        thigh = f'<ellipse cx="{wx + wrx * 0.62:.1f}" cy="{wy + wry * 0.42:.1f}" rx="{wrx * 0.36:.1f}" ry="{wry * 0.78:.1f}" fill="{blk}"/>'
        return (f'<g transform="translate(0 {dy})">' + ell(wx + wrx * 0.98, wy - wry * 0.5, 11, 10, P['white'], 3.5)
                + f'<clipPath id="pb{dy}"><path d="{body}"/></clipPath>' + path(body, P['white'], 0)
                + f'<g clip-path="url(#pb{dy})"><path d="{band}" fill="{blk}"/>{thigh}</g>' + path(body, 'none', 4) + '</g>')

    parts['walk-body'] = walk_body()
    fx, kx = wx - wrx * 0.5, wx + wrx * 0.58
    parts['leg-front'] = leg(fx, wy + wry * 0.4, blk)
    parts['leg-back'] = leg(kx, wy + wry * 0.4, blk)
    parts['leg-front-far'] = leg(fx + 22, wy, P['black_dk'])
    parts['leg-back-far'] = leg(kx + 20, wy, P['black_dk'])
    # --- napping: flat on its tummy, front paws out
    parts['loaf-body'] = (walk_body(2) + ell(wx - wrx * 0.95, GROUND - 8, 18, 9, blk, 4)
                          + ell(wx + wrx * 0.95, GROUND - 6, 16, 8, blk, 4))
    for k, v in parts.items():
        with open(os.path.join(OUT, k + '.svg'), 'w') as fh:
            fh.write(part(v))
    print(len(parts), 'parts ->', OUT)


if __name__ == '__main__':
    build()
