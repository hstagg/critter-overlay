"""The golden kitten's rig parts: the approved kitten's own parts recoloured
gold, with each variant's extras drawn into them. godot/art/golden_kitten/<variant>/.

Approved 2026-10-07 (studio round 2): three secret tiers within Legendary,
commonest first: glitter (polished gold with glitter, option 1), lynx (adds
ear tufts and a ruff of cheek fur, option 4), royal (cheek ruff, a heart gem
on its brow, star-shine eyes, option 6). Sheen and glitter are in every one.

    python design/studio/golden_rig.py
"""
import os
import random
import re

HERE = os.path.dirname(os.path.abspath(__file__))
KITTEN = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art', 'kitten'))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art', 'golden_kitten'))
OL = '#6B4A3A'
GOLD = {'#F6C28F': '#FAD260', '#E89A5B': '#D69628', '#E3AE7B': '#E8B848'}
FUR, DEEP = '#FAD260', '#D69628'

VARIANTS = {
    'glitter': dict(),
    'lynx': dict(tufts=True, cheeks=True),
    'royal': dict(cheeks=True, gem=True, star_eyes=True),
}


def sparkle(x, y, r, fill='#FFFFFF'):
    return (f'<path d="M{x} {y - r} Q{x + r * 0.18} {y - r * 0.18} {x + r} {y} Q{x + r * 0.18} {y + r * 0.18} {x} {y + r} '
            f'Q{x - r * 0.18} {y + r * 0.18} {x - r} {y} Q{x - r * 0.18} {y - r * 0.18} {x} {y - r} Z" fill="{fill}"/>')


def sheen_and_glitter(cx, cy, rx, ry, uid, seed):
    """A glossy diagonal sheen and glitter, clipped to an ellipse."""
    rnd = random.Random(seed)
    out = f'<clipPath id="{uid}"><ellipse cx="{cx}" cy="{cy}" rx="{rx - 2}" ry="{ry - 2}"/></clipPath><g clip-path="url(#{uid})">'
    for off, w, op in ((-0.35, 22, 0.32), (-0.05, 8, 0.26)):
        x = cx + rx * off
        out += f'<path d="M{x:.1f} {cy - ry:.1f} l{w} 0 l{-ry * 0.9:.1f} {ry * 2:.1f} l{-w} 0 Z" fill="#FFFFFF" opacity="{op}"/>'
    for _ in range(int(rx * ry / 260)):
        a, k = rnd.uniform(0, 6.283), rnd.uniform(0, 1) ** 0.5
        import math
        x, y = cx + rx * k * 0.92 * math.cos(a), cy + ry * k * 0.92 * math.sin(a)
        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rnd.uniform(0.9, 1.7):.1f}" fill="#FFFBE8" opacity="0.85"/>'
    return out + '</g>'


def cheeks():
    out = ''
    for s in (-1, 1):
        x = 150 + s * 86
        d = f'M{x} 120 L{x + s * 24} 128 L{x + s * 8} 136 L{x + s * 28} 146 L{x + s * 8} 152 L{x + s * 22} 166 L{x - s * 6} 160 Z'
        out += f'<path d="{d}" fill="{FUR}" stroke="{OL}" stroke-width="3.5" stroke-linejoin="round"/>'
    return out


def tuft(x, s):
    d = f'M{x - s * 6} 34 L{x - s * 8} 6 L{x - s * 1} 24 L{x + s * 2} -2 L{x + s * 5} 24 L{x + s * 11} 8 L{x + s * 9} 34 Z'
    return (f'<path d="{d}" fill="{FUR}" stroke="{OL}" stroke-width="3.5" stroke-linejoin="round"/>'
            f'<path d="M{x - s * 1} 30 L{x + s * 2} 6" stroke="{DEEP}" stroke-width="2.4" stroke-linecap="round"/>')


GEM = (f'<path d="M150 74 C 140 66 140 54 150 58 C 160 54 160 66 150 74 Z" fill="#F07FA8" stroke="{OL}" stroke-width="3" stroke-linejoin="round"/>'
       f'<path d="M146 60 q2 -2 5 -1" stroke="#FFFFFF" stroke-width="2" fill="none" stroke-linecap="round"/>')


def recolour(text):
    for a, b in GOLD.items():
        text = text.replace(a, b).replace(a.lower(), b)
    return text


def inject(svg, before='', after=''):
    head, rest = svg.split('>', 1)
    body, tail = rest.rsplit('</svg>', 1)
    return f'{head}>{before}{body}{after}</svg>{tail}'


def build():
    for vid, o in VARIANTS.items():
        d = os.path.join(OUT, vid)
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(KITTEN):
            if not f.endswith('.svg'):
                continue
            s = recolour(open(os.path.join(KITTEN, f)).read())
            name = f[:-4]
            if name == 'head':
                s = inject(s, before=cheeks() if o.get('cheeks') else '',
                           after=sheen_and_glitter(150, 122, 92, 74, 'hs', 3) + (GEM if o.get('gem') else ''))
            elif name in ('body', 'walk-body', 'loaf-body'):
                m = re.search(r'<ellipse cx="([\d.]+)" cy="([\d.]+)" rx="([\d.]+)" ry="([\d.]+)"', s)
                if m:
                    cx, cy, rx, ry = (float(v) for v in m.groups())
                    s = inject(s, after=sheen_and_glitter(cx, cy, rx, ry, 'bs', 5))
            elif name == 'ear-l' and o.get('tufts'):
                s = inject(s, after=tuft(84, -1))
            elif name == 'ear-r' and o.get('tufts'):
                s = inject(s, after=tuft(216, 1))
            elif name == 'eyes' and o.get('star_eyes'):
                s = inject(s, after=sparkle(116, 126, 6.5) + sparkle(192, 126, 6.5))
            open(os.path.join(d, f), 'w').write(s)
    print(len(VARIANTS), 'variants ->', OUT)


if __name__ == '__main__':
    build()
