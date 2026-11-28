extends Window
## The Critter Studio (docs/custom-critters-build-plan.md, D2 and D3, P18,
## decision 2; design/studio/builder/Builder.html): its own window, with the
## Settings window's chrome (borderless, its own title bar, drawn at the
## display scale or smaller to fit, UI.fit), and resizable down to a minimum
## that fits a 1366 x 768 screen.
##
## The top bar: back to My critters, the name, Shapes / Pins, undo and redo,
## Save. Below, left to right: the layers grouped by pose (layers_panel.gd),
## the tool rail, the canvas (canvas.gd) with the selection's commands above
## it, and the right column, kept for the colour panel (D4) and the live
## preview (D6). Pins and Save come with D6.
##
## The window holds the doc being built (shapes.json, 5.3) and the history;
## every change goes through tools.gd. Shortcuts are the design's ? panel's.

const Palette := preload("res://gui/palette.gd")
const UI := preload("res://gui/ui.gd")
const K := preload("res://gui/controls.gd")
const Icons := preload("res://gui/icons.gd")
const SI := preload("res://gui/studio/studio_icons.gd")
const Shapes := preload("res://studio/shapes.gd")
const Writer := preload("res://studio/shape_svg.gd")
const Tools := preload("res://gui/studio/tools.gd")
const History := preload("res://gui/studio/history.gd")
const LayersPanel := preload("res://gui/studio/layers_panel.gd")
const Canvas := preload("res://gui/studio/canvas.gd")
const Customs := preload("res://customs.gd")

const W := 1280                    # the design's size
const H := 800
const MIN_W := 1200                # P18's minimum, in the design's units
const MIN_H := 800
const ROOM := 0.95                 # of the work area, at most
const SIDE_W := 316
const TOOLS := [["move", "Move, turn and resize", "V"], [], ["ellipse", "Oval", "E"], ["rect", "Rounded box", "R"],
	["tri", "Triangle", "T"], ["drop", "Drop", "D"], ["heart", "Heart", "H"], ["star", "Star", "S"],
	["blob", "Blob", "B"], ["stroke", "Line", "L"], ["eye", "Eye", "I"], [], ["pan", "Pan (hold Space)", ""]]
const SHAPE_NAMES := {"ellipse": "oval", "rect": "rounded box", "tri": "triangle", "drop": "drop", "heart": "heart",
	"star": "star", "blob": "blob", "stroke": "line", "eye": "eye"}

var main: Node                     # main.gd
var doc := {}                      # shapes.json being built
var editing_id := ""               # the homemade critter being edited, or ""
var critter_name := ""
var part := ""                     # the picked layer
var sel: Array = []                # indices in it
var tool := "move"
var pose := "walk"                 # the pose the canvas shows
var hist := History.new()
var clip: Array = []
var clip_from := ""
var hidden := {}
var locked := {}
var others_on := true
var snap_on := true
var guide_on := true
var sym_on := true
var changed := false
var canvas: Control
var layers: RefCounted
var _layers_box: Control
var _ctx: HBoxContainer
var _rail: VBoxContainer
var _top_note: Label
var _undo: Button
var _redo: Button
var _zoom_pct: Label
var _hint: Label
var _hint_left := 0.0
var _drag_from := Vector2i(-1, -1)
var _resize_from := Vector2i(-1, -1)
var _resize_size := Vector2i.ZERO
var _taskbar_done := false


func _init() -> void:
	title = "Critter Studio"
	borderless = true
	unresizable = false
	wrap_controls = false
	visible = false
	initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	close_requested.connect(hide)


static func fit_for(usable: Vector2, display: float) -> Dictionary:
	# The scale, the size to open at and the minimum size, in px, for a work
	# area: the display scale, smaller if the minimum would not fit.
	var f := minf(display, minf(usable.x * ROOM / MIN_W, usable.y * ROOM / MIN_H))
	var open := (Vector2(W, H) * f).min(usable * ROOM)
	return {"scale": f, "size": Vector2i(open), "min": Vector2i((Vector2(MIN_W, MIN_H) * f).ceil())}


func open(main_ref: Node, shapes_doc := {}, id := "") -> void:
	main = main_ref
	if doc.is_empty() or not shapes_doc.is_empty() or id != editing_id:
		load_doc(shapes_doc, id)
	build()
	if not visible:
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
		var fit := fit_for(Vector2(usable.size), UI.scale())
		content_scale_factor = fit.scale
		min_size = fit.min
		size = fit.size
		position = usable.position + (usable.size - size) / 2
		show()
		# Only one window may wait for vsync (see host.gd).
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, get_window_id())
		if not _taskbar_done and main.native != null:
			_taskbar_done = true
			main.native.show_in_taskbar(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, get_window_id()))
	if mode == Window.MODE_MINIMIZED:
		mode = Window.MODE_WINDOWED
	grab_focus()
	canvas.grab_focus()


func load_doc(shapes_doc: Dictionary, id := "") -> void:
	# A starter, a saved critter's shapes.json, or {} for a blank side-on one.
	doc = Writer.clean_doc(shapes_doc).doc if not shapes_doc.is_empty() else Tools.blank()
	editing_id = id
	critter_name = str(Customs.all.get(id, {}).get("name", "")) if id != "" else ""
	hist.clear()
	sel = []
	hidden.clear()
	locked.clear()
	changed = false
	var need := LayersPanel.needed(doc)
	part = need[0] if not need.is_empty() else (doc.layers.keys()[0] if not doc.layers.is_empty() else "head")
	pose = LayersPanel.pose_of(doc.plan, part) if LayersPanel.pose_of(doc.plan, part) != "" else "walk"
	if canvas != null:
		canvas.mark_all()


# --- Building the window -----------------------------------------------------------------

func build() -> void:
	for ch in get_children():
		ch.queue_free()
	K.c = Palette.colours(Palette.is_dark())
	K.dark = Palette.is_dark()
	var c := K.c
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", K.box(c.ground, 0, c.line, 1))
	add_child(bg)
	var col := K.vbox(0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(col)
	col.add_child(_top())
	var body := K.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	layers = LayersPanel.new(self)
	_layers_box = K.vbox(0)
	_layers_box.custom_minimum_size.x = LayersPanel.W
	body.add_child(_layers_box)
	body.add_child(_line(true))
	_rail = K.vbox(4)
	body.add_child(_rail_panel())
	body.add_child(_line(true))
	body.add_child(_stage())
	body.add_child(_line(true))
	body.add_child(_side())
	add_child(_grip())
	refresh_layers()
	refresh_rail()
	refresh_ctx()
	refresh_top()


func _line(vertical: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = K.c.line
	r.custom_minimum_size = Vector2(2, 0) if vertical else Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _top() -> Control:
	var c := K.c
	var v := K.vbox(0)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(c.side, 0))
	p.custom_minimum_size.y = 60
	v.add_child(p)
	v.add_child(_line(false))
	var h := K.hbox(12)
	p.add_child(K.margins(h, 14, 0, 10, 0))
	var back := K.button("My critters", "bq", "", true, back_to_my_critters)
	back.icon = SI.line("back", 18, c.ink2)
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(back)
	h.add_child(_sep())
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(36, 36)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_theme_stylebox_override("panel", K.box(c.surface, 12, c.outline, 2, c.lip, 2))
	mark.add_child(UI.icon(SI.line("blob", 22, c.acc_ink)))
	h.add_child(mark)
	var ttl := K.vbox(0)
	ttl.alignment = BoxContainer.ALIGNMENT_CENTER
	ttl.add_child(UI.label("Critter Studio", 16, c.ink, 600, true))
	ttl.add_child(UI.label("Built from shapes", 11, c.ink3, 700))
	_draggable(ttl)
	h.add_child(ttl)
	var nl := UI.label("Name", 11, c.ink2, 700)
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(K.margins(nl, 10, 0, 0, 0))
	var name_field := K.text_field(critter_name, "Name it", 24, func(t): critter_name = t)
	name_field.custom_minimum_size.x = 180
	name_field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name_field)
	_top_note = UI.label("", 12, c.ink3, 700)
	_top_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_top_note)
	h.add_child(_grow(true))
	var mode_seg := K.seg(["Shapes", "Pins"], 0, func(i):
		if i == 1:
			say("Pins aren't built yet."))
	mode_seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mode_seg)
	h.add_child(_grow(true))
	_undo = _ib("undo", "Undo (Ctrl+Z)", undo)
	_redo = _ib("redo", "Redo (Ctrl+Y)", redo)
	h.add_child(_undo)
	h.add_child(_redo)
	var save := K.button("Save", "bp", "", false)
	save.disabled = true
	save.tooltip_text = "Saving isn't built yet."
	save.focus_mode = Control.FOCUS_NONE
	save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(save)
	h.add_child(_sep())
	for wb in [["min", "Minimise", func(): mode = Window.MODE_MINIMIZED],
			["max", "Maximise", func(): mode = Window.MODE_WINDOWED if mode == Window.MODE_MAXIMIZED else Window.MODE_MAXIMIZED],
			["close", "Close", hide]]:
		var b := _ib(wb[0], wb[1], wb[2])
		b.custom_minimum_size = Vector2(36, 32)
		h.add_child(b)
	return v


func _sep() -> Control:
	var s := ColorRect.new()
	s.color = K.c.line
	s.custom_minimum_size = Vector2(2, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s


func _grow(drag_moves := false) -> Control:
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if drag_moves:
		_draggable(g)
	else:
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _ib(icon: String, tip: String, cb: Callable) -> Button:
	var c := K.c
	var b := Button.new()
	b.icon = SI.line(icon, 18, c.ink2)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(36, 36)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("normal", K.box(Color.TRANSPARENT, 10))
	b.add_theme_stylebox_override("hover", K.box(c.track, 10))
	b.add_theme_stylebox_override("pressed", K.box(c.track, 10))
	b.add_theme_stylebox_override("disabled", K.box(Color.TRANSPARENT, 10))
	b.pressed.connect(cb)
	return b


func _rail_panel() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 60
	p.add_theme_stylebox_override("panel", K.box(K.c.surface, 0))
	_rail.alignment = BoxContainer.ALIGNMENT_BEGIN
	p.add_child(K.margins(_rail, 9, 12, 9, 12))
	return p


func _stage() -> Control:
	var c := K.c
	var v := K.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = 52
	bar.add_theme_stylebox_override("panel", K.box(c.ground, 0))
	_ctx = K.hbox(6)
	bar.add_child(K.margins(_ctx, 14, 0, 14, 0))
	v.add_child(bar)
	var div := ColorRect.new()
	div.color = c.div
	div.custom_minimum_size.y = 2
	v.add_child(div)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	v.add_child(holder)
	var keep_zoom: float = canvas.zoom if canvas != null else -1.0
	var keep_origin: Vector2 = canvas.origin if canvas != null else Vector2.ZERO
	canvas = Canvas.new(self)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if keep_zoom > 0.0:
		canvas.zoom = keep_zoom
		canvas.origin = keep_origin
		canvas.fitted = true
	holder.add_child(canvas)
	canvas.mark_all()
	# Zoom, bottom left, and the hint beside it.
	var zp := PanelContainer.new()
	zp.add_theme_stylebox_override("panel", K.box(c.raised, 14, c.sec_line, 2, c.sec_line, 2))
	var zh := K.hbox(4)
	zp.add_child(K.margins(zh, 3, 3, 3, 3))
	zh.add_child(_zb("-", "Zoom out", func(): canvas.set_zoom(canvas.zoom / 1.25)))
	_zoom_pct = UI.label("100%", 13, c.ink, 800)
	_zoom_pct.custom_minimum_size.x = 44
	_zoom_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zh.add_child(_zoom_pct)
	zh.add_child(_zb("+", "Zoom in", func(): canvas.set_zoom(canvas.zoom * 1.25)))
	zh.add_child(_zb("Fit", "Fit the frame (0)", func(): canvas.fit()))
	_corner(zp, false, 14, 14)
	holder.add_child(zp)
	_hint = UI.label("Hold Space and drag to move around. Ctrl and the wheel zoom.", 12, c.ink3, 700)
	_corner(_hint, false, 230, 24)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_hint)
	return v


static func _corner(ctl: Control, right: bool, dx: float, dy: float) -> void:
	# Pinned to the parent's bottom left (or right) corner, dx and dy in from
	# it, growing up (and left) to its own size.
	ctl.anchor_top = 1.0
	ctl.anchor_bottom = 1.0
	ctl.anchor_left = 1.0 if right else 0.0
	ctl.anchor_right = ctl.anchor_left
	ctl.offset_top = -dy
	ctl.offset_bottom = -dy
	ctl.offset_left = -dx if right else dx
	ctl.offset_right = ctl.offset_left
	ctl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ctl.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END


func _zb(text: String, tip: String, cb: Callable) -> Button:
	var c := K.c
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(30, 30)
	b.add_theme_font_override("font", UI.font(800))
	b.add_theme_font_size_override("font_size", 13)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, c.ink2)
	b.add_theme_stylebox_override("normal", K.box(Color.TRANSPARENT, 10))
	b.add_theme_stylebox_override("hover", K.box(c.ground, 10))
	b.add_theme_stylebox_override("pressed", K.box(c.ground, 10))
	b.pressed.connect(cb)
	return b


func _side() -> Control:
	# Kept for the colour panel (D4) and the live preview (D6).
	var c := K.c
	var p := PanelContainer.new()
	p.custom_minimum_size.x = SIDE_W
	p.add_theme_stylebox_override("panel", K.box(c.surface, 0))
	var v := K.vbox(10)
	p.add_child(K.margins(v, 12, 12, 12, 12))
	for sec in [["Colour", "The colour of the picked shape, its outline and marking, and the eyes and blush.", false],
			["How it moves", "The critter itself, walking, sitting and napping as you build it.", true]]:
		var head := K.hbox(8)
		head.add_child(UI.label(sec[0], 15, c.ink, 600, true))
		head.add_child(_grow())
		head.add_child(K.soon_pill())
		v.add_child(head)
		var well := PanelContainer.new()
		well.add_theme_stylebox_override("panel", K.box(c.ground, 16, c.line, 2))
		if sec[2]:
			well.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			well.custom_minimum_size.y = 300
		var note := UI.wrap(sec[1], 12, c.ink3, SIDE_W - 60)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		well.add_child(K.margins(note, 14, 14, 14, 14))
		v.add_child(well)
	return p


func _grip() -> Control:
	# Bottom right: drag to resize (a borderless window has no frame to drag).
	var g := TextureRect.new()
	g.texture = SI.line("grip", 16, K.c.ink3)
	_corner(g, true, 2, 2)
	g.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	g.tooltip_text = "Drag to resize"
	g.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_resize_from = DisplayServer.mouse_get_position() if e.pressed else Vector2i(-1, -1)
			_resize_size = size
		elif e is InputEventMouseMotion and _resize_from.x >= 0:
			size = (_resize_size + DisplayServer.mouse_get_position() - _resize_from).max(min_size))
	return g


func _draggable(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = DisplayServer.mouse_get_position() - position if e.pressed else Vector2i(-1, -1)
		elif e is InputEventMouseMotion and _drag_from.x >= 0 and mode == Window.MODE_WINDOWED:
			position = DisplayServer.mouse_get_position() - _drag_from)


# --- Keeping the panels in step -----------------------------------------------------------

func refresh_layers() -> void:
	if _layers_box == null:
		return
	for ch in _layers_box.get_children():
		ch.queue_free()
	var p: Control = layers.build()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layers_box.add_child(p)


func refresh_rail() -> void:
	if _rail == null:
		return
	var c := K.c
	for ch in _rail.get_children():
		ch.queue_free()
	for t in TOOLS:
		if t.is_empty():
			var hr := ColorRect.new()
			hr.color = c.div
			hr.custom_minimum_size = Vector2(30, 2)
			hr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_rail.add_child(K.margins(hr, 0, 6, 0, 6))
			continue
		var on: bool = tool == t[0]
		var b := Button.new()
		b.icon = SI.line("hand" if t[0] == "pan" else t[0], 20, c.acc_ink if on else c.ink2)
		b.tooltip_text = "%s (%s)" % [t[1], t[2]] if t[2] != "" else t[1]
		b.custom_minimum_size = Vector2(42, 40)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var n := K.box(c.chip_sel if on else Color.TRANSPARENT, 12, c.outline if on else Color.TRANSPARENT, 2, c.lip, 2 if on else 0)
		var hv := n.duplicate()
		if not on:
			hv.bg_color = c.ground
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", n)
		var id: String = t[0]
		b.pressed.connect(func(): set_tool(id))
		if t[2] != "":
			var k := UI.label(t[2], 9, c.ink3, 800)
			_corner(k, true, 3, 0)
			k.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(k)
		_rail.add_child(b)


func refresh_ctx() -> void:
	# Above the canvas: what is picked, the commands, the canvas switches.
	if _ctx == null:
		return
	var c := K.c
	for ch in _ctx.get_children():
		ch.queue_free()
	var shapes := Tools.layer(doc, part)
	var what := K.hbox(6)
	what.add_child(UI.label(LayersPanel.part_name(doc.plan, part), 13, c.ink, 800))
	var detail := "nothing picked"
	if sel.size() == 1 and sel[0] < shapes.size():
		detail = "%s, %d of %d" % [SHAPE_NAMES.get(shapes[sel[0]].t, "shape"), sel[0] + 1, shapes.size()]
	elif sel.size() > 1:
		detail = "%d shapes" % sel.size()
	elif shapes.is_empty():
		detail = "empty: pick a shape and click to add one"
	what.add_child(UI.label(detail, 13, c.ink3, 700))
	_ctx.add_child(K.margins(what, 0, 0, 6, 0))
	var any := not sel.is_empty()
	for b in [["fwd", "Bring forward (Page Up)", forward], ["bwd", "Send back (Page Down)", back],
			["mirror", "Mirror (M)", mirror], ["dup", "Duplicate (Ctrl+D)", duplicate_sel], ["del", "Delete (Del)", delete_sel]]:
		var ib := _ib(b[0], b[1], b[2])
		ib.disabled = not any
		if b[0] == "del":
			ib.icon = SI.line("del", 18, c.dng_ink)
		ib.modulate.a = 1.0 if any else 0.4
		_ctx.add_child(ib)
	_ctx.add_child(_grow())
	if Tools.symmetric(doc.plan, part):
		_ctx.add_child(_chip("sym", "Symmetry", "Shapes on one side are mirrored to the other", sym_on, func():
			sym_on = not sym_on
			refresh_ctx()))
	_ctx.add_child(_chip("snap", "Snap", "Shapes snap to the ground line and the middle", snap_on, func():
		snap_on = not snap_on
		refresh_ctx()))
	_ctx.add_child(_chip("show", "Other layers", "Show the other layers faintly, or hide them", others_on, func():
		others_on = not others_on
		refresh_ctx()
		canvas.queue_redraw()))
	_ctx.add_child(_chip("paw", "Guide", "A faint kitten to draw over, or none", guide_on, func():
		guide_on = not guide_on
		refresh_ctx()
		canvas.queue_redraw()))


func _chip(icon: String, text: String, tip: String, on: bool, cb: Callable) -> Button:
	var b := K.chip(text, on, cb)
	b.icon = SI.line(icon, 15, K.c.ink if on else K.c.ink_body)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func refresh_top() -> void:
	if _undo == null:
		return
	_undo.disabled = not hist.can_undo()
	_redo.disabled = not hist.can_redo()
	_undo.modulate.a = 1.0 if hist.can_undo() else 0.4
	_redo.modulate.a = 1.0 if hist.can_redo() else 0.4
	_top_note.text = "Changed since you opened it" if changed else ""


func zoom_changed() -> void:
	if _zoom_pct != null and canvas != null:
		_zoom_pct.text = "%d%%" % roundi(canvas.zoom * 100.0)


func say(text: String) -> void:
	# A short note where the canvas hint is.
	if _hint == null:
		return
	_hint.text = text
	_hint.add_theme_color_override("font_color", K.c.acc_ink)
	_hint_left = 4.0


func _process(delta: float) -> void:
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0 and _hint != null:
			_hint.text = "Hold Space and drag to move around. Ctrl and the wheel zoom."
			_hint.add_theme_color_override("font_color", K.c.ink3)


func changed_parts(parts: Array, final := true) -> void:
	# After any change: those layers are drawn again; when it is done (not
	# mid-drag), the panels follow.
	changed = true
	canvas.mark(parts)
	if final:
		sel = sel.filter(func(i): return i < Tools.layer(doc, part).size())
		refresh_layers()
		refresh_ctx()
		refresh_top()


func selection_changed(final := true) -> void:
	canvas.queue_redraw()
	if final:
		refresh_ctx()


# --- What the controls do --------------------------------------------------------------

func editable(p: String) -> bool:
	return not hidden.has(p) and not locked.has(p)


func sym_here() -> bool:
	return sym_on and Tools.symmetric(doc.plan, part)


func pick_part(p: String) -> void:
	part = p
	sel = []
	var ps := LayersPanel.pose_of(doc.plan, p)
	if ps != "":
		pose = ps
	refresh_layers()
	refresh_ctx()
	canvas.queue_redraw()


func set_tool(t: String) -> void:
	tool = t
	refresh_rail()
	canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS if t in Shapes.TYPES else Control.CURSOR_ARROW


func toggle_hidden(p: String) -> void:
	if hidden.has(p):
		hidden.erase(p)
	else:
		hidden[p] = true
		if p == part:
			sel = []
	refresh_layers()
	canvas.queue_redraw()


func toggle_locked(p: String) -> void:
	if locked.has(p):
		locked.erase(p)
	else:
		locked[p] = true
		if p == part:
			sel = []
	refresh_layers()
	refresh_ctx()
	canvas.queue_redraw()


func place(t: String, u: Vector2) -> void:
	# A click with a shape tool: the shape, picked, and back to Move.
	if not editable(part):
		say("Show and unlock %s to draw on it." % LayersPanel.part_name(doc.plan, part))
		return
	var at := Tools.snap_point(u, Tools.SNAP / canvas.zoom) if snap_on else u
	var i := Tools.place(doc, hist, part, t, at, sym_here())
	if i < 0:
		say("That's as many shapes as a critter can have here.")
		return
	sel = [i]
	set_tool("move")
	changed_parts([part])


func draw_pose(p: String, from: String) -> void:
	# Draw this pose: the pose it is made from, copied in to start from (P2).
	if not Tools.layer(doc, p).is_empty() or Tools.layer(doc, from).is_empty():
		say("Draw the %s first." % LayersPanel.part_name(doc.plan, from).to_lower())
		return
	Tools.act(doc, hist, [p], func(): return Tools.draw_pose(doc, p, from))
	pick_part(p)
	changed_parts([p])


func _sel_action(f: Callable) -> void:
	# A command on the selection, as one undo step.
	if sel.is_empty() or not editable(part):
		return
	hist.record(doc, [part])
	f.call()
	changed_parts([part])


func _one_or_all(each: Callable) -> void:
	# One shape on a symmetric layer: its twin follows. Otherwise each.
	if sel.size() == 1 and sym_here():
		var orig := Tools.layer(doc, part).duplicate(true)
		sel = [Tools.edit_one(doc, part, sel[0], orig, each.call(orig[sel[0]]), true)]
	else:
		var shapes := Tools.layer(doc, part).duplicate()
		for i in sel:
			shapes[i] = each.call(shapes[i])
		Tools.set_layer(doc, part, shapes)


func forward() -> void:
	_sel_action(func(): sel = Tools.forward(doc, part, sel))


func back() -> void:
	_sel_action(func(): sel = Tools.back(doc, part, sel))


func mirror() -> void:
	_sel_action(func():
		if sel.size() == 1:
			_one_or_all(func(s): return Tools.mirrored(s, Shapes.centre(s).x))
		else:
			Tools.mirror(doc, part, sel))


func duplicate_sel() -> void:
	if sel.is_empty() or not Tools.room(doc, part, sel.size() * 2):
		return
	_sel_action(func():
		sel = Tools.duplicate_shapes(doc, part, sel)
		_twin_new())


func _twin_new() -> void:
	# A single new shape on a symmetric layer gets its twin.
	if sel.size() == 1 and sym_here():
		var r := Tools.mirror_edit(Tools.layer(doc, part), sel[0], {})
		Tools.set_layer(doc, part, r.shapes)
		sel = [r.i]


func delete_sel() -> void:
	_sel_action(func():
		Tools.delete(doc, part, Tools.with_twins(doc, part, sel) if sym_here() else sel)
		sel = [])


func nudge(dir: Vector2, big: bool) -> void:
	_sel_action(func(): _one_or_all(func(s): return Tools.moved(s, dir * (Tools.NUDGE_BIG if big else 1.0))))


func copy_sel() -> void:
	if sel.is_empty():
		return
	clip = Tools.copy(doc, part, sel)
	clip_from = part
	say("Copied %d shape%s. Paste them on any layer." % [clip.size(), "" if clip.size() == 1 else "s"])


func paste() -> void:
	if clip.is_empty() or not editable(part):
		return
	if not Tools.room(doc, part, clip.size()):
		say("That's as many shapes as a critter can have here.")
		return
	hist.record(doc, [part])
	sel = Tools.paste(doc, part, clip, clip_from == part)
	_twin_new()
	changed_parts([part])


func undo() -> void:
	var parts := hist.undo(doc)
	if not parts.is_empty():
		sel = []
		changed_parts(parts)


func redo() -> void:
	var parts := hist.redo(doc)
	if not parts.is_empty():
		sel = []
		changed_parts(parts)


func back_to_my_critters() -> void:
	hide()
	if main != null:
		main.open_settings("my_critters")


func key(e: InputEventKey) -> bool:
	# The shortcuts (the design's ? panel). True when one was used.
	var k := e.keycode
	if e.ctrl_pressed:
		match k:
			KEY_Z:
				if e.shift_pressed:
					redo()
				else:
					undo()
			KEY_Y:
				redo()
			KEY_D:
				duplicate_sel()
			KEY_C:
				copy_sel()
			KEY_V:
				paste()
			KEY_A:
				sel = range(Tools.layer(doc, part).size())
				selection_changed()
			_:
				return false
		return true
	var arrows := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
	if arrows.has(k):
		nudge(arrows[k], e.shift_pressed)
		return true
	var letters := {KEY_V: "move", KEY_E: "ellipse", KEY_R: "rect", KEY_T: "tri", KEY_D: "drop", KEY_H: "heart",
		KEY_S: "star", KEY_B: "blob", KEY_L: "stroke", KEY_I: "eye"}
	if letters.has(k):
		set_tool(letters[k])
		return true
	match k:
		KEY_DELETE, KEY_BACKSPACE:
			delete_sel()
		KEY_PAGEUP:
			forward()
		KEY_PAGEDOWN:
			back()
		KEY_M:
			mirror()
		KEY_0:
			canvas.fit()
		KEY_ESCAPE:
			if sel.is_empty() and tool == "move":
				hide()
			sel = []
			set_tool("move")
			selection_changed()
		_:
			return false
	return true
