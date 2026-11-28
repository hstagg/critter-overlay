extends VBoxContainer
## The colour picker (docs/custom-critters-build-plan.md, P19): swatches from
## the cast's own art, the colours picked lately, a saturation and value
## square, a hue strip and a hex field. It answers with a "#RRGGBB".
##
## Picker.open() shows it in a dialog and calls back with the colour when the
## player presses Use this colour. The recent colours last for the session
## only (decision 2026-11-26): where they are kept for good is settled in D4,
## when the Shape Builder is the picker's main user.

const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")

# The fills the cast is drawn with most (art/<species>/*.svg), light to dark.
const SWATCHES := ["#FFFFFF", "#FFF1E2", "#FBF4EC", "#E9DED3", "#F9DDBF", "#FFE07A", "#F6C28F", "#F7A04A",
	"#E0823F", "#F7A9A2", "#F59C9C", "#A9D99B", "#8CC46C", "#A98468", "#6B4A3A", "#3B3437"]
const MAX_RECENT := 12
const PAD := Vector2(232, 150)

signal changed(hex: String)

static var recent: Array = []   # "#RRGGBB", newest first, this session only

var h := 0.0
var s := 0.0
var v := 1.0
var _sv: Pad
var _hue: Pad
var _field: LineEdit
var _now: Panel


static func parse_hex(t: String) -> String:
	# "#RRGGBB" in capitals for "#abc", "abc", "#aabbcc" or "aabbcc", else "".
	var x := t.strip_edges().trim_prefix("#").to_upper()
	if x.length() == 3:
		x = x[0] + x[0] + x[1] + x[1] + x[2] + x[2]
	if x.length() != 6:
		return ""
	for ch in x:
		if not ch in "0123456789ABCDEF":
			return ""
	return "#" + x


static func to_hex(col: Color) -> String:
	return "#" + col.to_html(false).to_upper()


static func remember(hex: String) -> void:
	# The newest first, each once, MAX_RECENT at most.
	var x := parse_hex(hex)
	if x == "":
		return
	recent.erase(x)
	recent.push_front(x)
	if recent.size() > MAX_RECENT:
		recent.resize(MAX_RECENT)


static func open(parent: Node, start: String, on_pick: Callable) -> AcceptDialog:
	# The picker in a dialog. on_pick gets the "#RRGGBB" when it is used.
	var c := K.c
	var d := AcceptDialog.new()
	d.title = "Pick a colour"
	d.ok_button_text = "Use this colour"
	d.add_cancel_button("Cancel")
	d.add_theme_stylebox_override("panel", K.box(c.surface, 0))
	var p = load("res://gui/colour_picker.gd").new(start)
	d.add_child(p)
	d.set_meta("picker", p)
	d.confirmed.connect(func():
		remember(p.hex())
		on_pick.call(p.hex())
		d.queue_free())
	d.canceled.connect(d.queue_free)
	parent.add_child(d)
	d.popup_centered()
	return d


func _init(start := "") -> void:
	var c := K.c
	add_theme_constant_override("separation", 12)
	var col := Color.html(parse_hex(start)) if parse_hex(start) != "" else Color.html(SWATCHES[6])
	h = col.h
	s = col.s
	v = col.v

	add_child(UI.label("From the critters", 13, c.ink2, 700))
	add_child(_swatch_grid(SWATCHES))
	if not recent.is_empty():
		add_child(UI.label("Used lately", 13, c.ink2, 700))
		add_child(_swatch_grid(recent))

	_sv = Pad.new()
	_sv.custom_minimum_size = PAD
	_sv.on_move = func(p: Vector2):
		s = p.x
		v = 1.0 - p.y
		_show(true)
	add_child(_sv)
	_hue = Pad.new()
	_hue.one_d = true
	_hue.custom_minimum_size = Vector2(PAD.x, 18)
	_hue.tex = _hue_texture()
	_hue.on_move = func(p: Vector2):
		h = p.x
		_sv.tex = _sv_texture(h)
		_show(true)
	add_child(_hue)

	var row := K.hbox(10)
	_now = Panel.new()
	_now.custom_minimum_size = Vector2(38, 38)
	row.add_child(_now)
	_field = K.text_field("", "#RRGGBB", 7, func(t):
		var x := parse_hex(t)
		if x != "":
			set_hex(x, false))
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_field)
	add_child(row)
	_sv.tex = _sv_texture(h)
	_show(false)


func hex() -> String:
	return to_hex(Color.from_hsv(h, s, v))


func set_hex(x: String, write_field := true) -> void:
	var col := Color.html(parse_hex(x)) if parse_hex(x) != "" else Color.WHITE
	# A grey has no hue of its own: keep the strip where it was.
	if col.s > 0.0 and col.v > 0.0:
		h = col.h
	s = col.s
	v = col.v
	_sv.tex = _sv_texture(h)
	_show(write_field)


func _show(write_field: bool) -> void:
	var col := Color.from_hsv(h, s, v)
	_sv.at = Vector2(s, 1.0 - v)
	_hue.at = Vector2(h, 0.5)
	_sv.queue_redraw()
	_hue.queue_redraw()
	_now.add_theme_stylebox_override("panel", K.box(col, 12, K.c.sec_line, 2))
	if write_field and _field != null:
		_field.text = hex()
	changed.emit(hex())


func _swatch_grid(colours: Array) -> Control:
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for x in colours:
		var hx: String = x
		var b := Button.new()
		b.custom_minimum_size = Vector2(24, 24)
		b.tooltip_text = hx
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var n := K.box(Color.html(hx), 8, K.c.sec_line, 2)
		var hv := K.box(Color.html(hx), 8, K.c.outline, 2)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 8, K.c.acc_ink, 2))
		b.pressed.connect(func(): set_hex(hx))
		g.add_child(b)
	return g


static func _sv_texture(hue: float) -> ImageTexture:
	var img := Image.create(48, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 48:
			img.set_pixel(x, y, Color.from_hsv(hue, x / 47.0, 1.0 - y / 31.0))
	return ImageTexture.create_from_image(img)


static func _hue_texture() -> ImageTexture:
	var img := Image.create(120, 1, false, Image.FORMAT_RGB8)
	for x in 120:
		img.set_pixel(x, 0, Color.from_hsv(x / 119.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


class Pad extends Control:
	## A gradient picked by clicking or dragging: `at` is 0..1 on each axis.
	var tex: Texture2D
	var at := Vector2.ZERO
	var one_d := false
	var on_move: Callable

	func _init() -> void:
		mouse_default_cursor_shape = Control.CURSOR_CROSS
		clip_contents = true

	func _gui_input(e: InputEvent) -> void:
		var press: bool = e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed
		var drag: bool = e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if press or drag:
			move_to((e.position / size).clamp(Vector2.ZERO, Vector2.ONE))
			accept_event()

	func move_to(p: Vector2) -> void:
		if one_d:
			p.y = 0.5
		at = p
		queue_redraw()
		if on_move.is_valid():
			on_move.call(p)

	func _draw() -> void:
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		var m := at * size
		if one_d:
			draw_rect(Rect2(m.x - 3, 1, 6, size.y - 2), Color.WHITE, false, 2.0)
		else:
			draw_arc(m, 8.0, 0, TAU, 24, Color(0, 0, 0, 0.5), 1.0, true)
			draw_arc(m, 6.5, 0, TAU, 24, Color.WHITE, 2.5, true)
