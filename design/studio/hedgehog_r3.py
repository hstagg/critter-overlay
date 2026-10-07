"""Hedgehog, studio round 3: G is final; its walk, ball and nap.

Harrison approved round-1 option G (upright, his first reference) and chose:
sit upright as G, walk side-on on four legs with G's face (short upturned
snout, big eye). This round draws the four-legged walk in three body lengths,
plus the roll-up ball (its special) and the nap, all with G's face.

    python design/studio/hedgehog_r3.py   ->  design/studio/out/r3/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import HERE, W, OL, svg, path, ell, line, egg, tufts, eye, nose, blush, shadow, render
from hedgehog_r1 import side, g_front, marks, COAT, COAT_DK, FACE, FEET, sym_lean

# G's face, set on a four-legged head: short upturned snout, big eye.
G_FACE = dict(forehead=(118, 132), brow=(94, 134), bridge=(78, 152), snout=(60, 164),
              nose=(57, 163, 8.5, 7), chin=(74, 188), jaw=(104, 226),
              eye=(98, 156, 10, 12.5), ear=(128, 134, 15), cheek=(100, 182),
              mouth='M66 177 Q72 181 78 177', depth=0.15, tip=1.12, lean=7)

WALKS = {
    'compact': dict(coat=(184, 158, 90, 86), a0=196, a1=414, n=17, shoulder=(158, 226),
                    front_ctrl=(148, 160), feet=[(126, 241), (222, 241)],
                    far_feet=[(146, 239), (240, 239)]),
    'medium': dict(coat=(190, 166, 98, 78), a0=194, a1=410, n=18, shoulder=(164, 224),
                   front_ctrl=(152, 162), feet=[(128, 241), (234, 241)],
                   far_feet=[(150, 239), (254, 239)]),
    'bighead': dict(coat=(190, 164, 92, 82), a0=203, a1=412, n=17, shoulder=(162, 226),
                    front_ctrl=(156, 150), feet=[(128, 241), (226, 241)],
                    far_feet=[(148, 239), (244, 239)],
                    forehead=(124, 134), brow=(92, 128), bridge=(74, 150), snout=(54, 162),
                    nose=(51, 161, 9, 7.5), chin=(70, 190), eye=(98, 150, 12, 15),
                    ear=(134, 122, 17), cheek=(102, 180), mouth='M62 177 Q68 181 74 177'),
    'long': dict(coat=(190, 168, 108, 76), a0=196, a1=410, n=20, shoulder=(166, 224),
                 front_ctrl=(152, 164), feet=[(128, 241), (246, 241)],
                 far_feet=[(150, 239), (266, 239)]),
}


def ball():
    # Rolled up: a full ball of spikes, eyes and nose peeking out low at the front.
    cx, cy, r = 164, 166, 70
    f = egg(cx, cy, r, r)
    out = shadow(cx, 66)
    out += path(tufts(f, 0, 360, 26, 0.16, 1.15, 8, 0.02, 21, -0.01) + ' Z', COAT, 4)
    out += marks(f, 10, 350, (0.35, 0.6, 0.8), 14, 8, seed=9)
    out += path('M98 196 C100 176 124 168 140 176 C150 184 148 204 132 212 C116 218 98 212 98 196 Z', FACE, 3.5)
    out += eye(122, 190, 7, 8.5)
    out += nose(102, 200, 7, 6)
    out += blush(132, 202, 7, 4)
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


def nap():
    p = dict(G_FACE)
    p.update(dict(coat=(184, 186, 98, 64), a0=196, a1=408, n=18, shoulder=(160, 230),
                  front_ctrl=(150, 182), belly_y=232, belly=238,
                  forehead=(116, 156), brow=(96, 160), bridge=(82, 182), snout=(66, 200),
                  nose=(63, 200, 8, 6.5), chin=(80, 220), jaw=(108, 236),
                  eye=(98, 184, 9, 9), ear=(126, 160, 14), cheek=(100, 206),
                  mouth='M72 212 Q77 215 82 212', closed=True,
                  feet=[(124, 244)], far_feet=[]))
    return side(p)


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    files = {'sit': g_front(), 'ball': ball(), 'nap': nap()}
    for k, w in WALKS.items():
        p = dict(G_FACE)
        p.update(w)
        files['walk-' + k] = side(p)
    pairs = []
    for k, s in files.items():
        sp = f'{out_dir}/hh-r3-{k}.svg'
        with open(sp, 'w') as fh:
            fh.write(s)
        pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 2.0)


if __name__ == '__main__':
    build(HERE + '/out/r3')
