extends RefCounted
## The Studio's layers, grouped by pose (docs/custom-critters-build-plan.md,
## D2 and P2; design/studio/builder/Builder.html and Empty.html): Every pose
## (head and face), Walking, Sitting, Napping and Extras, each part in plain
## words. A drawn part has its shape count, show/hide and lock. A needed part
## with nothing drawn is a red dashed row marked Needed, counted at the top.
## A part the critter gets for free is marked automatic (far legs, closed
## eyes, the far ear), and a pose that is automatic has Draw this pose,
## which copies the pose it is made from. An empty optional part says what
## the critter can't do without it (customs.gd NEEDS).
##
## rows() is the data and is tested headless; build() draws it.

const KitData := preload("res://critters/kit/kit_data.gd")
const Customs := preload("res://customs.gd")
const Tools := preload("res://gui/studio/tools.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")
const SI := preload("res://gui/studio/studio_icons.gd")

const W := 256
const EXTRAS := "Extras"
# [group, note, parts], per plan. Every part of the plan is in exactly one.
const LAYOUT := {
	"side": [
		["Every pose", "head and face", ["head", "eyes", "ear-l", "ear-r", "tail", "nose", "mouth-open", "eyes-closed", "head-front"]],
		["Walking", "", ["walk-body", "leg-front", "leg-back", "leg-front-far", "leg-back-far"]],
		["Sitting", "", ["body"]],
		["Napping", "", ["loaf-body"]],
		[EXTRAS, "add any time", ["wing", "back-extra", "front-extra", "stand-body", "groom-paws", "scratch-foot"]],
	],
	"front": [
		["Every pose", "head and face", ["head", "eyes", "ear-l", "ear-r", "tail", "nose", "mouth-open", "eyes-closed", "head-front"]],
		["Walking", "", ["walk-body", "leg-front", "leg-back", "leg-front-far", "leg-back-far", "head-side", "eye-side", "eye-side-closed"]],
		["Sitting", "", ["body", "paws", "foot-l", "foot-r"]],
		["Napping", "", ["loaf-body", "loaf-eyes", "loaf-eyes-closed"]],
		[EXTRAS, "add any time", ["wing", "back-extra", "front-extra", "stand-body", "groom-paws", "scratch-foot"]],
	],
	"upright": [
		["Every pose", "head and face", ["head", "eyes", "eyes-closed", "tuft", "tail", "mouth-open", "head-front"]],
		["Walking", "", ["leg-near", "leg-far", "walk-body", "wing-side"]],
		["Sitting", "", ["body", "wing-l", "wing-r", "foot-l", "foot-r"]],
		["Napping", "", ["loaf-body"]],
		[EXTRAS, "add any time", ["back-extra", "front-extra"]],
	],
	"blob": [
		["Every pose", "face", ["eyes", "head", "eyes-closed", "mouth-open", "ear-l", "ear-r", "tail", "head-front"]],
		["Walking", "", ["body"]],
		["Napping", "", ["loaf-body"]],
		[EXTRAS, "add any time", ["back-extra"]],
	],
}
const NAMES := {
	"head": "Head", "eyes": "Eyes", "ear-l": "Ear", "ear-r": "Far ear", "tail": "Tail", "nose": "Nose",
	"mouth-open": "Open mouth", "eyes-closed": "Closed eyes", "head-front": "Horns or fringe",
	"walk-body": "Body", "leg-front": "Front leg", "leg-back": "Back leg", "leg-front-far": "Far front leg",
	"leg-back-far": "Far back leg", "body": "Sitting body", "loaf-body": "Napping body", "wing": "Wing",
	"back-extra": "Mane or shell", "front-extra": "Bib or belly patch", "stand-body": "Standing up",
	"groom-paws": "Grooming paws", "scratch-foot": "Scratching foot", "head-side": "Side face",
	"eye-side": "Side eye", "eye-side-closed": "Side eye, closed", "paws": "Paws", "foot-l": "Foot",
	"foot-r": "Other foot", "loaf-eyes": "Napping eyes", "loaf-eyes-closed": "Napping eyes, closed",
	"leg-near": "Leg", "leg-far": "Far leg", "wing-l": "Wing", "wing-r": "Other wing",
	"wing-side": "Wing, walking", "tuft": "Tuft",
}
const PLAN_NAMES := {"front": {"body": "Body, facing you", "walk-body": "Walking body", "ear-r": "Other ear"},
	"upright": {"body": "Body, facing you", "walk-body": "Walking body", "mouth-open": "Open beak"},
	"blob": {"body": "Body", "ear-l": "Antenna or fin", "ear-r": "Other antenna"}}
const PLAN_CHIP := {"side": "Side-on, walks on four", "front": "Faces you", "upright": "Upright, on two legs", "blob": "Blob, no legs"}
# What the critter gets when a part isn't drawn: [made from, what it is,
# whether it is a pose (Draw this pose)]. A pose is automatic even before its
# source is drawn; anything else only once its source is.
const AUTO := {
	"side": {"leg-front-far": ["leg-front", "Made from your front leg, a little darker", false],
		"leg-back-far": ["leg-back", "Made from your back leg, a little darker", false],
		"ear-r": ["ear-l", "Made from your ear, a little darker", false],
		"eyes-closed": ["eyes", "Happy arcs where the eyes are", false],
		"body": ["walk-body", "It sits in its walking body, legs at rest", true],
		"loaf-body": ["walk-body", "The walking body, lowered and squashed, legs tucked away", true]},
	"front": {"leg-front-far": ["leg-front", "Made from your front leg, a little darker", false],
		"leg-back-far": ["leg-back", "Made from your back leg, a little darker", false],
		"ear-r": ["ear-l", "Your ear, mirrored", false],
		"eyes-closed": ["eyes", "Happy arcs where the eyes are", false],
		"head-side": ["head", "The front face stays on while it walks", false],
		"loaf-body": ["body", "The sitting body, lowered and squashed", true]},
	"upright": {"leg-far": ["leg-near", "Made from your leg, a little darker", false],
		"wing-r": ["wing-l", "Your wing, mirrored", false],
		"wing-side": ["wing-l", "Your wing, while it walks", false],
		"eyes-closed": ["eyes", "Happy arcs where the eyes are", false],
		"walk-body": ["body", "It walks in its front body", true],
		"loaf-body": ["body", "Settles down as a ball", true]},
	"blob": {"eyes-closed": ["eyes", "Happy arcs where the eyes are", false],
		"loaf-body": ["body", "The body, melted down", true]},
}
const MOVE_WORDS := {"yawn": "yawns", "sneeze": "sneezes", "ear_flick": "ear flicks", "tail_swish": "tail swishes",
	"chase_tail": "chasing its tail", "nose_twitch": "nose twitches", "stand_lookout": "standing up to look",
	"groom": "grooming", "scratch": "scratching", "preen": "preening", "peck_ground": "pecking"}

var st: Window                     # studio_window.gd
var extras_open := false


func _init(studio: Window) -> void:
	st = studio


# --- The data ----------------------------------------------------------------------------

static func part_name(plan: String, part: String) -> String:
	return PLAN_NAMES.get(plan, {}).get(part, NAMES.get(part, part))


static func group_of(plan: String, part: String) -> String:
	for g in LAYOUT.get(plan, []):
		if part in g[2]:
			return g[0]
	return ""


static func needed(doc: Dictionary) -> Array:
	# The plan's required parts with nothing drawn.
	var pl: Dictionary = KitData.PLANS.get(doc.plan, {})
	return pl.get("required", []).filter(func(p): return Tools.layer(doc, p).is_empty())


static func cost(plan: String, part: String, drawn: Array) -> String:
	# What an empty optional part costs, in the player's words.
	var lost := []
	for b in Customs.NEEDS:
		var n: Dictionary = Customs.NEEDS[b]
		if n.has("plans") and not plan in n.plans:
			continue
		var takes: bool = part in n.get("parts", []) or (part in n.get("any", []) and n.any.all(func(x): return x == part or not x in drawn))
		if takes and MOVE_WORDS.has(b) and not MOVE_WORDS[b] in lost:
			lost.append(MOVE_WORDS[b])
	return "Without one: no %s" % " or ".join(lost) if not lost.is_empty() else "Optional"


static func rows(doc: Dictionary, selected := "", extras_open := false) -> Array:
	# Every row of the panel, in order: {kind: group, part (drawn), missing
	# (needed, empty), auto, empty (optional), more (the folded extras)}.
	var plan: String = doc.plan
	var required: Array = KitData.PLANS.get(plan, {}).get("required", [])
	var drawn: Array = doc.layers.keys()
	var autos: Dictionary = AUTO.get(plan, {})
	var out := []
	for g in LAYOUT.get(plan, []):
		var note: String = g[1]
		if note == "" and g[2].any(func(p): return p in required):
			note = "needed"
		out.append({"kind": "group", "label": g[0], "note": note})
		var folded := []
		for p in g[2]:
			var row := {"part": p, "label": part_name(plan, p)}
			if p in drawn:
				row.kind = "part"
				row.count = Tools.layer(doc, p).size()
			elif p in required:
				row.kind = "missing"
				row.note = "Needed to walk"
			elif autos.has(p) and (autos[p][2] or autos[p][0] in drawn):
				row.kind = "auto"
				row.note = autos[p][1]
				row.from = autos[p][0]
				row.pose = autos[p][2] and autos[p][0] in drawn
			elif g[0] == EXTRAS and not extras_open and p != selected:
				folded.append(p)
				continue
			else:
				row.kind = "empty"
				row.note = cost(plan, p, drawn)
			out.append(row)
		if not folded.is_empty():
			var names: Array = folded.slice(0, 3).map(func(p): return part_name(plan, p).to_lower())
			out.append({"kind": "more", "label": "%d more: %s%s" % [folded.size(), ", ".join(names), "..." if folded.size() > 3 else ""], "parts": folded})
	return out


static func pose_of(plan: String, part: String) -> String:
	# Which pose the canvas shows while a part is picked: walk, sit or nap.
	match group_of(plan, part):
		"Sitting":
			return "sit"
		"Napping":
			return "nap"
		"Walking":
			return "walk"
	return ""


static func pose_parts(plan: String, pose: String) -> Array:
	# The parts drawn together on the canvas for a pose: every pose's parts,
	# the pose's own and the extras.
	var want: String = {"walk": "Walking", "sit": "Sitting", "nap": "Napping"}.get(pose, "Walking")
	var out := []
	for g in LAYOUT.get(plan, []):
		if g[0] == want or g[0] == EXTRAS or g[0] == "Every pose":
			out.append_array(g[2])
	return out


# --- Drawing it ------------------------------------------------------------------------

func build() -> Control:
	var c := K.c
	var doc: Dictionary = st.doc
	var p := PanelContainer.new()
	p.custom_minimum_size.x = W
	p.add_theme_stylebox_override("panel", K.box(c.surface, 0))
	var v := K.vbox(0)
	p.add_child(v)
	var head := K.hbox(8)
	head.add_child(UI.label("Layers", 17, c.ink, 600, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var need := needed(doc)
	if need.is_empty():
		head.add_child(UI.chip(PLAN_CHIP.get(doc.plan, doc.plan), c.acc_ink, c.track))
	else:
		head.add_child(UI.chip("%d needed to walk" % need.size(), c.dng_ink, c.dng_bg, c.dng_line))
	v.add_child(K.margins(head, 14, 14, 14, 8))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := K.vbox(2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(K.margins(list, 10, 0, 10, 10))
	for r in rows(doc, st.part, extras_open):
		list.add_child(_row(r))
	return p


func _row(r: Dictionary) -> Control:
	var c := K.c
	if r.kind == "group":
		var g := K.hbox(6)
		g.add_child(UI.label(str(r.label).to_upper(), 12, c.acc_ink, 500, true))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(gap)
		if r.note != "":
			g.add_child(UI.label(r.note, 11, c.ink3, 700))
		return K.margins(g, 4, 8, 4, 3)
	var sel: bool = r.get("part", "") == st.part
	var tall: bool = r.kind in ["missing", "empty"] or (r.kind == "auto" and r.get("pose", false))
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 46 if tall else 33
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg: Color = c.chip_sel if sel else Color.TRANSPARENT
	var line: Color = c.outline if sel else Color.TRANSPARENT
	if r.kind == "missing" and not sel:
		line = c.dng_line
	elif r.kind in ["empty", "more"] and not sel:
		line = c.chip_line
	var sb := K.box(bg, 11, line, 2, c.lip, 2 if sel else 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 6
	row.add_theme_stylebox_override("panel", sb)
	if r.kind in ["missing", "empty", "more"] and not sel:
		row.draw.connect(func(): _dashed(row, line))
		sb.border_color = Color.TRANSPARENT
	var h := K.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var ink: Color = c.ink if sel else c.ink_body
	if r.kind == "auto":
		h.add_child(UI.icon(SI.line("auto", 15, c.ink3)))
		ink = c.ink3
	elif r.kind in ["empty", "more"]:
		h.add_child(UI.icon(SI.line("plus", 16, c.ink3)))
		ink = c.ink3
	elif r.kind == "missing":
		ink = c.ink if sel else c.dng_ink
	var names := K.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := UI.label(r.label, 13, ink, 700)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	names.add_child(nm)
	if r.kind == "auto" and not r.pose:
		nm.text = "%s  · automatic" % r.label
	elif tall:
		var small := UI.label("Automatic" if r.kind == "auto" else str(r.get("note", "")), 11, c.ink3, 700)
		small.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		small.clip_text = true
		names.add_child(small)
	h.add_child(names)
	match r.kind:
		"part":
			h.add_child(UI.label(str(r.count), 11, c.ink3, 800))
			var part: String = r.part
			var hidden: bool = st.hidden.has(part)
			var locked: bool = st.locked.has(part)
			h.add_child(_icon("hide" if hidden else "show", "Show" if hidden else "Hide", func(): st.toggle_hidden(part)))
			h.add_child(_icon("lock" if locked else "unlock", "Unlock" if locked else "Lock", func(): st.toggle_locked(part)))
		"missing":
			h.add_child(UI.chip("Needed", c.dng_ink, c.dng_bg, c.dng_line, 11))
		"auto":
			if r.pose:
				var from: String = r.from
				var part: String = r.part
				var b := K.button("Draw this pose", "bs", "", true, func(): st.draw_pose(part, from))
				b.custom_minimum_size.y = 26
				b.add_theme_font_size_override("font_size", 12)
				b.focus_mode = Control.FOCUS_NONE
				b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				h.add_child(b)
	if r.kind == "auto":
		row.tooltip_text = r.note
	var part_id: String = r.get("part", "")
	row.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if r.kind == "more":
				extras_open = true
				st.refresh_layers()
			else:
				st.pick_part(part_id))
	return row


func _icon(name: String, tip: String, cb: Callable) -> Button:
	var c := K.c
	var b := Button.new()
	b.icon = SI.line(name, 16, c.ink3)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(22, 22)
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", K.box(Color.TRANSPARENT, 7))
	b.add_theme_stylebox_override("hover", K.box(c.track, 7))
	b.add_theme_stylebox_override("pressed", K.box(c.track, 7))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


static func _dashed(ctl: Control, colour: Color) -> void:
	# The design's dashed border for a needed or empty part.
	var r := Rect2(Vector2(1, 1), ctl.size - Vector2(2, 2))
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	for i in 4:
		ctl.draw_dashed_line(pts[i], pts[i + 1], colour, 2.0, 5.0)
