extends SceneTree
## Headless checks for settings.gd.
## Run: godot --headless --path godot --script res://settings_test.gd

const Settings := preload("res://settings.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	var path := OS.get_temp_dir().path_join("critter_settings_test.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var s = Settings.new()
	s.path = path
	s.load_file()
	check(s.value("focus.max_out") == 8, "defaults load without a file")
	check(s.value("world.notes") == "rare", "rare sighting notes default to Rare and up")
	check(s.sp("kitten", "visits") == 2 and s.sp("rabbit", "visits") == 1, "kittens visit often, as in v2.0")
	check(s.sp("turtle", "tier_max") == "epic" and s.sp("panda", "tier_max") == "epic", "turtle and panda stop at Epic")
	check(is_equal_approx(s.zoom(), 1.0), "120 px is the art's own size")

	var seen := []
	s.changed.connect(func(k): seen.append(k))
	s.set_value("focus.max_out", 12)
	s.set_value("focus.max_out", 12)
	check(seen == ["focus.max_out"], "a change is announced once, and not when nothing changed (got %s)" % [seen])
	s.set_value("species.rabbit.speed", 4)
	check(s.sp("rabbit", "speed") == 4 and s.sp("rabbit", "activity") == 2, "a species block fills in from the defaults")
	check(s.value("species.duckling.trail") == "none", "a species field reads its default by path")

	# Odds are relative weights.
	s.set_value("world.odds", {"common": 50, "uncommon": 25, "rare": 25, "epic": 0, "legendary": 0})
	var o: Dictionary = s.odds()
	check(is_equal_approx(o["common"], 0.5) and is_equal_approx(o["rare"], 0.25) and o["epic"] == 0.0, "odds normalise (got %s)" % [o])

	# Saving keeps unknown keys from a newer version.
	s.data["future"] = {"thing": 1}
	s.save()
	var t = Settings.new()
	t.path = path
	t.load_file()
	check(t.value("focus.max_out") == 12 and t.sp("rabbit", "speed") == 4, "settings survive a save and load")
	check(t.data.has("future") and t.data["future"]["thing"] == 1, "keys this version does not know are kept")
	check(t.value("focus.nap_after_min") == 3, "keys missing from the file come from the defaults")

	# Resets.
	t.reset_species("rabbit")
	check(t.sp("rabbit", "speed") == 2, "reset one critter")
	t.set_value("system.onboarded", true)
	t.set_value("critters.size", 200)
	t.reset_all()
	check(t.value("critters.size") == 120 and t.value("system.onboarded") == true, "reset all keeps having seen the welcome")

	check(Settings.key_text({"mods": 6, "vk": 0x50}) == PackedStringArray(["Ctrl", "Shift", "P"]), "Ctrl+Shift+P reads back")
	check(Settings.key_text({"mods": 1, "vk": 0x71}) == PackedStringArray(["Alt", "F2"]), "Alt+F2 reads back")
	check(Settings.key_text({"mods": 0, "vk": 0}).is_empty(), "an unset shortcut reads as nothing")

	# A broken file falls back to defaults.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var u = Settings.new()
	u.path = path
	u.load_file()
	check(u.value("focus.max_out") == 8, "an unreadable file means defaults")

	# Day and night pacing (time_of_day.gd, v2.0's buckets).
	var T := preload("res://time_of_day.gd")
	check(T.at(9.0) == [1.10, 1.20, 0.05], "mid-morning is lively (got %s)" % [T.at(9.0)])
	check(T.at(23.0) == [0.50, 0.50, 0.85] and T.at(3.0) == [0.50, 0.50, 0.85], "night wraps midnight")
	check(T.at(6.0)[0] == 0.90, "dawn")
	var edge: Array = T.at(7.95)
	check(edge[0] > 0.9 and edge[0] < 1.1, "blends into morning over ten minutes (got %s)" % [edge])
	check(is_equal_approx(T.at(4.999)[0], 0.9) or T.at(4.999)[0] > 0.5, "blends from night into dawn")

	print("SETTINGS TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	for x in [s, t, u]:
		x.free()
	quit(0 if fails == 0 else 1)
