"""Panda, studio round 3: the Common look. Round 2 gave the panda its Rare
versions (4, carrying bamboo; 6, the brown panda) but no Common, and every
pick walked face-on, so all of these do. Six takes on the everyday panda.

    python design/studio/panda_r3.py   ->  design/studio/out/panda-r3/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, HERE, render, path, line
import panda_r1 as p1
import panda_r2 as p2
from panda_r1 import BASE

_head = p1.head


def head(p, hx, hy, rx, ry, side=False):
    out = _head(p, hx, hy, rx, ry, side)
    if p.get('tuft') and not side:
        # a little curl of baby fur on the crown
        x, y = hx, hy - ry * 0.98
        out += path(f'M{x - 10} {y + 8} Q{x - 12} {y - 10} {x - 2} {y - 14} Q{x - 6} {y - 4} {x} {y + 6} '
                    f'Q{x + 4} {y - 12} {x + 14} {y - 8} Q{x + 6} {y - 2} {x + 8} {y + 8} Z', p['white'], 3.2)
    if p.get('smile_open') and not side:
        out += path(f'M{hx - 7} {hy + ry * 0.53:.1f} Q{hx} {hy + ry * 0.72:.1f} {hx + 7} {hy + ry * 0.53:.1f} Z', '#E98C8C', 2.4)
    return out


p1.head = head
p2.head = head

FACE_ON = dict(walk_body=(184, 200, 74, 40), walk_head=(112, 132, 56, 47))

OPTIONS = {
    '1': dict(BASE, uid='31', **FACE_ON, name='Classic, rounder', note='A with a rounder body and slightly smaller ears.',
              ear=19, body=(160, 192, 70, 54), head=(160, 106, 72, 60)),
    '2': dict(BASE, uid='32', **FACE_ON, tuft=True, name='Baby with a tuft',
              note='A with a little curl of baby fur on its head.', body=(160, 190, 64, 52), head=(160, 108, 70, 58)),
    '3': dict(BASE, uid='33', **FACE_ON, patch=(14, 19, 30), eye_k=1.35, name='Small patches, big eyes',
              note='Neat little patches almost filled by big sparkly eyes.', body=(160, 190, 64, 52), head=(160, 106, 70, 58)),
    '4': dict(BASE, uid='34', **FACE_ON, patch=(18, 26, 48), smile_open=True, name='Droopy and happy',
              note='Patches tilted right down, an open little smile.', body=(160, 190, 64, 52), head=(160, 106, 70, 58)),
    '5': dict(BASE, uid='35', **FACE_ON, patch=(21, 21, 0), patch_dx=0.42, tuft=True, name='Round patches, tuft',
              note='Round patches and the baby tuft.', body=(160, 192, 68, 54), head=(160, 106, 72, 60)),
    '6': dict(BASE, uid='36', walk_body=(182, 196, 70, 46), walk_head=(108, 124, 62, 52), eye_k=1.15, ear=21,
              name='Chubby chibi', note='Biggest head and the roundest body; the plushest.',
              body=(160, 200, 60, 46), head=(160, 108, 78, 64)),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', p1.front(o)), ('side', p2.walk(o))):
            sp = f'{out_dir}/panda-r3-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/panda-r3')
