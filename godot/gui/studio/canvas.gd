extends Control
## The Studio canvas (docs/custom-critters-build-plan.md, D2 and D3;
## design/studio/builder/canvas.js): the cast's 300 x 280 frame with 120 units
## of headroom above it for hats, the ground line at 262, the middle line, a
## faint guide critter (the kitten, in the pose being drawn), zoom from 50% to
## 400%, pan, and a grid from 200%.
##
## The picked layer is drawn in full and the others in the same pose faintly,
## so a part is drawn in place. Each layer is the SVG shape_svg.gd writes
## (P6, decided in A1: SVG throughout), rasterised again only when it changes
## or the zoom does, at most once a frame. Hit-testing uses the shapes'
## polygons (shapes.gd).
##
## The mouse becomes tools.gd calls: a shape tool places a shape; otherwise a
## click selects (Shift adds), a drag moves, a drag on empty canvas selects
## by box, and the handles scale, turn, move points and round corners. A drag
## is one undo step, recorded when it first moves. Space, the middle button
## or the Pan tool drag the view; Ctrl and the wheel zoom.

const Shapes := preload("res://studio/shapes.gd")
const Writer := preload("res://studio/shape_svg.gd")
const Tools := preload("res://gui/studio/tools.gd")
const LP := preload("res://gui/studio/layers_panel.gd")
const Pins := preload("res://gui/studio/pins_panel.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")

const VIEW := Rect2(-60, -120, 420, 480)    # what a layer is rasterised over, in frame units
const FRAME := Rect2(0, -120, 300, 400)     # the frame and its headroom
const FIT := Rect2(-34, -126, 368, 420)     # what Fit shows
const ZOOM_MIN := 0.5
const ZOOM_MAX := 4.0
const GRID_FROM := 2.0                      # the grid shows from 200%
const GRID := 10.0
const FAINT := 0.35
const RASTER_MAX := 3.0
const HANDLE := 6.0                         # px
# Back to front, for every plan.
const ORDER := ["back-extra", "tail", "wing-r", "leg-back-far", "leg-front-far", "leg-far", "ear-r", "ear-l",
	"walk-body", "body", "loaf-body", "stand-body", "leg-back", "leg-front", "leg-near", "foot-l", "foot-r", "paws",
	"front-extra", "wing-l", "wing-side", "wing", "head", "head-side", "tuft", "eyes", "eye-side", "eyes-closed",
	"eye-side-closed", "loaf-eyes", "loaf-eyes-closed", "nose", "mouth-open", "head-front", "groom-paws", "scratch-foot"]
# Drawn instead of another, so only while picked.
const ALTERNATES := ["eyes-closed", "eye-side-closed", "loaf-eyes-closed", "mouth-open"]
# The guide: the kitten's own parts (res://art/kitten), each moved from its
# own pivot onto the pin it hangs from in that pose (fixtures.gd's KITTEN_PINS).
const GUIDE := {
	"walk": [["tail", Vector2(26, -34)], ["leg-back-far", Vector2(96, 0)], ["leg-front-far", Vector2(16, 0)],
		["walk-body", Vector2.ZERO], ["leg-back", Vector2(78, 0)], ["leg-front", Vector2(-2, 0)],
		["ear-r", Vector2(-38, 8)], ["ear-l", Vector2(-38, 8)], ["head", Vector2(-38, 8)], ["eyes", Vector2(-38, 8)]],
	"sit": [["tail", Vector2.ZERO], ["body", Vector2.ZERO], ["foot-l", Vector2.ZERO], ["foot-r", Vector2.ZERO],
		["paws", Vector2.ZERO], ["ear-r", Vector2.ZERO], ["ear-l", Vector2.ZERO], ["head", Vector2.ZERO], ["eyes", Vector2.ZERO]],
	"nap": [["loaf-tail", Vector2.ZERO], ["loaf-body", Vector2.ZERO], ["loaf-paws", Vector2.ZERO],
		["ear-r", Vector2(0, 22)], ["ear-l", Vector2(0, 22)], ["head", Vector2(0, 22)], ["eyes-closed", Vector2(0, 22)]],
}

var st: Window                     # studio_window.gd
var zoom := 1.0
var origin := Vector2.ZERO         # where the frame's (0, 0) is, in px
var fitted := false
var tex := {}                      # part -> ImageTexture
var tex_scale := {}                # part -> the scale it was rasterised at
var dirty := {}                    # parts to rasterise again
var guides := {}                   # pose -> ImageTexture
var space := false
var drag := ""                     # "", pan, move, handle, box
var drag_from := Vector2.ZERO      # frame units
var drag_i := -1                   # the shape a handle drag works on (its index when the drag began)
var drag_handle := ""
var drag_orig: Array = []          # the layer when the drag began
var drag_moved := false
var box_rect := Rect2()
var box_base: Array = []


func _init(studio: Window) -> void:
	st = studio
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func():
		if not fitted and size.x > 10.0:
			fit())


func to_px(u: Vector2) -> Vector2:
	return origin + u * zoom


func to_frame(px: Vector2) -> Vector2:
	return (px - origin) / zoom


func fit() -> void:
	fitted = true
	zoom = clampf(minf(size.x / FIT.size.x, size.y / FIT.size.y), ZOOM_MIN, ZOOM_MAX)
	origin = size * 0.5 - FIT.get_center() * zoom
	_zoomed()


func set_zoom(z: float, about := Vector2(-1, -1)) -> void:
	if about.x < 0.0:
		about = size * 0.5
	var u := to_frame(about)
	zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	origin = about - u * zoom
	_zoomed()


func _zoomed() -> void:
	for p in tex:
		dirty[p] = true
	st.zoom_changed()
	queue_redraw()


func mark(parts: Array) -> void:
	for p in parts:
		dirty[p] = true
		if p == "eyes":   # the blush sits on the head (or a blob's body)
			dirty["head"] = true
			dirty["body"] = true
	queue_redraw()


func mark_all() -> void:
	tex.clear()
	mark(st.doc.layers.keys())


func _raster_scale() -> float:
	return clampf(snappedf(zoom * st.content_scale_factor, 0.25), 0.25, RASTER_MAX)


func _process(_delta: float) -> void:
	if dirty.is_empty():
		return
	var sc := _raster_scale()
	for p in dirty:
		_raster(p, sc)
	dirty.clear()
	queue_redraw()


func _raster(part: String, sc: float) -> void:
	var shapes := Tools.layer(st.doc, part)
	if shapes.is_empty():
		tex.erase(part)
		return
	var style: Dictionary = st.doc.style
	var eyes := Tools.layer(st.doc, "eyes")
	var extra := ""
	if style.blush and not eyes.is_empty() and (part == "head" or (part == "body" and not st.doc.layers.has("head"))):
		extra = Writer._blush(eyes)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%d %d %d %d" width="%d" height="%d">' % [
		VIEW.position.x, VIEW.position.y, VIEW.size.x, VIEW.size.y, VIEW.size.x, VIEW.size.y] \
		+ Writer.layer(shapes, style.outline, style.width, part, extra) + "</svg>"
	var img := Image.new()
	if img.load_svg_from_string(svg, sc) != OK:
		tex.erase(part)
		return
	tex[part] = ImageTexture.create_from_image(img)
	tex_scale[part] = sc


func _guide(pose: String) -> ImageTexture:
	# The kitten in this pose, grey, made once.
	if guides.has(pose):
		return guides[pose]
	var inner := ""
	for g in GUIDE.get(pose, GUIDE.walk):
		var s := FileAccess.get_file_as_string("res://art/kitten/%s.svg" % g[0])
		if s == "":
			continue
		var a := s.find(">", s.find("<svg")) + 1
		var shift: Vector2 = g[1]
		inner += '<g transform="translate(%s %s)">%s</g>' % [shift.x, shift.y, s.substr(a, s.rfind("</svg>") - a)]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%d %d %d %d" width="%d" height="%d">%s</svg>' % [
		VIEW.position.x, VIEW.position.y, VIEW.size.x, VIEW.size.y, VIEW.size.x, VIEW.size.y, inner]
	var img := Image.new()
	img.load_svg_from_string(svg, 1.5)
	img.adjust_bcs(1.0, 1.0, 0.0)
	guides[pose] = ImageTexture.create_from_image(img)
	return guides[pose]


func shown_parts() -> Array:
	# The layers drawn now, back to front.
	var in_pose := LP.pose_parts(st.doc.plan, st.pose)
	var out := []
	var pins: bool = st.view_mode == "pins"
	for p in ORDER:
		if (p == st.part and not pins) or (p in in_pose and not p in ALTERNATES and (st.others_on or pins)):
			if st.doc.layers.has(p) and not st.hidden.has(p):
				out.append(p)
	return out


# --- Drawing ----------------------------------------------------------------------------

func _draw() -> void:
	var c := K.c
	var font := UI.font(700)
	draw_rect(Rect2(Vector2.ZERO, size), c.ground)
	# The frame, its headroom and the middle line.
	var fr := Rect2(to_px(FRAME.position), FRAME.size * zoom)
	draw_rect(fr, c.surface)
	draw_rect(Rect2(fr.position, Vector2(fr.size.x, 120.0 * zoom)), Color(c.ground, 0.7))
	draw_rect(fr, c.line, false, 1.6)
	draw_dashed_line(to_px(Vector2(0, 0)), to_px(Vector2(300, 0)), c.dash, 1.2, 4.0 * zoom)
	draw_string(font, to_px(Vector2(8, -108)), "Room for hats", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c.ink3)
	draw_dashed_line(to_px(Vector2(150, -120)), to_px(Vector2(150, 280)), c.dash, 1.0, 3.0 * zoom)
	if zoom >= GRID_FROM:
		var x := GRID
		while x < 300.0:
			draw_line(to_px(Vector2(x, -120)), to_px(Vector2(x, 280)), c.div, 1.0)
			x += GRID
		var y := -120.0 + GRID
		while y < 280.0:
			draw_line(to_px(Vector2(0, y)), to_px(Vector2(300, y)), c.div, 1.0)
			y += GRID
	var view := Rect2(to_px(VIEW.position), VIEW.size * zoom)
	if st.guide_on:
		draw_texture_rect(_guide(st.pose), view, false, Color(1, 1, 1, 0.16))
	for p in shown_parts():
		if tex.has(p):
			draw_texture_rect(tex[p], view, false, Color(1, 1, 1, 1.0 if p == st.part or st.view_mode == "pins" else FAINT))
	# The ground.
	draw_dashed_line(to_px(Vector2(-30, Tools.GROUND)), to_px(Vector2(330, Tools.GROUND)), c.acc_ink, 1.6, 6.0 * zoom)
	draw_string(font, to_px(Vector2(296, Tools.GROUND + 13)) - Vector2(44, 0), "Ground", HORIZONTAL_ALIGNMENT_RIGHT, 44, 11, c.acc_ink)
	if st.view_mode == "pins":
		_draw_pins()
	else:
		_draw_selection()
	if drag == "box":
		var r := Rect2(to_px(box_rect.abs().position), box_rect.abs().size * zoom)
		draw_rect(r, Color(c.acc_ink, 0.08))
		draw_rect(r, c.acc_ink, false, 1.2)


func _draw_selection() -> void:
	var c := K.c
	var shapes := Tools.layer(st.doc, st.part)
	var sel: Array = st.sel.filter(func(i): return i < shapes.size())
	if sel.is_empty():
		return
	if sel.size() > 1:
		for i in sel:
			_outline(Shapes.polygon(shapes[i]), c.acc_ink)
		var r := Tools.rect_of(st.doc, st.part, sel)
		_dashed_rect(PackedVector2Array([to_px(r.position), to_px(Vector2(r.end.x, r.position.y)), to_px(r.end), to_px(Vector2(r.position.x, r.end.y))]), c.acc_ink)
		return
	var s: Dictionary = shapes[sel[0]]
	var b := Tools.box(s)
	var cen: Vector2 = b.c
	var half: Vector2 = b.half
	var ax: Vector2 = b.ax
	var ay: Vector2 = b.ay
	var corners := PackedVector2Array()
	for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		corners.append(to_px(cen + ax * k.x * half.x + ay * k.y * half.y))
	_dashed_rect(corners, c.acc_ink)
	if s.has("pts"):
		_outline(Shapes.catmull(Shapes._pts(s), s.t == "blob"), Color(c.acc_ink, 0.6), s.t == "blob")
	var top := to_px(cen - ay * half.y)
	for h in Tools.handles(s, zoom):
		var at := to_px(h[1])
		var id: String = h[0]
		if id == "rot":
			draw_line(top, at, c.acc_ink, 1.3)
			draw_circle(at, 4.5, c.knob)
			draw_circle(at, 4.5, c.acc_ink, false, 1.4)
		elif id == "r":
			draw_circle(at, 4.0, c.acc_ink)
		elif id.begins_with("p:"):
			draw_circle(at, 5.0, c.knob)
			draw_circle(at, 5.0, c.acc_ink, false, 1.6)
		else:
			var hr := Rect2(at - Vector2(HANDLE, HANDLE) * 0.5, Vector2(HANDLE, HANDLE))
			draw_rect(hr, c.knob)
			draw_rect(hr, c.acc_ink, false, 1.4)
	# The size, under the box.
	var low := corners[0]
	for p in corners:
		if p.y > low.y:
			low = p
	var tag := "%d x %d" % [roundi(half.x * 2.0), roundi(half.y * 2.0)]
	var tp := Vector2(to_px(cen).x - 24.0, low.y + 8.0)
	draw_rect(Rect2(tp, Vector2(48, 16)), c.tip_bg)
	draw_string(UI.font(800), tp + Vector2(0, 12), tag, HORIZONTAL_ALIGNMENT_CENTER, 48, 10, c.tip_ink)


func _draw_pins() -> void:
	# Pins mode: each joint a dot with its name; the picked one with the box
	# it must stay in and, once moved, where it was suggested.
	var c := K.c
	var font := UI.font(800)
	var doc: Dictionary = st.doc
	for p in Pins.shown(doc):
		var at := to_px(Pins.at(doc, p))
		var picked: bool = p == st.pin_sel
		if picked:
			var b := Pins.box(doc, p)
			_dashed_rect(PackedVector2Array([to_px(b.position), to_px(Vector2(b.end.x, b.position.y)), to_px(b.end), to_px(Vector2(b.position.x, b.end.y))]), c.acc_ink)
			if Pins.moved(doc, p):
				var was := to_px(Pins.suggested(doc).get(p, Pins.at(doc, p)))
				draw_arc(was, 6.0, 0.0, TAU, 20, Color(c.acc_ink, 0.6), 1.4)
				draw_dashed_line(was, at, Color(c.acc_ink, 0.6), 1.2, 3.0)
		draw_circle(at, 8.0 if picked else 6.5, c.acc_ink if picked else c.knob)
		draw_circle(at, 8.0 if picked else 6.5, c.outline, false, 2.0)
		var label: String = Pins.pin_name(doc.plan, p)[0]
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var tp := at + Vector2(10, -10)
		draw_rect(Rect2(tp - Vector2(4, 12), Vector2(tw + 8, 16)), c.tip_bg)
		draw_string(font, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c.tip_ink)


func _outline(poly: PackedVector2Array, colour: Color, closed := true) -> void:
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(to_px(p))
	if closed and pts.size() > 0:
		pts.append(pts[0])
	if pts.size() >= 2:
		draw_polyline(pts, colour, 1.2)


func _dashed_rect(corners: PackedVector2Array, colour: Color) -> void:
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], colour, 1.3, 4.0)


# --- The mouse ------------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	if e is InputEventKey:
		if e.keycode == KEY_SPACE and not e.ctrl_pressed:
			space = e.pressed
			mouse_default_cursor_shape = Control.CURSOR_DRAG if space else Control.CURSOR_ARROW
			accept_event()
		elif e.pressed and st.key(e):
			accept_event()
		return
	if e is InputEventMouseButton:
		_button(e as InputEventMouseButton)
		accept_event()
	elif e is InputEventMouseMotion:
		_motion(e as InputEventMouseMotion)


func _button(e: InputEventMouseButton) -> void:
	var px := e.position
	if e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var up := e.button_index == MOUSE_BUTTON_WHEEL_UP
		if e.ctrl_pressed:
			set_zoom(zoom * (1.1 if up else 1.0 / 1.1), px)
		else:
			origin += (Vector2(1, 0) if e.shift_pressed else Vector2(0, 1)) * (40.0 if up else -40.0)
			queue_redraw()
		return
	if e.button_index == MOUSE_BUTTON_MIDDLE or (e.button_index == MOUSE_BUTTON_LEFT and (space or st.tool == "pan")):
		drag = "pan" if e.pressed else ""
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	if not e.pressed:
		_release()
		return
	grab_focus()
	var u := to_frame(px)
	if st.view_mode == "pins":
		var pin := Pins.pin_at(st.doc, u, 10.0 / zoom)
		if pin != "":
			st.pick_pin(pin)
			_begin("pin", u)
			drag_handle = pin
		return
	if st.tool in Shapes.TYPES:
		st.place(st.tool, u)
		return
	_press(u, e.shift_pressed)


func _press(u: Vector2, shift: bool) -> void:
	var part: String = st.part
	var shapes := Tools.layer(st.doc, part)
	if st.editable(part) and st.sel.size() == 1 and st.sel[0] < shapes.size():
		var h := Tools.handle_at(shapes[st.sel[0]], u, zoom)
		if h != "":
			_begin("handle", u)
			drag_i = st.sel[0]
			drag_handle = h
			return
	var i := Tools.hit(st.doc, part, u) if st.editable(part) else -1
	if i < 0 and not shift:
		# A click on another layer's shape picks that layer.
		var others := shown_parts()
		others.reverse()
		for p in others:
			if p != part and st.editable(p):
				var j := Tools.hit(st.doc, p, u)
				if j >= 0:
					st.pick_part(p)
					part = p
					i = j
					break
	if i >= 0:
		if shift and i in st.sel:
			st.sel.erase(i)
			st.selection_changed()
			return
		if shift:
			st.sel.append(i)
		elif not i in st.sel:
			st.sel = [i]
		st.selection_changed()
		_begin("move", u)
		drag_i = i
		return
	if not shift:
		st.sel = []
		st.selection_changed()
	_begin("box", u)
	box_rect = Rect2(u, Vector2.ZERO)
	box_base = st.sel.duplicate()


func _begin(kind: String, u: Vector2) -> void:
	drag = kind
	drag_from = u
	drag_orig = Tools.layer(st.doc, st.part).duplicate(true)
	drag_moved = false


func _motion(e: InputEventMouseMotion) -> void:
	if drag == "pan":
		origin += e.relative
		queue_redraw()
		return
	if drag == "":
		return
	var u := to_frame(e.position)
	var part: String = st.part
	if drag == "box":
		box_rect.end = u
		var sel := box_base.duplicate()
		for i in Tools.in_rect(st.doc, part, box_rect):
			if not i in sel:
				sel.append(i)
		st.sel = sel
		st.selection_changed(false)
		queue_redraw()
		return
	if not drag_moved:
		if (u - drag_from).length() * zoom < 2.0:
			return
		st.hist.record(st.doc, ["@pins"] if drag == "pin" else [part])
		drag_moved = true
	if drag == "pin":
		Pins.set_pin(st.doc, drag_handle, u)
		st.pins_changed(false)
		return
	var sym: bool = st.sel.size() == 1 and st.sym_here()
	if drag == "move":
		Tools.set_layer(st.doc, part, drag_orig.duplicate(true))
		var d := u - drag_from
		if st.snap_on:
			d = Tools.snap_delta(st.doc, part, st.sel, d, Tools.SNAP / zoom)
		if sym:
			st.sel = [Tools.edit_one(st.doc, part, drag_i, drag_orig, Tools.moved(drag_orig[drag_i], d), true)]
		else:
			Tools.move(st.doc, part, st.sel, d)
	elif drag == "handle":
		var s0: Dictionary = drag_orig[drag_i]
		var s: Dictionary
		if drag_handle.begins_with("s:"):
			s = Tools.scaled(s0, Tools.scale_id(drag_handle), u, e.shift_pressed)
		elif drag_handle == "rot":
			s = Tools.turned(s0, drag_from, u, e.shift_pressed)
		elif drag_handle.begins_with("p:"):
			s = Tools.with_point(s0, int(drag_handle.get_slice(":", 1)), u)
		else:
			s = Tools.with_radius(s0, u)
		st.sel = [Tools.edit_one(st.doc, part, drag_i, drag_orig, s, sym)]
	st.changed_parts([part], false)


func _release() -> void:
	var was := drag
	drag = ""
	if was == "box":
		queue_redraw()
		st.selection_changed()
	elif was in ["move", "handle"] and drag_moved:
		st.changed_parts([st.part])
	elif was == "pin" and drag_moved:
		st.pins_changed()
