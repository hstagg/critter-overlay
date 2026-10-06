extends Node
## The focus economy: luck, berries, session gifts, the welcome-back after a
## break, rarity rolls for visitors, the Collection, and saving.
##
## The rules (tuned with tools/economy_sim.py; the numbers below match its
## PARAMS):
##   - Only time present counts. Breaks under 30 minutes do not end a
##     session; idle minutes simply do not count.
##   - Luck multiplies the odds of rare, epic and legendary visitors. It rises
##     with session time, from 1x to 3x at two hours, most of it in the first
##     hour. A long break halves it; a night away (six hours or more) resets
##     it. Midnight does not: working across it keeps the session. After five
##     hours of focus in a day it grows at a quarter of the pace.
##   - Berries: one a minute of focus, a quarter of that after five hours in a
##     day, plus the day's first-session bonus, the gifts and the welcome-backs.
##     Berries are only ever earned.
##   - Gifts at 25, 50, 90 and 150 minutes of session focus. What is inside is
##     a surprise; that a gift is coming is not. An item is guaranteed by the
##     sixth gift without one.
##   - Coming back from a 5 to 30 minute break: the critters found something.
##   - Nothing is ever taken away.
##   - Rare Hour (v2.0): an hour each evening, 21:00 by default, when rare,
##     epic and legendary are twice as likely, on top of luck.
##   - The day's first visitor is Rare or better (v2.0's first-spawn bonus:
##     70% Rare, 20% Epic, 10% Legendary, within the species' cap).
##
## Time comes from `now()`, which a test can replace.

signal berries_changed(total: int)
signal gift_opened(index: int, berries: int, item: String)
signal welcome_back(berries: int)
signal sighting(species: String, tier: String, first: bool)
signal rare_hour_changed(on: bool)

const TIERS := ["common", "uncommon", "rare", "epic", "legendary"]
const BASE_ODDS := {"common": 0.904, "uncommon": 0.07, "rare": 0.02, "epic": 0.005, "legendary": 0.001}
const LUCKY := ["rare", "epic", "legendary"]

const BERRIES_PER_MIN := 1.0
const DAILY_FULL_MIN := 300.0      # full rate for the first five hours a day
const DAILY_TAPER := 0.25
const FIRST_SESSION_BERRIES := 10
const GIFTS := [[25, 15, 0.10], [50, 30, 0.20], [90, 60, 0.35], [150, 90, 0.50]]   # minute, berries, item chance
const GIFT_PITY := 6
const GIFT_ITEM_POOL := 40         # placeholder ids until the cosmetics exist
const WELCOME_MIN_S := 5 * 60      # a break this long earns a welcome-back
const SESSION_END_S := 30 * 60     # a break this long ends the session
const WELCOME_BERRIES := 5
const LUCK_MAX := 3.0
const LUCK_FULL_MIN := 120.0
const LUCK_KEPT := 0.5             # of session luck kept across a long break
const NIGHT_S := 6 * 3600          # a break this long starts afresh
const SAVE_EVERY_S := 60.0
const SAVE_VERSION := 1
const FIRST_BONUS_ODDS := {"rare": 0.70, "epic": 0.20, "legendary": 0.10}

# Rare Hour, set from Settings (World > Rare Hour) once those exist.
var rare_hour_enabled := true
var rare_hour_start := 21          # local hour
var rare_hour_min := 60
var rare_hour_boost := 2.0

var save_path := "user://economy.json"
var now_fn := func() -> float: return Time.get_unix_time_from_system()

# Saved state.
var berries := 0
var lifetime_berries := 0
var session_min := 0.0             # focus minutes this session, for luck and gifts
var next_gift := 0
var day := ""                      # local date of the focus being counted
var day_focus_min := 0.0
var paid_first_session := false
var gifts_since_item := 0
var gift_items := []               # item ids found in gifts
var owned := []                    # item ids bought
var collection := {}               # "species:tier" -> {"first": unix, "count": n}
var sightings := []                # rare and up: {"t": unix, "species", "tier"}
var away_since := 0.0
var first_bonus_day := ""          # local date the first-visitor bonus was used

var rng := RandomNumberGenerator.new()
var _frac := 0.0                   # berries not yet whole
var _save_in := SAVE_EVERY_S
var _rare_hour_was := false
var _rare_hour_check := 0.0


func now() -> float:
	return now_fn.call()


func _today() -> String:
	return Time.get_date_string_from_unix_time(int(now() + _utc_offset_s()))


static func _utc_offset_s() -> float:
	return Time.get_time_zone_from_system().get("bias", 0) * 60.0


# --- Focus time -----------------------------------------------------------------

func tick(delta: float, present: bool) -> void:
	# Called every frame. Only time present counts.
	_save_in -= delta
	if _save_in <= 0.0:
		_save_in = SAVE_EVERY_S
		save()
	_rare_hour_check -= delta
	if _rare_hour_check <= 0.0:
		_rare_hour_check = 1.0
		var on := in_rare_hour()
		if on != _rare_hour_was:
			_rare_hour_was = on
			rare_hour_changed.emit(on)
	if not present:
		return
	_roll_day()
	if not paid_first_session:
		paid_first_session = true
		_earn(FIRST_SESSION_BERRIES)
	var mins := delta / 60.0
	var rate := BERRIES_PER_MIN if day_focus_min < DAILY_FULL_MIN else BERRIES_PER_MIN * DAILY_TAPER
	day_focus_min += mins
	session_min += mins if day_focus_min < DAILY_FULL_MIN else mins * DAILY_TAPER
	_frac += rate * mins
	if _frac >= 1.0:
		var whole := int(_frac)
		_frac -= whole
		_earn(whole)
	while next_gift < GIFTS.size() and session_min >= GIFTS[next_gift][0]:
		_open_gift(next_gift)
		next_gift += 1


func _roll_day() -> void:
	var today := _today()
	if today != day:
		# A new day's allowances. The session itself carries on: it ends
		# only with a break (see came_back).
		day = today
		day_focus_min = 0.0
		paid_first_session = false


func went_away() -> void:
	away_since = now()


func came_back(idle_before_s: float) -> void:
	# `idle_before_s`: the idle time already gone when the user was marked
	# away, so the break is measured from the last real input.
	if away_since <= 0.0:
		return
	var gap := now() - away_since + idle_before_s
	away_since = 0.0
	if gap >= NIGHT_S:
		session_min = 0.0
		next_gift = 0
	elif gap >= SESSION_END_S:
		session_min *= LUCK_KEPT
		next_gift = 0
		while next_gift < GIFTS.size() and session_min >= GIFTS[next_gift][0]:
			next_gift += 1   # gifts already passed are not given twice
	elif gap >= WELCOME_MIN_S:
		_earn(WELCOME_BERRIES)
		welcome_back.emit(WELCOME_BERRIES)


# --- Luck and rarity -------------------------------------------------------------

func luck() -> float:
	var f := clampf(session_min / LUCK_FULL_MIN, 0.0, 1.0)
	f = 1.0 - (1.0 - f) * (1.0 - f)   # most of the gain in the first hour
	return 1.0 + (LUCK_MAX - 1.0) * f


func _local_minute() -> int:
	# Minutes since local midnight.
	var t := int(now() + _utc_offset_s())
	return int(posmod(t, 86400) / 60)


func in_rare_hour() -> bool:
	if not rare_hour_enabled:
		return false
	var start := rare_hour_start * 60
	return posmod(_local_minute() - start, 1440) < rare_hour_min


func rare_hour_ends() -> String:
	# "22:00", for the toast.
	var end := (rare_hour_start * 60 + rare_hour_min) % 1440
	return "%02d:%02d" % [end / 60, end % 60]


func roll_arrival(max_tier := "legendary") -> Array:
	# A visitor's tier, and whether it was the day's first-visitor bonus.
	_roll_day()
	if first_bonus_day != day:
		first_bonus_day = day
		var r := rng.randf()
		var acc := 0.0
		var tier := "legendary"
		for t in FIRST_BONUS_ODDS:
			acc += FIRST_BONUS_ODDS[t]
			if r < acc:
				tier = t
				break
		if TIERS.find(tier) > TIERS.find(max_tier):
			tier = max_tier
		return [tier, true]
	return [roll_tier(max_tier), false]


func roll_tier(max_tier := "legendary") -> String:
	var lk := luck() * (rare_hour_boost if in_rare_hour() else 1.0)
	var odds := {}
	var rest := 0.0
	for t in TIERS:
		if t == "common":
			continue
		odds[t] = BASE_ODDS[t] * (lk if t in LUCKY else 1.0)
		rest += odds[t]
	odds["common"] = maxf(0.0, 1.0 - rest)
	var r := rng.randf()
	var acc := 0.0
	var tier := "common"
	for t in TIERS:
		acc += odds[t]
		if r < acc:
			tier = t
			break
	if TIERS.find(tier) > TIERS.find(max_tier):
		tier = max_tier
	return tier


func record_sighting(species: String, tier: String) -> bool:
	# Returns whether this species and tier is a first find.
	var key := "%s:%s" % [species, tier]
	var first := not collection.has(key)
	if first:
		collection[key] = {"first": int(now()), "count": 0}
	collection[key]["count"] += 1
	if tier in LUCKY:
		sightings.append({"t": int(now()), "species": species, "tier": tier})
	sighting.emit(species, tier, first)
	return first


# --- Berries, gifts, the shop ------------------------------------------------------

func _earn(n: int) -> void:
	berries += n
	lifetime_berries += n
	berries_changed.emit(berries)


func _open_gift(index: int) -> void:
	var g: Array = GIFTS[index]
	var item := ""
	gifts_since_item += 1
	if rng.randf() < g[2] or gifts_since_item >= GIFT_PITY:
		item = "gift_%03d" % rng.randi_range(0, GIFT_ITEM_POOL - 1)
		gifts_since_item = 0
		if not item in gift_items:
			gift_items.append(item)
	_earn(g[1])
	gift_opened.emit(index, g[1], item)


func gift_progress() -> float:
	# 0..1 towards the next gift, for the progress ring. The first ring starts
	# a quarter full (endowed progress).
	if next_gift >= GIFTS.size():
		return 1.0
	var from: float = 0.0 if next_gift == 0 else GIFTS[next_gift - 1][0]
	var to: float = GIFTS[next_gift][0]
	var p := clampf((session_min - from) / (to - from), 0.0, 1.0)
	return 0.25 + 0.75 * p if next_gift == 0 else p


func buy(item: String, price: int) -> bool:
	if item in owned or berries < price:
		return false
	berries -= price
	owned.append(item)
	berries_changed.emit(berries)
	save()
	return true


# --- Saving -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "berries": berries, "lifetime_berries": lifetime_berries,
		"session_min": session_min, "next_gift": next_gift, "day": day, "day_focus_min": day_focus_min,
		"paid_first_session": paid_first_session, "gifts_since_item": gifts_since_item,
		"gift_items": gift_items, "owned": owned, "collection": collection, "sightings": sightings,
		"first_bonus_day": first_bonus_day, "saved_at": int(now())}


func save() -> void:
	# Written to a temporary file and renamed, so a crash mid-write cannot
	# leave a half-written save.
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("economy: cannot write %s" % tmp)
		return
	f.store_string(JSON.stringify(to_dict(), " "))
	f.close()
	DirAccess.rename_absolute(tmp, save_path)


func load_save() -> void:
	# Starting inside Rare Hour is not its start: the tray shows it, no toast.
	_rare_hour_was = in_rare_hour()
	if not FileAccess.file_exists(save_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(d) != TYPE_DICTIONARY:
		push_warning("economy: unreadable save, starting fresh")
		return
	berries = int(d.get("berries", 0))
	lifetime_berries = int(d.get("lifetime_berries", berries))
	session_min = float(d.get("session_min", 0.0))
	next_gift = int(d.get("next_gift", 0))
	day = str(d.get("day", ""))
	day_focus_min = float(d.get("day_focus_min", 0.0))
	paid_first_session = bool(d.get("paid_first_session", false))
	gifts_since_item = int(d.get("gifts_since_item", 0))
	gift_items = d.get("gift_items", [])
	owned = d.get("owned", [])
	collection = d.get("collection", {})
	sightings = d.get("sightings", [])
	first_bonus_day = str(d.get("first_bonus_day", ""))
	# A long gap since the last save is a long break.
	var gap := now() - float(d.get("saved_at", now()))
	if gap >= SESSION_END_S:
		away_since = now() - gap
		came_back(0.0)
