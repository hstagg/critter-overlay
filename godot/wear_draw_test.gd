extends SceneTree
## Headless checks for clothes drawn at runtime (docs/custom-critters-build-plan.md,
## F2):
## - Parity: for every built-in species in design/wear/build.py's SPECIES
##   and every item build.py writes for it, wear_draw.gd's SVG rasterised
##   matches the shipped art/wear/<item>/<species>.svg rasterised: under 1%
##   of the drawn pixels (those either image draws) differ by more than 8 in
##   alpha. Any item that drifts is printed by name. How many come out as the
##   very same text is printed too.
## - A kitten kit wears a hat drawn from its own head, never a species-only
##   item, a hood hides its ears, a dye recolours it, and the textures go
##   when the kit is forgotten. A faces-you kit's hat moves between faces.
## - The Admin contact sheet renders (when admin.gd is there).
## Run: godot --headless --path godot --script res://wear_draw_test.gd
## With WEAR_DIFF set, every file whose text differs is printed both ways.

const WearDraw := preload("res://wear_draw.gd")
const Wear := preload("res://wear.gd")
const Customs := preload("res://customs.gd")
const Species := preload("res://species.gd")
const Fixtures := preload("res://critters/kit/fixtures.gd")
const Critter := preload("res://critters/critter.gd")

const SCALE := 0.75
const ALPHA_DIFF := 8
const MAX_DIFFERING := 0.01

# design/wear/build.py SPECIES, as written there (ints stay ints).
const SPECIES := {
	"kitten": {"cx": 150, "cy": 122, "rx": 92, "ry": 74, "eye_y": 124, "eye_dx": 38, "eye_r": 18, "chin": 196, "gap": [122, 178], "side": 1.0},
	"rabbit": {"cx": 150, "cy": 142, "rx": 78, "ry": 62, "eye_y": 142, "eye_dx": 28, "eye_r": 16, "chin": 204, "gap": [142, 158], "side": 0.9},
	"duckling": {"cx": 150, "cy": 128, "rx": 72, "ry": 72, "eye_y": 132, "eye_dx": 30, "eye_r": 17, "chin": 200, "gap": [132, 168], "side": 0.85},
	"hedgehog": {"cx": 150, "cy": 136, "rx": 80, "ry": 58, "eye_y": 140, "eye_dx": 28, "eye_r": 12, "chin": 194, "gap": [140, 170], "side": 0.85},
	"turtle": {"cx": 162, "cy": 184, "rx": 52, "ry": 48, "eye_y": 181, "eye_dx": 22, "eye_r": 12, "chin": 232, "gap": [181, 210], "side": 0.8},
	"squirrel": {"cx": 134, "cy": 140, "rx": 70, "ry": 60, "eye_y": 139, "eye_dx": 28, "eye_r": 15, "chin": 194, "gap": [139, 170], "side": 0.9},
	"otter": {"cx": 124, "cy": 128, "rx": 60, "ry": 50, "eye_y": 124, "eye_dx": 25, "eye_r": 15, "chin": 174, "gap": [124, 160], "side": 0.9},
	"panda": {"cx": 150, "cy": 130, "rx": 72, "ry": 60, "eye_y": 127, "eye_dx": 29, "eye_r": 11, "chin": 181, "gap": [127, 166], "side": 1.0},
	"unicorn": {"cx": 150, "cy": 130, "rx": 64, "ry": 56, "eye_y": 132, "eye_dx": 26, "eye_r": 14, "chin": 183, "gap": [132, 168], "side": 0.9},
	"golden_kitten": {"cx": 150, "cy": 122, "rx": 92, "ry": 74, "eye_y": 124, "eye_dx": 38, "eye_r": 18, "chin": 196, "gap": [122, 178], "side": 1.0},
}

var fails := 0
var checks := 0
var world: Node


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


class World extends Node:
	var floor_y := 300.0
	var left_x := 0.0
	var right_x := 2000.0
	func mouse_local() -> Vector2:
		return Vector2(400, 200)


func clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		clear_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func spawn(id: String, mode := "sit"):
	var c = Species.row(id)["script"].new()
	c.species = id
	c.idles = Species.row(id)["idles"]
	world.add_child(c)
	c.setup(world, 600.0, -1, mode)
	return c


static func raster(text: String) -> Image:
	var img := Image.new()
	img.load_svg_from_string(text, SCALE)
	img.convert(Image.FORMAT_RGBA8)
	return img


static func differing(a: Image, b: Image) -> Vector2i:
	# (pixels whose alpha differs by more than ALPHA_DIFF, pixels either draws).
	if a.get_size() != b.get_size():
		return Vector2i(1, 1)
	var da := a.get_data()
	var db := b.get_data()
	if da == db:
		return Vector2i(0, 1)
	var bad := 0
	var drawn := 0
	for i in range(3, da.size(), 4):
		if da[i] > ALPHA_DIFF or db[i] > ALPHA_DIFF:
			drawn += 1
		if absi(da[i] - db[i]) > ALPHA_DIFF:
			bad += 1
	return Vector2i(bad, maxi(drawn, 1))


func numbers() -> void:
	# Numbers written as Python writes them (half to even on the exact value).
	var cases := [[0.25, "{:.1f}", "0.2"], [0.35, "{:.1f}", "0.3"], [0.75, "{:.1f}", "0.8"], [2.5, "{:.0f}", "2"],
		[-0.04, "{:.1f}", "-0.0"], [150, "{:.1f}", "150.0"], [150, "{}", "150"], [150.0, "{}", "150.0"],
		[0.85, "{}", "0.85"], [66.06997637498885, "{}", "66.06997637498885"], [-16.5, "{:.0f}", "-16"]]
	for c in cases:
		check(WearDraw.fmt(c[1], [c[0]]) == c[2], "%s of %s is written %s (got %s)" % [c[1], c[0], c[2], WearDraw.fmt(c[1], [c[0]])])


func parity() -> void:
	numbers()
	for id in Wear.ITEMS:
		check(id in WearDraw.IDS, "wear_draw.gd draws %s" % id)
	check(WearDraw.IDS.size() == Wear.ITEMS.size(), "wear_draw.gd draws the catalogue's items and no others")
	var tried := 0
	var same_text := 0
	var passed := 0
	var drifting := []
	for id in Wear.ITEMS:
		var only := Wear.only(id)
		for sp in SPECIES:
			if only != "" and only != sp:
				continue
			var path := "res://art/wear/%s/%s.svg" % [id, sp]
			check(FileAccess.file_exists(path), "build.py's %s for %s is shipped" % [id, sp])
			if not FileAccess.file_exists(path):
				continue
			tried += 1
			var want := FileAccess.get_file_as_string(path)
			var got := WearDraw.draw(id, SPECIES[sp])
			if got == want:
				same_text += 1
			elif OS.get_environment("WEAR_DIFF") != "":
				print("TEXT: %s/%s
%s
%s" % [id, sp, got, want])
			var d := differing(raster(got), raster(want))
			var share := float(d.x) / d.y
			if share < MAX_DIFFERING:
				passed += 1
			else:
				drifting.append("%s/%s (%.1f%% of drawn pixels)" % [id, sp, 100.0 * share])
	for what in drifting:
		print("DRIFT: ", what)
	check(drifting.is_empty(), "every item draws as build.py's (%d drift)" % drifting.size())
	check(tried == 624, "624 item files checked (%d)" % tried)
	print("PARITY: %d item files, %d match when rasterised, %d drift, %d the same text" % [tried, passed, drifting.size(), same_text])


func kit_wears(src: String) -> void:
	Fixtures.kitten_kit(src.path_join("kitten_side"))
	var kid := Customs.add_folder(src.path_join("kitten_side"))
	check(kid != "", "the kitten kit loads")
	if kid == "":
		return
	var c = spawn(kid)
	check(not c._wear_head().is_empty(), "a kit rig draws its clothes from its own head")
	c.wear(["beanie"])
	check(c._wear_nodes.size() == 1, "the kitten kit wears a beanie")
	if c._wear_nodes.size() == 1:
		var tex: Texture2D = c._wear_nodes[0].texture
		check(tex != null and tex.get_image().get_used_rect().size.x > 20, "the kit's beanie has art")
	# Drawn from the kit's head, it lands about where the kitten's does (F1:
	# the kit's metrics are within 4 units of the kitten's).
	var kit_hat := raster(Wear.svg_for_kit("beanie", c.kit.head))
	var cat_hat := raster(Wear.svg("beanie", "kitten"))
	var d := differing(kit_hat, cat_hat)
	check(float(d.x) / d.y < 0.25, "the kit's beanie sits about where the kitten's does (%.0f%% of pixels differ)" % (100.0 * d.x / d.y))
	# Species-only items are never offered or drawn.
	for id in Wear.ITEMS:
		if Wear.only(id) != "":
			check(not Wear.fits(id, kid) and Wear.svg_for_kit(id, c.kit.head) == "", "a kit is never offered %s (only for %s)" % [id, Wear.only(id)])
	check(Wear.fits("beanie", kid), "a kit is offered the beanie")
	c.wear(["fish_bowtie"])
	check(c._wear_nodes.is_empty(), "a kit can't be dressed in a species-only item")
	# A hood hides the ears; taking it off shows them again.
	c.wear(["frog_hood"])
	check(not c.ears.is_empty() and c.ears.all(func(e): return not e.visible), "a hood hides the kit's ears")
	check(Wear.hides("frog_hood", kid) == Wear.KIT_HOOD_HIDES and Wear.hides("beanie", kid).is_empty(), "only hoods hide parts of a kit")
	c.wear([])
	check(c.ears.all(func(e): return e.visible), "the ears come back when the hood comes off")
	# A dye swaps the main colour, as for the shipped files.
	var dyed := Wear.svg_for_kit("beanie", c.kit.head, "rose")
	check(dyed.contains(Wear.DYES.rose[1]) and not dyed.containsn(Wear.MAINS.beanie), "a dye recolours a kit's beanie")
	c.wear(["beanie"], {"beanie": "rose"})
	var keys := Critter._wear_textures.keys().filter(func(k): return k.begins_with("wear:beanie:") and k.contains(":%s:" % kid))
	check(keys.size() == 2, "a kit's clothes are cached per item and dye (%d beanies)" % keys.size())
	c.wear([])
	c.free()
	Critter.forget(kid)
	keys = Critter._wear_textures.keys().filter(func(k): return k.contains(":%s:" % kid))
	check(keys.is_empty(), "forgetting the kit drops its clothes")
	# The built-in kitten still wears the shipped file.
	var cat = spawn("kitten")
	check(cat._wear_head().is_empty(), "the kitten draws clothes from its shipped files")
	cat.wear(["beanie"])
	check(cat._wear_nodes.size() == 1 and Critter._wear_textures.has("wear:beanie:kitten:"), "the kitten wears the shipped beanie")
	cat.free()


func front_kit_wears(src: String) -> void:
	# A faces-you kit (two_head.gd): the hat moves between faces.
	Fixtures.otter_kit(src.path_join("otter_front"))
	var oid := Customs.add_folder(src.path_join("otter_front"))
	check(oid != "", "the otter kit loads")
	if oid == "":
		return
	var c = spawn(oid)
	c.wear(["frog_hood"])
	check(c._wear_nodes.size() == 1 and c._wear_nodes[0].has_meta("at"), "the otter kit's hood is placed for both faces")
	check(not c.ears.is_empty() and c.ears.all(func(e): return not e.visible), "a hood hides the otter kit's ears")
	c.wear(["party_hat"])
	check(c._wear_nodes.size() == 1 and c._wear_nodes[0].has_meta("at"), "the otter kit wears a party hat on both faces")
	c.free()


func contact_sheet() -> void:
	# The Admin contact sheet (admin.gd, admin build only) renders: every
	# kit item on four heads. Whether they fit is for the developer to judge.
	if not ResourceLoader.exists("res://admin.gd"):
		return
	var Admin = load("res://admin.gd")
	var img: Image = Admin.contact_sheet()
	var n: int = Admin.kit_items().size()
	check(n == Wear.ITEMS.keys().filter(func(i): return Wear.only(i) == "").size(), "the sheet has every item that isn't one species' own (%d)" % n)
	check(img.get_width() > 2000 and img.get_height() > 160 * ceili(n / 5.0), "the contact sheet renders (%dx%d)" % [img.get_width(), img.get_height()])
	var used: Image = img.duplicate()
	used.convert(Image.FORMAT_L8)
	var dark := 0
	var data: PackedByteArray = used.get_data()
	for i in range(0, data.size(), 97):
		if data[i] < 128:
			dark += 1
	check(dark > 1000, "the contact sheet has drawing on it")


func _init() -> void:
	parity()
	contact_sheet()
	world = World.new()
	get_root().add_child(world)
	var root := "user://wear_draw_test"
	clear_dir(root)
	Customs.dir = root.path_join("store")
	DirAccess.make_dir_recursive_absolute(Customs.dir)
	Customs.all_ways_on()
	var src := root.path_join("src")
	kit_wears(src)
	front_kit_wears(src)
	Customs.ways.clear()
	clear_dir(root)
	print("WEAR DRAW TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
