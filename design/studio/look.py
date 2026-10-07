"""Contact sheet of a round for a quick look: python look.py out/<dir> [scale]"""
import glob
import sys

from PIL import Image, ImageDraw

d = sys.argv[1]
fronts = sorted(glob.glob(d + '/*-front.png'))
rows = [[f, f.replace('-front.png', '-side.png')] for f in fronts]
ims = [[Image.open(p).convert('RGBA') for p in r] for r in rows]
cw, ch = ims[0][0].size
cols = 2   # options per row (each a front and side pair)
nrow = (len(ims) + cols - 1) // cols
s = Image.new('RGBA', (cols * 2 * cw + 20, nrow * ch), (243, 230, 214, 255))
dr = ImageDraw.Draw(s)
for i, pair in enumerate(ims):
    x = (i % cols) * (2 * cw + 20)
    y = (i // cols) * ch
    for j, im in enumerate(pair):
        s.alpha_composite(im, (x + j * cw, y))
    dr.text((x + 4, y + 4), rows[i][0].replace('\\', '/').split('/')[-1], fill=(80, 60, 50, 255))
s.save(d + '/_look.png')
