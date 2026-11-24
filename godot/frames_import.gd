extends RefCounted
## Frame critters from drawing and animation apps (docs/custom-critters-build-plan.md,
## E2 and P11), the part with no screens: E3's importer shows what stage()
## found and calls write().
##
## stage(path) reads:
##   - a folder (or zip) with a folder of numbered PNGs per clip (walk/0.png ...);
##   - a GIF or an APNG per clip, named by the clip (walk.gif, sit.png ...);
##   - Aseprite's JSON with its sheet PNG: each frame tag is a clip;
##   - stage_sheet(): one sprite sheet cut on a grid, as one clip.
## Clip names are matched loosely (walking, idle, sleep ...); any other name
## is the player's own move, act-<name>.
##
## Every frame is decoded and re-encoded. The whole set is scaled to fit the
## cast's frame (pixel art by whole steps, kept crisp), centred, and each
## clip grounded on its lowest opaque pixel. The warnings are P11's: walk
## frames whose feet jump about, loops that don't close, art cut off at the
## edge.

const Raster := preload("res://raster_kit.gd")
const Gif := preload("res://gif.gd")
const Apng := preload("res://apng.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")

const FRAME := Vector2i(300, 280)
const STORE := 2                     # frames are kept at 2x for detail
const GROUND := 262
const FIT_HEIGHT := 200.0            # units: about the cast's height
const MAX_FRAMES := 64
const NAMES := {
	"walk": "walk", "walking": "walk", "run": "walk", "move": "walk",
	"sit": "sit", "idle": "sit", "stand": "sit", "sitting": "sit",
	"nap": "nap", "sleep": "nap", "sleeping": "nap", "rest": "nap",
	"blink": "blink", "held": "held", "hold": "held", "grab": "held", "dangle": "held",
	"thrown": "thrown", "fall": "thrown", "jump": "thrown", "fly": "thrown",
	"land": "land", "landing": "land", "climb": "climb", "climbing": "climb",
}


static func clip_name(raw: String) -> String:
	var n := raw.get_basename().to_lower().strip_edges().replace(" ", "-").replace("_", "-")
	if n.begins_with("act-"):
		return n
	return NAMES.get(n, "act-" + n)


static func stage(path: String) -> Dictionary:
	# {"clips": {name: [Image]}, "fps": {name: n}, "warnings": [], "error": ""}
	var raw := {}
	var fps := {}
	var ext := path.get_extension().to_lower()
	var err := ""
	if DirAccess.dir_exists_absolute(path):
		err = _from_folder(path, raw, fps)
	elif ext == "zip":
		var z := Raster.zip_files(path)
		if z.error != "":
			return _fail(z.error)
		err = _from_files(z.files, raw, fps)
	elif ext in ["gif", "png", "apng"]:
		err = _animation(path.get_file(), FileAccess.get_file_as_bytes(path), raw, fps)
	elif ext == "json":
		var files := {path.get_file(): FileAccess.get_file_as_bytes(path)}
		var dir := path.get_base_dir()
		for f in DirAccess.get_files_at(dir):
			if f.get_extension().to_lower() == "png":
				files[f] = FileAccess.get_file_as_bytes(dir.path_join(f))
		err = _aseprite(files, raw, fps)
	else:
		return _fail("Use a folder of frames, a GIF, an animated PNG, Aseprite's JSON, or a zip.")
	if err != "":
		return _fail(err)
	return _finish(raw, fps)


static func stage_sheet(path: String, clip: String, cols: int, rows: int, count := 0, fps := 8) -> Dictionary:
	# One clip cut from a sprite sheet on a grid, left to right, top to bottom.
	var bytes := FileAccess.get_file_as_bytes(path)
	var size := Raster.png_size(bytes)
	if size.x < 0 or size.x > Raster.MAX_SIDE or size.y > Raster.MAX_SIDE:
		return _fail("Use a PNG sheet up to 4096 px a side.")
	if cols < 1 or rows < 1 or size.x % cols != 0 or size.y % rows != 0:
		return _fail("A %d x %d sheet doesn't split into %d columns and %d rows evenly." % [size.x, size.y, cols, rows])
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return _fail("That sheet can't be read.")
	img.convert(Image.FORMAT_RGBA8)
	var cell := Vector2i(size.x / cols, size.y / rows)
	var n := mini(count if count > 0 else cols * rows, mini(cols * rows, MAX_FRAMES))
	var frames := []
	for i in n:
		frames.append(img.get_region(Rect2i(Vector2i(i % cols, i / cols) * cell, cell)))
	return _finish({clip_name(clip): frames}, {clip_name(clip): fps})


static func _fail(why: String) -> Dictionary:
	return {"clips": {}, "fps": {}, "warnings": [], "error": why}


static func _from_folder(dir: String, raw: Dictionary, fps: Dictionary) -> String:
	var files := {}
	for f in DirAccess.get_files_at(dir):
		files[f] = FileAccess.get_file_as_bytes(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		for f in DirAccess.get_files_at(dir.path_join(sub)):
			files[sub + "/" + f] = FileAccess.get_file_as_bytes(dir.path_join(sub).path_join(f))
	return _from_files(files, raw, fps)


static func _from_files(files: Dictionary, raw: Dictionary, fps: Dictionary) -> String:
	# Aseprite JSON if there is one; else per-clip folders of numbered PNGs
	# and per-clip animations.
	for n in files:
		if n.get_extension().to_lower() == "json":
			return _aseprite(files, raw, fps)
	var numbered := {}
	for n in files:
		var bits: PackedStringArray = n.split("/")
		if bits.size() >= 2 and n.get_extension().to_lower() == "png" and n.get_file().get_basename().is_valid_int():
			var clip := clip_name(bits[bits.size() - 2])
			if not numbered.has(clip):
				numbered[clip] = {}
			numbered[clip][int(n.get_file().get_basename())] = files[n]
		elif n.get_extension().to_lower() in ["gif", "png", "apng"]:
			var e := _animation(n.get_file(), files[n], raw, fps)
			if e != "":
				return e
	for clip in numbered:
		var keys: Array = numbered[clip].keys()
		keys.sort()
		raw[clip] = []
		for k in keys:
			var bytes: PackedByteArray = numbered[clip][k]
			var s := Raster.png_size(bytes)
			if s.x < 0 or s.x > Raster.MAX_SIDE or s.y > Raster.MAX_SIDE:
				return "%s/%d.png is too big or not a PNG." % [clip, k]
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				img.convert(Image.FORMAT_RGBA8)
				raw[clip].append(img)
	if raw.is_empty():
		return "No frames found. Put each clip's frames in a folder named after it (walk/0.png, walk/1.png ...)."
	return ""


static func _animation(name: String, bytes: PackedByteArray, raw: Dictionary, fps: Dictionary) -> String:
	var d := Gif.decode(bytes) if name.get_extension().to_lower() == "gif" else Apng.decode(bytes)
	if d.error != "":
		return "%s: %s" % [name, d.error]
	var clip := clip_name(name)
	raw[clip] = d.frames
	var total := 0.0
	for x in d.delays:
		total += x
	fps[clip] = clampi(roundi(d.delays.size() / maxf(0.01, total)), 1, 30)
	return ""


static func _aseprite(files: Dictionary, raw: Dictionary, fps: Dictionary) -> String:
	var json_name := ""
	for n in files:
		if n.get_extension().to_lower() == "json":
			json_name = n
	if files[json_name].size() > 256 * 1024:
		return "That JSON is over 256 KB."
	var j = JSON.parse_string(files[json_name].get_string_from_utf8())
	if typeof(j) != TYPE_DICTIONARY or not j.has("frames"):
		return "That JSON isn't an Aseprite sheet."
	var meta: Dictionary = j.get("meta", {})
	var sheet_name := str(meta.get("image", "")).get_file()
	var sheet_bytes = null
	for n in files:
		if n.get_file() == sheet_name or (sheet_bytes == null and n.get_extension().to_lower() == "png"):
			sheet_bytes = files[n]
	if sheet_bytes == null:
		return "The sheet PNG named in the JSON (%s) is missing." % sheet_name
	var s := Raster.png_size(sheet_bytes)
	if s.x < 0 or s.x > Raster.MAX_SIDE or s.y > Raster.MAX_SIDE:
		return "The sheet is too big or not a PNG."
	var sheet := Image.new()
	sheet.load_png_from_buffer(sheet_bytes)
	sheet.convert(Image.FORMAT_RGBA8)
	var list := []
	var fr = j.frames
	if typeof(fr) == TYPE_DICTIONARY:
		for k in fr:
			list.append(fr[k])
	else:
		list = fr
	var cells := []
	var delays := []
	for f in list:
		var r: Dictionary = f.get("frame", {})
		var src: Dictionary = f.get("spriteSourceSize", {"x": 0, "y": 0})
		var full: Dictionary = f.get("sourceSize", {"w": r.get("w", 1), "h": r.get("h", 1)})
		var cell := Image.create(maxi(1, int(full.w)), maxi(1, int(full.h)), false, Image.FORMAT_RGBA8)
		cell.blit_rect(sheet, Rect2i(int(r.get("x", 0)), int(r.get("y", 0)), int(r.get("w", 1)), int(r.get("h", 1))), Vector2i(int(src.get("x", 0)), int(src.get("y", 0))))
		cells.append(cell)
		delays.append(float(f.get("duration", 100)) / 1000.0)
	var tags: Array = meta.get("frameTags", [])
	if tags.is_empty():
		tags = [{"name": "walk", "from": 0, "to": cells.size() - 1}]
	for t in tags:
		var clip := clip_name(str(t.get("name", "walk")))
		var a := clampi(int(t.get("from", 0)), 0, cells.size() - 1)
		var b := clampi(int(t.get("to", a)), a, cells.size() - 1)
		raw[clip] = cells.slice(a, b + 1)
		var total := 0.0
		for i in range(a, b + 1):
			total += delays[i]
		fps[clip] = clampi(roundi((b - a + 1) / maxf(0.01, total)), 1, 30)
	return ""


# --- Fitting and grounding (P11) -----------------------------------------------------------

static func _finish(raw: Dictionary, fps: Dictionary) -> Dictionary:
	var out := {"clips": {}, "fps": {}, "warnings": [], "error": ""}
	if not raw.has("walk"):
		out.error = "There's no walk clip. Name one walk (a walk folder, walk.gif, or a walk tag)."
		return out
	var total := 0
	for c in raw:
		total += raw[c].size()
	if total > MAX_FRAMES:
		out.error = "That's %d frames; %d in all at most." % [total, MAX_FRAMES]
		return out
	# One scale for every clip, from the union of everything drawn.
	var union := Rect2i()
	for c in raw:
		for img in raw[c]:
			var u: Rect2i = img.get_used_rect()
			if u.size.x > 0:
				union = u if union.size.x == 0 else union.merge(u)
			if u.size.x > 0 and (u.position.x == 0 or u.position.y == 0 or u.end.x == img.get_width()):
				if not out.warnings.has("Some frames touch the edge of their picture: the art may be cut off."):
					out.warnings.append("Some frames touch the edge of their picture: the art may be cut off.")
	if union.size.x == 0:
		out.error = "Every frame is empty."
		return out
	var k := minf(FIT_HEIGHT / union.size.y, minf(280.0 * 0.95 / union.size.y, 300.0 * 0.95 / union.size.x))
	var pixel := union.size.y <= 128            # small art: whole steps, nearest pixels
	if pixel:
		k = maxf(1.0, floorf(k))
	for c in raw:
		var frames := []
		var lowest := 0
		var bottoms := []
		for img in raw[c]:
			var b: int = img.get_used_rect().end.y
			lowest = maxi(lowest, b)
			bottoms.append(b)
		for img in raw[c]:
			frames.append(_place(img, k, union, lowest, pixel))
		out.clips[c] = frames
		out.fps[c] = int(fps.get(c, 8))
		if c == "walk" and not bottoms.is_empty():
			var spread: float = (float(bottoms.max()) - float(bottoms.min())) * k
			if spread > 6.0:
				out.warnings.append("The walk frames' feet move up and down by %d px: line them up so it doesn't bounce." % roundi(spread))
		if c == "walk" and frames.size() > 2 and _differ(frames[0], frames[frames.size() - 1]) > 0.35:
			out.warnings.append("The walk's last frame is far from its first: the loop may jump.")
	return out


static func _place(img: Image, k: float, union: Rect2i, lowest: int, pixel: bool) -> Image:
	# Scaled by k, centred on x 150, the clip's lowest pixel on the ground, at 2x.
	var src: Image = img.get_region(Rect2i(union.position.x, union.position.y, union.size.x, maxi(1, lowest - union.position.y)))
	var w := maxi(1, roundi(src.get_width() * k * STORE))
	var h := maxi(1, roundi(src.get_height() * k * STORE))
	src.resize(w, h, Image.INTERPOLATE_NEAREST if pixel else Image.INTERPOLATE_BILINEAR)
	var out := Image.create(FRAME.x * STORE, FRAME.y * STORE, false, Image.FORMAT_RGBA8)
	var at := Vector2i(FRAME.x * STORE / 2 - w / 2, GROUND * STORE - h)
	out.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
	return out


static func _differ(a: Image, b: Image) -> float:
	# The share of sampled pixels whose coverage differs.
	var diff := 0
	var n := 0
	for y in range(0, a.get_height(), 8):
		for x in range(0, a.get_width(), 8):
			n += 1
			if (a.get_pixel(x, y).a > 0.5) != (b.get_pixel(x, y).a > 0.5):
				diff += 1
	var covered := 0
	for y in range(0, a.get_height(), 8):
		for x in range(0, a.get_width(), 8):
			if a.get_pixel(x, y).a > 0.5:
				covered += 1
	return float(diff) / maxf(1.0, covered)


static func write(staged: Dictionary, name: String, dest: String, stride := 100.0) -> String:
	if staged.error != "" or not staged.clips.has("walk"):
		return ""
	var info := {}
	for c in staged.clips:
		DirAccess.make_dir_recursive_absolute(dest.path_join("clips").path_join(c))
		for i in staged.clips[c].size():
			staged.clips[c][i].save_png(dest.path_join("clips/%s/%d.png" % [c, i]))
		info[c] = {"fps": staged.fps.get(c, 8), "loop": not c.begins_with("act-") and c != "blink" and c != "land"}
	_json(dest.path_join("clips.json"), {"schema": 1, "faces": "left", "ground": GROUND, "stride_px": stride, "clips": info})
	_json(dest.path_join("custom.json"), {"schema": 2, "kind": "frames", "rev": 1, "name": name.strip_edges().left(40),
		"made": int(Time.get_unix_time_from_system()), "from": "import", "size": 1.0, "speed": 1.0, "visits": 1,
		"enabled": true, "sound": "kitten", "seen": {}})
	return dest


static func _json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
