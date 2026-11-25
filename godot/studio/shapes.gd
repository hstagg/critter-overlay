extends RefCounted
## The Shape Builder's shapes (docs/custom-critters-build-plan.md, 5.3 and
## D1): each shape type as data, clamped to the limits, with its outline as
## a polygon (for hit-testing and pin suggestion) and its SVG element.
## shape_svg.gd turns a whole shapes.json into kit parts.
##
## A shape is a Dictionary: {"t": type, "x", "y" (centre), "w", "h", "rot"
## (degrees), "fill": "#RRGGBB", "line": outline on (default), "inside":
## clipped to the layer's other shapes, "flip": mirrored left to right},
## plus per type: rect "r"; tri "r", "apex"; star "n"; blob and stroke
## "pts" ([[x, y], ...]); stroke "width"; eye "preset".

const TYPES := ["ellipse", "rect", "tri", "drop", "heart", "star", "blob", "stroke", "eye"]
const EYE_PRESETS := ["big", "round", "dot", "lash"]
const MAX_PER_LAYER := 60
const MAX_SHAPES := 400
const MAX_POINTS := 12
const COORD := Vector2(-60.0, 360.0)
const SIZE := Vector2(2.0, 400.0)
const DEFAULT_FILL := "#F6C28F"
const STEPS := 48                    # points round a curved shape


static func clean(s: Dictionary, warn := []) -> Dictionary:
	# A copy within the limits (5.3), or {} if it can't be a shape.
	var t := str(s.get("t", ""))
	if not t in TYPES:
		warn.append("An unknown shape (%s) was left out." % t)
		return {}
	var o := {"t": t}
	o.x = _num(s, "x", 150.0, COORD, warn)
	o.y = _num(s, "y", 150.0, COORD, warn)
	o.w = _num(s, "w", 40.0, SIZE, warn)
	o.h = _num(s, "h", 40.0, SIZE, warn)
	o.rot = fposmod(float(s.get("rot", 0.0)), 360.0)
	var fill := str(s.get("fill", DEFAULT_FILL))
	o.fill = fill if _is_colour(fill) else DEFAULT_FILL
	o.line = bool(s.get("line", true))
	o.inside = bool(s.get("inside", false))
	o.flip = bool(s.get("flip", false))
	match t:
		"rect":
			o.r = clampf(float(s.get("r", 8.0)), 0.0, minf(o.w, o.h) * 0.5)
		"tri":
			o.r = clampf(float(s.get("r", 0.0)), 0.0, minf(o.w, o.h) * 0.3)
			o.apex = clampf(float(s.get("apex", 0.5)), 0.0, 1.0)
		"star":
			o.n = clampi(int(s.get("n", 5)), 4, 8)
		"blob", "stroke":
			var pts := []
			for p in s.get("pts", []):
				if typeof(p) == TYPE_ARRAY and p.size() >= 2:
					pts.append([clampf(float(p[0]), COORD.x, COORD.y), clampf(float(p[1]), COORD.x, COORD.y)])
			var lo := 3 if t == "blob" else 2
			var hi := MAX_POINTS if t == "blob" else 8
			if pts.size() < lo:
				warn.append("A %s needs at least %d points." % [t, lo])
				return {}
			if pts.size() > hi:
				warn.append("A %s can have %d points at most; the rest were left out." % [t, hi])
				pts = pts.slice(0, hi)
			o.pts = pts
			if t == "stroke":
				o.width = clampf(float(s.get("width", 6.0)), 1.0, 60.0)
		"eye":
			var pr := str(s.get("preset", "big"))
			o.preset = pr if pr in EYE_PRESETS else "big"
			o.line = false
	return o


static func _num(s: Dictionary, k: String, def: float, range_: Vector2, warn: Array) -> float:
	var v := float(s.get(k, def))
	if v < range_.x or v > range_.y:
		warn.append("%s was out of range and was brought back." % k)
	return clampf(v, range_.x, range_.y)


static func _is_colour(c: String) -> bool:
	return c.length() == 7 and c.begins_with("#") and c.substr(1).is_valid_hex_number()


# --- Geometry ------------------------------------------------------------------------

static func centre(s: Dictionary) -> Vector2:
	if s.has("pts"):
		var c := Vector2.ZERO
		for p in s.pts:
			c += Vector2(p[0], p[1])
		return c / s.pts.size()
	return Vector2(s.x, s.y)


static func local_points(s: Dictionary) -> PackedVector2Array:
	# The outline before rotation and flipping, about (0, 0) for sized shapes.
	var w: float = s.w * 0.5
	var h: float = s.h * 0.5
	var out := PackedVector2Array()
	match s.t:
		"ellipse", "eye":
			for i in STEPS:
				var a := TAU * i / STEPS
				out.append(Vector2(cos(a) * w, sin(a) * h))
		"rect":
			var r: float = s.r
			var corners := [Vector2(w - r, -h + r), Vector2(w - r, h - r), Vector2(-w + r, h - r), Vector2(-w + r, -h + r)]
			for c in 4:
				for i in 7:
					var a := -PI / 2 + PI / 2 * c + PI / 2 * i / 6.0
					out.append(corners[c] + Vector2(cos(a), sin(a)) * r)
		"tri":
			out.append(Vector2(-w + s.apex * 2.0 * w, -h))
			out.append(Vector2(w, h))
			out.append(Vector2(-w, h))
		"drop":
			# A teardrop: round at the bottom, a point at the top.
			for i in STEPS:
				var a := TAU * i / STEPS
				var k := 1.0 - 0.75 * pow(maxf(0.0, -sin(a)), 1.5)
				out.append(Vector2(cos(a) * w * k, sin(a) * h))
		"heart":
			for i in STEPS:
				var a := TAU * i / STEPS
				var x := 16.0 * pow(sin(a), 3)
				var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
				out.append(Vector2(x / 16.0 * w, (y + 2.0) / 15.0 * h))
		"star":
			var n: int = s.n
			for i in n * 2:
				var a := -PI / 2 + PI * i / n
				var k := 1.0 if i % 2 == 0 else 0.48
				out.append(Vector2(cos(a) * w * k, sin(a) * h * k))
	return out


static func polygon(s: Dictionary) -> PackedVector2Array:
	# The outline in frame units: what hit-testing and pins use.
	var out := PackedVector2Array()
	match s.t:
		"blob":
			out = catmull(_pts(s), true)
		"stroke":
			out = _thick(catmull(_pts(s), false), s.width * 0.5)
		_:
			var c := Vector2(s.x, s.y)
			var rot := deg_to_rad(s.rot)
			for p in local_points(s):
				out.append(c + p.rotated(rot))
	if s.flip:
		var cx := centre(s).x
		for i in out.size():
			out[i].x = 2.0 * cx - out[i].x
	return out


static func _pts(s: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s.pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func catmull(pts: PackedVector2Array, closed: bool, per := 8) -> PackedVector2Array:
	# A smooth curve through every point.
	var out := PackedVector2Array()
	var n := pts.size()
	var segs := n if closed else n - 1
	for i in segs:
		var p0 := pts[(i - 1 + n) % n] if closed or i > 0 else pts[0]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n] if closed or i + 2 < n else pts[n - 1]
		for k in per:
			var t := float(k) / per
			out.append(0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	if not closed:
		out.append(pts[n - 1])
	return out


static func _thick(line: PackedVector2Array, r: float) -> PackedVector2Array:
	# An open line as a closed band r either side, for hit-testing.
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for i in line.size():
		var d := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-d.y, d.x) * r
		a.append(line[i] + nrm)
		b.append(line[i] - nrm)
	b.reverse()
	return a + b


static func hit(s: Dictionary, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, polygon(s))


static func rect_of(s: Dictionary) -> Rect2:
	var poly := polygon(s)
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


# --- SVG ---------------------------------------------------------------------------

static func _f(v: float) -> String:
	return str(snappedf(v, 0.01))


static func path_d(poly: PackedVector2Array, closed := true) -> String:
	var d := "M%s %s" % [_f(poly[0].x), _f(poly[0].y)]
	for i in range(1, poly.size()):
		d += " L%s %s" % [_f(poly[i].x), _f(poly[i].y)]
	return d + (" Z" if closed else "")


static func element(s: Dictionary, paint: String) -> String:
	# The shape's SVG element with the given paint attributes.
	# An ellipse or rectangle mirrored about its own middle is the same
	# shape turned the other way.
	var rot: float = -s.rot if s.flip else s.rot
	var turn := ' transform="rotate(%s %s %s)"' % [_f(rot), _f(s.x), _f(s.y)] if rot != 0.0 else ""
	match s.t:
		"ellipse":
			return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s"%s %s/>' % [_f(s.x), _f(s.y), _f(s.w * 0.5), _f(s.h * 0.5), turn, paint]
		"rect":
			return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s"%s %s/>' % [_f(s.x - s.w * 0.5), _f(s.y - s.h * 0.5),
				_f(s.w), _f(s.h), _f(s.r), turn, paint]
		"stroke":
			return '<path d="%s" %s/>' % [path_d(catmull(_pts(s), false), false), paint]
		_:
			return '<path d="%s" %s/>' % [path_d(polygon(s)), paint]


# --- Pins (4.7) -------------------------------------------------------------------------

static func layer_rect(shapes: Array) -> Rect2:
	var r := Rect2()
	for s in shapes:
		r = rect_of(s) if r.size == Vector2.ZERO else r.merge(rect_of(s))
	return r


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxi(1, poly.size())


static func suggest_pins(layers: Dictionary) -> Dictionary:
	# Joints from the drawing: the neck is the middle of where the head and
	# body overlap (or meet); a hip is the top middle of its leg; the tail's
	# root is its point nearest the body; an ear's root its bottom middle;
	# the eyes pin the middle of the eyes.
	var pins := {}
	var rect := func(part: String) -> Rect2:
		return layer_rect(layers.get(part, []))
	var body: Rect2 = rect.call("walk-body") if layers.has("walk-body") else rect.call("body")
	if layers.has("head") and body.size != Vector2.ZERO:
		var hr: Rect2 = rect.call("head")
		var neck := Vector2(hr.get_center().x, hr.end.y)
		# The middle of the area where the shapes really overlap, else
		# the bottom middle of the head.
		var sum := Vector2.ZERO
		var area := 0.0
		for hs in layers.head:
			for bs in layers.get("walk-body", layers.get("body", [])):
				for piece in Geometry2D.intersect_polygons(polygon(hs), polygon(bs)):
					var a := _area(piece)
					sum += _centroid(piece) * a
					area += a
		if area > 1.0:
			neck = sum / area
		pins["neck-walk"] = [neck.x, neck.y]
		pins["neck-sit"] = [neck.x, neck.y]
		pins["head"] = [neck.x, neck.y]
	for leg in ["leg-front", "leg-back", "leg-front-far", "leg-back-far", "leg-near", "leg-far"]:
		if layers.has(leg):
			var lr: Rect2 = rect.call(leg)
			var hip_name: String = {"leg-near": "hip", "leg-far": "hip-far"}.get(leg, leg.replace("leg-", "hip-"))
			pins[hip_name] = [lr.get_center().x, lr.position.y + minf(6.0, lr.size.y * 0.2)]
	if layers.has("tail") and body.size != Vector2.ZERO:
		var best := Vector2.ZERO
		var bd := INF
		for s in layers.tail:
			var line: PackedVector2Array = catmull(_pts(s), false) if s.t == "stroke" else polygon(s)
			for p in line:
				var d := body.get_center().distance_to(p)
				if d < bd:
					bd = d
					best = p
		pins["tail"] = [best.x, best.y]
	for ear in ["ear-l", "ear-r"]:
		if layers.has(ear):
			var er: Rect2 = rect.call(ear)
			pins[ear] = [er.get_center().x, er.end.y]
	if layers.has("eyes"):
		var c: Vector2 = rect.call("eyes").get_center()
		pins["eyes"] = [c.x, c.y]
	return pins
