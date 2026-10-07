"""Split the approved hedgehog into rig parts: godot/art/hedgehog/*.svg.

Approved 2026-10-07 (studio rounds 1 to 3): it sits up as round-1 option G
and walks side-on on four legs as round-3's medium walk, with G's face; the
roll-up ball and the nap are matched to that walk.

Every part is drawn in the rig's shared 300 x 280 frame, facing left (see
critters/critter.gd). The studio drew in a 320 x 260 frame with the ground
at 246, so each part is wrapped in translate(-10 24): the ground lands on
270 and the shapes are exactly the approved stills.

    python design/studio/hedgehog_rig.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, EAR_IN, EYE, path, ell, line, egg, tufts, eye, blush, nose
from hedgehog_r1 import COAT, COAT_DK, FACE, FEET, marks, leg, mask_path, sym_lean, SIDE
from hedgehog_r3 import G_FACE, WALKS, ball as ball_still

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art', 'hedgehog'))
SHIFT = (-10, 24)


def part(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
            f'<g transform="translate({SHIFT[0]} {SHIFT[1]})">{body}</g></svg>')


# --- Sitting (round-1 G) --------------------------------------------------------

CX = 160
HALO = egg(CX, 128, 106, 112)


def sit_body():
    sp = tufts(HALO, 118, 422, 26, 0.13, 1.1, sym_lean(6), 0.02, 9, 0.0)
    xs, ys = HALO(118, 0.87)
    out = path(sp + f' Q{CX} 242 {xs:.1f} {ys:.1f} Z', COAT, 4)
    out += marks(HALO, 126, 414, (0.82, 0.92), 14, sym_lean(6))
    out += ell(CX, 196, 54, 44, FACE, 4)                      # belly
    return out


def sit_foot(x):
    return ell(x, 240, 18, 8, FEET, 3.5)


def sit_paw(x):
    return ell(x, 188, 13, 10, FACE, 3.5)


def ear(x):
    return ell(x, 76, 19, 19, FACE, 3.5) + ell(x, 77, 10.5, 11, EAR_IN, 0)


def head():
    out = path(mask_path(dict(cx=CX, top=76, peak=54, w=78, chin=170, cheek=100)), FACE, 4)
    out += blush(CX - 50, 138) + blush(CX + 50, 138)
    out += line('M148 146 Q160 156 172 146', OL, 2.8)
    return out


def eyes():
    return eye(CX - 28, 116, 10, 12) + eye(CX + 28, 116, 10, 12)


def eyes_closed():
    d = ''
    for x in (CX - 28, CX + 28):
        d += f'M{x - 10} 117 Q{x} 125 {x + 10} 117 '
    return line(d, OL, 3)


def nose_part():
    return nose(CX, 134, 8, 6.5)


def mouth_open():
    return path('M152 148 Q160 145 168 148 Q167 162 160 163 Q153 162 152 148 Z', '#C9706B', 2.6)


def groom_paws():
    # Both front paws up at the face, for washing.
    return ell(146, 146, 12, 10, FACE, 3.5) + ell(174, 146, 12, 10, FACE, 3.5)


def scratch_paw():
    # One front paw up rubbing the cheek (a hedgehog's legs are too short to
    # reach its ear with a hind foot).
    return (path('M196 196 Q214 176 214 150 L200 148 Q198 172 184 186 Z', FACE, 3.5)
            + ell(208, 146, 12, 10, FACE, 3.5))


# --- Walking (round-3 medium walk, G's face) -------------------------------------

P = dict(SIDE)
P.update(G_FACE)
P.update(WALKS['medium'])
WCX, WCY, WRX, WRY = P['coat']
WF = egg(WCX, WCY, WRX, WRY, P['back'], P['top'])


def coat_path():
    sp = tufts(WF, P['a0'], P['a1'], P['n'], P['depth'], P['tip'], P['lean'], P['jit'], 7, P['puff'])
    sx, sy = P['shoulder']
    x0, y0 = WF(P['a0'], 1 - P['depth'])
    xe, ye = WF(P['a1'], 1 - P['depth'])
    fcx, fcy = P['front_ctrl']
    by = P['belly_y']
    return (sp + f' C{xe - 6} {by} {xe - 20} {by} {xe - 40} {by} '
            f'L{sx + 20} {by} Q{sx} {sy} {sx - 6} {sy - 8} Q{fcx} {fcy} {x0:.1f} {y0:.1f} Z')


def coat():
    out = path(coat_path(), COAT, 4)
    out += marks(WF, P['a0'] + 14, P['a1'] - 14, P['fleck_rows'], P['fleck_per'], P['lean'])
    return out


def face_path():
    fx, fy = P['forehead']
    bx, by = P['brow']
    gx, gy = P['bridge']
    tx, ty = P['snout']
    hx, hy = P['chin']
    jx, jy = P['jaw']
    return (f'M{fx} {fy} C{(fx + bx) / 2} {fy - 2} {bx} {by - 8} {bx} {by} '
            f'C{bx - 4} {by + 14} {gx + 10} {gy - 6} {gx} {gy} '
            f'C{gx - 12} {gy + 8} {tx + 12} {ty - 6} {tx} {ty} '
            f'C{tx - 6} {ty + 6} {tx - 2} {ty + 14} {tx + 10} {ty + 16} '
            f'C{(tx + hx) / 2} {ty + 18} {hx - 8} {hy - 2} {hx} {hy} '
            f'C{hx + 14} {hy + 4} {jx - 16} {jy - 6} {jx} {jy} '
            f'L{jx + 46} {jy} L{jx + 58} {jy - 14} L{fx + 26} {fy + 4} Z')


def face_contour():
    # The face's visible outline only, forehead round to the jaw: the rest of
    # its edge is hidden under the coat or meets the body's belly strip.
    d = face_path()
    return d[:d.index(' L')]


def walk_body():
    # The belly strip from the jaw back to the rump, then the coat. The face
    # is the head's (head-side), drawn over the front of this.
    jx, jy = P['jaw']
    b = P['belly']
    rump = WCX + WRX * 0.95
    under = (f'M{jx} {jy - 24} L{jx} {jy} C{jx + 10} {b} {jx + 30} {b} {jx + 50} {b} '
             f'L{rump - 30} {b} C{rump - 10} {b} {rump} {b - 10} {rump} {WCY} L{jx + 40} {WCY} Z')
    return path(under, FACE, 4) + coat()


# The head carries a copy of the coat's front, clipped to the part of it in
# front of the ear, so its own back edge is hidden under quills that match
# the body's exactly at rest.
HEAD_CLIP = 'M0 0 L146 0 L146 120 L158 170 L170 260 L0 260 Z'


def head_side():
    out = path(face_path(), FACE, 0) + path(face_contour(), 'none', 4)
    out += f'<clipPath id="hc"><path d="{HEAD_CLIP}"/></clipPath><g clip-path="url(#hc)">{coat()}</g>'
    ex, ey, er = P['ear']
    out += ell(ex, ey, er, er * 1.05, FACE, 3.5) + ell(ex - 1, ey + 1, er * 0.55, er * 0.6, EAR_IN, 0)
    out += blush(*P['cheek'], 11, 6)
    out += nose(*P['nose'])
    out += line(P['mouth'], OL, 2.6)
    return out


def eye_side():
    return eye(*P['eye'])


def eye_side_closed():
    x, y, rx, ry = P['eye']
    return line(f'M{x - rx} {y} Q{x} {y + ry * 0.7} {x + rx} {y}', OL, 3)


def walk_leg(x, y, fill):
    return leg(x, y, P['belly'] - 10, fill)


# --- Nap and ball ---------------------------------------------------------------

def nap_parts():
    """The nap matched to the medium walk: the same coat lowered and squashed,
    face tucked low. Returns (body, eyes open, eyes closed)."""
    from hedgehog_r1 import side as side_still
    q = dict(G_FACE)
    q.update(WALKS['medium'])
    q.update(dict(coat=(190, 184, 98, 62), a0=196, a1=408, shoulder=(164, 230),
                  front_ctrl=(152, 180), belly_y=232, belly=238,
                  forehead=(116, 156), brow=(96, 160), bridge=(82, 182), snout=(66, 200),
                  nose=(63, 200, 8, 6.5), chin=(80, 220), jaw=(108, 236),
                  eye=(98, 184, 9, 9), ear=(126, 160, 14), cheek=(100, 206),
                  mouth='M72 212 Q77 215 82 212', feet=[(124, 244)], far_feet=[],
                  closed=True, eye_hidden=True))
    s = side_still(q)
    # side() mirrors for display; the rig wants it facing left, unmirrored, and
    # without its own shadow (the game draws none).
    inner = s[s.index('scale(-1 1)">') + len('scale(-1 1)">'):s.rindex('</g>')]
    inner = inner[inner.index('/>') + 2:]          # drop the shadow ellipse
    closed = line('M89 184 Q98 190 107 184', OL, 3)
    return inner, eye(98, 182, 8, 9.5), closed


def ball():
    s = ball_still()
    inner = s[s.index('scale(-1 1)">') + len('scale(-1 1)">'):s.rindex('</g>')]
    return inner[inner.index('/>') + 2:]


def build():
    os.makedirs(OUT, exist_ok=True)
    nap, nap_eyes, nap_closed = nap_parts()
    parts = {
        'body': sit_body(),
        'foot-l': sit_foot(132), 'foot-r': sit_foot(188),
        'paw-l': sit_paw(128), 'paw-r': sit_paw(192),
        'ear-l': ear(76), 'ear-r': ear(244),
        'head': head(), 'eyes': eyes(), 'eyes-closed': eyes_closed(),
        'nose': nose_part(), 'mouth-open': mouth_open(),
        'groom-paws': groom_paws(), 'scratch-foot': scratch_paw(),
        'walk-body': walk_body(), 'head-side': head_side(),
        'eye-side': eye_side(), 'eye-side-closed': eye_side_closed(),
        'leg-front': walk_leg(*P['feet'][0], FEET), 'leg-back': walk_leg(*P['feet'][1], FEET),
        'leg-front-far': walk_leg(*P['far_feet'][0], COAT_DK), 'leg-back-far': walk_leg(*P['far_feet'][1], COAT_DK),
        'loaf-body': nap, 'loaf-eyes': nap_eyes, 'loaf-eyes-closed': nap_closed,
        'ball': ball(),
    }
    for k, v in parts.items():
        with open(os.path.join(OUT, k + '.svg'), 'w') as fh:
            fh.write(part(v))
    print(len(parts), 'parts ->', OUT)


if __name__ == '__main__':
    build()
