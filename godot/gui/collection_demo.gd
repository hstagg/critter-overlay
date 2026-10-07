extends Node
## The Collection on its own, with made-up sightings, for checking by eye.
## Run: godot --path godot res://gui/collection_demo.tscn -- [--grab=PATH] [--seconds=N]

const Economy := preload("res://economy.gd")
const Collection := preload("res://gui/collection.gd")
const Species := preload("res://species.gd")

var grab := ""
var seconds := 0.0
var t := 0.0
var win: Window


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grab="):
			grab = arg.get_slice("=", 1)
		elif arg.begins_with("--seconds="):
			seconds = float(arg.get_slice("=", 1))
	get_window().gui_embed_subwindows = false
	get_window().size = Vector2i(1, 1)
	var e = Economy.new()
	e.save_path = OS.get_temp_dir().path_join("critter_collection_demo.json")
	var now := Time.get_unix_time_from_system()
	for sp in Species.DATA:
		if Species.is_special(sp):
			e.row_variants[sp] = Species.variants(sp)
	var made := [["kitten", "common", 9], ["kitten", "rare", 2], ["kitten", "epic", 1],
		["rabbit", "common", 6], ["rabbit", "rare", 1], ["unicorn", "legendary", 1, "lavender"]]
	var clock := now - 5 * 86400.0
	for m in made:
		for i in m[2]:
			clock += 3600.0 * 7
			e.now_fn = func() -> float: return clock
			e.record_sighting(m[0], m[1], m[3] if m.size() > 3 else "")
	add_child(e)
	# The Collection is a Settings page now; here it sits in a plain window.
	win = Window.new()
	win.size = Vector2i(860, 760)
	add_child(win)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(scroll)
	var page = Collection.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	page.setup(e)


func _process(delta: float) -> void:
	t += delta
	if grab != "" and t > 1.5:
		win.get_texture().get_image().save_png(grab)
		print("GRABBED ", grab, " ", win.size)
		grab = ""
	if seconds > 0.0 and t >= seconds:
		OS.kill(OS.get_process_id())
