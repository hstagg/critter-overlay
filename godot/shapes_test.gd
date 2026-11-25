extends SceneTree
## Headless checks for the Shape Builder's model and writer
## (docs/custom-critters-build-plan.md, D1): every shape type round-trips,
## out-of-range values are brought back or refused, the two-pass outline
## leaves no outline inside a layer, markings stay inside, pins are suggested
## where a person would put them, and a built critter becomes a kit that
## loads.
## Run: godot --headless --path godot --script res://shapes_test.gd

const Shapes := preload("res://studio/shapes.gd")
const Writer := preload("res://studio/shape_svg.gd")
const KitData := preload("res://critters/kit/kit_data.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func near_colour(c: Color, hex: String, tol := 0.12) -> bool:
	var w := Color(hex)
	return c.a > 0.9 and absf(c.r - w.r) < tol and absf(c.g - w.g) < tol and absf(c.b - w.b) < tol


func render(svg: String) -> Image:
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	return img


# A side-on critter built from shapes, with the pins a person would place.
const CRITTER := {
	"schema": 1, "plan": "side", "style": {"outline": "#5B3A29", "width": 5, "blush": true},
	"layers": {
		"walk-body": [{"t": "ellipse", "x": 160, "y": 200, "w": 140, "h": 70, "fill": "#C9A0E8"},
			{"t": "ellipse", "x": 160, "y": 214, "w": 80, "h": 30, "fill": "#F1E4FA", "inside": true, "line": false}],
		"head": [{"t": "ellipse", "x": 100, "y": 150, "w": 110, "h": 96, "fill": "#C9A0E8"}],
		"eyes": [{"t": "eye", "preset": "big", "x": 84, "y": 148, "w": 18, "h": 22, "fill": "#3A2A22"},
			{"t": "eye", "preset": "big", "x": 118, "y": 148, "w": 18, "h": 22, "fill": "#3A2A22"}],
		"leg-front": [{"t": "rect", "x": 116, "y": 240, "w": 22, "h": 44, "r": 9, "fill": "#C9A0E8"}],
		"leg-back": [{"t": "rect", "x": 204, "y": 240, "w": 22, "h": 44, "r": 9, "fill": "#C9A0E8"}],
		"ear-l": [{"t": "tri", "x": 80, "y": 98, "w": 34, "h": 44, "apex": 0.4, "fill": "#C9A0E8"}],
		"tail": [{"t": "stroke", "pts": [[226, 196], [252, 176], [262, 150]], "width": 12, "fill": "#C9A0E8"}],
	},
}
const HAND_PINS := {"neck-walk": [116, 180], "hip-front": [116, 222], "hip-back": [204, 222],
	"tail": [226, 196], "ear-l": [80, 120], "eyes": [101, 148]}


func _init() -> void:
	# --- Every type round-trips: JSON -> model -> JSON.
	var samples := [
		{"t": "ellipse", "x": 100, "y": 120, "w": 60, "h": 40, "rot": 30, "fill": "#AABBCC"},
		{"t": "rect", "x": 100, "y": 120, "w": 60, "h": 40, "r": 10, "fill": "#AABBCC", "flip": true},
		{"t": "tri", "x": 100, "y": 120, "w": 60, "h": 40, "r": 4, "apex": 0.2, "fill": "#AABBCC"},
		{"t": "drop", "x": 100, "y": 120, "w": 30, "h": 50, "fill": "#AABBCC", "line": false},
		{"t": "heart", "x": 100, "y": 120, "w": 40, "h": 36, "fill": "#E05577", "inside": true},
		{"t": "star", "x": 100, "y": 120, "w": 50, "h": 50, "n": 6, "fill": "#F2D060"},
		{"t": "blob", "pts": [[80, 100], [120, 90], [140, 130], [100, 150], [70, 130]], "fill": "#88CC88"},
		{"t": "stroke", "pts": [[60, 60], [90, 40], [120, 60]], "width": 8, "fill": "#333333"},
		{"t": "eye", "preset": "lash", "x": 100, "y": 120, "w": 20, "h": 24, "fill": "#222222"},
	]
	for s in samples:
		var a := Shapes.clean(s)
		var b := Shapes.clean(JSON.parse_string(JSON.stringify(a)))
		check(not a.is_empty() and JSON.stringify(a) == JSON.stringify(b), "%s round-trips" % s.t)
		check(Shapes.polygon(a).size() >= 3, "%s has an outline" % s.t)
		check(render(Writer.HEAD + Shapes.element(a, 'fill="#000000"') + "</svg>").get_used_rect().size.x > 2, "%s draws" % s.t)
	check(Shapes.hit(Shapes.clean(samples[0]), Vector2(100, 120)) and not Shapes.hit(Shapes.clean(samples[0]), Vector2(10, 10)), "hit-testing finds a shape's middle and misses outside it")

	# --- Limits.
	var warn := []
	var far := Shapes.clean({"t": "ellipse", "x": 999, "y": -500, "w": 9000, "h": 0.5, "fill": "red"}, warn)
	check(far.x == 360.0 and far.y == -60.0 and far.w == 400.0 and far.h == 2.0 and far.fill == Shapes.DEFAULT_FILL, "out-of-range values are brought back")
	check(warn.size() >= 4, "and each is said (%d)" % warn.size())
	check(Shapes.clean({"t": "laser"}).is_empty(), "an unknown type is refused")
	check(Shapes.clean({"t": "blob", "pts": [[0, 0], [1, 1]]}).is_empty(), "a blob of two points is refused")
	check(Shapes.clean({"t": "star", "n": 40}).n == 8 and Shapes.clean({"t": "star", "n": 1}).n == 4, "star points stay 4 to 8")
	var long_pts := []
	for i in 20:
		long_pts.append([i * 10, 50])
	check(Shapes.clean({"t": "blob", "pts": long_pts}).pts.size() == 12, "a blob keeps 12 points at most")
	var crowd := {"layers": {"walk-body": []}}
	for i in 70:
		crowd.layers["walk-body"].append({"t": "ellipse", "x": 150, "y": 200})
	var cd := Writer.clean_doc(crowd)
	check(cd.doc.layers["walk-body"].size() == 60 and not cd.warnings.is_empty(), "a layer keeps 60 shapes at most")

	# --- The two-pass outline: no outline inside, one round the outside.
	var two := [Shapes.clean({"t": "ellipse", "x": 120, "y": 140, "w": 80, "h": 80, "fill": "#F6C28F"}),
		Shapes.clean({"t": "ellipse", "x": 180, "y": 140, "w": 80, "h": 80, "fill": "#F6C28F"}),
		Shapes.clean({"t": "rect", "x": 150, "y": 175, "w": 160, "h": 30, "r": 0, "fill": "#FFFFFF", "inside": true})]
	var img := render(Writer.HEAD + Writer.layer(two, "#5B3A29", 4.0) + "</svg>")
	var inner_bad := 0
	for y in range(110, 170, 3):
		# The seam where the two circles meet, well inside the silhouette.
		if near_colour(img.get_pixel(140, y), "#5B3A29", 0.2):
			inner_bad += 1
	check(inner_bad == 0, "no outline pixels inside the layer (%d)" % inner_bad)
	check(near_colour(img.get_pixel(78, 140), "#5B3A29", 0.2), "an outline round the outside")
	check(near_colour(img.get_pixel(150, 170), "#FFFFFF") and img.get_pixel(150, 188).a < 0.05 or not near_colour(img.get_pixel(240, 180), "#FFFFFF"), "the marking stays inside")

	# --- The writer: parts, closed eyes, blush, and everything draws.
	var parts := Writer.write(CRITTER)
	for p in CRITTER.layers:
		check(parts.has(p), "%s is written" % p)
	check(parts.has("eyes-closed"), "closed eyes are made from the eyes")
	check(parts.head.contains(Writer.BLUSH), "blush goes on the head")
	var bad := 0
	for p in parts:
		if render(parts[p]).get_used_rect().size.x <= 0:
			bad += 1
	check(bad == 0, "every part draws (%d don't)" % bad)

	# --- Pins suggested near where a person puts them.
	var cleaned: Dictionary = Writer.clean_doc(CRITTER).doc
	var pins := Shapes.suggest_pins(cleaned.layers)
	for k in HAND_PINS:
		var got := Vector2(pins[k][0], pins[k][1]) if pins.has(k) else Vector2(-999, -999)
		var want := Vector2(HAND_PINS[k][0], HAND_PINS[k][1])
		check(got.distance_to(want) <= 6.0, "suggested %s is within 6 units (%s vs %s)" % [k, got, want])

	# --- A built critter is a kit.
	var dir := "user://shapes_test_kit"
	DirAccess.make_dir_recursive_absolute(dir.path_join("parts"))
	for p in parts:
		var f := FileAccess.open(dir.path_join("parts/%s.svg" % p), FileAccess.WRITE)
		f.store_string(parts[p])
		f.close()
	var kit := {"schema": 1, "plan": "side", "gait": "trot", "pins": pins}
	check(KitData.missing(dir, kit).is_empty(), "a built critter has all it needs (%s)" % str(KitData.missing(dir, kit)))
	var r := KitData.build(dir, kit)
	check(r.images.has("loaf-body") and r.images.has("leg-front-far") and r.images.has("ear-r"), "and the rig fills in the rest")
	for p in DirAccess.get_files_at(dir.path_join("parts")):
		DirAccess.remove_absolute(dir.path_join("parts/" + p))
	for p in DirAccess.get_files_at(dir.path_join("cache")):
		DirAccess.remove_absolute(dir.path_join("cache/" + p))
	for sub in ["parts", "cache", ""]:
		DirAccess.remove_absolute(dir.path_join(sub))

	print("SHAPES TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
