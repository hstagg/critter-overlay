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

	# Without the sim, idle time is Windows' clock, so hidden time is too:
	# Godot's delta runs slow at the 5 fps kept while hidden.
	var q: Node = Presence.new()
	q._last_mouse = DisplayServer.mouse_get_position()
	q._mouse_idle = 1000.0   # long idle, by the mouse fallback
	q.hidden = true
	q._process(0.01)
	q.hidden_s = 0.0
	OS.delay_msec(300)
	q._process(0.01)
	check(q.hidden_s > 0.25 and q.hidden_s < 1.0, "outside the sim it counts real time, not delta (%.2f s)" % q.hidden_s)
	q.free()

	# The native layer: input with no device handle (a precision touchpad, a
	# pen) still counts, through Windows' own last-input time (F13).
	var r: Node = Presence.new()
	r.away_after = 180.0
	var fake := FakeNative.new()
	r.native = fake
	fake.real = 600000   # no device input for 10 minutes
	fake.any = 2000      # but the touchpad was used 2 s ago
	r._process(0.1)
	check(is_equal_approx(r.idle_s, 2.0) and not r.away, "touchpad input keeps you here (idle %.1f s)" % r.idle_s)
	fake.any = 600000
	r._process(0.1)
	check(r.away, "and with no input at all you are away")
	fake.real = 1000
	r._process(0.1)
	check(not r.away and is_equal_approx(r.idle_s, 1.0), "a real mouse brings you back")
	r.free()

	print("presence_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


class FakeNative extends RefCounted:
	## The two idle clocks the native layer gives, set by the test.
	var real := 0
	var any := 0
	func real_input_age_ms() -> int:
		return real
	func idle_ms() -> int:
		return any
