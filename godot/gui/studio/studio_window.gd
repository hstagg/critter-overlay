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
## it, and the right column: the colour panel (style_panel.gd, D4) and the
## live preview (preview.gd, D6). In Pins mode the layers give way to the
## joints (pins_panel.gd) and the canvas drags them. Save opens a short
## dialog over the window (save_panel.gd); so does leaving with changes.
## Opened with nothing to build, it shows the Start page (start_page.gd, D5).
##
## The window holds the doc being built (shapes.json, 5.3) and the history;
## every change goes through tools.gd. Shortcuts are the design's ? panel's.
## Leaving (My critters, the close button, Esc) asks first if anything has
## changed since it was saved, and then forgets the doc, so the next visit
## starts on the Start page.

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
const KitData := preload("res://critters/kit/kit_data.gd")
const StylePanel := preload("res://gui/studio/style_panel.gd")
const PinsPanel := preload("res://gui/studio/pins_panel.gd")
const Preview := preload("res://gui/studio/preview.gd")
const SavePanel := preload("res://gui/studio/save_panel.gd")
const StartPage := preload("res://gui/studio/start_page.gd")
const Picker := preload("res://gui/colour_picker.gd")

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
var changed := false              # since it was last saved (or opened)
var starting := false              # the Start page is showing
var view_mode := "shapes"          # shapes | pins
var pin_sel := ""                  # the pin picked in Pins mode
var gait := ""                     # for Save: kit.json's gait
var size_i := 1                    # SavePanel.SIZES
var sound := "kitten"
var style: RefCounted
var pins_panel: RefCounted
var preview: Control
var overlay: Control               # the dialog over the window, or null
var _overlay_build := Callable()
var _style_box: VBoxContainer
var _save_b: Button
var _colour_key := ""              # the selection a picker drag is recording for
var _last_fill := ""
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
	close_requested.connect(func(): leave(Callable()))


static func fit_for(usable: Vector2, display: float) -> Dictionary:
	# The scale, the size to open at and the minimum size, in px, for a work
	# area: the display scale, smaller if the minimum would not fit.
	var f := minf(display, minf(usable.x * ROOM / MIN_W, usable.y * ROOM / MIN_H))
	var open := (Vector2(W, H) * f).min(usable * ROOM)
	return {"scale": f, "size": Vector2i(open), "min": Vector2i((Vector2(MIN_W, MIN_H) * f).ceil())}


func open(main_ref: Node, shapes_doc := {}, id := "") -> void:
	main = main_ref
	if visible and changed and id != "" and id == editing_id:
		pass                         # already open on it, with changes: kept
	elif not shapes_doc.is_empty() or (id != "" and id != editing_id):
		load_doc(shapes_doc, id)
		starting = false
	elif doc.is_empty():
		starting = true              # nothing to build: the Start page
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
	if canvas != null:
		canvas.grab_focus()


func load_doc(shapes_doc: Dictionary, id := "", starter_gait := "") -> void:
	# A starter, a saved critter's shapes.json, or {} for a blank side-on one.
	doc = Writer.clean_doc(shapes_doc).doc if not shapes_doc.is_empty() else Tools.blank()
	editing_id = id
	var d: Dictionary = Customs.all.get(id, {}) if id != "" else {}
	critter_name = str(d.get("name", ""))
	gait = str(d.get("_kit", {}).get("gait", starter_gait))
	if not gait in SavePanel.gaits(doc.plan):
		gait = SavePanel.gaits(doc.plan)[0]
	size_i = 1
	for i in SavePanel.SIZES.size():
		if absf(float(d.get("size", 1.0)) - SavePanel.SIZES[i][1]) < 0.01:
			size_i = i
	sound = str(d.get("sound", "kitten"))
	hist.clear()
	sel = []
	hidden.clear()
	locked.clear()
	changed = false
	view_mode = "shapes"
	pin_sel = ""
	_colour_key = ""
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
	overlay = null
	if starting:
		# The Start page: no canvas, nothing to undo or save.
		canvas = null
		_layers_box = null
		_ctx = null
		_rail = null
		_style_box = null
		_undo = null
		preview = null
		var sp: Control = StartPage.new(self).build()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(sp)
		add_child(_grip())
		return
	var body := K.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	layers = LayersPanel.new(self)
	style = StylePanel.new(self)
	pins_panel = PinsPanel.new(self)
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
	refresh_style()
	preview.restage()


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
	if starting:
		h.add_child(_grow(true))
		_window_buttons(h)
		return v
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
	var mode_seg := K.seg(["Shapes", "Pins"], 1 if view_mode == "pins" else 0, func(i): set_view_mode("pins" if i == 1 else "shapes"))
	mode_seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mode_seg.tooltip_text = "Shapes or Pins (P)"
	h.add_child(mode_seg)
	h.add_child(_grow(true))
	_undo = _ib("undo", "Undo (Ctrl+Z)", undo)
	_redo = _ib("redo", "Redo (Ctrl+Y)", redo)
	h.add_child(_undo)
	h.add_child(_redo)
	_save_b = K.button("Save", "bp", "", false, func(): open_save())
	_save_b.focus_mode = Control.FOCUS_NONE
	_save_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_save_b)
	h.add_child(_sep())
	_window_buttons(h)
	return v


func _window_buttons(h: HBoxContainer) -> void:
	for wb in [["min", "Minimise", func(): mode = Window.MODE_MINIMIZED],
			["max", "Maximise", func(): mode = Window.MODE_WINDOWED if mode == Window.MODE_MAXIMIZED else Window.MODE_MAXIMIZED],
			["close", "Close", func(): leave(Callable())]]:
		var b := _ib(wb[0], wb[1], wb[2])
		b.custom_minimum_size = Vector2(36, 32)
		h.add_child(b)


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
	# The colour panel (D4) over the live preview (D6). The colour panel
	# scrolls if the window is short.
	var c := K.c
	var p := PanelContainer.new()
	p.custom_minimum_size.x = SIDE_W
	p.add_theme_stylebox_override("panel", K.box(c.surface, 0))
	var v := K.vbox(10)
	p.add_child(K.margins(v, 12, 12, 12, 12))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.6
	_style_box = K.vbox(0)
	_style_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_style_box)
	v.add_child(scroll)
	var rule := ColorRect.new()
	rule.color = c.div
	rule.custom_minimum_size.y = 2
	v.add_child(rule)
	preview = Preview.new(self)
	v.add_child(preview)
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
	var p: Control = pins_panel.build() if view_mode == "pins" else layers.build()
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
	_top_note.text = ("Changed since you saved" if editing_id != "" else "Not saved yet") if changed else ""
	var need := LayersPanel.needed(doc)
	_save_b.disabled = not need.is_empty()
	_save_b.tooltip_text = "Save (Ctrl+S)" if need.is_empty() else (
		"%s more part%s and it can walk: %s." % [_count_word(need.size()), "" if need.size() == 1 else "s",
		", ".join(need.map(func(p): return LayersPanel.part_name(doc.plan, p).to_lower()))])


static func _count_word(n: int) -> String:
	return ["No", "One", "Two", "Three", "Four", "Five", "Six"][n] if n < 7 else str(n)


func refresh_style() -> void:
	# The colour panel, for the picked shapes. The colour a picker drag
	# left is remembered under Used lately.
	if _style_box == null:
		return
	if _last_fill != "":
		Picker.remember(_last_fill)
		_last_fill = ""
	_colour_key = ""
	for ch in _style_box.get_children():
		_style_box.remove_child(ch)
		ch.queue_free()
	if view_mode == "pins":
		var c := K.c
		var v := K.vbox(6)
		v.add_child(UI.label("Pins mode", 15, c.ink, 600, true))
		v.add_child(UI.wrap("Drag a dot on the canvas. Each pin stays inside its dashed box, so every move still looks like a critter. Watch the preview below to see if it looks right.", 12, c.ink2, SIDE_W - 40))
		_style_box.add_child(v)
		return
	_style_box.add_child(style.build())


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
	if parts.has("@style"):
		canvas.mark_all()
	canvas.mark(parts.filter(func(p): return not str(p).begins_with("@")))
	if final:
		sel = sel.filter(func(i): return i < Tools.layer(doc, part).size())
		refresh_layers()
		refresh_ctx()
		refresh_top()
		refresh_style()
		preview.changed()


func selection_changed(final := true) -> void:
	canvas.queue_redraw()
	if final:
		refresh_ctx()
		refresh_style()


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
	refresh_style()
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
	var eyes_now := StylePanel.eye_preset(doc)
	var i := Tools.place(doc, hist, part, t, at, sym_here())
	if t == "eye" and i >= 0:
		StylePanel.set_eyes(doc, eyes_now)   # a new eye matches the others
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
	leave(func():
		if main != null:
			main.open_settings("my_critters"))


func key(e: InputEventKey) -> bool:
	# The shortcuts (the design's ? panel). True when one was used.
	var k := e.keycode
	if overlay != null and k != KEY_ESCAPE:
		return false
	if e.ctrl_pressed:
		match k:
			KEY_S:
				open_save()
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
		KEY_P:
			set_view_mode("shapes" if view_mode == "pins" else "pins")
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
			if overlay != null:
				close_overlay()
				return true
			if sel.is_empty() and tool == "move":
				leave(Callable())
				return true
			sel = []
			set_tool("move")
			selection_changed()
		_:
			return false
	return true


# --- Colour and style (D4) ---------------------------------------------------------------

func set_fill(hex: String) -> void:
	# The picker moved: the picked shapes take its colour. A drag is one
	# undo step (recorded once for this selection).
	if sel.is_empty() or not editable(part):
		return
	var key := "%s:%s" % [part, sel]
	if key != _colour_key:
		hist.record(doc, [part])
		_colour_key = key
	_last_fill = hex
	_one_or_all(func(s):
		var o: Dictionary = s.duplicate(true)
		o.fill = hex
		return Shapes.clean(o))
	changed = true
	canvas.mark([part])
	refresh_top()
	preview.changed()


func set_shape_flag(flag: String, on: bool) -> void:
	# Outline ("line") or Marking ("inside") on the picked shapes.
	if sel.is_empty() or not editable(part):
		return
	_sel_action(func(): _one_or_all(func(s):
		var o: Dictionary = s.duplicate(true)
		o[flag] = on
		return Shapes.clean(o)))


func set_blush(on: bool) -> void:
	hist.record(doc, ["@style"])
	doc.style.blush = on
	changed_parts(["@style"])


func set_eye_preset(preset: String) -> void:
	var parts := StylePanel.eye_parts(doc)
	if parts.is_empty():
		return
	hist.record(doc, parts)
	StylePanel.set_eyes(doc, preset)
	changed_parts(parts)


# --- Pins (D6) --------------------------------------------------------------------------

func set_view_mode(m: String) -> void:
	if m == view_mode or canvas == null:
		return
	view_mode = m
	sel = []
	pin_sel = ""
	if m == "pins":
		set_tool("move")
	build()


func pick_pin(p: String) -> void:
	pin_sel = p
	# The pose the joint is seen in.
	pose = "sit" if p in ["neck-sit", "wing-l", "tuft"] else "walk"
	refresh_layers()
	canvas.queue_redraw()


func pins_changed(final := true) -> void:
	# A pin was dragged (or put back).
	changed = true
	canvas.queue_redraw()
	if final:
		refresh_layers()
		refresh_top()
		preview.changed()


func reset_pins(p: String) -> void:
	if doc.pins.is_empty():
		return
	hist.record(doc, ["@pins"])
	PinsPanel.reset(doc, p)
	pins_changed()


# --- Saving and leaving (D6) ---------------------------------------------------------------

func open_save(after := Callable()) -> void:
	# The Save dialog, if every needed part is drawn.
	if starting or canvas == null:
		return
	var need := LayersPanel.needed(doc)
	if not need.is_empty():
		say("Draw the needed parts first: %s." % ", ".join(need.map(func(p): return LayersPanel.part_name(doc.plan, p).to_lower())))
		return
	var sp := SavePanel.new(self, after)
	show_overlay(sp.build)


func show_overlay(make: Callable) -> void:
	# A dialog over the window: a scrim and a card, built by make().
	close_overlay()
	_overlay_build = make
	var c := K.c
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.32)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", K.box(c.surface, 22, c.outline, 2, c.lip, 4))
	card.add_child(K.margins(make.call(), 26, 22, 26, 22))
	centre.add_child(card)
	add_child(overlay)


func rebuild_overlay() -> void:
	# The dialog drawn again (a choice in it changed).
	if overlay != null and _overlay_build.is_valid():
		show_overlay(_overlay_build)


func close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null
	_overlay_build = Callable()


func kept(id: String, send: bool, after: Callable) -> void:
	# After Keep: saved, on the desk if asked, and the critters already out
	# drawn again with the new art.
	if id == "":
		close_overlay()
		say("It couldn't be saved. Check every needed part is drawn.")
		return
	var was := editing_id
	editing_id = id
	changed = false
	close_overlay()
	refresh_top()
	if main != null:
		if was != "":
			main.refresh_homemade(id)
		if send:
			main.spawn_homemade(id)
		if main.get("toasts") != null:
			var img := Image.load_from_file(Customs.thumb(id)) if FileAccess.file_exists(Customs.thumb(id)) else null
			var icon: Texture2D = ImageTexture.create_from_image(img) if img != null else Icons.berry(40)
			if send:
				main.toasts.show_note(icon, "Saved", "%s is on your desk" % critter_name, "It visits with the rest from now on. Click it to say hello.")
			else:
				main.toasts.show_note(icon, "Saved", "%s is saved" % critter_name, "It's in My critters, and visits with the rest.")
	if after.is_valid():
		after.call()


func leave(then: Callable) -> void:
	# Going back or closing: with changes since it was saved, ask first
	# (Save and go back, Don't save, Stay here).
	if not changed or starting or canvas == null:
		_go(then)
		return
	show_overlay(func() -> Control:
		var c := K.c
		var v := K.vbox(12)
		v.custom_minimum_size.x = 460
		var who := critter_name if critter_name != "" else "your critter"
		v.add_child(UI.label("Save your changes to %s?" % who, 22, c.ink, 600, true))
		var why := "You've changed %s since you last saved. If you go back without saving, those changes are lost." % who if editing_id != "" \
			else "%s hasn't been saved yet. If you go back without saving, it's lost." % who.capitalize()
		v.add_child(UI.wrap(why, 13, c.ink2, 440))
		var bar := K.hbox(10)
		bar.add_child(K.button("Stay here", "bq", "", false, close_overlay))
		var g := Control.new()
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(g)
		bar.add_child(K.button("Don't save", "bs", "", false, func():
			close_overlay()
			_go(then)))
		var save_b := K.button("Save and go back", "bp", "check", false, func():
			close_overlay()
			open_save(func(): _go(then)))
		save_b.disabled = not LayersPanel.needed(doc).is_empty()
		bar.add_child(save_b)
		v.add_child(bar)
		return v)


func _go(then: Callable) -> void:
	# Leaves: the window hides and forgets the doc.
	forget()
	hide()
	if then.is_valid():
		then.call()


func forget() -> void:
	close_overlay()
	if preview != null:
		preview.clear()
	doc = {}
	editing_id = ""
	critter_name = ""
	changed = false
	hist.clear()


# --- Starting (D5) -------------------------------------------------------------------------

func start_from(file: String) -> void:
	var s := StartPage.starter(file)
	if s.is_empty():
		return
	load_doc(s.doc, "", s.gait)
	starting = false
	build()
	if canvas != null:
		canvas.grab_focus()


func start_blank(plan: String) -> void:
	load_doc(Tools.blank(plan))
	starting = false
	build()
