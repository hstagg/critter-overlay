extends SceneTree
## Headless checks of win_pool.gd's bookkeeping: a window given back is
## parked and handed out again, never twice, and the pool keeps no more than
## its limit. (Whether Windows' GDI count stays flat is the VM's job.)
## Run: godot --headless --path godot --script res://win_pool_test.gd

const WinPool := preload("res://win_pool.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	await process_frame   # the root is in the tree from the first frame
	var pool := WinPool.new()
	pool.keep = 2
	root.add_child(pool)

	var a: Window = pool.take()
	check(pool.made == 1 and pool.reused == 0, "a new window is counted as made")
	check(a.get_parent() == pool, "windows live under the pool")
	check(not a.visible, "a new window waits hidden until put out")
	var thing := Node2D.new()
	a.add_child(thing)
	a.window_input.connect(func(_e): pass)
	pool.put_out(a, Vector2i(100, 200))
	check(a.visible and a.position == WinPool.AWAY, "put_out shows it off the screen first, so it draws before it is seen")
	pool.move(a, Vector2i(120, 210))
	check(a.position == WinPool.AWAY, "a move while held waits for the hold")
	pool._process(0.016)
	check(a.position == WinPool.AWAY, "not before it has drawn")
	var frame := [0]
	WinPool.drawn = func() -> int: return frame[0]
	pool.reveal(a, Vector2i(120, 210))
	for i in WinPool.HOLD_FRAMES:
		frame[0] += 1
		pool._process(0.016)
	check(a.position == Vector2i(120, 210), "then it goes where it was last asked")
	pool.move(a, Vector2i(130, 220))
	check(a.position == Vector2i(130, 220), "once drawn, moves are immediate")

	pool.give_back(a)
	check(pool.spare == [a], "a shown window given back is kept")
	check(a.visible, "and is never hidden (hiding would destroy it)")
	check(a.position == WinPool.AWAY, "but parked off the screen")
	check(thing.is_queued_for_deletion(), "what was drawn in it goes")
	check(a.window_input.get_connections().is_empty(), "the old owner no longer hears its input")
	check(a.process_mode == Node.PROCESS_MODE_DISABLED, "and nothing in it runs")
	pool.give_back(a)
	check(pool.spare.size() == 1, "given back twice, it is kept once")

	var b: Window = pool.take()
	check(b == a, "the spare is handed out again")
	check(pool.made == 1 and pool.reused == 1, "reuse is counted, nothing new made")
	check(b.process_mode == Node.PROCESS_MODE_INHERIT, "and runs again")

	var never: Window = pool.take()
	pool.give_back(never)
	check(never.is_queued_for_deletion() and not never in pool.spare, "one never shown is freed, not kept")

	var ws := []
	for i in 3:
		var w: Window = pool.take()
		pool.put_out(w, Vector2i(10 * i, 0))
		ws.append(w)
	for w in ws:
		pool.give_back(w)
	check(pool.spare.size() == 2, "no more spares than the limit")
	check(ws[2].is_queued_for_deletion(), "the one over the limit is freed")

	await process_frame
	print("WIN POOL TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 and checks > 0 else 1)
