import re, pathlib
from theme import THEME_CSS, TIERS_HEX, SP_HEX

SCR = pathlib.Path(r"C:/Users/harry/AppData/Local/Temp/claude/C--Users-harry-OneDrive-Documents-Second-Brain/c2bc2064-940e-4063-91b7-01d67eed348e/scratchpad")
CAST = (SCR / "artifact-files/6d837b9a-4e4d-470e-9a29-c5e3c6617246/project/Cast.dc.html").read_text(encoding="utf-8")

# ---------------------------------------------------------------- critter art
def _clean(s):
    s = re.sub(r'\s*class="anim [a-z]+"', '', s)
    s = re.sub(r'\s*style="animation-delay: [0-9.]+s"', '', s)
    return s.strip()

kit_body = re.search(r'<g id="c-kitten">(.*?)</g>\s*<g id="c-kitten-eyes">', CAST, re.S).group(1).strip()
kit_eyes = re.search(r'<g id="c-kitten-eyes">(.*?)</g>', CAST, re.S).group(1).strip()

LABELS = {"Rabbit": "rabbit", "Duckling": "duckling", "Turtle": "turtle", "Hedgehog": "hedgehog",
          "Squirrel with an acorn": "squirrel", "Otter holding a pebble": "otter", "Panda": "panda",
          "Unicorn": "unicorn"}
ART = {"kitten": kit_body + kit_eyes}
for m in re.finditer(r'<svg viewBox="20 0 270 280" width="212" height="220" role="img" aria-label="([^"]+)"><g class="anim breathe">(.*?)</g></svg>', CAST, re.S):
    lab, inner = m.group(1), m.group(2)
    if lab in LABELS:
        ART[LABELS[lab]] = _clean(inner)

gold = kit_body.replace("#F6C28F", "#F9D66B").replace("#E89A5B", "#E3A72F").replace("#FFF1E2", "#FFF8DD")
sparkles = ('<path d="M58 60 l4 10 l10 4 l-10 4 l-4 10 l-4 -10 l-10 -4 l10 -4 Z" fill="#FFD84D" stroke="#B8860B" stroke-width="1.5"/>'
            '<path d="M252 110 l3 8 l8 3 l-8 3 l-3 8 l-3 -8 l-8 -3 l8 -3 Z" fill="#FFD84D" stroke="#B8860B" stroke-width="1.5"/>'
            '<path d="M244 30 l2.5 6 l6 2.5 l-6 2.5 l-2.5 6 l-2.5 -6 l-6 -2.5 l6 -2.5 Z" fill="#FFD84D" stroke="#B8860B" stroke-width="1.5"/>')
ART["golden"] = gold + kit_eyes + sparkles
closed = '<path d="M97 126 q15 11 30 0 M173 126 q15 11 30 0" stroke="#2B2330" stroke-width="5" fill="none" stroke-linecap="round"/>'
ART["kitten_sleep"] = kit_body + closed

DEFS = ('<svg width="0" height="0" style="position: absolute" aria-hidden="true"><defs>'
        + "".join(f'<g id="cr-{k}">{v}</g>' for k, v in ART.items()) + '</defs></svg>')

SPECIES = [  # id, name, tint, gait
    ("kitten", "Kitten", "var(--sp-kitten)", "pounce-pause"),
    ("rabbit", "Rabbit", "var(--sp-rabbit)", "hop"),
    ("duckling", "Duckling", "var(--sp-duckling)", "waddle"),
    ("turtle", "Turtle", "var(--sp-turtle)", "plod"),
    ("hedgehog", "Hedgehog", "var(--sp-hedgehog)", "snuffle"),
    ("squirrel", "Squirrel", "var(--sp-squirrel)", "dart and freeze"),
    ("otter", "Otter", "var(--sp-otter)", "belly slide"),
    ("panda", "Panda", "var(--sp-panda)", "lumber"),
]
SPECIALS = [("unicorn", "Unicorn", "var(--sp-unicorn)"), ("golden", "Golden kitten", "var(--sp-golden)")]
TINT = {s[0]: s[2] for s in SPECIES}
TINT.update({s[0]: s[2] for s in SPECIALS})

def critter(cid, w, label=None, style=""):
    h = round(w * 280 / 270)
    lab = label or cid
    st = f' style="{style}"' if style else ""
    return f'<svg viewBox="20 0 270 280" width="{w}" height="{h}" role="img" aria-label="{lab}"{st}><use href="#cr-{cid}"/></svg>'

def kit_head(w, sleep=False):
    h = round(w * 182 / 200)
    cid = "kitten_sleep" if sleep else "kitten"
    return f'<svg viewBox="50 20 200 182" width="{w}" height="{h}" aria-hidden="true"><use href="#cr-{cid}"/></svg>'

# ---------------------------------------------------------------- icons
ICONS = {
    "home": '<path d="M4 11.5 12 5l8 6.5V19a1 1 0 0 1-1 1h-4.5v-5h-5v5H5a1 1 0 0 1-1-1z"/>',
    "paw": '<circle cx="6.5" cy="10" r="1.8"/><circle cx="10" cy="6" r="1.8"/><circle cx="14.5" cy="6" r="1.8"/><circle cx="18" cy="10" r="1.8"/><path d="M7.5 17.5c0-3 2.2-5.5 4.5-5.5s4.5 2.5 4.5 5.5c0 1.8-1.5 2.3-2.8 2-1.1-.3-2.3-.3-3.4 0-1.3.3-2.8-.2-2.8-2z"/>',
    "mug": '<path d="M5 9h11v6a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4z"/><path d="M16 11h1.5a2.5 2.5 0 0 1 0 5H16"/><path d="M8.5 3.5c0 1.2 1 1.3 1 2.5M12.5 3.5c0 1.2 1 1.3 1 2.5"/>',
    "leaf": '<path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14z"/><path d="M5 19 13 11"/>',
    "sound": '<path d="M4 10v4h3l5 4V6L7 10z"/><path d="M15.5 9.5a3.5 3.5 0 0 1 0 5M18 7a7 7 0 0 1 0 10"/>',
    "mute": '<path d="M4 10v4h3l5 4V6L7 10z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
    "star": '<path d="M12 4.5l2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5-3.6-3.5 5-.7z"/>',
    "sliders": '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
    "play": '<path d="M8 5.5v13l10-6.5z" fill="currentColor"/>',
    "pause": '<path d="M9 6v12M15 6v12"/>',
    "sparkle": '<path d="M12 3.5l1.8 5.2 5.2 1.8-5.2 1.8L12 17.5l-1.8-5.2L5 10.5l5.2-1.8z"/><path d="M18.5 16v4M16.5 18h4"/>',
    "close": '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
    "min": '<path d="M6 12h12"/>',
    "plus": '<path d="M12 5.5v13M5.5 12h13"/>',
    "minus": '<path d="M5.5 12h13"/>',
    "moon": '<path d="M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z"/>',
    "info": '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>',
    "clock": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    "power": '<path d="M12 4v8"/><path d="M7.2 7.2a7 7 0 1 0 9.6 0"/>',
    "reset": '<path d="M5 12a7 7 0 1 0 2-4.9"/><path d="M5 4v4h4"/>',
    "update": '<path d="M12 4v11M7.5 10.5 12 15l4.5-4.5M5 20h14"/>',
    "chev": '<path d="M9 6l6 6-6 6"/>',
    "chevd": '<path d="M6 9l6 6 6-6"/>',
    "arrow": '<path d="M5 12h14M13 6l6 6-6 6"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "lock": '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>',
    "keyboard": '<rect x="3" y="6.5" width="18" height="11" rx="2.5"/><path d="M7 10.5h.01M10.5 10.5h.01M14 10.5h.01M17 10.5h.01M8 14h8"/>',
    "monitor": '<rect x="3" y="4.5" width="18" height="12" rx="2.5"/><path d="M9 20h6M12 16.5V20"/>',
    "box": '<path d="M4 8l8-4 8 4v8l-8 4-8-4z"/><path d="M4 8l8 4 8-4M12 12v8"/>',
    "help": '<circle cx="12" cy="12" r="8.5"/><path d="M9.6 9.5a2.5 2.5 0 0 1 4.8 1c0 1.7-2.4 2-2.4 3.5M12 17h.01"/>',
    "heart": '<path d="M12 19s-7-4.4-7-9.5A3.8 3.8 0 0 1 12 7.5a3.8 3.8 0 0 1 7 2C19 14.6 12 19 12 19z"/>',
    "trash": '<path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/>',
    "calendar": '<rect x="4" y="5.5" width="16" height="14" rx="2.5"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4"/>',
    "eye": '<path d="M3 12s3.3-6 9-6 9 6 9 6-3.3 6-9 6-9-6-9-6z"/><circle cx="12" cy="12" r="2.5"/>',
    "link": '<path d="M14 5h5v5M19 5l-8 8M17 14v4a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 5 18V8.5A1.5 1.5 0 0 1 6.5 7H10"/>',
}

def icon(name, size=20, color="currentColor", sw=2):
    return (f'<svg viewBox="0 0 24 24" width="{size}" height="{size}" fill="none" stroke-width="{sw}" '
            f'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="flex-shrink: 0; stroke: {color}">{ICONS[name]}</svg>')

# ---------------------------------------------------------------- rarity
TIERS = [(k, n, f, f"var(--t-{k}-tint)", f"var(--t-{k}-ink)") for k, n, f, *_ in TIERS_HEX]
T = {t[0]: t for t in TIERS}
TIER_SHAPE = {
    "common": '<circle cx="10" cy="10" r="6.5"/>',
    "uncommon": '<path d="M10 3c4 3.2 5.6 6.2 5.6 8.6a5.6 5.6 0 0 1-11.2 0C4.4 9.2 6 6.2 10 3z"/>',
    "rare": '<path d="M10 2.5 16.8 10 10 17.5 3.2 10z"/>',
    "epic": '<path d="M10 2.4l2.3 4.8 5.2.6-3.9 3.6 1.1 5.2L10 14l-4.7 2.6 1.1-5.2-3.9-3.6 5.2-.6z"/>',
    "legendary": '<path d="M3 15.5h14l1.2-9.2-4.6 3.6L10 3.8 6.4 9.9 1.8 6.3z"/>',
}

def badge(tier, size=20, ghost=False):
    if ghost:
        return (f'<svg viewBox="0 0 20 20" width="{size}" height="{size}" aria-hidden="true" style="flex-shrink: 0">'
                f'<g stroke-width="1.6" stroke-dasharray="2.2 2" stroke-linejoin="round" style="fill: var(--surface); stroke: var(--dash)">{TIER_SHAPE[tier]}</g></svg>')
    return (f'<svg viewBox="0 0 20 20" width="{size}" height="{size}" aria-hidden="true" style="flex-shrink: 0">'
            f'<g fill="{T[tier][2]}" stroke-width="1.6" stroke-linejoin="round" style="stroke: var(--badge-line)">{TIER_SHAPE[tier]}</g></svg>')

def tier_chip(tier, text=None):
    _, name, fill, tint, ink = T[tier]
    return (f'<span style="display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 10px 0 7px; border-radius: 13px; '
            f'background: {tint}; color: {ink}; font-weight: 800; font-size: 12.5px; white-space: nowrap">{badge(tier, 16)}{text or name}</span>')

# ---------------------------------------------------------------- css
FONTS = '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600;700&amp;family=Nunito:wght@400;600;700;800&amp;display=swap">'
CSS = THEME_CSS + """
body{margin:0;font-family:'Nunito',system-ui,sans-serif;color:var(--ink);background:var(--ground)}
a{color:var(--acc-ink)}a:hover{color:var(--acc-ink-h)}
button{font-family:'Nunito',system-ui,sans-serif}
.disp{font-family:'Fredoka','Nunito',sans-serif}
.h1{margin:0;font-family:'Fredoka','Nunito',sans-serif;font-weight:600;font-size:32px;line-height:1.1;color:var(--ink)}
.sub{margin:6px 0 0;font-size:15px;line-height:1.45;color:var(--ink2);max-width:560px}
.lbl{font-family:'Fredoka','Nunito',sans-serif;font-weight:500;font-size:13px;letter-spacing:.08em;text-transform:uppercase;color:var(--acc-ink);margin:0 0 10px 6px}
.card{background:var(--surface);border:2px solid var(--line);border-radius:20px;box-sizing:border-box}
.row{display:flex;align-items:center;gap:24px;padding:16px 20px}
.row + .row{border-top:2px solid var(--div)}
.rt{flex:1;min-width:0}
.rtt{font-weight:800;font-size:15px;color:var(--ink);display:flex;align-items:center;gap:6px}
.rtd{font-size:13px;line-height:1.45;color:var(--ink2);margin-top:3px}
.val{font-family:'Fredoka','Nunito',sans-serif;font-weight:600;font-size:16px;color:var(--acc-ink);white-space:nowrap}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;height:40px;padding:0 16px;border-radius:14px;font-weight:800;font-size:14px;cursor:pointer;box-sizing:border-box;white-space:nowrap;text-decoration:none}
.bp{background:var(--btn);color:var(--btn-ink);border:2px solid var(--btn-lip);box-shadow:0 3px 0 var(--btn-lip)}
.bs{background:var(--raised);color:var(--ink);border:2px solid var(--sec-line);box-shadow:0 2px 0 var(--sec-line)}
.bq{background:transparent;color:var(--ink2);border:2px solid transparent}
.bd{background:var(--dng-bg);color:var(--dng-ink);border:2px solid var(--dng-line);box-shadow:0 2px 0 var(--dng-line)}
.bx{background:var(--ph-bg);color:var(--ph-ink);border:2px dashed var(--dash);cursor:default}
.sm{height:34px;padding:0 12px;font-size:13px;border-radius:12px}
.tg{width:48px;height:28px;border-radius:14px;border:2px solid var(--outline);position:relative;box-sizing:border-box;flex-shrink:0;padding:0;cursor:pointer}
.tg.on{background:var(--accent)}
.tg.off{background:var(--track);border-color:var(--off-line)}
.kn{position:absolute;top:2px;width:20px;height:20px;border-radius:10px;background:var(--knob);border:2px solid var(--outline);box-sizing:border-box}
.tg.on .kn{left:22px}.tg.off .kn{left:2px;border-color:var(--off-line)}
.seg{display:inline-flex;background:var(--track);border-radius:14px;padding:4px;gap:2px;flex-shrink:0}
.seg button{height:32px;padding:0 13px;border:2px solid transparent;border-radius:11px;background:transparent;font-weight:800;font-size:13px;color:var(--ink2);cursor:pointer;white-space:nowrap}
.seg button.sel{background:var(--raised);border-color:var(--outline);color:var(--ink);box-shadow:0 2px 0 var(--lip)}
.rng{-webkit-appearance:none;appearance:none;width:100%;height:10px;border-radius:5px;margin:0;background:var(--line);display:block}
.rng::-webkit-slider-thumb{-webkit-appearance:none;appearance:none;width:24px;height:24px;border-radius:12px;background:var(--knob);border:3px solid var(--outline);box-shadow:0 2px 0 var(--lip);cursor:pointer}
.rng::-moz-range-thumb{width:18px;height:18px;border-radius:12px;background:var(--knob);border:3px solid var(--outline)}
.ticks{display:flex;justify-content:space-between;font-size:11.5px;color:var(--ink3);margin-top:8px}
.ticks .on{color:var(--acc-ink);font-weight:800}
.chip{display:inline-flex;align-items:center;gap:6px;height:32px;padding:0 12px;border-radius:16px;border:2px solid var(--chip-line);background:var(--raised);font-weight:700;font-size:13px;color:var(--ink-body);cursor:pointer;white-space:nowrap}
.chip.sel{border-color:var(--outline);background:var(--chip-sel);color:var(--ink);box-shadow:0 2px 0 var(--lip)}
.kbd{display:inline-flex;align-items:center;justify-content:center;min-width:30px;height:30px;padding:0 9px;border-radius:9px;background:var(--raised);border:2px solid var(--sec-line);box-shadow:0 2px 0 var(--sec-line);font-weight:800;font-size:13px;color:var(--ink);box-sizing:border-box}
.ib{width:36px;height:36px;border-radius:12px;border:2px solid var(--sec-line);background:var(--raised);box-shadow:0 2px 0 var(--sec-line);display:inline-flex;align-items:center;justify-content:center;color:var(--outline);cursor:pointer;padding:0;flex-shrink:0}
.info{display:inline-flex;color:var(--ink3);background:none;border:0;padding:0;cursor:help}
.dd{display:inline-flex;align-items:center;justify-content:space-between;gap:10px;height:38px;padding:0 12px 0 14px;border-radius:12px;border:2px solid var(--sec-line);background:var(--raised);font-weight:800;font-size:14px;color:var(--ink);cursor:pointer;min-width:150px;box-sizing:border-box}
.nav{display:flex;align-items:center;gap:12px;height:44px;padding:0 14px;border-radius:14px;color:var(--ink2);font-weight:800;font-size:15px;text-decoration:none;border:2px solid transparent;box-sizing:border-box}
.nav:hover{background:var(--nav-h);color:var(--ink)}
.nav.act{background:var(--raised);border-color:var(--outline);color:var(--ink);box-shadow:0 2px 0 var(--lip)}
.wb{width:36px;height:32px;border-radius:10px;border:0;background:transparent;color:var(--ink2);display:inline-flex;align-items:center;justify-content:center;cursor:pointer;padding:0}
.wb:hover{background:var(--track)}
.sp{background:none;border:0;padding:2px 0;display:flex;flex-direction:column;align-items:center;gap:6px;font-weight:800;font-size:12px;color:var(--ink);cursor:pointer;text-align:center;line-height:1.2}
.pill{display:inline-flex;align-items:center;height:22px;padding:0 9px;border-radius:11px;font-weight:800;font-size:11.5px;white-space:nowrap}
.step{display:inline-flex;align-items:center;gap:0;border:2px solid var(--sec-line);border-radius:14px;background:var(--raised);height:40px;box-sizing:border-box;overflow:hidden;flex-shrink:0}
.step button{width:40px;height:36px;border:0;background:var(--ground);color:var(--outline);display:inline-flex;align-items:center;justify-content:center;cursor:pointer;padding:0}
.step span{min-width:96px;text-align:center;font-weight:800;font-size:14px}
"""

def head(title, extra_css=""):
    return (f'<!doctype html>\n<html lang="en-GB">\n<head>\n<meta charset="utf-8">\n<title>{title}</title>\n'
            f'<script src="./support.js"></script>\n</head>\n<body>\n<x-dc>\n<helmet>\n{FONTS}\n<style>{CSS}{extra_css}</style>\n</helmet>\n')

def foot(w, h):
    return ('\n</x-dc>\n<script type="text/x-dc" data-dc-script data-props=\'{"$preview":{"width":%d,"height":%d}}\'>\n'
            'class Component extends DCLogic {\nrenderVals() {\nreturn {};\n}\n}\n</script>\n</body>\n</html>\n') % (w, h)

# ---------------------------------------------------------------- controls
def toggle(on, aria):
    c = "on" if on else "off"
    return f'<button class="tg {c}" role="switch" aria-checked="{"true" if on else "false"}" aria-label="{aria}"><span class="kn"></span></button>'

def seg(opts, sel, aria):
    b = "".join(f'<button class="{"sel" if i == sel else ""}" role="radio" aria-checked="{"true" if i == sel else "false"}">{o}</button>' for i, o in enumerate(opts))
    return f'<div class="seg" role="radiogroup" aria-label="{aria}">{b}</div>'

def fillbg(pct):
    return f"background: linear-gradient(to right, var(--accent) 0 {pct}%, var(--line) {pct}% 100%)"

def slider(pct, aria, lo=None, hi=None, width=300):
    s = f'<div style="width: {width}px; flex-shrink: 0"><input type="range" class="rng" min="0" max="100" value="{pct}" aria-label="{aria}" style="{fillbg(pct)}">'
    if lo is not None:
        s += f'<div class="ticks"><span>{lo}</span><span>{hi}</span></div>'
    return s + '</div>'

def stepped(labels, idx, aria, width=None):
    n = len(labels)
    pct = round(idx / (n - 1) * 100)
    w = f"width: {width}px; flex-shrink: 0" if width else "width: 100%"
    t = "".join(f'<span class="{"on" if i == idx else ""}">{l}</span>' for i, l in enumerate(labels))
    return (f'<div style="{w}"><input type="range" class="rng" min="0" max="{n-1}" step="1" value="{idx}" aria-label="{aria}" style="{fillbg(pct)}">'
            f'<div class="ticks">{t}</div></div>')

def info(tip):
    return f'<button class="info" aria-label="{tip}">{icon("info", 16)}</button>'

def row(title, desc, control, tip=None, pill=None, style=""):
    t = title + (info(tip) if tip else "") + (pill or "")
    d = f'<div class="rtd">{desc}</div>' if desc else ""
    st = f' style="{style}"' if style else ""
    return f'<div class="row"{st}><div class="rt"><div class="rtt">{t}</div>{d}</div>{control}</div>'

def valctl(ctl, val):
    return f'<div style="display: flex; align-items: center; gap: 16px; flex-shrink: 0">{ctl}<span class="val" style="width: 84px; text-align: right">{val}</span></div>'

def card(inner, style=""):
    return f'<div class="card" style="{style}">{inner}</div>'

def section(label, inner, note=None):
    n = f'<span style="font-family: Nunito, sans-serif; text-transform: none; letter-spacing: 0; font-weight: 700; color: var(--ink3); font-size: 13px; margin-left: 10px">{note}</span>' if note else ""
    return f'<section style="display: flex; flex-direction: column"><h2 class="lbl">{label}{n}</h2>{inner}</section>'

def btn(text, kind="bs", ic=None, extra="", aria=None, small=False):
    i = icon(ic, 18) if ic else ""
    a = f' aria-label="{aria}"' if aria else ""
    s = " sm" if small else ""
    return f'<button class="btn {kind}{s}"{a}{extra}>{i}{text}</button>'

def keys(*ks):
    plus = '<span style="color: var(--ink3); font-weight: 800">+</span>'
    return '<span style="display: inline-flex; align-items: center; gap: 6px">' + plus.join(f'<span class="kbd">{k}</span>' for k in ks) + '</span>'

def pill(text, bg, fg):
    return f'<span class="pill" style="background: {bg}; color: {fg}">{text}</span>'

SOON = pill("Coming soon", "var(--track)", "var(--acc-ink)")
NEW = pill("New", "var(--t-uncommon-tint)", "var(--t-uncommon-ink)")

# ---------------------------------------------------------------- window shell
NAV = [("home", "Home", "Main.dc.html", "home"),
       ("critters", "Critters", "Settings-Critters.dc.html", "paw"),
       ("focus", "Focus", "Settings-Focus.dc.html", "mug"),
       ("world", "World", "Settings-World.dc.html", "leaf"),
       ("sound", "Sound", "Settings-Sound.dc.html", "sound"),
       ("collection", "Collection", "Collection.dc.html", "star"),
       ("system", "System", "Settings-System.dc.html", "sliders")]

MODE = {"dark": False}
DARK_FILES = {"home": "Dark-Home.dc.html", "critters": "Dark-Critters.dc.html", "collection": "Dark-Collection.dc.html"}

def sidebar(active):
    items = ""
    for key, label, href, ic in NAV:
        if MODE["dark"] and key in DARK_FILES:
            href = DARK_FILES[key]
        cls = "nav act" if key == active else "nav"
        cur = ' aria-current="page"' if key == active else ""
        extra = ""
        if key == "collection":
            extra = '<span style="margin-left: auto; font-size: 12px; font-weight: 800; color: var(--t-legendary-ink); background: var(--t-legendary-tint); border-radius: 10px; padding: 2px 8px">21/40</span>'
        items += f'<a href="{href}" class="{cls}"{cur}>{icon(ic, 20)}<span>{label}</span>{extra}</a>'
    return f'''<aside style="width: 232px; flex-shrink: 0; background: var(--side); display: flex; flex-direction: column; gap: 18px; padding: 18px 14px 18px; box-sizing: border-box">
<div style="display: flex; align-items: center; gap: 10px; padding: 2px 6px">
<div style="width: 46px; height: 46px; border-radius: 15px; background: var(--surface); border: 2px solid var(--outline); box-shadow: 0 2px 0 var(--lip); display: flex; align-items: center; justify-content: center; overflow: hidden; flex-shrink: 0">{kit_head(40)}</div>
<div><div class="disp" style="font-weight: 600; font-size: 18px; line-height: 1.1">Critter Overlay</div><div style="font-size: 12px; color: var(--ink3); margin-top: 2px">Version 3.0</div></div>
</div>
<div style="background: var(--surface); border: 2px solid var(--line); border-radius: 18px; padding: 12px 14px; display: flex; flex-direction: column; gap: 7px">
<div style="display: flex; align-items: center; gap: 8px"><span style="width: 10px; height: 10px; border-radius: 50%; background: #4FB286; border: 3px solid var(--ok-ring); box-sizing: content-box; flex-shrink: 0"></span><span style="font-weight: 800; font-size: 14px">Gathering</span><span style="margin-left: auto; font-size: 12px; font-weight: 700; color: var(--ink2)">42 min</span></div>
<div style="font-size: 13px; color: var(--ink2)">6 of 8 critters out</div>
<div style="height: 8px; border-radius: 4px; background: var(--track)"><div style="width: 60%; height: 8px; border-radius: 4px; background: var(--accent)"></div></div>
<div style="font-size: 12px; color: var(--ink2)">Next critter in 3 min</div>
</div>
<nav aria-label="Settings sections" style="display: flex; flex-direction: column; gap: 4px">{items}</nav>
<div style="margin-top: auto; display: flex; flex-direction: column; gap: 8px">
<button class="btn bs" style="width: 100%">{icon("sparkle", 18)}Spawn now</button>
<button class="btn bs" style="width: 100%">{icon("pause", 18)}Pause critters</button>
</div>
</aside>'''

def window(active, title, subtitle, body, h, right=""):
    th = "th-dark" if MODE["dark"] else "th-light"
    return f'''<div class="{th}" style="width: 1100px; height: {h}px; display: flex; background: var(--ground); color: var(--ink); overflow: hidden">
{DEFS}
{sidebar(active)}
<main style="flex: 1; min-width: 0; display: flex; flex-direction: column">
<div style="height: 44px; flex-shrink: 0; display: flex; align-items: center; justify-content: flex-end; gap: 2px; padding: 0 10px">
<button class="wb" aria-label="Minimise">{icon("min", 18)}</button><button class="wb" aria-label="Close to tray">{icon("close", 18)}</button>
</div>
<div style="padding: 0 40px 40px; display: flex; flex-direction: column; gap: 26px">
<header style="display: flex; align-items: flex-end; justify-content: space-between; gap: 20px">
<div><h1 class="h1">{title}</h1><p class="sub">{subtitle}</p></div>{right}
</header>
{body}
</div>
</main>
</div>'''
