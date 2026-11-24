extends "res://critters/critter.gd"
## A homemade critter that stands on two legs facing you and waddles side-on,
## like the duckling (docs/custom-critters-build-plan.md, 4.3). Its shape
## comes from its kit (kit_data.gd), its walk from gaits.gd (waddle or hop).
##
## The duckling's own parts and moves, copied from duckling.gd (cited) and
## made optional: both wings sitting and the near wing walking, the sprung
## tuft, the fluff-up groom, the one-wing stretch, preen and peck_ground
## (with mouth-open as the beak), the tuft flicking for ears it hasn't got.
## Napping not drawn: the body settled down as a ball (kit_data.gd's melt).

const Customs := preload("res://customs.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const Gaits := preload("res://critters/kit/gaits.gd")

var kit := {}
var gs := {}
var wings: Node2D
var wing_l: Node2D
var wing_r: Node2D
var wing_side: Node2D
var tuft: Node2D
var head_front: Sprite2D
var back_extra: Sprite2D
var front_extra: Sprite2D


func _define() -> void:
	var d: Dictionary = Customs.all.get(species, {})
	kit = KitData.rig(Customs.tex_key(species), str(d.get("_dir", "")), d.get("_kit", {}),
		float(d.get("size", 1.0)), float(d.get("speed", 1.0)))
	KitData.apply(self, kit)
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


# --- Rig -------------------------------------------------------------------------------

func _build_rig() -> void:
	super()
	if _has("back-extra"):
		back_extra = _sprite("back-extra")
		body.add_child(back_extra)
		body.move_child(back_extra, 0)
	if _has("front-extra"):
		front_extra = _sprite("front-extra")
		body.add_child(front_extra)
	if _has("wing-l"):
		# duckling.gd:79-93: wings on the body under the head; the near one
		# walking, in front of the near leg.
		wings = Node2D.new()
		wing_l = _pivot(pivots["wing-l"], base_pt)
		wing_l.add_child(_sprite("wing-l"))
		wing_r = _pivot(pivots["wing-r"], base_pt)
		wing_r.add_child(_sprite("wing-r"))
		wings.add_child(wing_l)
		wings.add_child(wing_r)
		torso_in.add_child(wings)
		torso_in.move_child(wings, body.get_index() + 1)
		wing_side = _pivot(pivots["wing-side"], base_pt)
		wing_side.add_child(_sprite("wing-side"))
		torso_in.add_child(wing_side)
		torso_in.move_child(wing_side, legs_near.get_index() + 1)


func _build_head_extras() -> void:
	if _has("tuft"):
		tuft = _pivot(pivots["tuft"], head_pivot)
		tuft.add_child(_sprite("tuft"))
		head.add_child(tuft)
		head.move_child(tuft, 0)   # behind the head's outline
	if _has("head-front"):
		head_front = _sprite("head-front")
		head.add_child(head_front)


func _on_pose(p: String) -> void:
	if wings != null:
		wings.visible = p == "sit"
		wing_side.visible = p == "walk"
	for n in [back_extra, front_extra]:
		if n != null:
			n.visible = p == "walk" or p == "sit"


func _act_pose(b: String) -> String:
	match b:
		"stretch":
			return "sit"
		"peck_ground":
			return "walk"
	return super(b)


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
	p.wing_l = 0.0             # duckling.gd:124-128
	p.wing_r = 0.0
	p.fluff = 0.0
	p.tuft = 0.0
	p.wing_front = false
	Gaits.params(self, gs, p)
	if pose == "walk" and gs.name == "waddle":
		var moving := smoothstep(0.0, 15.0, absf(vx))
		p.wing_r = 3.0 * absf(sin(gait * TAU)) * moving   # duckling.gd:136
	if twitch_left > 0.0 and wings != null:
		# duckling.gd:138-142: now and then a little wing flutter.
		var f := sin((1.0 - twitch_left / 0.25) * TAU * 2.0) * 14.0
		p.wing_l += f
		p.wing_r += f
	return p


# --- Behaviours: duckling.gd:145-218 ----------------------------------------------------

func _behaviour_params(p: Dictionary) -> void:
	var u := act_t
	match act:
		"preen":
			var k := _ease_io(_env(u, act_len, 0.35))
			var nib := maxf(0.0, sin(u * TAU * 4.0))
			p.head_off = p.head_off + Vector2(18.0, 14.0 + 3.0 * nib) * k
			p.head_rot += 22.0 * k
			p.mouth = 0.5 * nib * k
			p.wing_r = 26.0 * k + 6.0 * nib * k
			p.eyes_closed = k > 0.6
			p.blink = false
		"peck_ground":
			var k := _ease_io(_env(u, act_len, 0.25))
			var peck := maxf(0.0, sin(u * TAU * 3.0))
			p.torso_pivot = kit.feet
			p.torso_rot = -18.0 * k
			p.head_off = p.head_off + Vector2(-10.0, 28.0 + 14.0 * peck) * k
			p.head_rot -= 8.0 * k
			p.mouth = 0.6 * (1.0 - peck) * k
			p.tail_extra = 12.0 * k
			p.eyes_off = Vector2(-2.0, 4.0) * k
			p.legs = "plant"
		"groom":
			if wings == null:
				super(p)
			else:
				var k := _ease_io(_env(u, act_len, 0.3))
				var flap := absf(sin(u * TAU * 3.5)) * k
				p.fluff = k * (1.0 + 0.3 * sin(u * TAU * 9.0))
				p.wing_l = 40.0 * flap
				p.wing_r = 40.0 * flap
				p.head_off = p.head_off + Vector2(0, 4.0) * k
				p.eyes_closed = k > 0.4
				p.blink = false
				p.tuft = 18.0 * sin(u * TAU * 6.0) * k
		"stretch":
			if wings == null:
				super(p)
			else:
				var s := _ease_io(_env(u, act_len, 0.45))
				p.wing_r = 95.0 * s
				p.lean = p.lean - 6.0 * s
				p.head_rot -= 6.0 * s
				if s > 0.6:
					p.eyes_closed = true
					p.blink = false
					p.mouth = sin(clampf((u - 0.5) / maxf(0.1, act_len - 0.9), 0.0, 1.0) * PI)
		"ear_flick":
			if ear_l == null and tuft != null:
				p.tuft = 30.0 * sin(u / act_len * TAU * 2.0) * (1.0 - u / act_len)
			else:
				super(p)
		_:
			super(p)
	if act == "shake_off":
		var w := u * TAU * 7.0
		var k := _env(u, act_len, 0.12)
		p.wing_l = 30.0 * absf(sin(w - 0.6)) * k
		p.wing_r = 30.0 * absf(sin(w - 0.6)) * k
		p.tuft = 30.0 * sin(w - 1.2) * k
	elif act == "listen":
		p.tuft = 12.0 * signf(p.head_rot)


func _apply_extras(p: Dictionary) -> void:
	# duckling.gd:221-236, without its beak parts (mouth-open is critter.gd's).
	if wings != null:
		wing_l.rotation = deg_to_rad(p.wing_l)
		wing_r.rotation = deg_to_rad(-p.wing_r)
		wing_r.z_index = 1 if p.wing_front else 0
		wing_side.rotation = deg_to_rad(-p.wing_r)
	if tuft != null:
		tuft.rotation = deg_to_rad(p.tuft + 0.6 * p.ear_r) + ears_s * 2.0
	if p.fluff > 0.0:
		body.scale *= 1.0 + 0.12 * p.fluff
		head.scale = Vector2.ONE * (1.0 + 0.04 * p.fluff)
	else:
		head.scale = Vector2.ONE
