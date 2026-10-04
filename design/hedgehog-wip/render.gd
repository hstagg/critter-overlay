extends SceneTree
# godot --headless -s render.gd -- IN.svg OUT.png SCALE
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(a[0]), float(a[2]))
	var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color("#F3E6D6"))
	bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	bg.save_png(a[1])
	quit()
