extends "res://critters/critter.gd"
## The hedgehog: sits up facing you (studio round-1 option G: heart-shaped
## face, round ears, a halo of quills, paws on its tummy) and walks side-on on
## four short legs with its face in profile, so it carries two heads: the
## front one for sitting, the side one for walking. Its walk is v2.0's
## snuffle: quick little steps with a scurry in them. Its own behaviours are
## v2.0's ball_up (rolls into a spiky ball, eyes and nose peeking out) and
## snuffle (nose down, sniffing the ground). It naps low, face tucked.
## It washes its face with both paws and rubs its cheek with one paw; its
## legs are too short to scratch an ear with a hind foot.

const BASE := Vector2(150, 270)
const HEAD_PIVOT := Vector2(150, 194)     # the neck, sitting
const SIDE_PIVOT := Vector2(110, 224)     # the neck, walking
const FRONT_HIP := Vector2(118, 246)
const BACK_HIP := Vector2(224, 246)
const BALL_AT := Vector2(154, 190)
# From the top of the sitting face (relative to its neck) to the top of the
# walking face (relative to its neck), for clothes.
const WEAR_WALK_SHIFT := Vector2(-14, 14)
const WEAR_NAP_DROP := Vector2(0, 26)          # the nap's face sits this much lower
const WEAR_SIDE_SCALE := 0.8
const WEAR_CROWN := Vector2(150, 84)            # where hats sit on the sitting face
const WEAR_NECK := Vector2(150, 194)

const PIVOTS := {
	"body": BASE, "foot-l": BASE, "foot-r": BASE, "paw-l": BASE, "paw-r": BASE,
	"ear-l": Vector2(80, 110), "ear-r": Vector2(220, 110),
	"head": HEAD_PIVOT,
	"eyes": Vector2(150, 140), "eyes-closed": Vector2(150, 140),
	"nose": Vector2(150, 158),
	"mouth-open": Vector2(150, 178),
	"groom-paws": BASE,
	"scratch-foot": Vector2(180, 214),
	"walk-body": BASE,
	"head-side": SIDE_PIVOT,
	"eye-side": Vector2(88, 180), "eye-side-closed": Vector2(88, 180),
	"leg-front": FRONT_HIP, "leg-front-far": Vector2(140, 246),
	"leg-back": BACK_HIP, "leg-back-far": Vector2(244, 246),
	"loaf-body": BASE,
	"loaf-eyes": Vector2(88, 208), "loaf-eyes-closed": Vector2(88, 208),
	"ball": BALL_AT,
}

# Four short legs, back to front, all tucked under the coat. Front-near steps
# with back-far: a trot.
const WALK_LEGS := [
	["leg-front-far", Vector2(140, 246), 1, true],
	["leg-back-far", Vector2(244, 246), 0, false],
	["leg-front", FRONT_HIP, 0, true],
	["leg-back", BACK_HIP, 1, false],
]

var front_parts: Array = []    # the sitting head's own nodes
var head_side: Node2D
var eye_side: Node2D
var eye_side_open: Sprite2D
var eye_side_shut: Sprite2D
var loaf_eyes: Node2D
var loaf_open: Sprite2D
var loaf_shut: Sprite2D
var ball: Node2D
var balled := false


func _define() -> void:
	species = "hedgehog"
	critter_scale = 0.42
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": SIDE_PIVOT, "loaf": SIDE_PIVOT}
	tail_at = {}
	walk_legs = WALK_LEGS
	leg_len = 25.0
	stride_deg = 24.0
	leg_lift = 4.0
	hit_bounds = {
		"sit": Rect2(44, 40, 212, 232),
		"walk": Rect2(29, 100, 266, 172),
		"loaf": Rect2(45, 136, 250, 136),
	}
	sit_parts = ["foot-l", "foot-r", "body", "paw-l", "paw-r"]
	scratch_hides = "paw-r"
	speed_range = Vector2(30.0, 46.0)   # v2.0: 38 px/s, +/- 20%
	head_height = 41.0
	back_hip = BACK_HIP


func _build_rig() -> void:
	super()
	# The nap's eyes ride the nap body; the ball replaces everything.
	loaf_eyes = _pivot(PIVOTS["loaf-eyes"], BASE)
	loaf_open = _sprite("loaf-eyes")
	loaf_shut = _sprite("loaf-eyes-closed")
	loaf_eyes.add_child(loaf_open)
	loaf_eyes.add_child(loaf_shut)
	body.add_child(loaf_eyes)
	ball = _pivot(BALL_AT, BASE)
	ball.add_child(_sprite("ball"))
	ball.visible = false
	torso_in.add_child(ball)


func _build_head_extras() -> void:
	# Everything on the head so far is the sitting face; the walking face is
	# its own sprite on the same head node, placed at the side neck.
	front_parts = head.get_children()
	head_side = Node2D.new()   # at the head's origin, which walking puts at SIDE_PIVOT
	head_side.add_child(_sprite("head-side"))
	eye_side = _pivot(PIVOTS["eye-side"], SIDE_PIVOT)
	eye_side_open = _sprite("eye-side")
	eye_side_shut = _sprite("eye-side-closed")
	eye_side.add_child(eye_side_open)
	eye_side.add_child(eye_side_shut)
	head_side.add_child(eye_side)
	head.add_child(head_side)


func wear(items: Array, dyes: Dictionary = {}) -> void:
	# Clothes are drawn for the sitting face. Walking, the face is in profile:
	# hats and scarves move over to it, glasses come off.
	super(items, dyes)
	if head_side == null:
		return   # not built yet
	var ids := worn.filter(func(id): return FileAccess.file_exists("res://art/wear/%s/%s.svg" % [id, species]))
	for i in mini(ids.size(), _wear_nodes.size()):
		_wear_nodes[i].set_meta("slot", Wear.slot(ids[i]))
		_wear_nodes[i].set_meta("at", _wear_nodes[i].position)
	_on_pose(pose)   # the base shows every ear again; the walking pose has none


func _place_wear() -> void:
	# Napping, the face is the nap body's own, lower and further forward; the
	# head node stays up (empty) so the clothes ride along with it.
	var shift := Vector2.ZERO
	if pose == "walk":
		shift = WEAR_WALK_SHIFT
	elif pose == "loaf":
		shift = WEAR_WALK_SHIFT + WEAR_NAP_DROP
	# The side-on head is smaller than the face-on one: clothes shrink a little
	# about where they sit (the crown for hats, the chin for neckwear).
	var k := 1.0 if pose == "sit" else WEAR_SIDE_SCALE
	for n in _wear_nodes:
		if not n.has_meta("at"):
			continue
		var anchor: Vector2 = WEAR_NECK if n.get_meta("slot") == "neck" else WEAR_CROWN
		var tex := (anchor + Vector2(0, WEAR_HEADROOM)) * PART_SCALE   # the anchor, in the sprite
		var at: Vector2 = n.get_meta("at")
		n.scale = Vector2.ONE * k
		n.position = at + tex * (1.0 - k) + shift * PART_SCALE
		n.visible = not (pose != "sit" and n.get_meta("slot") == "face")


func _on_pose(p: String) -> void:
	_place_wear()
	var hood := false
	for id in worn:
		hood = hood or "ears" in Wear.hides(id, species)
	for n in front_parts:
		n.visible = p == "sit" and not (hood and n in ears)
	head_side.visible = p == "walk"
	loaf_eyes.visible = p == "loaf"


func _act_pose(b: String) -> String:
	return "walk" if b in ["stretch", "snuffle"] else "sit"


func _on_begin(b: String) -> void:
	super(b)
	if b == "ball_up":
		_kick_squash(-1.6)


func _can_hop() -> bool:
	return act != "ball_up"


func _gait_speed() -> float:
	# The snuffle: a scurry in every step. Averages 1 over a cycle.
	return 1.0 + 0.3 * sin(gait * TAU * 2.0)


# --- Its own behaviours ------------------------------------------------------------

func _base_params() -> Dictionary:
	var p := super()
	p.ball = 0.0
	return p


func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"ball_up":
			# Curl into a ball, rock on the spot, then pop open again.
			p.ball = _env(u, act_len, 0.18)
		"snuffle":
			# Nose down to the ground, sniffing in quick little bobs.
			var k := _ease_io(_env(u, act_len, 0.3))
			var sniff := sin(u * TAU * 6.0)
			p.torso_pivot = FRONT_HIP
			p.torso_rot = -7.0 * k
			p.head_off = p.head_off + Vector2(-3.0, 7.0 + 1.6 * sniff) * k
			p.head_rot -= (9.0 + 1.5 * sniff) * k
			p.legs = "plant"
			p.leg_front = 1.0
			p.leg_back = 0.0
		"scratch":
			# A gentler tilt than the shared scratch: the face mask is wide and
			# would swing out past its quills.
			super(p)
			var up := _ease_io(_env(u, act_len, 0.25))
			p.head_rot -= 9.0 * up
			p.head_off = p.head_off - Vector2(3.0, 2.0) * up
		_:
			super(p)


func _apply_extras(p: Dictionary) -> void:
	# The walking and napping faces blink with the sitting one. Their eye
	# nodes sit on the eye, so squashing the node closes the eye in place.
	eye_side_open.visible = eyes_open.visible
	eye_side_shut.visible = eyes_shut.visible
	eye_side.scale = eyes.scale
	loaf_open.visible = eyes_open.visible
	loaf_shut.visible = eyes_shut.visible
	loaf_eyes.scale = eyes.scale
	if pose != "sit":
		mouth_open.visible = false
	# Washing or rubbing a cheek: the paws on its tummy go up to the face.
	sit_sprites["paw-l"].visible = not groom_paws.visible
	if groom_paws.visible:
		sit_sprites["paw-r"].visible = false
	# Balled up: only the ball shows, rocking and squashing.
	var in_ball: bool = p.ball > 0.5
	if in_ball != balled:
		balled = in_ball
		_kick_squash(-1.2)
	ball.visible = in_ball
	body.visible = not in_ball
	head.visible = not in_ball
	legs_node.visible = not in_ball and pose == "walk"
	if in_ball:
		var rock := sin(act_t * TAU * 0.9) * 9.0 * clampf((p.ball - 0.5) * 2.0, 0.0, 1.0)
		ball.rotation = deg_to_rad(rock)
		ball.scale = Vector2(1.0 + 0.04 * p.breath, 1.0 - 0.03 * p.breath)
