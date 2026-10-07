extends RefCounted
## Pair interactions (v2.0's src/behaviours.py, the is_pair entries): two
## roaming critters near each other stop, face each other and do something
## together. One walks over to the other, they act, then go their ways.
##
##   sniff          one sniffs, the other looks at it
##   stare_contest  both stare; one gives in with an ear flick
##   play_bow       both bow, then one bounces
##   mutual_groom   both wash
##   sit_together   they settle down side by side for a short doze
##   kitten_tussle  two kittens crouch, wiggle and pounce (kittens only)
##   near_miss      a kitten stalks a rabbit, which bolts (kitten and rabbit)
##   bump           two walking straight at each other bump, hop and turn away
##
## v2.0's splash play (otter and duck), hedgehog defence and panda snuggle
## are listed with their species and wake up when those critters are built.
## World > Pair interactions turns it all off; nothing starts while you are
## away or the critters are paused.

# name: [weight, seconds, cooldown, species a, species b, gap (px at zoom 1)]
# Empty species means any. The first critter is the one that walks over.
const PAIRS := {
	"sniff": [1.0, [0.8, 1.5], 25.0, [], [], 46.0],
	"stare_contest": [0.6, [2.0, 4.0], 60.0, [], [], 70.0],
	"play_bow": [0.7, [1.6, 2.0], 45.0, [], [], 72.0],
	"mutual_groom": [0.5, [3.2, 3.6], 60.0, [], [], 58.0],
	"sit_together": [0.6, [4.0, 7.0], 90.0, [], [], 56.0],
	"kitten_tussle": [1.0, [2.4, 3.2], 50.0, ["kitten"], ["kitten"], 96.0],
	"near_miss": [0.9, [2.4, 3.2], 60.0, ["kitten"], ["rabbit"], 110.0],
	"splash_play": [1.0, [2.0, 3.0], 45.0, ["otter"], ["duckling"], 60.0],
	"hedgehog_defence": [0.8, [2.0, 3.5], 60.0, ["hedgehog"], ["kitten"], 70.0],
	"panda_snuggle": [0.8, [3.0, 5.0], 90.0, ["panda"], [], 52.0],
}
const NEAR := 420.0               # px at zoom 1: close enough to notice each other
const ROW := 140.0                # and this close up or down the screen
const CHANCE := 0.12              # per close pair per second, times behaviour frequency
const APPROACH_LIMIT := 8.0       # s to walk over before giving up
const MAX_ACTIVE := 2
const Y_SPEED := 70.0             # px/s the walker drifts to its partner's level

var active := []                  # Pair
var cool := {}                    # host instance id -> seconds until it may pair again
var bolts := []                   # [host, seconds left, cruise before]: a rabbit running off
var rng := RandomNumberGenerator.new()
var _acc := 0.0
var frequency := 1.0


class Pair:
	var name := ""
	var a: Node                   # walks over
	var b: Node
	var stage := "approach"       # approach | act
	var t := 0.0
	var length := 1.0
	var gap := 60.0
	var side := 1                 # which side of b that a stands: -1 left, +1 right
	var done := false


func _init() -> void:
	rng.randomize()


func tick(delta: float, hosts: Array, zoom: float, enabled: bool) -> void:
	for k in cool.keys():
		cool[k] -= delta
		if cool[k] <= 0.0:
			cool.erase(k)
	for p in active.duplicate():
		_step(p, delta, zoom)
	for bo in bolts:
		bo[1] -= delta
		if bo[1] <= 0.0 and is_instance_valid(bo[0]):
			bo[0].critter.cruise = bo[2]
	bolts = bolts.filter(func(bo): return bo[1] > 0.0 and is_instance_valid(bo[0]))
	if not enabled:
		for p in active.duplicate():
			_finish(p)
		return
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	_bumps(hosts, zoom)
	if active.size() < MAX_ACTIVE:
		_look_for_pairs(hosts, zoom)


static func _free(h) -> bool:
	return h.kind == "roam" and h.state == "live" and not h.leaving and not h.critter.entering \
		and h.critter.can_start_behaviour() and h.critter.mode in ["sit", "walk"]


func _ok(h) -> bool:
	return _free(h) and not cool.has(h.get_instance_id())


func _look_for_pairs(hosts: Array, zoom: float) -> void:
	var free := hosts.filter(func(h): return _ok(h))
	for i in free.size():
		for j in range(i + 1, free.size()):
			var x = free[i]
			var y = free[j]
			if absf(x.critter.position.x - y.critter.position.x) > NEAR * zoom or absf(x.y - y.y) > ROW * zoom:
				continue
			if rng.randf() > CHANCE * frequency:
				continue
			var pick := _pick(x.species, y.species)
			if pick.is_empty():
				continue
			if pick[1]:
				_start(pick[0], y, x, zoom)
			else:
				_start(pick[0], x, y, zoom)
			return


func _pick(sa: String, sb: String) -> Array:
	# [name, swapped] weighted among the interactions these two can do.
	var names := []
	var weights := []
	var swaps := []
	var total := 0.0
	for n in PAIRS:
		var d: Array = PAIRS[n]
		var fits_ab: bool = (d[3].is_empty() or sa in d[3]) and (d[4].is_empty() or sb in d[4])
		var fits_ba: bool = (d[3].is_empty() or sb in d[3]) and (d[4].is_empty() or sa in d[4])
		if not (fits_ab or fits_ba):
			continue
		names.append(n)
		weights.append(d[0])
		swaps.append(not fits_ab)
		total += d[0]
	if names.is_empty():
		return []
	var r := rng.randf() * total
	for i in names.size():
		r -= weights[i]
		if r <= 0.0:
			return [names[i], swaps[i]]
	return [names[-1], swaps[-1]]


func _start(name: String, a, b, zoom: float) -> void:
	var p := Pair.new()
	p.name = name
	p.a = a
	p.b = b
	var d: Array = PAIRS[name]
	p.length = rng.randf_range(d[1][0], d[1][1])
	p.gap = d[5] * zoom
	p.side = 1 if a.critter.position.x > b.critter.position.x else -1
	for h in [a, b]:
		h.critter.paired = true
		h.critter.act = ""
		h.critter.act_pending = ""
	# The partner waits, facing the one coming over; that one walks.
	b.critter._go_sit()
	b.critter.mode_left = INF
	b.critter.want_facing = p.side
	a.critter._go_walk()
	a.critter.mode_left = INF
	active.append(p)
	print("PAIR start ", name, " ", a.species, " to ", b.species)


func _step(p: Pair, delta: float, zoom: float) -> void:
	if p.done:
		return
	var a = p.a
	var b = p.b
	if not is_instance_valid(a) or not is_instance_valid(b) or a.state != "live" or b.state != "live" or a.leaving or b.leaving:
		_finish(p)
		return
	p.t += delta
	var ka = a.critter
	var kb = b.critter
	if p.stage == "approach":
		var target: float = clampf(kb.position.x + p.side * p.gap, a.world.left_x, a.world.right_x)
		var dx: float = target - ka.position.x
		a.y = move_toward(a.y, b.y, Y_SPEED * zoom * delta)
		ka.mode_left = INF
		if absf(dx) > 5.0 * zoom:
			if ka.mode != "walk":
				ka._go_walk()
				ka.mode_left = INF
			ka.want_facing = 1 if dx > 0.0 else -1
		elif absf(a.y - b.y) < 4.0 * zoom and absf(ka.vx) < 6.0:
			_act(p)
		else:
			ka.want_facing = -p.side   # arrived: face the partner, stop
			if ka.mode == "walk":
				ka._go_sit()
				ka.mode_left = INF
		if p.t > APPROACH_LIMIT:
			_finish(p)
		return
	# Acting.
	match p.name:
		"near_miss":
			# The rabbit bolts just before the pounce lands.
			if not p.get_meta("bolted", false) and p.t > p.length * 0.6:
				p.set_meta("bolted", true)
				kb.act = ""
				kb.poke()
				kb.paired = false
				kb._go_walk()
				kb.mode_left = 4.0
				kb.want_facing = -p.side
				bolts.append([b, 3.0, kb.cruise])
				kb.cruise *= 2.2
		"kitten_tussle", "play_bow":
			if not p.get_meta("bounced", false) and p.t > p.length * 0.85:
				p.set_meta("bounced", true)
				ka.poke()
				if p.name == "kitten_tussle":
					kb.poke()
	if p.t >= p.length:
		_finish(p)


func _act(p: Pair) -> void:
	print("PAIR act ", p.name)
	p.stage = "act"
	p.t = 0.0
	var ka = p.a.critter
	var kb = p.b.critter
	ka.facing = -p.side
	ka.want_facing = -p.side
	kb.facing = p.side
	kb.want_facing = p.side
	var heads := func(h) -> Vector2: return h.feet_on_screen() - Vector2(0, h.critter.head_height * h.zoom)
	match p.name:
		"sniff":
			ka.start_behaviour("nose_twitch" if ka.can_do("nose_twitch") else "listen", p.length)
			p.b.world.look_at = heads.call(p.a)
			kb.start_behaviour("look_at_cursor", p.length)
		"stare_contest":
			p.a.world.look_at = heads.call(p.b)
			p.b.world.look_at = heads.call(p.a)
			ka.start_behaviour("look_at_cursor", p.length)
			kb.start_behaviour("look_at_cursor", p.length)
		"play_bow":
			ka.start_behaviour("stretch", p.length)
			kb.start_behaviour("stretch", p.length)
		"mutual_groom", "splash_play", "panda_snuggle":
			ka.start_behaviour("groom", p.length)
			kb.start_behaviour("groom", p.length)
		"sit_together":
			ka._go_loaf(p.length)
			kb._go_loaf(p.length)
		"kitten_tussle":
			ka.start_behaviour("hunt", p.length)
			kb.start_behaviour("hunt", p.length)
		"near_miss":
			ka.start_behaviour("hunt", p.length)
			p.b.world.look_at = heads.call(p.a)
			kb.start_behaviour("look_at_cursor", p.length)
		"hedgehog_defence":
			# The kitten comes close and the hedgehog rolls up; the kitten
			# listens, puzzled.
			ka.start_behaviour("ball_up" if ka.can_do("ball_up") else "sit_and_look", p.length)
			kb.start_behaviour("listen", p.length)


func _finish(p: Pair) -> void:
	if p.done:
		return
	p.done = true
	active.erase(p)
	print("PAIR end ", p.name, " (", p.stage, ")")
	var cd: float = PAIRS[p.name][2]
	for h in [p.a, p.b]:
		if not is_instance_valid(h):
			continue
		cool[h.get_instance_id()] = cd
		h.world.look_at = Vector2.INF
		var k = h.critter
		if not k.paired:
			continue
		k.paired = false
		if p.stage == "act" and p.name == "stare_contest" and h == p.b and k.can_do("ear_flick"):
			k.act = ""
			k.start_behaviour("ear_flick", 0.4)   # the one that gives in
		var away: int = p.side if h == p.a else -p.side
		if k.mode == "loaf":
			k._wake()
		elif k.act == "" and k.mode in ["sit", "walk", "act"]:
			# Go separate ways.
			k._go_walk()
		k.want_facing = away


func _bumps(hosts: Array, zoom: float) -> void:
	# Two walking straight at each other, close: bump, hop back, turn away.
	var walkers := hosts.filter(func(h): return _ok(h) and h.critter.mode == "walk")
	for i in walkers.size():
		for j in range(i + 1, walkers.size()):
			var x = walkers[i]
			var y = walkers[j]
			var dx: float = y.critter.position.x - x.critter.position.x
			if absf(dx) > 64.0 * zoom or absf(x.y - y.y) > 24.0 * zoom:
				continue
			if x.critter.facing != signi(int(dx)) or y.critter.facing != -signi(int(dx)):
				continue
			print("PAIR bump ", x.species, " ", y.species)
			for h in [x, y]:
				var k = h.critter
				k._kick_squash(-1.5)
				k.poke()
				k.want_facing = -k.facing
				cool[h.get_instance_id()] = 10.0
			return
