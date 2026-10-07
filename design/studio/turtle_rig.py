"""Split the approved turtle into rig parts: godot/art/turtle/*.svg.

Approved 2026-10-07: studio round 2, option 1 (classic green, bigger head).
It sits facing you and walks side-on with its head in profile (two heads,
critters/two_head.gd). Parts are drawn in the rig's 300 x 280 frame, facing
left; the studio's 320 x 260 frame (ground 246) is wrapped in translate(2 24).

    python design/studio/turtle_rig.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import OL, path, ell, line, eye
import turtle_r1 as t1
from turtle_r2 import OPTIONS

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'godot', 'art', 'turtle'))
P = OPTIONS['1']
R = P['head_r']


def part(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
            f'<g transform="translate(2 24)">{body}</g></svg>')


def head_no_eyes(hx, hy, side):
    s = t1.head(P, hx, hy, side=side)
    # drop the eye(s): each eye is an ellipse in EYE colour plus two white circles
    import re
    s = re.sub(r'<ellipse[^>]*fill="#2B2330"[^>]*/><circle[^>]*/><circle[^>]*/>', '', s)
    return s


def front_parts():
    cx, base, rx, ry = P['front_shell']
    hx, hy = P['front_head']
    body = t1.shell(P, 'f', cx, base, rx, ry, front=True)
    feet = (t1.foot_stub(cx - rx * 0.62, base + 6, P['skin'], w=32), t1.foot_stub(cx + rx * 0.62, base + 6, P['skin'], w=32))
    neck = path(f'M{hx - R * 0.45} {hy + R * 0.4} L{hx - R * 0.42} {base + 18} L{hx + R * 0.42} {base + 18} L{hx + R * 0.45} {hy + R * 0.4} Z', P['skin'], 4)
    head = neck + head_no_eyes(hx, hy, False)
    e = R * 0.42
    eyes = eye(hx - e, hy - R * 0.05, R * 0.2, R * 0.25) + eye(hx + e, hy - R * 0.05, R * 0.2, R * 0.25)
    closed = line(''.join(f'M{x - R * 0.2:.1f} {hy - R * 0.03:.1f} Q{x:.1f} {hy + R * 0.12:.1f} {x + R * 0.2:.1f} {hy - R * 0.03:.1f} '
                          for x in (hx - e, hx + e)), OL, 3)
    mouth = path(f'M{hx - 8} {hy + R * 0.38:.1f} Q{hx} {hy + R * 0.34:.1f} {hx + 8} {hy + R * 0.38:.1f} '
                 f'Q{hx + 7} {hy + R * 0.62:.1f} {hx} {hy + R * 0.64:.1f} Q{hx - 7} {hy + R * 0.62:.1f} {hx - 8} {hy + R * 0.38:.1f} Z', '#D9776F', 2.6)
    return body, feet, head, eyes, closed, mouth


def side_parts(base_y=None):
    cx, base, rx, ry = P['side_shell']
    hx, hy = P['side_head']
    if base_y is not None:
        base = base_y
    tail = path(f'M{cx + rx - 6} {base + 6} Q{cx + rx + 22} {base + 10} {cx + rx + 26} {base + 20} Q{cx + rx + 8} {base + 22} {cx + rx - 8} {base + 16} Z', P['skin'], 3.5)
    shell = t1.shell(P, 's', cx, base, rx, ry)
    neck = (f'M{cx - rx + 24} {base - 14} C{cx - rx - 6} {base - 22} {hx + R * 0.9} {hy - R * 0.3} {hx + R * 0.5} {hy - R * 0.2} '
            f'L{hx + R * 0.3} {hy + R * 0.75} C{hx + R * 0.8} {base + 12} {cx - rx} {base + 16} {cx - rx + 24} {base + 14} Z')
    head = path(neck, P['skin'], 4) + head_no_eyes(hx, hy, True)
    ex, ey = hx - R * 0.28, hy - R * 0.08
    eye_open = eye(ex, ey, R * 0.2, R * 0.25)
    eye_shut = line(f'M{ex - R * 0.2:.1f} {ey + 1:.1f} Q{ex:.1f} {ey + R * 0.16:.1f} {ex + R * 0.2:.1f} {ey + 1:.1f}', OL, 3)
    legs = {
        'leg-front': t1.foot_stub(cx - rx * 0.62, base + 4, P['skin']),
        'leg-back': t1.foot_stub(cx + rx * 0.62, base + 4, P['skin']),
        'leg-front-far': t1.foot_stub(cx - rx * 0.62 + 14, base, P['skin_dk']),
        'leg-back-far': t1.foot_stub(cx + rx * 0.62 + 12, base, P['skin_dk']),
    }
    return tail + shell, head, eye_open, eye_shut, legs


def build():
    os.makedirs(OUT, exist_ok=True)
    body, (fl, fr), head, eyes, closed, mouth = front_parts()
    walk_body, head_side, eye_open, eye_shut, legs = side_parts()
    loaf_body, _, _, _, _ = side_parts(base_y=P['side_shell'][1] + 26)   # resting on its plastron
    parts = {'body': body, 'foot-l': fl, 'foot-r': fr, 'head': head, 'eyes': eyes, 'eyes-closed': closed,
             'mouth-open': mouth, 'walk-body': walk_body, 'head-side': head_side, 'eye-side': eye_open,
             'eye-side-closed': eye_shut, 'loaf-body': loaf_body, **legs}
    for k, v in parts.items():
        with open(os.path.join(OUT, k + '.svg'), 'w') as fh:
            fh.write(part(v))
    print(len(parts), 'parts ->', OUT)


if __name__ == '__main__':
    build()
