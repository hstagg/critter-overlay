extends SceneTree
## Headless check that every SVG under art/ is imported with "keep".
## Run: godot --headless --path godot --script res://import_test.gd
##
## The rigs read their SVGs as text at run time (critter.gd and friends), so
## an export only carries them when their .import file says importer="keep".
## Without one, Godot imports a new SVG as a texture and the exported game
## draws nothing for that part. The .import files are committed for this.

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _walk(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".svg"):
			var imp := dir.path_join(f) + ".import"
			var text := FileAccess.get_file_as_string(imp) if FileAccess.file_exists(imp) else ""
			check(text.contains("importer=\"keep\""), "%s has a .import with importer=\"keep\"" % dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d))


func _init() -> void:
	_walk("res://art")
	check(checks > 300, "found the art (%d SVGs)" % checks)
	print("IMPORT TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
