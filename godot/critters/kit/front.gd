extends "res://critters/two_head.gd"
## A homemade critter that sits facing you and walks side-on, like the otter
## (docs/custom-critters-build-plan.md, 4.2). two_head.gd carries its two
## faces and moves its clothes between them (P15); its shape comes from its
## kit (kit_data.gd), its walk from gaits.gd.
##
## What it does beyond two_head.gd:
## - One face is enough: with no head-side, the front face stays on while it
##   walks, as the panda's does. two_head.gd assumes the side face, and the
##   closed eyes, are always drawn; the overrides here don't.
## - Napping not drawn: the sitting body melted onto the ground (P3).
## - head-front, back-extra, front-extra and wing, as side.gd.

const Customs := preload("res://customs.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const Gaits := preload("res://critters/kit/gaits.gd")

var kit := {}                  # kit_data.gd rig()
var gs := {}                   # gaits.gd state()
var head_front: Sprite2D
var back_extra: Sprite2D
var front_extra: Sprite2D
var wing: Node2D


func _define() -> void:
	var d: Dictionary = Customs.all.get(species, {})
	kit = KitData.rig(Customs.tex_key(species), str(d.get("_dir", "")), d.get("_kit", {}),
		float(d.get("size", 1.0)), float(d.get("speed", 1.0)))
	KitData.apply(self, kit)
	side_pivot = kit.side_pivot
	wear_neck = kit.wear_neck
	wear_crown = kit.wear_neck - Vector2(0, 100)
	wear_walk_shift = kit.wear_walk_shift
	wear_nap_shift = kit.wear_nap_shift
	gs = Gaits.state(kit.gait, kit.mid, kit.feet)


func body_centre_px() -> float:
	return kit.body_centre_px


func head_top_px() -> float:
	return kit.head_top_px


func _load_textures() -> void:
	var key := art_key()
	if _textures.has(key):
		return
	var tex := {}
	for part in kit.images:
		var img: Image = kit.images[part].duplicate()
		img.generate_mipmaps()
		tex[part] = ImageTexture.create_from_image(img)
	_textures[key] = tex


# --- Rig -----------------------------------------------------------------------------

func _build_rig() -> void:
	super()
	if _has("back-extra"):
		back_extra = _sprite("back-extra")
		body.add_child(back_extra)
		body.move_child(back_extra, 0)
	if _has("front-extra"):
		front_extra = _sprite("front-extra")
		body.add_child(front_extra)
	if _has("wing"):
		wing = _pivot(pivots["wing"], base_pt)
		wing.add_child(_sprite("wing"))
		body.add_child(wing)


func _build_head_extras() -> void:
	# two_head.gd's, with the side face and each closed eye optional.
	if _has("head-front"):
		head_front = _sprite("head-front")
		head.add_child(head_front)
	front_parts = head.get_children()
	if not _has("head-side"):
		return
	head_side = Node2D.new()
	head_side.add_child(_sprite("head-side"))
	if _has("eye-side"):
		eye_side = _pivot(pivots["eye-side"], side_pivot)
		eye_side_open = _sprite("eye-side")
		eye_side.add_child(eye_side_open)
		if _has("eye-side-closed"):
			eye_side_shut = _sprite("eye-side-closed")
			eye_side.add_child(eye_side_shut)
		head_side.add_child(eye_side)
	head.add_child(head_side)


func _on_pose(p: String) -> void:
	# two_head.gd's, keeping the front face on while walking when there is
	# no side face.
	_place_wear()
	var hood := false
	for id in worn:
		hood = hood or "ears" in Wear.hides(id, species)
	var front_on := _sit_like(p) or head_side == null
	for n in front_parts:
		n.visible = front_on and not (hood and n in ears)
	if head_side != null:
		head_side.visible = p == "walk" or (p == "loaf" and side_in_loaf)
	if loaf_eyes != null:
		loaf_eyes.visible = p == "loaf"
	for n in [back_extra, front_extra, wing]:
		if n != null:
			n.visible = p == "walk"


func _apply_extras(p: Dictionary) -> void:
	# two_head.gd's, where a closed eye may not be drawn: then the open one
	# squashes, which critter.gd already does to the front eyes.
	if eye_side != null:
		var shut: bool = eyes_shut != null and eyes_shut.visible and eye_side_shut != null
		eye_side_open.visible = not shut
		if eye_side_shut != null:
			eye_side_shut.visible = shut
		eye_side.scale = eyes.scale
	if loaf_eyes != null:
		var lshut: bool = eyes_shut != null and eyes_shut.visible
		loaf_open.visible = not lshut
		loaf_shut.visible = lshut
		loaf_eyes.scale = eyes.scale
	if mouth_open != null and not _sit_like(pose):
		mouth_open.visible = false
	# otter.gd:154-160: sliding on its belly, legs tucked up.
	for leg in legs:
		if p.legs == "tuck":
			leg.node.rotation = deg_to_rad(60.0 if leg.front else -60.0)
			leg.node.scale = Vector2(1.0, 0.5)
		else:
			leg.node.scale = Vector2.ONE
	if wing != null:
		var f := 0.0
		match act:
			"fly":
				f = 25.0 * sin(t * TAU * 4.0)
			"shake_off":
				f = 15.0 * sin(t * TAU * 6.0)
		if airborne or lift > 0.5:
			f -= 20.0
		wing.rotation = deg_to_rad(f)


# --- The walk (as side.gd) --------------------------------------------------------------

func tick(delta: float) -> void:
	Gaits.tick(self, gs, delta)
	super(delta)


func _advance_gait(delta: float) -> void:
	if not Gaits.advance(self, gs, delta):
		super(delta)


func _gait_speed() -> float:
	return Gaits.speed(self, gs)


func _settled() -> bool:
	return Gaits.settled(self, gs)


func _base_params() -> Dictionary:
	var p := super()
	Gaits.params(self, gs, p)
	return p


func _act_pose(b: String) -> String:
	# The otter's: stretching is done walking, the rest sitting up.
	if b == "stand_lookout":
		return super(b)
	return "walk" if b == "stretch" else "sit"
