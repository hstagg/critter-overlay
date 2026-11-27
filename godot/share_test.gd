extends SceneTree
## Headless checks for share.gd (docs/custom-critters-build-plan.md, G1, G2):
## builder codes round-trip and refuse damaged, oversized and inflating
## codes; every kind of critter round-trips through a .critter file; a file
## needing a newer app, or changed since it was made, is refused; a v2.0
## file installs as a sticker.
## Run: godot --headless --path godot --script res://share_test.gd

const Share := preload("res://share.gd")
const Customs := preload("res://customs.gd")
const Fixtures := preload("res://critters/kit/fixtures.gd")
const KitData := preload("res://critters/kit/kit_data.gd")

var fails := 0
var checks := 0

const CRITTER := Fixtures.LILAC   # a builder critter, also used by the Admin page


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func code_of(payload: String) -> String:
	var packed := payload.to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	return Share.PREFIX + Marshalls.raw_to_base64(packed).replace("+", "-").replace("/", "_").replace("=", "")


func _init() -> void:
	var root := "user://share_test"
	Share.clear_dir(root)
	Customs.dir = root.path_join("store")
	DirAccess.make_dir_recursive_absolute(Customs.dir)
	Customs.all_ways_on()

	# --- Builder codes.
	var code := Share.encode_code(CRITTER, "Lilac")
	check(code.begins_with("CRIT1-") and code.length() < 1500, "a code is short enough for a chat (%d characters)" % code.length())
	var back := Share.decode_code(code)
	check(back.error == "" and back.name == "Lilac", "a code decodes (%s)" % back.error)
	check(JSON.stringify(back.shapes.layers) == JSON.stringify(preload("res://studio/shape_svg.gd").clean_doc(CRITTER).doc.layers), "to the same shapes")
	check(Share.decode_code("hello").error.contains("CRIT1-"), "not a code: said so")
	check(Share.decode_code("CRIT1-" + "A".repeat(20000)).error.contains("too long"), "an over-long code is refused")
	check(Share.decode_code("CRIT1-!!!!").error != "", "a damaged code is refused")
	var bomb := code_of(JSON.stringify({"n": "x", "s": {"layers": {}, "pad": "0".repeat(4 * 1024 * 1024)}}))
	check(bomb.length() < Share.MAX_CODE, "the bomb fits in a code (%d characters)" % bomb.length())
	check(Share.decode_code(bomb).error.contains("too big") or Share.decode_code(bomb).error.contains("damaged"), "a code that inflates past the cap is refused")
	var silly := code_of(JSON.stringify({"n": "x", "s": {"layers": {"head": [{"t": "ellipse", "x": 99999, "w": -5}], "eyes": [{"t": "nope"}]}}}))
	var ds := Share.decode_code(silly)
	check(ds.error == "" and ds.shapes.layers.head[0].x == 360.0 and not ds.warnings.is_empty(), "bad numbers are brought back and said")
	check(Share.decode_code(code_of(JSON.stringify({"n": "x", "s": {"layers": {"eyes": [{"t": "nope"}]}}}))).error.contains("no shapes"), "a code with nothing usable is refused")

	# --- A builder critter from a code is a kit that loads.
	var built := Share.write_builder_kit(back.shapes, back.name, root.path_join("built"))
	check(built != "", "a code becomes a kit folder")
	var bid := Customs.add_folder(built)
	check(bid != "" and Customs.all[bid]["from"] == "shapes", "and joins the store as a builder critter")

	# --- Every kind through a .critter file.
	Fixtures.kitten_kit(root.path_join("src_kit"))
	Fixtures.pixel_cat(root.path_join("src_frames"))
	var kid := Customs.add_folder(root.path_join("src_kit"))
	var fid := Customs.add_folder(root.path_join("src_frames"))
	var sticker_pic := Image.create(200, 200, false, Image.FORMAT_RGBA8)
	sticker_pic.fill_rect(Rect2i(40, 40, 120, 140), Color(0.95, 0.7, 0.5))
	var sid := Customs.add("Sticker", [sticker_pic])
	for pair in [["kitten kit", kid], ["builder critter", bid], ["frame critter", fid], ["sticker", sid]]:
		var file := root.path_join(pair[0].replace(" ", "_") + ".critter")
		var e := Share.export_critter(pair[1], ProjectSettings.globalize_path(file), "3.1.1", {"author": "Tester", "licence": "CC BY"})
		check(e == "", "%s exports (%s)" % [pair[0], e])
		var st := Share.stage_install(ProjectSettings.globalize_path(file), "3.1.1", root.path_join("staging"))
		check(st.error == "" and st.name == Customs.all[pair[1]]["name"] and st.meta.author == "Tester", "%s stages with its name and author (%s)" % [pair[0], st.error])
		var nid := Share.install(st)
		check(nid != "" and nid != pair[1] and Customs.kind(Customs.all[nid]) == Customs.kind(Customs.all[pair[1]]), "%s installs as a new critter of its kind" % pair[0])
		if nid != "" and Customs.kind(Customs.all[nid]) == "kit":
			var a := KitData.drawn(str(Customs.all[pair[1]]["_dir"]), Customs.all[pair[1]]["_kit"])
			var b := KitData.drawn(str(Customs.all[nid]["_dir"]), Customs.all[nid]["_kit"])
			a.sort()
			b.sort()
			check(a == b, "%s comes back with the same parts" % pair[0])
		check(not DirAccess.dir_exists_absolute(root.path_join("staging")), "nothing is left in staging")

	# --- Refusals.
	var kfile := ProjectSettings.globalize_path(root.path_join("kitten_kit.critter"))
	Share.export_critter(kid, kfile, "9.0.0")
	check(Share.stage_install(kfile, "3.1.1", root.path_join("staging")).error.contains("9.0.0"), "a file needing a newer app says which")
	var files := Raster_files(kfile)
	files["parts/head.svg"] = '<svg xmlns="http://www.w3.org/2000/svg"><circle r="1"/></svg>'.to_utf8_buffer()
	var tampered := ProjectSettings.globalize_path(root.path_join("tampered.critter"))
	zip_of(tampered, files)
	check(Share.stage_install(tampered, "9.9.9", root.path_join("staging")).error.contains("changed"), "a file changed since it was made is refused")

	# --- A v2.0 file installs as a sticker.
	var v2 := {"meta.json": JSON.stringify({"schema_version": 2, "name": "Old friend", "frame_count": 1, "import_method": "static_png"}).to_utf8_buffer(),
		"manifest.json": JSON.stringify({"content_hash": "x", "app_min_version": "2.0.0"}).to_utf8_buffer()}
	var pic := Image.create(120, 120, false, Image.FORMAT_RGBA8)
	pic.fill_rect(Rect2i(20, 20, 80, 90), Color(0.5, 0.6, 0.9))
	v2["frames/frame_0.png"] = pic.save_png_to_buffer()
	var v2file := ProjectSettings.globalize_path(root.path_join("old.critter"))
	zip_of(v2file, v2)
	var sv := Share.stage_install(v2file, "3.1.1", root.path_join("staging"))
	check(sv.error == "" and sv.v2, "a v2.0 file is recognised (%s)" % sv.error)
	var vid := Share.install(sv)
	check(vid != "" and Customs.kind(Customs.all[vid]) == "sticker" and Customs.all[vid]["name"] == "Old friend", "and installs as a sticker")

	Customs.ways.clear()
	Share.clear_dir(root)
	print("SHARE TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)


func Raster_files(path: String) -> Dictionary:
	return preload("res://raster_kit.gd").zip_files(path).files


func zip_of(path: String, files: Dictionary) -> void:
	var zw := ZIPPacker.new()
	zw.open(path)
	for n in files:
		zw.start_file(n)
		zw.write_file(files[n])
		zw.close_file()
	zw.close()
