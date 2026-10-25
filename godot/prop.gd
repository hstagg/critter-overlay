extends Node
## A showpiece on the desktop (economy design, the showpiece tier: "a
## critter's bed or house"): a basket, a tent or a cottage standing on the
## taskbar. It has its own small transparent window like a critter's; drag it
## anywhere on the screen (smoothly: the window follows the pointer every frame
## while held), or right-click it to put it away, send it behind your windows
## or make it invisible (Shop > Showpieces shows it again). When you step away, napping
## critters walk over and curl up in it; the cottage takes them inside and
## shows a little "zz" instead.

signal moved(id: String, place: Dictionary)

const WinPool := preload("res://win_pool.gd")

const ART := 300.0                # the art's frame, px across (art/props/*.svg)
const ART_H := 200.0

# id: [name, scale at zoom 1, sleep spots in art px (feet), hides sleepers]
const PROPS := {
	"basket": ["Basket bed", 0.5, [Vector2(118, 124), Vector2(182, 124)], false],
	"tent": ["Pillow tent", 0.55, [Vector2(150, 186), Vector2(84, 186)], false],
	"cottage": ["Little cottage", 0.62, [Vector2(150, 188), Vector2(150, 188), Vector2(150, 188)], true],
}
const PRICE: int = preload("res://wear.gd").PRICES["showpiece"]   # one price table (wear.gd)

var id := ""
var main: Node
var win: Window
var at := Vector2i.ZERO            # where the window stands, even while parked
var parked := false
var sprite: Sprite2D
var zz: Label
var scale_px := 0.5
var size := Vector2.ZERO
var x_fraction := 0.5             # across the work area, 0 left .. 1 right
var y_fraction := 1.0             # down it, 1 standing on the taskbar
var back := false                 # behind other windows instead of always on top
var hidden := false               # still there (critters still nap in it), not drawn or clickable
var _dragging := false
var _grab := Vector2i.ZERO        # where in the window the pointer took hold
var _menu: PopupMenu
var sleepers := []                # hosts asleep here, by spot


static func prop_name(pid: String) -> String:
	return PROPS[pid][0] if PROPS.has(pid) else pid


static func place_of(saved) -> Dictionary:
	# A saved place: {x, y, back, hidden}; before 3.1 it was only x (on the taskbar).
	if typeof(saved) == TYPE_DICTIONARY:
		return {"x": float(saved.get("x", 0.5)), "y": float(saved.get("y", 1.0)),
			"back": bool(saved.get("back", false)), "hidden": bool(saved.get("hidden", false))}
	return {"x": float(saved) if typeof(saved) in [TYPE_FLOAT, TYPE_INT] else 0.5, "y": 1.0, "back": false, "hidden": false}


func place() -> Dictionary:
	return {"x": x_fraction, "y": y_fraction, "back": back, "hidden": hidden}


func setup(main_ref: Node, pid: String, saved, zoom: float) -> void:
	main = main_ref
	id = pid
	var p := place_of(saved)
	x_fraction = p.x
	y_fraction = p.y
	back = p.back
	hidden = p.hidden
	scale_px = PROPS[pid][1] * zoom
	size = Vector2(ART, ART_H) * scale_px
	sleepers.resize(PROPS[pid][2].size())
	win = Window.new()
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = not back
	win.unfocusable = true
	win.visible = false
	win.size = Vector2i(size.ceil())
	win.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	add_child(win)
	win.close_requested.connect(main.close_requested_by_windows)
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
	WinPool.show_away(win)   # made off the screen, then shown once it has drawn
	main.win_pool.reveal(win, at)
	# Only now does the window exist, so only now can its vsync be set.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, win.get_window_id())
	_apply_hidden()


func _apply_hidden() -> void:
	# Clicks pass through except on the lower part, where it is solid; an
	# invisible one lets every click through (one corner pixel stays, as an
	# empty region would make the whole window solid).
	sprite.visible = not hidden
	zz.modulate.a = 0.0 if hidden else 1.0
	var solid := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]) if hidden else PackedVector2Array([
		Vector2(size.x * 0.1, size.y * 0.3), Vector2(size.x * 0.9, size.y * 0.3),
		Vector2(size.x * 0.9, size.y), Vector2(size.x * 0.1, size.y)])
	DisplayServer.window_set_mouse_passthrough(solid, win.get_window_id())


func set_hidden(on: bool) -> void:
	hidden = on
	_apply_hidden()
	moved.emit(id, place())


func _place() -> void:
	var r: Rect2 = main.area
	var x := r.position.x + x_fraction * (r.size.x - size.x)
	var y := r.position.y + y_fraction * (r.size.y - size.y) + (4.0 if y_fraction >= 0.999 else 0.0)
	at = Vector2i(int(x), int(y))
	if not parked:
		main.win_pool.move(win, at)


func show_window(on: bool) -> void:
	# Paused or a full-screen app: parked off the screen, not hidden, as the
	# critters' windows are (win_pool.gd says why).
	parked = not on
	if on:
		main.win_pool.reveal(win, at)   # back once it has drawn again, not with an old picture
	else:
		WinPool.park(win)
	WinPool.draw(win, on)


func _on_input(e: InputEvent) -> void:
	# Left: pick it up (_process moves it). Right: the menu.
	if not (e is InputEventMouseButton and e.pressed):
		return
	if e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = true
		_grab = DisplayServer.mouse_get_position() - at
		main.prop_dragging = true   # full frame rate while held (main._pace_frames)
	elif e.button_index == MOUSE_BUTTON_RIGHT:
		_open_menu()


func _process(_delta: float) -> void:
	# While held, the window follows the pointer every frame, anywhere in the
	# work area; let go (wherever the pointer is) and the place is saved.
	if not _dragging:
		return
	if not (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT):
		_dragging = false
		main.prop_dragging = false
		moved.emit(id, place())
		return
	var r: Rect2 = main.area
	var to := Vector2(DisplayServer.mouse_get_position() - _grab)
	x_fraction = clampf((to.x - r.position.x) / maxf(r.size.x - size.x, 1.0), 0.0, 1.0)
	y_fraction = clampf((to.y - r.position.y) / maxf(r.size.y - size.y, 1.0), 0.0, 1.0)
	if y_fraction > 0.985:
		y_fraction = 1.0   # close to the taskbar: stand on it
	_place()


func _open_menu() -> void:
	if _menu == null:
		_menu = PopupMenu.new()
		_menu.id_pressed.connect(_on_menu)
		win.add_child(_menu)
	_menu.clear()
	_menu.add_item("Put away", 0)
	_menu.add_item("Bring to front" if back else "Send to back", 1)
	_menu.add_item("Make invisible", 2)
	_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO))


func _on_menu(choice: int) -> void:
	match choice:
		0:
			main.put_out.call_deferred(id, false)   # back to storage (Shop > Showpieces)
		1:
			back = not back
			win.always_on_top = not back
			moved.emit(id, place())
		2:
			set_hidden(true)


func free_spot() -> int:
	for i in sleepers.size():
		if sleepers[i] == null or not is_instance_valid(sleepers[i]):
			return i
	return -1


func spot_feet(i: int) -> Vector2:
	# Where a sleeper's feet go, on screen.
	return Vector2(at) + PROPS[id][2][i] * scale_px


func hides() -> bool:
	return PROPS[id][3]


func take(i: int, h) -> void:
	sleepers[i] = h
	if hides():
		h.show_window(false)
		zz.visible = true


func release_all() -> void:
	# Everyone wakes: those inside come out of the door.
	for h in sleepers:
		if h != null and is_instance_valid(h) and hides():
			h.show_window(not main.paused and not main.busy_hidden)
	for i in sleepers.size():
		sleepers[i] = null
	zz.visible = false
