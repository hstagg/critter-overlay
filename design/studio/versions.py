"""Rare and Epic versions of each species: godot/art/<species>/<version>/.

Harrison's rarity model (2026-10-07): the Common is the species as built;
Rare and Epic are versions of it. A version folder holds only the parts it
changes (critter.gd falls back to the species' own for the rest). Each
version here is a recipe on the built parts: a colour swap, patches clipped
to the head or body, a fluffy ruff, coloured irises, new ears, small extras.
These are concepts for his picks (and for the artist to make their own);
the picked ones are marked in PICKED.

    python design/studio/versions.py            # every version
    python design/studio/versions.py kitten     # one species
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import egg, tufts

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art'))
OL = '#6B4A3A'
EYE = '#2B2330'

# Already chosen in the studio (round 2 and 3 answers).
PICKED = {('turtle', 'sprout'): 'rare', ('turtle', 'hatchling'): 'epic',
          ('squirrel', 'cinnamon'): 'rare', ('panda', 'bamboo'): 'rare', ('panda', 'brown'): 'epic'}


def flower(x, y, r=5.5, petal='#F7B8C8', mid='#F6C453'):
    out = ''.join(f'<ellipse cx="{x + r * 0.9 * math.cos(a):.1f}" cy="{y + r * 0.9 * math.sin(a):.1f}" rx="{r * 0.62:.1f}" ry="{r * 0.62:.1f}" fill="{petal}" stroke="{OL}" stroke-width="1.6"/>'
                  for a in [i * 2 * math.pi / 5 for i in range(5)])
    return out + f'<circle cx="{x}" cy="{y}" r="{r * 0.45:.1f}" fill="{mid}" stroke="{OL}" stroke-width="1.4"/>'


def fluffy_ring(cx, cy, rx, ry, fill, k=1.14, n=30, seed=4):
    f = egg(cx, cy, rx * k, ry * k)
    return f'<path d="{tufts(f, 0, 360, n, 0.08, 1.06, 6, 0.03, seed, 0.05)} Z" fill="{fill}" stroke="{OL}" stroke-width="4" stroke-linejoin="round"/>'


def sprout(x, y, daisy=False):
    out = (f'<path d="M{x} {y + 6} q2 -14 -2 -22" stroke="#5F8F3E" stroke-width="4" fill="none" stroke-linecap="round"/>'
           f'<path d="M{x - 2} {y - 14} q-22 -10 -26 4 q14 8 26 -4 Z" fill="#9ED36A" stroke="{OL}" stroke-width="3" stroke-linejoin="round"/>'
           f'<path d="M{x - 1} {y - 16} q18 -16 26 -4 q-12 12 -26 4 Z" fill="#B5E07E" stroke="{OL}" stroke-width="3" stroke-linejoin="round"/>')
    if daisy:
        fx, fy = x + 1, y - 26
        out += (f'<path d="M{fx} {fy + 2} L{fx} {fy + 12}" stroke="#5F8F3E" stroke-width="3"/>'
                + ''.join(f'<ellipse cx="{fx}" cy="{fy - 7}" rx="3.6" ry="6.5" transform="rotate({a} {fx} {fy})" fill="#FFFFFF" stroke="{OL}" stroke-width="2"/>' for a in range(0, 360, 60))
                + f'<circle cx="{fx}" cy="{fy}" r="4.2" fill="#F6C453" stroke="{OL}" stroke-width="2"/>')
    return out


def bamboo_sprig(x, y):
    return (f'<g transform="rotate(-70 {x} {y})"><path d="M{x - 4} {y + 30} L{x - 4} {y - 34} Q{x} {y - 37} {x + 4} {y - 34} L{x + 4} {y + 30} Z" fill="#9CCB6B" stroke="{OL}" stroke-width="3"/>'
            f'<path d="M{x - 4} {y - 6} l8 0" stroke="#6E9F45" stroke-width="2.5"/>'
            f'<path d="M{x + 3} {y - 24} q18 -13 28 -5 q-13 10 -28 5 Z" fill="#A9D873" stroke="{OL}" stroke-width="3"/></g>')


# --- Recipes -------------------------------------------------------------------------
# colours: hex -> hex over every part. patches: part -> [(dx, dy, rx, ry, colour)] in
# fractions of that part's first ellipse, clipped to it. before / after: part -> SVG
# in the part's own drawing coordinates. iris: a colour put in the lower half of each
# eye. replace: part -> whole new drawing.

KITTEN = {'fur': '#F6C28F', 'stripe': '#E89A5B', 'dark': '#E3AE7B'}
VERSIONS = {
    'kitten': {
        'calico': dict(tier='rare', name='Calico', note='White with orange and black patches.',
                       colours={'#F6C28F': '#FFF8F0', '#E89A5B': '#FFF8F0', '#E3AE7B': '#EFE6DC'},
                       patches={'head': [(-0.55, -0.45, 0.42, 0.38, '#F2A65E'), (0.6, -0.2, 0.36, 0.42, '#4A4048')],
                                'body': [(0.5, -0.3, 0.45, 0.4, '#F2A65E'), (-0.55, 0.3, 0.32, 0.3, '#4A4048')],
                                'walk-body': [(-0.3, -0.4, 0.38, 0.45, '#F2A65E'), (0.5, -0.1, 0.32, 0.42, '#4A4048')]}),
        'grey_tabby': dict(tier='rare', name='Grey tabby', note='Soft grey with darker stripes.',
                           colours={'#F6C28F': '#BDB8BE', '#E89A5B': '#8E8992', '#E3AE7B': '#A9A4AB'}),
        'tuxedo': dict(tier='rare', name='Tuxedo', note='Black coat, white muzzle, chest and socks.',
                       colours={'#F6C28F': '#4A4048', '#E89A5B': '#4A4048', '#E3AE7B': '#3D343B'}),
        'snow': dict(tier='epic', name='Snow kitten', note='Pure white, faint grey stripes, ice-blue eyes.',
                     colours={'#F6C28F': '#FBF8F6', '#E89A5B': '#E4DDE2', '#E3AE7B': '#EDE7EA'}, iris='#6FB7E8'),
        'longhair': dict(tier='epic', name='Fluffy longhair', note='Cream and ginger with a big fluffy ruff.',
                         colours={'#F6C28F': '#F8D9B0', '#E89A5B': '#E6A66B'},
                         before={'head': fluffy_ring(150, 122, 92, 74, '#F8D9B0', 1.12, 34)}),
    },
    'rabbit': {
        'wild_brown': dict(tier='rare', name='Wild brown', note='A brown wild-rabbit coat with a cream tummy.',
                           colours={'#FBF4EC': '#C9A27E', '#E9DED3': '#B48D69', '#E6DACE': '#B08A66'}),
        'dutch': dict(tier='rare', name='Dutch', note='White with dark patches over its eyes and back.',
                      patches={'head': [(-0.62, -0.1, 0.42, 0.62, '#4E4650'), (0.62, -0.1, 0.42, 0.62, '#4E4650')],
                               'walk-body': [(0.35, -0.2, 0.7, 0.6, '#4E4650')]},
                      colours={'#F7B8C0': '#F7B8C0'}),
        'lop': dict(tier='epic', name='Lop-eared', note='Its ears flop down beside its face.',
                    # drawn on the face, in front (its own ears sit behind the head)
                    replace={'ear-l': '', 'ear-r': ''},
                    after={'head': f'<path d="M126 86 C 100 80 70 98 66 140 C 64 170 80 184 92 172 C 96 148 104 118 134 94 Z" fill="#FBF4EC" stroke="{OL}" stroke-width="4" stroke-linejoin="round"/>'
                                   f'<path d="M116 96 C 94 104 80 122 78 150 C 80 162 86 164 90 156 C 92 132 100 114 120 102 Z" fill="#F7B8C0"/>'
                                   f'<path d="M174 86 C 200 80 230 98 234 140 C 236 170 220 184 208 172 C 204 148 196 118 166 94 Z" fill="#FBF4EC" stroke="{OL}" stroke-width="4" stroke-linejoin="round"/>'
                                   f'<path d="M184 96 C 206 104 220 122 222 150 C 220 162 214 164 210 156 C 208 132 200 114 180 102 Z" fill="#F7B8C0"/>'}),
        'lionhead': dict(tier='epic', name='Lionhead', note='A fluffy mane all round its face.',
                         before={'head': fluffy_ring(150, 142, 78, 62, '#F3E7DA', 1.18, 32)}),
    },
    'duckling': {
        'brown': dict(tier='rare', name='Brown duckling', note='A wild mallard duckling: warm brown with a cream face.',
                      colours={'#FFE07A': '#C49A63', '#F9C94E': '#A87E4C', '#D9A936': '#8E6A40', '#FFF4CC': '#F3E2B8'}),
        'spotted': dict(tier='rare', name='Spotted', note='Yellow with soft brown spots.',
                        patches={'body': [(-0.4, -0.3, 0.16, 0.14, '#C49A63'), (0.35, -0.45, 0.13, 0.12, '#C49A63'), (0.55, 0.1, 0.14, 0.13, '#C49A63')],
                                 'head': [(0.45, -0.5, 0.12, 0.11, '#C49A63'), (-0.5, -0.35, 0.1, 0.1, '#C49A63')]}),
        'cygnet': dict(tier='epic', name='Cygnet', note='A baby swan: soft grey down, a dark beak.',
                       colours={'#FFE07A': '#CFCBD2', '#F9C94E': '#B7B2BA', '#D9A936': '#9E99A2', '#FFF4CC': '#ECE9EE',
                                '#F7A04A': '#5E5A62', '#DE8A3A': '#4A464E'}),
        'rubber': dict(tier='epic', name='Rubber duck', note='Bath-toy bright and glossy, an orange beak.',
                       colours={'#FFE07A': '#FFD84D', '#F9C94E': '#F5C232', '#F7A04A': '#FF7A2E', '#DE8A3A': '#E0611E'},
                       after={'head': '<path d="M108 92 Q118 70 140 66" stroke="#FFFFFF" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.7"/>',
                              'body': '<path d="M112 210 Q118 196 132 192" stroke="#FFFFFF" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.6"/>'}),
    },
    'hedgehog': {
        'blonde': dict(tier='rare', name='Blonde', note='Pale cinnamon quills.',
                       colours={'#7B5640': '#C9A27A', '#A98468': '#E6CBA8', '#5E4030': '#A98060', '#7A5440': '#B08A64'}),
        'chocolate': dict(tier='rare', name='Chocolate', note='Deep chocolate quills, cream flecks.',
                          colours={'#7B5640': '#4E3428', '#A98468': '#9C7A62', '#5E4030': '#3A261C'}),
        'albino': dict(tier='epic', name='Snowy', note='White quills and rosy eyes.',
                       colours={'#7B5640': '#ECE5E0', '#A98468': '#FFFFFF', '#5E4030': '#D8CFC8', '#7A5440': '#E2D8D0', '#F9DDBF': '#FBEEE6'},
                       iris='#E06F8B'),
        'blossom': dict(tier='epic', name='Blossom', note='Little pink blossoms caught all over its quills.',
                        after_fn='blossoms'),
    },
    'squirrel': {
        'cinnamon': dict(tier='rare', name='Cinnamon', note='Your pick: the same squirrel in pale cinnamon.',
                         colours={'#E0823F': '#E9A06A', '#C66E33': '#D38B58', '#F4B07A': '#F7CFA6', '#D8743A': '#E39560'}),
        'snowy': dict(tier='epic', name='Snowy', note='A white winter squirrel with a silvery tail.',
                      colours={'#E0823F': '#F4F0EC', '#C66E33': '#DCD6D2', '#F4B07A': '#FFFFFF', '#D8743A': '#E8E2DE'}, iris='#7A9FD6'),
        'black': dict(tier='epic', name='Black squirrel', note='A glossy black coat, cream tummy, amber eyes.',
                      colours={'#E0823F': '#3E3438', '#C66E33': '#2E2629', '#F4B07A': '#6A5C62', '#D8743A': '#4A3E42'}, iris='#E8A33A'),
        'flying': dict(tier='epic', name='Flying squirrel', note='Grey-brown, with gliding flaps between its paws.',
                       colours={'#E0823F': '#A8927F', '#C66E33': '#8E7A68', '#F4B07A': '#CDBBA9', '#D8743A': '#9A8572'},
                       before={'body': f'<path d="M114 182 C 96 196 94 224 108 240 L120 232 Z M182 182 C 200 196 202 224 188 240 L176 232 Z" fill="#9A8572" stroke="{OL}" stroke-width="3.5" stroke-linejoin="round"/>'}),
    },
    'otter': {
        'sea': dict(tier='rare', name='Sea otter', note='A darker coat with a pale, fluffy face.',
                    colours={'#A8744E': '#6F5243', '#8F6141': '#5C4337', '#F3E1C8': '#EFE4D6'}),
        'caramel': dict(tier='rare', name='Caramel', note='Light caramel all over.',
                        colours={'#A8744E': '#C99466', '#8F6141': '#AF7C52', '#F3E1C8': '#FBEBD6'}),
        'snow': dict(tier='epic', name='Snow otter', note='White with a silvery sheen and blue eyes.',
                     colours={'#A8744E': '#ECE8E4', '#8F6141': '#D6D0CC', '#F3E1C8': '#FFFFFF'}, iris='#6FB7E8'),
        'spotted': dict(tier='epic', name='Giant otter', note='Dark chocolate with creamy throat spots.',
                        colours={'#A8744E': '#5A4038', '#8F6141': '#47322B'},
                        patches={'body': [(-0.3, -0.5, 0.18, 0.12, '#F3E1C8'), (0.25, -0.38, 0.15, 0.11, '#F3E1C8'), (-0.05, -0.2, 0.12, 0.09, '#F3E1C8')]}),
    },
    'panda': {
        'bamboo': dict(tier='rare', name='Bamboo', note='Your pick: a sprig of bamboo to chew.',
                       after={'head': bamboo_sprig(162, 142)}),
        'brown': dict(tier='epic', name='Brown panda', note='Your pick: the rare Qinling colouring.',
                      colours={'#3B3437': '#7A5A45', '#2E282B': '#664A39', '#FFFDF8': '#FBF4E8', '#F5EFE6': '#F3E6D2'}),
    },
    'turtle': {
        'sprout': dict(tier='rare', name='Sprouted', note='Your pick: a little sprout on its shell.',
                       after={'body': sprout(149, 90), 'walk-body': sprout(167, 102), 'loaf-body': sprout(167, 128)}),
        'hatchling': dict(tier='epic', name='Hatchling', note='Your pick: the baby, big head and small shell, a daisy on its sprout.',
                          after={'body': sprout(149, 90, True), 'walk-body': sprout(167, 102, True), 'loaf-body': sprout(167, 128, True)}),
    },
}


def blossoms(part, body):
    # Pink blossoms across the coat: placed along the coat's spikes.
    if part == 'body':
        f = egg(160, 128, 106, 112)
        pts = [f(a, 0.84) for a in (150, 200, 235, 270, 305, 340, 25)]
    elif part == 'walk-body':
        f = egg(190, 166, 98, 78, 0.05)
        pts = [f(a, k) for a, k in ((215, 0.8), (245, 0.75), (275, 0.82), (300, 0.7), (330, 0.8), (355, 0.65))]
    else:
        return ''
    return ''.join(flower(x, y) for x, y in pts)


def split(svg):
    head, rest = svg.split('>', 1)
    body, tail = rest.rsplit('</svg>', 1)
    m = re.match(r'\s*<g transform="translate\(([-\d.]+) ([-\d.]+)\)">', body)
    return head + '>', body, '</svg>' + tail, m


def put(svg, before='', after=''):
    head, body, tail, m = split(svg)
    if m:   # inside the part's own drawing group
        g_open = m.group(0)
        inner = body[len(g_open):]
        inner = inner[:inner.rindex('</g>')]
        return head + g_open + before + inner + after + '</g>' + tail
    return head + before + body + after + tail


def first_ellipse(svg):
    m = re.search(r'<ellipse cx="([\d.]+)" cy="([\d.]+)" rx="([\d.]+)" ry="([\d.]+)"', svg)
    return tuple(float(v) for v in m.groups()) if m else None


def patches(svg, items, uid):
    e = first_ellipse(svg)
    if not e:
        return svg
    cx, cy, rx, ry = e
    out = f'<clipPath id="{uid}"><ellipse cx="{cx}" cy="{cy}" rx="{rx - 2}" ry="{ry - 2}"/></clipPath><g clip-path="url(#{uid})">'
    for dx, dy, prx, pry, col in items:
        out += f'<ellipse cx="{cx + dx * rx:.1f}" cy="{cy + dy * ry:.1f}" rx="{prx * rx:.1f}" ry="{pry * ry:.1f}" fill="{col}"/>'
    out += '</g>'
    # under the part's details (eyes, stripes) but over its fill: right after the ellipse
    m = re.search(r'<ellipse cx="[\d.]+" cy="[\d.]+" rx="[\d.]+" ry="[\d.]+"[^>]*/>', svg)
    return svg[:m.end()] + out + svg[m.end():]


def irises(svg, colour):
    def add(m):
        attrs = dict(re.findall(r'(\w+)="([^"]+)"', m.group(0)))
        cx, cy, rx, ry = (float(attrs[k]) for k in ('cx', 'cy', 'rx', 'ry'))
        return m.group(0) + f'<ellipse cx="{cx:.1f}" cy="{cy + ry * 0.3:.1f}" rx="{rx * 0.72:.1f}" ry="{ry * 0.5:.1f}" fill="{colour}"/>'
    return re.sub(r'<ellipse [^>]*fill="' + EYE + r'"[^>]*/>', add, svg)


def build(only=None):
    n = 0
    for sp, versions in VERSIONS.items():
        if only and sp != only:
            continue
        base = os.path.join(ART, sp)
        for vid, r in versions.items():
            out = os.path.join(base, vid)
            os.makedirs(out, exist_ok=True)
            for f in os.listdir(out):
                if f.endswith('.svg'):
                    os.remove(os.path.join(out, f))
            for f in sorted(os.listdir(base)):
                if not f.endswith('.svg'):
                    continue
                part = f[:-4]
                src = open(os.path.join(base, f)).read()
                s = src
                if part in r.get('replace', {}):
                    head, _, tail, _ = split(s)
                    s = head + r['replace'][part] + tail
                for a, b in r.get('colours', {}).items():
                    s = s.replace(a, b).replace(a.lower(), b)
                if part in r.get('patches', {}):
                    s = patches(s, r['patches'][part], f'p{abs(hash(part)) % 9999}')
                if part in r.get('before', {}) or part in r.get('after', {}):
                    s = put(s, r.get('before', {}).get(part, ''), r.get('after', {}).get(part, ''))
                if r.get('after_fn') == 'blossoms':
                    extra = blossoms(part, s)
                    if extra:
                        s = put(s, '', extra)
                if r.get('iris') and part in ('eyes', 'eye-side', 'loaf-eyes'):
                    s = irises(s, r['iris'])
                if s != src:
                    open(os.path.join(out, f), 'w').write(s)
            n += 1
    print(n, 'versions ->', ART)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else None)
