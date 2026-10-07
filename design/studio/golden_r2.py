"""Golden kitten, studio round 2: Harrison kept B (polished sheen), D (glitter)
and F (stars), and asked for more effort for a Legendary. So beyond the
coat, some options give it its own features drawn over the kitten: lynx tufts
on the ears, a fluffy ruff of cheek fur, a cream chest bib, star-shine eyes
and a little gem.

Extras are drawn in the kitten's part frame and placed onto its engine stills
(--zoom=2: 0.675 px per unit, feet at (240, 345); walking, the head sits
38 units forward and 8 down, and the still is mirrored).

    python design/studio/golden_r2.py STILLS_DIR   ->  design/studio/out/golden-r2/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from common import OL, render
from golden_r1 import recolour, extras, frame

HERE = os.path.dirname(os.path.abspath(__file__)).replace('\\', '/')
K = 0.675
FEET = (240, 345)
BASE = (150, 262)


def hexc(c):
    return '#%02X%02X%02X' % c


def sparkle(x, y, r, fill):
    return (f'<path d="M{x} {y - r} Q{x + r * 0.18} {y - r * 0.18} {x + r} {y} Q{x + r * 0.18} {y + r * 0.18} {x} {y + r} '
            f'Q{x - r * 0.18} {y + r * 0.18} {x - r} {y} Q{x - r * 0.18} {y - r * 0.18} {x} {y - r} Z" fill="{fill}"/>')


def head_extras(o, fur, deep):
    out = ''
    if o.get('tufts'):
        for s in (-1, 1):
            x = 150 + s * 66   # ear tips at 84 and 216
            d = (f'M{x - s * 6} 34 L{x - s * 8} 6 L{x - s * 1} 24 L{x + s * 2} -2 L{x + s * 5} 24 L{x + s * 11} 8 L{x + s * 9} 34 Z')
            out += f'<path d="{d}" fill="{fur}" stroke="{OL}" stroke-width="3.5" stroke-linejoin="round"/>'
            out += f'<path d="M{x - s * 1} 30 L{x + s * 2} 6" stroke="{deep}" stroke-width="2.4" stroke-linecap="round"/>'
    if o.get('cheeks'):
        for s in (-1, 1):
            x = 150 + s * 86
            d = (f'M{x} 120 L{x + s * 24} 128 L{x + s * 8} 136 L{x + s * 28} 146 L{x + s * 8} 152 L{x + s * 22} 166 L{x - s * 6} 160 Z')
            out += f'<path d="{d}" fill="{fur}" stroke="{OL}" stroke-width="3.5" stroke-linejoin="round"/>'
    if o.get('star_eyes'):
        for x in (112, 188):
            out += sparkle(x + 4, 127, 6.5, '#FFFFFF')
    if o.get('gem'):
        out += (f'<path d="M150 82 C 140 74 140 62 150 66 C 160 62 160 74 150 82 Z" fill="#F07FA8" stroke="{OL}" stroke-width="3" stroke-linejoin="round"/>'
                f'<path d="M146 68 q2 -2 5 -1" stroke="#FFFFFF" stroke-width="2" fill="none" stroke-linecap="round"/>')
    return out


def body_extras(o):
    if not o.get('bib'):
        return ''
    d = 'M114 196 Q120 214 128 206 Q134 222 142 210 Q150 226 158 210 Q166 222 172 206 Q180 214 186 196 Z'
    return f'<path d="{d}" fill="#FFF8EE" stroke="{OL}" stroke-width="3.5" stroke-linejoin="round"/>'


def overlay(o, view, fur, deep, tmp):
    if view == 'front':
        g = f'<g transform="translate({FEET[0]} {FEET[1]}) scale({K}) translate({-BASE[0]} {-BASE[1]})">'
        body = g + body_extras(o) + head_extras(o, fur, deep) + '</g>'
    else:
        g = f'<g transform="translate({FEET[0]} {FEET[1]}) scale({-K} {K}) translate({-BASE[0]} {-BASE[1]}) translate(-38 8)">'
        body = g + head_extras(o, fur, deep) + '</g>'
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 480" width="480" height="480">{body}</svg>'
    sp = f'{tmp}/ov-{view}.svg'
    with open(sp, 'w') as fh:
        fh.write(svg)
    render([(sp, sp[:-4] + '.png')], 1.0)
    return Image.open(sp[:-4] + '.png').convert('RGBA')


GOLD = dict(fur=(250, 210, 96), stripe=(214, 150, 40))
STARS = [(0.02, 0.08, 13), (0.97, 0.16, 10), (0.94, 0.78, 9), (0.0, 0.62, 8)]

OPTIONS = {
    '1': dict(GOLD, shine=True, glitter=40, name='Polished glitter', note='B’s sheen with D’s glitter.'),
    '2': dict(GOLD, shine=True, stars=STARS, name='Polished and starry', note='B’s sheen with F’s floating stars.'),
    '3': dict(GOLD, shine=True, glitter=40, stars=STARS, name='All three', note='Sheen, glitter and stars.'),
    '4': dict(GOLD, shine=True, glitter=30, tufts=True, cheeks=True, name='Golden lynx',
              note='Its own look: tufted ears and a ruff of cheek fur, glossy and glittering.'),
    '5': dict(GOLD, shine=True, stars=STARS, tufts=True, cheeks=True, star_eyes=True,
              name='Golden lynx, star eyes', note='As 4, with star-shine in its eyes and stars round it.'),
    '6': dict(GOLD, shine=True, glitter=30, stars=STARS, cheeks=True, gem=True, star_eyes=True,
              name='Royal gold', note='Cheek ruff, a little heart gem on its brow, star eyes, sheen, glitter and stars.'),
}


def build(stills, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    tmp = out_dir + '/_tmp'
    os.makedirs(tmp, exist_ok=True)
    for key, o in OPTIONS.items():
        fur, deep = hexc(o['fur']), hexc(o['stripe'])
        for i, view in enumerate(('front', 'side')):
            im = Image.open(f'{stills}/kitten-{view}.png').convert('RGBA')
            im = recolour(im, o['fur'], o['stripe'])
            ov = overlay(o, view, fur, deep, tmp)
            base = Image.new('RGBA', im.size, (0, 0, 0, 0))
            # tufts and cheek fur sit behind nothing in front of them: put them
            # under the kitten so its outline stays on top, the bib and gem over it
            base.alpha_composite(ov)
            base.alpha_composite(im)
            if o.get('bib') or o.get('gem') or o.get('star_eyes'):
                o2 = dict(tufts=False, cheeks=False, bib=o.get('bib') and view == 'front',
                          gem=o.get('gem'), star_eyes=o.get('star_eyes'))
                base.alpha_composite(overlay(o2, view, fur, deep, tmp))
            out = extras(base, o, 7 + i)
            frame(out).save(f'{out_dir}/golden-r2-{key}-{view}.png')


if __name__ == '__main__':
    build(sys.argv[1], HERE + '/out/golden-r2')
