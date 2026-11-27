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
const KitImport := preload("res://kit_import.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")

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

	# --- Draw in your own app (C4): the kit screens.
	Customs.all_ways_on()
	var ks: RefCounted = my.kit_screen
	ks.start()
	t = page(my)
	check(ks.active and "Draw in your own app" in t and "Get the templates" in t and "Pick a file" in t, "Draw in your own app opens the choose page")
	ks.name = ""
	ks.open_file("res://templates/side-1.svg")
	check(ks.step == "kit" and ks.preview == Customs.staged_id(ks.SLOT), "a template comes in and walks before it is kept")
	t = page(my)
	check("What it can do" in t and "Keep" in t and t.any(func(x): return x.begins_with("Found ")), "the kit page lists what it found")
	check(ks.name == "Side 1", "named after the file (%s)" % ks.name)
	var lines: Array = ks.check_lines({"plan": "side", "parts": {"walk-body": 1, "head": 1, "eyes": 1, "leg-front": 1, "leg-back": 1},
		"missing": [], "dropped": ["a script"], "unmatched": ["doodle"]})
	check(lines.any(func(l): return l[0] == "cost" and "tail" in l[1] and "swish" in l[1]), "a missing tail costs its swishes")
	check(lines.any(func(l): return "a script" in l[1]) and lines.any(func(l): return "doodle" in l[1]), "what was taken out and not recognised is said")
	var need: Array = ks.check_lines({"plan": "side", "parts": {"head": 1}, "missing": ["walk-body"], "dropped": [], "unmatched": []})
	check(need.any(func(l): return l[0] == "need" and "walking body" in l[1]), "a needed part is said")
	# A layer it didn't recognise, named as a part.
	var odd := FileAccess.get_file_as_string("res://templates/side-1.svg").replace('inkscape:label="tail (optional)"', 'inkscape:label="swishy"').replace('id="tail"', 'id="swishy"')
	var odd_path := root.path_join("odd-side.svg")
	var of := FileAccess.open(odd_path, FileAccess.WRITE)
	of.store_string(odd)
	of.close()
	ks.open_file(odd_path)
	check("swishy" in ks.staged.unmatched and not ks.staged.parts.has("tail"), "a layer named oddly isn't recognised (%s)" % str(ks.staged.unmatched))
	check(ks.name_rows().size() == ks.staged.unmatched.size(), "each gets a which-part drop-down")
	ks.assign["swishy"] = "tail"
	ks.reload()
	check(ks.staged.parts.has("tail") and not "swishy" in ks.staged.unmatched, "named as the tail, it is the tail")
	ks.assign = {}
	ks.open_file("res://templates/side-1.svg")

	# --- Two staged slots live at once: the kit page's and another's.
	var other := Customs.show_staged(ks.STAGING, "studio")
	check(other != "" and other != ks.preview and Customs.all.has(other) and Customs.all.has(ks.preview), "two staged previews can be live at once (%s, %s)" % [ks.preview, other])
	check(not other in Customs.ids() and not ks.preview in Customs.ids() and Customs.is_staged(other), "neither is listed as a critter")
	Customs.clear_staged("studio")
	check(not Customs.all.has(other) and Customs.all.has(ks.preview), "clearing one leaves the other")

	# --- Joints (C4): dragged on the art, kept in the staged kit and on Reload.
	t = page(my)
	check("Joints" in t and "How it moves" in t, "the kit page shows the joints beside the critter walking")
	check(ks.shown_pins().has("hip-back") and ks.shown_pins().has("neck-walk") and ks.shown_pins().has("tail"), "the side-on joints it has parts for (%s)" % str(ks.shown_pins()))
	var base: Vector2 = KitImport.base_pins(ks.staged)["hip-back"]
	ks.drag_pin("hip-back", ks.pin_shown_at("hip-back") + Vector2(20, 10))
	check(KitImport.pin_now(ks.staged, "hip-back") == base + Vector2(20, 10) and ks.moved.has("hip-back"), "a dragged joint is kept in the staged kit")
	var sk = JSON.parse_string(FileAccess.get_file_as_string(ks.STAGING.path_join("kit.json")))
	check(Vector2(sk.pins["hip-back"][0], sk.pins["hip-back"][1]) == base + Vector2(20, 10 + ks.dy), "and the critter beside it walks with it")
	ks.drag_pin("hip-back", ks.pin_shown_at("hip-back") + Vector2(300, 0))
	check(absf(KitImport.pin_now(ks.staged, "hip-back").x - base.x) <= 60.0, "a joint stops at its box, 60 units from where it was drawn")
	ks.drag_pin("hip-back", base + Vector2(-12, 8) + Vector2(0, ks.dy))
	var neck_was: Vector2 = KitImport.pin_now(ks.staged, "neck-walk")
	ks.drag_pin("hip-front", Vector2(KitImport.pin_now(ks.staged, "hip-front").x, neck_was.y - 40.0 + ks.dy))
	check(KitImport.pin_now(ks.staged, "hip-front").y > neck_was.y, "a hip stays below the neck")
	ks.reload()
	check(KitImport.pin_now(ks.staged, "hip-back") == base + Vector2(-12, 8), "a dragged joint survives Reload")
	sk = JSON.parse_string(FileAccess.get_file_as_string(ks.STAGING.path_join("kit.json")))
	check(Vector2(sk.pins["hip-back"][0], sk.pins["hip-back"][1]) == base + Vector2(-12, 8 + ks.dy), "and is written again with it")

	# --- Where's its head? (F1), shown once clothes for homemade critters are on.
	check("Where's its head?" in page(my), "with clothes on, the kit page asks where its head is")
	Customs.ways.erase("share")
	check(not "Where's its head?" in page(my), "and not while they're off")
	Customs.all_ways_on()
	var meas: Dictionary = ks.staged.head_measured
	var want: Dictionary = meas.duplicate()
	want.cx = float(meas.cx) + 10.0
	want.cy = float(meas.cy) - 6.0
	want.rx = float(meas.rx) * 1.2
	ks.set_head(want)
	check(absf(float(ks.head_now().cx) - want.cx) < 0.01 and absf(float(ks.head_now().rx) - want.rx) < 0.01, "the head can be moved and sized")
	ks.hat = "glasses"
	check("Try on" in page(my), "with a hat to try on")
	ks.reload()
	check(absf(float(ks.head_now().cx) - want.cx) < 0.01, "the head's adjustment survives Reload")
	ks.name = "Biscuit"
	var kid: String = ks.keep()
	var kept = JSON.parse_string(FileAccess.get_file_as_string(str(Customs.all[kid]["_dir"]).path_join("kit.json")))
	check(absf(float(kept.head.cx) - want.cx) < 0.01 and absf(float(kept.head.cy) - want.cy) < 0.01 and absf(float(kept.head.rx) - want.rx) < 0.01,
		"Keep stores the adjusted head in kit.json (%s)" % str(kept.head))
	check(kept.has("moved") and Vector2(kept.pins["hip-back"][0], kept.pins["hip-back"][1]) == base + Vector2(-12, 8 + ks.dy), "and its dragged joints")
	var built_r := KitData.build(str(Customs.all[kid]["_dir"]), kept)
	check(absf(float(built_r.head.cx) - want.cx) < 0.01 and absf(float(built_r.head.rx) - want.rx) < 0.01, "and the rig dresses that head")
	check(kid != "" and Customs.all[kid]["name"] == "Biscuit" and Customs.badge(Customs.all[kid]) == "Drawn", "Keep adds it as Drawn")
	check(FileAccess.file_exists(str(Customs.all[kid]["_dir"]).path_join("source.json")) and not Customs.all.has(Customs.staged_id(ks.SLOT)), "remembering its file, with the preview gone")
	check(not ks.active and my.view == "detail" and my.selected == kid, "and opens its page")
	var rev := int(Customs.all[kid].get("rev", 0))
	my._edit(kid)
	check(ks.active and ks.step == "kit" and ks.replacing == kid, "Bring in a new version opens its file again")
	check(KitImport.pin_now(ks.staged, "hip-back") == base + Vector2(-12, 8) and absf(float(ks.head_now().cx) - want.cx) < 0.01,
		"with its dragged joints and its head")
	ks.reload()
	check(ks.changed_note != "", "Reload brings it in again and says so")
	check(ks.keep() == kid and int(Customs.all[kid].get("rev", 0)) > rev and Customs.all[kid]["name"] == "Biscuit", "and Save replaces its drawing, name kept")
	Customs.remove(kid)
	Customs.ways = {}

	# --- Bring an animation (E3): the frames screen.
	Customs.all_ways_on()
	var fs: RefCounted = my.frames_screen
	fs.start()
	t = page(my)
	check(fs.active and "Bring an animation" in t and "Pick a folder" in t, "Bring an animation opens its choose page")
	var cat_src: String = Fixtures.pixel_cat(root.path_join("src/cat"))
	fs.open_file(ProjectSettings.globalize_path(cat_src.path_join("clips")))
	check(fs.error == "" and fs.staged.clips.has("walk") and fs.preview == Customs.staged_id(fs.SLOT), "a folder of frames comes in and walks (%s)" % fs.error)
	t = page(my)
	check("ITS MOVES" in t and "Walk" in t and "Sit" in t and "Wave" in t, "its moves are listed, its own wave too")
	check(t.any(func(x): return x.begins_with("Nap: borrows")), "and a missing move says what it borrows")
	fs.info.walk.fps = 12
	fs.faces = "right"
	fs.apply()
	var cj = JSON.parse_string(FileAccess.get_file_as_string(fs.STAGING.path_join("clips.json")))
	check(int(cj.clips.walk.fps) == 12 and cj.faces == "right", "settings go into its clips.json")
	# --- Where's its head? (F3): marks per move, joined in between.
	t = page(my)
	check("Where's its head?" in t and t.any(func(x): return x.begins_with("Frame 1 of 4")), "with clothes on, a head panel with a frame stepper")
	check(t.any(func(x): return "shows no clothes" in x), "a move with no marks says it shows no clothes")
	fs.step_frame(1)
	check(fs.head_frame == 1, "the stepper steps through the frames")
	fs.mark("walk", 0, Vector3(120, 140, 30))
	fs.mark("walk", 3, Vector3(126, 146, 34))
	fs.head_clip = "sit"
	fs.mark("sit", 0, fs.suggest_head("sit", 0))
	fs.unmark("sit", 0)
	cj = JSON.parse_string(FileAccess.get_file_as_string(fs.STAGING.path_join("clips.json")))
	check(cj.clips.walk.has("head") and cj.clips.walk.head.size() == 2 and Array(cj.clips.walk.head["3"]) == [126.0, 146.0, 34.0],
		"marks are written per frame to clips.json (%s)" % str(cj.clips.walk.get("head")))
	check(not cj.clips.sit.has("head"), "an unmarked move has none")
	var mid = FrameData.head_at(cj, "walk", 1)
	check(mid is Vector3 and absf(mid.x - 122.0) < 0.01 and absf(mid.z - 31.333) < 0.01, "the frames between follow along (%s)" % str(mid))
	check(fs.head_shown("walk", 2) != null and not fs.marked("walk", 2) and fs.marked("walk", 3), "shown on every frame, marked on two")
	fs.reload()
	cj = JSON.parse_string(FileAccess.get_file_as_string(fs.STAGING.path_join("clips.json")))
	check(cj.clips.walk.head.size() == 2, "the marks survive Reload")
	fs.name = "Pixel"
	var fid: String = fs.keep()
	check(fid != "" and Customs.badge(Customs.all[fid]) == "Animated" and Customs.all[fid]["name"] == "Pixel", "Keep adds it as Animated")
	check(FrameData.has_head(Customs.all[fid]["_clips"]), "with its head marked, so it can wear clothes")
	my._edit(fid)
	check(fs.active and fs.replacing == fid and not fs.staged.is_empty(), "Change frames opens its frames again")
	check(fs.marks.get("walk", {}).size() == 2, "with its head marks")
	check(fs.keep() == fid, "and Save keeps the same critter")
	Customs.remove(fid)

	# --- A sprite sheet (E3): cut on a grid into one move, more sheets for more moves.
	var sheet_path := ProjectSettings.globalize_path(root.path_join("cat-sheet.png"))
	var cells := []
	for i in 4:
		cells.append(Fixtures._cat_frame(i))
	var cw: int = cells[0].get_width()
	var ch: int = cells[0].get_height()
	var sheet := Image.create(cw * 4, ch * 2, false, Image.FORMAT_RGBA8)
	for i in 7:
		sheet.blit_rect(cells[i % 4], Rect2i(Vector2i.ZERO, Vector2i(cw, ch)), Vector2i(i % 4 * cw, int(i / 4.0) * ch))
	sheet.save_png(sheet_path)
	fs.start()
	fs.add_sheet(sheet_path)
	check(fs.sheets.size() == 1 and fs.sheets[0].clip == "walk", "the first sheet is the walk")
	fs.set_sheet(0, "cols", 4)
	fs.set_sheet(0, "rows", 2)
	check(fs.error == "" and fs.staged.clips.walk.size() == 8, "cut on its grid: every cell (%s)" % fs.error)
	fs.set_sheet(0, "count", 7)
	check(fs.staged.clips.walk.size() == 7 and FrameData.frame_files(fs.STAGING, "walk").size() == 7, "or as many frames as it has")
	t = page(my)
	check("SPRITE SHEETS" in t and "Add another sheet" in t and "Walk" in t, "the sheet's settings are on the page")
	fs.add_sheet(sheet_path)
	check(fs.sheets[1].clip == "sit" and fs.staged.clips.has("sit") and fs.staged.clips.has("walk"), "another sheet is another move")
	fs.set_sheet(1, "clip", "act-wave")
	check(fs.staged.clips.has("act-wave") and not fs.staged.clips.has("sit"), "named from the list")
	fs.set_sheet(0, "cols", 7)
	check(fs.staged.is_empty() and fs.error.contains("evenly") and "Cut a sprite sheet" in page(my), "a grid that doesn't divide says so and keeps the sheets")
	fs.set_sheet(0, "cols", 4)
	fs.name = "Sheet cat"
	var sid: String = fs.keep()
	check(sid != "" and FrameData.frame_files(str(Customs.all[sid]["_dir"]), "walk").size() == 8, "Keep keeps the sheet's frames")
	var src = JSON.parse_string(FileAccess.get_file_as_string(str(Customs.all[sid]["_dir"]).path_join("source.json")))
	check(typeof(src) == TYPE_DICTIONARY and src.get("sheets", []).size() == 2, "and remembers its sheets")
	my._edit(sid)
	check(fs.active and fs.sheets.size() == 2 and fs.staged.clips.has("act-wave"), "Change frames opens the sheets again")
	fs.close()
	Customs.remove(sid)
	Customs.ways = {}

	# --- Dropping a file (C5): each kind to its importer, behind its way.
	Customs.ways = {}
	check(MyCritters.route("a/b.png") == "picture" and MyCritters.route("a/b.svg") == "" and MyCritters.route("a/b.critter") == "", "with the ways off only pictures go anywhere")
	Customs.all_ways_on()
	check(MyCritters.route("a/b.svg") == "kit" and MyCritters.route("a/b.zip") == "kit" and MyCritters.route("a/b.ora") == "kit", "drawings go to the kit importer")
	check(MyCritters.route("a/b.gif") == "frames" and MyCritters.route("a/b.critter") == "install" and MyCritters.route("a/b.psd") == "", "animations, critter files, and nothing for a .psd")
	check(my.drop("res://templates/front-1.svg") == "kit" and my.kit_screen.active and my.kit_screen.plan == "front", "a dropped template opens the kit page as its body")
	my.kit_screen.close()
	my.drop(file)
	check(my.view == "install" and not my.staged.is_empty(), "a dropped .critter file opens the install view")
	my._end_install()
	Customs.ways = {}

	# --- The Collection's Homemade row (H1): live past 12 only when hovered.
	var shelf = preload("res://gui/collection.gd").new()
	var live_card: Control = shelf._homemade_card(sticker, K.c, true)
	var still_card: Control = shelf._homemade_card(sticker, K.c, false)
	check(shelf._previews.size() == 1, "a capped card draws no live critter until hovered")
	var well: Control = still_card.get_child(0).get_child(0)
	well.mouse_entered.emit()
	check(shelf._previews.size() == 2, "and wakes when the pointer is over it")
	live_card.free()
	still_card.free()
	shelf.free()

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
