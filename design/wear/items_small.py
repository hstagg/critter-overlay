"""Small clothes (50 berries): clips, necklaces, glasses. Each draw(m) takes a
species' head metrics (build.py SPECIES) and returns the item's SVG."""
import math

from common import LINE, W, svg, top, star, heart, clip_at, neck_arc


def heart_clip(m):
    x, y = clip_at(m, 1)
    return svg(heart(x, y, 13, "#F590B4") + f'<circle cx="{x - 5:.1f}" cy="{y - 4:.1f}" r="2.6" fill="#FFFFFF" opacity="0.8"/>')


def star_clip(m):
    x, y = clip_at(m, -1)
    return svg(star(x, y, 15, "#FFD84D", rot=-12) + f'<circle cx="{x - 3:.1f}" cy="{y - 3:.1f}" r="2" fill="#FFFFFF" opacity="0.8"/>')


def cherry_clip(m):
    x, y = clip_at(m, 1)
    return svg(f'<path d="M{x - 9:.1f} {y + 6:.1f} Q {x - 4:.1f} {y - 16:.1f} {x + 4:.1f} {y - 20:.1f} M{x + 9:.1f} {y + 8:.1f} Q {x + 8:.1f} {y - 10:.1f} {x + 4:.1f} {y - 20:.1f}" stroke="{LINE}" stroke-width="{W + 1}" fill="none" stroke-linecap="round"/>'
               f'<path d="M{x - 9:.1f} {y + 6:.1f} Q {x - 4:.1f} {y - 16:.1f} {x + 4:.1f} {y - 20:.1f} M{x + 9:.1f} {y + 8:.1f} Q {x + 8:.1f} {y - 10:.1f} {x + 4:.1f} {y - 20:.1f}" stroke="#6CC27A" stroke-width="3" fill="none" stroke-linecap="round"/>'
               f'<path d="M{x + 4:.1f} {y - 20:.1f} q 10 -6 16 0 q -8 6 -16 0 Z" fill="#6CC27A" stroke="{LINE}" stroke-width="3"/>'
               f'<circle cx="{x - 10:.1f}" cy="{y + 12:.1f}" r="10" fill="#E4505C" stroke="{LINE}" stroke-width="{W}"/>'
               f'<circle cx="{x + 10:.1f}" cy="{y + 14:.1f}" r="10" fill="#E4505C" stroke="{LINE}" stroke-width="{W}"/>'
               f'<circle cx="{x - 13:.1f}" cy="{y + 8:.1f}" r="2.6" fill="#FFB3BA"/><circle cx="{x + 7:.1f}" cy="{y + 10:.1f}" r="2.6" fill="#FFB3BA"/>')


def leaf_sprig(m):
    # Three leaves on a twig, tucked in on the left.
    x, y = clip_at(m, -1, 0.38)
    leaves = "".join(
        f'<ellipse cx="{x + 13 * math.cos(math.radians(a)):.1f}" cy="{y + 13 * math.sin(math.radians(a)):.1f}" rx="13" ry="6.5" '
        f'transform="rotate({a} {x + 13 * math.cos(math.radians(a)):.1f} {y + 13 * math.sin(math.radians(a)):.1f})" fill="#7FCF86" stroke="{LINE}" stroke-width="3"/>'
        f'<path d="M{x:.1f} {y:.1f} l {20 * math.cos(math.radians(a)):.1f} {20 * math.sin(math.radians(a)):.1f}" stroke="#4FA35C" stroke-width="2" stroke-linecap="round"/>'
        for a in (-150, -90, -30))
    return svg(leaves + f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4.5" fill="#A0703F" stroke="{LINE}" stroke-width="2"/>')


def _beads(m, colours, r=6.5, n=9, sag=18):
    cx, y = m["cx"], m["chin"] - 4
    half = m["rx"] * 0.52
    out = ""
    for i in range(n):
        f = i / (n - 1)
        x = cx - half + 2 * half * f
        yy = y - 6 + sag * (1 - (2 * f - 1) ** 2)
        out += f'<circle cx="{x:.1f}" cy="{yy:.1f}" r="{r}" fill="{colours[i % len(colours)]}" stroke="{LINE}" stroke-width="3"/>'
        out += f'<circle cx="{x - r * 0.35:.1f}" cy="{yy - r * 0.35:.1f}" r="{r * 0.3:.1f}" fill="#FFFFFF" opacity="0.8"/>'
    return out


def pearl_necklace(m):
    return svg(_beads(m, ["#FBF7F0"], 6, 11, 16))


def bead_necklace(m):
    return svg(_beads(m, ["#F590B4", "#FFCF5C", "#7FBCF5", "#86D9B0", "#C8A8FF"], 7, 9, 18))


def _two_lenses(m, lens, extra=""):
    y = m["eye_y"]
    r = m["eye_r"] + 9
    lx, rx_ = m["cx"] - m["eye_dx"], m["cx"] + m["eye_dx"]
    arms = (f'<path d="M{lx - r:.1f} {y - 4} L {m["cx"] - m["rx"] + 6:.1f} {y - 10}" stroke="{LINE}" stroke-width="{W}" stroke-linecap="round"/>'
            f'<path d="M{rx_ + r:.1f} {y - 4} L {m["cx"] + m["rx"] - 6:.1f} {y - 10}" stroke="{LINE}" stroke-width="{W}" stroke-linecap="round"/>')
    bridge = f'<path d="M{lx + r - 2:.1f} {y - 2} Q {m["cx"]} {y - 10} {rx_ - r + 2:.1f} {y - 2}" stroke="{LINE}" stroke-width="{W}" fill="none" stroke-linecap="round"/>'
    return svg(arms + bridge + lens(lx, y, r) + lens(rx_, y, r) + extra)


def sunglasses(m):
    return _two_lenses(m, lambda x, y, r: (
        f'<path d="M{x - r:.1f} {y - r * 0.6:.1f} H {x + r:.1f} Q {x + r:.1f} {y + r:.1f} {x:.1f} {y + r * 0.9:.1f} Q {x - r:.1f} {y + r:.1f} {x - r:.1f} {y - r * 0.6:.1f} Z" fill="#2B2330" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
        f'<path d="M{x - r * 0.6:.1f} {y - r * 0.25:.1f} l {r * 0.5:.1f} 0" stroke="#7A6E85" stroke-width="4" stroke-linecap="round"/>'))


def heart_glasses(m):
    return _two_lenses(m, lambda x, y, r: heart(x, y - 2, r * 0.95, "#F590B4", opacity=0.85)
                       + f'<circle cx="{x - r * 0.4:.1f}" cy="{y - r * 0.4:.1f}" r="3" fill="#FFFFFF" opacity="0.8"/>')


def monocle(m):
    y = m["eye_y"]
    r = m["eye_r"] + 8
    x = m["cx"] + m["eye_dx"]
    return svg(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#DDEEFF" fill-opacity="0.35" stroke="#D9961A" stroke-width="{W + 1}"/>'
               f'<circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="{LINE}" stroke-width="1.5"/>'
               f'<path d="M{x + r * 0.5:.1f} {y + r * 0.85:.1f} q 10 30 -6 54" stroke="#D9961A" stroke-width="3" fill="none" stroke-dasharray="4 3" stroke-linecap="round"/>'
               f'<path d="M{x - r * 0.45:.1f} {y - r * 0.5:.1f} q {r * 0.25:.1f} {-r * 0.2:.1f} {r * 0.5:.1f} {-r * 0.12:.1f}" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>')


def plaster(m):
    x = m["cx"] - m["rx"] * 0.3
    y = top(m, x) + 22
    def strip(rot):
        return (f'<g transform="rotate({rot} {x:.1f} {y:.1f})"><rect x="{x - 22:.1f}" y="{y - 7:.1f}" width="44" height="14" rx="7" fill="#F7D3B0" stroke="{LINE}" stroke-width="3"/>'
                f'<rect x="{x - 7:.1f}" y="{y - 6:.1f}" width="14" height="12" fill="#EEC09A"/>'
                + "".join(f'<circle cx="{x + dx:.1f}" cy="{y + dy:.1f}" r="1.2" fill="#C99A72"/>' for dx in (-15, 15) for dy in (-2, 2)) + '</g>')
    return svg(strip(35) + strip(-35))


def rose_clip(m):
    x, y = clip_at(m, -1)
    return svg(f'<path d="M{x - 6:.1f} {y + 8:.1f} q -16 4 -18 -6 q 10 -4 18 6 Z M{x + 6:.1f} {y + 8:.1f} q 16 4 18 -6 q -10 -4 -18 6 Z" fill="#6CC27A" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
               f'<circle cx="{x:.1f}" cy="{y:.1f}" r="13" fill="#E4505C" stroke="{LINE}" stroke-width="{W}"/>'
               f'<path d="M{x - 6:.1f} {y + 2:.1f} q 0 -9 7 -9 q 7 1 5 7 q -2 5 -7 3 q -3 -2 -1 -4" stroke="#A62A3C" stroke-width="2.5" fill="none" stroke-linecap="round"/>')


def feather_clip(m):
    x, y = clip_at(m, 1)
    return svg(f'<g transform="rotate(28 {x:.1f} {y:.1f})">'
               f'<path d="M{x:.1f} {y + 4:.1f} C {x - 14:.1f} {y - 10:.1f} {x - 10:.1f} {y - 34:.1f} {x:.1f} {y - 46:.1f} C {x + 10:.1f} {y - 34:.1f} {x + 14:.1f} {y - 10:.1f} {x:.1f} {y + 4:.1f} Z" fill="#7FBCF5" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
               f'<path d="M{x:.1f} {y + 8:.1f} L {x:.1f} {y - 40:.1f}" stroke="{LINE}" stroke-width="2.5" stroke-linecap="round"/>'
               + "".join(f'<path d="M{x:.1f} {y - k:.1f} l {s * 8} -6" stroke="#4F8FD0" stroke-width="2" stroke-linecap="round"/>' for k in (8, 16, 24, 32) for s in (-1, 1))
               + f'<circle cx="{x:.1f}" cy="{y + 6:.1f}" r="5" fill="#FFCF5C" stroke="{LINE}" stroke-width="2.5"/></g>')


def heart_tag(m):
    cx, y = m["cx"], m["chin"] - 6
    return svg(neck_arc(m, "#7C4DD6", 10) + heart(cx, y + 18, 11, "#FFCF5C")
               + f'<circle cx="{cx}" cy="{y + 9}" r="3" fill="none" stroke="{LINE}" stroke-width="2.5"/>')


def clover_clip(m):
    x, y = clip_at(m, -1)
    leaves = "".join(heart(x + 9 * math.cos(math.radians(a)), y + 9 * math.sin(math.radians(a)), 8, "#6CC27A", rot=a + 90) for a in (-90, 0, 90, 180))
    return svg(f'<path d="M{x:.1f} {y:.1f} q 6 10 2 18" stroke="{LINE}" stroke-width="4" fill="none" stroke-linecap="round"/>' + leaves
               + f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3" fill="#4FA35C"/>')


# --- one species --------------------------------------------------------------

def fish_clip(m):
    # Kitten: a little blue fish clip.
    x, y = clip_at(m, 1)
    return svg(f'<g transform="rotate(-20 {x:.1f} {y:.1f})">'
               f'<path d="M{x - 16:.1f} {y:.1f} C {x - 8:.1f} {y - 12:.1f} {x + 8:.1f} {y - 12:.1f} {x + 14:.1f} {y:.1f} C {x + 8:.1f} {y + 12:.1f} {x - 8:.1f} {y + 12:.1f} {x - 16:.1f} {y:.1f} Z" fill="#7FBCF5" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round"/>'
               f'<path d="M{x + 12:.1f} {y:.1f} l 12 -10 l 0 20 Z" fill="#7FBCF5" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>'
               f'<circle cx="{x - 8:.1f}" cy="{y - 2:.1f}" r="2.6" fill="{LINE}"/></g>')


def lily_pad(m):
    # Duckling: a lily pad worn as a hat, with a pink flower.
    cx = m["cx"]
    y = top(m, cx) + 6
    pad = (f'<path d="M{cx:.1f} {y:.1f} L {cx + 10:.1f} {y - 16:.1f} A 40 16 0 1 1 {cx - 4:.1f} {y - 17:.1f} Z" fill="#6CC27A" stroke="{LINE}" stroke-width="{W}" stroke-linejoin="round" transform="translate(0 -4)"/>'
           f'<path d="M{cx - 24:.1f} {y - 18:.1f} q 12 -6 22 0 M{cx + 6:.1f} {y - 26:.1f} q 12 2 18 8" stroke="#4FA35C" stroke-width="2.5" fill="none" stroke-linecap="round"/>')
    fx, fy = cx + 18, y - 26
    flower = "".join(f'<ellipse cx="{fx + 7 * math.cos(math.radians(a)):.1f}" cy="{fy + 5 * math.sin(math.radians(a)):.1f}" rx="7" ry="5" fill="#F7A8C4" stroke="{LINE}" stroke-width="2.5"/>' for a in range(0, 360, 72))
    return svg(pad + flower + f'<circle cx="{fx}" cy="{fy}" r="4" fill="#FFD84D" stroke="{LINE}" stroke-width="2"/>')


ITEMS = {
    "heart_clip": (heart_clip, "Heart clip", "head", "small"),
    "star_clip": (star_clip, "Star clip", "head", "small"),
    "cherry_clip": (cherry_clip, "Cherry clip", "head", "small"),
    "leaf_sprig": (leaf_sprig, "Leaf sprig", "head", "small"),
    "pearl_necklace": (pearl_necklace, "Pearl necklace", "neck", "small"),
    "bead_necklace": (bead_necklace, "Bead necklace", "neck", "small"),
    "sunglasses": (sunglasses, "Sunglasses", "face", "small"),
    "heart_glasses": (heart_glasses, "Heart glasses", "face", "small"),
    "monocle": (monocle, "Monocle", "face", "small"),
    "plaster": (plaster, "Plaster", "head", "small"),
    "rose_clip": (rose_clip, "Rose clip", "head", "small"),
    "feather_clip": (feather_clip, "Feather clip", "head", "small"),
    "heart_tag": (heart_tag, "Heart tag collar", "neck", "small"),
    "clover_clip": (clover_clip, "Clover clip", "head", "small"),
    "fish_clip": (fish_clip, "Fish clip", "head", "small", "kitten"),
    "lily_pad": (lily_pad, "Lily pad hat", "head", "small", "duckling"),
}
