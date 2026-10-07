extends "res://critters/critter.gd"
## The panda (studio round 3, option 1: classic, rounder). Sits facing you,
## pink paw pads out; walks side-on with its round face turned to you, a
## little smaller (one head, as the kitten). Its walk is v2.0's lumber: slow,
## heavy, swaying from side to side. Its own behaviour is v2.0's panda_roll:
## it tips over and rolls right round. Naps flat on its tummy.

const BASE := Vector2(150, 270)
const HEAD_PIVOT := Vector2(150, 181)
const WALK_HEAD := Vector2(102, 196)
const NAP_HEAD := Vector2(98, 222)
const HEAD_SMALL := 0.78                  # the face-on head on the side-on body
const BACK_HIP := Vector2(219, 244)
const ROLL_AT := Vector2(150, 200)

const PIVOTS := {
	"body": BASE, "foot-l": BASE, "foot-r": BASE,
	"ear-l": Vector2(102, 86), "ear-r": Vector2(198, 86),
	"head": HEAD_PIVOT,
	"eyes": Vector2(150, 126.9), "eyes-closed": Vector2(150, 126.9),
	"mouth-open": Vector2(150, 166),
	"groom-paws": BASE,
	"walk-body": BASE, "loaf-body": BASE,
	"leg-front": Vector2(137, 240), "leg-front-far": Vector2(159, 224),
	"leg-back": Vector2(217, 240), "leg-back-far": Vector2(237, 224),
}

const WALK_LEGS := [
	["leg-front-far", Vector2(159, 224), 1, true],
	["leg-back-far", Vector2(237, 224), 0, false],
	["leg-front", Vector2(137, 240), 0, true],
	["leg-back", Vector2(217, 240), 1, false],
]


func _define() -> void:
	species = "panda"
	critter_scale = 0.46
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": WALK_HEAD, "loaf": NAP_HEAD}
	tail_at = {}
	walk_legs = WALK_LEGS
	leg_len = 30.0
	stride_deg = 16.0
	leg_lift = 4.0
	hit_bounds = {
		"sit": Rect2(60, 62, 180, 210),
		"walk": Rect2(44, 98, 226, 174),
		"loaf": Rect2(40, 150, 236, 122),
	}
	sit_parts = ["body", "foot-l", "foot-r"]
	speed_range = Vector2(27.0, 41.0)   # v2.0: 34 px/s, +/- 20%
	head_height = 52.0
	back_hip = BACK_HIP


func _act_pose(b: String) -> String:
	return "walk" if b == "stretch" else "sit"


func _can_hop() -> bool:
	return act != "panda_roll"


func _base_params() -> Dictionary:
	var p := super()
	if pose == "walk":
		# The lumber: a heavy sway over each planted foot, head rolling with it.
		var moving := smoothstep(0.0, 12.0, absf(vx))
		var sway := sin(gait * TAU)
		p.torso_rot += 2.2 * sway * moving
		p.head_rot += -3.0 * sway * moving
	return p


func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"panda_roll":
			# Tip over and roll right round, squashing as it lands.
			var k := _ease_io(clampf((u - 0.2) / maxf(0.1, act_len - 0.5), 0.0, 1.0))
			p.torso_pivot = ROLL_AT
			p.torso_rot = -360.0 * k
			p.torso_dy -= 10.0 * sin(k * PI)
			p.eyes_closed = k > 0.05 and k < 0.95
			p.blink = false
		_:
			super(p)


func _apply_extras(_p: Dictionary) -> void:
	head.scale = Vector2.ONE * (1.0 if pose == "sit" else HEAD_SMALL)
	if pose != "sit" and mouth_open != null:
		mouth_open.visible = false
