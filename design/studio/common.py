"""Shared drawing kit for the cast design studio.

Every option is drawn as one still illustration in a 320 x 260 frame, in the
same units as the rig parts (the kitten's head is 184 wide), feet on y = 246.
At real size one unit is about 0.42 px, so a critter here lands near 88 px.
"""
import math
import os
import random
import subprocess

OL = '#6B4A3A'          # style A outline
EYE = '#2B2330'
BLUSH = '#F59C9C'
CREAM = '#FCEBD5'
CREAM_SH = '#EFD3B4'
EAR_IN = '#F4B3AA'
NOSE = '#3B2A2C'
W, H = 320, 260
GROUND = 246

HERE = os.path.dirname(os.path.abspath(__file__)).replace('\\', '/')
GODOT = 'godot_console'


def svg(body, w=W, h=H):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
            f'width="{w}" height="{h}">{body}</svg>')


def path(d, fill, sw=4.0, extra=''):
    stroke = f'stroke="{OL}" stroke-width="{sw}" ' if sw else ''
    return (f'<path d="{d}" fill="{fill}" {stroke}stroke-linejoin="round" '
            f'stroke-linecap="round" {extra}/>')


def ell(cx, cy, rx, ry, fill, sw=4.0, extra=''):
    stroke = f'stroke="{OL}" stroke-width="{sw}" ' if sw else ''
    return f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}" {stroke}{extra}/>'


def line(d, color=OL, sw=3.0, op=1.0):
    return (f'<path d="{d}" stroke="{color}" stroke-width="{sw}" fill="none" '
            f'stroke-linecap="round" stroke-linejoin="round" opacity="{op}"/>')


def egg(cx, cy, rx, ry, back=0.0, top=0.0):
    """An outline function f(angle, k): an ellipse that can swell at the back
    (+x side) and flatten or lift the top."""
    def f(a, k=1.0):
        t = math.radians(a)
        c, s = math.cos(t), math.sin(t)
        sx = rx * (1 + back * c)
        sy = ry * (1 + (top * -s if s < 0 else 0))
        return (cx + sx * k * c, cy + sy * k * s)
    return f


def tufts(f, a0, a1, n, depth=0.09, tip=1.07, lean=6.0, jit=0.0, seed=1, puff=0.035):
    """A fuzzy run of quill tufts along outline f from angle a0 to a1.

    lean is degrees the tip is pushed along the run (+ sweeps towards a1);
    a callable lean(a) lets a front view sweep both ways from the crown.
    Returns the path data from the first base point, ending at the last.
    """
    rnd = random.Random(seed)
    step = (a1 - a0) / n
    lf = lean if callable(lean) else (lambda a, v=lean: v)
    d = 'M%.1f %.1f' % f(a0, 1 - depth)
    for i in range(n):
        a = a0 + step * i
        ln = lf(a + step / 2)
        tk = tip + rnd.uniform(-jit, jit)
        mid = (1 - depth + tk) / 2
        tp = f(a + step * 0.5 + ln, tk)
        c1 = f(a + step * 0.15 + ln * 0.5, mid + puff)
        c2 = f(a + step * 0.95 + ln * 0.35, mid + puff * 0.4)
        b = f(a + step, 1 - depth)
        d += ' Q %.1f %.1f %.1f %.1f Q %.1f %.1f %.1f %.1f' % (c1 + tp + c2 + b)
    return d


def strokes(f, a0, a1, rows, per, lean=8.0, length=0.1, seed=3, light='#E0B48C',
            dark='#734630', sw=2.4, every=3):
    """Rows of short quill strokes inside a coat, light and dark."""
    rnd = random.Random(seed)
    lf = lean if callable(lean) else (lambda a, v=lean: v)
    lt, dk = '', ''
    for j, r in enumerate(rows):
        n = max(3, int(per * r))
        for i in range(n):
            a = a0 + (a1 - a0) * (i + 0.5 * (j % 2) + 0.25) / n
            if a > a1:
                continue
            a += rnd.uniform(-2, 2)
            p0 = f(a, r - length / 2)
            p1 = f(a + lf(a) * 0.8, r + length / 2)
            seg = 'M%.1f %.1f L%.1f %.1f ' % (p0 + p1)
            if (i + j) % every == 0:
                dk += seg
            else:
                lt += seg
    out = ''
    if dk:
        out += line(dk, dark, sw, 0.55)
    if lt:
        out += line(lt, light, sw + 0.2, 0.85)
    return out


def eye(cx, cy, rx, ry, look=0.0):
    """Style A eye: dark oval, a big shine up and back, a small one low."""
    return (ell(cx, cy, rx, ry, EYE, 0)
            + f'<circle cx="{cx - rx * 0.38 + look:.1f}" cy="{cy - ry * 0.42:.1f}" r="{rx * 0.42:.1f}" fill="#FFFFFF"/>'
            + f'<circle cx="{cx + rx * 0.4 + look:.1f}" cy="{cy + ry * 0.38:.1f}" r="{rx * 0.19:.1f}" fill="#FFFFFF"/>')


def blush(cx, cy, rx=13, ry=7):
    return ell(cx, cy, rx, ry, BLUSH, 0, 'opacity="0.55"')


def nose(cx, cy, rx=8, ry=6):
    return (ell(cx, cy, rx, ry, NOSE, 2.5)
            + f'<ellipse cx="{cx - rx * 0.3:.1f}" cy="{cy - ry * 0.35:.1f}" rx="{rx * 0.35:.1f}" ry="{ry * 0.25:.1f}" fill="#FFFFFF" opacity="0.8"/>')


def foot(cx, cy, rx=14, ry=8, fill=CREAM, toes=True):
    t = ''
    if toes:
        t = line('M%.1f %.1f l0 %.1f M%.1f %.1f l0 %.1f' % (
            cx - rx * 0.3, cy + ry * 0.1, ry * 0.6, cx + rx * 0.3, cy + ry * 0.1, ry * 0.6), OL, 2, 0.6)
    return ell(cx, cy, rx, ry, fill, 3.5) + t


def shadow(cx, w):
    return ell(cx, GROUND + 2, w, 7, '#000000', 0, 'opacity="0.07"')


def render(pairs, scale=2.0):
    """Rasterise [(svg_path, png_path)] with Godot, headless."""
    lst = HERE + '/_render_list.txt'
    with open(lst, 'w') as fh:
        for a, b in pairs:
            fh.write(f'{a}|{b}\n')
    subprocess.run([GODOT, '--headless', '-s', HERE + '/render.gd', '--', lst, str(scale)],
                   check=True, capture_output=True)
    os.remove(lst)
