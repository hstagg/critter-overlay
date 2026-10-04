from parts import *

EXTRA = """
.mi{display:flex;align-items:center;gap:12px;width:100%;height:42px;padding:0 12px;border-radius:12px;border:0;background:transparent;font-weight:800;font-size:14.5px;cursor:pointer;text-align:left;box-sizing:border-box}
.h2{margin:0;font-family:'Fredoka','Nunito',sans-serif;font-weight:600;font-size:22px;color:var(--ink)}
.note{font-size:13.5px;line-height:1.5;color:var(--ink-body)}
table{border-collapse:collapse;width:100%}
th{font-family:'Fredoka','Nunito',sans-serif;font-weight:600;font-size:13px;letter-spacing:.06em;text-transform:uppercase;color:var(--acc-ink);text-align:left;padding:10px 12px;border-bottom:2px solid var(--line)}
td{font-size:13.5px;line-height:1.4;color:var(--ink);padding:8px 12px;border-bottom:1px solid var(--div);vertical-align:top}
td.g{color:var(--ink2);font-weight:700;white-space:nowrap}
tr.grp td{background:var(--div);font-weight:800;color:var(--outline);font-size:12.5px;letter-spacing:.04em;text-transform:uppercase}
"""

# ============================================================ TRAY
def tray_icon(state, size):
    fur = "#D8CFC6" if state == "paused" else "#F6C28F"
    if state == "napping":
        eyes = '<path d="M8.8 18.2q2.6 2.2 5.2 0M18 18.2q2.6 2.2 5.2 0" stroke="#2B2330" stroke-width="2" fill="none" stroke-linecap="round"/>'
    else:
        eyes = '<circle cx="11.4" cy="18" r="2.4" fill="#2B2330"/><circle cx="20.6" cy="18" r="2.4" fill="#2B2330"/>'
    badge_ = ""
    if state == "paused":
        badge_ = '<circle cx="25" cy="25" r="6.5" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="1.8"/><path d="M23 22.4v5.2M27 22.4v5.2" stroke="#6B4A3A" stroke-width="1.9" stroke-linecap="round"/>'
    if state == "napping":
        badge_ = '<circle cx="25" cy="7" r="6" fill="#E6EEF3" stroke="#6B4A3A" stroke-width="1.6"/><path d="M22.6 4.6h4.6l-4.6 4.8h4.6" stroke="#3E5670" stroke-width="1.7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    blush = "" if state == "paused" else '<ellipse cx="8.4" cy="22.4" rx="2.1" ry="1.3" fill="#F59C9C"/><ellipse cx="23.6" cy="22.4" rx="2.1" ry="1.3" fill="#F59C9C"/>'
    return (f'<svg viewBox="0 0 32 32" width="{size}" height="{size}" role="img" aria-label="Tray icon, {state}">'
            f'<path d="M5.5 15 6.6 4.4l7 5.2z" fill="{fur}" stroke="#6B4A3A" stroke-width="2.2" stroke-linejoin="round"/>'
            f'<path d="M26.5 15 25.4 4.4l-7 5.2z" fill="{fur}" stroke="#6B4A3A" stroke-width="2.2" stroke-linejoin="round"/>'
            f'<ellipse cx="16" cy="18.5" rx="12.4" ry="10.4" fill="{fur}" stroke="#6B4A3A" stroke-width="2.2"/>{blush}{eyes}{badge_}</svg>')

def tray_panel(state="running", dark=False):
    c = dict(bg="var(--surface)", bd="var(--outline)", tx="var(--ink)", sx="var(--ink2)", hv="var(--div)", box="var(--ground)", tr="var(--track)", sep="var(--div)", ic="var(--acc-ink)", kb="var(--raised)", kbb="var(--sec-line)", qt="var(--dng-ink)")
    theme = "th-dark" if dark else "th-light"
    def item(ic, text, right="", hover=False, primary=False, color=None):
        bg = c["hv"] if hover else "transparent"
        col = color or c["tx"]
        if primary:
            return f'<button class="mi" style="background: var(--btn); color: var(--btn-ink); border: 2px solid var(--btn-lip); box-shadow: 0 2px 0 var(--btn-lip); margin-bottom: 4px">{icon(ic, 20, "var(--btn-ink)")}<span style="flex: 1">{text}</span>{right}</button>'
        return f'<button class="mi" style="background: {bg}; color: {col}">{icon(ic, 20, color or c["ic"])}<span style="flex: 1">{text}</span>{right}</button>'
    hint = f'<span style="font-size: 12px; font-weight: 700; color: {c["sx"]}; border: 1.5px solid {c["kbb"]}; background: {c["kb"]}; border-radius: 7px; padding: 2px 6px">Ctrl+Shift+P</span>'
    cnt = f'<span style="font-size: 12px; font-weight: 800; color: var(--t-legendary-ink); background: var(--t-legendary-tint); border-radius: 10px; padding: 2px 8px">21/40</span>'
    if state == "running":
        dot, status = "#4FB286", "Gathering · 6 critters out"
        box = f'''<div style="background: {c["box"]}; border-radius: 14px; padding: 10px 12px; display: flex; flex-direction: column; gap: 6px">
<div style="display: flex; justify-content: space-between; font-size: 13px; font-weight: 800; color: {c["tx"]}"><span>Focused 42 min</span><span style="color: {c["sx"]}; font-weight: 700">Next in 3 min</span></div>
<div style="height: 7px; border-radius: 4px; background: {c["tr"]}"><div style="width: 60%; height: 7px; border-radius: 4px; background: var(--accent)"></div></div></div>'''
        items = item("sparkle", "Spawn a critter", hover=True) + item("pause", "Pause critters", hint) + item("star", "Collection", cnt) + item("sliders", "Settings")
    elif state == "paused":
        dot, status = "#C9A13B", "Paused · critters are hiding"
        box = f'<div style="background: {c["box"]}; border-radius: 14px; padding: 10px 12px; font-size: 13px; color: {c["sx"]}; line-height: 1.45">Your focus time keeps counting. Resume to bring everyone back.</div>'
        items = item("play", "Resume critters", hint, primary=True) + item("sparkle", "Spawn a critter") + item("star", "Collection", cnt) + item("sliders", "Settings")
    else:
        dot, status = "#6C8DB0", "Napping · back when you are"
        box = f'<div style="background: {c["box"]}; border-radius: 14px; padding: 10px 12px; font-size: 13px; color: {c["sx"]}; line-height: 1.45">Away for 6 min. Six critters are curled up asleep.</div>'
        items = item("sparkle", "Spawn a critter") + item("pause", "Pause critters", hint) + item("star", "Collection", cnt) + item("sliders", "Settings")
    sleep = state == "napping"
    return f'''<div role="menu" aria-label="Critter Overlay" class="{theme}" style="width: 312px; background: {c["bg"]}; border: 2px solid {c["bd"]}; border-radius: 22px; box-shadow: 0 4px 0 rgba(43,33,28,0.35); padding: 12px; box-sizing: border-box; display: flex; flex-direction: column; gap: 10px">
<div style="display: flex; align-items: center; gap: 12px; padding: 2px 4px">
<div style="width: 46px; height: 46px; border-radius: 15px; background: var(--sp-kitten); border: 2px solid var(--outline); display: flex; align-items: center; justify-content: center; overflow: hidden; flex-shrink: 0">{kit_head(40, sleep)}</div>
<div><div class="disp" style="font-weight: 600; font-size: 17px; color: {c["tx"]}">Critter Overlay</div><div style="display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 700; color: {c["sx"]}; margin-top: 2px"><span style="width: 8px; height: 8px; border-radius: 4px; background: {dot}"></span>{status}</div></div>
</div>
{box}
<div style="display: flex; flex-direction: column; gap: 2px">{items}</div>
<div style="height: 2px; background: {c["sep"]}; margin: 0 6px"></div>
{item("power", "Quit", color=c["qt"])}
</div>'''

def taskbar(hl=True, dark=True):
    sq = lambda inner: f'<span style="width: 32px; height: 32px; border-radius: 6px; display: inline-flex; align-items: center; justify-content: center; color: #D7DCE3">{inner}</span>'
    ours = f'<span style="width: 32px; height: 32px; border-radius: 6px; display: inline-flex; align-items: center; justify-content: center; background: {"#3B4250" if hl else "transparent"}">{tray_icon("running", 18)}</span>'
    return f'''<div style="height: 48px; background: #20242C; border-radius: 12px; display: flex; align-items: center; justify-content: flex-end; gap: 4px; padding: 0 12px">
{sq(icon("chevd", 16))}{ours}{sq(icon("sound", 16))}{sq(icon("monitor", 16))}
<span style="display: flex; flex-direction: column; align-items: flex-end; font-size: 11.5px; color: #E6EAF0; line-height: 1.3; margin-left: 6px"><span>14:44</span><span>04/10/2026</span></span></div>'''

def tray():
    def col(label, sub, panel, bg):
        return f'''<div style="display: flex; flex-direction: column; gap: 12px">
<div><div class="h2">{label}</div><div class="note" style="color: var(--ink2)">{sub}</div></div>
<div style="background: {bg}; border-radius: 20px; padding: 24px 18px 14px; display: flex; flex-direction: column; align-items: flex-end; gap: 10px">{panel}{taskbar()}</div></div>'''
    cols = (col("Working, light", "Default state. The hovered row shows the highlight.", tray_panel("running"), "#DCE3EA")
            + col("Paused, light", "Resume becomes the main action.", tray_panel("paused"), "#DCE3EA")
            + col("Napping, light", "Away from the keyboard.", tray_panel("napping"), "#DCE3EA"))
    dcols = (col("Working, dark", "Follows Windows dark mode.", tray_panel("running", True), "#3B4250")
            + col("Paused, dark", "Resume stays the main action.", tray_panel("paused", True), "#3B4250")
            + col("Napping, dark", "Muted status, same menu.", tray_panel("napping", True), "#3B4250"))
    sizes = ""
    for st, nm in [("running", "Working"), ("napping", "Napping"), ("paused", "Paused")]:
        sizes += f'''<div style="display: flex; flex-direction: column; gap: 10px; align-items: flex-start">
<div style="font-weight: 800; font-size: 14px">{nm}</div>
<div style="display: flex; align-items: flex-end; gap: 16px">{tray_icon(st, 16)}{tray_icon(st, 24)}{tray_icon(st, 32)}{tray_icon(st, 48)}</div></div>'''
    tooltip = f'''<div style="display: flex; flex-direction: column; gap: 10px">
<div style="font-weight: 800; font-size: 14px">Hover tooltip</div>
<div style="display: inline-flex; padding: 7px 11px; background: #2B2F37; color: #EEF1F5; border-radius: 8px; font-size: 12.5px; border: 1px solid #454B57">Critter Overlay · 6 critters out</div>
<div class="note" style="color: var(--ink2); max-width: 260px">Paused reads "Critter Overlay · paused". Napping reads "Critter Overlay · napping".</div></div>'''
    native = f'''<div style="display: flex; flex-direction: column; gap: 10px">
<div style="font-weight: 800; font-size: 14px">Fallback: plain Windows menu</div>
<div style="width: 220px; background: #F9F9F9; border: 1px solid #D5D5D5; border-radius: 8px; padding: 4px; font-family: 'Segoe UI', system-ui, sans-serif; font-size: 13px; color: #1B1B1B">
<div style="padding: 6px 12px">Spawn a critter</div><div style="padding: 6px 12px">Pause critters</div><div style="padding: 6px 12px">Collection</div><div style="padding: 6px 12px">Settings</div><div style="height: 1px; background: #E0E0E0; margin: 4px 0"></div><div style="padding: 6px 12px">Quit</div></div>
<div class="note" style="color: var(--ink2); max-width: 260px">Same items, same order, if the styled panel is cut for time.</div></div>'''
    return f'''<div style="width: 1280px; height: 1720px; box-sizing: border-box; padding: 48px; background: var(--ground); display: flex; flex-direction: column; gap: 36px">
{DEFS}
<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 28px">{cols}</div>
<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 28px">{dcols}</div>
<div class="card" style="padding: 24px 28px; display: flex; flex-wrap: wrap; gap: 32px 64px; align-items: flex-start">
<div style="display: flex; flex-direction: column; gap: 20px"><div class="h2">Tray icon</div><div style="display: flex; gap: 40px">{sizes}</div>
<div class="note" style="color: var(--ink2); max-width: 520px">Drawn by hand at 16 px, not scaled down from the critter art. Left click or right click opens the panel. Double click opens Settings.</div></div>
{tooltip}{native}</div>
</div>'''

# ============================================================ TOASTS
def toast(tier, cid, kicker, title, sub, pct=65, legendary=False):
    _, name, fill, tint, ink = T[tier]
    bd = "#E3A72F" if legendary else fill
    bw = 3 if legendary else 2
    spark = ""
    if legendary:
        spark = ('<svg viewBox="0 0 24 24" width="16" height="16" style="position: absolute; left: 6px; top: 6px" aria-hidden="true"><path d="M12 2l2.4 7.6L22 12l-7.6 2.4L12 22l-2.4-7.6L2 12l7.6-2.4z" fill="#FFD84D" stroke="#B8860B" stroke-width="1.4"/></svg>'
                 '<svg viewBox="0 0 24 24" width="11" height="11" style="position: absolute; left: 62px; top: 4px" aria-hidden="true"><path d="M12 2l2.4 7.6L22 12l-7.6 2.4L12 22l-2.4-7.6L2 12l7.6-2.4z" fill="#FFD84D" stroke="#B8860B" stroke-width="1.6"/></svg>')
    return f'''<div role="status" style="width: 360px; background: var(--surface); border: {bw}px solid {bd}; border-radius: 20px; box-shadow: 0 4px 0 {bd}; overflow: hidden; position: relative; box-sizing: border-box">{spark}
<div style="display: flex; align-items: center; gap: 14px; padding: 12px 12px 12px 14px">
<div style="position: relative; flex-shrink: 0"><div style="width: 60px; height: 60px; border-radius: 30px; background: {tint}; display: flex; align-items: flex-end; justify-content: center; overflow: hidden">{critter(cid, 54)}</div><div style="position: absolute; right: -4px; bottom: -2px; background: var(--surface); border-radius: 12px; padding: 2px; display: flex">{badge(tier, 20)}</div></div>
<div style="flex: 1; min-width: 0"><div class="disp" style="font-weight: 600; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: {ink}">{kicker}</div><div style="font-weight: 800; font-size: 15.5px; margin-top: 1px">{title}</div><div style="font-size: 13px; color: var(--ink2); margin-top: 2px; line-height: 1.35">{sub}</div></div>
<button class="wb" aria-label="Dismiss" style="align-self: flex-start; width: 30px; height: 30px">{icon("close", 16)}</button>
</div>
<div style="height: 4px; background: {tint}"><div style="width: {pct}%; height: 4px; background: {bd}"></div></div>
</div>'''

def rarehour_toast():
    return f'''<div role="status" style="width: 360px; background: var(--rh-bg); border: 2px solid #9FB2EC; border-radius: 20px; box-shadow: 0 4px 0 #9FB2EC; overflow: hidden; box-sizing: border-box">
<div style="display: flex; align-items: center; gap: 14px; padding: 12px 12px 12px 14px">
<div style="width: 60px; height: 60px; border-radius: 30px; background: var(--surface); border: 2px solid var(--outline); display: flex; align-items: center; justify-content: center; flex-shrink: 0; box-sizing: border-box">{icon("moon", 28, "var(--rh-ink)")}</div>
<div style="flex: 1"><div class="disp" style="font-weight: 600; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--rh-ink)">Rare Hour</div><div style="font-weight: 800; font-size: 15.5px; margin-top: 1px">Rare Hour has begun</div><div style="font-size: 13px; color: var(--rh-text); margin-top: 2px">Rare and better are twice as likely until 22:00.</div></div>
<button class="wb" aria-label="Dismiss" style="align-self: flex-start; width: 30px; height: 30px">{icon("close", 16)}</button></div></div>'''

def paused_pill():
    return f'''<div role="status" style="display: inline-flex; align-items: center; gap: 10px; height: 44px; padding: 0 18px 0 14px; background: #2F2143; color: #F7F1FF; border-radius: 22px; box-shadow: 0 3px 0 #120A1C; font-weight: 800; font-size: 14px">{icon("pause", 18, "#C8A8FF", 2.6)}Critters paused<span style="font-weight: 600; color: #CDBFE0; font-size: 13px">Ctrl+Shift+P to resume</span></div>'''

def toasts():
    spec = (toast("rare", "otter", "Rare", "An otter has arrived", "Your first Rare otter. Added to your Collection.", 70)
            + toast("epic", "hedgehog", "Epic", "A hedgehog has arrived", "Only about 1 in 111 critters is Epic.", 45)
            + toast("legendary", "kitten", "Legendary", "A Legendary kitten", "Your first Legendary. Take a moment.", 85, legendary=True)
            + toast("legendary", "unicorn", "Special visitor", "A unicorn is passing through", "Seen once before.", 30, legendary=True)
            + toast("uncommon", "rabbit", "Uncommon", "A rabbit hopped in", "Only shown if notes are set to every tier.", 55)
            + rarehour_toast() + paused_pill())
    crit = "".join(critter(c, w) for c, w in [("kitten", 30), ("rabbit", 28), ("otter", 30), ("duckling", 26), ("kitten_sleep", 28)])
    mock = f'''<div style="width: 100%; height: 470px; border-radius: 18px; background: #C9D6E2; position: relative; overflow: hidden">
<div style="position: absolute; left: 40px; top: 30px; width: 520px; height: 330px; background: var(--surface); border-radius: 10px; border: 1px solid #B9C6D3"><div style="height: 30px; background: #EEF2F6; border-radius: 10px 10px 0 0"></div>
<div style="padding: 18px 22px; display: flex; flex-direction: column; gap: 10px"><div style="height: 10px; width: 60%; background: #E3E8EE; border-radius: 5px"></div><div style="height: 10px; width: 85%; background: #E3E8EE; border-radius: 5px"></div><div style="height: 10px; width: 72%; background: #E3E8EE; border-radius: 5px"></div><div style="height: 10px; width: 80%; background: #E3E8EE; border-radius: 5px"></div></div></div>
<div style="position: absolute; left: 70px; bottom: 34px; display: flex; align-items: flex-end; gap: 22px">{crit}</div>
<div style="position: absolute; right: 10px; bottom: 44px; transform: scale(0.62); transform-origin: bottom right; display: flex; flex-direction: column; gap: 12px; align-items: flex-end">{rarehour_toast()}{toast("rare", "otter", "Rare", "An otter has arrived", "Your first Rare otter. Added to your Collection.", 70)}</div>
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 30px; background: #20242C"></div>
</div>'''
    rules = [("Where", "Bottom right of the main screen, 16 px in from the edge and 16 px above the taskbar."),
             ("Stacking", "Up to three. The newest sits nearest the corner and older ones move up."),
             ("Timing", "Six seconds, shown by the bar running down. Hovering pauses it."),
             ("Focus", "Never takes keyboard focus. Clicking one opens the Collection on that critter."),
             ("When", "Follows Rare sighting notes in World. Stays silent in full-screen apps and while paused, except the paused pill itself.")]
    rl = "".join(f'<div style="display: grid; grid-template-columns: 90px minmax(0, 1fr); gap: 12px; padding: 8px 0; border-top: 2px solid var(--div)"><span style="font-weight: 800; font-size: 13.5px">{a}</span><span class="note">{b}</span></div>' for a, b in rules)
    return f'''<div style="width: 1280px; height: 1000px; box-sizing: border-box; padding: 48px; background: var(--ground); display: flex; gap: 48px">
{DEFS}
<div style="display: flex; flex-direction: column; gap: 16px; width: 380px; flex-shrink: 0"><div class="h2" style="margin-bottom: 4px">Styles</div>{spec}</div>
<div style="display: flex; flex-direction: column; gap: 20px; flex: 1"><div class="h2">In place, at about 40% scale</div>{mock}
<div class="card" style="padding: 8px 22px 12px">{rl}</div></div>
</div>'''

# ============================================================ ONBOARDING
def dots(i):
    return '<div style="display: flex; gap: 6px" aria-label="Step %d of 4">' % (i + 1) + "".join(
        f'<span style="width: {22 if j == i else 8}px; height: 8px; border-radius: 4px; background: {"var(--outline)" if j == i else "var(--chip-line)"}"></span>' for j in range(4)) + '</div>'

def ob_card(i, illus_h, illus_bg, illus, title, body, footer_btns):
    return f'''<div style="width: 480px; height: 680px; background: var(--surface); border: 2px solid var(--outline); border-radius: 28px; box-shadow: 0 5px 0 var(--lip); display: flex; flex-direction: column; overflow: hidden; flex-shrink: 0; box-sizing: border-box">
<div style="height: {illus_h}px; background: {illus_bg}; position: relative; flex-shrink: 0; display: flex; align-items: flex-end; justify-content: center; overflow: hidden">{illus}</div>
<div style="padding: 24px 30px 0; flex: 1; display: flex; flex-direction: column; gap: 12px">
<div style="font-size: 12.5px; font-weight: 800; color: var(--acc-ink); letter-spacing: .06em; text-transform: uppercase">Step {i + 1} of 4</div>
<h2 class="disp" style="margin: 0; font-weight: 600; font-size: 30px; line-height: 1.1">{title}</h2>
{body}</div>
<div style="padding: 16px 30px 26px; display: flex; align-items: center; justify-content: space-between">{dots(i)}<div style="display: flex; gap: 10px">{footer_btns}</div></div>
</div>'''

def onboarding():
    p = lambda t: f'<p style="margin: 0; font-size: 15px; line-height: 1.55; color: var(--ink-body)">{t}</p>'
    ground = '<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 26px; background: var(--stage-ground)"></div>'
    il1 = ground + f'<div style="position: relative; display: flex; align-items: flex-end; gap: 6px; padding-bottom: 14px">{critter("rabbit", 104)}{critter("kitten", 128)}{critter("duckling", 92)}{critter("otter", 106)}</div>'
    c1 = ob_card(0, 270, "var(--sp-kitten)", il1, "Hello there",
                 p("Critter Overlay brings small, very cute critters to the bottom of your screen. They keep you company while you work and never get in your way.")
                 + p("You can click straight through them, or pop one for a squeak."),
                 btn("Skip setup", "bq") + btn("Get started", "bp", "arrow"))
    tiles = ""
    for cid, name, tint, g in SPECIES:
        tiles += (f'<button class="sp" aria-pressed="true" aria-label="{name}, included" style="position: relative">'
                  f'<span style="width: 62px; height: 62px; border-radius: 31px; background: {tint}; border: 3px solid var(--outline); display: flex; align-items: center; justify-content: center; overflow: hidden; box-sizing: border-box">{critter(cid, 54)}</span>'
                  f'<span style="position: absolute; right: 8px; top: 0; width: 22px; height: 22px; border-radius: 11px; background: var(--accent); border: 2px solid var(--outline); display: flex; align-items: center; justify-content: center; box-sizing: border-box">{icon("check", 13, "var(--ink)", 3)}</span>'
                  f'<span>{name}</span></button>')
    il2 = f'<div style="display: flex; gap: 22px; align-items: flex-end; margin-bottom: -34px">{critter("otter", 96)}{critter("panda", 110)}{critter("squirrel", 100)}</div>'
    c2 = ob_card(1, 150, "var(--sp-turtle)", il2, "Who should visit?",
                 p("Pick your favourites. You can change this any time in Settings.")
                 + f'<div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px 6px; margin-top: 6px">{tiles}</div>'
                 + '<div style="font-size: 13px; color: var(--ink2)">The unicorn and the golden kitten are special visitors. They turn up on their own.</div>',
                 btn("Back", "bq") + btn("Next", "bp", "arrow"))
    z = '<div class="disp" style="position: absolute; left: 315px; top: 70px; font-weight: 600; font-size: 22px; color: var(--zz)">z<span style="font-size: 15px; vertical-align: super">z</span></div>'
    il3 = (f'<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 50%; background: var(--sp-kitten)"></div>'
           f'<div style="position: absolute; left: 50%; top: 0; bottom: 0; width: 50%; background: var(--sp-otter)"></div>'
           f'<div style="position: absolute; left: 22px; top: 16px; font-size: 12px; font-weight: 800; color: var(--outline)">WORKING</div>'
           f'<div style="position: absolute; left: 262px; top: 16px; font-size: 12px; font-weight: 800; color: #3E5670">AWAY</div>'
           f'<div style="position: relative; width: 100%; display: flex; align-items: flex-end; padding: 0 18px 12px; box-sizing: border-box; gap: 2px">{critter("rabbit", 62)}{critter("kitten", 76)}{critter("otter", 64)}<div style="width: 52px"></div>{critter("kitten_sleep", 92)}{critter("kitten_sleep", 70, "Second kitten napping")}</div>{z}')
    c3 = ob_card(2, 200, "var(--sp-kitten)", il3, "They gather while you work",
                 p("Keep working and more critters gather, and the rare ones get more likely. Step away and they curl up for a nap.")
                 + f'<div style="display: flex; flex-direction: column; gap: 8px; margin-top: 4px"><span style="font-weight: 800; font-size: 14px">Nap after</span>{seg(["1 min", "3 min", "5 min", "10 min"], 1, "Nap after")}</div>'
                 + f'<div style="display: flex; gap: 10px; align-items: flex-start; padding: 12px 14px; background: var(--ground); border-radius: 14px; font-size: 13px; line-height: 1.45; color: var(--ink2); margin-top: 4px">{icon("lock", 18, "var(--outline)")}<span>Only the time since your last key press or click is checked. Nothing you type is recorded.</span></div>',
                 btn("Back", "bq") + btn("Next", "bp", "arrow"))
    il4 = f'''<div style="position: absolute; left: 30px; right: 30px; bottom: 30px">{taskbar(hl=True)}</div>
<div style="position: absolute; right: 178px; bottom: 32px; width: 44px; height: 44px; border-radius: 22px; border: 3px solid var(--accent)"></div>
<div style="position: absolute; left: 30px; top: 28px; display: flex; flex-direction: column; align-items: flex-start; gap: 4px"><span class="disp" style="font-weight: 600; font-size: 20px; color: var(--surface)">Find us here</span><span style="font-size: 13px; color: #C9D1DB">Click the kitten for the menu.</span></div>
<svg width="80" height="60" viewBox="0 0 80 60" style="position: absolute; right: 186px; bottom: 76px" aria-hidden="true"><path d="M4 8 C 36 8 58 20 68 48" stroke="#C8A8FF" stroke-width="3" fill="none" stroke-linecap="round"/><path d="M60 43 L68 50 L72 40" stroke="#C8A8FF" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'''
    c4 = ob_card(3, 230, "#3B4250", il4, "You're all set",
                 p("Critter Overlay lives in your system tray. If you cannot see the kitten, check the arrow by the clock. Pause or resume from anywhere with")
                 + f'<div>{keys("Ctrl", "Shift", "P")}</div>'
                 + f'<div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 14px; background: var(--ground); border-radius: 14px; margin-top: 6px"><span style="font-weight: 800; font-size: 14px">Start with Windows</span>{toggle(True, "Start with Windows")}</div>',
                 btn("Open Settings", "bs") + btn("Let them in", "bp", "heart"))
    return f'''<div style="width: 2160px; height: 820px; box-sizing: border-box; padding: 60px 60px; background: var(--stage); display: flex; gap: 40px; align-items: flex-start">
{DEFS}{c1}{c2}{c3}{c4}</div>'''
