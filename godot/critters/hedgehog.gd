extends "res://critters/critter.gd"
## The hedgehog, in three-quarter view: a cream face tapering into a long
## upturned snout, quills from the forehead back over the whole body. It
## scurries side-on with its nose low and sniffing (v2.0's snuffle gait:
## slow, a low head bob), stops to snuffle at the ground (snuffle_pause),
## and curls into a spiky ball, face peeking out, that rolls along (ball_up).
## Its tail swish,
## having no tail to speak of, is a bristle of the spines.

const BASE := Vector2(150, 270)
const HEAD_PIVOT := Vector2(160, 196)
const HIP := Vector2(130, 246)
const BALL_AT := Vector2(150, 214)
const BALL_R := 58.0           # SVG units

const PIVOTS := {
	"spines": BASE, "body": BASE, "foot-l": BASE, "foot-r": BASE, "paws": BASE,
	"walk-body": BASE, "loaf-body": BASE,
	"leg-front": HIP, "leg-front-far": HIP, "leg-back": HIP, "leg-back-far": HIP,
	"ball": BALL_AT, "ball-face": BALL_AT,
	"groom-paws": Vector2(110, 200),
	"scratch-foot": Vector2(172, 264),
	"quills": HEAD_PIVOT,
	"ear-l": Vector2(150, 106),
	"ear-r": Vector2(176, 126),
	"head": HEAD_PIVOT,
	"nose": Vector2(60, 150),
	"eyes": Vector2(112, 128),
	"eyes-closed": Vector2(112, 128),
	"mouth-open": Vector2(89, 166),
}

const WALK_LEGS := [
	["leg-front-far", Vector2(132, 248), 1, true],
	["leg-back-far", Vector2(212, 248), 0, false],
	["leg-front", Vector2(120, 248), 0, true],
	["leg-back", Vector2(200, 248), 1, false],
]

var ball: Node2D
var ball_face: Node2D
var ball_turn := 0.0


func _define() -> void:
	species = "hedgehog"
	critter_scale = 0.43
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": Vector2(126, 214), "loaf": Vector2(156, 236), "ball": HEAD_PIVOT}
	tail_at = {}
	walk_legs = WALK_LEGS
	leg_len = 22.0
	stride_deg = 22.0
	leg_lift = 4.0
	hit_bounds = {
		"sit": Rect2(48, 70, 196, 202),
		"walk": Rect2(14, 84, 248, 188),
		"loaf": Rect2(30, 120, 232, 152),
		"ball": Rect2(86, 150, 128, 122),
	}
	sit_parts = ["spines", "body", "foot-l", "foot-r", "paws"]
	speed_range = Vector2(18.5, 31.0)   # v2.0: 38 px/s at the snuffle's 0.65, +/- 25%
	head_height = 45.0
	back_hip = Vector2(212, 248)
	scratch_hides = "foot-r"


func _build_rig() -> void:
	super()
	ball = _pivot(BALL_AT, base_pt)
	ball.add_child(_sprite("ball"))
	torso_in.add_child(ball)
	ball_face = _pivot(BALL_AT, base_pt)   # stays upright while the quills roll
	ball_face.add_child(_sprite("ball-face"))
	torso_in.add_child(ball_face)


func _build_head_extras() -> void:
	# Quills behind the face; the near ear pokes out of them at the side,
	# in front, and the far one stays tucked behind.
	var q := _sprite("quills")
	head.add_child(q)
	head.move_child(q, 0)
	head.move_child(ear_r, head.get_child_count() - 1)


func _on_pose(p: String) -> void:
	ball.visible = p == "ball"
	ball_face.visible = p == "ball"
	head.visible = p != "ball"


func _act_pose(b: String) -> String:
	match b:
		"ball_up":
			return "ball"
		"snuffle_pause":
			return "walk"
	return super(b)


func _can_hop() -> bool:
	return act != "ball_up"


# --- Scurrying, snuffling, rolling ---------------------------------------------------

func _update_motion(delta: float) -> void:
	super(delta)
	if act != "ball_up" or held:
		return
	# Roll along between curling up and uncurling; stop at the screen's edge.
	if act_t > 0.3 and act_t < act_len - 0.3:
		var d := facing * cruise * 1.2 / 0.65 * delta   # v2.0: 1.2x base speed
		var x := position.x + d
		if x > world.left_x and x < world.right_x:
			position.x = x
			ball_turn -= absf(d) / (BALL_R * px() * zoom)
		else:
			act_t = maxf(act_t, act_len - 0.3)


func _base_params() -> Dictionary:
	var p := super()
	p.bristle = 0.0
	if pose == "loaf":
		p.head_rot -= 12.0   # snout down, resting
	if pose == "walk":
		# Nose to the ground, sniffing as it goes.
		var moving := smoothstep(0.0, 8.0, absf(vx))
		p.head_off = p.head_off + Vector2(-1.5 * sin(gait * TAU), 6.0 + 2.0 * sin(gait * TAU * 2.0)) * moving
		p.nose = 0.6 * sin(t * TAU * 7.0) * moving
	return p


func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"snuffle_pause":
			# Stop and snuffle at the ground, sweeping side to side.
			var k := _ease_io(_env(u, act_len, 0.25))
			p.head_off = p.head_off + Vector2(-4.0 + 5.0 * sin(u * 3.0), 16.0) * k
			p.head_rot -= 6.0 * k
			p.nose = sin(u * TAU * 8.0) * k
			p.eyes_off = Vector2(-3.0, 4.0) * k
		"ball_up":
			# Curl up (squash in), roll, uncurl (pop back out).
			var k := _env(u, act_len, 0.3)
			p.ball_k = lerpf(0.75, 1.0, _ease_io(k))
		"tail_swish":
			# No tail to swish: the spines bristle instead.
			p.bristle = sin(u / act_len * TAU * 2.0) * (1.0 - u / act_len)
		_:
			super(p)


func _apply_extras(p: Dictionary) -> void:
	if pose == "ball":
		var k: float = p.get("ball_k", 1.0)
		ball.rotation = ball_turn
		ball.scale = Vector2(k, k)
		ball.position = (BALL_AT - base_pt + Vector2(0, (1.0 - k) * BALL_R)) * PART_SCALE
		ball_face.position = ball.position
		ball_face.scale = ball.scale
	var spines: Sprite2D = sit_sprites["spines"]
	spines.scale = Vector2.ONE * (1.0 + 0.06 * p.bristle)
