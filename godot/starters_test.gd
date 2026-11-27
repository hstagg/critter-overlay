extends SceneTree
## Headless checks for the Critter Studio's D4-D6 (docs/custom-critters-build-
## plan.md): every starter is a valid doc that saves as a kit that loads
## (Customs.add_folder) and builds a rig; Save and Edit-then-save round trips
## (save_panel.gd keep: a new id, then the same id with its rev bumped);
## pins stay within their limits (pins_panel.gd); style changes reach the
## written SVG (shape_svg.gd); a triangle's corner radius rounds it; and, in
## the window (built, not shown), recolouring, Outline, Blush, eyes and a
## pin drag, each one undo step.
## Run: godot --headless --path godot --script res://starters_test.gd

const Customs := preload("res://customs.gd")
const Share := preload("res://share.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const Shapes := preload("res://studio/shapes.gd")
const Writer := preload("res://studio/shape_svg.gd")
const Tools := preload("res://gui/studio/tools.gd")
const LP := preload("res://gui/studio/layers_panel.gd")
const Pins := preload("res://gui/studio/pins_panel.gd")
const Style := preload("res://gui/studio/style_panel.gd")
const SavePanel := preload("res://gui/studio/save_panel.gd")
const Start := preload("res://gui/studio/start_page.gd")
const History := preload("res://gui/studio/history.gd")

const ROOT := "user://starters_test"

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	Share.clear_dir(ROOT)
	Customs.dir = ROOT.path_join("store")
	DirAccess.make_dir_recursive_absolute(Customs.dir)
	Customs.all_ways_on()
	_starters()
	_save()
	_pins()
	_style()
	_tri()
	process_frame.connect(_frame)


var frame := 0


func _frame() -> void:
	frame += 1
	if frame == 1:
		_window()
	elif frame == 3:
		Share.clear_dir(ROOT)
		print("STARTERS TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
		quit(0 if fails == 0 else 1)


func _starters() -> void:
	check(Start.STARTERS.size() == 8, "eight starters")
	var plans := {}
	for s in Start.STARTERS:
		var file: String = s[0]
		var raw = JSON.parse_string(FileAccess.get_file_as_string("res://studio/starters/%s.json" % file))
		check(typeof(raw) == TYPE_DICTIONARY, "%s reads" % file)
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var c := Writer.clean_doc(raw)
		check(c.warnings.is_empty(), "%s is within every limit (%s)" % [file, c.warnings])
		var st := Start.starter(file)
		var doc: Dictionary = st.doc
		plans[doc.plan] = int(plans.get(doc.plan, 0)) + 1
		check(LP.needed(doc).is_empty(), "%s has every needed part" % file)
		check(st.gait in SavePanel.gaits(doc.plan), "%s's gait (%s) is one its body has" % [file, st.gait])
		var auto_poses: Array = LP.AUTO[doc.plan].keys().filter(func(p): return LP.AUTO[doc.plan][p][2])
		check(auto_poses.all(func(p): return not doc.layers.has(p)), "%s leaves its automatic poses automatic" % file)
		check(doc.style.outline == Writer.LINE_DEFAULT and doc.style.blush, "%s has the house outline and blush" % file)
		var eyes := Tools.layer(doc, "eyes")
		check(eyes.size() == 2 and eyes.all(func(e): return e.t == "eye"), "%s has two big eyes" % file)
		var dest := ROOT.path_join("kits/" + file)
		check(Share.write_builder_kit(doc, st.name, dest, st.gait) == dest, "%s writes a kit" % file)
		var id := Customs.add_folder(dest)
		check(id != "", "%s's kit loads (Customs.add_folder)" % file)
		if id == "":
			continue
		var d: Dictionary = Customs.all[id]
		check(KitData.missing(str(d["_dir"]), d["_kit"]).is_empty(), "%s's kit is complete" % file)
		var r := KitData.build(str(d["_dir"]), d["_kit"])
		check(r.images.has("loaf-body") and r.head_at.has("loaf") and r.head_at.has("walk"), "%s builds a rig that walks and naps" % file)
		var hit: Dictionary = KitData.hit_bounds(r)
		check(absf(hit.walk.end.y - KitData.GROUND - KitData.HIT_PAD) < 12.0, "%s stands on the ground (%s)" % [file, hit.walk.end.y])
		check(Species_has(id), "%s is a species the game can spawn" % file)
		check(Start.picture(file) != null, "%s has a picture for the Start page" % file)
	check(plans == {"side": 2, "front": 2, "upright": 2, "blob": 2}, "two starters for each body (%s)" % plans)


func Species_has(id: String) -> bool:
	return load("res://species.gd").custom.has(id)


func _save() -> void:
	# Keep: a new critter, then saved over in place.
	var st := Start.starter("round-cat")
	var doc: Dictionary = st.doc
	check(SavePanel.keep(Tools.blank("side"), "Nothing", "trot", {}) == "", "a doc missing its needed parts isn't kept")
	var id := SavePanel.keep(doc, "  Ginger the very long named cat  ", "hop", {"size": 1.3, "sound": "rabbit"})
	check(id != "" and Customs.all.has(id), "Keep adds it to the store")
	if id == "":
		return
	var d: Dictionary = Customs.all[id]
	var folder := str(d["_dir"])
	check(d.name == "Ginger the very long nam" and d.size == 1.3 and d.sound == "rabbit" and d.from == "shapes", "with its name (24 at most), size, sound and Shapes (%s)" % [d.name])
	check(Customs.badge(d) == "Shapes" and d["_kit"].gait == "hop", "as a Shapes kit with its gait")
	check(folder.get_file().begins_with("ginger-the-very-long-nam"), "in a folder named after it (%s)" % folder.get_file())
	check(FileAccess.file_exists(folder.path_join("thumb.png")), "with a card picture")
	var thumb := Image.load_from_file(folder.path_join("thumb.png"))
	check(thumb != null and maxi(thumb.get_width(), thumb.get_height()) == 128, "128 px a side at most")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("shapes.json")))
	check(typeof(saved) == TYPE_DICTIONARY and JSON.stringify(saved, "", true) == JSON.stringify(JSON.parse_string(JSON.stringify(Writer.clean_doc(doc).doc)), "", true), "its shapes.json is the doc")
	check(not DirAccess.dir_exists_absolute(SavePanel.STAGING), "the staging folder is cleared")
	# Edit then save: the same critter, a new rev, the new art, the rest kept.
	d["visits"] = 3
	d["seen"] = {"2026-11-01": 2}
	Customs.save(id)
	var rev := int(d.get("rev", 0))
	var n_before := Customs.ids().size()
	var edited: Dictionary = saved.duplicate(true)
	edited.layers["walk-body"][0].fill = "#A9D99B"
	edited.layers.erase("tail")
	var id2 := SavePanel.keep(edited, "Ginger", "trot", {"size": 1.0, "sound": "kitten"}, id)
	check(id2 == id and Customs.ids().size() == n_before, "Edit then save keeps the same critter")
	check(int(Customs.all[id].get("rev", 0)) == rev + 1, "with its rev bumped, so its textures are made again")
	check(Customs.all[id].name == "Ginger" and int(Customs.all[id].visits) == 3 and Customs.all[id].seen.has("2026-11-01"), "its name changes, its visits and sightings stay")
	check(FileAccess.get_file_as_string(folder.path_join("parts/walk-body.svg")).contains("#A9D99B"), "its parts are the new art")
	check(not FileAccess.file_exists(folder.path_join("parts/tail.svg")) and not Customs.all[id]._kit.is_empty(), "a part taken away is gone")
	var again = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("custom.json")))
	check(typeof(again) == TYPE_DICTIONARY and int(again.rev) == rev + 1 and again.name == "Ginger", "custom.json is saved")
	# And loads from disk as it was left.
	Customs.load_all()
	check(Customs.all.has(id) and Customs.all[id]._kit.gait == "trot", "the store loads it back")


func _pins() -> void:
	var doc: Dictionary = Start.starter("round-cat").doc
	var sug := Pins.suggested(doc)
	check(Pins.shown(doc) == ["neck-walk", "hip-front", "hip-back", "tail", "ear-l", "ear-r", "eyes"], "a side-on critter shows its seven joints (%s)" % [Pins.shown(doc)])
	var q := Pins.set_pin(doc, "hip-back", sug["hip-back"] + Vector2(500, 500))
	var box := Pins.box(doc, "hip-back")
	check(box.grow(0.01).has_point(q) and q.distance_to(sug["hip-back"]) <= KitData.PIN_SLACK * 1.5, "a pin dragged far stops at its box (%s)" % q)
	check(q.x <= KitData.FRAME.x and q.y <= KitData.FRAME.y, "and inside the frame")
	check(Pins.moved(doc, "hip-back") and Pins.at(doc, "hip-back") == q, "and is kept as moved")
	q = Pins.set_pin(doc, "hip-front", Vector2(sug["hip-front"].x, 0))
	check(q.y > Pins.at(doc, "neck-walk").y, "a hip stays below the neck (%s)" % q)
	Pins.set_pin(doc, "neck-walk", sug["neck-walk"] + Vector2(-10, 5))
	check(doc.pins.has("head") and Vector2(doc.pins.head[0], doc.pins.head[1]) == Pins.at(doc, "neck-walk"), "the head turns where the neck is moved to")
	Pins.reset(doc, "neck-walk")
	check(not doc.pins.has("neck-walk") and not doc.pins.has("head"), "Put it back follows the shapes again")
	# Pins follow the shapes until moved.
	var before := Pins.at(doc, "tail")
	Tools.move(doc, "tail", [0], Vector2(10, 0))
	check(Pins.at(doc, "tail").distance_to(before) > 1.0, "an unmoved pin follows its shapes")
	# The written kit uses them, clamped.
	var dest := ROOT.path_join("pinned")
	Share.write_builder_kit(doc, "Pinned", dest)
	var kit = JSON.parse_string(FileAccess.get_file_as_string(dest.path_join("kit.json")))
	check(typeof(kit) == TYPE_DICTIONARY and Vector2(kit.pins["hip-back"][0], kit.pins["hip-back"][1]) == Pins.at(doc, "hip-back"), "kit.json has the moved pin")
	check(KitData.pins(kit).warnings.is_empty(), "and the rig needn't move any pin")
	Pins.reset(doc)
	check(doc.pins.is_empty(), "Put every pin back")
	# Faces you: the head sits on the sitting body; walking, near the front.
	var bear: Dictionary = Start.starter("bear").doc
	var bs := Pins.suggested(bear)
	check(bs["neck-sit"].distance_to(Vector2(150, 165)) < 12.0 and bs["neck-walk"].x < 130.0, "a bear's necks: sitting under its head, walking at the front (%s, %s)" % [bs["neck-sit"], bs["neck-walk"]])
	check(Pins.shown(Start.starter("chick").doc).has("hip") and Pins.shown(Start.starter("slime").doc) == ["eyes"], "each body shows its own joints")


func _style() -> void:
	var doc: Dictionary = Start.starter("round-cat").doc
	var pal := Style.palette(doc)
	check(pal[0] == "#F6C28F" and pal.has("#3A2A22") and pal.size() == pal.reduce(func(a, x): return a if x in a else a + [x], []).size(), "In this critter: its colours, most used first (%s)" % [pal])
	var shapes: Array = doc.layers["walk-body"]
	shapes[0].fill = "#123456"
	shapes[0].line = false
	var svg: String = Writer.write(doc)["walk-body"]
	check(svg.contains('fill="#123456"'), "a new fill reaches the SVG")
	check(not svg.contains('stroke="#5B3A29"'), "with Outline off, no outline is drawn round it")
	shapes[1].inside = false
	check(not Writer.write(doc)["walk-body"].contains("clip-path"), "Marking off: the belly isn't clipped")
	check(Writer.write(doc)["head"].contains(Writer.BLUSH), "blush on: rosy cheeks on the head")
	doc.style.blush = false
	check(not Writer.write(doc)["head"].contains(Writer.BLUSH), "blush off: none")
	check(Style.set_eyes(doc, "lash") == ["eyes"] and Style.eye_preset(doc) == "lash", "every eye takes the preset")
	check(Writer.write(doc)["eyes"].contains("<path"), "and a lash is drawn")
	Style.set_eyes(doc, "dot")
	check(not Writer.write(doc)["eyes"].contains("#FFFFFF"), "a dot eye has no highlight")
	check(Style.eye_icon("big") != null, "each preset has a picture")


func _tri() -> void:
	var sharp := Shapes.clean({"t": "tri", "x": 100, "y": 100, "w": 60, "h": 60, "r": 0})
	var round := Shapes.clean({"t": "tri", "x": 100, "y": 100, "w": 60, "h": 60, "r": 10})
	var ps := Shapes.polygon(sharp)
	var pr := Shapes.polygon(round)
	check(ps.size() == 3 and pr.size() > 3, "a triangle with r is rounded (%d points)" % pr.size())
	check(Shapes._area(pr) < Shapes._area(ps) and Shapes._area(pr) > Shapes._area(ps) * 0.8, "a little smaller than the sharp one")
	var top := pr[0]
	for p in pr:
		if p.y < top.y:
			top = p
	check(top.y > 70.5, "its top corner is rounded off (%s)" % top.y)
	check(Writer.layer([round], "#5B3A29", 6.0) != Writer.layer([sharp], "#5B3A29", 6.0), "and draws differently")
	# History keeps the doc's style and pins as well as layers.
	var doc := Tools.blank("side")
	var h := History.new()
	h.record(doc, ["@style", "@pins"])
	doc.style.blush = false
	doc.pins["tail"] = [1, 2]
	h.undo(doc)
	check(doc.style.blush and doc.pins.is_empty(), "undo puts the style and pins back")
	h.redo(doc)
	check(not doc.style.blush and doc.pins.has("tail"), "redo again")


func _window() -> void:
	# The Studio built (not shown): the Start page, a starter, recolouring
	# by the picker, Outline, Blush, eyes and a pin drag.
	var w: Window = load("res://gui/studio/studio_window.gd").new()
	root.add_child(w)
	w.starting = true
	w.build()
	check(w.canvas == null and w.get_child_count() > 0, "with nothing to build, the Start page shows")
	w.start_from("round-cat")
	check(not w.starting and w.canvas != null and w.doc.layers.has("tail") and w.gait == "trot", "a starter opens the Builder")
	check(not w._save_b.disabled, "Save is on: every needed part is drawn")
	w.pick_part("walk-body")
	w.sel = [0]
	w.selection_changed()
	check(w.style.picker != null, "the colour panel has the picker for the picked shape")
	w.style.picker.set_hex("#ABCDEF")
	w.style.picker.set_hex("#ABCDE0")
	check(Tools.layer(w.doc, "walk-body")[0].fill == "#ABCDE0" and w.changed, "the picker recolours it")
	w.undo()
	check(Tools.layer(w.doc, "walk-body")[0].fill == "#F6C28F", "a picker drag is one undo step")
	w.sel = [0]
	w.set_shape_flag("line", false)
	check(not Tools.layer(w.doc, "walk-body")[0].line, "Outline off")
	w.set_blush(false)
	check(not w.doc.style.blush, "Blush off")
	w.undo()
	check(w.doc.style.blush, "and undone")
	w.set_eye_preset("round")
	check(Style.eye_preset(w.doc) == "round", "the eyes change")
	w.pick_part("eyes")
	w.place("eye", Vector2(200, 100))
	check(Tools.layer(w.doc, "eyes")[-1].preset == "round", "a new eye matches the others")
	# Pins mode: a drag on the canvas moves the back hip, within its box.
	w.set_view_mode("pins")
	check(w.view_mode == "pins" and w.canvas != null, "Pins mode")
	var cv: Control = w.canvas
	cv.zoom = 1.0
	cv.origin = Vector2(100, 200)
	var hip := Pins.at(w.doc, "hip-back")
	var e := InputEventMouseButton.new()
	e.position = cv.to_px(hip)
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	cv._button(e)
	var mv := InputEventMouseMotion.new()
	mv.position = cv.to_px(hip + Vector2(200, 0))
	cv._motion(mv)
	cv._release()
	check(w.pin_sel == "hip-back" and Pins.moved(w.doc, "hip-back") and Pins.at(w.doc, "hip-back").x <= hip.x + KitData.PIN_SLACK + 0.5, "dragging a pin moves it, no further than its box")
	w.undo()
	check(not Pins.moved(w.doc, "hip-back"), "and undo puts it back")
	# Leaving with changes asks first; Don't save forgets the doc.
	w.leave(Callable())
	check(w.overlay != null and w.doc.layers.size() > 0, "leaving with changes asks first")
	w.close_overlay()
	w.preview.clear()
	w.queue_free()
