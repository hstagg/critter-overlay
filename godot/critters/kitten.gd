extends "res://critters/critter.gd"
## The kitten: a trotting walk, a loaf with its paws tucked and tail wrapped
## round, and its own groom (paw lick and face wipe), play-bow stretch and
## hunt (crouch, wiggle, pounce). Everything else is shared, in critter.gd.

# The kitten's origin: between its feet, on the ground.
const BASE := Vector2(150, 262)
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

# Walking legs, back to front: part, where its hip sits, diagonal pair, and
# whether it is a front leg. Front-near steps with back-far: a trot.
const WALK_LEGS := [
	["leg-front-far", Vector2(134, 224), 1, true],
	["leg-back-far", Vector2(214, 224), 0, false],
	["leg-front", Vector2(116, 224), 0, true],
	["leg-back", Vector2(196, 224), 1, false],
]

var pounced := false
var sit_paws: Node2D
var paw_left: Node2D
var groom_arm: Node2D
var tongue: Node2D
var loaf_front: Node2D
var loaf_tail: Node2D


func _define() -> void:
	species = "kitten"
	critter_scale = 0.45       # about 95 px tall
	base_pt = BASE
	ground_y = 262.0
	head_pivot = HEAD_PIVOT
	pivots = PIVOTS
	head_at = {"sit": Vector2(150, 190), "walk": Vector2(112, 198), "loaf": Vector2(150, 212)}
	tail_at = {"sit": Vector2(200, 226), "walk": Vector2(226, 192)}
	tail_rest_deg = {"sit": 0.0, "walk": -10.0}
	walk_legs = WALK_LEGS
	leg_len = 38.0
	stride_deg = 18.0
	leg_lift = 6.0
	hit_bounds = {
		"sit": Rect2(58, 28, 204, 234),
		"walk": Rect2(18, 36, 272, 226),
		"loaf": Rect2(58, 52, 194, 211),
	}
	sit_parts = ["body", "feet", "paws", "paw-left"]
	speed_range = Vector2(38.0, 62.0)
	head_height = 60.0
	back_hip = BACK_HIP


func _build_rig() -> void:
	# Back to front: tail, walking legs, body, head, groom arm, loaf front.
	super()
	sit_paws = sit_sprites["paws"]
	paw_left = sit_sprites["paw-left"]

	groom_arm = _pivot(PIVOTS["groom-arm"], BASE)
	groom_arm.add_child(_sprite("groom-arm"))
	torso_in.add_child(groom_arm)

	loaf_front = Node2D.new()
	loaf_front.add_child(_sprite("loaf-paws"))
	loaf_tail = _pivot(PIVOTS["loaf-tail"], BASE)
	loaf_tail.add_child(_sprite("loaf-tail"))
	loaf_front.add_child(loaf_tail)
	torso_in.add_child(loaf_front)


func _build_head_extras() -> void:
	tongue = _pivot(PIVOTS["tongue"], HEAD_PIVOT)
	tongue.add_child(_sprite("tongue"))
	tongue.z_index = 1   # licks the paw, which is drawn over the head
	head.add_child(tongue)


func _on_pose(p: String) -> void:
	loaf_front.visible = p == "loaf"


func _act_pose(b: String) -> String:
	return "walk" if b in ["stretch", "hunt"] else "sit"


func _on_begin(b: String) -> void:
	pounced = false
	if b == "groom":
		_kick_squash(-0.8)


func _can_hop() -> bool:
	return act != "hunt"


# --- Behaviours ------------------------------------------------------------------

func _behaviour_params(p: Dictionary) -> void:
	match act:
		"groom":
			_groom_params(p, act_t)
		"hunt":
			_hunt_params(p, act_t)
		_:
			super(p)


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
		p.tail_rot = tail_rest_deg["walk"] + 30.0 * c
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
		p.tail_rot = tail_rest_deg["walk"] + 20.0
		if not airborne:
			p.legs = "gait"   # landed: skids to a stop as the speed eases off


# --- Its own parts -----------------------------------------------------------------

func _apply_extras(p: Dictionary) -> void:
	tongue.visible = p.tongue > 0.02
	tongue.scale = Vector2(1.0, p.tongue)

	groom_arm.visible = p.arm
	sit_paws.visible = not p.arm
	paw_left.visible = p.arm
	if p.arm:
		groom_arm.position = (PIVOTS["groom-arm"] - BASE + Vector2(0, p.arm_dy)) * PART_SCALE
		groom_arm.rotation = deg_to_rad(p.arm_rot)

	if pose == "loaf":
		var flick := 0.0 if dozing else pow(maxf(0.0, sin(t * 0.9 + phase)), 4.0)
		loaf_tail.rotation = deg_to_rad(-5.0 * flick)
