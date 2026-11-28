extends RefCounted
## Pins mode (docs/custom-critters-build-plan.md, D6, 4.7, P4;
## design/studio/builder/Pins.html): the joints the critter turns its head,
## swings its legs and swishes its tail round, as dots on the canvas.
##
## Each pin is suggested from the shapes (shapes.gd suggest_pins) and follows
## them until the player drags it; only dragged pins are kept in the doc's
## "pins". A dragged pin stays inside its box: within PIN_SLACK (60 units)
## of where it was suggested, inside the frame, and a hip below the neck.
## Put it back drops it from the doc, so it follows the shapes again.
##
## A joint is where a part turns and where it sits, so dragging the neck
## moves both: "head" (where the head turns in its own drawing) goes with the
## neck it is drawn on, so the head stays where it was drawn.
##
## The functions are plain ones on the doc, tested headless; build() draws
## the list that stands in for the layers in this mode.

const Shapes := preload("res://studio/shapes.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")
const SI := preload("res://gui/studio/studio_icons.gd")

const W := 256
# The pins shown for each plan, in order, and the part each needs drawn.
const PINS := {
	"side": ["neck-walk", "hip-front", "hip-back", "tail", "ear-l", "ear-r", "eyes"],
	"front": ["neck-sit", "neck-walk", "hip-front", "hip-back", "tail", "ear-l", "eyes"],
	"upright": ["neck-sit", "hip", "wing-l", "tuft", "eyes"],
	"blob": ["eyes", "tail", "ear-l", "ear-r"],
}
const NAMES := {"neck-walk": ["Neck", "where the head turns"], "neck-sit": ["Neck", "where the head sits"],
	"hip-front": ["Front hip", "where the front leg swings"], "hip-back": ["Back hip", "where the back leg swings"],
	"hip": ["Hip", "where the leg swings"], "tail": ["Tail", "where it swishes from"], "ear-l": ["Ear", "where it flicks"],
	"ear-r": ["Far ear", "where it flicks"], "eyes": ["Eyes", "where it looks from"], "wing-l": ["Wing", "where it flaps"],
	"tuft": ["Tuft", "where it springs from"]}
const PLAN_NAMES := {"front": {"neck-walk": ["Neck, walking", "where the head sits as it walks"]},
	"blob": {"ear-l": ["Antenna", "where it wiggles"], "ear-r": ["Other antenna", "where it wiggles"]}}
const HIPS := ["hip-front", "hip-back", "hip"]

var st: Window                     # studio_window.gd


func _init(studio: Window) -> void:
	st = studio


# --- The data -----------------------------------------------------------------------------

static func pin_name(plan: String, pin: String) -> Array:
	return PLAN_NAMES.get(plan, {}).get(pin, NAMES.get(pin, [pin, ""]))


static func suggested(doc: Dictionary) -> Dictionary:
	# pin -> Vector2, from the shapes alone.
	var out := {}
	var s := Shapes.suggest_pins(doc.layers, doc.plan)
	for k in s:
		out[k] = Vector2(s[k][0], s[k][1])
	return out


static func shown(doc: Dictionary) -> Array:
	# The plan's pins that have something to turn (their part is drawn).
	var sug := suggested(doc)
	return PINS.get(doc.plan, []).filter(func(p): return sug.has(p))


static func at(doc: Dictionary, pin: String) -> Vector2:
	# Where a pin is now: moved, else suggested.
	var v = doc.pins.get(pin)
	if typeof(v) == TYPE_ARRAY and v.size() >= 2:
		return Vector2(v[0], v[1])
	return suggested(doc).get(pin, Vector2(150, 150))


static func moved(doc: Dictionary, pin: String) -> bool:
	return doc.pins.has(pin)


static func box(doc: Dictionary, pin: String) -> Rect2:
	# Where it may go: PIN_SLACK round its suggestion, inside the frame.
	var c: Vector2 = suggested(doc).get(pin, at(doc, pin))
	var r := Rect2(c - Vector2.ONE * KitData.PIN_SLACK, Vector2.ONE * KitData.PIN_SLACK * 2.0)
	return r.intersection(Rect2(Vector2.ZERO, KitData.FRAME))


static func clamp_pin(doc: Dictionary, pin: String, p: Vector2) -> Vector2:
	var r := box(doc, pin)
	var q := p.clamp(r.position, r.end)
	if pin in HIPS:
		var neck := at(doc, "neck-walk" if doc.plan != "upright" else "neck-sit")
		q.y = maxf(q.y, minf(neck.y + 1.0, r.end.y))
	return q.round()


static func set_pin(doc: Dictionary, pin: String, p: Vector2) -> Vector2:
	# Moves a pin, within its box. Returns where it went.
	var q := clamp_pin(doc, pin, p)
	doc.pins[pin] = [q.x, q.y]
	if _carries_head(doc.plan, pin):
		doc.pins["head"] = [q.x, q.y]
	return q


static func reset(doc: Dictionary, pin := "") -> void:
	# Put it back (or every pin, with none named).
	if pin == "":
		doc.pins.clear()
		return
	doc.pins.erase(pin)
	if _carries_head(doc.plan, pin):
		doc.pins.erase("head")


static func _carries_head(plan: String, pin: String) -> bool:
	# The neck the head is drawn on: walking side-on, sitting otherwise.
	return pin == ("neck-walk" if plan == "side" else "neck-sit")


static func pin_at(doc: Dictionary, u: Vector2, reach: float) -> String:
	# The pin under u (frame units), or "".
	var best := ""
	var bd := reach
	for p in shown(doc):
		var d := at(doc, p).distance_to(u)
		if d <= bd:
			bd = d
			best = p
	return best


# --- Drawing the list ------------------------------------------------------------------

func build() -> Control:
	var c := K.c
	var doc: Dictionary = st.doc
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(c.surface, 0))
	var v := K.vbox(8)
	p.add_child(K.margins(v, 12, 14, 12, 12))
	var head := K.hbox(8)
	head.add_child(UI.label("Pins", 17, c.ink, 600, true))
	var pins := shown(doc)
	head.add_child(UI.label("%d joints" % pins.size(), 12, c.ink3, 700))
	v.add_child(head)
	v.add_child(UI.wrap("Pins are the joints. It turns its head, swings its legs and swishes its tail round them. We put them where they usually go; drag one if something bends in the wrong place.", 12, c.ink2, W - 24))
	if pins.is_empty():
		v.add_child(UI.wrap("Draw the head, body and legs first: the pins come with them.", 12, c.ink3, W - 24))
	for pin in pins:
		v.add_child(_row(doc, pin))
	if st.pin_sel != "" and moved(doc, st.pin_sel):
		var nm: String = pin_name(doc.plan, st.pin_sel)[0]
		v.add_child(K.button("Put the %s back" % nm.to_lower(), "bs", "", true, func(): st.reset_pins(st.pin_sel)))
	var all_b := K.button("Put every pin back", "bq", "", true, func(): st.reset_pins(""))
	all_b.disabled = doc.pins.is_empty()
	v.add_child(all_b)
	v.add_child(UI.wrap("Pins move with your shapes. If you change the body later, the ones you haven't moved follow it.", 11, c.ink3, W - 24))
	return p


func _row(doc: Dictionary, pin: String) -> Control:
	var c := K.c
	var sel: bool = st.pin_sel == pin
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 40
	var n := K.box(c.chip_sel if sel else Color.TRANSPARENT, 12, c.outline if sel else Color.TRANSPARENT, 2)
	var hv := n.duplicate()
	if not sel:
		hv.bg_color = c.ground
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", n)
	var h := K.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var nm: Array = pin_name(doc.plan, pin)
	var t := K.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(UI.label(nm[0], 13, c.ink, 800))
	t.add_child(UI.label(nm[1], 11, c.ink3, 700))
	h.add_child(t)
	var tag := UI.label("Moved" if moved(doc, pin) else "Suggested", 11, c.acc_ink if moved(doc, pin) else c.ink3, 800)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tag)
	b.add_child(K.margins(h, 10, 2, 10, 2))
	(b.get_child(0) as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(b.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func(): st.pick_pin(pin))
	return b
