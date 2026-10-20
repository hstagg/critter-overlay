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


func take() -> Window:
	# A spare window, or a new one. A new one is hidden until put_out, so it
	# never flashes up in the middle of the screen.
	if not spare.is_empty():
		var w: Window = spare.pop_back()
		w.process_mode = Node.PROCESS_MODE_INHERIT
		reused += 1
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
	return win


func put_out(win: Window, at: Vector2i, vsync := false) -> void:
	# Onto the screen at `at`, shown without taking the keyboard. The vsync
	# mode is set here because the window only exists once it has been shown:
	# set before that, it reaches whichever window happens to be current.
	win.position = at
	if not win.visible:
		win.show()
	RenderingServer.viewport_set_update_mode(win.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_WHEN_VISIBLE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED, win.get_window_id())


func give_back(win: Window) -> void:
	# Emptied and parked for next time. One that was never shown has no
	# Windows window behind it yet, so freeing it costs nothing.
	if not is_instance_valid(win) or win.is_queued_for_deletion() or win in spare:
		return
	for c in win.get_children():
		c.queue_free()   # not removed now: a toast's own button may be what closed it
	for c in win.window_input.get_connections():
		win.window_input.disconnect(c.callable)
	if not win.visible or spare.size() >= keep:
		win.queue_free()
		return
	park(win)
	RenderingServer.viewport_set_update_mode(win.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, win.get_window_id())
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), win.get_window_id())
	win.content_scale_factor = 1.0
	win.process_mode = Node.PROCESS_MODE_DISABLED
	spare.append(win)


static func park(win: Window) -> void:
	# Out of sight without hiding it (hiding would destroy it).
	win.position = AWAY
