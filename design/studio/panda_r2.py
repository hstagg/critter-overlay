"""Panda, studio round 2: Harrison kept A (classic) and C (bamboo snack), and
E (brown) as a variant for Rare and up. His note: the walk profile "needs
work and inspiration". From references: a real panda's side has a shoulder
hump, a black saddle over the shoulders running down into the front legs,
black hind legs up into the thighs, a white rump and a stub of a tail; the
cute versions walk with the big head turned to you. These walks try the head
face-on, three-quarter and in a fuller profile.

    python design/studio/panda_r2.py   ->  design/studio/out/panda-r2/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, W, GROUND, EYE, svg, path, ell, line, blush, shadow, render, HERE
from panda_r1 import OPTIONS as R1, front, head, patch_eye, bamboo, PAD

A, C, E = R1['A'], R1['C'], R1['E']


def head_tq(p, hx, hy, rx, ry):
    """Head turned two-thirds to you, looking left."""
    out = ell(hx + rx * 0.62, hy - ry * 0.74, p['ear'], p['ear'], p['black'], 4)
    out += ell(hx - rx * 0.72, hy - ry * 0.7, p['ear'] * 0.78, p['ear'] * 0.78, p['black'], 4)
    out += ell(hx, hy, rx, ry, p['white'], 4)
    mx = hx - rx * 0.3
    prx, pry, rot = p['patch']
    out += patch_eye(hx - rx * 0.62, hy, prx * 0.82, pry * 0.9, rot + 6, p, -1.5)
    out += patch_eye(hx + rx * 0.1, hy - ry * 0.02, prx, pry, -rot, p, -1.5)
    out += ell(mx, hy + ry * 0.42, rx * 0.3, ry * 0.24, p['muzzle'], 0)
    out += path(f'M{mx - 8:.1f} {hy + ry * 0.28:.1f} Q{mx:.1f} {hy + ry * 0.22:.1f} {mx + 8:.1f} {hy + ry * 0.28:.1f} Q{mx + 5:.1f} {hy + ry * 0.42:.1f} {mx:.1f} {hy + ry * 0.44:.1f} Q{mx - 5:.1f} {hy + ry * 0.42:.1f} {mx - 8:.1f} {hy + ry * 0.28:.1f} Z', p['black'], 2)
    out += line(f'M{mx - 7:.1f} {hy + ry * 0.55:.1f} Q{mx:.1f} {hy + ry * 0.64:.1f} {mx + 7:.1f} {hy + ry * 0.55:.1f}', OL, 2.6)
    out += blush(hx + rx * 0.62, hy + ry * 0.36, rx * 0.15, ry * 0.1)
    return out


def head_profile(p, hx, hy, rx, ry):
    """A fuller profile than round 1: round skull, a short soft muzzle,
    the patch a slanted teardrop, one ear up behind."""
    out = ell(hx + rx * 0.38, hy - ry * 0.8, p['ear'], p['ear'], p['black'], 4)
    d = (f'M{hx + rx:.1f} {hy:.1f} C{hx + rx:.1f} {hy - ry * 1.05:.1f} {hx - rx * 0.7:.1f} {hy - ry * 1.15:.1f} {hx - rx * 0.88:.1f} {hy - ry * 0.15:.1f} '
         f'C{hx - rx * 1.2:.1f} {hy - ry * 0.05:.1f} {hx - rx * 1.32:.1f} {hy + ry * 0.35:.1f} {hx - rx * 1.12:.1f} {hy + ry * 0.62:.1f} '
         f'C{hx - rx * 0.9:.1f} {hy + ry * 0.92:.1f} {hx - rx * 0.2:.1f} {hy + ry * 1.0:.1f} {hx + rx * 0.3:.1f} {hy + ry * 0.9:.1f} '
         f'C{hx + rx * 0.9:.1f} {hy + ry * 0.75:.1f} {hx + rx:.1f} {hy + ry * 0.4:.1f} {hx + rx:.1f} {hy:.1f} Z')
    out += path(d, p['white'], 4)
    out += patch_eye(hx - rx * 0.35, hy - ry * 0.05, rx * 0.27, ry * 0.38, -28, p, -2)
    out += ell(hx - rx * 1.2, hy + ry * 0.24, 7.5, 6, p['black'], 2.5)
    out += line(f'M{hx - rx * 1.1:.1f} {hy + ry * 0.55:.1f} Q{hx - rx * 0.95:.1f} {hy + ry * 0.66:.1f} {hx - rx * 0.8:.1f} {hy + ry * 0.56:.1f}', OL, 2.6)
    out += blush(hx + rx * 0.12, hy + ry * 0.42, rx * 0.18, ry * 0.11)
    return out


def leg(x, top, fill):
    """A chunky leg with a rounded paw, toes forward (to -x)."""
    y = GROUND
    d = (f'M{x + 13} {top} L{x + 13} {y - 10} Q{x + 13} {y} {x + 3} {y} L{x - 9} {y} '
         f'Q{x - 19} {y} {x - 17} {y - 9} L{x - 13} {top} Z')
    return path(d, fill, 4) + line(f'M{x - 10} {y - 1} l0 -5 M{x - 3} {y - 1} l0 -5', '#FFFFFF', 1.8, 0.35)


def walk(p):
    out = shadow(176, 102)
    bx, by, brx, bry = p['walk_body']
    blk, dk = p['black'], p['black_dk']
    # far legs, a shade darker
    for lx in (bx - brx * 0.5 + 22, bx + brx * 0.58 + 20):
        out += leg(lx, by, dk)
    out += ell(bx + brx * 0.98, by - bry * 0.5, 11, 10, p['white'], 3.5)     # stub tail
    # the body: a soft hump over the shoulders, a round rump
    body = (f'M{bx - brx:.1f} {by + bry * 0.4:.1f} C{bx - brx * 1.05:.1f} {by - bry * 0.8:.1f} {bx - brx * 0.55:.1f} {by - bry * 1.25:.1f} {bx - brx * 0.1:.1f} {by - bry * 1.12:.1f} '
            f'C{bx + brx * 0.5:.1f} {by - bry * 1.02:.1f} {bx + brx * 1.05:.1f} {by - bry * 0.7:.1f} {bx + brx:.1f} {by + bry * 0.2:.1f} '
            f'C{bx + brx * 0.95:.1f} {by + bry * 1.0:.1f} {bx - brx * 0.8:.1f} {by + bry * 1.05:.1f} {bx - brx:.1f} {by + bry * 0.4:.1f} Z')
    uid = p['uid']
    out += f'<clipPath id="pb{uid}"><path d="{body}"/></clipPath>'
    out += path(body, p['white'], 0)
    band = (f'M{bx - brx * 0.66:.1f} {by - bry * 1.5:.1f} L{bx - brx * 0.08:.1f} {by - bry * 1.5:.1f} '
            f'L{bx - brx * 0.22:.1f} {by + bry * 1.3:.1f} L{bx - brx * 0.95:.1f} {by + bry * 1.3:.1f} Z')
    thigh = f'<ellipse cx="{bx + brx * 0.62:.1f}" cy="{by + bry * 0.42:.1f}" rx="{brx * 0.36:.1f}" ry="{bry * 0.78:.1f}" fill="{blk}"/>'
    out += f'<g clip-path="url(#pb{uid})"><path d="{band}" fill="{blk}"/>{thigh}</g>'
    out += path(body, 'none', 4)
    # near legs, black, on the ground
    for lx in (bx - brx * 0.5, bx + brx * 0.58):
        out += leg(lx, by + bry * 0.4, blk)
    hx, hy, rx, ry = p['walk_head']
    style = p.get('head_style', 'face')
    if style == 'face':
        out += head(p, hx, hy, rx, ry)
    elif style == 'tq':
        out += head_tq(p, hx, hy, rx, ry)
    else:
        out += head_profile(p, hx, hy, rx, ry)
    if p.get('mouth_bamboo'):
        out += f'<g transform="rotate(-70 {hx - rx * 0.1:.1f} {hy + ry * 0.55:.1f})">{bamboo(hx - rx * 0.1, hy + ry * 0.55)}</g>'
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


OPTIONS = {
    '1': dict(A, uid='1', name='Classic, face-on walk', note='A, walking with its big head turned to you.',
              walk_body=(184, 200, 74, 40), walk_head=(112, 132, 56, 47)),
    '2': dict(A, uid='2', head_style='tq', name='Classic, three-quarter walk',
              note='A, head turned partly towards where it is going.',
              walk_body=(184, 200, 74, 40), walk_head=(108, 136, 56, 47)),
    '3': dict(A, uid='3', head_style='profile', name='Classic, full profile',
              note='A redrawn side-on: shoulder hump, saddle, black thighs, soft muzzle.',
              walk_body=(186, 200, 74, 40), walk_head=(96, 150, 46, 40)),
    '4': dict(C, uid='4', mouth_bamboo=True, name='Bamboo, face-on walk',
              note='C, carrying a bamboo sprig as it walks.',
              walk_body=(184, 200, 74, 40), walk_head=(112, 132, 56, 47)),
    '5': dict(A, uid='5', name='Chubby, face-on walk', note='Rounder body and a bigger head.',
              eye_k=1.1, walk_body=(182, 196, 70, 46), walk_head=(108, 124, 62, 52)),
    '6': dict(E, uid='6', name='Brown variant (Rare and up)',
              note='E as you suggested: the same panda in cocoa and cream, only from Rare up.',
              walk_body=(184, 200, 74, 40), walk_head=(112, 132, 56, 47)),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', walk(o))):
            sp = f'{out_dir}/panda-r2-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/panda-r2')
