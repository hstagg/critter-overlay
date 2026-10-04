from parts import *

# ============================================================ HOME
def desk_scene(h=190):
    def stand(cid, w, extra="", glow=None, label=None, zz=False):
        g = ""
        if glow:
            _, name, fill, tint, ink = T[glow]
            g = (f'<div style="position: absolute; left: 50%; bottom: -6px; width: {w+30}px; height: {w+30}px; margin-left: -{(w+30)//2}px; '
                 f'border-radius: 50%; background: {tint}; border: 3px solid {fill}; opacity: 0.9"></div>')
        lab = ""
        if label:
            lab = f'<div style="position: absolute; left: 50%; top: -34px; transform: translateX(-50%)">{tier_chip(glow, label)}</div>'
        z = ""
        if zz:
            z = '<div class="disp" style="position: absolute; right: -10px; top: -8px; font-weight: 600; font-size: 15px; color: var(--zz); line-height: 1">z<span style="font-size: 11px; vertical-align: super">z</span></div>'
        return f'<div style="position: relative; display: flex; align-items: flex-end">{g}{lab}{z}<div style="position: relative">{critter(cid, w)}</div></div>'
    crit = "".join([
        stand("kitten", 62),
        stand("rabbit", 58),
        stand("otter", 60, glow="rare", label="Rare otter"),
        stand("kitten_sleep", 56, zz=True),
        stand("duckling", 52),
        stand("hedgehog", 54),
    ])
    return f'''<div class="th-light" style="height: {h}px; border-radius: 16px; background: #DCE3EA; display: flex; flex-direction: column; justify-content: flex-end; overflow: hidden; position: relative">
<div style="position: absolute; left: 22px; top: 18px; width: 220px; height: 92px; border-radius: 10px; background: #F5F7FA; border: 1px solid #C8D2DC"><div style="height: 22px; border-radius: 10px 10px 0 0; background: #E6EBF0"></div></div>
<div style="display: flex; align-items: flex-end; gap: 22px; padding: 0 20px 0 262px">{crit}</div>
<div style="height: 30px; background: #2E3440; flex-shrink: 0"></div>
</div>'''

def stat(label, value, foot, ic):
    return f'''<div class="card" style="padding: 18px 20px; display: flex; flex-direction: column; gap: 10px">
<div style="display: flex; align-items: center; gap: 8px; color: var(--ink2); font-weight: 800; font-size: 13px">{icon(ic, 18, "var(--acc-ink)")}{label}</div>
<div class="disp" style="font-weight: 600; font-size: 34px; line-height: 1">{value}</div>
{foot}
</div>'''

def home():
    heads = "".join(f'<span style="width: 26px; height: 26px; border-radius: 13px; background: {TINT[c]}; border: 2px solid var(--surface); margin-left: -6px; display: inline-flex; align-items: center; justify-content: center; overflow: hidden">{critter(c, 24)}</span>' for c in ["kitten", "rabbit", "otter", "kitten", "duckling", "hedgehog"])
    heads += '<span style="width: 22px; height: 22px; border-radius: 13px; border: 2px dashed var(--dash); margin-left: 4px"></span><span style="width: 22px; height: 22px; border-radius: 13px; border: 2px dashed var(--dash); margin-left: 4px"></span>'
    stats = f'''<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px">
{stat("Focused for", "42 min", '<div style="height: 8px; border-radius: 4px; background: var(--track)"><div style="width: 60%; height: 8px; border-radius: 4px; background: var(--accent)"></div></div><div style="font-size: 13px; color: var(--ink2)">Next critter in 3 min</div>', "mug")}
{stat("On your desk", "6 of 8", f'<div style="display: flex; align-items: center; padding-left: 6px; height: 26px">{heads}</div><div style="font-size: 13px; color: var(--ink2)">Room for two more</div>', "paw")}
{stat("Rare luck", "x1.6", '<div style="display: flex; gap: 4px">' + "".join(f'<span style="flex: 1; height: 8px; border-radius: 4px; background: {"var(--t-rare-fill)" if i < 3 else "var(--track)"}"></span>' for i in range(5)) + '</div><div style="font-size: 13px; color: var(--ink2)">Grows the longer you stay</div>', "sparkle")}
</div>'''
    scene = f'''<div class="card" style="padding: 18px 20px 20px; display: flex; flex-direction: column; gap: 14px">
<div style="display: flex; align-items: center; justify-content: space-between"><div style="font-weight: 800; font-size: 16px">On your desk now</div><div style="display: flex; gap: 8px">{btn("Spawn now", "bs", "sparkle", small=True)}{btn("Pause", "bs", "pause", small=True)}</div></div>
{desk_scene()}
</div>'''
    sight = [("rare", "Rare otter", "Today, 14:02", NEW),
             ("uncommon", "Uncommon rabbit", "Today, 13:40", ""),
             ("epic", "Epic hedgehog", "Yesterday, 21:18", "")]
    srows = "".join(f'<div style="display: flex; align-items: center; gap: 12px; padding: 9px 0; {"border-top: 2px solid var(--div);" if i else ""}">{badge(t, 22)}<span style="font-weight: 800; font-size: 14px; color: {T[t][4]}">{n}</span>{p}<span style="margin-left: auto; font-size: 13px; color: var(--ink2)">{d}</span></div>' for i, (t, n, d, p) in enumerate(sight))
    bottom = f'''<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px">
<div class="card" style="padding: 18px 20px; display: flex; gap: 16px; align-items: center; background: var(--rh-bg); border-color: var(--rh-line)">
<div style="width: 64px; height: 64px; border-radius: 20px; background: var(--surface); border: 2px solid var(--outline); display: flex; align-items: center; justify-content: center; color: var(--rh-ink); flex-shrink: 0">{icon("moon", 30, "var(--rh-ink)")}</div>
<div style="flex: 1"><div style="font-weight: 800; font-size: 16px">Rare Hour tonight</div><div style="font-size: 13px; color: var(--rh-text); margin-top: 3px">21:00 to 22:00. Rare and better are twice as likely.</div><div class="disp" style="font-weight: 600; font-size: 20px; color: var(--rh-ink); margin-top: 8px">Starts in 3 h 12 min</div></div>
</div>
<div class="card" style="padding: 14px 20px 12px">
<div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px"><div style="font-weight: 800; font-size: 16px">Recent sightings</div><a href="Collection.dc.html" style="font-weight: 800; font-size: 13px">Open collection</a></div>
{srows}
</div>
</div>'''
    body = stats + scene + bottom
    return window("home", "Good afternoon", "Your critters have been gathering while you work.", body, 880)

# ============================================================ CRITTERS
def critters():
    tiles = ""
    for cid, name, tint, gait in SPECIES:
        sel = cid == "kitten"
        off = cid == "squirrel"
        ring = "border: 3px solid var(--outline); box-shadow: 0 2px 0 var(--lip);" if sel else "border: 2px solid var(--chip-line);"
        op = "opacity: 0.45;" if off else ""
        sub = '<span style="font-size: 11px; color: var(--ink3); font-weight: 700">Off</span>' if off else ""
        tiles += (f'<button class="sp" aria-pressed="{"true" if sel else "false"}" aria-label="{name}{", off" if off else ""}" style="{op}">'
                  f'<span style="width: 58px; height: 58px; border-radius: 29px; background: {tint}; {ring} display: flex; align-items: center; justify-content: center; overflow: hidden; box-sizing: border-box">{critter(cid, 50)}</span>'
                  f'<span>{name}</span>{sub}</button>')
    tiles += '<div style="width: 2px; background: var(--line); margin: 4px 0 22px"></div>'
    for cid, name, tint in SPECIALS:
        tiles += (f'<button class="sp" aria-label="{name}, special visitor">'
                  f'<span style="width: 58px; height: 58px; border-radius: 29px; background: {tint}; border: 2px solid var(--chip-line); display: flex; align-items: center; justify-content: center; overflow: hidden; box-sizing: border-box">{critter(cid, 50)}</span>'
                  f'<span>{name}</span></button>')
    tiles += (f'<button class="sp" aria-label="Your own critters, coming soon" aria-disabled="true" style="cursor: default">'
              f'<span style="width: 58px; height: 58px; border-radius: 29px; border: 2px dashed var(--dash); background: var(--ph-bg); display: flex; align-items: center; justify-content: center; color: var(--ph-ink); box-sizing: border-box">{icon("plus", 24)}</span>'
              f'<span style="color: var(--ink3)">Your own</span><span class="pill" style="background: var(--track); color: var(--acc-ink); height: 18px; font-size: 10.5px">Soon</span></button>')
    strip = f'''<div class="card" style="padding: 16px 18px 12px">
<div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 6px">{tiles}</div>
</div>'''
    everyone = card(
        row("Size", "Applies to every critter.", valctl(slider(33, "Critter size", "80 px", "200 px", 240), "120 px"))
        + row("Opacity", "Lower it if they distract you.", valctl(slider(100, "Critter opacity", "50%", "100%", 240), "100%"))
    )
    trails = "".join(f'<button class="chip{" sel" if t == "Sparkles" else ""}" aria-pressed="{"true" if t == "Sparkles" else "false"}">{t}</button>' for t in ["None", "Dots", "Stars", "Sparkles", "Bubbles", "Glitter", "Hearts"])
    def block(title, value, ctl, tip=None, last=False):
        v = f'<span class="val" style="font-size: 15px">{value}</span>' if value else ""
        bd = "" if last else "border-bottom: 2px solid var(--div);"
        return (f'<div style="padding: 14px 0; {bd} display: flex; flex-direction: column; gap: 10px">'
                f'<div style="display: flex; align-items: center; justify-content: space-between"><div class="rtt">{title}{info(tip) if tip else ""}</div>{v}</div>{ctl}</div>')
    tooltip = '''<div role="tooltip" style="position: absolute; left: 54px; top: 46px; width: 260px; background: var(--tip-bg); color: var(--tip-ink); font-size: 13px; line-height: 1.45; padding: 10px 12px; border-radius: 12px; z-index: 2">How often this critter stops to groom, stretch or nap. Wired hardly stops. Narcoleptic naps all the time.<div style="position: absolute; left: 16px; top: -6px; width: 12px; height: 12px; background: var(--tip-bg); transform: rotate(45deg)"></div></div>'''
    right = (block("How often it visits", "", seg(["Seldom", "Normal", "Often", "Constant"], 3, "How often it visits"), "How often this species is picked when critters arrive.")
             + block("Speed", "average", stepped(["snail", "slow", "average", "fast", "rapid", "supersonic"], 2, "Speed"))
             + f'<div style="position: relative">{block("Activity", "normal", stepped(["wired", "active", "normal", "lazy", "sleepy", "narcoleptic"], 2, "Activity"), "Activity")}{tooltip}</div>'
             + block("Trail", "", f'<div style="display: flex; flex-wrap: wrap; gap: 8px">{trails}</div>', "Only shows when rarity tiers are on.")
             + block("Can appear as", "", f'<div style="display: flex; align-items: center; gap: 10px"><span style="font-size: 14px; color: var(--ink2); font-weight: 700">From</span><button class="dd">{badge("common", 18)}<span style="flex: 1; text-align: left">Common</span>{icon("chevd", 16)}</button><span style="font-size: 14px; color: var(--ink2); font-weight: 700">to</span><button class="dd">{badge("legendary", 18)}<span style="flex: 1; text-align: left">Legendary</span>{icon("chevd", 16)}</button></div>', "Limit the rarity tiers this critter can roll. Turtles and pandas stop at Epic by default.", last=True))
    detail = f'''<div class="card" style="display: grid; grid-template-columns: 250px minmax(0, 1fr); gap: 28px; padding: 20px 24px 10px 20px">
<div style="display: flex; flex-direction: column; gap: 14px">
<div style="height: 250px; border-radius: 20px; background: var(--sp-kitten); display: flex; align-items: flex-end; justify-content: center; padding-bottom: 14px; box-sizing: border-box">{critter("kitten", 200, "Kitten, animated preview")}</div>
<div><div class="disp" style="font-weight: 600; font-size: 26px">Kitten</div><div style="font-size: 13px; color: var(--ink2); margin-top: 2px">Walks with a pounce-pause</div></div>
<div style="display: flex; flex-direction: column; gap: 10px; padding: 12px 14px; background: var(--ground); border-radius: 16px">
<div style="display: flex; align-items: center; justify-content: space-between"><span style="font-weight: 800; font-size: 14px">Visits your desk</span>{toggle(True, "Kitten visits your desk")}</div>
<div style="display: flex; align-items: center; justify-content: space-between"><span style="font-weight: 800; font-size: 14px">Pop sound</span><span style="display: flex; gap: 8px; align-items: center"><button class="ib" aria-label="Play kitten sound">{icon("play", 16)}</button>{toggle(True, "Kitten pop sound")}</span></div>
</div>
<button class="btn bq sm" style="align-self: flex-start">{icon("reset", 16)}Reset kitten</button>
</div>
<div style="display: flex; flex-direction: column">{right}</div>
</div>'''
    body = section("Everyone", everyone) + section("Choose a critter", strip + '<div style="height: 14px"></div>' + detail)
    return window("critters", "Critters", "Choose who visits and how each one behaves.", body, 1220,
                  right=btn("Reset all critters", "bq", "reset", small=True))

# ============================================================ FOCUS
def focus():
    def stepcard(title, text, art, tint):
        return f'''<div style="flex: 1; display: flex; flex-direction: column; gap: 10px">
<div style="height: 108px; border-radius: 16px; background: {tint}; display: flex; align-items: flex-end; justify-content: center; gap: 4px; padding-bottom: 8px; box-sizing: border-box; position: relative">{art}</div>
<div style="font-weight: 800; font-size: 15px">{title}</div><div style="font-size: 13px; line-height: 1.45; color: var(--ink2)">{text}</div></div>'''
    arrow = f'<div style="padding-top: 44px; color: var(--off-line)">{icon("arrow", 24)}</div>'
    z = '<div class="disp" style="position: absolute; left: 58%; top: 14px; font-weight: 600; font-size: 20px; color: var(--zz)">z<span style="font-size: 14px; vertical-align: super">z</span></div>'
    explainer = card(f'''<div style="display: flex; gap: 14px; padding: 20px">
{stepcard("While you work", "Critters gather. One more every 5 minutes, up to 8.", critter("rabbit", 64) + critter("kitten", 72) + critter("duckling", 58), "var(--sp-kitten)")}
{arrow}
{stepcard("When you step away", "After 3 quiet minutes they curl up and nap.", critter("kitten_sleep", 74) + z, "var(--sp-otter)")}
{arrow}
{stepcard("When you come back", "They wake with a stretch and carry on. Your luck keeps building.", critter("kitten", 72) + critter("otter", 66), "var(--sp-turtle)")}
</div>''')
    work = card(
        row("How critters arrive", "Gathering follows your focus. The timer brings a group every few minutes, whatever you are doing.", seg(["Gather while I work", "On a timer"], 0, "How critters arrive"))
        + row("Start with", "How many come out when you sit down.", f'<div class="step"><button aria-label="Fewer">{icon("minus", 16)}</button><span>2 critters</span><button aria-label="More">{icon("plus", 16)}</button></div>')
        + row("One more every", "", valctl(slider(14, "Gather rate", "1 min", "30 min", 260), "5 min"))
        + row("At most", "The desk never gets busier than this.", valctl(slider(29, "Most critters at once", "1", "25", 260), "8 critters"))
        + row("Rarer the longer you stay", "Each focused stretch nudges up the odds of Rare and better. Resets after a long break.", toggle(True, "Rarer the longer you stay"))
        + row("Pause in full-screen apps", "Hide critters during games, films and presentations.", toggle(True, "Pause in full-screen apps"), pill=NEW)
    )
    away = card(
        row("Nap after", "Counts from your last key press or mouse movement.", valctl(slider(7, "Nap after", "1 min", "30 min", 260), "3 min"))
        + row("Tidy up after a long break", "Critters head home if you are gone a long time, and gather again when you return.", seg(["Never", "30 min", "1 hour", "2 hours"], 2, "Tidy up after"), pill=NEW)
        + f'<div style="display: flex; gap: 10px; align-items: center; padding: 12px 20px; background: var(--ground); border-top: 2px solid var(--div); border-radius: 0 0 18px 18px; font-size: 13px; color: var(--ink2)">{icon("lock", 18, "var(--outline)")}Only the time since your last input is checked. Nothing you type or click is recorded.</div>'
    )
    timer = card(
        row("New group every", "", valctl(slider(7, "Group interval", "1 min", "60 min", 260), "5 min"))
        + row("Smallest group", "", valctl(slider(29, "Smallest group", "1", "15", 260), "5"))
        + row("Largest group", "", valctl(slider(38, "Largest group", "1", "25", 260), "10")),
        "opacity: 0.55")
    solo = card(
        row("Solo walkers", "Now and then a lone critter strolls along the edge of your screen.", toggle(True, "Solo walkers"))
        + row("One every", "", valctl(slider(15, "Solo walker interval", "1 min", "60 min", 260), "10 min"))
    )
    body = (explainer + section("While you work", work) + section("When you step away", away)
            + section("Timer arrivals", timer, "Used when critters arrive on a timer")
            + section("Solo walkers", solo))
    return window("focus", "Focus", "Critters gather while you work and curl up for a nap when you step away.", body, 1780)
