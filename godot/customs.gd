extends RefCounted
## Homemade critters (docs/sticker-critters-beta-plan.md): a picture that
## walks the desktop as one piece, drawn by critters/still.gd.
##
## Each lives in its own folder, user://custom/<id>/ (%APPDATA%\Critter
## Overlay\custom\), holding custom.json (name, size, speed, visits, on/off,
## sightings, where it came from), the cut-out as image.png, and frames/ for
## a v2.0 critter that came with its own animation. settings.json and the
## economy save are not touched (developer's decision, 2026-10-25): homemade
## critters sit outside rarity and the economy, so they keep their own count.
##
## v2.0 kept its custom critters in %APPDATA%\CritterOverlay\custom\<id>\
## (meta.json, frames/frame_N.png, source.png). carry_over() copies each one
## in once; v2.0's files are left as they are.
##
## Pictures are always decoded and re-saved as PNG, no more than MAX_SIDE a
## side, so nothing but pixels is kept (no EXIF or GPS from a photo).

const Species := preload("res://species.gd")
const STILL := "res://critters/still.gd"   # loaded, not preloaded: still.gd preloads this file

const SCHEMA := 1
const MAX_SIDE := 512            # px, the longest side of a stored picture
const MAX_FILE := 15 * 1024 * 1024
const MAX_SOURCE_SIDE := 4096
const MAX_FRAMES := 16
const EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const SOUNDS := ["kitten", "rabbit", "duck", "hedgehog", "turtle", "squirrel", "otter", "panda"]
const IDLES := ["sit_and_look", "nap", "wake_up", "look_at_cursor", "shake_off"]

static var dir := "user://custom"
static var all := {}             # "custom:<id>" -> its custom.json, plus "_dir"
static var _frames := {}         # "custom:<id>" -> Array[ImageTexture], loaded on first spawn


static func v2_dir() -> String:
	return OS.get_environment("APPDATA").path_join("CritterOverlay").path_join("custom")


static func load_all() -> void:
	# Every folder with a custom.json and its picture; broken ones are skipped
	# with a log line rather than stopping the app.
	all.clear()
	_frames.clear()
	Species.custom.clear()
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name in DirAccess.get_directories_at(dir):
		var folder := dir.path_join(name)
		var d = JSON.parse_string(_read(folder.path_join("custom.json"))) if FileAccess.file_exists(folder.path_join("custom.json")) else null
		if typeof(d) != TYPE_DICTIONARY or not FileAccess.file_exists(folder.path_join("image.png")):
			printerr("CUSTOM skipped ", folder)
			continue
		d["_dir"] = folder
		var id := "custom:" + name
		all[id] = d
		Species.custom[id] = _row(d)


static func _row(d: Dictionary) -> Dictionary:
	# What species.gd answers for this critter.
	var pop := []
	for c in d.get("pop", []):
		pop.append(Color(str(c)))
	if pop.is_empty():
		pop = [Color8(240, 190, 140), Color8(255, 220, 180), Color8(250, 160, 170)]
	var sound: String = d.get("sound", "kitten")
	return {"gait": "a bob and a lean", "script": load(STILL), "sound": sound if sound in SOUNDS else "kitten",
		"pop": pop, "idles": IDLES, "rarity_max": "common", "special": false, "custom": true,
		"name": str(d.get("name", "Homemade critter"))}


static func is_custom(id: String) -> bool:
	return id.begins_with("custom:")


static func ids(enabled_only := false) -> Array:
	return all.keys().filter(func(id): return not enabled_only or bool(all[id].get("enabled", true)))


static func frames(id: String) -> Array:
	# The critter's textures: one for a still, or its v2.0 animation.
	if _frames.has(id):
		return _frames[id]
	var out := []
	var folder: String = all[id]["_dir"]
	var n := int(all[id].get("frames", 0))
	var paths := [folder.path_join("image.png")] if n == 0 else range(n).map(func(i): return folder.path_join("frames/%d.png" % i))
	for p in paths:
		var img := Image.load_from_file(p)
		if img == null or img.is_empty():
			continue
		img.generate_mipmaps()
		out.append(ImageTexture.create_from_image(img))
	if out.is_empty():
		printerr("CUSTOM no picture for ", id)
	_frames[id] = out
	return out


# --- Arrivals ---------------------------------------------------------------

static func pick(species_weight: float, visits: Array, rng: RandomNumberGenerator) -> String:
	# Whether a Common arrival is a homemade critter instead, and which. Each
	# switched-on critter counts as one species at its Visits weight (the
	# same steps as Settings > Critters), against the species' total.
	var weights := {}
	var total := 0.0
	for id in ids(true):
		var w := float(visits[clampi(int(all[id].get("visits", 1)), 0, visits.size() - 1)])
		if w > 0.0:
			weights[id] = w
			total += w
	if total <= 0.0:
		return ""
	var r := rng.randf() * (total + species_weight)
	for id in weights:
		r -= weights[id]
		if r <= 0.0:
			return id
	return ""


static func record_visit(id: String) -> void:
	# Its own count, in custom.json: no first find, no berries, no Collection key.
	if not all.has(id):
		return
	var seen: Dictionary = all[id].get("seen", {})
	if not seen.has("first"):
		seen["first"] = int(Time.get_unix_time_from_system())
	seen["count"] = int(seen.get("count", 0)) + 1
	all[id]["seen"] = seen
	save(id)


static func save(id: String) -> void:
	var d: Dictionary = all[id].duplicate()
	var folder: String = d["_dir"]
	d.erase("_dir")
	var f := FileAccess.open(folder.path_join("custom.json"), FileAccess.WRITE)
	if f == null:
		printerr("CUSTOM can't save ", folder)
		return
	f.store_string(JSON.stringify(d, "\t"))
	Species.custom[id] = _row(all[id])


static func remove(id: String) -> void:
	if not all.has(id):
		return
	var folder: String = all[id]["_dir"]
	for sub in ["frames", ""]:
		var p := folder.path_join(sub)
		if DirAccess.dir_exists_absolute(p):
			for f in DirAccess.get_files_at(p):
				DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(folder.path_join("frames"))
	DirAccess.remove_absolute(folder)
	all.erase(id)
	_frames.erase(id)
	Species.custom.erase(id)


# --- Making one ---------------------------------------------------------------

static func check_file(path: String) -> String:
	# Why a file can't be used, or "" if it can.
	if not path.get_extension().to_lower() in EXTENSIONS:
		return "Use a PNG, JPG or WebP picture."
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "That file can't be opened."
	if f.get_length() > MAX_FILE:
		return "That picture is over 15 MB."
	return ""


static func load_picture(path: String) -> Image:
	# The picture as RGBA, or null. A huge one is refused before anything else.
	if check_file(path) != "":
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty() or img.get_width() > MAX_SOURCE_SIDE or img.get_height() > MAX_SOURCE_SIDE:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return fit(img)


static func fit(img: Image) -> Image:
	# No more than MAX_SIDE a side, keeping its shape.
	var w := img.get_width()
	var h := img.get_height()
	var k := minf(1.0, float(MAX_SIDE) / maxf(w, h))
	if k < 1.0:
		img.resize(maxi(1, roundi(w * k)), maxi(1, roundi(h * k)), Image.INTERPOLATE_LANCZOS)
	return img


static func has_transparency(img: Image) -> bool:
	# More than 1% see-through: already cut out (v2.0's test).
	var clear := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a < 0.99:
				clear += 1
	return clear > (w * h / 4) * 0.01


static func remove_background(src: Image, tolerance := 30) -> Image:
	# v2.0's cut-out: the commonest corner colour is the background; flood-fill
	# it from all four corners, within `tolerance` per channel (0 to 255), and
	# make what it reaches see-through. Then a soft one-pixel edge.
	var img: Image = src.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var corners := [img.get_pixel(0, 0), img.get_pixel(w - 1, 0), img.get_pixel(0, h - 1), img.get_pixel(w - 1, h - 1)]
	var bg: Color = corners[0]
	var best := 0
	for c in corners:
		var n: int = corners.filter(func(o): return _near(o, c, 0.02)).size()
		if n > best:
			best = n
			bg = c
	var tol := tolerance / 255.0
	var gone := PackedByteArray()
	gone.resize(w * h)
	var stack := PackedInt32Array([0, w - 1, (h - 1) * w, h * w - 1])
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if gone[i] == 1:
			continue
		var x := i % w
		var y := i / w
		if not _near(img.get_pixel(x, y), bg, tol):
			continue
		gone[i] = 1
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	for y in h:
		for x in w:
			var i := y * w + x
			if gone[i] == 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif (x > 0 and gone[i - 1] == 1) or (x < w - 1 and gone[i + 1] == 1) \
					or (y > 0 and gone[i - w] == 1) or (y < h - 1 and gone[i + w] == 1):
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c, c.a * 0.5))   # the soft edge
	return img


static func _near(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


static func trim(img: Image) -> Image:
	# Cropped to what is drawn.
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	return img.get_region(used)


static func palette(img: Image) -> Array:
	# Three colours for the pop burst: the picture's commonest opaque shades.
	var counts := {}
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(1, int(maxf(w, h) / 48.0))
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			if c.a < 0.9:
				continue
			var k := Color(snappedf(c.r, 0.125), snappedf(c.g, 0.125), snappedf(c.b, 0.125)).to_html(false)
			counts[k] = counts.get(k, 0) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	return keys.slice(0, 3).map(func(k): return "#" + k)


static func add(name: String, pictures: Array, extra := {}) -> String:
	# Stores a new critter from one cut-out (a still) or several (its own
	# animation, from v2.0). Returns its id, "" if nothing was usable.
	var imgs := []
	for p in pictures.slice(0, MAX_FRAMES):
		if p is Image and not p.is_empty():
			imgs.append(fit(p))
	if imgs.is_empty():
		return ""
	if imgs.size() == 1:
		imgs[0] = trim(imgs[0])
	var slug := name.to_lower().strip_edges()
	var clean := ""
	for ch in slug:
		clean += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	while clean.contains("--"):
		clean = clean.replace("--", "-")
	clean = clean.trim_prefix("-").trim_suffix("-").left(24)
	if clean == "":
		clean = "critter"
	var key := "%s-%s" % [clean, "%06x" % (randi() & 0xFFFFFF)]
	var folder := dir.path_join(key)
	DirAccess.make_dir_recursive_absolute(folder)
	imgs[0].save_png(folder.path_join("image.png"))
	var n := 0
	if imgs.size() > 1:
		DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
		for i in imgs.size():
			imgs[i].save_png(folder.path_join("frames/%d.png" % i))
		n = imgs.size()
	var d := {"schema": SCHEMA, "name": name.strip_edges().left(40), "made": int(Time.get_unix_time_from_system()),
		"from": "import", "size": 1.0, "speed": 1.0, "visits": 1, "enabled": true, "frames": n,
		"sound": SOUNDS[hash(name) % SOUNDS.size()], "pop": palette(imgs[0]), "seen": {}}
	d.merge(extra, true)
	d["_dir"] = folder
	var id := "custom:" + key
	all[id] = d
	save(id)
	return id


# --- v2.0 -------------------------------------------------------------------

static func carry_over(from_dir: String, v2_seen: Dictionary) -> int:
	# Copies in each v2.0 critter not already here. Returns how many came.
	if not DirAccess.dir_exists_absolute(from_dir):
		return 0
	var have := {}
	for id in all:
		have[str(all[id].get("from", ""))] = true
	var n := 0
	for v2id in DirAccess.get_directories_at(from_dir):
		if have.has("v2:" + v2id):
			continue
		var folder := from_dir.path_join(v2id)
		if not FileAccess.file_exists(folder.path_join("meta.json")):
			continue
		var meta = JSON.parse_string(_read(folder.path_join("meta.json")))
		if typeof(meta) != TYPE_DICTIONARY:
			continue
		var pics := _v2_pictures(folder, meta)
		if pics.is_empty():
			printerr("CUSTOM v2.0 critter without a picture: ", folder)
			continue
		var seen := {}
		var old = v2_seen.get("custom:" + v2id, null)
		if typeof(old) == TYPE_DICTIONARY:   # v2.0's Seen Log: {tier: count}
			var c := 0
			for v in old.values():
				c += int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0
			seen["count"] = c
		elif typeof(old) in [TYPE_INT, TYPE_FLOAT]:
			seen["count"] = int(old)
		var extra := {"from": "v2:" + v2id, "seen": seen,
			"size": clampf(float(meta.get("size_multiplier", 1.0)), 0.5, 2.0),
			"speed": clampf(float(meta.get("speed_multiplier", 1.0)), 0.5, 2.0)}
		var sound: String = str(meta.get("sound_profile", "")).replace("duckling", "duck")
		if sound in SOUNDS:
			extra["sound"] = sound
		var pal := []
		for c in meta.get("trail_palette", []):
			if typeof(c) == TYPE_ARRAY and c.size() >= 3:
				pal.append(Color8(int(c[0]), int(c[1]), int(c[2])).to_html(false).insert(0, "#"))
		if not pal.is_empty():
			extra["pop"] = pal
		if add(str(meta.get("name", v2id)), pics, extra) != "":
			n += 1
	return n


static func _v2_pictures(folder: String, meta: Dictionary) -> Array:
	# A still from v2.0 is one picture: its original if it was already cut
	# out (static_png), else the second of its four walking frames, which is
	# the cut-out with no lean or sway. An animated one (a GIF or a frame
	# strip) keeps all its frames.
	var count := clampi(int(meta.get("frame_count", 1)), 1, MAX_FRAMES)
	var frame := func(i): return Image.load_from_file(folder.path_join("frames/frame_%d.png" % i)) \
		if FileAccess.file_exists(folder.path_join("frames/frame_%d.png" % i)) else null
	if not bool(meta.get("procedural_animation", true)) and count > 1:
		return range(count).map(frame).filter(func(i): return i != null)
	if str(meta.get("import_method", "")) == "static_png" and FileAccess.file_exists(folder.path_join("source.png")):
		var src := Image.load_from_file(folder.path_join("source.png"))
		if src != null and not src.is_empty() and src.get_width() <= MAX_SOURCE_SIDE and src.get_height() <= MAX_SOURCE_SIDE:
			src.convert(Image.FORMAT_RGBA8)
			return [src]
	var one = frame.call(1 if count > 1 else 0)
	if one == null:
		one = frame.call(0)
	return [one] if one != null else []


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
