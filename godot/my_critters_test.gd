extends SceneTree
## Headless checks for Settings › My critters (gui/my_critters.gd, plan A2)
## and the colour picker (gui/colour_picker.gd): the grid lists every
## homemade critter, a picture imports through it, ways still behind their
## switch show nothing, Make a copy, and the picker gives back what it's set to.
## Run: godot --headless --path godot --script res://my_critters_test.gd

const Customs := preload("res://customs.gd")
const Fixtures := preload("res://critters/kit/fixtures.gd")
const Palette := preload("res://gui/palette.gd")
const K := preload("res://gui/controls.gd")
const MyCritters := preload("res://gui/my_critters.gd")
const Picker := preload("res://gui/colour_picker.gd")
const Pages := preload("res://gui/settings_pages.gd")
const Share := preload("res://share.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


class StubWin extends Window:
	# What my_critters.gd asks of settings_window.gd.
	var main = null
	var pages: RefCounted
	var selected_species := ""
	var dark := false
	var rebuilt := 0
	func rebuild(_keep := true) -> void:
		rebuilt += 1
	func go(_page: String) -> void:
		rebuilt += 1
	func confirm(_t: String, _b: String, _ok: String, _f: Callable) -> void:
		pass


func texts(n: Node, out: Array = []) -> Array:
	# Every label's and button's words under n.
	if n is Label or n is Button:
		out.append(n.text)
	for ch in n.get_children():
		texts(ch, out)
	return out


func page(my: RefCounted) -> Array:
	var body := VBoxContainer.new()
	my.build(body, func(b: VBoxContainer, title: String, sub: String, right: Control = null):
		var l := Label.new()
		l.text = title
		b.add_child(l)
		if right != null:
			b.add_child(right))
	var t := texts(body)
	body.free()
	return t


func clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		clear_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func picture(path: String) -> void:
	var img := Image.create(160, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.8, 0.8))
	img.fill_rect(Rect2i(40, 30, 80, 60), Color(0.9, 0.5, 0.3))
	img.save_png(path)


func _init() -> void:
	var root := "user://my_critters_test"
	clear_dir(root)
	DirAccess.make_dir_recursive_absolute(root)
	Customs.dir = root.path_join("custom")
	Customs.ways = {}
	Customs.load_all()
	K.c = Palette.colours(false)
	var w := StubWin.new()
	w.pages = Pages.new(w)
	var my: RefCounted = w.pages.my

	# --- With none, the page is the chooser; the player build has one way.
	var t := page(my)
	check("Use a picture" in t and "Pick a picture" in t, "with none yet, the page offers Use a picture")
	for gated in ["Build from shapes", "Draw in your own app", "Bring an animation", "Got a code?"]:
		check(not gated in t, "a way still behind its switch shows nothing: " + gated)
	Customs.all_ways_on()
	t = page(my)
	for way in ["Build from shapes", "Draw in your own app", "Bring an animation", "Use a picture", "Got a code?"]:
		check(way in t, "with every way on, the chooser has " + way)

	# --- A picture imported through the page.
	var pic := root.path_join("photo.png")
	picture(pic)
	my.importer.open_file(ProjectSettings.globalize_path(pic))
	check(my.importer.editing == "new", "a picked picture opens the editor")
	t = page(my)
	check("Use a picture" in t and "Keep" in t, "the page shows the editor while one is being made")
	my.importer.name = "Toffee"
	my.importer.keep()
	check(Customs.ids().size() == 1 and my.importer.editing == "", "Keep adds it and closes the editor")
	var sticker: String = Customs.ids()[0]
	check(Customs.badge(Customs.all[sticker]) == "Picture", "an imported picture's badge is Picture")
	check(MyCritters.newest() == sticker and MyCritters.count() == 1, "the newest and the count, for the Your own tile and the sidebar")

	# --- The grid lists every homemade critter, with chips by kind.
	var kit := Customs.add_folder(Fixtures.kitten_kit(root.path_join("src/kitten_side")))
	check(kit != "" and Customs.badge(Customs.all[kit]) == "Drawn", "a drawn kit's badge is Drawn")
	my.view = "list"
	t = page(my)
	check("Toffee" in t and str(Customs.all[kit]["name"]) in t, "the grid lists every homemade critter")
	check("All 2" in t and "Picture 1" in t and "Drawn 1" in t, "a chip for all and for each kind there is")
	my.filter = "Picture"
	t = page(my)
	check("Toffee" in t and not str(Customs.all[kit]["name"]) in t, "the Picture chip shows pictures only")
	my.filter = "All"

	# --- One critter: the Edit button's words follow the kind; Share waits for its way.
	my.view = "detail"
	my.selected = sticker
	t = page(my)
	check("Change picture" in t and "Make a copy" in t and "Spawn one now" in t, "a picture's detail: Change picture, Make a copy, Spawn one now")
	check("Share" in t, "Share shows with every way on")
	my.selected = kit
	t = page(my)
	check("Bring in a new version" in t and "Open the Shop" in t, "a drawn kit's detail: Bring in a new version, and Clothes")
	# --- Share (G1, G2): a file for every kind, a code for builder critters.
	my.selected = sticker
	my.sharing = true
	t = page(my)
	check("Save as a file" in t and not "Copy code" in t, "a picture shares as a file, with no code")
	check(t.any(func(x): return "only share pictures" in x), "with decision 5's note")
	var built := Share.write_builder_kit(Fixtures.LILAC, "Lilac", root.path_join("src/lilac"))
	var lilac := Customs.add_folder(built)
	my.selected = lilac
	my.sharing = true
	t = page(my)
	check("Copy code" in t and "Save as a file" in t, "a builder critter offers its code too")
	my._copy_code(lilac)
	check(my.share_note.begins_with("Copied"), "Copy code copies it (%s)" % my.share_note)
	var file := ProjectSettings.globalize_path(root.path_join("lilac.critter"))
	check(Share.export_critter(lilac, file, "3.1.1") == "" and FileAccess.file_exists(file), "and Save as a file writes one")
	Customs.remove(lilac)
	my.sharing = false

	# --- Installing (G2) and adding a code (G1), shown before anything is written.
	w.main = {"VERSION": "3.1.1"}
	var before := Customs.ids().size()
	my.install_file(file)
	t = page(my)
	check("Install Lilac?" in t and "Only install critters from people you trust." in t, "a .critter file opens the install view")
	check(Customs.ids().size() == before and Customs.all.has(Customs.STAGED), "nothing is added yet, but it is shown")
	var got: String = my.confirm_install()
	check(got != "" and Customs.all[got]["name"] == "Lilac" and not Customs.all.has(Customs.STAGED), "Install adds it")
	my.install_file(file)
	t = page(my)
	check(t.any(func(x): return "as Lilac 2" in x), "a taken name is said")
	var got2: String = my.confirm_install()
	check(Customs.all[got2]["name"] == "Lilac 2" and Customs.all[got]["name"] == "Lilac", "and the new one is Lilac 2, the old one kept")
	my.add_code(Share.encode_code(Fixtures.LILAC, "Pip"))
	t = page(my)
	check("Add Pip?" in t and "Codes don't say who made them." in t, "a code opens the same view, with Add")
	var pip: String = my.confirm_install()
	check(pip != "" and Customs.all[pip].get("friend", false) and Customs.badge(Customs.all[pip]) == "Shapes", "Add keeps it as Shapes, from a friend")
	my.add_code("hello")
	t = page(my)
	check("That code can't be used" in t and Customs.ids().size() == before + 3, "a bad code says so and adds nothing")
	my._end_install()
	for x in [got, got2, pip]:
		Customs.remove(x)

	Customs.ways = {}
	my.selected = sticker
	t = page(my)
	check(not "Share" in t, "Share is hidden while its way is off")

	# --- Make a copy.
	var copy := Customs.make_copy(sticker)
	check(copy != "" and copy != sticker, "Make a copy adds a new critter")
	check(str(Customs.all[copy]["name"]) == "Toffee copy", "named <name> copy")
	check(Customs.all[copy]["_dir"] != Customs.all[sticker]["_dir"] and FileAccess.file_exists(str(Customs.all[copy]["_dir"]).path_join("image.png")),
		"in its own folder, with its picture")
	check(Customs.all[copy].get("seen", {}).is_empty(), "met afresh")
	Customs.load_all()
	check(Customs.all.has(copy), "and it loads again from the store")
	Customs.remove(copy)
	check(not Customs.all.has(copy), "and deletes like any other")

	# --- The colour picker.
	check(Picker.parse_hex("#abc") == "#AABBCC" and Picker.parse_hex("8cc46c") == "#8CC46C", "hex in short and long forms")
	check(Picker.parse_hex("#12345") == "" and Picker.parse_hex("#GG0000") == "", "not a colour: nothing")
	var p = Picker.new("#3b3437")
	check(p.hex() == "#3B3437", "the picker starts on the colour it was given")
	p.set_hex("#8CC46C")
	check(p.hex() == "#8CC46C", "set_hex gives that colour back")
	p._hue.move_to(Vector2(0.0, 0.5))
	p._sv.move_to(Vector2(1.0, 0.0))
	check(p.hex() == "#FF0000", "the hue strip and the square pick a colour: %s" % p.hex())
	p.free()
	Picker.recent = []
	for i in 14:
		Picker.remember("#%02X0000" % i)
	Picker.remember("#050000")
	check(Picker.recent.size() == Picker.MAX_RECENT and Picker.recent[0] == "#050000" and Picker.recent.count("#050000") == 1,
		"twelve recent colours at most, the newest first, each once")

	w.free()
	clear_dir(root)
	print("MY CRITTERS TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
