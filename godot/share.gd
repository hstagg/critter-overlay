extends RefCounted
## Sharing homemade critters (docs/custom-critters-build-plan.md, 5.5, G1,
## G2; P10, P24), the part with no screens.
##
## Builder codes: "CRIT1-" + base64url(deflate(JSON of the shapes and the
## name)). Pasting one inflates it with a cap, validates every number
## (shape_svg.gd clean_doc) and writes the app's own SVGs from them: nothing
## in a code is ever read as SVG.
##
## .critter v3 files: a zip of manifest.json (schema 3, kind, plan, app_min,
## a hash of the contents), meta.json (name, author, licence, made_with,
## ai_made), the kind's own files and thumb.png. Installing puts every file
## through the same path as a fresh import (svg_clean.gd, re-encoded
## pictures, validated JSON) into a staging folder; nothing reaches the
## store until install(). v2.0's .critter files install as stickers, as the
## 3.1 carry-over does.

const Customs := preload("res://customs.gd")
const Writer := preload("res://studio/shape_svg.gd")
const Clean := preload("res://svg_clean.gd")
const Raster := preload("res://raster_kit.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")
const Updater := preload("res://updater.gd")

const PREFIX := "CRIT1-"
const MAX_CODE := 16 * 1024          # characters
const MAX_INFLATED := 64 * 1024      # bytes
const SCHEMA := 3


# --- Builder codes (G1) --------------------------------------------------------------

static func encode_code(shapes: Dictionary, name: String) -> String:
	var doc: Dictionary = Writer.clean_doc(shapes).doc
	doc.erase("auto")
	var text := JSON.stringify({"n": name.strip_edges().left(24), "s": doc})
	var packed := text.to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	return PREFIX + Marshalls.raw_to_base64(packed).replace("+", "-").replace("/", "_").replace("=", "")


static func decode_code(code: String) -> Dictionary:
	# {"shapes": validated doc, "name": "", "warnings": [], "error": ""}
	var out := {"shapes": {}, "name": "", "warnings": [], "error": ""}
	code = code.strip_edges()
	if not code.begins_with(PREFIX):
		out.error = "That isn't a critter code (they start with CRIT1-)."
		return out
	if code.length() > MAX_CODE:
		out.error = "That code is too long."
		return out
	var b64 := code.substr(PREFIX.length()).replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var packed := Marshalls.base64_to_raw(b64)
	if packed.is_empty():
		out.error = "That code is damaged."
		return out
	# Inflated with a cap: a tiny code that would inflate past it is refused.
	var raw := packed.decompress_dynamic(MAX_INFLATED, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty() or raw.size() >= MAX_INFLATED:
		out.error = "That code is damaged or too big."
		return out
	var j = JSON.parse_string(Clean.text_of(raw))
	if typeof(j) != TYPE_DICTIONARY or typeof(j.get("s")) != TYPE_DICTIONARY:
		out.error = "That code is damaged."
		return out
	var c := Writer.clean_doc(j.s)
	if c.doc.layers.is_empty():
		out.error = "That code has no shapes in it."
		return out
	out.shapes = c.doc
	out.warnings = c.warnings
	out.name = str(j.get("n", "Shared critter")).strip_edges().left(24)
	return out


static func write_builder_kit(shapes: Dictionary, name: String, dest: String, gait := "") -> String:
	# A builder critter's folder from its (validated) shapes: shapes.json,
	# the parts the app writes, kit.json with its pins (the shapes' own, else
	# suggested). Returns dest, or "" if the plan's required parts are missing.
	var doc: Dictionary = Writer.clean_doc(shapes).doc
	var plan: String = doc.plan if KitData.PLANS.has(doc.plan) else "side"
	var parts := Writer.write(doc)
	DirAccess.make_dir_recursive_absolute(dest.path_join("parts"))
	for p in parts:
		var f := FileAccess.open(dest.path_join("parts/%s.svg" % p), FileAccess.WRITE)
		f.store_string(parts[p])
		f.close()
	var pins := preload("res://studio/shapes.gd").suggest_pins(doc.layers)
	pins.merge(doc.pins, true)
	var pl: Dictionary = KitData.PLANS[plan]
	var kit := {"schema": 1, "plan": plan, "gait": gait if gait in pl.gaits else pl.gaits[0], "pins": pins, "made_with": "builder"}
	if not KitData.missing(dest, kit).is_empty():
		return ""
	_json(dest.path_join("shapes.json"), doc)
	_json(dest.path_join("kit.json"), kit)
	_json(dest.path_join("custom.json"), {"schema": 2, "kind": "kit", "rev": 1, "name": name, "from": "shapes",
		"made": int(Time.get_unix_time_from_system()), "size": 1.0, "speed": 1.0, "visits": 1, "enabled": true,
		"sound": "kitten", "seen": {}})
	return dest


# --- .critter v3 files (G2) ----------------------------------------------------------

static func content_hash(files: Dictionary) -> String:
	# SHA-256 over every file but the manifest, in name order.
	var names: Array = files.keys().filter(func(n): return n != "manifest.json")
	names.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for n in names:
		ctx.update(n.to_utf8_buffer())
		ctx.update(files[n])
	return ctx.finish().hex_encode()


static func export_critter(id: String, dest: String, app_version: String, meta := {}) -> String:
	# Writes the .critter file. Returns "" or why not.
	if not Customs.all.has(id):
		return "That critter isn't here."
	var d: Dictionary = Customs.all[id]
	var folder := str(d["_dir"])
	var kind := Customs.kind(d)
	var files := {}
	var add := func(rel: String) -> void:
		var p := folder.path_join(rel)
		if FileAccess.file_exists(p):
			files[rel] = FileAccess.get_file_as_bytes(p)
	match kind:
		"kit":
			add.call("kit.json")
			if FileAccess.file_exists(folder.path_join("shapes.json")):
				add.call("shapes.json")     # the app writes the parts again from these
			else:
				for f in DirAccess.get_files_at(folder.path_join("parts")):
					add.call("parts/" + f)
		"frames":
			add.call("clips.json")
			for c in DirAccess.get_directories_at(folder.path_join("clips")):
				for f in DirAccess.get_files_at(folder.path_join("clips").path_join(c)):
					add.call("clips/%s/%s" % [c, f])
		_:
			add.call("image.png")
	add.call("thumb.png")
	var own := Customs.own_sound_path(d)
	if own != "":
		add.call(own.get_file())
	var m := {"name": str(d.get("name", "Critter")), "author": str(meta.get("author", "")).left(40),
		"licence": str(meta.get("licence", "")).left(40), "made_with": str(d.get("_kit", {}).get("made_with", kind)),
		"ai_made": bool(meta.get("ai_made", false))}
	files["meta.json"] = JSON.stringify(m, "\t").to_utf8_buffer()
	var manifest := {"schema": SCHEMA, "kind": kind, "plan": str(d.get("_kit", {}).get("plan", "")),
		"app_min": app_version, "hash": content_hash(files)}
	files["manifest.json"] = JSON.stringify(manifest, "\t").to_utf8_buffer()
	var zw := ZIPPacker.new()
	if zw.open(dest) != OK:
		return "That file can't be written."
	for n in files:
		zw.start_file(n)
		zw.write_file(files[n])
		zw.close_file()
	zw.close()
	return ""


static func stage_install(path: String, app_version: String, staging: String) -> Dictionary:
	# Reads a .critter file into a staging folder through the import paths.
	# {"name", "meta", "kind", "error", "warnings", "folder", "v2": bool}
	var out := {"name": "", "meta": {}, "kind": "", "error": "", "warnings": [], "folder": "", "v2": false}
	var z := Raster.zip_files(path)
	if z.error != "":
		out.error = z.error
		return out
	var files: Dictionary = z.files
	var meta = _small_json(files.get("meta.json", PackedByteArray()))
	var manifest = _small_json(files.get("manifest.json", PackedByteArray()))
	if typeof(meta) != TYPE_DICTIONARY:
		out.error = "That isn't a critter file."
		return out
	out.meta = {"author": str(meta.get("author", "")).left(40), "licence": str(meta.get("licence", meta.get("license", ""))).left(40),
		"ai_made": bool(meta.get("ai_made", false))}
	out.name = str(meta.get("name", "Shared critter")).strip_edges().left(40)
	if int(meta.get("schema_version", 0)) == 2 or (typeof(manifest) == TYPE_DICTIONARY and manifest.has("app_min_version")):
		return _stage_v2(files, meta, staging, out)
	if typeof(manifest) != TYPE_DICTIONARY or int(manifest.get("schema", 0)) != SCHEMA:
		out.error = "That critter file is from a version this app doesn't know."
		return out
	var app_min := str(manifest.get("app_min", "0.0.0"))
	if Updater.newer(app_min, app_version):
		out.error = "That critter needs Critter Overlay %s or newer. Update, then try again." % app_min
		return out
	if str(manifest.get("hash", "")) != content_hash(files):
		out.error = "That critter file has been changed or damaged since it was made."
		return out
	out.kind = str(manifest.get("kind", ""))
	clear_dir(staging)
	DirAccess.make_dir_recursive_absolute(staging)
	var err := ""
	match out.kind:
		"kit":
			err = _stage_kit(files, staging, out)
		"frames":
			err = _stage_frames(files, staging)
		"sticker":
			err = _stage_png(files.get("image.png", PackedByteArray()), staging.path_join("image.png"), 4096)
		_:
			err = "That critter file has a kind this app doesn't know."
	if err == "":
		err = _stage_sound(files, staging)
	if err != "":
		out.error = err
		clear_dir(staging)
		return out
	if files.has("thumb.png"):
		_stage_png(files["thumb.png"], staging.path_join("thumb.png"), 512)
	_json(staging.path_join("custom.json"), {"schema": 2, "kind": out.kind, "rev": 1, "name": out.name,
		"from": "file", "made": int(Time.get_unix_time_from_system()), "size": 1.0, "speed": 1.0, "visits": 1,
		"enabled": true, "sound": "own" if Customs.own_sound_path({"_dir": staging}) != "" else "kitten", "seen": {},
		"author": out.meta.author, "licence": out.meta.licence, "ai_made": out.meta.ai_made})
	out.folder = staging
	return out


static func install(staged: Dictionary) -> String:
	# Adds a staged critter to the store. Returns its id, or "".
	if staged.error != "" or staged.folder == "":
		return ""
	if staged.v2:
		var before := Customs.ids()
		Customs.carry_over(staged.folder, {})
		var after := Customs.ids().filter(func(i): return not i in before)
		clear_dir(staged.folder)
		return after[0] if not after.is_empty() else ""
	var id := Customs.add_folder(staged.folder)
	clear_dir(staged.folder)
	return id


static func _stage_kit(files: Dictionary, staging: String, out: Dictionary) -> String:
	var kit = _small_json(files.get("kit.json", PackedByteArray()))
	if typeof(kit) != TYPE_DICTIONARY or not KitData.PLANS.has(str(kit.get("plan", ""))):
		return "That critter file's kit is damaged."
	if files.has("shapes.json"):
		var shapes = _small_json(files["shapes.json"])
		if typeof(shapes) != TYPE_DICTIONARY:
			return "That critter file's shapes are damaged."
		shapes["plan"] = kit.plan
		if write_builder_kit(shapes, out.name, staging, str(kit.get("gait", ""))) == "":
			return "That critter file's shapes are missing a part."
		out.kind = "kit"
		return ""
	DirAccess.make_dir_recursive_absolute(staging.path_join("parts"))
	var pl: Dictionary = KitData.PLANS[kit.plan]
	for n in files:
		if not n.begins_with("parts/"):
			continue
		var part: String = n.get_file().get_basename()
		if not (part in pl.required or part in pl.optional):
			continue
		match n.get_extension():
			"svg":
				var c := Clean.clean(Clean.text_of(files[n]))
				if c.error != "":
					return "%s: %s" % [part, c.error]
				var f := FileAccess.open(staging.path_join("parts/%s.svg" % part), FileAccess.WRITE)
				f.store_string(c.svg)
				f.close()
				out.warnings.append_array(c.dropped)
			"png":
				var e := _stage_png(files[n], staging.path_join("parts/%s.png" % part), 4096)
				if e != "":
					return e
	var pins := {}
	for k in kit.get("pins", {}):
		var v = kit.pins[k]
		if typeof(v) == TYPE_ARRAY and v.size() >= 2:
			pins[str(k).left(24)] = [clampf(float(v[0]), -60.0, 360.0), clampf(float(v[1]), -60.0, 360.0)]
	var clean_kit := {"schema": 1, "plan": kit.plan, "gait": str(kit.get("gait", pl.gaits[0])) if str(kit.get("gait", "")) in pl.gaits else pl.gaits[0],
		"pins": pins, "made_with": str(kit.get("made_with", "svg")).left(12)}
	if not KitData.missing(staging, clean_kit).is_empty():
		return "That critter file is missing %s." % ", ".join(KitData.missing(staging, clean_kit))
	_json(staging.path_join("kit.json"), clean_kit)
	return ""


static func _stage_frames(files: Dictionary, staging: String) -> String:
	var clips = _small_json(files.get("clips.json", PackedByteArray()))
	if typeof(clips) != TYPE_DICTIONARY:
		return "That critter file's clips are damaged."
	var info := {}
	for c in FrameData.clip_names(clips.get("clips", {})):
		var ci = clips.clips[c]
		info[c] = {"fps": clampf(float(ci.get("fps", 8.0)) if typeof(ci) == TYPE_DICTIONARY else 8.0, 1.0, 30.0),
			"loop": bool(ci.get("loop", true)) if typeof(ci) == TYPE_DICTIONARY else true,
			"loops": clampi(int(ci.get("loops", 1)) if typeof(ci) == TYPE_DICTIONARY else 1, 1, 8)}
		var i := 0
		while files.has("clips/%s/%d.png" % [c, i]) and i < FrameData.MAX_FRAMES:
			DirAccess.make_dir_recursive_absolute(staging.path_join("clips").path_join(c))
			var e := _stage_png(files["clips/%s/%d.png" % [c, i]], staging.path_join("clips/%s/%d.png" % [c, i]), 1200)
			if e != "":
				return e
			i += 1
	_json(staging.path_join("clips.json"), {"schema": 1, "faces": "right" if str(clips.get("faces", "")) == "right" else "left",
		"ground": clampf(float(clips.get("ground", 262.0)), 100.0, 280.0),
		"stride_px": clampf(float(clips.get("stride_px", 100.0)), 10.0, 600.0), "clips": info})
	var why := FrameData.missing(staging, {"clips": info})
	return "That critter file's frames: %s." % why if why != "" else ""


static func _stage_png(bytes: PackedByteArray, dest: String, max_side: int) -> String:
	# Re-encoded: decoded from a checked header, written fresh.
	var s := Raster.png_size(bytes)
	if s.x <= 0 or s.x > max_side or s.y > max_side:
		return "A picture in that file is too big or not a PNG."
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return "A picture in that file can't be read."
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(dest)
	return ""


static func _stage_sound(files: Dictionary, staging: String) -> String:
	for ext in ["wav", "ogg"]:
		if files.has("sound." + ext):
			var tmp := staging.path_join("incoming." + ext)
			var f := FileAccess.open(tmp, FileAccess.WRITE)
			f.store_buffer(files["sound." + ext])
			f.close()
			var why := Customs.check_sound(tmp)
			if why == "":
				if ext == "wav":
					AudioStreamWAV.load_from_file(tmp).save_to_wav(staging.path_join("sound.wav"))
				else:
					DirAccess.copy_absolute(tmp, staging.path_join("sound.ogg"))
			DirAccess.remove_absolute(tmp)
	return ""


static func _stage_v2(files: Dictionary, meta: Dictionary, staging: String, out: Dictionary) -> Dictionary:
	# v2.0's .critter: meta.json and frames/frame_N.png (and source/), laid
	# out as a v2.0 folder for customs.gd carry_over().
	clear_dir(staging)
	var id := "shared-%06x" % (randi() & 0xFFFFFF)
	var folder := staging.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	var clean_meta := {}
	for k in ["schema_version", "name", "frame_count", "import_method", "procedural_animation", "size_multiplier",
			"speed_multiplier", "sound_profile", "trail_palette"]:
		if meta.has(k):
			clean_meta[k] = meta[k]
	_json(folder.path_join("meta.json"), clean_meta)
	for n in files:
		if n.begins_with("frames/frame_") and n.ends_with(".png"):
			var e := _stage_png(files[n], folder.path_join("frames/" + n.get_file()), 4096)
			if e != "":
				out.error = e
				return out
		elif n.begins_with("source/") and n.ends_with(".png") and not FileAccess.file_exists(folder.path_join("source.png")):
			_stage_png(files[n], folder.path_join("source.png"), 4096)
	out.kind = "sticker"
	out.v2 = true
	out.folder = staging
	return out


static func _small_json(bytes: PackedByteArray):
	if bytes.is_empty() or bytes.size() > 256 * 1024:
		return null
	var text := Clean.text_of(bytes)
	return JSON.parse_string(text) if text != "" else null


static func _json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()


static func clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		clear_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
