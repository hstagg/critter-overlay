extends Window
## The Settings window (design: "Critter Overlay v3 GUI" canvas, the seven
## settings pages). Borderless, 1100 x 760, with its own title bar: a sidebar
## with the live status and the seven pages (Home, Critters, Focus, World,
## Sound, Collection, System), and the page on the right, scrolling.
##
## Every control writes straight to settings.gd; main.gd listens and applies
## the change. Closing the window keeps the critters running in the tray.
## The pages themselves are in settings_pages.gd.

const Palette := preload("res://gui/palette.gd")
const Icons := preload("res://gui/icons.gd")
const UI := preload("res://gui/ui.gd")
const K := preload("res://gui/controls.gd")
const Pages := preload("res://gui/settings_pages.gd")

const W := 1100
const H := 760
const SIDE_W := 232
const NAV := [["home", "Home", "home"], ["critters", "Critters", "paw"], ["focus", "Focus", "mug"],
	["world", "World", "leaf"], ["sound", "Sound", "sound"], ["collection", "Collection", "star"],
	["shop", "Shop", "heart"], ["system", "System", "sliders"]]

var main: Node                     # main.gd
var page := "home"
var dark := false
var live := {}                     # labels and bars the once-a-second refresh updates
var pages: RefCounted
var selected_species := "kitten"
var focus_species := ""            # the Collection scrolls to this critter (from a toast)
var capturing := -1                # shortcut slot waiting for keys, or -1
var _scroll: ScrollContainer
var _body: VBoxContainer
var _side: Control
var _drag_from := Vector2i(-1, -1)
var _refresh_in := 0.0
var _taskbar_done := false


func _init() -> void:
	title = "Critter Overlay"
	borderless = true
	unresizable = true
	size = Vector2i(W, H)
	wrap_controls = false
	visible = false
	initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	close_requested.connect(hide)


func open(main_ref: Node, which := "", species := "") -> void:
	main = main_ref
	if which != "":
		page = which
	if species != "":
		selected_species = species
	focus_species = species if which == "collection" else ""
	if pages == null:
		pages = Pages.new(self)
	rebuild()
	if not visible:
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
		position = usable.position + (usable.size - size) / 2
		show()
		# Only one window may wait for vsync (see host.gd); a second halves
		# the frame rate of every critter.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, get_window_id())
		if not _taskbar_done and main.native != null:
			_taskbar_done = true
			main.native.show_in_taskbar(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, get_window_id()))
	# Back up from the taskbar only if minimised: setting the mode on a
	# window that is already showing stops it drawing (a grey box).
	if mode == Window.MODE_MINIMIZED:
		mode = Window.MODE_WINDOWED
	grab_focus()


func go(which: String) -> void:
	page = which
	rebuild(false)


func rebuild(keep_scroll := true) -> void:
	var scroll_y := _scroll.scroll_vertical if keep_scroll and _scroll != null else 0
	for ch in get_children():
		ch.queue_free()
	live.clear()
	dark = Palette.is_dark()
	K.c = Palette.colours(dark)
	K.dark = dark
	var c := K.c

	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", K.box(c.ground, 0, c.line, 1))
	add_child(bg)
	var row := K.hbox(0)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	_side = _sidebar()
	row.add_child(_side)

	var main_col := K.vbox(0)
	main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(main_col)
	main_col.add_child(_titlebar())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_col.add_child(_scroll)
	_body = K.vbox(26)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := K.margins(_body, 40, 0, 40, 40)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pad)
	pages.build(page, _body)
	if scroll_y > 0:
		_scroll.set_deferred("scroll_vertical", scroll_y)
	_refresh()


# --- Sidebar and title bar -------------------------------------------------------------

func _sidebar() -> Control:
	var c := K.c
	var p := PanelContainer.new()
	p.custom_minimum_size.x = SIDE_W
	var s := K.box(c.side, 0)
	s.set_content_margin_all(14)
	s.content_margin_top = 18
	p.add_theme_stylebox_override("panel", s)
	var v := K.vbox(18)
	p.add_child(v)

	# The kitten, the name, the version. Dragging here moves the window.
	var head := K.hbox(10)
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(46, 46)
	avatar.add_theme_stylebox_override("panel", K.box(c.surface, 15, c.outline, 2, c.lip, 2))
	var face := UI.icon(Icons.tray("running", 36))
	avatar.add_child(face)
	head.add_child(avatar)
	var names := K.vbox(2)
	names.add_child(UI.label("Critter Overlay", 18, c.ink, 600, true))
	names.add_child(UI.label("Version %s" % main.VERSION.substr(0, 3), 12, c.ink3, 600))
	head.add_child(names)
	_draggable(head)
	v.add_child(K.margins(head, 6, 2, 0, 0))

	# The live status.
	var st := PanelContainer.new()
	var ss := K.box(c.surface, 18, c.line, 2)
	ss.content_margin_left = 14
	ss.content_margin_right = 14
	ss.content_margin_top = 12
	ss.content_margin_bottom = 12
	st.add_theme_stylebox_override("panel", ss)
	var sv := K.vbox(7)
	st.add_child(sv)
	var top := K.hbox(8)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(dot)
	live["dot"] = dot
	var mode_l := UI.label("", 14, c.ink, 800)
	mode_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mode_l)
	live["mode"] = mode_l
	live["focus"] = UI.label("", 12, c.ink2, 700)
	top.add_child(live["focus"])
	sv.add_child(top)
	live["out"] = UI.label("", 13, c.ink2, 400)
	sv.add_child(live["out"])
	live["bar"] = UI.bar(0.0, c.track, c.accent, 8)
	sv.add_child(live["bar"])
	live["next"] = UI.label("", 12, c.ink2, 400)
	sv.add_child(live["next"])
	v.add_child(st)

	# The pages.
	var nav := K.vbox(4)
	for n in NAV:
		nav.add_child(_nav_button(n[0], n[1], n[2]))
	v.add_child(nav)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var spawn := K.button("Spawn now", "bs", "sparkle", false, func(): main.spawn_now())
	v.add_child(spawn)
	var pause := K.button("Resume critters" if main.paused else "Pause critters", "bs", "play" if main.paused else "pause", false, func():
		main.toggle_pause()
		rebuild())
	v.add_child(pause)
	return p


func _nav_button(key: String, label: String, icon: String) -> Button:
	var c := K.c
	var on := key == page
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = Icons.line(icon, 20, c.ink if on else c.ink2)
	b.add_theme_constant_override("h_separation", 12)
	b.custom_minimum_size.y = 44
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var n := K.box(c.raised if on else Color.TRANSPARENT, 14, c.outline if on else Color.TRANSPARENT, 2, c.lip, 2 if on else 0)
	n.content_margin_left = 14
	n.content_margin_right = 14
	var hv := n.duplicate()
	if not on:
		hv.bg_color = c.nav_h
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 14, c.acc_ink, 2))
	b.add_theme_font_override("font", UI.font(800))
	b.add_theme_font_size_override("font_size", 15)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, c.ink if on else c.ink2)
	b.pressed.connect(func(): go(key))
	if key == "shop":
		var bc := UI.chip("%d" % main.economy.berries, c.ink, c.surface, c.line)
		bc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		bc.position.x -= 10
		b.add_child(bc)
	if key == "collection":
		# The found count, in Legendary's colours.
		var t := Palette.tier("legendary", dark)
		var chip := UI.chip("%d/%d" % main.collection_counts(), t.ink, t.tint)
		chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		chip.position.x -= 10
		b.add_child(chip)
	return b


func scroll_to(c: Control) -> void:
	# Bring a control into view (after layout has placed it).
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(c) and is_instance_valid(_scroll):
		_scroll.ensure_control_visible(c)


func _titlebar() -> Control:
	var c := K.c
	var bar := K.hbox(2)
	bar.custom_minimum_size.y = 44
	var grip := Control.new()
	grip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_draggable(grip)
	bar.add_child(grip)
	for w in [["min", "Minimise", func(): mode = Window.MODE_MINIMIZED], ["close", "Close to tray", hide]]:
		var b := Button.new()
		b.icon = Icons.line(w[0], 18, c.ink2)
		b.tooltip_text = w[1]
		b.custom_minimum_size = Vector2(36, 32)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("normal", K.box(Color.TRANSPARENT, 10))
		b.add_theme_stylebox_override("hover", K.box(c.track, 10))
		b.add_theme_stylebox_override("pressed", K.box(c.track, 10))
		b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 10, c.acc_ink, 2))
		b.pressed.connect(w[2])
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(b)
	bar.add_child(Control.new())
	return K.margins(bar, 0, 0, 8, 0)


func _draggable(node: Control) -> void:
	# A borderless window moves when its title area is dragged.
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = DisplayServer.mouse_get_position() - position if e.pressed else Vector2i(-1, -1)
		elif e is InputEventMouseMotion and _drag_from.x >= 0:
			position = DisplayServer.mouse_get_position() - _drag_from)


# --- Live values ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = 1.0
		_refresh()


func _refresh() -> void:
	# Once a second: the sidebar status and whatever the page shows live.
	if live.is_empty() or main == null:
		return
	var c := K.c
	var s: Dictionary = main.status()
	var colour: Color = Color(Palette.STATUS[s.mode])
	live.dot.add_theme_stylebox_override("panel", K.box(colour, 5, K.c.ok_ring if s.mode == "running" else Color.TRANSPARENT, 0))
	live.mode.text = {"running": "Gathering", "paused": "Paused", "napping": "Napping"}[s.mode]
	live.focus.text = _mins(s.focus_min)
	live.out.text = "%d of %d critters out" % [s.out, s.max_out]
	live.bar.value = s.next_progress
	live.next.text = s.next_text
	pages.refresh(live, s)


static func _mins(m: float) -> String:
	var whole := int(m)
	if whole < 60:
		return "%d min" % whole
	return "%d h %02d min" % [whole / 60, whole % 60]


# --- Shortcut capture ------------------------------------------------------------------

func capture(slot: int) -> void:
	capturing = slot
	rebuild()


func _input(e: InputEvent) -> void:
	if capturing < 0 or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var slot := capturing
	var key: int = e.keycode
	if key in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
		return   # wait for the key itself
	get_viewport().set_input_as_handled()
	capturing = -1
	if key == KEY_ESCAPE:
		rebuild()
		return
	if key in [KEY_BACKSPACE, KEY_DELETE] and slot == 1:
		main.set_shortcut(slot, {"mods": 0, "vk": 0})
		rebuild()
		return
	var vk := 0
	if key >= KEY_A and key <= KEY_Z:
		vk = key            # Godot's letter codes are the ASCII capitals, as are Windows'
	elif key >= KEY_0 and key <= KEY_9:
		vk = key
	elif key >= KEY_F1 and key <= KEY_F24:
		vk = 0x70 + (key - KEY_F1)
	var mods := (2 if e.ctrl_pressed else 0) | (1 if e.alt_pressed else 0) | (4 if e.shift_pressed else 0) | (8 if e.meta_pressed else 0)
	if vk == 0 or (mods == 0 and not (vk >= 0x70 and vk <= 0x87)):
		pages.shortcut_note = "Use a letter, number or F key, with Ctrl, Alt or Shift."
		rebuild()
		return
	main.set_shortcut(slot, {"mods": mods, "vk": vk})
	rebuild()


# --- Dialogs -------------------------------------------------------------------------

func confirm(title_text: String, body: String, ok_text: String, on_ok: Callable) -> void:
	var c := K.c
	var d := ConfirmationDialog.new()
	d.title = title_text
	d.dialog_text = body
	d.ok_button_text = ok_text
	d.cancel_button_text = "Cancel"
	d.dialog_autowrap = true
	d.min_size = Vector2i(420, 160)
	d.add_theme_stylebox_override("panel", K.box(c.surface, 0))
	d.confirmed.connect(on_ok)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered()


func notice(title_text: String, body: String) -> void:
	var c := K.c
	var d := AcceptDialog.new()
	d.title = title_text
	d.min_size = Vector2i(640, 460)
	d.add_theme_stylebox_override("panel", K.box(c.surface, 0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 380)
	var l := UI.label(body, 13, c.ink_body, 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 580
	scroll.add_child(l)
	d.add_child(scroll)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered()
