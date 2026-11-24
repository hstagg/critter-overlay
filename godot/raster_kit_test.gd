extends SceneTree
## Headless checks for raster_kit.gd (docs/custom-critters-build-plan.md, C3):
## a PNG folder at 2x, a zip, a Krita-style .ora, a trimmed set with
## parts.txt, and the refusals: wrong sizes (with the size it should be),
## a huge picture refused from its header, and hostile zips.
## Run: godot --headless --path godot --script res://raster_kit_test.gd

const Raster := preload("res://raster_kit.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func part_png(k: int, at: Vector2i, size := Vector2i(60, 40)) -> Image:
	var img := Image.create(300 * k, 280 * k, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(at * k, size * k), Color(0.9, 0.6, 0.3))
	return img


func clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		clear_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func zip_of(path: String, files: Dictionary) -> void:
	var zw := ZIPPacker.new()
	zw.open(path)
	for n in files:
		zw.start_file(n)
		zw.write_file(files[n])
		zw.close_file()
	zw.close()


func _init() -> void:
	var root := ProjectSettings.globalize_path("user://raster_test")
	clear_dir(root)
	DirAccess.make_dir_recursive_absolute(root)
	var shapes := {"walk-body": Vector2i(100, 160), "head": Vector2i(60, 100), "eyes": Vector2i(80, 120),
		"Leg Front": Vector2i(110, 220), "leg_back": Vector2i(190, 220)}

	# --- A folder of PNGs at 2x.
	var folder := root.path_join("pngs")
	DirAccess.make_dir_recursive_absolute(folder)
	for n in shapes:
		part_png(2, shapes[n]).save_png(folder.path_join(n + ".png"))
	var r := Raster.read(folder)
	check(r.error == "" and r.scale == 2, "a 2x PNG folder reads (%s)" % r.error)
	for p in ["walk-body", "head", "eyes", "leg-front", "leg-back"]:
		check(r.parts.has(p), "%s is found by its file name" % p)

	# --- The same zipped, in a folder inside the zip.
	var zf := {}
	for n in shapes:
		zf["my kit/" + n + ".png"] = part_png(2, shapes[n]).save_png_to_buffer()
	zip_of(root.path_join("parts.zip"), zf)
	var rz := Raster.read(root.path_join("parts.zip"))
	check(rz.error == "" and rz.parts.size() == 5, "a zip of PNGs reads (%s, %d parts)" % [rz.error, rz.parts.size()])

	# --- A Krita-style .ora: layers at offsets on a 2x canvas.
	var of := {"mimetype": "image/openraster".to_utf8_buffer()}
	var stack := '<?xml version="1.0"?><image w="600" h="560"><stack>'
	var i := 0
	for n in shapes:
		var small := Image.create(120, 80, false, Image.FORMAT_RGBA8)
		small.fill(Color(0.4, 0.7, 0.9))
		of["data/layer%d.png" % i] = small.save_png_to_buffer()
		stack += '<layer name="%s" src="data/layer%d.png" x="%d" y="%d"/>' % [n, i, shapes[n].x * 2, shapes[n].y * 2]
		i += 1
	stack += '<layer name="guide" src="data/guide.png" x="0" y="0"/></stack></image>'
	of["stack.xml"] = stack.to_utf8_buffer()
	zip_of(root.path_join("kit.ora"), of)
	var ro := Raster.read(root.path_join("kit.ora"))
	check(ro.error == "" and ro.scale == 2 and ro.parts.size() == 5, "a .ora reads (%s, %d parts)" % [ro.error, ro.parts.size()])
	if ro.parts.has("head"):
		var used: Rect2i = ro.parts["head"].get_used_rect()
		check(used.position == shapes["head"] * 2 and ro.parts["head"].get_size() == Vector2i(600, 560), "a .ora layer lands at its offset on the full canvas")

	# --- A trimmed set with parts.txt.
	var trim := root.path_join("trimmed")
	DirAccess.make_dir_recursive_absolute(trim)
	var txt := ""
	for n in shapes:
		var small := Image.create(120, 80, false, Image.FORMAT_RGBA8)
		small.fill(Color(0.3, 0.8, 0.4))
		small.save_png(trim.path_join(n + ".png"))
		txt += "%s %d %d\n" % [n + ".png", shapes[n].x * 2, shapes[n].y * 2]
	var f := FileAccess.open(trim.path_join("parts.txt"), FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	var rt := Raster.read(trim)
	check(rt.error == "" and rt.parts.size() == 5, "a trimmed set with parts.txt reads (%s)" % rt.error)
	if rt.parts.has("eyes"):
		check(rt.parts["eyes"].get_used_rect().position == shapes["eyes"] * 2, "and each part is put back at its place")

	# --- Refusals.
	var bad := root.path_join("bad")
	DirAccess.make_dir_recursive_absolute(bad)
	Image.create(512, 512, false, Image.FORMAT_RGBA8).save_png(bad.path_join("walk-body.png"))
	var rb := Raster.read(bad)
	check(rb.error.contains("512 x 512") and rb.error.contains("300 x 280"), "a wrong size is refused with the size it should be (%s)" % rb.error)
	var mixed := root.path_join("mixed")
	DirAccess.make_dir_recursive_absolute(mixed)
	part_png(1, Vector2i(10, 10)).save_png(mixed.path_join("head.png"))
	part_png(2, Vector2i(10, 10)).save_png(mixed.path_join("eyes.png"))
	check(Raster.read(mixed).error.contains("different size"), "mixed sizes are refused")
	# A header claiming 20000 x 20000, with nothing after it: refused unread.
	var huge := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
		0, 0, 0x4E, 0x20, 0, 0, 0x4E, 0x20, 8, 6, 0, 0, 0])
	var hd := root.path_join("huge")
	DirAccess.make_dir_recursive_absolute(hd)
	f = FileAccess.open(hd.path_join("body.png"), FileAccess.WRITE)
	f.store_buffer(huge)
	f.close()
	check(Raster.png_size(huge) == Vector2i(20000, 20000), "the PNG header is read")
	check(Raster.read(hd).error.contains("4096"), "a huge picture is refused from its header")
	# Hostile zips.
	zip_of(root.path_join("evil.zip"), {"../../evil.png": PackedByteArray([1, 2, 3])})
	check(Raster.read(root.path_join("evil.zip")).error.contains("allowed"), "a zip reaching outside its folder is refused")
	var zeros := PackedByteArray()
	zeros.resize(9 * 1024 * 1024)
	zip_of(root.path_join("bomb.zip"), {"walk-body.png": zeros})
	var bomb_size := FileAccess.get_file_as_bytes(root.path_join("bomb.zip")).size()
	check(bomb_size < 200 * 1024 and Raster.read(root.path_join("bomb.zip")).error.contains("8 MB"), "a small zip that unpacks to 9 MB is refused before unpacking (%d bytes)" % bomb_size)
	var crowd := {}
	for n in 301:
		crowd["p%d.png" % n] = PackedByteArray([0])
	zip_of(root.path_join("crowd.zip"), crowd)
	check(Raster.read(root.path_join("crowd.zip")).error.contains("300"), "a zip of 301 files is refused")
	f = FileAccess.open(root.path_join("fake.zip"), FileAccess.WRITE)
	f.store_string("not a zip at all")
	f.close()
	check(Raster.read(root.path_join("fake.zip")).error != "", "a file that isn't a zip is refused")
	check(Raster.read(root.path_join("x.psd")).error != "", "a .psd is refused")

	clear_dir(root)
	print("RASTER KIT TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
