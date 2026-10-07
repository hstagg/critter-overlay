extends Node
## Everything the Settings window can change, saved as JSON in
## user://settings.json (written to a temporary file and renamed, like the
## economy save). Loading merges the file over the defaults and keeps keys it
## does not know, so a newer version's settings survive an older build.
##
## Keys are dotted paths ("focus.max_out"). Each species has its own block
## under "species.<id>"; species() fills it in from the defaults.
##
## v2.0's values are kept where v2.0 had the setting (speed and activity
## stops, visit weights, sizes, odds, Rare Hour).

signal changed(key: String)

const SAVE_DELAY := 0.6

# v2.0's stops (src/settings_window.py).
const SPEEDS := [0.10, 0.30, 1.0, 2.5, 5.0, 12.0]
const SPEED_NAMES := ["snail", "slow", "average", "fast", "rapid", "supersonic"]
const ACTIVITY := [0.17, 0.44, 1.0, 2.5, 5.6, 13.9]      # v2.0 idle rates over "normal"
const ACTIVITY_NAMES := ["wired", "active", "normal", "lazy", "sleepy", "narcoleptic"]
const VISITS := [0.1, 1.0, 3.0, 5.0]
const VISIT_NAMES := ["Seldom", "Normal", "Often", "Constant"]
const TRAILS := ["none", "dots", "stars", "sparkles", "bubbles", "glitter", "hearts"]
const TIERS := ["common", "rare", "epic", "legendary"]

const DEFAULTS := {
	"critters": {"size": 120, "opacity": 100},
	"species": {},
	"focus": {
		"mode": "gather",          # gather | timer
		"start_with": 2,
		"gather_every_min": 12,
		"max_out": 8,
		"luck": true,              # "Rarer the longer you stay"
		"pause_fullscreen": true,
		"nap_after_min": 3,
		"tidy_after_min": 60,      # 0: never
		"timer_every_min": 5,
		"timer_min": 5,
		"timer_max": 10,
		"solo": true,
		"solo_every_min": 10,
	},
	"world": {
		"day_night": true,
		"behaviour_freq": 1.0,     # 0.3 to 2.0
		"pairs": true,
		"rarity": true,
		"odds": {"common": 95.0, "rare": 4.0, "epic": 0.9, "legendary": 0.1},
		"first_bonus": true,
		"notes": "rare",           # off | rare | epic | legendary
		"rare_hour": true,
		"rare_hour_start": 21,
		"rare_hour_min": 60,
		"rare_hour_boost": 2.0,
	},
	"sound": {"pops": true, "volume": 50},
	"system": {
		"pause_key": {"mods": 6, "vk": 0x50},   # Ctrl+Shift+P (MOD_CONTROL | MOD_SHIFT)
		"spawn_key": {"mods": 0, "vk": 0},      # not set
		"theme": "system",         # system | light | dark
		"detail": "detailed",      # detailed | simple
		"seen_log": true,
		"onboarded": false,
		"beta": false,             # beta testers only: odds and tier ranges can be changed (--beta)
		"updates": "download",     # off | tell | download (and tell)
		"admin": false,            # the developer's Admin page (five clicks on the version, or --admin)
		"update_checked": 0,       # unix time of the last automatic check
		"update_dismissed": "",    # a version the user closed the note for
	},
}

const SPECIES_DEFAULTS := {"enabled": true, "visits": 1, "speed": 2, "activity": 2, "trail": "none",
	"tier_min": "common", "tier_max": "epic", "sound": true}

var path := "user://settings.json"
var data := {}
var _save_in := -1.0


func _init() -> void:
	data = DEFAULTS.duplicate(true)


func load_file() -> void:
	data = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		push_warning("settings: unreadable file, using defaults")
		return
	_merge(data, d)


static func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		if into.has(k) and typeof(into[k]) == TYPE_DICTIONARY and typeof(from[k]) == TYPE_DICTIONARY:
			_merge(into[k], from[k])
		else:
			into[k] = from[k]


func save() -> void:
	_save_in = -1.0
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("settings: cannot write %s" % tmp)
		return
	f.store_string(JSON.stringify(data, " "))
	f.close()
	DirAccess.rename_absolute(tmp, path)


func _process(delta: float) -> void:
	if _save_in > 0.0:
		_save_in -= delta
		if _save_in <= 0.0:
			save()


func value(key: String, fallback = null):
	var node = data
	for part in key.split("."):
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return _default(key, fallback)
		node = node[part]
	return node


func _default(key: String, fallback):
	var parts := key.split(".")
	if parts.size() == 3 and parts[0] == "species":
		return SPECIES_DEFAULTS.get(parts[2], fallback)
	var node = DEFAULTS
	for part in parts:
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return fallback
		node = node[part]
	return node


func set_value(key: String, v) -> void:
	var parts := key.split(".")
	var node: Dictionary = data
	for i in parts.size() - 1:
		if not node.has(parts[i]) or typeof(node[parts[i]]) != TYPE_DICTIONARY:
			node[parts[i]] = {}
		node = node[parts[i]]
	if node.get(parts[-1]) == v:
		return
	node[parts[-1]] = v
	_save_in = SAVE_DELAY
	changed.emit(key)


func species(id: String) -> Dictionary:
	var out := SPECIES_DEFAULTS.duplicate()
	if id == "kitten":
		out["visits"] = 2          # v2.0: kittens come often
	var mine: Dictionary = data.get("species", {}).get(id, {})
	var keep_tiers := [out.tier_min, out.tier_max]
	out.merge(mine, true)
	if not beta():
		out.tier_min = keep_tiers[0]   # tier ranges are for beta testers only
		out.tier_max = keep_tiers[1]
	# Saved before the four tiers: Uncommon became Common, and an everyday
	# species tops out at Epic (Legendary is the special visitors).
	for k in ["tier_min", "tier_max"]:
		if out[k] == "uncommon" or not out[k] in TIERS:
			out[k] = "common" if k == "tier_min" else "epic"
		elif out[k] == "legendary":
			out[k] = "epic"
	return out


func sp(id: String, field: String):
	return species(id)[field]


func reset_species(id: String) -> void:
	data["species"].erase(id)
	_save_in = SAVE_DELAY
	changed.emit("species." + id)


func reset_all_species() -> void:
	data["species"] = {}
	_save_in = SAVE_DELAY
	changed.emit("species")


func reset_all() -> void:
	# Everything back to how it started. The Collection is the economy's and
	# is kept; so is having seen the welcome.
	var onboarded: bool = data.get("system", {}).get("onboarded", false)
	data = DEFAULTS.duplicate(true)
	data["system"]["onboarded"] = onboarded
	save()
	changed.emit("")


# --- Coming from v2.0 ------------------------------------------------------------

static func _nearest(values: Array, v: float) -> int:
	var best := 0
	for i in values.size():
		if absf(float(values[i]) - v) < absf(float(values[best]) - v):
			best = i
	return best


func import_v2(v2: Dictionary) -> void:
	# The first run after upgrading: v2.0's choices, where v3 has them.
	var vis: Dictionary = v2.get("visual", {})
	if vis.has("animal_size"):
		data.critters.size = clampi(int(vis.animal_size), 80, 200)
	if vis.has("opacity"):
		data.critters.opacity = clampi(int(vis.opacity), 50, 100)
	if vis.get("animation_detail", "") == "simple":
		data.system.detail = "simple"
	var au: Dictionary = v2.get("audio", {})
	data.sound.pops = bool(au.get("sound_enabled", true))
	data.sound.volume = clampi(int(au.get("volume", 50)), 0, 100)
	var sp: Dictionary = v2.get("spawn", {})
	data.focus.timer_every_min = clampi(int(sp.get("primary_interval_min", 5)), 1, 60)
	data.focus.timer_min = clampi(int(sp.get("primary_count_min", 5)), 1, 15)
	data.focus.timer_max = clampi(int(sp.get("primary_count_max", 10)), 1, 25)
	data.focus.solo = bool(sp.get("solo_enabled", true))
	data.focus.solo_every_min = clampi(int(sp.get("solo_interval_min", 10)), 1, 60)
	var be: Dictionary = v2.get("behaviour", {})
	data.world.day_night = bool(be.get("day_night_enabled", true))
	data.world.behaviour_freq = clampf(float(be.get("behaviour_frequency", 1.0)), 0.3, 2.0)
	data.world.pairs = bool(be.get("interactions_enabled", true))
	var ra: Dictionary = v2.get("rarity", {})
	data.world.rarity = bool(ra.get("enabled", true))
	data.world.first_bonus = bool(ra.get("first_spawn_of_day_bonus", true))
	if ra.has("distribution") and beta():
		var o := {}
		for t in TIERS:
			o[t] = snappedf(float(ra.distribution.get(t, 0.0)) * 100.0, 0.01)
		data.world.odds = o
	var rh: Dictionary = ra.get("rare_hour", {})
	data.world.rare_hour = bool(rh.get("enabled", true))
	data.world.rare_hour_start = clampi(int(rh.get("start_hour", 21)), 0, 23)
	data.world.rare_hour_min = [30, 60, 120][_nearest([30, 60, 120], float(rh.get("duration_minutes", 60)))]
	data.world.rare_hour_boost = [1.5, 2.0, 3.0][_nearest([1.5, 2.0, 3.0], float(rh.get("rare_tier_boost", 2.0)))]
	data.system.seen_log = bool(ra.get("seen_log_enabled", true))
	# Each species, by v3's name (v2.0's "duck" is the duckling).
	var idle_rates := [0.003, 0.008, 0.018, 0.045, 0.100, 0.250]
	for name in v2.get("animals", {}):
		var a: Dictionary = v2.animals[name]
		var id: String = "duckling" if name == "duck" else name
		data.species[id] = {
			"enabled": bool(a.get("enabled", true)),
			"visits": _nearest(VISITS, float(a.get("weight", 1.0))),
			"speed": _nearest(SPEEDS, float(a.get("speed_multiplier", 1.0))),
			"activity": _nearest(idle_rates, float(a.get("idle_rate", 0.018))),
			"trail": a.get("trail_style", "none") if a.get("trail_style", "none") in TRAILS else "none",
			"tier_min": a.get("rarity_min", "common"),
			"tier_max": a.get("rarity_max", "legendary"),
			"sound": bool(a.get("sound", true)),
		}
	data.system.from_v2 = true
	save()


# --- Derived values -----------------------------------------------------------

func zoom() -> float:
	# 120 px (v2.0's default size) is the art at its drawn size.
	return float(value("critters.size")) / 120.0


func beta() -> bool:
	return bool(value("system.beta"))


func odds() -> Dictionary:
	# The odds as fractions. They are relative weights, so they need not add up.
	# Only a beta tester's own odds count; everyone else has the game's, so a
	# Legendary means the same for every player.
	var w: Dictionary = value("world.odds") if beta() else DEFAULTS.world.odds
	var total := 0.0
	for t in TIERS:
		total += maxf(float(w.get(t, 0.0)), 0.0)
	var out := {}
	for t in TIERS:
		out[t] = maxf(float(w.get(t, 0.0)), 0.0) / total if total > 0.0 else (1.0 if t == "common" else 0.0)
	return out


static func key_text(k: Dictionary) -> PackedStringArray:
	# {"mods", "vk"} -> ["Ctrl", "Shift", "P"]; empty when not set.
	var out := PackedStringArray()
	if int(k.get("vk", 0)) == 0:
		return out
	var m := int(k.get("mods", 0))
	if m & 2:
		out.append("Ctrl")
	if m & 1:
		out.append("Alt")
	if m & 4:
		out.append("Shift")
	if m & 8:
		out.append("Win")
	var vk := int(k.vk)
	if vk >= 0x70 and vk <= 0x87:
		out.append("F%d" % (vk - 0x6F))
	else:
		out.append(char(vk))
	return out
