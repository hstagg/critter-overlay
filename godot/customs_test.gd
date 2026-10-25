extends SceneTree
## Headless checks for homemade critters: customs.gd's store, cut-out and
## v2.0 carry-over, the arrival pick, and critters/still.gd moving.
## Run: godot --headless --path godot --script res://customs_test.gd

const Customs := preload("res://customs.gd")
const Species := preload("res://species.gd")
const Updater := preload("res://updater.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


class World extends Node:
	# What critter.gd reads from host.gd's World.
	var floor_y := 300.0
	var left_x := 0.0
	var right_x := 2000.0
	func mouse_local() -> Vector2:
		return Vector2(400, 200)


func blob(w: int, h: int, bg: Color, fg: Color) -> Image:
	# A filled ellipse on a plain background.
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for y in h:
		for x in w:
			var dx := (x - w * 0.5) / (w * 0.35)
			var dy := (y - h * 0.5) / (h * 0.35)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, fg)
	return img


func clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		clear_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func v2_critter(root: String, id: String, meta: Dictionary, frames: int, source := false, source_bg := Color(0, 0, 0, 0)) -> void:
	# A folder as v2.0's importer left it.
	var folder := root.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	for i in frames:
		var img := Image.create(120, 120, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.fill_rect(Rect2i(30, 20 + i, 60, 80), Color(0.8, 0.5, 0.3))   # each frame a little different
		img.save_png(folder.path_join("frames/frame_%d.png" % i))
	if source:
		var src := Image.create(400, 300, false, Image.FORMAT_RGBA8)
		src.fill(source_bg)
		src.fill_rect(Rect2i(100, 50, 200, 200), Color(0.2, 0.6, 0.9))
		src.save_png(folder.path_join("source.png"))
	var f := FileAccess.open(folder.path_join("meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()


func _init() -> void:
	var root := "user://customs_test"
	clear_dir(root)
	Customs.dir = root.path_join("custom")

	# --- The cut-out: the corner colour goes, the middle stays, a soft edge.
	var photo := blob(200, 160, Color(1, 1, 1), Color(0.3, 0.4, 0.9))
	check(not Customs.has_transparency(photo), "a photo on white is not already cut out")
	var cut := Customs.remove_background(photo)
	check(cut.get_pixel(0, 0).a == 0.0 and cut.get_pixel(199, 159).a == 0.0, "the corners are see-through")
	check(cut.get_pixel(100, 80).a == 1.0, "the middle is kept")
	check(Customs.has_transparency(cut), "the cut-out counts as cut out")
	var soft := 0
	for x in 200:
		var a := cut.get_pixel(x, 80).a
		if a > 0.0 and a < 1.0:
			soft += 1
	check(soft == 2, "a one-pixel soft edge each side (got %d)" % soft)
	var noisy := blob(120, 120, Color(0.9, 0.9, 0.9), Color(0.1, 0.1, 0.1))
	noisy.set_pixel(1, 1, Color(0.95, 0.93, 0.92))   # off-white grain inside the tolerance
	check(Customs.remove_background(noisy).get_pixel(1, 1).a == 0.0, "near-background grain goes too")
	check(Customs.remove_background(noisy, 0).get_pixel(1, 1).a > 0.0, "with no tolerance it stays (as a soft edge)")

	# --- Sizes and files.
	var big := Customs.fit(Image.create(2000, 1000, false, Image.FORMAT_RGBA8))
	check(big.get_width() == 512 and big.get_height() == 256, "a big picture is fitted to 512 px (got %dx%d)" % [big.get_width(), big.get_height()])
	check(Customs.trim(cut).get_width() < 200, "trim crops to what is drawn")
	check(Customs.check_file("res://x.gif") != "", "a GIF is refused")
	check(Customs.check_file("res://nothing.png") != "", "a missing file is refused")
	var p := root.path_join("pic.png")
	DirAccess.make_dir_recursive_absolute(root)
	photo.save_png(p)
	check(Customs.check_file(p) == "", "a PNG is accepted")
	check(Customs.load_picture(p) != null, "and loads")
	var jpg := root.path_join("pic.jpg")
	photo.save_jpg(jpg)
	check(Customs.load_picture(jpg) != null, "a JPG loads (re-saved as PNG pixels only)")

	# --- The store round-trips.
	var id := Customs.add("Mr Biscuits!", [cut])
	check(id.begins_with("custom:mr-biscuits-"), "the id comes from the name (got %s)" % id)
	check(Species.custom.has(id), "species.gd answers for it")
	check(Species.row(id)["script"].resource_path.ends_with("still.gd"), "drawn by still.gd")
	check(Species.row(id)["rarity_max"] == "common" and not Species.is_special(id), "outside rarity")
	check(not Species.has(id) and not Species.DATA.has(id), "never in the cast's table")
	check(Species.row(id)["pop"].size() >= 1, "pop colours from the picture")
	Customs.record_visit(id)
	Customs.record_visit(id)
	Customs.load_all()
	check(Customs.all.has(id), "it loads back")
	var d: Dictionary = Customs.all.get(id, {})
	check(d.get("name") == "Mr Biscuits!" and int(d.get("seen", {}).get("count", 0)) == 2, "with its name and visits")
	check(Customs.frames(id).size() == 1, "one picture")
	var stored := Image.load_from_file(str(d.get("_dir", "")).path_join("image.png"))
	check(stored != null and stored.get_width() <= 512, "stored as a PNG within 512 px")
	var junk := Customs.dir.path_join("junk")
	DirAccess.make_dir_recursive_absolute(junk)
	Customs.load_all()
	check(Customs.all.size() == 1, "a folder without custom.json is skipped")

	# --- The importer's preview is drawn but never arrives or lists.
	Customs.set_preview(cut, "left", 1.3)
	check(Species.custom.has(Customs.PREVIEW) and Customs.frames(Customs.PREVIEW).size() == 1, "the preview can be drawn")
	check(not Customs.PREVIEW in Customs.ids(), "but is not listed")
	var prng := RandomNumberGenerator.new()
	var leaked := false
	for i in 200:
		if Customs.pick(0.0, [0.1, 1.0, 3.0, 5.0], prng) == Customs.PREVIEW:
			leaked = true
	check(not leaked, "and never arrives")
	Customs.clear_preview()
	check(not Species.custom.has(Customs.PREVIEW), "cleared")

	# --- The arrival pick.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var visits := [0.1, 1.0, 3.0, 5.0]
	var got := 0
	for i in 4000:
		if Customs.pick(9.0, visits, rng) == id:
			got += 1
	check(got > 280 and got < 520, "one custom at weight 1 against 9 of species: about 10%% (got %d of 4000)" % got)
	check(Customs.pick(0.0, visits, rng) == id, "with no species on, it is the only choice")
	Customs.all[id]["enabled"] = false
	check(Customs.pick(9.0, visits, rng) == "", "switched off, never")
	Customs.all[id]["enabled"] = true
	Customs.all[id]["visits"] = 0
	got = 0
	for i in 4000:
		if Customs.pick(9.0, visits, rng) != "":
			got += 1
	check(got < 120, "Visits 'rarely' is rare (got %d)" % got)
	Customs.all[id]["visits"] = 1

	# --- v2.0 carry-over.
	var v2 := root.path_join("v2")
	v2_critter(v2, "pip-a1b2c3", {"schema_version": 2, "name": "Pip", "frame_count": 4, "import_method": "static_jpg",
		"procedural_animation": true, "size_multiplier": 1.5, "speed_multiplier": 0.8, "sound_profile": "rabbit",
		"trail_palette": [[200, 100, 50], [250, 200, 150]]}, 4)
	v2_critter(v2, "wiggle-d4e5f6", {"schema_version": 2, "name": "Wiggle", "frame_count": 4,
		"import_method": "animated_gif", "procedural_animation": false}, 4)
	v2_critter(v2, "clean-0a0b0c", {"schema_version": 2, "name": "Clean", "frame_count": 4,
		"import_method": "static_png", "procedural_animation": true}, 4, true)
	v2_critter(v2, "photo-333333", {"schema_version": 2, "name": "Photo", "frame_count": 4, "import_method": "static_jpg",
		"procedural_animation": true}, 4, true, Color(1, 1, 1))     # its original still has its white background
	v2_critter(v2, "old-111111", {"name": "Old one"}, 1)          # schema 1: only a name
	v2_critter(v2, "broken-222222", {"name": "Broken"}, 0)        # no picture at all
	DirAccess.make_dir_recursive_absolute(v2.path_join("not-a-critter"))
	var seen := {"custom:pip-a1b2c3": {"common": 3, "rare": 1}}
	var came := Customs.carry_over(v2, seen)
	check(came == 5, "five of six v2.0 critters come over (got %d)" % came)
	var by_name := {}
	for k in Customs.all:
		by_name[Customs.all[k]["name"]] = k
	check(by_name.has("Pip") and by_name.has("Wiggle") and by_name.has("Clean") and by_name.has("Old one"), "by name")
	check(not by_name.has("Broken"), "the broken one is skipped")
	if by_name.has("Pip"):
		var pip: Dictionary = Customs.all[by_name["Pip"]]
		check(pip["from"] == "v2:pip-a1b2c3", "it remembers where it came from")
		check(pip["enabled"] == false, "and waits switched off until the player turns it on")
		check(is_equal_approx(pip["size"], 1.5) and is_equal_approx(pip["speed"], 0.8), "size and speed come over")
		check(pip["sound"] == "rabbit", "and its sound")
		check(int(pip["seen"].get("count", 0)) == 4, "and its sightings from v2.0's Seen Log")
		check(int(pip["frames"]) == 0, "a v2.0 still is one picture")
		check(pip["pop"].size() == 2, "its v2.0 colours")
		var pic := Image.load_from_file(str(pip["_dir"]).path_join("image.png"))
		check(pic != null and pic.get_height() == 80, "the unleaned frame, trimmed (got %d px tall)" % (pic.get_height() if pic else -1))
	if by_name.has("Wiggle"):
		check(int(Customs.all[by_name["Wiggle"]]["frames"]) == 4, "a v2.0 animation keeps its frames")
		check(Customs.frames(by_name["Wiggle"]).size() == 4, "and loads them")
	if by_name.has("Clean"):
		var clean := Image.load_from_file(str(Customs.all[by_name["Clean"]]["_dir"]).path_join("image.png"))
		check(clean != null and clean.get_width() == 200, "a cut-out PNG uses its original, trimmed (got %d px wide)" % (clean.get_width() if clean else -1))
	if by_name.has("Photo"):
		var ph := Image.load_from_file(str(Customs.all[by_name["Photo"]]["_dir"]).path_join("image.png"))
		check(ph != null and ph.get_width() == 200 and ph.get_height() == 200, "a photo's original is cut out again, not the 120 px frame (got %s)" % (str(ph.get_size()) if ph else "none"))
	check(Customs.carry_over(v2, seen) == 0, "each comes over once")
	check(FileAccess.file_exists(v2.path_join("pip-a1b2c3/meta.json")), "v2.0's files are left alone")

	# --- A still critter moves.
	var world := World.new()
	root_add(world)
	for k in [id, by_name.get("Wiggle", id)]:
		var c = Species.row(k)["script"].new()
		c.species = k
		c.idles = Species.row(k)["idles"]
		world.add_child(c)
		c.setup(world, 500.0, 1, "walk")
		var x0: float = c.position.x
		for i in 90:
			c.tick(1.0 / 30.0)
		check(absf(c.position.x - x0) > 5.0, "%s walks (moved %.0f px)" % [k, c.position.x - x0])
		check(c.region_rect().size.x > 10.0 and c.hit_rect().size.y > 10.0, "it has a size on screen")
		c._go_loaf(5.0)
		c.tick(0.1)
		check(c.is_napping(), "it naps")
		c.vx = 0.0
		c.start_behaviour("shake_off", 0.8)
		for i in 10:
			c.tick(1.0 / 30.0)
		check(c.act == "shake_off", "it shakes off")
		c.wear(["bow"])
		c.queue_free()

	# --- The beta's version as shown, and as the updater compares it.
	check(Updater.version_name("3.0.90") == "3.1 beta 1" and Updater.version_name("3.0.91") == "3.1 beta 2", "3.0.90 shows as 3.1 beta 1")
	check(Updater.version_name("3.0.1") == "3.0.1", "a normal version shows as it is")
	check(not Updater.newer("3.0.1", "3.0.90") and Updater.newer("3.1.0", "3.0.90"), "a beta copy skips 3.0.x patches and takes 3.1.0")

	Customs.remove(id)
	check(not Customs.all.has(id) and not Species.custom.has(id), "remove takes it out")
	check(not DirAccess.dir_exists_absolute(str(d.get("_dir", ""))), "and deletes its folder")
	clear_dir(root)
	print("CUSTOMS TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)


func root_add(n: Node) -> void:
	get_root().add_child(n)
