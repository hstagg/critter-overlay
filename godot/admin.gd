extends Node
## The Admin page's hands (Settings > Admin, the developer's audit page):
## spawn exactly what is asked for, play every move of a species in turn,
## force a pair, try clothes on, and set off events. Turned on by clicking
## the version in the Settings sidebar five times, or --admin.
##
## Nothing here touches the save except "Give berries" and, when asked,
## counting a spawn in the Collection. Dressing is for the look only: the
## Shop's outfit comes back with "Undress".

const Species := preload("res://species.gd")
const Behaviours := preload("res://behaviours.gd")
const Pairs := preload("res://pairs.gd")
const Wear := preload("res://wear.gd")
const Onboarding := preload("res://gui/onboarding.gd")
const Critter := preload("res://critters/critter.gd")

const WALK_S := 4.0               # the walk at the start of a run of moves
const SIT_S := 1.5
const NAP_S := 5.0
const GAP_S := 0.7                # between moves

var main: Node
var hold := false                 # no arrivals and nobody leaves while auditing
var count_finds := false          # admin spawns count in the Collection

# A run of moves: one critter, each step in turn.
var seq_host = null
var seq: Array = []
var seq_i := -1
var now_playing := ""
var _left := 0.0
var _started := false


func _init(m: Node) -> void:
	main = m


static func versions(sp: String) -> Array:
	# The art folders of a species' Rare and Epic looks.
	if Species.is_special(sp):
		return []
	var out := Array(DirAccess.get_directories_at("res://art/%s" % sp))
	out.sort()
	return out


# --- Spawning -------------------------------------------------------------------

func spawn(sp: String, tier: String, version := "", variant := "", n := 1, mode := "walk") -> Array:
	# version "" is the tier's own look, "-" the Common look whatever the tier.
	var out := []
	for i in n:
		if main.hosts.size() >= main.HARD_MAX:
			break
		var at := Vector2(-1, -1)
		var h = main._spawn("roam", mode, at, sp, tier, version, variant)
		if h == null:
			break
		if count_finds:
			main._announce(sp, h.tier, false, str(h.critter.get("variant")) if variant != "" or Species.is_special(sp) else "")
		out.append(h)
	return out


func spawn_looks(sp: String) -> void:
	# A species in each look it has: Common, Rare, Epic (or every colour).
	if Species.is_special(sp):
		for v in Species.variants(sp):
			spawn(sp, "legendary", "", v)
		return
	for t in ["common", "rare", "epic"]:
		spawn(sp, t, "", "", 1, "sit")


func spawn_versions(sp: String) -> void:
	# Every version drawn for a species, picked or not, to compare.
	for v in versions(sp):
		spawn(sp, "rare", v, "", 1, "sit")


func clear_all() -> void:
	stop_moves()
	for h in main.hosts.duplicate():
		if h.state == "live" and not h.leaving:
			h.leave()


func climb(sp: String, down := false) -> void:
	var area: Rect2 = main.area
	var d := area.size.x + area.size.y * 0.3 if not down else 2.0 * area.size.x + area.size.y * 1.2
	var h = main._spawn("perimeter", "walk", Vector2(area.position.x + d, 0), sp, "common")
	if h != null:
		h.critter.mode_left = INF
		h.critter.activity = 0.0


# --- Every move in turn ---------------------------------------------------------------

func play_moves(sp: String, only := "") -> void:
	# One critter, near the left of the screen, through its walk, sit, each
	# of its moves, then a nap and waking. `only` plays a single move.
	stop_moves()
	var area: Rect2 = main.area
	var hs: Array = spawn(sp, "common", "", "", 1, "sit")
	if hs.is_empty():
		return
	seq_host = hs[0]
	seq_host.critter.mode_left = INF
	seq_host.critter.activity = 0.0
	if only != "":
		seq = [only]
	else:
		seq = ["walk", "sit"]
		for b in Species.row(sp)["idles"]:
			if not b in ["nap", "wake_up"]:
				seq.append(b)
		seq += ["nap", "wake_up"]
	seq_i = -1
	_left = 1.0
	_started = true
	now_playing = "getting ready"


func moves_of(sp: String) -> Array:
	return ["walk", "sit"] + Species.row(sp)["idles"].filter(func(b): return b != "wake_up")


func stop_moves() -> void:
	seq = []
	seq_i = -1
	now_playing = ""
	_started = false
	if seq_host != null and is_instance_valid(seq_host):
		seq_host.critter.activity = 1.0
		seq_host.critter.mode_left = 3.0
	seq_host = null


func _process(delta: float) -> void:
	if seq.is_empty():
		return
	if seq_host == null or not is_instance_valid(seq_host) or seq_host.state == "popping":
		stop_moves()
		return
	var k = seq_host.critter
	k.mode_left = INF
	if _started:
		# The step under way: wait out its time, or for its move to end.
		_left -= delta
		var busy: bool = k.act != "" or k.act_pending != ""
		if _left > 0.0 or busy or k.airborne:
			return
	_started = true
	seq_i += 1
	if seq_i >= seq.size():
		now_playing = "done (%d moves)" % seq.size()
		seq = []
		return
	var b: String = seq[seq_i]
	now_playing = "%s (%d of %d)" % [b.replace("_", " "), seq_i + 1, seq.size()]
	print("ADMIN ", now_playing)
	match b:
		"walk":
			k._go_walk()
			_left = WALK_S
		"sit":
			k._go_sit()
			_left = SIT_S
		"nap":
			k.go_to_sleep()
			_left = NAP_S
		"wake_up":
			k.wake_up()
			_left = 2.0
		_:
			if not k.can_start_behaviour():
				# Not ready yet (landing, or still settling): try again shortly.
				seq_i -= 1
				_left = 0.3
				return
			k.start_behaviour(b, main.evaluator.duration_of(b))
			_left = GAP_S


# --- The audit's Run buttons ---------------------------------------------------------

func run(action: String, chosen := "kitten") -> void:
	# What a Run button on the audit does (gui/admin_page.gd checks()).
	var kind := action.get_slice(":", 0)
	var arg := action.substr(kind.length() + 1)
	match kind:
		"moves":
			play_moves(arg)
		"looks":
			spawn_looks(arg)
		"versions":
			spawn_versions(chosen)
		"wear":
			var s := arg.get_slice(":", 0)
			var items := arg.get_slice(":", 1).split(",")
			spawn(s, "common", "", "", 1, "walk")
			spawn(s, "common", "", "", 1, "sit")
			dress(s, Array(items))
		"hoods":
			spawn("kitten", "common", "", "", 1, "sit")
			spawn("rabbit", "common", "", "", 1, "sit")
			spawn("hedgehog", "common", "", "", 1, "sit")
			dress("kitten", ["frog_hood"])
			dress("rabbit", ["bear_hood"])
			dress("hedgehog", ["dino_hood"])
		"pair":
			pair(arg)
		"auras":
			for t in ["common", "rare", "epic"]:
				spawn("kitten", t, "", "", 1, "sit")
			spawn("unicorn", "legendary")
		"toasts":
			toasts()
		"present":
			present()
		"climb":
			climb("kitten")
			climb("kitten", true)
		"throw":
			if main.hosts.size() < 2:
				spawn("kitten", "common", "", "", 2, "sit")
			get_tree().create_timer(1.0).timeout.connect(func(): throw())
		"nap":
			everyone_nap()
			get_tree().create_timer(10.0).timeout.connect(func(): everyone_wake())
		"rare_hour":
			rare_hour_now()
		"eight":
			for i in 8:
				spawn(Species.DATA.keys().pick_random(), "common")
		"welcome":
			welcome()
		"open":
			main.open_settings(arg)
		"url":
			OS.shell_open(arg)


# --- Pairs, clothes, events ----------------------------------------------------------

func pair(name: String) -> void:
	var d: Array = Pairs.PAIRS[name]
	var sa: String = d[3][0] if not d[3].is_empty() else "kitten"
	var sb: String = d[4][0] if not d[4].is_empty() else "rabbit"
	var c: Vector2 = main.area.get_center() + Vector2(0, 120)
	var a = main._spawn("roam", "sit", c - Vector2(220, 0), sa, "common")
	var b = main._spawn("roam", "sit", c + Vector2(120, 0), sb, "common")
	if a == null or b == null:
		return
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(a) and is_instance_valid(b):
			a.critter.paired = false
			b.critter.paired = false
			main.pairs.cool.clear()
			main.pairs._start(name, a, b, Critter.zoom))


func dress(sp: String, items: Array) -> void:
	for h in main.hosts:
		if h.species == sp and h.state != "popping":
			h.critter.wear(items, main.economy.dyed.get(sp, {}))


func undress(sp: String) -> void:
	main._redress(sp)


func toasts() -> void:
	main._run_toast_demo()


func rare_hour_now() -> void:
	var e = main.economy
	e.rare_hour_enabled = true
	e.rare_hour_start = int(e._local_minute() / 60)


func everyone_nap() -> void:
	main._on_went_away()


func everyone_wake() -> void:
	main._on_came_back()


func throw() -> void:
	var live: Array = main.hosts.filter(func(h): return h.state == "live")
	if live.is_empty():
		return
	var a = live[0]
	a.foot = a.feet_on_screen()
	var to: Vector2 = live[1].body_centre() if live.size() > 1 else main.area.get_center() + Vector2(randf_range(-400, 400), -300)
	a.launch((to - a.body_centre()).normalized() * 1400.0)


func present() -> void:
	# A visitor arriving with a present: the look and the note, without
	# giving the item.
	var hs: Array = spawn(["kitten", "rabbit", "duckling", "hedgehog"].pick_random(), "rare")
	if hs.is_empty():
		return
	var h = hs[0]
	var item: String = Wear.ITEMS.keys().pick_random()
	h.critter.wear([item], {})
	main.toasts.show_sighting(h.species, h.tier, "A present", "A %s brought you something" % h.species.replace("_", " "),
		"The %s is yours. Find it in the Shop. (Admin: not really given.)" % Wear.item_name(item).to_lower())


func welcome() -> void:
	var w := Onboarding.new()
	main.add_child(w)
	w.open(main)


func give_berries(n: int) -> void:
	main.economy.berries += n
	main.economy.save()
	main._update_tray()
