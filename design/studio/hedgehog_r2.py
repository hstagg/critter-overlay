"""Hedgehog, studio round 2: remixes of round 1's A and B.

Harrison's picks: keep A (his references) and B (chibi head), bold spikes,
medium snout in side profile. Six options along that line, varying head size,
spike size, face roundness and body length.

    python design/studio/hedgehog_r2.py   ->  design/studio/out/r2/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import HERE, render
from hedgehog_r1 import OPTIONS as R1, front, side

A_F, A_S = R1['A']['front'], R1['A']['side']
B_F, B_S = R1['B']['front'], R1['B']['side']


def mix(*ds):
    out = {}
    for d in ds:
        out.update(d)
    return out


# The medium snout, measured from B's head: nose about 50 units ahead of the eye.
MED = dict(bridge=(70, 160), snout=(40, 177), nose=(38, 177, 9, 7.5), chin=(64, 202),
           mouth='M48 192 Q54 196 60 192')

OPTIONS = {
    '1': dict(
        name='A and B merged',
        note='B’s head and eyes on A’s longer body.',
        front=mix(B_F, dict(chest=(160, 220, 46, 26), feet=[(134, 243), (186, 243)],
                            back_feet=[(100, 241), (220, 241)])),
        side=mix(A_S, B_S, MED, dict(coat=(184, 166, 106, 80), a0=194, n=19,
                                    feet=[(126, 241), (240, 241)], far_feet=[(148, 239), (262, 239)])),
    ),
    '2': dict(
        name='B, refined',
        note='Bigger eyes and ears, a few more spikes.',
        front=mix(B_F, dict(eyes=(31, 132, 14, 17), ears=(76, 84, 23), n=22,
                            cheeks=(56, 166))),
        side=mix(B_S, MED, dict(eye=(94, 163, 12, 15), ear=(134, 138, 17), n=19)),
    ),
    '3': dict(
        name='B, bigger spikes',
        note='Fewer, chunkier spikes: bolder outline at 88 px.',
        front=mix(B_F, dict(n=15, depth=0.2, tip=1.17, flecks=True)),
        side=mix(B_S, MED, dict(n=13, depth=0.2, tip=1.18, lean=9)),
    ),
    '4': dict(
        name='B, rounder face',
        note='Softer heart, wider cheeks; snout tip turns up a touch.',
        front=mix(B_F, dict(mask=dict(cx=160, top=90, peak=70, w=88, chin=204, cheek=124),
                            cheeks=(58, 168), eyes=(32, 136, 13, 15.5), nose=(160, 160, 8, 6.5),
                            mouth='M151 172 Q155.5 177 160 172 Q164.5 177 169 172')),
        side=mix(B_S, MED, dict(snout=(42, 172), nose=(40, 171, 9, 7.5), bridge=(72, 162),
                                cheek=(104, 192))),
    ),
    '5': dict(
        name='B, compact',
        note='Shorter, taller body: sits closest to the kitten’s size.',
        front=mix(B_F, dict(halo=(160, 132, 114, 108))),
        side=mix(B_S, MED, dict(coat=(184, 158, 86, 86), a0=192, a1=414, n=17,
                                shoulder=(160, 226), front_ctrl=(152, 158),
                                feet=[(130, 241), (220, 241)], far_feet=[(150, 239), (238, 239)])),
    ),
    '6': dict(
        name='A, medium snout',
        note='A as drawn, the snout cut to medium.',
        front=dict(A_F),
        side=mix(A_S, dict(bridge=(64, 164), snout=(36, 182), nose=(34, 182, 9, 7.5),
                           chin=(60, 206), mouth='M44 197 Q50 201 56 197')),
    ),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o['front'])), ('side', side(o['side']))):
            sp = f'{out_dir}/hh-r2-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 2.0)


if __name__ == '__main__':
    build(HERE + '/out/r2')
