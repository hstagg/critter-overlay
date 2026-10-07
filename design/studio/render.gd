extends SceneTree
# godot --headless -s render.gd -- LIST.txt SCALE
# LIST.txt: one "in.svg|out.png" per line. Transparent background.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scale := float(a[1])
	for ln in FileAccess.get_file_as_string(a[0]).split("\n", false):
		var p := ln.strip_edges().split("|")
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(p[0]), scale)
		img.save_png(p[1])
	quit()
