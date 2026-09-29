extends Node2D
## Critter Overlay v3 engine spike: rigged kittens on a transparent,
## click-through, always-on-top window.
##
## Each kitten is built from the eight SVG parts in art/kitten/, rasterised at
## runtime, and animated by rotating and scaling pivots in code (breathing,
## head bob, tail sway, blink, ear twitch, a hopping walk).
##
## Unattended run: `godot --path godot -- --seconds=20 --report=PATH`
## quits after N seconds and writes timings to PATH, plus live critter
## positions to PATH.live.json every half second for an external hit test.

const PART_SCALE := 0.75       # SVG units -> texture pixels
const CRITTER_SCALE := 0.45    # node scale: a kitten is about 95 px tall
const N_KITTENS := 12

# Pivot points in SVG units (the canvas marks the same points).
const PIVOTS := {
	"tail": Vector2(200, 226),
	"body": Vector2(150, 262),
	"feet": Vector2(150, 262),
	"paws": Vector2(150, 262),
	"ear-l": Vector2(100, 76),
	"ear-r": Vector2(200, 76),
	"head": Vector2(150, 190),
	"eyes": Vector2(150, 124),
}

# Hit shape around a kitten, relative to its feet, in screen pixels.
const HIT_SHAPE := [
	Vector2(-30, -84), Vector2(30, -84), Vector2(40, -60),
	Vector2(40, 4), Vector2(-40, 4), Vector2(-40, -60),
]

var textures := {}
var kittens := []
var floor_y := 0.0
var left_x := 0.0
var right_x := 0.0
var t := 0.0

var seconds := 0.0
var report_path := ""
var process_ms := []
var passthrough_ms := []
var fps := []
var clicks := 0
var live_timer := 0.0
var no_passthrough := false
var grab_path := ""
var grabbed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--grab="):
			grab_path = arg.get_slice("=", 1)
		elif arg == "--no-passthrough":
			no_passthrough = true
		elif arg.begins_with("--report="):
			report_path = arg.get_slice("=", 1)

	# Godot numbers the whole desktop from the top-left of all screens, so with
	# more than one monitor the primary does not start at (0, 0). Place the
	# window on the primary screen and lay out in window-local coordinates.
	var scr := DisplayServer.get_primary_screen()
	var origin := DisplayServer.screen_get_position(scr)
	var screen := DisplayServer.screen_get_size(scr)
	var usable := DisplayServer.screen_get_usable_rect(scr)
	var win := get_window()
	win.position = origin
	# A borderless window exactly the screen's size can be promoted to
	# exclusive fullscreen and lose transparency; one pixel short avoids it.
	win.size = Vector2i(screen.x, screen.y - 1)
	floor_y = usable.end.y - origin.y - 2
	left_x = usable.position.x - origin.x + 50
	right_x = usable.end.x - origin.x - 50

	for part in PIVOTS.keys():
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://art/kitten/%s.svg" % part), PART_SCALE)
		img.generate_mipmaps()
		textures[part] = ImageTexture.create_from_image(img)

	randomize()
	for i in N_KITTENS:
		kittens.append(_make_kitten())


func _sprite(part: String, pivot_svg: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = textures[part]
	s.centered = false
	s.position = -pivot_svg * PART_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


func _pivot(at_svg: Vector2, parent_pivot_svg: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = (at_svg - parent_pivot_svg) * PART_SCALE
	return n


func _make_kitten() -> Dictionary:
	var base: Vector2 = PIVOTS["body"]   # the kitten's origin is between its feet
	var root := Node2D.new()
	add_child(root)

	var tail := _pivot(PIVOTS["tail"], base)
	tail.add_child(_sprite("tail", PIVOTS["tail"]))
	root.add_child(tail)

	var body := _pivot(base, base)
	for p in ["body", "feet", "paws"]:
		body.add_child(_sprite(p, base))
	root.add_child(body)

	var head := _pivot(PIVOTS["head"], base)
	var ear_l := _pivot(PIVOTS["ear-l"], PIVOTS["head"])
	ear_l.add_child(_sprite("ear-l", PIVOTS["ear-l"]))
	var ear_r := _pivot(PIVOTS["ear-r"], PIVOTS["head"])
	ear_r.add_child(_sprite("ear-r", PIVOTS["ear-r"]))
	head.add_child(ear_l)
	head.add_child(ear_r)
	head.add_child(_sprite("head", PIVOTS["head"]))
	var eyes := _pivot(PIVOTS["eyes"], PIVOTS["head"])
	eyes.add_child(_sprite("eyes", PIVOTS["eyes"]))
	head.add_child(eyes)
	root.add_child(head)

	var k := {
		"root": root, "tail": tail, "body": body, "head": head,
		"head_base": head.position, "ear_l": ear_l, "ear_r": ear_r, "eyes": eyes,
		"x": randf_range(left_x, right_x), "dir": [-1, 1].pick_random(),
		"speed": randf_range(35.0, 70.0), "phase": randf() * TAU,
		"walking": randf() < 0.6, "state_left": randf_range(2.0, 6.0),
		"blink_in": randf_range(1.0, 5.0), "blink_left": 0.0,
		"twitch_in": randf_range(3.0, 9.0), "twitch_left": 0.0,
		"jump_left": 0.0,
	}
	return k


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	t += delta
	for k in kittens:
		_animate(k, delta)
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
	if grab_path != "" and not grabbed and t > 2.0:
		grabbed = true
		var img := get_viewport().get_texture().get_image()
		print("GRAB size=", img.get_size(), " format=", img.get_format(), " corner=", img.get_pixel(5, 5), " at_kitten=", img.get_pixelv(Vector2i((kittens[0].root as Node2D).position) + Vector2i(0, -40)))
		img.save_png(grab_path)
	if seconds > 0.0 and t >= seconds:
		_write_report()
		get_tree().quit()


func _animate(k: Dictionary, delta: float) -> void:
	var ph: float = k.phase
	# Switch between walking and sitting now and then.
	k.state_left -= delta
	if k.state_left <= 0.0:
		k.walking = not k.walking
		k.state_left = randf_range(2.0, 7.0)

	var hop := 0.0
	var squash := 1.0
	if k.walking:
		k.x += k.dir * k.speed * delta
		if k.x < left_x or k.x > right_x:
			k.dir = -k.dir
			k.x = clamp(k.x, left_x, right_x)
		var cycle := fmod(t * 2.2 + ph, 1.0)          # one hop per cycle
		hop = sin(cycle * PI) * 7.0
		squash = 1.0 - 0.06 * (1.0 - smoothstep(0.0, 0.18, cycle))  # squash on landing
	if k.jump_left > 0.0:
		k.jump_left -= delta
		var j: float = 1.0 - k.jump_left / 0.5
		hop += sin(j * PI) * 40.0

	var root: Node2D = k.root
	root.position = Vector2(k.x, floor_y - hop)
	# Tail on the right in the art, so face left by default and mirror to walk right.
	root.scale = Vector2(CRITTER_SCALE * (-1.0 if k.dir > 0 else 1.0), CRITTER_SCALE * squash)

	var breath := (sin(t * TAU / 3.4 + ph) + 1.0) * 0.5
	(k.body as Node2D).scale = Vector2(1.0 + 0.018 * breath, 1.0 + 0.035 * breath)
	(k.head as Node2D).position = k.head_base + Vector2(0, 2.5 * PART_SCALE * breath)

	var sway_speed: float = 4.0 if k.walking else 2.2
	(k.tail as Node2D).rotation = deg_to_rad(-9.0 - (6.0 if k.walking else 0.0)) * (sin(t * sway_speed + ph) + 1.0) * 0.5

	k.blink_in -= delta
	if k.blink_in <= 0.0:
		k.blink_left = 0.14
		k.blink_in = randf_range(2.5, 6.0)
	if k.blink_left > 0.0:
		k.blink_left -= delta
	var closed: float = 1.0 - sin(clamp(1.0 - k.blink_left / 0.14, 0.0, 1.0) * PI) if k.blink_left > 0.0 else 1.0
	(k.eyes as Node2D).scale = Vector2(1.0, max(0.08, closed))

	k.twitch_in -= delta
	if k.twitch_in <= 0.0:
		k.twitch_left = 0.25
		k.twitch_in = randf_range(4.0, 10.0)
	var twitch := 0.0
	if k.twitch_left > 0.0:
		k.twitch_left -= delta
		twitch = sin((1.0 - k.twitch_left / 0.25) * TAU) * deg_to_rad(-10.0)
	(k.ear_r as Node2D).rotation = twitch


func _update_passthrough() -> void:
	# One polygon for all kittens: each outline, joined by zero-width bridges.
	var poly := PackedVector2Array()
	var starts := []
	for k in kittens:
		var c: Vector2 = (k.root as Node2D).position
		for p in HIT_SHAPE:
			poly.append(c + p)
		poly.append(c + HIT_SHAPE[0])
		starts.append(c + HIT_SHAPE[0])
	starts.reverse()
	for p in starts:
		poly.append(p)
	DisplayServer.window_set_mouse_passthrough(poly)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for k in kittens:
			var c: Vector2 = (k.root as Node2D).position
			if Rect2(c + Vector2(-40, -84), Vector2(80, 88)).has_point(event.position):
				clicks += 1
				k.jump_left = 0.5
				print("click on kitten at ", c)
				break


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
	for k in kittens:
		var c: Vector2 = (k.root as Node2D).position
		pts.append([c.x, c.y])
	print("LIVE ", JSON.stringify({"t": t, "feet": pts, "pid": OS.get_process_id()}))


func _write_report() -> void:
	if report_path == "":
		return
	var trimmed := fps.slice(int(fps.size() * 0.2))   # skip the warm-up
	var r := {
		"godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_video_adapter_name(),
		"screen": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"kittens": N_KITTENS,
		"seconds": t,
		"fps": _stats(trimmed),
		"animate_ms": _stats(process_ms),
		"passthrough_ms": _stats(passthrough_ms),
		"clicks_seen": clicks,
		"transparent_bg": get_viewport().transparent_bg,
	}
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
	f.close()
