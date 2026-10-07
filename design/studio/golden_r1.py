"""Golden kitten, studio round 1: six gold treatments of the approved kitten.

The golden kitten is a Legendary-only special: the approved kitten rig with
its own coat, so these recolour the kitten's own engine stills (--stills)
rather than redrawing it. The ginger fur and stripes are remapped by hue;
outline, eyes, cream and blush stay. Some options add shine or glitter.

    python design/studio/golden_r1.py STILLS_DIR   ->  design/studio/out/golden-r1/
"""
import colorsys
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__)).replace('\\', '/')
G = 344   # the ground line in a --zoom=2 still


def recolour(im, fur, stripe, cream=None):
    """Map the kitten's ginger (hue 20-35 deg, saturated) onto new fur and stripe
    colours, keeping each pixel's lightness relative to the original fur."""
    a = np.asarray(im.convert('RGBA')).astype(np.float32) / 255.0
    rgb = a[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.zeros_like(mx)
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == r, ((g - b) / d) % 6, hue)
    hue = np.where(mx == g, (b - r) / d + 2, hue)
    hue = np.where(mx == b, (r - g) / d + 4, hue)
    hue = hue * 60
    ginger = (hue > 14) & (hue < 40) & (sat > 0.22) & (mx > 0.55)
    # stripes are the more saturated ginger
    is_stripe = ginger & (sat > 0.48)
    out = rgb.copy()
    base_v = 246 / 255
    for mask, col in ((ginger & ~is_stripe, fur), (is_stripe, stripe)):
        c = np.array(col, np.float32) / 255
        k = (mx / base_v)[..., None]
        out = np.where(mask[..., None], np.clip(c * np.minimum(k, 1.08), 0, 1), out)
    if cream is not None:
        cr = (sat < 0.16) & (mx > 0.9)
        c = np.array(cream, np.float32) / 255
        out = np.where(cr[..., None], c, out)
    res = np.concatenate([out, a[..., 3:]], -1)
    return Image.fromarray((res * 255).astype(np.uint8), 'RGBA')


def star(dr, x, y, r, fill):
    pts = []
    for i in range(8):
        rr = r if i % 2 == 0 else r * 0.28
        ang = i * 3.14159 / 4
        pts.append((x + rr * np.sin(ang), y - rr * np.cos(ang)))
    dr.polygon(pts, fill=fill)


def extras(im, opt, seed):
    rnd = random.Random(seed)
    alpha = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(alpha > 250)
    lay = Image.new('RGBA', im.size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(lay)
    if opt.get('glitter'):
        for _ in range(opt['glitter']):
            i = rnd.randrange(len(xs))
            x, y = xs[i], ys[i]
            px = im.getpixel((int(x), int(y)))
            if px[0] > 200 and px[2] < 190:   # only on the gold fur
                r = rnd.uniform(1.0, 1.9)
                dr.ellipse((x - r, y - r, x + r, y + r), fill=(255, 250, 225, 205))
    if opt.get('stars'):
        x0, y0, x1, y1 = im.getbbox()
        for fx, fy, r in opt['stars']:
            star(dr, x0 + (x1 - x0) * fx, y0 + (y1 - y0) * fy, r, (255, 206, 72, 255))
    out = im.copy()
    out.alpha_composite(lay)
    if opt.get('shine'):
        # a soft diagonal sheen over the fur only
        sh = Image.new('L', im.size, 0)
        sd = ImageDraw.Draw(sh)
        x0, y0, x1, y1 = im.getbbox()
        w = x1 - x0
        for off, wd in ((0.25, 16), (0.45, 7)):
            cx = x0 + w * off
            sd.polygon([(cx, y0), (cx + wd, y0), (cx + wd - 60, y1), (cx - 60, y1)], fill=70)
        fur = np.asarray(out)[..., 0] > 200
        m = np.asarray(sh) * (fur & (np.asarray(out)[..., 3] > 250))
        white = Image.new('RGBA', im.size, (255, 255, 255, 0))
        white.putalpha(Image.fromarray(m.astype(np.uint8)))
        out.alpha_composite(white)
    return out


def frame(im):
    # crop to the critter, then place on a 320x260 card, feet on its ground line
    x0, y0, x1, y1 = im.getbbox()
    cx = (x0 + x1) // 2
    c = im.crop((cx - 160, G - 236, cx + 160, G + 24))
    return c


OPTIONS = {
    'A': dict(name='Honey gold', note='Warm honey-gold fur, deeper gold stripes.',
              fur=(247, 205, 110), stripe=(226, 160, 52)),
    'B': dict(name='Polished gold', note='Bright gold with a glossy sheen across the fur.',
              fur=(250, 210, 96), stripe=(214, 150, 40), shine=True),
    'C': dict(name='Champagne', note='Pale, soft gold: the most delicate.',
              fur=(244, 222, 170), stripe=(222, 186, 118)),
    'D': dict(name='Glitter gold', note='Rich gold flecked with glitter.',
              fur=(242, 194, 84), stripe=(204, 138, 36), glitter=55),
    'E': dict(name='Rose gold', note='Pinkish gold, rosy stripes.',
              fur=(242, 190, 168), stripe=(214, 140, 120)),
    'F': dict(name='Starry gold', note='Honey gold with little stars floating round it.',
              fur=(247, 205, 110), stripe=(226, 160, 52),
              stars=[(0.02, 0.08, 13), (0.97, 0.16, 10), (0.94, 0.78, 9), (0.0, 0.62, 8)]),
}


def build(stills, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for key, o in OPTIONS.items():
        for i, view in enumerate(('front', 'side')):
            im = Image.open(f'{stills}/kitten-{view}.png').convert('RGBA')
            im = recolour(im, o['fur'], o['stripe'])
            im = extras(im, o, 7 + i)
            frame(im).save(f'{out_dir}/golden-r1-{key}-{view}.png')


if __name__ == '__main__':
    build(sys.argv[1], HERE + '/out/golden-r1')
