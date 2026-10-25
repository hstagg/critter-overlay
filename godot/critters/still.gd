extends "res://critters/critter.gd"
## A homemade critter (customs.gd): one picture, moved as one piece, as
## v2.0's custom critters were. Walking bobs it, leans it into the stride and
## swings its bottom part like legs (v2.0's split at 58% of its height, here a
## mesh bent each frame); sitting breathes; napping settles it lower. A v2.0
## critter that came with its own animation plays its frames instead of the
## lean and swing, one loop per stretch walked, as v2.0 played them. Because it is still a critter, host.gd's window, dragging,
## throwing, dizzy spins and wall climbing work as for the cast.
##
## No head, ears, tail or blinks, so it does only the behaviours that need
## none (customs.gd IDLES), and wears no clothes.
##
## v2.0 stored pictures facing right, so they are drawn as they are when
## walking right and flipped when walking left (the cast is drawn facing left).

const Customs := preload("res://customs.gd")

const BOX := Vector2(210.0, 200.0)   # SVG units the picture fits inside, at size 1
const SPLIT := 0.58                  # where the "legs" start, down from the top (v2.0)
const BOB := 7.0                     # SVG units the body rises mid-stride
const LEAN := 5.0                    # degrees into the stride (v2.0)
const SWING := 0.2                   # bottom edge's swing, as a share of the leg part (v2.0)
const ANIM_CYCLE_PX := 114.0         # px walked per loop of a v2.0 animation (v2.0: 0.055 rad a px)

var tex: Array = []
var pic: Polygon2D
var pic_px := Vector2.ZERO           # the picture's size in rig pixels (SVG units x PART_SCALE)
var faces_right := true
var walked := 0.0                    # px walked, at zoom 1: a v2.0 animation follows the feet


func _define() -> void:
	# species is the "custom:<id>" host.gd set before setup().
	var d: Dictionary = Customs.all.get(species, {})
	tex = Customs.frames(species) if not d.is_empty() else []
	var tsize := Vector2(100, 100) if tex.is_empty() else Vector2(tex[0].get_size())
	var k := minf(BOX.x / tsize.x, BOX.y / tsize.y) * clampf(float(d.get("size", 1.0)), 0.5, 2.0)
	var units := tsize * k
	pic_px = units * PART_SCALE
	faces_right = str(d.get("faces", "right")) == "right"
	pivots = {}
	base_pt = Vector2(150, 262)
	ground_y = 262.0
	head_pivot = base_pt - Vector2(0, units.y * 0.75)
	head_at = {"sit": head_pivot, "walk": head_pivot, "loaf": head_pivot, "stand": head_pivot}
	head_height = units.y * 0.75 * PART_SCALE * critter_scale
	var box := Rect2(base_pt.x - units.x * 0.45, base_pt.y - units.y, units.x * 0.9, units.y)
	hit_bounds = {"sit": box, "walk": box, "stand": box,
		"loaf": Rect2(box.position + Vector2(0, units.y * 0.14), box.size * Vector2(1.0, 0.86))}
	leg_len = units.y * (1.0 - SPLIT)   # sets the gait's length: a step every ~0.3 of its height
	var speed := clampf(float(d.get("speed", 1.0)), 0.5, 2.0)
	speed_range = Vector2(40.0, 60.0) * speed


func _load_textures() -> void:
	pass   # customs.gd loads the picture


func _build_rig() -> void:
	# Just the picture, standing on base_pt. The empty leg nodes are there
	# because critter.gd's pose switching shows and hides them.
	legs_node = Node2D.new()
	legs_near = Node2D.new()
	torso_in.add_child(legs_node)
	torso_in.add_child(legs_near)
	body = _pivot(base_pt, base_pt)
	sit_body = Node2D.new()
	body.add_child(sit_body)
	torso_in.add_child(body)
	pic = Polygon2D.new()
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not tex.is_empty():
		pic.texture = tex[0]
		var ts := Vector2(tex[0].get_size())
		# Two columns, four rows: the top, the split, the knees, the feet.
		var rows := [0.0, SPLIT, (SPLIT + 1.0) * 0.5, 1.0]
		var uv := PackedVector2Array()
		for v in rows:
			uv.append(Vector2(0, v * ts.y))
			uv.append(Vector2(ts.x, v * ts.y))
		pic.uv = uv
		pic.polygons = [PackedInt32Array([0, 1, 3, 2]), PackedInt32Array([2, 3, 5, 4]), PackedInt32Array([4, 5, 7, 6])]
		_bend(0.0)
	body.add_child(pic)


func _bend(swing: float) -> void:
	# The picture's outline in rig pixels, feet at 0, with the part below the
	# split shifted sideways more towards the feet (swing in rig pixels).
	var w := pic_px.x * 0.5
	var pts := PackedVector2Array()
	for v in [0.0, SPLIT, (SPLIT + 1.0) * 0.5, 1.0]:
		var u := clampf((v - SPLIT) / (1.0 - SPLIT), 0.0, 1.0)
		var dx := swing * pow(u, 1.4)
		var y: float = (v - 1.0) * pic_px.y
		pts.append(Vector2(-w + dx, y))
		pts.append(Vector2(w + dx, y))
	pic.polygon = pts


func tick(delta: float) -> void:
	walked += absf(vx) * delta / zoom
	super(delta)


func _behaviour_params(p: Dictionary) -> void:
	super(p)
	var u := act_t
	var env := _env(u, act_len, 0.25)
	match act:
		"look_at_cursor":
			# Leans towards the pointer, in its own frame.
			var m: Vector2 = world.mouse_local()
			var side := signf((m.x - position.x) * -facing)
			p.lean = -side * 7.0 * env
		"shake_off":
			p.lean = sin(u * 38.0) * 9.0 * env
		"sit_and_look":
			p.lean = sin(u * 1.6) * 3.0 * env
		"wake_up":
			p.breath_y = 0.08


func _apply(p: Dictionary) -> void:
	var walking := pose == "walk"
	position.y = world.floor_y - air_y - lift - p.get("float", 0.0) * zoom
	var sq := squash
	var flip := 1.0 if (facing > 0) == faces_right else -1.0
	scale = Vector2(critter_scale * zoom * (1.0 + (1.0 - sq) * 0.6) * flip, critter_scale * zoom * sq)

	var pivot: Vector2 = p.torso_pivot
	torso.position = (pivot - base_pt + Vector2(0, p.torso_dy)) * PART_SCALE
	torso_in.position = -(pivot - base_pt) * PART_SCALE
	torso.rotation = deg_to_rad(p.torso_rot + p.head_rot * 0.5)

	var lean: float = p.lean
	var bob := 0.0
	var swing := 0.0
	var animated := tex.size() > 1
	var moving := smoothstep(0.0, 15.0, absf(vx)) if walking else 0.0
	if moving > 0.0:
		var c := cos(gait * TAU)
		bob = absf(sin(gait * TAU)) * BOB * moving
		if not animated:
			lean += c * LEAN * moving
			swing = c * SWING * pic_px.y * (1.0 - SPLIT) * moving
	if not tex.is_empty() and pic.texture != null:
		_bend(swing)
	if animated:
		# As v2.0 played them: one loop per ANIM_CYCLE_PX walked, and still
		# while it stands (frame 0), not a constant flicker.
		var i := int(walked / ANIM_CYCLE_PX * tex.size()) % tex.size() if walking and moving > 0.1 else 0
		pic.texture = tex[i]

	var napping := pose == "loaf"
	var breath := Vector2(1.0 + 0.018 * p.breath, 1.0 + p.breath_y * p.breath)
	body.scale = breath * (Vector2(1.06, 0.86) if napping else Vector2.ONE)
	body.position = Vector2(0, -bob) * PART_SCALE
	body.rotation = deg_to_rad(lean)


func region_rect() -> Rect2:
	# The picture as drawn this frame (critter.gd's version reads Sprite2Ds).
	var r := hit_rect()
	if pic != null:
		var b := Rect2(-pic_px.x * 0.5 - pic_px.x * 0.2, -pic_px.y, pic_px.x * 1.4, pic_px.y)
		r = r.merge(pic.get_global_transform() * b)
	return r.grow(REGION_SLACK)
