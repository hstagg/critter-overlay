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


func faces_you(src: String) -> void:
	# B2: the otter as a faces-you kit, and a kit with one face.
	Fixtures.otter_kit(src.path_join("otter_front"))
	Fixtures.otter_kit(src.path_join("one_face"), true, "plod")
	var oid := Customs.add_folder(src.path_join("otter_front"))
	check(oid != "", "the otter kit loads")
	if oid == "":
		return
	var d: Dictionary = Customs.all[oid]
	var r := KitData.build(str(d["_dir"]), d["_kit"])
	var otter = spawn("otter")
	var shift := Fixtures.OTTER_SHIFT
	check(absf(r.leg_len - otter.leg_len) <= 2.0, "otter kit: leg length within 2 of the otter's (%.1f vs %.1f)" % [r.leg_len, otter.leg_len])
	check(r.head_at.sit == otter.head_at.sit + shift and r.head_at.walk == otter.head_at.walk + shift, "otter kit: the head sits and walks where the otter's does")
	check(r.side_pivot == otter.side_pivot + shift, "otter kit: the side face's neck is the otter's")
	# F1: the clothes shift between faces is the crown's move (P15).
	check(r.wear_walk_shift.distance_to(otter.wear_walk_shift) <= 10.0, "otter kit: clothes move to the side face about as far as the otter's (%s vs %s)" % [r.wear_walk_shift, otter.wear_walk_shift])
	for pose in ["walk", "sit"]:
		var got: Rect2 = r.hit_bounds[pose]
		var want: Rect2 = otter.hit_bounds[pose]
		want.position += shift
		# The otter's boxes have hand-set slack and its walk has a tail of its
		# own (tail-side); a kit's box is what it draws, so it sits inside.
		var share := got.get_area() / want.get_area()
		check(want.grow(6.0).encloses(got) and share > 0.6, "otter kit: %s hit box inside the otter's and most of it (%s vs %s, %.2f)" % [pose, got, want, share])
	check(r.two_faces and r.auto.is_empty(), "otter kit: two faces, nothing filled in (%s)" % str(r.auto))
	otter.free()
	var oidles: Array = Species.row(oid)["idles"]
	check("groom" in oidles and "yawn" in oidles and not "hunt" in oidles and not "chase_tail" in oidles, "otter kit's moves (%s)" % ", ".join(oidles))

	var fid := Customs.add_folder(src.path_join("one_face"))
	check(fid != "", "the one-face kit loads")
	var fd: Dictionary = Customs.all[fid]
	var fr := KitData.build(str(fd["_dir"]), fd["_kit"])
	check(fr.auto.get("head-side") == "front face" and fr.auto.get("ear-r") == "mirror" and fr.auto.get("loaf-body") == "melt", "one-face kit: front face walking, mirrored ear, melted nap (%s)" % str(fr.auto))
	for id in [oid, fid]:
		var c = spawn(id)
		var name: String = Customs.all[id]["name"]
		c.vx = c.facing * c.cruise
		var x0: float = c.position.x
		for i in 240:
			c.tick(1.0 / 30.0)
			if c.mode != "walk":
				c._go_walk()
		check(absf(c.position.x - x0) > 5.0, "%s walks" % name)
		var face: Array = c.front_parts.filter(func(n): return n != c.mouth_open)   # the mouth opens only to yawn
		var front_shown: bool = face.all(func(n): return n.visible)
		if id == fid:
			check(c.head_side == null and front_shown, "%s keeps its front face while walking" % name)
		else:
			check(c.head_side.visible and not front_shown, "%s walks with its side face" % name)
		c._go_sit()
		c.tick(0.1)
		check(face.all(func(n): return n.visible) and c.sit_body.visible, "%s sits facing you" % name)
		c._go_loaf(5.0)
		c.tick(0.1)
		check(c.loaf_body != null and shown(c.loaf_body), "%s naps with a body" % name)
		c._go_sit()
		c.blink_left = c.blink_len * 0.5
		c.tick(0.0)
		check(c.eyes.scale.y < 0.5 or (c.eyes_shut != null and c.eyes_shut.visible), "%s blinks" % name)
		c.free()


func upright(src: String) -> void:
	# B3: the duckling as an upright kit, and a bare one.
	Fixtures.duckling_kit(src.path_join("duck_up"))
	Fixtures.duckling_kit(src.path_join("bare_up"), true, "hop")
	var did := Customs.add_folder(src.path_join("duck_up"))
	check(did != "", "the duckling kit loads")
	if did == "":
		return
	var d: Dictionary = Customs.all[did]
	var r := KitData.build(str(d["_dir"]), d["_kit"])
	var duck = spawn("duckling")
	var shift := Fixtures.DUCKLING_SHIFT
	check(absf(r.leg_len - duck.leg_len) <= 2.0, "duckling kit: leg length within 2 (%.1f vs %.1f)" % [r.leg_len, duck.leg_len])
	check(r.head_at.sit == duck.head_at.sit + shift and r.head_at.walk == duck.head_at.walk + shift and r.head_at.loaf == duck.head_at.loaf + shift, "duckling kit: the head where the duckling's is")
	check(r.walk_legs[0][1] == duck.walk_legs[0][1] + shift and r.walk_legs[1][1] == duck.walk_legs[1][1] + shift, "duckling kit: its legs on the duckling's hips")
	check(r.tail_at.has("walk") and not r.tail_at.has("sit"), "duckling kit: the tail shows only walking")
	check(r.auto.is_empty(), "duckling kit: nothing filled in (%s)" % str(r.auto))
	for pose in ["walk", "sit", "loaf"]:
		var got: Rect2 = r.hit_bounds[pose]
		var want: Rect2 = duck.hit_bounds[pose]
		want.position += shift
		var share := got.get_area() / want.get_area()
		check(want.grow(10.0).encloses(got) and share > 0.6, "duckling kit: %s hit box inside the duckling's and most of it (%s vs %s, %.2f)" % [pose, got, want, share])
	duck.free()
	var didles: Array = Species.row(did)["idles"]
	for b in ["preen", "peck_ground", "groom", "ear_flick", "yawn", "tail_swish", "stretch"]:
		check(b in didles, "duckling kit can %s" % b)
	check(not "hunt" in didles and not "chase_tail" in didles, "and doesn't hunt or chase its tail")

	var bid := Customs.add_folder(src.path_join("bare_up"))
	check(bid != "", "the bare upright kit loads")
	var bd: Dictionary = Customs.all[bid]
	var br := KitData.build(str(bd["_dir"]), bd["_kit"])
	for part in ["leg-far", "walk-body", "wing-r", "wing-side", "loaf-body"]:
		check(br.auto.has(part), "bare upright kit: %s filled in" % part)
	for id in [did, bid]:
		var c = spawn(id)
		var name: String = Customs.all[id]["name"]
		c.vx = c.facing * c.cruise
		var x0: float = c.position.x
		for i in 120:
			c.tick(1.0 / 30.0)
			if c.mode != "walk":
				c._go_walk()
		check(absf(c.position.x - x0) > 5.0, "%s walks" % name)
		check(c.wing_side != null and c.wing_side.visible and not c.wings.visible, "%s walks with its near wing" % name)
		c._go_sit()
		c.tick(0.1)
		check(c.wings.visible and c.sit_body.visible, "%s stands facing you with both wings" % name)
		c.vx = 0.0
		c.start_behaviour("groom", 2.0)
		for i in 20:
			c.tick(1.0 / 30.0)
		check(c.act == "groom" and absf(c.wing_l.rotation) > 0.01, "%s fluffs up, wings going" % name)
		c._go_loaf(5.0)
		c.tick(0.1)
		check(c.loaf_body != null and shown(c.loaf_body), "%s naps with a body" % name)
		c.free()


func blobs(src: String) -> void:
	# B4: a slime (bounce), a ghost (float, no head) and a snake (slither).
	for which in ["slime", "ghost", "snake"]:
		Fixtures.blob_kit(src.path_join(which), which)
		var id := Customs.add_folder(src.path_join(which))
		check(id != "", "the %s loads" % which)
		if id == "":
			continue
		var idles: Array = Species.row(id)["idles"]
		for b in ["stretch", "hunt", "chase_tail", "scratch", "groom", "stand_lookout"]:
			check(not b in idles, "the %s is never given %s" % [which, b])
		for b in ["sit_and_look", "nap", "shake_off", "look_at_cursor"]:
			check(b in idles, "the %s can %s" % [which, b])
		var c = spawn(id)
		check(c.legs.is_empty() and c.head != null and c.eyes != null, "the %s has no legs and carries its eyes" % which)
		c.vx = c.facing * c.cruise
		var x0: float = c.position.x
		var low := 1e9
		var high := 0.0
		for i in 240:
			c.tick(1.0 / 30.0)
			if c.mode != "walk":
				c._go_walk()
			var units: float = (c.lift / c.zoom + c._base_params().float) / c.px()
			if i < 30:
				continue   # rising to its hover height
			low = minf(low, units)
			high = maxf(high, units)
		check(absf(c.position.x - x0) > 5.0, "the %s gets about (moved %.0f px)" % [which, c.position.x - x0])
		if which == "ghost":
			check(low >= 9.9 and high <= 20.1, "the ghost floats 10 to 20 units up (%.1f to %.1f)" % [low, high])
		if which == "slime":
			check(high > 3.0, "the slime bounces (up to %.1f units)" % high)
		c._go_loaf(5.0)
		c.tick(0.1)
		check(c.loaf_body != null and shown(c.loaf_body), "the %s naps melted" % which)
		var lb: Rect2 = KitData.bounds(c.kit.images["loaf-body"])
		var bb: Rect2 = KitData.bounds(c.kit.images["body"])
		check(lb.size.x > bb.size.x * 1.1 and lb.size.y < bb.size.y * 0.8, "the %s's nap is wider and lower (%s vs %s)" % [which, lb.size, bb.size])
		c._go_walk()
		c.climbing = true
		c.climb_turn = 90.0
		var p: Dictionary = c._base_params()
		check(c._climb_surge() == 1.0 and p.has("torso_rot"), "the %s climbs as a slide" % which)
		c.climbing = false
		c.free()


func pairs_and_sizes() -> void:
	# B6: homemade critters join only the generic pairs they can do (P16),
	# and host.gd's sizes come from the critter (P17).
	var Pairs = load("res://pairs.gd")
	var pairs = Pairs.new()
	var kit_id := ""
	var blob_id := ""
	for id in Customs.ids():
		var k: Dictionary = Customs.all[id].get("_kit", {})
		if k.get("plan") == "side" and kit_id == "" and Customs.all[id]["name"] == "Kitten kit":
			kit_id = id
		if k.get("plan") == "blob" and blob_id == "":
			blob_id = id
	var kitten_idles: Array = Species.row("kitten")["idles"]
	var seen := {}
	for i in 600:
		for pair in [[kit_id, "kitten"], ["kitten", kit_id], [kit_id, kit_id]]:
			var pick = pairs._pick(pair[0], pair[1], Species.row(pair[0])["idles"], Species.row(pair[1])["idles"])
			if not pick.is_empty():
				seen[pick[0]] = true
	check(not seen.has("kitten_tussle") and not seen.has("near_miss") and not seen.has("mutual_groom"), "a kit never gets a species pair (%s)" % str(seen.keys()))
	check(seen.has("sniff") and seen.has("play_bow") and seen.has("sit_together"), "the kitten kit joins sniff, play bow and sit together (%s)" % str(seen.keys()))
	var bseen := {}
	for i in 600:
		var pick = pairs._pick(blob_id, "kitten", Species.row(blob_id)["idles"], kitten_idles)
		if not pick.is_empty():
			bseen[pick[0]] = true
	check(not bseen.has("play_bow") and bseen.has("sit_together"), "a blob never bows (%s)" % str(bseen.keys()))
	var cast_seen := {}
	for i in 300:
		var pick = pairs._pick("kitten", "kitten")
		if not pick.is_empty():
			cast_seen[pick[0]] = true
	check(cast_seen.has("kitten_tussle") and cast_seen.has("mutual_groom"), "two kittens still get their own pairs")
	var src_txt := FileAccess.get_file_as_string("res://pairs.gd")
	check(src_txt.contains('"stretch" if ka.can_do("stretch")'), "play bow asks before stretching")

	var c = spawn(kit_id)
	var kitten = spawn("kitten")
	check(absf(c.body_centre_px() - c.kit.body_centre_px) < 0.01 and c.body_centre_px() > 10.0, "a kit's body centre is measured (%.1f px)" % c.body_centre_px())
	check(absf(c.head_top_px() - kitten.head_top_px()) < 30.0, "the kitten kit's head top is near the cast's 90 px (%.1f)" % c.head_top_px())
	check(kitten.body_centre_px() == 36.0 and kitten.head_top_px() == 90.0, "the cast keeps its numbers")
	c.free()
	kitten.free()


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
	# F1: the head's metrics match design/wear/build.py's for the kitten
	# (cx 150, cy 122, rx 92, ry 74, eye_y 124, eye_dx 38, eye_r 18, chin 196).
	var want_head := {"cx": 150.0, "cy": 122.0, "rx": 92.0, "ry": 74.0, "eye_y": 124.0, "eye_dx": 38.0, "eye_r": 18.0, "chin": 196.0}
	for k in want_head:
		check(absf(float(r.head[k]) - want_head[k]) <= 4.0, "kitten kit head %s within 4 of build.py's (%.1f vs %.1f)" % [k, r.head[k], want_head[k]])
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

	faces_you(src)
	upright(src)
	blobs(src)
	pairs_and_sizes()

	# --- An edit makes new art: the rig and textures are keyed by rev.
	var before := Customs.tex_key(kid)
	Customs.bump_rev(kid)
	check(Customs.tex_key(kid) != before and not KitData._rigs.has(before), "a rev bump drops the old rig")

	Customs.ways.clear()
	clear_dir(root)
	print("KIT TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
