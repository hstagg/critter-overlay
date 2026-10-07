extends "res://critters/critter.gd"
## A critter that sits facing you and walks side-on with its face in profile
## (or three-quarter), so it carries two heads on one head node: the front
## one (critter.gd's head, eyes, ears, mouth, nose) for sitting and the side
## one ("head-side" plus "eye-side" and "eye-side-closed") for walking.
## The hedgehog was built first and keeps its own copy of this; the turtle,
## squirrel, otter and unicorn extend this file.
##
## Parts it adds when the species has them:
##   head-side, eye-side, eye-side-closed   the walking face, about side_pivot
##   loaf-eyes, loaf-eyes-closed            eyes for a nap body drawn without them
## Clothes are drawn for the sitting face; walking and napping they move to
## the other face (wear_walk_shift, wear_nap_shift) and shrink a little,
## and glasses come off.

var side_pivot := Vector2(110, 224)        # the walking head's neck, SVG units
var side_in_loaf := false                  # the nap uses the walking face
var wear_walk_shift := Vector2.ZERO
var wear_nap_shift := Vector2.ZERO
var wear_side_scale := 0.8
var wear_crown := Vector2(150, 84)         # where hats sit on the sitting face
var wear_neck := Vector2(150, 194)

var front_parts: Array = []
var head_side: Node2D
var eye_side: Node2D
var eye_side_open: Sprite2D
var eye_side_shut: Sprite2D
var loaf_eyes: Node2D
var loaf_open: Sprite2D
var loaf_shut: Sprite2D


func _build_rig() -> void:
	super()
	if _has("loaf-eyes"):
		loaf_eyes = _pivot(pivots["loaf-eyes"], base_pt)
		loaf_open = _sprite("loaf-eyes")
		loaf_shut = _sprite("loaf-eyes-closed")
		loaf_eyes.add_child(loaf_open)
		loaf_eyes.add_child(loaf_shut)
		body.add_child(loaf_eyes)


func _build_head_extras() -> void:
	front_parts = head.get_children()
	head_side = Node2D.new()   # at the head's origin, which walking puts at side_pivot
	head_side.add_child(_sprite("head-side"))
	if _has("eye-side"):
		eye_side = _pivot(pivots["eye-side"], side_pivot)
		eye_side_open = _sprite("eye-side")
		eye_side_shut = _sprite("eye-side-closed")
		eye_side.add_child(eye_side_open)
		eye_side.add_child(eye_side_shut)
		head_side.add_child(eye_side)
	head.add_child(head_side)
	_build_side_extras()


func _build_side_extras() -> void:
	pass   # a species' own parts on the walking head


func wear(items: Array, dyes: Dictionary = {}) -> void:
	super(items, dyes)
	if head_side == null:
		return   # not built yet
	var ids := worn.filter(func(id): return FileAccess.file_exists("res://art/wear/%s/%s.svg" % [id, species]))
	for i in mini(ids.size(), _wear_nodes.size()):
		_wear_nodes[i].set_meta("slot", Wear.slot(ids[i]))
		_wear_nodes[i].set_meta("at", _wear_nodes[i].position)
	_on_pose(pose)   # the base shows every ear again; the walking pose has none


func _place_wear() -> void:
	var shift := Vector2.ZERO
	if pose == "walk":
		shift = wear_walk_shift
	elif pose == "loaf":
		shift = wear_nap_shift
	var k := 1.0 if pose == "sit" else wear_side_scale
	for n in _wear_nodes:
		if not n.has_meta("at"):
			continue
		var anchor: Vector2 = wear_neck if n.get_meta("slot") == "neck" else wear_crown
		var tex := (anchor + Vector2(0, WEAR_HEADROOM)) * PART_SCALE
		n.scale = Vector2.ONE * k
		n.position = n.get_meta("at") + tex * (1.0 - k) + shift * PART_SCALE
		n.visible = not (pose != "sit" and n.get_meta("slot") == "face")


func _sit_like(p: String) -> bool:
	# Poses that show the front face.
	return p == "sit" or p == "stand"


func _on_pose(p: String) -> void:
	_place_wear()
	var hood := false
	for id in worn:
		hood = hood or "ears" in Wear.hides(id, species)
	for n in front_parts:
		n.visible = _sit_like(p) and not (hood and n in ears)
	head_side.visible = p == "walk" or (p == "loaf" and side_in_loaf)
	if loaf_eyes != null:
		loaf_eyes.visible = p == "loaf"


func _apply_extras(p: Dictionary) -> void:
	# The other faces blink with the sitting one; their eye nodes sit on the
	# eye, so squashing the node closes the eye in place.
	if eye_side != null:
		eye_side_open.visible = eyes_open.visible
		eye_side_shut.visible = eyes_shut.visible
		eye_side.scale = eyes.scale
	if loaf_eyes != null:
		loaf_open.visible = eyes_open.visible
		loaf_shut.visible = eyes_shut.visible
		loaf_eyes.scale = eyes.scale
	if mouth_open != null and not _sit_like(pose):
		mouth_open.visible = false
