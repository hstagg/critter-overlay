extends RefCounted
## The design's controls, built from Godot nodes (design/gui/parts.py is the
## source: .row, .tg, .seg, .rng, .btn, .chip, .kbd, .dd, .nav, .card).
##
## Set `c` (Palette.colours) before building; every builder reads it.

const Palette := preload("res://gui/palette.gd")
const Icons := preload("res://gui/icons.gd")
const UI := preload("res://gui/ui.gd")

static var c := {}
static var dark := false


static func box(bg: Color, radius: int, border := Color.TRANSPARENT, bw := 0, lip := Color.TRANSPARENT, lip_px := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = true
	if lip_px > 0:
		s.shadow_color = lip
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, lip_px)
	return s


static func margins(node: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(node)
	return m


static func vbox(sep := 0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


# --- Page structure ---------------------------------------------------------------

static func section(label: String, inner: Control, note := "") -> Control:
	var v := vbox(10)
	var head := hbox(10)
	head.add_child(margins(UI.label(label.to_upper(), 13, c.acc_ink, 500, true), 6, 0, 0, 0))
	if note != "":
		head.add_child(UI.label(note, 13, c.ink3, 700))
	v.add_child(head)
	v.add_child(inner)
	return v


static func card(rows: Array, pad := 0) -> PanelContainer:
	# A card of rows with a divider between each.
	var p := PanelContainer.new()
	var s := box(c.surface, 20, c.line, 2)
	s.set_content_margin_all(maxi(pad, 2))   # never over the border
	p.add_theme_stylebox_override("panel", s)
	var v := vbox(0)
	p.add_child(v)
	for i in rows.size():
		if i > 0:
			v.add_child(divider())
		v.add_child(rows[i])
	return p


static func divider() -> Control:
	var d := Panel.new()
	d.custom_minimum_size.y = 2
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_theme_stylebox_override("panel", box(c.div, 0))
	return d


static func row(title: String, desc: String, control: Control, tip := "", pill: Control = null) -> Control:
	var h := hbox(24)
	var text := vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := hbox(6)
	t.add_child(UI.label(title, 15, c.ink, 800))
	if tip != "":
		t.add_child(info(tip))
	if pill != null:
		t.add_child(pill)
	text.add_child(t)
	if desc != "":
		var d := UI.label(desc, 13, c.ink2, 400)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 200
		text.add_child(d)
	h.add_child(text)
	if control != null:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(control)
	return margins(h, 20, 16, 20, 16)


static func info(tip: String) -> Control:
	var r := UI.icon(Icons.line("info", 16, c.ink3))
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.tooltip_text = tip
	r.mouse_default_cursor_shape = Control.CURSOR_HELP
	return r


static func pill(text: String, bg: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, 11)
	s.content_margin_left = 9
	s.content_margin_right = 9
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(UI.label(text, 11, fg, 800))
	return p


static func new_pill() -> PanelContainer:
	var t := Palette.tier("uncommon", dark)
	return pill("New", t.tint, t.ink)


static func soon_pill() -> PanelContainer:
	return pill("Coming soon", c.track, c.acc_ink)


static func value_label(text: String, width := 84) -> Label:
	var l := UI.label(text, 16, c.acc_ink, 600, true)
	l.custom_minimum_size.x = width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


# --- Toggle -------------------------------------------------------------------------

class Toggle extends Control:
	signal toggled(on: bool)
	var on := false
	var cs := {}
	func _init(state: bool, colours: Dictionary, aria: String) -> void:
		on = state
		cs = colours
		custom_minimum_size = Vector2(48, 28)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL
		tooltip_text = ""
		set_meta("aria", aria)
	func _gui_input(e: InputEvent) -> void:
		var hit: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventKey and e.pressed and e.keycode in [KEY_SPACE, KEY_ENTER])
		if hit:
			on = not on
			queue_redraw()
			toggled.emit(on)
			accept_event()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(48, 28))
		var track := StyleBoxFlat.new()
		track.set_corner_radius_all(14)
		track.bg_color = cs.accent if on else cs.track
		track.border_color = cs.outline if on else cs.off_line
		track.set_border_width_all(2)
		track.anti_aliasing = true
		draw_style_box(track, r)
		var knob := StyleBoxFlat.new()
		knob.set_corner_radius_all(10)
		knob.bg_color = cs.knob
		knob.border_color = cs.outline if on else cs.off_line
		knob.set_border_width_all(2)
		knob.anti_aliasing = true
		draw_style_box(knob, Rect2(Vector2(22 if on else 4, 4), Vector2(20, 20)))
		if has_focus():
			var f := StyleBoxFlat.new()
			f.draw_center = false
			f.set_corner_radius_all(17)
			f.border_color = cs.acc_ink
			f.set_border_width_all(2)
			draw_style_box(f, r.grow(3))


static func toggle(on: bool, aria: String, on_change: Callable) -> Toggle:
	var t := Toggle.new(on, c, aria)
	t.toggled.connect(on_change)
	return t


# --- Segmented choice ---------------------------------------------------------------

static func seg(options: Array, selected: int, on_pick: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(c.track, 14)
	s.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", s)
	var h := hbox(2)
	p.add_child(h)
	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size.y = 32
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sel := i == selected
		var normal := box(c.raised if sel else Color.TRANSPARENT, 11, c.outline if sel else Color.TRANSPARENT, 2, c.lip, 2 if sel else 0)
		normal.content_margin_left = 13
		normal.content_margin_right = 13
		var hover := normal.duplicate()
		if not sel:
			hover.bg_color = c.nav_h
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", normal)
		b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, 11, c.acc_ink, 2))
		b.add_theme_font_override("font", UI.font(800))
		b.add_theme_font_size_override("font_size", 13)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, c.ink if sel else c.ink2)
		var idx := i
		b.pressed.connect(func(): on_pick.call(idx))
		h.add_child(b)
	return p


# --- Sliders ------------------------------------------------------------------------

static func _knob_texture() -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 26 28" width="26" height="28"><circle cx="13" cy="15" r="11.5" fill="#%s"/><circle cx="13" cy="13" r="10.5" fill="#%s" stroke="#%s" stroke-width="3"/></svg>' % [
		c.lip.to_html(false), c.knob.to_html(false), c.outline.to_html(false)]
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	return ImageTexture.create_from_image(img)


static func slider(value: float, lo: float, hi: float, step: float, width: int, on_change: Callable) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.custom_minimum_size = Vector2(width, 28)
	sl.focus_mode = Control.FOCUS_ALL
	sl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := box(c.line, 5)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := box(c.accent, 5)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	for k in ["grabber", "grabber_highlight", "grabber_disabled"]:
		sl.add_theme_icon_override(k, knob)
	sl.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, 8, c.acc_ink, 2))
	sl.value_changed.connect(on_change)
	return sl


static func slider_row_control(sl: HSlider, lo_text: String, hi_text: String, val: Label) -> Control:
	# The slider with its end labels under it, and the value to its right.
	var h := hbox(16)
	var v := vbox(4)
	v.add_child(sl)
	if lo_text != "":
		var ticks := hbox(0)
		var a := UI.label(lo_text, 11, c.ink3, 600)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ticks.add_child(a)
		ticks.add_child(UI.label(hi_text, 11, c.ink3, 600))
		v.add_child(ticks)
	h.add_child(v)
	if val != null:
		h.add_child(val)
	return h


static func stepped(labels: Array, idx: int, on_pick: Callable) -> Control:
	# A slider that snaps to named stops, with the stops written under it.
	var v := vbox(4)
	var ticks := hbox(0)
	var sl := slider(idx, 0, labels.size() - 1, 1, 0, func(x):
		on_pick.call(int(x))
		for i in ticks.get_child_count():
			var l: Label = ticks.get_child(i)
			var on := i == int(x)
			l.add_theme_color_override("font_color", c.acc_ink if on else c.ink3)
			l.add_theme_font_override("font", UI.font(800 if on else 600)))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(sl)
	for i in labels.size():
		var l := UI.label(str(labels[i]), 11, c.acc_ink if i == idx else c.ink3, 800 if i == idx else 600)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else (HORIZONTAL_ALIGNMENT_RIGHT if i == labels.size() - 1 else HORIZONTAL_ALIGNMENT_CENTER)
		ticks.add_child(l)
	v.add_child(ticks)
	return v


# --- Buttons, chips, keys -------------------------------------------------------------

static func button(text: String, kind := "bs", icon := "", small := false, on_press := Callable()) -> Button:
	# bp primary, bs secondary, bq quiet, bd danger.
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 34 if small else 40
	var r := 12 if small else 14
	var bg: Color = {"bp": c.btn, "bs": c.raised, "bq": Color.TRANSPARENT, "bd": c.dng_bg}[kind]
	var ink: Color = {"bp": c.btn_ink, "bs": c.ink, "bq": c.ink2, "bd": c.dng_ink}[kind]
	var line: Color = {"bp": c.btn_lip, "bs": c.sec_line, "bq": Color.TRANSPARENT, "bd": c.dng_line}[kind]
	var lip := 3 if kind == "bp" else (0 if kind == "bq" else 2)
	var normal := box(bg, r, line, 2, line, lip)
	normal.content_margin_left = 12 if small else 16
	normal.content_margin_right = 12 if small else 16
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.06) if kind != "bq" else c.track
	var pressed := normal.duplicate()
	pressed.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, r, c.acc_ink, 2))
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_font_override("font", UI.font(800))
	b.add_theme_font_size_override("font_size", 13 if small else 14)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, ink)
	if icon != "":
		b.icon = Icons.line(icon, 18, ink)
		b.add_theme_constant_override("h_separation", 8)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func icon_button(icon: String, tip: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.icon = Icons.line(icon, 16, c.outline)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(36, 36)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var n := box(c.raised, 12, c.sec_line, 2, c.sec_line, 2)
	b.add_theme_stylebox_override("normal", n)
	var hv := n.duplicate()
	hv.bg_color = c.raised.lightened(0.06)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, 12, c.acc_ink, 2))
	b.pressed.connect(on_press)
	return b


static func chip(text: String, selected: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size.y = 32
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var n := box(c.chip_sel if selected else c.raised, 16, c.outline if selected else c.chip_line, 2, c.lip, 2 if selected else 0)
	n.content_margin_left = 12
	n.content_margin_right = 12
	var hv := n.duplicate()
	if not selected:
		hv.bg_color = c.nav_h
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, 16, c.acc_ink, 2))
	b.add_theme_font_override("font", UI.font(700))
	b.add_theme_font_size_override("font_size", 13)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, c.ink if selected else c.ink_body)
	b.pressed.connect(on_press)
	return b


static func keys(names: PackedStringArray) -> Control:
	var h := hbox(6)
	for i in names.size():
		if i > 0:
			h.add_child(UI.label("+", 13, c.ink3, 800))
		var k := PanelContainer.new()
		var s := box(c.raised, 9, c.sec_line, 2, c.sec_line, 2)
		s.content_margin_left = 9
		s.content_margin_right = 9
		s.content_margin_top = 3
		s.content_margin_bottom = 3
		k.add_theme_stylebox_override("panel", s)
		k.custom_minimum_size = Vector2(30, 30)
		var l := UI.label(names[i], 13, c.ink, 800)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k.add_child(l)
		h.add_child(k)
	return h


static func dropdown(options: Array, selected: int, on_pick: Callable, icons: Array = []) -> OptionButton:
	var o := OptionButton.new()
	for i in options.size():
		if i < icons.size() and icons[i] != null:
			o.add_icon_item(icons[i], str(options[i]), i)
		else:
			o.add_item(str(options[i]), i)
	o.selected = selected
	o.focus_mode = Control.FOCUS_ALL
	o.custom_minimum_size = Vector2(150, 38)
	o.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var n := box(c.raised, 12, c.sec_line, 2)
	n.content_margin_left = 14
	n.content_margin_right = 12
	o.add_theme_stylebox_override("normal", n)
	var hv := n.duplicate()
	hv.bg_color = c.raised.lightened(0.05)
	o.add_theme_stylebox_override("hover", hv)
	o.add_theme_stylebox_override("pressed", n)
	o.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, 12, c.acc_ink, 2))
	o.add_theme_font_override("font", UI.font(800))
	o.add_theme_font_size_override("font_size", 14)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		o.add_theme_color_override(k, c.ink)
	o.add_theme_icon_override("arrow", Icons.line("chevd", 16, c.ink2))
	var pop := o.get_popup()
	pop.add_theme_stylebox_override("panel", box(c.surface, 12, c.line, 2))
	pop.add_theme_stylebox_override("hover", box(c.nav_h, 8))
	pop.add_theme_font_override("font", UI.font(700))
	pop.add_theme_font_size_override("font_size", 14)
	pop.add_theme_color_override("font_color", c.ink)
	pop.add_theme_color_override("font_hover_color", c.ink)
	o.item_selected.connect(on_pick)
	return o


static func stepper(text: String, on_minus: Callable, on_plus: Callable) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(c.raised, 14, c.sec_line, 2))
	var h := hbox(0)
	p.add_child(h)
	var mk := func(icon: String, tip: String, cb: Callable) -> Button:
		var b := Button.new()
		b.icon = Icons.line(icon, 16, c.outline)
		b.tooltip_text = tip
		b.custom_minimum_size = Vector2(40, 36)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", box(c.ground, 12))
		b.add_theme_stylebox_override("hover", box(c.nav_h, 12))
		b.add_theme_stylebox_override("pressed", box(c.track, 12))
		b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, 12, c.acc_ink, 2))
		b.pressed.connect(cb)
		return b
	h.add_child(mk.call("minus", "Fewer", on_minus))
	var l := UI.label(text, 14, c.ink, 800)
	l.custom_minimum_size.x = 96
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.add_child(mk.call("plus", "More", on_plus))
	return p
