extends "res://critters/critter.gd"
## The rabbit: travels in hops (v2.0's hop gait: an arc, then a short pause
## on the ground), sits up on its hind legs to keep a lookout, washes its
## face with both front paws, and twitches its nose. Naps as a round loaf
## with its ears laid down.
##
## The hop runs on time, not distance: each hop is HOP_CYCLE seconds, most of
## it in the air. The body pitches nose-up on take-off and nose-down to land,
## stretches as it leaves the ground and squashes as it lands, with the hind
## feet kicking back and the front paws reaching for the landing.

const BASE := Vector2(150, 270)
const HEAD_PIVOT := Vector2(150, 196)
const HIND_HIP := Vector2(204, 228)
const FORE_HIP := Vector2(128, 228)
const BODY_MID := Vector2(172, 214)    # the body pitches about this in a hop

const PIVOTS := {
	"tail": Vector2(194, 238),
	"body": BASE, "foot-l": BASE, "foot-r": BASE, "paws": BASE,
	"walk-body": BASE,
	"leg-back": HIND_HIP, "leg-back-far": HIND_HIP,
	"leg-front": FORE_HIP, "leg-front-far": FORE_HIP,
	"loaf-body": BASE, "loaf-paws": BASE,
	"stand-body": BASE, "stand-feet": BASE,
	"groom-paws": Vector2(150, 200),
	"scratch-foot": Vector2(194, 252),
	"ear-l": Vector2(126, 90),
	"ear-r": Vector2(174, 90),
	"head": HEAD_PIVOT,
	"nose": Vector2(150, 160),
	"eyes": Vector2(150, 142),
	"eyes-closed": Vector2(150, 142),
	"mouth-open": Vector2(150, 170),
}

# Back to front; the near hind leg (its haunch) is drawn over the body.
const WALK_LEGS := [
	["leg-back-far", Vector2(214, 228), 0, false],
	["leg-front-far", Vector2(136, 228), 0, true],
	["leg-front", Vector2(124, 228), 0, true],
	["leg-back", Vector2(200, 228), 0, false, true],
]

# v2.0 _hop: a 0.8 s cycle, 0.5 s of it an arc, then a pause on the ground.
const HOP_CYCLE := 0.8
const ARC := 0.625             # share of the cycle in the air
const ARC_SPEED := 1.55        # body speed in the air, as a share of cruising speed
const HOLD_SPEED := 0.08       # creeping forward between hops (averages 1 with the arc)
const HOP_HEIGHT := 20.0       # px at full speed

var loaf_paws: Node2D
var hop_k := 1.0               # this hop's size: smaller when slowing down


func _define() -> void:
	species = "rabbit"
	critter_scale = 0.45
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": Vector2(120, 206), "loaf": Vector2(150, 226), "stand": Vector2(150, 150)}
	tail_at = {"sit": Vector2(194, 238), "walk": Vector2(236, 198), "stand": Vector2(190, 242)}
	tail_rest_deg = {"sit": 0.0, "walk": 0.0}
	walk_legs = WALK_LEGS
	leg_len = 42.0
	stride_deg = 16.0
	leg_lift = 6.0
	hit_bounds = {
		"sit": Rect2(70, 6, 160, 266),
		"walk": Rect2(40, 16, 228, 256),
		"loaf": Rect2(56, 100, 188, 172),
		"stand": Rect2(70, -40, 160, 312),
	}
	sit_parts = ["body", "foot-l", "foot-r", "paws"]
	speed_range = Vector2(43.0, 81.0)   # v2.0: 62 px/s, +/- 30%
	head_height = 50.0
	back_hip = HIND_HIP
	scratch_hides = "foot-r"


func _build_rig() -> void:
	super()
	loaf_paws = _sprite("loaf-paws")
	torso_in.add_child(loaf_paws)


func _on_pose(p: String) -> void:
	loaf_paws.visible = p == "loaf"


# --- Hopping -----------------------------------------------------------------------

func _advance_gait(delta: float) -> void:
	# Time, not distance: a hop in the air always finishes; a new one starts
	# only while the rabbit means to keep moving.
	var moving := absf(vx) > 6.0 * zoom
	var was := gait
	if gait < ARC or moving:
		gait += delta / HOP_CYCLE
		if gait >= 1.0:
			gait -= 1.0
	if was >= ARC and gait < ARC:
		hop_k = clampf(absf(vx) / maxf(cruise, 1.0), 0.4, 1.0)
		_kick_squash(1.4 * hop_k)        # stretch leaving the ground
	elif was < ARC and gait >= ARC:
		_kick_squash(-1.9 * hop_k)       # squash on landing
	if gait < ARC:
		var u := gait / ARC
		lift = HOP_HEIGHT * zoom * hop_k * 4.0 * u * (1.0 - u)
	else:
		lift = 0.0


func _gait_speed() -> float:
	return ARC_SPEED if gait < ARC else HOLD_SPEED


func _settled() -> bool:
	# Never stop, sit or turn in mid-air.
	return pose != "walk" or gait >= ARC


func _base_params() -> Dictionary:
	var p := super()
	if pose == "walk" and gait < ARC:
		var u := gait / ARC
		p.torso_pivot = BODY_MID
		p.torso_rot = 10.0 * cos(PI * u) * hop_k          # nose up, then nose down
		p.head_off = p.head_off + Vector2(0, 3.0 * cos(PI * u) * hop_k)   # a beat behind
		var back := 6.0 + 12.0 * sin(PI * u) * hop_k        # ears stream back
		p.ear_l += back
		p.ear_r += back
	elif pose == "walk" and absf(vx) > 6.0 * zoom:
		# Gathering for the next hop: a small crouch.
		var h := (gait - ARC) / (1.0 - ARC)
		p.torso_dy = 4.0 * smoothstep(0.5, 1.0, h)
	if pose == "loaf":
		# Asleep with the ears laid down either side.
		p.ear_l -= 100.0
		p.ear_r += 100.0
	# Rabbits' noses are never still for long.
	p.nose = 0.6 * sin(t * TAU * 6.0) * pow(maxf(0.0, sin(t * 0.8 + phase)), 10.0)
	return p


func _apply_legs(p: Dictionary) -> void:
	if p.legs != "gait":
		super(p)
		return
	var hind := 0.0
	var front := 0.0
	if gait < ARC:
		var u := gait / ARC
		hind = _keys(u, [[0.0, 0.0], [0.22, -42.0], [0.7, 18.0], [1.0, 6.0]]) * hop_k
		front = _keys(u, [[0.0, 0.0], [0.25, -28.0], [0.72, 34.0], [1.0, 4.0]]) * hop_k
	else:
		var h := 1.0 - smoothstep(0.0, 0.35, (gait - ARC) / (1.0 - ARC))
		hind = 6.0 * h * hop_k
		front = 4.0 * h * hop_k
	for leg in legs:
		var node: Node2D = leg.node
		node.position = (leg.hip - base_pt) * PART_SCALE
		# The far pair trails a touch, so the two sides do not move as one.
		var a: float = front if leg.front else hind
		if node.get_parent() == legs_node:
			a *= 0.85
		node.rotation = deg_to_rad(a)


func _keys(u: float, keys: Array) -> float:
	# Eased steps between [time, value] keys.
	for i in range(1, keys.size()):
		if u <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(a[1], b[1], _ease_io((u - a[0]) / (b[0] - a[0])))
	return keys[-1][1]
