extends SubViewportContainer
## A real critter idling inside a GUI panel: the same rig as on the desktop,
## drawn into its own small viewport and scaled to fit. Used by the Settings
## pages (Home's desk, the Critters preview, the Focus explainer, Sound).

const Species := preload("res://species.gd")


class Floor extends Node:
	## Just enough world for a critter that sits in a panel.
	var floor_y := 0.0
	var left_x := -INF
	var right_x := INF
	func mouse_local() -> Vector2:
		return Vector2(-9999, -9999)


const FPS := 24.0                  # previews redraw the whole window; 24 a second is plenty

var critter: Node2D
var _vp: SubViewport
var _step := 0.0
var still := false
var variant := ""             # a Legendary visitor's colour, "" for a random one


static func make(species: String, w: int, h: int, scale := 1.0, mode := "sit", asleep := false, face := -1, wear: Array = [], still := false, dyes: Dictionary = {}, variant := "") -> SubViewportContainer:
	# `still`: drawn once and left (many small previews, like the Shop's).
	# `variant`: a Legendary visitor's colour; "" picks one at random.
	var v = load("res://gui/critter_view.gd").new()
	v.still = still
	v.variant = variant
	v._build(species, w, h, scale, mode, asleep, face)
	if not wear.is_empty() and v.critter != null:
		v.critter.wear(wear, dyes)
	return v


func _build(species: String, w: int, h: int, scale: float, mode: String, asleep: bool, face: int) -> void:
	stretch = not still
	custom_minimum_size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.size = Vector2i(w, h)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	if not Species.has(species) and not Species.custom.has(species):
		return
	var shrink := Node2D.new()
	shrink.scale = Vector2(scale, scale)
	_vp.add_child(shrink)
	var floor := Floor.new()
	floor.floor_y = h / scale - 6.0
	_vp.add_child(floor)
	critter = Species.row(species)["script"].new()
	critter.idles = Species.row(species)["idles"]
	critter.species = species   # a homemade critter needs its id; the cast set their own
	if variant != "" and critter.has_method("set_variant"):
		critter.set_variant(variant)
	shrink.add_child(critter)
	critter.setup(floor, w * 0.5 / scale, face, "sit" if asleep else mode)
	critter.mode_left = INF
	critter.tick(1.0 / 30.0)   # onto its floor (a still preview never ticks again)
	if asleep:
		# Curl up and doze before it is first seen.
		critter.go_to_sleep()
		for i in 240:
			critter.tick(1.0 / 30.0)
	fit(critter, shrink, floor, w, h)


static func drawn_rect(c: Node2D) -> Rect2:
	# What a critter draws this frame, in its viewport's pixels.
	var items: Array = c._sprites.duplicate()
	if c.get("pic") is Polygon2D:
		items.append(c.pic)   # a homemade critter's picture
	var r := Rect2()
	var any := false
	for s in items:
		if not is_instance_valid(s) or not s.is_visible_in_tree():
			continue
		var local := Rect2()
		if s is Sprite2D:
			local = s.get_rect()
		else:
			var pts: PackedVector2Array = s.polygon
			if pts.is_empty():
				continue
			local = Rect2(pts[0], Vector2.ZERO)
			for q in pts:
				local = local.expand(q)
		var g: Rect2 = s.get_global_transform() * local
		r = g if not any else r.merge(g)
		any = true
	return r


static func fit(c: Node2D, holder: Node2D, floor_node: Node, w: float, h: float) -> void:
	# Shrinks the holder until the whole critter (ears, tail, hat) sits inside
	# w x h with a little room, feet on the floor and centred: a big panda or
	# a tall-eared rabbit is drawn smaller rather than cut off.
	for i in 3:
		var r := drawn_rect(c)
		if r.size.x <= 0.0:
			return
		var k := minf(1.0, minf((w - 6.0) / r.size.x, (h - 6.0) / r.size.y))
		if k >= 0.999 and r.position.y >= 2.0 and absf(w * 0.5 - r.get_center().x) < 2.0:
			return
		# Scaling is about the viewport's corner, so the centre moves with it.
		var off := w * 0.5 - r.get_center().x * k
		var sc: float = holder.scale.x * k
		holder.scale = Vector2(sc, sc)
		floor_node.floor_y = (h - 4.0) / sc
		c.position.x += off / sc
		c.tick(0.0)


func _ready() -> void:
	if still and critter != null:
		# Once drawn, keep the picture and let the viewport go: dozens of
		# live viewports cost the critters frames even when idle.
		_vp.size = Vector2i(custom_minimum_size)
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not is_instance_valid(_vp):
			return
		var img := _vp.get_texture().get_image()
		var tex := ImageTexture.create_from_image(img)
		var pic := TextureRect.new()
		pic.texture = tex
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.stretch_mode = TextureRect.STRETCH_KEEP
		var parent := get_parent()
		if parent == null:
			return
		var idx := get_index()
		pic.custom_minimum_size = custom_minimum_size
		parent.add_child(pic)
		parent.move_child(pic, idx)
		queue_free()


func _process(delta: float) -> void:
	if critter == null or still or not is_visible_in_tree():
		return
	_step += delta
	if _step < 1.0 / FPS:
		return
	critter.tick(_step)
	_step = 0.0
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
