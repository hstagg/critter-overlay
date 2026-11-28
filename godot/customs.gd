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
##
## Schema 2 (docs/custom-critters-build-plan.md, 5.1) adds "kind" (sticker,
## kit or frames; none means sticker, so 3.1 stores load unchanged) and "rev",
## bumped whenever the art changes, so texture caches keyed by tex_key() never
## show a stale picture. Kits and frame critters never write image.png, which
## is how 3.1.x skips them rather than showing them broken. Each kind but
## stickers waits behind its way's switch in `ways` (plan P20) until the
## release that ships it. Textures of homemade critters are counted (acquire,
## release) and freed by sweep() once none has drawn them for RELEASE_AFTER s.

const Species := preload("res://species.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")
const STILL := "res://critters/still.gd"   # loaded, not preloaded: still.gd preloads this file

const SCHEMA := 2
const KINDS := ["sticker", "kit", "frames"]
# The rig for each kit plan (plan 4.1-4.4) and for frame critters. A critter
# whose rig isn't in this build is skipped with a log line.
const RIGS := {"side": "res://critters/kit/side.gd", "front": "res://critters/kit/front.gd",
	"upright": "res://critters/kit/upright.gd", "blob": "res://critters/kit/blob.gd",
	"frames": "res://critters/kit/frames.gd"}
const WAYS := ["kit", "shapes", "frames", "share"]
const RELEASE_AFTER := 60.0     # s with none drawn before its textures are freed

# What each behaviour needs of a kit (plan 4.6). "parts": all of these drawn;
# "any": one of these; "plans": only these body plans; "gaits": only these
# gaits; "legged": a plan with legs. A kit's idles are those it meets. The
# moves only one species can draw (ball_up, head_tuck, chitter, belly_roll,
# panda_roll, prance, snuffle) are never offered.
const NEEDS := {
	"sit_and_look": {"parts": ["head", "eyes"]},
	"look_at_cursor": {"parts": ["head", "eyes"]},
	"wake_up": {"parts": ["head", "eyes"]},
	"listen": {"parts": ["head", "eyes"]},
	"nap": {},
	"shake_off": {},
	"stretch": {"legged": true},
	"yawn": {"parts": ["mouth-open"]},
	"sneeze": {"parts": ["mouth-open"]},
	"ear_flick": {"any": ["ear-l", "ear-r", "tuft"]},
	"tail_swish": {"parts": ["tail"]},
	"chase_tail": {"parts": ["tail"], "plans": ["side"]},
	"nose_twitch": {"parts": ["nose"]},
	"stand_lookout": {"parts": ["stand-body"]},
	"groom": {"any": ["groom-paws", "wing-l"]},   # upright: the duckling's fluff-up
	"scratch": {"parts": ["scratch-foot"]},
	"preen": {"parts": ["mouth-open"], "plans": ["upright"]},
	"peck_ground": {"parts": ["mouth-open"], "plans": ["upright"]},
	"hunt": {"plans": ["side"], "gaits": ["trot"]},
}
const MAX_SIDE := 512            # px, the longest side of a stored picture
const MAX_FILE := 15 * 1024 * 1024
const MAX_SOURCE_SIDE := 4096
const MAX_FRAMES := 16
const EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const MAX_SOUND_BYTES := 500 * 1024
const MAX_SOUND_S := 2.0
const SOUNDS := ["kitten", "rabbit", "duck", "hedgehog", "turtle", "squirrel", "otter", "panda"]
const IDLES := ["sit_and_look", "nap", "wake_up", "look_at_cursor", "shake_off"]
const PREVIEW := "custom:_preview"   # the importer's picture before it is kept; never arrives
const STAGED := "custom:_staged"     # a critter from someone, shown before it is installed; never arrives

static var dir := "user://custom"
static var all := {}             # "custom:<id>" -> its custom.json, plus "_dir"
static var _frames := {}         # tex_key() -> Array[ImageTexture], loaded on first spawn
static var ways := {}            # way (WAYS) -> true when it is on in this build
static var _refs := {}           # "custom:<id>" -> how many critters draw it now
static var _sounds := {}         # "custom:<id>" -> its own AudioStream, loaded on first play
static var _idle := {}           # "custom:<id>" -> when the last one stopped (s)


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
		if typeof(d) != TYPE_DICTIONARY:
			printerr("CUSTOM skipped ", folder)
			continue
		d["_dir"] = folder
		_read_extras(d)
		var why := _unusable(d)
		if why != "":
			printerr("CUSTOM skipped ", folder, ": ", why)
			continue
		var id := "custom:" + name
		all[id] = d
		Species.custom[id] = _row(d)


static func _read_extras(d: Dictionary) -> void:
	# A kit's kit.json, a frame critter's clips.json (each its own file).
	var files := {"kit": ["kit.json", "_kit"], "frames": ["clips.json", "_clips"]}
	if files.has(kind(d)):
		var f: Array = files[kind(d)]
		var path := str(d["_dir"]).path_join(f[0])
		var j = JSON.parse_string(_read(path)) if FileAccess.file_exists(path) and FileAccess.open(path, FileAccess.READ).get_length() <= 256 * 1024 else null
		d[f[1]] = j if typeof(j) == TYPE_DICTIONARY else {}


static func kind(d: Dictionary) -> String:
	return str(d.get("kind", "sticker"))


static func way(d: Dictionary) -> String:
	# Which switch a critter waits behind: "" for stickers, which have shipped.
	match kind(d):
		"kit":
			return "shapes" if str(d.get("from", "")) == "shapes" else "kit"
		"frames":
			return "frames"
	return ""


static func badge(d: Dictionary) -> String:
	# How it was made, in the words used everywhere (A0): Shapes, Drawn,
	# Animated or Picture.
	match kind(d):
		"kit":
			return "Shapes" if str(d.get("from", "")) == "shapes" else "Drawn"
		"frames":
			return "Animated"
	return "Picture"


static func way_on(w: String) -> bool:
	return w == "" or bool(ways.get(w, false))


static func all_ways_on() -> void:
	# The admin build and --studio: every way not yet released is on.
	for w in WAYS:
		ways[w] = true


static func _unusable(d: Dictionary) -> String:
	# Why a stored critter can't come out in this build, or "".
	var k := kind(d)
	if not k in KINDS:
		return "unknown kind " + k
	if k == "sticker":
		return "" if FileAccess.file_exists(str(d["_dir"]).path_join("image.png")) else "no image.png"
	if not way_on(way(d)):
		return "%s isn't on in this build" % way(d)
	var rig := rig_path(d)
	if rig == "" or not ResourceLoader.exists(rig):
		return "no rig for %s" % str(d.get("_kit", d).get("plan", k))
	if k == "kit":
		var lacking := KitData.missing(str(d["_dir"]), d.get("_kit", {}))
		if not lacking.is_empty():
			return "missing " + ", ".join(lacking)
	if k == "frames":
		return FrameData.missing(str(d["_dir"]), d.get("_clips", {}))
	return ""


static func rig_path(d: Dictionary) -> String:
	# The script that draws it: still.gd, a kit plan's rig or the frame rig.
	match kind(d):
		"sticker":
			return STILL
		"frames":
			return RIGS["frames"]
	return RIGS.get(str(d.get("_kit", d).get("plan", "")), "")


static func _row(d: Dictionary) -> Dictionary:
	# What species.gd answers for this critter.
	var pop := []
	for c in d.get("pop", []):
		pop.append(Color(str(c)))
	if pop.is_empty():
		pop = [Color8(240, 190, 140), Color8(255, 220, 180), Color8(250, 160, 170)]
	var sound: String = d.get("sound", "kitten")
	if sound == "own" and own_sound_path(d) != "":
		sound = "custom:" + str(d["_dir"]).get_file()   # main.gd plays it through sound_stream()
	var idles := IDLES
	var gait := "a bob and a lean"
	if kind(d) == "kit":
		var k: Dictionary = d.get("_kit", {})
		idles = idles_for(k, KitData.drawn(str(d["_dir"]), k))
		gait = str(k.get("gait", "trot")).replace("_", " ")
	elif kind(d) == "frames":
		# Its own frames: a nap (its nap or sit clip) and each act-* clip.
		idles = ["nap"]
		for c in FrameData.clip_names(d.get("_clips", {}).get("clips", {})):
			if c.begins_with("act-"):
				idles.append("clip:" + c.trim_prefix("act-"))
		gait = "its own frames"
	return {"gait": gait, "script": load(rig_path(d)), "sound": sound if sound in SOUNDS or is_custom(sound) else "kitten",
		"pop": pop, "idles": idles, "rarity_max": "common", "special": false, "custom": true,
		"name": str(d.get("name", "Homemade critter"))}


static func idles_for(kit: Dictionary, parts: Array) -> Array:
	# The behaviours a kit meets the needs of (NEEDS).
	var pl := KitData.plan(kit)
	if str(kit.get("plan", "")) == "blob":
		parts = parts + ["head"]   # a blob's eyes do the head's looking (4.6)
	var out := []
	for b in NEEDS:
		var n: Dictionary = NEEDS[b]
		if n.has("plans") and not str(kit.get("plan", "")) in n.plans:
			continue
		if n.has("gaits") and not str(kit.get("gait", "trot")) in n.gaits:
			continue
		if n.get("legged", false) and not pl.get("legged", false):
			continue
		if not n.get("parts", []).all(func(x): return x in parts):
			continue
		if n.has("any") and not n.any.any(func(x): return x in parts):
			continue
		out.append(b)
	return out


static func is_custom(id: String) -> bool:
	return id.begins_with("custom:")


static func ids(enabled_only := false) -> Array:
	return all.keys().filter(func(id): return id != PREVIEW and id != STAGED and (not enabled_only or bool(all[id].get("enabled", true))))


static func set_preview(img: Image, faces := "right", size := 1.0) -> void:
	# The importer's live preview: drawn by still.gd like a kept one, but held
	# in memory only. Each new picture is a new rev, so no view shows the last.
	var tex := ImageTexture.create_from_image(img)
	var rev := int(all.get(PREVIEW, {}).get("rev", 0)) + 1
	_forget(PREVIEW)
	all[PREVIEW] = {"name": "Preview", "faces": faces, "size": size, "frames": 0, "_dir": "", "rev": rev}
	_frames[tex_key(PREVIEW)] = [tex]
	Species.custom[PREVIEW] = _row(all[PREVIEW])


static func show_staged(folder: String) -> String:
	# A staged critter (share.gd stage_install) drawn like a kept one, so the
	# install dialog can show it walking. Returns STAGED, or "" if it can't.
	clear_staged()
	var d = JSON.parse_string(_read(folder.path_join("custom.json"))) if FileAccess.file_exists(folder.path_join("custom.json")) else null
	if typeof(d) != TYPE_DICTIONARY:
		return ""
	d["_dir"] = folder
	d["rev"] = int(Time.get_ticks_msec())   # a new texture key each time
	_read_extras(d)
	if _unusable(d) != "":
		return ""
	all[STAGED] = d
	Species.custom[STAGED] = _row(d)
	return STAGED


static func clear_staged() -> void:
	_forget(STAGED)
	all.erase(STAGED)
	Species.custom.erase(STAGED)


static func clear_preview() -> void:
	_forget(PREVIEW)
	all.erase(PREVIEW)
	Species.custom.erase(PREVIEW)


static func tex_key(id: String) -> String:
	# The texture cache key, which changes whenever the critter's art does.
	return "%s@%d" % [id, int(all.get(id, {}).get("rev", 0))]


static func bump_rev(id: String) -> void:
	# After its art changed: new textures the next time it is drawn.
	_forget(id)
	all[id]["rev"] = int(all[id].get("rev", 0)) + 1
	save(id)


static func thumb(id: String) -> String:
	# The card picture's path: thumb.png, or a 3.1 sticker's picture.
	var folder: String = all[id]["_dir"]
	var t := folder.path_join("thumb.png")
	return t if FileAccess.file_exists(t) else folder.path_join("image.png")


static func make_thumb(img: Image, folder: String) -> void:
	# A card picture no more than 128 px a side.
	var t: Image = img.duplicate()
	var k := minf(1.0, 128.0 / maxf(t.get_width(), t.get_height()))
	if k < 1.0:
		t.resize(maxi(1, roundi(t.get_width() * k)), maxi(1, roundi(t.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	t.save_png(folder.path_join("thumb.png"))


# --- Its own sound (plan B5) ----------------------------------------------------

static func own_sound_path(d: Dictionary) -> String:
	for ext in ["wav", "ogg"]:
		var p := str(d.get("_dir", "")).path_join("sound." + ext)
		if FileAccess.file_exists(p):
			return p
	return ""


static func _decode_sound(path: String) -> AudioStream:
	match path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
	return null


static func check_sound(path: String) -> String:
	# Why a sound file can't be used, or "" if it can.
	if not path.get_extension().to_lower() in ["wav", "ogg"]:
		return "Use a WAV or OGG sound."
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "That file can't be opened."
	if f.get_length() > MAX_SOUND_BYTES:
		return "That sound is over 500 KB."
	f.close()
	var st := _decode_sound(path)
	if st == null:
		return "That sound can't be read."
	if st.get_length() > MAX_SOUND_S + 0.05:
		return "Keep it to 2 seconds (that one is %.1f)." % st.get_length()
	return ""


static func set_sound(id: String, path: String) -> String:
	# Gives a critter its own sound from a WAV or OGG. A WAV is decoded and
	# written again (nothing but the samples is kept); an OGG is kept as it
	# is once it has decoded, since Godot can't write one. Returns why not,
	# or "".
	var why := check_sound(path)
	if why != "":
		return why
	var d: Dictionary = all[id]
	var old := own_sound_path(d)
	if old != "":
		DirAccess.remove_absolute(old)
	var dest := str(d["_dir"]).path_join("sound." + path.get_extension().to_lower())
	if dest.ends_with(".wav"):
		_decode_sound(path).save_to_wav(dest)
	else:
		DirAccess.copy_absolute(path, dest)
	_sounds.erase(id)
	all[id]["sound"] = "own"
	save(id)
	return ""


static func sound_stream(id: String) -> AudioStream:
	# A critter's own sound, or null.
	if _sounds.has(id):
		return _sounds[id]
	if not all.has(id):
		return null
	var p := own_sound_path(all[id])
	var st := _decode_sound(p) if p != "" else null
	_sounds[id] = st
	return st


# --- Textures in use ----------------------------------------------------------

static func acquire(id: String) -> void:
	# A critter or a preview has started drawing it.
	_refs[id] = int(_refs.get(id, 0)) + 1
	_idle.erase(id)


static func release(id: String, now: float) -> void:
	if not _refs.has(id):
		return
	_refs[id] -= 1
	if _refs[id] <= 0:
		_refs.erase(id)
		_idle[id] = now


static func sweep(now: float) -> Array:
	# Frees the textures of each homemade critter none has drawn for
	# RELEASE_AFTER seconds. Returns their ids.
	var gone := []
	for id in _idle.keys():
		if now - float(_idle[id]) >= RELEASE_AFTER:
			_idle.erase(id)
			_forget(id)
			gone.append(id)
	return gone


static func _forget(id: String) -> void:
	# Every rev of its textures, here and in the rigs' cache.
	for k in _frames.keys():
		if k.begins_with(id + "@"):
			_frames.erase(k)
	KitData.forget(id)
	FrameData.forget(id)
	load("res://critters/critter.gd").forget(id)


static func frames(id: String) -> Array:
	# The critter's textures: one for a still, or its v2.0 animation.
	var key := tex_key(id)
	if _frames.has(key):
		return _frames[key]
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
	_frames[key] = out
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
	d.erase("_kit")   # kit.json and clips.json are their own files
	d.erase("_clips")
	var f := FileAccess.open(folder.path_join("custom.json"), FileAccess.WRITE)
	if f == null:
		printerr("CUSTOM can't save ", folder)
		return
	f.store_string(JSON.stringify(d, "\t"))
	Species.custom[id] = _row(all[id])


static func remove(id: String) -> void:
	if not all.has(id):
		return
	_remove_tree(all[id]["_dir"])
	_forget(id)
	all.erase(id)
	Species.custom.erase(id)


static func _remove_tree(folder: String) -> void:
	# A critter's folder and everything in it (frames/, parts/, cache/, clips/).
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub in DirAccess.get_directories_at(folder):
		_remove_tree(folder.path_join(sub))
	for f in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(f))
	DirAccess.remove_absolute(folder)


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
	var key := _new_key(name)
	var folder := dir.path_join(key)
	DirAccess.make_dir_recursive_absolute(folder)
	imgs[0].save_png(folder.path_join("image.png"))
	make_thumb(imgs[0], folder)
	var n := 0
	if imgs.size() > 1:
		DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
		for i in imgs.size():
			imgs[i].save_png(folder.path_join("frames/%d.png" % i))
		n = imgs.size()
	var d := {"schema": SCHEMA, "kind": "sticker", "rev": 1, "name": name.strip_edges().left(40), "made": int(Time.get_unix_time_from_system()),
		"from": "import", "size": 1.0, "speed": 1.0, "visits": 1, "enabled": true, "frames": n,
		"sound": SOUNDS[hash(name) % SOUNDS.size()], "pop": palette(imgs[0]), "seen": {}}
	d.merge(extra, true)
	d["_dir"] = folder
	var id := "custom:" + key
	all[id] = d
	save(id)
	return id


static func _new_key(name: String) -> String:
	# A folder name: the name in lower-case letters and digits, and a random tail.
	var clean := ""
	for ch in name.to_lower().strip_edges():
		clean += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	while clean.contains("--"):
		clean = clean.replace("--", "-")
	clean = clean.trim_prefix("-").trim_suffix("-").left(24)
	if clean == "":
		clean = "critter"
	return "%s-%s" % [clean, "%06x" % (randi() & 0xFFFFFF)]


static func make_copy(id: String) -> String:
	# Make a copy (My critters): the whole folder as a new critter, "<name>
	# copy", met afresh. Returns its id, or "" if it can't be used here.
	if not all.has(id):
		return ""
	var name := (str(all[id].get("name", "My critter")).left(35) + " copy")
	var key := _new_key(name)
	var folder := dir.path_join(key)
	_copy_tree(str(all[id]["_dir"]), folder)
	var d = JSON.parse_string(_read(folder.path_join("custom.json")))
	if typeof(d) != TYPE_DICTIONARY:
		_remove_tree(folder)
		return ""
	d["name"] = name
	d["made"] = int(Time.get_unix_time_from_system())
	d["rev"] = 1
	d["seen"] = {}
	d["_dir"] = folder
	_read_extras(d)
	if _unusable(d) != "":
		_remove_tree(folder)
		return ""
	var nid := "custom:" + key
	all[nid] = d
	save(nid)
	return nid


static func add_folder(src: String) -> String:
	# Copies a whole critter folder (custom.json, kit.json, parts/ ...) into
	# the store as a new critter and loads it. Returns its id, or "" with a
	# log line if it can't be used here. For --kit-dir and the test kits.
	var d = JSON.parse_string(_read(src.path_join("custom.json")))
	if typeof(d) != TYPE_DICTIONARY:
		printerr("CUSTOM no custom.json in ", src)
		return ""
	var key := "%s-%s" % [src.get_file().to_lower().replace("_", "-").left(24), "%06x" % (randi() & 0xFFFFFF)]
	var folder := dir.path_join(key)
	_copy_tree(src, folder)
	d["_dir"] = folder
	_read_extras(d)
	var why := _unusable(d)
	if why != "":
		printerr("CUSTOM can't use ", src, ": ", why)
		_remove_tree(folder)
		return ""
	var id := "custom:" + key
	all[id] = d
	Species.custom[id] = _row(d)
	return id


static func _copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for sub in DirAccess.get_directories_at(from):
		if sub != "cache":
			_copy_tree(from.path_join(sub), to.path_join(sub))
	for f in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(f), to.path_join(f))


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
		# Off until the player switches it on (developer's decision, 2026-10-26).
		var extra := {"from": "v2:" + v2id, "seen": seen, "enabled": false,
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
	# A still from v2.0 is one picture: its original, cut out again if it had
	# a background (static_jpg), since v2.0's 120 px walking frames are small
	# and their bob crops the top; without the original, the second of those
	# frames (no lean or sway). An animated one (a GIF or a frame strip)
	# keeps all its frames.
	var count := clampi(int(meta.get("frame_count", 1)), 1, MAX_FRAMES)
	var frame := func(i): return Image.load_from_file(folder.path_join("frames/frame_%d.png" % i)) \
		if FileAccess.file_exists(folder.path_join("frames/frame_%d.png" % i)) else null
	if not bool(meta.get("procedural_animation", true)) and count > 1:
		return range(count).map(frame).filter(func(i): return i != null)
	var method := str(meta.get("import_method", ""))
	if method in ["static_png", "static_jpg"] and FileAccess.file_exists(folder.path_join("source.png")):
		var src := Image.load_from_file(folder.path_join("source.png"))
		if src != null and not src.is_empty() and src.get_width() <= MAX_SOURCE_SIDE and src.get_height() <= MAX_SOURCE_SIDE:
			src.convert(Image.FORMAT_RGBA8)
			src = fit(src)
			if not has_transparency(src):
				src = remove_background(src)
			return [src]
	var one = frame.call(1 if count > 1 else 0)
	if one == null:
		one = frame.call(0)
	return [one] if one != null else []


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
