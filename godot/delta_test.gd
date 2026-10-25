extends SceneTree
## Headless check that frame deltas add up to real time at the low frame
## caps main.gd's _pace_frames() uses (5 and 10 fps). Godot takes off the
## process delta whatever a frame needs beyond max_physics_steps_per_frame
## (8) physics steps; at the default 60 physics ticks a 5 fps frame needs 12,
## so berries, arrivals and every timer ran at two thirds of real time while
## paused, hidden or with nobody out. The project uses no physics, so
## project.godot sets physics_ticks_per_second to 10.
## Run: godot --headless --path godot --script res://delta_test.gd

const SECS := 3.0

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	for fps in [5, 10]:
		Engine.max_fps = fps
		await process_frame   # the first frame at the new cap
		var sum := 0.0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < int(SECS * 1e6):
			await process_frame
			sum += root.get_process_delta_time()
		var wall := (Time.get_ticks_usec() - t0) / 1e6
		check(sum / wall > 0.95, "at %d fps, %.2f s of deltas over %.2f s of real time" % [fps, sum, wall])

	print("DELTA TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 and checks > 0 else 1)
