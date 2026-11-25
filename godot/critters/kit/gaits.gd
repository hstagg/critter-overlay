extends RefCounted
## The gaits a homemade critter can walk with (docs/custom-critters-build-plan.md,
## 4.5), as static functions the kit rigs (critters/kit/*.gd) call from their
## overrides of tick, _advance_gait, _gait_speed, _settled, _base_params and
## _apply_legs.
##
## Each copied gait does exactly what its species does: the constants are the
## species' own, with the line they come from, and gaits_test.gd drives the
## species and this file side by side to keep them equal. The species
## scripts themselves are not changed (plan section 3), so this file cannot
## break the cast.
##
## A rig owns one state dictionary per critter (`s`), made by state(): the
## gait's name, its counters (hop_k, freeze_*, slide_*), and the pins it
## rocks or pitches about (mid, feet), which a kit takes from its parts.
##
## "c" is the critter: these read and write its gait, vx, lift, pose and so
## on, and call its _kick_squash, the same way the species' code does.

const NAMES := ["trot", "hop", "waddle", "plod", "scurry", "dart", "slide", "bounce", "sway",
	"blob_bounce", "glide", "float", "slither"]
const LEGLESS := ["blob_bounce", "glide", "float", "slither"]   # the blob plan's own (4.4)

# hop: rabbit.gd:46-50
const HOP_CYCLE := 0.8
const ARC := 0.625             # share of the cycle in the air
const ARC_SPEED := 1.55        # body speed in the air, as a share of cruising speed
const HOLD_SPEED := 0.08       # creeping forward between hops (averages 1 with the arc)
const HOP_HEIGHT := 20.0       # px at full speed

# blob_bounce: new. A shorter, lower hop with no legs; the squash does the work.
const BLOB_CYCLE := 0.7
const BLOB_ARC := 0.55
const BLOB_HOLD := 0.1
const BLOB_ARC_SPEED := (1.0 - (1.0 - BLOB_ARC) * BLOB_HOLD) / BLOB_ARC   # averages 1
const BLOB_HEIGHT := 14.0

# float: new. Bobbing in the air, never touching the ground; in drawing
# units (plan 4.4: 10 to 20 up), so a big ghost floats as high for its size.
const FLOAT_PERIOD := 1.6      # s per bob
const FLOAT_HEIGHT := 15.0     # units held above the ground
const FLOAT_BOB := 5.0         # units either way


static func state(gait_name: String, mid := Vector2(150, 220), feet := Vector2(150, 262)) -> Dictionary:
	# A new critter's gait state. mid: what a hop pitches about (rabbit's
	# BODY_MID); feet: what a waddle rocks about (duckling's FEET).
	return {"name": gait_name if gait_name in NAMES else "trot", "mid": mid, "feet": feet,
		"hop_k": 1.0, "freeze_in": 3.0, "freeze_left": 0.0, "slide_in": 4.0, "slide_left": 0.0}


static func timed(s: Dictionary) -> bool:
	# Whether the gait follows time rather than distance.
	return s.name in ["hop", "blob_bounce"]


# --- tick: before the critter's own (dart, slide) ---------------------------------

static func tick(c, s: Dictionary, delta: float) -> void:
	match s.name:
		"dart":
			# squirrel.gd:94-110. Walking, every few seconds it stops dead,
			# looks, and darts off faster than it was going.
			if c.mode == "walk" and c.act == "" and not c.airborne and not c.entering and not c.climbing:
				if s.freeze_left > 0.0:
					s.freeze_left -= delta
					c.vx = 0.0
					if s.freeze_left <= 0.0:
						c.vx = c.facing * c.cruise * 1.6
						c._kick_squash(1.0)
				else:
					s.freeze_in -= delta
					if s.freeze_in <= 0.0:
						s.freeze_in = c.rng.randf_range(2.0, 5.0)
						s.freeze_left = c.rng.randf_range(0.4, 1.1)
						c._kick_squash(-1.4)
		"slide":
			# otter.gd:103-117. Now and then, walking, it flops onto its belly
			# and slides.
			if c.mode == "walk" and c.act == "" and not c.airborne and not c.climbing and not c.entering:
				if s.slide_left > 0.0:
					s.slide_left -= delta
				else:
					s.slide_in -= delta
					if s.slide_in <= 0.0:
						s.slide_in = c.rng.randf_range(5.0, 10.0)
						s.slide_left = c.rng.randf_range(1.0, 1.8)
						c.vx = c.facing * c.cruise * 1.8
						c._kick_squash(-1.2)
			else:
				s.slide_left = 0.0


# --- The phase ---------------------------------------------------------------------

static func advance(c, s: Dictionary, delta: float) -> bool:
	# Moves the gait's phase on. False: the rig's default (by distance) applies.
	match s.name:
		"hop":
			_hop_advance(c, s, delta, HOP_CYCLE, ARC, HOP_HEIGHT)
			return true
		"blob_bounce":
			_hop_advance(c, s, delta, BLOB_CYCLE, BLOB_ARC, BLOB_HEIGHT)
			return true
		"slide":
			return s.slide_left > 0.0   # otter.gd:124-127: legs stay tucked while sliding
	return false


static func _hop_advance(c, s: Dictionary, delta: float, cycle: float, arc: float, height: float) -> void:
	# rabbit.gd:95-113. Time, not distance: a hop in the air always finishes;
	# a new one starts only while it means to keep moving.
	var moving: bool = absf(c.vx) > 6.0 * c.zoom
	var was: float = c.gait
	if c.gait < arc or moving:
		c.gait += delta / cycle
		if c.gait >= 1.0:
			c.gait -= 1.0
	if was >= arc and c.gait < arc:
		s.hop_k = clampf(absf(c.vx) / maxf(c.cruise, 1.0), 0.4, 1.0)
		c._kick_squash(1.4 * s.hop_k)        # stretch leaving the ground
	elif was < arc and c.gait >= arc:
		c._kick_squash(-1.9 * s.hop_k)       # squash on landing
	if c.gait < arc:
		var u: float = c.gait / arc
		c.lift = height * c.zoom * s.hop_k * 4.0 * u * (1.0 - u)
	else:
		c.lift = 0.0


static func speed(c, s: Dictionary) -> float:
	# The body's speed at this point in the gait, as a share of walking speed.
	# Averages 1 over a cycle.
	var g: float = c.gait
	match s.name:
		"hop":
			return ARC_SPEED if g < ARC else HOLD_SPEED            # rabbit.gd:116-117
		"blob_bounce":
			return BLOB_ARC_SPEED if g < BLOB_ARC else BLOB_HOLD
		"plod":
			return 1.0 + 0.45 * sin(g * TAU * 2.0)                 # turtle.gd:73-75
		"scurry":
			return 1.0 + 0.3 * sin(g * TAU * 2.0)                  # hedgehog.gd:181-183
		"slide":
			return 1.4 if s.slide_left > 0.0 else 1.0               # otter.gd:120-121
		"slither":
			return 1.0 + 0.25 * sin(g * TAU * 2.0)
	return 1.0


static func settled(c, s: Dictionary) -> bool:
	# Whether it can stop, sit or turn now: never in mid-air (rabbit.gd:120-122).
	match s.name:
		"hop":
			return c.pose != "walk" or c.gait >= ARC
		"blob_bounce":
			return c.pose != "walk" or c.gait >= BLOB_ARC
	return true


# --- Pose --------------------------------------------------------------------------

static func hover(c) -> float:
	# float: px held above the ground now, in every pose.
	return (FLOAT_HEIGHT + FLOAT_BOB * sin(c.t * TAU / FLOAT_PERIOD + c.phase)) * c.px()


static func params(c, s: Dictionary, p: Dictionary) -> void:
	# The gait's part of the pose, on top of critter.gd's _base_params.
	if s.name == "float":
		p.float += hover(c)   # critter.gd _apply lifts the body by p.float (x zoom)
	if c.pose != "walk":
		return
	var g: float = c.gait
	match s.name:
		"hop", "blob_bounce":
			var arc := ARC if s.name == "hop" else BLOB_ARC
			if g < arc:
				# rabbit.gd:127-135: nose up, then nose down; ears stream back.
				var u := g / arc
				p.torso_pivot = s.mid
				p.torso_rot = 10.0 * cos(PI * u) * s.hop_k
				p.head_off = p.head_off + Vector2(0, 3.0 * cos(PI * u) * s.hop_k)
				var back: float = 6.0 + 12.0 * sin(PI * u) * s.hop_k
				p.ear_l += back
				p.ear_r += back
			elif absf(c.vx) > 6.0 * c.zoom:
				# rabbit.gd:136-139: gathering for the next hop, a small crouch.
				var h := (g - arc) / (1.0 - arc)
				p.torso_dy = 4.0 * smoothstep(0.5, 1.0, h)
		"waddle":
			# duckling.gd:129-137: rock over the planted foot, tail the other way.
			var moving := smoothstep(0.0, 15.0, absf(c.vx))
			var rock := sin(g * TAU)
			p.torso_pivot = s.feet
			p.torso_rot = 2.5 * rock * moving
			p.tail_extra = -8.0 * rock * moving
			p.head_off = p.head_off + Vector2(0.6 * rock * moving, 0)
		"plod":
			# turtle.gd:84-87: a heavy sway from foot to foot.
			var moving := smoothstep(0.0, 10.0, absf(c.vx))
			p.torso_rot += 1.2 * sin(g * TAU) * moving
		"sway":
			# panda.gd:70-76: the lumber, head rolling with it.
			var moving := smoothstep(0.0, 12.0, absf(c.vx))
			var sway := sin(g * TAU)
			p.torso_rot += 2.2 * sway * moving
			p.head_rot += -3.0 * sway * moving
		"bounce":
			# unicorn.gd:153-157: the body rises a touch at each stride.
			var moving := smoothstep(0.0, 12.0, absf(c.vx))
			p.torso_dy -= 2.0 * absf(sin(g * TAU * 2.0)) * moving
		"dart":
			if s.freeze_left > 0.0:
				# squirrel.gd:115-118: frozen, head up, tail twitching.
				p.head_off = p.head_off + Vector2(0, -3.0)
				p.tail_extra += 10.0 * sin(c.t * 18.0)
		"slide":
			if s.slide_left > 0.0:
				# otter.gd:133-139: on its belly, legs tucked, eyes shut.
				var k := smoothstep(0.0, 0.2, s.slide_left) * smoothstep(0.0, 0.2, 1.8 - s.slide_left)
				p.torso_dy += 14.0 * k
				p.legs = "tuck"
				p.head_off = p.head_off + Vector2(-4.0, 6.0) * k
				p.eyes_closed = true
				p.blink = false
		"float":
			p.torso_rot += 2.0 * sin(g * TAU + 0.6)
		"glide":
			# new: gliding along, a slow wobble.
			var moving := smoothstep(0.0, 10.0, absf(c.vx))
			p.torso_pivot = s.feet
			p.torso_rot += 2.5 * sin(c.t * 3.0 + c.phase) * moving
		"slither":
			var moving := smoothstep(0.0, 10.0, absf(c.vx))
			p.torso_pivot = s.feet
			p.torso_rot += 3.0 * sin(g * TAU) * moving
			p.torso_dy += 1.5 * (1.0 - cos(g * TAU * 2.0)) * moving


static func hop_legs(c, s: Dictionary) -> Vector2:
	# rabbit.gd:148-165: the hop's leg angles in degrees, x front and y hind,
	# for the near pair (the far pair takes 0.85 of them).
	var hind := 0.0
	var front := 0.0
	var g: float = c.gait
	if g < ARC:
		var u := g / ARC
		hind = _keys(u, [[0.0, 0.0], [0.22, -42.0], [0.7, 18.0], [1.0, 6.0]]) * s.hop_k
		front = _keys(u, [[0.0, 0.0], [0.25, -28.0], [0.72, 34.0], [1.0, 4.0]]) * s.hop_k
	else:
		var h := 1.0 - smoothstep(0.0, 0.35, (g - ARC) / (1.0 - ARC))
		hind = 6.0 * h * s.hop_k
		front = 4.0 * h * s.hop_k
	return Vector2(front, hind)


static func _keys(u: float, keys: Array) -> float:
	# rabbit.gd:168-175: eased steps between [time, value] keys.
	for i in range(1, keys.size()):
		if u <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(a[1], b[1], _ease_io((u - a[0]) / (b[0] - a[0])))
	return keys[-1][1]


static func _ease_io(x: float) -> float:
	# critter.gd:1245.
	return x * x * (3.0 - 2.0 * x)
