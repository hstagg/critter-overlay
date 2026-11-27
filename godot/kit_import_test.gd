extends SceneTree
## Headless checks for kit_import.gd (docs/custom-critters-build-plan.md, C1
## and C4): an untouched template imports as its example critter (the round
## trip), the same parts as PNGs do too, a drawing floating above the line
## is grounded, and a missing part is named.
## Run: godot --headless --path godot --script res://kit_import_test.gd

const Import := preload("res://kit_import.gd")
const Clean := preload("res://svg_clean.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const Fixtures := preload("res://critters/kit/fixtures.gd")
const Customs := preload("res://customs.gd")

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


func rect_near(a: Rect2, b: Rect2, eps: float) -> bool:
	return a.position.distance_to(b.position) <= eps and a.end.distance_to(b.end) <= eps


func same_rig(a: Dictionary, b: Dictionary, eps: float, what: String) -> void:
	check(absf(a.leg_len - b.leg_len) <= eps and absf(a.critter_scale - b.critter_scale) <= 0.01, "%s: leg length and size match (%.1f/%.1f, %.3f/%.3f)" % [what, a.leg_len, b.leg_len, a.critter_scale, b.critter_scale])
	for pose in ["walk", "sit", "loaf"]:
		check(a.head_at[pose].distance_to(b.head_at[pose]) <= eps, "%s: head where it should be, %s (%s vs %s)" % [what, pose, a.head_at[pose], b.head_at[pose]])
		check(rect_near(a.hit_bounds[pose], b.hit_bounds[pose], eps + 2.0), "%s: %s box matches (%s vs %s)" % [what, pose, a.hit_bounds[pose], b.hit_bounds[pose]])
	check(a.auto.keys() == b.auto.keys(), "%s: the same parts filled in (%s vs %s)" % [what, a.auto, b.auto])


func _init() -> void:
	var root := "user://kit_import_test"
	clear_dir(root)
	for plan in ["side", "front", "upright", "blob"]:
		var fx := root.path_join("fixture_" + plan)
		match plan:
			"side":
				Fixtures.kitten_kit(fx)
			"front":
				Fixtures.otter_kit(fx)
			"upright":
				Fixtures.duckling_kit(fx)
			"blob":
				Fixtures.blob_kit(fx, "slime")
		var fk = JSON.parse_string(FileAccess.get_file_as_string(fx.path_join("kit.json")))
		var want := KitData.build(fx, fk)

		# The template, untouched, as SVG.
		var tpath := ProjectSettings.globalize_path("res://templates/%s-1.svg" % plan)
		var st := Import.stage(tpath)
		check(st.error == "" and st.plan == plan and st.missing.is_empty() and st.unmatched.is_empty(), "%s template stages (%s %s %s %s)" % [plan, st.error, st.plan, st.missing, st.unmatched])
		check(st.gait == fk.gait, "%s template keeps its gait (%s)" % [plan, st.gait])
		var out := Import.write(st, "Template " + plan, root.path_join("svg_" + plan))
		var k = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("kit.json")))
		same_rig(KitData.build(out, k), want, 1.0, "%s template as SVG" % plan)

		# The same parts as 2x PNGs, as from a raster app.
		var png_dir := root.path_join("pngs_" + plan)
		DirAccess.make_dir_recursive_absolute(png_dir)
		for p in st.parts:
			var img := Image.new()
			img.load_svg_from_string(st.parts[p].svg, 2.0)
			img.save_png(png_dir.path_join(p + ".png"))
		var sp := Import.stage(ProjectSettings.globalize_path(png_dir), plan)
		check(sp.error == "" and sp.missing.is_empty(), "%s as PNGs stages (%s %s)" % [plan, sp.error, sp.missing])
		var pout := Import.write(sp, "PNG " + plan, root.path_join("png_" + plan))
		var pk = JSON.parse_string(FileAccess.get_file_as_string(pout.path_join("kit.json")))
		same_rig(KitData.build(pout, pk), want, 2.0, "%s as PNGs" % plan)

	# --- Grounding: a kit drawn 20 units above the line is brought down.
	var high_dir := root.path_join("high")
	var st2 := Import.stage(ProjectSettings.globalize_path("res://templates/side-1.svg"))
	for p in st2.parts:
		var s: String = st2.parts[p].svg
		var a := s.find(">", s.find("<svg")) + 1
		st2.parts[p].svg = s.substr(0, a) + '<g transform="translate(0 -20)">' + s.substr(a, s.rfind("</svg>") - a) + "</g></svg>"
	for k in st2.pins:
		st2.pins[k] = [st2.pins[k][0], st2.pins[k][1] - 20]
	var before: Dictionary = st2.pins.duplicate(true)
	Import.write(st2, "High", high_dir)
	var hk = JSON.parse_string(FileAccess.get_file_as_string(high_dir.path_join("kit.json")))
	var hr := KitData.build(high_dir, hk)
	check(absf(hr.ground_dy) <= 1.0, "a kit drawn above the line is grounded (%.1f off)" % hr.ground_dy)
	check(st2.pins == before and hk.pins != before, "grounding leaves the staged pins in the file's frame")
	Import.write(st2, "High", root.path_join("high2"))
	var hk2 = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("high2/kit.json")))
	check(hk2.pins == hk.pins, "so writing it again gives the same kit")

	# --- Joints dragged on the kit page (C4): within 60 units, hips below the neck.
	var sj := Import.stage(ProjectSettings.globalize_path("res://templates/side-1.svg"))
	var hip: Vector2 = Import.base_pins(sj)["hip-back"]
	check(Import.move_pin(sj, "hip-back", hip + Vector2(100, 0)) == hip + Vector2(60, 0), "a joint stops 60 units from where it was")
	var neck := Import.pin_now(sj, "neck-walk")
	check(Import.move_pin(sj, "hip-front", Vector2(neck.x, neck.y - 30)).y > neck.y, "a hip stays below the neck")
	check(Import.move_pin(sj, "neck-walk", neck + Vector2(5, 5)) == neck + Vector2(5, 5) and Import.pin_now(sj, "head") == neck + Vector2(5, 5), "the neck takes the head's pivot with it")
	var again := Import.stage(ProjectSettings.globalize_path("res://templates/side-1.svg"))
	Import.with_moved(again, sj.moved)
	check(Import.pin_now(again, "hip-back") == hip + Vector2(60, 0) and Import.pin_now(again, "neck-walk") == neck + Vector2(5, 5), "laid over the file again after a reload")

	# --- Where's its head? (F1): the adjusted ellipse is kit.json's head, and the rig's.
	again["head_adj"] = {"dx": 8.0, "dy": -4.0, "kx": 1.25, "ky": 0.9}
	Import.write(again, "Head", root.path_join("head"))
	var hj = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("head/kit.json")))
	var m: Dictionary = again.head_measured
	check(absf(float(hj.head.cx) - float(m.cx) - 8.0) < 0.01 and absf(float(hj.head.rx) - float(m.rx) * 1.25) < 0.01 and absf(float(hj.head.ry) - float(m.ry) * 0.9) < 0.01,
		"the adjusted head is stored")
	check(absf(float(hj.head.eye_y) - float(m.eye_y)) < 0.01, "the eyes stay where they were measured")
	var hb := KitData.build(root.path_join("head"), hj)
	check(absf(float(hb.head.cx) - float(hj.head.cx)) < 0.01 and absf(float(hb.head.rx) - float(hj.head.rx)) < 0.01, "and the rig dresses that head")
	var back_adj := Import.head_adj_between(m, Import.adjusted_head(m, again.head_adj))
	check(absf(float(back_adj.dx) - 8.0) < 0.01 and absf(float(back_adj.ky) - 0.9) < 0.001, "an adjustment can be worked back from a head")
	check(absf(float(Import.adjusted_head(m, {"dx": 500.0}).cx) - float(m.cx) - Import.HEAD_ADJ_MOVE) < 0.01, "and it can't run off the head")

	# --- A missing part is named, and nothing is written.
	var bare := root.path_join("bare.svg")
	var f := FileAccess.open(bare, FileAccess.WRITE)
	f.store_string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280"><g id="walk body"><circle cx="150" cy="200" r="50"/></g><g id="head"><circle cx="110" cy="150" r="40"/></g><g id="scribbles"><circle cx="10" cy="10" r="4"/></g></svg>')
	f.close()
	var sb := Import.stage(ProjectSettings.globalize_path(bare), "side")
	check(sb.missing.has("eyes") and sb.missing.has("leg-front") and sb.unmatched.has("scribbles"), "missing parts and stray layers are listed (%s, %s)" % [sb.missing, sb.unmatched])
	check(Import.write(sb, "Bare", root.path_join("nope")) == "", "nothing is written while parts are missing")

	# --- An imported kit loads and walks.
	Customs.dir = root.path_join("store")
	DirAccess.make_dir_recursive_absolute(Customs.dir)
	Customs.all_ways_on()
	var id := Customs.add_folder(root.path_join("svg_side"))
	check(id != "" and Customs.all[id]["_kit"]["made_with"] == "svg", "an imported kit joins the store")
	Customs.ways.clear()

	clear_dir(root)
	print("KIT IMPORT TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
