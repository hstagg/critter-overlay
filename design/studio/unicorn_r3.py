"""Unicorn, studio round 3: the curly foal (round-2 option 1) is final. Harrison
wants about seven colour variants, each a secret rarity tier within
Legendary. Nine palettes to choose from; the rarest gets decided later.

    python design/studio/unicorn_r3.py   ->  design/studio/out/unicorn-r3/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import HERE, render
from unicorn_r2 import LAV, front, side


def pal(coat, coat_dk, muzzle, hoof, horn, horn_band, ring, iris, mane, **kw):
    return dict(coat=coat, coat_dk=coat_dk, muzzle=muzzle, hoof=hoof, fetlock='#FFFFFF', horn=horn,
                horn_band=horn_band, ring=ring, iris=iris, mane=mane, style='curly', **kw)


OPTIONS = {
    '1': dict(LAV, style='curly', name='Lavender dream', note='The one you loved: lilac coat, pink and violet curls.'),
    '2': pal('#FFFDF9', '#EEE8E4', '#FBE3E6', '#E8C99A', '#FFF6D6', '#F6D77A', '#F2C14E', '#6FB7E8',
             ['#F7A8B8', '#FFD59A', '#FFF1A6', '#B9E8B0', '#A9D4F5', '#C9B6F2'],
             name='Pastel rainbow', note='White coat, a soft rainbow mane, gold horn.'),
    '3': pal('#FFDCE8', '#F5C6D7', '#FFEAF1', '#F2A7C1', '#FFFFFF', '#F7C9DA', '#F2C14E', '#5FA8E8',
             ['#A9D9F7', '#FFFFFF', '#C7E7FB'], name='Cotton candy', note='Pink coat, sky-blue and white curls.'),
    '4': pal('#DFF3E8', '#C9E6D6', '#F1FAF4', '#9FD1B6', '#FFFFFF', '#CDEBD9', '#F2C14E', '#E8836F',
             ['#FFC7A8', '#FFE7A3', '#FFB0B8'], name='Mint sorbet', note='Mint coat, peach, lemon and rose curls.'),
    '5': pal('#DDEBFA', '#C8DBF2', '#EEF5FD', '#9EBBE3', '#FFFFFF', '#D2E2F6', '#C9D3E3', '#7A6FE0',
             ['#FFFFFF', '#D6C8F5', '#BFD6F7'], name='Sky', note='Pale blue coat, cloud-white and lilac curls, silver ring.'),
    '6': pal('#FFE6D5', '#F7D3BC', '#FFF1E7', '#F0B28E', '#FFF6E6', '#F6D6A8', '#F2C14E', '#E06F8B',
             ['#FF9F8A', '#FFC48C', '#F58FA8'], name='Peach sunset', note='Peach coat, coral, apricot and rose curls.'),
    '7': pal('#FFF6E2', '#F1E4C6', '#FCE9D8', '#D9B57C', '#FFF3D0', '#F6D27A', '#E9A93A', '#C9862E',
             ['#F6C453', '#FFDA7A', '#E9A93A'], name='Golden sun', note='Cream coat, golden curls, a gold horn.'),
    '8': pal('#3E4B86', '#334072', '#5A68A6', '#C9CFE6', '#FFF3B8', '#F6E39A', '#E3C766', '#F6D46A',
             ['#DCE3F7', '#B7C3EC', '#F2F4FC'], glow=True, name='Starry night',
             note='Midnight-blue coat, silver curls, a glowing horn.'),
    '9': pal('#4A4458', '#3C3748', '#5E5770', '#9C93B3', '#F4F1FA', '#D9CCF2', '#F2C14E', '#7EE0D2',
             ['#8EF0DE', '#F7A8E0', '#B8A6FF'], glow=True, name='Twilight neon',
             note='Charcoal-violet coat, glowing mint, pink and violet curls: the rarest-looking.'),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', side(o))):
            sp = f'{out_dir}/unicorn-r3-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/unicorn-r3')
