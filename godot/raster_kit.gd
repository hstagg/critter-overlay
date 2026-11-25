extends RefCounted
## Kit parts from raster drawing apps (docs/custom-critters-build-plan.md,
## C3; P9, P10): a folder or a zip of PNGs named by part, Krita's .ora (and
## any app that writes OpenRaster), and trimmed exports with a parts.txt of
## offsets (Photoshop's "export layers to files").
##
## Every picture is the template's frame (300 x 280) at a whole multiple, 1x
## to 4x, or it is refused with the size it should be. Sizes are read from
## the PNG header before anything is decoded, and a zip's directory is read
## before anything is unpacked (P10: entries, sizes, names). Names match as
## SVG layers do (svg_clean.gd normalise).
##
## read(path) -> {"parts": {part: Image}, "scale": k, "unmatched": [], "error": ""}

const Clean := preload("res://svg_clean.gd")

const FRAME := Vector2i(300, 280)
const MAX_SIDE := 4096
const MAX_ENTRIES := 300
const MAX_ENTRY := 8 * 1024 * 1024
const MAX_TOTAL := 40 * 1024 * 1024
const MAX_FILE := 40 * 1024 * 1024


static func read(path: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(path):
		return _from_files(_folder_files(path))
	var ext := path.get_extension().to_lower()
	if not FileAccess.file_exists(path):
		return _fail("That file can't be found.")
	match ext:
		"zip":
			var z := zip_files(path)
			return _fail(z.error) if z.error != "" else _from_files(z.files)
		"ora":
			return read_ora(path)
		"png":
			return _from_files({path.get_file(): FileAccess.get_file_as_bytes(path)})
	return _fail("Use a folder or zip of PNGs, or a Krita .ora file.")


static func _fail(why: String) -> Dictionary:
	return {"parts": {}, "scale": 0, "unmatched": [], "error": why}


# --- Headers, before decoding --------------------------------------------------

static func png_size(bytes: PackedByteArray) -> Vector2i:
	# Width and height from the IHDR chunk; (-1, -1) if not a PNG.
	if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return Vector2i(-1, -1)
	var w := (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19]
	var h := (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23]
	return Vector2i(w, h)


static func safe_name(n: String) -> bool:
	# P10's rule ([A-Za-z0-9._/-], no "..", no leading slash or drive), with
	# spaces allowed too: drawing apps put them in layer file names.
	if n == "" or n.begins_with("/") or n.begins_with("\\") or n.contains("..") or (n.length() > 1 and n[1] == ":"):
		return false
	for ch in n:
		if not ((ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch in "0123456789._/- "):
			return false
	return true


static func zip_entries(path: String) -> Dictionary:
	# The zip's directory, read from the file's own bytes before unpacking:
	# {"entries": [[name, unpacked size]], "error": ""}.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"entries": [], "error": "That file can't be opened."}
	var size := f.get_length()
	if size > MAX_FILE:
		return {"entries": [], "error": "That file is over 40 MB."}
	var tail_len := mini(size, 65557)
	f.seek(size - tail_len)
	var tail := f.get_buffer(tail_len)
	var eocd := -1
	for i in range(tail_len - 22, -1, -1):
		if tail[i] == 0x50 and tail[i + 1] == 0x4b and tail[i + 2] == 0x05 and tail[i + 3] == 0x06:
			eocd = i
			break
	if eocd < 0:
		return {"entries": [], "error": "That isn't a zip file."}
	var count := tail.decode_u16(eocd + 10)
	var cd_size := tail.decode_u32(eocd + 12)
	var cd_off := tail.decode_u32(eocd + 16)
	if count > MAX_ENTRIES:
		return {"entries": [], "error": "That zip has over %d files." % MAX_ENTRIES}
	if cd_off + cd_size > size:
		return {"entries": [], "error": "That zip is damaged."}
	f.seek(cd_off)
	var cd := f.get_buffer(cd_size)
	var out := []
	var at := 0
	var total := 0
	for i in count:
		if at + 46 > cd.size() or cd.decode_u32(at) != 0x02014b50:
			return {"entries": [], "error": "That zip is damaged."}
		var unpacked := cd.decode_u32(at + 24)
		var nlen := cd.decode_u16(at + 28)
		var elen := cd.decode_u16(at + 30)
		var clen := cd.decode_u16(at + 32)
		var name := cd.slice(at + 46, at + 46 + nlen).get_string_from_utf8()
		at += 46 + nlen + elen + clen
		if name.ends_with("/"):
			continue
		if not safe_name(name):
			return {"entries": [], "error": "That zip has a file name that isn't allowed (%s)." % name.left(40)}
		if unpacked > MAX_ENTRY:
			return {"entries": [], "error": "%s is over 8 MB unpacked." % name.get_file()}
		total += unpacked
		if total > MAX_TOTAL:
			return {"entries": [], "error": "That zip is over 40 MB unpacked."}
		out.append([name, unpacked])
	return {"entries": out, "error": ""}


static func zip_files(path: String) -> Dictionary:
	# {"files": {name: bytes}, "error": ""}, after zip_entries says it's safe.
	var e := zip_entries(path)
	if e.error != "":
		return {"files": {}, "error": e.error}
	var z := ZIPReader.new()
	if z.open(path) != OK:
		return {"files": {}, "error": "That zip can't be opened."}
	var files := {}
	for entry in e.entries:
		var b := z.read_file(entry[0])
		if b.size() > MAX_ENTRY:
			z.close()
			return {"files": {}, "error": "%s is bigger than its zip said." % entry[0].get_file()}
		files[entry[0]] = b
	z.close()
	return {"files": files, "error": ""}


static func _folder_files(dir: String) -> Dictionary:
	var files := {}
	for n in DirAccess.get_files_at(dir):
		if n.get_extension().to_lower() in ["png", "txt"]:
			var p := dir.path_join(n)
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null and f.get_length() <= MAX_ENTRY:
				files[n] = f.get_buffer(f.get_length())
	return files


# --- Parts --------------------------------------------------------------------------

static func scale_of(size: Vector2i) -> int:
	# The whole multiple of the frame a picture is, or 0.
	for k in [1, 2, 3, 4]:
		if size == FRAME * k:
			return k
	return 0


static func _from_files(files: Dictionary) -> Dictionary:
	# PNGs named by part. With a parts.txt ("part x y" per line, in px of the
	# frame at the same multiple), each trimmed picture is put back at its place.
	var offsets := {}
	for n in files:
		if n.get_file().to_lower() == "parts.txt":
			for line in files[n].get_string_from_utf8().split("\n"):
				# "<file name> x y": the name may have spaces, so x and y are
				# the last two words.
				var bits: PackedStringArray = str(line).strip_edges().split(" ", false)
				if bits.size() >= 3:
					var name := " ".join(bits.slice(0, bits.size() - 2))
					offsets[Clean.normalise(name.get_basename())] = Vector2i(int(bits[-2]), int(bits[-1]))
	var out := {"parts": {}, "scale": 0, "unmatched": [], "error": ""}
	for n in files:
		if n.get_extension().to_lower() != "png":
			continue
		var bytes: PackedByteArray = files[n]
		var size := png_size(bytes)
		if size.x < 0:
			out.unmatched.append(n.get_file())
			continue
		if size.x > MAX_SIDE or size.y > MAX_SIDE:
			return _fail("%s is %d x %d: pictures can be 4096 px a side at most." % [n.get_file(), size.x, size.y])
		var part := Clean.normalise(n.get_file().get_basename())
		var img := Image.new()
		if img.load_png_from_buffer(bytes) != OK:
			out.unmatched.append(n.get_file())
			continue
		img.convert(Image.FORMAT_RGBA8)
		if offsets.has(part):
			# Trimmed: put it back on a full canvas at the template's multiple.
			var k := _guess_k(files, offsets)
			var full := Image.create(FRAME.x * k, FRAME.y * k, false, Image.FORMAT_RGBA8)
			full.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), offsets[part])
			img = full
			size = img.get_size()
		var k2 := scale_of(size)
		if k2 == 0:
			return _fail("%s is %d x %d. Parts must be the template's size, 300 x 280, or 2x (600 x 560), 3x or 4x." % [n.get_file(), size.x, size.y])
		if out.scale != 0 and k2 != out.scale:
			return _fail("%s is a different size from the other parts. Export them all at the same size." % n.get_file())
		out.scale = k2
		out.parts[part] = img
	if out.parts.is_empty() and out.error == "":
		return _fail("No PNG parts found. Name each picture after its part, like walk-body.png.")
	return out


static func _guess_k(files: Dictionary, offsets: Dictionary) -> int:
	# A trimmed set's multiple: from a part that wasn't trimmed, else 2x
	# (the guide PNG's size).
	for n in files:
		if n.get_extension().to_lower() == "png" and not offsets.has(Clean.normalise(n.get_file().get_basename())):
			var k := scale_of(png_size(files[n]))
			if k > 0:
				return k
	return 2


# --- OpenRaster (.ora: Krita, MyPaint, GIMP with a plug-in) ------------------------------

static func read_ora(path: String) -> Dictionary:
	var z := zip_files(path)
	if z.error != "":
		return _fail(z.error)
	var files: Dictionary = z.files
	if not files.has("stack.xml"):
		return _fail("That .ora file has no layer list (stack.xml).")
	var xml := XMLParser.new()
	if xml.open_buffer(files["stack.xml"]) != OK:
		return _fail("That .ora file's layer list can't be read.")
	var canvas := Vector2i.ZERO
	var layers := []
	while xml.read() == OK:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		match xml.get_node_name():
			"image":
				canvas = Vector2i(int(xml.get_named_attribute_value_safe("w")), int(xml.get_named_attribute_value_safe("h")))
			"layer":
				layers.append({"name": xml.get_named_attribute_value_safe("name"), "src": xml.get_named_attribute_value_safe("src"),
					"x": int(xml.get_named_attribute_value_safe("x")), "y": int(xml.get_named_attribute_value_safe("y")),
					"hidden": xml.get_named_attribute_value_safe("visibility") == "hidden"})
	var k := scale_of(canvas)
	if k == 0:
		return _fail("The canvas is %d x %d. Start from the template: 300 x 280, or 2x (600 x 560), 3x or 4x." % [canvas.x, canvas.y])
	var out := {"parts": {}, "scale": k, "unmatched": [], "error": ""}
	for l in layers:
		var part := Clean.normalise(l.name)
		if part in ["guide", "guides", "background", "pins"]:
			continue
		if not files.has(l.src):
			out.unmatched.append(l.name)
			continue
		var size := png_size(files[l.src])
		if size.x < 0 or size.x > MAX_SIDE or size.y > MAX_SIDE:
			return _fail("The layer %s is too big or not a picture." % l.name)
		var img := Image.new()
		if img.load_png_from_buffer(files[l.src]) != OK:
			out.unmatched.append(l.name)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var full := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
		full.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(l.x, l.y))
		if full.get_used_rect().size.x <= 0:
			continue   # an empty layer: that part isn't drawn
		out.parts[part] = full
	return out
