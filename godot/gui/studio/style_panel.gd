extends RefCounted
## The Studio's colour panel (docs/custom-critters-build-plan.md, D4;
## design/studio/builder/Builder.html, the right column's top): the A2
## picker laid flat for the picked shapes (From the critters, In this
## critter, Used lately, the square, the hue strip and hex), Outline and
## Marking for them, and for the whole critter Blush and the eyes (the
## engine's presets: big, round, dot and lash, shape_svg.gd eye()).
##
## The outline's colour and width are the cast's and can't be changed: that
## is what keeps homemade critters looking as if they belong.
##
## The doc changes go through studio_window.gd, as one undo step each (a drag
## on the picker is one step: it records once until the selection changes).
## palette() and set_eyes() are plain functions, tested headless.

const Picker := preload("res://gui/colour_picker.gd")
const Shapes := preload("res://studio/shapes.gd")
const Writer := preload("res://studio/shape_svg.gd")
const Tools := preload("res://gui/studio/tools.gd")
const LP := preload("res://gui/studio/layers_panel.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")

const EYE_NAMES := {"big": "Big", "round": "Round", "dot": "Dot", "lash": "Lash"}
const MAX_MINE := 16

var st: Window                     # studio_window.gd
var picker: Picker
var _quiet := false


func _init(studio: Window) -> void:
	st = studio


# --- The data ---------------------------------------------------------------------------

static func palette(doc: Dictionary) -> Array:
	# The colours used in this critter, most used first, each once.
	var n := {}
	for part in doc.layers:
		for s in doc.layers[part]:
			n[s.fill] = int(n.get(s.fill, 0)) + 1
	var out: Array = n.keys()
	out.sort_custom(func(a, b): return n[a] > n[b] or (n[a] == n[b] and a < b))
	return out.slice(0, MAX_MINE)


static func eye_preset(doc: Dictionary) -> String:
	# The eyes' preset (the first eye's), or "big" with none drawn.
	for part in doc.layers:
		for s in doc.layers[part]:
			if s.t == "eye":
				return s.preset
	return "big"


static func eye_parts(doc: Dictionary) -> Array:
	return doc.layers.keys().filter(func(p): return doc.layers[p].any(func(s): return s.t == "eye"))


static func set_eyes(doc: Dictionary, preset: String) -> Array:
	# Every eye in the critter in this preset. Returns the layers changed.
	var parts := eye_parts(doc)
	for p in parts:
		var shapes: Array = doc.layers[p].duplicate(true)
		for s in shapes:
			if s.t == "eye":
				s.preset = preset
		doc.layers[p] = shapes
	return parts


# --- Drawing it -------------------------------------------------------------------------

func build() -> Control:
	var c := K.c
	var v := K.vbox(8)
	var shapes := Tools.layer(st.doc, st.part)
	var sel: Array = st.sel.filter(func(i): return i < shapes.size())
	var head := K.hbox(8)
	head.add_child(UI.label("Colour", 15, c.ink, 600, true))
	var what := "pick a shape to colour it"
	if sel.size() == 1:
		what = "for the %s %s" % [LP.part_name(st.doc.plan, st.part).to_lower(), st.SHAPE_NAMES.get(shapes[sel[0]].t, "shape")]
	elif sel.size() > 1:
		what = "for %d shapes" % sel.size()
	var wl := UI.label(what, 12, c.ink3, 700)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wl.clip_text = true
	head.add_child(wl)
	v.add_child(head)
	if sel.is_empty():
		picker = null
		var note := UI.wrap("Click a shape on the canvas, then pick its colour here. A marking (a belly or a spot) stays inside the shapes under it.", 12, c.ink3, st.SIDE_W - 40)
		v.add_child(K.margins(note, 0, 4, 0, 8))
	else:
		var first: Dictionary = shapes[sel[0]]
		_quiet = true
		picker = Picker.new(first.fill)
		_quiet = false
		picker.add_theme_constant_override("separation", 6)
		# In this critter, after From the critters (the picker's first two rows).
		var mine := palette(st.doc)
		if not mine.is_empty():
			var lab := UI.label("In this critter", 13, c.ink2, 700)
			picker.add_child(lab)
			picker.move_child(lab, 2)
			var grid: Control = picker._swatch_grid(mine)
			picker.add_child(grid)
			picker.move_child(grid, 3)
		picker._sv.custom_minimum_size = Vector2(st.SIDE_W - 40, 96)
		picker._hue.custom_minimum_size.x = st.SIDE_W - 40
		picker.changed.connect(func(hex: String):
			if not _quiet:
				st.set_fill(hex))
		v.add_child(picker)
		var opts := K.hbox(10)
		var eyes_only := sel.all(func(i): return shapes[i].t == "eye")
		var line_on: bool = sel.all(func(i): return shapes[i].line)
		var inside_on: bool = sel.all(func(i): return shapes[i].inside)
		var ol := _opt("Outline", "Brown edge", "The brown edge round the outside, like the cast's", line_on, func(on): st.set_shape_flag("line", on))
		if eyes_only:
			ol.modulate.a = 0.4
			ol.tooltip_text = "Eyes have no outline."
			for ch in ol.get_children():
				if ch is Control:
					(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		opts.add_child(ol)
		opts.add_child(_opt("Marking", "Stays inside", "A marking is clipped to the shapes under it: bellies, spots, stripes", inside_on, func(on): st.set_shape_flag("inside", on)))
		v.add_child(opts)
	v.add_child(_rule())
	var wh := K.hbox(8)
	wh.add_child(UI.label("The whole critter", 15, c.ink, 600, true))
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(g)
	wh.add_child(UI.label("Blush", 13, c.ink2, 800))
	var bl := K.toggle(bool(st.doc.style.blush), "Blush", func(on): st.set_blush(on))
	bl.tooltip_text = "Rosy cheeks under the eyes"
	wh.add_child(bl)
	v.add_child(wh)
	var eyes := K.hbox(6)
	var now := eye_preset(st.doc)
	var any_eyes := not eye_parts(st.doc).is_empty()
	for p in Shapes.EYE_PRESETS:
		eyes.add_child(_eye_button(p, p == now, any_eyes))
	v.add_child(eyes)
	return v


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = K.c.div
	r.custom_minimum_size.y = 2
	return K.margins(r, 0, 4, 0, 4)


func _opt(title: String, sub: String, tip: String, on: bool, cb: Callable) -> Control:
	var c := K.c
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.tooltip_text = tip
	p.add_theme_stylebox_override("panel", K.box(c.ground, 12, c.line, 2))
	var h := K.hbox(6)
	var t := K.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label(title, 13, c.ink, 800))
	t.add_child(UI.label(sub, 11, c.ink3, 700))
	h.add_child(t)
	var tg := K.toggle(on, title, cb)
	tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tg)
	p.add_child(K.margins(h, 10, 6, 8, 6))
	return p


func _eye_button(preset: String, on: bool, enabled: bool) -> Button:
	var c := K.c
	var b := Button.new()
	b.text = EYE_NAMES[preset]
	b.tooltip_text = "Every eye %s" % EYE_NAMES[preset].to_lower() if enabled else "Draw the eyes first"
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 58
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.icon = eye_icon(preset)
	b.add_theme_font_override("font", UI.font(800))
	b.add_theme_font_size_override("font_size", 11)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, c.ink if on else c.ink2)
	var n := K.box(c.chip_sel if on else c.ground, 12, c.outline if on else c.line, 2, c.lip, 2 if on else 0)
	var hv := n.duplicate()
	if not on:
		hv.bg_color = c.track
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("disabled", n)
	b.pressed.connect(func(): st.set_eye_preset(preset))
	return b


static func eye_icon(preset: String) -> ImageTexture:
	# The preset as the engine draws it.
	var s := Shapes.clean({"t": "eye", "preset": preset, "x": 13, "y": 14, "w": 14, "h": 18, "fill": Tools.EYE_FILL})
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 26 28" width="26" height="28">%s</svg>' % Writer.eye(s)
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	return ImageTexture.create_from_image(img)
