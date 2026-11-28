extends VBoxContainer
## The Studio's live preview (docs/custom-critters-build-plan.md, D6, P25;
## design/studio/builder/Builder.html, bottom right): a real kit critter,
## the same rig as on the desktop, walking beside the canvas.
##
## The doc is written to a staging folder through share.gd
## write_builder_kit() and drawn through Customs.show_staged() and
## critter_view.gd, so what walks here is exactly what Save would make. It is
## written again DEBOUNCE s after the last change, not on every mouse move.
## Walk, Sit and Nap hold it in that pose; Blink, Look around and Swish tail
## play once (only the moves it has). It turns at the well's sides.
##
## Customs has one staged slot, shared with the importers' previews: the
## Studio takes it while it is open.

const Customs := preload("res://customs.gd")
const Share := preload("res://share.gd")
const CritterView := preload("res://gui/critter_view.gd")
const LP := preload("res://gui/studio/layers_panel.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")

const STAGING := "user://studio_preview"
const DEBOUNCE := 0.5
const SIDE := 22.0                 # px kept clear at each side of the well

var st: Window                     # studio_window.gd
var pose := "walk"
var id := ""                       # Customs.STAGED once written, else ""
var view: Control
var _well: PanelContainer
var _moves: HBoxContainer
var _wait := -1.0


func _init(studio: Window) -> void:
	st = studio
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var c := K.c
	var head := K.hbox(8)
	head.add_child(UI.label("How it moves", 15, c.ink, 600, true))
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(g)
	head.add_child(K.seg(["Walk", "Sit", "Nap"], ["walk", "sit", "nap"].find(pose), func(i):
		pose = ["walk", "sit", "nap"][i]
		_rebuild_head()
		hold()))
	add_child(head)
	_well = PanelContainer.new()
	_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_well.custom_minimum_size.y = 120
	_well.add_theme_stylebox_override("panel", K.box(c.ground, 16, c.line, 2))
	add_child(_well)
	_moves = K.hbox(6)
	add_child(_moves)


func _rebuild_head() -> void:
	# The segment shows the pose: built again in place.
	var head: HBoxContainer = get_child(0)
	var old := head.get_child(2)
	var seg := K.seg(["Walk", "Sit", "Nap"], ["walk", "sit", "nap"].find(pose), func(i):
		pose = ["walk", "sit", "nap"][i]
		_rebuild_head()
		hold())
	head.add_child(seg)
	head.remove_child(old)
	old.queue_free()


func changed() -> void:
	# The doc changed: written again once it has been still for a moment.
	_wait = DEBOUNCE


func _process(delta: float) -> void:
	if _wait >= 0.0:
		_wait -= delta
		if _wait < 0.0:
			restage()
	if view != null and view.critter != null and view.critter.mode == "walk":
		_bounds()


func restage() -> void:
	# Writes the doc and shows it walking, or says what it still needs.
	_wait = -1.0
	for ch in _well.get_children():
		ch.queue_free()
	view = null
	id = ""
	var need := LP.needed(st.doc)
	if not need.is_empty():
		var l := UI.wrap("It can walk once the needed parts are drawn: %s." % ", ".join(need.map(func(p): return LP.part_name(st.doc.plan, p).to_lower())),
			12, K.c.ink3, st.SIDE_W - 60)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_well.add_child(K.margins(l, 12, 12, 12, 12))
		_buttons()
		return
	Share.clear_dir(STAGING)
	if Share.write_builder_kit(st.doc, st.critter_name if st.critter_name != "" else "My critter", STAGING, st.gait) == "":
		_buttons()
		return
	id = Customs.show_staged(STAGING)
	if id == "":
		_buttons()
		return
	var w := int(maxf(160.0, _well.size.x if _well.size.x > 10.0 else float(st.SIDE_W) - 24.0))
	var h := int(maxf(110.0, _well.size.y if _well.size.y > 10.0 else 150.0))
	view = CritterView.make(id, w, h, 0.8, "walk" if pose == "walk" else "sit", pose == "nap")
	_well.add_child(view)
	hold()
	_buttons()


func _floor() -> Node:
	for n in view.get_child(0).get_children():
		if n.get("floor_y") != null:
			return n
	return null


func _bounds() -> void:
	# Turns round inside the well rather than walking out of it.
	var fl := _floor()
	var holder: Node2D = view.get_child(0).get_child(0)
	if fl == null or holder == null:
		return
	var sc: float = holder.scale.x
	fl.left_x = SIDE / sc
	fl.right_x = (view.custom_minimum_size.x - SIDE) / sc


func hold() -> void:
	# Holds the critter in the picked pose.
	if view == null or view.critter == null:
		return
	var cr: Node2D = view.critter
	match pose:
		"walk":
			cr.wake_up()
			cr._go_walk()
		"sit":
			cr.wake_up()
			cr._go_sit()
		"nap":
			cr._go_loaf(INF)
	cr.mode_left = INF


func play(move: String) -> void:
	if view == null or view.critter == null:
		return
	var cr: Node2D = view.critter
	match move:
		"blink":
			cr.blink_in = 0.0
		"look":
			pose = "sit"
			_rebuild_head()
			cr.wake_up()
			cr.start_behaviour("sit_and_look", 2.4)
		"tail":
			pose = "sit"
			_rebuild_head()
			cr.wake_up()
			cr.start_behaviour("tail_swish", 1.6)


func can(move: String) -> bool:
	if view == null or view.critter == null:
		return false
	match move:
		"look":
			return view.critter.can_do("sit_and_look")
		"tail":
			return view.critter.can_do("tail_swish")
	return true


func _buttons() -> void:
	for ch in _moves.get_children():
		ch.queue_free()
	for m in [["blink", "Blink"], ["look", "Look around"], ["tail", "Swish tail"]]:
		if m[0] == "tail" and not can("tail"):
			continue
		var mv: String = m[0]
		var b := K.button(m[1], "bs", "", true, func(): play(mv))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not can(mv)
		b.focus_mode = Control.FOCUS_NONE
		_moves.add_child(b)


func clear() -> void:
	# The Studio is closing: the staged slot is let go.
	_wait = -1.0
	if id != "":
		Customs.clear_staged()
	id = ""
	Share.clear_dir(STAGING)
