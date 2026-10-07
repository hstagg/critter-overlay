"""Grab each behaviour of a species from the game and lay the frames out as a
contact sheet, one row per behaviour.

    python design/studio/clips.py SPECIES OUT_DIR [behaviour ...]
"""
import glob
import os
import subprocess
import sys

from PIL import Image, ImageDraw

GODOT_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'godot'))
DEFAULT = ['walk', 'sit', 'loaf', 'stretch', 'yawn', 'groom', 'scratch', 'sneeze', 'shake_off',
           'listen', 'ear_flick', 'wake_up', 'look_at_cursor']


def grab(species, b, out, frames=8, fps=4):
    d = os.path.join(out, b)
    os.makedirs(d, exist_ok=True)
    for f in glob.glob(d + '/*.png'):
        os.remove(f)
    subprocess.run(['godot_console', '--path', GODOT_DIR, '--', f'--species={species}', f'--demo={b}',
                    '--zoom=2', '--no-passthrough', f'--seconds={1.2 + frames / fps + 0.5}',
                    f'--grab={d}/f%d.png', '--grab-start=1.0', f'--grab-frames={frames}', f'--grab-fps={fps}'],
                   capture_output=True)
    return [Image.open(f'{d}/f{i}.png').convert('RGBA') for i in range(frames) if os.path.exists(f'{d}/f{i}.png')]


def sheet(rows, path, cell=(240, 200)):
    W = max(len(r[1]) for r in rows) * cell[0] + 120
    s = Image.new('RGBA', (W, len(rows) * cell[1]), (243, 230, 214, 255))
    dr = ImageDraw.Draw(s)
    for j, (name, ims) in enumerate(rows):
        dr.text((6, j * cell[1] + 6), name, fill=(80, 60, 50, 255))
        for i, im in enumerate(ims):
            bb = im.getbbox() or (0, 0, im.width, im.height)
            # keep the feet line: crop a fixed window around the critter's centre
            cx = (bb[0] + bb[2]) // 2
            c = im.crop((cx - 120, 160, cx + 120, 360)).resize(cell)
            s.alpha_composite(c, (120 + i * cell[0], j * cell[1]))
    s.save(path)


if __name__ == '__main__':
    sp, out = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or DEFAULT
    rows = [(b, grab(sp, b, out)) for b in names]
    sheet(rows, os.path.join(out, f'_{sp}.png'))
    print('sheet', os.path.join(out, f'_{sp}.png'))
