"""Stack a species' rig parts into poses and render a check sheet.

    python design/studio/comp.py SPECIES "body,foot-l,head,eyes" "walk-body,head-side,eye-side" ...
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from common import render

HERE = os.path.dirname(os.path.abspath(__file__)).replace('\\', '/')
sp = sys.argv[1]
art = f'{HERE}/../../godot/art/{sp}'
out = f'{HERE}/out/rig-{sp}'
os.makedirs(out, exist_ok=True)


def inner(n):
    s = open(f'{art}/{n}.svg').read()
    return s[s.index('>') + 1:s.rindex('</svg>')]


pairs = []
for i, group in enumerate(sys.argv[2:]):
    s = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
         + ''.join(inner(n) for n in group.split(',')) + '</svg>')
    p = f'{out}/pose{i}.svg'
    open(p, 'w').write(s)
    pairs.append((p, p[:-4] + '.png'))
render(pairs, 1.0)
ims = [Image.open(b) for a, b in pairs]
sheet = Image.new('RGBA', (300 * len(ims), 280), (243, 230, 214, 255))
for i, im in enumerate(ims):
    sheet.alpha_composite(im, (300 * i, 0))
sheet.save(f'{out}/_sheet.png')
print(f'{out}/_sheet.png')
