extends RefCounted
## Settings > Admin: the developer's page for auditing a build. Spawn any
## critter in any tier, look or colour; play every move of a species in
## turn; force a pair; try clothes on; set off events. Below, the audit: each
## check has a Run button where the app can set it up, Pass / Fix / Idea, and
## a note. Notes are saved as they are typed to audit.json and audit.md in
## the app's data folder (%APPDATA%\Critter Overlay), where Claude reads them,
## and "Copy for Claude" puts the same text on the clipboard.
##
## Only in the admin build (build-v3.ps1 -Admin); the player build leaves this
## file and admin.gd out. Running from source: --admin.

const Palette := preload("res://gui/palette.gd")
const UI := preload("res://gui/ui.gd")
const K := preload("res://gui/controls.gd")
const Species := preload("res://species.gd")
const Wear := preload("res://wear.gd")
const Pairs := preload("res://pairs.gd")
const Collection := preload("res://gui/collection.gd")
const Admin := preload("res://admin.gd")

const SAVE := "user://audit.json"
const NOTES := "user://audit.md"
const TIERS := ["common", "rare", "epic", "legendary"]
const VERDICTS := [["pass", "Pass"], ["fix", "Fix"], ["idea", "Idea"]]
const CANVAS := "https://claude.ai/artifact/7A758ZZf5x3q7rvMhvAne4"

var w: Window                      # settings_window.gd
var sp := "kitten"
var tier := "common"
var look := 0                      # 0 the tier's own look, 1 the Common look, then each version or colour
var count := 1
var pose := "walk"
var move := 0
var pair_i := 0
var item_i := 0
var audit := {"round": 1, "items": {}, "ideas": ""}
var _loaded := false


func _init(win: Window) -> void:
	w = win


func A():
	return w.main.admin


# --- The checks ---------------------------------------------------------------------

func checks() -> Array:
	# [group, id, title, how, action]. An action is what Run does (see _run).
	var out := []
	for s in Species.DATA:
		var name := Collection.species_name(s)
		out.append(["The cast", "moves:" + s, "%s: every move" % name,
			"Walk, sit, each of its moves, a nap and waking, one after another. Blinks, legs, the face in each pose, the sound when popped.", "moves:" + s])
		if Species.is_special(s):
			out.append(["The cast", "looks:" + s, "%s: every secret colour" % name, "One of each colour, with its Legendary aura.", "looks:" + s])
		else:
			out.append(["The cast", "looks:" + s, "%s: Common, Rare and Epic" % name, "The three looks side by side, each with its aura and trail.", "looks:" + s])
	out.append(["The cast", "versions", "Every version drawn (pick the Rare and Epic)", "Spawns all the version concepts of the species chosen above, to compare.", "versions"])
	for s in Species.DATA:
		var own := Wear.ITEMS.keys().filter(func(i): return Wear.only(i) == s)
		if own.is_empty():
			continue
		out.append(["Clothes", "wear:" + s, "%s's own clothes" % Collection.species_name(s),
			"%s, walking and sitting. Do they sit right and follow the head?" % ", ".join(own.map(func(i): return Wear.item_name(i))), "wear:%s:%s" % [s, ",".join(own)]])
	out.append(["Clothes", "hoods", "Hoods hide ears", "Frog hood on kittens, bear hood on rabbits (their ears poke through), dino hood on hedgehogs.", "hoods"])
	out.append(["Clothes", "kit_dress", "The kitten kit tries on everything", "The kitten kit sits and puts on each item homemade critters can wear, one every 1.5 s: each sits on its own head as on the kitten's, hoods hide its ears, and no species' own item comes.", "dress_kit"])
	out.append(["Clothes", "kit_sheet", "Clothes fit homemade heads (contact sheet reviewed)", "Writes wear_contact_sheet.png (and a .txt naming each item) in Open folder and opens it: every item homemade critters can wear on the kitten's head, then on a wide, a tall and a tiny head. Anything that looks wrong goes on FITS_BADLY in wear.gd.", "wear_sheet"])
	out.append(["Clothes", "wardrobe", "The launch wardrobe, all 84", "On the clothes canvas: mark any to redo.", "url:" + CANVAS])
	for p in Pairs.PAIRS:
		out.append(["Together", "pair:" + p, "Pair: %s" % p.replace("_", " "), "Two critters, the interaction forced once.", "pair:" + p])
	out += [
		["Rarity", "auras", "Auras and trails, one of each tier", "A Common, Rare and Epic kitten and a Legendary unicorn. Subtle enough? Still special?", "auras"],
		["Rarity", "toasts", "Sighting notes", "Rare, Epic, Legendary, Rare Hour, a gift, welcome back, a full row.", "toasts"],
		["Rarity", "collection", "The Collection page", "Common, Rare and Epic per critter; a secret slot per colour for the visitors.", "open:collection"],
		["Rarity", "present", "A visitor with a present", "The look and the note (not really given here).", "present"],
		["Rarity", "odds", "The odds feel right", "95% Common, 4% Rare, 0.9% Epic, 0.1% Legendary, rarer the longer you stay. Judge over a day of normal use.", ""],
		["Moving about", "desktop", "Stay on the desktop", "Switches it on with critters out and asks Windows whether they are behind this window (the line above says how many). Then open an app over them: they walk behind it. Show desktop (Win+D) brings them into view; the tray turns it off.", "desktop"],
		["Moving about", "climb", "Climbing the side walls", "The critter chosen above goes up the right wall, then another down the left: head upright, body along the wall. Check every species.", "climb"],
		["Moving about", "throw", "Throwing", "Grab and fling: a good throw crosses the screen; a hard flick throws them out; dizzy after a spin; bumps.", "throw"],
		["Moving about", "nap", "Napping when you step away", "Everyone settles down, then wakes when you come back.", "nap"],
		["Moving about", "tidy", "Tidy up after a long break", "Step away longer than the setting (default an hour) and come back. Time behind a full-screen film does not count towards it.", ""],
		["Moving about", "rare_hour", "Rare Hour", "Starts it now: the note, and more Rares while it lasts.", "rare_hour"],
		["Moving about", "busy", "Eight at once", "Eight random critters: smooth? Anything clipping?", "eight"],
		["The app", "welcome", "First-run welcome", "The welcome screens as a new player sees them.", "welcome"],
		["The app", "settings", "Settings, every page", "Change things and watch the critters follow.", "open:home"],
		["The app", "early", "Early gifts", "A new player's first berries: 1,500 at 20 focus minutes, 500 at the first hour, 750 on a second and a third day of focus. Run pays the next one now (the note, the berries in the tray and the Shop); after the fourth it starts again. The tray's Gift in line counts down to the next one.", "early_gift"],
		["The app", "shop", "The Shop", "Dress up, dyes, treats, showpieces, perk clothes.", "open:shop"],
		["The app", "shortcuts", "Shortcuts", "Change the pause keys and set a spawn key in System; try them from another app.", "open:system"],
		["The app", "startup", "Start with Windows", "Restart the laptop: does it come back on its own?", ""],
		["The app", "native", "The Windows helper", "Rename the helper DLL beside the installed exe and start it: System says start-up, shortcuts and full-screen pause are off. The log's START line says native layer MISSING.", "open:system"],
		["The app", "startover", "Start over", "System > Start over: everyone leaves, the welcome opens, the Collection and berries are empty, and economy.json.before-start-over sits beside the save.", "open:system"],
		["The app", "help", "Log files and diagnostics", "System > Copy diagnostics and paste it: the START line, settings and the recent log. Open folder shows the logs.", "open:system"],
		["The app", "size", "Changing the size", "With a Legendary out wearing something, drag Critters > Size: it keeps its colour and outfit, nothing redraws until let go, and the showpieces resize.", "open:critters"],
		["The app", "v2custom", "v2.0 custom critters", "Upgrade from v2.0 with custom critters: one note says they are back, and they show in System and the Collection. It never shows again.", ""],
		["Homemade critters", "homemade", "Homemade critters walk, sit and nap", "Each switched-on homemade critter walks in (a test one is made if there are none), and one sits. A bob, a lean and a swing of its lower half; breathing when sitting; drag, throw, climb. No aura and no sighting note.", "homemade"],
		["Homemade critters", "my_critters", "My critters lists every homemade critter and imports a picture", "Every homemade critter is a card in one grid, with its badge (Shapes, Drawn, Animated, Picture) and chips to filter by them; Make a critter offers Use a picture, which imports one. The sidebar shows the count. In the player build the chooser shows Use a picture alone; here every way shows, and the unbuilt ones open a placeholder. Critters > Your own and System's pointer open this page.", "open:my_critters"],
		["Homemade critters", "import", "Import a critter", "My critters opens with a made-up photo in the importer: the grey goes at Normal, Gentle and Strong change it, Faces and Size change the walking preview, Keep adds it to the grid, Cancel leaves nothing behind.", "import_test"],
		["Homemade critters", "carry", "v2.0 custom critters come back", "A made-up v2.0 still and animation are carried over: both appear in My critters and the Collection. Run again: nothing more comes.", "carry_test"],
		["Homemade critters", "shelf", "The Homemade shelf", "The Collection shows each homemade critter idling, with its name, visits and badge, below the Legendary visitors; Open My critters links across.", "open:collection"],
		["Homemade critters", "manage", "On, off, how often, size, speed, sound, copy, delete", "Click a card in My critters: switched off, it stops arriving; Constant brings it often; Size and Speed change the next one out; Spawn one now brings one, free; Pop sound borrows a cast sound or adds your own; Change picture renames and resizes it; Make a copy adds \"<name> copy\"; Delete asks first and removes it.", "open:my_critters"],
		["The app", "colour_picker", "Colour picker returns the colour picked", "The picker opens over Settings: a swatch, the square, the hue strip and typing a hex all change the colour; Use this colour shows a note with the same hex as the field, and the colour heads Used lately next time.", "colour_picker"],
		["Homemade critters", "kit:kitten", "Kitten kit walks, sits, naps and blinks like the kitten", "The kitten rebuilt as a side-on kit walks in beside a real kitten, and another sits. Same size, same walk, same face; it naps in the kitten's loaf and blinks. Throw it, let it climb.", "kit:kitten"],
		["Homemade critters", "kit:bare", "Bare kit naps with a body and blinks", "A kit with only a body, head, eyes and two legs: far legs darker behind, sits on its walking body, naps as a melted loaf on the ground (not a floating head), blinks by squashing its eyes. Never swishes a tail or flicks an ear.", "kit:bare"],
		["Homemade critters", "kit:hop", "A hopping kit", "The bare kit with the hop gait: hops like the rabbit, never stops or turns in mid-air.", "kit:hop"],
		["Homemade critters", "kit:otter", "Otter kit sits facing you and walks side-on", "The otter rebuilt as a faces-you kit beside a real otter: sits facing you, walks with its side face, slides on its belly now and then, naps in the otter's loaf.", "kit:otter"],
		["Homemade critters", "kit:oneface", "One-face kit keeps its face while walking", "A faces-you kit with no side face, one ear and no nap drawing: the front face stays on while it plods, the other ear is mirrored, it naps as a melted loaf.", "kit:oneface"],
		["Homemade critters", "kit:duckling", "Duckling kit stands and waddles like the duckling", "The duckling rebuilt as an upright kit beside a real duckling: both wings sitting, the near wing walking, the tuft on a spring, the fluff-up groom, preen and peck with its beak.", "kit:duckling"],
		["Homemade critters", "kit:upright", "Bare upright kit", "Only a body, head, eyes, one leg and one wing, hopping: the far leg darker, the other wing mirrored, walks on its body, naps as a ball.", "kit:upright"],
		["Homemade critters", "kit:slime", "Blobs: the slime bounces", "A legless slime with one antenna: squash, spring and land; naps melted (wider, lower); climbs a wall as a slide; throw and pop it.", "kit:slime"],
		["Homemade critters", "kit:ghost", "Blobs: the ghost floats", "A ghost with no head: hovers 10 to 20 units up with a slow bob in every pose, eyes on its body; throw it and it lands softly and rises again.", "kit:ghost"],
		["Homemade critters", "kit:snake", "Blobs: the snake slithers", "A snake: a side-to-side wave along the ground, tail flicking; never stretches, hunts or scratches.", "kit:snake"],
		["Homemade critters", "kit:pixelcat", "Frame critter walks, sits, naps, plays its act clips, climbs and is thrown", "A pixel cat drawn frame by frame: its walk keeps pace with the ground, it sits and blinks with its own frames, naps on its sit frames, waves now and then (its own clip), and climbs and flies when thrown on its fallbacks.", "kit:pixelcat"],
		["Homemade critters", "own_sound", "Imported sound plays on pop", "A made-up chirp is given to the first homemade critter and played; it walks in: pop it and throw it, and the chirp plays at the set volume (and not at all with Pop sounds off).", "own_sound"],
		["Homemade critters", "kit_pair:sniff", "Homemade critters join generic pairs only", "The kitten kit walks over to a kitten and sniffs. Run kit_pair:sit_together too. In normal use a homemade critter only ever sniffs, stares, bows (if it can stretch), sits together or bumps.", "kit_pair:sniff"],
		["Moving about", "screen", "The display changes", "Run: within 2 s everyone is drawn again where they stood, inside the screen. Then for real on the test VM: change the resolution, move the taskbar, undock.", "screen"],
		["Moving about", "dpi", "Display scale", "At 150% Windows scaling, critters are 1.5x the Size setting and Settings, the tray and notes are drawn larger; on a small screen Settings shrinks to fit.", ""],
		["Moving about", "windows", "Windows used again", "Ten rounds of pops, refills, a pause and a note, then a note with the counts: the windows made during the run stay near the most out at once (a dozen at most, not 40 or more), nothing flashes up mid-screen, and pausing hides everyone. On the VM, GDI objects stay flat over a soak.", "windows"],
		["Moving about", "fullscreen", "A full-screen app", "Play a full-screen video for a minute in timer mode: no critter or showpiece shows over it, none arrive, and they come back after.", ""],
		["The app", "secret", "Secret visitors", "Before meeting a visitor its Collection card is a silhouette with one ? (no colour count); after, its picture is a colour you have met.", "open:collection"],
		["The app", "bank", "Rolls come from focus time", "System > Copy diagnostics shows the rolls banked: one per 5.5 focus minutes, at most 6. With none banked, arrivals are Common.", "open:system"],
		["The app", "spawnprice", "Spawn now costs berries", "With fewer berries than the price, Spawn now says so and nothing comes; with enough, the price goes and the critter rolls its rarity.", ""],
		["The app", "charm", "The lucky charm", "Put a lucky charm on any critter: diagnostics shows luck 1.5x higher on every roll, once however many wear one.", "open:shop"],
		["The app", "tuning", "Odds and tier ranges", "Only the admin build shows World > Odds and each critter's Can appear as; the player build has neither.", "open:world"],
		["The app", "saves", "Saves survive damage", "Quit, put junk in economy.json, start again: the Collection comes back from the .bak and the junk is kept as economy.json.corrupt-<time>.", ""],
		["The app", "v2", "Your v2.0 settings carried over", "Rare Hour, behaviour frequency, size, trails, and the old Seen Log in the Collection.", ""],
		["The app", "install", "Installer and update check", "Install over the old copy; System > Check for updates.", ""],
		["The app", "build", "Telling builds apart", "The tray icon's tooltip, About and the sidebar show the full version (3.0.0); the installer's name carries it too. Copy diagnostics shows arrivals and arrivals an hour.", "open:system"],
		["Codes", "code_redeem", "Redeem a code", "Run opens System > Codes with the test Supporter code pasted. Redeem: the thank-you note, then the Shop shows the moon nightcap, starry capelet and star glasses marked Supporter Pack, the moon cradle puts out, and Royal blue is on offer for owned clothes. About says \"Supporter: thank you.\" Redeem the code again: already redeemed.", "code:supporter"],
		["Codes", "code_wrong", "A code that isn't right", "Run pastes the test code with one letter changed: Redeem says it doesn't look right. Delete a few characters and Redeem again: the same. Nothing unlocks.", "code:wrong"],
		["Codes", "code_creator", "Creator code", "Run pastes the test creator code. Redeem: the note lists 25,000 berries, the director's beret, the Supporter Pack and creator mode, and the berries arrive once (quit and relaunch: no more). The beret is in the Shop marked Creator pack; System has a Creator section and the tray a Call a critter item.", "code:creator"],
		["Codes", "code_later", "A code for a later version", "Run pastes a test code of a kind this version doesn't know. Redeem: kept and listed, the note says it unlocks after an update, and nothing unlocks now.", "code:later_pack"],
		["Codes", "code_creator_mode", "Creator mode", "Run turns creator mode on (a session creator pack if no code gave it), opens System > Creator and calls each everyday species in each look: each walks in wearing its outfit, and the Collection and berries don't change. Call more past 25: it says no more can come. Switch Creator mode off: the tray's Call a critter goes. No Legendary visitor can be called.", "creator"],
		["Codes", "code_stay", "Codes stay", "With a creator code redeemed: Start over, quit and relaunch. The pack and creator mode are still there, and the creator berries come once more for the fresh start.", ""],
		["Codes", "code_none", "Without a code", "Run forgets this PC's codes (codes.json.before-forget is kept). No pack item anywhere in the Shop, no Royal blue among the colours, and System > Codes has the one line and the link to the pack's page. The Shop's \"Have a code?\" opens System > Codes.", "forget"],
		["Codes", "code_real", "A real code", "On the VM: one code from the developer's range of the real batch redeems in the installed player build.", ""],
		["The app", "credits", "Credits and notices", "System > About > Credits and licences lists Godot and its components, both fonts and godot-cpp. THIRD-PARTY-NOTICES.txt sits beside the installed exe.", "open:system"],
	]
	return out


# --- Page ------------------------------------------------------------------------------

func build(body: VBoxContainer) -> void:
	_load()
	var c := K.c
	var h := K.vbox(6)
	h.add_child(UI.label("Admin", 32, c.ink, 600, true))
	var sub := UI.label("For auditing the build. Only the admin build has this page; players never get it.", 15, c.ink2, 400)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(sub)
	body.add_child(h)
	body.add_child(K.section("Spawn", _spawn_card()))
	body.add_child(K.section("Moves", _moves_card()))
	body.add_child(K.section("Pairs, clothes, events", _events_card()))
	_audit(body)


func _species_list() -> Array:
	return Species.DATA.keys()


func _looks() -> Array:
	# [label, version, variant] for the Look dropdown.
	var out := [["Tier's own look", "", ""]]
	if Species.is_special(sp):
		out[0][0] = "Random colour"
		for v in Species.variants(sp):
			out.append([Collection.variant_name(v), "", v])
	else:
		out.append(["Common look", "-", ""])
		for v in Admin.versions(sp):
			var used := ""
			for t in ["rare", "epic"]:
				if Species.version_for(sp, t) == v:
					used = " (%s)" % t.capitalize()
			out.append([v.replace("_", " ").capitalize() + used, v, ""])
	return out


func _spawn_card() -> Control:
	var c := K.c
	var v := K.vbox(14)
	var r1 := HFlowContainer.new()
	r1.add_theme_constant_override("h_separation", 10)
	r1.add_theme_constant_override("v_separation", 10)
	var names := _species_list().map(func(s): return Collection.species_name(s))
	r1.add_child(K.dropdown(names, _species_list().find(sp), func(i):
		sp = _species_list()[i]
		look = 0
		if Species.is_special(sp):
			tier = "legendary"
		elif tier == "legendary":
			tier = "common"
		w.rebuild()))
	r1.add_child(K.dropdown(TIERS.map(func(t): return t.capitalize()), TIERS.find(tier), func(i):
		tier = TIERS[i]
		w.rebuild()))
	var looks := _looks()
	look = mini(look, looks.size() - 1)
	r1.add_child(K.dropdown(looks.map(func(l): return l[0]), look, func(i): look = i))
	r1.add_child(K.dropdown(["1", "2", "3", "4", "8"], ["1", "2", "3", "4", "8"].find(str(count)), func(i): count = [1, 2, 3, 4, 8][i]))
	r1.add_child(K.dropdown(["Walking", "Sitting"], 0 if pose == "walk" else 1, func(i): pose = ["walk", "sit"][i]))
	r1.add_child(K.button("Spawn", "bp", "sparkle", false, func():
		var l: Array = _looks()[look]
		A().spawn(sp, tier, l[1], l[2], count, pose)))
	v.add_child(r1)
	var r2 := HFlowContainer.new()
	r2.add_theme_constant_override("h_separation", 10)
	r2.add_theme_constant_override("v_separation", 10)
	r2.add_child(K.button("Every look of it", "bs", "", true, func(): A().spawn_looks(sp)))
	r2.add_child(K.button("Every version drawn", "bs", "", true, func(): A().spawn_versions(sp)))
	r2.add_child(K.button("Clear all critters", "bd", "trash", true, func(): A().clear_all()))
	v.add_child(r2)
	var r3 := K.hbox(18)
	r3.add_child(_check("Hold arrivals", "Nobody new arrives and nobody leaves", A().hold, func(on): A().hold = on))
	r3.add_child(_check("Count in Collection", "Admin spawns record a sighting, pay first finds and show notes", A().count_finds, func(on): A().count_finds = on))
	v.add_child(r3)
	return K.margins(_panel(v), 0, 0, 0, 0)


func _check(text: String, tip: String, on: bool, cb: Callable) -> Control:
	var h := K.hbox(8)
	h.add_child(K.toggle(on, text, cb))
	var l := UI.label(text, 14, K.c.ink, 700)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	h.add_child(l)
	return h


func _panel(inner: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var s := K.box(K.c.surface, 20, K.c.line, 2)
	s.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", s)
	p.add_child(inner)
	return p


func _moves_card() -> Control:
	var c := K.c
	var v := K.vbox(12)
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 10)
	r.add_theme_constant_override("v_separation", 10)
	r.add_child(UI.label("%s:" % Collection.species_name(sp), 15, c.ink, 800))
	r.add_child(K.button("Play every move", "bp", "play", false, func(): A().play_moves(sp)))
	var moves: Array = A().moves_of(sp)
	move = mini(move, moves.size() - 1)
	r.add_child(K.dropdown(moves.map(func(m): return m.replace("_", " ")), move, func(i): move = i))
	r.add_child(K.button("Play one", "bs", "", false, func(): A().play_moves(sp, A().moves_of(sp)[move])))
	r.add_child(K.button("Stop", "bq", "pause", false, func(): A().stop_moves()))
	v.add_child(r)
	var now := UI.label("", 14, c.acc_ink, 800)
	w.live["admin_now"] = now
	v.add_child(now)
	var hint := UI.label("The species is the one chosen under Spawn. The critter appears near the middle of the screen; move this window aside to watch.", 12, c.ink2, 400)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return _panel(v)


func _events_card() -> Control:
	var v := K.vbox(14)
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 10)
	r.add_theme_constant_override("v_separation", 10)
	var pairs := Pairs.PAIRS.keys()
	pair_i = mini(pair_i, pairs.size() - 1)
	r.add_child(K.dropdown(pairs.map(func(p): return p.replace("_", " ")), pair_i, func(i): pair_i = i))
	r.add_child(K.button("Play pair", "bs", "play", false, func(): A().pair(Pairs.PAIRS.keys()[pair_i])))
	v.add_child(r)
	var items := _items()
	item_i = mini(item_i, items.size() - 1)
	var r2 := HFlowContainer.new()
	r2.add_theme_constant_override("h_separation", 10)
	r2.add_theme_constant_override("v_separation", 10)
	r2.add_child(K.dropdown(items.map(func(i): return Wear.item_name(i) + ("  (%s)" % Collection.species_name(Wear.only(i)) if Wear.only(i) != "" else "")), item_i, func(i): item_i = i))
	r2.add_child(K.button("Put on every %s" % Collection.species_name(sp).to_lower(), "bs", "", false, func(): A().dress(sp, [_items()[item_i]])))
	r2.add_child(K.button("Undress", "bq", "reset", false, func(): A().undress(sp)))
	v.add_child(r2)
	var r3 := HFlowContainer.new()
	r3.add_theme_constant_override("h_separation", 10)
	r3.add_theme_constant_override("v_separation", 10)
	for e in [["Notes tour", func(): A().toasts()], ["Rare Hour now", func(): A().rare_hour_now()],
			["Everyone nap", func(): A().everyone_nap()], ["Everyone wake", func(): A().everyone_wake()],
			["Throw one", func(): A().throw()], ["A present", func(): A().present()],
			["Climb up", func(): A().climb(sp)], ["Climb down", func(): A().climb(sp, true)],
			["Welcome screens", func(): A().welcome()], ["+10,000 berries", _berries],
			["Dress the kitten kit in everything", func(): A().dress_kit_all()],
			["Make the clothes contact sheet", func(): A().wear_sheet()],
			["Open My critters", func(): A().run("open:my_critters")], ["Colour picker test", func(): A().colour_picker_test()],
			["Infinite berries: " + ("on" if w.main.economy.infinite else "off"), _infinite]]:
		r3.add_child(K.button(e[0], "bs", "", true, e[1]))
	v.add_child(r3)
	# Codes (codes.gd): packs for this session only, and forgetting this PC's codes.
	var r4 := HFlowContainer.new()
	r4.add_theme_constant_override("h_separation", 10)
	r4.add_theme_constant_override("v_separation", 10)
	var codes = w.main.codes
	for p in [["supporter", "Supporter Pack"], ["creator", "Creator"]]:
		var pack: String = p[0]
		var on: bool = codes.session.has(pack)
		r4.add_child(K.button("%s: %s" % [p[1], "on" if on else "off"], "bs", "", true, func():
			A().set_pack(pack, not on)
			w.rebuild()))
	r4.add_child(K.button("Forget codes", "bq", "reset", true, func():
		A().forget_codes()
		w.rebuild()))
	v.add_child(r4)
	return _panel(v)


func _infinite() -> void:
	A().set_infinite(not w.main.economy.infinite)
	w.rebuild()


func _berries() -> void:
	A().give_berries(10000)
	w.rebuild()


func _items() -> Array:
	var out := Wear.ITEMS.keys()
	out.sort_custom(func(a, b): return Wear.item_name(a) < Wear.item_name(b))
	return out


# --- The audit -------------------------------------------------------------------------

func _audit(body: VBoxContainer) -> void:
	var c := K.c
	var all := checks()
	var done := 0
	for ch in all:
		if audit.items.get(ch[1], {}).get("verdict", "") != "":
			done += 1
	var head := K.hbox(12)
	var t := K.vbox(4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label("Audit, round %d" % int(audit.round), 26, c.ink, 600, true))
	t.add_child(UI.label("%d of %d checked. Notes save as you type." % [done, all.size()], 13, c.ink2, 600))
	head.add_child(t)
	head.add_child(K.button("Copy for Claude", "bp", "check", true, func():
		DisplayServer.clipboard_set(_markdown())
		w.notice("Copied", "The audit is on the clipboard. Paste it into the chat with Claude.")))
	head.add_child(K.button("Open folder", "bs", "box", true, func(): OS.shell_open(ProjectSettings.globalize_path("user://"))))
	head.add_child(K.button("New round", "bq", "reset", true, func():
		w.confirm("Start round %d?" % (int(audit.round) + 1), "This round's answers are kept in audit-round-%d.json, and every check starts blank again." % int(audit.round), "Start", func():
			_save_as("user://audit-round-%d.json" % int(audit.round))
			audit = {"round": int(audit.round) + 1, "items": {}, "ideas": ""}
			_save()
			w.rebuild())))
	body.add_child(head)

	var groups := {}
	var order := []
	for ch in all:
		if not groups.has(ch[0]):
			groups[ch[0]] = []
			order.append(ch[0])
		groups[ch[0]].append(ch)
	for g in order:
		var rows := []
		for ch in groups[g]:
			rows.append(_check_row(ch))
		body.add_child(K.section(g, K.card(rows)))

	var ideas := TextEdit.new()
	ideas.text = audit.ideas
	ideas.placeholder_text = "Anything else: ideas from playing around, things that bugged you, what you would add."
	ideas.custom_minimum_size.y = 140
	ideas.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	ideas.add_theme_font_override("font", UI.font(600))
	ideas.add_theme_font_size_override("font_size", 14)
	ideas.text_changed.connect(func():
		audit.ideas = ideas.text
		_save())
	body.add_child(K.section("Ideas and anything else", ideas))


func _check_row(ch: Array) -> Control:
	var c := K.c
	var id: String = ch[1]
	var entry: Dictionary = audit.items.get(id, {"verdict": "", "note": ""})
	var v := K.vbox(8)
	var top := K.hbox(12)
	var text := K.vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(ch[2], 15, c.ink, 800))
	var how := UI.label(ch[3], 12, c.ink2, 400)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 200
	text.add_child(how)
	top.add_child(text)
	if ch[4] != "":
		var b := K.button("Run", "bs", "play", true, func(): _run(ch[4]))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(b)
	for vd in VERDICTS:
		var key: String = vd[0]
		var chip := K.chip(vd[1], entry.verdict == key, func():
			var e: Dictionary = audit.items.get(id, {"verdict": "", "note": ""})
			e.verdict = "" if e.verdict == key else key
			audit.items[id] = e
			_save()
			w.rebuild())
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(chip)
	v.add_child(top)
	var note := LineEdit.new()
	note.text = entry.note
	note.placeholder_text = "What is wrong, or the idea"
	note.add_theme_font_override("font", UI.font(600))
	note.add_theme_font_size_override("font_size", 13)
	note.text_changed.connect(func(t):
		var e: Dictionary = audit.items.get(id, {"verdict": "", "note": ""})
		e.note = t
		audit.items[id] = e
		_save())
	v.add_child(note)
	return K.margins(v, 20, 14, 20, 14)


func _run(action: String) -> void:
	A().run(action, sp)


# --- Saving ------------------------------------------------------------------------------

func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(SAVE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if typeof(d) == TYPE_DICTIONARY:
			audit.merge(d, true)


func _save() -> void:
	_save_as(SAVE)
	var f := FileAccess.open(NOTES, FileAccess.WRITE)
	if f != null:
		f.store_string(_markdown())


func _save_as(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(audit, "  "))


func _markdown() -> String:
	var lines := ["# Critter Overlay audit, round %d" % int(audit.round), "",
		"Build %s, %s." % [w.main.VERSION, Time.get_datetime_string_from_system(false, true)], ""]
	var group := ""
	for ch in checks():
		if ch[0] != group:
			group = ch[0]
			lines += ["", "## " + group, ""]
		var e: Dictionary = audit.items.get(ch[1], {})
		var vd: String = e.get("verdict", "")
		var mark: String = {"pass": "PASS", "fix": "FIX", "idea": "IDEA"}.get(vd, "not checked")
		var line := "- [%s] %s" % [mark, ch[2]]
		if str(e.get("note", "")).strip_edges() != "":
			line += ": " + str(e.note).strip_edges()
		lines.append(line)
	if str(audit.ideas).strip_edges() != "":
		lines += ["", "## Ideas and anything else", "", str(audit.ideas).strip_edges()]
	return "\n".join(lines) + "\n"
