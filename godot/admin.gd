extends Node
## The Admin page's hands (Settings > Admin, the developer's audit page):
## spawn exactly what is asked for, play every move of a species in turn,
## force a pair, try clothes on, and set off events. Only in the admin build
## (build-v3.ps1 -Admin); running from source, --admin.
##
## Nothing here touches the save except "Give berries" and, when asked,
## counting a spawn in the Collection. Dressing is for the look only: the
## Shop's outfit comes back with "Undress".

const Species := preload("res://species.gd")
const Customs := preload("res://customs.gd")
const Behaviours := preload("res://behaviours.gd")
const Pairs := preload("res://pairs.gd")
const Wear := preload("res://wear.gd")
const Onboarding := preload("res://gui/onboarding.gd")
const Critter := preload("res://critters/critter.gd")
const Icons := preload("res://gui/icons.gd")

const WALK_S := 4.0               # the walk at the start of a run of moves
const SIT_S := 1.5
const NAP_S := 5.0
const GAP_S := 0.7                # between moves

var main: Node
var hold := false                 # no arrivals and nobody leaves while auditing
var count_finds := false          # admin spawns count in the Collection

# A run of moves: one critter, each step in turn.
var seq_host = null
var seq: Array = []
var seq_i := -1
var now_playing := ""
var _left := 0.0
var _started := false


func _init(m: Node) -> void:
	main = m


static func versions(sp: String) -> Array:
	# The art folders of a species' Rare and Epic looks.
	if Species.is_special(sp):
		return []
	var out := Array(DirAccess.get_directories_at("res://art/%s" % sp))
	out.sort()
	return out


# --- Spawning -------------------------------------------------------------------

func spawn(sp: String, tier: String, version := "", variant := "", n := 1, mode := "walk") -> Array:
	# version "" is the tier's own look, "-" the Common look whatever the tier.
	var out := []
	for i in n:
		if main.hosts.size() >= main.HARD_MAX:
			break
		var at := Vector2(-1, -1)
		var h = main._spawn("roam", mode, at, sp, tier, version, variant)
		if h == null:
			break
		if count_finds and not Customs.is_custom(sp):
			main._announce(sp, h.tier, false, str(h.critter.get("variant")) if variant != "" or Species.is_special(sp) else "")
		out.append(h)
	return out


func spawn_looks(sp: String) -> void:
	# A species in each look it has: Common, Rare, Epic (or every colour).
	if Species.is_special(sp):
		for v in Species.variants(sp):
			spawn(sp, "legendary", "", v)
		return
	for t in ["common", "rare", "epic"]:
		spawn(sp, t, "", "", 1, "sit")


func spawn_versions(sp: String) -> void:
	# Every version drawn for a species, picked or not, to compare.
	for v in versions(sp):
		spawn(sp, "rare", v, "", 1, "sit")


func clear_all() -> void:
	stop_moves()
	for h in main.hosts.duplicate():
		if h.state == "live" and not h.leaving:
			h.leave()


func climb(sp: String, down := false) -> void:
	var area: Rect2 = main.area
	var d := area.size.x + area.size.y * 0.3 if not down else 2.0 * area.size.x + area.size.y * 1.2
	var h = main._spawn("perimeter", "walk", Vector2(area.position.x + d, 0), sp, "common")
	if h != null:
		h.critter.mode_left = INF
		h.critter.activity = 0.0


# --- Every move in turn ---------------------------------------------------------------

func play_moves(sp: String, only := "") -> void:
	# One critter, near the left of the screen, through its walk, sit, each
	# of its moves, then a nap and waking. `only` plays a single move.
	stop_moves()
	var area: Rect2 = main.area
	var hs: Array = spawn(sp, "common", "", "", 1, "sit")
	if hs.is_empty():
		return
	seq_host = hs[0]
	seq_host.critter.mode_left = INF
	seq_host.critter.activity = 0.0
	if only != "":
		seq = [only]
	else:
		seq = ["walk", "sit"]
		for b in Species.row(sp)["idles"]:
			if not b in ["nap", "wake_up"]:
				seq.append(b)
		seq += ["nap", "wake_up"]
	seq_i = -1
	_left = 1.0
	_started = true
	now_playing = "getting ready"


func moves_of(sp: String) -> Array:
	return ["walk", "sit"] + Species.row(sp)["idles"].filter(func(b): return b != "wake_up")


func stop_moves() -> void:
	seq = []
	seq_i = -1
	now_playing = ""
	_started = false
	if seq_host != null and is_instance_valid(seq_host):
		seq_host.critter.activity = 1.0
		seq_host.critter.mode_left = 3.0
	seq_host = null


func _process(delta: float) -> void:
	if seq.is_empty():
		return
	if seq_host == null or not is_instance_valid(seq_host) or seq_host.state == "popping":
		stop_moves()
		return
	var k = seq_host.critter
	k.mode_left = INF
	if _started:
		# The step under way: wait out its time, or for its move to end.
		_left -= delta
		var busy: bool = k.act != "" or k.act_pending != ""
		if _left > 0.0 or busy or k.airborne:
			return
	_started = true
	seq_i += 1
	if seq_i >= seq.size():
		now_playing = "done (%d moves)" % seq.size()
		seq = []
		return
	var b: String = seq[seq_i]
	now_playing = "%s (%d of %d)" % [b.replace("_", " "), seq_i + 1, seq.size()]
	print("ADMIN ", now_playing)
	match b:
		"walk":
			k._go_walk()
			_left = WALK_S
		"sit":
			k._go_sit()
			_left = SIT_S
		"nap":
			k.go_to_sleep()
			_left = NAP_S
		"wake_up":
			k.wake_up()
			_left = 2.0
		_:
			if not k.can_start_behaviour():
				# Not ready yet (landing, or still settling): try again shortly.
				seq_i -= 1
				_left = 0.3
				return
			k.start_behaviour(b, main.evaluator.duration_of(b, k))
			_left = GAP_S


# --- The audit's Run buttons ---------------------------------------------------------

func run(action: String, chosen := "kitten") -> void:
	# What a Run button on the audit does (gui/admin_page.gd checks()).
	var kind := action.get_slice(":", 0)
	var arg := action.substr(kind.length() + 1)
	match kind:
		"moves":
			play_moves(arg)
		"looks":
			spawn_looks(arg)
		"versions":
			spawn_versions(arg if arg != "" else chosen)
		"wear":
			var s := arg.get_slice(":", 0)
			var items := arg.get_slice(":", 1).split(",")
			spawn(s, "common", "", "", 1, "walk")
			spawn(s, "common", "", "", 1, "sit")
			dress(s, Array(items))
		"hoods":
			spawn("kitten", "common", "", "", 1, "sit")
			spawn("rabbit", "common", "", "", 1, "sit")
			spawn("hedgehog", "common", "", "", 1, "sit")
			dress("kitten", ["frog_hood"])
			dress("rabbit", ["bear_hood"])
			dress("hedgehog", ["dino_hood"])
		"pair":
			pair(arg)
		"auras":
			for t in ["common", "rare", "epic"]:
				spawn("kitten", t, "", "", 1, "sit")
			spawn("unicorn", "legendary")
		"toasts":
			toasts()
		"windows":
			window_churn()
		"desktop":
			desktop_check()
		"early_gift":
			early_gift()
		"present":
			present()
		"climb":
			climb(chosen)
			climb(chosen, true)
		"throw":
			if main.hosts.size() < 2:
				spawn("kitten", "common", "", "", 2, "sit")
			get_tree().create_timer(1.0).timeout.connect(func(): throw())
		"nap":
			everyone_nap()
			get_tree().create_timer(10.0).timeout.connect(func(): everyone_wake())
		"rare_hour":
			rare_hour_now()
		"eight":
			for i in 8:
				spawn(Species.DATA.keys().pick_random(), "common")
		"screen":
			# As if the display had changed: the next look (every 2 s) finds
			# the work area different, measures again and draws everyone again.
			if main.hosts.is_empty():
				for i in 3:
					spawn(Species.DATA.keys().pick_random(), "common")
			main.area = Rect2(main.area.position, main.area.size * 0.5)
		"welcome":
			welcome()
		"homemade":
			homemade()
		"import_test":
			import_test()
		"carry_test":
			carry_test()
		"kit":
			kit_test(arg)
		"dress_pixelcat":
			dress_pixel_cat()
		"own_sound":
			own_sound()
		"colour_picker":
			colour_picker_test()
		"kit_pair":
			kit_pair(arg)
		"dress_kit":
			dress_kit_all()
		"wear_sheet":
			wear_sheet()
		"open":
			main.open_settings(arg)
		"url":
			OS.shell_open(arg)


# --- Pairs, clothes, events ----------------------------------------------------------

func pair(name: String, sa := "", sb := "") -> void:
	var d: Array = Pairs.PAIRS[name]
	if sa == "":
		sa = d[3][0] if not d[3].is_empty() else "kitten"
	if sb == "":
		sb = d[4][0] if not d[4].is_empty() else "rabbit"
	var c: Vector2 = main.area.get_center() + Vector2(0, 120)
	# 120 px apart: any further and the walk over outlasts the 8 s approach
	# limit at the slower cruise speeds (pairs.gd APPROACH_LIMIT).
	var a = main._spawn("roam", "sit", c - Vector2(60, 0), sa, "common")
	var b = main._spawn("roam", "sit", c + Vector2(60, 0), sb, "common")
	if a == null or b == null:
		return
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(a) and is_instance_valid(b):
			a.critter.paired = false
			b.critter.paired = false
			main.pairs.cool.clear()
			main.pairs._start(name, a, b, Critter.zoom))


func dress(sp: String, items: Array) -> void:
	for h in main.hosts:
		if h.species == sp and h.state != "popping":
			h.critter.wear(items, main.economy.dyed.get(sp, {}))


func undress(sp: String) -> void:
	main._redress(sp)


func toasts() -> void:
	main._run_toast_demo()


func early_gift() -> void:
	# The next early gift now (Economy.EARLY_GIFTS, D32): its note, and the
	# berries in the tray and the Shop. Once all four are paid, the ladder
	# starts again, as for a new player.
	var e = main.economy
	if e.early_done():
		e.early_paid = []
		e.early_min = 0.0
		e.early_days = 0
		e.early_day = ""
		e.save()
		now_playing = "Early gifts: back to the start, as for a new player"
		return
	for i in e.EARLY_GIFTS.size():
		if not i in e.early_paid:
			e.pay_early(i)
			now_playing = "Early gifts: %d of %d paid" % [e.early_paid.size(), e.EARLY_GIFTS.size()]
			return


func desktop_check() -> void:
	# Stay on the desktop: switched on with critters out, then asks Windows
	# whether they are below this Settings window (an ordinary app window).
	if not main.desktop_ok():
		now_playing = "Stay on the desktop: the Windows helper is missing or too old"
		return
	if main.hosts.is_empty():
		for i in 3:
			spawn(Species.DATA.keys().pick_random(), "common")
	main.settings.set_value("world.on_desktop", true)
	await get_tree().create_timer(1.5).timeout
	var sw = main.settings_win
	if sw == null or not sw.visible:
		now_playing = "Stay on the desktop: on"
		return
	var hw := func(win: Window) -> int: return DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, win.get_window_id())
	var mine: int = main.native.window_z(hw.call(sw))
	var below: int = main.hosts.filter(func(h): return main.native.window_z(hw.call(h.win)) > mine).size()
	now_playing = "Stay on the desktop: on; %d of %d critters behind this window. Turn it off in World or the tray." % [below, main.hosts.size()]
	print("ADMIN ", now_playing)


func window_churn(rounds := 10) -> void:
	# S2: rounds of pops and refills, a pause and a note each, then a note
	# with the window counts. With windows used again (win_pool.gd), the
	# number made stops near the most out at once instead of growing.
	var made_before: int = main.win_pool.made + main.toasts.pool.made
	for i in rounds:
		get_tree().create_timer(1.0 + i * 1.5).timeout.connect(func():
			for h in main.hosts.duplicate():
				if h.state == "live":
					h.pop()
			spawn(Species.DATA.keys().pick_random(), "common", "", "", 4)
			main._set_paused(true)
			main._set_paused(false)
			main.toasts.show_note(Icons.berry(40), "Admin", "Window churn %d of %d" % [i + 1, rounds], "Pops, refills, a pause and this note."))
	get_tree().create_timer(2.5 + rounds * 1.5).timeout.connect(func():
		var p = main.win_pool
		var tp = main.toasts.pool
		main.toasts.show_note(Icons.berry(40), "Admin", "Windows used again",
			"Critters: %d made, %d used again, %d spare. Notes: %d made, %d used again. Made during the run: %d." % [
				p.made, p.reused, p.spare.size(), tp.made, tp.reused, p.made + tp.made - made_before]))


func rare_hour_now() -> void:
	var e = main.economy
	e.rare_hour_enabled = true
	e.rare_hour_start = int(e._local_minute() / 60)


func everyone_nap() -> void:
	main._on_went_away()


func everyone_wake() -> void:
	main._on_came_back()


func throw() -> void:
	var live: Array = main.hosts.filter(func(h): return h.state == "live")
	if live.is_empty():
		return
	var a = live[0]
	a.foot = a.feet_on_screen()
	var to: Vector2 = live[1].body_centre() if live.size() > 1 else main.area.get_center() + Vector2(randf_range(-400, 400), -300)
	a.launch((to - a.body_centre()).normalized() * 1400.0)


func present() -> void:
	# A visitor arriving with a present: the look and the note, without
	# giving the item.
	var hs: Array = spawn(["kitten", "rabbit", "duckling", "hedgehog"].pick_random(), "rare")
	if hs.is_empty():
		return
	var h = hs[0]
	var item: String = Wear.ITEMS.keys().pick_random()
	h.critter.wear([item], {})
	main.toasts.show_sighting(h.species, h.tier, "A present", "A %s brought you something" % h.species.replace("_", " "),
		"The %s is yours. Find it in the Shop. (Admin: not really given.)" % Wear.item_name(item).to_lower())


func welcome() -> void:
	var w := Onboarding.new()
	main.add_child(w)
	w.open(main)


# --- Homemade critters (customs.gd) ----------------------------------------------------

func homemade() -> void:
	# Each switched-on homemade critter walks in, and the first sits too; a
	# test one is made first if there are none.
	if Customs.ids(true).is_empty():
		Customs.add("Test critter", [test_picture(false)], {"faces": "left"})
	for id in Customs.ids(true):
		spawn(id, "common")
	spawn(Customs.ids(true)[0], "common", "", "", 1, "sit")


func import_test() -> void:
	# The importer with a made-up photo: a critter on a plain grey background.
	var path := "user://admin_test_picture.png"
	test_picture(true).save_png(path)
	main.open_settings("my_critters")
	await get_tree().process_frame
	var pages = main.settings_win.pages if main.settings_win != null else null
	if pages != null and pages.get("my") != null:
		pages.my.importer.open_file(ProjectSettings.globalize_path(path))


func carry_test() -> void:
	# A made-up v2.0 folder (a still and a four-frame animation), carried over
	# as on an upgrade. Run twice: nothing more comes the second time.
	var root := "user://admin_v2_test"
	for spec in [["test-still-000001", 1, true, "Test still"], ["test-anim-000002", 4, false, "Test animation"]]:
		var folder: String = root.path_join(spec[0])
		DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
		for i in spec[1]:
			var img := test_picture(false)
			img.resize(120, 120 - i * 6)
			var can := Image.create(120, 120, false, Image.FORMAT_RGBA8)
			can.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, i * 6))
			can.save_png(folder.path_join("frames/frame_%d.png" % i))
		var f := FileAccess.open(folder.path_join("meta.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"schema_version": 2, "name": spec[3], "frame_count": spec[1],
			"import_method": "static_png" if spec[2] else "animated_gif", "procedural_animation": spec[2]}))
		f.close()
	var n := Customs.carry_over(root, {})
	main.toasts.show_note(Icons.berry(40), "Admin", "v2.0 carry-over", "%d came over. Look in My critters and the Collection." % n)
	main.open_settings("my_critters")


func _kitten_kit() -> String:
	# The kitten kit's id, made if needed; "" if it doesn't load.
	for k in Customs.ids():
		if Customs.all[k].get("name") == "Kitten kit":
			return k
	var Fixtures = load("res://critters/kit/fixtures.gd")
	return Customs.add_folder(Fixtures.kitten_kit("user://admin_kits/kitten"))


func kit_pair(name: String) -> void:
	# The kitten kit (made if needed) and a kitten do a generic pair.
	var id := _kitten_kit()
	if id != "":
		pair(name, id, "kitten")


# --- Clothes on homemade critters (F2) -------------------------------------------------

# Three heads no species has, in the head drawing's frame (the keys of
# design/wear/build.py SPECIES; side as kit_data.gd head_metrics() sets it).
const AWKWARD_HEADS := {
	"wide": {"cx": 150.0, "cy": 150.0, "rx": 135.0, "ry": 52.0, "eye_y": 154.0, "eye_dx": 62.0, "eye_r": 13.0, "chin": 202.0, "top": 98.0, "side": 1.0},
	"tall": {"cx": 150.0, "cy": 135.0, "rx": 42.0, "ry": 100.0, "eye_y": 120.0, "eye_dx": 17.0, "eye_r": 10.0, "chin": 235.0, "top": 35.0, "side": 0.8},
	"tiny": {"cx": 150.0, "cy": 205.0, "rx": 26.0, "ry": 22.0, "eye_y": 207.0, "eye_dx": 10.0, "eye_r": 5.0, "chin": 227.0, "top": 183.0, "side": 0.8},
}
const KITTEN_HEAD := {"cx": 150, "cy": 122, "rx": 92, "ry": 74, "eye_y": 124, "eye_dx": 38, "eye_r": 18, "chin": 196, "side": 1.0}
const SHEET_SCALE := 0.4       # each head 120 x 160 px
const SHEET_ACROSS := 5        # items to a row
const SHEET_PATH := "user://wear_contact_sheet.png"


func dress_kit_all() -> void:
	# The kitten kit (made if needed) sits and puts on every item homemade
	# critters can wear, one after another, then takes the last one off.
	var id := _kitten_kit()
	if id == "":
		main.toasts.show_note(Icons.berry(40), "Admin", "Kitten kit", "It didn't load: see the log.")
		return
	var hs := spawn(id, "common", "", "", 1, "sit")
	if hs.is_empty():
		return
	var h = hs[0]
	h.critter.mode_left = INF   # sits still to be looked at, as main.gd's clothes sheet does
	h.critter.activity = 0.0
	var ids := kit_items()
	for i in ids.size() + 1:
		get_tree().create_timer(1.0 + 1.5 * i).timeout.connect(func():
			if is_instance_valid(h) and h.state != "popping":
				h.critter.wear([ids[i]] if i < ids.size() else []))


static func kit_items() -> Array:
	# Every item a homemade critter can wear, in the catalogue's order.
	return Wear.ITEMS.keys().filter(func(i): return Wear.for_kits(i))


static func _head_svg(m: Dictionary) -> String:
	# A plain head with eyes and a body below it, for the contact sheet.
	var body := '<ellipse cx="%f" cy="%f" rx="%f" ry="44" fill="#E9D3B8" stroke="#6B4A3A" stroke-width="4"/>' % [m.cx, m.chin + 36.0, m.rx * 0.8]
	var head := '<ellipse cx="%f" cy="%f" rx="%f" ry="%f" fill="#F6E3CC" stroke="#6B4A3A" stroke-width="4"/>' % [m.cx, m.cy, m.rx, m.ry]
	var eyes := ""
	for s in [-1, 1]:
		eyes += '<circle cx="%f" cy="%f" r="%f" fill="#2B2330"/>' % [m.cx + s * m.eye_dx, m.eye_y, m.eye_r]
	return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -120 300 400" width="300" height="400">%s%s%s</svg>' % [body, head, eyes]


static func contact_sheet() -> Image:
	# Every item kits can wear on the kitten's head (as it ships) and on the
	# three AWKWARD_HEADS, drawn by wear_draw.gd: four heads to an item,
	# SHEET_ACROSS items to a row, in kit_items() order (the .txt beside the
	# PNG lists them).
	var heads := [KITTEN_HEAD, AWKWARD_HEADS.wide, AWKWARD_HEADS.tall, AWKWARD_HEADS.tiny]
	var cw := int(300 * SHEET_SCALE)
	var ch := int(400 * SHEET_SCALE)
	var gap := 10
	var block := Vector2i(cw * heads.size() + gap, ch + gap)
	var ids := kit_items()
	var rows := ceili(float(ids.size()) / SHEET_ACROSS)
	var sheet := Image.create(block.x * SHEET_ACROSS + gap, block.y * rows + gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var bare := []
	for m in heads:
		var img := Image.new()
		img.load_svg_from_string(_head_svg(m), SHEET_SCALE)
		img.convert(Image.FORMAT_RGBA8)
		bare.append(img)
	for n in ids.size():
		var at := Vector2i(gap + (n % SHEET_ACROSS) * block.x, gap + (n / SHEET_ACROSS) * block.y)
		var shade := Image.create(block.x - gap, ch, false, Image.FORMAT_RGBA8)
		shade.fill(Color(0.94, 0.95, 0.97) if (n + n / SHEET_ACROSS) % 2 == 0 else Color(0.98, 0.97, 0.93))
		sheet.blit_rect(shade, Rect2i(Vector2i.ZERO, shade.get_size()), at)
		for k in heads.size():
			var cell: Image = bare[k].duplicate()
			var item := Image.new()
			item.load_svg_from_string(Wear.svg_for_kit(ids[n], heads[k]), SHEET_SCALE)
			item.convert(Image.FORMAT_RGBA8)
			cell.blend_rect(item, Rect2i(Vector2i.ZERO, item.get_size()), Vector2i.ZERO)
			sheet.blend_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), at + Vector2i(k * cw, 0))
	return sheet


func wear_sheet() -> void:
	# Writes the contact sheet and its index to user:// and opens it.
	var img := contact_sheet()
	img.save_png(SHEET_PATH)
	var ids := kit_items()
	var lines := ["Clothes contact sheet: each item on the kitten's head, then wide, tall and tiny heads.",
		"%d items, %d to a row, left to right:" % [ids.size(), SHEET_ACROSS]]
	for n in ids.size():
		lines.append("row %d, %d: %s (%s)" % [n / SHEET_ACROSS + 1, n % SHEET_ACROSS + 1, Wear.item_name(ids[n]), ids[n]])
	var f := FileAccess.open(SHEET_PATH.get_basename() + ".txt", FileAccess.WRITE)
	f.store_string("
".join(lines) + "
")
	f.close()
	OS.shell_open(ProjectSettings.globalize_path(SHEET_PATH))


func own_sound() -> void:
	# A made-up two-note chirp as a WAV, given to the first homemade critter
	# (a test one if there are none), played now; it walks in to be popped.
	if Customs.ids(true).is_empty():
		Customs.add("Test critter", [test_picture(false)], {"faces": "left"})
	var id: String = Customs.ids(true)[0]
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050)   # 0.5 s
	for i in 11025:
		var hz := 880.0 if i < 5500 else 1320.0
		data.encode_s16(i * 2, int(9000.0 * sin(i * TAU * hz / 22050.0) * (1.0 - float(i % 5500) / 5500.0)))
	w.data = data
	var path := "user://admin_test_sound.wav"
	w.save_to_wav(path)
	var why := Customs.set_sound(id, path)
	if why != "":
		main.toasts.show_note(Icons.berry(40), "Admin", "Homemade sound", why)
		return
	main._play(id)
	spawn(id, "common")


func colour_picker_test() -> void:
	# The picker (gui/colour_picker.gd) in a dialog over Settings; the colour
	# used comes back in a note, which should match the hex field.
	main.open_settings("my_critters")
	load("res://gui/colour_picker.gd").open(main.settings_win, "#F6C28F", func(hex):
		main.toasts.show_note(Icons.berry(40), "Admin", "Colour picker", "It returned %s." % hex))


func kit_test(which: String) -> void:
	# A test kit made from the cast's own art (critters/kit/fixtures.gd):
	# "kitten" or "otter" with every part, beside the real one; "bare" (side-on)
	# or "oneface" (faces you) with only the required parts; "hop". Each
	# walks in and another sits.
	var Fixtures = load("res://critters/kit/fixtures.gd")
	var src := "user://admin_kits/" + which
	if which == "pixelcat":
		Fixtures.pixel_cat(src)
	elif which in ["slime", "ghost", "snake"]:
		Fixtures.blob_kit(src, which)
	elif which in ["duckling", "upright"]:
		Fixtures.duckling_kit(src, which == "upright", "waddle" if which == "duckling" else "hop")
	elif which in ["otter", "oneface"]:
		Fixtures.otter_kit(src, which == "oneface", "slide" if which == "otter" else "plod")
	else:
		Fixtures.kitten_kit(src, which == "bare", "hop" if which == "hop" else "trot")
	var id: String = Customs.add_folder(src)
	if id == "":
		main.toasts.show_note(Icons.berry(40), "Admin", "Test kit", "It didn't load: see the log.")
		return
	spawn(id, "common")
	spawn(id, "common", "", "", 1, "sit")
	if which in ["kitten", "otter", "duckling"]:
		spawn(which, "common")


func dress_pixel_cat() -> void:
	# F3: the pixel cat with its head marked walks and sits in a hat; the hat
	# follows its head, and goes while it waves (an unmarked clip).
	var src := "user://admin_kits/pixelcat_head"
	load("res://critters/kit/fixtures.gd").pixel_cat(src, true, true)
	var id: String = Customs.add_folder(src)
	if id == "":
		main.toasts.show_note(Icons.berry(40), "Admin", "Pixel cat", "It didn't load: see the log.")
		return
	spawn(id, "common")
	spawn(id, "common", "", "", 1, "sit")
	var hat := ""
	for item in Wear.ITEMS:
		if Wear.slot(item) == "head" and Wear.fits(item, id):
			hat = item
			break
	dress(id, [hat])


static func test_picture(with_background: bool) -> Image:
	# A round critter with ears and eyes, on grey or on nothing.
	var w := 300
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	img.fill(Color("#DCD8D0") if with_background else Color(0, 0, 0, 0))
	var outline := Color("#4A3466")
	var fur := Color("#F2B27A")
	for y in w:
		for x in w:
			var body := Vector2((x - 150) / 100.0, (y - 175) / 105.0).length_squared() <= 1.0
			var ear := (absf(x - 95.0) + (y - 40.0) * 0.45 < 30.0 or absf(x - 205.0) + (y - 40.0) * 0.45 < 30.0) and y > 40 and y < 110
			var eye := Vector2(x - 115, y - 150).length() < 14.0 or Vector2(x - 185, y - 150).length() < 14.0
			if eye:
				img.set_pixel(x, y, outline)
			elif body or ear:
				var edge := Vector2((x - 150) / 106.0, (y - 175) / 111.0).length_squared() > 0.9 and body and not ear
				img.set_pixel(x, y, outline if edge else fur)
	return img

func set_infinite(on: bool) -> void:
	# The developer's own PC (Economy.INFINITE_FLAG): berries never run out.
	# A file in this PC's app data, never part of a build's defaults.
	if on:
		var f := FileAccess.open(main.economy.INFINITE_FLAG, FileAccess.WRITE)
		if f != null:
			f.store_string("berries never run out on this PC (Admin page)
")
	else:
		DirAccess.remove_absolute(main.economy.INFINITE_FLAG)
	main.economy.infinite = on
	main.economy._top_up()
	main.economy.berries_changed.emit(main.economy.berries)
	main.economy.save()


func give_berries(n: int) -> void:
	main.economy.berries += n
	main.economy.save()
	main._update_tray()
