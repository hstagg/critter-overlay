extends SceneTree
## Headless checks that a player's saves survive bad writes and bad files
## (save_file.gd, and how economy.gd and settings.gd use it).
## Run: godot --headless --path godot --script res://save_test.gd

const SaveFile := preload("res://save_file.gd")
const Economy := preload("res://economy.gd")
const Settings := preload("res://settings.gd")

var fails := 0
var checks := 0
var dir := OS.get_temp_dir().path_join("critter_save_test")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func corrupt_copies(path: String) -> Array:
	return Array(DirAccess.get_files_at(path.get_base_dir())).filter(func(n): return n.begins_with(path.get_file() + ".corrupt-"))


func clean() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for n in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(n))


func _init() -> void:
	clean()
	var p := dir.path_join("a.json")

	# --- Writing keeps the last good copy.
	check(SaveFile.write(p, {"n": 1}), "a first write succeeds")
	check(SaveFile.read(p) == {"n": 1.0}, "and reads back")
	SaveFile.write(p, {"n": 2})
	check(SaveFile.read(p).n == 2.0 and SaveFile.read(p + ".bak").n == 1.0, "a second write keeps the first as .bak")
	check(not FileAccess.file_exists(p + ".tmp"), "no .tmp is left behind")

	# --- A damaged file is set aside, never overwritten, and the .bak is used.
	put(p, "{\"n\": 3, broken")
	var d = SaveFile.read(p)
	check(d != null and d.n == 1.0, "a damaged file falls back to the last good copy")
	var cc := corrupt_copies(p)
	check(cc.size() == 1 and FileAccess.get_file_as_string(dir.path_join(cc[0])) == "{\"n\": 3, broken", "the damaged file is kept byte for byte")
	SaveFile.write(p, {"n": 4})
	check(SaveFile.read(p).n == 4.0 and SaveFile.read(p + ".bak").n == 1.0, "the next write does not rotate the damaged file into .bak")

	# --- A crash between the two renames leaves the new copy as .tmp.
	DirAccess.remove_absolute(p)
	put(p + ".tmp", "{\"n\": 5}")
	check(SaveFile.read(p).n == 5.0, "with no file, a complete .tmp is the newest copy")

	# --- Nothing readable at all.
	clean()
	put(p, "not json")
	check(SaveFile.read(p) == null and corrupt_copies(p).size() == 1, "nothing readable reads as null, and the file is still kept aside")

	# --- The economy: a damaged save starts fresh but is kept.
	clean()
	var ep := dir.path_join("economy.json")
	put(ep, "{\"berries\": 500,")
	var e = Economy.new()
	e.save_path = ep
	e.load_save()
	check(e.berries == 0 and corrupt_copies(ep).size() == 1, "a damaged economy save is kept aside")
	e.free()

	# --- The economy: wrong types read as defaults, without errors.
	put(ep, JSON.stringify({"version": 2, "berries": "lots", "collection": [], "owned": {}, "worn": [], "bond": 5, "day": 7}))
	e = Economy.new()
	e.save_path = ep
	e.load_save()
	check(e.berries == 0 and e.collection == {} and e.owned == [] and e.worn == {} and e.bond == {}, "wrong-typed fields load as defaults")
	e.free()

	# --- The economy: a save from a newer version is never written over.
	var newer := JSON.stringify({"version": 99, "berries": 12})
	put(ep, newer)
	e = Economy.new()
	e.save_path = ep
	e.load_save()
	e.berries += 50
	e.save()
	check(e.read_only and FileAccess.get_file_as_string(ep) == newer, "a newer version's save is left as it is")
	e.free()

	# --- The economy: one long frame (sleep, a stall) is not hours of focus.
	clean()
	e = Economy.new()
	e.save_path = ep
	e.tick(3600.0, true)
	check(e.day_focus_min <= Economy.MAX_TICK_S / 60.0 + 0.0001, "an hour-long frame counts at most %.1f s (got %.2f min)" % [Economy.MAX_TICK_S, e.day_focus_min])
	check(e.next_gift == 0, "and opens no gifts")
	e.free()

	# --- Settings: wrong types read as defaults; unknown keys are kept.
	var sp := dir.path_join("settings.json")
	put(sp, JSON.stringify({"species": {"kitten": [], "rabbit": {"visits": 3}}, "system": {"pause_key": 5}, "critters": {"size": "big"}, "focus": [], "later": {"x": 1}}))
	var s = Settings.new()
	s.path = sp
	s.load_file()
	check(s.sp("kitten", "visits") == 2 and s.sp("rabbit", "visits") == 3, "a wrong-typed species reads as its defaults, others load")
	check(s.value("system.pause_key").vk == 0x50 and s.value("critters.size") == 120 and s.value("focus.max_out") == 8, "wrong-typed settings read as defaults")
	check(s.data.has("later"), "unknown keys are kept")

	# --- Settings: a damaged file is kept aside, and a change is flushed on quit.
	put(sp, "{oops")
	s.load_file()
	check(corrupt_copies(sp).size() == 1 and s.value("focus.max_out") == 8, "a damaged settings file is kept aside")
	s.set_value("focus.max_out", 5)
	s.flush()
	var saved = SaveFile.read(sp)
	check(saved != null and int(saved.focus.max_out) == 5, "flush writes a pending change at once")
	s.free()

	print("SAVE TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
