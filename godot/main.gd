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
##   --selftest         check the click-through polygon and quit

const Critter := preload("res://critters/critter.gd")
const Species := preload("res://species.gd")
const Behaviours := preload("res://behaviours.gd")
const Presence := preload("res://presence.gd")
const Host := preload("res://host.gd")
const Region := preload("res://region.gd")
const Economy := preload("res://economy.gd")
const Tray := preload("res://gui/tray.gd")

const START_KITTENS := 2
const MAX_KITTENS := 8
const PERIMETER_SHARE := 0.3   # of arrivals, how many walk the edges
const STAY_MIN := 30.0 * 60.0   # a visit lasts 30 to 50 minutes of focus
const STAY_MAX := 50.0 * 60.0
const TRAY_EVERY := 0.5
const MOD_CTRL_SHIFT := 0x0002 | 0x0004   # Win32 MOD_CONTROL | MOD_SHIFT
const VK_P := 0x50

var area := Rect2()            # where critters live: the primary screen less the taskbar
var screen_rect := Rect2i()
var vsync_taken := false       # host.gd: only the first window waits for vsync
var t := 0.0

var hosts := []
var evaluator := Behaviours.new()
var presence: Node
var gather_every := 720.0     # a new visitor every 12 minutes of focus
var focus_s := 0.0
var next_arrival := 0.0
var fixed_count := -1
var fixed_perimeter := 0
var species := Species.DEFAULT
var species_fixed := false
var economy: Node
var tray: Node
var paused := false
var stay_scale := 1.0           # --stay: shorter visits for testing
var save_path := ""
var tray_in := 0.0
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
			gather_every = float(v)
		elif arg.begins_with("--away-after="):
			presence.away_after = float(v)
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
		elif arg == "--no-passthrough":
			no_passthrough = true
		elif arg.begins_with("--stay="):
			stay_scale = float(v) / STAY_MAX
		elif arg.begins_with("--save="):
			save_path = v
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
		native.start(MOD_CTRL_SHIFT, VK_P)
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
	add_child(economy)
	economy.load_save()
	economy.sighting.connect(func(sp, tier, first): print("SIGHTING ", sp, " ", tier, " first" if first else ""))
	economy.gift_opened.connect(func(i, b, item): print("GIFT ", i, " +", b, " ", item))
	economy.welcome_back.connect(func(b): print("WELCOME BACK +", b))

	tray = Tray.new()
	add_child(tray)
	tray.spawn_pressed.connect(func():
		if paused:
			_set_paused(false)
		if hosts.size() < MAX_KITTENS:
			_arrive())
	tray.pause_pressed.connect(func(): _set_paused(not paused))
	tray.collection_pressed.connect(func(): print("TRAY collection (not built yet)"))
	tray.settings_pressed.connect(func(): print("TRAY settings (not built yet)"))
	tray.quit_pressed.connect(func(): _quit(0))

	add_child(presence)
	presence.went_away.connect(_on_went_away)
	presence.came_back.connect(_on_came_back)

	if demo != "":
		var h = _spawn("roam", "walk" if demo == "walk" else "sit", area.get_center() + Vector2(0, 40))
		h.critter.mode_left = INF
		return
	presence.start()
	if fixed_count > 0 or fixed_perimeter > 0:
		for i in maxi(fixed_count, 0):
			_spawn("roam", ["sit", "walk", "walk", "loaf"].pick_random())
		for i in fixed_perimeter:
			_spawn("perimeter", "walk")
		return
	for i in START_KITTENS:
		_spawn("roam", ["sit", "walk", "walk", "loaf"].pick_random())
	next_arrival = gather_every


func _spawn(kind: String, start_mode: String, at := Vector2(-1, -1)):
	var sp := _pick_species()
	var h = Host.new()
	add_child(h)
	h.setup(self, sp, Critter.zoom, kind, start_mode, at)
	h.gone.connect(_on_gone)
	hosts.append(h)
	# Every visitor rolls its rarity, with the session's luck, and goes in
	# the Collection. A visit lasts a while, then it leaves.
	if economy != null and demo == "":
		h.tier = economy.roll_tier(Species.row(sp).get("rarity_max", "legendary"))
		economy.record_sighting(sp, h.tier)
		if fixed_count <= 0 and fixed_perimeter <= 0:
			h.stay_left = randf_range(STAY_MIN, STAY_MAX) * stay_scale
	return h


func _pick_species() -> String:
	# Any built species that is not a special visitor, unless one was asked
	# for. Per-species weights come with the settings.
	if species_fixed:
		return species
	var pool := []
	for sp in Species.DATA:
		if not Species.row(sp).get("special", false):
			pool.append(sp)
	return pool.pick_random() if not pool.is_empty() else species


func _on_gone(h) -> void:
	hosts.erase(h)


func _arrive() -> void:
	# A newcomer: a roamer walks in from a side, an edge-walker appears on
	# the bottom edge and sets off round the screen.
	if randf() < PERIMETER_SHARE:
		_spawn("perimeter", "walk")
		return
	var from_left := randf() < 0.5
	var x := area.position.x - 80.0 if from_left else area.end.x + 80.0
	var h = _spawn("roam", "walk", Vector2(x, randf_range(area.position.y + 260.0, area.end.y)))
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


func play_sound(species: String) -> void:
	if sounds.has(species):
		player.stream = sounds[species]
		player.play()


# --- Presence -------------------------------------------------------------------

func _on_went_away() -> void:
	# Settle down over the next few seconds, not all at once.
	if economy != null:
		economy.went_away()
	queued.clear()
	for k in kittens():
		queued.append([k, randf_range(0.0, 6.0), "sleep"])


func _on_came_back() -> void:
	if economy != null:
		economy.came_back(presence.away_after)
	queued.clear()
	for k in kittens():
		queued.append([k, randf_range(0.3, 2.5), "wake"])


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
		if not presence.away and not paused:
			evaluator.tick(delta, kittens(), presence.sleep_bias())
			if fixed_count <= 0 and fixed_perimeter <= 0:
				focus_s += delta
				if focus_s >= next_arrival and hosts.size() < MAX_KITTENS:
					_arrive()
					next_arrival = focus_s + gather_every
				for h in hosts:
					if h.state == "live" and not h.leaving:
						h.stay_left -= delta
						if h.stay_left <= 0.0:
							h.leave()
		if native != null and native.poll_hotkey() == 1:
			_set_paused(not paused)
		tray_in -= delta
		if tray_in <= 0.0:
			tray_in = TRAY_EVERY
			_update_tray()

	if not paused:
		for h in hosts.duplicate():
			h.release_if_up()
			h.tick(delta)
	process_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	fps.append(Engine.get_frames_per_second())

	if report_path != "":
		live_timer -= delta
		if live_timer <= 0.0:
			live_timer = 0.5
			_write_live()
	if grab_path != "" and t >= grab_next and not hosts.is_empty():
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
			demo_wait = 1.2
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


func _set_paused(p: bool) -> void:
	# Paused: the critters hide and no one arrives or leaves. Focus time
	# keeps counting.
	paused = p
	for h in hosts:
		h.win.visible = not p
	_update_tray()


func _update_tray() -> void:
	if tray == null or economy == null:
		return
	var mode := "paused" if paused else ("napping" if presence.away else "running")
	var gift_min := -1.0
	if economy.next_gift < Economy.GIFTS.size():
		gift_min = maxf(0.0, Economy.GIFTS[economy.next_gift][0] - economy.session_min)
	var total := 0
	for sp in Species.DATA:
		total += Economy.TIERS.find(Species.row(sp).get("rarity_max", "legendary")) + 1
	tray.update({"mode": mode, "out": hosts.size(), "focus_min": economy.session_min,
		"gift_min": gift_min, "gift_progress": economy.gift_progress(),
		"away_min": presence.idle_s / 60.0, "found": economy.collection.size(),
		"found_total": total, "berries": economy.berries})


func note_pop() -> void:
	pops += 1


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
	}
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
	f.close()
