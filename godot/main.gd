extends Node2D
## Critter Overlay v3: critters anywhere on the desktop, each in its own small
## transparent, always-on-top window (host.gd) that moves with it.
##
## This file owns the screen, arrivals, the behaviour evaluator, the presence
## layer and sound. Each critter's window, place on screen, drag, throw and
## pop live in host.gd; its rig, walking and behaviours in critters/ (the
## shared rig in critter.gd, each species in its own file, listed in species.gd).
##
## As in v2.0, most critters roam the whole screen and some walk round its
## edges; a click pops one, a drag throws it. The focus layer is new: two
## kittens to start, another wanders in every few minutes while you keep
## working, up to a cap. Step away and they settle into loaves and doze; come
## back and they wake, most with a stretch.
##
## Flags (after `--`):
##   --seconds=N        quit after N seconds; with --report=PATH write timings
##   --report=PATH      timings as JSON; live positions stream on stdout
##   --species=NAME     which critter to spawn (default kitten; see species.gd)
##   --kittens=N        a fixed number of roaming critters (no gathering)
##   --perimeter=N      and N more walking the screen's edges
##   --demo=NAME        one critter in the middle doing NAME on a loop: any
##                      behaviour, or walk, sit, loaf
##   --gather-every=S   seconds of focus per new visitor (default 720)
##   --away-after=S     seconds idle before they nap (default 180)
##   --idle-sim=P,A     fake presence: P seconds present, A away, repeating
##   --grab=PATH        save the first critter's window after two seconds; a
##                      PATH with %d saves a burst (--grab-start, --grab-frames,
##                      --grab-fps)
##   --zoom=Z           draw the critters Z times larger (for demo captures)
##   --no-passthrough   leave the critter windows wholly clickable
##   --stay=S           visits last up to S seconds of focus (testing)
##   --save=PATH        the economy save (timed runs use a throwaway one)
##   --open=PAGE        open Settings on PAGE at start (home, critters, focus,
##                      world, sound, collection, system)
##   --settings=PATH    the settings file (timed runs use a throwaway one)
##   --set=KEY:JSON     change a setting three seconds in, as Settings would
##                      (repeatable; testing live changes)
##   --settings-tour=DIR open Settings and save every page, scrolled through,
##                      as PNGs in DIR, then quit (testing)
##   --tier=NAME        every critter arrives at this rarity tier (testing)
##   --toast-demo       show one of each toast, a few seconds apart
##   --welcome          show the first-run welcome even if it has been seen
##   --welcome-tour=DIR save each step of the welcome as a PNG, then quit
##   --wear=A,B         every critter wears these (wear.gd ids; testing)
##   --wear-sheet=DIR   every clothing item on every critter, saved as
##                      DIR/<item>-<species>.png, then quit (--wear=A,B for some)
##   --throw-demo=SPEED throws the first critter at the second (px/s) after 1.5 s
##   --fake-pointer     a pretend pointer for the bond test: it circles the first
##                      critter for eight seconds, then rests
##   --beta             beta-tester mode, kept once set: the rarity odds and
##                      each critter's tier range can be changed in Settings
##   --pair-demo=NAME   two critters in the middle do pair interaction NAME
##                      (see pairs.gd), again every eight seconds
##   --selftest         check the click-through polygon and quit

const Critter := preload("res://critters/critter.gd")
const Species := preload("res://species.gd")
const Behaviours := preload("res://behaviours.gd")
const Presence := preload("res://presence.gd")
const Host := preload("res://host.gd")
const Region := preload("res://region.gd")
const Economy := preload("res://economy.gd")
const Tray := preload("res://gui/tray.gd")
const Collection := preload("res://gui/collection.gd")
const Toasts := preload("res://gui/toast.gd")
const Settings := preload("res://settings.gd")
const SettingsWindow := preload("res://gui/settings_window.gd")
const Onboarding := preload("res://gui/onboarding.gd")
const Palette := preload("res://gui/palette.gd")
const Aura := preload("res://aura.gd")
const Trail := preload("res://trail.gd")
const TimeOfDay := preload("res://time_of_day.gd")
const Pairs := preload("res://pairs.gd")
const Wear := preload("res://wear.gd")
const Prop := preload("res://prop.gd")
const Icons := preload("res://gui/icons.gd")

const VERSION := "3.0.0"
const HARD_MAX := 25            # never more critters than this, whatever the settings
const STAY_MIN := 30.0 * 60.0   # a visit lasts 30 to 50 minutes of focus
const STAY_MAX := 50.0 * 60.0
const TRAY_EVERY := 0.5
const UPDATE_URL := "https://api.github.com/repos/hstagg/critter-overlay/releases/latest"
const RELEASES_URL := "https://github.com/hstagg/critter-overlay/releases/latest"
const UPDATE_EVERY := 24 * 3600   # s between automatic checks

var area := Rect2()            # where critters live: the primary screen less the taskbar
var screen_rect := Rect2i()
var vsync_taken := false       # host.gd: only the first window waits for vsync
var t := 0.0

var hosts := []
var evaluator := Behaviours.new()
var pairs := Pairs.new()
var presence: Node
var gather_flag := -1.0       # --gather-every, over the setting
var away_flag := -1.0         # --away-after, over the setting
var zoom_flag := false        # --zoom, over the size setting
var focus_s := 0.0            # focus seconds this run (gathering, solo walkers)
var next_arrival := 0.0
var wall_s := 0.0             # seconds this run, not paused (timer arrivals)
var next_group := 0.0
var next_solo := 0.0
var tidied := false           # everyone went home during a long break
var busy_hidden := false      # hidden while a full-screen app has the screen
var busy_check := 0.0
var settings: Node
var settings_win: Window
var pace := 1.0               # World > Day and night pacing: how lively now
var spawn_rate := 1.0         # and how often they arrive
var night_sleep := 0.0        # and how sleepy
var tod_in := 0.0
var settings_path := ""
var tour_dir := ""
var shop_try_flag := ""       # --shop-try=ITEM[:DYE]: the tour shows it being tried on
var late_sets := []           # --set: [key, value], applied at three seconds
var fixed_count := -1
var fixed_perimeter := 0
var species := Species.DEFAULT
var species_fixed := false
var economy: Node
var tray: Node
var toasts: Node
var force_tier := ""
var toast_demo := false
var pair_demo := ""
var fake_pointer := false
var throw_demo := 0.0
var beta_flag := false
var wear_flag := []
var props := {}               # showpiece id -> prop.gd node on the desktop
var sheet_dir := ""
var stills_dir := ""
var welcome := ""             # --welcome: show | tour
var welcome_dir := ""
var waiting_welcome := false  # nobody arrives until the welcome is closed
var paused := false
var stay_scale := 1.0           # --stay: shorter visits for testing
var save_path := ""
var tray_in := 0.0
var open_on_start := ""
var native: RefCounted = null   # CritterNative (native/), when built
var demo := ""
var demo_wait := 0.5
var queued := []             # [kitten, seconds left, "sleep" | "wake"]
var sounds := {}
var player: AudioStreamPlayer

var seconds := 0.0
var report_path := ""
var process_ms := []
var fps := []
var pops := 0
var throws := 0
var live_timer := 0.0
var no_passthrough := false
var grab_path := ""
var grab_count := 0
var grab_frames := 16
var grab_fps := 15.0
var grab_next := 2.0


func _ready() -> void:
	presence = Presence.new()
	var selftest := false
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--seconds="):
			seconds = float(v)
		elif arg.begins_with("--report="):
			report_path = v
		elif arg.begins_with("--species="):
			if Species.has(v):
				species = v
				species_fixed = true
			else:
				printerr("Unknown species '%s'; known: %s" % [v, ", ".join(Species.DATA.keys())])
		elif arg.begins_with("--kittens="):
			fixed_count = int(v)
		elif arg.begins_with("--perimeter="):
			fixed_perimeter = int(v)
		elif arg.begins_with("--demo="):
			demo = v
		elif arg.begins_with("--gather-every="):
			gather_flag = float(v)
		elif arg.begins_with("--away-after="):
			away_flag = float(v)
		elif arg.begins_with("--idle-sim="):
			presence.sim = PackedFloat32Array([float(v.get_slice(",", 0)), float(v.get_slice(",", 1))])
		elif arg.begins_with("--grab="):
			grab_path = v
		elif arg.begins_with("--grab-frames="):
			grab_frames = int(v)
		elif arg.begins_with("--grab-start="):
			grab_next = float(v)
		elif arg.begins_with("--grab-fps="):
			grab_fps = float(v)
		elif arg.begins_with("--zoom="):
			Critter.zoom = float(v)
			zoom_flag = true
		elif arg == "--no-passthrough":
			no_passthrough = true
		elif arg.begins_with("--stay="):
			stay_scale = float(v) / STAY_MAX
		elif arg.begins_with("--save="):
			save_path = v
		elif arg.begins_with("--open="):
			open_on_start = v
		elif arg.begins_with("--settings="):
			settings_path = v
		elif arg.begins_with("--set="):
			var kv := arg.substr(6)
			late_sets.append([kv.get_slice(":", 0), JSON.parse_string(kv.substr(kv.find(":") + 1))])
		elif arg.begins_with("--shop-try="):
			shop_try_flag = v
		elif arg.begins_with("--settings-tour="):
			tour_dir = v
		elif arg.begins_with("--tier="):
			if v in Economy.TIERS:
				force_tier = v
			else:
				printerr("Unknown tier '%s'; known: %s" % [v, ", ".join(Economy.TIERS)])
		elif arg == "--toast-demo":
			toast_demo = true
		elif arg == "--welcome":
			welcome = "show"
		elif arg.begins_with("--welcome-tour="):
			welcome = "tour"
			welcome_dir = v
		elif arg.begins_with("--wear="):
			wear_flag = Array(v.split(","))
		elif arg.begins_with("--wear-sheet="):
			sheet_dir = v
		elif arg.begins_with("--stills="):
			stills_dir = v
		elif arg == "--beta":
			beta_flag = true
		elif arg.begins_with("--throw-demo="):
			throw_demo = float(arg.get_slice("=", 1))
		elif arg == "--fake-pointer":
			fake_pointer = true
		elif arg.begins_with("--pair-demo="):
			pair_demo = v
		elif arg == "--selftest":
			selftest = true

	if selftest:
		presence.free()
		set_process(false)
		get_tree().quit(0 if Region.selftest() == 0 else 1)
		return

	# Godot numbers the whole desktop from the top-left of all screens, so with
	# more than one monitor the primary does not start at (0, 0).
	var scr := DisplayServer.get_primary_screen()
	screen_rect = Rect2i(DisplayServer.screen_get_position(scr), DisplayServer.screen_get_size(scr))
	area = Rect2(DisplayServer.screen_get_usable_rect(scr))

	# The project's own window carries nothing: shrink it out of the way. The
	# critters' windows are real desktop windows, not embedded in it.
	var main_win := get_window()
	main_win.gui_embed_subwindows = false
	main_win.size = Vector2i(1, 1)
	main_win.position = screen_rect.position + Vector2i(0, screen_rect.size.y - 1)

	# Settings first: everything below reads them. A timed test run never
	# touches the real file.
	settings = Settings.new()
	if settings_path != "":
		settings.path = settings_path
	elif seconds > 0.0 or demo != "":
		# Each test run starts from the defaults.
		settings.path = OS.get_temp_dir().path_join("critter_test_settings.json")
		if FileAccess.file_exists(settings.path):
			DirAccess.remove_absolute(settings.path)
	add_child(settings)
	var v2 := _v2_settings() if settings_path == "" and seconds <= 0.0 and demo == "" and not FileAccess.file_exists(settings.path) else {}
	settings.load_file()
	if beta_flag:
		settings.set_value("system.beta", true)
	if not v2.is_empty():
		settings.import_v2(v2)
	Palette.theme = settings.value("system.theme")

	# The Windows layer, when built: one copy at a time, the global pause
	# shortcut, no taskbar button, and idle time from real devices only.
	# Without it the game still runs, on the PowerShell idle poller.
	if ClassDB.class_exists("CritterNative"):
		native = ClassDB.instantiate("CritterNative")
		var test_run := seconds > 0.0 or demo != ""
		if not test_run and not native.single_instance("CritterOverlay.v3"):
			print("Critter Overlay is already running")
			set_process(false)
			get_tree().quit()
			return
		var pk: Dictionary = settings.value("system.pause_key")
		native.start(int(pk.mods), int(pk.vk))
		get_tree().create_timer(0.3).timeout.connect(func():
			var sk: Dictionary = settings.value("system.spawn_key")
			if int(sk.vk) != 0:
				native.set_hotkey(1, int(sk.mods), int(sk.vk)))
		native.hide_from_taskbar(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, 0))
		presence.native = native

	randomize()
	player = AudioStreamPlayer.new()
	add_child(player)
	for sp in Species.DATA:
		_load_sound(Species.row(sp)["sound"])

	# The economy. A timed test run never touches the real save.
	economy = Economy.new()
	if save_path != "":
		economy.save_path = save_path
	elif seconds > 0.0:
		economy.save_path = OS.get_temp_dir().path_join("critter_test_economy.json")
	var fresh_economy := not FileAccess.file_exists(economy.save_path)
	add_child(economy)
	economy.load_save()
	if not v2.is_empty() and fresh_economy:
		economy.import_v2_seen(v2.get("rarity", {}).get("seen_log", {}))
	economy.sighting.connect(func(sp, tier, first): print("SIGHTING ", sp, " ", tier, " first" if first else ""))
	economy.gift_opened.connect(_on_gift)
	economy.welcome_back.connect(_on_welcome_back)
	economy.row_completed.connect(_on_row_completed)
	economy.bond_grew.connect(_on_bond_grew)
	for sp in Species.DATA:
		economy.row_caps[sp] = Species.row(sp).get("rarity_max", "epic")
		if Species.row(sp).get("special", false):
			economy.row_variants[sp] = Species.variants(sp)
	economy.fold_old_tiers()
	economy.rare_hour_changed.connect(_on_rare_hour)

	toasts = Toasts.new()
	add_child(toasts)
	toasts.open_collection.connect(func(sp): open_settings("collection", sp))
	toasts.closed.connect(func(url):
		if url == RELEASES_URL and _update_seen != "":
			settings.set_value("system.update_dismissed", _update_seen))
	if seconds <= 0.0 and demo == "":
		get_tree().create_timer(20.0).timeout.connect(_auto_update_check)
		var again := Timer.new()
		again.wait_time = 6 * 3600
		again.timeout.connect(_auto_update_check)
		add_child(again)
		again.start()
	if toast_demo:
		_run_toast_demo()

	tray = Tray.new()
	add_child(tray)
	tray.spawn_pressed.connect(spawn_now)
	tray.pause_pressed.connect(toggle_pause)
	tray.collection_pressed.connect(func(): open_settings("collection"))
	tray.settings_pressed.connect(func(): open_settings("home"))
	tray.quit_pressed.connect(quit_app)
	if open_on_start != "":
		# --open=PAGE, or PAGE:SPECIES (the Collection, scrolled to a critter)
		open_settings.call_deferred(open_on_start.get_slice(":", 0), open_on_start.get_slice(":", 1) if ":" in open_on_start else "")
	if tour_dir != "":
		_tour.call_deferred()
	if not late_sets.is_empty():
		get_tree().create_timer(3.0).timeout.connect(func():
			for kv in late_sets:
				settings.set_value(kv[0], kv[1]))

	add_child(presence)
	presence.went_away.connect(_on_went_away)
	presence.came_back.connect(_on_came_back)
	_apply_all()
	settings.changed.connect(_on_setting)
	sync_props()

	if demo in ["climb", "climb_down"]:
		# Up the right-hand wall, or down the left, for looking at the climb.
		var d := area.size.x + area.size.y * 0.3 if demo == "climb" else 2.0 * area.size.x + area.size.y * 1.2
		var h = _spawn("perimeter", "walk", Vector2(area.position.x + d, 0))
		h.critter.mode_left = INF
		h.critter.activity = 0.0
		return
	if demo != "":
		var h = _spawn("roam", "walk" if demo == "walk" else "sit", area.get_center() + Vector2(0, 40))
		h.critter.mode_left = INF
		return
	presence.start()
	if pair_demo != "":
		_run_pair_demo()
		return
	if sheet_dir != "":
		_wear_sheet()
		return
	if stills_dir != "":
		_stills()
		return
	if fixed_count > 0 or fixed_perimeter > 0:
		for i in maxi(fixed_count, 0):
			_spawn("roam", ["sit", "walk", "walk", "loaf"].pick_random())
		for i in fixed_perimeter:
			_spawn("perimeter", "walk")
		return
	# The first run: the welcome first, then the critters.
	var test_run := seconds > 0.0 and welcome == ""
	if welcome != "" or (not test_run and not settings.value("system.onboarded")):
		waiting_welcome = true
		var w := Onboarding.new()
		add_child(w)
		w.finished.connect(func(open_settings_too):
			waiting_welcome = false
			_first_critters()
			if open_settings_too:
				open_settings("home"))
		w.open(self)
		if welcome == "tour":
			_welcome_tour(w)
		return
	_first_critters()


func sync_props() -> void:
	# The showpieces put out in the Shop, standing on the taskbar.
	for pid in props.keys():
		if not economy.props_out.has(pid):
			props[pid].release_all()
			props[pid].queue_free()
			props.erase(pid)
	for pid in economy.props_out:
		if props.has(pid) or not Prop.PROPS.has(pid):
			continue
		var p = Prop.new()
		add_child(p)
		p.setup(self, pid, float(economy.props_out[pid]), Critter.zoom)
		p.moved.connect(func(id, f):
			economy.props_out[id] = f
			economy.save())
		props[pid] = p


func put_out(pid: String, out: bool) -> void:
	if out:
		economy.props_out[pid] = economy.props_out.get(pid, randf_range(0.15, 0.85))
	else:
		economy.props_out.erase(pid)
	economy.save()
	sync_props()


static func _v2_settings() -> Dictionary:
	# v2.0 kept its settings in %APPDATA%\CritterOverlay\settings.json.
	var path := OS.get_environment("APPDATA").path_join("CritterOverlay").path_join("settings.json")
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY and d.has("animals") else {}


func _first_critters() -> void:
	for i in mini(int(settings.value("focus.start_with")), _max_out()):
		_spawn("roam", ["sit", "walk", "walk", "loaf"].pick_random())
	next_arrival = focus_s + _gather_every()
	next_group = wall_s + _timer_every()
	next_solo = (wall_s if settings.value("focus.mode") == "timer" else focus_s) + _solo_every()


func _welcome_tour(w: Window) -> void:
	# --welcome-tour: each step saved for checking by eye.
	for i in 4:
		w._go(i)
		await get_tree().create_timer(1.0).timeout
		w.get_texture().get_image().save_png(welcome_dir.path_join("welcome-%d.png" % i))
	w.startup = is_startup()   # leave the real startup entry as it is
	w._done(false)
	await get_tree().create_timer(1.0).timeout
	print("WELCOME closed: onboarded ", settings.value("system.onboarded"), ", critters out ", hosts.size())
	print("TOUR done")
	_quit(0)


func _spawn(kind: String, start_mode: String, at := Vector2(-1, -1), sp := "", keep_tier := "", version := ""):
	# Every visitor rolls its rarity, with the session's luck, before it is
	# made: a Rare or Epic is a different version of the species, and a
	# Legendary is a special visitor. It goes in the Collection; a visit lasts
	# a while, then it leaves. A critter redrawn at a new size keeps its tier.
	var tier := keep_tier
	var bonus := false
	var rolled := false
	if tier == "" and economy != null and demo == "":
		var r: Array = _roll_visitor(sp)
		sp = r[0]
		tier = r[1]
		bonus = r[2]
		rolled = true
	elif sp == "":
		sp = _pick_species()
	if sp == "":
		return null   # every species is switched off
	if force_tier != "":
		tier = force_tier
	if version == "" and tier != "":
		version = Species.version_for(sp, tier)
	var h = Host.new()
	h.version = version
	add_child(h)
	h.setup(self, sp, Critter.zoom, kind, start_mode, at)
	h.gone.connect(_on_gone)
	hosts.append(h)
	_personalise(h)
	h.critter.wear(wear_flag if not wear_flag.is_empty() else economy.worn.get(sp, []), economy.dyed.get(sp, {}))
	if tier != "":
		h.tier = tier
	if rolled:
		_announce(sp, h.tier, bonus and force_tier == "", str(h.critter.get("variant") if "variant" in h.critter else ""))
		_maybe_bring(h)
		if fixed_count <= 0 and fixed_perimeter <= 0:
			h.stay_left = randf_range(STAY_MIN, STAY_MAX) * stay_scale
	_trail_for(h)
	return h


func _roll_visitor(sp: String) -> Array:
	# [species, tier, whether it was the day's first-visitor bonus]. The
	# everyday species top out at Epic; a Legendary roll brings a special
	# visitor instead (unless a species was asked for).
	if sp == "":
		sp = _pick_species()
	if sp == "":
		return ["", "", false]
	if Species.is_special(sp):
		return [sp, "legendary", false]
	var rarity_on: bool = settings.value("world.rarity")
	var row: Dictionary = settings.species(sp)
	var roll: Array = economy.roll_arrival("legendary", row.tier_min, Wear.luck_mult(economy.worn.get(sp, [])))
	var tier: String = roll[0] if rarity_on else "common"
	if tier == "legendary" and not species_fixed:
		var special := _pick_special()
		if special != "":
			return [special, "legendary", roll[1]]
	var top: String = Species.row(sp).get("rarity_max", "epic")
	if Economy.TIERS.find(row.tier_max) >= 0 and Economy.TIERS.find(row.tier_max) < Economy.TIERS.find(top):
		top = row.tier_max
	if Economy.TIERS.find(tier) > Economy.TIERS.find(top):
		tier = top
	return [sp, tier, roll[1]]


func _pick_special() -> String:
	var pool := Species.DATA.keys().filter(func(s): return Species.is_special(s) and settings.sp(s, "enabled"))
	return pool.pick_random() if not pool.is_empty() else ""


func _on_gift(index: int, berries: int, item: String) -> void:
	# The focus gifts at 25, 50, 90 and 150 minutes (economy design).
	print("GIFT ", index, " +", berries, " ", item)
	if _quiet() or toasts == null:
		return
	var mins: int = Economy.GIFTS[index][0]
	var sub := "%d berries" % berries + (", and a %s." % Wear.item_name(item).to_lower() if item != "" else ".")
	toasts.show_note(Icons.berry(40), "A gift", "%d minutes of focus" % mins, sub)


func _on_welcome_back(berries: int) -> void:
	print("WELCOME BACK +", berries)
	if _quiet() or toasts == null:
		return
	toasts.show_note(Icons.berry(40), "Welcome back", "The critters found something", "%d berries while you were away." % berries)


func _on_row_completed(sp: String, berries: int) -> void:
	print("ROW ", sp, " +", berries)
	if _quiet() or toasts == null:
		return
	var name := Collection.species_name(sp).to_lower()
	toasts.show_note(Icons.line("star", 40, Color("#D9961A")), "Collection", "Every %s met" % name,
		"%d berries, and a gold frame for its card." % berries, "#E3A72F")


func _on_bond_grew(sp: String, level: int) -> void:
	print("BOND ", sp, " ", level)
	if _quiet() or toasts == null:
		return
	var name := Collection.species_name(sp).to_lower()
	var what := "They say hello when your pointer comes near." if level == 1 else "One curls up beside your pointer when it rests."
	toasts.show_note(Icons.line("heart", 40, Color("#E07BA0")), "Bond", "Your %ss like you" % name, what, "#F590B4")


var _pointer_last := Vector2.ZERO
var _pointer_still := 0.0
var _snuggler = null


func _bond_tick() -> void:
	# Once a second. Level 1: a bonded critter near the pointer says hello.
	# Level 2: when the pointer rests, one walks over and curls up by it.
	var m := _pointer()
	var moved := m.distance_to(_pointer_last) > 6.0
	_pointer_last = m
	_pointer_still = 0.0 if moved else _pointer_still + 1.0
	if moved and _snuggler != null:
		if is_instance_valid(_snuggler):
			_snuggler.cancel_nap()
			_snuggler.critter.wake_up()
		_snuggler = null
	for h in hosts:
		if h.state != "live" or h.kind != "roam" or economy.bond_level(h.species) < 1:
			continue
		var k = h.critter
		if moved and h.feet_on_screen().distance_to(m) < 170.0 * Critter.zoom and k.can_start_behaviour() and not k.on_cooldown("hello"):
			k.cooldowns["hello"] = Behaviours.REGISTRY["hello"]["cool"]
			k.start_behaviour("hello", evaluator.duration_of("hello"))
	if _pointer_still >= 5.0 and _snuggler == null:
		var best = null
		var best_d := INF
		for h in hosts:
			if h.state == "live" and h.kind == "roam" and economy.bond_level(h.species) >= 2 and h.critter.can_start_behaviour():
				var d: float = h.feet_on_screen().distance_to(m)
				if d < best_d and d < 700.0 * Critter.zoom:
					best_d = d
					best = h
		if best != null:
			_snuggler = best
			best.nap_goal = Vector2(m.x + 50.0 * Critter.zoom, clampf(m.y + 60.0 * Critter.zoom, area.position.y + 200.0, area.end.y))


func _pointer() -> Vector2:
	if fake_pointer and not hosts.is_empty():
		if t < 8.0:
			return hosts[0].feet_on_screen() + Vector2(cos(t * 3.0), sin(t * 3.0)) * 60.0 - Vector2(0, 60)
		return Vector2(area.get_center().x, area.end.y - 120.0)
	return Vector2(DisplayServer.mouse_get_position())


func note_play(sp: String) -> void:
	# A click to pop is play: a little bond.
	economy.add_bond(sp, 1)


func _maybe_bring(h) -> void:
	# Now and then a visitor arrives wearing a present; one not yet owned is
	# a free gift (wear.gd BRING_CHANCE).
	var item: String = economy.roll_brought_item(h.tier, h.species)
	if item == "":
		return
	var outfit: Array = economy.worn.get(h.species, []).filter(func(x): return Wear.slot(x) != Wear.slot(item))
	h.critter.wear(outfit + [item], economy.dyed.get(h.species, {}))
	var got_it: bool = economy.receive_brought(item)
	if got_it:
		economy.add_bond(h.species, 2)
	if got_it and not _quiet():
		var t: String = h.tier
		toasts.show_sighting(h.species, t, "A present", "%s %s brought you something" % ["An" if h.species[0] in "aeiou" else "A", Collection.species_name(h.species).to_lower()],
			"The %s is yours. Find it in the Shop." % Wear.item_name(item).to_lower())
	print("BROUGHT ", h.species, " ", h.tier, " ", item)


func _personalise(h) -> void:
	# The species' Speed and Activity, the hour's pace, everyone's Opacity,
	# and the trail.
	var row: Dictionary = settings.species(h.species)
	var k = h.critter
	if not k.has_meta("base_cruise"):
		k.set_meta("base_cruise", k.cruise)
	k.cruise = k.get_meta("base_cruise") * Settings.SPEEDS[int(row.speed)]
	k.cruise *= pace
	k.activity = Settings.ACTIVITY[int(row.activity)]
	h.set_opacity(float(settings.value("critters.opacity")) / 100.0)
	_trail_for(h)


func _trail_for(h) -> void:
	# The species' chosen trail, in its own colours; otherwise, with rarity
	# tiers on, its tier's trail in the tier's colours (v2.0). None with
	# Animation detail set to Simple.
	var style: String = settings.sp(h.species, "trail")
	var palette: Array = Species.row(h.species)["pop"]
	if style == "none" and settings.value("world.rarity") and Trail.TIER_TRAIL.has(h.tier):
		style = Trail.TIER_TRAIL[h.tier]
		palette = Trail.TIER_COLOURS[h.tier]
	if settings.value("system.detail") == "simple":
		style = "none"
	h.set_trail(style, palette)


func _pick_species() -> String:
	# A built species that is switched on, weighted by how often it visits
	# (Settings > Critters), unless one was asked for. "" when none are on.
	if species_fixed:
		return species
	# A treat calls its species next (Shop > Treats).
	while economy != null and not economy.treats.is_empty():
		var called: String = economy.treats.pop_front()
		economy.save()
		if Species.has(called) and settings.sp(called, "enabled"):
			return called
	var pool := []
	var weights := []
	var total := 0.0
	for sp in Species.DATA:
		if Species.row(sp).get("special", false) or not settings.sp(sp, "enabled"):
			continue
		pool.append(sp)
		weights.append(Settings.VISITS[int(settings.sp(sp, "visits"))])
		total += weights[-1]
	if pool.is_empty():
		return ""
	var r := randf() * total
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0:
			return pool[i]
	return pool[-1]


func _on_gone(h) -> void:
	hosts.erase(h)


func _arrive() -> void:
	# A newcomer: a roamer walks in from a side.
	var from_left := randf() < 0.5
	var x := area.position.x - 80.0 if from_left else area.end.x + 80.0
	var h = _spawn("roam", "walk", Vector2(x, randf_range(area.position.y + 260.0, area.end.y)))
	if h == null:
		return
	var k = h.critter
	k.facing = 1 if from_left else -1
	k.want_facing = k.facing
	k.vx = k.facing * k.cruise
	k.entering = true
	k.mode_left = 6.0 + randf() * 4.0


func kittens() -> Array:
	# The critters free to act: not held, thrown or popping.
	var out := []
	for h in hosts:
		if h.state == "live":
			out.append(h.critter)
	return out


# --- Sound --------------------------------------------------------------------

func _load_sound(species: String) -> void:
	var path := "res://sounds/%s.wav" % species
	if FileAccess.file_exists(path):
		sounds[species] = AudioStreamWAV.load_from_file(path)


func play_sound(sound: String, sp := "") -> void:
	# Pops and throws: off with Sound > Pop sounds, or the species' own switch.
	if not settings.value("sound.pops") or (sp != "" and not settings.sp(sp, "sound")):
		return
	_play(sound)


func preview_sound(sp: String) -> void:
	# The play buttons in Settings: always heard, at the set volume.
	_play(Species.row(sp)["sound"])


func _play(sound: String) -> void:
	if sounds.has(sound):
		player.stream = sounds[sound]
		player.volume_db = linear_to_db(maxf(float(settings.value("sound.volume")) / 100.0, 0.0001))
		player.play()


# --- Presence -------------------------------------------------------------------

func _on_went_away() -> void:
	# Settle down over the next few seconds, not all at once. Roamers near a
	# showpiece with room walk over and curl up in it.
	if economy != null:
		economy.went_away()
	queued.clear()
	var sent := {}
	for h in hosts:
		if h.kind != "roam" or h.state != "live":
			continue
		var best = null
		var best_d := INF
		for pid in props:
			var p = props[pid]
			var spot: int = p.free_spot()
			if spot < 0:
				continue
			var d: float = absf(p.spot_feet(spot).x - h.critter.position.x)
			if d < best_d:
				best_d = d
				best = p
		if best != null:
			var spot: int = best.free_spot()
			best.sleepers[spot] = h   # held while it walks over
			h.go_nap_at(best, spot)
			sent[h] = true
	for h in hosts:
		if h.state == "live" and not sent.has(h):
			queued.append([h.critter, randf_range(0.0, 6.0), "sleep"])


func _on_came_back() -> void:
	if economy != null:
		economy.came_back(presence.away_after)
	queued.clear()
	for h in hosts:
		h.cancel_nap()
	for pid in props:
		props[pid].release_all()
	for k in kittens():
		queued.append([k, randf_range(0.3, 2.5), "wake"])
	if tidied:
		# Everyone went home during the break: gather again.
		tidied = false
		for i in mini(int(settings.value("focus.start_with")), _max_out()):
			_arrive()
		next_arrival = focus_s + _gather_every()


func _run_queue(delta: float) -> void:
	for q in queued:
		q[1] -= delta
		if q[1] <= 0.0 and is_instance_valid(q[0]):
			if q[2] == "sleep":
				q[0].go_to_sleep()
			else:
				q[0].wake_up()
	queued = queued.filter(func(q): return q[1] > 0.0 and is_instance_valid(q[0]))


# --- Frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	t += delta

	if demo != "":
		_run_demo(delta)
	else:
		_run_queue(delta)
		economy.tick(delta, not presence.away)
		if fixed_count <= 0 and fixed_perimeter <= 0:
			_arrivals(delta)
		tod_in -= delta
		if tod_in <= 0.0:
			tod_in = 30.0
			_time_of_day()
		if not presence.away and not paused:
			evaluator.tick(delta, kittens(), maxf(presence.sleep_bias(), night_sleep))
		pairs.frequency = evaluator.frequency
		pairs.tick(delta, hosts, Critter.zoom, settings.value("world.pairs") and not presence.away and not paused)
		if native != null:
			if native.poll_hotkey() == 1:
				toggle_pause()
			if native.poll_hotkey_slot(1) == 1:
				spawn_now()
		busy_check -= delta
		if busy_check <= 0.0:
			busy_check = 1.0
			_check_busy()
			if not presence.away and not paused:
				_bond_tick()
		tray_in -= delta
		if tray_in <= 0.0:
			tray_in = TRAY_EVERY
			_update_tray()

	if not paused:
		for h in hosts.duplicate():
			h.release_if_up()
			h.tick(delta)
		_bumps()
		if throw_demo > 0.0 and t > 1.5 and hosts.size() >= 2 and hosts[0].state == "live":
			var a = hosts[0]
			a.foot = a.feet_on_screen()
			a.launch((hosts[1].body_centre() - a.body_centre()).normalized() * throw_demo)
			print("THROWN ", a.state)
			throw_demo = 0.0
	process_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	fps.append(Engine.get_frames_per_second())

	if report_path != "":
		live_timer -= delta
		if live_timer <= 0.0:
			live_timer = 0.5
			_write_live()
	if grab_path != "" and not toast_demo and t >= grab_next and not hosts.is_empty():
		_grab()
	if seconds > 0.0 and t >= seconds:
		_write_report()
		_quit(0)


func _run_demo(delta: float) -> void:
	if hosts.is_empty():
		return
	var k = hosts[0].critter
	match demo:
		"walk", "sit":
			k.mode_left = INF
			return
		"loaf":
			if not k.is_napping():
				k.go_to_sleep()
			return
	if Behaviours.REGISTRY.has(demo) and k.can_do(demo) and k.can_start_behaviour():
		demo_wait -= delta
		if demo_wait <= 0.0:
			demo_wait = 1.2 if Behaviours.REGISTRY[demo]["dur"][1] < 2.0 else 0.6
			k.start_behaviour(demo, evaluator.duration_of(demo))
	if k.mode == "sit":
		k.mode_left = INF   # stay sitting between repeats


func _grab() -> void:
	var img: Image = hosts[0].win.get_texture().get_image()
	if "%d" in grab_path:
		img.save_png(grab_path % grab_count)
		grab_count += 1
		grab_next = t + 1.0 / grab_fps if grab_count < grab_frames else INF
	else:
		img.save_png(grab_path)
		grab_next = INF


# --- Rarity notes ---------------------------------------------------------------

func _quiet() -> bool:
	# No toasts while paused, or while a full-screen app, game or
	# presentation has the screen.
	return paused or (native != null and native.user_busy())


func _announce(sp: String, tier: String, bonus: bool, variant := "") -> void:
	# Records the sighting, then shows a toast if it is rare enough.
	var had_legendary := false
	for key in economy.collection:
		if key.ends_with(":legendary"):
			had_legendary = true
	var first: bool = economy.record_sighting(sp, tier, variant)
	var notes: String = settings.value("world.notes")
	if notes == "off" or Economy.TIERS.find(tier) < Economy.TIERS.find(notes) or _quiet():
		return
	var text := sighting_text(sp, tier, first, bonus, had_legendary,
		economy.collection.get("%s:%s" % [sp, tier], {}).get("count", 1), economy.odds)
	toasts.show_sighting(sp, tier, text[0], text[1], text[2])


static func sighting_text(sp: String, tier: String, first: bool, bonus: bool, had_legendary: bool, count: int, odds := Economy.BASE_ODDS) -> Array:
	# [kicker, title, line] for a sighting toast.
	var name := Collection.species_name(sp)
	var low := name.to_lower()
	var tier_name := tier.capitalize()
	var title := "A Legendary %s" % low if tier == "legendary" else "%s %s has arrived" % ["An" if low[0] in "aeiou" else "A", low]
	var line := ""
	if bonus:
		line = "Your first visitor today. The first is always Rare or better."
	elif tier == "legendary" and not had_legendary:
		line = "Your first Legendary. Take a moment."
	elif first:
		line = "Your first %s %s. Added to your Collection." % [tier_name, low]
	elif tier == "legendary":
		line = "Seen once before." if count == 2 else "Seen %d times before." % (count - 1)
	else:
		line = "Only about 1 in %d critters is %s." % [int(round(1.0 / maxf(odds[tier], 0.00001))), tier_name]
	return [tier_name, title, line]


func _on_rare_hour(on: bool) -> void:
	_update_tray()
	if on and not _quiet():
		toasts.show_rare_hour(economy.rare_hour_ends(), economy.rare_hour_boost)


func _wear_sheet() -> void:
	# --wear-sheet: each item on each critter, grabbed from the game itself.
	fixed_count = 3
	var ids: Array = wear_flag.duplicate() if not wear_flag.is_empty() else Wear.ITEMS.keys()
	wear_flag = []
	var hs := []
	var i := 0
	for sp in Species.DATA.keys():
		var h = _spawn("roam", "sit", area.position + Vector2(300 + i * 520, 600), sp, "common")
		h.critter._go_sit()
		h.critter.mode_left = INF
		h.critter.activity = 0.0
		hs.append(h)
		i += 1
	await get_tree().create_timer(1.0).timeout
	for id in ids:
		for h in hs:
			h.critter.wear([id] if Wear.fits(id, h.species) else [])
		await get_tree().create_timer(0.35).timeout
		for h in hs:
			if Wear.fits(id, h.species):
				h.win.get_texture().get_image().save_png(sheet_dir.path_join("%s-%s.png" % [id, h.species]))
	print("SHEET done ", ids.size())
	_quit(0)


func _stills() -> void:
	# --stills: every built species sitting (front) and walking (side), grabbed
	# from the game itself, for the design boards.
	# Every version folder too (art/<species>/<version>/), named species@version.
	# The specials keep their colours in their own scripts, so they are grabbed
	# as they come.
	var jobs := []
	for sp in Species.DATA.keys():
		jobs.append([sp, ""])
		if Species.row(sp).get("special", false):
			continue
		for d in DirAccess.get_directories_at("res://art/%s" % sp):
			jobs.append([sp, d])
	fixed_count = jobs.size()
	var done := 0
	while done < jobs.size():
		# A batch at a time, so the windows fit along the screen.
		var batch: Array = jobs.slice(done, done + 4)
		var hs := []
		var i := 0
		for j in batch:
			var h = _spawn("roam", "sit", area.position + Vector2(300 + i * 420, 600), j[0], "common", j[1])
			h.critter._go_sit()
			h.critter.mode_left = INF
			h.critter.activity = 0.0
			hs.append([h, j[0] + ("@" + j[1] if j[1] != "" else "")])
			i += 1
		await get_tree().create_timer(1.5).timeout
		for e in hs:
			e[0].win.get_texture().get_image().save_png(stills_dir.path_join("%s-front.png" % e[1]))
		for e in hs:
			e[0].critter._go_walk()
			e[0].critter.mode_left = INF
		await get_tree().create_timer(1.2).timeout
		for e in hs:
			e[0].win.get_texture().get_image().save_png(stills_dir.path_join("%s-side.png" % e[1]))
			e[0].queue_free()
			hosts.erase(e[0])
		await get_tree().process_frame
		done += batch.size()
	print("STILLS done ", jobs.size())
	_quit(0)


func _run_pair_demo() -> void:
	# Two critters of the right species in the middle, the interaction
	# forced every eight seconds.
	fixed_count = 2
	var d: Array = Pairs.PAIRS[pair_demo]
	var sa: String = d[3][0] if not d[3].is_empty() else "kitten"
	var sb: String = d[4][0] if not d[4].is_empty() else "rabbit"
	var c := area.get_center() + Vector2(0, 120)
	var a = _spawn("roam", "sit", c - Vector2(220, 0), sa)
	var b = _spawn("roam", "sit", c + Vector2(120, 0), sb)
	var go := func():
		if is_instance_valid(a) and is_instance_valid(b) and pairs.active.is_empty():
			a.critter.paired = false
			b.critter.paired = false
			pairs.cool.clear()
			pairs._start(pair_demo, a, b, Critter.zoom)
	var timer := Timer.new()
	timer.wait_time = 8.0
	timer.timeout.connect(go)
	add_child(timer)
	timer.start()
	get_tree().create_timer(1.0).timeout.connect(go)


func _run_toast_demo() -> void:
	var steps := [
		func(): toasts.show_sighting("rabbit", "rare", "Rare", "A rabbit has arrived", "Your first Rare rabbit. Added to your Collection."),
		func(): toasts.show_sighting("duckling", "epic", "Epic", "A duckling has arrived", "Only about 1 in 200 critters is Epic."),
		func(): toasts.show_sighting("kitten", "legendary", "Legendary", "A Legendary kitten", "Your first Legendary. Take a moment."),
		func(): toasts.show_rare_hour(economy.rare_hour_ends(), economy.rare_hour_boost),
		func(): toasts.show_note(Icons.berry(40), "A gift", "50 minutes of focus", "30 berries, and a bobble beanie."),
		func(): toasts.show_note(Icons.berry(40), "Welcome back", "The critters found something", "5 berries while you were away."),
		func(): toasts.show_note(Icons.line("star", 40, Color("#D9961A")), "Collection", "Every kitten met", "500 berries, and a gold frame for its card.", "#E3A72F"),
	]
	for i in steps.size():
		get_tree().create_timer(1.0 + i * (3.0 if grab_path == "" else 1.2)).timeout.connect(steps[i])
	if grab_path != "":
		# --grab=PATH with %d: save each toast's window once all are up.
		get_tree().create_timer(6.0).timeout.connect(func():
			for i in toasts.toasts.size():
				toasts.toasts[i].win.get_texture().get_image().save_png(grab_path % i))


func _tour() -> void:
	# --settings-tour: every page, top to bottom, saved for checking by eye.
	await get_tree().create_timer(1.5).timeout
	for n in SettingsWindow.NAV:
		if n[0] == "shop" and shop_try_flag != "" and settings_win != null:
			settings_win.pages.shop_try = shop_try_flag.get_slice(":", 0)
			settings_win.pages.shop_dye = shop_try_flag.get_slice(":", 1) if ":" in shop_try_flag else ""
		open_settings(n[0])
		await get_tree().create_timer(1.2).timeout
		var y := 0
		var i := 0
		while true:
			settings_win._scroll.scroll_vertical = y
			await get_tree().create_timer(0.4).timeout
			var sc: ScrollContainer = settings_win._scroll
			settings_win.get_texture().get_image().save_png(tour_dir.path_join("%s-%d.png" % [n[0], i]))
			var max_y := int(sc.get_v_scroll_bar().max_value - sc.size.y)
			if y >= max_y or i >= 5:
				break
			y = mini(y + 600, max_y)
			i += 1
	print("TOUR done")
	_quit(0)


func open_settings(page := "", sp := "") -> void:
	if settings_win == null:
		settings_win = SettingsWindow.new()
		add_child(settings_win)
	settings_win.open(self, page, sp)


func _set_paused(p: bool) -> void:
	# Paused: the critters hide and no one arrives or leaves. Focus time
	# keeps counting.
	paused = p
	_show_critters()
	_update_tray()


func _show_critters() -> void:
	for h in hosts:
		h.win.visible = not paused and not busy_hidden


func _time_of_day() -> void:
	# World > Day and night pacing (v2.0 time_of_day.py): livelier in the
	# morning, sleepier at night. Only pace changes, never the colours.
	var was := pace
	if settings.value("world.day_night"):
		var st: Array = TimeOfDay.now()
		pace = st[0]
		spawn_rate = st[1]
		night_sleep = st[2]
	else:
		pace = 1.0
		spawn_rate = 1.0
		night_sleep = 0.0
	evaluator.frequency = float(settings.value("world.behaviour_freq")) * pace
	if not is_equal_approx(was, pace):
		for h in hosts:
			if h.state != "popping":
				_personalise(h)


func _check_busy() -> void:
	# Focus > Pause in full-screen apps: hide while a game, film or
	# presentation has the screen.
	var busy: bool = settings.value("focus.pause_fullscreen") and native != null and native.user_busy()
	if busy != busy_hidden:
		busy_hidden = busy
		_show_critters()


# --- Arrivals -------------------------------------------------------------------

func _max_out() -> int:
	return mini(int(settings.value("focus.max_out")), HARD_MAX)


func _gather_every() -> float:
	return gather_flag if gather_flag > 0.0 else float(settings.value("focus.gather_every_min")) * 60.0 / spawn_rate


func _timer_every() -> float:
	return float(settings.value("focus.timer_every_min")) * 60.0 / spawn_rate


func _solo_every() -> float:
	return float(settings.value("focus.solo_every_min")) * 60.0


func _arrivals(delta: float) -> void:
	# Who comes and goes. Gathering counts focus time; the timer counts
	# time whatever you are doing (arrivals while you are away nap at once).
	# Solo walkers come along the edges in either mode. Nobody comes or goes
	# while paused.
	if paused or waiting_welcome:
		return
	var present: bool = not presence.away
	var timer: bool = settings.value("focus.mode") == "timer"
	if present:
		focus_s += delta
	wall_s += delta
	if timer:
		if wall_s >= next_group:
			next_group = wall_s + _timer_every()
			_group()
	elif present and focus_s >= next_arrival:
		next_arrival = focus_s + _gather_every()
		if hosts.size() < _max_out():
			_arrive()
	var solo_clock := wall_s if timer else focus_s
	if settings.value("focus.solo") and (present or timer) and solo_clock >= next_solo:
		next_solo = solo_clock + _solo_every()
		if hosts.size() < (HARD_MAX if timer else _max_out()):
			var h = _spawn("perimeter", "walk")
			if h != null and not present:
				h.critter.go_to_sleep()
	if present:
		for h in hosts:
			if h.state == "live" and not h.leaving:
				h.stay_left -= delta
				if h.stay_left <= 0.0:
					h.leave()
	# Focus > Tidy up after a long break.
	var tidy: float = float(settings.value("focus.tidy_after_min")) * 60.0
	if not present and tidy > 0.0 and not tidied and presence.idle_s >= tidy:
		tidied = true
		for h in hosts:
			if h.state == "live" and not h.leaving:
				h.leave(true)


func _group() -> void:
	# v2.0's timed spawn: a group of one species at random spots.
	var lo := int(settings.value("focus.timer_min"))
	var hi := maxi(lo, int(settings.value("focus.timer_max")))
	var sp := _pick_species()
	if sp == "":
		return
	for i in mini(randi_range(lo, hi), HARD_MAX - hosts.size()):
		var h = _spawn("roam", ["sit", "walk", "walk"].pick_random(), Vector2(-1, -1), sp)
		if h != null and presence.away:
			h.critter.go_to_sleep()


# --- What the tray and Settings ask for -------------------------------------------

func spawn_now() -> void:
	if paused:
		_set_paused(false)
	if hosts.size() < HARD_MAX:
		_arrive()


func toggle_pause() -> void:
	_set_paused(not paused)


func quit_app() -> void:
	_quit(0)


func collection_counts() -> Array:
	var total := 0
	var found := 0
	# The Collection's slots: Common, Rare and Epic of each everyday species,
	# and each colour variant of a Legendary visitor.
	for sp in Species.DATA:
		var keys := []
		if Species.is_special(sp):
			keys = Species.variants(sp).map(func(v): return "%s:legendary:%s" % [sp, v])
		else:
			for i in Economy.TIERS.find(Species.row(sp).get("rarity_max", "epic")) + 1:
				keys.append("%s:%s" % [sp, Economy.TIERS[i]])
		total += keys.size()
		for k in keys:
			if economy.collection.has(k):
				found += 1
	return [found, total]


func status() -> Dictionary:
	# The live numbers the Settings sidebar and Home page show.
	var timer: bool = settings.value("focus.mode") == "timer"
	var mode := "paused" if paused else ("napping" if presence.away else "running")
	var next_text := ""
	var progress := 0.0
	if timer:
		var left := maxf(0.0, next_group - wall_s)
		progress = 1.0 - left / maxf(_timer_every(), 1.0)
		next_text = "Next group in %d min" % ceili(left / 60.0)
	elif hosts.size() >= _max_out():
		progress = 1.0
		next_text = "The desk is full"
	else:
		var left := maxf(0.0, next_arrival - focus_s)
		progress = 1.0 - left / maxf(_gather_every(), 1.0)
		next_text = "Next critter in %d min" % ceili(left / 60.0)
	var desk := []
	var species_out := []
	for h in hosts:
		if h.state in ["live", "held", "sliding", "thrown"]:
			desk.append({"species": h.species, "tier": h.tier, "napping": h.critter.is_napping()})
			species_out.append(h.species)
	var boost: float = economy.rare_hour_boost
	var how: String = {1.5: "half as likely again", 2.0: "twice as likely", 3.0: "three times as likely"}.get(boost, "%.1f times as likely" % boost)
	var now_min: int = economy._local_minute()
	var start: int = economy.rare_hour_start * 60
	return {"mode": mode, "focus_min": economy.session_min, "out": hosts.size(), "max_out": _max_out(),
		"next_text": next_text, "next_progress": clampf(progress, 0.0, 1.0), "luck": economy.luck(),
		"desk": desk, "species_out": species_out,
		"rare_hour": {"enabled": economy.rare_hour_enabled, "on": economy.in_rare_hour(),
			"start": "%02d:00" % economy.rare_hour_start, "end": economy.rare_hour_ends(), "start_h": economy.rare_hour_start,
			"how": how, "starts_in_min": posmod(start - now_min, 1440),
			"ends_in_min": posmod(start + economy.rare_hour_min - now_min, 1440)}}


func is_startup() -> bool:
	return native != null and native.is_launch_at_startup()


func set_startup(on: bool) -> void:
	# The Run entry starts this executable; from the editor's Godot it also
	# needs the project folder.
	if native == null:
		return
	var args := ""
	if not OS.has_feature("template"):
		args = '--path "%s"' % ProjectSettings.globalize_path("res://").trim_suffix("/")
	native.set_launch_at_startup(on, OS.get_executable_path(), args)


func shortcut_state(slot: int) -> int:
	return native.hotkey_state(slot) if native != null else 0


func set_shortcut(slot: int, k: Dictionary) -> void:
	# Registers the new keys; if another app already has them, the old ones
	# come back and Settings says so.
	var key := "system.pause_key" if slot == 0 else "system.spawn_key"
	var old: Dictionary = settings.value(key)
	settings.set_value(key, k)
	if native == null:
		return
	native.set_hotkey(slot, int(k.mods), int(k.vk))
	get_tree().create_timer(0.3).timeout.connect(func():
		if native.hotkey_state(slot) == -1:
			settings.set_value(key, old)
			native.set_hotkey(slot, int(old.mods), int(old.vk))
			if settings_win != null and settings_win.visible:
				settings_win.pages.shortcut_note = "Another app is using those keys, so the old shortcut is kept."
				settings_win.rebuild())


func set_worn(sp: String, items: Array) -> void:
	# Shop > Dress up: everyone of that species out now changes straight away.
	economy.set_worn(sp, items)
	_redress(sp)


func set_dye(sp: String, item: String, dye: String) -> void:
	economy.set_dye(sp, item, dye)
	_redress(sp)


func _redress(sp: String) -> void:
	for h in hosts:
		if h.species == sp and h.state != "popping":
			h.critter.wear(economy.worn.get(sp, []), economy.dyed.get(sp, {}))


func clear_seen_log() -> void:
	economy.clear_seen_log()
	_update_tray()


var _update_seen := ""


func _auto_update_check() -> void:
	# Once a day, quietly: a note only for a newer version not closed before.
	var now := int(Time.get_unix_time_from_system())
	if now - int(settings.value("system.update_checked")) < UPDATE_EVERY:
		return
	settings.set_value("system.update_checked", now)
	_latest_release(func(tag):
		if tag != "" and _newer(tag, VERSION) and tag != settings.value("system.update_dismissed"):
			_update_seen = tag
			if not _quiet():
				toasts.show_update(tag, RELEASES_URL))


func _latest_release(done: Callable) -> void:
	# The newest release's version on GitHub, or "" if it cannot be reached.
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0
	req.request_completed.connect(func(result, code, _headers, body):
		req.queue_free()
		var tag := ""
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var d = JSON.parse_string(body.get_string_from_utf8())
			if typeof(d) == TYPE_DICTIONARY:
				tag = str(d.get("tag_name", "")).trim_prefix("v")
		done.call(tag))
	if req.request(UPDATE_URL, ["User-Agent: CritterOverlay"]) != OK:
		req.queue_free()
		done.call("")


func check_for_updates(done: Callable) -> void:
	# System > Updates > Check now: the newest release on GitHub.
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0
	req.request_completed.connect(func(result, code, _headers, body):
		req.queue_free()
		var stamp := "Checked today at %s." % Time.get_time_string_from_system().substr(0, 5)
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			done.call("Could not reach GitHub. Try again later.")
			return
		var d = JSON.parse_string(body.get_string_from_utf8())
		var tag: String = str(d.get("tag_name", "")).trim_prefix("v") if typeof(d) == TYPE_DICTIONARY else ""
		if tag != "" and _newer(tag, VERSION):
			done.call("Version %s is out. Press What is new to get it. %s" % [tag, stamp])
		else:
			done.call("You are up to date. " + stamp))
	if req.request(UPDATE_URL, ["User-Agent: CritterOverlay"]) != OK:
		req.queue_free()
		done.call("Could not reach GitHub. Try again later.")


static func _newer(a: String, b: String) -> bool:
	var x := a.split(".")
	var y := b.split(".")
	for i in 3:
		var p := int(x[i]) if i < x.size() else 0
		var q := int(y[i]) if i < y.size() else 0
		if p != q:
			return p > q
	return false


# --- Applying settings ------------------------------------------------------------

func _apply_all() -> void:
	_on_setting("")


func _on_setting(key: String) -> void:
	# Called for every change. "" means everything (start-up and reset).
	var all := key == ""
	var under := func(prefix: String) -> bool: return all or key == prefix or key.begins_with(prefix + ".") or prefix.begins_with(key + ".")
	if under.call("system.theme"):
		var was: String = Palette.theme
		Palette.theme = settings.value("system.theme")
		if was != Palette.theme and settings_win != null and settings_win.visible:
			settings_win.rebuild()
	if under.call("system.detail"):
		Aura.simple = settings.value("system.detail") == "simple"
	if under.call("system.seen_log"):
		economy.seen_log_enabled = settings.value("system.seen_log")
	if under.call("world"):
		_time_of_day()
		economy.odds = settings.odds()
		economy.first_bonus_enabled = settings.value("world.first_bonus")
		economy.rare_hour_enabled = settings.value("world.rare_hour")
		economy.rare_hour_start = int(settings.value("world.rare_hour_start"))
		economy.rare_hour_min = int(settings.value("world.rare_hour_min"))
		economy.rare_hour_boost = float(settings.value("world.rare_hour_boost"))
		if key == "world.rarity" and not settings.value("world.rarity"):
			for h in hosts:
				h.tier = "common"
	if under.call("focus"):
		economy.luck_enabled = settings.value("focus.luck")
		presence.away_after = away_flag if away_flag > 0.0 else float(settings.value("focus.nap_after_min")) * 60.0
		if key == "focus.gather_every_min":
			next_arrival = minf(next_arrival, focus_s + _gather_every())
		if key == "focus.timer_every_min" or key == "focus.mode":
			next_group = minf(next_group, wall_s + _timer_every()) if key != "focus.mode" else wall_s + _timer_every()
		if key == "focus.solo_every_min":
			next_solo = minf(next_solo, (wall_s if settings.value("focus.mode") == "timer" else focus_s) + _solo_every())
		if key == "focus.pause_fullscreen":
			_check_busy()
	if under.call("critters.size") and not zoom_flag:
		var z: float = settings.zoom()
		if not is_equal_approx(z, Critter.zoom):
			Critter.zoom = z
			if not all:
				_redraw_all()
	if under.call("critters.opacity") or under.call("species") or key == "world.rarity" or under.call("system.detail"):
		for h in hosts:
			if h.state != "popping":
				_personalise(h)
	_update_tray()


func _redraw_all() -> void:
	# A new size: every critter is drawn again at the new size, where it
	# stood, keeping its species, tier and how long it has left.
	for h in hosts.duplicate():
		if h.state != "live":
			continue
		var feet: Vector2 = h.feet_on_screen()
		var n = _spawn(h.kind, "walk" if h.critter.mode == "walk" else "sit", feet, h.species, h.tier)
		if n != null:
			n.stay_left = h.stay_left
			if h.critter.is_napping():
				n.critter.go_to_sleep()
		hosts.erase(h)
		h.queue_free()
	_show_critters()


func _update_tray() -> void:
	if tray == null or economy == null:
		return
	var mode := "paused" if paused else ("napping" if presence.away else "running")
	var gift_min := -1.0
	if economy.next_gift < Economy.GIFTS.size():
		gift_min = maxf(0.0, Economy.GIFTS[economy.next_gift][0] - economy.session_min)
	var counts := collection_counts()
	tray.update({"mode": mode, "out": hosts.size(), "focus_min": economy.session_min,
		"rare_hour_until": economy.rare_hour_ends() if economy.in_rare_hour() else "",
		"gift_min": gift_min, "gift_progress": economy.gift_progress(),
		"away_min": presence.idle_s / 60.0, "found": counts[0],
		"found_total": counts[1], "berries": economy.berries})


func note_pop() -> void:
	pops += 1


const BUMP_BOUNCE := 0.9      # pool balls: a little speed lost in each knock


func _bumps() -> void:
	# A critter on the move knocks into others like pool balls: equal
	# weights, so they trade the push along the line between them, and a
	# standing one is sent sliding too.
	var movers := hosts.filter(func(h): return h.state in ["sliding", "thrown"] and h.can_bump())
	if movers.is_empty():
		return
	for a in movers:
		for b in hosts:
			if b == a or not b.can_bump():
				continue
			var d: Vector2 = b.body_centre() - a.body_centre()
			var reach: float = (a.BODY_R * a.zoom + b.BODY_R * b.zoom)
			var dist := d.length()
			if dist >= reach or dist < 0.5:
				continue
			var n := d / dist
			var vb: Vector2 = b.throw_v if b.state in ["sliding", "thrown"] else Vector2.ZERO
			var closing: float = (a.throw_v - vb).dot(n)
			if closing <= 0.0:
				continue
			var push: float = closing * (1.0 + BUMP_BOUNCE) * 0.5
			# Apart, so they do not catch again next frame.
			var gap := (reach - dist) * 0.5
			a.foot -= n * gap
			a.throw_v -= n * push
			if b.state == "live":
				b.knock(vb + n * push)
				b.foot += n * gap
			else:
				b.foot += n * gap
				b.throw_v = vb + n * push
			a.restate()
			b.restate()
			print("BUMP ", a.species, " ", b.species)
			if push > 120.0:
				play_sound(Species.row(b.species)["sound"], b.species)


func note_throw() -> void:
	throws += 1


func _quit(code: int) -> void:
	# Intel's OpenGL driver (igxelpicd64.dll) crashes with 0xC0000005 while
	# Godot tears down the GL context, after window regions have changed:
	# about one exit in three. Nothing is left to do by then, so stop the
	# poller, then end the process without the teardown. Anything that must be
	# saved is saved before this.
	if economy != null and is_instance_valid(economy):
		economy.save()
	if presence != null and is_instance_valid(presence):
		presence.stop()
	if OS.get_name() == "Windows":
		OS.kill(OS.get_process_id())
	get_tree().quit(code)


# --- Reporting ------------------------------------------------------------------

func _stats(xs: Array) -> Dictionary:
	var s := xs.duplicate()
	s.sort()
	if s.is_empty():
		return {}
	return {"median": snappedf(s[s.size() / 2], 0.01), "p95": snappedf(s[int(s.size() * 0.95)], 0.01), "n": s.size()}


func _write_live() -> void:
	# Streamed on stdout rather than written to a file, so a watcher sees it
	# while the run is going.
	var pts := []
	var states := []
	for h in hosts:
		var f: Vector2 = h.feet_on_screen()
		pts.append([snappedf(f.x, 0.1), snappedf(f.y, 0.1)])
		var k = h.critter
		states.append("%s:%s" % [h.kind, h.state if h.state != "live" else (k.act if k.act != "" else k.mode)])
	print("LIVE ", JSON.stringify({"t": snappedf(t, 0.01), "feet": pts, "states": states, "idle": presence.idle_s,
		"away": presence.away, "source": presence.source}))


func _write_report() -> void:
	if report_path == "":
		return
	var r := {
		"godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_video_adapter_name(),
		"screen": [screen_rect.size.x, screen_rect.size.y],
		"area": [area.position.x, area.position.y, area.size.x, area.size.y],
		"species": species,
		"critters": hosts.size(),
		"seconds": t,
		"fps": _stats(fps.slice(int(fps.size() * 0.2))),   # skip the warm-up
		"frame_ms": _stats(process_ms),
		"pops": pops,
		"berries": economy.berries if economy != null else 0,
		"collection": economy.collection.size() if economy != null else 0,
		"luck": snappedf(economy.luck(), 0.01) if economy != null else 1.0,
		"throws": throws,
		"presence_source": presence.source,
		"injected_events": native.injected_events() if native != null else -1,
		"zoom": Critter.zoom,
		"species_out": hosts.map(func(h): return h.species),
		"tiers": hosts.map(func(h): return h.tier),
		"opacity": hosts.map(func(h): return snappedf(h.spin.modulate.a, 0.01)),
		"window_px": hosts.map(func(h): return h.size),
		"cruise": hosts.map(func(h): return snappedf(h.critter.cruise, 0.1)),
	}
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
	f.close()
