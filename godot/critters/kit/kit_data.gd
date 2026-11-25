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


static func squashed(img: Image, k: float) -> Image:
	# Squashed to k of its height towards the top of the frame (the rig moves
	# it back down onto the ground with its pivot).
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var small: Image = img.duplicate()
	small.resize(img.get_width(), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
	out.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i.ZERO)
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
	def.call("head", p["neck-walk"])
	def.call("neck-sit", p["neck-walk"])
	def.call("tail-walk", p.get("tail", Vector2(226, 192)))
	def.call("tail", p["tail-walk"])
	def.call("tail-sit", p["tail"])
	def.call("mouth-open", p["eyes"] + Vector2(0, 28))
	def.call("nose", p["eyes"] + Vector2(0, 18))
	def.call("wing", p["neck-walk"].lerp(p["hip-back"], 0.5))
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
	var pivots := {"walk-body": BASE}
	var head_pivot: Vector2 = P["head"]
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
	# darker, a little further back.
	var walk_legs := []
	var leg_pins := {}
	for side in ["front", "back"]:
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
		if not imgs.has("ear-r"):
			imgs["ear-r"] = tinted(imgs["ear-l"], FAR_TINT, FAR_EAR_SHIFT)
			auto["ear-r"] = "tint"
			pivots["ear-r"] = P["ear-l"] + Vector2(FAR_EAR_SHIFT, 0)
		else:
			pivots["ear-r"] = P["ear-r"]
		if auto.has("ear-r"):
			ear_parts.insert(0, "ear-r")   # the made-up far ear goes behind
		else:
			ear_parts.append("ear-r")
	elif imgs.has("ear-r"):
		pivots["ear-r"] = P["ear-r"]
		ear_parts.append("ear-r")

	# Poses. Sitting not drawn: the walking body with its legs at rest.
	# Napping not drawn: the walking body melted onto the ground (P3).
	var walk_body: Image = imgs["walk-body"]
	var wb := bounds(walk_body)
	var head_at := {"walk": P["neck-walk"]}
	var tail_at := {}
	var sit_parts := []
	if imgs.has("body"):
		pivots["body"] = BASE
		sit_parts = ["body"]
		head_at["sit"] = P["neck-sit"]
	else:
		auto["body"] = "walk"
		head_at["sit"] = P["neck-walk"]
	var bottom := wb.end.y if wb.size.y > 0 else GROUND
	var melt := func(v: Vector2) -> Vector2:
		return Vector2(v.x, GROUND + MELT * (v.y - bottom))
	if imgs.has("loaf-body"):
		pivots["loaf-body"] = BASE
		head_at["loaf"] = P.get("neck-loaf", P["neck-walk"] + Vector2(0, 20))
	else:
		imgs["loaf-body"] = squashed(walk_body, MELT)
		pivots["loaf-body"] = Vector2(BASE.x, MELT * bottom)
		auto["loaf-body"] = "melt"
		head_at["loaf"] = melt.call(P["neck-walk"])
	if imgs.has("stand-body"):
		head_at["stand"] = P.get("neck-stand", P["neck-sit"])
	if imgs.has("tail"):
		pivots["tail"] = P["tail"]
		tail_at["walk"] = P["tail-walk"]
		tail_at["sit"] = P["tail-sit"] if imgs.has("body") else P["tail-walk"]
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
	r["mid"] = (P["hip-front"] + P["hip-back"]) * 0.5 - Vector2(0, 10)
	r["feet"] = Vector2(BASE.x, GROUND)
	r["leg_len"] = maxf(8.0, GROUND - P["hip-front"].y)
	r["stride_deg"] = 18.0
	r["leg_lift"] = 6.0 * r["leg_len"] / 38.0
	r["hit_bounds"] = hit_bounds(r)
	var walk_hit: Rect2 = r["hit_bounds"]["walk"].grow(-HIT_PAD)
	var tall := maxf(40.0, GROUND - walk_hit.position.y)
	r["critter_scale"] = clampf(REF_SCALE * REF_HEIGHT / tall, SCALE_MIN, SCALE_MAX) * clampf(size, 0.5, 2.0)
	var eyes_walk: Vector2 = P["neck-walk"] + P["eyes"] - head_pivot
	r["head_height"] = (GROUND - eyes_walk.y) * PART_SCALE * r["critter_scale"]
	r["speed_range"] = pl.speed * clampf(speed, 0.5, 2.0)
	r["ground_dy"] = GROUND - _lowest(r, "walk")
	return r


static func _placed(r: Dictionary, pose: String) -> Array:
	# [image, offset in units] for each part drawn in a pose, legs at rest.
	var imgs: Dictionary = r.images
	var pv: Dictionary = r.pivots
	var out := []
	var body_parts := []
	match pose:
		"walk":
			body_parts = ["walk-body", "back-extra", "front-extra", "wing"]
		"sit":
			body_parts = ["body"] if not r.sit_parts.is_empty() else ["walk-body", "back-extra", "front-extra", "wing"]
		"loaf":
			body_parts = ["loaf-body"]
		"stand":
			body_parts = ["stand-body"]
	for part in body_parts:
		if imgs.has(part):
			# Sprites in the body sit at BASE - pivot; the wing turns on a
			# pivot node, which leaves its art where it was drawn.
			out.append([imgs[part], Vector2.ZERO if part == "wing" else BASE - pv[part]])
	if pose == "walk" or (pose == "sit" and r.sit_parts.is_empty()):
		for spec in r.walk_legs:
			if imgs.has(spec[0]):
				out.append([imgs[spec[0]], spec[1] - pv[spec[0]]])
	if r.head_at.has(pose):
		var off: Vector2 = r.head_at[pose] - r.head_pivot
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
