extends Node2D
## Critter Overlay v3 engine spike: rigged kittens on a transparent,
## click-through, always-on-top window.
##
## Each kitten is built from the SVG parts in art/kitten/, rasterised at
## runtime, and animated by rotating and scaling pivots in code. A kitten has
## three poses, each a set of parts shown or hidden on the same rig:
##   sit   front-facing, breathing, blinking, tail sway
##   walk  side-on body, four legs in a diagonal trot, head bob, tail up
##   loaf  paws tucked, tail wrapped round the front, dozes off with eyes shut
##
## Unattended run: `godot --path godot -- --seconds=20 --report=PATH`
## quits after N seconds and writes timings to PATH, and streams live critter
## positions on stdout every half second for an external hit test.
## `--pose=sit|walk|loaf` holds every kitten in one pose; `--kittens=N` sets
## the count; `--grab=PATH` saves one frame after two seconds, and a PATH
## containing %d saves a short burst of frames instead.

const PART_SCALE := 0.75       # SVG units -> texture pixels
const CRITTER_SCALE := 0.45    # node scale: a kitten is about 95 px tall
const PX := PART_SCALE * CRITTER_SCALE   # SVG units -> screen pixels
const N_KITTENS := 12

# The kitten's origin: between its feet, on the ground.
const BASE := Vector2(150, 262)
const LEG_HIP := Vector2(118, 224)

# Pivot of each part in SVG units, where it is drawn in its own file.
const PIVOTS := {
	"tail": Vector2(200, 226),
	"body": BASE, "feet": BASE, "paws": BASE,
	"walk-body": BASE,
	"leg-front": LEG_HIP, "leg-front-far": LEG_HIP,
	"leg-back": LEG_HIP, "leg-back-far": LEG_HIP,
	"loaf-body": BASE, "loaf-paws": BASE,
	"loaf-tail": Vector2(232, 246),
	"ear-l": Vector2(100, 76),
	"ear-r": Vector2(200, 76),
	"head": Vector2(150, 190),
	"eyes": Vector2(150, 124),
	"eyes-closed": Vector2(150, 124),
}

# Where the shared parts sit in each pose (SVG units). The art faces left.
const HEAD_AT := {"sit": Vector2(150, 190), "walk": Vector2(112, 198), "loaf": Vector2(150, 212)}
const TAIL_AT := {"sit": Vector2(200, 226), "walk": Vector2(226, 192)}
const TAIL_REST_DEG := {"sit": 0.0, "walk": -10.0}

# Walking legs, back to front: part, where its hip sits, diagonal pair.
# Front-near steps with back-far, front-far with back-near: a trot.
const WALK_LEGS := [
	["leg-front-far", Vector2(134, 224), 1],
	["leg-back-far", Vector2(214, 224), 0],
	["leg-front", Vector2(116, 224), 0],
	["leg-back", Vector2(196, 224), 1],
]
const LEG_LEN := 38.0          # hip to sole, SVG units
const STRIDE_DEG := 18.0       # leg swing either side of straight down
const LEG_LIFT := 6.0          # how high a foot lifts mid-swing, SVG units
# Ground covered per gait cycle. The planted foot sweeps back 2 L sin(a) in
# half a cycle, so tying the cycle to distance keeps the feet from skating.
var cycle_px := 4.0 * LEG_LEN * sin(deg_to_rad(STRIDE_DEG)) * PX

# Hit box per pose, SVG units: left, top, width, height.
const HIT_BOUNDS := {
	"sit": Rect2(58, 28, 204, 234),
	"walk": Rect2(18, 36, 272, 226),
	"loaf": Rect2(58, 52, 194, 211),
}

const SETTLE_S := 0.2          # squash-and-settle when changing pose

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
var grab_count := 0
var grab_next := 2.0
var fixed_pose := ""
var n_kittens := N_KITTENS


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
		elif arg.begins_with("--pose="):
			fixed_pose = arg.get_slice("=", 1)
		elif arg.begins_with("--kittens="):
			n_kittens = int(arg.get_slice("=", 1))

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
	for i in n_kittens:
		kittens.append(_make_kitten())


func _sprite(part: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = textures[part]
	s.centered = false
	s.position = -PIVOTS[part] * PART_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


func _pivot(at_svg: Vector2, parent_at_svg: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = (at_svg - parent_at_svg) * PART_SCALE
	return n


func _make_kitten() -> Dictionary:
	# Draw order, back to front: tail, walking legs, body, head, loaf front.
	var root := Node2D.new()
	add_child(root)

	var tail := _pivot(TAIL_AT["sit"], BASE)
	tail.add_child(_sprite("tail"))
	root.add_child(tail)

	var legs_node := Node2D.new()
	var legs := []
	for spec in WALK_LEGS:
		var hip := _pivot(spec[1], BASE)
		hip.add_child(_sprite(spec[0]))
		legs_node.add_child(hip)
		legs.append({"node": hip, "at": hip.position, "pair": spec[2]})
	root.add_child(legs_node)

	var body := _pivot(BASE, BASE)
	var sit_body := Node2D.new()
	for p in ["body", "feet", "paws"]:
		sit_body.add_child(_sprite(p))
	var walk_body := _sprite("walk-body")
	var loaf_body := _sprite("loaf-body")
	body.add_child(sit_body)
	body.add_child(walk_body)
	body.add_child(loaf_body)
	root.add_child(body)

	var head := _pivot(HEAD_AT["sit"], BASE)
	var ear_l := _pivot(PIVOTS["ear-l"], PIVOTS["head"])
	ear_l.add_child(_sprite("ear-l"))
	var ear_r := _pivot(PIVOTS["ear-r"], PIVOTS["head"])
	ear_r.add_child(_sprite("ear-r"))
	head.add_child(ear_l)
	head.add_child(ear_r)
	head.add_child(_sprite("head"))
	var eyes := _pivot(PIVOTS["eyes"], PIVOTS["head"])
	var eyes_open := _sprite("eyes")
	var eyes_shut := _sprite("eyes-closed")
	eyes.add_child(eyes_open)
	eyes.add_child(eyes_shut)
	head.add_child(eyes)
	root.add_child(head)

	var loaf_front := Node2D.new()
	loaf_front.add_child(_sprite("loaf-paws"))
	var loaf_tail := _pivot(PIVOTS["loaf-tail"], BASE)
	loaf_tail.add_child(_sprite("loaf-tail"))
	loaf_front.add_child(loaf_tail)
	root.add_child(loaf_front)

	var k := {
		"root": root, "tail": tail, "legs_node": legs_node, "legs": legs,
		"body": body, "sit_body": sit_body, "walk_body": walk_body, "loaf_body": loaf_body,
		"head": head, "head_base": head.position, "ear_l": ear_l, "ear_r": ear_r,
		"eyes": eyes, "eyes_base": eyes.position, "eyes_open": eyes_open, "eyes_shut": eyes_shut,
		"loaf_front": loaf_front, "loaf_tail": loaf_tail,
		"pose": "", "x": randf_range(left_x, right_x), "dir": [-1, 1].pick_random(),
		"speed": randf_range(35.0, 70.0), "phase": randf() * TAU, "gait": randf(),
		"state_left": 0.0, "settle": 0.0, "dozing": false, "doze_in": 0.0,
		"blink_in": randf_range(1.0, 5.0), "blink_left": 0.0, "blink_len": 0.14,
		"twitch_in": randf_range(3.0, 9.0), "twitch_left": 0.0,
		"jump_left": 0.0,
	}
	_set_pose(k, fixed_pose if fixed_pose != "" else ["sit", "walk", "walk", "loaf"].pick_random())
	k.settle = 0.0
	return k


func _set_pose(k: Dictionary, pose: String) -> void:
	k.pose = pose
	(k.tail as Node2D).visible = pose != "loaf"
	if pose != "loaf":
		(k.tail as Node2D).position = (TAIL_AT[pose] - BASE) * PART_SCALE
	(k.legs_node as Node2D).visible = pose == "walk"
	(k.sit_body as Node2D).visible = pose == "sit"
	(k.walk_body as Node2D).visible = pose == "walk"
	(k.loaf_body as Node2D).visible = pose == "loaf"
	(k.loaf_front as Node2D).visible = pose == "loaf"
	k.head_base = (HEAD_AT[pose] - BASE) * PART_SCALE
	k.dozing = false
	k.doze_in = randf_range(2.0, 5.0)
	k.settle = SETTLE_S
	match pose:
		"walk":
			k.state_left = randf_range(3.0, 8.0)
			if randf() < 0.3:
				k.dir = -k.dir
		"sit":
			k.state_left = randf_range(2.0, 6.0)
		"loaf":
			k.state_left = randf_range(8.0, 16.0)
	_show_eyes(k)


func _next_pose(pose: String) -> String:
	match pose:
		"walk":
			return "sit" if randf() < 0.65 else "loaf"
		"sit":
			return "walk" if randf() < 0.6 else "loaf"
	return "sit"   # a loafing kitten wakes up by sitting


func _show_eyes(k: Dictionary) -> void:
	(k.eyes_open as Node2D).visible = not k.dozing
	(k.eyes_shut as Node2D).visible = k.dozing


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
	if grab_path != "" and t >= grab_next:
		_grab()
	if seconds > 0.0 and t >= seconds:
		_write_report()
		get_tree().quit()


func _grab() -> void:
	var img := get_viewport().get_texture().get_image()
	if "%d" in grab_path:
		img.save_png(grab_path % grab_count)
		grab_count += 1
		grab_next = t + 1.0 / 15.0 if grab_count < 16 else INF
	else:
		print("GRAB size=", img.get_size(), " format=", img.get_format(), " corner=", img.get_pixel(5, 5))
		img.save_png(grab_path)
		grab_next = INF


func _animate(k: Dictionary, delta: float) -> void:
	var ph: float = k.phase
	if fixed_pose == "":
		k.state_left -= delta
		if k.state_left <= 0.0:
			_set_pose(k, _next_pose(k.pose))

	var walking: bool = k.pose == "walk"
	var drop := 0.0   # SVG units the whole kitten sits lower, from the gait
	if walking:
		k.x += k.dir * k.speed * delta
		if k.x < left_x or k.x > right_x:
			k.dir = -k.dir
			k.x = clamp(k.x, left_x, right_x)
		k.gait = fmod(k.gait + k.speed * delta / cycle_px, 1.0)
		var stance_deg := 0.0
		for leg in k.legs:
			var p: float = fmod(k.gait + 0.5 * leg.pair, 1.0)
			var a: float
			var lift := 0.0
			if p < 0.5:
				# Stance: the foot is planted and sweeps back at the body's speed.
				a = lerpf(STRIDE_DEG, -STRIDE_DEG, p / 0.5)
				stance_deg = a
			else:
				# Swing: the foot lifts and eases forward to the next step.
				var s := (p - 0.5) / 0.5
				a = lerpf(-STRIDE_DEG, STRIDE_DEG, smoothstep(0.0, 1.0, s))
				lift = sin(s * PI) * LEG_LIFT
			(leg.node as Node2D).rotation = deg_to_rad(a)
			(leg.node as Node2D).position = leg.at + Vector2(0, -lift * PART_SCALE)
		# A swung leg is shorter vertically, so the body dips at each footfall
		# and rises over the planted foot: the bob comes from the legs.
		drop = LEG_LEN * (1.0 - cos(deg_to_rad(stance_deg)))

	var hop := 0.0
	if k.jump_left > 0.0:
		k.jump_left -= delta
		var j: float = 1.0 - k.jump_left / 0.5
		hop += sin(j * PI) * 40.0

	# Squash on a pose change, then ease back: wider and shorter, same volume.
	var squash := 1.0
	if k.settle > 0.0:
		k.settle = maxf(0.0, k.settle - delta)
		squash = 1.0 - 0.08 * ease(k.settle / SETTLE_S, 2.0)

	var root: Node2D = k.root
	root.position = Vector2(k.x, floor_y - hop + drop * PX)
	# The art faces left, so mirror to face right.
	root.scale = Vector2(CRITTER_SCALE * (2.0 - squash) * (-1.0 if k.dir > 0 else 1.0), CRITTER_SCALE * squash)

	var loafing: bool = k.pose == "loaf"
	var breath_period := 4.6 if loafing else 3.4
	var breath := (sin(t * TAU / breath_period + ph) + 1.0) * 0.5
	var breath_y := 0.05 if loafing else 0.035
	(k.body as Node2D).scale = Vector2(1.0 + 0.018 * breath, 1.0 + breath_y * breath)
	var head_off := Vector2(0, 2.5 * breath)
	if walking:
		head_off.y += sin(k.gait * TAU * 2.0 - 0.8) * 1.5   # a beat behind the body
	(k.head as Node2D).position = k.head_base + head_off * PART_SCALE
	# Walking, the eyes look a little ahead.
	(k.eyes as Node2D).position = k.eyes_base + Vector2(-6.0 * PART_SCALE if walking else 0.0, 0)

	if not loafing:
		var sway_speed: float = 4.0 if walking else 2.2
		var rest: float = TAIL_REST_DEG[k.pose]
		(k.tail as Node2D).rotation = deg_to_rad(rest - (6.0 if walking else 9.0) * (sin(t * sway_speed + ph) + 1.0) * 0.5)
	else:
		# The wrapped tail's tip lifts now and then, and stops once asleep.
		var flick := 0.0 if k.dozing else maxf(0.0, sin(t * 0.9 + ph)) ** 4
		(k.loaf_tail as Node2D).rotation = deg_to_rad(-5.0 * flick)
		k.doze_in -= delta
		if not k.dozing and k.doze_in <= 0.0:
			k.dozing = true
			_show_eyes(k)

	# Blinks; slow, heavy ones while settling into a loaf.
	k.blink_in -= delta
	if k.blink_in <= 0.0 and not k.dozing:
		k.blink_len = 0.35 if loafing else 0.14
		k.blink_left = k.blink_len
		k.blink_in = randf_range(1.5, 3.0) if loafing else randf_range(2.5, 6.0)
	if k.blink_left > 0.0:
		k.blink_left -= delta
	var closed: float = 1.0 - sin(clamp(1.0 - k.blink_left / k.blink_len, 0.0, 1.0) * PI) if k.blink_left > 0.0 else 1.0
	(k.eyes_open as Node2D).scale = Vector2(1.0, max(0.08, closed))

	k.twitch_in -= delta
	if k.twitch_in <= 0.0:
		k.twitch_left = 0.25
		k.twitch_in = randf_range(4.0, 10.0)
	var twitch := 0.0
	if k.twitch_left > 0.0:
		k.twitch_left -= delta
		twitch = sin((1.0 - k.twitch_left / 0.25) * TAU) * deg_to_rad(-10.0)
	(k.ear_r as Node2D).rotation = twitch


func _hit_rect(k: Dictionary) -> Rect2:
	# The pose's hit box in window pixels, mirrored when facing right, with a
	# few pixels of slack below the feet.
	var b: Rect2 = HIT_BOUNDS[k.pose]
	var x0 := (b.position.x - BASE.x) * PX
	var w := b.size.x * PX
	if k.dir > 0:
		x0 = -x0 - w
	var c: Vector2 = (k.root as Node2D).position
	return Rect2(c + Vector2(x0, (b.position.y - BASE.y) * PX), Vector2(w, b.size.y * PX + 4.0))


func _update_passthrough() -> void:
	# One polygon for all kittens: each outline, joined by zero-width bridges.
	var poly := PackedVector2Array()
	var starts := []
	for k in kittens:
		var r := _hit_rect(k)
		var shape := [
			r.position + Vector2(12, 0), Vector2(r.end.x - 12, r.position.y),
			Vector2(r.end.x, r.position.y + 24), r.end,
			Vector2(r.position.x, r.end.y), r.position + Vector2(0, 24),
		]
		for p in shape:
			poly.append(p)
		poly.append(shape[0])
		starts.append(shape[0])
	starts.reverse()
	for p in starts:
		poly.append(p)
	DisplayServer.window_set_mouse_passthrough(poly)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for k in kittens:
			if _hit_rect(k).has_point(event.position):
				clicks += 1
				if k.pose == "loaf":
					_set_pose(k, "sit")   # a napping kitten wakes up first
				k.jump_left = 0.5
				print("click on kitten at ", (k.root as Node2D).position)
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
		"kittens": n_kittens,
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
