extends "res://critters/two_head.gd"
## The squirrel (studio round 2, option 2: chibi, stuffed cheeks, curly red
## tail). Sits up facing you, tail curling up behind; walks side-on with its
## head in profile (two_head.gd). Its walk is v2.0's dart-and-freeze: quick
## bursts, a sudden stop to look, then off again. The tail rides a spring in
## both poses and flicks (tail_swish). Its own behaviour is v2.0's chitter:
## quick chatter with flicks. Naps curled up under its tail.

const BASE := Vector2(134, 270)
const HEAD_PIVOT := Vector2(134, 194)
const SIDE_PIVOT := Vector2(117, 199)
const TAIL_SIT := Vector2(166, 250)
const TAIL_WALK := Vector2(210, 230)
const FRONT_HIP := Vector2(124, 228)
const BACK_HIP := Vector2(187, 246)

const PIVOTS := {
	"tail": TAIL_SIT,
	"tail-side": TAIL_WALK,
	"body": BASE, "foot-l": BASE, "foot-r": BASE, "paws": BASE,
	"groom-paws": BASE,
	"ear-l": Vector2(95.5, 96.8), "ear-r": Vector2(172.5, 96.8),
	"head": HEAD_PIVOT,
	"eyes": Vector2(134, 138.8), "eyes-closed": Vector2(134, 138.8),
	"mouth-open": Vector2(134, 170),
	"walk-body": BASE, "loaf-body": BASE,
	"loaf-eyes": Vector2(76, 238), "loaf-eyes-closed": Vector2(76, 238),
	"head-side": SIDE_PIVOT,
	"eye-side": Vector2(65.8, 161.8), "eye-side-closed": Vector2(65.8, 161.8),
	"leg-front": FRONT_HIP, "leg-front-far": Vector2(134, 228),
	"leg-back": BACK_HIP, "leg-back-far": Vector2(197, 246),
}

const WALK_LEGS := [
	["leg-front-far", Vector2(134, 228), 1, true],
	["leg-back-far", Vector2(197, 246), 0, false],
	["leg-front", FRONT_HIP, 0, true],
	["leg-back", BACK_HIP, 1, false],
]

var tail_side: Node2D
var freeze_in := 3.0
var freeze_left := 0.0


func _define() -> void:
	species = "squirrel"
	critter_scale = 0.43
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	side_pivot = SIDE_PIVOT
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": SIDE_PIVOT, "loaf": SIDE_PIVOT}
	tail_at = {"sit": TAIL_SIT}
	tail_rest_deg = {"sit": 0.0, "walk": 0.0}
	walk_legs = WALK_LEGS
	leg_len = 34.0
	stride_deg = 22.0
	leg_lift = 6.0
	hit_bounds = {
		"sit": Rect2(50, 28, 232, 244),
		"walk": Rect2(8, 40, 290, 232),
		"loaf": Rect2(40, 150, 240, 122),
	}
	sit_parts = ["foot-l", "foot-r", "body", "paws"]
	speed_range = Vector2(52.0, 78.0)   # v2.0: 65 px/s, +/- 20%
	head_height = 55.0
	back_hip = BACK_HIP
	wear_crown = Vector2(134, 80)
	wear_neck = Vector2(134, 194)
	wear_walk_shift = Vector2(-35, 31)
	wear_nap_shift = Vector2(-31, 119)


func _build_rig() -> void:
	super()
	tail_side = _pivot(TAIL_WALK, BASE)
	tail_side.add_child(_sprite("tail-side"))
	torso_in.add_child(tail_side)
	torso_in.move_child(tail_side, 0)   # behind everything


func _on_pose(p: String) -> void:
	super(p)
	if tail_side != null:
		tail_side.visible = p == "walk"


func _act_pose(b: String) -> String:
	return "walk" if b == "stretch" else "sit"


func tick(delta: float) -> void:
	# Dart and freeze: walking, every few seconds it stops dead, looks, and
	# darts off faster than it was going.
	if mode == "walk" and act == "" and not airborne and not entering and not climbing:
		if freeze_left > 0.0:
			freeze_left -= delta
			vx = 0.0
			if freeze_left <= 0.0:
				vx = facing * cruise * 1.6
				_kick_squash(1.0)
		else:
			freeze_in -= delta
			if freeze_in <= 0.0:
				freeze_in = rng.randf_range(2.0, 5.0)
				freeze_left = rng.randf_range(0.4, 1.1)
				_kick_squash(-1.4)
	super(delta)


func _base_params() -> Dictionary:
	var p := super()
	if pose == "walk" and freeze_left > 0.0:
		# Frozen: head up, looking about, tail twitching.
		p.head_off = p.head_off + Vector2(0, -3.0)
		p.tail_extra += 10.0 * sin(t * 18.0)
	return p


func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"chitter":
			# Quick chatter: mouth snapping, cheeks puffing, tail flicking.
			var k := _env(u, act_len, 0.1)
			var chat := maxf(0.0, sin(u * TAU * 7.0))
			p.mouth = 0.7 * chat * k
			p.head_off = p.head_off + Vector2(0, -1.5 * chat * k)
			p.tail_extra += 16.0 * sin(u * TAU * 3.5) * k
			p.ear_l -= 6.0 * k
			p.ear_r += 6.0 * k
		_:
			super(p)


func _apply_extras(p: Dictionary) -> void:
	super(p)
	if tail_side != null and tail_side.visible:
		tail_side.rotation = deg_to_rad(p.tail_rot + p.tail_extra) * 0.7 + tail_s
