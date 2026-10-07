extends "res://critters/two_head.gd"
## The otter (studio round 2, option 4: chubby, three-quarter head walking,
## tail tip lifted). Sits up facing you, paws together on its chest; walks
## low and long with its head turned two-thirds towards you (two_head.gd).
## Its walk is v2.0's slide: every so often it flops onto its belly, legs
## tucked, and slides. Its own behaviour is v2.0's belly_roll: it rolls onto
## its back and floats, paws on its chest, rocking. Naps lying low.

const BASE := Vector2(124, 270)
const HEAD_PIVOT := Vector2(124, 174)
const SIDE_PIVOT := Vector2(122, 217)
const TAIL_SIT := Vector2(140, 226)
const TAIL_WALK := Vector2(227.5, 210)
const FRONT_HIP := Vector2(133, 244.4)
const BACK_HIP := Vector2(210, 244.4)

const PIVOTS := {
	"tail": TAIL_SIT,
	"tail-side": TAIL_WALK,
	"body": BASE, "foot-l": BASE, "foot-r": BASE, "paws": BASE,
	"groom-paws": BASE,
	"ear-l": Vector2(77.2, 97), "ear-r": Vector2(170.8, 97),
	"head": HEAD_PIVOT,
	"eyes": Vector2(124, 124), "eyes-closed": Vector2(124, 124),
	"mouth-open": Vector2(124, 168),
	"walk-body": BASE, "loaf-body": BASE,
	"head-side": SIDE_PIVOT,
	"eye-side": Vector2(92.5, 176.8), "eye-side-closed": Vector2(92.5, 176.8),
	"leg-front": FRONT_HIP, "leg-front-far": Vector2(145, 244.4),
	"leg-back": BACK_HIP, "leg-back-far": Vector2(222, 244.4),
	"float": BASE,
}

const WALK_LEGS := [
	["leg-front-far", Vector2(145, 244.4), 1, true],
	["leg-back-far", Vector2(222, 244.4), 0, false],
	["leg-front", FRONT_HIP, 0, true],
	["leg-back", BACK_HIP, 1, false],
]

var tail_side: Node2D
var float_node: Node2D
var slide_in := 4.0
var slide_left := 0.0


func _define() -> void:
	species = "otter"
	critter_scale = 0.44
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	side_pivot = SIDE_PIVOT
	side_in_loaf = true
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": SIDE_PIVOT, "loaf": SIDE_PIVOT + Vector2(0, 10)}
	tail_at = {"sit": TAIL_SIT}
	walk_legs = WALK_LEGS
	leg_len = 26.0
	stride_deg = 24.0
	leg_lift = 5.0
	hit_bounds = {
		"sit": Rect2(48, 50, 220, 222),
		"walk": Rect2(36, 100, 262, 172),
		"loaf": Rect2(36, 110, 262, 162),
	}
	sit_parts = ["foot-l", "foot-r", "body", "paws"]
	speed_range = Vector2(44.0, 66.0)   # v2.0: 55 px/s, +/- 20%
	head_height = 48.0
	back_hip = BACK_HIP
	wear_crown = Vector2(124, 78)
	wear_neck = Vector2(124, 174)
	wear_walk_shift = Vector2(-16, 13)
	wear_nap_shift = Vector2(-16, 23)


func _build_rig() -> void:
	super()
	tail_side = _pivot(TAIL_WALK, BASE)
	tail_side.add_child(_sprite("tail-side"))
	torso_in.add_child(tail_side)
	torso_in.move_child(tail_side, 0)
	float_node = Node2D.new()
	float_node.add_child(_sprite("float"))
	float_node.visible = false
	torso_in.add_child(float_node)


func _on_pose(p: String) -> void:
	super(p)
	if tail_side != null:
		tail_side.visible = p == "walk" or p == "loaf"


func _act_pose(b: String) -> String:
	return "walk" if b == "stretch" else "sit"


func _can_hop() -> bool:
	return act != "belly_roll"


func tick(delta: float) -> void:
	# The slide: now and then, walking, it flops onto its belly and slides.
	if mode == "walk" and act == "" and not airborne and not climbing and not entering:
		if slide_left > 0.0:
			slide_left -= delta
		else:
			slide_in -= delta
			if slide_in <= 0.0:
				slide_in = rng.randf_range(5.0, 10.0)
				slide_left = rng.randf_range(1.0, 1.8)
				vx = facing * cruise * 1.8
				_kick_squash(-1.2)
	else:
		slide_left = 0.0
	super(delta)


func _gait_speed() -> float:
	return 1.4 if slide_left > 0.0 else 1.0


func _advance_gait(delta: float) -> void:
	if slide_left > 0.0:
		return   # legs stay tucked while sliding
	super(delta)


func _base_params() -> Dictionary:
	var p := super()
	p.float_k = 0.0
	if pose == "walk" and slide_left > 0.0:
		var k := smoothstep(0.0, 0.2, slide_left) * smoothstep(0.0, 0.2, 1.8 - slide_left)
		p.torso_dy += 14.0 * k
		p.legs = "tuck"
		p.head_off = p.head_off + Vector2(-4.0, 6.0) * k
		p.eyes_closed = true
		p.blink = false
	return p


func _behaviour_params(p: Dictionary) -> void:
	match act:
		"belly_roll":
			p.float_k = _env(act_t, act_len, 0.25)
		_:
			super(p)


func _apply_extras(p: Dictionary) -> void:
	super(p)
	if tail_side != null and tail_side.visible:
		tail_side.rotation = deg_to_rad(p.tail_rot + p.tail_extra) * 0.6 + tail_s
	if p.legs == "tuck":
		for leg in legs:
			leg.node.rotation = deg_to_rad(60.0 if leg.front else -60.0)
			leg.node.scale = Vector2(1.0, 0.5)
	else:
		for leg in legs:
			leg.node.scale = Vector2.ONE
	# Floating on its back: only the float drawing shows, rocking gently.
	var floating: bool = p.float_k > 0.5
	float_node.visible = floating
	body.visible = not floating
	head.visible = not floating
	if tail != null:
		tail.visible = not floating and pose == "sit"
	if floating:
		float_node.rotation = deg_to_rad(4.0 * sin(t * 2.2))
		float_node.position = Vector2(0, (2.0 * sin(t * 2.2 + 1.0)) * PART_SCALE)
