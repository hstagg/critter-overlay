extends SceneTree
## Headless checks for economy.gd on a fake clock.
## Run: godot --headless --path godot --script res://economy_test.gd

const Economy := preload("res://economy.gd")
const Wear := preload("res://wear.gd")

var clock := 0.0
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func fresh(path: String) -> Node:
	var e = Economy.new()
	e.save_path = path
	e.now_fn = func() -> float: return clock
	e.rng.seed = 7
	return e


func work(e, minutes: float, step := 1.0) -> void:
	var s := 0.0
	while s < minutes * 60.0:
		e.tick(step, true)
		clock += step
		s += step


func away(e, minutes: float) -> void:
	# Idle for the presence layer's three minutes, then marked away.
	clock += 180.0
	e.went_away()
	clock += minutes * 60.0 - 180.0
	e.came_back(180.0)


func _init() -> void:
	var dir := OS.get_temp_dir().path_join("critter_economy_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("economy.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	clock = 1_790_000_000.0 + 8 * 3600.0 + 31600.0   # 08:00 BST, Tue 22 Sep 2026

	# --- First session: bonus, rate, gifts, luck curve.
	var e = fresh(path)
	var gifts := []
	e.gift_opened.connect(func(i, b, item): gifts.append([i, b, item]))
	check(is_equal_approx(e.luck(), 1.0), "luck starts at 1.0")
	check(is_equal_approx(e.gift_progress(), 0.25), "first gift ring starts a quarter full")
	work(e, 25.0 + 1.0 / 60.0)
	check(gifts.size() == 1 and gifts[0][0] == 0, "first gift at 25 min (got %s)" % [gifts])
	check(e.berries >= 10 + 25 + 15 - 1, "berries after 25 min: bonus + rate + gift (got %d)" % e.berries)
	var l25: float = e.luck()
	work(e, 35.0)
	var l60: float = e.luck()
	work(e, 60.0)
	var l120: float = e.luck()
	check(l25 > 1.0 and l60 > l25 and l120 > l60, "luck rises: %.2f %.2f %.2f" % [l25, l60, l120])
	check(is_equal_approx(l120, 3.0), "luck reaches 3.0 at two hours (got %.2f)" % l120)
	check(l60 - 1.0 > (l120 - 1.0) * 0.7, "most of the luck comes in the first hour")
	check(gifts.size() == 3, "gifts at 25, 50 and 90 min by two hours (got %d)" % gifts.size())

	# --- Short break: no session loss, a welcome-back.
	var welcomed := [0]
	e.welcome_back.connect(func(b): welcomed[0] += b)
	var before_luck: float = e.luck()
	var before_berries: int = e.berries
	away(e, 10.0)
	check(is_equal_approx(e.luck(), before_luck), "a 10 min break keeps luck")
	check(welcomed[0] == 5 and e.berries == before_berries + 5, "a 10 min break pays a welcome-back")
	away(e, 3.5)
	check(welcomed[0] == 5, "a break under 5 min is not paid")

	# --- Long break: luck halved, never zeroed; gifts not repeated.
	var session_before: float = e.session_min
	away(e, 45.0)
	check(is_equal_approx(e.session_min, session_before * 0.5), "a 45 min break halves session luck time")
	check(e.luck() > 1.0, "luck after a long break is above the floor")
	var n_gifts := gifts.size()
	work(e, 5.0)
	check(gifts.size() == n_gifts, "no gift repeated straight after a long break")

	# --- Daily taper after five hours.
	var b0: int = e.berries
	work(e, 300.0 - e.day_focus_min + 60.0)   # past five hours, then an hour more
	var b1: int = e.berries
	work(e, 60.0)
	var tapered: int = e.berries - b1
	check(tapered <= 20, "an hour past five hours earns about a quarter (got %d, plus any gift)" % tapered)

	# --- Rarity: base odds at luck 1, caps.
	var r = fresh(path + ".r")
	r.rare_hour_enabled = false   # Rare Hour is checked on its own below
	var counts := {"common": 0, "uncommon": 0, "rare": 0, "epic": 0, "legendary": 0}
	for i in 200000:
		counts[r.roll_tier()] += 1
	check(absf(counts["rare"] / 200000.0 - 0.02) < 0.003, "rare near 2%% at luck 1 (got %.4f)" % (counts["rare"] / 200000.0))
	check(absf(counts["uncommon"] / 200000.0 - 0.07) < 0.005, "uncommon near 7%%")
	r.session_min = 120.0
	var lucky := 0
	for i in 200000:
		if r.roll_tier() in ["rare", "epic", "legendary"]:
			lucky += 1
	check(absf(lucky / 200000.0 - 0.026 * 3.0) < 0.006, "rare+ about triples at full luck (got %.4f)" % (lucky / 200000.0))
	var capped_ok := true
	for i in 50000:
		if r.roll_tier("epic") == "legendary":
			capped_ok = false
	check(capped_ok, "a species capped at epic never rolls legendary")

	# --- Rare Hour: the window, its boost, the signal at each end.
	var h = fresh(path + ".h")
	var hour: int = h._local_minute() / 60
	h.rare_hour_start = hour
	check(h.in_rare_hour(), "inside Rare Hour when it started this hour")
	h.rare_hour_start = (hour + 2) % 24
	check(not h.in_rare_hour(), "outside Rare Hour two hours before it")
	h.rare_hour_start = (hour + 23) % 24
	h.rare_hour_min = 120
	check(h.in_rare_hour(), "a two-hour Rare Hour that began last hour is still on (wraps midnight too)")
	h.rare_hour_min = 60
	h.rare_hour_start = hour
	var boosted := 0
	for i in 200000:
		if h.roll_tier() in ["rare", "epic", "legendary"]:
			boosted += 1
	check(absf(boosted / 200000.0 - 0.026 * 2.0) < 0.005, "rare+ about doubles in Rare Hour (got %.4f)" % (boosted / 200000.0))
	h.rare_hour_enabled = false
	check(not h.in_rare_hour(), "Rare Hour off in settings means never")
	h.rare_hour_enabled = true
	var changes := []
	h.rare_hour_changed.connect(func(on): changes.append(on))
	h.rare_hour_start = (hour + 1) % 24
	work(h, 60 - h._local_minute() % 60 + 1)
	work(h, 61.0)
	check(changes == [true, false], "Rare Hour signals its start and end once each (got %s)" % [changes])
	check(h.rare_hour_ends() == "%02d:00" % ((hour + 2) % 24), "Rare Hour end time for the toast (got %s)" % h.rare_hour_ends())

	# --- The day's first visitor is Rare or better, once a day, within caps.
	var f = fresh(path + ".f")
	var first = f.roll_arrival()
	check(first[1] and first[0] in ["rare", "epic", "legendary"], "first visitor of the day is Rare+ (got %s)" % [first])
	check(not f.roll_arrival()[1], "the bonus is once a day")
	var bonus := {"rare": 0, "epic": 0, "legendary": 0}
	for i in 20000:
		f.first_bonus_day = ""
		bonus[f.roll_arrival("epic")[0]] += 1
	check(bonus["legendary"] == 0, "the bonus respects a species capped at Epic")
	check(absf(bonus["rare"] / 20000.0 - 0.7) < 0.02, "the bonus is about 70%% Rare (got %.3f)" % (bonus["rare"] / 20000.0))
	f.save()
	var f2 = fresh(path + ".f")
	f2.load_save()
	check(not f2.roll_arrival()[1], "a restart the same day does not pay the bonus again")
	clock += 86400.0
	check(f2.roll_arrival()[1], "the next day pays it again")
	clock -= 86400.0
	for x in [h, f, f2]:
		x.free()

	# --- Collection and sightings.
	check(e.record_sighting("kitten", "rare") == true, "first rare kitten is a first find")
	check(e.record_sighting("kitten", "rare") == false, "second is not")
	e.record_sighting("kitten", "common")
	check(e.sightings.size() == 2, "only rare and up go in the sightings diary (got %d)" % e.sightings.size())
	check(e.collection["kitten:rare"]["count"] == 2, "collection counts repeats")

	# --- Shop.
	var have: int = e.berries
	check(e.buy("hat_red", 50), "can buy an affordable item")
	check(e.berries == have - 50, "price taken")
	check(not e.buy("hat_red", 50), "cannot buy the same item twice")
	check(not e.buy("castle", 999999), "cannot buy what you cannot afford")

	# --- Dyes and treats (repeatable sinks).
	e.berries = 1000
	check(not e.buy_dye("bow", "sky"), "no dye for an item not owned")
	e.buy("bow", 50)
	var d0: int = e.berries
	check(e.buy_dye("bow", "sky") and e.berries == d0 - 100, "a dye costs 100 for an owned item")
	check(not e.buy_dye("bow", "sky"), "a colour is bought once per item")
	e.set_dye("kitten", "bow", "sky")
	check(e.dyed["kitten"]["bow"] == "sky", "a bought colour can be worn")
	e.set_dye("kitten", "bow", "rose")
	check(e.dyed["kitten"]["bow"] == "sky", "an unbought colour cannot")
	var t0: int = e.berries
	check(e.buy_treat("rabbit") and e.buy_treat("rabbit") and e.berries == t0 - 120, "treats are repeatable, 60 each")
	check(e.treats == ["rabbit", "rabbit"], "treats queue in order")

	# --- Visitors bringing presents, and the lucky charm.
	var g = fresh(path + ".g")
	var n := 400000
	var hits := {"common": 0, "legendary": 0}
	var by_tier := {}
	for t in hits:
		for i in n:
			var it: String = g.roll_brought_item(t, "kitten")
			if it != "":
				hits[t] += 1
				var pt: String = Wear.ITEMS[it][2]
				by_tier[pt] = by_tier.get(pt, 0) + 1
	check(absf(hits["common"] / float(n) - 0.0002) < 0.0001, "a Common visitor almost never brings a present (got %.5f)" % (hits["common"] / float(n)))
	check(absf(hits["legendary"] / float(n) - 0.03) < 0.003, "a Legendary one still rarely does (got %.4f)" % (hits["legendary"] / float(n)))
	check(by_tier.get("small", 0) > by_tier.get("large", 0) and by_tier.get("large", 0) > by_tier.get("perk", 0), "cheaper presents are likelier (%s)" % [by_tier])
	check(g.receive_brought("wizard_hat") and g.owns("wizard_hat") and not g.receive_brought("wizard_hat"), "a present not owned is free, once")
	g.rare_hour_enabled = false
	var charmed := 0
	var plain := 0
	for i in 200000:
		if g.roll_tier("legendary", 1.5) in ["rare", "epic", "legendary"]:
			charmed += 1
		if g.roll_tier() in ["rare", "epic", "legendary"]:
			plain += 1
	check(absf(float(charmed) / plain - 1.5) < 0.08, "the lucky charm's luck is half again (got %.2f)" % (float(charmed) / plain))
	g.free()

	# --- First finds pay; a full row pays once more.
	var ff = fresh(path + ".ff")
	ff.row_caps = {"panda": "epic"}
	var rows := []
	ff.row_completed.connect(func(sp, b): rows.append(sp))
	var b_before: int = ff.berries
	ff.record_sighting("panda", "rare")
	check(ff.berries == b_before + 40, "a first Rare find pays 40 berries")
	ff.record_sighting("panda", "rare")
	check(ff.berries == b_before + 40, "a repeat pays nothing")
	for t in ["common", "uncommon", "epic"]:
		ff.record_sighting("panda", t)
	check(rows == ["panda"] and ff.row_complete("panda"), "meeting every tier a species can roll completes its row, once")
	check(ff.berries == b_before + 40 + 5 + 15 + 100 + 500, "first finds and the row bonus add up (got %d)" % (ff.berries - b_before))
	ff.free()

	# --- v2.0's Seen Log into the Collection.
	var v = fresh(path + ".v2")
	v.import_v2_seen({"duck": {"common": 15, "rare": 1}, "kitten": {"legendary": 1}, "custom:x": {"rare": 5}})
	check(v.collection["duckling:common"]["count"] == 15 and v.collection.has("kitten:legendary"), "v2.0 sightings carry over, duck as duckling")
	check(not v.collection.has("custom:x:rare"), "custom critters are left for their own import")
	v.free()

	# --- Save and load round trip; a gap since the save counts as a long break.
	e.save()
	var saved_berries: int = e.berries
	var saved_session: float = e.session_min
	var e2 = fresh(path)
	e2.load_save()
	check(e2.berries == saved_berries, "berries survive a save and load")
	check(e2.collection.has("kitten:rare") and e2.owned.has("hat_red"), "collection and shop survive")
	check(e2.dyed.get("kitten", {}).get("bow", "") == "sky" and e2.treats.size() == 2, "dyes and treats survive")
	check(is_equal_approx(e2.session_min, saved_session), "an immediate reload keeps the session")
	clock += 3600.0
	var e3 = fresh(path)
	e3.load_save()
	check(is_equal_approx(e3.session_min, saved_session * 0.5), "reloading an hour later counts as a long break")

	# --- A night away resets the session; a new day resets the allowances;
	# berries are kept. Working across midnight keeps the session.
	var kept: int = e3.berries
	clock += 3 * 3600.0
	e3.went_away()
	clock += 8 * 3600.0
	e3.came_back(180.0)
	work(e3, 1.0)
	check(e3.session_min < 2.0 and e3.day_focus_min < 2.0, "a night away starts a new session and day")
	check(e3.berries >= kept + 10, "the new day's first session pays its bonus")
	var m = fresh(path + ".m")
	clock = 1_790_000_000.0 + 2000.0   # 23:46 local
	work(m, 60.0)
	check(m.session_min > 59.0, "working across midnight keeps the session (got %.1f)" % m.session_min)
	m.free()

	print("ECONOMY TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	for x in [e, e2, e3, r]:
		x.free()
	quit(0 if fails == 0 else 1)
