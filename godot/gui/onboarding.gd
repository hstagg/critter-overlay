extends Window
## The first run (design: "First run" artboard): four cards, shown once.
##   1 Hello there                 what the app is
##   2 Who should visit?           pick the species (Settings > Critters)
##   3 They gather while you work  how focus works; nap after
##   4 You're all set              the tray, the pause keys, start with Windows
## Skip and finishing both mark it done (settings system.onboarded); the
## critters come out when it closes.

signal finished(open_settings: bool)

const Palette := preload("res://gui/palette.gd")
const Icons := preload("res://gui/icons.gd")
const UI := preload("res://gui/ui.gd")
const K := preload("res://gui/controls.gd")
const Species := preload("res://species.gd")
const Settings := preload("res://settings.gd")
const CritterView := preload("res://gui/critter_view.gd")
const Collection := preload("res://gui/collection.gd")

const W := 480
const H := 680

var main: Node
var step := 0
var startup := true
var dark := false
var _drag_from := Vector2i(-1, -1)


func _init() -> void:
	title = "Welcome to Critter Overlay"
	borderless = true
	transparent = true
	transparent_bg = true
	unresizable = true
	always_on_top = true
	size = Vector2i(W + 8, H + 10)
	visible = false
	initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	close_requested.connect(func(): _done(false))


func open(main_ref: Node) -> void:
	main = main_ref
	_build()
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	position = usable.position + (usable.size - size) / 2
	show()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, get_window_id())
	grab_focus()


func _done(open_settings: bool) -> void:
	main.settings.set_value("system.onboarded", true)
	if step == 3 or open_settings:
		main.set_startup(startup)
	hide()
	finished.emit(open_settings)
	queue_free()


func _go(to: int) -> void:
	step = to
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	dark = Palette.is_dark()
	K.c = Palette.colours(dark)
	K.dark = dark
	var c := K.c

	var card := PanelContainer.new()
	card.position = Vector2(4, 2)
	card.size = Vector2(W, H)
	var cs := K.box(c.surface, 28, c.outline, 2, c.lip, 5)
	cs.set_content_margin_all(2)
	card.add_theme_stylebox_override("panel", cs)
	add_child(card)
	var col := K.vbox(0)
	card.add_child(col)

	var art: Control = [_hello_art, _who_art, _gather_art, _tray_art][step].call()
	col.add_child(art)
	_draggable(art)

	var body := K.vbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(UI.label("STEP %d OF 4" % (step + 1), 12, c.acc_ink, 800))
	body.add_child(UI.label(["Hello there", "Who should visit?", "They gather while you work", "You're all set"][step], 30, c.ink, 600, true))
	[_hello_body, _who_body, _gather_body, _tray_body][step].call(body)
	var body_m := K.margins(body, 30, 24, 30, 0)
	body_m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body_m)

	var foot := K.hbox(10)
	var dots := K.hbox(6)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for j in 4:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(22 if j == step else 8, 8)
		d.add_theme_stylebox_override("panel", K.box(c.outline if j == step else c.chip_line, 4))
		dots.add_child(d)
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(dots)
	match step:
		0:
			foot.add_child(K.button("Skip setup", "bq", "", false, func(): _done(false)))
			foot.add_child(K.button("Get started", "bp", "arrow", false, func(): _go(1)))
		1, 2:
			foot.add_child(K.button("Back", "bq", "", false, func(): _go(step - 1)))
			foot.add_child(K.button("Next", "bp", "arrow", false, func(): _go(step + 1)))
		3:
			foot.add_child(K.button("Open Settings", "bs", "", false, func(): _done(true)))
			foot.add_child(K.button("Let them in", "bp", "heart", false, func(): _done(false)))
	col.add_child(K.margins(foot, 30, 16, 30, 26))


func _para(text: String) -> Label:
	var l := UI.label(text, 15, K.c.ink_body, 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = W - 60
	return l


func _art(h: int, bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.y = h
	var s := K.box(bg, 0)
	s.corner_radius_top_left = 26
	s.corner_radius_top_right = 26
	p.add_theme_stylebox_override("panel", s)
	p.clip_contents = true
	return p


func _row(critters: Array, sep := 6) -> HBoxContainer:
	var r := K.hbox(sep)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_END
	for cr in critters:
		r.add_child(CritterView.make(cr[0], int(110 * cr[1]), int(118 * cr[1]), cr[1], "sit", cr.size() > 2 and cr[2]))
	return r


func _built() -> Array:
	var out := []
	for sp in Species.DATA:
		if not Species.row(sp).get("special", false):
			out.append(sp)
	return out


# --- 1 Hello ---------------------------------------------------------------------------

func _hello_art() -> Control:
	var a := _art(270, Palette.species_tint("kitten", dark))
	var stack := Control.new()
	var ground := Panel.new()
	ground.add_theme_stylebox_override("panel", K.box(Color("#DCCFEF") if not dark else Color("#2A2036"), 0))
	ground.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -26
	stack.add_child(ground)
	var crits := []
	for sp in _built():
		crits.append([sp, 1.3 if sp == "kitten" else 1.1])
	var r := _row(crits)
	r.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	r.offset_top = -170
	r.offset_bottom = -10
	stack.add_child(r)
	a.add_child(stack)
	return a


func _hello_body(body: VBoxContainer) -> void:
	body.add_child(_para("Critter Overlay brings small, very cute critters to the bottom of your screen. They keep you company while you work and never get in your way."))
	body.add_child(_para("You can click straight through them, or pop one for a squeak."))


# --- 2 Who should visit ----------------------------------------------------------------

func _who_art() -> Control:
	var a := _art(150, Palette.species_tint("turtle", dark))
	var crits := []
	for sp in _built():
		crits.append([sp, 0.85])
	a.add_child(_row(crits, 22))
	return a


func _who_body(body: VBoxContainer) -> void:
	var c := K.c
	body.add_child(_para("Pick your favourites. You can change this any time in Settings."))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 14)
	for sp in _built():
		var on: bool = main.settings.sp(sp, "enabled")
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(100, 94)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "%s, %s" % [Collection.species_name(sp), "included" if on else "left out"]
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 12, c.acc_ink, 2))
		var v := K.vbox(6)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var well := PanelContainer.new()
		well.custom_minimum_size = Vector2(62, 62)
		well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_theme_stylebox_override("panel", K.box(Palette.species_tint(sp, dark), 31, c.outline if on else c.chip_line, 3 if on else 2))
		well.add_child(CritterView.make(sp, 56, 56, 0.62))
		if not on:
			well.modulate.a = 0.45
		v.add_child(well)
		var name := UI.label(Collection.species_name(sp), 12, c.ink, 800)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name)
		b.add_child(v)
		if on:
			var tick := PanelContainer.new()
			tick.add_theme_stylebox_override("panel", K.box(c.accent, 11, c.outline, 2))
			tick.custom_minimum_size = Vector2(22, 22)
			tick.add_child(UI.icon(Icons.line("check", 13, c.ink)))
			tick.position = Vector2(64, 0)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tick)
		var spc: String = sp
		b.pressed.connect(func():
			# At least one must stay.
			var others := _built().filter(func(x): return x != spc and main.settings.sp(x, "enabled"))
			if on and others.is_empty():
				return
			main.settings.set_value("species.%s.enabled" % spc, not on)
			_build())
		grid.add_child(b)
	body.add_child(grid)
	var note := UI.label("More critters join as they are drawn. Special visitors turn up on their own.", 13, c.ink2, 400)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = W - 60
	body.add_child(note)


# --- 3 Gathering ----------------------------------------------------------------------------

func _gather_art() -> Control:
	var c := K.c
	var a := _art(200, Palette.species_tint("kitten", dark))
	var split := K.hbox(0)
	var built := _built()
	for half in 2:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", K.box(Palette.species_tint("kitten" if half == 0 else "otter", dark), 0))
		var v := K.vbox(0)
		v.add_child(K.margins(UI.label("WORKING" if half == 0 else "AWAY", 12, c.outline if half == 0 else Color("#3E5670") if not dark else c.zz, 800), 20, 16, 0, 0))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(spacer)
		var crits := []
		if half == 0:
			for sp in built:
				crits.append([sp, 0.62])
		else:
			crits = [["kitten", 0.8, true], [built[1 % built.size()], 0.66, true]]
		v.add_child(K.margins(_row(crits, 2), 0, 0, 0, 10))
		p.add_child(v)
		split.add_child(p)
	a.add_child(split)
	return a


func _gather_body(body: VBoxContainer) -> void:
	var c := K.c
	body.add_child(_para("Keep working and more critters gather, and the rare ones get more likely. Step away and they curl up for a nap."))
	var nap := K.vbox(8)
	nap.add_child(UI.label("Nap after", 14, c.ink, 800))
	var opts := [1, 3, 5, 10]
	var cur := opts.find(int(main.settings.value("focus.nap_after_min")))
	nap.add_child(K.seg(["1 min", "3 min", "5 min", "10 min"], cur, func(i):
		main.settings.set_value("focus.nap_after_min", opts[i])
		_build()))
	body.add_child(nap)
	var priv := PanelContainer.new()
	var ps := K.box(c.ground, 14)
	ps.set_content_margin_all(12)
	priv.add_theme_stylebox_override("panel", ps)
	var pr := K.hbox(10)
	pr.add_child(UI.icon(Icons.line("lock", 18, c.outline)))
	var pl := UI.label("Only the time since your last key press or click is checked. Nothing you type is recorded.", 13, c.ink2, 400)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pl.custom_minimum_size.x = W - 120
	pr.add_child(pl)
	priv.add_child(pr)
	body.add_child(priv)


# --- 4 The tray -------------------------------------------------------------------------------

func _tray_art() -> Control:
	var a := _art(230, Color("#3B4250"))
	var v := K.vbox(4)
	v.add_child(UI.label("Find us here", 20, Color.WHITE, 600, true))
	v.add_child(UI.label("Click the kitten for the menu.", 13, Color("#C9D1DB"), 400))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	# A taskbar with the tray kitten ringed.
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = 48
	bar.add_theme_stylebox_override("panel", K.box(Color("#20242C"), 12))
	var icons := K.hbox(10)
	icons.alignment = BoxContainer.ALIGNMENT_END
	for ic in ["chevd", "", "sound", "monitor"]:
		if ic == "":
			var ring := PanelContainer.new()
			ring.custom_minimum_size = Vector2(40, 40)
			ring.add_theme_stylebox_override("panel", K.box(Color("#3B4250"), 20, K.c.accent, 3))
			ring.add_child(UI.icon(Icons.tray("running", 22)))
			icons.add_child(ring)
		elif Icons.LINE.has(ic):
			icons.add_child(UI.icon(Icons.line(ic, 16, Color("#D7DCE3"))))
	var clock := K.vbox(0)
	var now := Time.get_datetime_dict_from_system()
	clock.add_child(UI.label("%02d:%02d" % [now.hour, now.minute], 11, Color("#E6EAF0"), 600))
	clock.add_child(UI.label("%02d/%02d/%d" % [now.day, now.month, now.year], 11, Color("#E6EAF0"), 600))
	icons.add_child(clock)
	bar.add_child(K.margins(icons, 12, 4, 12, 4))
	v.add_child(bar)
	a.add_child(K.margins(v, 30, 28, 30, 30))
	return a


func _tray_body(body: VBoxContainer) -> void:
	var c := K.c
	body.add_child(_para("Critter Overlay lives in your system tray. If you cannot see the kitten, check the arrow by the clock. Pause or resume from anywhere with"))
	body.add_child(K.keys(Settings.key_text(main.settings.value("system.pause_key"))))
	var row := PanelContainer.new()
	var rs := K.box(c.ground, 14)
	rs.set_content_margin_all(12)
	row.add_theme_stylebox_override("panel", rs)
	var h := K.hbox(8)
	var l := UI.label("Start with Windows", 14, c.ink, 800)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(K.toggle(startup, "Start with Windows", func(on): startup = on))
	row.add_child(h)
	body.add_child(row)


func _draggable(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = DisplayServer.mouse_get_position() - position if e.pressed else Vector2i(-1, -1)
		elif e is InputEventMouseMotion and _drag_from.x >= 0:
			position = DisplayServer.mouse_get_position() - _drag_from)
