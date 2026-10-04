extends "res://critters/critter.gd"
## The duckling: a fluffball with a big round head facing you, a tiny beak,
## a three-feather tuft on a spring and stubby wings it flaps. It waddles
## side-on on two short orange legs (v2.0's waddle gait: the body rocks from
## foot to foot, tail wagging against it). Its own behaviours are v2.0's
## preen and peck_ground; its groom is a fluff-up with both wings going, its
## stretch is one wing up, and it scratches with a wing tip, not a foot.
## Naps settled down as a ball.

const BASE := Vector2(150, 270)
const HEAD_PIVOT := Vector2(150, 196)
const HIP := Vector2(156, 244)
const FEET := Vector2(166, 270)        # the waddle rocks about this

const PIVOTS := {
	"tail": Vector2(230, 208),
	"body": BASE, "foot-l": BASE, "foot-r": BASE,
	"wing-l": Vector2(108, 206), "wing-r": Vector2(192, 206),
	"walk-body": BASE, "wing-side": Vector2(154, 208),
	"loaf-body": BASE,
	"leg-near": HIP, "leg-far": HIP,
	"head": HEAD_PIVOT,
	"tuft": Vector2(150, 60),
	"beak": Vector2(150, 154),
	"beak-low": Vector2(150, 157),
	"beak-in": Vector2(150, 156),
	"eyes": Vector2(150, 132),
	"eyes-closed": Vector2(150, 132),
}

# Two legs, stepping alternately.
const WALK_LEGS := [
	["leg-far", Vector2(182, 244), 1, false],
	["leg-near", Vector2(154, 244), 0, true],
]

var wings: Node2D              # both wings, sitting
var wing_l: Node2D
var wing_r: Node2D
var wing_side: Node2D          # the near wing, walking
var tuft: Node2D
var beak_low: Node2D
var beak_in: Node2D


func _define() -> void:
	species = "duckling"
	critter_scale = 0.44
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": Vector2(126, 196), "loaf": Vector2(150, 220)}
	tail_at = {"walk": Vector2(230, 208)}
	tail_rest_deg = {"sit": 0.0, "walk": 0.0}
	walk_legs = WALK_LEGS
	leg_len = 26.0
	stride_deg = 26.0
	leg_lift = 5.0
	hit_bounds = {
		"sit": Rect2(70, 26, 160, 246),
		"walk": Rect2(52, 26, 206, 246),
		"loaf": Rect2(64, 60, 172, 212),
	}
	sit_parts = ["body", "foot-l", "foot-r"]
	ear_parts = []
	speed_range = Vector2(35.0, 58.0)   # v2.0: 46 px/s, +/- 25%
	head_height = 55.0
	back_hip = Vector2(182, 244)


func _build_rig() -> void:
	super()
	# Wings sit on the body, under the head.
	wings = Node2D.new()
	wing_l = _pivot(PIVOTS["wing-l"], base_pt)
	wing_l.add_child(_sprite("wing-l"))
	wing_r = _pivot(PIVOTS["wing-r"], base_pt)
	wing_r.add_child(_sprite("wing-r"))
	wings.add_child(wing_l)
	wings.add_child(wing_r)
	torso_in.add_child(wings)
	torso_in.move_child(wings, body.get_index() + 1)
	wing_side = _pivot(PIVOTS["wing-side"], base_pt)
	wing_side.add_child(_sprite("wing-side"))
	torso_in.add_child(wing_side)
	torso_in.move_child(wing_side, legs_near.get_index() + 1)


func _build_head_extras() -> void:
	tuft = _pivot(PIVOTS["tuft"], HEAD_PIVOT)
	tuft.add_child(_sprite("tuft"))
	head.add_child(tuft)
	head.move_child(tuft, 0)   # behind the head's outline
	beak_in = _pivot(PIVOTS["beak-in"], HEAD_PIVOT)
	beak_in.add_child(_sprite("beak-in"))
	head.add_child(beak_in)
	beak_low = _pivot(PIVOTS["beak-low"], HEAD_PIVOT)
	beak_low.add_child(_sprite("beak-low"))
	head.add_child(beak_low)
	var top := _pivot(PIVOTS["beak"], HEAD_PIVOT)
	top.add_child(_sprite("beak"))
	head.add_child(top)


func _on_pose(p: String) -> void:
	wings.visible = p == "sit"
	wing_side.visible = p == "walk"


func _act_pose(b: String) -> String:
	match b:
		"stretch":
			return "sit"
		"peck_ground":
			return "walk"
	return super(b)


# --- Waddling and its own behaviours ------------------------------------------------

func _base_params() -> Dictionary:
	var p := super()
	p.wing_l = 0.0             # degrees, positive lifts the wing out
	p.wing_r = 0.0
	p.fluff = 0.0
	p.tuft = 0.0
	p.wing_front = false
	if pose == "walk":
		# The waddle: rock over the planted foot, tail wagging the other way.
		var moving := smoothstep(0.0, 15.0, absf(vx))
		var rock := sin(gait * TAU)
		p.torso_pivot = FEET
		p.torso_rot = 2.5 * rock * moving
		p.tail_extra = -8.0 * rock * moving
		p.head_off = p.head_off + Vector2(0.6 * rock * moving, 0)
		p.wing_r = 3.0 * absf(rock) * moving
	if twitch_left > 0.0:
		# Now and then a little wing flutter.
		var f := sin((1.0 - twitch_left / 0.25) * TAU * 2.0) * 14.0
		p.wing_l += f
		p.wing_r += f
	return p


func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"preen":
			# Head down to one side, nibbling along the wing, which lifts.
			var k := _ease_io(_env(u, act_len, 0.35))
			var nib := maxf(0.0, sin(u * TAU * 4.0))
			p.head_off = p.head_off + Vector2(18.0, 14.0 + 3.0 * nib) * k
			p.head_rot += 22.0 * k
			p.mouth = 0.5 * nib * k
			p.wing_r = 26.0 * k + 6.0 * nib * k
			p.eyes_closed = k > 0.6
			p.blink = false
		"peck_ground":
			# Tip forward and peck the ground, three quick pecks.
			var k := _ease_io(_env(u, act_len, 0.25))
			var peck := maxf(0.0, sin(u * TAU * 3.0))
			p.torso_pivot = FEET
			p.torso_rot = -18.0 * k
			p.head_off = p.head_off + Vector2(-10.0, 28.0 + 14.0 * peck) * k
			p.head_rot -= 8.0 * k
			p.mouth = 0.6 * (1.0 - peck) * k
			p.tail_extra = 12.0 * k
			p.eyes_off = Vector2(-2.0, 4.0) * k
			p.legs = "plant"
		"groom":
			# A fluff-up: feathers out, a shiver, both wings going, eyes shut.
			var k := _ease_io(_env(u, act_len, 0.3))
			var flap := absf(sin(u * TAU * 3.5)) * k
			p.fluff = k * (1.0 + 0.3 * sin(u * TAU * 9.0))
			p.wing_l = 40.0 * flap
			p.wing_r = 40.0 * flap
			p.head_off = p.head_off + Vector2(0, 4.0) * k
			p.eyes_closed = k > 0.4
			p.blink = false
			p.tuft = 18.0 * sin(u * TAU * 6.0) * k
		"stretch":
			# One wing right up and out, a lean the other way, then a yawn.
			var s := _ease_io(_env(u, act_len, 0.45))
			p.wing_r = 95.0 * s
			p.lean = p.lean - 6.0 * s
			p.head_rot -= 6.0 * s
			if s > 0.6:
				p.eyes_closed = true
				p.blink = false
				p.mouth = sin(clampf((u - 0.5) / maxf(0.1, act_len - 0.9), 0.0, 1.0) * PI)
		"scratch":
			# The wing tip up to the cheek, rubbing fast, head tilted in.
			var k := _ease_io(_env(u, act_len, 0.25))
			var buzz := sin(u * TAU * 8.0)
			p.wing_r = (128.0 + 12.0 * buzz) * k
			p.wing_front = k > 0.4
			p.head_rot += 14.0 * k
			p.head_off = p.head_off + Vector2(4.0, 4.0) * k
			p.lean = p.lean - 3.0 * k
			p.eyes_closed = k > 0.6
			p.blink = false
			p.tuft = 10.0 * buzz * k
		"ear_flick":
			# No ears: the tuft flicks instead.
			p.tuft = 30.0 * sin(u / act_len * TAU * 2.0) * (1.0 - u / act_len)
		_:
			super(p)
	if act == "shake_off":
		var w := u * TAU * 7.0
		var k := _env(u, act_len, 0.12)
		p.wing_l = 30.0 * absf(sin(w - 0.6)) * k
		p.wing_r = 30.0 * absf(sin(w - 0.6)) * k
		p.tuft = 30.0 * sin(w - 1.2) * k
	elif act == "listen":
		p.tuft = 12.0 * signf(p.head_rot)


func _apply_extras(p: Dictionary) -> void:
	# Wings lift outwards about the shoulder: the left one turns
	# clockwise, the right one anticlockwise.
	wing_l.rotation = deg_to_rad(p.wing_l)
	wing_r.rotation = deg_to_rad(-p.wing_r)
	wing_r.z_index = 1 if p.wing_front else 0   # over the cheek while scratching
	wing_side.rotation = deg_to_rad(-p.wing_r)
	tuft.rotation = deg_to_rad(p.tuft + 0.6 * p.ear_r) + ears_s * 2.0
	var open: float = p.mouth
	beak_in.visible = open > 0.02
	beak_in.scale = Vector2(1.0, open)
	beak_low.position = (PIVOTS["beak-low"] - HEAD_PIVOT + Vector2(0, 7.0 * open)) * PART_SCALE
	if p.fluff > 0.0:
		body.scale *= 1.0 + 0.12 * p.fluff
		head.scale = Vector2.ONE * (1.0 + 0.04 * p.fluff)
	else:
		head.scale = Vector2.ONE
