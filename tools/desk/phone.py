"""The "someone filmed my screen" look: the desktop shown on a monitor in a
room, seen by a phone held upright, with a slight angle, handheld drift,
grain and a little glare. A second visual register next to the clean
screen-capture look, tested against it.

    from phone import PhoneLook
    look = PhoneLook((1280, 800), wall="#d8c8b8")
    frame = look.frame(full_screen_image, t, zoom=1.05)   # 1080x1920 RGB

The room comes from desk.html (mode=room) through desk.render. In edit.py:
"look": {"kind": "phone", "wall": "#d8c8b8", "zoom": [[0, 1.0], [11, 1.12]]}
"""

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from desk import render

W, H = 1080, 1920
MARGIN = 1.12          # the room is drawn this much larger, for drift and zoom


def perspective_coeffs(dst, src):
    """PIL PERSPECTIVE coefficients mapping output points dst to input points src."""
    a, b = [], []
    for (x, y), (X, Y) in zip(dst, src):
        a.append([x, y, 1, 0, 0, 0, -X * x, -X * y])
        b.append(X)
        a.append([0, 0, 0, x, y, 1, -Y * x, -Y * y])
        b.append(Y)
    return np.linalg.solve(np.array(a, float), np.array(b, float)).tolist()


class PhoneLook:
    def __init__(self, screen_size, wall="#d8c8b8", seed=3):
        sw, sh = screen_size
        rw = 940
        rh = round(rw * sh / sw)
        self.rect = (70, 640, rw, rh)                       # screen, in 1080x1920 room space
        self.room = render({"mode": "room", "wall": wall, "sx": 70, "sy": 640, "sw": rw, "sh": rh},
                           (W, H), MARGIN)
        M = MARGIN
        rx, ry, rw_, rh_ = (v * M for v in self.rect)
        self.screen_box = (round(rx), round(ry), round(rw_), round(rh_))
        g = Image.new("L", (self.screen_box[2], self.screen_box[3]))
        d = ImageDraw.Draw(g)
        for i in range(g.width + g.height):         # a soft diagonal sheen across the glass
            v = max(0, 1 - abs(i - g.width * 0.55) / (g.width * 0.22))
            d.line([(i, 0), (i - g.height, g.height)], fill=int(26 * v * v))
        self.glare = g.filter(ImageFilter.GaussianBlur(18))
        rng = np.random.default_rng(seed)
        self.grain = [rng.normal(0, 3.2, (H, W, 1)).astype(np.float32) for _ in range(6)]
        yy, xx = np.mgrid[0:H, 0:W]
        v = 1 - 0.22 * np.clip(((xx - W / 2) ** 2 / (W * 0.7) ** 2 + (yy - H / 2) ** 2 / (H * 0.62) ** 2) - 0.4, 0, 1)
        self.vign = (v[..., None] * np.array([1.03, 1.0, 0.95], np.float32)).astype(np.float32)   # a touch warm
        self.i = 0

    def frame(self, shot, t, zoom=1.0, focus=None):
        """focus: the subject as (x, y) fractions of the screen; the closer the
        zoom, the more the phone centres on it, as a person filming would."""
        room = self.room.copy()
        bx, by, bw, bh = self.screen_box
        scr = shot.resize((bw, bh), Image.LANCZOS)
        white = Image.new("RGB", (bw, bh), (255, 255, 255))
        scr = Image.composite(white, scr, self.glare)
        room.paste(scr, (bx, by))
        # the phone's frame in room space: centred, zoomed, a little angled, drifting
        cx = room.width / 2 + 6 * math.sin(2 * math.pi * 0.31 * t) + 3 * math.sin(2 * math.pi * 0.87 * t + 1)
        cy = room.height / 2 - 30 + 5 * math.sin(2 * math.pi * 0.23 * t + 2) + 2.5 * math.sin(2 * math.pi * 1.1 * t)
        rot = math.radians(0.6 + 0.25 * math.sin(2 * math.pi * 0.17 * t))
        hw, hh = W / 2 / zoom, H / 2 / zoom
        if focus:
            k = min(1.0, max(0.0, (zoom - 1) / 0.7))
            rx, ry, rw, rh = self.rect
            fx, fy = (rx + focus[0] * rw) * MARGIN, (ry + focus[1] * rh) * MARGIN
            cx = min(max(cx + (fx - cx) * k, hw + 20), room.width - hw - 20)
            cy = min(max(cy + (fy - cy) * k, hh + 20), room.height - hh - 20)
        quad = [(-hw + 16, -hh + 20), (hw - 8, -hh - 4), (hw + 4, hh + 6), (-hw - 12, hh - 14)]   # slight yaw and tilt
        c, s = math.cos(rot), math.sin(rot)
        src = [(cx + x * c - y * s, cy + x * s + y * c) for x, y in quad]
        out = room.transform((W, H), Image.PERSPECTIVE, perspective_coeffs([(0, 0), (W, 0), (W, H), (0, H)], src),
                             Image.BICUBIC)
        px = np.asarray(out, dtype=np.float32) * self.vign + self.grain[self.i % len(self.grain)]
        self.i += 1
        return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
