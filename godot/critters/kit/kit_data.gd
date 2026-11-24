extends RefCounted
## A homemade kit's data (docs/custom-critters-build-plan.md, 4.1-4.7 and 5.2):
## reads kit.json and the drawn parts, fills in the parts that weren't drawn
## from the critter's own art (P1: never from the cast's), works out the
## numbers the rig needs (P4: grounding, size, leg length, hit bounds, all
## computed, never typed in), and hands the kit rigs (side.gd and the other
## plans) everything critter.gd's _define() would set.
##
## A kit folder (user://custom/<id>/) holds kit.json and parts/<part>.svg or
## parts/<part>.png, every part drawn in the cast's shared 300 x 280 frame,
## facing left, standing on y 262. Parts are rasterised once into
## cache/<part>.png (rebuilt when CACHE changes or the files are newer), so a
## spawn never parses an SVG.
##
## Pins (kit.json "pins") are joints, in that frame:
##   neck-walk, neck-sit, neck-loaf, neck-stand  where the head sits in each pose
##   head          where the head is pivoted in its own drawing (default neck-walk)
##   hip-front, hip-back (and -far)              where each leg hangs
##   leg-front ...  where a leg is pivoted in its own drawing (default its hip)
##   tail, tail-walk, tail-sit                   the tail's own pivot and where it sits
##   ear-l, ear-r, eyes, mouth-open, nose, wing  pivots of those parts
## Only a plan's required pins must be there; the rest have defaults.
##
## This file is pure: it preloads nothing of the game, so customs.gd can.

const PART_SCALE := 0.75       # critter.gd's: SVG units -> texture pixels
const FRAME := Vector2(300, 280)
const BASE := Vector2(150, 262)
const GROUND := 262.0
const CACHE := 1               # bump to make every kit rasterise its parts again
# The kitten's walking pose is this many units tall (kitten-as-kit, kit_test):
# a kit as tall as the kitten is drawn the kitten's size, 0.45.
const REF_HEIGHT := 226.0
const REF_SCALE := 0.45
const SCALE_MIN := 0.3
const SCALE_MAX := 0.7
const FAR_TINT := 0.82         # a far leg or ear made from the near one: 18% darker
const FAR_LEG_SHIFT := 8.0     # units back
const FAR_EAR_SHIFT := 10.0
const MELT := 0.85             # the automatic nap: the walking body squashed to this
const HIT_PAD := 4.0
const PIN_SLACK := 60.0        # a pin may sit this far from its default (4.7)

const PLANS := {
	"side": {
		"rig": "res://critters/kit/side.gd",
		"required": ["walk-body", "head", "eyes", "leg-front", "leg-back"],
		"optional": ["leg-front-far", "leg-back-far", "body", "loaf-body", "stand-body",
			"eyes-closed", "ear-l", "ear-r", "tail", "mouth-open", "nose", "head-front",
			"wing", "back-extra", "front-extra", "groom-paws", "scratch-foot"],
		"pins": ["neck-walk", "hip-front", "hip-back", "eyes"],
		"gaits": ["trot", "hop"],
		"speed": Vector2(38.0, 62.0),
		"legged": true,
	},
	"front": {
		"rig": "res://critters/kit/front.gd",
		"required": ["body", "head", "eyes", "walk-body", "leg-front", "leg-back"],
		"optional": ["head-side", "eye-side", "eye-side-closed", "eyes-closed", "loaf-body",
			"loaf-eyes", "loaf-eyes-closed", "ear-l", "ear-r", "foot-l", "foot-r", "paws", "tail",
			"mouth-open", "nose", "head-front", "wing", "back-extra", "front-extra",
			"leg-front-far", "leg-back-far", "groom-paws", "scratch-foot", "stand-body"],
		"pins": ["neck-sit", "neck-walk", "hip-front", "hip-back", "eyes"],
		"gaits": ["trot", "plod", "scurry", "dart", "slide", "bounce", "sway"],
		"speed": Vector2(40.0, 62.0),
		"legged": true,
	},
	"upright": {
		"rig": "res://critters/kit/upright.gd",
		"required": ["body", "head", "eyes", "leg-near"],
		"optional": ["leg-far", "walk-body", "wing-l", "wing-r", "wing-side", "loaf-body", "tuft",
			"tail", "eyes-closed", "mouth-open", "head-front", "back-extra", "front-extra",
			"foot-l", "foot-r"],
		"pins": ["neck-sit", "hip", "eyes"],
		"gaits": ["waddle", "hop"],
		"speed": Vector2(35.0, 58.0),
		"legged": true,
	},
	"blob": {
		"rig": "res://critters/kit/blob.gd",
		"required": ["body", "eyes"],
		"optional": ["head", "eyes-closed", "mouth-open", "ear-l", "ear-r", "tail", "head-front",
			"back-extra", "loaf-body"],
		"pins": ["eyes"],
		"gaits": ["blob_bounce", "glide", "float", "slither"],
		"speed": Vector2(32.0, 52.0),
		"legged": false,
	},
}

static var _rigs := {}         # tex key ("custom:<id>@<rev>") -> rig


static func plan(kit: Dictionary) -> Dictionary:
	return PLANS.get(str(kit.get("plan", "")), {})


static func missing(folder: String, kit: Dictionary) -> Array:
	# The required parts and pins this kit hasn't got, by name.
	var pl := plan(kit)
	if pl.is_empty():
		return ["a known body plan"]
	var out := []
	for part in pl.required:
		if part_file(folder, part) == "":
			out.append(part)
	var pins: Dictionary = kit.get("pins", {})
	for pin in pl.pins:
		if not pins.has(pin):
			out.append("the %s pin" % pin)
	return out


static func part_file(folder: String, part: String) -> String:
	for ext in ["svg", "png"]:
		var p := folder.path_join("parts/%s.%s" % [part, ext])
		if FileAccess.file_exists(p):
			return p
	return ""


static func drawn(folder: String, kit: Dictionary) -> Array:
	# Every part of the plan that has a file.
	var pl := plan(kit)
	return (pl.required + pl.optional).filter(func(p): return part_file(folder, p) != "")


# --- Images --------------------------------------------------------------------

static func image(folder: String, part: String) -> Image:
	# A part at PART_SCALE in the frame: from the cache when it is current,
	# otherwise rasterised (SVG) or fitted (PNG) and cached.
	var src := part_file(folder, part)
	if src == "":
		return null
	var cached := folder.path_join("cache/%s.png" % part)
	var stamp := "%d:%d" % [CACHE, FileAccess.get_modified_time(src)]
	var stamp_path := folder.path_join("cache/%s.stamp" % part)
	if FileAccess.file_exists(cached) and FileAccess.get_file_as_string(stamp_path) == stamp:
		var c := Image.load_from_file(cached)
		if c != null and not c.is_empty():
			return c
	var img := Image.new()
	if src.ends_with(".svg"):
		if img.load_svg_from_string(FileAccess.get_file_as_string(src), PART_SCALE) != OK:
			return null
	else:
		img = Image.load_from_file(src)
		if img == null or img.is_empty():
			return null
	img.convert(Image.FORMAT_RGBA8)
	var want := Vector2i((FRAME * PART_SCALE).round())
	if img.get_size() != want:
		img.resize(want.x, want.y, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(folder.path_join("cache"))
	img.save_png(cached)
	var f := FileAccess.open(stamp_path, FileAccess.WRITE)
	if f != null:
		f.store_string(stamp)
	return img


static func tinted(img: Image, k: float, shift_units := 0.0) -> Image:
	# A darker copy, moved back (towards the tail, +x) by shift_units.
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var dx := roundi(shift_units * PART_SCALE)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and x + dx < out.get_width():
				out.set_pixel(x + dx, y, Color(c.r * k, c.g * k, c.b * k, c.a))
	return out


static func widened(img: Image, k: float) -> Image:
	# Stretched to k of its width about the frame's middle (x 150).
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var wide: Image = img.duplicate()
	var w := roundi(img.get_width() * k)
	wide.resize(w, img.get_height(), Image.INTERPOLATE_BILINEAR)
	var cut := (w - img.get_width()) / 2
	out.blit_rect(wide, Rect2i(cut, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	return out


static func squashed(img: Image, k: float) -> Image:
	# Squashed to k of its height towards the top of the frame (the rig moves
	# it back down onto the ground with its pivot).
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var small: Image = img.duplicate()
	small.resize(img.get_width(), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
	out.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i.ZERO)
	return out


static func mirrored(img: Image, about_x: float) -> Image:
	# Flipped left to right about x = about_x (SVG units).
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var c := about_x * PART_SCALE
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			var to := roundi(2.0 * c - x - 1)
			if px.a > 0.0 and to >= 0 and to < out.get_width():
				out.set_pixel(to, y, px)
	return out


static func bounds(img: Image) -> Rect2:
	# The drawn area in SVG units, or an empty rect.
	if img == null:
		return Rect2()
	var r := img.get_used_rect()
	if r.size.x <= 0:
		return Rect2()
	return Rect2(Vector2(r.position) / PART_SCALE, Vector2(r.size) / PART_SCALE)


# --- Pins ------------------------------------------------------------------------

static func pins(kit: Dictionary) -> Dictionary:
	# Every pin the rig uses, with defaults, clamped to the frame and hips
	# below the neck. "warnings" lists any the clamp moved.
	var raw: Dictionary = kit.get("pins", {})
	var p := {}
	var warn := []
	for k in raw:
		var v = raw[k]
		if typeof(v) == TYPE_ARRAY and v.size() >= 2:
			p[k] = Vector2(float(v[0]), float(v[1]))
	var def := func(k: String, v: Vector2) -> void:
		if not p.has(k):
			p[k] = v
	if str(kit.get("plan", "")) == "upright":
		# One pair of legs under a body facing you (duckling.gd's numbers).
		def.call("neck-walk", p.get("neck-sit", Vector2(126, 196)))
		def.call("hip", Vector2(154, 244))
		def.call("hip-front", p["hip"])
		def.call("hip-back", p.get("hip-far", p["hip"] + Vector2(28, 0)))
	def.call("neck-walk", Vector2(112, 198))
	def.call("hip-front", Vector2(118, 224))
	def.call("hip-back", Vector2(196, 224))
	def.call("eyes", Vector2(100, 150))
	for k in p:
		var c: Vector2 = p[k].clamp(Vector2.ZERO, FRAME)
		if c != p[k]:
			warn.append("%s was outside the frame" % k)
			p[k] = c
	for hip in ["hip-front", "hip-back", "hip-front-far", "hip-back-far"]:
		if p.has(hip) and p[hip].y <= p["neck-walk"].y:
			p[hip] = Vector2(p[hip].x, p["neck-walk"].y + 1.0)
			warn.append("%s was above the neck" % hip)
	def.call("neck-sit", p["neck-walk"])
	# The head is drawn where it sits in the plan's one required pose.
	match str(kit.get("plan", "")):
		"front":
			def.call("head", p["neck-sit"])
		"blob":
			def.call("head", p["eyes"] + Vector2(0, 30))   # where its eyes and ears ride
	def.call("head", p["neck-walk"])
	def.call("eye-side", p["neck-walk"] + Vector2(-30, -40))
	def.call("tail-walk", p.get("tail", Vector2(226, 192)))
	def.call("tail", p["tail-walk"])
	def.call("tail-sit", p["tail"])
	def.call("mouth-open", p["eyes"] + Vector2(0, 28))
	def.call("nose", p["eyes"] + Vector2(0, 18))
	def.call("wing", p["neck-walk"].lerp(p["hip-back"], 0.5))
	def.call("wing-l", p["neck-sit"] + Vector2(-42, 10))
	def.call("wing-r", Vector2(2.0 * p["neck-sit"].x - p["wing-l"].x, p["wing-l"].y))
	def.call("wing-side", p["neck-sit"] + Vector2(4, 12))
	def.call("tuft", p["neck-sit"] + Vector2(0, -136))
	def.call("ear-l", p["head"] + Vector2(-20, -60))
	def.call("ear-r", p["ear-l"] + Vector2(FAR_EAR_SHIFT, 0))
	p["warnings"] = warn
	return p


# --- The rig ---------------------------------------------------------------------

static func forget(id: String) -> void:
	for k in _rigs.keys():
		if k.begins_with(id + "@"):
			_rigs.erase(k)


static func rig(key: String, folder: String, kit: Dictionary, size := 1.0, speed := 1.0) -> Dictionary:
	# Everything a kit rig's _define() sets, its part images and what was
	# filled in. Cached by key (customs.gd tex_key: changes with every edit).
	if _rigs.has(key):
		return _rigs[key]
	var r := build(folder, kit, size, speed)
	_rigs[key] = r
	return r


static func build(folder: String, kit: Dictionary, size := 1.0, speed := 1.0) -> Dictionary:
	var pl := plan(kit)
	var P := pins(kit)
	var imgs := {}
	for part in drawn(folder, kit):
		var img := image(folder, part)
		if img != null:
			imgs[part] = img
	var auto := {}
	var front := str(kit.get("plan", "")) == "front"
	var blob := str(kit.get("plan", "")) == "blob"
	var upright := str(kit.get("plan", "")) == "upright"
	var pivots := {"walk-body": BASE}
	var head_pivot: Vector2 = P["head"]
	if imgs.has("head"):
		pivots["head"] = head_pivot
	pivots["eyes"] = P["eyes"]
	if imgs.has("eyes-closed"):
		pivots["eyes-closed"] = P["eyes"]
	else:
		auto["eyes-closed"] = "squash"   # critter.gd's blink squashes the eyes
	for part in ["mouth-open", "nose"]:
		if imgs.has(part):
			pivots[part] = P[part]
	if imgs.has("head-front"):
		pivots["head-front"] = head_pivot
	for part in ["back-extra", "front-extra", "stand-body"]:
		if imgs.has(part):
			pivots[part] = BASE
	for part in ["wing", "groom-paws", "scratch-foot"]:
		if imgs.has(part):
			pivots[part] = P[part] if part == "wing" or P.has(part) else BASE

	# Legs, back to front: far front, far back, near front, near back (a trot:
	# near front steps with far back). A far leg not drawn is the near one,
	# darker, a little further back. Upright: one near and one far leg.
	var walk_legs := []
	var leg_pins := {}
	if upright:
		var hip: Vector2 = P["hip"]
		var art: Vector2 = P.get("leg-near", hip)
		var far_hip: Vector2 = P.get("hip-far", hip + Vector2(28, 0))
		pivots["leg-near"] = art
		if imgs.has("leg-far"):
			pivots["leg-far"] = P.get("leg-far", art)
		else:
			imgs["leg-far"] = tinted(imgs["leg-near"], FAR_TINT)
			pivots["leg-far"] = art
			auto["leg-far"] = "tint"
		walk_legs = [["leg-far", far_hip, 1, false], ["leg-near", hip, 0, true]]
	for side in ([] if upright or blob else ["front", "back"]):
		var near: String = "leg-" + side
		var far: String = near + "-far"
		var hip: Vector2 = P["hip-" + side]
		var art: Vector2 = P.get(near, hip)
		pivots[near] = art
		if imgs.has(far):
			leg_pins[far] = [P.get("hip-%s-far" % side, hip), P.get(far, P.get("hip-%s-far" % side, hip))]
		elif imgs.has(near):
			imgs[far] = tinted(imgs[near], FAR_TINT)
			leg_pins[far] = [hip + Vector2(FAR_LEG_SHIFT, 0), art]
			auto[far] = "tint"
		pivots[far] = leg_pins[far][1]
		leg_pins[near] = [hip, art]
	if not upright and not blob:
		walk_legs = [
			["leg-front-far", leg_pins["leg-front-far"][0], 1, true],
			["leg-back-far", leg_pins["leg-back-far"][0], 0, false],
			["leg-front", leg_pins["leg-front"][0], 0, true],
			["leg-back", leg_pins["leg-back"][0], 1, false],
		]

	# Ears: the far one (ear-r) not drawn is the near one, darker and back.
	var ear_parts := []
	if imgs.has("ear-l"):
		pivots["ear-l"] = P["ear-l"]
		ear_parts.append("ear-l")
		if not imgs.has("ear-r") and front:
			# Facing you: the other ear is this one mirrored about the face.
			imgs["ear-r"] = mirrored(imgs["ear-l"], head_pivot.x)
			auto["ear-r"] = "mirror"
			pivots["ear-r"] = Vector2(2.0 * head_pivot.x - P["ear-l"].x, P["ear-l"].y)
		elif not imgs.has("ear-r"):
			imgs["ear-r"] = tinted(imgs["ear-l"], FAR_TINT, FAR_EAR_SHIFT)
			auto["ear-r"] = "tint"
			pivots["ear-r"] = P["ear-l"] + Vector2(FAR_EAR_SHIFT, 0)
		else:
			pivots["ear-r"] = P["ear-r"]
		if auto.get("ear-r", "") == "tint":
			ear_parts.insert(0, "ear-r")   # the made-up far ear goes behind
		else:
			ear_parts.append("ear-r")
	elif imgs.has("ear-r"):
		pivots["ear-r"] = P["ear-r"]
		ear_parts.append("ear-r")

	# Poses. Sitting not drawn: the walking body with its legs at rest.
	# Napping not drawn: the walking body melted onto the ground (P3).
	var head_at := {"walk": P["neck-walk"]}
	var tail_at := {}
	var sit_parts := []
	if blob:
		# One body for every pose; no legs. Its eyes ride on the body when
		# there is no head (the head node holds them either way).
		imgs["walk-body"] = imgs["body"]
		pivots["body"] = BASE
		sit_parts = ["body"]
		head_at["walk"] = head_pivot
		head_at["sit"] = head_pivot
	elif upright:
		# Stands facing you; walks on its walking body, or the same body.
		for part in ["body", "foot-l", "foot-r"]:
			if imgs.has(part):
				pivots[part] = BASE
				sit_parts.append(part)
		head_at["sit"] = P["neck-sit"]
		if not imgs.has("walk-body"):
			imgs["walk-body"] = imgs["body"]
			auto["walk-body"] = "body"
		if imgs.has("wing-l"):
			pivots["wing-l"] = P["wing-l"]
			if not imgs.has("wing-r"):
				imgs["wing-r"] = mirrored(imgs["wing-l"], P["neck-sit"].x)
				auto["wing-r"] = "mirror"
			pivots["wing-r"] = P["wing-r"]
			if not imgs.has("wing-side"):
				imgs["wing-side"] = imgs["wing-l"]
				auto["wing-side"] = "wing-l"
				pivots["wing-side"] = P["wing-l"]
			else:
				pivots["wing-side"] = P["wing-side"]
		if imgs.has("tuft"):
			pivots["tuft"] = P["tuft"]
	elif front:
		# Sits facing you (required), walks side-on: the walking face is
		# head-side when drawn, else the front face (as the panda's).
		for part in ["foot-l", "foot-r", "body", "paws"]:
			if imgs.has(part):
				pivots[part] = BASE
				sit_parts.append(part)
		head_at["sit"] = P["neck-sit"]
		if imgs.has("head-side"):
			pivots["head-side"] = P["neck-walk"]
			for part in ["eye-side", "eye-side-closed"]:
				if imgs.has("eye-side") and imgs.has(part):
					pivots[part] = P["eye-side"]
		else:
			auto["head-side"] = "front face"
		if imgs.has("loaf-eyes") and imgs.has("loaf-eyes-closed"):
			pivots["loaf-eyes"] = P.get("loaf-eyes", BASE)
			pivots["loaf-eyes-closed"] = pivots["loaf-eyes"]
	elif imgs.has("body"):
		pivots["body"] = BASE
		sit_parts = ["body"]
		head_at["sit"] = P["neck-sit"]
	else:
		auto["body"] = "walk"
		head_at["sit"] = P["neck-walk"]
	# Napping not drawn: the pose it was drawn in, melted onto the ground.
	var melt_from := "body" if front or upright or blob else "walk-body"
	var melt_neck: Vector2 = head_pivot if blob else (P["neck-sit"] if front or upright else P["neck-walk"])
	var wb := bounds(imgs[melt_from])
	var bottom := wb.end.y if wb.size.y > 0 else GROUND
	var melt := func(v: Vector2) -> Vector2:
		return Vector2(v.x, GROUND + MELT * (v.y - bottom))
	if imgs.has("loaf-body"):
		pivots["loaf-body"] = BASE
		head_at["loaf"] = P.get("neck-loaf", P["neck-walk"] + Vector2(0, 20))
	elif blob:
		# 4.4: melted, 120% wide and 70% tall.
		imgs["loaf-body"] = squashed(widened(imgs["body"], 1.2), 0.7)
		pivots["loaf-body"] = Vector2(BASE.x, 0.7 * bottom)
		auto["loaf-body"] = "melt"
		head_at["loaf"] = Vector2(head_pivot.x, GROUND + 0.7 * (head_pivot.y - bottom))
	else:
		imgs["loaf-body"] = squashed(imgs[melt_from], MELT)
		pivots["loaf-body"] = Vector2(BASE.x, MELT * bottom)
		auto["loaf-body"] = "melt"
		head_at["loaf"] = melt.call(melt_neck)
	if imgs.has("stand-body"):
		head_at["stand"] = P.get("neck-stand", P["neck-sit"])
	if imgs.has("tail"):
		pivots["tail"] = P["tail"]
		tail_at["walk"] = P["tail-walk"]
		tail_at["sit"] = P["tail-sit"] if imgs.has("body") else P["tail-walk"]
		if front:
			tail_at["sit"] = P["tail-sit"]
		if upright:
			tail_at.erase("sit")   # duckling.gd: the tail shows only walking
		if blob:
			tail_at["sit"] = P["tail-walk"]
			tail_at["loaf"] = Vector2(P["tail-walk"].x, GROUND + 0.7 * (P["tail-walk"].y - bottom))
		if auto.has("loaf-body"):
			tail_at["loaf"] = melt.call(P["tail-walk"])

	var r := {
		"plan": kit.get("plan"), "images": imgs, "auto": auto, "warnings": P["warnings"],
		"pivots": pivots, "head_pivot": head_pivot, "head_at": head_at, "tail_at": tail_at,
		"walk_legs": walk_legs, "sit_parts": sit_parts, "ear_parts": ear_parts,
		"tail_rest_deg": {"sit": 0.0, "walk": -10.0 if imgs.has("tail") else 0.0},
		"front_hip": P["hip-front"], "back_hip": P["hip-back"],
		"gait": str(kit.get("gait", "trot")) if str(kit.get("gait", "trot")) in pl.gaits else "trot",
	}
	r["side_pivot"] = P["neck-walk"]
	r["two_faces"] = imgs.has("head-side")
	r["wear_neck"] = P["neck-sit"]
	r["wear_walk_shift"] = P["neck-walk"] - P["neck-sit"]
	r["wear_nap_shift"] = head_at["loaf"] - P["neck-sit"]
	r["mid"] = (P["hip-front"] + P["hip-back"]) * 0.5 - Vector2(0, 10)
	r["feet"] = Vector2(BASE.x, GROUND)
	r["blob"] = blob
	r["leg_len"] = maxf(8.0, GROUND - (P["hip"] if upright else P["hip-front"]).y)
	if blob:
		# No legs: leg_len only sets how far one gait cycle carries it
		# (critter.gd cycle_px), a step about a third of its height.
		var bb := bounds(imgs["body"])
		r["leg_len"] = maxf(8.0, bb.size.y * 0.3)
		r["mid"] = Vector2(bb.get_center().x, bb.end.y - 10.0)
		r["feet"] = Vector2(bb.get_center().x, GROUND)
	r["stride_deg"] = 26.0 if upright else 18.0
	r["leg_lift"] = 6.0 * r["leg_len"] / 38.0
	r["hit_bounds"] = hit_bounds(r)
	var walk_hit: Rect2 = r["hit_bounds"]["walk"].grow(-HIT_PAD)
	var tall := maxf(40.0, GROUND - walk_hit.position.y)
	r["critter_scale"] = clampf(REF_SCALE * REF_HEIGHT / tall, SCALE_MIN, SCALE_MAX) * clampf(size, 0.5, 2.0)
	var eyes_walk: Vector2 = P["neck-walk"] + P["eyes"] - head_pivot
	r["head_height"] = (GROUND - eyes_walk.y) * PART_SCALE * r["critter_scale"]
	r["speed_range"] = pl.speed * clampf(speed, 0.5, 2.0)
	r["ground_dy"] = GROUND - _lowest(r, "walk")
	# host.gd's spin centre and confetti height (P17), px at zoom 1.
	r["body_centre_px"] = walk_hit.size.y * 0.5 * PART_SCALE * r["critter_scale"]
	r["head_top_px"] = tall * PART_SCALE * r["critter_scale"]
	return r


static func _placed(r: Dictionary, pose: String) -> Array:
	# [image, offset in units] for each part drawn in a pose, legs at rest.
	var imgs: Dictionary = r.images
	var pv: Dictionary = r.pivots
	var out := []
	var body_parts := []
	match pose:
		"walk":
			body_parts = ["walk-body", "back-extra", "front-extra", "wing", "wing-side"]
		"sit":
			body_parts = r.sit_parts + ["wing-l", "wing-r"] if not r.sit_parts.is_empty() else ["walk-body", "back-extra", "front-extra", "wing"]
		"loaf":
			body_parts = ["loaf-body"]
		"stand":
			body_parts = ["stand-body"]
	for part in body_parts:
		if imgs.has(part):
			# Sprites in the body sit at BASE - pivot; the wing turns on a
			# pivot node, which leaves its art where it was drawn.
			out.append([imgs[part], Vector2.ZERO if part in ["wing", "wing-side", "wing-l", "wing-r"] else BASE - pv[part]])
	if pose == "walk" or (pose == "sit" and r.sit_parts.is_empty()):
		for spec in r.walk_legs:
			if imgs.has(spec[0]):
				out.append([imgs[spec[0]], spec[1] - pv[spec[0]]])
	if r.head_at.has(pose):
		var off: Vector2 = r.head_at[pose] - r.head_pivot
		if pose == "walk" and r.get("two_faces", false):
			# Walking shows the side face, drawn where it sits.
			out.append([imgs["head-side"], r.head_at[pose] - pv["head-side"]])
		else:
			for part in ["head", "eyes", "head-front"] + r.ear_parts:
				if imgs.has(part):
					out.append([imgs[part], off])
	if r.tail_at.has(pose) and imgs.has("tail"):
		out.append([imgs["tail"], r.tail_at[pose] - pv["tail"]])
	return out


static func hit_bounds(r: Dictionary) -> Dictionary:
	# Per pose, the union of what is drawn, in units, plus HIT_PAD (4.7).
	var out := {}
	for pose in ["walk", "sit", "loaf", "stand"]:
		var u := Rect2()
		for pair in _placed(r, pose):
			var b := bounds(pair[0])
			if b.size.x <= 0:
				continue
			b.position += pair[1]
			u = b if u.size.x <= 0 else u.merge(b)
		if u.size.x > 0:
			out[pose] = u.grow(HIT_PAD)
	if not out.has("sit"):
		out["sit"] = out["walk"]
	if not out.has("stand"):
		out["stand"] = out["sit"]
	return out


static func _lowest(r: Dictionary, pose: String) -> float:
	var y := 0.0
	for pair in _placed(r, pose):
		var b := bounds(pair[0])
		if b.size.x > 0:
			y = maxf(y, b.end.y + pair[1].y)
	return y


static func apply(c: Node, r: Dictionary) -> void:
	# Sets a critter.gd rig's shape from a kit rig.
	c.base_pt = BASE
	c.ground_y = GROUND
	c.pivots = r.pivots
	c.head_pivot = r.head_pivot
	c.head_at = r.head_at
	c.tail_at = r.tail_at
	c.tail_rest_deg = r.tail_rest_deg
	c.walk_legs = r.walk_legs
	c.leg_len = r.leg_len
	c.stride_deg = r.stride_deg
	c.leg_lift = r.leg_lift
	c.hit_bounds = r.hit_bounds
	c.sit_parts = r.sit_parts
	c.ear_parts = r.ear_parts
	c.speed_range = r.speed_range
	c.head_height = r.head_height
	c.back_hip = r.back_hip
	c.critter_scale = r.critter_scale
