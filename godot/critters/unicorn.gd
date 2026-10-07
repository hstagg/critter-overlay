extends "res://critters/two_head.gd"
## The unicorn: a special visitor, Legendary only (studio round 2, option 1,
## the curly foal). Sits facing you; walks side-on with its head in profile
## (two_head.gd), mane down its neck and a curly striped tail on a spring.
## It comes in seven colours, each a secret tier within Legendary: the colour
## is picked on arrival by VARIANTS' weights (commonest first) and its art
## comes from art/unicorn/<variant>/. Its walk is v2.0's smooth glide with a
## little prance in it; its own behaviour is a prance (a happy rear and hop).
## Naps lying down, legs folded.

const BASE := Vector2(150, 270)
const HEAD_PIVOT := Vector2(150, 183)
const SIDE_PIVOT := Vector2(116.5, 185)
const TAIL_SIT := Vector2(182, 212)
const TAIL_WALK := Vector2(221.5, 200.4)
const BACK_HIP := Vector2(203.7, 227.6)

# Secret tiers within Legendary: [variant, weight]. Kept off every screen.
const VARIANTS := [
	["lavender", 35.0], ["cotton_candy", 22.0], ["sky", 15.0], ["rainbow", 11.0],
	["golden_sun", 8.0], ["starry_night", 6.0], ["twilight_neon", 3.0],
]

const PIVOTS := {
	"tail": TAIL_SIT,
	"tail-side": TAIL_WALK,
	"body": BASE,
	"head": HEAD_PIVOT,
	"eyes": Vector2(150, 132.2), "eyes-closed": Vector2(150, 132.2),
	"mouth-open": Vector2(150, 167.5),
	"walk-body": BASE, "loaf-body": BASE,
	"head-side": SIDE_PIVOT,
	"eye-side": Vector2(86, 151.1), "eye-side-closed": Vector2(86, 151.1),
	"leg-front": Vector2(147, 227.6), "leg-front-far": Vector2(159, 218),
	"leg-back": BACK_HIP, "leg-back-far": Vector2(215.7, 218),
}

const WALK_LEGS := [
	["leg-front-far", Vector2(159, 218), 1, true],
	["leg-back-far", Vector2(215.7, 218), 0, false],
	["leg-front", Vector2(147, 227.6), 0, true],
	["leg-back", BACK_HIP, 1, false],
]

static var _variant_textures := {}   # variant -> part -> texture

var variant := "lavender"
var tail_side: Node2D


static func pick_variant() -> String:
	var total := 0.0
	for v in VARIANTS:
		total += v[1]
	var r := randf() * total
	for v in VARIANTS:
		r -= v[1]
		if r <= 0.0:
			return v[0]
	return VARIANTS[0][0]


func _define() -> void:
	species = "unicorn"
	if variant == "lavender" and not has_meta("variant_set"):
		variant = pick_variant()
	critter_scale = 0.44
	base_pt = BASE
	ground_y = BASE.y
	head_pivot = HEAD_PIVOT
	side_pivot = SIDE_PIVOT
	side_in_loaf = true
	pivots = PIVOTS
	head_at = {"sit": HEAD_PIVOT, "walk": SIDE_PIVOT, "loaf": SIDE_PIVOT + Vector2(0, 18)}
	tail_at = {"sit": TAIL_SIT}
	walk_legs = WALK_LEGS
	leg_len = 42.0
	stride_deg = 20.0
	leg_lift = 7.0
	hit_bounds = {
		"sit": Rect2(54, 34, 196, 238),
		"walk": Rect2(36, 66, 250, 206),
		"loaf": Rect2(36, 90, 250, 182),
	}
	sit_parts = ["body"]
	ear_parts = []
	speed_range = Vector2(42.0, 58.0)   # v2.0: 50 px/s
	head_height = 64.0
	back_hip = BACK_HIP
	wear_crown = Vector2(150, 74)
	wear_neck = Vector2(150, 186)
	wear_walk_shift = Vector2(-22.5, 32)
	wear_nap_shift = Vector2(-22.5, 50)


func set_variant(v: String) -> void:
	# Before setup(): a chosen colour (a demo, or a saved visitor).
	variant = v
	set_meta("variant_set", true)


func _load_textures() -> void:
	if _variant_textures.has(variant):
		return
	var tex := {}
	for part in pivots.keys():
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://art/unicorn/%s/%s.svg" % [variant, part]), PART_SCALE)
		img.generate_mipmaps()
		tex[part] = ImageTexture.create_from_image(img)
	_variant_textures[variant] = tex


func _sprite(part: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _variant_textures[variant][part]
	s.centered = false
	s.position = -pivots[part] * PART_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprites.append(s)
	return s


func _build_rig() -> void:
	super()
	tail_side = _pivot(TAIL_WALK, BASE)
	tail_side.add_child(_sprite("tail-side"))
	torso_in.add_child(tail_side)
	torso_in.move_child(tail_side, 0)


func _on_pose(p: String) -> void:
	super(p)
	if tail_side != null:
		tail_side.visible = p == "walk" or p == "loaf"


func _act_pose(b: String) -> String:
	return "walk" if b in ["stretch", "prance"] else "sit"


func _on_begin(b: String) -> void:
	super(b)
	if b == "prance" and not airborne:
		_launch(-360.0 * zoom)


func _base_params() -> Dictionary:
	var p := super()
	if pose == "walk":
		# A light, bouncy step: the body rises a touch at each stride.
		var moving := smoothstep(0.0, 12.0, absf(vx))
		p.torso_dy -= 2.0 * absf(sin(gait * TAU * 2.0)) * moving
	return p


func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"prance":
			# Rear up on the hind legs and hop, mane and tail flying.
			var k := _env(u, act_len, 0.25)
			p.torso_pivot = back_hip
			p.torso_rot = 16.0 * k
			p.legs = "plant"
			p.leg_front = -1.0
			p.leg_back = 0.0
			p.tail_extra += 18.0 * k
			p.eyes_closed = k > 0.5
			p.blink = false
		_:
			super(p)


func _apply_extras(p: Dictionary) -> void:
	super(p)
	if tail_side != null and tail_side.visible:
		tail_side.rotation = deg_to_rad(p.tail_rot + p.tail_extra) * 0.6 + tail_s
