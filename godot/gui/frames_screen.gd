extends RefCounted
## Bring an animation (docs/custom-critters-build-plan.md, E3), laid out as
## design/studio/import/Frames.html: pick a folder of frames, a GIF or
## animated PNG, Aseprite's JSON or a zip; then its moves (each clip's
## frames, how fast and whether it loops, and what a missing move borrows),
## which way it faces, a nudge to the ground, its step length, size and sound,
## P11's warnings, and Keep. frames_import.gd does the work.
##
## The frames are written to a staging folder once per file; the settings
## only rewrite its clips.json, and the critter walking beside them is
## shown again (Customs.show_staged). The file is watched as on the kit
## page (Reload), and Change frames reopens a kept critter's file.
##
## Not yet: cutting a single sprite sheet on a grid (frames_import.gd
## stage_sheet() is ready for it), and Where's its head?, which comes with
## clothes for homemade critters (R4).

const Customs := preload("res://customs.gd")
const FramesImport := preload("res://frames_import.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")
const CritterView := preload("res://gui/critter_view.gd")

const STAGING := "user://frames_staging"
const SIZES := [["Small", 0.8], ["Normal", 1.0], ["Big", 1.3]]
const MOVE_NAMES := {"walk": "Walk", "sit": "Sit", "nap": "Nap", "blink": "Blink", "held": "Held",
	"thrown": "Thrown", "land": "Land", "climb": "Climb"}
# What a missing move borrows (frames.gd which_clip()).
const BORROWS := {"sit": "walk's first frame", "nap": "sit", "blink": "nothing: it doesn't blink",
	"held": "sit", "thrown": "held", "land": "a squash", "climb": "walk"}

var w: Window
var my: RefCounted
var active := false
var path := ""
var replacing := ""
var staged := {}                   # frames_import.gd stage()
var info := {}                     # clip -> {"fps", "loop", "loops"}
var preview := ""
var name := ""
var faces := "left"
var nudge := 0
var stride := 100.0
var size_i := 1
var sound := "kitten"
var error := ""
var changed_note := ""
var _mtime := 0
var _watching := false


func _init(win: Window, owner: RefCounted) -> void:
	w = win
	my = owner


func start(id := "") -> void:
	active = true
	replacing = id
	error = ""
	changed_note = ""
	staged = {}
	path = ""
	if id != "":
		var d: Dictionary = Customs.all[id]
		name = str(d.get("name", ""))
		var src_path := str(d["_dir"]).path_join("source.json")
		var src = JSON.parse_string(FileAccess.get_file_as_string(src_path)) if FileAccess.file_exists(src_path) else null
		if typeof(src) == TYPE_DICTIONARY and (FileAccess.file_exists(str(src.get("path", ""))) or DirAccess.dir_exists_absolute(str(src.get("path", "")))):
			open_file(str(src.path))
			return
	else:
		name = ""
	w.rebuild(false)


func close() -> void:
	active = false
	_watching = false
	staged = {}
	Customs.clear_staged()
	preview = ""
	Customs._remove_tree(STAGING)
	w.rebuild(false)


func build(body: VBoxContainer, header: Callable) -> void:
	if staged.is_empty():
		_choose_page(body, header)
	else:
		_frames_page(body, header)


func _choose_page(body: VBoxContainer, header: Callable) -> void:
	var c := K.c
	var back := K.button("Make a critter", "bq", "", true, close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(back)
	header.call(body, "Bring an animation", "Your frames play exactly as you drew them. Give each move its own file or tag, and name it after what it shows.")
	if error != "":
		var l := UI.label(error, 14, c.dng_ink, 800)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
		body.add_child(l)
	var pick := K.hbox(10)
	pick.add_child(K.button("Pick a file", "bp", "plus", true, func(): _dialog(FileDialog.FILE_MODE_OPEN_FILE,
		["*.gif, *.png, *.apng, *.json, *.zip ; Animations"], "Pick your animation")))
	pick.add_child(K.button("Pick a folder", "bs", "box", true, func(): _dialog(FileDialog.FILE_MODE_OPEN_DIR, [], "Pick the folder of frames")))
	body.add_child(K.card([
		K.row("Only walk is needed", "Add sit, nap, blink, held, thrown, land and climb if you like, and up to 8 extra moves such as wave or dance. Anything missing borrows from the others.", null),
		K.row("Your animation", "A GIF or animated PNG for each move, Aseprite's JSON with its sheet, a zip, or a folder with a folder of numbered frames per move.", pick),
	]))


func _dialog(mode: int, filters: Array, title: String) -> void:
	var fd := FileDialog.new()
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = mode
	fd.filters = PackedStringArray(filters)
	fd.title = title
	var pick := func(p):
		fd.queue_free()
		open_file(p)
	fd.file_selected.connect(pick)
	fd.dir_selected.connect(pick)
	fd.canceled.connect(fd.queue_free)
	w.add_child(fd)
	fd.popup_centered_ratio(0.6)


func open_file(p: String) -> void:
	path = p
	active = true
	var st := FramesImport.stage(p)
	if st.error != "":
		error = st.error
		staged = {}
		w.rebuild(false)
		return
	error = ""
	staged = st
	if name == "":
		name = p.get_file().get_basename().replace("_", " ").replace("-", " ").strip_edges().capitalize().left(40)
	var keep_info := info.duplicate()
	info = {}
	for c in staged.clips:
		var old: Dictionary = keep_info.get(c, {})
		info[c] = {"fps": int(old.get("fps", staged.fps.get(c, 8))),
			"loop": bool(old.get("loop", not c.begins_with("act-") and c != "blink" and c != "land")),
			"loops": int(old.get("loops", 2))}
	Customs._remove_tree(STAGING)
	if FramesImport.write(staged, name if name != "" else "My critter", STAGING, stride) != "":
		apply()
	_mtime = _modified(p)
	_watch()
	w.rebuild(false)


func apply() -> void:
	# The settings into the staging folder's clips.json, and the preview again.
	var cj := STAGING.path_join("clips.json")
	if not FileAccess.file_exists(cj):
		preview = ""
		return
	var clips := {}
	for c in info:
		clips[c] = {"fps": info[c].fps, "loop": info[c].loop}
		if c.begins_with("act-"):
			clips[c]["loops"] = info[c].loops
	_json(cj, {"schema": 1, "faces": faces, "ground": FramesImport.GROUND + nudge, "stride_px": stride, "clips": clips})
	preview = Customs.show_staged(STAGING)


func _modified(p: String) -> int:
	if DirAccess.dir_exists_absolute(p):
		var newest := 0
		for sub in [""] + Array(DirAccess.get_directories_at(p)):
			var d := p.path_join(sub)
			for f in DirAccess.get_files_at(d):
				newest = maxi(newest, FileAccess.get_modified_time(d.path_join(f)))
		return newest
	return FileAccess.get_modified_time(p)


func _watch() -> void:
	if _watching:
		return
	_watching = true
	while _watching and active and is_instance_valid(w) and w.is_inside_tree():
		await w.get_tree().create_timer(2.0).timeout
		if not (_watching and active) or staged.is_empty():
			break
		var m := _modified(path)
		if m != _mtime and m != 0:
			_mtime = m
			reload("Your frames changed, so they were brought in again. Settings are kept.")
	_watching = false


func reload(note := "Brought in again from your file.") -> void:
	_watching = false
	open_file(path)
	changed_note = note if error == "" else ""
	w.rebuild()


# --- The frames page (Frames.html) --------------------------------------------------

func _frames_page(body: VBoxContainer, header: Callable) -> void:
	var c := K.c
	var back := K.button("Bring an animation", "bq", "", true, func():
		staged = {}
		_watching = false
		w.rebuild(false))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(back)
	header.call(body, "Change frames" if replacing != "" else "Your animation",
		"From %s. Keep this page open while you draw: it's brought in again whenever you save." % path.get_file())
	if changed_note != "":
		body.add_child(UI.label(changed_note, 14, c.acc_ink, 800))

	var top := K.hbox(20)
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(320, 260)
	well.add_theme_stylebox_override("panel", K.box(c.track, 18))
	if preview != "":
		well.add_child(CritterView.make(preview, 320, 256, 1.1, "walk"))
	top.add_child(well)
	var checks := K.vbox(8)
	checks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checks.add_child(UI.label("Worth a look", 17, c.ink, 600, true))
	var warns: Array = staged.get("warnings", [])
	if not staged.clips.has("walk"):
		warns = ["No walk: it needs a move called walk to get about."] + warns
	if warns.is_empty():
		checks.add_child(UI.label("Nothing: it's all ready.", 13, c.ink2, 400))
	for x in warns:
		var l := UI.label(str(x), 13, c.ink_body, 400)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 300
		checks.add_child(l)
	top.add_child(checks)
	body.add_child(K.card([K.margins(top, 20, 18, 20, 18)]))

	body.add_child(K.section("Its moves", K.card(move_rows())))
	body.add_child(K.card([
		K.row("Faces", "Which way your frames face.", K.seg(["Left", "Right"], 1 if faces == "right" else 0, func(i):
			faces = "right" if i == 1 else "left"
			_changed())),
		K.row("Ground", "Nudge it up or down if its feet float or sink.", K.stepper("%+d" % nudge if nudge != 0 else "On the line",
			func():
				nudge = clampi(nudge - 2, -40, 40)
				_changed(),
			func():
				nudge = clampi(nudge + 2, -40, 40)
				_changed())),
		_stride_row(),
		K.row("Size", "", K.seg(SIZES.map(func(x): return x[0]), size_i, func(i):
			size_i = i
			w.rebuild())),
		K.row("Pop sound", "Borrow a critter's sound. Add your own on its page once it's kept.", K.dropdown(Customs.SOUNDS.map(func(x): return str(x).capitalize()),
			maxi(0, Customs.SOUNDS.find(sound)), func(i): sound = Customs.SOUNDS[i])),
	]))

	var bar := K.hbox(10)
	var field := K.text_field(name, "Its name", 40, func(t): name = t)
	field.custom_minimum_size.x = 260
	bar.add_child(field)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	if not staged.clips.has("walk"):
		bar.add_child(UI.label("Add a walk to keep it.", 13, c.dng_ink, 700))
	bar.add_child(K.button("Cancel", "bs", "", true, close))
	var keep_b := K.button("Save" if replacing != "" else "Keep", "bp", "check", true, func(): keep())
	keep_b.disabled = not staged.clips.has("walk")
	bar.add_child(keep_b)
	body.add_child(K.card([K.margins(bar, 20, 14, 20, 14)]))


func _stride_row() -> Control:
	var sl := K.slider(stride, 20, 300, 5, 220, func(x): stride = x)
	sl.drag_ended.connect(func(_c): _changed())
	return K.row("Step length", "How far one walk cycle carries it, so its feet don't slide.", K.slider_row_control(sl, "Short", "Long", null))


func move_rows() -> Array:
	# One row per move it has, then one per move it borrows.
	var c := K.c
	var rows := []
	for clip in FrameData.clip_names(staged.clips):
		var cl: String = clip
		var h := K.hbox(12)
		var title: String = MOVE_NAMES.get(cl, cl.trim_prefix("act-").capitalize())
		var tv := K.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(title, 15, c.ink, 800))
		tv.add_child(UI.label("%d frame%s" % [staged.clips[cl].size(), "" if staged.clips[cl].size() == 1 else "s"], 13, c.ink2, 400))
		h.add_child(tv)
		h.add_child(K.stepper("%d a second" % int(info[cl].fps),
			func():
				info[cl].fps = clampi(int(info[cl].fps) - 1, 1, 30)
				_changed(),
			func():
				info[cl].fps = clampi(int(info[cl].fps) + 1, 1, 30)
				_changed()))
		if cl.begins_with("act-"):
			h.add_child(K.seg(["Once", "Twice", "3 times"], clampi(int(info[cl].loops) - 1, 0, 2), func(i):
				info[cl].loops = i + 1
				_changed()))
		elif cl != "walk":
			h.add_child(K.seg(["Loops", "Plays once"], 0 if info[cl].loop else 1, func(i):
				info[cl].loop = i == 0
				_changed()))
		rows.append(K.margins(h, 20, 12, 20, 12))
	for cl in BORROWS:
		if not staged.clips.has(cl):
			rows.append(K.margins(UI.label("%s: borrows %s." % [MOVE_NAMES[cl], BORROWS[cl]], 13, c.ink2, 400), 20, 8, 20, 8))
	return rows


func _changed() -> void:
	apply()
	w.rebuild()


func keep() -> String:
	if staged.is_empty() or not staged.clips.has("walk"):
		return ""
	var n := name.strip_edges() if name.strip_edges() != "" else "My critter"
	apply()
	Customs.clear_staged()
	var cd = JSON.parse_string(FileAccess.get_file_as_string(STAGING.path_join("custom.json")))
	if typeof(cd) == TYPE_DICTIONARY:
		cd.merge({"name": n, "size": SIZES[size_i][1], "sound": sound}, true)
		_json(STAGING.path_join("custom.json"), cd)
	_json(STAGING.path_join("source.json"), {"path": path})
	var id := ""
	if replacing != "" and Customs.all.has(replacing):
		id = replacing
		var folder := str(Customs.all[id]["_dir"])
		Customs._remove_tree(folder.path_join("clips"))
		Customs._copy_tree(STAGING.path_join("clips"), folder.path_join("clips"))
		for f in ["clips.json", "source.json"]:
			DirAccess.copy_absolute(STAGING.path_join(f), folder.path_join(f))
		Customs._read_extras(Customs.all[id])
		Customs.bump_rev(id)
		FrameData.forget(id)
	else:
		id = Customs.add_folder(STAGING)
	Customs._remove_tree(STAGING)
	active = false
	_watching = false
	staged = {}
	preview = ""
	if id != "":
		my.selected = id
		my.view = "detail"
	w.rebuild(false)
	return id


static func _json(p: String, d: Dictionary) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
