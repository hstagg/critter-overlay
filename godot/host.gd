extends Node
## One critter on the desktop: its own small transparent window that moves
## with it, so critters can go anywhere without a full-screen window (which
## the compositor promotes to fullscreen flip and turns black).
##
## The critter keeps its own walking logic along a single track (its x). The
## host turns that track into a place on screen:
##   roam       the track is screen x; the host drifts y while it walks, and
##              bounces it off the top and bottom (v2.0's free roamers)
##   perimeter  the track runs round the screen's edges, and the rig is
##              rotated to stand on whichever edge it is on (v2.0's solos)
## and owns what happens to it: drag, throw, pop.
##
## Throwing (Harrison, 6 Oct): a gentle throw slides across the screen,
## bounces off its sides and stops; a hard one leaves the screen, at a capped
## speed so nothing flies off like a cannon. Sliding critters knock into each
## other like pool balls (main.gd _bumps).

signal gone(host)

const Region := preload("res://region.gd")
const Species := preload("res://species.gd")
const Aura := preload("res://aura.gd")
const Trail := preload("res://trail.gd")

const WINDOW := 240.0          # px across at zoom 1: room for a tall hat and a hop
const FOOT_DROP := 50.0        # px at zoom 1 the feet sit below the window's centre
const LEDGE := 120.0           # px below the top of the screen where top walkers' feet are
const DRAG_THRESHOLD := 8.0    # px of travel that turns a click into a drag
const ESCAPE_SPEED := 1600.0   # px/s: released faster than this, it leaves the screen
const MAX_THROW := 2000.0      # px/s: the fastest anything goes
const SLIDE_FRICTION := 1.6    # 1/s
const SLIDE_DECEL := 220.0     # px/s^2, so a slide comes to a definite stop
const STOP_SPEED := 30.0       # px/s: slow enough to be back on its feet
const WALL_BOUNCE := 0.55      # speed kept off a side of the screen
const BODY_R := 40.0           # px at zoom 1: the round body that bumps
const POP_TIME := 0.7          # s of particles before the window closes

var main: Node                 # main.gd: the screen, the sound, the pointer
var species := ""
var critter: Node2D
var win: Window
var spin: Node2D               # rotated to the edge being walked on
var track: Node2D              # slides the critter's track under the window
var size := 200
var kind := "roam"             # roam | perimeter

# Roaming.
var y := 0.0
var vy := 0.0

# Perimeter: lengths of the four edges, bottom, right, top, left.
var edges := PackedFloat32Array()
var edges_ledge := 0.0

# Drag, throw, pop.
var state := "live"            # live | held | sliding | thrown | popping

# A visit: its rarity, how long it stays (seconds of focus), and leaving.
var tier := "common":
	set(v):
		tier = v
		_make_aura()
var aura: Node2D               # rare and up: the aura, behind and in front
var opacity := 1.0             # Settings > Critters > Opacity
var foot_drop := FOOT_DROP

# Walking to a showpiece for a nap (main.gd sends it when you step away).
var nap_goal := Vector2.INF        # screen px for its feet
var _confetti_for := ""            # the celebration already showered
var nap_prop: Node = null
var nap_spot := -1
var trail: Node2D              # its trail, if it leaves one
var zoom := 1.0
var stay_left := INF
var leaving := false
var fade := 1.0
var fade_away := false
var grab_from := Vector2.ZERO  # screen px where the button went down
var grab_offset := Vector2.ZERO
var moved := 0.0
var history := []              # [time s, screen pos]
var foot := Vector2.ZERO       # screen px of the feet, while held or thrown
var throw_v := Vector2.ZERO
var spin_v := 0.0
var pop_left := 0.0
var particles := []

# Click-through hole.
var _hole := Rect2(-1, -1, 0, 0)
var world: Node


class World extends Node:
	## What a critter reads from its world: the floor, the ends of its track,
	## and the pointer in its own coordinates.
	var floor_y := 0.0
	var left_x := -INF
	var right_x := INF
	var host: Node
	var look_at := Vector2.INF   # a screen point to look at instead of the pointer (pairs.gd)
	func mouse_local() -> Vector2:
		var at := look_at if look_at.x != INF else Vector2(DisplayServer.mouse_get_position())
		return host.to_critter(at)


class Particle extends Node2D:
	var v := Vector2.ZERO
	var colour := Color.WHITE
	var life := 0.0
	var age := 0.0
	var r := 5.0
	func step(delta: float) -> bool:
		age += delta
		v.y += 420.0 * delta
		v *= 1.0 - 1.5 * delta
		position += v * delta
		queue_redraw()
		return age < life
	func _draw() -> void:
		var a := 1.0 - age / life
		draw_circle(Vector2.ZERO, r * (0.4 + 0.6 * a), Color(colour, a))


func setup(main_ref: Node, species_id: String, zoom: float, how: String, start_mode: String, at := Vector2(-1, -1)) -> void:
	main = main_ref
	species = species_id
	kind = how
	self.zoom = zoom
	size = int(WINDOW * zoom)
	foot_drop = FOOT_DROP * zoom

	win = Window.new()
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = true
	win.unfocusable = true
	win.size = Vector2i(size, size)
	# Created hidden and shown once it is in place (end of setup), so no
	# window flashes up in the middle of the screen, and shown without taking
	# the keyboard from whatever the user is typing in.
	win.visible = false
	win.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	add_child(win)
	# One window paces the frame; more vsyncs only cost frames.
	if not main.vsync_taken:
		main.vsync_taken = true
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, win.get_window_id())
	win.window_input.connect(_on_input)

	spin = Node2D.new()
	spin.position = Vector2(size, size) * 0.5
	win.add_child(spin)
	track = Node2D.new()
	spin.add_child(track)

	world = World.new()
	world.host = self
	add_child(world)
	var r: Rect2 = main.area
	if kind == "perimeter":
		# The sides stop at the top ledge, where they walk upright.
		edges_ledge = LEDGE * zoom
		var side := r.size.y - edges_ledge
		edges = PackedFloat32Array([r.size.x, side, r.size.x, side])
	else:
		world.left_x = r.position.x + size * 0.3
		world.right_x = r.end.x - size * 0.3

	critter = Species.row(species)["script"].new()
	critter.idles = Species.row(species)["idles"]
	track.add_child(critter)
	var face: int = [-1, 1].pick_random()
	var x0: float
	if kind == "perimeter":
		# Anywhere round the edges, or at a point on the bottom edge if asked.
		x0 = randf_range(0.0, 2.0 * (r.size.x + r.size.y)) if at.x < 0 else at.x - r.position.x
	else:
		x0 = randf_range(world.left_x, world.right_x) if at.x < 0 else at.x
		y = randf_range(r.position.y + size, r.end.y) if at.y < 0 else at.y
		vy = randf_range(-35.0, 35.0)
	critter.setup(world, x0, face, start_mode)
	_place()
	win.show()


# --- Where it is ----------------------------------------------------------------

func _edge_pose(s: float) -> Array:
	# A distance round the perimeter -> [feet in screen px, rotation, mirrored].
	# Going up the track runs left to right along the bottom, up the right
	# wall, right to left along the top and down the left wall. Walls are
	# walked side-on, rotated to stand on them; the top is walked upright on a
	# ledge just below the edge, mirrored so the critter faces the way it goes,
	# never upside down.
	var r: Rect2 = main.area
	var top := r.position.y + edges_ledge
	var total := edges[0] + edges[1] + edges[2] + edges[3]
	var d := fposmod(s, total)
	if d < edges[0]:
		return [Vector2(r.position.x + d, r.end.y), 0.0, false]
	d -= edges[0]
	if d < edges[1]:
		return [Vector2(r.end.x, r.end.y - d), -PI * 0.5, false]
	d -= edges[1]
	if d < edges[2]:
		return [Vector2(r.end.x - d, top), 0.0, true]
	d -= edges[2]
	return [Vector2(r.position.x, top + d), PI * 0.5, false]


func _place() -> void:
	var feet: Vector2
	var rot := 0.0
	var mirror := false
	match state:
		"held", "sliding", "thrown", "popping":
			feet = foot
			rot = spin.rotation if state == "popping" else 0.0
			mirror = spin.scale.x < 0.0 and state == "popping"
		_:
			if kind == "perimeter":
				var p := _edge_pose(critter.position.x)
				feet = p[0]
				rot = p[1]
				mirror = p[2]
				critter.climbing = absf(rot) > 1.0   # the side walls
				if critter.climbing and critter.facing * sin(rot) > 0.0:
					# Its head would point down the wall: mirror it along the
					# wall instead, so it backs down tail-first like a cat.
					mirror = true
				critter.climb_turn = rad_to_deg(rot) * (-1.0 if mirror else 1.0)
			else:
				feet = Vector2(critter.position.x, y)
	spin.rotation = rot
	spin.scale = Vector2(-1.0 if mirror else 1.0, 1.0)
	# The critter's track slides under the window so it stays in the middle.
	track.position = Vector2(-critter.position.x, foot_drop)
	var centre := feet - Vector2(0, foot_drop).rotated(rot)
	win.position = Vector2i((centre - Vector2(size, size) * 0.5).round())


func feet_on_screen() -> Vector2:
	return Vector2(win.position) + Vector2(size, size) * 0.5 + Vector2(0, foot_drop).rotated(spin.rotation)


func to_critter(screen_pt: Vector2) -> Vector2:
	# A screen point in the coordinates the critter moves in.
	var local := screen_pt - Vector2(win.position)
	return (track.get_global_transform()).affine_inverse() * local


func _critter_box() -> Rect2:
	# The critter's hit box in window pixels.
	return track.get_global_transform() * critter.hit_rect()


# --- Per frame ------------------------------------------------------------------

func tick(delta: float) -> void:
	match state:
		"live":
			critter.tick(delta)
			if leaving and _left_the_screen(delta):
				_close()
				return
			if nap_goal.x != INF:
				_walk_to_nap(delta)
			elif kind == "roam" and critter.mode == "walk" and not critter.airborne:
				# Drift up or down the screen in step with the walk.
				if randf() < delta * 0.25:
					vy = randf_range(-40.0, 40.0)
				var r: Rect2 = main.area
				y += vy * delta * clampf(absf(critter.vx) / maxf(critter.cruise, 1.0), 0.0, 1.0)
				if y < r.position.y + size * 0.6 or y > r.end.y:
					vy = -vy
					y = clampf(y, r.position.y + size * 0.6, r.end.y)
		"held":
			critter.tick(delta)
			var m := Vector2(DisplayServer.mouse_get_position())
			foot = m + grab_offset
			moved = maxf(moved, m.distance_to(grab_from))
			history.append([Time.get_ticks_msec() / 1000.0, m])
			while history.size() > 2 and history[-1][0] - history[0][0] > 0.12:
				history.pop_front()
		"sliding":
			critter.tick(delta)
			var sp := throw_v.length()
			var nsp := maxf(0.0, sp * exp(-SLIDE_FRICTION * delta) - SLIDE_DECEL * delta)
			throw_v = throw_v * (nsp / sp) if sp > 0.0 else Vector2.ZERO
			foot += throw_v * delta
			# Off the sides of the screen, losing some speed each time.
			var r: Rect2 = main.area
			var lo := Vector2(r.position.x + size * 0.3, r.position.y + size * 0.6)
			var hi := Vector2(r.end.x - size * 0.3, r.end.y)
			for i in 2:
				if foot[i] < lo[i] or foot[i] > hi[i]:
					foot[i] = clampf(foot[i], lo[i], hi[i])
					throw_v[i] = -throw_v[i] * WALL_BOUNCE
			# Leaning into the slide, upright again as it slows.
			critter.rotation = clampf(throw_v.x / 2600.0, -0.35, 0.35)
			if nsp < STOP_SPEED:
				_settle()
		"thrown":
			# Off the screen in a straight line, tumbling.
			critter.tick(delta)
			foot += throw_v * delta
			critter.rotation += spin_v * delta
			var bounds := Rect2(main.screen_rect).grow(size)
			if not bounds.has_point(foot):
				_close()
				return
		"popping":
			pop_left -= delta
			particles = particles.filter(func(p): return p.step(delta))
			if pop_left <= 0.0:
				_close()
				return
	_place()
	if state == "live" and critter.act == "celebrate" and critter.act_t < 0.2 and _confetti_for != str(critter.act_len):
		_confetti_for = str(critter.act_len)
		_confetti()
	if state != "popping" and not particles.is_empty():
		particles = particles.filter(func(p):
			if p.step(delta):
				return true
			p.queue_free()
			return false)
	if trail != null:
		# The body's place on screen, and whether it is going anywhere.
		var body: Vector2 = (foot if state in ["held", "sliding", "thrown"] else feet_on_screen()) - Vector2(0, 36.0 * zoom).rotated(spin.rotation)
		var moving: bool = state in ["sliding", "thrown"] or (state == "live" and critter.mode == "walk" and absf(critter.vx) > 5.0 * zoom)
		trail.step(delta, body, moving)
	_update_hole()


func set_trail(style: String, palette: Array) -> void:
	# "none" takes it away. Drawn under the critter.
	var key := "%s|%s" % [style, palette]
	if trail != null and trail.get_meta("key", "") == key:
		return
	if trail != null:
		trail.queue_free()
		trail = null
	if style == "none" or win == null:
		return
	trail = Trail.new()
	trail.setup(self, style, palette, zoom)
	trail.set_meta("key", key)
	win.add_child(trail)
	win.move_child(trail, 0)


# --- Pointer ------------------------------------------------------------------

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and state in ["live", "sliding"] and _critter_box().has_point(event.position):
			critter.rotation = 0.0
			if spin.scale.x < 0.0:
				critter.facing = -critter.facing
				critter.want_facing = critter.facing
			if state == "live":
				foot = feet_on_screen()
			state = "held"
			critter.held = true
			grab_from = Vector2(DisplayServer.mouse_get_position())
			grab_offset = foot - grab_from
			moved = 0.0
			history = [[Time.get_ticks_msec() / 1000.0, grab_from]]
		elif not event.pressed and state == "held":
			_release()


func release_if_up() -> void:
	# Called each frame by main.gd: the button can come up outside this
	# window, where its release event never arrives.
	if state == "held" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		and not (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT):
		_release()


func _release() -> void:
	if moved < DRAG_THRESHOLD:
		critter.held = false
		pop()
		return
	var v := Vector2.ZERO
	if history.size() >= 2:
		var a = history[0]
		var b = history[-1]
		v = (b[1] - a[1]) / maxf(b[0] - a[0], 0.001)
	launch(v)
	main.note_throw()
	if state == "thrown":
		main.play_sound(Species.row(species)["sound"], species)


func launch(v: Vector2) -> void:
	# Sends it off at v (capped): sliding if gentle, off the screen if hard.
	# Also how a bump knocks a standing critter (main.gd _bumps).
	critter.held = true   # no walking until it stops
	if v.length() > MAX_THROW:
		v = v.normalized() * MAX_THROW
	throw_v = v
	spin_v = clampf(v.x / 160.0, -8.0, 8.0)
	state = "thrown" if v.length() >= ESCAPE_SPEED else "sliding"
	if state == "sliding" and v.length() < STOP_SPEED:
		_settle()


func restate() -> void:
	# After a bump: fast enough to leave, or slowed into a slide.
	if state == "thrown" and throw_v.length() < ESCAPE_SPEED:
		state = "sliding"
	elif state == "sliding" and throw_v.length() >= ESCAPE_SPEED:
		state = "thrown"


func knock(v: Vector2) -> void:
	# Hit by a sliding critter: off it goes too.
	if state != "live":
		throw_v = v
		return
	cancel_nap()
	if critter.is_napping():
		critter.wake_up()
	critter.act = ""
	foot = feet_on_screen()
	launch(v)


func body_centre() -> Vector2:
	var feet: Vector2 = foot if state in ["held", "sliding", "thrown"] else feet_on_screen()
	return feet - Vector2(0, 36.0 * zoom)


func can_bump() -> bool:
	# Standing roamers and anything on the move; not climbers on the walls,
	# not ones tucked inside a showpiece.
	if not win.visible or leaving:
		return false
	if state in ["sliding", "thrown"]:
		return true
	return state == "live" and not critter.climbing and nap_prop == null


func _settle() -> void:
	# Stopped: back on its feet where it is. An edge walker thrown into the
	# middle of the screen stays a free roamer from then on.
	state = "live"
	critter.held = false
	critter.rotation = 0.0
	throw_v = Vector2.ZERO
	if kind == "perimeter":
		kind = "roam"
		var r: Rect2 = main.area
		world.left_x = r.position.x + size * 0.3
		world.right_x = r.end.x - size * 0.3
		critter.climbing = false
		critter.climb_turn = 0.0
		vy = randf_range(-35.0, 35.0)
	critter.position.x = foot.x
	critter.vx = 0.0
	y = foot.y
	_place()


func leave(quietly := false) -> void:
	# The visit is over. A roamer walks off the nearer side of the screen; an
	# edge walker, which has no side to walk off, fades away. `quietly`: fade
	# where it is (tidied away during a long break, napping, unwatched).
	if leaving or state != "live":
		return
	leaving = true
	fade_away = quietly
	if kind == "roam" and not quietly:
		world.left_x = -INF
		world.right_x = INF
		critter.hold_nap = false
		critter.act = ""
		critter._go_walk()
		critter.mode_left = INF
		var r: Rect2 = main.area
		critter.want_facing = -1 if critter.position.x < r.get_center().x else 1


func _left_the_screen(delta: float) -> bool:
	if kind == "roam" and not fade_away:
		critter.mode_left = INF   # keep walking
		var r: Rect2 = main.area
		return critter.position.x < r.position.x - size or critter.position.x > r.end.x + size
	fade -= delta / 1.2
	spin.modulate.a = clampf(fade, 0.0, 1.0) * opacity
	return fade <= 0.0


func go_nap_at(prop: Node, spot: int) -> void:
	nap_prop = prop
	nap_spot = spot
	nap_goal = prop.spot_feet(spot)
	critter.hold_nap = false
	critter.act = ""


func cancel_nap() -> void:
	nap_goal = Vector2.INF
	nap_prop = null
	nap_spot = -1


func _walk_to_nap(delta: float) -> void:
	# Over to the spot, level with it, then curl up there.
	var k = critter
	var gx: float = clampf(nap_goal.x, world.left_x, world.right_x)
	var dx: float = gx - k.position.x
	y = move_toward(y, nap_goal.y, 80.0 * zoom * delta)
	if absf(dx) > 6.0 * zoom:
		if k.mode != "walk":
			k._go_walk()
		k.mode_left = INF
		k.want_facing = 1 if dx > 0.0 else -1
	elif absf(y - nap_goal.y) < 3.0 and absf(k.vx) < 8.0:
		k.go_to_sleep()
		if is_instance_valid(nap_prop):
			nap_prop.take(nap_spot, self)
		nap_goal = Vector2.INF
	else:
		k.want_facing = k.facing
		if k.mode == "walk":
			k._go_sit()
			k.mode_left = INF


func set_opacity(o: float) -> void:
	opacity = o
	if spin != null:
		spin.modulate.a = clampf(fade, 0.0, 1.0) * opacity


func _make_aura() -> void:
	# Common critters have none. The aura goes behind the critter's track in
	# the spin node and its front layer after it.
	if aura != null:
		aura.front.queue_free()
		aura.queue_free()
		aura = null
	if spin == null or not Aura.TIER.has(tier):
		return
	aura = Aura.new()
	aura.setup(tier, species, critter, zoom, foot_drop)
	spin.add_child(aura)
	spin.move_child(aura, 0)
	spin.add_child(aura.front)


func _confetti() -> void:
	# The confetti crown's shower, from just above the head.
	var at := Vector2(size, size) * 0.5 + Vector2(0, foot_drop - 90.0 * zoom).rotated(spin.rotation)
	var cols := [Color("#F590B4"), Color("#7FBCF5"), Color("#86D9B0"), Color("#FFCF5C"), Color("#C8A8FF")]
	for i in 22:
		var p := Particle.new()
		p.position = at
		p.v = Vector2.from_angle(randf_range(-PI * 0.95, -PI * 0.05)) * randf_range(90.0, 220.0) * zoom
		p.colour = cols.pick_random()
		p.life = randf_range(0.8, 1.4)
		p.r = randf_range(2.5, 4.5) * zoom
		win.add_child(p)
		particles.append(p)


func pop() -> void:
	# v2.0's click: a burst of particles, the species sound, and gone.
	state = "popping"
	foot = feet_on_screen()
	critter.visible = false
	if aura != null:
		aura.visible = false
		aura.front.visible = false
	pop_left = POP_TIME
	var at := Vector2(size, size) * 0.5
	for i in randi_range(10, 16):
		var p := Particle.new()
		p.position = at
		p.v = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 170.0) - Vector2(0, 60)
		p.colour = Species.row(species)["pop"].pick_random()
		p.life = randf_range(0.4, POP_TIME)
		p.r = randf_range(3.0, 6.0)
		win.add_child(p)
		particles.append(p)
	main.note_pop()
	main.note_play(species)
	main.play_sound(Species.row(species)["sound"], species)


func _close() -> void:
	state = "gone"
	gone.emit(self)
	queue_free()


func _update_hole() -> void:
	# Clicks through the window, except on the critter: a hole under the
	# pointer when it is over this window but not over the critter.
	if main.no_passthrough:
		return
	var s := Vector2(size, size)
	var m := Vector2(DisplayServer.mouse_get_position() - win.position)
	var hole := Rect2()
	if state == "live" and Rect2(Vector2.ZERO, s).has_point(m) and not _critter_box().grow(4.0).has_point(m):
		hole = Rect2(m + Region.HOLE_FROM, Region.HOLE_TO - Region.HOLE_FROM)
		if hole.intersects(critter.region_rect()):
			hole = Rect2(m - Vector2(1, 1), Vector2(3, 3))   # nothing inside a hole is drawn
		hole = hole.intersection(Rect2(Vector2.ZERO, s))
	if hole == _hole:
		return
	_hole = hole
	DisplayServer.window_set_mouse_passthrough(Region.polygon(s, hole), win.get_window_id())
