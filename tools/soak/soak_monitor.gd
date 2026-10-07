extends Node
## Soak monitor. Flags (after --, alongside main.gd's own):
##   --soak-log=PATH     JSON lines, one per --soak-every seconds
##   --soak-every=S      sample period (default 60)
##   --soak-mode=M       soak | legend | churn | throw | specials | idle
##   --soak-pid=PATH     write this process id here (for the external sampler)

const Species := preload("res://species.gd")

var main: Node
var log_path := ""
var every := 60.0
var mode := "idle"
var t := 0.0
var next_sample := 0.0
var deltas := PackedFloat32Array()
var next_act := 0.0
var actions := {}
var anomalies := []
var thrown_since := {}      # host instance id -> seconds in thrown/sliding
var last_specials := {}
var special_i := 0
var started := false


func _ready() -> void:
	process_priority = 1000   # after main.gd
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--soak-log="):
			log_path = v
		elif arg.begins_with("--soak-every="):
			every = float(v)
		elif arg.begins_with("--soak-mode="):
			mode = v
		elif arg.begins_with("--soak-pid="):
			var f := FileAccess.open(v, FileAccess.WRITE)
			f.store_string(str(OS.get_process_id()))
			f.close()
	if log_path != "":
		var f := FileAccess.open(log_path, FileAccess.WRITE)
		f.close()
	next_sample = every
	print("SOAK start mode=", mode, " pid=", OS.get_process_id())


func _bump(k: String) -> void:
	actions[k] = actions.get(k, 0) + 1


func _live() -> Array:
	return main.hosts.filter(func(h): return is_instance_valid(h) and h.state == "live")


func _process(delta: float) -> void:
	t += delta
	deltas.append(delta * 1000.0)
	if not started:
		if main.hosts.is_empty():
			return
		started = true
		_start_mode()
	_check(delta)
	_drive(delta)
	if t >= next_sample:
		next_sample += every
		_sample()


func _start_mode() -> void:
	match mode:
		"specials":
			# One of each species in a row across the middle of the screen.
			for h in main.hosts.duplicate():
				h.leave(true)
			var sps: Array = Species.DATA.keys()
			var a: Rect2 = main.area
			for i in sps.size():
				var x: float = a.position.x + a.size.x * (i + 0.5) / sps.size()
				var y: float = a.position.y + a.size.y * (0.45 if i % 2 == 0 else 0.75)
				var h = main._spawn("roam", "sit", Vector2(x, y), sps[i])
				if h != null:
					h.critter.mode_left = INF
		"pairs":
			for h in main.hosts.duplicate():
				h.leave(true)
		"legend":
			for sp in ["unicorn", "golden_kitten", "unicorn", "golden_kitten"]:
				main._spawn("roam", "walk", Vector2(-1, -1), sp)


func _drive(delta: float) -> void:
	next_act -= delta
	if next_act > 0.0:
		return
	var live := _live()
	match mode:
		"soak":
			# Every 5 min pop one; every 7 min throw one at another; every
			# 10 min a special visitor walks in. Arrivals refill naturally.
			next_act = 1.0
			var s := int(t)
			if s % 300 == 150 and not live.is_empty():
				live.pick_random().pop()
				_bump("pop")
			if s % 420 == 200 and live.size() >= 2:
				_throw(live, randf_range(600.0, 2400.0))
			if s % 600 == 300 and main.hosts.size() < 12:
				main._spawn("roam", "walk", Vector2(-1, -1), ["unicorn", "golden_kitten"][special_i % 2])
				special_i += 1
				_bump("special")
		"pairs":
			# Every pair interaction in turn, the two 120 px apart.
			next_act = 12.0
			for h in main.hosts.duplicate():
				if h.state == "live":
					h.leave(true)
			var names: Array = main.pairs.PAIRS.keys()
			var n: String = names[special_i % names.size()]
			special_i += 1
			var d: Array = main.pairs.PAIRS[n]
			var sa: String = d[3][0] if not d[3].is_empty() else "kitten"
			var sb: String = d[4][0] if not d[4].is_empty() else "rabbit"
			var c: Vector2 = main.area.get_center() + Vector2(randf_range(-300, 300), 120)
			var a = main._spawn("roam", "sit", c - Vector2(60, 0), sa)
			var b = main._spawn("roam", "sit", c + Vector2(60, 0), sb)
			if a != null and b != null:
				main.pairs.active.clear()
				main.pairs.cool.clear()
				main.pairs._start(n, a, b, 1.0)
				_bump("pair:" + n)
		"churn":
			# Pop up to four at a time every 3 s; the tray's Spawn refills.
			next_act = 3.0
			live.shuffle()
			for h in live.slice(0, mini(4, live.size())):
				h.pop()
				_bump("pop")
			for i in 3:
				if main.hosts.size() < 14:
					main.spawn_now()
					_bump("spawn")
		"throw":
			next_act = 2.0
			if live.size() >= 2:
				_throw(live, randf_range(150.0, 4000.0))
			if main.hosts.size() < 12:
				main.spawn_now()
				_bump("spawn")
		"specials":
			next_act = 0.25
			for h in main.hosts:
				if not is_instance_valid(h) or h.state != "live":
					continue
				var k = h.critter
				var idles: Array = Species.row(h.species)["idles"]
				var own: Array = idles.slice(12) if idles.size() > 12 else idles.slice(-1)
				# Each species' own behaviours, plus a nap now and then.
				var pick: String = own[last_specials.get(h.species, 0) % own.size()]
				if k.is_napping() or not k.can_start_behaviour():
					continue
				k.mode_left = INF
				k.start_behaviour(pick, main.evaluator.duration_of(pick))
				last_specials[h.species] = last_specials.get(h.species, 0) + 1
				_bump("act:" + pick)


func _throw(live: Array, speed: float) -> void:
	var a = live.pick_random()
	var b = live.filter(func(x): return x != a).pick_random()
	a.foot = a.feet_on_screen()
	a.launch((b.body_centre() - a.body_centre()).normalized() * speed)
	main.note_throw()
	_bump("throw")


func _check(delta: float) -> void:
	# Anything odd: non-finite positions, critters far off screen while live,
	# or stuck mid-throw.
	var a: Rect2 = Rect2(main.area).grow(600.0)
	for h in main.hosts:
		if not is_instance_valid(h):
			_anomaly("freed host still listed")
			continue
		var f: Vector2 = h.feet_on_screen()
		if not (is_finite(f.x) and is_finite(f.y)):
			_anomaly("non-finite feet %s %s" % [h.species, h.state])
		elif h.state == "live" and not h.leaving and not h.critter.entering and not a.has_point(f):
			_anomaly("live critter off screen %s at %s" % [h.species, f])
		var id: int = h.get_instance_id()
		if h.state in ["thrown", "sliding"]:
			thrown_since[id] = thrown_since.get(id, 0.0) + delta
			if thrown_since[id] > 20.0 and thrown_since[id] - delta <= 20.0:
				_anomaly("stuck %s for 20 s: %s at %s" % [h.state, h.species, f])
		else:
			thrown_since.erase(id)


func _anomaly(s: String) -> void:
	if anomalies.size() < 200 and not anomalies.has(s):
		anomalies.append(s)
		print("SOAK ANOMALY ", s)


func _pct(s: PackedFloat32Array, p: float) -> float:
	return snappedf(s[clampi(int(s.size() * p), 0, s.size() - 1)], 0.01)


func _sample() -> void:
	var s := deltas.duplicate()
	s.sort()
	deltas.clear()
	var hitches := 0
	for d in s:
		if d > 50.0:
			hitches += 1
	var sp := {}
	var tiers := {}
	var trails := 0
	var auras := 0
	var napping := 0
	for h in main.hosts:
		if not is_instance_valid(h):
			continue
		sp[h.species] = sp.get(h.species, 0) + 1
		tiers[h.tier] = tiers.get(h.tier, 0) + 1
		if h.trail != null:
			trails += 1
		if h.aura != null:
			auras += 1
		if h.critter.is_napping():
			napping += 1
	var row := {
		"t": snappedf(t, 0.1),
		"frames": s.size(),
		"fps": Engine.get_frames_per_second(),
		"ms_p50": _pct(s, 0.5), "ms_p95": _pct(s, 0.95), "ms_p99": _pct(s, 0.99),
		"ms_max": snappedf(s[-1], 0.01) if not s.is_empty() else 0.0,
		"hitches_50ms": hitches,
		"critters": main.hosts.size(),
		"species": sp, "tiers": tiers, "trails": trails, "auras": auras, "napping": napping,
		"away": main.presence.away, "paused": main.paused,
		"static_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.01),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.01),
		"tex_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.01),
		"windows": DisplayServer.get_window_list().size(),
		"main_fps_len": main.fps.size(),
		"main_ms_len": main.process_ms.size(),
		"actions": actions.duplicate(),
		"anomalies": anomalies.size(),
	}
	print("SOAK ", JSON.stringify(row))
	if mode == "specials":
		for h in main.hosts:
			var k = h.critter
			print("STATE %s host=%s mode=%s act=%s pending=%s vx=%.1f air=%s enter=%s paired=%s held=%s hold_nap=%s mode_left=%s" % [
				h.species, h.state, k.mode, k.act, k.act_pending, k.vx, k.airborne, k.entering, k.paired, k.held, k.hold_nap, k.mode_left])
	if log_path != "":
		var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(row))
		f.close()
