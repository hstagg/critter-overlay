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


static func make(species: String, w: int, h: int, scale := 1.0, mode := "sit", asleep := false, face := -1, wear: Array = [], still := false) -> SubViewportContainer:
	# `still`: drawn once and left (many small previews, like the Shop's).
	var v = load("res://gui/critter_view.gd").new()
	v.still = still
	v._build(species, w, h, scale, mode, asleep, face)
	if not wear.is_empty() and v.critter != null:
		v.critter.wear(wear)
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
	if not Species.has(species):
		return
	var shrink := Node2D.new()
	shrink.scale = Vector2(scale, scale)
	_vp.add_child(shrink)
	var floor := Floor.new()
	floor.floor_y = h / scale - 6.0
	_vp.add_child(floor)
	critter = Species.row(species)["script"].new()
	critter.idles = Species.row(species)["idles"]
	shrink.add_child(critter)
	critter.setup(floor, w * 0.5 / scale, face, "sit" if asleep else mode)
	critter.mode_left = INF
	critter.tick(1.0 / 30.0)   # onto its floor (a still preview never ticks again)
	if asleep:
		# Curl up and doze before it is first seen.
		critter.go_to_sleep()
		for i in 240:
			critter.tick(1.0 / 30.0)


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
