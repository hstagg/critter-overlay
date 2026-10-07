extends Node2D
## A critter's trail (v2.0's TrailParticle, src/animals.py): small shapes left
## behind as it moves, drifting, twinkling and fading. Styles: dots, stars,
## sparkles, bubbles, glitter, hearts (v2.0's TRAIL_PRESETS for rate, size
## and life).
##
## It lives in the critter's own window, under the critter, but the particles
## keep their place on the screen: the window moves with the critter, so each
## is drawn at its screen position less the window's. One that falls outside
## the window is simply not seen.

# style: [particle, per second, size px, life s] (v2.0 constants.TRAIL_PRESETS)
const PRESETS := {
	"dots": ["dot", 15, 6, 0.9],
	"stars": ["star", 15, 6, 0.9],
	"sparkles": ["sparkle", 25, 4, 0.5],
	"bubbles": ["bubble", 12, 7, 1.4],
	"glitter": ["glitter", 40, 2, 0.25],
	"hearts": ["heart", 12, 6, 0.9],
}
# With rarity tiers on and no trail chosen for the species, the tier's own
# (v2.0 rarity.py), in its colours.
const TIER_TRAIL := {"rare": "sparkles", "epic": "glitter", "legendary": "hearts"}
const TIER_COLOURS := {
	"rare": ["#7FBCF5", "#D5E9FC", "#FFFFFF"],
	"epic": ["#F590B4", "#FCD9E6", "#FFFFFF"],
	"legendary": ["#FFCF5C", "#FFF0C2", "#F590B4", "#7FBCF5", "#FFFFFF"],
}

var host: Node                    # host.gd
var style := "dot"
var rate := 15.0
var px := 6.0
var life := 0.9
var colours: Array = []
var zoom := 1.0
var _acc := 0.0
var _parts := []                  # [screen pos, velocity, colour, size, life, max life, twinkle phase, age]
var _last := Vector2.INF


func setup(host_ref: Node, trail: String, palette: Array, z: float) -> void:
	host = host_ref
	var p: Array = PRESETS[trail]
	style = p[0]
	rate = p[1]
	px = p[2] * z
	life = p[3]
	colours = palette
	zoom = z


func step(delta: float, body_on_screen: Vector2, moving: bool) -> void:
	# Called by the host each frame with where the body is.
	if moving:
		_acc += delta
		var every := 1.0 / rate
		var n := 0
		while _acc >= every and n < 8:
			_acc -= every
			n += 1
			_emit(body_on_screen)
	else:
		_acc = 0.0
	for p in _parts:
		_move(p, delta)
	_parts = _parts.filter(func(p): return p[4] > 0.0)
	queue_redraw()


func _emit(at: Vector2) -> void:
	var off := Vector2(randf_range(-0.18, 0.18), randf_range(-0.2, 0.1)) * 80.0 * zoom
	var v := Vector2(randf_range(-18, 18), randf_range(-30, 6))
	if style == "bubble":
		v = Vector2(randf_range(-8, 8), -15.0 + randf_range(-5, 5))
	elif style == "glitter":
		v = Vector2(randf_range(-10, 10), randf_range(-12, 4))
	var l := randf_range(life * 0.65, life * 1.25)
	var c: Color = Color(colours.pick_random())
	_parts.append([at + off, v * zoom, c, randf_range(maxf(3.0, px - 2.0), px + 2.0), l, l, randf() * TAU, 0.0])


func _move(p: Array, delta: float) -> void:
	p[4] -= delta
	p[7] += delta
	p[0] += p[1] * delta
	if style == "bubble":
		p[1].y += 8.0 * delta
		p[1].x *= 1.0 - 0.5 * delta
	else:
		p[1].y += 35.0 * delta
		p[1].x *= 1.0 - 0.9 * delta


func _draw() -> void:
	if host == null or host.win == null:
		return
	var origin := Vector2(host.win.position)
	for p in _parts:
		var t: float = maxf(0.0, p[4] / p[5])
		var twink := 0.65 + 0.35 * sin(p[7] * 9.0 + p[6])
		var r: float = p[3] * t * twink
		if r < 0.6:
			continue
		var at: Vector2 = p[0] - origin
		var c: Color = Color(p[2], clampf(t * 1.6, 0.0, 1.0))
		var w := maxf(1.0, zoom)
		match style:
			"star", "sparkle":
				draw_line(at - Vector2(r, 0), at + Vector2(r, 0), c, w, true)
				draw_line(at - Vector2(0, r), at + Vector2(0, r), c, w, true)
				if style == "sparkle":
					var d := r * 0.7
					draw_line(at - Vector2(d, d), at + Vector2(d, d), c, w, true)
					draw_line(at + Vector2(d, -d), at - Vector2(d, -d), c, w, true)
				draw_circle(at, maxf(1.0, r * 0.5), c)
			"bubble":
				draw_arc(at, r, 0.0, TAU, 16, c, maxf(1.0, r / 3.0), true)
			"heart":
				var h := r * 0.5
				draw_circle(at + Vector2(-h, -h * 0.5), h, c)
				draw_circle(at + Vector2(h, -h * 0.5), h, c)
				draw_colored_polygon(PackedVector2Array([at + Vector2(-r, -h * 0.2), at + Vector2(r, -h * 0.2), at + Vector2(0, r)]), c)
			_:
				draw_circle(at, r, c)
