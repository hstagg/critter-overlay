extends Node2D
## Spike: one small transparent window per critter, so critters can go
## anywhere on screen without a full-screen window (which the compositor
## promotes to fullscreen flip and turns black). Each kitten lives in its own
## borderless, always-on-top window that moves with it.
##
## Run: godot --path godot res://spike_windows.tscn -- --kittens=8 --seconds=40
## Flags: --kittens=N  --seconds=N  --report=PATH  --vsync-all (vsync on every
## window, not just the first)

const Kitten := preload("res://critters/kitten.gd")

const WIN := 200               # px, square window per kitten
const FLOOR := WIN - 24        # the kitten's feet in its window

var seconds := 40.0
var count := 8
var report_path := ""
var vsync_all := false
var t := 0.0
var critters := []             # {win, holder, kitten, world, y, vy}
var origin := Vector2i.ZERO
var screen := Vector2i.ZERO
var frame_ms := []
var move_ms := []
var fps := []


class World extends Node:
	## What a kitten needs from main.gd, for a kitten whose x is in screen
	## pixels and whose floor is in its own window.
	var floor_y := float(FLOOR)
	var left_x := 0.0
	var right_x := 0.0
	var win: Window
	var holder: Node2D
	func mouse_local() -> Vector2:
		var m := Vector2(DisplayServer.mouse_get_position() - win.position)
		return m - holder.position


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--kittens="):
			count = int(v)
		elif arg.begins_with("--seconds="):
			seconds = float(v)
		elif arg.begins_with("--report="):
			report_path = v
		elif arg == "--vsync-all":
			vsync_all = true

	var scr := DisplayServer.get_primary_screen()
	origin = DisplayServer.screen_get_position(scr)
	screen = DisplayServer.screen_get_size(scr)

	# The project's own window is the bottom strip; shrink it out of the way.
	var main_win := get_window()
	main_win.size = Vector2i(1, 1)
	main_win.position = origin + Vector2i(0, screen.y - 1)
	main_win.gui_embed_subwindows = false

	Kitten.load_textures()
	randomize()
	for i in count:
		_add(i)


func _add(i: int) -> void:
	var w := Window.new()
	w.borderless = true
	w.transparent = true
	w.transparent_bg = true
	w.always_on_top = true
	w.unfocusable = true
	w.size = Vector2i(WIN, WIN)
	add_child(w)
	if not vsync_all and i > 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, w.get_window_id())

	var world := World.new()
	world.left_x = WIN * 0.5
	world.right_x = screen.x - WIN * 0.5
	world.win = w
	add_child(world)

	var holder := Node2D.new()
	w.add_child(holder)
	world.holder = holder

	var k = Kitten.new()
	holder.add_child(k)
	var x := randf_range(world.left_x, world.right_x)
	k.setup(world, x, [-1, 1].pick_random(), ["walk", "walk", "sit"].pick_random())

	var c := {"win": w, "holder": holder, "kitten": k, "world": world,
		"y": randf_range(WIN, screen.y - 40.0), "vy": randf_range(-30.0, 30.0)}
	critters.append(c)
	_place(c)


func _place(c: Dictionary) -> void:
	# Keep the kitten in the middle of its window and move the window instead.
	var k = c.kitten
	c.holder.position = Vector2(WIN * 0.5 - k.position.x, 0)
	c.win.position = origin + Vector2i(int(round(k.position.x - WIN * 0.5)), int(round(c.y - FLOOR)))


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	t += delta
	for c in critters:
		var k = c.kitten
		k.tick(delta)
		# Free roaming: drift up and down the screen while walking.
		if k.mode == "walk":
			if randf() < delta * 0.3:
				c.vy = randf_range(-40.0, 40.0)
			c.y += c.vy * delta
			if c.y < FLOOR + 10 or c.y > screen.y - 30:
				c.vy = -c.vy
				c.y = clampf(c.y, FLOOR + 10, screen.y - 30)
	var t1 := Time.get_ticks_usec()
	for c in critters:
		_place(c)
	move_ms.append((Time.get_ticks_usec() - t1) / 1000.0)
	frame_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	fps.append(Engine.get_frames_per_second())
	if seconds > 0.0 and t >= seconds:
		_finish()


func _stats(xs: Array) -> Dictionary:
	var s := xs.duplicate()
	s.sort()
	if s.is_empty():
		return {}
	return {"median": snappedf(s[s.size() / 2], 0.01), "p95": snappedf(s[int(s.size() * 0.95)], 0.01), "n": s.size()}


func _finish() -> void:
	set_process(false)
	var r := {"kittens": critters.size(), "fps": _stats(fps.slice(int(fps.size() * 0.2))),
		"frame_ms": _stats(frame_ms), "move_ms": _stats(move_ms), "vsync_all": vsync_all,
		"seconds": t, "renderer": RenderingServer.get_video_adapter_name()}
	print("REPORT ", JSON.stringify(r))
	if report_path != "":
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(r, " "))
		f.close()
	# Same Intel GL teardown crash as main.gd: end without it.
	if OS.get_name() == "Windows":
		OS.kill(OS.get_process_id())
	get_tree().quit()
