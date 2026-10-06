extends RefCounted
## Behaviour catalogue and evaluator, ported from v2.0's src/behaviours.py.
##
## Behaviours are short named states layered on top of walking and sitting.
## The evaluator runs once a second (not every frame) and starts at most one
## behaviour per kitten, weighted, with a per-kitten cooldown so the same one
## does not repeat. Adding a behaviour is a registry entry here plus its pose
## in critters/ (_behaviour_params): the shared ones in critter.gd, a
## species' own in its file. Each species lists the ones it can do in
## species.gd; the evaluator offers a critter only those.
##
## `sleep` is extra weight added in proportion to the sleep bias, which rises
## the longer the user has been idle: yawns and naps get likelier as they
## drift away from the keyboard.

const REGISTRY := {
	"stretch":        {"dur": [1.6, 2.0], "cool": 45.0, "w": 1.0, "sleep": 0.0},
	"yawn":           {"dur": [0.9, 1.2], "cool": 60.0, "w": 0.8, "sleep": 0.8},
	"sit_and_look":   {"dur": [2.0, 4.0], "cool": 30.0, "w": 1.0, "sleep": 0.2},
	"nap":            {"dur": [8.0, 16.0], "cool": 120.0, "w": 0.5, "sleep": 2.0},
	"groom":          {"dur": [3.2, 3.6], "cool": 40.0, "w": 1.2, "sleep": 0.3},
	"ear_flick":      {"dur": [0.35, 0.45], "cool": 8.0, "w": 0.7, "sleep": 0.0},
	"tail_swish":     {"dur": [0.6, 0.8], "cool": 6.0, "w": 0.7, "sleep": 0.0},
	"look_at_cursor": {"dur": [1.5, 2.5], "cool": 15.0, "w": 1.0, "sleep": 0.0},
	"hunt":           {"dur": [2.4, 3.4], "cool": 45.0, "w": 0.8, "sleep": -0.6},
	# The rest of v2.0's universal idles, and the species' own. Durations are
	# v2.0's, lengthened a little where the rig needs time to read.
	"scratch":        {"dur": [1.2, 2.0], "cool": 35.0, "w": 1.0, "sleep": 0.0},
	"sneeze":         {"dur": [0.6, 0.8], "cool": 30.0, "w": 0.6, "sleep": 0.0},
	"shake_off":      {"dur": [0.7, 1.0], "cool": 60.0, "w": 0.8, "sleep": 0.0},
	"listen":         {"dur": [1.0, 1.6], "cool": 20.0, "w": 1.0, "sleep": 0.0},
	"wake_up":        {"dur": [0.6, 0.9], "cool": 30.0, "w": 0.5, "sleep": 0.0},
	"nose_twitch":    {"dur": [0.4, 0.6], "cool": 5.0, "w": 1.0, "sleep": 0.0},
	"stand_lookout":  {"dur": [1.8, 3.0], "cool": 40.0, "w": 1.0, "sleep": 0.0},
	"chase_tail":     {"dur": [1.2, 2.0], "cool": 90.0, "w": 0.6, "sleep": -0.3},
	"preen":          {"dur": [2.0, 3.5], "cool": 40.0, "w": 1.0, "sleep": 0.2},
	"peck_ground":    {"dur": [1.0, 1.5], "cool": 25.0, "w": 1.0, "sleep": 0.0},
	# From perk clothes (wear.gd PERKS): only a critter wearing one does them.
	"dance":          {"dur": [3.0, 5.0], "cool": 40.0, "w": 1.2, "sleep": -0.5},
	"fly":            {"dur": [3.5, 5.0], "cool": 60.0, "w": 1.0, "sleep": -0.5},
	"celebrate":      {"dur": [1.4, 1.8], "cool": 50.0, "w": 1.0, "sleep": -0.5},
}

const BASE_CHANCE := 0.1          # per kitten per second, before weighting
const MAX_BEHAVING := 0.5         # at most half the kittens busy at once

var frequency := 1.0              # World > Behaviour frequency, 0.3 to 2.0
var _acc := 0.0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func duration_of(b: String) -> float:
	var d: Array = REGISTRY[b]["dur"]
	return rng.randf_range(d[0], d[1])


func tick(delta: float, kittens: Array, sleep_bias: float) -> void:
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	var busy := 0
	for k in kittens:
		if not k.can_start_behaviour():
			busy += 1
	var cap := maxi(1, int(kittens.size() * MAX_BEHAVING))
	for k in kittens:
		if busy >= cap:
			return
		# Each critter's Activity (Critters page) scales its own chance.
		if not k.can_start_behaviour() or rng.randf() > BASE_CHANCE * frequency * k.activity:
			continue
		var b := _pick(k, sleep_bias)
		if b == "":
			continue
		k.cooldowns[b] = REGISTRY[b]["cool"]
		k.start_behaviour(b, duration_of(b))
		busy += 1


func _pick(k, sleep_bias: float) -> String:
	var names := []
	var weights := []
	var total := 0.0
	for b in REGISTRY.keys():
		if k.on_cooldown(b) or not k.can_do(b):
			continue
		var w: float = REGISTRY[b]["w"] + REGISTRY[b]["sleep"] * sleep_bias
		if w <= 0.0:
			continue
		names.append(b)
		weights.append(w)
		total += w
	if names.is_empty():
		return ""
	var r := rng.randf() * total
	for i in names.size():
		r -= weights[i]
		if r <= 0.0:
			return names[i]
	return names[-1]
