extends RefCounted
## Critter Studio's shape tools (docs/custom-critters-build-plan.md, D3) as
## plain functions on a shapes.json doc (5.3), so each can be tested without
## a window: add, hit-test, select by box, move, scale, turn, points, corner
## radius, forward, back, mirror, duplicate, delete, nudge, copy and paste,
## snapping, live symmetry and Draw this pose. canvas.gd turns the mouse
## into these calls and history.gd records the layer before each one.
##
## Every shape that goes into the doc goes through Shapes.clean(), so the doc
## is always within the limits and shape_svg.gd can draw it as it is.
##
## A drag is applied from the shape as it was when the drag began (the
## canvas keeps that copy), never step by step, so clamping on the way never
## builds up.
##
## Live symmetry (front-facing layers): a shape's twin is the shape that is
## its exact mirror about the frame's middle. Editing one shape keeps its
## twin its mirror, a new shape off the middle gets one, and a shape moved
## onto the middle loses it. Nothing is stored for this: shapes.json stays
## plain shapes. With several shapes selected, edits are not mirrored.

const Shapes := preload("res://studio/shapes.gd")
const Writer := preload("res://studio/shape_svg.gd")

const GROUND := 262.0              # kit_data.gd's GROUND
const MIDDLE := 150.0              # the frame's centre line
const SNAP := 6.0                  # units, at 100%
const NUDGE_BIG := 10.0
const SHIFT := 10.0                # a duplicate, or a paste into the same layer, lands this far off
const ROT_STEP := 15.0
const MIN_SIZE := 4.0
const ROT_HANDLE := 22.0           # px above the box
const EYE_FILL := "#3A2A22"

const DEFAULTS := {
	"ellipse": {"w": 60, "h": 50}, "rect": {"w": 60, "h": 44, "r": 10}, "tri": {"w": 50, "h": 50},
	"drop": {"w": 36, "h": 50}, "heart": {"w": 44, "h": 40}, "star": {"w": 50, "h": 50, "n": 5},
	"eye": {"w": 18, "h": 22, "preset": "big"},
}
# Layers that face you, drawn with live symmetry (4.2-4.4). Side-on layers
# are profiles, so none of theirs.
const FRONT := {
	"front": ["body", "head", "eyes", "eyes-closed", "nose", "mouth-open", "head-front", "front-extra", "paws", "loaf-body", "loaf-eyes", "loaf-eyes-closed"],
	"upright": ["body", "head", "eyes", "eyes-closed", "mouth-open", "tuft", "head-front", "front-extra", "loaf-body"],
	"blob": ["body", "head", "eyes", "eyes-closed", "mouth-open", "head-front", "loaf-body"],
}


static func blank(plan := "side") -> Dictionary:
	return Writer.clean_doc({"plan": plan}).doc


static func layer(doc: Dictionary, part: String) -> Array:
	return doc.layers.get(part, [])


static func set_layer(doc: Dictionary, part: String, shapes: Array) -> void:
	if shapes.is_empty():
		doc.layers.erase(part)
	else:
		doc.layers[part] = shapes


static func count(doc: Dictionary) -> int:
	var n := 0
	for part in doc.layers:
		n += doc.layers[part].size()
	return n


static func room(doc: Dictionary, part: String, more := 1) -> bool:
	# Whether `more` shapes still fit in the layer and the doc (5.3's limits).
	return layer(doc, part).size() + more <= Shapes.MAX_PER_LAYER and count(doc) + more <= Shapes.MAX_SHAPES


# --- Adding --------------------------------------------------------------------------

static func new_shape(t: String, at: Vector2, fill := Shapes.DEFAULT_FILL) -> Dictionary:
	# A shape of type t at its default size, centred on `at`.
	var s := {"t": t, "x": at.x, "y": at.y, "fill": EYE_FILL if t == "eye" else fill}
	match t:
		"blob":
			var pts := []
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2.0
				pts.append([at.x + cos(a) * 32.0, at.y + sin(a) * 26.0])
			s.pts = pts
		"stroke":
			s.pts = [[at.x - 30.0, at.y + 8.0], [at.x, at.y - 8.0], [at.x + 30.0, at.y + 8.0]]
			s.width = 8.0
		_:
			s.merge(DEFAULTS[t])
	return Shapes.clean(s)


static func fill_for(doc: Dictionary, part: String) -> String:
	# A new shape takes the colour last used in its layer (D4 adds the picker).
	var shapes := layer(doc, part)
	for i in range(shapes.size() - 1, -1, -1):
		if shapes[i].t != "eye":
			return shapes[i].fill
	return Shapes.DEFAULT_FILL


static func add(doc: Dictionary, part: String, s: Dictionary) -> int:
	# The new shape's index, or -1 when the layer or the doc is full.
	if not room(doc, part):
		return -1
	var shapes := layer(doc, part).duplicate()
	shapes.append(Shapes.clean(s))
	set_layer(doc, part, shapes)
	return shapes.size() - 1


# --- Finding -------------------------------------------------------------------------

static func hit(doc: Dictionary, part: String, p: Vector2) -> int:
	# The topmost shape under p, or -1.
	var shapes := layer(doc, part)
	for i in range(shapes.size() - 1, -1, -1):
		if Shapes.hit(shapes[i], p):
			return i
	return -1


static func in_rect(doc: Dictionary, part: String, r: Rect2) -> Array:
	# Every shape the drag-select box touches.
	var out := []
	var shapes := layer(doc, part)
	for i in shapes.size():
		if r.abs().intersects(Shapes.rect_of(shapes[i]), true):
			out.append(i)
	return out


static func rect_of(doc: Dictionary, part: String, idx: Array) -> Rect2:
	var shapes := layer(doc, part)
	var r := Rect2()
	for i in idx:
		r = Shapes.rect_of(shapes[i]) if r.size == Vector2.ZERO else r.merge(Shapes.rect_of(shapes[i]))
	return r


# --- One shape -------------------------------------------------------------------------

static func eff(s: Dictionary) -> float:
	# The turn as drawn, in radians: a flipped shape turns the other way.
	if s.has("pts"):
		return 0.0
	return deg_to_rad(-s.rot if s.flip else s.rot)


static func box(s: Dictionary) -> Dictionary:
	# The handles' box: centre, half size and axes (turned with the shape).
	if s.has("pts"):
		var r := Shapes.rect_of(s)
		return {"c": r.get_center(), "half": r.size * 0.5, "ax": Vector2.RIGHT, "ay": Vector2.DOWN}
	var a := eff(s)
	return {"c": Vector2(s.x, s.y), "half": Vector2(s.w, s.h) * 0.5, "ax": Vector2(cos(a), sin(a)), "ay": Vector2(-sin(a), cos(a))}


static func moved(s: Dictionary, d: Vector2) -> Dictionary:
	var o := s.duplicate(true)
	if o.has("pts"):
		for p in o.pts:
			p[0] += d.x
			p[1] += d.y
	else:
		o.x += d.x
		o.y += d.y
	return Shapes.clean(o)


static func mirrored(s: Dictionary, cx := MIDDLE) -> Dictionary:
	# Mirrored left to right about x = cx.
	var o := s.duplicate(true)
	if o.has("pts"):
		for p in o.pts:
			p[0] = 2.0 * cx - p[0]
	else:
		o.x = 2.0 * cx - o.x
		o.flip = not o.flip
	return Shapes.clean(o)


static func scaled(s: Dictionary, h: Vector2i, p: Vector2, keep: bool) -> Dictionary:
	# Dragging scale handle h (-1, 0 or 1 on each axis) to p; the opposite
	# side stays put. keep (Shift) keeps the ratio.
	var b := box(s)
	var half: Vector2 = b.half
	var ax: Vector2 = b.ax
	var ay: Vector2 = b.ay
	var anchor: Vector2 = b.c - ax * h.x * half.x - ay * h.y * half.y
	var q := p - anchor
	var size := half * 2.0
	var w := size.x if h.x == 0 else maxf(MIN_SIZE, q.dot(ax) * h.x)
	var ht := size.y if h.y == 0 else maxf(MIN_SIZE, q.dot(ay) * h.y)
	if keep and size.x > 0.0 and size.y > 0.0:
		var k := 1.0
		if h.x != 0 and h.y != 0:
			k = maxf(w / size.x, ht / size.y)
		elif h.x != 0:
			k = w / size.x
		else:
			k = ht / size.y
		w = size.x * k
		ht = size.y * k
	var o := s.duplicate(true)
	if o.has("pts"):
		var k := Vector2(w / maxf(size.x, 0.01), ht / maxf(size.y, 0.01))
		for pt in o.pts:
			var v := anchor + (Vector2(pt[0], pt[1]) - anchor) * k
			pt[0] = v.x
			pt[1] = v.y
	else:
		var c := anchor + ax * h.x * w * 0.5 + ay * h.y * ht * 0.5
		o.x = c.x
		o.y = c.y
		o.w = w
		o.h = ht
	return Shapes.clean(o)


static func turned(s: Dictionary, from: Vector2, p: Vector2, snap: bool) -> Dictionary:
	# Dragging the turn handle from `from` to p. snap (Shift): steps of 15°.
	var c: Vector2 = box(s).c
	var delta := rad_to_deg((p - c).angle() - (from - c).angle())
	var o := s.duplicate(true)
	if o.has("pts"):
		if snap:
			delta = snappedf(delta, ROT_STEP)
		for pt in o.pts:
			var v := c + (Vector2(pt[0], pt[1]) - c).rotated(deg_to_rad(delta))
			pt[0] = v.x
			pt[1] = v.y
	else:
		var shown := rad_to_deg(eff(s)) + delta
		if snap:
			shown = snappedf(shown, ROT_STEP)
		o.rot = -shown if s.flip else shown
	return Shapes.clean(o)


static func with_point(s: Dictionary, k: int, p: Vector2) -> Dictionary:
	var o := s.duplicate(true)
	o.pts[k] = [p.x, p.y]
	return Shapes.clean(o)


static func with_radius(s: Dictionary, p: Vector2) -> Dictionary:
	# The corner-radius handle (rect and tri) slides along the top edge.
	var b := box(s)
	var half: Vector2 = b.half
	var o := s.duplicate(true)
	o.r = maxf(0.0, (p - b.c).dot(b.ax) + half.x)
	return Shapes.clean(o)


static func handles(s: Dictionary, zoom := 1.0) -> Array:
	# [id, place]: "s:<hx>:<hy>" scale, "rot" turn, "p:<k>" a point, "r" the
	# corner radius. In frame units; the turn handle sits ROT_HANDLE px up.
	var b := box(s)
	var c: Vector2 = b.c
	var half: Vector2 = b.half
	var ax: Vector2 = b.ax
	var ay: Vector2 = b.ay
	var out := []
	if s.has("pts"):
		for k in s.pts.size():
			out.append(["p:%d" % k, Vector2(s.pts[k][0], s.pts[k][1])])
	if s.t in ["rect", "tri"]:
		out.append(["r", c + ax * (-half.x + float(s.r)) - ay * half.y])
	for hy in [-1, 0, 1]:
		for hx in [-1, 0, 1]:
			if hx != 0 or hy != 0:
				out.append(["s:%d:%d" % [hx, hy], c + ax * hx * half.x + ay * hy * half.y])
	out.append(["rot", c - ay * (half.y + ROT_HANDLE / zoom)])
	return out


static func handle_at(s: Dictionary, p: Vector2, zoom := 1.0, reach_px := 7.0) -> String:
	# The handle under p (points and the radius first), or "".
	for h in handles(s, zoom):
		if (h[1] as Vector2).distance_to(p) <= reach_px / zoom:
			return h[0]
	return ""


static func scale_id(id: String) -> Vector2i:
	return Vector2i(int(id.get_slice(":", 1)), int(id.get_slice(":", 2)))


# --- The selection --------------------------------------------------------------------

static func move(doc: Dictionary, part: String, idx: Array, d: Vector2) -> void:
	var shapes := layer(doc, part).duplicate()
	for i in idx:
		shapes[i] = moved(shapes[i], d)
	set_layer(doc, part, shapes)


static func nudge(doc: Dictionary, part: String, idx: Array, dir: Vector2, big: bool) -> void:
	move(doc, part, idx, dir * (NUDGE_BIG if big else 1.0))


static func snap_delta(doc: Dictionary, part: String, idx: Array, d: Vector2, reach := SNAP) -> Vector2:
	# A move of the selection, pulled onto the ground line (its bottom) and
	# the frame's middle (its centre) when it comes within reach.
	var r := rect_of(doc, part, idx)
	if r.size == Vector2.ZERO:
		return d
	r.position += d
	if absf(r.end.y - GROUND) < reach:
		d.y += GROUND - r.end.y
	if absf(r.get_center().x - MIDDLE) < reach:
		d.x += MIDDLE - r.get_center().x
	return d


static func snap_point(p: Vector2, reach := SNAP) -> Vector2:
	# Where a click places a new shape: onto the middle when near it.
	if absf(p.x - MIDDLE) < reach:
		p.x = MIDDLE
	return p


static func forward(doc: Dictionary, part: String, idx: Array) -> Array:
	# One step towards the front each; returns the new indices.
	var shapes := layer(doc, part).duplicate()
	var sel := idx.duplicate()
	sel.sort()
	sel.reverse()
	var out := []
	for i in sel:
		if i < shapes.size() - 1 and not (i + 1) in out:
			var t = shapes[i + 1]
			shapes[i + 1] = shapes[i]
			shapes[i] = t
			out.append(i + 1)
		else:
			out.append(i)
	set_layer(doc, part, shapes)
	out.sort()
	return out


static func back(doc: Dictionary, part: String, idx: Array) -> Array:
	var shapes := layer(doc, part).duplicate()
	var sel := idx.duplicate()
	sel.sort()
	var out := []
	for i in sel:
		if i > 0 and not (i - 1) in out:
			var t = shapes[i - 1]
			shapes[i - 1] = shapes[i]
			shapes[i] = t
			out.append(i - 1)
		else:
			out.append(i)
	set_layer(doc, part, shapes)
	out.sort()
	return out


static func mirror(doc: Dictionary, part: String, idx: Array) -> void:
	# The selection mirrored about its own middle.
	var cx := rect_of(doc, part, idx).get_center().x
	var shapes := layer(doc, part).duplicate()
	for i in idx:
		shapes[i] = mirrored(shapes[i], cx)
	set_layer(doc, part, shapes)


static func copy(doc: Dictionary, part: String, idx: Array) -> Array:
	var shapes := layer(doc, part)
	var sel := idx.duplicate()
	sel.sort()
	return sel.map(func(i): return shapes[i].duplicate(true))


static func paste(doc: Dictionary, part: String, clip: Array, shift := false) -> Array:
	# The copied shapes into this layer (any layer, any pose), on top, at the
	# same place, or SHIFT off when pasted where they came from. Returns their
	# indices; none if they don't fit.
	if clip.is_empty() or not room(doc, part, clip.size()):
		return []
	var shapes := layer(doc, part).duplicate()
	var out := []
	for s in clip:
		shapes.append(moved(s, Vector2(SHIFT, SHIFT)) if shift else Shapes.clean(s))
		out.append(shapes.size() - 1)
	set_layer(doc, part, shapes)
	return out


static func duplicate_shapes(doc: Dictionary, part: String, idx: Array) -> Array:
	return paste(doc, part, copy(doc, part, idx), true)


static func delete(doc: Dictionary, part: String, idx: Array) -> void:
	var shapes := layer(doc, part).duplicate()
	var sel := idx.duplicate()
	sel.sort()
	sel.reverse()
	for i in sel:
		if i >= 0 and i < shapes.size():
			shapes.remove_at(i)
	set_layer(doc, part, shapes)


static func draw_pose(doc: Dictionary, part: String, from: String) -> bool:
	# Draw this pose (P2): an automatic pose becomes a copy of the one it is
	# made from, as a starting point. Only into an empty layer.
	if not layer(doc, part).is_empty() or layer(doc, from).is_empty():
		return false
	doc.layers[part] = layer(doc, from).duplicate(true)
	return true


# --- Live symmetry ----------------------------------------------------------------------

static func symmetric(plan: String, part: String) -> bool:
	return part in FRONT.get(plan, [])


static func centred(s: Dictionary) -> bool:
	return absf(Shapes.centre(s).x - MIDDLE) < 1.0


static func same(a: Dictionary, b: Dictionary) -> bool:
	# The same shape, give or take rounding.
	if a.t != b.t or a.flip != b.flip:
		return false
	if a.has("pts"):
		if a.pts.size() != b.pts.size():
			return false
		for k in a.pts.size():
			if absf(a.pts[k][0] - b.pts[k][0]) > 0.51 or absf(a.pts[k][1] - b.pts[k][1]) > 0.51:
				return false
		return true
	for k in ["x", "y", "w", "h"]:
		if absf(float(a[k]) - float(b[k])) > 0.51:
			return false
	return absf(angle_difference(deg_to_rad(a.rot), deg_to_rad(b.rot))) < 0.01


static func twin_of(shapes: Array, i: int, s: Dictionary) -> int:
	# The shape that is s's mirror about the middle, other than shape i.
	if s.is_empty() or centred(s):
		return -1
	var m := mirrored(s)
	for j in shapes.size():
		if j != i and same(shapes[j], m):
			return j
	return -1


static func mirror_edit(shapes: Array, i: int, before: Dictionary) -> Dictionary:
	# After shape i changed (from `before`, or {} when it is new): its twin
	# follows. {"shapes": the layer, "i": where shape i is now, "twin": its
	# twin's index or -1}.
	var out := shapes.duplicate()
	var now: Dictionary = out[i]
	var j := twin_of(out, i, before)
	if j >= 0 and centred(now):
		out.remove_at(j)
		return {"shapes": out, "i": i - 1 if j < i else i, "twin": -1}
	if j >= 0:
		out[j] = mirrored(now)
		return {"shapes": out, "i": i, "twin": j}
	if before.is_empty() and not centred(now):
		out.insert(i + 1, mirrored(now))
		return {"shapes": out, "i": i, "twin": i + 1}
	return {"shapes": out, "i": i, "twin": -1}


static func with_twins(doc: Dictionary, part: String, idx: Array) -> Array:
	# The selection plus each shape's twin: what Delete takes on a symmetric layer.
	var shapes := layer(doc, part)
	var out := idx.duplicate()
	for i in idx:
		var j := twin_of(shapes, i, shapes[i])
		if j >= 0 and not j in out:
			out.append(j)
	return out


# --- Doing an action -------------------------------------------------------------------

static func act(doc: Dictionary, hist: RefCounted, parts: Array, f: Callable) -> Variant:
	# One undoable action: the layers it touches are recorded, then f runs.
	hist.record(doc, parts)
	return f.call()


static func place(doc: Dictionary, hist: RefCounted, part: String, t: String, at: Vector2, sym := false) -> int:
	# A click with a shape tool: the new shape at its default size (and its
	# twin on a symmetric layer). Returns its index, or -1 when full.
	if not room(doc, part, 2 if sym else 1):
		return -1
	hist.record(doc, [part])
	var i := add(doc, part, new_shape(t, at, fill_for(doc, part)))
	if sym:
		var r := mirror_edit(layer(doc, part), i, {})
		set_layer(doc, part, r.shapes)
		i = r.i
	return i


static func edit_one(doc: Dictionary, part: String, i: int, orig: Array, s: Dictionary, sym: bool) -> int:
	# A drag's step on one shape: the layer as it was (orig) with shape i
	# now s, and its twin following on a symmetric layer. Returns i's index.
	var shapes := orig.duplicate()
	shapes[i] = s
	if sym:
		var r := mirror_edit(shapes, i, orig[i])
		set_layer(doc, part, r.shapes)
		return r.i
	set_layer(doc, part, shapes)
	return i
