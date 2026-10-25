extends SceneTree
## Headless checks of presence.gd's hidden time, which keeps a full-screen
## film from counting towards Focus > Tidy up after a long break: time spent
## hidden builds up, never exceeds the idle time, and goes when input comes
## back. Presence runs on --idle-sim's fake cycle here, so no input is read.
## Run: godot --headless --path godot --script res://presence_test.gd

const Presence := preload("res://presence.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func run(p: Node, seconds: float) -> void:
	# Whole seconds of frames, as the game would tick it.
	for i in int(seconds):
		p._process(1.0)


func _initialize() -> void:
	var p: Node = Presence.new()
	p.away_after = 10.0
	p.sim = PackedFloat32Array([5.0, 10000.0])   # 5 s present, then away

	run(p, 4)
	check(p.idle_s == 0.0 and p.hidden_s == 0.0, "nothing counts while present")
	run(p, 20)
	check(p.away and p.hidden_s == 0.0, "an ordinary break has no hidden time")
	var before: float = p.idle_s
	p.hidden = true
	run(p, 30)
	check(is_equal_approx(p.hidden_s, 30.0), "time behind a full-screen app builds up")
	check(is_equal_approx(p.idle_s - p.hidden_s, before), "so the break the tidy-up sees stands still")
	p.hidden = false
	run(p, 7)
	check(is_equal_approx(p.idle_s - p.hidden_s, before + 7.0), "and counts on once the app closes")
	p.hidden = true
	p._process(3600.0)
	check(is_equal_approx(p.hidden_s, 31.0), "a long frame (a sleep) counts a second at most")

	p.hidden = true
	p._sim_t = 10004.0   # the cycle comes round: input again
	run(p, 1)
	check(p.idle_s == 0.0 and p.hidden_s == 0.0, "input clears it, even while still hidden")
	run(p, 3)
	check(p.hidden_s == 0.0, "hidden while in use counts nothing (it never exceeds the idle time)")
	p.free()

	print("presence_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
