extends "res://critters/two_head.gd"
## The turtle (studio round 2, option 1: classic green dome, big round head).
## Sits facing you with its feet out either side of the shell and walks
## side-on with its head in profile on a reaching neck (two_head.gd). Its
## walk is v2.0's plod: slow, short heavy steps. Its own behaviour is v2.0's
## head_tuck: head and legs pull into the shell, a pause, then it peeks out.
## It naps resting on its shell, head down on the ground.

const BASE := Vector2(162, 270)
const HEAD_PIVOT := Vector2(162, 230)    # the neck, sitting
const SIDE_PIVOT := Vector2(106, 220)    # the neck, walking: the front of the shell
const BACK_HIP := Vector2(237.5, 224)

const PIVOTS := {
	"body": BASE, "foot-l": BASE, "foot-r": BASE,
	"head": HEAD_PIVOT,
	"eyes": Vector2(162, 181.4), "eyes-closed": Vector2(162, 181.4),
	"mouth-open": Vector2(162, 210),
	"walk-body": BASE, "loaf-body": BASE,
	"head-side": SIDE_PIVOT,
	"eye-side": Vector2(49.4, 179.8), "eye-side-closed": Vector2(49.4, 179.8),
	"leg-front": Vector2(118.5, 224), "leg-back": BACK_HIP,
	"leg-front-far": Vector2(132.5, 220), "leg-back-far": Vector2(249.5, 220),
}

const WALK_LEGS := [
	["leg-front-far", Vector2(132.5, 220), 1, true],
	["leg-back-far", Vector2(249.5, 220), 0, false],
	["leg-front", Vector2(118.5, 224), 0, true],
	["leg-back", BACK_HIP, 1, false],
]


func _define() -> void:
	species = "turtle"
	critter_scale = 0.45
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	side_pivot = SIDE_PIVOT
	side_in_loaf = true
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": SIDE_PIVOT, "loaf": SIDE_PIVOT + Vector2(0, 26)}
	tail_at = {}
	walk_legs = WALK_LEGS
	leg_len = 46.0
	stride_deg = 14.0
	leg_lift = 4.0
	hit_bounds = {
		"sit": Rect2(46, 110, 232, 162),
		"walk": Rect2(0, 122, 300, 150),
		"loaf": Rect2(0, 150, 300, 122),
	}
	sit_parts = ["body", "foot-l", "foot-r"]
	ear_parts = []
	speed_range = Vector2(22.0, 34.0)   # v2.0: 28 px/s, +/- 20%
	head_height = 30.0
	back_hip = BACK_HIP
	wear_crown = Vector2(162, 136)
	wear_neck = Vector2(162, 232)
	wear_walk_shift = Vector2(-42, 10)
	wear_nap_shift = Vector2(-42, 36)


func _act_pose(b: String) -> String:
	return "walk" if b == "stretch" else "sit"


func _can_hop() -> bool:
	return act != "head_tuck"


func _gait_speed() -> float:
	# The plod: a push on each step, a near stop between. Averages 1.
	return 1.0 + 0.45 * sin(gait * TAU * 2.0)


func _base_params() -> Dictionary:
	var p := super()
	p.tuck = 0.0
	if pose == "loaf":
		p.head_rot -= 6.0          # chin down on the ground
	if pose == "walk":
		# A heavy sway from foot to foot.
		var moving := smoothstep(0.0, 10.0, absf(vx))
		p.torso_rot += 1.2 * sin(gait * TAU) * moving
	return p


func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"head_tuck":
			# Pull in quickly, stay hidden, then peek out slowly, eyes first.
			var into := _ease_io(clampf(u / 0.35, 0.0, 1.0))
			var out := _ease_io(clampf((u - (act_len - 0.9)) / 0.9, 0.0, 1.0))
			p.tuck = into * (1.0 - out)
			p.torso_dy += 5.0 * p.tuck
			p.blink = false
			p.eyes_closed = p.tuck > 0.2 and p.tuck < 0.95
		"stretch":
			super(p)
			# A long neck stretch forwards rather than a bow.
			var s := _ease_io(_env(u, act_len, 0.45))
			p.torso_rot = -4.0 * s
			p.head_off = p.head_off + Vector2(-14.0, -6.0) * s
		_:
			super(p)


func _apply_extras(p: Dictionary) -> void:
	super(p)
	# Tucked in: the head shrinks back into the neck pivot (the front of the
	# shell), the feet pull up under the rim.
	var t: float = p.get("tuck", 0.0)
	var k := 1.0 - 0.85 * t
	head.scale = Vector2(k, k)
	if t > 0.0:
		var pull := Vector2(16.0, 4.0) if pose == "walk" else Vector2(0, 10.0)
		head.position += pull * t * PART_SCALE
	head.visible = t < 0.9
	var feet := 1.0 - 0.7 * t
	for part in ["foot-l", "foot-r"]:
		sit_sprites[part].scale = Vector2(1.0, feet)
		# squash about the top of the leg (y 230), not the top of the frame
		sit_sprites[part].position.y = (-pivots[part].y + 230.0 * (1.0 - feet)) * PART_SCALE
	for leg in legs:
		leg.node.scale = Vector2(1.0, feet)
