extends RefCounted
## shapes.json to kit parts (docs/custom-critters-build-plan.md, 5.3, D1, P5):
## one SVG per drawn layer, in the cast's frame, so the kit rigs see ordinary
## parts.
##
## Each layer is drawn in two passes so overlapping shapes get one outline,
## as the cast's parts have: first every outlined shape in the outline
## colour at twice the outline width, then every fill on top. "inside"
## shapes (markings, bellies, spots) come after, clipped to the union of the
## layer's other shapes, with no outline. Eyes come last, in their preset.
## With blush on, two rosy marks go under the eyes on the head (or a blob's
## body). An eyes layer with no eyes-closed layer gets one made: an arc at
## each eye. Everything else not drawn is filled in by kit_data.gd from the
## critter's own art.

const Shapes := preload("res://studio/shapes.gd")

const HEAD := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
const BLUSH := "#F29C9C"
const LINE_DEFAULT := "#5B3A29"


static func clean_doc(doc: Dictionary) -> Dictionary:
	# {"doc": within every limit, "warnings": [...]}
	var warn := []
	var out := {"schema": 1, "plan": str(doc.get("plan", "side")), "layers": {}, "pins": {}, "auto": {}}
	var style: Dictionary = doc.get("style", {}) if typeof(doc.get("style")) == TYPE_DICTIONARY else {}
	var outline := str(style.get("outline", LINE_DEFAULT))
	out.style = {"outline": outline if Shapes._is_colour(outline) else LINE_DEFAULT,
		"width": clampf(float(style.get("width", 6.0)), 0.0, 16.0), "blush": bool(style.get("blush", true))}
	var total := 0
	var layers: Dictionary = doc.get("layers", {}) if typeof(doc.get("layers")) == TYPE_DICTIONARY else {}
	for part in layers:
		var shapes := []
		for s in layers[part]:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			if shapes.size() >= Shapes.MAX_PER_LAYER:
				warn.append("%s has over %d shapes; the rest were left out." % [part, Shapes.MAX_PER_LAYER])
				break
			if total >= Shapes.MAX_SHAPES:
				warn.append("Over %d shapes in all; the rest were left out." % Shapes.MAX_SHAPES)
				break
			var c := Shapes.clean(s, warn)
			if not c.is_empty():
				shapes.append(c)
				total += 1
		if not shapes.is_empty():
			out.layers[str(part)] = shapes
	for k in doc.get("pins", {}):
		var v = doc.pins[k]
		if typeof(v) == TYPE_ARRAY and v.size() >= 2:
			out.pins[str(k)] = [clampf(float(v[0]), Shapes.COORD.x, Shapes.COORD.y), clampf(float(v[1]), Shapes.COORD.x, Shapes.COORD.y)]
	return {"doc": out, "warnings": warn}


static func write(doc: Dictionary) -> Dictionary:
	# part -> SVG text, for every layer with shapes (and the eyes-closed arcs).
	var d: Dictionary = clean_doc(doc).doc
	var out := {}
	var line: String = d.style.outline
	var width: float = d.style.width
	var eyes: Array = d.layers.get("eyes", [])
	for part in d.layers:
		var extra := ""
		if d.style.blush and not eyes.is_empty() and (part == "head" or (part == "body" and not d.layers.has("head"))):
			extra = _blush(eyes)
		out[part] = HEAD + layer(d.layers[part], line, width, part, extra) + "</svg>"
	if not eyes.is_empty() and not d.layers.has("eyes-closed"):
		out["eyes-closed"] = HEAD + _closed_eyes(eyes, line) + "</svg>"
	return out


static func layer(shapes: Array, line: String, width: float, id := "layer", extra := "") -> String:
	var outlined := shapes.filter(func(s): return s.line and not s.inside and s.t != "eye")
	var plain := shapes.filter(func(s): return not s.inside and s.t != "eye")
	var marks := shapes.filter(func(s): return s.inside and s.t != "eye")
	var eye_shapes := shapes.filter(func(s): return s.t == "eye")
	var svg := ""
	# Pass one: the outline, twice as wide, under everything.
	if width > 0.0 and not outlined.is_empty():
		svg += "<g>"
		for s in outlined:
			if s.t == "stroke":
				svg += Shapes.element(s, 'fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"' % [line, Shapes._f(s.width + 2.0 * width)])
			else:
				svg += Shapes.element(s, 'fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"' % [line, line, Shapes._f(2.0 * width)])
		svg += "</g>"
	# Pass two: the fills.
	for s in plain:
		if s.t == "stroke":
			svg += Shapes.element(s, 'fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"' % [s.fill, Shapes._f(s.width)])
		else:
			svg += Shapes.element(s, 'fill="%s"' % s.fill)
	# Markings, clipped inside the rest.
	if not marks.is_empty() or extra != "":
		var clip_id := "in-" + id
		var clip := ""
		for s in plain:
			if s.t != "stroke":
				clip += Shapes.element(s, "")
		svg += '<defs><clipPath id="%s">%s</clipPath></defs><g clip-path="url(#%s)">' % [clip_id, clip, clip_id]
		for s in marks:
			svg += Shapes.element(s, 'fill="%s"' % s.fill)
		svg += extra + "</g>"
	for s in eye_shapes:
		svg += eye(s)
	return svg


static func eye(s: Dictionary) -> String:
	# A preset eye: big (dark, two highlights), round, dot, or lash (big with
	# a lash on the outer side).
	var x: float = s.x
	var y: float = s.y
	var w: float = s.w * 0.5
	var h: float = s.h * 0.5
	var f := Shapes._f
	match s.preset:
		"dot":
			return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>' % [f.call(x), f.call(y), f.call(w), f.call(h), s.fill]
		"round":
			return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/><circle cx="%s" cy="%s" r="%s" fill="#FFFFFF"/>' % [
				f.call(x), f.call(y), f.call(w), f.call(h), s.fill, f.call(x + w * 0.3), f.call(y - h * 0.35), f.call(minf(w, h) * 0.3)]
	var out := '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>' % [f.call(x), f.call(y), f.call(w), f.call(h), s.fill] \
		+ '<circle cx="%s" cy="%s" r="%s" fill="#FFFFFF"/>' % [f.call(x + w * 0.28), f.call(y - h * 0.38), f.call(minf(w, h) * 0.38)] \
		+ '<circle cx="%s" cy="%s" r="%s" fill="#FFFFFF" opacity="0.8"/>' % [f.call(x - w * 0.3), f.call(y + h * 0.35), f.call(minf(w, h) * 0.16)]
	if s.preset == "lash":
		var side := -1.0 if s.flip else 1.0
		out += '<path d="M%s %s Q%s %s %s %s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % [
			f.call(x + side * w * 0.7), f.call(y - h * 0.7), f.call(x + side * w * 1.2), f.call(y - h * 1.0),
			f.call(x + side * w * 1.4), f.call(y - h * 1.4), s.fill, f.call(maxf(1.5, w * 0.2))]
	return out


static func _blush(eyes: Array) -> String:
	var out := ""
	for s in eyes:
		var w: float = s.w * 0.5
		out += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" opacity="0.7"/>' % [
			Shapes._f(s.x), Shapes._f(s.y + s.h * 0.75), Shapes._f(w * 1.1), Shapes._f(w * 0.6), BLUSH]
	return out


static func _closed_eyes(eyes: Array, line: String) -> String:
	# A happy shut arc where each eye is.
	var out := ""
	for s in eyes:
		var w: float = s.w * 0.6
		out += '<path d="M%s %s Q%s %s %s %s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % [
			Shapes._f(s.x - w), Shapes._f(s.y), Shapes._f(s.x), Shapes._f(s.y + s.h * 0.45),
			Shapes._f(s.x + w), Shapes._f(s.y), line, Shapes._f(maxf(2.5, s.w * 0.16))]
	return out
