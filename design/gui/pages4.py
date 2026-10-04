from parts import *
from pages3 import EXTRA

# ============================================================ FOUNDATIONS
from theme import LIGHT, DARK, TIERS_HEX
TOKENS = [("Ground", "ground", "window"), ("Sidebar", "side", "nav rail"), ("Surface", "surface", "cards"),
          ("Raised", "raised", "buttons, chips"), ("Line", "line", "borders"), ("Track", "track", "sliders, choices"),
          ("Ink", "ink", "text"), ("Ink soft", "ink2", "secondary text"), ("Ink faint", "ink3", "hints, ticks"),
          ("Violet", "accent", "toggles, fills"), ("Grape", "btn", "primary button"), ("Grape lip", "btn-lip", "button shadow"),
          ("Plum ink", "acc-ink", "values, links, labels"), ("Outline", "outline", "control outline"), ("Danger", "dng-ink", "quit, clear")]

def sw(name, key, role):
    l, d = LIGHT[key], DARK[key]
    box = lambda h: f'<div style="width: 36px; height: 36px; border-radius: 11px; background: {h}; border: 2px solid #D5C8E8; box-sizing: border-box; flex-shrink: 0"></div>'
    return (f'<div style="display: flex; align-items: center; gap: 8px">{box(l)}{box(d)}<div style="font-size: 12.5px; line-height: 1.35; margin-left: 4px">'
            f'<div style="font-weight: 800; font-size: 13.5px">{name}</div><div style="color: var(--ink2)">{l} · {d}</div><div style="color: var(--ink3)">{role}</div></div></div>')

def foundations():
    lsw = "".join(sw(*x) for x in TOKENS)
    def tier_tiles():
        out = ""
        for k, name, fill, lt, li, dt, di in TIERS_HEX:
            out += f'''<div style="display: flex; flex-direction: column; gap: 10px; align-items: flex-start; padding: 14px; border-radius: 16px; background: var(--t-{k}-tint)">
<div style="display: flex; align-items: center; gap: 10px">{badge(k, 34)}<span class="disp" style="font-weight: 600; font-size: 20px; color: var(--t-{k}-ink)">{name}</span></div>
<div style="font-size: 12.5px; line-height: 1.5; color: var(--ink-body)">Fill {fill}<br>Tint {lt} · {dt}<br>Ink {li} · {di}</div>{tier_chip(k)}</div>'''
        return out
    tiers = tier_tiles()
    type_ = '''<div style="display: flex; flex-direction: column; gap: 12px">
<div style="display: flex; align-items: baseline; gap: 16px"><span class="disp" style="font-weight: 600; font-size: 32px">Page title</span><span style="font-size: 12.5px; color: var(--ink2)">Fredoka 600 · 32</span></div>
<div style="display: flex; align-items: baseline; gap: 16px"><span class="disp" style="font-weight: 600; font-size: 22px">Card title</span><span style="font-size: 12.5px; color: var(--ink2)">Fredoka 600 · 22</span></div>
<div style="display: flex; align-items: baseline; gap: 16px"><span class="lbl" style="margin: 0">Section label</span><span style="font-size: 12.5px; color: var(--ink2)">Fredoka 500 · 13 · caps</span></div>
<div style="display: flex; align-items: baseline; gap: 16px"><span style="font-weight: 800; font-size: 15px">Setting name</span><span style="font-size: 12.5px; color: var(--ink2)">Nunito 800 · 15</span></div>
<div style="display: flex; align-items: baseline; gap: 16px"><span style="font-size: 13px; color: var(--ink2)">Description text sits under each setting.</span><span style="font-size: 12.5px; color: var(--ink2)">Nunito 400 · 13</span></div>
<div style="display: flex; align-items: baseline; gap: 16px"><span class="val">120 px</span><span style="font-size: 12.5px; color: var(--ink2)">Fredoka 600 · 16 · value</span></div>
<div style="font-size: 12.5px; color: var(--ink2); max-width: 420px; line-height: 1.5">Both families are SIL Open Font Licence, bundled with the app as FontFile resources.</div></div>'''
    ctl = lambda label, inner: f'<div style="display: flex; flex-direction: column; gap: 10px"><div style="font-size: 12.5px; font-weight: 800; color: var(--ink2); text-transform: uppercase; letter-spacing: .05em">{label}</div><div style="display: flex; flex-wrap: wrap; gap: 12px; align-items: center">{inner}</div></div>'
    controls = (
        ctl("Buttons", btn("Primary", "bp") + btn("Secondary", "bs") + btn("Quiet", "bq") + btn("Danger", "bd") + '<button class="btn bx" aria-disabled="true">Coming soon</button>' + btn("Small", "bs", small=True))
        + ctl("Toggles and choices", toggle(True, "On") + toggle(False, "Off") + seg(["Seldom", "Normal", "Often"], 1, "Example") + '<button class="chip sel">Selected chip</button><button class="chip">Chip</button>')
        + ctl("Sliders", f'{slider(40, "Example slider", "Calm", "Lively", 280)}<div style="width: 340px">{stepped(["snail", "slow", "average", "fast", "rapid", "supersonic"], 2, "Stepped example")}</div>')
        + ctl("Inputs", f'<button class="dd">{badge("rare", 18)}<span style="flex: 1; text-align: left">Rare</span>{icon("chevd", 16)}</button><div class="step"><button aria-label="Fewer">{icon("minus", 16)}</button><span>2 critters</span><button aria-label="More">{icon("plus", 16)}</button></div>{keys("Ctrl", "Shift", "P")}<button class="ib" aria-label="Play">{icon("play", 16)}</button>{NEW}{SOON}')
        + ctl("Tooltip", f'<div style="display: flex; align-items: center; gap: 10px"><span class="rtt">Activity{info("tip")}</span><div role="tooltip" style="position: relative; width: 250px; background: var(--tip-bg); color: var(--tip-ink); font-size: 13px; line-height: 1.45; padding: 10px 12px; border-radius: 12px">Shows on hover after 400 ms and on keyboard focus.</div></div>')
    )
    dialog = f'''<div style="width: 420px; background: var(--surface); border: 2px solid var(--outline); border-radius: 24px; box-shadow: 0 5px 0 var(--lip); padding: 24px; box-sizing: border-box; display: flex; flex-direction: column; gap: 12px" role="dialog" aria-label="Reset all settings">
<div style="display: flex; align-items: center; gap: 12px"><div style="width: 52px; height: 52px; border-radius: 16px; background: var(--sp-kitten); display: flex; align-items: center; justify-content: center; overflow: hidden">{kit_head(46)}</div><h3 class="disp" style="margin: 0; font-weight: 600; font-size: 22px">Reset all settings?</h3></div>
<p style="margin: 0; font-size: 14px; line-height: 1.5; color: var(--ink-body)">Critters, odds and shortcuts go back to how they started. Your Collection is kept.</p>
<div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 6px">{btn("Cancel", "bq")}{btn("Reset", "bp", "reset")}</div></div>'''
    godot = [("Cards, buttons, dialogs", "PanelContainer and Button themes using StyleBoxFlat: flat fill, 2 px border, corner radius 20 for cards, 14 for buttons, 24 to 28 for dialogs."),
             ("The chunky lip", "StyleBoxFlat shadow with size 0 and offset (0, 3) in the lip colour (grape lip for primary buttons). Pressed state drops the offset to 0 and moves content down 2 px."),
             ("Toggles", "CheckButton with custom on and off icons drawn as SVG textures."),
             ("Segmented choices", "HBoxContainer of toggle-mode Buttons sharing a ButtonGroup, inside a PanelContainer."),
             ("Sliders", "HSlider with a themed grabber and grabber_area StyleBox for the filled part. Stepped ones use step 1 and labels in an HBoxContainer."),
             ("Critter thumbnails", "The live rig in a SubViewport for the large preview; pre-rendered textures for small tiles. Unseen silhouettes use modulate black at 18% in light mode and white at 20% in dark mode."),
             ("Rarity glow", "A soft circle texture behind the critter, tinted with the tier fill. No shaders needed."),
             ("Two themes", "Two Theme resources, light and dark, generated from the same token table. The app swaps them when DisplayServer.is_dark_mode() changes, unless the player picked one."),
             ("Not used", "No blur, no backdrop effects, no gradients other than the slider fill. Everything is a flat StyleBox, an SVG texture or a label.")]
    gl = "".join(f'<div style="display: grid; grid-template-columns: 170px minmax(0, 1fr); gap: 14px; padding: 9px 0; border-top: 2px solid var(--div)"><span style="font-weight: 800; font-size: 13.5px">{a}</span><span class="note">{b}</span></div>' for a, b in godot)
    return f'''<div style="width: 1280px; height: 2800px; box-sizing: border-box; padding: 48px; background: var(--ground); display: flex; flex-direction: column; gap: 28px">
{DEFS}
<div class="card" style="padding: 22px 24px; display: flex; flex-direction: column; gap: 16px"><div class="h2">Colour tokens, light and dark</div>
<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px 20px">{lsw}</div>
<div class="note" style="color: var(--ink2)">Left swatch light, right swatch dark. The theme follows the Windows setting unless the player picks one. The critter art never changes with the theme: behind critters sit warm pastel wells in light mode and muted ones in dark mode, so the ginger fur always sits on something warm rather than straight on violet.</div></div>
<div class="card" style="padding: 22px 24px; display: flex; flex-direction: column; gap: 16px"><div class="h2">Rarity tiers</div>
<div style="display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 14px">{tiers}</div>
<div class="th-dark" style="display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 14px; background: var(--surface); padding: 14px; border-radius: 18px; color: var(--ink)">{tiers}</div>
<div class="note" style="color: var(--ink2)">Epic moved from lilac to rose so it no longer blends into the violet theme, and Rare Hour moved to night blue for the same reason. Each tier keeps its own shape as well as its own colour, so the tiers read for colour-blind players and in greyscale. Every tier ink passes 4.5:1 on its tint and on the card surface in both themes.</div></div>
<div style="display: grid; grid-template-columns: minmax(0, 1fr) 460px; gap: 28px">
<div class="card" style="padding: 22px 24px; display: flex; flex-direction: column; gap: 18px"><div class="h2">Controls</div>{controls}</div>
<div style="display: flex; flex-direction: column; gap: 28px">
<div class="card" style="padding: 22px 24px; display: flex; flex-direction: column; gap: 16px"><div class="h2">Type</div>{type_}</div>
<div style="display: flex; flex-direction: column; gap: 12px"><div class="h2">Confirm dialog</div>{dialog}</div>
</div></div>
<div class="th-dark card" style="padding: 22px 24px; display: grid; grid-template-columns: minmax(0, 1fr) 440px; gap: 28px; color: var(--ink); background: var(--ground)">
<div style="display: flex; flex-direction: column; gap: 18px"><div class="h2" style="color: var(--ink)">Controls, dark</div>{controls}</div>
<div style="display: flex; flex-direction: column; gap: 12px"><div class="h2" style="color: var(--ink)">Confirm dialog, dark</div>{dialog}</div></div>
<div class="card" style="padding: 22px 24px 14px"><div class="h2" style="margin-bottom: 10px">Building it in Godot 4</div>{gl}</div>
</div>'''

# ============================================================ NOTES
MAP = [
    ("Window and sidebar", None),
    ("Sidebar status pill (Running or Paused)", "Sidebar status card: Gathering, Napping or Paused, with focus time and the next-critter bar. Also the tray panel header."),
    ("Sidebar Spawn Now", "Sidebar Spawn now, Home Spawn now, tray Spawn a critter."),
    ("Sidebar Pause / Resume", "Sidebar Pause critters, Home Pause, tray Pause or Resume."),
    ("Version label", "Sidebar Version 3.0 and System > About."),
    ("Close button hides to tray", "Kept. Window close button reads Close to tray."),
    ("Critters tab", None),
    ("Import image, Import frames, Import .critter, Export all", "Deferred. Placeholder only: the Your own tile on Critters and the Custom critters card on System, both marked Coming soon."),
    ("Species card: enabled toggle", "Critters > species detail > Visits your desk."),
    ("Species card: spawn frequency (rare, normal, often, constant)", "How often it visits: Seldom, Normal, Often, Constant. Rare is renamed so it only ever means a rarity tier."),
    ("Species card: speed (snail to supersonic)", "Speed, same six stops."),
    ("Species card: activity level (wired to narcoleptic)", "Activity, same six stops, with tooltip."),
    ("Species card: animation trail (7 options)", "Trail chips, same seven options."),
    ("Species card: animated preview", "Large animated preview in the detail panel, small tiles in the picker."),
    ("Reset all weights to default", "Reset all critters (page header) and Reset kitten (per critter)."),
    ("Custom critter rows (rename, toggle, weight, size, speed, idle, trail, sound preset, upload, preview, export, delete)", "Deferred with custom critters."),
    ("Tooltips on personality controls", "Info icon beside each control that needs one; tooltip on hover and keyboard focus."),
    ("Behaviour tab", None),
    ("Spawn frequency (every N minutes)", "Focus > Timer arrivals > New group every."),
    ("Min and max animals per spawn", "Focus > Timer arrivals > Smallest group and Largest group."),
    ("Solo walkers toggle and frequency", "Focus > Solo walkers."),
    ("Day / night cycle (listed twice in v2.0)", "World > Living world > Day and night pacing, once."),
    ("Behaviour frequency (listed twice)", "World > Living world > Behaviour frequency, Calm to Lively."),
    ("Pair interactions (listed twice)", "World > Living world > Pair interactions."),
    ("Enable rarity tiers", "World > Rarity > Rarity tiers."),
    ("Tier distribution (5 sliders)", "World > Rarity > Odds, with 1 in N hints and a reset."),
    ("Rare hour toggle and start hour", "World > Rare Hour > toggle and Starts at."),
    ("First spawn of the day bonus", "World > Rarity > First arrival of the day."),
    ("Audio tab", None),
    ("Sound enabled", "Sound > Pop sounds."),
    ("Volume", "Sound > Volume."),
    ("Per-species row: sound toggle and preview", "Sound > Every critter (now includes the two specials). Mirrored in Critters > Pop sound."),
    ("System tab", None),
    ("Launch on Windows startup", "System > Start with Windows, and onboarding step 4."),
    ("Keyboard shortcut Ctrl + Shift + P (display only)", "System > Shortcuts > Pause or resume, now changeable. Also onboarding and the tray hint."),
    ("Reset all settings", "System > Reset and quit > Reset, behind a confirm dialog that keeps the Collection."),
    ("Quit Critter Overlay", "System > Reset and quit > Quit, and tray Quit."),
    ("Check for updates on GitHub", "System > Updates > Check now, with inline status."),
    ("Critters I've seen (Seen Log)", "Its own Collection page, plus Home > Recent sightings and the tray Collection item."),
    ("About", "System > About, with Help, Credits and licences, Privacy."),
    ("Dialogs", None),
    ("First-run welcome modal (tray hint, hotkey, Don't show again, Open Settings)", "Four-step onboarding. It no longer closes itself after 8 seconds."),
    ("Import, frames, preview and install-confirm modals; delete confirm", "Deferred with custom critters."),
    ("Update result message boxes", "Inline status in System > Updates."),
    ("Tray menu", None),
    ("Settings, Spawn now, Pause / Resume (checked), Quit", "Styled tray panel with the same items plus Collection. Plain Windows menu as the fallback, same order."),
    ("Tray tooltip", "Critter Overlay · 6 critters out (or paused, or napping)."),
    ("In config but never in the v2.0 window", None),
    ("visual.animal_size, visual.opacity", "Critters > Everyone > Size and Opacity."),
    ("visual.animation_detail", "System > Display > Animation detail."),
    ("rarity.rare_hour.duration_minutes, rare_tier_boost", "World > Rare Hour > Lasts and Boost."),
    ("rarity.seen_log_enabled", "System > Collection > Keep a Seen Log."),
    ("animals.*.rarity_min and rarity_max", "Critters > species detail > Can appear as."),
]

def notes():
    rows = ""
    for a, b in MAP:
        if b is None:
            rows += f'<tr class="grp"><td colspan="2">{a}</td></tr>'
        else:
            rows += f'<tr><td class="g" style="white-space: normal; width: 44%">{a}</td><td>{b}</td></tr>'
    li = lambda xs: "".join(f'<li style="margin-bottom: 7px">{x}</li>' for x in xs)
    assumptions = [
        "Second pass: the whole GUI is rethemed to violet and plum. Light mode uses soft lavender surfaces; dark mode uses deep plum. Primary buttons are grape with the chunky toy-button lip kept.",
        "Decided after the first pass: the styled tray panel ships in v3.0, and the dark theme ships in v3.0, following the Windows setting by default (Match Windows is first in System, Display).",
        "Dark versions are drawn for Home, Critters, Collection and the tray panel. Other pages use the same tokens and are not drawn separately.",
        "The critter art is unchanged from the style sheet. Critters sit on warm pastel wells in light mode and muted wells in dark mode, never straight on violet.",
        "Epic moved from lilac to rose and Rare Hour moved from violet to night blue, so neither blends into the theme. Common, Uncommon, Rare and Legendary keep their hues, slightly adjusted.",
        "The tray icon stays a ginger kitten so it reads as the app, not as a purple blob, on both light and dark taskbars.",
        "The window is 1100 x 760 and borderless with its own title bar. Taller artboards show the whole page as it scrolls.",
        "Tabs are restructured from four to seven: Home, Critters, Focus, World, Sound, Collection, System. Presence gets its own page and the Seen Log becomes a top-level Collection.",
        "Gathering is the default way critters arrive. The v2.0 timer is kept as a second mode so nothing is lost.",
        "The unicorn and golden kitten appear as specials: shown in Critters, Sound and Collection, not in onboarding choices. Whether they can be switched off is open.",
        "Turtle and panda keep their Epic cap, shown as a lock on their Legendary slot in the Collection.",
        "The Collection shows first-met dates and a sightings diary. That needs a timestamp per sighting; v2.0 only stored counts.",
        "Rare sighting notes default to Rare and up.",
        "Three controls are new proposals, marked New: Pause in full-screen apps, Tidy up after a long break, and a Spawn a critter shortcut.",
        "Fonts are Fredoka and Nunito, both open licence.",
        "Every number on screen (42 min, 6 of 8, counts, dates) is sample data.",
        "Custom critters are out of scope: two placeholder entry points only.",
    ]
    fixes = [
        "Day / night, behaviour frequency and pair interactions each appeared twice on the v2.0 Behaviour tab. Now once.",
        "The v2.0 odds sliders ran from 0 to 50%, so Common's 90% default could not be shown or set. The new odds scale covers the full range and stretches at the low end.",
        "Six settings existed in config with no control in the window. All six now have one.",
        "The v2.0 welcome closed itself after 8 seconds and marked first run as done, so a player who looked away never saw it.",
        "Spawn weight used the word rare, which clashed with the Rare tier.",
    ]
    return f'''<div style="width: 1280px; height: 2900px; box-sizing: border-box; padding: 48px; background: var(--ground); display: flex; flex-direction: column; gap: 28px">
<div class="card" style="padding: 24px 28px"><div class="h2" style="margin-bottom: 12px">Assumptions in this first pass</div><ul class="note" style="margin: 0; padding-left: 20px">{li(assumptions)}</ul></div>
<div class="card" style="padding: 24px 28px"><div class="h2" style="margin-bottom: 12px">v2.0 problems this layout fixes</div><ul class="note" style="margin: 0; padding-left: 20px">{li(fixes)}</ul></div>
<div class="card" style="padding: 24px 28px"><div class="h2" style="margin-bottom: 6px">Where every v2.0 control went</div>
<div class="note" style="color: var(--ink2); margin-bottom: 10px">Read from settings_window.py, main.py and config.py. Nothing is dropped except the custom critter controls, which are deferred to their own planning session.</div>
<table><thead><tr><th>v2.0</th><th>v3 layout</th></tr></thead><tbody>{rows}</tbody></table></div>
</div>'''
