"""Split the approved unicorn into rig parts, once per colour:
godot/art/unicorn/<variant>/*.svg.

Approved 2026-10-07: the curly foal (studio round 2, option 1) in seven of
round 3's colours, each a secret tier within Legendary. It sits facing you and
walks side-on with its head in profile (critters/two_head.gd). Parts are drawn
in the rig's 300 x 280 frame facing left; the studio frame is wrapped in
translate(-10 24).

    python design/studio/unicorn_rig.py
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, EAR_IN, path, ell, line, blush
import unicorn_r2 as u
from unicorn_r3 import OPTIONS as COLOURS

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art', 'unicorn'))

# variant id -> round-3 option, commonest first
VARIANTS = {'lavender': '1', 'cotton_candy': '3', 'sky': '5', 'rainbow': '2',
            'golden_sun': '7', 'starry_night': '8', 'twilight_neon': '9'}

EYE_RE = r'<ellipse[^>]*fill="#2B2330"[^>]*/>.*?stroke-linejoin="round" opacity="1.0"/>'
HX, HY, RX, RY = 160, 106, 64, 56            # the sitting head
SX, SY, SRX, SRY = 104, 128, 50, 44          # the walking head
BX, BY, BRX, BRY = 184, 194, 54, 32          # the walking body


def part(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
            f'<g transform="translate(-10 24)">{body}</g></svg>')


def face_front_no_eyes(p):
    s = u.face_front(p, HX, HY, RX, RY)
    return re.sub(EYE_RE, '', s, flags=re.S)


def eye_pair(p):
    return ''.join(u.u_eye(HX + s * RX * 0.4, HY + RY * 0.04, RX * 0.19, RY * 0.25, p['iris'], s) for s in (-1, 1))


def closed_pair():
    out = ''
    for s in (-1, 1):
        x, y = HX + s * RX * 0.4, HY + RY * 0.06
        out += line(f'M{x - 11:.1f} {y:.1f} Q{x:.1f} {y + 9:.1f} {x + 11:.1f} {y:.1f}', OL, 3)
        out += line(f'M{x - s * 9:.1f} {y + 3:.1f} l{-s * 5:.1f} 4 M{x - s * 2:.1f} {y + 6:.1f} l{-s * 3:.1f} 5', OL, 2.4)
    return out


def neck_path():
    return (f'M{SX + SRX * 0.45:.1f} {SY + SRY * 0.75:.1f} C{SX + SRX * 0.7:.1f} {BY - BRY * 0.1:.1f} {BX - BRX * 0.95:.1f} {BY:.1f} {BX - BRX * 0.9:.1f} {BY + BRY * 0.35:.1f} '
            f'L{BX - BRX * 0.2:.1f} {BY - BRY * 0.85:.1f} C{BX - BRX * 0.55:.1f} {BY - BRY * 1.25:.1f} {SX + SRX * 1.15:.1f} {SY + SRY * 0.35:.1f} {SX + SRX * 0.8:.1f} {SY - SRY * 0.35:.1f} Z')


def side_mane(p):
    m = p['mane']
    d, pts = u.band([(SX + SRX * 0.2, SY - SRY * 1.0), (SX + SRX * 1.35, SY - SRY * 0.75), (BX - BRX * 0.3, BY - BRY * 0.95)],
                    38, 18, wave=3.0, waves=3, side=-1, curl=0)
    out = u.striped(d, m, angle=60, strands=[u.strand(pts, 0.1, 0.9)])
    n = len(pts) - 1
    for j, k in enumerate((0.42, 0.68, 0.9)):
        x, y = pts[int(n * k)]
        out += u.ringlet(x + 16 - j * 3, y + 6, 11 - j, m[(j + 1) % len(m)])
    return out


def walk_body(p, dy=0):
    neck = neck_path()
    out = path(neck, p['coat'], 4) + ell(BX, BY, BRX, BRY, p['coat'], 4) + path(neck, p['coat'], 0)
    out += side_mane(p)
    return f'<g transform="translate(0 {dy})">{out}</g>'


def head_side(p):
    ex, ey = SX + SRX * 0.32, SY - SRY * 0.84
    out = path(f'M{ex - 10:.1f} {ey + 12:.1f} Q{ex - 4:.1f} {ey - 16:.1f} {ex + 4:.1f} {ey - 24:.1f} Q{ex + 12:.1f} {ey - 2:.1f} {ex + 12:.1f} {ey + 12:.1f} Z', p['coat'], 3.5)
    out += path(f'M{ex - 3:.1f} {ey + 8:.1f} Q{ex:.1f} {ey - 6:.1f} {ex + 4:.1f} {ey - 13:.1f} Q{ex + 7:.1f} {ey:.1f} {ex + 5:.1f} {ey + 8:.1f} Z', EAR_IN, 0)
    out += ell(SX, SY, SRX, SRY, p['coat'], 4)
    out += ell(SX - SRX * 0.7, SY + SRY * 0.44, SRX * 0.44, SRY * 0.36, p['muzzle'], 3.2)
    out += f'<circle cx="{SX - SRX * 1.02:.1f}" cy="{SY + SRY * 0.32:.1f}" r="2.3" fill="{OL}" opacity="0.55"/>'
    out += line(f'M{SX - SRX * 1.0:.1f} {SY + SRY * 0.6:.1f} Q{SX - SRX * 0.88:.1f} {SY + SRY * 0.7:.1f} {SX - SRX * 0.72:.1f} {SY + SRY * 0.62:.1f}', OL, 2.5)
    out += blush(SX + SRX * 0.24, SY + SRY * 0.38, SRX * 0.18, SRY * 0.1)
    out += u.horn(SX - SRX * 0.2, SY - SRY * 0.88, 44, 16, -16, p)
    out += u.bangs(p, SX, SY, SRX, SRY, side=True)
    return out


def build_variant(vid, p):
    p = dict(p, style='curly')
    d = os.path.join(OUT, vid)
    os.makedirs(d, exist_ok=True)
    parts = {}
    # --- sitting
    parts['tail'] = u.tail_shape(p, (192, 188), 1, 58)
    parts['body'] = (u.hoof_leg(138, 200, 16, p['coat_dk'], p) + u.hoof_leg(182, 200, 16, p['coat_dk'], p)
                     + ell(160, 196, 46, 30, p['coat'], 4) + u.hoof_leg(148, 192, 18, p['coat'], p)
                     + u.hoof_leg(172, 192, 18, p['coat'], p) + ell(160, 181, 31, 24, p['coat'], 4))
    parts['head'] = u.mane_front(p, HX, HY, RX, RY) + face_front_no_eyes(p) + u.horn(HX, HY - RY * 0.9, 44, 17, 0, p) + u.bangs(p, HX, HY, RX, RY)
    parts['eyes'] = eye_pair(p)
    parts['eyes-closed'] = closed_pair()
    parts['mouth-open'] = path(f'M{HX - 7} {HY + RY * 0.62:.1f} Q{HX} {HY + RY * 0.6:.1f} {HX + 7} {HY + RY * 0.62:.1f} '
                               f'Q{HX + 6} {HY + RY * 0.8:.1f} {HX} {HY + RY * 0.82:.1f} Q{HX - 6} {HY + RY * 0.8:.1f} {HX - 7} {HY + RY * 0.62:.1f} Z', '#D9776F', 2.4)
    # --- walking
    parts['tail-side'] = u.tail_shape(p, (BX + BRX * 0.88, BY - BRY * 0.55), 1, 62)
    parts['walk-body'] = walk_body(p)
    parts['leg-front'] = u.hoof_leg(BX - BRX * 0.5, BY + BRY * 0.3, 17, p['coat'], p)
    parts['leg-back'] = u.hoof_leg(BX + BRX * 0.55, BY + BRY * 0.3, 17, p['coat'], p)
    parts['leg-front-far'] = u.hoof_leg(BX - BRX * 0.5 + 12, BY, 15, p['coat_dk'], p)
    parts['leg-back-far'] = u.hoof_leg(BX + BRX * 0.55 + 12, BY, 15, p['coat_dk'], p)
    parts['head-side'] = head_side(p)
    parts['eye-side'] = u.u_eye(SX - SRX * 0.16, SY - SRY * 0.02, SRX * 0.22, SRY * 0.27, p['iris'], 1)
    ex, ey = SX - SRX * 0.16, SY
    parts['eye-side-closed'] = line(f'M{ex - 11:.1f} {ey:.1f} Q{ex:.1f} {ey + 9:.1f} {ex + 11:.1f} {ey:.1f}', OL, 3)
    # --- napping: lying down, legs folded under, head resting
    fold = ''.join(ell(x, 238, 14, 8, p['hoof'], 3.2) for x in (BX - BRX * 0.75, BX + BRX * 0.7))
    parts['loaf-body'] = u.tail_shape(p, (BX + BRX * 0.88, BY - BRY * 0.55 + 18), 1, 50) + fold + walk_body(p, 18)
    for k, v in parts.items():
        with open(os.path.join(d, k + '.svg'), 'w') as fh:
            fh.write(part(v))
    return len(parts)


if __name__ == '__main__':
    for vid, key in VARIANTS.items():
        n = build_variant(vid, COLOURS[key])
    print(len(VARIANTS), 'variants x', n, 'parts ->', OUT)
