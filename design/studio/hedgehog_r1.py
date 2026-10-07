"""Hedgehog, studio round 1: seven options, each a front view and a side view.

Front language from Harrison's first reference (heart-shaped face mask with a
widow's peak, round ears outside it, a spiky halo, button nose, small smile);
side language from his second (bold swept-back spikes with leaf flecks, peach
face, long tapering snout with the nose at the tip, pink round ear on the
quill line, peach belly strip, small dark feet). All on four legs except
option G, which is his first reference taken literally (upright).

Side views are drawn facing left, as the rig expects, and mirrored on output
so they face the same way as the approved critters' side stills.

    python design/studio/hedgehog_r1.py   ->  design/studio/out/r1/*.svg, *.png
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (OL, EAR_IN, GROUND, W, H, svg, path, ell, line, egg, tufts, strokes,
                    eye, blush, nose, shadow, render, HERE)

COAT = '#7B5640'
COAT_DK = '#5E4030'
FLECK = '#A98468'
FACE = '#F9DDBF'
FACE_SH = '#F0C9A4'
FEET = '#7A5440'


def marks(f, a0, a1, rows, per, lean, seed=5, color=FLECK, size=(8.5, 3.0)):
    """Leaf-shaped flecks inside the coat, turned along the sweep."""
    rnd = random.Random(seed)
    lf = lean if callable(lean) else (lambda a, v=lean: v)
    out = ''
    for j, r in enumerate(rows):
        n = max(2, int(per * r))
        for i in range(n):
            a = a0 + (a1 - a0) * (i + 0.5 * (j % 2) + 0.3) / n + rnd.uniform(-3, 3)
            if a > a1:
                continue
            x0, y0 = f(a, r)
            x1, y1 = f(a + lf(a) * 1.2, r + 0.12)
            rot = math.degrees(math.atan2(y1 - y0, x1 - x0))
            s = rnd.uniform(0.75, 1.15)
            out += (f'<ellipse cx="{x0:.1f}" cy="{y0:.1f}" rx="{size[0] * s:.1f}" ry="{size[1] * s:.1f}" '
                    f'transform="rotate({rot:.1f} {x0:.1f} {y0:.1f})" fill="{color}" opacity="0.9"/>')
    return out


def sym_lean(v):
    # Front views: tips lean away from the crown, down both sides.
    return lambda a: v if (a % 360) > 270 or (a % 360) < 90 else -v


# --- Side view (facing left) -------------------------------------------------

SIDE = dict(
    coat=(182, 166, 110, 82), back=0.05, top=0.0,
    a0=200, a1=410, n=19, depth=0.16, tip=1.13, lean=7, puff=-0.01, jit=0.02,
    belly_y=222, shoulder=(160, 224), front_ctrl=(150, 168),
    # face: forehead, bridge, snout tip, chin, jaw
    forehead=(112, 124), brow=(84, 136), bridge=(62, 164), snout=(24, 186),
    chin=(52, 206), jaw=(96, 228), belly=232,
    nose=(22, 186, 9, 7.5), eye=(82, 166, 9, 11), ear=(122, 146, 14),
    cheek=(94, 192), mouth='M34 199 Q40 203 46 199',
    feet=[(122, 241), (240, 241)], far_feet=[(144, 239), (262, 239)],
    flecks=True, fleck_rows=(0.32, 0.5, 0.68, 0.84), fleck_per=13, texture=False,
)


def side(p):
    q = dict(SIDE)
    q.update(p)
    p = q
    cx, cy, rx, ry = p['coat']
    f = egg(cx, cy, rx, ry, p['back'], p['top'])
    out = shadow(cx - 10, rx * 0.95)
    # far feet, behind everything
    for x, y in p['far_feet']:
        out += ell(x, y, 12, 6, COAT_DK, 3.5)
    # peach face and underbody, one shape
    fx, fy = p['forehead']
    bx, by = p['brow']
    gx, gy = p['bridge']
    tx, ty = p['snout']
    hx, hy = p['chin']
    jx, jy = p['jaw']
    rump = cx + rx * 0.95
    d = (f'M{fx} {fy} C{(fx + bx) / 2} {fy - 2} {bx} {by - 8} {bx} {by} '
         f'C{bx - 4} {by + 14} {gx + 10} {gy - 6} {gx} {gy} '
         f'C{gx - 12} {gy + 8} {tx + 12} {ty - 6} {tx} {ty} '
         f'C{tx - 6} {ty + 6} {tx - 2} {ty + 14} {tx + 10} {ty + 16} '
         f'C{(tx + hx) / 2} {ty + 18} {hx - 8} {hy - 2} {hx} {hy} '
         f'C{hx + 14} {hy + 4} {jx - 16} {jy - 6} {jx} {jy} '
         f'C{jx + 10} {p["belly"]} {jx + 30} {p["belly"]} {jx + 50} {p["belly"]} '
         f'L{rump - 30} {p["belly"]} C{rump - 10} {p["belly"]} {rump} {p["belly"] - 10} {rump} {cy} '
         f'L{fx + 20} {fy} Z')
    out += path(d, p.get('face', FACE), 4)
    # the coat: spikes over the top and rump, belly edge, then the front edge
    sp = tufts(f, p['a0'], p['a1'], p['n'], p['depth'], p['tip'], p['lean'],
               p['jit'], 7, p['puff'])
    sx, sy = p['shoulder']
    x0, y0 = f(p['a0'], 1 - p['depth'])
    xe, ye = f(p['a1'], 1 - p['depth'])
    fcx, fcy = p['front_ctrl']
    d = (sp + f' C{xe - 6} {p["belly_y"]} {xe - 20} {p["belly_y"]} {xe - 40} {p["belly_y"]} '
         f'L{sx + 20} {p["belly_y"]} Q{sx} {sy} {sx - 6} {sy - 8} Q{fcx} {fcy} {x0:.1f} {y0:.1f} Z')
    out += path(d, p.get('coat_fill', COAT), 4)
    if p['flecks']:
        out += marks(f, p['a0'] + 14, p['a1'] - 14, p['fleck_rows'], p['fleck_per'], p['lean'])
    if p['texture']:
        out += strokes(f, p['a0'] + 10, p['a1'] - 10, (0.36, 0.5, 0.64, 0.78, 0.9), 30, p['lean'] + 4,
                       light='#B48A6C', dark='#4E3426')
    # ear on the quill line
    ex, ey, er = p['ear']
    out += ell(ex, ey, er, er * 1.05, FACE, 3.5) + ell(ex - 1, ey + 1, er * 0.55, er * 0.6, EAR_IN, 0)
    # near feet
    for x, y in p['feet']:
        out += ell(x, y, 13, 6.5, FEET, 3.5)
    # face details
    out += eye(*p['eye'])
    out += blush(*p['cheek'], 11, 6)
    out += nose(*p['nose'])
    out += line(p['mouth'], OL, 2.6)
    out += p.get('extra', '')
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


# --- Front view (four legs) --------------------------------------------------

FRONT = dict(
    halo=(160, 140, 112, 100), n=22, depth=0.15, tip=1.12, lean=6, puff=-0.01, jit=0.02,
    gap=(60, 120),
    mask=dict(cx=160, top=92, peak=70, w=74, chin=194, cheek=116),
    ears=(82, 96, 20), eyes=(28, 134, 11, 13), nose=(160, 154, 9, 7),
    muzzle=None, mouth='M150 167 Q155 173 160 167 Q165 173 170 167',
    cheeks=(50, 160), chest=(160, 212, 52, 32),
    feet=[(132, 242), (188, 242)], back_feet=[(94, 240), (226, 240)],
    flecks=True, texture=False,
)


def mask_path(m):
    c, t, pk, w, ch, chk = m['cx'], m['top'], m['peak'], m['w'], m['chin'], m['cheek']
    return (f'M{c} {t} C{c - 18} {pk} {c - w + 6} {pk} {c - w} {chk} '
            f'C{c - w - 6} {chk + 44} {c - 48} {ch} {c} {ch} '
            f'C{c + 48} {ch} {c + w + 6} {chk + 44} {c + w} {chk} '
            f'C{c + w - 6} {pk} {c + 18} {pk} {c} {t} Z')


def front(p):
    q = dict(FRONT)
    q.update(p)
    p = q
    cx, cy, rx, ry = p['halo']
    f = egg(cx, cy, rx, ry)
    out = shadow(cx, rx * 0.9)
    for x, y in p['back_feet']:
        out += ell(x, y, 13, 6.5, COAT_DK, 3.5)
    g0, g1 = p['gap']
    a0, a1 = g1, g0 + 360
    sp = tufts(f, a0, a1, p['n'], p['depth'], p['tip'], sym_lean(p['lean']), p['jit'], 4, p['puff'])
    xs, ys = f(a0, 1 - p['depth'])
    out += path(sp + f' Q{cx} {GROUND + 6} {xs:.1f} {ys:.1f} Z', p.get('coat_fill', COAT), 4)
    if p['flecks']:
        out += marks(f, a0 + 8, a1 - 8, (0.8, 0.9), 14, sym_lean(6))
    if p['texture']:
        out += strokes(f, a0 + 6, a1 - 6, (0.78, 0.88), 30, sym_lean(8),
                       light='#B48A6C', dark='#4E3426')
    out += ell(*p['chest'], FACE, 4)
    ex, ey, er = p['ears']
    for x in (ex, 2 * cx - ex):
        out += ell(x, ey, er, er, FACE, 3.5) + ell(x, ey + 1, er * 0.55, er * 0.58, EAR_IN, 0)
    out += path(mask_path(p['mask']), p.get('face', FACE), 4)
    for x, y in p['feet']:
        out += ell(x, y, 14, 7, FEET, 3.5)
    dx, ey2, erx, ery = p['eyes']
    out += eye(cx - dx, ey2, erx, ery) + eye(cx + dx, ey2, erx, ery)
    bd, by = p['cheeks']
    out += blush(cx - bd, by) + blush(cx + bd, by)
    if p['muzzle']:
        mx, my, mrx, mry = p['muzzle']
        out += ell(mx, my, mrx, mry, FACE, 2.5, 'stroke-opacity="0.55"')
    out += nose(*p['nose'])
    out += line(p['mouth'], OL, 2.6)
    out += p.get('extra', '')
    return svg(out)


# --- The options ---------------------------------------------------------------

OPTIONS = {}

# A. Straight from the two references: bold spikes, long tapering snout.
OPTIONS['A'] = dict(
    name='Your references',
    front={}, side={},
)

# B. Chibi head: big head, short body, medium snout, the kitten's proportions.
OPTIONS['B'] = dict(
    name='Chibi head',
    front=dict(halo=(160, 134, 118, 104), mask=dict(cx=160, top=84, peak=60, w=82, chin=200, cheek=112),
               ears=(76, 84, 21), eyes=(31, 132, 13, 15.5), nose=(160, 158, 8, 6.5),
               mouth='M151 170 Q155.5 175 160 170 Q164.5 175 169 170',
               cheeks=(54, 164), chest=(160, 222, 40, 22), feet=[(138, 243), (182, 243)],
               back_feet=[(108, 241), (212, 241)], n=20),
    side=dict(coat=(190, 168, 96, 76), a0=192, forehead=(122, 140), brow=(94, 138), bridge=(70, 158),
              snout=(42, 176), chin=(66, 202), jaw=(108, 228), nose=(40, 176, 9, 7.5),
              eye=(92, 160, 11, 13.5), ear=(132, 136, 15), cheek=(104, 190),
              mouth='M50 192 Q56 196 62 192', front_ctrl=(156, 160), shoulder=(166, 224), n=17,
              feet=[(130, 241), (232, 241)], far_feet=[(152, 239), (252, 239)]),
)

# C. Fluffy: the same coat as soft dense tufts (his earlier "almost fluffy").
OPTIONS['C'] = dict(
    name='Fluffy coat',
    front=dict(n=40, depth=0.07, tip=1.06, puff=0.04, lean=8, jit=0.015, flecks=False, texture=True),
    side=dict(n=44, depth=0.07, tip=1.07, puff=0.04, lean=9, flecks=False, texture=True,
              bridge=(64, 164), snout=(34, 182), nose=(32, 182, 9, 7.5),
              mouth='M42 196 Q48 200 54 196'),
)

# D. Sonic swoop: fewer, longer, curved spikes swept hard back; upturned snout.
OPTIONS['D'] = dict(
    name='Sonic swoop',
    front=dict(n=12, depth=0.24, tip=1.2, puff=0.05, lean=14, jit=0.0,
               mask=dict(cx=160, top=100, peak=76, w=72, chin=192, cheek=120),
               eyes=(26, 136, 12, 16), muzzle=(160, 166, 24, 16), nose=(160, 158, 9, 7),
               mouth='M152 175 Q160 180 168 175', cheeks=(52, 164)),
    side=dict(coat=(172, 166, 100, 80), a1=404, n=10, depth=0.26, tip=1.22, puff=0.06, lean=16, jit=0.0,
              bridge=(66, 160), snout=(26, 170), chin=(54, 204), nose=(26, 168, 9.5, 8),
              eye=(88, 160, 10, 15), mouth='M36 190 Q44 194 50 188',
              fleck_rows=(0.45, 0.68), fleck_per=8),
)

# E. Round ball: nearly a sphere, ready to roll; short snout, tiny feet.
OPTIONS['E'] = dict(
    name='Round ball',
    front=dict(halo=(160, 138, 108, 106), n=26, chest=(160, 218, 40, 20),
               feet=[(140, 243), (180, 243)], back_feet=[(112, 241), (208, 241)]),
    side=dict(coat=(168, 146, 98, 98), back=0.0, a0=196, a1=428, n=23,
              forehead=(96, 118), brow=(72, 136), bridge=(56, 170), snout=(36, 186),
              chin=(56, 204), jaw=(94, 226), nose=(34, 186, 9, 7.5), eye=(76, 164, 9.5, 11.5),
              ear=(106, 140, 13), cheek=(84, 194), mouth='M44 199 Q50 203 56 199',
              shoulder=(140, 228), front_ctrl=(132, 170), belly_y=228, belly=234,
              feet=[(116, 242), (210, 242)], far_feet=[(136, 240), (228, 240)]),
)

# F. Long and low: stretched dome, long fine snout, the realistic one.
OPTIONS['F'] = dict(
    name='Long and low',
    front=dict(halo=(160, 150, 120, 90), mask=dict(cx=160, top=104, peak=84, w=66, chin=196, cheek=126),
               ears=(92, 112, 16), eyes=(24, 140, 9, 11), muzzle=(160, 168, 20, 15),
               nose=(160, 162, 8, 6.5), mouth='M154 178 Q160 182 166 178', cheeks=(46, 166)),
    side=dict(coat=(178, 176, 110, 70), n=22, back=0.03, forehead=(108, 136), brow=(82, 150),
              bridge=(54, 178), snout=(12, 198), chin=(46, 214), jaw=(92, 232), nose=(12, 197, 8, 7),
              eye=(78, 178, 8, 9.5), ear=(118, 158, 12), cheek=(86, 200),
              mouth='M24 208 Q30 211 36 208', front_ctrl=(150, 180), shoulder=(164, 228),
              belly_y=228, belly=236, feet=[(118, 243), (248, 243)], far_feet=[(140, 241), (270, 241)]),
)


# G. Upright, his first reference literally. Breaks the four-legs rule.
def g_front():
    cx = 160
    f = egg(cx, 128, 106, 112)
    out = shadow(cx, 70)
    sp = tufts(f, 118, 422, 26, 0.13, 1.1, sym_lean(6), 0.02, 9, 0.0)
    xs, ys = f(118, 0.87)
    out += path(sp + f' Q{cx} {GROUND - 4} {xs:.1f} {ys:.1f} Z', COAT, 4)
    out += marks(f, 126, 414, (0.82, 0.92), 14, sym_lean(6))
    out += ell(132, 240, 18, 8, FEET, 3.5) + ell(188, 240, 18, 8, FEET, 3.5)
    out += ell(cx, 196, 54, 44, FACE, 4)                                  # belly
    for x in (76, 244):
        out += ell(x, 76, 19, 19, FACE, 3.5) + ell(x, 77, 10.5, 11, EAR_IN, 0)
    out += path(mask_path(dict(cx=cx, top=76, peak=54, w=78, chin=170, cheek=100)), FACE, 4)
    out += ell(128, 188, 13, 10, FACE, 3.5) + ell(192, 188, 13, 10, FACE, 3.5)   # paws on belly
    out += eye(cx - 28, 116, 10, 12) + eye(cx + 28, 116, 10, 12)
    out += blush(cx - 50, 138) + blush(cx + 50, 138)
    out += nose(cx, 134, 8, 6.5)
    out += line('M148 146 Q160 156 172 146', OL, 2.8)
    return svg(out)


def g_side():
    # Standing: body upright, quills down the back, short snout.
    f = egg(176, 132, 82, 108, 0.0, 0.0)
    out = shadow(160, 70)
    out += ell(150, 240, 20, 8, COAT_DK, 3.5)
    d = ('M140 46 C112 44 96 62 90 82 C84 94 70 100 60 104 C52 110 58 122 72 122 '
         'C92 124 104 132 106 146 C96 160 92 200 112 224 C124 238 150 240 172 236 '
         'L200 236 L200 60 Z')
    out += path(d, FACE, 4)
    sp = tufts(f, 236, 450, 18, 0.15, 1.12, 8, 0.02, 11, -0.01)
    x0, y0 = f(236, 0.85)
    xe, ye = f(450, 0.85)
    out += path(sp + f' Q190 240 174 238 Q150 220 150 170 Q146 100 {x0:.1f} {y0:.1f} Z', COAT, 4)
    out += marks(f, 250, 440, (0.55, 0.75), 10, 8)
    out += ell(150, 62, 14, 14.5, FACE, 3.5) + ell(149, 63, 7.5, 8, EAR_IN, 0)
    out += ell(108, 176, 13, 10, FACE, 3.5)                                   # arm
    out += ell(170, 241, 20, 8, FEET, 3.5)
    out += eye(104, 86, 9.5, 12)
    out += blush(110, 112, 11, 6)
    out += nose(62, 108, 8.5, 7)
    out += line('M70 118 Q76 122 82 118', OL, 2.6)
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


OPTIONS['G'] = dict(name='Upright, like your example (breaks the four-legs rule)', front=None, side=None)


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        if key == 'G':
            fr, sd = g_front(), g_side()
        else:
            fr, sd = front(o['front']), side(o['side'])
        for view, s in (('front', fr), ('side', sd)):
            sp = f'{out_dir}/hh-r1-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 2.0)
    return pairs


if __name__ == '__main__':
    build(HERE + '/out/r1')
