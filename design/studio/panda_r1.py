"""Panda, studio round 1: six takes, each a front view and a side view.

The panda's own things: a chubby round body, black legs and shoulder band,
black ears and eye patches, a lumbering walk and a roll (v2.0). Sitting, it
shows its pink paw pads. Options vary patch shape, head size, colour and
what it holds.

    python design/studio/panda_r1.py   ->  design/studio/out/panda-r1/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (OL, W, GROUND, EYE, svg, path, ell, line, egg, tufts, blush, shadow, render, HERE)

PAD = '#F4A9A8'


def blob(cx, cy, rx, ry, fill, p, sw=4.0, seed=1):
    """An ellipse, or a fluffy one when the option asks for fluff."""
    if p.get('fluffy'):
        f = egg(cx, cy, rx, ry)
        return path(tufts(f, 0, 360, max(14, int((rx + ry) / 5)), 0.05, 1.04, 4, 0.01, seed, 0.03) + ' Z', fill, sw)
    return ell(cx, cy, rx, ry, fill, sw)


def patch_eye(cx, cy, rx, ry, rot, p, look=0.0):
    """A black eye patch with a sparkly eye inside it."""
    out = f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" transform="rotate({rot:.1f} {cx:.1f} {cy:.1f})" fill="{p["black"]}"/>'
    er = min(rx, ry) * 0.62 * p.get('eye_k', 1.0)
    ex, ey = cx + look, cy - ry * 0.08
    out += f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="{er + 2.2:.1f}" fill="#FFFFFF" opacity="0.92"/>'
    out += f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="{er:.1f}" fill="{EYE}"/>'
    out += f'<circle cx="{ex - er * 0.35:.1f}" cy="{ey - er * 0.38:.1f}" r="{er * 0.42:.1f}" fill="#FFFFFF"/>'
    out += f'<circle cx="{ex + er * 0.4:.1f}" cy="{ey + er * 0.36:.1f}" r="{er * 0.18:.1f}" fill="#FFFFFF"/>'
    return out


def bamboo(x, y):
    out = path(f'M{x - 5} {y + 40} L{x - 5} {y - 44} Q{x} {y - 48} {x + 5} {y - 44} L{x + 5} {y + 40} Z', '#9CCB6B', 3)
    out += line(f'M{x - 5} {y - 14} l10 0 M{x - 5} {y + 14} l10 0', '#6E9F45', 2.5)
    out += path(f'M{x + 4} {y - 30} q22 -16 34 -6 q-16 12 -34 6 Z', '#A9D873', 3)
    out += path(f'M{x - 4} {y - 38} q-20 -18 -32 -8 q14 14 32 8 Z', '#B8E082', 3)
    return out


def head(p, hx, hy, rx, ry, side=False):
    out = ''
    if side:
        out += ell(hx + rx * 0.35, hy - ry * 0.78, p['ear'], p['ear'], p['black'], 4)
        out += blob(hx, hy, rx, ry, p['white'], p, 4, 3)
        out += ell(hx - rx * 0.78, hy + ry * 0.3, rx * 0.42, ry * 0.36, p['white'], 3.5)
        out += patch_eye(hx - rx * 0.3, hy - ry * 0.02, rx * 0.26, ry * 0.36, -25, p, -1.5)
        out += ell(hx - rx * 1.14, hy + ry * 0.2, 7, 5.5, p['black'], 2.5)
        out += line(f'M{hx - rx * 1.05:.1f} {hy + ry * 0.48:.1f} Q{hx - rx * 0.92:.1f} {hy + ry * 0.58:.1f} {hx - rx * 0.78:.1f} {hy + ry * 0.48:.1f}', OL, 2.6)
        out += blush(hx + rx * 0.08, hy + ry * 0.42, rx * 0.17, ry * 0.11)
        return out
    for s in (-1, 1):
        out += ell(hx + s * rx * 0.8, hy - ry * 0.78, p['ear'], p['ear'], p['black'], 4)
    out += blob(hx, hy, rx, ry, p['white'], p, 4, 3)
    d = rx * p.get('patch_dx', 0.4)
    prx, pry, rot = p['patch']
    out += patch_eye(hx - d, hy - ry * 0.02, prx, pry, rot, p) + patch_eye(hx + d, hy - ry * 0.02, prx, pry, -rot, p)
    out += ell(hx, hy + ry * 0.4, rx * 0.3, ry * 0.24, p['muzzle'], 0)
    out += path(f'M{hx - 8} {hy + ry * 0.26:.1f} Q{hx} {hy + ry * 0.2:.1f} {hx + 8} {hy + ry * 0.26:.1f} Q{hx + 5} {hy + ry * 0.4:.1f} {hx} {hy + ry * 0.42:.1f} Q{hx - 5} {hy + ry * 0.4:.1f} {hx - 8} {hy + ry * 0.26:.1f} Z', p['black'], 2)
    out += line(f'M{hx - 8} {hy + ry * 0.52:.1f} Q{hx - 4} {hy + ry * 0.6:.1f} {hx} {hy + ry * 0.52:.1f} Q{hx + 4} {hy + ry * 0.6:.1f} {hx + 8} {hy + ry * 0.52:.1f}', OL, 2.6)
    out += blush(hx - rx * 0.68, hy + ry * 0.36, rx * 0.15, ry * 0.1) + blush(hx + rx * 0.68, hy + ry * 0.36, rx * 0.15, ry * 0.1)
    return out


def front(p):
    out = shadow(160, 86)
    bx, by, brx, bry = p['body']
    out += ell(bx, by - bry * 0.62, brx * 0.98, bry * 0.42, p['black'], 4)     # shoulder band
    out += blob(bx, by, brx, bry, p['white'], p, 4, 7)
    # hind legs sticking forward, pink pads to you
    for s in (-1, 1):
        lx = bx + s * brx * 0.62
        out += ell(lx, GROUND - 20, 24, 21, p['black'], 4)
        out += ell(lx, GROUND - 18, 11, 10, PAD, 0)
        for i in (-1, 0, 1):
            out += f'<circle cx="{lx + i * 9:.1f}" cy="{GROUND - 33:.1f}" r="3.4" fill="{PAD}"/>'
    # arms down the front
    for s in (-1, 1):
        ax = bx + s * brx * 0.6
        out += (f'<ellipse cx="{ax:.1f}" cy="{by - bry * 0.1:.1f}" rx="{brx * 0.26:.1f}" ry="{bry * 0.55:.1f}" '
                f'transform="rotate({-s * 18} {ax:.1f} {by - bry * 0.1:.1f})" fill="{p["black"]}" stroke="{OL}" stroke-width="4"/>')
    hx, hy, rx, ry = p['head']
    out += head(p, hx, hy, rx, ry)
    if p.get('bamboo'):
        out += bamboo(bx + brx * 0.86, by - bry * 0.42)
        out += ell(bx + brx * 0.8, by - bry * 0.05, 14, 12, p['black'], 3.5)
    return svg(out)


def side(p):
    out = shadow(170, 104)
    bx, by, brx, bry = p['side_body']
    # far legs
    for lx in (bx - brx * 0.55 + 14, bx + brx * 0.55 + 14):
        out += path(f'M{lx - 14} {by} L{lx - 15} {GROUND - 8} Q{lx - 15} {GROUND} {lx - 6} {GROUND} L{lx + 12} {GROUND} Q{lx + 16} {GROUND} {lx + 15} {GROUND - 8} L{lx + 14} {by} Z', p['black_dk'], 3.5)
    out += ell(bx + brx * 0.98, by - bry * 0.45, 11, 10, p['white'], 3.5)                  # tail
    out += blob(bx, by, brx, bry, p['white'], p, 4, 9)
    # shoulder band down into the front leg
    sx = bx - brx * 0.45
    out += path(f'M{sx - 22:.1f} {by - bry * 0.96:.1f} Q{sx + 4:.1f} {by - bry * 1.02:.1f} {sx + 24:.1f} {by - bry * 0.86:.1f} '
                f'Q{sx + 30:.1f} {by:.1f} {sx + 14:.1f} {by + bry * 0.9:.1f} L{sx - 26:.1f} {by + bry * 0.9:.1f} Q{sx - 34:.1f} {by:.1f} {sx - 22:.1f} {by - bry * 0.96:.1f} Z', p['black'], 4)
    for lx in (bx - brx * 0.55, bx + brx * 0.55):
        out += path(f'M{lx - 15} {by + bry * 0.3} L{lx - 16} {GROUND - 8} Q{lx - 16} {GROUND} {lx - 7} {GROUND} L{lx + 12} {GROUND} Q{lx + 17} {GROUND} {lx + 16} {GROUND - 8} L{lx + 15} {by + bry * 0.3} Z', p['black'], 4)
    hx, hy, rx, ry = p['side_head']
    out += head(p, hx, hy, rx, ry, side=True)
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


BASE = dict(white='#FFFDF8', black='#3B3437', black_dk='#2E282B', muzzle='#F5EFE6', ear=22,
            patch=(17, 24, 35))

OPTIONS = {
    'A': dict(BASE, name='Classic', note='Teardrop patches, round head, pink paw pads.',
              body=(160, 190, 64, 52), head=(160, 106, 70, 58),
              side_body=(178, 188, 74, 46), side_head=(88, 140, 52, 46)),
    'B': dict(BASE, name='Round patches', note='Big round patches for a softer, sleepier look.',
              patch=(21, 21, 0), patch_dx=0.42,
              body=(160, 190, 64, 52), head=(160, 106, 70, 58),
              side_body=(178, 188, 74, 46), side_head=(88, 140, 52, 46)),
    'C': dict(BASE, name='Bamboo snack', note='Classic, with a bamboo stalk in one paw.', bamboo=True,
              body=(156, 190, 64, 52), head=(156, 106, 70, 58),
              side_body=(178, 188, 74, 46), side_head=(88, 140, 52, 46)),
    'D': dict(BASE, name='Chibi', note='Huge head, little body; patches tilted way down.',
              patch=(19, 26, 40), eye_k=1.15, ear=24,
              body=(160, 204, 50, 40), head=(160, 108, 82, 66),
              side_body=(182, 196, 60, 38), side_head=(92, 132, 62, 54)),
    'E': dict(BASE, white='#FBF4E8', black='#7A5A45', black_dk='#664A39', muzzle='#F3E6D2',
              name='Brown panda', note='The rare Qinling colouring: cocoa brown and cream.',
              body=(160, 190, 64, 52), head=(160, 106, 70, 58),
              side_body=(178, 188, 74, 46), side_head=(88, 140, 52, 46)),
    'F': dict(BASE, name='Fluffy', note='Fuzzy outline all round, like a plush toy.', fluffy=True,
              body=(160, 190, 66, 54), head=(160, 106, 72, 60),
              side_body=(178, 188, 76, 48), side_head=(88, 140, 54, 48)),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', side(o))):
            sp = f'{out_dir}/panda-r1-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/panda-r1')
