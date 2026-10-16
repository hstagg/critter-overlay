"""Cut a --film capture into a finished vertical clip: camera, slow motion,
effects, titles and sound, all timed to what the critters actually do.

  python tools/film/edit.py CAPTURE out.mp4 --cut cut.json

main.gd --film logs every frame's windows plus what each critter is doing
(species, tier, mode, act) and which pairs are running. This finds events in
that log and hangs the edit on them, so a cut written once works on any take.

Events (the "on" field anywhere below):
  pair_start, pair_act, pair_end   a pair walks over / starts acting / ends
  act:NAME, act:*                  a critter starts a behaviour (groom, pounce...)
  arrive                           a critter appears
  t:SECONDS                        a fixed moment in the capture
Add "nth": 1 to use the second occurrence, and "offset": -0.3 to shift it.

The cut (JSON, every key optional):
  "fps": 30                         output rate; capture at --fixed-fps 60 for
                                    clean slow motion
  "from": {"on": "pair_start", "lead": 1.5}, "length": 9
                                    where the clip starts (capture seconds
                                    before the event) and how long it runs
                                    (output seconds)
  "camera": {"mode": "pair"|"follow"|"all", "tight": 0.55,
             "push": [{"on": "pair_act", "tight": 0.36, "hold": 2.0}]}
                                    tight = crop height / screen height; push
                                    eases in at the event and back after hold
  "slowmo": [{"on": "pair_act", "before": 0.1, "dur": 1.2, "speed": 0.4}]
  "fx": [{"on": "pair_act", "kind": "hearts"|"sparkles"|"stars"|"impact"|
          "flash"|"spotlight", "dur": 1.5, "who": "a"|"b"|"pair"}]
  "titles": [{"t": 0.0, "dur": 2.5, "text": "...", "pos": "top"|"bottom"|"centre",
              "size": 84}]       (t in output seconds)
  "cards": [{"on": "...", "delay": 0.4, "dur": 3, "name": "Sea otter",
             "sub": "Rare  ·  1 in 25", "tier": "rare"}]
  "sfx": [{"on": "pair_act", "sound": "sparkle"|"pop"|"whoosh"|"boing"|
           "bloop"|"chime"|"game:otter"|"file:path.wav", "gain": 0.8}]
  "music": {"file": "bed.mp3", "gain": 0.5, "start": 0.0, "fade": 1.0}
  "backdrop": "studio" | "image.png"   studio is a soft brand-coloured set for
                                    close-ups; default is the mock work screen

Needs Pillow, numpy and ffmpeg on PATH.
"""

import argparse
import json
import math
import random
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).parent))
from compose import load_frames, mock_backdrop, paste_premultiplied  # noqa: E402

W, H = 1080, 1920
SR = 48000
ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "godot" / "fonts" / "Fredoka.ttf"
TIER = {"common": (240, 236, 246), "rare": (74, 150, 235), "epic": (222, 76, 140),
        "legendary": (246, 190, 60)}


# --- Events --------------------------------------------------------------------

def find_events(frames, fps_in):
    """Every event in the capture as dicts with t (capture s), kind, name, who."""
    ev = []
    prev_act, prev_stage, seen = {}, {}, set()
    for i, fr in enumerate(frames):
        t = i / fps_in
        pos = {w["id"]: (w["x"] + _size(w) / 2, w["y"] + _size(w) / 2) for w in fr["wins"] if "id" in w}
        for w in fr["wins"]:
            if "id" not in w:
                continue
            if w["id"] not in seen:
                seen.add(w["id"])
                ev.append({"t": t, "kind": "arrive", "name": w["sp"], "pos": [pos[w["id"]]], "tier": w["tier"]})
            a = w.get("act", "")
            if a and a != prev_act.get(w["id"], ""):
                ev.append({"t": t, "kind": "act", "name": a, "pos": [pos[w["id"]]], "tier": w["tier"]})
            prev_act[w["id"]] = a
        live = set()
        for p in fr.get("pairs", []):
            key = (p["a"], p["b"], p["name"])
            live.add(key)
            pp = [pos.get(p["a"]), pos.get(p["b"])]
            pp = [q for q in pp if q]
            if key not in prev_stage:
                ev.append({"t": t, "kind": "pair_start", "name": p["name"], "pos": pp, "ids": [p["a"], p["b"]]})
            if p["stage"] == "act" and prev_stage.get(key) != "act":
                ev.append({"t": t, "kind": "pair_act", "name": p["name"], "pos": pp, "ids": [p["a"], p["b"]]})
            prev_stage[key] = p["stage"]
        for key in list(prev_stage):
            if key not in live:
                ev.append({"t": t, "kind": "pair_end", "name": key[2], "pos": [], "ids": [key[0], key[1]]})
                del prev_stage[key]
    return ev


def _size(w):
    return w.get("_w", 0)


def pick(events, spec):
    """The event a cut entry hangs on, or None."""
    on = spec["on"]
    if on.startswith("t:"):
        return {"t": float(on[2:]) + spec.get("offset", 0.0), "kind": "t", "pos": [], "name": ""}
    if on.startswith("act:"):
        name = on[4:]
        hits = [e for e in events if e["kind"] == "act" and (name == "*" or e["name"] == name)]
    else:
        hits = [e for e in events if e["kind"] == on]
    n = spec.get("nth", 0)
    if n >= len(hits):
        return None
    e = dict(hits[n])
    e["t"] += spec.get("offset", 0.0)
    return e


# --- Time ----------------------------------------------------------------------

def time_map(t0, length, fps_out, slowmo, events):
    """Capture time for each output frame, slowing down inside slowmo windows."""
    wins = []
    for s in slowmo:
        e = pick(events, s)
        if e:
            a = e["t"] - s.get("before", 0.1)
            wins.append((a, a + s.get("dur", 1.0), s.get("speed", 0.5)))

    def speed(t):
        for a, b, sp in wins:
            # ease into and out of the slow part over 0.15 s so it reads as a ramp
            if a - 0.15 <= t <= b + 0.15:
                k = min(1.0, (t - (a - 0.15)) / 0.15, ((b + 0.15) - t) / 0.15)
                return 1.0 + (sp - 1.0) * max(0.0, k)
        return 1.0

    out, t = [], t0
    for _ in range(int(length * fps_out)):
        out.append(t)
        t += speed(t) / fps_out
    return out


def to_out(src_times, t):
    """Output seconds at which capture time t is shown."""
    i = int(np.searchsorted(src_times, t))
    return i


# --- Drawing helpers -----------------------------------------------------------

def heart(d, cx, cy, r, fill):
    pts = []
    for k in range(40):
        a = k / 40 * 2 * math.pi
        x = 16 * math.sin(a) ** 3
        y = -(13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a))
        pts.append((cx + x * r / 17, cy + y * r / 17))
    d.polygon(pts, fill=fill)


def sparkle(d, cx, cy, r, fill, rot=0.0):
    pts = []
    for k in range(8):
        a = rot + k * math.pi / 4
        rr = r if k % 2 == 0 else r * 0.28
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=fill)


def star5(d, cx, cy, r, fill, rot=0.0):
    pts = []
    for k in range(10):
        a = rot - math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=fill)


def studio_backdrop(sw, sh, rng):
    """A soft lavender set with out-of-focus lights: reads well at any zoom."""
    yy, xx = np.mgrid[0:sh, 0:sw].astype(np.float32)
    r = np.sqrt(((xx - sw * 0.5) / sw) ** 2 + ((yy - sh * 0.62) / sh) ** 2)
    inner, outer = np.array([250, 244, 255], np.float32), np.array([214, 196, 240], np.float32)
    px = inner + (outer - inner) * np.clip(r / 0.75, 0, 1)[..., None]
    img = Image.fromarray(px.astype(np.uint8)).convert("RGBA")
    dots = Image.new("RGBA", (sw, sh))
    d = ImageDraw.Draw(dots)
    for _ in range(26):
        x, y, rad = rng.uniform(0, sw), rng.uniform(0, sh * 0.7), rng.uniform(30, 110)
        col = rng.choice([(255, 214, 236), (220, 206, 255), (255, 240, 210), (206, 232, 255)])
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=col + (int(rng.uniform(60, 130)),))
    img.alpha_composite(dots.filter(ImageFilter.GaussianBlur(18)))
    floor = Image.new("RGBA", (sw, sh))
    ImageDraw.Draw(floor).ellipse([-sw * 0.2, sh * 0.78, sw * 1.2, sh * 1.5], fill=(196, 176, 228, 120))
    img.alpha_composite(floor.filter(ImageFilter.GaussianBlur(40)))
    return img.convert("RGB")


def ease_out_back(x):
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


def text_img(text, size, fill=(255, 255, 255), stroke=(45, 30, 60), sw=None):
    f = ImageFont.truetype(str(FONT), size)
    sw = max(3, size // 12) if sw is None else sw
    tmp = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    box = [int(round(v)) for v in tmp.multiline_textbbox((0, 0), text, font=f, stroke_width=sw, align="center", spacing=size // 6)]
    im = Image.new("RGBA", (box[2] - box[0] + 20, box[3] - box[1] + 20))
    ImageDraw.Draw(im).multiline_text((10 - box[0], 10 - box[1]), text, font=f, fill=fill, stroke_width=sw,
                                      stroke_fill=stroke, align="center", spacing=size // 6)
    return im


def card_img(name, sub, tier):
    col = TIER.get(tier, TIER["common"])
    n = text_img(name, 92, stroke=tuple(int(c * 0.45) for c in col))
    s = text_img(sub, 50, fill=(255, 255, 255), stroke=(40, 30, 50), sw=4)
    w = max(n.width, s.width) + 90
    h = n.height + s.height + 50
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, h - 1], 46, fill=col + (235,))
    d.rounded_rectangle([8, 8, w - 9, h - 9], 40, outline=(255, 255, 255, 170), width=4)
    im.alpha_composite(n, ((w - n.width) // 2, 18))
    im.alpha_composite(s, ((w - s.width) // 2, n.height + 22))
    return im


# --- Particles -----------------------------------------------------------------

class Burst:
    """A one-off particle burst in screen coordinates, drawn in output space."""

    def __init__(self, kind, t0, origin, dur, rng):
        self.kind, self.t0, self.dur = kind, t0, dur
        n = {"hearts": 9, "sparkles": 16, "stars": 12, "impact": 1}.get(kind, 0)
        self.p = []
        for _ in range(n):
            a = rng.uniform(-math.pi * 0.95, -math.pi * 0.05) if kind == "hearts" else rng.uniform(0, 2 * math.pi)
            v = rng.uniform(140, 320) if kind != "hearts" else rng.uniform(90, 200)
            self.p.append({"x": origin[0] + rng.uniform(-30, 30), "y": origin[1] + rng.uniform(-40, 10),
                           "vx": math.cos(a) * v, "vy": math.sin(a) * v, "r": rng.uniform(14, 30),
                           "rot": rng.uniform(0, 6.28), "spin": rng.uniform(-3, 3),
                           "delay": rng.uniform(0, 0.35), "hue": rng.random()})
        self.origin = origin

    def draw(self, d, t, cam, scale):
        age = t - self.t0
        if age < 0 or age > self.dur:
            return
        ox, oy = cam
        if self.kind == "impact":
            k = age / min(self.dur, 0.45)
            if k > 1:
                return
            r = (40 + 220 * ease_out_back(min(k, 1))) * scale
            cx, cy = (self.origin[0] - ox) * scale, (self.origin[1] - oy) * scale
            a = int(230 * (1 - k))
            wd = max(3, int(16 * (1 - k) * scale))
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(236, 120, 190, a), width=wd + 4)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, a), width=max(1, wd // 2))
            return
        for q in self.p:
            age_q = age - q["delay"]
            if age_q < 0:
                continue
            life = age_q / (self.dur - q["delay"])
            if life > 1:
                continue
            g = 60 if self.kind == "hearts" else 260
            x = q["x"] + q["vx"] * age_q
            y = q["y"] + q["vy"] * age_q + 0.5 * g * age_q * age_q * (0.2 if self.kind == "hearts" else 1)
            if self.kind == "hearts":
                x += math.sin(age_q * 5 + q["rot"]) * 12
            pop = min(1.0, age_q / 0.18)
            r = q["r"] * ease_out_back(pop) * (1 - life * 0.35) * scale
            a = int(255 * min(1.0, (1 - life) * 2.2))
            cx, cy = (x - ox) * scale, (y - oy) * scale
            if self.kind == "hearts":
                heart(d, cx, cy, r * 1.3 + 4 * scale, (200, 60, 120, a))
                heart(d, cx, cy, r * 1.3, (255, 110 + int(q["hue"] * 60), 160 + int(q["hue"] * 30), a))
            elif self.kind == "sparkles":
                rot = q["rot"] + q["spin"] * age_q
                sparkle(d, cx, cy, r * 1.35, (246, 176, 40, a), rot)
                sparkle(d, cx, cy, r * 0.8, (255, 252, 226, a), rot)
            else:
                rot = q["rot"] + q["spin"] * age_q
                star5(d, cx, cy, r * 1.2, (232, 130, 30, a), rot)
                star5(d, cx, cy, r * 0.95, (255, 220 + int(q["hue"] * 30), 80, a), rot)


# --- Sound ---------------------------------------------------------------------

def synth(name, rng):
    """Small owned sound effects, made here so every clip has sound from day one."""
    def env(n, attack, decay):
        e = np.ones(n)
        a = max(1, int(attack * SR))
        e[:a] = np.linspace(0, 1, a)
        e[a:] = np.exp(-np.arange(n - a) / (decay * SR))
        return e
    t = lambda s: np.arange(int(s * SR)) / SR  # noqa: E731
    if name == "sparkle":
        out = np.zeros(int(1.2 * SR))
        for k in range(7):
            f = rng.choice([1568, 1760, 2093, 2349, 2637, 3136, 3520])
            st = int(k * 0.06 * SR)
            x = t(0.6)
            s = (np.sin(2 * np.pi * f * x) + 0.3 * np.sin(2 * np.pi * f * 2.01 * x)) * env(len(x), 0.002, 0.12)
            out[st:st + len(s)] += s * 0.22
        return out
    if name == "chime":
        x = t(1.6)
        out = sum(np.sin(2 * np.pi * f * x) * env(len(x), 0.003, d) * g
                  for f, d, g in [(1046.5, 0.5, 0.4), (1568, 0.4, 0.25), (2093, 0.3, 0.18), (3136, 0.2, 0.08)])
        return out
    if name == "pop":
        x = t(0.18)
        f = 900 * np.exp(-x * 18) + 280
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.001, 0.04) * 0.7
    if name == "bloop":
        x = t(0.3)
        f = 380 + 520 * (1 - np.exp(-x * 14))
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.004, 0.08) * 0.6
    if name == "boing":
        x = t(0.5)
        f = 210 * (1 + 0.5 * np.exp(-x * 6) * np.sin(2 * np.pi * 16 * x)) + 90 * np.exp(-x * 5)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.002, 0.16) * 0.6
    if name == "whoosh":
        x = t(0.7)
        noise = np.random.default_rng(1).standard_normal(len(x))
        cut = 0.02 + 0.25 * np.sin(np.pi * x / x[-1])
        y = np.zeros_like(noise)
        acc = 0.0
        for i, (n, c) in enumerate(zip(noise, cut)):
            acc += c * (n - acc)
            y[i] = acc
        return y * np.sin(np.pi * x / x[-1]) ** 2 * 0.9
    raise ValueError(f"unknown sound {name}")


def load_wav(path):
    """Any audio file as mono float at SR, through ffmpeg."""
    raw = subprocess.run([shutil.which("ffmpeg"), "-loglevel", "error", "-i", str(path), "-f", "f32le",
                          "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def mix_audio(length, cues, music, rng):
    track = np.zeros(int(length * SR) + SR)
    if music:
        m = load_wav(music["file"])
        m = m[int(music.get("start", 0) * SR):][:len(track)]
        fade = int(music.get("fade", 1.0) * SR)
        g = np.full(len(m), music.get("gain", 0.5))
        if fade and len(m) > fade:
            g[-fade:] *= np.linspace(1, 0, fade)
            g[:int(0.05 * SR)] *= np.linspace(0, 1, int(0.05 * SR))
        track[:len(m)] += m * g
    for t, sound, gain in cues:
        if sound.startswith("game:"):
            s = load_wav(ROOT / "godot" / "sounds" / f"{sound[5:]}.wav")
        elif sound.startswith("file:"):
            s = load_wav(sound[5:])
        else:
            s = synth(sound, rng)
        a = int(t * SR)
        if a >= len(track):
            continue
        s = s[:len(track) - a]
        track[a:a + len(s)] += s * gain
    peak = np.max(np.abs(track)) or 1.0
    track = np.tanh(track / max(peak, 1.0) * 1.2) * 0.89   # soft limit
    return track[:int(length * SR)]


def write_wav(path, x):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


# --- Main ----------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("capture", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--cut", type=Path)
    ap.add_argument("--fps-in", type=float, default=0, help="capture rate; read from the log when 0")
    ap.add_argument("--events", action="store_true", help="list the capture's events and stop")
    a = ap.parse_args()
    cut = json.loads(a.cut.read_text(encoding="utf-8")) if a.cut else {}
    rng = random.Random(cut.get("seed", 7))

    head, frames = load_frames(a.capture)
    sx, sy, sw, sh = head["screen"]
    # The capture rate is in the log: t steps by one fixed frame each line.
    fps_in = a.fps_in or (round(1.0 / (frames[2]["t"] - frames[1]["t"])) if len(frames) > 2 else 30.0)
    # Critter windows in one capture share a size; centres need it.
    first = next((w for fr in frames for w in fr["wins"] if "id" in w), None)
    wsz = Image.open(a.capture / first["png"]).width if first else 240
    for fr in frames:
        for w in fr["wins"]:
            w["_w"] = wsz
    events = find_events(frames, fps_in)
    if a.events:
        for e in events:
            print(f"{e['t']:6.2f}  {e['kind']:10} {e['name']}")
        return

    fps = cut.get("fps", 30)
    start = 0.5
    if "from" in cut:
        e = pick(events, cut["from"])
        if e:
            start = max(0.0, e["t"] - cut["from"].get("lead", 1.0))
    length = cut.get("length", min(12.0, len(frames) / fps_in - start))
    src = time_map(start, length, fps, cut.get("slowmo", []), events)
    src = [min(s, (len(frames) - 1) / fps_in) for s in src]
    out_at = lambda t_src: to_out(src, t_src) / fps  # noqa: E731

    bd = cut.get("backdrop", "")
    back = (studio_backdrop(sw, sh, rng) if bd == "studio"
            else Image.open(bd).convert("RGB").resize((sw, sh)) if bd
            else mock_backdrop(sw, sh, [head["area"][0] - sx, head["area"][1] - sy, head["area"][2], head["area"][3]]))
    back_px = np.asarray(back, dtype=np.float32)

    cam_cfg = cut.get("camera", {})
    base_tight = cam_cfg.get("tight", 0.55)
    pushes = []
    for p in cam_cfg.get("push", []):
        e = pick(events, p)
        if e:
            pushes.append((out_at(e["t"]), p.get("hold", 2.0), p.get("tight", 0.38)))

    bursts, flashes, spots = [], [], []
    for f in cut.get("fx", []):
        e = pick(events, f)
        if not e:
            continue
        t_out = out_at(e["t"])
        k = f["kind"]
        if k == "flash":
            flashes.append((t_out, f.get("dur", 0.5)))
        elif k == "spotlight":
            spots.append((t_out - f.get("lead", 0.6), t_out + f.get("dur", 2.0)))
        else:
            pts = e["pos"] or [(sw / 2, sh / 2)]
            who = f.get("who", "pair")
            o = pts[0] if who == "a" else pts[-1] if who == "b" else tuple(np.mean(pts, axis=0))
            o = (o[0] - sx + f.get("dx", 0), o[1] - sy + f.get("dy", -40))
            bursts.append(Burst(k, t_out, o, f.get("dur", 1.6), rng))

    cards = []
    for c in cut.get("cards", []):
        e = pick(events, c) if "on" in c else {"t": None}
        if e:
            t0 = (out_at(e["t"]) if e["t"] is not None else c.get("t", 0)) + c.get("delay", 0.0)
            cards.append((t0, c.get("dur", 3.0), card_img(c["name"], c.get("sub", ""), c.get("tier", "common"))))
    titles = [(ti.get("t", 0), ti.get("dur", 2.5), ti.get("pos", "top"), text_img(ti["text"], ti.get("size", 84)))
              for ti in cut.get("titles", [])]

    yy, xx = np.mgrid[0:H, 0:W]
    vign = 1 - 0.32 * np.clip(((xx - W / 2) ** 2 / (W * 0.62) ** 2 + (yy - H / 2) ** 2 / (H * 0.6) ** 2) - 0.35, 0, 1)
    vign = vign[..., None].astype(np.float32)

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        sys.exit("ffmpeg is not on PATH")
    silent = a.out.with_suffix(".video.mp4")
    enc = subprocess.Popen([ffmpeg, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                            "-s", f"{W}x{H}", "-r", str(fps), "-i", "-", "-c:v", "libx264", "-pix_fmt",
                            "yuv420p", "-crf", "17", "-preset", "slow", str(silent)], stdin=subprocess.PIPE)

    mode = cam_cfg.get("mode", "pair")
    cam = None
    tight = base_tight
    for i, ts in enumerate(src):
        t_out = i / fps
        fi = ts * fps_in
        f0 = int(fi)
        fr = frames[min(f0, len(frames) - 1)]
        # subject: the pair if one is running, else everyone, else the nearest
        centres = {w["id"]: (w["x"] - sx + wsz / 2, w["y"] - sy + wsz / 2) for w in fr["wins"] if "id" in w}
        subj, fit = None, 0.0
        if mode == "pair" and fr.get("pairs"):
            ids = [fr["pairs"][0]["a"], fr["pairs"][0]["b"]]
            pts = [centres[k] for k in ids if k in centres]
            subj = tuple(np.mean(pts, axis=0)) if pts else None
        if mode in ("pair", "all") and centres:
            pts = [centres[k] for k in ids if k in centres] if subj else list(centres.values())
            xs = [p[0] for p in pts]
            # never crop a critter: the frame is at least as wide as the group
            fit = (max(xs) - min(xs) + wsz * 0.9) * 16 / 9 / sh
        if subj is None and centres:
            pts = list(centres.values())
            if mode == "follow" and cam is not None:
                subj = min(pts, key=lambda p: (p[0] - cam[0]) ** 2 + (p[1] - cam[1]) ** 2)
            else:
                subj = tuple(np.mean(pts, axis=0))
        subj = subj or (sw / 2, sh / 2)
        want_t = base_tight
        for t0, hold, tt in pushes:
            if t0 <= t_out <= t0 + hold:
                want_t = tt
        cam = subj if cam is None else (cam[0] + (subj[0] - cam[0]) * 0.08, cam[1] + (subj[1] - cam[1]) * 0.08)
        want_t = min(1.0, max(want_t, fit))
        tight += (want_t - tight) * 0.12
        ch = sh * tight
        cw = ch * 9 / 16
        left = min(max(cam[0] - cw / 2, 0), sw - cw)
        top = min(max(cam[1] - ch * 0.55, 0), sh - ch)

        # composite only the crop, from the nearest capture frame
        x0, y0, x1, y1 = int(left), int(top), int(math.ceil(left + cw)), int(math.ceil(top + ch))
        buf = back_px[y0:y1, x0:x1].copy()
        for w in fr["wins"]:
            im = Image.open(a.capture / w["png"]).convert("RGBA")
            paste_premultiplied(buf, im, w["x"] - sx - x0, w["y"] - sy - y0)
        frame = Image.fromarray(np.clip(buf, 0, 255).astype(np.uint8)).resize((W, H), Image.LANCZOS, box=(left - x0, top - y0, left - x0 + cw, top - y0 + ch))
        scale = W / cw

        px = np.asarray(frame, dtype=np.float32)
        for s0, s1 in spots:
            if s0 <= t_out <= s1:
                k = min(1.0, (t_out - s0) / 0.4, (s1 - t_out) / 0.4)
                cx, cy = (subj[0] - left) * scale, (subj[1] - top) * scale
                d2 = ((xx - cx) ** 2 + (yy - cy) ** 2) / (330.0 ** 2)
                dim = 1 - 0.62 * k * np.clip(d2 - 0.6, 0, 1)[..., None]
                px = px * dim
        px = px * vign
        frame = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8)).convert("RGBA")

        over = Image.new("RGBA", (W, H))
        d = ImageDraw.Draw(over)
        for b in bursts:
            b.draw(d, t_out, (left, top), scale)
        frame.alpha_composite(over)
        for t0, dur in flashes:
            if t0 <= t_out <= t0 + dur:
                k = 1 - (t_out - t0) / dur
                frame.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(235 * k * k))))
        for t0, dur, pos, im in titles + [(t0, dur, "card", im) for t0, dur, im in cards]:
            if not (t0 <= t_out <= t0 + dur):
                continue
            k_in = min(1.0, (t_out - t0) / 0.28)
            k_out = min(1.0, (t0 + dur - t_out) / 0.22)
            s = max(0.05, ease_out_back(k_in) * (0.9 + 0.1 * k_out))
            t_im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
            if k_out < 1:
                t_im.putalpha(t_im.getchannel("A").point(lambda v: int(v * k_out)))
            y = {"top": 260, "bottom": H - 360, "centre": H // 2, "card": H - 470}[pos] - t_im.height // 2
            frame.alpha_composite(t_im, ((W - t_im.width) // 2, max(0, y)))
        enc.stdin.write(frame.convert("RGB").tobytes())
    enc.stdin.close()
    if enc.wait():
        sys.exit("ffmpeg failed")

    cues = []
    for s in cut.get("sfx", []):
        e = pick(events, s)
        if e:
            cues.append((max(0.0, out_at(e["t"]) + s.get("delay", 0.0)), s["sound"], s.get("gain", 0.8)))
    audio = a.out.with_suffix(".wav")
    write_wav(audio, mix_audio(len(src) / fps, cues, cut.get("music"), rng))
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(silent), "-i", str(audio), "-c:v", "copy",
                    "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(a.out)], check=True)
    silent.unlink()
    audio.unlink()
    print(f"{a.out}: {len(src)} frames, {len(src) / fps:.1f} s, {len(cues)} sound cues")


if __name__ == "__main__":
    main()
