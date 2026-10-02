extends Node2D
## One kitten: a rig of SVG parts, posed and animated in code, and the small
## state machine that moves it between walking, sitting, loafing and its
## behaviours.
##
## main.gd owns the window, the click-through area and the behaviour
## evaluator (which decides when a kitten starts a behaviour). This file owns
## how the kitten moves and how each behaviour looks.
##
## Every frame builds a fresh set of pose parameters (_base_params), lets the
## current behaviour override them (_behaviour_params), then writes them to
## the rig (_apply). Secondary motion (tail, ears, body squash) runs on damped
## springs stepped at a fixed rate, so it looks the same at 30 and 60 fps.

const PART_SCALE := 0.75       # SVG units -> texture pixels
const CRITTER_SCALE := 0.45    # node scale: a kitten is about 95 px tall
const PX := PART_SCALE * CRITTER_SCALE   # SVG units -> screen pixels

# The kitten's origin: between its feet, on the ground. The art faces left.
const BASE := Vector2(150, 262)
const GROUND_Y := 262.0
const LEG_HIP := Vector2(118, 224)
const HEAD_PIVOT := Vector2(150, 190)
const BACK_HIP := Vector2(205, 224)    # the stretch tips forward about this
const FRONT_HIP := Vector2(125, 224)   # the hunting wiggle rocks about this

# Pivot of each part in SVG units, where it is drawn in its own file.
const PIVOTS := {
	"tail": Vector2(200, 226),
	"body": BASE, "feet": BASE, "paws": BASE, "paw-left": BASE,
	"walk-body": BASE,
	"leg-front": LEG_HIP, "leg-front-far": LEG_HIP,
	"leg-back": LEG_HIP, "leg-back-far": LEG_HIP,
	"loaf-body": BASE, "loaf-paws": BASE,
	"loaf-tail": Vector2(232, 246),
	"groom-arm": Vector2(172, 206),
	"ear-l": Vector2(100, 76),
	"ear-r": Vector2(200, 76),
	"head": HEAD_PIVOT,
	"eyes": Vector2(150, 124),
	"eyes-closed": Vector2(150, 124),
	"mouth-open": Vector2(150, 152),
	"tongue": Vector2(157, 158),
}

# Where the shared parts sit in each pose (SVG units).
const HEAD_AT := {"sit": Vector2(150, 190), "walk": Vector2(112, 198), "loaf": Vector2(150, 212)}
const TAIL_AT := {"sit": Vector2(200, 226), "walk": Vector2(226, 192)}
const TAIL_REST_DEG := {"sit": 0.0, "walk": -10.0}

# Walking legs, back to front: part, where its hip sits, diagonal pair, and
# whether it is a front leg. Front-near steps with back-far: a trot.
const WALK_LEGS := [
	["leg-front-far", Vector2(134, 224), 1, true],
	["leg-back-far", Vector2(214, 224), 0, false],
	["leg-front", Vector2(116, 224), 0, true],
	["leg-back", Vector2(196, 224), 1, false],
]
const LEG_LEN := 38.0          # hip to sole, SVG units
const STRIDE_DEG := 18.0       # leg swing either side of straight down
const LEG_LIFT := 6.0          # how high a foot lifts mid-swing, SVG units

# Hit box per pose, SVG units: left, top, width, height.
const HIT_BOUNDS := {
	"sit": Rect2(58, 28, 204, 234),
	"walk": Rect2(18, 36, 272, 226),
	"loaf": Rect2(58, 52, 194, 211),
}

const ACCEL := 4.0             # how quickly walking speed eases to its target, 1/s
const GRAVITY := 1800.0        # px/s^2, for hops and pounces
const SPRING_DT := 1.0 / 120.0

static var _textures := {}
static var zoom := 1.0           # draws everything bigger, for close-up demo captures

var world: Node                # main.gd: floor_y, left_x, right_x, mouse_local()
var rng := RandomNumberGenerator.new()

# Rig nodes.
var torso: Node2D
var torso_in: Node2D
var tail: Node2D
var legs_node: Node2D
var legs := []
var body: Node2D
var sit_body: Node2D
var sit_paws: Node2D
var paw_left: Node2D
var walk_body: Node2D
var loaf_body: Node2D
var head: Node2D
var ear_l: Node2D
var ear_r: Node2D
var eyes: Node2D
var eyes_open: Node2D
var eyes_shut: Node2D
var mouth_open: Node2D
var tongue: Node2D
var groom_arm: Node2D
var loaf_front: Node2D
var loaf_tail: Node2D

# Movement.
var pose := ""
var mode := "sit"              # walk | sit | loaf | act
var mode_left := 0.0
var facing := -1               # -1 faces left (as drawn), +1 faces right
var want_facing := -1
var vx := 0.0                  # px/s, signed
var cruise := 50.0
var gait := 0.0
var air_y := 0.0               # px above the floor
var air_vy := 0.0
var airborne := false
var entering := false          # walking in from off-screen; ignore the edges

# Behaviour.
var act := ""                  # the behaviour running, or ""
var act_t := 0.0
var act_len := 0.0
var act_pending := ""          # a behaviour waiting for the kitten to stop
var act_pending_len := 0.0
var pounced := false
var act_after := ""            # a behaviour chained to start when this one ends
var cooldowns := {}
var hold_nap := false          # nap until told to wake (the user is away)

# Ambient life.
var phase := 0.0
var t := 0.0
var dozing := false
var doze_in := 0.0
var blink_in := 0.0
var blink_left := 0.0
var blink_len := 0.14
var twitch_in := 0.0
var twitch_left := 0.0
var shift_in := 0.0            # weight shift while sitting
var shift_from := 0.0
var shift_to := 0.0
var shift_t := 1.0

# Springs: value, velocity.
var squash := 1.0
var squash_v := 0.0
var tail_s := 0.0
var tail_sv := 0.0
var ears_s := 0.0
var ears_sv := 0.0
var spring_acc := 0.0
var prev_vx := 0.0
var prev_vy := 0.0
var cycle_px := 4.0 * LEG_LEN * sin(deg_to_rad(STRIDE_DEG)) * PX * zoom


static func load_textures() -> void:
	if not _textures.is_empty():
		return
	for part in PIVOTS.keys():
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://art/kitten/%s.svg" % part), PART_SCALE)
		img.generate_mipmaps()
		_textures[part] = ImageTexture.create_from_image(img)


func setup(world_ref: Node, x: float, face: int, start_mode: String) -> void:
	world = world_ref
	rng.randomize()
	position.x = x
	facing = face
	want_facing = face
	phase = rng.randf() * TAU
	gait = rng.randf()
	cruise = rng.randf_range(38.0, 62.0) * zoom
	blink_in = rng.randf_range(1.0, 5.0)
	twitch_in = rng.randf_range(3.0, 9.0)
	shift_in = rng.randf_range(2.0, 6.0)
	_build()
	match start_mode:
		"walk":
			_go_walk()
			vx = facing * cruise
		"loaf":
			_go_loaf(rng.randf_range(8.0, 16.0))
		_:
			_go_sit()
	squash = 1.0


# --- Rig -------------------------------------------------------------------

func _sprite(part: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _textures[part]
	s.centered = false
	s.position = -PIVOTS[part] * PART_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


func _pivot(at_svg: Vector2, parent_at_svg: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = (at_svg - parent_at_svg) * PART_SCALE
	return n


func _build() -> void:
	# torso turns about a movable pivot; torso_in cancels the pivot's offset so
	# everything below it is laid out in plain SVG units about BASE.
	torso = Node2D.new()
	torso_in = Node2D.new()
	torso.add_child(torso_in)
	add_child(torso)

	# Draw order, back to front: tail, walking legs, body, head, groom arm,
	# loaf front.
	tail = _pivot(TAIL_AT["sit"], BASE)
	tail.add_child(_sprite("tail"))
	torso_in.add_child(tail)

	legs_node = Node2D.new()
	for spec in WALK_LEGS:
		var hip := _pivot(spec[1], BASE)
		hip.add_child(_sprite(spec[0]))
		legs_node.add_child(hip)
		legs.append({"node": hip, "hip": spec[1], "pair": spec[2], "front": spec[3]})
	torso_in.add_child(legs_node)

	body = _pivot(BASE, BASE)
	sit_body = Node2D.new()
	sit_body.add_child(_sprite("body"))
	sit_body.add_child(_sprite("feet"))
	sit_paws = _sprite("paws")
	paw_left = _sprite("paw-left")
	sit_body.add_child(sit_paws)
	sit_body.add_child(paw_left)
	walk_body = _sprite("walk-body")
	loaf_body = _sprite("loaf-body")
	body.add_child(sit_body)
	body.add_child(walk_body)
	body.add_child(loaf_body)
	torso_in.add_child(body)

	head = _pivot(HEAD_AT["sit"], BASE)
	ear_l = _pivot(PIVOTS["ear-l"], HEAD_PIVOT)
	ear_l.add_child(_sprite("ear-l"))
	ear_r = _pivot(PIVOTS["ear-r"], HEAD_PIVOT)
	ear_r.add_child(_sprite("ear-r"))
	head.add_child(ear_l)
	head.add_child(ear_r)
	head.add_child(_sprite("head"))
	eyes = _pivot(PIVOTS["eyes"], HEAD_PIVOT)
	eyes_open = _sprite("eyes")
	eyes_shut = _sprite("eyes-closed")
	eyes.add_child(eyes_open)
	eyes.add_child(eyes_shut)
	head.add_child(eyes)
	mouth_open = _pivot(PIVOTS["mouth-open"], HEAD_PIVOT)
	mouth_open.add_child(_sprite("mouth-open"))
	head.add_child(mouth_open)
	tongue = _pivot(PIVOTS["tongue"], HEAD_PIVOT)
	tongue.add_child(_sprite("tongue"))
	tongue.z_index = 1   # licks the paw, which is drawn over the head
	head.add_child(tongue)
	torso_in.add_child(head)

	groom_arm = _pivot(PIVOTS["groom-arm"], BASE)
	groom_arm.add_child(_sprite("groom-arm"))
	torso_in.add_child(groom_arm)

	loaf_front = Node2D.new()
	loaf_front.add_child(_sprite("loaf-paws"))
	loaf_tail = _pivot(PIVOTS["loaf-tail"], BASE)
	loaf_tail.add_child(_sprite("loaf-tail"))
	loaf_front.add_child(loaf_tail)
	torso_in.add_child(loaf_front)


func _set_pose(p: String) -> void:
	if p == pose:
		return
	pose = p
	tail.visible = p != "loaf"
	if p != "loaf":
		tail.position = (TAIL_AT[p] - BASE) * PART_SCALE
	legs_node.visible = p == "walk"
	sit_body.visible = p == "sit"
	walk_body.visible = p == "walk"
	loaf_body.visible = p == "loaf"
	loaf_front.visible = p == "loaf"
	_kick_squash(-1.2)   # a small settle on every change of pose


# --- Modes -----------------------------------------------------------------

func _go_walk() -> void:
	mode = "walk"
	mode_left = rng.randf_range(3.0, 8.0)
	if rng.randf() < 0.3:
		want_facing = -facing
	_set_pose("walk")


func _go_sit() -> void:
	mode = "sit"
	mode_left = rng.randf_range(2.0, 6.0)
	_set_pose("sit")


func _go_loaf(duration: float) -> void:
	mode = "loaf"
	mode_left = duration
	dozing = false
	doze_in = rng.randf_range(2.0, 5.0)
	_set_pose("loaf")


func _next_mode() -> void:
	match mode:
		"walk":
			_go_sit()
		"sit":
			if rng.randf() < 0.75 or on_cooldown("nap"):
				_go_walk()
			else:
				_go_loaf(rng.randf_range(8.0, 16.0))
		"loaf":
			_wake()


func _wake() -> void:
	dozing = false
	hold_nap = false
	cooldowns["nap"] = 60.0   # do not drop straight back off
	_go_sit()
	if rng.randf() < 0.7:
		start_behaviour("stretch", 1.8)


# --- Behaviours (called by main.gd's evaluator) ----------------------------

func can_start_behaviour() -> bool:
	return act == "" and act_pending == "" and not airborne and not entering \
		and mode != "loaf" and not hold_nap


func is_napping() -> bool:
	return mode == "loaf"


func on_cooldown(b: String) -> bool:
	return cooldowns.get(b, 0.0) > 0.0


func start_behaviour(b: String, duration: float) -> void:
	if b == "nap":
		_go_loaf(duration)
		return
	# A walking kitten eases to a stop first.
	if absf(vx) > 4.0:
		act_pending = b
		act_pending_len = duration
		return
	_begin(b, duration)


func _begin(b: String, duration: float) -> void:
	act = b
	pounced = false
	act_t = 0.0
	act_len = duration
	mode = "act"
	match b:
		"stretch", "hunt":
			_set_pose("walk")
		_:
			_set_pose("sit")
	if b == "groom":
		_kick_squash(-0.8)


func _end_behaviour() -> void:
	var finished := act
	act = ""
	if act_after != "":
		var next := act_after
		act_after = ""
		_begin(next, 1.1)
		return
	match finished:
		"stretch":
			if rng.randf() < 0.6:
				_go_walk()
			else:
				_go_sit()
		_:
			_go_sit()


func go_to_sleep() -> void:
	# The user has gone away: settle down and stay asleep until wake_up().
	act = ""
	act_pending = ""
	act_after = ""
	hold_nap = true
	if mode != "loaf":
		_go_loaf(INF)
	mode_left = INF


func wake_up() -> void:
	if mode == "loaf":
		_wake()
	hold_nap = false


func poke() -> void:
	# Clicked: hop. A napping kitten wakes up first.
	if mode == "loaf":
		dozing = false
		hold_nap = false
		_go_sit()
	if act == "hunt":
		return
	if not airborne:
		_launch(-420.0 * zoom)


func _launch(vy: float) -> void:
	airborne = true
	air_vy = vy
	_kick_squash(2.2)   # stretch on take-off


func _kick_squash(v: float) -> void:
	squash_v += v


# --- Per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	t += delta
	for b in cooldowns.keys():
		cooldowns[b] = maxf(0.0, cooldowns[b] - delta)

	_update_mode(delta)
	_update_motion(delta)
	_update_ambient(delta)
	_step_springs(delta)

	var p := _base_params()
	if act != "":
		_behaviour_params(p)
	_apply(p)


func _update_mode(delta: float) -> void:
	if act != "":
		act_t += delta
		if act_t >= act_len:
			_end_behaviour()
		return
	if act_pending != "":
		if absf(vx) < 4.0 and not airborne:
			var b := act_pending
			act_pending = ""
			_begin(b, act_pending_len)
		return
	mode_left -= delta
	if mode_left <= 0.0:
		_next_mode()


func _update_motion(delta: float) -> void:
	var left: float = world.left_x
	var right: float = world.right_x
	var target := 0.0
	if mode == "walk" and act_pending == "":
		if entering:
			if position.x > left and position.x < right:
				entering = false
		elif (position.x <= left and facing < 0) or (position.x >= right and facing > 0):
			want_facing = -facing
		if want_facing != facing:
			target = 0.0
			if absf(vx) < 3.0:
				facing = want_facing   # turn round once stopped
				_kick_squash(-1.0)
		else:
			target = facing * cruise
	if not airborne:
		vx += (target - vx) * (1.0 - exp(-ACCEL * delta))
	position.x += vx * delta

	if airborne:
		air_vy += GRAVITY * zoom * delta
		air_y -= air_vy * delta
		if air_y <= 0.0:
			# Landing: squash in proportion to how hard it came down.
			air_y = 0.0
			airborne = false
			_kick_squash(-clampf(air_vy / (140.0 * zoom), 0.5, 3.5))
			air_vy = 0.0

	if pose == "walk":
		gait = fmod(gait + absf(vx) * delta / cycle_px, 1.0)


func _update_ambient(delta: float) -> void:
	if mode == "loaf" and not dozing:
		doze_in -= delta
		if doze_in <= 0.0:
			dozing = true

	blink_in -= delta
	if blink_in <= 0.0 and not dozing:
		var loafing := mode == "loaf"
		blink_len = 0.35 if loafing else 0.14
		blink_left = blink_len
		blink_in = rng.randf_range(1.5, 3.0) if loafing else rng.randf_range(2.5, 6.0)
	if blink_left > 0.0:
		blink_left -= delta

	twitch_in -= delta
	if twitch_in <= 0.0:
		twitch_left = 0.25
		twitch_in = rng.randf_range(4.0, 10.0)
	if twitch_left > 0.0:
		twitch_left -= delta

	if mode == "sit" and act == "":
		shift_in -= delta
		if shift_in <= 0.0:
			shift_from = lerpf(shift_from, shift_to, _ease_io(shift_t))
			shift_to = rng.randf_range(-2.5, 2.5) if rng.randf() < 0.7 else 0.0
			shift_t = 0.0
			shift_in = rng.randf_range(2.0, 6.0)
	shift_t = minf(1.0, shift_t + delta / 0.6)


func _step_springs(delta: float) -> void:
	# Accelerations felt by the kitten, in its own facing frame: forward is
	# the way it faces, so the tail lags behind whichever way it turns.
	var ax := 0.0
	var ay := 0.0
	if delta > 0.0:
		ax = (vx - prev_vx) / delta * facing / zoom   # positive: speeding up forwards
		ay = (air_vy - prev_vy) / delta / zoom
	prev_vx = vx
	prev_vy = air_vy
	spring_acc += minf(delta, 0.1)
	while spring_acc >= SPRING_DT:
		spring_acc -= SPRING_DT
		var h := SPRING_DT
		# Body squash: a bouncy spring about 1.
		squash_v += (-260.0 * (squash - 1.0) - 9.0 * squash_v) * h
		squash += squash_v * h
		# Tail: lags speed changes, settles slowly, a little underdamped.
		tail_sv += (-40.0 * tail_s - 6.0 * tail_sv + ax * 0.012) * h
		tail_s += tail_sv * h
		# Ears: flop on landings and take-offs.
		ears_sv += (-160.0 * ears_s - 10.0 * ears_sv - ay * 0.004) * h
		ears_s += ears_sv * h
	squash = clampf(squash, 0.7, 1.3)
	tail_s = clampf(tail_s, -0.6, 0.6)
	ears_s = clampf(ears_s, -0.5, 0.5)


# --- Pose parameters ------------------------------------------------------------

func _base_params() -> Dictionary:
	var walking := pose == "walk"
	var loafing := pose == "loaf"
	var breath_period := 4.6 if loafing else 3.4
	var breath := (sin(t * TAU / breath_period + phase) + 1.0) * 0.5
	var p := {
		"torso_pivot": BASE, "torso_rot": 0.0, "torso_dy": 0.0,
		"breath": breath, "breath_y": 0.05 if loafing else 0.035,
		"head_off": Vector2(0, 2.5 * breath), "head_rot": 0.0,
		"eyes_off": Vector2.ZERO, "eyes_closed": dozing, "blink": true,
		"mouth": 0.0, "tongue": 0.0,
		"arm": false, "arm_rot": 0.0, "arm_dy": 0.0,
		"tail_rot": 0.0, "tail_extra": 0.0, "ear_l": 0.0, "ear_r": 0.0,
		"legs": "gait", "leg_front": 0.0, "leg_back": 0.0, "lean": 0.0,
	}
	if walking:
		var moving := smoothstep(0.0, 15.0, absf(vx))
		p.head_off = p.head_off + Vector2(0, sin(gait * TAU * 2.0 - 0.8) * 1.5 * moving)   # a beat behind the body
		p.eyes_off = Vector2(-6.0, 0)   # looking where it is going
		p.tail_rot = TAIL_REST_DEG["walk"] - 6.0 * (sin(t * 4.0 + phase) + 1.0) * 0.5
	elif pose == "sit":
		p.tail_rot = -9.0 * (sin(t * 2.2 + phase) + 1.0) * 0.5
		p.lean = lerpf(shift_from, shift_to, _ease_io(shift_t))
	if twitch_left > 0.0:
		p.ear_r = sin((1.0 - twitch_left / 0.25) * TAU) * -10.0
	return p


func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"sit_and_look":
			# Looks one way, then the other, with the head following a little.
			var look := sin(u * 1.4) * 6.0
			p.eyes_off = Vector2(look, -1.0)
			p.head_off = p.head_off + Vector2(look * 0.4, 0)
		"look_at_cursor":
			var m: Vector2 = world.mouse_local()
			var head_px := position + Vector2(0, -60) * zoom
			var d := (m - head_px)
			d.x *= -facing   # into the drawn (left-facing) frame
			var dir := d.normalized() if d.length() > 1.0 else Vector2.ZERO
			p.eyes_off = dir * 7.0
			p.head_rot = clampf(dir.x * 6.0, -6.0, 6.0) * _env(u, act_len, 0.3)
		"yawn":
			_yawn_params(p, u, act_len)
		"ear_flick":
			var f := sin(u / act_len * TAU * 2.0) * (1.0 - u / act_len)
			p.ear_l = 14.0 * f
			p.ear_r = -14.0 * f
		"tail_swish":
			p.tail_extra = sin(u / act_len * TAU * 1.5) * 22.0 * (1.0 - u / act_len)
		"groom":
			_groom_params(p, u)
		"stretch":
			_stretch_params(p, u)
		"hunt":
			_hunt_params(p, u)


func _yawn_params(p: Dictionary, u: float, length: float) -> void:
	var open := _env(u, length, 0.35)
	p.mouth = open
	p.eyes_closed = open > 0.3
	p.blink = false
	p.head_rot -= 7.0 * open
	p.head_off = p.head_off - Vector2(0, 3.0 * open)
	p.ear_l -= 8.0 * open
	p.ear_r += 8.0 * open


func _groom_params(p: Dictionary, u: float) -> void:
	# Raise the paw, lick it four times, wipe it over the face, put it down.
	var up := _env(u, act_len, 0.3)
	p.arm = true
	p.arm_dy = (1.0 - up) * 36.0
	p.arm_rot = -11.0
	p.eyes_closed = up > 0.5
	p.blink = false
	var lick_end := 0.3 + 1.5
	if u > 0.3 and u < lick_end:
		var k := fmod((u - 0.3) / 0.375, 1.0)
		var lick := sin(k * PI)
		p.tongue = lick
		p.head_off = p.head_off + Vector2(0, 2.5 * lick)
		p.head_rot += 3.0 * lick
	elif u >= lick_end:
		var w := clampf((u - lick_end) / 0.3, 0.0, 1.0) * up
		var rub := sin((u - lick_end) * TAU * 2.0)
		p.head_rot += 11.0 * w
		p.head_off = p.head_off + Vector2(4.0, 7.0) * w
		p.arm_rot += -6.0 * w + 5.0 * rub * w
		p.ear_r -= 10.0 * w


func _stretch_params(p: Dictionary, u: float) -> void:
	# A play bow: tip forward about the back hips, front legs reaching out,
	# tail up, eyes shut, then a yawn at full stretch.
	var s := _ease_io(_env(u, act_len, 0.45))
	p.torso_pivot = BACK_HIP
	p.torso_rot = -14.0 * s
	p.legs = "plant"
	p.leg_front = 1.0
	p.leg_back = 0.0
	p.tail_rot = TAIL_REST_DEG["walk"] - 22.0 * s
	p.eyes_off = Vector2.ZERO
	if s > 0.6:
		p.eyes_closed = true
		p.blink = false
		var y := clampf((u - 0.5) / maxf(0.1, act_len - 0.9), 0.0, 1.0)
		p.mouth = sin(y * PI)
	p.head_rot = -6.0 * s


func _hunt_params(p: Dictionary, u: float) -> void:
	# Crouch, wiggle, pounce. The pounce is a real jump forwards.
	var crouch_in := 0.35
	var wiggle_end := act_len - 0.6
	p.eyes_off = Vector2(-8.0, 1.0)
	p.blink = false
	p.ear_l = 10.0
	p.ear_r = -10.0
	if u < wiggle_end:
		var c := _ease_io(clampf(u / crouch_in, 0.0, 1.0))
		p.torso_dy = 12.0 * c
		p.legs = "plant"
		p.leg_front = 1.0
		p.leg_back = -1.0
		p.tail_rot = TAIL_REST_DEG["walk"] + 30.0 * c
		if u > crouch_in:
			var wig := sin((u - crouch_in) * TAU * 5.0)
			p.torso_pivot = FRONT_HIP
			p.torso_rot = 3.0 * wig
			p.tail_extra = 6.0 * wig
	else:
		if not pounced:
			pounced = true
			_launch(-380.0 * zoom)
			vx = facing * 190.0 * zoom
		p.legs = "leap"
		p.torso_rot = 10.0 if air_vy < 0.0 else -6.0
		p.tail_rot = TAIL_REST_DEG["walk"] + 20.0
		if not airborne:
			p.legs = "gait"   # landed: skids to a stop as the speed eases off


# --- Writing the pose to the rig ---------------------------------------------

func _apply(p: Dictionary) -> void:
	var walking := pose == "walk"

	position.y = world.floor_y - air_y
	var sq := squash
	scale = Vector2(CRITTER_SCALE * zoom * (1.0 + (1.0 - sq) * 0.6) * (1.0 if facing < 0 else -1.0), CRITTER_SCALE * zoom * sq)

	var pivot: Vector2 = p.torso_pivot
	torso.position = (pivot - BASE + Vector2(0, p.torso_dy)) * PART_SCALE
	torso_in.position = -(pivot - BASE) * PART_SCALE
	torso.rotation = deg_to_rad(p.torso_rot)

	body.scale = Vector2(1.0 + 0.018 * p.breath, 1.0 + p.breath_y * p.breath)
	body.rotation = deg_to_rad(p.lean)

	head.position = (HEAD_AT[pose] - BASE + p.head_off) * PART_SCALE
	head.rotation = deg_to_rad(p.head_rot + p.lean * 0.6)
	eyes.position = (PIVOTS["eyes"] - HEAD_PIVOT + p.eyes_off) * PART_SCALE
	var shut: bool = p.eyes_closed
	eyes_open.visible = not shut
	eyes_shut.visible = shut
	var closed := 1.0
	if p.blink and blink_left > 0.0:
		closed = 1.0 - sin(clampf(1.0 - blink_left / blink_len, 0.0, 1.0) * PI)
	eyes_open.scale = Vector2(1.0, maxf(0.08, closed))
	mouth_open.visible = p.mouth > 0.02
	mouth_open.scale = Vector2(0.8 + 0.2 * p.mouth, p.mouth)
	tongue.visible = p.tongue > 0.02
	tongue.scale = Vector2(1.0, p.tongue)
	ear_l.rotation = deg_to_rad(p.ear_l) - ears_s
	ear_r.rotation = deg_to_rad(p.ear_r) + ears_s

	groom_arm.visible = p.arm
	sit_paws.visible = not p.arm
	paw_left.visible = p.arm
	if p.arm:
		groom_arm.position = (PIVOTS["groom-arm"] - BASE + Vector2(0, p.arm_dy)) * PART_SCALE
		groom_arm.rotation = deg_to_rad(p.arm_rot)

	if pose != "loaf":
		tail.rotation = deg_to_rad(p.tail_rot + p.tail_extra) + tail_s
	else:
		var flick := 0.0 if dozing else pow(maxf(0.0, sin(t * 0.9 + phase)), 4.0)
		loaf_tail.rotation = deg_to_rad(-5.0 * flick)

	if walking:
		match p.legs:
			"gait":
				_gait_legs()
			"plant":
				_plant_legs(p)
			"leap":
				for leg in legs:
					var node: Node2D = leg.node
					node.position = (leg.hip - BASE) * PART_SCALE
					node.rotation = deg_to_rad(40.0 if leg.front else -40.0)


func _gait_legs() -> void:
	var moving := smoothstep(0.0, 15.0, absf(vx))
	var stance_deg := 0.0
	for leg in legs:
		var ph: float = fmod(gait + 0.5 * leg.pair, 1.0)
		var a: float
		var lift := 0.0
		if ph < 0.5:
			# Stance: the foot is planted and sweeps back at the body's speed.
			a = lerpf(STRIDE_DEG, -STRIDE_DEG, ph / 0.5)
			stance_deg = a
		else:
			# Swing: the foot lifts and eases forward to the next step.
			var s := (ph - 0.5) / 0.5
			a = lerpf(-STRIDE_DEG, STRIDE_DEG, smoothstep(0.0, 1.0, s))
			lift = sin(s * PI) * LEG_LIFT
		var node: Node2D = leg.node
		node.rotation = deg_to_rad(a * moving)
		node.position = (leg.hip - BASE + Vector2(0, -lift * moving)) * PART_SCALE
	# A swung leg is shorter vertically, so the body dips at each footfall
	# and rises over the planted foot: the bob comes from the legs.
	var drop := LEG_LEN * (1.0 - cos(deg_to_rad(stance_deg * moving)))
	torso.position.y += drop * PART_SCALE


func _plant_legs(p: Dictionary) -> void:
	# Turn each leg so its foot rests on the ground wherever the tilted or
	# lowered torso has put its hip. Front legs reach forwards, back legs
	# backwards (or stand straight when the weight is 0).
	var pivot: Vector2 = p.torso_pivot
	var rot := deg_to_rad(p.torso_rot)
	for leg in legs:
		var hip: Vector2 = leg.hip
		var world_hip: Vector2 = pivot + (hip - pivot).rotated(rot) + Vector2(0, p.torso_dy)
		var c := clampf((GROUND_Y - world_hip.y) / LEG_LEN, -1.0, 1.0)
		var reach: float = p.leg_front if leg.front else p.leg_back
		var angle := acos(c) * signf(reach) if reach != 0.0 else 0.0
		var node: Node2D = leg.node
		node.position = (hip - BASE) * PART_SCALE
		node.rotation = angle - rot


func hit_rect() -> Rect2:
	# The pose's hit box in window pixels, mirrored when facing right, with a
	# few pixels of slack below the feet.
	var b: Rect2 = HIT_BOUNDS[pose]
	var x0 := (b.position.x - BASE.x) * PX * zoom
	var w := b.size.x * PX * zoom
	if facing > 0:
		x0 = -x0 - w
	return Rect2(position + Vector2(x0, (b.position.y - BASE.y) * PX * zoom), Vector2(w, b.size.y * PX * zoom + 4.0))


# --- Helpers ------------------------------------------------------------------

func _env(u: float, length: float, ramp: float) -> float:
	# 0 -> 1 over `ramp` seconds, hold, 1 -> 0 over the last `ramp` seconds.
	return clampf(minf(u / ramp, (length - u) / ramp), 0.0, 1.0)


func _ease_io(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
