extends SceneTree
## Headless checks for the Critter Studio (docs/custom-critters-build-plan.md,
## D2 and D3): hit-testing on turned and flipped shapes, each shape tool's
## doc operation (gui/studio/tools.gd), live symmetry, the layers panel's
## rows (gui/studio/layers_panel.gd), the window's size on small screens,
## the scripted test critter (fixtures.gd studio_steps) matching
## test_data/studio/test_critter.json, and the window itself, built and
## drawn headless (nothing opens). D7: every button in the window has a
## tooltip (the tools with their keys), the ? panel lists every key the
## window answers to, the first-time tips show only while settings.gd's
## studio.tips_seen is false, an empty part's hint card, and Save with parts
## missing naming them.
## Run: godot --headless --path godot --script res://studio_test.gd

const Tools := preload("res://gui/studio/tools.gd")
const History := preload("res://gui/studio/history.gd")
const LP := preload("res://gui/studio/layers_panel.gd")
const Shapes := preload("res://studio/shapes.gd")
const Writer := preload("res://studio/shape_svg.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const Fixtures := preload("res://critters/kit/fixtures.gd")
const Help := preload("res://gui/studio/help.gd")
const StartPage := preload("res://gui/studio/start_page.gd")
const STORED := "res://test_data/studio/test_critter.json"


class FakeMain extends Node:
	var settings: Node

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func near(a: Vector2, b: Vector2, tol := 0.6) -> bool:
	return a.distance_to(b) <= tol


func one(t: String, extra := {}) -> Dictionary:
	# A doc with one shape on "head".
	var doc := Tools.blank("side")
	var s := {"t": t, "x": 150, "y": 150, "w": 100, "h": 20}
	s.merge(extra, true)
	Tools.add(doc, "head", s)
	return doc


func _init() -> void:
	_hits()
	_shape_ops()
	_selection_ops()
	_symmetry()
	_layers()
	_window()
	_script()
	_help_data()
	# The window needs the tree running, and a few frames to draw.
	process_frame.connect(_frame)


var frame := 0
var drawn := 0
var studio: Window
var helpw: Window
var fake: FakeMain


func _frame() -> void:
	frame += 1
	if frame == 1:
		_gui()
		_help()
	elif frame == 3:
		_tooltips()
	elif frame == 4:
		var none := _untipped(helpw)
		check(none.is_empty(), "in Pins mode too (not: %s)" % [none])
		helpw.queue_free()
		fake.settings.free()
		fake.free()
		check(drawn > 0, "the canvas draws, with a selection and the guide, without an error (%d)" % drawn)
		studio.queue_free()
		print("STUDIO TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
		quit(0 if fails == 0 else 1)


func _hits() -> void:
	# A 100 x 20 bar turned 90 degrees stands upright.
	var doc := one("rect", {"rot": 90, "r": 0})
	check(Tools.hit(doc, "head", Vector2(150, 190)) == 0, "a turned bar is hit along its new length")
	check(Tools.hit(doc, "head", Vector2(190, 150)) == -1, "and missed where it lay before")
	doc = one("ellipse", {"rot": 45})
	check(Tools.hit(doc, "head", Vector2(180, 180)) == 0 and Tools.hit(doc, "head", Vector2(180, 120)) == -1, "an oval turned 45 degrees is hit on its diagonal only")
	# Flipped, a turn goes the other way.
	doc = one("ellipse", {"rot": 45, "flip": true})
	check(Tools.hit(doc, "head", Vector2(180, 120)) == 0 and Tools.hit(doc, "head", Vector2(180, 180)) == -1, "flipped, it is hit on the other diagonal")
	# The topmost of two overlapping shapes.
	Tools.add(doc, "head", {"t": "ellipse", "x": 150, "y": 150, "w": 30, "h": 30})
	check(Tools.hit(doc, "head", Vector2(150, 150)) == 1, "the topmost shape is the one hit")
	check(Tools.in_rect(doc, "head", Rect2(140, 140, 20, 20)) == [0, 1] and Tools.in_rect(doc, "head", Rect2(0, 0, 20, 20)).is_empty(), "drag-select finds the shapes the box touches")


func _shape_ops() -> void:
	# Every type is placed valid, at its default size, where clicked.
	for t in Shapes.TYPES:
		var s := Tools.new_shape(t, Vector2(120, 140))
		check(not s.is_empty() and near(Shapes.centre(s), Vector2(120, 140), 3.0), "%s is placed where clicked" % t)
	check(Tools.new_shape("eye", Vector2(1, 1)).fill == Tools.EYE_FILL, "eyes come dark")
	# Scale: the opposite corner stays put, on a turned shape too.
	var s := Shapes.clean({"t": "rect", "x": 150, "y": 150, "w": 60, "h": 40, "rot": 30, "r": 0})
	var corner := func(sh: Dictionary, hx: int, hy: int) -> Vector2:
		var b := Tools.box(sh)
		return b.c + b.ax * hx * b.half.x + b.ay * hy * b.half.y
	var far: Vector2 = corner.call(s, -1, -1)
	var grabbed: Vector2 = corner.call(s, 1, 1)
	var big := Tools.scaled(s, Vector2i(1, 1), grabbed + (grabbed - far) * 0.5, false)
	check(near(corner.call(big, -1, -1), far) and absf(big.w - 90.0) < 0.6 and absf(big.h - 60.0) < 0.6, "scaling from a corner keeps the opposite one (%s x %s)" % [big.w, big.h])
	var wide := Tools.scaled(s, Vector2i(1, 0), corner.call(s, 1, 0) + Vector2(30, 0).rotated(deg_to_rad(30)), false)
	check(absf(wide.w - 90.0) < 0.6 and absf(wide.h - 40.0) < 0.6, "an edge handle changes one side only")
	var kept := Tools.scaled(s, Vector2i(1, 0), corner.call(s, 1, 0) + Vector2(30, 0).rotated(deg_to_rad(30)), true)
	check(absf(kept.w / kept.h - 1.5) < 0.01, "Shift keeps the ratio")
	check(Tools.scaled(s, Vector2i(1, 1), far, false).w == Tools.MIN_SIZE, "a shape can't be scaled through itself")
	# Scaling a blob scales its points about the far corner.
	var blob := Tools.new_shape("blob", Vector2(150, 150))
	var br := Shapes.rect_of(blob)
	var bb := Tools.scaled(blob, Vector2i(1, 1), br.end + br.size, false)
	check(near(Shapes.rect_of(bb).position, br.position, 1.0) and absf(Shapes.rect_of(bb).size.x - br.size.x * 2.0) < 1.0, "a blob scales from its far corner")
	# Turn: Shift snaps to 15 degrees.
	var tr := Tools.turned(s, Vector2(150, 100), Vector2(190, 110), false)
	var snapped := Tools.turned(s, Vector2(150, 100), Vector2(190, 110), true)
	check(absf(fposmod(snapped.rot, 15.0)) < 0.01 and absf(snapped.rot - tr.rot) <= 7.5, "Shift snaps the turn to 15 degrees (%s, %s)" % [tr.rot, snapped.rot])
	var fl := Tools.turned(Shapes.clean({"t": "ellipse", "x": 150, "y": 150, "w": 60, "h": 40, "flip": true}), Vector2(150, 100), Vector2(200, 150), false)
	check(absf(angle_difference(Tools.eff(fl), PI / 2.0)) < 0.01, "a flipped shape turns the way it is dragged")
	var line := Tools.turned(Tools.new_shape("stroke", Vector2(150, 150)), Vector2(150, 100), Vector2(200, 150), true)
	check(absf(line.pts[0][0] - 142.0) < 0.6 and absf(line.pts[0][1] - 120.0) < 0.6, "a line turns its points")
	# Points and corner radius.
	var pt := Tools.with_point(blob, 2, Vector2(200, 210))
	check(pt.pts[2] == [200.0, 210.0] and pt.pts[0] == blob.pts[0], "a point handle moves that point only")
	var rr := Shapes.clean({"t": "rect", "x": 150, "y": 150, "w": 60, "h": 40, "r": 4})
	check(Tools.with_radius(rr, Vector2(130, 130)).r == 10.0 and Tools.with_radius(rr, Vector2(300, 130)).r == 20.0, "the corner handle sets the radius, within the limit")
	# Handles: where they are and which is under the pointer.
	var hs := Tools.handles(rr, 2.0)
	var ids := hs.map(func(x): return x[0])
	check(ids.has("r") and ids.has("rot") and ids.has("s:1:1") and ids.size() == 10, "a box has 8 scale handles, a turn and a radius handle")
	check(Tools.handle_at(rr, Vector2(180, 170), 2.0) == "s:1:1" and Tools.handle_at(rr, Vector2(150, 150), 2.0) == "", "the handle under the pointer is found")
	check(Tools.handle_at(blob, Vector2(blob.pts[3][0], blob.pts[3][1])) == "p:3", "a blob's point handles")


func _selection_ops() -> void:
	var doc := Tools.blank("side")
	for x in [100, 150, 200]:
		Tools.add(doc, "head", {"t": "ellipse", "x": x, "y": 150, "w": 30, "h": 30})
	# Order.
	check(Tools.forward(doc, "head", [0]) == [1] and Tools.layer(doc, "head")[1].x == 100.0, "bring forward")
	check(Tools.forward(doc, "head", [2]) == [2], "the front one stays in front")
	check(Tools.back(doc, "head", [1]) == [0] and Tools.layer(doc, "head")[0].x == 100.0, "send back")
	check(Tools.back(doc, "head", [0, 1]) == [0, 1], "a block at the back stays put")
	# Mirror about the selection's middle.
	Tools.mirror(doc, "head", [0, 2])
	check(Tools.layer(doc, "head")[0].x == 200.0 and Tools.layer(doc, "head")[2].x == 100.0 and Tools.layer(doc, "head")[0].flip, "mirror swaps sides about the selection's middle and flips each")
	# Duplicate, delete, nudge.
	check(Tools.duplicate_shapes(doc, "head", [1]) == [3] and Tools.layer(doc, "head")[3].x == 160.0, "duplicate lands on top, a little off")
	Tools.delete(doc, "head", [0, 3])
	check(Tools.layer(doc, "head").size() == 2 and Tools.layer(doc, "head")[0].x == 150.0, "delete takes the selected shapes")
	Tools.nudge(doc, "head", [0], Vector2.RIGHT, false)
	Tools.nudge(doc, "head", [0], Vector2.DOWN, true)
	check(Tools.layer(doc, "head")[0].x == 151.0 and Tools.layer(doc, "head")[0].y == 160.0, "arrows nudge by 1, Shift by 10")
	Tools.delete(doc, "head", [0, 1])
	check(not doc.layers.has("head"), "an emptied layer goes")
	# Copy and paste across layers.
	Tools.add(doc, "walk-body", {"t": "rect", "x": 160, "y": 200, "w": 100, "h": 50})
	var clip := Tools.copy(doc, "walk-body", [0])
	check(Tools.paste(doc, "body", clip) == [0] and Tools.layer(doc, "body")[0].x == 160.0, "paste on another layer lands in the same place")
	check(Tools.paste(doc, "walk-body", clip, true) == [1] and Tools.layer(doc, "walk-body")[1].x == 170.0, "paste on its own layer lands a little off")
	clip[0].x = 0.0
	check(Tools.layer(doc, "body")[0].x == 160.0, "a paste is a copy")
	# Snapping to the ground and the middle.
	var d := Tools.snap_delta(doc, "walk-body", [0], Vector2(-12, 34))
	var r := Tools.rect_of(doc, "walk-body", [0])
	check(absf(r.end.y + d.y - Tools.GROUND) < 0.01 and absf(r.get_center().x + d.x - Tools.MIDDLE) < 0.01, "a move near the ground and the middle snaps to both")
	check(Tools.snap_delta(doc, "walk-body", [0], Vector2(-40, 0)) == Vector2(-40, 0), "and away from them, it doesn't")
	check(Tools.snap_point(Vector2(147, 80)) == Vector2(150, 80) and Tools.snap_point(Vector2(140, 80)) == Vector2(140, 80), "a click near the middle places on it")
	# Draw this pose copies; only into an empty pose.
	var p2 := Tools.blank("side")
	Tools.add(p2, "walk-body", {"t": "ellipse", "x": 160, "y": 200, "w": 140, "h": 70})
	check(Tools.draw_pose(p2, "loaf-body", "walk-body") and Tools.layer(p2, "loaf-body") == Tools.layer(p2, "walk-body"), "Draw this pose copies the walking body")
	Tools.move(p2, "loaf-body", [0], Vector2(0, 20))
	check(Tools.layer(p2, "walk-body")[0].y == 200.0, "and the copy is its own")
	check(not Tools.draw_pose(p2, "loaf-body", "walk-body"), "a drawn pose isn't copied over")
	# Limits.
	var full := Tools.blank("side")
	var n := 0
	while Tools.add(full, "tail", Tools.new_shape("star", Vector2(100, 100))) >= 0:
		n += 1
	check(n == Shapes.MAX_PER_LAYER, "a layer takes %d shapes and no more (%d)" % [Shapes.MAX_PER_LAYER, n])
	check(Writer.clean_doc(full).warnings.is_empty(), "so the doc stays within the limits")
	# One placed action is one undo step.
	var h := History.new()
	var p3 := Tools.blank("side")
	Tools.place(p3, h, "head", "heart", Vector2(100, 100))
	check(h.undos.size() == 1 and h.undo(p3) == ["head"] and p3.layers.is_empty(), "placing a shape is one undo step")


func _symmetry() -> void:
	check(Tools.symmetric("front", "head") and not Tools.symmetric("side", "head") and not Tools.symmetric("front", "walk-body"), "front-facing layers are symmetric; side-on ones aren't")
	var doc := Tools.blank("front")
	var h := History.new()
	var i := Tools.place(doc, h, "eyes", "eye", Vector2(130, 148), true)
	var eyes := Tools.layer(doc, "eyes")
	check(eyes.size() == 2 and eyes[1].x == 170.0 and eyes[1].flip and i == 0, "an eye off the middle gets its twin")
	check(Tools.place(doc, h, "head", "ellipse", Tools.snap_point(Vector2(148, 140)), true) == 0 and Tools.layer(doc, "head").size() == 1, "a shape on the middle (snapped) has none")
	# Editing one moves its twin.
	var orig := Tools.layer(doc, "eyes").duplicate(true)
	var j := Tools.edit_one(doc, "eyes", 1, orig, Tools.moved(orig[1], Vector2(10, -5)), true)
	eyes = Tools.layer(doc, "eyes")
	check(j == 1 and eyes[1].x == 180.0 and eyes[0].x == 120.0 and eyes[0].y == 143.0, "moving the right eye moves the left one, mirrored")
	orig = eyes.duplicate(true)
	Tools.edit_one(doc, "eyes", 0, orig, Tools.scaled(orig[0], Vector2i(1, 1), Vector2(140, 160), false), true)
	eyes = Tools.layer(doc, "eyes")
	check(Tools.same(eyes[1], Tools.mirrored(eyes[0])), "scaling one scales its twin")
	orig = eyes.duplicate(true)
	Tools.edit_one(doc, "eyes", 0, orig, Tools.turned(orig[0], Vector2(eyes[0].x, 100), Vector2(eyes[0].x + 50, 120), true), true)
	eyes = Tools.layer(doc, "eyes")
	check(Tools.same(eyes[1], Tools.mirrored(eyes[0])) and eyes[0].rot != 0.0, "turning one turns its twin the other way")
	check(Tools.with_twins(doc, "eyes", [0]) == [0, 1], "Delete takes a shape's twin too")
	# Moved onto the middle, the twin goes.
	orig = eyes.duplicate(true)
	var k := Tools.edit_one(doc, "eyes", 1, orig, Tools.moved(orig[1], Vector2(150.0 - Shapes.centre(orig[1]).x, 0)), true)
	check(Tools.layer(doc, "eyes").size() == 1 and k == 0, "on the middle, a shape loses its twin")
	# An unpaired shape (a lopsided drawing) is left as it is.
	var lop := Tools.blank("front")
	Tools.add(lop, "head", {"t": "ellipse", "x": 120, "y": 100, "w": 30, "h": 30})
	Tools.add(lop, "head", {"t": "ellipse", "x": 200, "y": 100, "w": 20, "h": 20})
	var lo := Tools.layer(lop, "head").duplicate(true)
	Tools.edit_one(lop, "head", 0, lo, Tools.moved(lo[0], Vector2(0, 5)), true)
	check(Tools.layer(lop, "head").size() == 2 and Tools.layer(lop, "head")[1].y == 100.0, "an edit never makes or moves a twin that wasn't there")


func _layers() -> void:
	# Every part of every plan is listed exactly once.
	for plan in KitData.PLANS:
		var pl: Dictionary = KitData.PLANS[plan]
		var listed := []
		for g in LP.LAYOUT[plan]:
			listed.append_array(g[2])
		var all: Array = pl.required + pl.optional
		var missing := all.filter(func(p): return not p in listed)
		var extra := listed.filter(func(p): return listed.count(p) > 1 or not p in all)
		check(missing.is_empty() and extra.is_empty(), "%s: every part listed once (missing %s, extra %s)" % [plan, missing, extra])
	# A blank start: the needed parts are flagged and counted.
	var blank := Tools.blank("side")
	var rows := LP.rows(blank)
	var flagged := rows.filter(func(r): return r.kind == "missing").map(func(r): return r.part)
	check(flagged == ["head", "eyes", "walk-body", "leg-front", "leg-back"] and LP.needed(blank).size() == 5, "a blank side-on critter has its 5 needed parts flagged")
	check(rows.filter(func(r): return r.kind == "group").map(func(r): return r.label) == ["Every pose", "Walking", "Sitting", "Napping", "Extras"], "grouped Every pose, Walking, Sitting, Napping, Extras")
	var sit: Dictionary = rows.filter(func(r): return r.get("part", "") == "body")[0]
	check(sit.kind == "auto" and not sit.pose, "the sitting pose is automatic, with nothing to copy yet")
	# With a critter drawn: counts, automatic parts, Draw this pose, costs.
	var doc: Dictionary = Writer.clean_doc(Fixtures.LILAC).doc
	rows = LP.rows(doc)
	var by := {}
	for r in rows:
		if r.has("part"):
			by[r.part] = r
	check(LP.needed(doc).is_empty() and by.head.kind == "part" and by.eyes.count == 2, "drawn parts show their shape count")
	check(by["leg-front-far"].kind == "auto" and by["eyes-closed"].kind == "auto", "far legs and closed eyes are automatic")
	check(by.body.kind == "auto" and by.body.pose and by.body.from == "walk-body", "the sitting pose has Draw this pose, from walking")
	check(by["ear-r"].kind == "empty" and by.nose.kind == "empty" and "nose twitches" in by.nose.note, "an empty optional part says what it costs (%s)" % by.nose.note)
	check(rows.any(func(r): return r.kind == "more") and not by.has("wing"), "the extras fold into one row")
	check(LP.rows(doc, "wing").any(func(r): return r.get("part", "") == "wing"), "unless one of them is picked")
	check(LP.rows(doc, "", true).any(func(r): return r.get("part", "") == "wing"), "or they are opened")
	check(LP.pose_of("side", "loaf-body") == "nap" and LP.pose_of("side", "head") == "" and LP.pose_of("front", "body") == "sit", "each part shows its pose")
	check(LP.part_name("blob", "ear-l") == "Antenna or fin" and LP.part_name("side", "leg-front") == "Front leg", "parts have plain names")


func _window() -> void:
	# The Studio's sizes: a 1366 x 768 screen (a 40 px taskbar) at 100%, and
	# 1920 x 1080 at 150%.
	var SW = load("res://gui/studio/studio_window.gd")
	for t in [[Vector2(1366, 728), 1.0], [Vector2(1920, 1032), 1.5], [Vector2(1280, 680), 1.25]]:
		var f: Dictionary = SW.fit_for(t[0], t[1])
		var usable: Vector2 = t[0]
		var mn: Vector2i = f.min
		var sz: Vector2i = f.size
		check(mn.x <= usable.x and mn.y <= usable.y and sz.x >= mn.x - 1 and sz.y >= mn.y - 1 and sz.x <= usable.x and sz.y <= usable.y,
			"on %s at %d%%, the Studio opens within the screen at its minimum or more (min %s, opens %s)" % [usable, roundi(t[1] * 100), mn, sz])
		check(absf(mn.x / f.scale - SW.MIN_W) < 2.0 and absf(mn.y / f.scale - SW.MIN_H) < 2.0, "and its minimum is the design's %d x %d, scaled" % [SW.MIN_W, SW.MIN_H])
	check(SW.fit_for(Vector2(3840, 2100), 1.0).scale == 1.0, "a big screen draws it at the display scale")


func _script() -> void:
	# The Admin page's Build the test critter by script, headless.
	var doc := Tools.blank("side")
	var h := History.new()
	for step in Fixtures.studio_steps():
		step.call(doc, h)
	var stored = JSON.parse_string(FileAccess.get_file_as_string(STORED))
	check(typeof(stored) == TYPE_DICTIONARY, "the stored test critter reads")
	var got := JSON.stringify(JSON.parse_string(JSON.stringify(doc)), "", true)
	check(typeof(stored) == TYPE_DICTIONARY and got == JSON.stringify(stored, "", true), "the scripted critter matches test_critter.json")
	if typeof(stored) == TYPE_DICTIONARY and got != JSON.stringify(stored, "", true):
		print("  got: ", got)
	check(Writer.clean_doc(doc).warnings.is_empty() and LP.needed(doc).is_empty(), "it is within the limits, with every needed part")
	check(not doc.layers.has("nose") and h.can_undo(), "the undone nose is gone")
	var svgs := Writer.write(doc)
	var drew := true
	for part in svgs:
		var img := Image.new()
		if img.load_svg_from_string(svgs[part], 0.5) != OK or img.get_used_rect().size.x < 2:
			drew = false
	check(drew and svgs.has("eyes-closed"), "every layer it made draws (and closed eyes come free)")


func _gui() -> void:
	# The window built without showing it (no window opens): placing, a
	# drag, undo and redo by key, delete, Draw this pose, and the layers
	# rasterised, through the same calls the mouse and keys make.
	var w: Window = load("res://gui/studio/studio_window.gd").new()
	root.add_child(w)
	w.load_doc({})
	w.build()
	var cv: Control = w.canvas
	check(w.part == "walk-body" and w._layers_box.get_child_count() == 1, "a blank Studio picks the first needed part, the body")
	w.pick_part("head")
	w.set_tool("ellipse")
	cv.zoom = 2.0
	cv.origin = Vector2(100, 300)
	cv._button(_click(cv.to_px(Vector2(148, 200)), true))
	var head := Tools.layer(w.doc, "head")
	check(head.size() == 1 and head[0].x == 150.0 and w.tool == "move" and w.sel == [0], "a click with the oval places one, snapped to the middle, picked, and back to Move")
	cv._press(Vector2(150, 200), false)
	var mv := InputEventMouseMotion.new()
	mv.position = cv.to_px(Vector2(180, 210))
	cv._motion(mv)
	cv._release()
	check(Tools.layer(w.doc, "head")[0].x == 180.0 and Tools.layer(w.doc, "head")[0].y == 210.0, "a drag moves it")
	check(w.key(_key(KEY_Z, true)) and Tools.layer(w.doc, "head")[0].x == 150.0, "Ctrl+Z undoes the drag in one step")
	check(w.key(_key(KEY_Y, true)) and Tools.layer(w.doc, "head")[0].x == 180.0, "Ctrl+Y redoes it")
	w.sel = [0]
	var hs := Tools.handles(Tools.layer(w.doc, "head")[0], cv.zoom)
	var corner: Vector2 = hs.filter(func(x): return x[0] == "s:1:1")[0][1]
	cv._press(corner, false)
	mv.position = cv.to_px(corner + Vector2(20, 10))
	cv._motion(mv)
	cv._release()
	check(Tools.layer(w.doc, "head")[0].w == 80.0 and Tools.layer(w.doc, "head")[0].h == 60.0, "a corner handle drag scales it")
	w.key(_key(KEY_RIGHT, false, true))
	check(Tools.layer(w.doc, "head")[0].x == 200.0, "Shift and an arrow nudge it by 10")
	w.key(_key(KEY_C, true))
	w.pick_part("walk-body")
	w.key(_key(KEY_V, true))
	check(Tools.layer(w.doc, "walk-body").size() == 1 and w.sel == [0], "Ctrl+C and Ctrl+V copy it to another layer")
	w.draw_pose("body", "walk-body")
	check(w.part == "body" and w.pose == "sit" and Tools.layer(w.doc, "body").size() == 1, "Draw this pose copies walking and shows sitting")
	w.pick_part("head")
	w.sel = [0]
	w.key(_key(KEY_DELETE))
	check(not w.doc.layers.has("head"), "Del deletes")
	cv._process(0.0)
	check(cv.tex.has("walk-body") and cv.tex.has("body") and not cv.tex.has("head"), "the drawn layers are rasterised, the emptied one dropped")
	w.pick_part("walk-body")
	check(cv.shown_parts() == ["walk-body"], "the canvas shows the walking pose's layers (%s)" % [cv.shown_parts()])
	# Shown (headless, so nothing opens) to draw: a faces-you critter with
	# its eyes picked, zoomed in to the grid.
	studio = w
	w.load_doc({"plan": "front"})
	w.build()
	w.size = Vector2i(1280, 800)
	w.show()
	w.pick_part("eyes")
	w.place("eye", Vector2(130, 140))
	check(Tools.layer(w.doc, "eyes").size() == 2, "on a faces-you critter an eye comes with its twin")
	w.canvas.set_zoom(2.5)
	w.canvas.draw.connect(func(): drawn += 1)


func _help_data() -> void:
	# The hint cards: every part of every plan has one, with 1 to 3 shapes.
	var bad := []
	for plan in LP.LAYOUT:
		var doc := Tools.blank(plan)
		for g in LP.LAYOUT[plan]:
			for part in g[2]:
				var h := Help.hint_for(doc, part)
				var ok: bool = h.text != "" and str(h.title).begins_with("Add a shape to draw") and h.shapes.size() >= 1 and h.shapes.size() <= 3
				if not ok or not h.shapes.all(func(t): return t in Shapes.TYPES):
					bad.append("%s %s" % [plan, part])
	check(bad.is_empty(), "every part has a hint card with 1 to 3 shapes (%s)" % [bad])
	var tail := Help.hint_for(Tools.blank("side"), "tail")
	check(tail.title == "Add a shape to draw the tail" and tail.shapes.size() >= 2, "the tail's card offers two or more shapes (%s)" % [tail.shapes])
	check(str(Help.hint_for(Tools.blank("side"), "leg-front-far").title).contains("your own"), "an automatic part's card says it's made for you")
	var head := Help.hint_for(Tools.blank("side"), "head")
	check(head.at != Vector2(150, 170), "a part goes where the round cat has it (%s)" % head.at)
	# The tool rail's keys are the ? panel's.
	var SW = load("res://gui/studio/studio_window.gd")
	var listed := Help.listed()
	for t in SW.TOOLS:
		if not t.is_empty() and t[2] != "":
			check(t[2] in listed, "the %s tool's key %s is in the ? panel" % [t[1], t[2]])


func _help() -> void:
	# A second window with settings of its own (never saved: not in the tree).
	var w: Window = load("res://gui/studio/studio_window.gd").new()
	helpw = w
	root.add_child(w)
	fake = FakeMain.new()
	fake.settings = load("res://settings.gd").new()
	fake.settings.path = "user://studio_test_settings.json"
	w.main = fake
	check(fake.settings.value("studio.tips_seen") == false, "studio.tips_seen starts false")
	# The tips: once, then never again until the key is reset.
	w.load_doc({})
	w.build()
	check(w.tip_i == 0 and w._tip_box != null, "a first visit shows the first tip")
	w.place("ellipse", Vector2(160, 200))
	check(w.tip_i == 1, "putting a shape down moves on to the second tip")
	w.next_tip()
	check(w.tip_i == 2 and w._tip_box != null, "Next tip shows the third")
	w.next_tip()
	check(w.tip_i == -1 and w._tip_box == null and fake.settings.value("studio.tips_seen") == true, "Got it closes them and remembers")
	w.build()
	check(w.tip_i == -1 and w._tip_box == null, "with the key true, the tips don't show again")
	fake.settings.set_value("studio.tips_seen", false)
	w.load_doc({})
	w.build()
	check(w.tip_i == 0, "with the key false again, they show again")
	w.key(_key(KEY_ESCAPE))
	check(w.tip_i == -1 and not w.doc.is_empty() and fake.settings.value("studio.tips_seen") == true, "Esc skips the tips (and doesn't leave)")
	# The hint card on an empty part.
	w.pick_part("tail")
	check(not w.hint_now.is_empty() and w._hint_box != null and w.hint_now.shapes.size() >= 2, "an empty tail shows its hint card")
	w.use_hint(w.hint_now.shapes[0])
	check(Tools.layer(w.doc, "tail").size() == 1 and w.hint_now.is_empty(), "a shape from the card draws the tail and the card goes")
	w.pick_part("nose")
	w.skip_hint()
	check(w.hint_now.is_empty() and Tools.layer(w.doc, "nose").is_empty(), "Skip hides the card")
	# Save with parts missing says which.
	w.open_save()
	var said := _texts(w.overlay)
	var need := LP.needed(w.doc)
	var named := need.all(func(p): return said.contains(LP.part_name(w.doc.plan, p)))
	check(w.overlay_kind == "missing" and named and said.contains("more parts and it can walk"), "Save with parts missing names them (%s)" % said.left(160))
	w.close_overlay()
	# ? lists every key the window answers to.
	var cat := StartPage.starter("round-cat")
	w.load_doc(cat.doc)
	w.build()
	w.key(_key(KEY_SLASH, false, true, 63))
	said = _texts(w.overlay)
	var rows_ok := true
	for g in Help.SHORTCUTS:
		for row in g[1]:
			rows_ok = rows_ok and said.contains(row[0])
	check(w.overlay_kind == "keys" and rows_ok, "? opens the shortcuts, with every row")
	w.key(_key(KEY_SLASH, false, true, 63))
	check(w.overlay == null, "and ? closes it")
	w.set_view_mode("pins")
	w.set_tool("ellipse")
	check(w.view_mode == "shapes" and w.tool == "ellipse", "a shape tool in Pins mode goes back to Shapes with it")
	var listed := Help.listed()
	var unlisted := []
	var probe: Array = [KEY_DELETE, KEY_BACKSPACE, KEY_PAGEUP, KEY_PAGEDOWN, KEY_ESCAPE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
		KEY_F1, KEY_HOME, KEY_END, KEY_TAB, KEY_ENTER, KEY_INSERT, KEY_SPACE]
	for k in range(KEY_A, KEY_Z + 1):
		probe.append(k)
	for k in range(KEY_0, KEY_9 + 1):
		probe.append(k)
	for k in probe:
		for mods in [[false, false], [true, false], [true, true]]:
			if w.doc.is_empty() or w.canvas == null:
				w.load_doc(cat.doc)
				w.build()
			w.close_overlay()
			if w.view_mode != "shapes":
				w.set_view_mode("shapes")
			var e := _key(k, mods[0], mods[1])
			if w.key(e) and not Help.key_name(e) in listed:
				unlisted.append(Help.key_name(e))
	check(unlisted.is_empty(), "every key the Studio answers to is in the ? panel (not listed: %s)" % [unlisted])
	w.load_doc(cat.doc)
	w.build()


func _tooltips() -> void:
	# Every button in the window (no dialog open) has a tooltip; a tool's
	# names its key.
	var w := helpw
	var none := _untipped(w)
	check(none.is_empty(), "every button in the Studio has a tooltip (not: %s)" % [none])
	for b in w._rail.get_children():
		if b is Button:
			var tip := (b as Button).tooltip_text
			check(tip.contains("(") or tip.begins_with("Pan"), "a tool's tooltip names its key (%s)" % tip)
	w.set_view_mode("pins")


func _untipped(n: Node) -> Array:
	var out := []
	for ch in n.get_children():
		if ch.is_queued_for_deletion():
			continue
		if ch is BaseButton and (ch as BaseButton).tooltip_text == "":
			out.append(str((ch as Button).text) if ch is Button else ch.get_class())
		out.append_array(_untipped(ch))
	return out


func _texts(n: Node) -> String:
	# Every label's text under n, joined.
	if n == null:
		return ""
	var out := ""
	if n is Label:
		out += (n as Label).text + " | "
	for ch in n.get_children():
		out += _texts(ch)
	return out


func _click(at: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = at
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	return e


func _key(k: Key, ctrl := false, shift := false, uni := 0) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.unicode = uni
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	return e
