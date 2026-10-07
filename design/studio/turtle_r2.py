"""Turtle, studio round 2: Harrison kept A (classic green), D (big-head
hatchling) and F (mossy sprout). Five merges of the three.

    python design/studio/turtle_r2.py   ->  design/studio/out/turtle-r2/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import HERE, render, path, line
import turtle_r1 as t1
from turtle_r1 import GREEN, OPTIONS as R1

_shell = t1.shell


def shell(p, uid, cx, base, rx, ry, front=False):
    out = _shell(p, uid, cx, base, rx, ry, front)
    if p.get('flower'):
        # a tiny daisy on the sprout
        fx, fy = cx - rx * 0.1 + 1, base - ry - 26
        petals = ''.join(f'<ellipse cx="{fx}" cy="{fy - 7}" rx="3.6" ry="6.5" transform="rotate({a} {fx} {fy})" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="2"/>'
                         for a in range(0, 360, 60))
        out += line(f'M{fx} {fy + 2} L{fx} {fy + 12}', '#5F8F3E', 3) + petals + f'<circle cx="{fx}" cy="{fy}" r="4.2" fill="#F6C453" stroke="#6B4A3A" stroke-width="2"/>'
    return out


t1.shell = shell

A, D, F = R1['A'], R1['D'], R1['F']

OPTIONS = {
    '1': dict(A, name='Classic, bigger head', note='A’s green dome with a head nearer the hatchling’s.',
              head_r=52, side_head=(62, 160), front_head=(160, 160)),
    '2': dict(D, sprout=True, name='Hatchling with a sprout', note='D’s big head and small shell, plus F’s sprout.'),
    '3': dict(F, head_r=52, side_head=(62, 160), front_head=(160, 160),
              name='Classic with a sprout', note='A’s shell and a bigger head, with the sprout.'),
    '4': dict(D, sprout=True, flower=True, name='Hatchling, sprout in flower',
              note='D with a sprout that has a little daisy on it.'),
    '5': dict(GREEN, sprout=True, name='In between', note='Shell between A and D, head between too, sprout on top.',
              shell='#74AE5F', scute='#96CA74', side_shell=(182, 200, 88, 84), side_head=(66, 154),
              front_shell=(160, 204, 100, 90), front_head=(160, 156), head_r=50, rim_h=14),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', t1.front(o)), ('side', t1.side(o))):
            sp = f'{out_dir}/turtle-r2-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/turtle-r2')
