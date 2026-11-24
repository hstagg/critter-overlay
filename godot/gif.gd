extends RefCounted
## A GIF decoder (docs/custom-critters-build-plan.md, E2, P13): Godot reads
## no GIFs, and frame critters drawn in many apps come as one. Frames come
## out composited on the full canvas as each would be shown, honouring
## transparency and the disposal modes (1 keep, 2 clear to nothing,
## 3 restore the previous frame), with interlacing undone.
##
## decode(bytes) -> {"frames": [Image], "delays": [s], "size": Vector2i, "error": ""}
## The screen size is read and refused (over MAX_SIDE) before any decoding,
## and decoding stops at MAX_FRAMES.

const MAX_SIDE := 4096
const MAX_FRAMES := 64


static func size_of(bytes: PackedByteArray) -> Vector2i:
	# From the header alone; (-1, -1) if it isn't a GIF.
	if bytes.size() < 10 or bytes.slice(0, 3).get_string_from_ascii() != "GIF":
		return Vector2i(-1, -1)
	return Vector2i(bytes.decode_u16(6), bytes.decode_u16(8))


static func decode(bytes: PackedByteArray) -> Dictionary:
	var out := {"frames": [], "delays": [], "size": Vector2i.ZERO, "error": ""}
	var size := size_of(bytes)
	if size.x < 0:
		out.error = "That isn't a GIF."
		return out
	if size.x <= 0 or size.y <= 0 or size.x > MAX_SIDE or size.y > MAX_SIDE:
		out.error = "That GIF is %d x %d: 4096 px a side at most." % [size.x, size.y]
		return out
	out.size = size
	var at := 13
	var flags := bytes[10]
	var global := PackedColorArray()
	if flags & 0x80:
		var n := 1 << ((flags & 7) + 1)
		global = _palette(bytes, at, n)
		at += 3 * n
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var gce := {"dispose": 0, "transparent": -1, "delay": 0.1}
	while at < bytes.size() and out.frames.size() < MAX_FRAMES:
		var block := bytes[at]
		at += 1
		match block:
			0x3B:
				break
			0x21:
				var label := bytes[at]
				at += 1
				if label == 0xF9 and at + 5 <= bytes.size():
					var pf := bytes[at + 1]
					gce = {"dispose": (pf >> 2) & 7, "transparent": bytes[at + 4] if pf & 1 else -1,
						"delay": maxf(0.02, bytes.decode_u16(at + 2) / 100.0)}
				at = _skip_blocks(bytes, at)
			0x2C:
				if at + 9 > bytes.size():
					out.error = "That GIF is cut short."
					break
				var x := bytes.decode_u16(at)
				var y := bytes.decode_u16(at + 2)
				var w := bytes.decode_u16(at + 4)
				var h := bytes.decode_u16(at + 6)
				var lf := bytes[at + 8]
				at += 9
				var pal := global
				if lf & 0x80:
					var n := 1 << ((lf & 7) + 1)
					pal = _palette(bytes, at, n)
					at += 3 * n
				if at >= bytes.size():
					out.error = "That GIF is cut short."
					break
				var min_code := bytes[at]
				at += 1
				var data := PackedByteArray()
				while at < bytes.size():
					var len := bytes[at]
					at += 1
					if len == 0:
						break
					data.append_array(bytes.slice(at, at + len))
					at += len
				var idx := _lzw(data, min_code, w * h)
				if lf & 0x40:
					idx = _deinterlace(idx, w, h)
				var before: Image = canvas.duplicate() if gce.dispose == 3 else null
				for py in h:
					for px in w:
						var i := py * w + px
						if i >= idx.size():
							break
						var c := idx[i]
						if c == gce.transparent or c >= pal.size():
							continue
						var cx := x + px
						var cy := y + py
						if cx < size.x and cy < size.y:
							canvas.set_pixel(cx, cy, pal[c])
				out.frames.append(canvas.duplicate())
				out.delays.append(gce.delay)
				match gce.dispose:
					2:
						canvas.fill_rect(Rect2i(x, y, w, h), Color(0, 0, 0, 0))
					3:
						canvas = before
				gce = {"dispose": 0, "transparent": -1, "delay": 0.1}
			_:
				out.error = "That GIF has a block it doesn't know (%d)." % block
				break
	if out.frames.is_empty() and out.error == "":
		out.error = "That GIF has no frames."
	return out


static func _palette(bytes: PackedByteArray, at: int, n: int) -> PackedColorArray:
	var p := PackedColorArray()
	for i in n:
		var j := at + i * 3
		if j + 2 >= bytes.size():
			p.append(Color(0, 0, 0))
		else:
			p.append(Color8(bytes[j], bytes[j + 1], bytes[j + 2]))
	return p


static func _skip_blocks(bytes: PackedByteArray, at: int) -> int:
	while at < bytes.size():
		var len := bytes[at]
		at += 1 + len
		if len == 0:
			break
	return at


static func _lzw(data: PackedByteArray, min_code: int, want: int) -> PackedInt32Array:
	# GIF's LZW: variable-width codes, least significant bit first.
	var out := PackedInt32Array()
	if min_code < 2 or min_code > 8:
		return out
	var clear := 1 << min_code
	var stop := clear + 1
	var width := min_code + 1
	var prefix := PackedInt32Array()
	var suffix := PackedInt32Array()
	var first := PackedInt32Array()
	prefix.resize(4096)
	suffix.resize(4096)
	first.resize(4096)
	for i in clear:
		prefix[i] = -1
		suffix[i] = i
		first[i] = i
	var next := clear + 2
	var old := -1
	var bits := 0
	var acc := 0
	var stack := PackedInt32Array()
	for byte in data:
		acc |= byte << bits
		bits += 8
		while bits >= width:
			var code := acc & ((1 << width) - 1)
			acc >>= width
			bits -= width
			if code == clear:
				width = min_code + 1
				next = clear + 2
				old = -1
				continue
			if code == stop or out.size() >= want:
				return out
			var cur := code
			stack.clear()
			if code >= next:
				if old < 0:
					return out
				stack.append(first[old])
				cur = old
			while cur >= 0 and stack.size() < 4097:
				stack.append(suffix[cur])
				cur = prefix[cur]
			for i in range(stack.size() - 1, -1, -1):
				out.append(stack[i])
			if old >= 0 and next < 4096:
				prefix[next] = old
				suffix[next] = stack[stack.size() - 1]
				first[next] = first[old]
				next += 1
				if next == (1 << width) and width < 12:
					width += 1
			old = code
	return out


static func _deinterlace(idx: PackedInt32Array, w: int, h: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(idx.size())
	var row := 0
	for pass_ in [[0, 8], [4, 8], [2, 4], [1, 2]]:
		var y: int = pass_[0]
		while y < h:
			for x in w:
				if row * w + x < idx.size() and y * w + x < out.size():
					out[y * w + x] = idx[row * w + x]
			row += 1
			y += pass_[1]
	return out
