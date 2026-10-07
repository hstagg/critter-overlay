extends Node2D
## A critter's rarity aura (design canvas "Critter Rarity Auras", direction A
## "Halo and motes", Legendary as "Sunburst and prism").
##
## Two layers in the critter's window: this node draws behind the critter,
## `front` in front of it. Both sit in the host's spin node, so they turn with
## an edge walker and fade with a leaving critter.
##
##   Uncommon   a soft mint glow, leaves drifting up
##   Rare       a blue glow, diamonds, twinkling glints
##   Epic       a rose glow, stars, glints, stars orbiting the body
##   Legendary  a gold glow, turning sunburst rays, a spinning prism ring,
##              rainbow sparkles, two pulse rings, orbiting sparkles, and a
##              crown that floats above the head
##
## Sizes are the canvas's, which drew the window at twice game size: one
## canvas px is half a game px, times the critter zoom.

const TIER := {
	#            colour     deep       glow  min  max   rise motes glints orbs
	"uncommon": ["#86D9B0", "#2F9E6C", 240, 0.30, 0.50, 120, 4, 0, 0],
	"rare": ["#7FBCF5", "#2F7FD0", 270, 0.40, 0.65, 150, 6, 3, 0],
	"epic": ["#F590B4", "#D6457C", 300, 0.50, 0.78, 165, 8, 4, 3],
	"legendary": ["#FFCF5C", "#D9961A", 330, 0.60, 0.92, 185, 12, 6, 5],
}
const SHAPE := {
	"uncommon": "M10 3c4 3.2 5.6 6.2 5.6 8.6a5.6 5.6 0 0 1-11.2 0C4.4 9.2 6 6.2 10 3z",
	"rare": "M10 2.5 16.8 10 10 17.5 3.2 10z",
	"epic": "M10 2.4l2.3 4.8 5.2.6-3.9 3.6 1.1 5.2L10 14l-4.7 2.6 1.1-5.2-3.9-3.6 5.2-.6z",
	"legendary": "M10 1.5l2 6.5 6.5 2-6.5 2-2 6.5-2-6.5-6.5-2 6.5-2z",
}
const Wear := preload("res://wear.gd")
const SPARKLE := "M10 1.5l2 6.5 6.5 2-6.5 2-2 6.5-2-6.5-6.5-2 6.5-2z"
const CROWN := "M3 15.5h14l1.2-9.2-4.6 3.6L10 3.8 6.4 9.9 1.8 6.3z"
# Legendary sparkles cycle through these (the prism look).
const RAINBOW := ["#F590B4", "#FFFFFF", "#7FBCF5", "#FFFFFF", "#86D9B0", "#FFFFFF"]
const PRISM := ["#FFCF5C", "#F590B4", "#C8A8FF", "#7FBCF5", "#86D9B0", "#FFE08A", "#FFCF5C"]
const RASTER := 64.0              # px the shapes are rasterised at

# The crown floats this far above the head's pivot, in canvas px.
const CROWN_LIFT := {"kitten": 131.0, "rabbit": 149.0, "duckling": 132.0, "hedgehog": 135.0}

var tier := "rare"
var species := "kitten"
var critter                       # the rig (critters/critter.gd)
var k := 0.5                      # game px per canvas px
var t := 0.0
var front: Node2D
var centre := Vector2.ZERO        # the body's middle, in this node's px

var _row: Array
var _c: Color
var _deep: Color
var _glow: Texture2D
var _mote: Array = []             # a texture per mote
var _glint: Texture2D
var _orb: Texture2D
var _crown: Texture2D
var _spark: Texture2D

static var _cache := {}
static var simple := false        # System > Animation detail > Simple: glow, motes and crown only


func setup(tier_name: String, species_id: String, critter_node, zoom: float, foot_drop := 40.0) -> void:
	tier = tier_name
	species = species_id
	critter = critter_node
	k = 0.5 * zoom
	_row = TIER[tier]
	_c = Color(_row[0])
	_deep = Color(_row[1])
	# The feet sit `foot_drop` px below the window's middle, the body's middle 36 px
	# (times zoom) above the feet's pivot.
	centre = Vector2(0, foot_drop - 36.0 * zoom)
	_glow = _glow_texture(_row[0])
	var n: int = _row[6]
	for i in n:
		var fill: String = RAINBOW[i % RAINBOW.size()] if tier == "legendary" else _row[0]
		_mote.append(_shape(SHAPE[tier], fill, _row[1]))
	_glint = _shape(SPARKLE, "#FFFFFF", _row[1])
	_orb = _shape(SHAPE[tier], _row[0], _row[1])
	_crown = _shape(CROWN, "#FFCF5C", "#A86F00", '<circle cx="10" cy="12.2" r="1.6" fill="#FFFFFF"/>')
	_spark = _shape(SPARKLE, "#FFFFFF", "#D9961A")
	front = Node2D.new()
	front.draw.connect(_draw_front)
	t = randf() * 30.0             # critters of a tier do not pulse in step


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if front != null:
		front.queue_redraw()


# --- Drawing helpers ----------------------------------------------------------------

static func _shape(path: String, fill: String, stroke: String, extra := "") -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2 24 24" width="24" height="24"><path d="%s" fill="%s" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>%s</svg>' % [path, fill, stroke, extra]
	if _cache.has(svg):
		return _cache[svg]
	var img := Image.new()
	img.load_svg_from_string(svg, RASTER / 24.0)
	var tex := ImageTexture.create_from_image(img)
	_cache[svg] = tex
	return tex


static func _glow_texture(colour: String) -> Texture2D:
	# CSS radial-gradient(circle, c 0%, c/45% 38%, transparent 70%) on a
	# square box: a circle's stops run to the box's corner.
	var key := "glow" + colour
	if _cache.has(key):
		return _cache[key]
	var c := Color(colour)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.38, 0.70, 1.0])
	g.colors = PackedColorArray([c, Color(c, 0.45), Color(c, 0.0), Color(c, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5 + 0.7071, 0.5)
	tex.width = 128
	tex.height = 128
	_cache[key] = tex
	return tex


static func _ease(x: float) -> float:
	# CSS ease-in-out, near enough.
	return x * x * (3.0 - 2.0 * x)


static func _keys(p: float, keys: Array, ease := true) -> float:
	# Keyframes [[at, value], ...] with 0 <= at <= 1, eased between each pair.
	if p <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if p <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var f: float = (p - a[0]) / maxf(b[0] - a[0], 0.0001)
			return lerpf(a[1], b[1], _ease(f) if ease else f)
	return keys[-1][1]


static func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


func _sprite(on: CanvasItem, tex: Texture2D, at: Vector2, canvas_px: float, rot := 0.0, alpha := 1.0) -> void:
	# A shape `canvas_px` across, centred at `at` (this node's px).
	if alpha <= 0.003 or canvas_px <= 0.01:
		return
	var s := canvas_px * k
	on.draw_set_transform(at, rot, Vector2.ONE)
	on.draw_texture_rect(tex, Rect2(-Vector2(s, s) * 0.5 * 24.0 / 20.0, Vector2(s, s) * 24.0 / 20.0), false, Color(1, 1, 1, alpha))
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _at(canvas: Vector2) -> Vector2:
	# A canvas offset from the body's middle -> this node's px.
	return centre + canvas * k


# --- Behind the critter ----------------------------------------------------------

func _draw() -> void:
	# The glow, breathing.
	var b := 0.5 - 0.5 * cos(TAU * t / 3.6)
	var alpha := lerpf(_row[3], _row[4], b)
	var gs: float = _row[2] * lerpf(0.94, 1.04, b) * k
	draw_texture_rect(_glow, Rect2(centre - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(1, 1, 1, alpha))

	if simple:
		return
	if tier == "legendary":
		_draw_rays()
		_draw_prism()
		for delay in [0.0, 2.25]:
			_draw_ring(fposmod(t + delay, 4.5) / 4.5)
	_draw_orbs(self, false)


func _draw_rays() -> void:
	# Twelve rays 7 degrees wide, turning once in 26 s; the burst breathes.
	var a := lerpf(0.55, 0.95, 0.5 - 0.5 * cos(TAU * t / 4.0))
	_spin_texture(_rays_texture(_row[0]), RAYS_R, TAU * t / 26.0, a)


func _draw_prism() -> void:
	# The rainbow ring, turning once in 9 s.
	_spin_texture(_prism_texture(), PRISM_R, TAU * t / 9.0, 1.0)


func _spin_texture(tex: Texture2D, canvas_r: float, rot: float, alpha: float) -> void:
	var r := canvas_r * k
	draw_set_transform(centre, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-r, -r, 2.0 * r, 2.0 * r), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# The sunburst and the prism ring are drawn once into textures and turned,
# not built from polygons each frame (that cost 40 fps with eight).
const RAYS_R := 173.0             # canvas px: rays fade in from 46, full at 76, gone by 173
const PRISM_R := 122.0            # canvas px: ring fades 110-113 in, 118-122 out
const BAKE := 256                 # px across


static func _rays_texture(colour: String) -> Texture2D:
	var key := "rays" + colour
	if _cache.has(key):
		return _cache[key]
	var c := Color(colour)
	var img := Image.create(BAKE, BAKE, false, Image.FORMAT_RGBA8)
	var half := BAKE * 0.5
	var px := RAYS_R / half                     # canvas px per texture px
	var period := TAU / 12.0
	var width := deg_to_rad(7.0)
	for y in BAKE:
		for x in BAKE:
			var d := Vector2(x + 0.5 - half, y + 0.5 - half)
			var r := d.length() * px
			var radial := 0.0
			if r > 46.0 and r < 76.0:
				radial = (r - 46.0) / 30.0
			elif r >= 76.0 and r < 173.0:
				radial = 1.0 - (r - 76.0) / 97.0
			if radial <= 0.0:
				img.set_pixel(x, y, Color(c, 0.0))
				continue
			# Inside a ray, with a soft pixel at its sides.
			var along := fposmod(d.angle(), period)
			var edge_px := maxf(d.length(), 1.0)
			var inside := clampf(minf(along, width - along) * edge_px + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(c, 0.7 * radial * inside))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _prism_texture() -> Texture2D:
	if _cache.has("prism"):
		return _cache["prism"]
	var img := Image.create(BAKE, BAKE, false, Image.FORMAT_RGBA8)
	var half := BAKE * 0.5
	var px := PRISM_R / half
	for y in BAKE:
		for x in BAKE:
			var d := Vector2(x + 0.5 - half, y + 0.5 - half)
			var r := d.length() * px
			var a := 0.0
			if r > 109.6 and r < 113.1:
				a = (r - 109.6) / 3.5
			elif r >= 113.1 and r <= 118.5:
				a = 1.0
			elif r > 118.5 and r < 122.0:
				a = (122.0 - r) / 3.5
			# CSS conic: from the top, clockwise.
			var f := fposmod(d.angle() + PI * 0.5, TAU) / TAU
			img.set_pixel(x, y, Color(_prism_colour(f), 0.9 * a))
	var tex := ImageTexture.create_from_image(img)
	_cache["prism"] = tex
	return tex


static func _prism_colour(f: float) -> Color:
	var x := f * (PRISM.size() - 1)
	var i := mini(int(x), PRISM.size() - 2)
	return Color(PRISM[i]).lerp(Color(PRISM[i + 1]), x - i)


func _draw_ring(p: float) -> void:
	# A ring 150 canvas px across grows to 2.3 times and fades, in the first
	# 45% of its 4.5 s.
	if p >= 0.45:
		return
	var scale := lerpf(1.0, 2.3, _ease_out(p / 0.45))
	var a := _keys(p, [[0.0, 0.0], [0.08, 0.9], [0.45, 0.0]], false)
	draw_arc(centre, 75.0 * k * scale, 0.0, TAU, 64, Color(_c, a), maxf(3.0 * k, 1.0), true)


func _draw_orbs(on: CanvasItem, near: bool) -> void:
	# Round an ellipse 122 by 34 canvas px, 14 below the middle, once in
	# 5.5 s; in front of the critter on the near half, behind it (dimmer) on
	# the far half.
	var n: int = _row[8]
	for i in n:
		var p := fposmod(t / 5.5 + float(i) / n, 1.0)
		var front_half := p < 0.5
		if front_half != near:
			continue
		var th := TAU * p
		var at := _at(Vector2(122.0 * cos(th), 14.0 + 34.0 * sin(th)))
		_sprite(on, _orb, at, 13.0, 0.0, 1.0 if near else 0.75)


# --- In front of the critter ------------------------------------------------------

func _draw_front() -> void:
	var rise: float = _row[5]
	var n: int = _row[6]
	for i in n:
		var dur := 4.2 * (0.85 + fmod(i * 0.37, 0.4))
		var p := fposmod(t / dur + float(i) / n, 1.0)
		var s := 10.0 + (i * 5) % 6
		var x0 := 105.0 + (i * 71) % 190 + s * 0.5 - 200.0
		var y0 := 236.0 + s * 0.5 - 168.0
		var dx := _keys(p, [[0.0, 0.0], [0.5, 9.0], [1.0, -5.0]])
		var dy := _keys(p, [[0.0, 0.0], [0.5, -0.5 * rise], [1.0, -rise]])
		var sc := _keys(p, [[0.0, 0.5], [0.5, 1.0], [1.0, 0.7]])
		var rot := deg_to_rad(_keys(p, [[0.0, -10.0], [0.5, 8.0], [1.0, -6.0]]))
		var a := _keys(p, [[0.0, 0.0], [0.18, 1.0], [0.8, 0.9], [1.0, 0.0]])
		_sprite(front, _mote[i], _at(Vector2(x0 + dx, y0 + dy)), s * sc, rot, a)

	var g: int = 0 if simple else _row[7]
	for i in g:
		var ang := i * TAU / g + 0.6
		var r := 104.0 + (i % 2) * 14.0
		var p := fposmod((t + i * 0.9) / 2.6, 1.0)
		_twinkle(_glint, _at(Vector2(r * cos(ang), r * sin(ang) * 0.85 - 3.0)), 16.0, p)

	if not simple:
		_draw_orbs(front, true)

	if tier == "legendary" and critter != null and is_instance_valid(critter) and critter.head != null:
		var head := front.to_local(critter.head.global_position)
		var lift: float = CROWN_LIFT.get(species, 95.0)
		for id in critter.worn:
			if Wear.slot(id) == "head":
				lift += 44.0   # above the hat
				break
		var bob := 0.5 - 0.5 * cos(TAU * t / 2.4)
		var crown_at := head + Vector2(0, (-lift - 5.0 * bob) * k)
		_sprite(front, _crown, crown_at, 28.0, deg_to_rad(lerpf(-6.0, 5.0, bob)))
		_twinkle(_spark, crown_at + Vector2(21.0, -15.0) * k, 14.0, fposmod(t / 1.8, 1.0))


func _twinkle(tex: Texture2D, at: Vector2, canvas_px: float, p: float) -> void:
	# Out of nothing to full size, turning, and gone (CSS "twinkle").
	var sc := _keys(p, [[0.0, 0.0], [0.55, 0.0], [0.7, 1.0], [0.85, 0.4], [1.0, 0.0]])
	var rot := deg_to_rad(_keys(p, [[0.0, 0.0], [0.55, 0.0], [0.7, 45.0], [0.85, 90.0], [1.0, 0.0]]))
	var a := _keys(p, [[0.0, 0.0], [0.55, 0.0], [0.7, 1.0], [0.85, 0.6], [1.0, 0.0]])
	_sprite(front, tex, at, canvas_px * sc, rot, a)
