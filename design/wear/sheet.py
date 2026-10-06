"""Contact sheet of clothes renders from the game.

    godot --path godot -- --zoom=2 --seconds=600 --wear-sheet=DIR [--wear=a,b]
    python design/wear/sheet.py DIR OUT.png [item ...]

Godot saves its windows with premultiplied alpha; this undoes that before
compositing, so the colours read as they do on the desktop.
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SPECIES = ["kitten", "rabbit", "duckling"]
CELL = (250, 290)
CROP = (115, 60, 365, 350)   # a 480 px window at zoom 2


def unpremultiply(im):
    a = np.asarray(im.convert("RGBA")).astype(float)
    al = a[..., 3:4] / 255.0
    rgb = np.where(al > 0, np.clip(a[..., :3] / np.maximum(al, 1e-6), 0, 255), 0)
    return Image.fromarray(np.concatenate([rgb, a[..., 3:4]], -1).astype("uint8"), "RGBA")


def main():
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])
    items = sys.argv[3:] or sorted({p.stem.rsplit("-", 1)[0] for p in src.glob("*.png")})
    label_w = 200
    sheet = Image.new("RGBA", (label_w + CELL[0] * 3, CELL[1] * len(items)), (243, 238, 248, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("segoeuib.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    for r, it in enumerate(items):
        draw.text((14, r * CELL[1] + CELL[1] // 2 - 12), it, fill=(37, 26, 53, 255), font=font)
        for c, sp in enumerate(SPECIES):
            f = src / f"{it}-{sp}.png"
            if f.exists():
                sheet.alpha_composite(unpremultiply(Image.open(f)).crop(CROP), (label_w + c * CELL[0], r * CELL[1]))
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
