"""Contact sheet: rows of PNGs on the board colour, for checking a round."""
import sys
from PIL import Image, ImageDraw


def sheet(rows, out, bg=(243, 230, 214, 255), pad=16):
    ims = [[Image.open(p).convert('RGBA') for p in r] for r in rows]
    w = max(sum(i.width for i in r) + pad * (len(r) + 1) for r in ims)
    h = sum(max(i.height for i in r) + pad for r in ims) + pad
    s = Image.new('RGBA', (w, h), bg)
    d = ImageDraw.Draw(s)
    y = pad
    for r, names in zip(ims, rows):
        x = pad
        for i, n in zip(r, names):
            s.alpha_composite(i, (x, y))
            d.text((x + 4, y + 2), n.replace('\\', '/').split('/')[-1][:-4], fill=(90, 70, 60, 255))
            x += i.width + pad
        y += max(i.height for i in r) + pad
    s.save(out)


if __name__ == '__main__':
    import glob
    d = sys.argv[1]
    keys = sorted({p.replace('\\', '/').split('/')[-1].split('-')[2] for p in glob.glob(d + '/hh-r1-*-front.png')})
    rows = [[f'{d}/hh-r1-{k}-front.png', f'{d}/hh-r1-{k}-side.png'] for k in keys]
    sheet(rows[:4], d + '/_sheet1.png')
    sheet(rows[4:], d + '/_sheet2.png')
