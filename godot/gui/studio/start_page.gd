extends RefCounted
## The Studio's first page (docs/custom-critters-build-plan.md, D5;
## design/studio/builder/Start.html): shown when the Studio opens with
## nothing to build. Eight starters (studio/starters/*.json), each a picture,
## a name and how it moves; beside them, Or start blank, with the four body
## plans and what you draw for each.
##
## A starter is an ordinary shapes.json (5.3) with its "name" and "gait"
## beside it. Every automatic pose is left automatic (no sitting or napping
## body is drawn), so a new player only sees what they need to change. Its
## card picture is made from the real rig (save_panel.gd card_picture), once
## a session.

const Shapes := preload("res://studio/shapes.gd")
const Writer := preload("res://studio/shape_svg.gd")
const Share := preload("res://share.gd")
const Tools := preload("res://gui/studio/tools.gd")
const SavePanel := preload("res://gui/studio/save_panel.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")

const DIR := "res://studio/starters"
# [file, how it moves], the design's order: two per body plan.
const STARTERS := [["round-cat", "Trots on four legs"], ["floppy-dog", "Trots on four legs"],
	["bear", "Faces you, plods off"], ["round-mouse", "Faces you, scurries off"],
	["chick", "Stands on two, waddles"], ["penguin", "Stands on two, waddles"],
	["slime", "No legs, bounces along"], ["ghost", "No legs, floats along"]]
const BLANKS := [
	["side", "Side-on", "Walks on four legs, seen from the side, like the kitten.", "You draw: body, head, eyes, 2 legs"],
	["front", "Faces you", "Sits looking at you, turns side-on to walk, like the otter.", "You draw: sitting and walking body, head, eyes, 2 legs"],
	["upright", "Upright", "Stands on two legs and waddles, like the duckling.", "You draw: body, head, eyes, 1 leg"],
	["blob", "Blob", "No legs. Bounces, glides, floats or slithers.", "You draw: body, eyes"],
]
const PICS := "user://studio_starters"

static var _pics := {}             # file -> ImageTexture, made once a session

var st: Window                     # studio_window.gd


func _init(studio: Window) -> void:
	st = studio


static func starter(file: String) -> Dictionary:
	# {"doc": the shapes doc, "name", "gait"}, or {} if it can't be read.
	var j = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [DIR, file]))
	if typeof(j) != TYPE_DICTIONARY:
		return {}
	return {"doc": Writer.clean_doc(j).doc, "name": str(j.get("name", file.capitalize())), "gait": str(j.get("gait", ""))}


static func picture(file: String) -> ImageTexture:
	if _pics.has(file):
		return _pics[file]
	var s := starter(file)
	var tex: ImageTexture = null
	var dest := PICS.path_join(file)
	Share.clear_dir(dest)
	if not s.is_empty() and Share.write_builder_kit(s.doc, s.name, dest, s.gait) != "":
		var img := SavePanel.card_picture(dest)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	Share.clear_dir(dest)
	_pics[file] = tex
	return tex


func build() -> Control:
	var c := K.c
	var body := K.hbox(36)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := K.vbox(18)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lh := K.vbox(4)
	lh.add_child(UI.label("Start from a friend", 28, c.ink, 600, true))
	lh.add_child(UI.wrap("Pick one that's close to what you have in mind, then change anything: shapes, colours, eyes. The round cat is the easiest start.", 14, c.ink2, 640))
	left.add_child(lh)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for s in STARTERS:
		grid.add_child(_card(s[0], s[1]))
	left.add_child(grid)
	var tip := PanelContainer.new()
	tip.add_theme_stylebox_override("panel", K.box(c.side, 18))
	tip.add_child(K.margins(UI.wrap("A starter only needs a few changes to be yours. Everything you leave alone, like how it naps, stays automatic until you want to draw it.", 13, c.ink2, 600), 16, 12, 16, 12))
	left.add_child(tip)
	body.add_child(left)
	var right := K.vbox(10)
	right.custom_minimum_size.x = 372
	var rh := K.vbox(4)
	rh.add_child(UI.label("Or start blank", 22, c.ink, 600, true))
	rh.add_child(UI.wrap("First pick how it stands. It decides which parts you draw and how it moves.", 14, c.ink2, 360))
	right.add_child(K.margins(rh, 0, 0, 0, 8))
	for b in BLANKS:
		right.add_child(_plan(b))
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := K.margins(body, 44, 30, 44, 32)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(m)
	return scroll


func _card(file: String, moves: String) -> Control:
	var c := K.c
	var s := starter(file)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(150, 196)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "Start from the %s" % str(s.get("name", file)).to_lower()
	var n := K.box(c.surface, 18, c.outline if file == "round-cat" else c.line, 2, c.lip, 3 if file == "round-cat" else 0)
	var hv := K.box(c.surface, 18, c.outline, 2, c.lip, 3)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 18, c.acc_ink, 2))
	var v := K.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.custom_minimum_size.y = 124
	well.add_theme_stylebox_override("panel", K.box(c.ground, 14))
	var tex := picture(file)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(K.margins(pic, 10, 10, 10, 8))
	v.add_child(well)
	v.add_child(UI.label(str(s.get("name", file)), 15, c.ink, 800))
	v.add_child(UI.label(moves, 12, c.ink2, 600))
	var m := K.margins(v, 8, 8, 8, 10)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(m)
	b.pressed.connect(func(): st.start_from(file))
	return b


func _plan(p: Array) -> Control:
	var c := K.c
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 92
	b.add_theme_stylebox_override("normal", K.box(c.surface, 18, c.line, 2))
	b.add_theme_stylebox_override("hover", K.box(c.surface, 18, c.outline, 2, c.lip, 3))
	b.add_theme_stylebox_override("pressed", K.box(c.surface, 18, c.outline, 2, c.lip, 3))
	b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 18, c.acc_ink, 2))
	var v := K.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UI.label(p[1], 17, c.ink, 800))
	var d := UI.wrap(p[2], 13, c.ink2, 320)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	v.add_child(UI.label(p[3], 12, c.ink3, 700))
	var m := K.margins(v, 16, 12, 16, 12)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(m)
	var plan: String = p[0]
	b.pressed.connect(func(): st.start_blank(plan))
	return b
