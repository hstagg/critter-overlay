extends RefCounted
## Animated PNG (docs/custom-critters-build-plan.md, E2, P13): Godot's PNG
## loader reads only the first frame, so the file is split by chunk into
## plain PNGs, one per frame (IHDR at the frame's size, the shared chunks,
## its image data), each decoded and composited onto the canvas with the
## frame's offset, blend and dispose modes.
##
## decode(bytes) -> {"frames": [Image], "delays": [s], "size": Vector2i, "error": ""}
## A plain PNG comes back as one frame.

const MAX_SIDE := 4096
const MAX_FRAMES := 64
const SIG := [137, 80, 78, 71, 13, 10, 26, 10]

static var _crc := PackedInt64Array()


static func crc32(data: PackedByteArray) -> int:
	if _crc.is_empty():
		_crc.resize(256)
		for n in 256:
			var c := n
			for k in 8:
				c = (0xEDB88320 ^ (c >> 1)) if c & 1 else (c >> 1)
			_crc[n] = c
	var c := 0xFFFFFFFF
	for b in data:
		c = _crc[(c ^ b) & 0xFF] ^ (c >> 8)
	return c ^ 0xFFFFFFFF


static func chunk(type: String, data: PackedByteArray) -> PackedByteArray:
	var n := data.size()
	var out := PackedByteArray([(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF])
	var body := type.to_ascii_buffer()
	body.append_array(data)
	out.append_array(body)
	var c := crc32(body)
	out.append_array(PackedByteArray([(c >> 24) & 0xFF, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF]))
	return out


static func _u32(b: PackedByteArray, at: int) -> int:
	return (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3]


static func _u16(b: PackedByteArray, at: int) -> int:
	return (b[at] << 8) | b[at + 1]


static func chunks(bytes: PackedByteArray) -> Array:
	# [[type, data], ...], or [] if not a PNG.
	if bytes.size() < 8 or Array(bytes.slice(0, 8)) != SIG:
		return []
	var out := []
	var at := 8
	while at + 8 <= bytes.size():
		var n := _u32(bytes, at)
		var type := bytes.slice(at + 4, at + 8).get_string_from_ascii()
		if at + 12 + n > bytes.size():
			break
		out.append([type, bytes.slice(at + 8, at + 8 + n)])
		at += 12 + n
		if type == "IEND":
			break
	return out


static func decode(bytes: PackedByteArray) -> Dictionary:
	var out := {"frames": [], "delays": [], "size": Vector2i.ZERO, "error": ""}
	var cs := chunks(bytes)
	if cs.is_empty() or cs[0][0] != "IHDR":
		out.error = "That isn't a PNG."
		return out
	var ihdr: PackedByteArray = cs[0][1]
	if ihdr.size() < 13:
		out.error = "That PNG is damaged."   # G3: a cut-short header
		return out
	var size := Vector2i(_u32(ihdr, 0), _u32(ihdr, 4))
	if size.x <= 0 or size.y <= 0 or size.x > MAX_SIDE or size.y > MAX_SIDE:
		out.error = "That picture is %d x %d: 4096 px a side at most." % [size.x, size.y]
		return out
	out.size = size
	var shared := PackedByteArray()      # PLTE, tRNS, gAMA and the like, before the image data
	var animated := false
	var frames := []                     # {"fc": PackedByteArray, "data": [PackedByteArray]}
	var cur = null
	var default_idat := []
	for c in cs.slice(1):
		match c[0]:
			"acTL":
				animated = true
			"fcTL":
				cur = {"fc": c[1], "data": []}
				frames.append(cur)
			"IDAT":
				# The default image is the first frame when an fcTL comes
				# before it; otherwise it isn't part of the animation.
				if cur != null and frames.size() == 1:
					cur.data.append(c[1])
				else:
					default_idat.append(c[1])
			"fdAT":
				if cur != null:
					cur.data.append(c[1].slice(4))   # less its sequence number
			"IEND":
				pass
			_:
				if frames.is_empty() and default_idat.is_empty():
					shared.append_array(chunk(c[0], c[1]))
	if not animated or frames.is_empty():
		var img := Image.new()
		if img.load_png_from_buffer(bytes) != OK:
			out.error = "That PNG can't be read."
			return out
		img.convert(Image.FORMAT_RGBA8)
		out.frames = [img]
		out.delays = [0.1]
		return out
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for f in frames.slice(0, MAX_FRAMES):
		var fc: PackedByteArray = f.fc
		if fc.size() < 26 or f.data.is_empty():
			continue
		var w := _u32(fc, 4)
		var h := _u32(fc, 8)
		var x := _u32(fc, 12)
		var y := _u32(fc, 16)
		var num := _u16(fc, 20)
		var den := _u16(fc, 22)
		var dispose := fc[24]
		var blend := fc[25]
		if w <= 0 or h <= 0 or x + w > size.x or y + h > size.y:
			out.error = "A frame in that PNG lies outside it."
			return out
		var png := PackedByteArray(SIG)
		var hdr: PackedByteArray = ihdr.duplicate()
		hdr[0] = (w >> 24) & 0xFF
		hdr[1] = (w >> 16) & 0xFF
		hdr[2] = (w >> 8) & 0xFF
		hdr[3] = w & 0xFF
		hdr[4] = (h >> 24) & 0xFF
		hdr[5] = (h >> 16) & 0xFF
		hdr[6] = (h >> 8) & 0xFF
		hdr[7] = h & 0xFF
		png.append_array(chunk("IHDR", hdr))
		png.append_array(shared)
		for d in f.data:
			png.append_array(chunk("IDAT", d))
		png.append_array(chunk("IEND", PackedByteArray()))
		var img := Image.new()
		if img.load_png_from_buffer(png) != OK:
			out.error = "A frame in that PNG can't be read."
			return out
		img.convert(Image.FORMAT_RGBA8)
		var before: Image = canvas.duplicate() if dispose == 2 else null
		if blend == 0:
			canvas.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(x, y))
		else:
			canvas.blend_rect(img, Rect2i(0, 0, w, h), Vector2i(x, y))
		out.frames.append(canvas.duplicate())
		out.delays.append(maxf(0.02, float(num) / float(den if den > 0 else 100)))
		match dispose:
			1:
				canvas.fill_rect(Rect2i(x, y, w, h), Color(0, 0, 0, 0))
			2:
				canvas = before
	return out
