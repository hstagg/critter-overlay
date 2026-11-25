"""Mock Windows desktops behind the critters in marketing clips.

desk.html draws each scene (windows, taskbar, wallpaper, all content invented);
this renders it with the installed Edge, headless (no window opens), at the
capture's screen size and a supersampling factor, so text stays sharp when
the camera pushes in. Renders are cached by their parameters.

    from desk import Desk
    d = Desk({"scene": "spreadsheet", "theme": "light", "wall": "bloom"}, (1280, 800), taskbar=48, ss=2)
    d.base                          # PIL RGB image, (1280*2, 800*2)
    d.layers_below(img, t, crop)    # toasts and typing, drawn under the critters
    d.layers_above(img, t, crop)    # the pointer, drawn over everything

Motion, in the cut's "desk" block (times in output seconds, places as
fractions of the screen):
  "motion": [
    {"kind": "cursor", "path": [[0, 0.3, 0.4], [1.2, 0.55, 0.62]], "clicks": [1.3]},
    {"kind": "toast", "t": 2.0, "dur": 3.5, "title": "Priya Shah", "body": "can we move it to 2pm?", "icon": "💬"},
    {"kind": "type", "id": "typed", "t": 1.0, "dur": 2.0}
  ]
"type" reveals the element with that id in desk.html left to right, with a
caret, as if typed.

    python tools/desk/desk.py spreadsheet out.png [--theme dark] [--wall night] [--size 1280x800] [--ss 2]

Needs Edge (msedge) and Pillow.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
PAGE = HERE / "desk.html"
CACHE = Path(os.environ.get("CRITTER_DESK_CACHE", Path.home() / "Videos" / "Critter Overlay" / "desk-cache"))
TOAST = (360, 92)


def edge():
    for p in (shutil.which("msedge"), r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
              r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"):
        if p and Path(p).exists():
            return p
    sys.exit("Edge (msedge.exe) not found")


def _run_edge(params, size, ss, extra, profile):
    url = PAGE.as_uri() + "?" + urllib.parse.urlencode(params)
    cmd = [edge(), "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
           "--disable-extensions", f"--user-data-dir={profile}", f"--force-device-scale-factor={ss}",
           f"--window-size={size[0]},{size[1]}", "--virtual-time-budget=1500", *extra, url]
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)


def _stop_edge(profile):
    """End any Edge still running on this render's profile. A headless Edge can
    linger after writing its file, and a later launch on the same profile is
    handed to it and never writes anything."""
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    "Get-CimInstance Win32_Process -Filter \"Name='msedge.exe'\" | "
                    f"Where-Object {{ $_.CommandLine -like '*{profile.name}*' }} | "
                    "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"],
                   capture_output=True, timeout=60)
    shutil.rmtree(profile, ignore_errors=True)


def render(params, size, ss=2):
    """The page with these parameters as a PIL image of size*ss, cached."""
    key = hashlib.sha1(json.dumps([params, size, ss, PAGE.stat().st_mtime_ns], sort_keys=True).encode()).hexdigest()[:16]
    out = CACHE / f"{params.get('scene', params.get('mode', 'x'))}-{key}.png"
    if not out.exists():
        out.parent.mkdir(parents=True, exist_ok=True)
        tmp = out.with_suffix(".part.png")
        tmp.unlink(missing_ok=True)
        profile = CACHE / "profiles" / f"p{os.getpid()}-{key}"    # a fresh profile per render
        profile.mkdir(parents=True, exist_ok=True)
        try:
            _run_edge(params, size, ss, [f"--screenshot={tmp}"], profile)
            # msedge.exe's launcher returns before the browser writes the file
            last, deadline = -1, time.time() + 60
            while time.time() < deadline:
                n = tmp.stat().st_size if tmp.exists() else -1
                if n > 0 and n == last:
                    break
                last = n
                time.sleep(0.5)
        finally:
            _stop_edge(profile)
        if not tmp.exists():
            sys.exit(f"Edge did not write {tmp}")
        tmp.replace(out)
    im = Image.open(out).convert("RGB")
    want = (round(size[0] * ss), round(size[1] * ss))
    return im if im.size == want else im.resize(want, Image.LANCZOS)


def boxes(params, size, ids):
    """Element rectangles (CSS px) from the page. The page draws each number as
    a bar that long (desk.html), because Edge's launcher returns no output."""
    im = render(dict(params, boxes=",".join(ids)), size, 1).convert("L")
    px = im.load()
    out = {}
    for i, id_ in enumerate(ids):
        vals = [sum(1 for x in range(im.width) if px[x, 4 * i + k] < 128) for k in range(4)]
        if vals[2] and vals[3]:
            out[id_] = vals
    return out


def cursor_sprite(ss):
    pts = [(0, 0), (0, 17), (4.2, 13), (7.2, 19.4), (9.6, 18.4), (6.7, 12.2), (12, 12.2)]
    k = 1.15 * ss
    im = Image.new("RGBA", (int(16 * k), int(23 * k)))
    d = ImageDraw.Draw(im)
    poly = [(1 + x * k, 1 + y * k) for x, y in pts]
    d.polygon(poly, fill=(255, 255, 255, 255), outline=(0, 0, 0, 255))
    d.line(poly + [poly[0]], fill=(0, 0, 0, 255), width=max(1, round(ss * 0.9)))
    return im


def smooth(a):
    a = min(1.0, max(0.0, a))
    return a * a * (3 - 2 * a)


class Desk:
    def __init__(self, spec, size, taskbar=48, ss=2):
        self.spec, self.size, self.ss = spec, size, ss
        self.params = {"scene": spec.get("scene", "blank"), "theme": spec.get("theme", "light"),
                       "tb": str(taskbar)}
        for k in ("wall", "clock", "date"):
            if spec.get(k):
                self.params[k] = spec[k]
        self.base = render(self.params, size, ss)
        self.motion = spec.get("motion", [])
        self.cursor = cursor_sprite(ss)
        self.toasts, self.types = [], []
        for m in self.motion:
            if m["kind"] == "toast":
                im = render({"mode": "toast", "theme": self.params["theme"], "title": m.get("title", ""),
                             "body": m.get("body", ""), "icon": m.get("icon", "💬")}, TOAST, ss)
                self.toasts.append((m, self._rounded(im, 8 * ss)))
            elif m["kind"] == "type":
                before = render(dict(self.params, hide=m["id"]), size, ss)
                box = boxes(self.params, size, [m["id"]]).get(m["id"])
                if box:
                    self.types.append((m, before, [v * ss for v in box]))
        self.taskbar = taskbar

    @staticmethod
    def _rounded(im, r):
        mask = Image.new("L", im.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], r, fill=255)
        out = im.convert("RGBA")
        out.putalpha(mask)
        return out

    def layers_below(self, img, t, crop):
        """Typing and toasts onto img, the crop (x0, y0) of the supersampled screen."""
        x0, y0 = crop
        for m, before, (bx, by, bw, bh) in self.types:
            k = (t - m["t"]) / m.get("dur", 2.0)
            if k >= 1:
                continue
            # hide the not-yet-typed part, stepping like keystrokes
            step = 7.5 * self.ss
            shown = 0 if k < 0 else int((bw * k) // step * step)
            region = before.crop((int(bx + shown), int(by), int(bx + bw + 2), int(by + bh)))
            img.paste(region, (int(bx + shown - x0), int(by - y0)))
            if k >= 0 and int(t * 2.2) % 2 == 0:
                d = ImageDraw.Draw(img)
                cx = bx + shown - x0 + 1
                d.line([(cx, by - y0 + bh * 0.15), (cx, by - y0 + bh * 0.85)], fill=(40, 40, 48), width=max(1, round(self.ss)))
        for m, im in self.toasts:
            t0, dur = m.get("t", 0), m.get("dur", 3.5)
            if not t0 <= t <= t0 + dur:
                continue
            k = min(smooth((t - t0) / 0.35), smooth((t0 + dur - t) / 0.3))
            sw, sh = self.size[0] * self.ss, self.size[1] * self.ss
            x = sw - im.width - 12 * self.ss + (1 - k) * (im.width + 24 * self.ss)
            y = sh - self.taskbar * self.ss - im.height - 12 * self.ss
            img.paste(im, (int(x - x0), int(y - y0)), im)

    def layers_above(self, img, t, crop):
        x0, y0 = crop
        for m in self.motion:
            if m["kind"] != "cursor":
                continue
            path = m["path"]
            if t <= path[0][0]:
                fx, fy = path[0][1:]
            elif t >= path[-1][0]:
                fx, fy = path[-1][1:]
            else:
                for a, b in zip(path, path[1:]):
                    if a[0] <= t <= b[0]:
                        k = smooth((t - a[0]) / max(1e-6, b[0] - a[0]))
                        fx, fy = a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k
                        break
            cur = self.cursor
            if any(0 <= t - c <= 0.12 for c in m.get("clicks", [])):
                cur = cur.resize((int(cur.width * 0.88), int(cur.height * 0.88)), Image.LANCZOS)
            px, py = fx * self.size[0] * self.ss, fy * self.size[1] * self.ss
            img.paste(cur, (int(px - x0), int(py - y0)), cur)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("scene")
    ap.add_argument("out", type=Path)
    ap.add_argument("--theme", default="light")
    ap.add_argument("--wall", default="")
    ap.add_argument("--size", default="1280x800")
    ap.add_argument("--taskbar", type=int, default=48)
    ap.add_argument("--ss", type=float, default=2)
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.split("x"))
    d = Desk({"scene": a.scene, "theme": a.theme, "wall": a.wall}, (w, h), a.taskbar, a.ss)
    d.base.save(a.out)
    print(f"{a.out}: {d.base.size[0]}x{d.base.size[1]}")


if __name__ == "__main__":
    main()
