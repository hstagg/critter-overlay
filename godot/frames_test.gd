extends SceneTree
## Headless checks for frame critters (docs/custom-critters-build-plan.md,
## E1): the pixel cat loads, its act clips become behaviours the evaluator
## can pick, each state plays its clip or the fallback, walking frames follow
## the distance, the atlas stays within 2048, and its frames are freed a
## minute after the last one goes.
## Run: godot --headless --path godot --script res://frames_test.gd

const Customs := preload("res://customs.gd")
const Species := preload("res://species.gd")
const Behaviours := preload("res://behaviours.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")
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


func _init() -> void:
	world = World.new()
	get_root().add_child(world)
	var root := "user://frames_test"
	clear_dir(root)
	Customs.dir = root.path_join("store")
	DirAccess.make_dir_recursive_absolute(Customs.dir)
	Fixtures.pixel_cat(root.path_join("cat"))
	Fixtures.pixel_cat(root.path_join("walker"), false)

	Customs.ways.clear()
	check(Customs.add_folder(root.path_join("cat")) == "", "a frame critter waits while the frames way is off")
	Customs.all_ways_on()
	var id := Customs.add_folder(root.path_join("cat"))
	check(id != "", "the pixel cat loads")
	var idles: Array = Species.row(id)["idles"]
	check(idles == ["nap", "clip:wave"], "its moves are a nap and its own clip (%s)" % str(idles))

	var c = spawn(id)
	check(c.atlas.size.x <= 2048 and c.atlas.size.y <= 2048, "the atlas is within 2048 (%s)" % str(c.atlas.size))
	check(c.atlas.regions.walk.size() == 4 and c.atlas.regions["act-wave"].size() == 4, "every frame is on the atlas")
	# Walking: frames follow the distance.
	c.vx = c.facing * c.cruise
	var x0: float = c.position.x
	var seen := {}
	for i in 120:
		c.tick(1.0 / 30.0)
		if c.mode != "walk":
			c._go_walk()
		if c.clip == "walk" and c.pose == "walk":
			seen[c.sheet.region_rect] = true   # not the odd frame where its walk ran out
	check(c.clip == "walk" and seen.size() == 4, "it walks through all four walk frames (%d)" % seen.size())
	check(absf(c.position.x - x0) > 40.0, "and gets somewhere (%.0f px in 4 s)" % absf(c.position.x - x0))
	check(absf(c.cycle_px - 100.0 * c.px()) < 0.5, "a walk cycle carries it stride_px (%.1f vs %.1f)" % [c.cycle_px, 100.0 * c.px()])
	c._go_sit()
	c.blink_left = 0.0
	c.blink_in = 1e9   # no ambient blink in the way
	c.tick(0.1)
	check(c.clip == "sit", "sitting plays sit")
	c.blink_left = 0.1
	c.tick(0.01)
	check(c.clip == "blink", "and blinks with its blink clip")
	c.blink_left = 0.0
	c._go_loaf(5.0)
	c.tick(0.1)
	check(c.clip == "sit", "with no nap clip it naps on sit")
	c.held = true
	c.tick(0.1)
	check(c.clip == "sit", "held, with no held clip: sit")
	c.held = false
	c._go_walk()
	c.airborne = true
	c.air_y = 80.0
	c.air_vy = -200.0
	c.tick(0.01)
	check(c.clip == "sit", "thrown falls back through held to sit")
	c.airborne = false
	c.climbing = true
	c.tick(0.01)
	check(c.clip == "walk", "climbing with no climb clip: walk")
	c.climbing = false
	# Its own move, picked by the evaluator.
	var ev := Behaviours.new()
	var picked := false
	for i in 50:
		if ev._pick(c, 0.0) == "clip:wave":
			picked = true
	check(picked, "the evaluator offers clip:wave")
	check(absf(ev.duration_of("clip:wave", c) - 1.0) < 0.01, "and plays it for its length (%.2f s)" % ev.duration_of("clip:wave", c))
	c.vx = 0.0
	c.start_behaviour("clip:wave", ev.duration_of("clip:wave", c))
	c.tick(0.05)
	check(c.clip == "act-wave", "its act clip plays")
	for i in 40:
		c.tick(1.0 / 30.0)
	check(c.act == "" or c.act_t >= c.act_len - 0.05, "and ends with the clip")
	check(c.hit_rect().size.y > 10.0 and c.region_rect().size.x > 10.0, "it has a size on screen")
	c.free()

	# A walk-only critter: sitting shows the first walk frame.
	var wid := Customs.add_folder(root.path_join("walker"))
	var w = spawn(wid, "sit")
	w.tick(0.1)
	check(w.clip == "walk" and w.sheet.region_rect == w.atlas.regions.walk[0], "with only walk frames it sits on the first")
	w.free()

	# Frames are freed a minute after the last one goes.
	var key := Customs.tex_key(id)
	check(FrameData._atlases.has(key), "the atlas is kept while it is out")
	Customs.sweep(Time.get_ticks_msec() / 1000.0 + 59.0)
	check(FrameData._atlases.has(key), "59 s on: still kept")
	Customs.sweep(Time.get_ticks_msec() / 1000.0 + 61.0)
	check(not FrameData._atlases.has(key), "61 s on: freed")

	# Limits: no walk, too many frames.
	var nowalk := root.path_join("nowalk")
	Fixtures.pixel_cat(nowalk)
	for f in DirAccess.get_files_at(nowalk.path_join("clips/walk")):
		DirAccess.remove_absolute(nowalk.path_join("clips/walk/" + f))
	check(Customs.add_folder(nowalk) == "", "no walk frames: refused")
	var many := root.path_join("many")
	Fixtures.pixel_cat(many)
	var img := Image.load_from_file(many.path_join("clips/walk/0.png"))
	for i in range(4, 70):
		img.save_png(many.path_join("clips/walk/%d.png" % i))
	check(FrameData.missing(many, {"clips": {"walk": {}}}) == "" and FrameData.frame_files(many, "walk").size() == 64, "a clip reads 64 frames at most")
	check(FrameData.missing(many, {"clips": {"walk": {}, "sit": {}, "act-wave": {}}}).contains("64"), "over 64 frames in all is refused")

	Customs.ways.clear()
	clear_dir(root)
	print("FRAMES TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
