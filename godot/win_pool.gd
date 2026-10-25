extends Node
## Transparent windows, kept and used again instead of freed (S2 in
## docs/v3-launch-plan.md).
##
## Godot leaks a GDI object (the HRGN it makes for DwmEnableBlurBehindWindow)
## each time it makes a transparent window, and it makes a new one every time
## a Window is shown, because hiding a Window destroys it (soak report,
## finding 4). Arrivals, toasts and every pause add up towards Windows'
## 10,000-object limit over days of running. So a window here is made once
## and never hidden again: one not in use is parked far off the screen with
## its drawing switched off, and handed out again for the next critter or
## toast.
##
## The windows are children of this node, not of whatever uses them, because
## a Window that leaves the scene tree is destroyed too.

const AWAY := Vector2i(-30000, -30000)   # off every screen

var keep := 8                  # spare windows kept; any more are freed
var close_request := Callable()   # main.gd: Windows asked a window to close
var spare: Array[Window] = []
var made := 0                  # windows made, for the Admin page
var reused := 0                # and handed out again
const HOLD_FRAMES := 3         # frames drawn off the screen before a window is shown

# Windows waiting off the screen until they have drawn: [where to go, the
# frame count (Engine.get_frames_drawn) to wait for]. Counted in frames drawn,
# not process ticks: at a capped frame rate a tick can pass with nothing
# presented, and an arrival still showed a white box for a moment. One just shown, or unparked with its drawing off, still holds its
# last picture (or nothing, which Windows shows as a white box) for a frame
# or two (the toast and arrival flash). Static, so park() can let one go.
static var held := {}
static var test_frames := -1   # the tests count their own frames (a lambda in a static crashed at exit)


func take() -> Window:
	# A spare window, or a new one. A new one is hidden until put_out, so it
	# never flashes up in the middle of the screen.
	if not spare.is_empty():
		var w: Window = spare.pop_back()
		w.process_mode = Node.PROCESS_MODE_INHERIT
		reused += 1
		held[w] = [AWAY, _drawn() + HOLD_FRAMES]   # placed by move() until put out and drawn
		return w
	var win := Window.new()
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = true
	win.unfocusable = true
	win.visible = false
	win.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	add_child(win)
	if close_request.is_valid():
		win.close_requested.connect(close_request)
	made += 1
	held[win] = [AWAY, _drawn() + HOLD_FRAMES]
	return win


func put_out(win: Window, at: Vector2i, vsync := false) -> void:
	# Onto the screen at `at`, shown without taking the keyboard. The vsync
	# mode is set here because the window only exists once it has been shown:
	# set before that, it reaches whichever window happens to be current.
	if not win.visible:
		show_away(win)
	reveal(win, at)
	draw(win, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED, win.get_window_id())


static func show_away(win: Window) -> void:
	# Shows a window for the first time without a white box. Godot makes the
	# Windows window on a screen whatever position it is given (one off every
	# screen lands in the primary screen's top-left corner), and Windows shows
	# it there, blank and so white, until the game moves it away: the box at
	# each arrival and toast (VM recording, 2026-10-25). So it is made one
	# pixel across, sent off the screen at once, and only then given its size.
	var want := win.size
	win.size = Vector2i.ONE
	win.position = AWAY
	win.show()
	win.position = AWAY   # Godot placed it on a screen; this moves the real window
	win.size = want


static func _drawn() -> int:
	return test_frames if test_frames >= 0 else Engine.get_frames_drawn()


func reveal(win: Window, at: Vector2i) -> void:
	# To `at` once it has drawn HOLD_FRAMES frames off the screen.
	win.position = AWAY
	held[win] = [at, _drawn() + HOLD_FRAMES]


func move(win: Window, at: Vector2i) -> void:
	# Where a window goes: now, or when its hold ends.
	if held.has(win):
		held[win][0] = at
	elif win.position != at:
		win.position = at   # only when it moved: each move is a call into Windows


func _process(_delta: float) -> void:
	for win in held.keys():
		if not is_instance_valid(win) or win.is_queued_for_deletion():
			held.erase(win)
			continue
		if not win.visible:
			held[win][1] = _drawn() + HOLD_FRAMES   # not put out yet: the wait starts when it is
			continue
		if _drawn() >= held[win][1]:
			win.position = held[win][0]
			held.erase(win)


func give_back(win: Window) -> void:
	# Emptied and parked for next time. One that was never shown has no
	# Windows window behind it yet, so freeing it costs nothing.
	if not is_instance_valid(win) or win.is_queued_for_deletion() or win in spare:
		return
	held.erase(win)
	for c in win.get_children():
		c.queue_free()   # not removed now: a toast's own button may be what closed it
	for c in win.window_input.get_connections():
		win.window_input.disconnect(c.callable)
	if not win.visible or spare.size() >= keep:
		win.queue_free()
		return
	park(win)
	draw(win, false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, win.get_window_id())
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), win.get_window_id())
	win.content_scale_factor = 1.0
	win.process_mode = Node.PROCESS_MODE_DISABLED
	spare.append(win)


static func park(win: Window) -> void:
	# Out of sight without hiding it (hiding would destroy it).
	held.erase(win)
	win.position = AWAY


static func draw(win: Window, on: bool) -> void:
	# Whether the window is drawn each frame. A parked one need not be.
	RenderingServer.viewport_set_update_mode(win.get_viewport_rid(),
		RenderingServer.VIEWPORT_UPDATE_WHEN_VISIBLE if on else RenderingServer.VIEWPORT_UPDATE_DISABLED)
