"""Squirrel, studio round 2: Harrison kept C (chibi), D (stuffed cheeks) and F
(curly tail). His note on D: the acorn is a shop item, not part of the
squirrel, so no option holds one. Five merges.

    python design/studio/squirrel_r2.py   ->  design/studio/out/squirrel-r2/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import HERE, render
from squirrel_r1 import OPTIONS as R1, RED, front, side

C, F = R1['C'], R1['F']
CINNAMON = dict(fur='#E9A06A', fur_dk='#D38B58', tail_lt='#F7CFA6', tuft='#E39560')

# The chibi body with F's curl, scaled to the chibi's bigger tail.
CURL_FRONT = [(190, 228, 30), (226, 196, 38), (250, 146, 44), (246, 90, 42), (216, 52, 34), (176, 44, 27), (160, 64, 20)]
CURL_SIDE = [(224, 206, 28), (258, 168, 36), (270, 116, 42), (256, 66, 36), (222, 40, 28), (190, 46, 21), (182, 68, 16)]

CHIBI = dict(head=C['head'], body=C['body'], ear_h=28, eye_k=1.2, side_body=C['side_body'],
             side_head=C['side_head'])

OPTIONS = {
    '1': dict(RED, **CHIBI, tufts=True, tail_front=CURL_FRONT, tail_side=CURL_SIDE,
              name='Chibi, curly tail', note='C’s big head and tiny body, F’s tail curling over its head.'),
    '2': dict(RED, **CHIBI, tufts=True, cheek=1.12, tail_front=CURL_FRONT, tail_side=CURL_SIDE,
              name='Chibi, cheeks, curly tail', note='All three: chubby stuffed cheeks too.'),
    '3': dict(RED, **CHIBI, **{k: v for k, v in CINNAMON.items()}, tufts=True, cheek=1.12, tail_front=CURL_FRONT, tail_side=CURL_SIDE,
              name='All three, cinnamon', note='As 2, in F’s paler cinnamon.'),
    '4': dict(RED, **CHIBI, tufts=True, cheek=1.12, tail_front=C['tail_front'], tail_side=C['tail_side'],
              name='Chibi with cheeks, big plume', note='C’s huge plume tail instead of the curl.'),
    '5': dict(RED, **dict(CHIBI, ear_h=22), cheek=1.12, tail_front=CURL_FRONT, tail_side=CURL_SIDE,
              name='All three, no ear tufts', note='As 2 with plain round ears: softer.'),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', side(o))):
            sp = f'{out_dir}/squirrel-r2-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/squirrel-r2')
