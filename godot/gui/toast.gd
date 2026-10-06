extends Node
## Rare-sighting toasts (design: "Rare sighting toasts" artboard).
##
## Bottom right of the main screen, 16 px in from the edge and 16 px above
## the taskbar. Up to three: the newest sits nearest the corner and older ones
## move up. Each stays six seconds, shown by the bar running down; hovering
## pauses it. A toast never takes keyboard focus. Clicking one opens the
## Collection; the cross dismisses it.
##
## main.gd decides when to show one (and stays quiet while paused or while a
## full-screen app has the screen); this file only draws and stacks them.

signal open_collection(species: String)

const Palette := preload("res://gui/palette.gd")
const Icons := preload("res://gui/icons.gd")
const UI := preload("res://gui/ui.gd")
const Species := preload("res://species.gd")

const W := 360
const EDGE := 16
const GAP := 12
const LIFE := 6.0
const MAX_SHOWN := 3
const SLIDE := 0.22            # s to slide in from the right
const LEGENDARY_EDGE := "#E3A72F"

var toasts := []               # Toast, oldest first


class Floor extends Node:
	var floor_y := 0.0
	var left_x := -INF
	var right_x := INF
	func mouse_local() -> Vector2:
		return Vector2(-9999, -9999)


class Toast extends RefCounted:
	var win: Window
	var bar: ProgressBar
	var critter: Node2D
	var species := ""
	var left := LIFE
	var hovered := false
	var age := 0.0
	var y := 0.0               # where it is heading
	var y_now := -1.0


func show_sighting(species: String, tier: String, kicker: String, title: String, sub: String) -> void:
	var dark := Palette.is_dark()
	var c := Palette.colours(dark)
	var tc := Palette.tier(tier, dark)
	var legendary := tier == "legendary"
	var edge: Color = Color(LEGENDARY_EDGE) if legendary else tc.fill

	var t := Toast.new()
	t.species = species
	var well := _well(tc.tint)
	# The critter itself, sitting in the well and idling.
	var view := SubViewportContainer.new()
	view.stretch = true
	view.size = Vector2(60, 60)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(60, 60)
	view.add_child(vp)
	var shrink := Node2D.new()     # the critter at 60% in a 60 px well
	shrink.scale = Vector2(0.6, 0.6)
	vp.add_child(shrink)
	var floor := Floor.new()
	floor.floor_y = 60.0 / 0.6 - 4.0
	vp.add_child(floor)
	if Species.has(species):
		var k = Species.row(species)["script"].new()
		k.idles = Species.row(species)["idles"]
		shrink.add_child(k)
		k.setup(floor, 30.0 / 0.6, -1, "sit")
		k.mode_left = INF
		t.critter = k
	well.add_child(view)
	# The tier badge on the well's corner.
	var pip := PanelContainer.new()
	pip.add_theme_stylebox_override("panel", UI.box(c.surface, 12, Color.TRANSPARENT, 0, 2))
	pip.add_child(UI.icon(Icons.badge(tier, 20, tc.fill, c.badge_line)))
	pip.position = Vector2(42, 40)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(pip)

	var kick := UI.label(kicker.to_upper(), 12, tc.ink, 600, true)
	_build(t, c, c.surface, edge, 3 if legendary else 2, well, kick, title, sub, c.ink2, tc.tint)
	if legendary:
		for s in [[Vector2(6, 6), 16], [Vector2(62, 4), 11]]:
			var star := UI.icon(Icons.sparkle(s[1]))
			star.position = s[0]
			t.win.add_child(star)
	_push(t)


func show_rare_hour(until: String, boost: float) -> void:
	var dark := Palette.is_dark()
	var c := Palette.colours(dark)
	var t := Toast.new()
	var well := _well(c.surface, c.outline)
	var moon := UI.icon(Icons.line("moon", 28, c.rh_ink))
	moon.size = Vector2(60, 60)
	well.add_child(moon)
	var how: String = {1.5: "half as likely again", 2.0: "twice as likely", 3.0: "three times as likely"}.get(boost, "%.1f times as likely" % boost)
	_build(t, c, c.rh_bg, c.rh_line, 2, well, UI.label("RARE HOUR", 12, c.rh_ink, 600, true),
		"Rare Hour has begun", "Rare and better are %s until %s." % [how, until], c.rh_text, Color.TRANSPARENT)
	_push(t)


func _well(bg: Color, border := Color.TRANSPARENT) -> Control:
	var well := Control.new()
	well.custom_minimum_size = Vector2(60, 60)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := Panel.new()
	disc.size = Vector2(60, 60)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override("panel", UI.box(bg, 30, border, 2 if border.a > 0.0 else 0))
	well.add_child(disc)
	return well


func _build(t: Toast, c: Dictionary, bg: Color, edge: Color, bw: int, well: Control, kick: Label,
		title: String, sub: String, sub_ink: Color, track: Color) -> void:
	var win := Window.new()
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = true
	win.unfocusable = true
	win.visible = false
	win.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	t.win = win

	var card := PanelContainer.new()
	card.custom_minimum_size.x = W
	card.add_theme_stylebox_override("panel", UI.box(bg, 20, edge, bw, 0, edge))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_entered.connect(func(): t.hovered = true)
	card.mouse_exited.connect(func(): t.hovered = false)
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if t.species != "":
				open_collection.emit(t.species)
			_dismiss(t))
	win.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in [["left", 14], ["right", 12], ["top", 12], ["bottom", 12 if track.a == 0.0 else 8]]:
		pad.add_theme_constant_override("margin_" + m[0], m[1])
	col.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)
	row.add_child(well)

	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(kick)
	words.add_child(UI.label(title, 15, c.ink, 800))
	var s := UI.wrap(sub, 13, sub_ink, W - 14 - 60 - 14 - 14 - 30 - 12)
	words.add_child(s)
	for l in [kick, s]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)

	var close := Button.new()
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.icon = Icons.line("close", 16, c.ink2)
	close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.custom_minimum_size = Vector2(30, 30)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = "Dismiss"
	close.add_theme_stylebox_override("hover", UI.box(c.div, 15))
	close.add_theme_stylebox_override("pressed", UI.box(c.track, 15))
	close.pressed.connect(func(): _dismiss(t))
	row.add_child(close)

	# The time left, running down. Inset and rounded, inside the card.
	if track.a > 0.0:
		var bar_pad := MarginContainer.new()
		bar_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for m in [["left", 14], ["right", 14], ["bottom", 10]]:
			bar_pad.add_theme_constant_override("margin_" + m[0], m[1])
		t.bar = UI.bar(1.0, track, edge, 4)
		t.bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_pad.add_child(t.bar)
		col.add_child(bar_pad)

	add_child(win)
	win.size = Vector2i(W, int(card.get_combined_minimum_size().y) + 6)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, win.get_window_id())   # one vsync'd window only


func _push(t: Toast) -> void:
	toasts.append(t)
	while toasts.size() > MAX_SHOWN:
		_dismiss(toasts[0])
	_restack()
	t.y_now = t.y
	_place(t, 1.0)
	t.win.show()


func _restack() -> void:
	# Newest nearest the corner; older ones above it.
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	var y := float(usable.end.y - EDGE)
	for i in range(toasts.size() - 1, -1, -1):
		var t: Toast = toasts[i]
		y -= t.win.size.y
		t.y = y
		y -= GAP


func _place(t: Toast, slide: float) -> void:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	var x := usable.end.x - EDGE - W + int((1.0 - slide) * (W + EDGE))
	t.win.position = Vector2i(x, int(round(t.y_now)))


func _dismiss(t: Toast) -> void:
	if not t in toasts:
		return
	toasts.erase(t)
	t.win.queue_free()
	_restack()


func _process(delta: float) -> void:
	for t in toasts.duplicate():
		t.age += delta
		if not t.hovered:
			t.left -= delta
		if t.left <= 0.0:
			_dismiss(t)
			continue
		if t.bar != null:
			t.bar.value = t.left / LIFE
		if t.critter != null and is_instance_valid(t.critter):
			t.critter.tick(delta)
		t.y_now = lerpf(t.y_now, t.y, minf(1.0, delta * 14.0))
		var s := clampf(t.age / SLIDE, 0.0, 1.0)
		_place(t, 1.0 - pow(1.0 - s, 3.0))
