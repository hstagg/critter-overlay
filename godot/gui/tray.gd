extends Node
## The tray icon and its panel (design: "Tray panel and icon" artboard).
##
## The icon sits in the Windows notification area and shows the state:
## working, paused (grey, a pause badge) or napping (closed eyes, a zz badge).
## A left or right click opens the panel just above it; a double click opens
## Settings. The panel is a small borderless popup window that closes when
## anything else is clicked, and follows Windows' light or dark mode.
##
## main.gd feeds it with update() and listens to the signals.

signal spawn_pressed
signal pause_pressed
signal collection_pressed
signal settings_pressed
signal quit_pressed

const Palette := preload("res://gui/palette.gd")
const Icons := preload("res://gui/icons.gd")

const PANEL_W := 312
const MARGIN := 12             # px between the panel and the taskbar
const DOUBLE_CLICK_S := 0.35

var info := {
	"mode": "running",         # running | paused | napping
	"out": 0,                  # critters on screen
	"focus_min": 0.0,          # session focus time
	"gift_min": 0.0,           # minutes to the next gift, or -1 when none are left
	"gift_progress": 0.0,      # 0..1 for the bar
	"away_min": 0.0,
	"found": 0,
	"found_total": 48,
	"berries": 0,
}

var indicator: StatusIndicator
var panel: Window
var _last_click := -10.0
var _dark := false


func _ready() -> void:
	indicator = StatusIndicator.new()
	add_child(indicator)
	indicator.pressed.connect(_on_pressed)
	_refresh_icon()


func update(new_info: Dictionary) -> void:
	var mode_changed: bool = new_info.get("mode", info.mode) != info.mode
	info.merge(new_info, true)
	if mode_changed:
		_refresh_icon()
	indicator.tooltip = _tooltip()
	if panel != null and panel.visible:
		_build()


func _tooltip() -> String:
	match info.mode:
		"paused":
			return "Critter Overlay · paused"
		"napping":
			return "Critter Overlay · napping"
	return "Critter Overlay · %d critter%s out" % [info.out, "" if info.out == 1 else "s"]


func _refresh_icon() -> void:
	# 32 px: Windows scales the notification icon for the display.
	indicator.icon = Icons.tray(info.mode, 32)
	indicator.tooltip = _tooltip()


func _on_pressed(_button: int, _pos: Vector2i) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_click < DOUBLE_CLICK_S:
		_last_click = -10.0
		close()
		settings_pressed.emit()
		return
	_last_click = now
	if panel != null and panel.visible:
		close()
	else:
		open()


# --- The panel ------------------------------------------------------------------

func open() -> void:
	_dark = DisplayServer.is_dark_mode()
	if panel == null:
		panel = Window.new()
		panel.borderless = true
		panel.transparent = true
		panel.transparent_bg = true
		panel.always_on_top = true
		panel.popup_window = true
		panel.unresizable = true
		panel.close_requested.connect(close)
		panel.focus_exited.connect(close)
		add_child(panel)
	_build()
	panel.show()
	_place()
	panel.grab_focus()


func close() -> void:
	if panel != null:
		panel.hide()


func _place() -> void:
	# Just above the icon, right-aligned to it, kept on its screen.
	var size := Vector2i(PANEL_W + 8, int(panel.get_contents_minimum_size().y) + 10)
	panel.size = size
	var icon_rect := Rect2i(indicator.get_rect())
	var scr := DisplayServer.get_screen_from_rect(Rect2(icon_rect)) if icon_rect.size.x > 0 else DisplayServer.get_primary_screen()
	var usable := DisplayServer.screen_get_usable_rect(scr)
	var pos := Vector2i(icon_rect.end.x - size.x + 16, usable.end.y - size.y - MARGIN)
	if icon_rect.size.x <= 0:
		pos = Vector2i(usable.end.x - size.x - MARGIN, usable.end.y - size.y - MARGIN)
	pos.x = clampi(pos.x, usable.position.x + MARGIN, usable.end.x - size.x - MARGIN)
	panel.position = pos


func _build() -> void:
	for c in panel.get_children():
		c.queue_free()
	var c := Palette.colours(_dark)

	var card := PanelContainer.new()
	card.position = Vector2(4, 2)
	card.custom_minimum_size.x = PANEL_W
	card.add_theme_stylebox_override("panel", _box(c.surface, 22, c.outline, 2, 12, Color(0.17, 0.13, 0.11, 0.35)))
	panel.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	# Header: the kitten, the name, the state.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(46, 46)
	avatar.add_theme_stylebox_override("panel", _box(c.sp_kitten, 15, c.outline, 2, 3))
	var face := TextureRect.new()
	face.texture = Icons.tray("napping" if info.mode == "napping" else "running", 36)
	face.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	avatar.add_child(face)
	head.add_child(avatar)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.add_child(_label("Critter Overlay", 17, c.ink, 600, true))
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 6)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", _box(Color(Palette.STATUS[info.mode]), 4))
	status.add_child(dot)
	status.add_child(_label(_status_text(), 13, c.ink2, 700))
	titles.add_child(status)
	head.add_child(titles)
	col.add_child(head)

	# The box: focus and the next gift, or what is happening instead.
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(c.ground, 14, Color.TRANSPARENT, 0, 10))
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 6)
	box.add_child(bc)
	match info.mode:
		"running":
			var row := HBoxContainer.new()
			var left := _label("Focused %s" % _mins(info.focus_min), 13, c.ink, 800)
			left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(left)
			var right_text := "Gift in %s" % _mins(info.gift_min) if info.gift_min >= 0.0 else "%d berries" % info.berries
			row.add_child(_label(right_text, 13, c.ink2, 700))
			bc.add_child(row)
			bc.add_child(_bar(info.gift_progress, c))
		"paused":
			bc.add_child(_wrap("Your focus time keeps counting. Resume to bring everyone back.", 13, c.ink2))
		_:
			bc.add_child(_wrap("Away for %s. %s curled up asleep." % [_mins(info.away_min), _sleepers()], 13, c.ink2))
	col.add_child(box)

	# The actions.
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 2)
	var hint := _chip("Ctrl+Shift+P", c.ink2, c.raised, c.sec_line)
	var count := _chip("%d/%d" % [info.found, info.found_total], Palette.tier("legendary", _dark).ink, Palette.tier("legendary", _dark).tint, Color.TRANSPARENT)
	if info.mode == "paused":
		items.add_child(_item("play", "Resume critters", c, pause_pressed, hint, true))
		items.add_child(_item("sparkle", "Spawn a critter", c, spawn_pressed))
	else:
		items.add_child(_item("sparkle", "Spawn a critter", c, spawn_pressed))
		items.add_child(_item("pause", "Pause critters", c, pause_pressed, hint))
	items.add_child(_item("star", "Collection", c, collection_pressed, count))
	items.add_child(_item("sliders", "Settings", c, settings_pressed))
	col.add_child(items)

	var sep := Panel.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.add_theme_stylebox_override("panel", _box(c.div, 1))
	col.add_child(sep)
	col.add_child(_item("power", "Quit", c, quit_pressed, null, false, c.dng_ink))

	if panel.visible:
		_place.call_deferred()


func _status_text() -> String:
	match info.mode:
		"paused":
			return "Paused · critters are hiding"
		"napping":
			return "Napping · back when you are"
	return "Gathering · %d critter%s out" % [info.out, "" if info.out == 1 else "s"]


func _sleepers() -> String:
	var n: int = info.out
	if n <= 0:
		return "Nobody is"
	var words := ["", "One critter is", "Two critters are", "Three critters are", "Four critters are",
		"Five critters are", "Six critters are", "Seven critters are", "Eight critters are"]
	return words[n] if n < words.size() else "%d critters are" % n


static func _mins(m: float) -> String:
	var whole := int(round(m))
	if whole < 60:
		return "%d min" % maxi(whole, 1) if m > 0.0 else "0 min"
	return "%d h %02d min" % [whole / 60, whole % 60]


# --- Building blocks --------------------------------------------------------------

static func _box(bg: Color, radius: int, border := Color.TRANSPARENT, bw := 0, pad := 0, shadow := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	if shadow.a > 0.0:
		s.shadow_color = shadow
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 4)
	return s


static func font(weight: int, display := false) -> SystemFont:
	# The design's Fredoka and Nunito when installed, else Segoe UI.
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Fredoka", "Segoe UI"] if display else ["Nunito", "Segoe UI"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	return f


func _label(text: String, size: int, colour: Color, weight := 400, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight, display))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _wrap(text: String, size: int, colour: Color) -> Label:
	var l := _label(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = PANEL_W - 48
	return l


func _bar(value: float, c: Dictionary) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.value = value
	b.custom_minimum_size.y = 7
	b.add_theme_stylebox_override("background", _box(c.track, 4))
	b.add_theme_stylebox_override("fill", _box(c.accent, 4))
	return b


func _chip(text: String, ink: Color, bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _box(bg, 8, border, 1 if border.a > 0.0 else 0)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_label(text, 12, ink, 800))
	return p


func _item(icon: String, text: String, c: Dictionary, sig: Signal, right: Control = null, primary := false, colour := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 42)
	b.focus_mode = Control.FOCUS_NONE
	var ink: Color = c.btn_ink if primary else (colour if colour.a > 0.0 else c.ink)
	var icon_ink: Color = c.btn_ink if primary else (colour if colour.a > 0.0 else c.acc_ink)
	if primary:
		var s := _box(c.btn, 12, c.btn_lip, 2)
		s.border_width_bottom = 4   # the chunky toy-button lip
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)
		b.add_theme_stylebox_override("pressed", _box(c.btn_lip, 12, c.btn_lip, 2))
	else:
		b.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, 12))
		b.add_theme_stylebox_override("hover", _box(c.div, 12))
		b.add_theme_stylebox_override("pressed", _box(c.track, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = Icons.line(icon, 20, icon_ink)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := _label(text, 15, ink, 800)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	if right != null:
		row.add_child(right)
	b.add_child(row)
	b.pressed.connect(func():
		close()
		sig.emit())
	return b
