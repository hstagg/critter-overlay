"""Turtle, studio round 1: six takes, each a front view and a side view.

The turtle's own things: a domed shell it tucks into (its special), a slow
plod (v2.0), stubby elephant feet, a head on a neck that pokes out of the
shell. Options vary shell height and pattern, head size and kind of turtle.

    python design/studio/turtle_r1.py   ->  design/studio/out/turtle-r1/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (OL, W, GROUND, svg, path, ell, line, eye, blush, shadow, render, HERE)


def hexa(cx, cy, w, h, fill, stroke):
    """A rounded hexagonal scute."""
    d = (f'M{cx - w / 2:.1f} {cy:.1f} L{cx - w / 4:.1f} {cy - h / 2:.1f} L{cx + w / 4:.1f} {cy - h / 2:.1f} '
         f'L{cx + w / 2:.1f} {cy:.1f} L{cx + w / 4:.1f} {cy + h / 2:.1f} L{cx - w / 4:.1f} {cy + h / 2:.1f} Z')
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="3" stroke-linejoin="round"/>'


def rings(cx, cy, w, h, stroke):
    """Growth rings inside a scute (tortoise)."""
    out = ''
    for k in (0.62, 0.3):
        out += hexa(cx, cy, w * k, h * k, 'none', stroke).replace('stroke-width="3"', 'stroke-width="2" opacity="0.55"')
    return out


def scutes(p, cx, base, rx, ry, front=False):
    s = ''
    sc, ln = p['scute'], p['line']
    if front:
        rows = [(0, -0.62, 0.42, 0.42), (-0.62, -0.28, 0.4, 0.44), (0.62, -0.28, 0.4, 0.44),
                (0, -0.18, 0.38, 0.34)]
    else:
        rows = [(-0.42, -0.74, 0.4, 0.38), (0.0, -0.8, 0.4, 0.38), (0.42, -0.74, 0.4, 0.38),
                (-0.74, -0.3, 0.36, 0.44), (-0.26, -0.32, 0.42, 0.46), (0.26, -0.32, 0.42, 0.46),
                (0.74, -0.3, 0.36, 0.44)]
    for dx, dy, w, h in rows:
        x, y = cx + dx * rx, base + dy * ry
        s += hexa(x, y, w * rx, h * ry, sc, ln)
        if p['pattern'] == 'rings':
            s += rings(x, y, w * rx, h * ry, ln)
        elif p['pattern'] == 'spots':
            s += (f'<path d="M{x:.1f} {y:.1f} l-6 -8 M{x:.1f} {y:.1f} l7 -7 M{x:.1f} {y:.1f} l1 10" '
                  f'stroke="{p["spot"]}" stroke-width="3.2" stroke-linecap="round"/>')
    return s


def shell(p, uid, cx, base, rx, ry, front=False):
    dome = f'M{cx - rx} {base} A{rx} {ry} 0 0 1 {cx + rx} {base} Z'
    out = f'<clipPath id="c{uid}"><path d="{dome}"/></clipPath>'
    out += path(dome, p['shell'], 4.5)
    out += f'<g clip-path="url(#c{uid})">{scutes(p, cx, base, rx, ry, front)}</g>'
    # a soft shine on the dome
    out += (f'<path d="M{cx - rx * 0.55:.1f} {base - ry * 0.55:.1f} Q{cx - rx * 0.3:.1f} {base - ry * 0.92:.1f} '
            f'{cx + rx * 0.05:.1f} {base - ry * 0.93:.1f}" stroke="#FFFFFF" stroke-width="6" '
            f'stroke-linecap="round" fill="none" opacity="0.35"/>')
    out += path(dome, 'none', 4.5)
    # the rim, with its marginal scutes
    rh = p['rim_h']
    rim = (f'M{cx - rx - 6} {base - 4} Q{cx} {base + 6} {cx + rx + 6} {base - 4} '
           f'Q{cx + rx + 10} {base + rh / 2} {cx + rx + 2} {base + rh} Q{cx} {base + rh + 8} {cx - rx - 2} {base + rh} '
           f'Q{cx - rx - 10} {base + rh / 2} {cx - rx - 6} {base - 4} Z')
    out += path(rim, p['rim'], 4)
    n = 7 if not front else 6
    marks = ''
    for i in range(1, n):
        x = cx - rx + 2 * rx * i / n
        marks += f'M{x:.1f} {base + 1:.1f} l0 {rh - 2:.1f} '
    out += line(marks, p['line'], 2.5, 0.6)
    if p.get('sprout'):
        sx, sy = cx - rx * 0.1, base - ry - 2
        out += line(f'M{sx} {sy + 6} q2 -14 -2 -22', '#5F8F3E', 4)
        out += path(f'M{sx - 2} {sy - 14} q-22 -10 -26 4 q14 8 26 -4 Z', '#9ED36A', 3)
        out += path(f'M{sx - 1} {sy - 16} q18 -16 26 -4 q-12 12 -26 4 Z', '#B5E07E', 3)
    return out


def foot_stub(x, top, fill, front=True, w=30):
    """An elephant-foot leg from under the rim to the ground, toes forward."""
    y = GROUND
    d = (f'M{x - w / 2} {top} L{x - w / 2 - 2} {y - 8} Q{x - w / 2 - 3} {y} {x - w / 2 + 6} {y} '
         f'L{x + w / 2 - 4} {y} Q{x + w / 2 + 3} {y} {x + w / 2 + 1} {y - 8} L{x + w / 2} {top} Z')
    out = path(d, fill, 4)
    nails = ' '.join(f'M{x - w / 2 + 6 + i * (w - 10) / 2:.1f} {y - 2} l0 -5' for i in range(3))
    out += line(nails, OL, 2.2, 0.55)
    return out


def head(p, hx, hy, side=False):
    r = p['head_r']
    out = ell(hx, hy, r * (1.08 if side else 1.0), r * 0.92, p['skin'], 4)
    if p.get('cheeks', True):
        out += ell(hx + (r * 0.3 if side else 0), hy + r * 0.42, r * 0.55, r * 0.32, p['skin_lt'], 0, 'opacity="0.9"')
    if side:
        out += eye(hx - r * 0.28, hy - r * 0.08, r * 0.2, r * 0.25)
        out += blush(hx + r * 0.02, hy + r * 0.32, r * 0.2, r * 0.11)
        out += f'<circle cx="{hx - r * 0.98:.1f}" cy="{hy - r * 0.1:.1f}" r="2.2" fill="{OL}"/>'
        out += line(f'M{hx - r * 0.95:.1f} {hy + r * 0.28:.1f} Q{hx - r * 0.7:.1f} {hy + r * 0.42:.1f} {hx - r * 0.45:.1f} {hy + r * 0.3:.1f}', OL, 2.8)
    else:
        e = r * 0.42
        out += eye(hx - e, hy - r * 0.05, r * 0.2, r * 0.25) + eye(hx + e, hy - r * 0.05, r * 0.2, r * 0.25)
        out += blush(hx - r * 0.66, hy + r * 0.3, r * 0.2, r * 0.11) + blush(hx + r * 0.66, hy + r * 0.3, r * 0.2, r * 0.11)
        out += f'<circle cx="{hx - 4}" cy="{hy + r * 0.18:.1f}" r="2" fill="{OL}"/><circle cx="{hx + 4}" cy="{hy + r * 0.18:.1f}" r="2" fill="{OL}"/>'
        out += line(f'M{hx - r * 0.22:.1f} {hy + r * 0.38:.1f} Q{hx:.1f} {hy + r * 0.56:.1f} {hx + r * 0.22:.1f} {hy + r * 0.38:.1f}', OL, 2.8)
    if p.get('head_spots'):
        out += f'<circle cx="{hx + r * 0.35:.1f}" cy="{hy - r * 0.6:.1f}" r="4" fill="{p["spot"]}"/><circle cx="{hx + r * 0.6:.1f}" cy="{hy - r * 0.35:.1f}" r="3" fill="{p["spot"]}"/>'
    return out


def side(p):
    cx, base, rx, ry = p['side_shell']
    out = shadow(cx - 6, rx + 14)
    # far legs, a shade darker
    out += foot_stub(cx - rx * 0.62 + 14, base, p['skin_dk'])
    out += foot_stub(cx + rx * 0.62 + 12, base, p['skin_dk'])
    # tail
    out += path(f'M{cx + rx - 6} {base + 6} Q{cx + rx + 22} {base + 10} {cx + rx + 26} {base + 20} Q{cx + rx + 8} {base + 22} {cx + rx - 8} {base + 16} Z', p['skin'], 3.5)
    # neck and head
    hx, hy = p['side_head']
    r = p['head_r']
    neck = (f'M{cx - rx + 24} {base - 14} C{cx - rx - 6} {base - 22} {hx + r * 0.9} {hy - r * 0.3} {hx + r * 0.5} {hy - r * 0.2} '
            f'L{hx + r * 0.3} {hy + r * 0.75} C{hx + r * 0.8} {base + 12} {cx - rx} {base + 16} {cx - rx + 24} {base + 14} Z')
    # near legs, then the shell over the leg tops, then the neck and head poking out
    out += foot_stub(cx - rx * 0.62, base + 4, p['skin'])
    out += foot_stub(cx + rx * 0.62, base + 4, p['skin'])
    out += shell(p, 's', cx, base, rx, ry)
    out += path(neck, p['skin'], 4)
    out += head(p, hx, hy, side=True)
    return svg(f'<g transform="translate({W} 0) scale(-1 1)">{out}</g>')


def front(p):
    cx, base, rx, ry = p['front_shell']
    out = shadow(cx, rx + 4)
    out += shell(p, 'f', cx, base, rx, ry, front=True)
    out += foot_stub(cx - rx * 0.62, base + 6, p['skin'], w=32)
    out += foot_stub(cx + rx * 0.62, base + 6, p['skin'], w=32)
    hx, hy = p['front_head']
    r = p['head_r']
    out += path(f'M{hx - r * 0.45} {hy + r * 0.4} L{hx - r * 0.42} {base + 18} L{hx + r * 0.42} {base + 18} L{hx + r * 0.45} {hy + r * 0.4} Z', p['skin'], 4)
    out += head(p, hx, hy)
    return svg(out)


GREEN = dict(shell='#6FA65A', scute='#8CC46C', line='#4F7F3E', rim='#E9DDA2', skin='#A9D99B',
             skin_lt='#CDEBC2', skin_dk='#8DC27E', spot='#F3E28C', pattern='hex')
BROWN = dict(shell='#A1724A', scute='#C49660', line='#7A5236', rim='#E7D2A6', skin='#D6C08F',
             skin_lt='#EADCB6', skin_dk='#BFA676', spot='#F2D27A', pattern='rings')

OPTIONS = {
    'A': dict(GREEN, name='Classic green', note='High green dome with hex scutes, mint skin, round baby head.',
              side_shell=(176, 196, 96, 92), side_head=(58, 166), front_shell=(160, 196, 108, 104),
              front_head=(160, 168), head_r=46, rim_h=16),
    'B': dict(BROWN, name='Tortoise', note='Tall brown dome with growth rings, tan skin, sturdier feet.',
              side_shell=(178, 194, 94, 104), side_head=(60, 170), front_shell=(160, 194, 104, 112),
              front_head=(160, 172), head_r=42, rim_h=14),
    'C': dict(GREEN, shell='#B5703C', scute='#D88E4C', line='#7F4A26', rim='#F2D08A', skin='#9FB78A',
              skin_lt='#C9D8B6', skin_dk='#879F74', spot='#FFD45E', pattern='spots', head_spots=True,
              name='Box turtle', note='Orange-brown dome with sunny streaks, freckles on its head.',
              side_shell=(176, 196, 94, 96), side_head=(58, 168), front_shell=(160, 196, 106, 106),
              front_head=(160, 170), head_r=44, rim_h=15),
    'D': dict(GREEN, name='Big-head hatchling', note='Small shell, very big head: the most chibi.',
              shell='#79B465', scute='#9BD078', side_shell=(186, 204, 80, 76), side_head=(66, 150),
              front_shell=(160, 210, 96, 80), front_head=(160, 150), head_r=56, rim_h=14),
    'E': dict(GREEN, name='Flat and wide', note='Low, wide pancake shell; a long reach of neck.',
              shell='#5F9C6E', scute='#7DBA8A', line='#456F50', skin='#B6DDB0', skin_lt='#D7EED2',
              skin_dk='#98C792', side_shell=(180, 204, 112, 66), side_head=(50, 178),
              front_shell=(160, 206, 124, 72), front_head=(160, 182), head_r=42, rim_h=14),
    'F': dict(GREEN, name='Mossy sprout', note='Classic shape with a little sprout growing on top.',
              sprout=True, shell='#6E9F58', scute='#93C46F', side_shell=(176, 198, 92, 88),
              side_head=(60, 168), front_shell=(160, 198, 104, 98), front_head=(160, 170),
              head_r=46, rim_h=15),
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pairs = []
    for key, o in OPTIONS.items():
        for view, s in (('front', front(o)), ('side', side(o))):
            sp = f'{out_dir}/turtle-r1-{key}-{view}.svg'
            with open(sp, 'w') as fh:
                fh.write(s)
            pairs.append((sp, sp[:-4] + '.png'))
    render(pairs, 1.0)


if __name__ == '__main__':
    build(HERE + '/out/turtle-r1')
