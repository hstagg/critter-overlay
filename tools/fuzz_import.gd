extends SceneTree
## Hostile-file pass (docs/custom-critters-build-plan.md, G3; P10): mutated
## fixtures thrown at every importer. Not shipped.
##
##   godot --headless --path godot --script <abs path>/tools/fuzz_import.gd [-- N]
##
## For each importer, N cases (default 2000) of a good fixture truncated,
## with bytes flipped, with sizes inflated, or with entries renamed. A case
## passes if it returns (an error is fine) within MAX_S. Any SCRIPT ERROR the
## engine prints is a finding too: grep the output for it. Ends with
## "FUZZ: <cases> cases, <slow> slow, peak <MB> MB".

const Clean := preload("res://svg_clean.gd")
const Raster := preload("res://raster_kit.gd")
const Gif := preload("res://gif.gd")
const Apng := preload("res://apng.gd")
const Frames := preload("res://frames_import.gd")
const Share := preload("res://share.gd")

const MAX_S := 5.0

var rng := RandomNumberGenerator.new()
var slow := 0
var cases := 0
var peak := 0.0
var dir := ""


func _init() -> void:
	rng.seed = 20261124
	var n := 2000
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			n = int(a)
	dir = ProjectSettings.globalize_path("user://fuzz")
	DirAccess.make_dir_recursive_absolute(dir)
	var svg := FileAccess.get_file_as_string("res://templates/side-1.svg").to_utf8_buffer()
	var png := _png()
	var gif := _gif()
	var zip := _zip({"walk-body.png": png, "head.png": png})
	var code := Share.encode_code({"plan": "side", "layers": {"head": [{"t": "ellipse", "x": 100, "y": 100}]}}, "Fuzz").to_utf8_buffer()
	var importers := [
		["svg clean", svg, func(b: PackedByteArray): Clean.split(Clean.text_of(b))],
		["png header + decode", png, func(b: PackedByteArray): _write("p/walk-body.png", b); Raster.read(dir.path_join("p"))],
		["zip of parts", zip, func(b: PackedByteArray): _write("z.zip", b); Raster.read(dir.path_join("z.zip"))],
		["gif", gif, func(b: PackedByteArray): Gif.decode(b)],
		["apng", png, func(b: PackedByteArray): Apng.decode(b)],
		["frames from a gif", gif, func(b: PackedByteArray): _write("walk.gif", b); Frames.stage(dir.path_join("walk.gif"))],
		["builder code", code, func(b: PackedByteArray): Share.decode_code(Clean.text_of(b))],
		[".critter install", zip, func(b: PackedByteArray): _write("x.critter", b); Share.stage_install(dir.path_join("x.critter"), "3.1.1", dir.path_join("stage"))],
	]
	for imp in importers:
		var t0 := Time.get_ticks_msec()
		for i in n:
			var b := _mutate(imp[1])
			var t := Time.get_ticks_usec()
			imp[2].call(b)
			var s := (Time.get_ticks_usec() - t) / 1e6
			cases += 1
			if s > MAX_S:
				slow += 1
				print("SLOW %s case %d: %.1f s" % [imp[0], i, s])
				_write("slow/%s-%d.bin" % [str(imp[0]).replace(" ", "_"), i], b)   # kept to look into
			peak = maxf(peak, OS.get_static_memory_usage() / 1048576.0)
		print("%-22s %d cases in %.1f s" % [imp[0], n, (Time.get_ticks_msec() - t0) / 1000.0])
	print("FUZZ: %d cases, %d slow, peak %.0f MB" % [cases, slow, peak])
	quit(0 if slow == 0 and peak < 1024.0 else 1)


func _mutate(src: PackedByteArray) -> PackedByteArray:
	var b := src.duplicate()
	match rng.randi() % 5:
		0:   # truncated
			b = b.slice(0, rng.randi_range(0, b.size()))
		1:   # bytes flipped
			for k in rng.randi_range(1, 12):
				if b.size() > 0:
					b[rng.randi() % b.size()] = rng.randi() % 256
		2:   # a size or count field inflated
			for k in rng.randi_range(1, 4):
				if b.size() > 8:
					var at := rng.randi() % (b.size() - 4)
					for j in 4:
						b[at + j] = 0xFF if rng.randf() < 0.5 else 0x7F
		3:   # a run of junk inserted
			var junk := PackedByteArray()
			junk.resize(rng.randi_range(1, 4096))
			for j in junk.size():
				junk[j] = rng.randi() % 256
			var at := rng.randi() % maxi(1, b.size())
			b = b.slice(0, at) + junk + b.slice(at)
		4:   # renamed: a dot, a slash or two dots dropped in
			for k in rng.randi_range(1, 6):
				if b.size() > 0:
					b[rng.randi() % b.size()] = [46, 47, 92, 0][rng.randi() % 4]
	return b


func _write(rel: String, b: PackedByteArray) -> void:
	var p := dir.path_join(rel)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()


func _png() -> PackedByteArray:
	var img := Image.create(300, 280, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(100, 150, 100, 100), Color(0.9, 0.6, 0.3))
	return img.save_png_to_buffer()


func _gif() -> PackedByteArray:
	# Two 8 x 8 frames, literal LZW codes.
	var b := "GIF89a".to_ascii_buffer()
	b.append_array(PackedByteArray([8, 0, 8, 0, 0x81, 0, 0, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255]))
	for f in 2:
		b.append_array(PackedByteArray([0x21, 0xF9, 4, 4, 10, 0, 0, 0, 0x2C, 0, 0, 0, 0, 8, 0, 8, 0, 0, 2]))
		var codes := [4]
		for i in 64:
			codes.append(1 + f)
			if i % 2 == 1:
				codes.append(4)
		codes.append(5)
		var data := PackedByteArray()
		var acc := 0
		var bits := 0
		for c in codes:
			acc |= c << bits
			bits += 3
			while bits >= 8:
				data.append(acc & 255)
				acc >>= 8
				bits -= 8
		if bits > 0:
			data.append(acc & 255)
		b.append(data.size())
		b.append_array(data)
		b.append(0)
	b.append(0x3B)
	return b


func _zip(files: Dictionary) -> PackedByteArray:
	var p := dir.path_join("seed.zip")
	var zw := ZIPPacker.new()
	zw.open(p)
	for n in files:
		zw.start_file(n)
		zw.write_file(files[n])
		zw.close_file()
	zw.close()
	return FileAccess.get_file_as_bytes(p)
