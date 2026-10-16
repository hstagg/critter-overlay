"""Turn a --film capture into a vertical 1080x1920 MP4 for short-video posts.

main.gd's --film=DIR saves every critter and showpiece window each frame, with
its place on screen, to DIR/frames.jsonl. This pastes those windows onto a
backdrop at their real positions, so nothing on the real desktop is ever read.

Layouts:
  letterbox  the whole screen, scaled to the frame's width, with plain bands
             above and below for captions (added here with --caption, or later
             in an editor)
  crop       a 9:16 window that follows one critter (whichever is nearest the
             camera), smoothed; --tight 0.5 frames half the screen's height

Usage:
  python tools/film/compose.py DIR out.mp4 [--layout crop] [--backdrop img.png]
      [--caption "text"] [--fps 30] [--tight 0.6]

Without --backdrop a plain mock work screen is drawn (mock_backdrop below).
Needs Pillow, numpy, and ffmpeg on PATH.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920


def mock_backdrop(sw, sh, area):
    """A neutral desktop: soft wallpaper, a document window, a taskbar."""
    img = Image.new("RGB", (sw, sh))
    d = ImageDraw.Draw(img)
    top, bottom = (196, 186, 226), (232, 214, 226)
    for y in range(sh):
        f = y / max(1, sh - 1)
        d.line([(0, y), (sw, y)], fill=tuple(round(a + (b - a) * f) for a, b in zip(top, bottom)))
    ax, ay, aw, ah = area
    # Taskbar: whatever the critters' area leaves at the bottom of the screen.
    if ay + ah < sh:
        d.rectangle([0, ay + ah, sw, sh], fill=(32, 32, 40))
        for i in range(5):
            cx = sw // 2 - 100 + i * 50
            d.rounded_rectangle([cx - 14, ay + ah + 10, cx + 14, sh - 10], 6, fill=(78, 78, 96))
    # A document window, left of centre, so critters have room on the right.
    x0, y0 = int(sw * 0.12), int(sh * 0.08)
    x1, y1 = int(sw * 0.66), int(ay + ah - sh * 0.08)
    d.rounded_rectangle([x0 + 6, y0 + 8, x1 + 6, y1 + 8], 10, fill=(150, 140, 170))
    d.rounded_rectangle([x0, y0, x1, y1], 10, fill=(252, 252, 253))
    d.rounded_rectangle([x0, y0, x1, y0 + 44], 10, fill=(240, 239, 244))
    d.rectangle([x0, y0 + 30, x1, y0 + 44], fill=(240, 239, 244))
    for i, c in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        d.ellipse([x1 - 130 + i * 38, y0 + 14, x1 - 114 + i * 38, y0 + 30], fill=c)
    y = y0 + 90
    d.rounded_rectangle([x0 + 60, y, x0 + 60 + int((x1 - x0) * 0.45), y + 22], 6, fill=(60, 60, 72))
    y += 60
    widths = [0.82, 0.86, 0.79, 0.6, 0, 0.84, 0.81, 0.88, 0.7, 0, 0.83, 0.77, 0.85, 0.5]
    for wf in widths:
        if wf:
            d.rounded_rectangle([x0 + 60, y, x0 + 60 + int((x1 - x0 - 120) * wf), y + 12], 5, fill=(196, 196, 206))
        y += 30 if wf else 24
        if y > y1 - 40:
            break
    return img


def paste_premultiplied(screen, im, x, y):
    """Godot hands back window pixels with colour already multiplied by alpha,
    so blend as src + dst * (1 - a); a plain paste darkens every soft edge."""
    src = np.asarray(im, dtype=np.float32)
    h, w = src.shape[:2]
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + w, screen.shape[1]), min(y + h, screen.shape[0])
    if x0 >= x1 or y0 >= y1:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    d = screen[y0:y1, x0:x1]
    d[:] = s[..., :3] + d * (1.0 - s[..., 3:] / 255.0)


def load_frames(cap):
    lines = (cap / "frames.jsonl").read_text(encoding="utf-8").splitlines()
    head = json.loads(lines[0])
    return head, [json.loads(l) for l in lines[1:] if l.strip()]


def font(size):
    for name in ("segoeuib.ttf", "seguisb.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("capture", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--layout", choices=["letterbox", "crop"], default="letterbox")
    ap.add_argument("--backdrop", type=Path)
    ap.add_argument("--caption", default="")
    ap.add_argument("--fps", type=float, default=30.0)
    ap.add_argument("--tight", type=float, default=1.0, help="crop height as a fraction of the screen's")
    ap.add_argument("--skip", type=int, default=15, help="frames dropped from the start (windows settling)")
    a = ap.parse_args()

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        sys.exit("ffmpeg is not on PATH")
    head, frames = load_frames(a.capture)
    sx, sy, sw, sh = head["screen"]
    area = head["area"]
    frames = frames[a.skip:]
    if not frames:
        sys.exit("no frames in the capture")

    back = Image.open(a.backdrop).convert("RGB").resize((sw, sh)) if a.backdrop else mock_backdrop(sw, sh, [area[0] - sx, area[1] - sy, area[2], area[3]])

    back_px = np.asarray(back, dtype=np.float32)

    enc = subprocess.Popen(
        [ffmpeg, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
         "-r", str(a.fps), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
         "-movflags", "+faststart", str(a.out)],
        stdin=subprocess.PIPE)

    # Crop: a 9:16 window, its centre easing after one critter (the one nearest
    # the camera, so it stays on a subject) so the camera drifts, not jumps.
    ch = round(sh * min(max(a.tight, 0.2), 1.0))
    cw = round(ch * 9 / 16)
    cam = None
    cap_font = font(64)
    for fr in frames:
        buf = back_px.copy()
        pts = []
        for w in fr["wins"]:
            im = Image.open(a.capture / w["png"]).convert("RGBA")
            x, y = w["x"] - sx, w["y"] - sy
            paste_premultiplied(buf, im, x, y)
            pts.append((x + im.width / 2, y + im.height / 2))
        screen = Image.fromarray(np.clip(buf, 0, 255).astype(np.uint8))
        canvas = Image.new("RGB", (W, H), (24, 22, 30))
        if a.layout == "letterbox":
            th = round(sh * W / sw)
            top = (H - th) // 2
            canvas.paste(screen.resize((W, th), Image.LANCZOS), (0, top))
            if a.caption:
                d = ImageDraw.Draw(canvas)
                d.multiline_text((W / 2, top / 2), a.caption, font=cap_font, fill=(255, 255, 255), anchor="mm", align="center", spacing=12)
        else:
            if pts:
                want = pts[0] if cam is None else min(pts, key=lambda p: (p[0] - cam[0]) ** 2 + (p[1] - cam[1]) ** 2)
            else:
                want = cam or (sw / 2, sh / 2)
            cam = want if cam is None else (cam[0] + (want[0] - cam[0]) * 0.06, cam[1] + (want[1] - cam[1]) * 0.06)
            left = int(min(max(cam[0] - cw / 2, 0), sw - cw))
            top = int(min(max(cam[1] - ch / 2, 0), sh - ch))
            canvas = screen.crop((left, top, left + cw, top + ch)).resize((W, H), Image.LANCZOS)
        enc.stdin.write(canvas.tobytes())
    enc.stdin.close()
    if enc.wait():
        sys.exit("ffmpeg failed")
    print(f"{a.out}: {len(frames)} frames, {len(frames) / a.fps:.1f} s")


if __name__ == "__main__":
    main()
