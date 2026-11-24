extends SceneTree
## Headless checks for side-on kits (docs/custom-critters-build-plan.md, B1):
## the kitten rebuilt as a kit comes out with the kitten's numbers, a bare kit
## with only the required parts fills the rest in from its own art, the
## behaviour table never offers a move a kit can't draw, and both walk, sit,
## nap and blink.
## Run: godot --headless --path godot --script res://kit_test.gd

const Customs := preload("res://customs.gd")
const Species := preload("res://species.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const Fixtures := preload("res://critters/kit/fixtures.gd")

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


func spawn(id: String, mode := "walk"):
	var c = Species.row(id)["script"].new()
	c.species = id
	c.idles = Species.row(id)["idles"]
	world.add_child(c)
	c.setup(world, 600.0, -1, mode)
	return c


func shown(n: Node) -> bool:
	# Visible all the way up (the tree isn't running in _init, so
	# is_visible_in_tree() can't be used).
	while n != null and n is CanvasItem:
		if not n.visible:
			return false
		n = n.get_parent()
	return true


func rect_near(a: Rect2, b: Rect2, eps: float) -> bool:
	return a.position.distance_to(b.position) <= eps and a.end.distance_to(b.end) <= eps


func _init() -> void:
	world = World.new()
	get_root().add_child(world)
	var root := "user://kit_test"
	clear_dir(root)
	Customs.dir = root.path_join("store")
	DirAccess.make_dir_recursive_absolute(Customs.dir)
	var src := root.path_join("src")
	Fixtures.kitten_kit(src.path_join("kitten_side"))
	Fixtures.kitten_kit(src.path_join("bare_side"), true)
	Fixtures.kitten_kit(src.path_join("hop_side"), true, "hop")

	# --- The gate: no kits while the kit way is off.
	Customs.ways.clear()
	check(Customs.add_folder(src.path_join("kitten_side")) == "", "a kit is refused while the kit way is off")
	Customs.all_ways_on()

	# --- The kitten as a kit.
	var kid := Customs.add_folder(src.path_join("kitten_side"))
	check(kid != "" and Customs.all.has(kid), "the kitten kit loads")
	var d: Dictionary = Customs.all[kid]
	var r := KitData.build(str(d["_dir"]), d["_kit"])
	var kitten = spawn("kitten")
	check(absf(r.leg_len - kitten.leg_len) <= 2.0, "leg length within 2 of the kitten's (%.1f vs %.1f)" % [r.leg_len, kitten.leg_len])
	check(absf(r.critter_scale - kitten.critter_scale) <= 0.01, "size the kitten's (%.3f vs %.3f)" % [r.critter_scale, kitten.critter_scale])
	for pose in ["walk", "sit", "loaf"]:
		var got: Rect2 = r.hit_bounds[pose]
		var want: Rect2 = kitten.hit_bounds[pose]
		# The kitten's boxes are trimmed by hand; a kit's is all it draws
		# plus 4 (4.7), so it holds the kitten's and is a little larger.
		check(got.encloses(want) and rect_near(got, want, 40.0), "%s hit box holds the kitten's and is near it (%s vs %s)" % [pose, got, want])
	check(r.head_at.walk == kitten.head_at.walk and r.head_at.sit == kitten.head_at.sit and r.head_at.loaf == kitten.head_at.loaf, "the head sits where the kitten's does")
	check(r.tail_at.walk == kitten.tail_at.walk and r.tail_at.sit == kitten.tail_at.sit, "and the tail")
	check(absf(r.ground_dy) <= 2.0, "the kitten kit stands on the ground (%.1f off)" % r.ground_dy)
	check(r.auto.is_empty() or r.auto.keys() == [], "nothing filled in for the kitten kit (%s)" % str(r.auto))
	var kidles: Array = Species.row(kid)["idles"]
	for b in ["sit_and_look", "nap", "stretch", "yawn", "sneeze", "ear_flick", "tail_swish", "chase_tail", "hunt", "scratch", "shake_off"]:
		check(b in kidles, "the kitten kit can %s" % b)
	check(not "groom" in kidles, "no groom without groom paws")
	kitten.free()

	# --- A required part missing: refused, by name.
	var nohead := src.path_join("nohead")
	Fixtures.kitten_kit(nohead, true)
	DirAccess.remove_absolute(nohead.path_join("parts/head.svg"))
	var k = JSON.parse_string(FileAccess.get_file_as_string(nohead.path_join("kit.json")))
	check(KitData.missing(nohead, k) == ["head"], "a kit with no head is missing the head (%s)" % str(KitData.missing(nohead, k)))
	check(Customs.add_folder(nohead) == "", "and is refused")
	var nopin: Dictionary = k.duplicate(true)
	nopin.pins.erase("hip-back")
	check("the hip-back pin" in KitData.missing(src.path_join("bare_side"), nopin), "a missing required pin is named")

	# --- The bare kit: everything else from its own art.
	var bid := Customs.add_folder(src.path_join("bare_side"))
	check(bid != "", "the bare kit loads")
	var bd: Dictionary = Customs.all[bid]
	var br := KitData.build(str(bd["_dir"]), bd["_kit"])
	for part in ["leg-front-far", "leg-back-far", "body", "loaf-body", "eyes-closed"]:
		check(br.auto.has(part), "the bare kit's %s is filled in (%s)" % [part, br.auto.get(part, "none")])
	check(br.images.has("leg-front-far") and br.images.has("loaf-body"), "with images of its own")
	var near_px: Color = br.images["leg-front"].get_pixelv(br.images["leg-front"].get_used_rect().get_center())
	var far_px: Color = br.images["leg-front-far"].get_pixelv(br.images["leg-front"].get_used_rect().get_center())
	check(far_px.a > 0.5 and absf(far_px.r - near_px.r * KitData.FAR_TINT) < 0.02, "the far leg is the near one, darker")
	var bidles: Array = Species.row(bid)["idles"]
	for b in ["tail_swish", "chase_tail", "ear_flick", "yawn", "sneeze", "nose_twitch", "groom", "scratch", "stand_lookout"]:
		check(not b in bidles, "the bare kit is never given %s" % b)
	for b in ["sit_and_look", "nap", "stretch", "shake_off", "hunt"]:
		check(b in bidles, "the bare kit can %s" % b)

	# --- The table: no kit gets a move touching a part it lacks.
	var parts_of := {"tail_swish": "tail", "chase_tail": "tail", "yawn": "mouth-open", "sneeze": "mouth-open",
		"nose_twitch": "nose", "stand_lookout": "stand-body", "groom": "groom-paws", "scratch": "scratch-foot"}
	var all_parts: Array = KitData.PLANS.side.required + KitData.PLANS.side.optional
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var bad := 0
	for i in 200:
		var have: Array = KitData.PLANS.side.required.duplicate()
		for p in KitData.PLANS.side.optional:
			if rng.randf() < 0.5:
				have.append(p)
		for b in Customs.idles_for({"plan": "side", "gait": "trot"}, have):
			if parts_of.has(b) and not parts_of[b] in have:
				bad += 1
			if b == "ear_flick" and not ("ear-l" in have or "ear-r" in have):
				bad += 1
	check(bad == 0, "200 random kits never get a move for a part they lack")
	check(not "hunt" in Customs.idles_for({"plan": "side", "gait": "hop"}, all_parts), "a hopping kit doesn't hunt")

	# --- Both walk, sit, nap with a body, and blink.
	for id in [kid, bid, Customs.add_folder(src.path_join("hop_side"))]:
		var c = spawn(id)
		var name: String = Customs.all[id]["name"] + (" (hop)" if c.gs.name == "hop" else "")
		var x0: float = c.position.x
		c.vx = c.facing * c.cruise
		for i in 90:
			c.tick(1.0 / 30.0)
			if c.mode != "walk":
				c._go_walk()
		check(absf(c.position.x - x0) > 5.0, "%s walks (moved %.0f px)" % [name, c.position.x - x0])
		check(c.region_rect().size.x > 10.0 and c.hit_rect().size.y > 10.0, "%s has a size on screen" % name)
		c._go_sit()
		c.tick(0.1)
		var sitting_body: bool = (c.sit_body.get_child_count() > 0 and c.sit_body.visible) or (c.walk_body.visible and c.legs_node.visible)
		check(sitting_body, "%s sits with a body" % name)
		c._go_loaf(5.0)
		c.tick(0.1)
		check(c.loaf_body != null and shown(c.loaf_body) and c.loaf_body.texture.get_size().x > 0, "%s naps with a body (pose %s, mode %s, shown %s)" % [name, c.pose, c.mode, c.loaf_body.visible if c.loaf_body else "none"])
		check(not c.legs_node.visible and not c.walk_body.visible, "%s hides its legs and walking body to nap" % name)
		if c.loaf_body != null:
			var bottom: Vector2 = c.loaf_body.get_global_transform() * Vector2(c.loaf_body.texture.get_image().get_used_rect().end)
			check(absf(bottom.y - world.floor_y) < 8.0, "%s's nap rests on the ground (%.1f vs %.1f)" % [name, bottom.y, world.floor_y])
		c._go_sit()
		c.blink_left = c.blink_len * 0.5
		c.tick(0.0)
		check(c.eyes.scale.y < 0.5, "%s blinks" % name)
		c.vx = 0.0
		c.start_behaviour("shake_off", 0.8)
		for i in 10:
			c.tick(1.0 / 30.0)
		check(c.act == "shake_off", "%s shakes off" % name)
		c.free()

	# --- An edit makes new art: the rig and textures are keyed by rev.
	var before := Customs.tex_key(kid)
	Customs.bump_rev(kid)
	check(Customs.tex_key(kid) != before and not KitData._rigs.has(before), "a rev bump drops the old rig")

	Customs.ways.clear()
	clear_dir(root)
	print("KIT TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
