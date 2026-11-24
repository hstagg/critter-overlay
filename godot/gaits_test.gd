extends SceneTree
## Headless checks for critters/kit/gaits.gd (docs/custom-critters-build-plan.md,
## 4.5 and step A4). Each copied gait is driven side by side with its species,
## which is the reference: same phase, speed and state in, same pose, speed,
## lift and leg angles out. Every gait's speed averages 1 over a cycle and its
## lift is never negative.
## Run: godot --headless --path godot --script res://gaits_test.gd

const Species := preload("res://species.gd")
const Gaits := preload("res://critters/kit/gaits.gd")

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


func spawn(id: String):
	var c = Species.row(id)["script"].new()
	c.species = id
	c.idles = Species.row(id)["idles"]
	world.add_child(c)
	c.setup(world, 600.0, -1, "walk")
	c.vx = c.facing * c.cruise
	c.twitch_left = 0.0
	c.twitch_in = 1e9
	return c


func sync(from, to) -> void:
	# The state critter.gd's _base_params and the gaits read.
	for k in ["t", "phase", "gait", "vx", "cruise", "pose", "mode", "act", "facing", "lift",
			"twitch_left", "shift_from", "shift_to", "shift_t", "dozing", "climbing", "airborne",
			"entering", "squash_v", "base_pt"]:
		to.set(k, from.get(k))


func near(a, b, eps := 1e-4) -> bool:
	if a is Vector2:
		return a.distance_to(b) < eps
	if a is float or a is int:
		return absf(float(a) - float(b)) < eps
	return a == b


const KEYS := ["torso_pivot", "torso_rot", "torso_dy", "head_off", "head_rot", "ear_l", "ear_r",
	"tail_extra", "legs", "eyes_closed", "blink"]


func same_pose(sp, probe, s: Dictionary, what: String) -> void:
	# The species' walking pose against kitten (critter.gd's own pose) plus
	# the gait. Only the keys a gait sets are compared.
	sync(sp, probe)
	var want: Dictionary = sp._base_params()
	var got: Dictionary = probe._base_params()
	Gaits.params(probe, s, got)
	var bad := []
	for k in KEYS:
		if want.has(k) and got.has(k) and not near(want[k], got[k]):
			bad.append("%s %s vs %s" % [k, want[k], got[k]])
	check(bad.is_empty(), "%s: pose matches (%s)" % [what, ", ".join(bad)])


func _init() -> void:
	world = World.new()
	get_root().add_child(world)
	var probe = spawn("kitten")
	var dt := 1.0 / 60.0

	# --- Distance gaits whose pose and speed come from the phase alone.
	for pair in [["waddle", "duckling"], ["plod", "turtle"], ["scurry", "hedgehog"], ["sway", "panda"], ["bounce", "unicorn"], ["trot", "kitten"]]:
		var sp = spawn(pair[1])
		var s := Gaits.state(pair[0], Vector2(172, 214), sp.get("FEET") if sp.get("FEET") != null else Vector2(150, 262))
		var bad := 0
		for i in 24:
			sp.gait = i / 24.0
			sp.t = i * 0.37
			sync(sp, probe)
			if not near(sp._gait_speed(), Gaits.speed(probe, s)):
				bad += 1
			if i % 4 == 0:
				same_pose(sp, probe, s, "%s at %.2f" % [pair[0], sp.gait])
		check(bad == 0, "%s: speed matches %s at every phase" % [pair[0], pair[1]])
		sp.free()

	# --- Hop: time, lift, squash kicks, pose and legs, through two cycles.
	var rb = spawn("rabbit")
	var s := Gaits.state("hop", rb.BODY_MID)
	rb.gait = 0.9
	rb.hop_k = 1.0
	sync(rb, probe)
	var bad_adv := []
	var legs_ok := true
	var near_front = null
	for leg in rb.legs:
		if leg.front:
			near_front = leg
	for i in int(2.0 * Gaits.HOP_CYCLE / dt):
		if i == 70:
			rb.vx = rb.facing * rb.cruise * 0.5   # slowing: a smaller hop
			probe.vx = rb.vx
		rb._advance_gait(dt)
		Gaits.advance(probe, s, dt)
		for k in ["gait", "lift", "squash_v"]:
			if not near(rb.get(k), probe.get(k)):
				bad_adv.append("%s at step %d: %s vs %s" % [k, i, rb.get(k), probe.get(k)])
		if not near(rb.hop_k, s.hop_k):
			bad_adv.append("hop_k at step %d" % i)
		if not near(rb._gait_speed(), Gaits.speed(probe, s)) or rb._settled() != Gaits.settled(probe, s):
			bad_adv.append("speed or settled at step %d" % i)
		if i % 9 == 0:
			same_pose(rb, probe, s, "hop at %.2f" % rb.gait)
			if near_front != null:
				rb._apply_legs(rb._base_params())
				var want: float = near_front.node.rotation
				var far: float = 0.85 if near_front.node.get_parent() == rb.legs_node else 1.0
				if not near(want, deg_to_rad(Gaits.hop_legs(probe, s).x * far)):
					legs_ok = false
		probe.squash_v = rb.squash_v
	check(bad_adv.is_empty(), "hop: phase, lift, squash and speed match rabbit (%s)" % ", ".join(bad_adv.slice(0, 4)))
	check(near_front != null and legs_ok, "hop: leg angles match rabbit")
	rb.free()

	# --- Dart and slide: the same draws give the same freezes and slides.
	for pair in [["dart", "squirrel", "freeze_in", "freeze_left"], ["slide", "otter", "slide_in", "slide_left"]]:
		var sp = spawn(pair[1])
		var st := Gaits.state(pair[0])
		st[pair[2]] = sp.get(pair[2])
		st[pair[3]] = sp.get(pair[3])
		var bad := []
		var saw := false
		for i in 900:
			sync(sp, probe)
			probe.rng.state = sp.rng.state
			Gaits.tick(probe, st, dt)
			sp.tick(dt)
			if sp.mode != "walk":
				sp._go_walk()
				sp.vx = sp.facing * sp.cruise
			for k in [pair[2], pair[3]]:
				if not near(sp.get(k), st[k]):
					bad.append("%s at %d" % [k, i])
			if st[pair[3]] > 0.0:
				saw = true
				if i % 10 == 0 and sp.pose == "walk":
					same_pose(sp, probe, st, "%s while it happens" % pair[0])
					if pair[0] == "slide":
						check(near(sp._gait_speed(), Gaits.speed(probe, st)), "slide: speed matches otter")
			st[pair[2]] = sp.get(pair[2])
			st[pair[3]] = sp.get(pair[3])
		check(saw, "%s: it happened in 15 s" % pair[0])
		check(bad.is_empty(), "%s: matches %s (%s)" % [pair[0], pair[1], ", ".join(bad.slice(0, 4))])
		sp.free()

	# --- Every gait: speed averages 1, lift never below the ground.
	for g in Gaits.NAMES:
		var st := Gaits.state(g)
		var sum := 0.0
		var n := 0
		var low := 0.0
		probe.vx = probe.facing * probe.cruise
		probe.pose = "walk"
		probe.mode = "walk"
		probe.gait = 0.0
		probe.lift = 0.0
		if Gaits.timed(st):
			var cycle: float = {"hop": Gaits.HOP_CYCLE, "blob_bounce": Gaits.BLOB_CYCLE, "float": Gaits.FLOAT_PERIOD}[g]
			var fine := dt / 10.0
			for i in int(round(2.0 * cycle / fine)):
				Gaits.advance(probe, st, fine)
				sum += Gaits.speed(probe, st)
				n += 1
				low = minf(low, probe.lift)
		else:
			for i in 400:
				probe.gait = i / 400.0
				sum += Gaits.speed(probe, st)
				n += 1
		var avg := sum / n
		check(absf(avg - 1.0) < 0.03, "%s: speed averages 1 (%.3f)" % [g, avg])
		check(low >= 0.0, "%s: lift never negative" % g)
		var p: Dictionary = probe._base_params()
		Gaits.params(probe, st, p)
		check(p.has("torso_rot"), "%s: poses" % g)

	check(Gaits.state("moonwalk").name == "trot", "an unknown gait walks as a trot")
	print("GAITS TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
