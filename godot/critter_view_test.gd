extends SceneTree
## Headless checks for gui/critter_view.gd's drawn_rect, which the Collection's
## cards and the Settings previews are sized by. They run on the first frame,
## once the root is in the tree: drawn_rect skips parts not visible in it.
## Run: godot --headless --path godot --script res://critter_view_test.gd

const Customs := preload("res://customs.gd")
const CritterView := preload("res://gui/critter_view.gd")

var fails := 0
var checks := 0
var done := false


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		clear_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	var root := "user://critter_view_test"
	clear_dir(root)
	Customs.dir = root.path_join("custom")

	# A homemade critter is one Polygon2D picture beside the cast's Sprite2D parts.
	var img := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(20, 10, 60, 80), Color(0.8, 0.5, 0.3))
	var id := Customs.add("Measured", [img])
	var home = CritterView.make(id, 160, 140)
	get_root().add_child(home)
	var r: Rect2 = CritterView.drawn_rect(home.critter)
	check(r.size.x > 10.0 and r.size.y > 10.0, "a homemade critter's picture is measured (got %s)" % r.size)

	var cast = CritterView.make("kitten", 160, 140)
	get_root().add_child(cast)
	check(CritterView.drawn_rect(cast.critter).size.x > 10.0, "a kitten's parts are measured")

	home.queue_free()
	cast.queue_free()
	Customs.remove(id)
	clear_dir(root)
	print("CRITTER VIEW TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
	return true
