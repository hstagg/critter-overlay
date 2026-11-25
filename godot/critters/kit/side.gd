extends "res://critters/critter.gd"
## A homemade critter drawn side-on, like the kitten
## (docs/custom-critters-build-plan.md, 4.1). Its shape comes from its kit
## (kit_data.gd), its walk from gaits.gd; every shared move is critter.gd's.
##
## What it does beyond critter.gd:
## - Poses it wasn't drawn in (P2, P3): sitting is the walking body with its
##   legs at rest; napping is the walking body melted onto the ground, legs
##   hidden. critter.gd would otherwise nap it as a floating head.
## - The new optional parts: head-front over the head; back-extra behind and
##   front-extra in front of the body; a wing that flaps in fly, shake off and
##   hops.
## - The kitten's hunt and tail chase, copied from kitten.gd (cited), since
##   any side-on critter with a tail and a trot can do them.

const Customs := preload("res://customs.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const Gaits := preload("res://critters/kit/gaits.gd")

var kit := {}                  # kit_data.gd rig()
var gs := {}                   # gaits.gd state()
var sit_walks := false         # no sitting drawing: sits as it walks, legs at rest
var head_front: Sprite2D
var back_extra: Sprite2D
var front_extra: Sprite2D
var wing: Node2D
var pounced := false           # kitten.gd's hunt and chase
var spins := 0


func _define() -> void:
	# species is the "custom:<id>" host.gd set before setup().
	var d: Dictionary = Customs.all.get(species, {})
	kit = KitData.rig(Customs.tex_key(species), str(d.get("_dir", "")), d.get("_kit", {}),
		float(d.get("size", 1.0)), float(d.get("speed", 1.0)))
	KitData.apply(self, kit)
	gs = Gaits.state(kit.gait, kit.mid, kit.feet)
	sit_walks = kit.sit_parts.is_empty()


func body_centre_px() -> float:
	return kit.body_centre_px


func head_top_px() -> float:
	return kit.head_top_px


func _wear_head() -> Dictionary:
	# Clothes are drawn from the kit's own head (F2).
	return kit.head


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
	# critter.gd's order, with the new parts: tail, legs, (back-extra) body
	# (front-extra, wing), near legs, head (head-front), the optional parts.
	_build_tail()
	_build_legs()
	_build_body()
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
	torso_in.add_child(legs_near)
	_build_head()
	_build_optional()


func _build_head_extras() -> void:
	if _has("head-front"):
		head_front = _sprite("head-front")
		head.add_child(head_front)


func _set_pose(p: String) -> void:
	if p == pose:
		return
	super(p)
	var shows_walk_body := p == "walk" or (p == "sit" and sit_walks)
	if sit_walks:
		walk_body.visible = shows_walk_body
		legs_node.visible = shows_walk_body
		legs_near.visible = shows_walk_body
		if p == "sit":
			for leg in legs:   # at rest under the body
				leg.node.rotation = 0.0
				leg.node.position = (leg.hip - base_pt) * PART_SCALE
	for n in [back_extra, front_extra, wing]:
		if n != null:
			n.visible = shows_walk_body


# --- The walk --------------------------------------------------------------------------

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


func _apply_legs(p: Dictionary) -> void:
	if p.legs != "gait" or gs.name != "hop":
		super(p)
		return
	# rabbit.gd:148-165: the hop's legs, the far pair trailing a touch.
	var a := Gaits.hop_legs(self, gs)
	for leg in legs:
		var node: Node2D = leg.node
		node.position = (leg.hip - base_pt) * PART_SCALE
		var deg: float = a.x if leg.front else a.y
		if node.get_parent() == legs_node:
			deg *= 0.85
		node.rotation = deg_to_rad(deg)


func _apply_extras(_p: Dictionary) -> void:
	if wing == null:
		return
	var f := 0.0
	match act:
		"fly":
			f = 25.0 * sin(t * TAU * 4.0)
		"shake_off":
			f = 15.0 * sin(t * TAU * 6.0)
		"dance":
			f = 12.0 * sin(t * TAU * 2.0)
	if airborne or lift > 0.5:
		f -= 20.0
	wing.rotation = deg_to_rad(f)


# --- Behaviours ---------------------------------------------------------------------

func _act_pose(b: String) -> String:
	if b in ["hunt", "chase_tail"]:
		return "walk"
	return super(b)


func _on_begin(b: String) -> void:
	super(b)
	pounced = false
	spins = 0


func _can_hop() -> bool:
	return act != "hunt"


func _behaviour_params(p: Dictionary) -> void:
	match act:
		"hunt":
			_hunt_params(p, act_t)
		"chase_tail":
			_chase_params(p, act_t)
		_:
			super(p)


func _hunt_params(p: Dictionary, u: float) -> void:
	# kitten.gd _hunt_params: crouch, wiggle, pounce, rocking about the front hip.
	var crouch_in := 0.35
	var wiggle_end := act_len - 0.6
	p.eyes_off = Vector2(-8.0, 1.0)
	p.blink = false
	p.ear_l = 10.0
	p.ear_r = -10.0
	if u < wiggle_end:
		var c := _ease_io(clampf(u / crouch_in, 0.0, 1.0))
		p.torso_dy = 12.0 * c
		p.legs = "plant"
		p.leg_front = 1.0
		p.leg_back = -1.0
		p.tail_rot = tail_rest_deg["walk"] + 30.0 * c
		if u > crouch_in:
			var wig := sin((u - crouch_in) * TAU * 5.0)
			p.torso_pivot = kit.front_hip
			p.torso_rot = 3.0 * wig
			p.tail_extra = 6.0 * wig
	else:
		if not pounced:
			pounced = true
			_launch(-380.0 * zoom)
			vx = facing * 190.0 * zoom
		p.legs = "leap"
		p.torso_rot = 10.0 if air_vy < 0.0 else -6.0
		p.tail_rot = tail_rest_deg["walk"] + 20.0
		if not airborne:
			p.legs = "gait"


func _chase_params(p: Dictionary, u: float) -> void:
	# kitten.gd _chase_params: round and round after its own tail.
	var n := int(u / 0.4)
	if n > spins and u < act_len - 0.2:
		spins = n
		facing = -facing
		want_facing = facing
		_kick_squash(-1.3)
	var f := fmod(u, 0.4) / 0.4
	p.eyes_off = Vector2(8.0, 2.0)
	p.blink = false
	p.head_rot = 8.0 * sin(f * PI)
	p.torso_rot = -4.0 * sin(f * PI)
	p.tail_extra = 28.0 * sin(u * TAU * 2.5)
	p.ear_l = 8.0
	p.ear_r = -8.0
