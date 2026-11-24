extends SceneTree
## Headless checks for the frame formats (docs/custom-critters-build-plan.md,
## E2): GIFs (disposal 1, 2 and 3, transparency, interlacing), APNGs, numbered
## PNG folders, Aseprite JSON, a sprite sheet and a zip all become clips with
## the right frames; the 64-frame cap holds; an oversized header is refused
## before decoding; P11's warnings fire.
## Run: godot --headless --path godot --script res://frames_import_test.gd

const Gif := preload("res://gif.gd")
const Apng := preload("res://apng.gd")
const Import := preload("res://frames_import.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		clear_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


# --- A small GIF writer, for fixtures --------------------------------------------------

const PAL := [Color8(0, 0, 0), Color8(255, 0, 0), Color8(0, 255, 0), Color8(0, 0, 255)]


func gif(w: int, h: int, frames: Array, interlace := false) -> PackedByteArray:
	# frames: [{"x","y","w","h","px": PackedByteArray of palette indices,
	#  "dispose", "transparent" (-1 none)}]
	var b := "GIF89a".to_ascii_buffer()
	b.append_array(PackedByteArray([w & 255, w >> 8, h & 255, h >> 8, 0xF7, 0, 0]))
	for i in 256:
		var c: Color = PAL[i] if i < PAL.size() else Color(1, 1, 1)
		b.append_array(PackedByteArray([c.r8, c.g8, c.b8]))
	for f in frames:
		var tr: int = f.get("transparent", -1)
		b.append_array(PackedByteArray([0x21, 0xF9, 4, (f.get("dispose", 0) << 2) | (1 if tr >= 0 else 0), 10, 0, maxi(tr, 0), 0]))
		var fw: int = f.w
		var fh: int = f.h
		b.append_array(PackedByteArray([0x2C, f.x & 255, f.x >> 8, f.y & 255, f.y >> 8, fw & 255, fw >> 8, fh & 255, fh >> 8, 0x40 if interlace else 0]))
		var px: PackedByteArray = f.px
		if interlace:
			var rows := []
			for p in [[0, 8], [4, 8], [2, 4], [1, 2]]:
				var y: int = p[0]
				while y < fh:
					rows.append(y)
					y += p[1]
			var re := PackedByteArray()
			for y in rows:
				re.append_array(px.slice(y * fw, y * fw + fw))
			px = re
		b.append(8)
		b.append_array(_blocks(_lzw(px)))
	b.append(0x3B)
	return b


func _lzw(px: PackedByteArray) -> PackedByteArray:
	# Literal codes only, 9 bits, a clear every 254 so the width never grows.
	var codes := [256]
	var n := 0
	for p in px:
		codes.append(p)
		n += 1
		if n == 254:
			codes.append(256)
			n = 0
	codes.append(257)
	var out := PackedByteArray()
	var acc := 0
	var bits := 0
	for c in codes:
		acc |= c << bits
		bits += 9
		while bits >= 8:
			out.append(acc & 255)
			acc >>= 8
			bits -= 8
	if bits > 0:
		out.append(acc & 255)
	return out


func _blocks(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	var at := 0
	while at < data.size():
		var n := mini(255, data.size() - at)
		out.append(n)
		out.append_array(data.slice(at, at + n))
		at += n
	out.append(0)
	return out


func solid(w: int, h: int, idx: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(w * h)
	p.fill(idx)
	return p


# --- A small APNG writer, for fixtures ----------------------------------------------------

func apng(frames: Array, delay_cs := 10) -> PackedByteArray:
	# frames: [Image], all one size; each a full frame (dispose none, blend source).
	var first := Apng.chunks(frames[0].save_png_to_buffer())
	var out := PackedByteArray(Apng.SIG)
	out.append_array(Apng.chunk("IHDR", first[0][1]))
	var actl := PackedByteArray()
	actl.resize(8)
	actl.encode_u32(0, 0)
	actl = PackedByteArray([0, 0, 0, frames.size(), 0, 0, 0, 0])
	out.append_array(Apng.chunk("acTL", actl))
	var seq := 0
	for i in frames.size():
		var img: Image = frames[i]
		var w := img.get_width()
		var h := img.get_height()
		var fc := PackedByteArray([seq >> 24, (seq >> 16) & 255, (seq >> 8) & 255, seq & 255,
			0, 0, w >> 8, w & 255, 0, 0, h >> 8, h & 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, delay_cs, 0, 100, 0, 0])
		out.append_array(Apng.chunk("fcTL", fc))
		seq += 1
		for c in Apng.chunks(img.save_png_to_buffer()):
			if c[0] != "IDAT":
				continue
			if i == 0:
				out.append_array(Apng.chunk("IDAT", c[1]))
			else:
				var fd := PackedByteArray([seq >> 24, (seq >> 16) & 255, (seq >> 8) & 255, seq & 255])
				fd.append_array(c[1])
				out.append_array(Apng.chunk("fdAT", fd))
				seq += 1
	out.append_array(Apng.chunk("IEND", PackedByteArray()))
	return out


func cat(i: int, w := 40, h := 40) -> Image:
	# A small figure whose legs move with i.
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(8, 8, 24, 20), Color(0.9, 0.6, 0.3))
	img.fill_rect(Rect2i(10 + (i % 2) * 2, 28, 4, 10), Color(0.9, 0.6, 0.3))
	img.fill_rect(Rect2i(26 - (i % 2) * 2, 28, 4, 10), Color(0.9, 0.6, 0.3))
	return img


func save_bytes(path: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()


func _init() -> void:
	var root := ProjectSettings.globalize_path("user://frames_import_test")
	clear_dir(root)
	DirAccess.make_dir_recursive_absolute(root)

	# --- GIF: disposal and transparency, pixel by pixel.
	var g := gif(20, 10, [
		{"x": 0, "y": 0, "w": 20, "h": 10, "px": solid(20, 10, 1)},                       # all red
		{"x": 0, "y": 0, "w": 10, "h": 10, "px": solid(10, 10, 2), "dispose": 1},          # left green, kept
		{"x": 10, "y": 0, "w": 10, "h": 10, "px": solid(10, 10, 3), "dispose": 2},         # right blue, then cleared
		{"x": 0, "y": 0, "w": 10, "h": 10, "px": solid(10, 10, 1), "dispose": 3},          # left red, then restored
		{"x": 0, "y": 0, "w": 20, "h": 10, "px": solid(20, 10, 0), "transparent": 0},      # all see-through: no change
	])
	var d := Gif.decode(g)
	check(d.error == "" and d.frames.size() == 5 and d.size == Vector2i(20, 10), "a GIF decodes to its 5 frames (%s, %d)" % [d.error, d.frames.size()])
	if d.frames.size() == 5:
		var px := func(f: int, x: int, y: int) -> Color: return d.frames[f].get_pixel(x, y)
		check(px.call(0, 15, 5).is_equal_approx(Color(1, 0, 0)), "frame 1 is red")
		check(px.call(1, 5, 5).is_equal_approx(Color(0, 1, 0)) and px.call(1, 15, 5).is_equal_approx(Color(1, 0, 0)), "frame 2 draws green over the left")
		check(px.call(2, 15, 5).is_equal_approx(Color(0, 0, 1)) and px.call(2, 5, 5).is_equal_approx(Color(0, 1, 0)), "frame 3 draws blue; disposal 1 kept the green")
		check(px.call(3, 15, 5).a < 0.01 and px.call(3, 5, 5).is_equal_approx(Color(1, 0, 0)), "disposal 2 cleared the blue")
		check(px.call(4, 5, 5).is_equal_approx(Color(0, 1, 0)), "disposal 3 restored the green, and transparency left it showing")
		check(absf(d.delays[0] - 0.1) < 0.001, "delays come through")
	var gi := Gif.decode(gif(8, 16, [{"x": 0, "y": 0, "w": 8, "h": 16, "px": (func() -> PackedByteArray:
		var p := PackedByteArray()
		for y in 16:
			for x in 8:
				p.append(1 if y < 8 else 3)
		return p).call()}], true))
	check(gi.frames.size() == 1 and gi.frames[0].get_pixel(4, 2).is_equal_approx(Color(1, 0, 0)) and gi.frames[0].get_pixel(4, 12).is_equal_approx(Color(0, 0, 1)), "an interlaced GIF comes out in row order")
	var big := gif(9000, 10, [])
	check(Gif.size_of(big) == Vector2i(9000, 10) and Gif.decode(big).error.contains("1280"), "an oversized GIF is refused from its header")
	var many := []
	for i in 70:
		many.append({"x": 0, "y": 0, "w": 4, "h": 4, "px": solid(4, 4, 1 + i % 3)})
	check(Gif.decode(gif(4, 4, many)).frames.size() == 64, "a GIF decodes 64 frames at most")

	# --- APNG.
	var ap := Apng.decode(apng([cat(0), cat(1), cat(2)], 12))
	check(ap.error == "" and ap.frames.size() == 3, "an APNG splits into its 3 frames (%s)" % ap.error)
	if ap.frames.size() == 3:
		check(ap.frames[1].get_pixel(15, 30).a > 0.5 and ap.frames[0].get_pixel(15, 30).a < 0.5, "each frame is its own picture")
		check(absf(ap.delays[0] - 0.12) < 0.001, "APNG delays come through")
	check(Apng.decode(cat(0).save_png_to_buffer()).frames.size() == 1, "a plain PNG is one frame")
	var huge := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	huge.append_array(Apng.chunk("IHDR", PackedByteArray([0, 0, 0x4E, 0x20, 0, 0, 0x4E, 0x20, 8, 6, 0, 0, 0])))
	check(Apng.decode(huge).error.contains("4096"), "an oversized PNG is refused from its header")

	# --- A folder of clips: numbered PNGs, a GIF, an APNG.
	var folder := root.path_join("clips")
	for c in ["walk", "Sleeping"]:
		DirAccess.make_dir_recursive_absolute(folder.path_join(c))
	for i in 4:
		cat(i).save_png(folder.path_join("walk/%d.png" % i))
	for i in 2:
		cat(0).save_png(folder.path_join("Sleeping/%d.png" % i))
	var wave := []
	for i in 6:
		wave.append({"x": 0, "y": 0, "w": 40, "h": 40, "px": solid(40, 40, 1 + i % 3)})
	save_bytes(folder.path_join("wave.gif"), gif(40, 40, wave))
	save_bytes(folder.path_join("idle.png"), apng([cat(0), cat(0)]))
	var st := Import.stage(folder)
	check(st.error == "", "a folder of clips stages (%s)" % st.error)
	check(st.clips.get("walk", []).size() == 4 and st.clips.get("nap", []).size() == 2 and st.clips.get("act-wave", []).size() == 6 and st.clips.get("sit", []).size() == 2,
		"walk, a renamed nap, a GIF move and an APNG sit (%s)" % str(st.clips.keys().map(func(c): return "%s %d" % [c, st.clips[c].size()])))
	var w0: Image = st.clips.walk[0]
	check(w0.get_size() == Vector2i(600, 560), "frames are stored at 2x the frame")
	check(w0.get_used_rect().end.y == Import.GROUND * 2, "the walk stands on the ground line")
	check(absf(w0.get_used_rect().get_center().x - 300.0) <= 8.0, "and is centred")
	check(st.fps.get("act-wave", 0) == 10, "the GIF's speed is kept (%d fps)" % st.fps.get("act-wave", 0))
	var out := Import.write(st, "Clip cat", root.path_join("kit"))
	check(out != "" and FrameData.missing(out, JSON.parse_string(FileAccess.get_file_as_string(out.path_join("clips.json")))) == "", "it writes a frame critter that loads")

	# --- Aseprite: tags become clips.
	var ase := root.path_join("ase")
	DirAccess.make_dir_recursive_absolute(ase)
	var sheet := Image.create(40 * 6, 40, false, Image.FORMAT_RGBA8)
	var frames := []
	for i in 6:
		sheet.blit_rect(cat(i), Rect2i(0, 0, 40, 40), Vector2i(i * 40, 0))
		frames.append({"filename": "cat %d.ase" % i, "frame": {"x": i * 40, "y": 0, "w": 40, "h": 40},
			"spriteSourceSize": {"x": 0, "y": 0, "w": 40, "h": 40}, "sourceSize": {"w": 40, "h": 40}, "duration": 125})
	sheet.save_png(ase.path_join("cat.png"))
	var f := FileAccess.open(ase.path_join("cat.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames": frames, "meta": {"image": "cat.png", "frameTags": [
		{"name": "Walk", "from": 0, "to": 3}, {"name": "Idle", "from": 4, "to": 5}]}}))
	f.close()
	var sa := Import.stage(ase.path_join("cat.json"))
	check(sa.error == "" and sa.clips.get("walk", []).size() == 4 and sa.clips.get("sit", []).size() == 2, "Aseprite tags become clips (%s)" % sa.error)
	check(sa.fps.get("walk", 0) == 8, "at Aseprite's speed (%d fps)" % sa.fps.get("walk", 0))

	# --- A sprite sheet on a grid, and a zip.
	var ss := Import.stage_sheet(ase.path_join("cat.png"), "walk", 6, 1, 4)
	check(ss.error == "" and ss.clips.get("walk", []).size() == 4, "a sheet cuts on its grid (%s)" % ss.error)
	check(Import.stage_sheet(ase.path_join("cat.png"), "walk", 7, 1).error.contains("evenly"), "a grid that doesn't divide is refused")
	var zp := root.path_join("clips.zip")
	var zw := ZIPPacker.new()
	zw.open(zp)
	for i in 4:
		zw.start_file("walk/%d.png" % i)
		zw.write_file(cat(i).save_png_to_buffer())
		zw.close_file()
	zw.close()
	check(Import.stage(zp).clips.get("walk", []).size() == 4, "a zip of clip folders stages")

	# --- Limits and P11's warnings.
	var lots := root.path_join("lots/walk")
	DirAccess.make_dir_recursive_absolute(lots)
	for i in 70:
		cat(i).save_png(lots.path_join("%d.png" % i))
	check(Import.stage(root.path_join("lots")).error.contains("64"), "over 64 frames is refused")
	var bouncy := root.path_join("bouncy/walk")
	DirAccess.make_dir_recursive_absolute(bouncy)
	for i in 4:
		var img := Image.create(40, 60, false, Image.FORMAT_RGBA8)
		img.fill_rect(Rect2i(8, 8 + i * 5, 24, 30), Color(0.9, 0.6, 0.3))
		img.save_png(bouncy.path_join("%d.png" % i))
	var sb := Import.stage(root.path_join("bouncy"))
	check(sb.warnings.any(func(x): return x.contains("feet move")), "feet that jump about are warned of (%s)" % str(sb.warnings))
	check(Import.stage(root.path_join("nothing.txt")).error != "", "an unknown file is refused")
	var nowalk := root.path_join("nowalk/sit")
	DirAccess.make_dir_recursive_absolute(nowalk)
	cat(0).save_png(nowalk.path_join("0.png"))
	check(Import.stage(root.path_join("nowalk")).error.contains("walk"), "no walk clip is refused")

	clear_dir(root)
	print("FRAMES IMPORT TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
