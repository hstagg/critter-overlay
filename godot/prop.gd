extends Node
## A showpiece on the desktop (economy design, the showpiece tier: "a
## critter's bed or house"): a basket, a tent or a cottage standing on the
## taskbar. It has its own small transparent window like a critter's; drag it
## to move it along the bottom of the screen. When you step away, napping
## critters walk over and curl up in it; the cottage takes them inside and
## shows a little "zz" instead.

signal moved(id: String, x_fraction: float)

const ART := 300.0                # the art's frame, px across (art/props/*.svg)
const ART_H := 200.0

# id: [name, scale at zoom 1, sleep spots in art px (feet), hides sleepers]
const PROPS := {
	"basket": ["Basket bed", 0.5, [Vector2(118, 124), Vector2(182, 124)], false],
	"tent": ["Pillow tent", 0.55, [Vector2(150, 186), Vector2(84, 186)], false],
	"cottage": ["Little cottage", 0.62, [Vector2(150, 188), Vector2(150, 188), Vector2(150, 188)], true],
}
const PRICE := 4000

var id := ""
var main: Node
var win: Window
var sprite: Sprite2D
var zz: Label
var scale_px := 0.5
var size := Vector2.ZERO
var x_fraction := 0.5
var sleepers := []                # hosts asleep here, by spot
var _drag_from := -1.0


static func prop_name(pid: String) -> String:
	return PROPS[pid][0] if PROPS.has(pid) else pid


func setup(main_ref: Node, pid: String, frac: float, zoom: float) -> void:
	main = main_ref
	id = pid
	x_fraction = frac
	scale_px = PROPS[pid][1] * zoom
	size = Vector2(ART, ART_H) * scale_px
	sleepers.resize(PROPS[pid][2].size())
	win = Window.new()
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = true
	win.unfocusable = true
	win.visible = false
	win.size = Vector2i(size.ceil())
	win.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	add_child(win)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, win.get_window_id())
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string("res://art/props/%s.svg" % pid), scale_px)
	sprite = Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.centered = false
	win.add_child(sprite)
	zz = Label.new()
	zz.text = "z z"
	zz.add_theme_font_size_override("font_size", int(18 * zoom))
	zz.add_theme_color_override("font_color", Color("#5C6F86"))
	zz.position = Vector2(size.x * 0.62, size.y * 0.05)
	zz.visible = false
	win.add_child(zz)
	win.window_input.connect(_on_input)
	_place()
	win.show()
	# Clicks pass through except on the lower part, where it is solid.
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([
		Vector2(size.x * 0.1, size.y * 0.3), Vector2(size.x * 0.9, size.y * 0.3),
		Vector2(size.x * 0.9, size.y), Vector2(size.x * 0.1, size.y)]), win.get_window_id())


func _place() -> void:
	var r: Rect2 = main.area
	var x := r.position.x + x_fraction * (r.size.x - size.x)
	win.position = Vector2i(int(x), int(r.end.y - size.y + 4))


func _on_input(e: InputEvent) -> void:
	# Drag along the bottom of the screen.
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag_from = DisplayServer.mouse_get_position().x - win.position.x
		elif _drag_from >= 0.0:
			_drag_from = -1.0
			moved.emit(id, x_fraction)
	elif e is InputEventMouseMotion and _drag_from >= 0.0:
		var r: Rect2 = main.area
		var x := DisplayServer.mouse_get_position().x - _drag_from
		x_fraction = clampf((x - r.position.x) / maxf(r.size.x - size.x, 1.0), 0.0, 1.0)
		_place()


func free_spot() -> int:
	for i in sleepers.size():
		if sleepers[i] == null or not is_instance_valid(sleepers[i]):
			return i
	return -1


func spot_feet(i: int) -> Vector2:
	# Where a sleeper's feet go, on screen.
	return Vector2(win.position) + PROPS[id][2][i] * scale_px


func hides() -> bool:
	return PROPS[id][3]


func take(i: int, h) -> void:
	sleepers[i] = h
	if hides():
		h.win.visible = false
		zz.visible = true


func release_all() -> void:
	# Everyone wakes: those inside come out of the door.
	for h in sleepers:
		if h != null and is_instance_valid(h) and hides():
			h.win.visible = not main.paused and not main.busy_hidden
	for i in sleepers.size():
		sleepers[i] = null
	zz.visible = false
