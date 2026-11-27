extends RefCounted
## The Studio's help (docs/custom-critters-build-plan.md, D7;
## design/studio/builder/Builder.html's ? panel and Empty.html): the
## shortcuts panel, the three first-time tips, the hint card on an empty
## part, and the card that says which parts Save still needs.
##
## SHORTCUTS is the one list of keys: the ? panel draws it, and
## studio_test.gd checks every key studio_window.gd key() answers to is in
## it (key_name() names a key press the way the list does). The tips are
## shown once: studio_window.gd remembers it in settings.gd's
## studio.tips_seen. A hint card offers two or three shapes that suit the
## part, placed where the starter of the same body plan has it.

const Tools := preload("res://gui/studio/tools.gd")
const LP := preload("res://gui/studio/layers_panel.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const StartPage := preload("res://gui/studio/start_page.gd")
const Shapes := preload("res://studio/shapes.gd")
const SI := preload("res://gui/studio/studio_icons.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")

# [group, [[what it does, [keys]]]]. A key is "Ctrl+Z"; a lowercase part
# ("drag", "wheel") is a word, not a key.
const SHORTCUTS := [
	["Shapes", [["Move, turn and resize", ["V"]], ["Oval", ["E"]], ["Rounded box", ["R"]], ["Triangle", ["T"]],
		["Drop", ["D"]], ["Heart", ["H"]], ["Star", ["S"]], ["Blob", ["B"]], ["Line", ["L"]], ["Eye", ["I"]]]],
	["Changing shapes", [["Undo", ["Ctrl+Z"]], ["Redo", ["Ctrl+Y", "Ctrl+Shift+Z"]], ["Duplicate", ["Ctrl+D"]],
		["Delete", ["Del", "Backspace"]], ["Copy, paste (any layer)", ["Ctrl+C", "Ctrl+V"]],
		["Pick every shape in the part", ["Ctrl+A"]], ["Mirror", ["M"]], ["Bring forward, send back", ["PgUp", "PgDn"]],
		["Nudge (Shift: by 10)", ["Arrows"]], ["Keep its shape while resizing", ["Shift+drag"]],
		["Turn in steps of 15°", ["Shift+drag"]]]],
	["Looking around", [["Move around", ["Space+drag"]], ["Zoom", ["Ctrl+wheel"]], ["Fit the frame", ["0"]],
		["Shapes or Pins", ["P"]], ["Save", ["Ctrl+S"]], ["This panel", ["?", "F1"]],
		["Let go of the shape (again: go back)", ["Esc"]]]],
]
const TIPS := [
	["Pick a part, then a shape", "The part on the left is the one you're drawing. Pick a shape here and click the canvas to put it down."],
	["Move, resize, turn", "Drag a shape to move it. Pull a corner to resize it; the round handle turns it."],
	["Watch it as you go", "The preview on the right walks with every change."],
]
# The starter whose parts show where a part usually goes, per body plan.
const PLAN_STARTER := {"side": "round-cat", "front": "bear", "upright": "chick", "blob": "slime"}
const BODY := "The body is the big middle part. An oval is a good start; drag it to fit the faint kitten, or make it your own shape."
# part -> [what it is, the shapes that suit it]
const HINTS := {
	"walk-body": [BODY, ["ellipse", "rect", "blob"]],
	"body": [BODY, ["ellipse", "rect", "blob"]],
	"head": ["The head is on every pose. An oval is a good start; drag it over the faint kitten's head.", ["ellipse", "blob", "rect"]],
	"head-side": ["Its face while it walks side-on. An oval is a good start.", ["ellipse", "blob"]],
	"eyes": ["Eyes blink and look around by themselves. Put one down, then another beside it.", ["eye"]],
	"eye-side": ["Its eye while it walks side-on.", ["eye"]],
	"loaf-eyes": ["Its eyes while it naps.", ["eye"]],
	"leg-front": ["A leg swings from the top as it walks. A rounded box makes a good one; keep its foot on the ground line.", ["rect", "ellipse", "drop"]],
	"leg-back": ["A leg swings from the top as it walks. A rounded box makes a good one; keep its foot on the ground line.", ["rect", "ellipse", "drop"]],
	"leg-near": ["Its leg swings from the top as it walks. A rounded box makes a good one; keep its foot on the ground line.", ["rect", "ellipse", "drop"]],
	"tail": ["Tails swish when it's happy. A line makes a quick one, a drop a fluffy one.", ["stroke", "drop"]],
	"ear-l": ["Ears flick now and then. A triangle makes a pointy one, an oval a round one.", ["tri", "ellipse", "drop"]],
	"ear-r": ["Ears flick now and then. A triangle makes a pointy one, an oval a round one.", ["tri", "ellipse", "drop"]],
	"nose": ["A nose twitches when it sniffs. A small oval or a heart works well.", ["ellipse", "heart"]],
	"mouth-open": ["Shown when it yawns or sneezes. A small oval or a drop.", ["ellipse", "drop"]],
	"head-front": ["Horns, a fringe or a bow, drawn over the head.", ["tri", "heart", "star"]],
	"tuft": ["A tuft on top of its head. Try a drop or a triangle.", ["drop", "tri"]],
	"paws": ["Its front paws while it sits. Small ovals work well.", ["ellipse", "drop"]],
	"foot-l": ["A foot while it sits. A small oval works well.", ["ellipse", "drop"]],
	"foot-r": ["A foot while it sits. A small oval works well.", ["ellipse", "drop"]],
}
const GENERIC := ["Pick a shape here, or any tool on the left, then drag it into place.", ["ellipse", "drop", "blob"]]
const SHORT := {"ellipse": "Oval", "rect": "Box", "tri": "Triangle", "drop": "Drop", "heart": "Heart", "star": "Star",
	"blob": "Blob", "stroke": "Line", "eye": "Eye"}

static var _starters := {}         # plan -> its starter's doc


# --- Keys -------------------------------------------------------------------------------

static func listed() -> Array:
	# Every key the ? panel lists.
	var out := []
	for g in SHORTCUTS:
		for row in g[1]:
			out.append_array(row[1])
	return out


static func is_help_key(e: InputEventKey) -> bool:
	return e.unicode == 63 or e.keycode == KEY_QUESTION or e.keycode == KEY_F1 or (e.keycode == KEY_SLASH and e.shift_pressed)


static func key_name(e: InputEventKey) -> String:
	# A key press as SHORTCUTS writes it.
	if is_help_key(e):
		return "F1" if e.keycode == KEY_F1 else "?"
	var names := {KEY_DELETE: "Del", KEY_BACKSPACE: "Backspace", KEY_PAGEUP: "PgUp", KEY_PAGEDOWN: "PgDn",
		KEY_ESCAPE: "Esc", KEY_LEFT: "Arrows", KEY_RIGHT: "Arrows", KEY_UP: "Arrows", KEY_DOWN: "Arrows"}
	var k: String = names.get(e.keycode, OS.get_keycode_string(e.keycode))
	if k == "Arrows":
		return k                     # Shift only makes the step bigger
	if e.ctrl_pressed:
		return ("Ctrl+Shift+" if e.shift_pressed else "Ctrl+") + k
	return k


static func shortcuts(st: Window) -> Control:
	# The ? panel: every shortcut, in the design's three groups.
	var c := K.c
	var v := K.vbox(4)
	v.custom_minimum_size.x = 700
	var head := K.hbox(10)
	var t := K.vbox(4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label("Shortcuts", 24, c.ink, 600, true))
	t.add_child(UI.label("Every tool also has a button. Hover over one to see its key.", 13, c.ink2, 500))
	head.add_child(t)
	head.add_child(st._ib("close", "Close (Esc)", st.close_overlay))
	v.add_child(head)
	for g in SHORTCUTS:
		v.add_child(K.margins(UI.label(str(g[0]).to_upper(), 12, c.acc_ink, 500, true), 0, 8, 0, 2))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 26)
		grid.add_theme_constant_override("v_separation", 4)
		for row in g[1]:
			var r := K.hbox(10)
			r.custom_minimum_size = Vector2(337, 30)
			var l := UI.label(row[0], 13, c.ink_body, 700)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			var ks := K.hbox(4)
			for combo in row[1]:
				if ks.get_child_count() > 0:
					ks.add_child(K.margins(Control.new(), 3, 0, 3, 0))
				for part in str(combo).split("+"):
					ks.add_child(_kbd(part))
			r.add_child(ks)
			grid.add_child(r)
		v.add_child(grid)
	return v


static func _kbd(text: String) -> Control:
	var c := K.c
	if text == text.to_lower() and text.length() > 1:
		return UI.label("+ " + text, 12, c.ink2, 700)      # a word: drag, wheel
	var p := PanelContainer.new()
	var b := K.box(c.raised, 7, c.sec_line, 2, c.sec_line, 2)
	b.content_margin_left = 6
	b.content_margin_right = 6
	p.add_theme_stylebox_override("panel", b)
	p.custom_minimum_size = Vector2(24, 24)
	var l := UI.label(text, 12, c.ink, 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


# --- The first-time tips -------------------------------------------------------------------

static func tip_bubble(st: Window, i: int) -> Control:
	# Tip i of three: by the tool rail, over the canvas, by the preview.
	var c := K.c
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := K.box(c.tip_bg, 16)
	sb.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = 270
	var v := K.vbox(4)
	p.add_child(K.margins(v, 16, 14, 16, 14))
	v.add_child(UI.label(TIPS[i][0], 16, c.tip_ink, 600, true))
	v.add_child(UI.wrap(TIPS[i][1], 13, c.tip_ink, 238))
	var bar := K.hbox(8)
	var n := UI.label("%d of %d" % [i + 1, TIPS.size()], 12, c.tip_ink, 700)
	n.modulate.a = 0.75
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(n)
	if i < TIPS.size() - 1:
		bar.add_child(_tip_button("Skip tips", false, st.skip_tips))
	bar.add_child(_tip_button("Got it" if i == TIPS.size() - 1 else "Next tip", true, st.next_tip))
	v.add_child(K.margins(bar, 0, 8, 0, 0))
	# Where it sits, in the design's units (studio_window.gd's layout).
	var left := LP.W + 2 + 60 + 2
	match i:
		0:
			p.position = Vector2(left + 12, 146)
		1:
			p.position = Vector2(left + 150, 128)
		_:
			p.anchor_left = 1.0
			p.anchor_right = 1.0
			p.anchor_top = 1.0
			p.anchor_bottom = 1.0
			p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			p.grow_vertical = Control.GROW_DIRECTION_BEGIN
			p.offset_right = -(st.SIDE_W + 2 + 14)
			p.offset_left = p.offset_right
			p.offset_bottom = -150
			p.offset_top = p.offset_bottom
	return p


static func _tip_button(text: String, primary: bool, cb: Callable) -> Button:
	var c := K.c
	var b := Button.new()
	b.text = text
	b.tooltip_text = "Stop showing the tips" if text == "Skip tips" else ("Close the tips" if text == "Got it" else "Show the next tip")
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 30
	var n := K.box(c.tip_ink if primary else Color.TRANSPARENT, 10, c.tip_ink, 2)
	n.content_margin_left = 12
	n.content_margin_right = 12
	var hv := n.duplicate()
	if not primary:
		hv.bg_color = Color(c.tip_ink, 0.14)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_font_override("font", UI.font(800))
	b.add_theme_font_size_override("font_size", 12)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, c.tip_bg if primary else c.tip_ink)
	b.pressed.connect(cb)
	return b


# --- The hint card on an empty part ---------------------------------------------------------

static func hint_for(doc: Dictionary, part: String) -> Dictionary:
	# {title, text, shapes, at}: what the card on an empty part says, the
	# shapes it offers and where they go.
	var plan: String = doc.plan
	var nm := LP.part_name(plan, part).to_lower()
	var h: Array = HINTS.get(part, GENERIC)
	var auto: Dictionary = LP.AUTO.get(plan, {})
	var title := "Add a shape to draw the %s" % nm
	var text: String = h[0]
	if part == "eyes" and Tools.symmetric(plan, part):
		text = "Eyes blink and look around by themselves. Put one down: its twin comes with it."
	if auto.has(part) and not part in KitData.PLANS.get(plan, {}).get("required", []):
		var note: String = auto[part][1]
		title = "Add a shape to draw your own %s" % nm
		text = "Until you do, it's made for you: %s." % (note.left(1).to_lower() + note.substr(1))
	return {"title": title, "text": text, "shapes": h[1], "at": usual_place(plan, part)}


static func usual_place(plan: String, part: String) -> Vector2:
	# Where the plan's starter has this part (its first shape), or the
	# middle of the frame.
	if not _starters.has(plan):
		var s := StartPage.starter(PLAN_STARTER.get(plan, "round-cat"))
		_starters[plan] = s.get("doc", {})
	var d: Dictionary = _starters[plan]
	var shapes: Array = d.get("layers", {}).get(part, [])
	return Shapes.centre(shapes[0]) if not shapes.is_empty() else Vector2(150, 170)


static func hint_card(st: Window, h: Dictionary) -> Control:
	var c := K.c
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", K.box(c.surface, 18, c.outline, 2, c.lip, 3))
	p.custom_minimum_size.x = 320
	var v := K.vbox(8)
	p.add_child(K.margins(v, 18, 16, 18, 16))
	v.add_child(UI.wrap(h.title, 17, c.ink, 284))
	(v.get_child(0) as Label).add_theme_font_override("font", UI.font(600, true))
	v.add_child(UI.wrap(h.text, 13, c.ink2, 284))
	var qs := K.hbox(6)
	var first := true
	for t in h.shapes:
		var shape: String = t
		var b := K.button(SHORT.get(shape, shape), "bp" if first else "bs", "", true, func(): st.use_hint(shape))
		b.icon = SI.line(shape, 16, c.btn_ink if first else c.ink2)
		var what: String = st.SHAPE_NAMES.get(shape, "shape")
		b.tooltip_text = "Put down %s %s where it usually goes" % ["an" if what[0] in "aeiou" else "a", what]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qs.add_child(b)
		first = false
	var skip := K.button("Skip", "bq", "", true, st.skip_hint)
	skip.tooltip_text = "Hide this card for this part"
	skip.focus_mode = Control.FOCUS_NONE
	qs.add_child(skip)
	v.add_child(K.margins(qs, 0, 4, 0, 0))
	return p


# --- Save with parts missing ---------------------------------------------------------------

static func missing_card(st: Window, need: Array) -> Control:
	# What Save still needs, each a row that picks the part.
	var c := K.c
	var v := K.vbox(10)
	v.custom_minimum_size.x = 400
	var n := need.size()
	v.add_child(UI.label("%s more part%s and it can walk" % [st._count_word(n), "" if n == 1 else "s"], 20, c.ink, 600, true))
	v.add_child(UI.wrap("Every critter needs %s. Click one to draw it." % ("this" if n == 1 else "these"), 13, c.ink2, 380))
	var list := K.vbox(6)
	for p in need:
		var part: String = p
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size.y = 38
		b.tooltip_text = "Draw the %s" % LP.part_name(st.doc.plan, part).to_lower()
		var sb := K.box(c.surface, 11, c.dng_line, 2)
		var hv := K.box(c.dng_bg, 11, c.dng_line, 2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		var h := K.hbox(8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UI.label(LP.part_name(st.doc.plan, part), 13, c.dng_ink, 700)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var chip := UI.chip("Needed", c.dng_ink, c.dng_bg, c.dng_line, 11)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(chip)
		var m := K.margins(h, 10, 0, 8, 0)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(m)
		b.pressed.connect(func():
			st.close_overlay()
			st.pick_part(part))
		list.add_child(b)
	v.add_child(list)
	var bar := K.hbox(10)
	var opt := UI.label("Everything else is optional.", 12, c.ink3, 700)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(opt)
	bar.add_child(K.button("Keep drawing", "bs", "", true, st.close_overlay))
	v.add_child(bar)
	return v
