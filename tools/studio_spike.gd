extends SceneTree
## Spike A1 of docs/custom-critters-build-plan.md: how fast and how well
## Godot's SVG rasteriser (ThorVG) draws Shape Builder layers. Not shipped.
##
##   godot --headless --path godot --script <abs path>/tools/studio_spike.gd
##
## 1. Times Image.load_svg_from_string at PART_SCALE (and at the largest
##    critter size) for layers of 10, 40 and 60 shapes, with and without a
##    clipPath for markings.
## 2. Checks the two-pass outline (plan P5): no outline inside the merged
##    silhouette, an outline on its outer edge, and clipped markings.
## 3. Probes which SVG features ThorVG draws (plan P8).

const PART_SCALE := 0.75
const BIG_SCALE := 0.75 * 1.6   # the largest critter size
const RUNS := 15
const FILL := "#F6C28F"
const LINE := "#6B4A3A"
const MARK := "#FFFFFF"


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	print("== timings (median of %d, ms) ==" % RUNS)
	print("shapes | clip | x0.75 | x1.2")
	for n in [10, 40, 60]:
		for clip in [false, true]:
			var svg := _layer(rng, n, clip)
			print("%6d | %4s | %5.2f | %5.2f" % [n, "yes" if clip else "no",
				_time(svg, PART_SCALE), _time(svg, BIG_SCALE)])
	print("")
	print("== two-pass outline ==")
	_outline_checks()
	print("")
	print("== feature probe ==")
	_probe()
	quit()


func _time(svg: String, scale: float) -> float:
	var times: Array[float] = []
	for i in RUNS:
		var img := Image.new()
		var t := Time.get_ticks_usec()
		img.load_svg_from_string(svg, scale)
		times.append((Time.get_ticks_usec() - t) / 1000.0)
	times.sort()
	return times[RUNS / 2]


## A layer as the Shape Builder will write it: pass one draws every outlined
## shape's stroke at twice the width, pass two every fill on top; markings
## are clipped to the union of the other shapes.
func _layer(rng: RandomNumberGenerator, n: int, clip: bool) -> String:
	var shapes: Array[String] = []
	for i in n:
		var cx := rng.randf_range(80, 220)
		var cy := rng.randf_range(80, 220)
		match i % 3:
			0:
				shapes.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f"/>' % [cx, cy, rng.randf_range(10, 50), rng.randf_range(10, 40)])
			1:
				shapes.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="8"/>' % [cx - 20, cy - 15, rng.randf_range(15, 60), rng.randf_range(15, 50)])
			2:
				shapes.append('<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z"/>' % [cx, cy, cx + 40, cy - 30, cx + 50, cy + 30, cx, cy + 20])
	var body := "\n".join(shapes)
	var s := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
	if clip:
		s += '<defs><clipPath id="u">%s</clipPath></defs>' % body
	s += '<g fill="none" stroke="%s" stroke-width="8" stroke-linejoin="round">%s</g>' % [LINE, body]
	s += '<g fill="%s">%s</g>' % [FILL, body]
	if clip:
		s += '<g clip-path="url(#u)" fill="%s"><ellipse cx="150" cy="150" rx="90" ry="20"/><ellipse cx="120" cy="110" rx="30" ry="60"/></g>' % MARK
	return s + "</svg>"


func _render(svg: String, scale := 1.0) -> Image:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK:
		return null
	return img


func _near(c: Color, hex: String, tol := 0.08) -> bool:
	var w := Color(hex)
	return c.a > 0.9 and absf(c.r - w.r) < tol and absf(c.g - w.g) < tol and absf(c.b - w.b) < tol


func _outline_checks() -> void:
	# Two circles overlapping at x 140-160. Naive: each with its own stroke.
	var a := '<circle cx="120" cy="140" r="40"/>'
	var b := '<circle cx="180" cy="140" r="40"/>'
	var head := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">'
	var naive := head + '<g fill="%s" stroke="%s" stroke-width="4">%s%s</g></svg>' % [FILL, LINE, a, b]
	var two := head + '<g fill="none" stroke="%s" stroke-width="8">%s%s</g><g fill="%s">%s%s</g>' % [LINE, a, b, FILL, a, b]
	two += '<defs><clipPath id="u">%s%s</clipPath></defs>' % [a, b]
	two += '<g clip-path="url(#u)" fill="%s"><rect x="60" y="150" width="180" height="60"/></g></svg>' % MARK
	var n := _render(naive)
	var t := _render(two)
	var inner := Vector2i(140, 140)   # on b's left edge, inside a
	print("naive: outline inside the silhouette at %s: %s" % [inner, _near(n.get_pixelv(inner), LINE, 0.15)])
	print("two-pass: inside is fill: %s" % _near(t.get_pixelv(inner), FILL))
	print("two-pass: outer edge is outline at (78,140): %s" % _near(t.get_pixelv(Vector2i(78, 140)), LINE, 0.15))
	print("two-pass: outline width outside the fill ~ 4 px: %s" % _near(t.get_pixelv(Vector2i(77, 140)), LINE, 0.15))
	print("two-pass: marking clipped inside (150,160) white: %s" % _near(t.get_pixelv(Vector2i(150, 160)), MARK))
	print("two-pass: marking clipped outside (70,200) clear: %s" % (t.get_pixelv(Vector2i(70, 200)).a < 0.05))


## Each probe draws a red square from (20,20) to (80,80) (or the feature's
## version of it) and checks the pixel at the given point.
func _probe() -> void:
	var head := '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 100 100" width="100" height="100">'
	var red_png := _red_png_uri()
	var probes := [
		["clipPath", '<defs><clipPath id="c"><rect x="0" y="0" width="50" height="100"/></clipPath></defs><rect x="20" y="20" width="60" height="60" fill="#FF0000" clip-path="url(#c)"/>', [Vector2i(30, 50), "#FF0000"], [Vector2i(70, 50), "clear"]],
		["mask", '<defs><mask id="m"><rect x="0" y="0" width="50" height="100" fill="#FFFFFF"/></mask></defs><rect x="20" y="20" width="60" height="60" fill="#FF0000" mask="url(#m)"/>', [Vector2i(30, 50), "#FF0000"], [Vector2i(70, 50), "clear"]],
		["linearGradient", '<defs><linearGradient id="g"><stop offset="0" stop-color="#FF0000"/><stop offset="1" stop-color="#0000FF"/></linearGradient></defs><rect x="20" y="20" width="60" height="60" fill="url(#g)"/>', [Vector2i(22, 50), "#FF0000"], [Vector2i(78, 50), "#0000FF"]],
		["radialGradient", '<defs><radialGradient id="g"><stop offset="0" stop-color="#FF0000"/><stop offset="1" stop-color="#0000FF"/></radialGradient></defs><rect x="20" y="20" width="60" height="60" fill="url(#g)"/>', [Vector2i(50, 50), "#FF0000"], [Vector2i(21, 50), "#0000FF"]],
		["stroke-linejoin round", '<polyline points="20,80 50,20 80,80" fill="none" stroke="#FF0000" stroke-width="16" stroke-linejoin="round"/>', [Vector2i(50, 16), "#FF0000"], [Vector2i(50, 6), "clear"]],
		["stroke-linecap round", '<line x1="30" y1="50" x2="70" y2="50" stroke="#FF0000" stroke-width="20" stroke-linecap="round"/>', [Vector2i(25, 50), "#FF0000"], [Vector2i(17, 50), "clear"]],
		["opacity", '<rect x="20" y="20" width="60" height="60" fill="#FF0000" opacity="0.5"/>', [Vector2i(50, 50), "half"], [Vector2i(10, 10), "clear"]],
		["fill-rule evenodd", '<path d="M20 20 H80 V80 H20 Z M35 35 H65 V65 H35 Z" fill="#FF0000" fill-rule="evenodd"/>', [Vector2i(25, 50), "#FF0000"], [Vector2i(50, 50), "clear"]],
		["filter blur", '<defs><filter id="f"><feGaussianBlur stdDeviation="6"/></filter></defs><rect x="20" y="20" width="60" height="60" fill="#FF0000" filter="url(#f)"/>', [Vector2i(16, 50), "some"], [Vector2i(50, 50), "#FF0000"]],
		["text", '<text x="10" y="70" font-size="60" fill="#FF0000">WW</text>', [Vector2i(-1, -1), "anyred"], [Vector2i(0, 0), "clear"]],
		["image data URI", '<image x="20" y="20" width="60" height="60" xlink:href="%s"/>' % red_png, [Vector2i(50, 50), "#FF0000"], [Vector2i(10, 10), "clear"]],
		["image href (SVG 2)", '<image x="20" y="20" width="60" height="60" href="%s"/>' % red_png, [Vector2i(50, 50), "#FF0000"], [Vector2i(10, 10), "clear"]],
		["use", '<defs><rect id="r" width="60" height="60" fill="#FF0000"/></defs><use href="#r" x="20" y="20"/>', [Vector2i(50, 50), "#FF0000"], [Vector2i(10, 10), "clear"]],
		["transform", '<g transform="translate(40 40) rotate(45)"><rect x="-20" y="-20" width="40" height="40" fill="#FF0000"/></g>', [Vector2i(40, 40), "#FF0000"], [Vector2i(40, 13), "#FF0000"]],
		["css style attr", '<rect x="20" y="20" width="60" height="60" style="fill:#FF0000"/>', [Vector2i(50, 50), "#FF0000"], [Vector2i(10, 10), "clear"]],
		["<style> class", '<style>.a{fill:#FF0000}</style><rect class="a" x="20" y="20" width="60" height="60"/>', [Vector2i(50, 50), "#FF0000"], [Vector2i(10, 10), "clear"]],
	]
	for p in probes:
		var img := _render(head + p[1] + "</svg>")
		if img == null:
			print("%-22s | failed to load" % p[0])
			continue
		var ok := _expect(img, p[2]) and _expect(img, p[3])
		print("%-22s | %s" % [p[0], "drawn" if ok else "NOT drawn as expected (%s, %s)" % [_desc(img, p[2][0]), _desc(img, p[3][0])]])


func _expect(img: Image, e: Array) -> bool:
	var at: Vector2i = e[0]
	var want: String = e[1]
	if want == "anyred":
		for y in img.get_height():
			for x in img.get_width():
				if _near(img.get_pixel(x, y), "#FF0000", 0.2):
					return true
		return false
	var c := img.get_pixelv(at)
	match want:
		"clear":
			return c.a < 0.05
		"half":
			return c.a > 0.35 and c.a < 0.65
		"some":
			return c.a > 0.05 and c.a < 0.95
		_:
			return _near(c, want, 0.15)


func _desc(img: Image, at: Vector2i) -> String:
	if at.x < 0:
		return "-"
	return img.get_pixelv(at).to_html()


func _red_png_uri() -> String:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0))
	return "data:image/png;base64," + Marshalls.raw_to_base64(img.save_png_to_buffer())
