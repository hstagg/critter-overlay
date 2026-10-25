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
			k.start_behaviour(b, main.evaluator.duration_of(b))
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
		"open":
			main.open_settings(arg)
		"url":
			OS.shell_open(arg)


# --- Pairs, clothes, events ----------------------------------------------------------

func pair(name: String) -> void:
	var d: Array = Pairs.PAIRS[name]
	var sa: String = d[3][0] if not d[3].is_empty() else "kitten"
	var sb: String = d[4][0] if not d[4].is_empty() else "rabbit"
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
	main.open_settings("system")
	await get_tree().process_frame
	var pages = main.settings_win.pages if main.settings_win != null else null
	if pages != null and pages.get("importer") != null:
		pages.importer.open_file(ProjectSettings.globalize_path(path))


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
	main.toasts.show_note(Icons.berry(40), "Admin", "v2.0 carry-over", "%d came over. Look in System and the Collection." % n)
	main.open_settings("system")


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
