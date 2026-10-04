extends Node2D
## Critter Overlay v3: kittens on a transparent, click-through, always-on-top
## window along the bottom of the screen.
##
## This file owns the window, the kittens' arrival, the behaviour evaluator,
## the presence layer and the click-through area. Each kitten's rig, movement
## and behaviours live in critters/kitten.gd.
##
## The focus layer: two kittens to start; while you keep working another
## wanders in every few minutes, up to a cap. Step away and they settle into
## loaves and doze; come back and they wake, most with a stretch.
##
## Flags (after `--`):
##   --seconds=N        quit after N seconds; with --report=PATH write timings
##   --report=PATH      timings as JSON; live positions stream on stdout
##   --kittens=N        a fixed number of kittens (no gathering)
##   --demo=NAME        one kitten in the middle doing NAME on a loop: any
##                      behaviour, or walk, sit, loaf
##   --gather-every=S   seconds of focus per new kitten (default 300)
##   --away-after=S     seconds idle before they nap (default 180)
##   --idle-sim=P,A     fake presence: P seconds present, A away, repeating
##   --grab=PATH        save a frame after two seconds; a PATH with %d saves a
##                      burst of frames instead (--grab-start, --grab-frames,
##                      --grab-fps)
##   --zoom=Z           draw the kittens Z times larger (for demo captures)
##   --no-passthrough   leave the whole window clickable
##   --fake-pointer     sweep a pretend pointer along the strip, so the
##                      click-through hole moves every frame (exit-crash test)
##   --selftest         check the click-through polygon and quit

const Kitten := preload("res://critters/kitten.gd")
const Behaviours := preload("res://behaviours.gd")
const Presence := preload("res://presence.gd")

const START_KITTENS := 2
const MAX_KITTENS := 8
const HOLE_FROM := Vector2(-4, -4)   # the click-through hole about the pointer's tip,
const HOLE_TO := Vector2(12, 14)      # mostly under the arrow so its edges stay hidden
const STRIP_H := 260           # window height in px: a kitten (~95) plus hops and pounces

var floor_y := 0.0
var left_x := 0.0
var right_x := 0.0
var t := 0.0
var fake_pointer := false
var _hole := Rect2(-1, -1, 0, 0)
var _region_size := Vector2.ZERO

var kittens := []
var evaluator := Behaviours.new()
var presence: Node
var gather_every := 300.0
var focus_s := 0.0
var fixed_count := -1
var demo := ""
var demo_wait := 0.5
var queued := []             # [kitten, seconds left, "sleep" | "wake"]

var seconds := 0.0
var report_path := ""
var process_ms := []
var passthrough_ms := []
var fps := []
var clicks := 0
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
		elif arg.begins_with("--kittens="):
			fixed_count = int(v)
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
			Kitten.zoom = float(v)
		elif arg == "--no-passthrough":
			no_passthrough = true
		elif arg == "--fake-pointer":
			fake_pointer = true
		elif arg == "--selftest":
			selftest = true

	# Godot numbers the whole desktop from the top-left of all screens, so with
	# more than one monitor the primary does not start at (0, 0). Place the
	# window on the primary screen and lay out in window-local coordinates.
	var scr := DisplayServer.get_primary_screen()
	var origin := DisplayServer.screen_get_position(scr)
	var screen := DisplayServer.screen_get_size(scr)
	var usable := DisplayServer.screen_get_usable_rect(scr)
	var win := get_window()
	# A strip along the bottom of the usable area, not the whole screen. A
	# borderless window covering (or one pixel short of) the monitor gets
	# promoted to fullscreen flip by the compositor, which drops the alpha
	# channel and turns the whole screen black until another window takes
	# focus. The kittens only live along the floor, so they need no more.
	var strip_h := mini(int(STRIP_H * Kitten.zoom), usable.size.y)
	win.position = Vector2i(origin.x, usable.end.y - strip_h)
	win.size = Vector2i(screen.x, strip_h)
	floor_y = strip_h - 2
	left_x = usable.position.x - origin.x + 50
	right_x = usable.end.x - origin.x - 50

	Kitten.load_textures()
	randomize()

	if selftest:
		presence.free()
		set_process(false)   # _process reads presence, which is gone
		_selftest()
		return

	add_child(presence)
	presence.went_away.connect(_on_went_away)
	presence.came_back.connect(_on_came_back)

	if demo != "":
		var k = _spawn((left_x + right_x) * 0.5, -1, "walk" if demo == "walk" else "sit")
		k.mode_left = INF
	else:
		presence.start()
		var n := fixed_count if fixed_count > 0 else START_KITTENS
		for i in n:
			_spawn(randf_range(left_x, right_x), [-1, 1].pick_random(), ["sit", "walk", "walk", "loaf"].pick_random())


func _spawn(x: float, face: int, start_mode: String):
	var k = Kitten.new()
	add_child(k)
	k.setup(self, x, face, start_mode)
	kittens.append(k)
	return k


func _arrive() -> void:
	# A new kitten wanders in from whichever edge is further from the others.
	var mean := 0.0
	for k in kittens:
		mean += k.position.x
	mean /= maxf(1.0, kittens.size())
	var from_left := mean > (left_x + right_x) * 0.5
	var x := left_x - 110.0 if from_left else right_x + 110.0
	var k = _spawn(x, 1 if from_left else -1, "walk")
	k.entering = true
	k.want_facing = k.facing
	k.mode_left = 6.0 + randf() * 4.0


func mouse_local() -> Vector2:
	return Vector2(DisplayServer.mouse_get_position() - get_window().position)


# --- Presence ---------------------------------------------------------------

func _on_went_away() -> void:
	# Settle down over the next few seconds, not all at once.
	queued.clear()
	for k in kittens:
		queued.append([k, randf_range(0.0, 6.0), "sleep"])


func _on_came_back() -> void:
	queued.clear()
	for k in kittens:
		queued.append([k, randf_range(0.3, 2.5), "wake"])


func _run_queue(delta: float) -> void:
	for q in queued:
		q[1] -= delta
		if q[1] <= 0.0:
			if q[2] == "sleep":
				q[0].go_to_sleep()
			else:
				q[0].wake_up()
	queued = queued.filter(func(q): return q[1] > 0.0)


# --- Frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	t += delta

	if demo != "":
		_run_demo(delta)
	else:
		_run_queue(delta)
		if not presence.away:
			evaluator.tick(delta, kittens, presence.sleep_bias())
			if fixed_count <= 0:
				focus_s += delta
				var want := mini(MAX_KITTENS, START_KITTENS + int(focus_s / gather_every))
				if kittens.size() < want:
					_arrive()

	for k in kittens:
		k.tick(delta)
	process_ms.append((Time.get_ticks_usec() - t0) / 1000.0)

	var t1 := Time.get_ticks_usec()
	if not no_passthrough:
		_update_passthrough()
	passthrough_ms.append((Time.get_ticks_usec() - t1) / 1000.0)
	fps.append(Engine.get_frames_per_second())

	if report_path != "":
		live_timer -= delta
		if live_timer <= 0.0:
			live_timer = 0.5
			_write_live()
	if grab_path != "" and t >= grab_next:
		_grab()
	if seconds > 0.0 and t >= seconds:
		_write_report()
		_quit(0)


func _run_demo(delta: float) -> void:
	var k = kittens[0]
	match demo:
		"walk", "sit":
			k.mode_left = INF
			return
		"loaf":
			if not k.is_napping():
				k.go_to_sleep()
			return
	if Behaviours.REGISTRY.has(demo) and k.can_start_behaviour():
		demo_wait -= delta
		if demo_wait <= 0.0:
			demo_wait = 1.2
			k.start_behaviour(demo, evaluator.duration_of(demo))
	if k.mode == "sit":
		k.mode_left = INF   # stay sitting between repeats


func _grab() -> void:
	var img := get_viewport().get_texture().get_image()
	if "%d" in grab_path:
		img.save_png(grab_path % grab_count)
		grab_count += 1
		grab_next = t + 1.0 / grab_fps if grab_count < grab_frames else INF
	else:
		img.save_png(grab_path)
		grab_next = INF


# --- Click-through -------------------------------------------------------------
#
# On Windows the passthrough polygon is a window region: clicks outside it
# reach the window below, and nothing outside it is drawn. Every change to the
# region makes the compositor redraw the window, and for a frame the newly
# covered area shows as an edge or a box. So the region is not shaped to the
# kittens. It is the whole strip, with a small hole under the mouse pointer
# when the pointer is in the strip but not on a kitten. Clicks through the hole
# land on whatever is below; the only part that changes from frame to frame is
# the hole, which the pointer covers, and nothing changes at all while the
# pointer is elsewhere.

func _update_passthrough() -> void:
	var size := Vector2(get_window().size)
	var m := Vector2(fmod(t * 400.0, size.x), size.y * 0.6) if fake_pointer else mouse_local()
	var hole := Rect2()
	if Rect2(Vector2.ZERO, size).has_point(m) and not _over_kitten(m):
		hole = Rect2(m + HOLE_FROM, HOLE_TO - HOLE_FROM)
		for k in kittens:
			if hole.intersects(k.region_rect()):
				hole = Rect2(m - Vector2(1, 1), Vector2(3, 3))   # don't clip a kitten
				break
		hole = hole.intersection(Rect2(Vector2.ZERO, size))
	if hole == _hole and size == _region_size:
		return
	_hole = hole
	_region_size = size
	DisplayServer.window_set_mouse_passthrough(region_polygon(size, hole))


func _over_kitten(m: Vector2) -> bool:
	for k in kittens:
		if k.hit_rect().grow(4.0).has_point(m):
			return true
	return false


static func region_polygon(size: Vector2, hole: Rect2) -> PackedVector2Array:
	# The strip's outline, then a zero-width bridge to the hole and round it.
	# Windows fills the region even-odd, so the hole, inside both, is left out.
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), Vector2.ZERO])
	if hole.has_area():
		poly.append_array([hole.position, Vector2(hole.end.x, hole.position.y), hole.end,
			Vector2(hole.position.x, hole.end.y), hole.position, Vector2.ZERO])
	return poly


static func inside_even_odd(poly: PackedVector2Array, pt: Vector2) -> bool:
	# The fill rule Windows applies to the passthrough region.
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var a := poly[i]
		var b := poly[j]
		if (a.y > pt.y) != (b.y > pt.y) and pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


func _selftest() -> void:
	# Holes in the middle and against each edge, and no hole: every point in
	# the strip outside the hole must be in the region, and none inside it.
	var size := Vector2(1920, 260)
	var holes := [Rect2(), Rect2(500, 100, 16, 18), Rect2(0, 0, 12, 14), Rect2(1908, 246, 12, 14), Rect2(900, 0, 3, 3)]
	var fails := 0
	var checks := 0
	for hole in holes:
		var poly := region_polygon(size, hole)
		for x in range(0, 1920, 7):
			for y in range(0, 260, 3):
				var pt := Vector2(x + 0.5, y + 0.5)
				checks += 1
				if inside_even_odd(poly, pt) == hole.has_point(pt):
					fails += 1
		for x in range(int(hole.position.x), int(hole.end.x)):
			for y in range(int(hole.position.y), int(hole.end.y)):
				checks += 1
				if inside_even_odd(poly, Vector2(x + 0.5, y + 0.5)):
					fails += 1
	print("SELFTEST passthrough: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	get_tree().quit(0 if fails == 0 else 1)


func _quit(code: int) -> void:
	# Intel's OpenGL driver (igxelpicd64.dll) crashes with 0xC0000005 while
	# Godot tears down the GL context, after the window region has changed:
	# about one exit in three, more with the pointer moving. Nothing is left to
	# do by then, so stop the poller, then end the process without the
	# teardown. Anything that must be saved is saved before this.
	if presence != null and is_instance_valid(presence):
		presence.stop()
	if OS.get_name() == "Windows" and not no_passthrough:
		OS.kill(OS.get_process_id())
	get_tree().quit(code)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for k in kittens:
			if k.hit_rect().has_point(event.position):
				clicks += 1
				k.poke()
				print("click on kitten at ", k.position)
				break


# --- Reporting -----------------------------------------------------------------

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
	for k in kittens:
		pts.append([k.position.x, k.position.y])
		states.append(k.act if k.act != "" else k.mode)
	print("LIVE ", JSON.stringify({"t": t, "feet": pts, "states": states, "idle": presence.idle_s,
		"away": presence.away, "source": presence.source, "pid": OS.get_process_id()}))


func _write_report() -> void:
	if report_path == "":
		return
	var trimmed := fps.slice(int(fps.size() * 0.2))   # skip the warm-up
	var r := {
		"godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_video_adapter_name(),
		"screen": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"kittens": kittens.size(),
		"seconds": t,
		"fps": _stats(trimmed),
		"animate_ms": _stats(process_ms),
		"passthrough_ms": _stats(passthrough_ms),
		"clicks_seen": clicks,
		"presence_source": presence.source,
		"transparent_bg": get_viewport().transparent_bg,
	}
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
	f.close()
