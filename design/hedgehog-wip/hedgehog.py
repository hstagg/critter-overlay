"""Design the hedgehog as one illustration, then render it large to check.

Pieces are functions so the same shapes can be split into rig parts.
Always on four legs. Quills are many and dense, so the coat reads almost
fluffy: a fuzzy outline of small quills and rows of quill strokes inside.
"""
import math
import os
import random
import subprocess

D = os.path.dirname(os.path.abspath(__file__)).replace('\\', '/')
O = 'stroke="#6B4A3A"'
Q_DARK = '#86563B'
Q = '#A66F4C'
Q_LIGHT = '#E0B48C'
Q_LINE = '#734630'
CR = '#FCE8CF'
CR_SH = '#EED2B2'
EYE = '#2B2330'
PINK = '#F7A9A2'


def pt(cx, cy, rx, ry, a, k=1.0):
    a = math.radians(a)
    return (cx + rx * k * math.cos(a), cy + ry * k * math.sin(a))


def fuzz(cx, cy, rx, ry, a0, a1, n, lean=10.0, depth=0.07, tip=1.05, close=None):
    """A fuzzy outline of many small quills, tips leaning back (towards a1)."""
    step = (a1 - a0) / n
    d = 'M%.1f %.1f' % pt(cx, cy, rx, ry, a0, 1 - depth)
    for i in range(n):
        a = a0 + step * i
        t = pt(cx, cy, rx, ry, a + step * 0.55 + lean, tip)
        v = pt(cx, cy, rx, ry, a + step, 1 - depth)
        c = pt(cx, cy, rx, ry, a + step * 0.9 + lean * 0.4, 1.0)
        d += ' L %.1f %.1f Q %.1f %.1f %.1f %.1f' % (t + c + v)
    if close:
        d += ' ' + close
    return d + ' Z'


def texture(cx, cy, rx, ry, a0, a1, rows=(0.42, 0.52, 0.62, 0.72, 0.82, 0.91), per=30, lean=10.0, seed=3):
    """Rows of short quill strokes inside the coat, light and dark."""
    rnd = random.Random(seed)
    light, dark = '', ''
    for j, r in enumerate(rows):
        n = int(per * r)
        for i in range(n):
            a = a0 + (a1 - a0) * (i + 0.5 * (j % 2) + 0.25) / n
            if a > a1:
                continue
            a += rnd.uniform(-2, 2)
            p0 = pt(cx, cy, rx, ry, a, r - 0.04)
            p1 = pt(cx, cy, rx, ry, a + lean * 0.8, r + 0.05)
            seg = 'M%.1f %.1f L%.1f %.1f ' % (p0 + p1)
            if (i + j) % 3 == 0:
                dark += seg
            else:
                light += seg
    return (f'<path d="{dark}" stroke="{Q_LINE}" stroke-width="2.4" stroke-linecap="round" fill="none" opacity="0.55"/>'
            f'<path d="{light}" stroke="{Q_LIGHT}" stroke-width="2.6" stroke-linecap="round" fill="none" opacity="0.85"/>')


BODY = (172, 196, 100, 80)        # the coat's ellipse
COAT_CLOSE = 'C 250 256 130 260 110 240'


def coat():
    cx, cy, rx, ry = BODY
    return (f'<path d="{fuzz(cx, cy, rx, ry, 182, 372, 30, close=COAT_CLOSE)}" fill="{Q}" {O} stroke-width="3.5" stroke-linejoin="round"/>'
            + texture(cx, cy, rx, ry, 186, 366))


def underside():
    return f'<ellipse cx="170" cy="250" rx="70" ry="13" fill="{CR}" {O} stroke-width="3.5"/>'


def foot(x, fill=CR):
    return (f'<path d="M{x - 8} 248 L{x - 8} 260 L{x + 8} 260 L{x + 8} 248 Z" fill="{fill}" {O} stroke-width="3.5" stroke-linejoin="round"/>'
            f'<ellipse cx="{x - 3}" cy="264" rx="11" ry="6" fill="{fill}" {O} stroke-width="3.5"/>')


def legs_far():
    return foot(138, CR_SH) + foot(222, CR_SH)


def legs_near():
    return foot(122) + foot(206)


# The face: a cream patch on the front of the ball, tapering to a short,
# soft, slightly upturned snout.
FACE = ('M128 158 C 112 154 98 160 92 170 C 86 178 76 181 66 183 '
        'C 54 186 53 200 66 201 C 78 202 88 208 94 216 '
        'C 100 226 98 240 108 248 C 124 256 150 254 160 240 '
        'C 166 220 156 168 128 158 Z')


def face():
    return (f'<path d="{FACE}" fill="{CR}" {O} stroke-width="3.5" stroke-linejoin="round"/>'
            f'<ellipse cx="126" cy="206" rx="10" ry="6" fill="#F59C9C" opacity="0.7"/>'
            f'<ellipse cx="132" cy="236" rx="16" ry="11" fill="#FFFFFF" opacity="0.4"/>'
            f'<path d="M80 208 Q 84 212 88 208" {O} stroke-width="2.6" fill="none" stroke-linecap="round"/>')


def fringe():
    # The coat coming over the crown and forehead, down to above the eyes.
    cx, cy = 132, 200
    close = 'C 160 172 136 168 116 170 C 106 171 98 172 92 176'
    return (f'<path d="{fuzz(cx, cy, 50, 50, 204, 330, 10, lean=12, tip=1.07, close=close)}" fill="{Q}" {O} stroke-width="3.5" stroke-linejoin="round"/>'
            + texture(cx, cy, 50, 50, 210, 326, rows=(0.8, 0.9), per=14, lean=12, seed=7))


def ear():
    return (f'<ellipse cx="150" cy="176" rx="9" ry="10" fill="{CR}" {O} stroke-width="3.5"/>'
            f'<ellipse cx="151" cy="177" rx="4" ry="5" fill="{PINK}"/>')


def nose():
    return (f'<ellipse cx="60" cy="191" rx="8.5" ry="7" fill="#3A2A26"/>'
            f'<ellipse cx="57.5" cy="188" rx="2.6" ry="2" fill="#FFFFFF" opacity="0.85"/>')


def eyes():
    return (f'<ellipse cx="93" cy="189" rx="7" ry="10.5" fill="{EYE}"/><circle cx="91.5" cy="184" r="3" fill="#FFFFFF"/>'
            f'<ellipse cx="119" cy="190" rx="12.5" ry="15" fill="{EYE}"/><circle cx="114" cy="183" r="5" fill="#FFFFFF"/>'
            f'<circle cx="123.5" cy="196" r="2.3" fill="#FFFFFF"/>')


def standing():
    head = face() + fringe() + ear() + eyes() + nose()
    return legs_far() + underside() + legs_near() + coat() + head


def sheet(name, body, scale=2.0):
    svg = f'{D}/{name}.svg'
    with open(svg, 'w', newline='\n') as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">' + body + '</svg>')
    subprocess.run(['godot', '--headless', '-s', f'{D}/render.gd', '--', svg, f'{D}/{name}.png', str(scale)],
                   capture_output=True, timeout=60)
    print(f'{D}/{name}.png')


def ball_coat():
    cx, cy, r = 150, 204, 62
    return (f'<path d="{fuzz(cx, cy, r, r, 0, 360, 34, lean=10, tip=1.08)}" fill="{Q}" {O} stroke-width="3.5" stroke-linejoin="round"/>'
            + texture(cx, cy, r, r, 0, 360, rows=(0.4, 0.55, 0.7, 0.84), per=34, seed=11))


def ball_face():
    # Eyes and a little nose peeking out of the front of the ball.
    return (f'<path d="M98 222 C 98 206 112 198 126 202 C 138 206 140 222 132 232 C 122 242 104 240 98 232 Z" fill="{CR}" {O} stroke-width="3.5" stroke-linejoin="round"/>'
            f'<ellipse cx="108" cy="216" rx="5.5" ry="7.5" fill="{EYE}"/><circle cx="106.5" cy="212.5" r="2.2" fill="#FFFFFF"/>'
            f'<ellipse cx="124" cy="216" rx="5.5" ry="7.5" fill="{EYE}"/><circle cx="122.5" cy="212.5" r="2.2" fill="#FFFFFF"/>'
            f'<ellipse cx="96" cy="229" rx="7" ry="6" fill="#3A2A26"/><ellipse cx="94" cy="226.5" rx="2" ry="1.6" fill="#FFFFFF" opacity="0.85"/>'
            f'<ellipse cx="128" cy="230" rx="6" ry="3.5" fill="#F59C9C" opacity="0.7"/>'
            f'<ellipse cx="130" cy="266" rx="10" ry="5.5" fill="{CR}" {O} stroke-width="3"/><ellipse cx="166" cy="266" rx="10" ry="5.5" fill="{CR}" {O} stroke-width="3"/>')


def eyes_shut():
    return f'<path d="M86 189 Q93 195 100 189 M108 190 Q119 199 130 190" stroke="{EYE}" stroke-width="4.5" stroke-linecap="round" fill="none"/>'


def napping():
    head = face() + fringe() + ear() + eyes_shut() + nose()
    return (f'<g transform="translate(0 16)">{coat()}</g>'
            f'<g transform="translate(4 14) rotate(-8 140 200)">{head}</g>')


if __name__ == '__main__':
    sheet('hh_stand', standing())
    body = (standing() + f'<g transform="translate(300 -10)">{ball_coat()}{ball_face()}</g>'
            + f'<g transform="translate(600 0)">{napping()}</g>')
    svg = f'{D}/hh_sheet.svg'
    with open(svg, 'w', newline='') as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 290" width="900" height="290">' + body + '</svg>')
    subprocess.run(['godot', '--headless', '-s', f'{D}/render.gd', '--', svg, f'{D}/hh_sheet.png', '1.5'], capture_output=True, timeout=60)
    print(f'{D}/hh_sheet.png')
