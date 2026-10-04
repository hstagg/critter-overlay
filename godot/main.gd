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
##   --selftest         check the click-through polygon and quit

const Kitten := preload("res://critters/kitten.gd")
const Behaviours := preload("res://behaviours.gd")
const Presence := preload("res://presence.gd")

const START_KITTENS := 2
const MAX_KITTENS := 8
const STRIP_H := 260           # window height in px: a kitten (~95) plus hops and pounces

var floor_y := 0.0
var left_x := 0.0
var right_x := 0.0
var t := 0.0

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
		DisplayServer.window_set_mouse_passthrough(passthrough_polygon(_hit_rects()))
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
		get_tree().quit()


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

func _hit_rects() -> Array:
	var rects := []
	for k in kittens:
		rects.append(k.hit_rect())
	return rects


static func _shape(r: Rect2) -> PackedVector2Array:
	# A hit box with its top corners cut, roughly the kitten's outline.
	return PackedVector2Array([
		r.position + Vector2(12, 0), Vector2(r.end.x - 12, r.position.y),
		Vector2(r.end.x, r.position.y + 24), r.end,
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, 24),
	])


static func passthrough_polygon(rects: Array) -> PackedVector2Array:
	# Windows fills the passthrough polygon even-odd, so two kittens whose
	# boxes overlap would cancel each other out where they meet. Merge
	# overlapping shapes first, then join the separate outlines into one
	# polygon with zero-width bridges back to a common start.
	var shapes := []
	for r in rects:
		var merged := _shape(r)
		var rest := []
		for s in shapes:
			if Geometry2D.intersect_polygons(merged, s).is_empty():
				rest.append(s)
				continue
			merged = _largest(Geometry2D.merge_polygons(merged, s))
		rest.append(merged)
		shapes = rest

	var poly := PackedVector2Array()
	var starts := []
	for s in shapes:
		poly.append_array(s)
		poly.append(s[0])
		starts.append(s[0])
	starts.reverse()
	for p in starts:
		poly.append(p)
	return poly


static func _largest(polys: Array) -> PackedVector2Array:
	# merge_polygons returns the outline plus any holes; keep the outline.
	var best := PackedVector2Array()
	var best_area := -1.0
	for p in polys:
		var a := absf(_area(p))
		if a > best_area:
			best_area = a
			best = p
	return best


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var j := (i + 1) % p.size()
		a += p[i].x * p[j].y - p[j].x * p[i].y
	return a * 0.5


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
	# Overlapping boxes (a pair, and a chain of three) plus one apart: every
	# point inside any box must be inside the polygon, and no point outside.
	var rects := [
		Rect2(100, 100, 70, 80), Rect2(140, 110, 70, 80),
		Rect2(300, 100, 70, 80), Rect2(340, 100, 70, 80), Rect2(380, 104, 70, 80),
		Rect2(600, 100, 70, 80),
	]
	var poly := passthrough_polygon(rects)
	var fails := 0
	var checks := 0
	for x in range(80, 700, 3):
		for y in range(90, 200, 3):
			var pt := Vector2(x + 0.5, y + 0.5)
			var want := false
			var near_edge := false
			for r in rects:
				if Geometry2D.is_point_in_polygon(pt, _shape(r)):
					want = true
				if r.grow(2.0).has_point(pt) and not r.grow(-2.0).has_point(pt):
					near_edge = true
			if near_edge:
				continue
			checks += 1
			if inside_even_odd(poly, pt) != want:
				fails += 1
	print("SELFTEST passthrough: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	get_tree().quit(0 if fails == 0 else 1)


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
