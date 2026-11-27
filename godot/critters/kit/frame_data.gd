extends RefCounted
## A frame critter's frames (docs/custom-critters-build-plan.md, 5.4, E1,
## P12): every clip's frames packed into one atlas with mipmaps, at the
## rigs' part scale, built the first time it spawns and freed with its other
## textures (customs.gd sweep()).
##
## A frame critter's folder holds clips.json and clips/<clip>/<n>.png, each
## frame drawn in the cast's 300 x 280 frame (up to 4x), facing left, feet on
## y 262 (or clips.json's "ground").

const PART_SCALE := 0.75
const FRAME := Vector2(300, 280)
const ATLAS_MAX := 2048
const MAX_FRAMES := 64
const CLIPS := ["walk", "sit", "nap", "blink", "held", "thrown", "land", "climb"]
const MAX_ACTS := 8

static var _atlases := {}        # tex key -> built


static func forget(id: String) -> void:
	for k in _atlases.keys():
		if k.begins_with(id + "@"):
			_atlases.erase(k)


static func clip_names(clips: Dictionary) -> Array:
	# The clips it may have, in order, act-* ones last (8 at most).
	var out := []
	for c in CLIPS:
		if clips.has(c):
			out.append(c)
	var acts: Array = clips.keys().filter(func(c): return str(c).begins_with("act-"))
	acts.sort()
	return out + acts.slice(0, MAX_ACTS)


static func frame_files(folder: String, clip: String) -> Array:
	var dir := folder.path_join("clips").path_join(clip)
	var out := []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var n := 0
	while FileAccess.file_exists(dir.path_join("%d.png" % n)) and n < MAX_FRAMES:
		out.append(dir.path_join("%d.png" % n))
		n += 1
	return out


# --- Head marks (F3): where its head is, for clothes --------------------------
# clips.json "clips": {"<clip>": {"head": {"<frame>": [cx, cy, r]}}}, in the
# 300 x 280 frame. A clip's marked frames are joined by straight lines; before
# the first and after the last mark the head stays put. A clip with no marks
# shows no clothes, and a critter with none at all can't wear any.

static func head_marks(clips: Dictionary, clip: String) -> Array:
	# [[frame, Vector3(cx, cy, r)], ...] sorted by frame; bad entries skipped.
	var raw = clips.get("clips", {}).get(clip, {}).get("head", {})
	var out := []
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw:
		var v = raw[k]
		if not str(k).is_valid_int() or typeof(v) != TYPE_ARRAY or v.size() != 3:
			continue
		var r := clampf(float(v[2]), 4.0, 200.0)
		out.append([int(k), Vector3(clampf(float(v[0]), 0.0, FRAME.x), clampf(float(v[1]), 0.0, FRAME.y), r)])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


static func head_at(clips: Dictionary, clip: String, frame: int) -> Variant:
	# The head (Vector3 cx, cy, r) on this frame of the clip, or null.
	var m := head_marks(clips, clip)
	if m.is_empty():
		return null
	if frame <= m[0][0]:
		return m[0][1]
	for j in range(1, m.size()):
		if frame <= m[j][0]:
			var t := float(frame - m[j - 1][0]) / float(m[j][0] - m[j - 1][0])
			return (m[j - 1][1] as Vector3).lerp(m[j][1], t)
	return m[-1][1]


static func has_head(clips: Dictionary) -> bool:
	for c in clips.get("clips", {}):
		if not head_marks(clips, c).is_empty():
			return true
	return false


static func missing(folder: String, clips: Dictionary) -> String:
	# Why the clips can't be used, or "".
	if frame_files(folder, "walk").is_empty():
		return "no walk frames"
	var total := 0
	for c in clip_names(clips.get("clips", {})):
		total += frame_files(folder, c).size()
	if total > MAX_FRAMES:
		return "over %d frames" % MAX_FRAMES
	return ""


static func atlas(key: String, folder: String, clips: Dictionary) -> Dictionary:
	if _atlases.has(key):
		return _atlases[key]
	var a := build(folder, clips)
	_atlases[key] = a
	return a


static func build(folder: String, clips: Dictionary) -> Dictionary:
	# {"texture", "regions": {clip: [Rect2]}, "bounds": {clip: Rect2 units},
	#  "fps", "loop", "loops": {clip: ...}, "cell": Vector2i}
	var cell := Vector2i((FRAME * PART_SCALE).round())
	var cols := ATLAS_MAX / cell.x
	var info: Dictionary = clips.get("clips", {})
	var frames := []                  # [clip, Image]
	for c in clip_names(info):
		for p in frame_files(folder, c):
			if frames.size() >= MAX_FRAMES:
				break
			var img := Image.load_from_file(p)
			if img == null or img.is_empty():
				continue
			img.convert(Image.FORMAT_RGBA8)
			if img.get_size() != cell:
				img.generate_mipmaps()
				img.resize(cell.x, cell.y, Image.INTERPOLATE_TRILINEAR)
				img.clear_mipmaps()
			frames.append([c, img])
	var rows := int(ceil(frames.size() / float(cols)))
	var sheet := Image.create(mini(cols, frames.size()) * cell.x, maxi(1, rows) * cell.y, false, Image.FORMAT_RGBA8)
	var out := {"regions": {}, "bounds": {}, "fps": {}, "loop": {}, "loops": {}, "cell": cell}
	for i in frames.size():
		var at := Vector2i(i % cols, i / cols) * cell
		var c: String = frames[i][0]
		var img: Image = frames[i][1]
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		if not out.regions.has(c):
			out.regions[c] = []
			out.bounds[c] = Rect2()
		out.regions[c].append(Rect2(at, cell))
		var used := img.get_used_rect()
		if used.size.x > 0:
			var b := Rect2(Vector2(used.position) / PART_SCALE, Vector2(used.size) / PART_SCALE)
			out.bounds[c] = b if out.bounds[c].size == Vector2.ZERO else out.bounds[c].merge(b)
	for c in out.regions:
		var ci: Dictionary = info.get(c, {}) if typeof(info.get(c)) == TYPE_DICTIONARY else {}
		out.fps[c] = clampf(float(ci.get("fps", 8.0)), 1.0, 30.0)
		out.loop[c] = bool(ci.get("loop", not c.begins_with("act-")))
		out.loops[c] = clampi(int(ci.get("loops", 1)), 1, 8)
	sheet.generate_mipmaps()
	out.texture = ImageTexture.create_from_image(sheet)
	out.size = sheet.get_size()
	return out
