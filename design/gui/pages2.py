from parts import *

# ============================================================ WORLD
def world():
    living = card(
        row("Day and night pacing", "Livelier in the morning, sleepier late at night. Only their pace changes, never the colours.", toggle(True, "Day and night pacing"))
        + row("Behaviour frequency", "How often they stop to groom, stretch, play or nap.", valctl(slider(41, "Behaviour frequency", "Calm", "Lively", 260), "1.0x"))
        + row("Pair interactions", "Two critters close together may sniff, follow, play or groom.", toggle(True, "Pair interactions"))
    )
    odds_rows = ""
    data = [("common", 90, "9 in 10", 90), ("uncommon", 7, "1 in 14", 35), ("rare", 2, "1 in 50", 22), ("epic", 0.9, "1 in 111", 16), ("legendary", 0.1, "1 in 1,000", 6)]
    for k, v, hint, pos in data:
        _, name, fill, tint, ink = T[k]
        odds_rows += f'''<div style="display: grid; grid-template-columns: 150px minmax(0, 1fr) 70px 90px; align-items: center; gap: 16px; padding: 9px 0">
<span style="display: flex; align-items: center; gap: 10px; font-weight: 800; font-size: 14px; color: {ink}">{badge(k, 22)}{name}</span>
<input type="range" class="rng" min="0" max="100" value="{pos}" aria-label="{name} odds" style="{fillbg(pos)}">
<span class="val" style="text-align: right">{v}%</span><span style="font-size: 13px; color: var(--ink2)">{hint}</span></div>'''
    rarity = card(
        row("Rarity tiers", "Each critter rolls a tier when it arrives. Rarer ones glow softly and leave a trail.", toggle(True, "Rarity tiers"))
        + f'''<div style="padding: 14px 20px 16px; border-top: 2px solid var(--div)">
<div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 4px"><div class="rtt">Odds{info("These are relative weights, so they do not need to add up to 100.")}</div>{btn("Reset odds", "bq", "reset", small=True)}</div>
{odds_rows}
<div style="font-size: 12.5px; color: var(--ink2); margin-top: 4px">Relative weights, so they do not need to add up to 100. The scale stretches at the low end so tiny odds are easy to set.</div>
</div>'''
        + row("First arrival of the day", "The first critter after midnight is always Rare or better.", toggle(True, "First arrival of the day bonus"))
        + row("Rare sighting notes", "A small note in the corner when someone special arrives.", seg(["Off", "Rare and up", "Epic and up", "Legendary"], 1, "Rare sighting notes"))
    )
    rh = card(
        f'''<div style="display: flex; align-items: center; gap: 16px; padding: 18px 20px; background: var(--rh-bg); border-radius: 18px 18px 0 0">
<div style="width: 56px; height: 56px; border-radius: 18px; background: var(--surface); border: 2px solid var(--outline); display: flex; align-items: center; justify-content: center; flex-shrink: 0">{icon("moon", 28, "var(--rh-ink)")}</div>
<div style="flex: 1"><div style="font-weight: 800; font-size: 16px">Rare Hour</div><div style="font-size: 13px; color: var(--rh-text); margin-top: 3px">Once a day, Rare and better become more likely for a while.</div></div>{toggle(True, "Rare Hour")}</div>'''
        + row("Starts at", "Your local time.", f'<button class="dd" style="min-width: 120px">{icon("clock", 18, "var(--acc-ink)")}<span style="flex: 1; text-align: left">21:00</span>{icon("chevd", 16)}</button>')
        + row("Lasts", "", seg(["30 min", "1 hour", "2 hours"], 1, "Rare Hour length"))
        + row("Boost", "How much likelier Rare and better become.", seg(["x1.5", "x2", "x3"], 1, "Rare Hour boost"))
    )
    body = section("Living world", living) + section("Rarity", rarity) + section("Rare Hour", rh)
    return window("world", "World", "How the living world behaves, and how rare things get.", body, 1420)

# ============================================================ SOUND
def sound():
    master = card(
        row("Pop sounds", "Each critter makes its own little noise when you click to pop it.", toggle(True, "Pop sounds"))
        + row("Volume", "", f'<div style="display: flex; align-items: center; gap: 12px; flex-shrink: 0">{icon("mute", 20, "var(--ink3)")}{slider(50, "Volume", None, None, 260)}{icon("sound", 20, "var(--ink3)")}<span class="val" style="width: 50px; text-align: right">50%</span></div>')
    )
    allc = [(c, n, t) for c, n, t, g in SPECIES] + SPECIALS
    cells = ""
    for i, (cid, name, tint) in enumerate(allc):
        on = cid != "squirrel"
        top = "border-top: 2px solid var(--div);" if i >= 2 else ""
        cells += f'''<div style="display: flex; align-items: center; gap: 14px; padding: 12px 20px; {top}">
<span style="width: 46px; height: 46px; border-radius: 23px; background: {tint}; display: flex; align-items: center; justify-content: center; overflow: hidden; flex-shrink: 0">{critter(cid, 40)}</span>
<span style="flex: 1; font-weight: 800; font-size: 15px{"; color: var(--ink3)" if not on else ""}">{name}</span>
<button class="ib" aria-label="Play {name.lower()} sound">{icon("play", 16)}</button>{toggle(on, name + " sound")}</div>'''
    lst = card(f'<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 0">{cells}</div>', "overflow: hidden")
    body = section("Master", master) + section("Every critter", lst, "Press play to hear one")
    return window("sound", "Sound", "Little squeaks, peeps and bloops when you pop a critter.", body, 780)

# ============================================================ SYSTEM
def system():
    startup = card(row("Start with Windows", "Your critters are ready when you log in.", toggle(True, "Start with Windows")))
    shortcuts = card(
        row("Pause or resume", "Works from any app.", f'<div style="display: flex; align-items: center; gap: 14px">{keys("Ctrl", "Shift", "P")}{btn("Change", "bs", small=True)}</div>')
        + row("Spawn a critter", "Optional.", f'<div style="display: flex; align-items: center; gap: 14px"><span style="font-size: 13px; color: var(--ink3); font-weight: 700">Not set</span>{btn("Set", "bs", small=True)}</div>', pill=NEW)
    )
    display = card(
        row("Theme", "Follows your Windows light or dark setting unless you pick one.", seg(["Match Windows", "Light", "Dark"], 0, "Theme"))
        + row("Animation detail", "Simple uses fewer animation layers on slower computers.", seg(["Detailed", "Simple"], 0, "Animation detail"))
    )
    coll = card(
        row("Keep a Seen Log", "Records each critter and tier you meet, for your Collection.", toggle(True, "Keep a Seen Log"))
        + row("Clear the Seen Log", "Start your Collection again from nothing. This cannot be undone.", btn("Clear", "bd", "trash", small=True))
    )
    custom = f'''<div style="border: 2px dashed var(--dash); border-radius: 20px; padding: 18px 20px; display: flex; align-items: center; gap: 16px; background: var(--ph-bg)">
<div style="width: 52px; height: 52px; border-radius: 16px; background: var(--surface); border: 2px dashed var(--dash); display: flex; align-items: center; justify-content: center; color: var(--ph-ink); flex-shrink: 0">{icon("box", 26)}</div>
<div style="flex: 1"><div class="rtt">Custom critters {SOON}</div><div class="rtd">Bring your own art and share critters with friends. This arrives in a later update.</div></div>
<button class="btn bx sm" aria-disabled="true">{icon("plus", 16)}Import a critter</button></div>'''
    updates = card(row("Version 3.0.0", f'<span style="display: flex; align-items: center; gap: 6px; flex-wrap: wrap"><span style="display: inline-flex; align-items: center; gap: 6px; color: var(--t-uncommon-ink); font-weight: 700">{icon("check", 16, "var(--t-uncommon-ink)", 2.5)}You are up to date.</span><span>Checked today at 09:12.</span></span>', f'<div style="display: flex; gap: 8px">{btn("What is new", "bq", small=True)}{btn("Check now", "bs", "update", small=True)}</div>'))
    danger = card(
        row("Reset all settings", "Critters, odds and shortcuts go back to how they started. Your Collection is kept.", btn("Reset", "bs", "reset", small=True))
        + row("Quit Critter Overlay", "Closing this window keeps your critters running in the tray. Quit stops them completely.", btn("Quit", "bd", "power", small=True))
    )
    about = f'''<div style="display: flex; align-items: center; gap: 18px; padding: 6px 4px">
<div style="width: 64px; height: 64px; border-radius: 20px; background: var(--sp-kitten); border: 2px solid var(--outline); display: flex; align-items: center; justify-content: center; overflow: hidden; flex-shrink: 0">{kit_head(56)}</div>
<div style="flex: 1"><div class="disp" style="font-weight: 600; font-size: 20px">Critter Overlay 3.0</div><div style="font-size: 13px; color: var(--ink2); margin-top: 2px">Small companions for long days.</div></div>
<div style="display: flex; gap: 18px; font-weight: 800; font-size: 13px"><a href="#help">Help</a><a href="#credits">Credits and licences</a><a href="#privacy">Privacy</a></div></div>'''
    body = (section("Startup", startup) + section("Shortcuts", shortcuts) + section("Display", display)
            + section("Collection", coll) + section("Custom critters", custom) + section("Updates", updates)
            + section("Reset and quit", danger) + section("About", about))
    return window("system", "System", "Startup, shortcuts, updates and the small print.", body, 1560)

# ============================================================ COLLECTION
SEEN = {  # tier counts; None = not possible (cap)
    "kitten": [112, 9, 3, 1, 0], "rabbit": [64, 5, 1, 0, 0], "duckling": [58, 4, 0, 0, 0],
    "turtle": [31, 2, 1, 0, None], "hedgehog": [40, 3, 0, 1, 0], "squirrel": [47, 0, 0, 0, 0],
    "otter": [52, 6, 2, 0, 0], "panda": [29, 0, 0, 0, None],
}

def collection():
    tot = {"Common": "8/8", "Uncommon": "6/8", "Rare": "4/8", "Epic": "2/8", "Legendary": "0/6"}
    tiers = "".join(f'<div style="display: flex; flex-direction: column; align-items: center; gap: 4px; min-width: 76px">{badge(k, 26)}<span style="font-weight: 800; font-size: 12.5px; color: {ink}">{name}</span><span class="disp" style="font-weight: 600; font-size: 15px">{tot[name]}</span></div>' for k, name, fill, tint, ink in TIERS)
    progress = card(f'''<div style="display: flex; align-items: center; gap: 28px; padding: 20px 24px">
<div style="flex: 1"><div class="disp" style="font-weight: 600; font-size: 30px">21 of 40 found</div>
<div style="height: 12px; border-radius: 6px; background: var(--track); margin-top: 10px"><div style="width: 52%; height: 12px; border-radius: 6px; background: var(--accent)"></div></div>
<div style="font-size: 13px; color: var(--ink2); margin-top: 8px">Newest: a Rare otter, today at 14:02.</div></div>
<div style="display: flex; gap: 6px">{tiers}</div></div>''')
    cards = ""
    for cid, name, tint, gait in SPECIES:
        counts = SEEN[cid]
        total = sum(c for c in counts if c)
        pips = ""
        for (k, tname, fill, ttint, ink), c in zip(TIERS, counts):
            if c is None:
                pips += f'<div style="display: flex; flex-direction: column; align-items: center; gap: 3px; width: 30px" title="Not possible for this critter"><span style="color: var(--dash)">{icon("lock", 18)}</span><span style="font-size: 11px; color: var(--ink3); font-weight: 700">no</span></div>'
            elif c == 0:
                pips += f'<div style="display: flex; flex-direction: column; align-items: center; gap: 3px; width: 30px">{badge(k, 22, ghost=True)}<span style="font-size: 11px; color: var(--ink3); font-weight: 800">?</span></div>'
            else:
                pips += f'<div style="display: flex; flex-direction: column; align-items: center; gap: 3px; width: 30px">{badge(k, 22)}<span style="font-size: 11px; color: {ink}; font-weight: 800">x{c}</span></div>'
        sel = cid == "otter"
        bd = "border-color: var(--outline); box-shadow: 0 3px 0 var(--lip);" if sel else ""
        cards += f'''<div class="card" style="padding: 0; overflow: hidden; {bd}">
<div style="height: 110px; background: {tint}; display: flex; align-items: flex-end; justify-content: center; padding-bottom: 6px; box-sizing: border-box; position: relative">{critter(cid, 92)}{'<span style="position: absolute; top: 10px; right: 10px">' + pill("New Rare", "var(--t-rare-tint)", "var(--t-rare-ink)") + '</span>' if sel else ''}</div>
<div style="padding: 10px 12px 12px"><div style="display: flex; align-items: baseline; justify-content: space-between"><span class="disp" style="font-weight: 600; font-size: 18px">{name}</span><span style="font-size: 12px; color: var(--ink2); font-weight: 700">Seen {total}</span></div>
<div style="display: flex; justify-content: space-between; margin-top: 10px">{pips}</div></div></div>'''
    grid = f'<div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px">{cards}</div>'
    specials = f'''<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px">
<div class="card" style="display: flex; align-items: center; gap: 16px; padding: 14px 18px">
<span style="width: 84px; height: 84px; border-radius: 22px; background: var(--sp-unicorn); display: flex; align-items: flex-end; justify-content: center; overflow: hidden; flex-shrink: 0">{critter("unicorn", 78)}</span>
<div style="flex: 1"><div class="disp" style="font-weight: 600; font-size: 19px">Unicorn</div><div style="font-size: 13px; color: var(--ink2); margin-top: 2px">Found. Seen once, on 2 Oct.</div><div style="margin-top: 8px">{tier_chip("legendary", "Special visitor")}</div></div></div>
<div class="card" style="display: flex; align-items: center; gap: 16px; padding: 14px 18px; background: var(--ground); border-style: dashed">
<span style="width: 84px; height: 84px; border-radius: 22px; background: var(--ph-bg); display: flex; align-items: flex-end; justify-content: center; overflow: hidden; flex-shrink: 0">{critter("golden", 78, "Golden kitten, not yet found", "filter: var(--sil); opacity: var(--sil-op)")}</span>
<div style="flex: 1"><div class="disp" style="font-weight: 600; font-size: 19px; color: var(--ink3)">Not yet met</div><div style="font-size: 13px; color: var(--ink2); margin-top: 2px">About 1 in 1,000 arrivals. Keep at it.</div><div style="margin-top: 8px">{pill("Special visitor", "var(--ph-bg)", "var(--t-common-ink)")}</div></div></div>
</div>'''
    diary_rows = [("rare", "Rare otter", "Today, 14:02", "First Rare otter"),
                  ("epic", "Epic hedgehog", "3 Oct, 21:18", "During Rare Hour"),
                  ("legendary", "Unicorn", "2 Oct, 11:30", "Special visitor"),
                  ("rare", "Rare kitten", "1 Oct, 16:45", "")]
    drows = "".join(f'<div style="display: grid; grid-template-columns: 30px 200px minmax(0, 1fr) 140px; align-items: center; gap: 12px; padding: 11px 20px; {"border-top: 2px solid var(--div);" if i else ""}">{badge(t, 22)}<span style="font-weight: 800; font-size: 14px; color: {T[t][4]}">{n}</span><span style="font-size: 13px; color: var(--ink2)">{note}</span><span style="font-size: 13px; color: var(--ink2); text-align: right">{d}</span></div>' for i, (t, n, d, note) in enumerate(diary_rows))
    diary = card(drows)
    body = (progress + section("Critters", grid) + section("Specials", specials)
            + section("Sightings diary", diary, "Rare and better, newest first"))
    return window("collection", "Collection", "Everyone you have met so far. Stay focused to meet the rare ones.", body, 1240,
                  right=seg(["All", "Found", "Missing"], 0, "Filter"))
