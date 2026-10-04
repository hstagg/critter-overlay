extends Node
## The tray on its own, with made-up numbers, for checking it by eye.
## Run: godot --path godot res://gui/tray_demo.tscn -- [--mode=running|paused|napping]
##      [--open] [--grab=PATH] [--seconds=N]
## Clicks on the panel's actions are printed; Quit ends the demo.

const Tray := preload("res://gui/tray.gd")

var tray: Node
var seconds := 0.0
var grab := ""
var t := 0.0
var grabbed := false


func _ready() -> void:
	var mode := "running"
	var open := false
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--mode="):
			mode = v
		elif arg == "--open":
			open = true
		elif arg.begins_with("--grab="):
			grab = v
			open = true
		elif arg.begins_with("--seconds="):
			seconds = float(v)
	var win := get_window()
	win.gui_embed_subwindows = false
	win.size = Vector2i(1, 1)
	win.position = Vector2i(-10, -10)

	tray = Tray.new()
	add_child(tray)
	tray.update({"mode": mode, "out": 6, "focus_min": 42.0, "gift_min": 8.0, "gift_progress": 0.68,
		"away_min": 6.0, "found": 21, "found_total": 48, "berries": 214})
	for s in ["spawn_pressed", "pause_pressed", "collection_pressed", "settings_pressed"]:
		tray.connect(s, func(): print("TRAY ", s))
	tray.quit_pressed.connect(func():
		print("TRAY quit_pressed")
		_end())
	if open:
		tray.open.call_deferred()


func _process(delta: float) -> void:
	t += delta
	if grab != "" and not grabbed and t > 1.0 and tray.panel != null and tray.panel.visible:
		grabbed = true
		tray.panel.get_texture().get_image().save_png(grab)
		print("GRABBED ", grab, " ", tray.panel.size)
	if seconds > 0.0 and t >= seconds:
		_end()


func _end() -> void:
	# Same Intel GL teardown crash as main.gd: end without it.
	if OS.get_name() == "Windows":
		OS.kill(OS.get_process_id())
	get_tree().quit()
