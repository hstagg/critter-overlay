extends SceneTree
## Every script in the project compiles. The other tests load only what they
## check, so a mistake in main.gd or a GUI page would otherwise reach a build.
## Run: godot --headless --path godot --script res://compile_test.gd

var fails := 0
var checks := 0


func scripts(dir: String) -> Array:
	var out := []
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(scripts(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and not f.ends_with("_test.gd"):
			out.append(dir.path_join(f))
	return out


func _init() -> void:
	for path in scripts("res://"):
		checks += 1
		var s = load(path)
		if s == null or not s.can_instantiate():
			fails += 1
			print("FAIL: ", path, " does not compile")
	print("COMPILE TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
