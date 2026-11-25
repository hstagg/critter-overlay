extends "res://critters/critter.gd"
## A homemade critter with no legs: a slime, a ghost, a snake, a rock with
## eyes (docs/custom-critters-build-plan.md, 4.4). One body drawing for every
## pose; its eyes ride on a head node, drawn or not. It bounces, glides,
## floats or slithers (gaits.gd), naps melted (wider and lower), and climbs
## a wall as a slide, with no reach and pull. Legged moves are never offered
## (customs.gd NEEDS).

const Customs := preload("res://customs.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const Gaits := preload("res://critters/kit/gaits.gd")

var kit := {}
var gs := {}
var head_front: Sprite2D
var back_extra: Sprite2D


func _define() -> void:
	var d: Dictionary = Customs.all.get(species, {})
	kit = KitData.rig(Customs.tex_key(species), str(d.get("_dir", "")), d.get("_kit", {}),
		float(d.get("size", 1.0)), float(d.get("speed", 1.0)))
	KitData.apply(self, kit)
	back_hip = kit.mid
	gs = Gaits.state(kit.gait, kit.mid, kit.feet)


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


func _build_rig() -> void:
	super()
	if _has("back-extra"):
		back_extra = _sprite("back-extra")
		body.add_child(back_extra)
		body.move_child(back_extra, 0)


func _build_head() -> void:
	# critter.gd's, with the head drawing optional: without one, the head
	# node just carries the eyes (and any ears, mouth) on the body.
	head = _pivot(head_at["sit"], base_pt)
	for part in ear_parts:
		var ear := _pivot(pivots[part], head_pivot)
		ear.add_child(_sprite(part))
		head.add_child(ear)
		ears.append(ear)
	if ears.size() >= 2:
		ear_l = ears[0]
		ear_r = ears[1]
	if _has("head"):
		head.add_child(_sprite("head"))
	eyes = _pivot(pivots["eyes"], head_pivot)
	eyes_open = _sprite("eyes")
	eyes.add_child(eyes_open)
	if _has("eyes-closed"):
		eyes_shut = _sprite("eyes-closed")
		eyes.add_child(eyes_shut)
	head.add_child(eyes)
	if _has("mouth-open"):
		mouth_open = _pivot(pivots["mouth-open"], head_pivot)
		mouth_open.add_child(_sprite("mouth-open"))
		head.add_child(mouth_open)
	if _has("head-front"):
		head_front = _sprite("head-front")
		head.add_child(head_front)
	torso_in.add_child(head)


func _act_pose(_b: String) -> String:
	return "sit"   # nothing it does needs walking legs


# --- The walk ----------------------------------------------------------------------------

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
	p.head_off = Vector2(0, 1.0 * p.breath)   # eyes stay on the body, not bobbing over it
	Gaits.params(self, gs, p)
	return p


func _climb_surge() -> float:
	return 1.0   # a steady slide up the wall, no reach and pull


func _climb_params(p: Dictionary) -> void:
	# Pressed to the wall, eyes level; nothing reaching.
	p.head_rot += -climb_turn * (1.0 if facing < 0 else -1.0)
	p.torso_rot += 4.0
	p.tail_extra += 20.0
