extends Node2D
## One critter: a rig of SVG parts, posed and animated in code, and the small
## state machine that moves it between walking, sitting, loafing and its
## behaviours. Every species extends this file (critters/<species>.gd): it
## sets its proportions in _define(), adds any parts of its own, and poses its
## own behaviours. Everything they share lives here.
##
## main.gd owns the arrivals, presence and the behaviour evaluator (which
## decides when a critter starts a behaviour); host.gd owns its window. This
## file owns how a critter moves and how each behaviour looks.
##
## Every frame builds a fresh set of pose parameters (_base_params), lets the
## current behaviour override them (_behaviour_params), then writes them to
## the rig (_apply). Secondary motion (tail, ears, body squash) runs on damped
## springs stepped at a fixed rate, so it looks the same at 30 and 60 fps.
##
## Art: every part is its own SVG in art/<species>/, drawn in one shared
## 300 x 280 frame, so a part's pivot is simply where it sits in that frame.
## The art faces left.

const Wear := preload("res://wear.gd")
const PART_SCALE := 0.75
const WEAR_HEADROOM := 120.0    # clothes art starts this far above the part frame (tall hats)       # SVG units -> texture pixels
const ACCEL := 4.0             # how quickly walking speed eases to its target, 1/s
const GRAVITY := 1800.0        # px/s^2, for hops and pounces
const REGION_SLACK := 6.0      # px kept clear around a drawn critter
const SPRING_DT := 1.0 / 120.0

static var _textures := {}     # species -> part -> texture
static var zoom := 1.0         # draws everything bigger, for close-up demo captures
static var _wear_textures := {}   # "wear:item:species" -> texture

# --- Species shape: set by each species in _define() ----------------------------
var species := ""
var critter_scale := 0.45      # node scale: SVG texture -> screen
var base_pt := Vector2(150, 262)   # the origin: between the feet, on the ground
var ground_y := 262.0
var head_pivot := Vector2(150, 190)
var pivots := {}               # part -> pivot, SVG units; every part is listed
var head_at := {}              # pose -> where the head's pivot sits
var tail_at := {}              # pose -> where the tail's pivot sits (no entry: hidden)
var tail_rest_deg := {"sit": 0.0, "walk": 0.0}
var walk_legs := []            # [part, hip, diagonal pair, is front, (near)], back to front;
                               # a leg marked near is drawn in front of the body
var leg_len := 38.0            # hip to sole, SVG units
var stride_deg := 18.0         # leg swing either side of straight down
var leg_lift := 6.0            # how high a foot lifts mid-swing, SVG units
var hit_bounds := {}           # pose -> Rect2 in SVG units
var sit_parts := ["body"]      # drawn back to front in the sitting pose
var ear_parts := ["ear-l", "ear-r"]
var speed_range := Vector2(38.0, 62.0)   # px/s cruising speed, picked per critter
var head_height := 60.0        # px above the feet that the eyes look out from
var back_hip := Vector2(205, 224)   # the stretch tips forward about this
var scratch_hides := ""        # sitting part hidden while scratch-foot is up
var activity := 1.0            # how often it stops for a behaviour (Settings > Activity)
var paired := false
var climbing := false          # on a side wall (host.gd): reach-and-pull, tail hanging
var climb_turn := 0.0          # degrees the host turned it onto the wall
var worn: Array = []            # clothes on the head (wear.gd ids)
var perk_moves: Array = []      # behaviours its perk clothes give it
var _wear_nodes: Array = []            # in a pair interaction (pairs.gd): the evaluator leaves it be
var idles := []                # behaviours this species can do (species.gd)

var world: Node                # host.gd's World: floor_y, left_x, right_x, mouse_local()
var rng := RandomNumberGenerator.new()

# Rig nodes. Any a species does not draw stay null.
var torso: Node2D
var torso_in: Node2D
var tail: Node2D
var legs_node: Node2D
var legs_near: Node2D
var legs := []
var body: Node2D
var sit_body: Node2D
var sit_sprites := {}          # part -> sprite, for species that swap them
var walk_body: Node2D
var loaf_body: Node2D
var head: Node2D
var ears := []                 # ear pivots, left first
var ear_l: Node2D
var ear_r: Node2D
var eyes: Node2D
var eyes_open: Node2D
var eyes_shut: Node2D
var mouth_open: Node2D
var nose: Node2D
var groom_paws: Node2D         # both front paws up at the face, for washing
var scratch_foot: Node2D       # a hind foot raised to the ear
var stand_body: Node2D         # up on the hind legs, for a lookout
var puffs: Node2D              # sneeze puffs
var _sprites: Array[Sprite2D] = []   # every part, for region_rect()

# Movement.
var pose := ""
var mode := "sit"              # walk | sit | loaf | act
var mode_left := 0.0
var facing := -1               # -1 faces left (as drawn), +1 faces right
var want_facing := -1
var vx := 0.0                  # px/s, signed
var cruise := 50.0
var gait := 0.0
var air_y := 0.0               # px above the floor
var air_vy := 0.0
var airborne := false
var lift := 0.0                # px the gait raises the body (hops), set each frame
var prev_lift := 0.0
var lift_v := 0.0
var entering := false          # walking in from off-screen; ignore the edges

# Behaviour.
var act := ""                  # the behaviour running, or ""
var act_t := 0.0
var act_len := 0.0
var act_pending := ""          # a behaviour waiting for the critter to stop
var act_pending_len := 0.0
var act_after := ""            # a behaviour chained to start when this one ends
var cooldowns := {}
var hold_nap := false          # nap until told to wake (the user is away)
var sneezed := false
var held := false              # picked up by the pointer: no walking

# Ambient life.
var phase := 0.0
var t := 0.0
var dozing := false
var doze_in := 0.0
var blink_in := 0.0
var blink_left := 0.0
var blink_len := 0.14
var twitch_in := 0.0
var twitch_left := 0.0
var shift_in := 0.0            # weight shift while sitting
var shift_from := 0.0
var shift_to := 0.0
var shift_t := 1.0

# Springs: value, velocity.
var squash := 1.0
var squash_v := 0.0
var tail_s := 0.0
var tail_sv := 0.0
var ears_s := 0.0
var ears_sv := 0.0
var spring_acc := 0.0
var prev_vx := 0.0
var prev_vy := 0.0
var cycle_px := 1.0            # px travelled per full gait cycle


func _define() -> void:
	pass   # each species sets its shape here


func px() -> float:
	# SVG units -> screen pixels, before zoom.
	return PART_SCALE * critter_scale


func setup(world_ref: Node, x: float, face: int, start_mode: String) -> void:
	_define()
	world = world_ref
	rng.randomize()
	position.x = x
	facing = face
	want_facing = face
	phase = rng.randf() * TAU
	gait = rng.randf()
	cruise = rng.randf_range(speed_range.x, speed_range.y) * zoom
	cycle_px = 4.0 * leg_len * sin(deg_to_rad(stride_deg)) * px() * zoom
	blink_in = rng.randf_range(1.0, 5.0)
	twitch_in = rng.randf_range(3.0, 9.0)
	shift_in = rng.randf_range(2.0, 6.0)
	_load_textures()
	_build()
	match start_mode:
		"walk":
			_go_walk()
			vx = facing * cruise
		"loaf":
			_go_loaf(rng.randf_range(8.0, 16.0))
		_:
			_go_sit()
	squash = 1.0


func _load_textures() -> void:
	if _textures.has(species):
		return
	var tex := {}
	for part in pivots.keys():
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://art/%s/%s.svg" % [species, part]), PART_SCALE)
		img.generate_mipmaps()
		tex[part] = ImageTexture.create_from_image(img)
	_textures[species] = tex


# --- Rig -------------------------------------------------------------------

func _sprite(part: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _textures[species][part]
	s.centered = false
	s.position = -pivots[part] * PART_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprites.append(s)
	return s


func _pivot(at_svg: Vector2, parent_at_svg: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = (at_svg - parent_at_svg) * PART_SCALE
	return n


func wear(items: Array, dyes: Dictionary = {}) -> void:
	# Hang clothes on the head pivot, each drawn in this species' part frame,
	# so they ride every pose. One per slot.
	for n in _wear_nodes:
		_sprites.erase(n)
		n.queue_free()
	_wear_nodes.clear()
	worn = Wear.ordered(items)
	perk_moves = Wear.perk_behaviours(worn)
	if head == null:
		return
	# A hood hides the wearer's own ears (or the duckling's tuft).
	var hidden: Array = []
	for id in worn:
		hidden.append_array(Wear.hides(id, species))
	for e in ears:
		e.visible = not "ears" in hidden
	var tuft_node = get("tuft")
	if tuft_node is Node2D:
		tuft_node.visible = not "tuft" in hidden
	for id in worn:
		var path := "res://art/wear/%s/%s.svg" % [id, species]
		if not FileAccess.file_exists(path):
			continue
		var dye: String = dyes.get(id, "")
		var key := "wear:%s:%s:%s" % [id, species, dye]
		if not _wear_textures.has(key):
			var img := Image.new()
			img.load_svg_from_string(Wear.svg(id, species, dye), PART_SCALE)
			img.generate_mipmaps()
			_wear_textures[key] = ImageTexture.create_from_image(img)
		var s := Sprite2D.new()
		s.texture = _wear_textures[key]
		s.centered = false
		s.position = (Vector2(0, -WEAR_HEADROOM) - head_pivot) * PART_SCALE
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		head.add_child(s)
		_sprites.append(s)
		_wear_nodes.append(s)


func _has(part: String) -> bool:
	return pivots.has(part)


func _build() -> void:
	# torso turns about a movable pivot; torso_in cancels the pivot's offset so
	# everything below it is laid out in plain SVG units about base_pt.
	torso = Node2D.new()
	torso_in = Node2D.new()
	torso.add_child(torso_in)
	add_child(torso)
	_build_rig()


func _build_rig() -> void:
	# Draw order, back to front: tail, walking legs, body, near legs, head,
	# then the optional parts in front. A species adds its own parts before
	# or after by overriding this.
	_build_tail()
	_build_legs()
	_build_body()
	torso_in.add_child(legs_near)
	_build_head()
	_build_optional()


func _build_tail() -> void:
	if not _has("tail"):
		return
	tail = _pivot(tail_at.get("sit", pivots["tail"]), base_pt)
	tail.add_child(_sprite("tail"))
	torso_in.add_child(tail)


func _build_legs() -> void:
	legs_node = Node2D.new()
	legs_near = Node2D.new()
	for spec in walk_legs:
		var hip := _pivot(spec[1], base_pt)
		hip.add_child(_sprite(spec[0]))
		var near: bool = spec.size() > 4 and spec[4]
		(legs_near if near else legs_node).add_child(hip)
		legs.append({"node": hip, "hip": spec[1], "pair": spec[2], "front": spec[3]})
	torso_in.add_child(legs_node)


func _build_body() -> void:
	body = _pivot(base_pt, base_pt)
	sit_body = Node2D.new()
	for part in sit_parts:
		var s := _sprite(part)
		sit_sprites[part] = s
		sit_body.add_child(s)
	body.add_child(sit_body)
	if _has("walk-body"):
		walk_body = _sprite("walk-body")
		body.add_child(walk_body)
	if _has("loaf-body"):
		loaf_body = _sprite("loaf-body")
		body.add_child(loaf_body)
	if _has("stand-body"):
		stand_body = Node2D.new()
		if _has("stand-feet"):
			stand_body.add_child(_sprite("stand-feet"))
		stand_body.add_child(_sprite("stand-body"))
		body.add_child(stand_body)
	torso_in.add_child(body)


func _build_head() -> void:
	head = _pivot(head_at["sit"], base_pt)
	for part in ear_parts:
		var ear := _pivot(pivots[part], head_pivot)
		ear.add_child(_sprite(part))
		head.add_child(ear)
		ears.append(ear)
	if ears.size() >= 2:
		ear_l = ears[0]
		ear_r = ears[1]
	head.add_child(_sprite("head"))
	eyes = _pivot(pivots["eyes"], head_pivot)
	eyes_open = _sprite("eyes")
	eyes.add_child(eyes_open)
	if _has("eyes-closed"):
		eyes_shut = _sprite("eyes-closed")
		eyes.add_child(eyes_shut)
	head.add_child(eyes)
	if _has("mouth-open"):
		mouth_open = _pivot(pivots["mouth-open"], head_pivot)
		mouth_open.add_child(_sprite("mouth-open"))
		head.add_child(mouth_open)
	if _has("nose"):
		nose = _pivot(pivots["nose"], head_pivot)
		nose.add_child(_sprite("nose"))
		head.add_child(nose)
	_build_head_extras()
	torso_in.add_child(head)


func _build_head_extras() -> void:
	pass


func _build_optional() -> void:
	# Parts drawn in front, used by the shared behaviours.
	if _has("scratch-foot"):
		scratch_foot = _pivot(pivots["scratch-foot"], base_pt)
		scratch_foot.add_child(_sprite("scratch-foot"))
		scratch_foot.visible = false
		torso_in.add_child(scratch_foot)   # over the cheek, where it can be seen
	if _has("groom-paws"):
		groom_paws = _pivot(pivots["groom-paws"], base_pt)
		groom_paws.add_child(_sprite("groom-paws"))
		groom_paws.visible = false
		torso_in.add_child(groom_paws)


func _set_pose(p: String) -> void:
	if p == pose:
		return
	pose = p
	if tail != null:
		tail.visible = tail_at.has(p)
		if tail.visible:
			tail.position = (tail_at[p] - base_pt) * PART_SCALE
	legs_node.visible = p == "walk"
	legs_near.visible = p == "walk"
	sit_body.visible = p == "sit"
	if walk_body != null:
		walk_body.visible = p == "walk"
	if loaf_body != null:
		loaf_body.visible = p == "loaf"
	if stand_body != null:
		stand_body.visible = p == "stand"
	_on_pose(p)
	_kick_squash(-1.2)   # a small settle on every change of pose


func _on_pose(_p: String) -> void:
	pass


# --- Modes -----------------------------------------------------------------

func _go_walk() -> void:
	mode = "walk"
	mode_left = rng.randf_range(3.0, 8.0)
	if rng.randf() < 0.3:
		want_facing = -facing
	_set_pose("walk")


func _go_sit() -> void:
	mode = "sit"
	mode_left = rng.randf_range(2.0, 6.0)
	_set_pose("sit")


func _go_loaf(duration: float) -> void:
	mode = "loaf"
	mode_left = duration
	dozing = false
	doze_in = rng.randf_range(2.0, 5.0)
	_set_pose("loaf")


func _settled() -> bool:
	# Whether the gait is at a point where the critter can stop, sit or turn
	# (a hopper is not, in mid-air).
	return true


func _next_mode() -> void:
	match mode:
		"walk":
			if not _settled():
				return
			_go_sit()
		"sit":
			if rng.randf() < 0.75 or on_cooldown("nap"):
				_go_walk()
			else:
				_go_loaf(rng.randf_range(8.0, 16.0))
		"loaf":
			_wake()


func _wake() -> void:
	dozing = false
	hold_nap = false
	cooldowns["nap"] = 60.0   # do not drop straight back off
	_go_sit()
	if rng.randf() < 0.7 and can_do("stretch"):
		start_behaviour("stretch", 1.8)
	elif can_do("wake_up"):
		start_behaviour("wake_up", 0.8)


# --- Behaviours (called by main.gd's evaluator) ----------------------------

func can_do(b: String) -> bool:
	return idles.has(b) or perk_moves.has(b)


func can_start_behaviour() -> bool:
	return act == "" and act_pending == "" and not airborne and not entering \
		and mode != "loaf" and not hold_nap and not held and not paired


func is_napping() -> bool:
	return mode == "loaf"


func on_cooldown(b: String) -> bool:
	return cooldowns.get(b, 0.0) > 0.0


func start_behaviour(b: String, duration: float) -> void:
	if b == "nap":
		_go_loaf(duration)
		return
	# A walking critter eases to a stop first.
	if absf(vx) > 4.0:
		act_pending = b
		act_pending_len = duration
		return
	_begin(b, duration)


func _begin(b: String, duration: float) -> void:
	act = b
	act_t = 0.0
	act_len = duration
	mode = "act"
	_set_pose(_act_pose(b))
	_on_begin(b)


func _act_pose(b: String) -> String:
	# The pose a behaviour is done in.
	match b:
		"stretch":
			return "walk"
		"stand_lookout":
			return "stand" if stand_body != null else "sit"
	return "sit"


func _on_begin(b: String) -> void:
	if b == "sneeze":
		sneezed = false
	if b == "celebrate" and not airborne:
		_launch(-520.0 * zoom)   # a happy jump; host.gd throws the confetti


func _end_behaviour() -> void:
	var finished := act
	act = ""
	if act_after != "":
		var next := act_after
		act_after = ""
		_begin(next, 1.1)
		return
	match finished:
		"stretch":
			if rng.randf() < 0.6:
				_go_walk()
			else:
				_go_sit()
		_:
			_go_sit()


func go_to_sleep() -> void:
	# The user has gone away: settle down and stay asleep until wake_up().
	act = ""
	act_pending = ""
	act_after = ""
	hold_nap = true
	if mode != "loaf":
		_go_loaf(INF)
	mode_left = INF


func wake_up() -> void:
	if mode == "loaf":
		_wake()
	hold_nap = false


func poke() -> void:
	# Clicked: hop. A napping critter wakes up first.
	if mode == "loaf":
		dozing = false
		hold_nap = false
		_go_sit()
	if not _can_hop():
		return
	if not airborne:
		_launch(-420.0 * zoom)


func _can_hop() -> bool:
	return true


func _launch(vy: float) -> void:
	airborne = true
	air_vy = vy
	_kick_squash(2.2)   # stretch on take-off


func _kick_squash(v: float) -> void:
	squash_v += v


# --- Per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	t += delta
	for b in cooldowns.keys():
		cooldowns[b] = maxf(0.0, cooldowns[b] - delta)

	_update_mode(delta)
	_update_motion(delta)
	_update_ambient(delta)
	_step_springs(delta)

	var p := _base_params()
	if act != "":
		_behaviour_params(p)
	_apply(p)


func _update_mode(delta: float) -> void:
	if held:
		return
	if act != "":
		act_t += delta
		if act_t >= act_len:
			_end_behaviour()
		return
	if act_pending != "":
		if absf(vx) < 4.0 and not airborne and _settled():
			var b := act_pending
			act_pending = ""
			_begin(b, act_pending_len)
		return
	mode_left -= delta
	if mode_left <= 0.0:
		_next_mode()


func _update_motion(delta: float) -> void:
	if held:
		vx = 0.0
		return
	var left: float = world.left_x
	var right: float = world.right_x
	var target := 0.0
	if mode == "walk" and act_pending == "":
		if entering:
			if position.x > left and position.x < right:
				entering = false
		elif (position.x <= left and facing < 0) or (position.x >= right and facing > 0):
			want_facing = -facing
		if want_facing != facing:
			target = 0.0
			if absf(vx) < 3.0 and _settled():
				facing = want_facing   # turn round once stopped
				_kick_squash(-1.0)
		else:
			target = facing * cruise
	if not airborne:
		vx += (target - vx) * (1.0 - exp(-ACCEL * delta))
	var surge := 1.0
	if pose == "walk":
		surge = _climb_surge() if climbing else _gait_speed()
	position.x += vx * delta * surge

	if airborne:
		air_vy += GRAVITY * zoom * delta
		air_y -= air_vy * delta
		if air_y <= 0.0:
			# Landing: squash in proportion to how hard it came down.
			air_y = 0.0
			airborne = false
			_kick_squash(-clampf(air_vy / (140.0 * zoom), 0.5, 3.5))
			air_vy = 0.0

	if pose == "walk":
		_advance_gait(delta)
	else:
		lift = 0.0


func _advance_gait(delta: float) -> void:
	# The gait's phase, 0 to 1. By default it follows distance, so feet do
	# not skate; a hopping species follows time instead.
	gait = fmod(gait + absf(vx) * delta / cycle_px, 1.0)


func _climb_surge() -> float:
	# Climbing goes in pulls: slow while reaching, quick while hauling up.
	# Averages 1 over a cycle.
	var s := sin(gait * TAU)
	return 0.35 + 1.3 * s * s


func _gait_speed() -> float:
	# How fast the body moves at this point in the gait, as a share of its
	# walking speed. Averages 1 over a cycle.
	return 1.0


func _update_ambient(delta: float) -> void:
	if mode == "loaf" and not dozing:
		doze_in -= delta
		if doze_in <= 0.0:
			dozing = true

	blink_in -= delta
	if blink_in <= 0.0 and not dozing:
		var loafing := mode == "loaf"
		blink_len = 0.35 if loafing else 0.14
		blink_left = blink_len
		blink_in = rng.randf_range(1.5, 3.0) if loafing else rng.randf_range(2.5, 6.0)
	if blink_left > 0.0:
		blink_left -= delta

	twitch_in -= delta
	if twitch_in <= 0.0:
		twitch_left = 0.25
		twitch_in = rng.randf_range(4.0, 10.0)
	if twitch_left > 0.0:
		twitch_left -= delta

	if mode == "sit" and act == "":
		shift_in -= delta
		if shift_in <= 0.0:
			shift_from = lerpf(shift_from, shift_to, _ease_io(shift_t))
			shift_to = rng.randf_range(-2.5, 2.5) if rng.randf() < 0.7 else 0.0
			shift_t = 0.0
			shift_in = rng.randf_range(2.0, 6.0)
	shift_t = minf(1.0, shift_t + delta / 0.6)


func _step_springs(delta: float) -> void:
	# Accelerations felt by the critter, in its own facing frame: forward is
	# the way it faces, so the tail lags behind whichever way it turns.
	var ax := 0.0
	var ay := 0.0
	if delta > 0.0:
		ax = (vx - prev_vx) / delta * facing / zoom   # positive: speeding up forwards
		var lv := (prev_lift - lift) / delta   # px/s, positive falling, like air_vy
		ay = (air_vy - prev_vy + lv - lift_v) / delta / zoom
		lift_v = lv
	prev_lift = lift
	prev_vx = vx
	prev_vy = air_vy
	spring_acc += minf(delta, 0.1)
	while spring_acc >= SPRING_DT:
		spring_acc -= SPRING_DT
		var h := SPRING_DT
		# Body squash: a bouncy spring about 1.
		squash_v += (-260.0 * (squash - 1.0) - 9.0 * squash_v) * h
		squash += squash_v * h
		# Tail: lags speed changes, settles slowly, a little underdamped.
		tail_sv += (-40.0 * tail_s - 6.0 * tail_sv + ax * 0.012) * h
		tail_s += tail_sv * h
		# Ears: flop on landings and take-offs.
		ears_sv += (-160.0 * ears_s - 10.0 * ears_sv - ay * 0.004) * h
		ears_s += ears_sv * h
	squash = clampf(squash, 0.7, 1.3)
	tail_s = clampf(tail_s, -0.6, 0.6)
	ears_s = clampf(ears_s, -0.5, 0.5)


# --- Pose parameters ------------------------------------------------------------

func _base_params() -> Dictionary:
	var walking := pose == "walk"
	var loafing := pose == "loaf"
	var breath_period := 4.6 if loafing else 3.4
	var breath := (sin(t * TAU / breath_period + phase) + 1.0) * 0.5
	var p := {
		"torso_pivot": base_pt, "torso_rot": 0.0, "torso_dy": 0.0,
		"breath": breath, "breath_y": 0.05 if loafing else 0.035,
		"head_off": Vector2(0, 2.5 * breath), "head_rot": 0.0,
		"eyes_off": Vector2.ZERO, "eyes_closed": dozing, "blink": true,
		"mouth": 0.0, "tongue": 0.0, "nose": 0.0,
		"paws_up": 0.0, "paws_dy": 0.0, "scratch": 0.0, "scratch_rot": 0.0, "rise": 1.0,
		"arm": false, "arm_rot": 0.0, "arm_dy": 0.0,
		"tail_rot": 0.0, "tail_extra": 0.0, "ear_l": 0.0, "ear_r": 0.0,
		"legs": "gait", "leg_front": 0.0, "leg_back": 0.0, "lean": 0.0, "float": 0.0,
	}
	if walking:
		var moving := smoothstep(0.0, 15.0, absf(vx))
		p.head_off = p.head_off + Vector2(0, sin(gait * TAU * 2.0 - 0.8) * 1.5 * moving)   # a beat behind the body
		p.eyes_off = Vector2(-6.0, 0)   # looking where it is going
		p.tail_rot = tail_rest_deg["walk"] - 6.0 * (sin(t * 4.0 + phase) + 1.0) * 0.5
	elif pose == "sit":
		p.tail_rot = -9.0 * (sin(t * 2.2 + phase) + 1.0) * 0.5
		p.lean = lerpf(shift_from, shift_to, _ease_io(shift_t))
	if twitch_left > 0.0:
		p.ear_r = sin((1.0 - twitch_left / 0.25) * TAU) * -10.0
	if climbing and pose == "walk":
		_climb_params(p)
	return p


func _climb_params(p: Dictionary) -> void:
	# On a wall: head up the climb, ears back, body leaning in, tail hanging.
	var pull := sin(gait * TAU)
	# The head stays upright while the body lies along the wall: undo the
	# wall's turn (mirrored when facing right, since the rig is flipped).
	p.head_rot += -climb_turn * (1.0 if facing < 0 else -1.0)
	p.head_off = p.head_off + Vector2(-12.0, -4.0)   # a little further up the wall, clear of the body
	p.torso_rot += 6.0 + 2.0 * pull
	p.ear_l -= 12.0
	p.ear_r -= 12.0
	p.tail_extra += 28.0


func _behaviour_params(p: Dictionary) -> void:
	# The behaviours every species does the same way. A species poses its own
	# by overriding this and passing the rest back here.
	var u := act_t
	match act:
		"sit_and_look":
			# Looks one way, then the other, with the head following a little.
			var look := sin(u * 1.4) * 6.0
			p.eyes_off = Vector2(look, -1.0)
			p.head_off = p.head_off + Vector2(look * 0.4, 0)
		"look_at_cursor":
			var m: Vector2 = world.mouse_local()
			var head_px := position + Vector2(0, -head_height) * zoom
			var d := (m - head_px)
			d.x *= -facing   # into the drawn (left-facing) frame
			var dir := d.normalized() if d.length() > 1.0 else Vector2.ZERO
			p.eyes_off = dir * 7.0
			p.head_rot = clampf(dir.x * 6.0, -6.0, 6.0) * _env(u, act_len, 0.3)
		"yawn":
			_yawn_params(p, u, act_len)
		"ear_flick":
			var f := sin(u / act_len * TAU * 2.0) * (1.0 - u / act_len)
			p.ear_l = 14.0 * f
			p.ear_r = -14.0 * f
		"tail_swish":
			p.tail_extra = sin(u / act_len * TAU * 1.5) * 22.0 * (1.0 - u / act_len)
		"stretch":
			_stretch_params(p, u)
		"groom":
			_paw_wash_params(p, u)
		"scratch":
			_scratch_params(p, u)
		"sneeze":
			_sneeze_params(p, u)
		"shake_off":
			_shake_params(p, u)
		"listen":
			_listen_params(p, u)
		"wake_up":
			_wake_up_params(p, u)
		"nose_twitch":
			var n := _env(u, act_len, 0.08)
			p.nose = n * sin(u * TAU * 7.0)
			p.head_off = p.head_off + Vector2(0, 0.8 * p.nose)
		"stand_lookout":
			_lookout_params(p, u)
		"dance":
			# Sway and bob to the beat, ears swinging, eyes happily shut.
			var beat := sin(u * TAU * 2.0)
			var k := _env(u, act_len, 0.3)
			p.torso_rot += 8.0 * beat * k
			p.head_rot += -6.0 * beat * k
			p.torso_dy -= 6.0 * absf(beat) * k
			p.ear_l += 12.0 * beat * k
			p.ear_r -= 12.0 * beat * k
			p.eyes_closed = k > 0.5 and fmod(u, 1.0) > 0.5
			p.blink = false
			p.tail_extra += 20.0 * beat * k
		"fly":
			# Up into the air, bobbing, then gently down again.
			var k := _env(u, act_len, 0.8)
			p.float = (46.0 + 5.0 * sin(u * TAU * 1.5)) * k
			p.head_rot += 4.0 * sin(u * TAU * 0.8) * k
			p.ear_l -= 10.0 * k
			p.ear_r -= 10.0 * k
		"celebrate":
			var k := _env(u, act_len, 0.2)
			p.ear_l -= 14.0 * k
			p.ear_r -= 14.0 * k
			p.eyes_closed = true
			p.blink = false


func _stretch_params(p: Dictionary, u: float) -> void:
	# A play bow: tip forward about the back hips, front legs reaching out,
	# tail up, eyes shut, then a yawn at full stretch.
	var s := _ease_io(_env(u, act_len, 0.45))
	p.torso_pivot = back_hip
	p.torso_rot = -14.0 * s
	p.legs = "plant"
	p.leg_front = 1.0
	p.leg_back = 0.0
	p.tail_rot = tail_rest_deg["walk"] - 22.0 * s
	p.eyes_off = Vector2.ZERO
	if s > 0.6:
		p.eyes_closed = true
		p.blink = false
		var y := clampf((u - 0.5) / maxf(0.1, act_len - 0.9), 0.0, 1.0)
		p.mouth = sin(y * PI)
	p.head_rot = -6.0 * s


func _paw_wash_params(p: Dictionary, u: float) -> void:
	# Both front paws up to the face, rubbing down over the cheeks, head
	# bobbing into them, eyes shut.
	var up := _ease_io(_env(u, act_len, 0.3))
	p.paws_up = up
	var rub := sin(u * TAU * 2.2)
	p.paws_dy = (1.0 - up) * 40.0 + 7.0 * rub * up
	p.head_off = p.head_off + Vector2(0, 2.0 * up + 2.0 * rub * up)
	p.head_rot += 4.0 * sin(u * TAU * 1.1) * up
	p.eyes_closed = up > 0.5
	p.blink = false
	p.ear_l += 6.0 * up
	p.ear_r -= 6.0 * up


func _scratch_params(p: Dictionary, u: float) -> void:
	# A hind foot up to the ear, scratching fast, head tilted into it.
	var up := _ease_io(_env(u, act_len, 0.25))
	var buzz := sin(u * TAU * 9.0)
	p.scratch = up
	p.scratch_rot = 7.0 * buzz * up
	p.head_rot += 16.0 * up
	p.head_off = p.head_off + Vector2(6.0, 6.0) * up
	p.lean = p.lean - 4.0 * up
	p.eyes_closed = up > 0.6
	p.blink = false
	p.ear_r += 10.0 * up + 6.0 * buzz * up


func _sneeze_params(p: Dictionary, u: float) -> void:
	# Wind up with the head back, then snap forward with a squash and a puff.
	var wind := 0.55 * act_len
	if u < wind:
		var w := _ease_io(u / wind)
		p.head_rot -= 9.0 * w
		p.head_off = p.head_off - Vector2(0, 4.0 * w)
		p.eyes_closed = w > 0.5
		p.nose = 0.6 * w
	else:
		if not sneezed:
			sneezed = true
			_kick_squash(-2.4)
			_puff()
		var k := 1.0 - clampf((u - wind) / (act_len - wind), 0.0, 1.0)
		p.head_rot += 8.0 * k
		p.head_off = p.head_off + Vector2(0, 5.0 * k)
		p.eyes_closed = k > 0.4
	p.blink = false


func _shake_params(p: Dictionary, u: float) -> void:
	# A shake from the head down: fast twisting that dies away, ears flapping.
	var k := _env(u, act_len, 0.12) * (1.0 - 0.6 * u / act_len)
	var w := u * TAU * 7.0
	p.head_rot += 14.0 * sin(w) * k
	p.lean = p.lean + 5.0 * sin(w - 0.9) * k
	p.ear_l += 22.0 * sin(w - 1.4) * k
	p.ear_r += 22.0 * sin(w - 1.4) * k
	p.tail_extra = 18.0 * sin(w - 2.0) * k
	p.eyes_closed = k > 0.3
	p.blink = false


func _listen_params(p: Dictionary, u: float) -> void:
	# Ears up and turning to a sound, head cocked, eyes off to one side.
	var k := _ease_io(_env(u, act_len, 0.2))
	var side := 1.0 if fmod(phase, 2.0) < 1.0 else -1.0
	p.ear_l += (-6.0 + 10.0 * side) * k
	p.ear_r += (6.0 + 10.0 * side) * k
	p.head_rot += 7.0 * side * k
	p.eyes_off = Vector2(6.0 * side, -3.0) * k
	p.blink = false


func _wake_up_params(p: Dictionary, u: float) -> void:
	# Two slow blinks, a little head shake, ears perking up.
	var f := u / act_len
	p.eyes_closed = f < 0.15 or (f > 0.35 and f < 0.45)
	p.blink = false
	p.head_rot += 5.0 * sin(f * TAU * 2.0) * (1.0 - f)
	p.ear_l -= 6.0 * sin(f * PI)
	p.ear_r += 6.0 * sin(f * PI)


func _lookout_params(p: Dictionary, u: float) -> void:
	# Up on the hind legs, looking round one way then the other.
	var r := _ease_io(clampf(u / 0.3, 0.0, 1.0))
	var down := _ease_io(clampf((act_len - u) / 0.25, 0.0, 1.0))
	p.rise = minf(r, down)
	var look := sin(u * 1.6) * 7.0
	p.eyes_off = Vector2(look, -2.0)
	p.head_off = p.head_off + Vector2(look * 0.3, 0)
	p.ear_l -= 4.0
	p.ear_r += 4.0


func _yawn_params(p: Dictionary, u: float, length: float) -> void:
	var open := _env(u, length, 0.35)
	p.mouth = open
	p.eyes_closed = open > 0.3
	p.blink = false
	p.head_rot -= 7.0 * open
	p.head_off = p.head_off - Vector2(0, 3.0 * open)
	p.ear_l -= 8.0 * open
	p.ear_r += 8.0 * open


# --- Writing the pose to the rig ---------------------------------------------

func _apply(p: Dictionary) -> void:
	var walking := pose == "walk"

	position.y = world.floor_y - air_y - lift - p.get("float", 0.0) * zoom
	var sq := squash
	scale = Vector2(critter_scale * zoom * (1.0 + (1.0 - sq) * 0.6) * (1.0 if facing < 0 else -1.0), critter_scale * zoom * sq)

	var pivot: Vector2 = p.torso_pivot
	torso.position = (pivot - base_pt + Vector2(0, p.torso_dy)) * PART_SCALE
	torso_in.position = -(pivot - base_pt) * PART_SCALE
	torso.rotation = deg_to_rad(p.torso_rot)

	body.scale = Vector2(1.0 + 0.018 * p.breath, 1.0 + p.breath_y * p.breath)
	body.rotation = deg_to_rad(p.lean)

	var head_pt: Vector2 = head_at[pose]
	if pose == "stand":
		# Rising from sitting: the head comes up as the body stretches tall.
		head_pt = head_at["sit"].lerp(head_pt, p.rise)
		stand_body.scale = Vector2(1.0, lerpf(0.72, 1.0, p.rise))
	head.position = (head_pt - base_pt + p.head_off) * PART_SCALE
	head.rotation = deg_to_rad(p.head_rot + p.lean * 0.6)
	eyes.position = (pivots["eyes"] - head_pivot + p.eyes_off) * PART_SCALE
	var shut: bool = p.eyes_closed and eyes_shut != null
	eyes_open.visible = not shut
	if eyes_shut != null:
		eyes_shut.visible = shut
	var closed := 1.0
	if p.blink and blink_left > 0.0:
		closed = 1.0 - sin(clampf(1.0 - blink_left / blink_len, 0.0, 1.0) * PI)
	if p.eyes_closed and eyes_shut == null:
		closed = 0.0
	eyes_open.scale = Vector2(1.0, maxf(0.08, closed))
	if mouth_open != null:
		mouth_open.visible = p.mouth > 0.02
		mouth_open.scale = Vector2(0.8 + 0.2 * p.mouth, p.mouth)
	if ear_l != null:
		ear_l.rotation = deg_to_rad(p.ear_l) - ears_s
		ear_r.rotation = deg_to_rad(p.ear_r) + ears_s
	if nose != null:
		nose.scale = Vector2(1.0 + 0.3 * p.nose, 1.0 - 0.35 * p.nose)
		nose.position = (pivots["nose"] - head_pivot + Vector2(0, -3.0 * p.nose)) * PART_SCALE
	if groom_paws != null:
		groom_paws.visible = p.paws_up > 0.0
		if sit_sprites.has("paws"):
			sit_sprites["paws"].visible = p.paws_up <= 0.0
		groom_paws.position = (pivots["groom-paws"] - base_pt + Vector2(0, p.paws_dy)) * PART_SCALE
	if scratch_foot != null:
		scratch_foot.visible = p.scratch > 0.15
		if scratch_hides != "":
			sit_sprites[scratch_hides].visible = p.scratch <= 0.0
		scratch_foot.rotation = deg_to_rad(p.scratch_rot)
		scratch_foot.scale = Vector2(1.0, lerpf(0.5, 1.0, p.scratch))   # unfolds from the heel
	if puffs != null:
		_step_puffs()

	_apply_extras(p)

	if tail != null and tail.visible:
		tail.rotation = deg_to_rad(p.tail_rot + p.tail_extra) + tail_s

	if walking:
		_apply_legs(p)


func _apply_extras(_p: Dictionary) -> void:
	pass   # a species' own parts


# --- Sneeze puffs -------------------------------------------------------------

class Puff extends Node2D:
	var v := Vector2.ZERO
	var age := 0.0
	var life := 0.6
	var r := 8.0
	func _draw() -> void:
		var a := clampf(1.0 - age / life, 0.0, 1.0)
		var rr := r * (0.5 + 0.9 * age / life)
		draw_circle(Vector2.ZERO, rr, Color(1, 1, 1, 0.95 * a))
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 16, Color(0.42, 0.29, 0.23, 0.25 * a), 1.5)


func _puff() -> void:
	# A few soft puffs from the nose, in the critter's own frame, so they
	# leave the face whichever way it faces.
	if puffs == null:
		puffs = Node2D.new()
		torso_in.add_child(puffs)
	var at: Vector2 = pivots["nose"] if _has("nose") else pivots["eyes"] + Vector2(0, 26)
	var from: Vector2 = head.position + (at - head_pivot + Vector2(-2, 6)) * PART_SCALE
	for i in 6:
		var q := Puff.new()
		q.position = from + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
		q.v = Vector2(rng.randf_range(-420.0, -160.0), rng.randf_range(-120.0, 120.0))
		q.r = rng.randf_range(5.0, 10.0)
		q.life = rng.randf_range(0.3, 0.5)
		puffs.add_child(q)


func _step_puffs() -> void:
	var dt := get_process_delta_time()
	for q in puffs.get_children():
		q.age += dt
		q.position += q.v * dt
		q.v *= 1.0 - 2.5 * dt
		q.queue_redraw()
		if q.age >= q.life:
			q.queue_free()


func _apply_legs(p: Dictionary) -> void:
	match p.legs:
		"gait":
			_gait_legs()
		"plant":
			_plant_legs(p)
		"leap":
			for leg in legs:
				var node: Node2D = leg.node
				node.position = (leg.hip - base_pt) * PART_SCALE
				node.rotation = deg_to_rad(40.0 if leg.front else -40.0)


func _gait_legs() -> void:
	var moving := smoothstep(0.0, 15.0, absf(vx))
	var stance_deg := 0.0
	var reach := 1.5 if climbing else 1.0   # longer reaches up a wall, feet lifted clear
	for leg in legs:
		var ph: float = fmod(gait + 0.5 * leg.pair, 1.0)
		var a: float
		var lift := 0.0
		if ph < 0.5:
			# Stance: the foot is planted and sweeps back at the body's speed.
			a = lerpf(stride_deg, -stride_deg, ph / 0.5) * reach
			stance_deg = a / reach
		else:
			# Swing: the foot lifts and eases forward to the next step.
			var s := (ph - 0.5) / 0.5
			a = lerpf(-stride_deg, stride_deg, smoothstep(0.0, 1.0, s)) * reach
			lift = sin(s * PI) * leg_lift * (1.8 if climbing else 1.0)
		var node: Node2D = leg.node
		node.rotation = deg_to_rad(a * moving)
		node.position = (leg.hip - base_pt + Vector2(0, -lift * moving)) * PART_SCALE
	# A swung leg is shorter vertically, so the body dips at each footfall
	# and rises over the planted foot: the bob comes from the legs.
	var drop := leg_len * (1.0 - cos(deg_to_rad(stance_deg * moving)))
	torso.position.y += drop * PART_SCALE


func _plant_legs(p: Dictionary) -> void:
	# Turn each leg so its foot rests on the ground wherever the tilted or
	# lowered torso has put its hip. Front legs reach forwards, back legs
	# backwards (or stand straight when the weight is 0).
	var pivot: Vector2 = p.torso_pivot
	var rot := deg_to_rad(p.torso_rot)
	for leg in legs:
		var hip: Vector2 = leg.hip
		var world_hip: Vector2 = pivot + (hip - pivot).rotated(rot) + Vector2(0, p.torso_dy)
		var c := clampf((ground_y - world_hip.y) / leg_len, -1.0, 1.0)
		var reach: float = p.leg_front if leg.front else p.leg_back
		var angle := acos(c) * signf(reach) if reach != 0.0 else 0.0
		var node: Node2D = leg.node
		node.position = (hip - base_pt) * PART_SCALE
		node.rotation = angle - rot


func hit_rect() -> Rect2:
	# The pose's hit box in window pixels, mirrored when facing right, with a
	# few pixels of slack below the feet.
	var b: Rect2 = hit_bounds[pose]
	var k := px() * zoom
	var x0 := (b.position.x - base_pt.x) * k
	var w := b.size.x * k
	if facing > 0:
		x0 = -x0 - w
	return Rect2(position + Vector2(x0, (b.position.y - base_pt.y) * k), Vector2(w, b.size.y * k + 4.0))


func region_rect() -> Rect2:
	# Everything drawn this frame, in window pixels, wherever springs, squash
	# and stretches have put the parts. host.gd keeps the click-through hole
	# off it, since nothing inside the hole is drawn.
	var r := hit_rect()
	for s in _sprites:
		if s.is_visible_in_tree():
			r = r.merge(s.get_global_transform() * s.get_rect())
	return r.grow(REGION_SLACK)


# --- Helpers ------------------------------------------------------------------

func _env(u: float, length: float, ramp: float) -> float:
	# 0 -> 1 over `ramp` seconds, hold, 1 -> 0 over the last `ramp` seconds.
	return clampf(minf(u / ramp, (length - u) / ramp), 0.0, 1.0)


func _ease_io(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
