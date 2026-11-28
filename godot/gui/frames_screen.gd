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
## Cut a sprite sheet: a PNG cut on a grid (columns, rows, how many frames)
## into one move; more sheets add more moves, each named from a list
## (frames_import.gd stage_sheets(), which sizes them all together). The
## sheets are watched and remembered (source.json) like any other file.
##
## Where's its head? (F3), once homemade critters can wear clothes (the share
## way, R4): per move, a circle on its head in the first frame and on any
## frame where the head moves, stepped through frame by frame; the frames in
## between follow (frame_data.gd head_at()). The marks go into clips.json
## per move, "head": {"<frame>": [cx, cy, r]}, and are kept on Reload; a move
## without marks shows no clothes, and says so.

const Customs := preload("res://customs.gd")
const FramesImport := preload("res://frames_import.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")
const CritterView := preload("res://gui/critter_view.gd")

const STAGING := "user://frames_staging"
const SLOT := "frames"             # its own Customs.show_staged() slot
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
var sheets := []                   # cut a sprite sheet: {"path", "clip", "cols", "rows", "count", "fps"}
var marks := {}                    # clip -> {"<frame>": [cx, cy, r]}: Where's its head?
var head_clip := "walk"            # the move being marked
var head_frame := 0                # and its frame
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
	sheets = []
	marks = {}
	head_clip = "walk"
	head_frame = 0
	if id != "":
		var d: Dictionary = Customs.all[id]
		name = str(d.get("name", ""))
		# Its head marks come with it to the new frames.
		var kept: Dictionary = d.get("_clips", {}).get("clips", {})
		for c in kept:
			if typeof(kept[c]) == TYPE_DICTIONARY and typeof(kept[c].get("head")) == TYPE_DICTIONARY:
				marks[c] = kept[c].head.duplicate(true)
		var src_path := str(d["_dir"]).path_join("source.json")
		var src = JSON.parse_string(FileAccess.get_file_as_string(src_path)) if FileAccess.file_exists(src_path) else null
		if typeof(src) == TYPE_DICTIONARY and typeof(src.get("sheets")) == TYPE_ARRAY and not src.sheets.is_empty():
			if src.sheets.all(func(sh): return typeof(sh) == TYPE_DICTIONARY and FileAccess.file_exists(str(sh.get("path", "")))):
				path = str(src.get("path", src.sheets[0].path))
				sheets = src.sheets.duplicate(true)
				restage_sheets()
				return
		elif typeof(src) == TYPE_DICTIONARY and (FileAccess.file_exists(str(src.get("path", ""))) or DirAccess.dir_exists_absolute(str(src.get("path", "")))):
			open_file(str(src.path))
			return
	else:
		name = ""
	w.rebuild(false)


func close() -> void:
	active = false
	_watching = false
	staged = {}
	sheets = []
	Customs.clear_staged(SLOT)
	preview = ""
	Customs._remove_tree(STAGING)
	w.rebuild(false)


func build(body: VBoxContainer, header: Callable) -> void:
	if not staged.is_empty():
		_frames_page(body, header)
	elif not sheets.is_empty():
		_sheets_page(body, header)
	else:
		_choose_page(body, header)


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
		["*.gif, *.png, *.apng, *.json, *.zip ; Animations"], "Pick your animation", open_file)))
	pick.add_child(K.button("Pick a folder", "bs", "box", true, func(): _dialog(FileDialog.FILE_MODE_OPEN_DIR, [], "Pick the folder of frames", open_file)))
	body.add_child(K.card([
		K.row("Only walk is needed", "Add sit, nap, blink, held, thrown, land and climb if you like, and up to 8 extra moves such as wave or dance. Anything missing borrows from the others.", null),
		K.row("Your animation", "A GIF or animated PNG for each move, Aseprite's JSON with its sheet, a zip, or a folder with a folder of numbered frames per move.", pick),
		K.row("A sprite sheet", "One PNG with the frames in a grid. Say how many columns and rows it has, and which move it is; add another sheet for each other move.",
			K.button("Cut a sprite sheet", "bs", "plus", true, _pick_sheet)),
	]))


func _pick_sheet() -> void:
	_dialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.png ; Sprite sheets"], "Pick your sprite sheet", add_sheet)


func _dialog(mode: int, filters: Array, title: String, done: Callable) -> void:
	var fd := FileDialog.new()
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = mode
	fd.filters = PackedStringArray(filters)
	fd.title = title
	var pick := func(p):
		fd.queue_free()
		done.call(p)
	fd.file_selected.connect(pick)
	fd.dir_selected.connect(pick)
	fd.canceled.connect(fd.queue_free)
	w.add_child(fd)
	fd.popup_centered_ratio(0.6)


func open_file(p: String) -> void:
	path = p
	sheets = []
	_bring_in(FramesImport.stage(p))


func _bring_in(st: Dictionary) -> void:
	# What stage() or stage_sheets() found: written to the staging folder,
	# with the settings (and head marks) kept from before.
	active = true
	if st.error != "":
		error = st.error
		staged = {}
		preview = ""
		Customs.clear_staged(SLOT)
		w.rebuild(false)
		return
	error = ""
	staged = st
	if name == "":
		name = path.get_file().get_basename().replace("_", " ").replace("-", " ").strip_edges().capitalize().left(40)
	var keep_info := info.duplicate()
	info = {}
	for c in staged.clips:
		var old: Dictionary = keep_info.get(c, {})
		info[c] = {"fps": int(old.get("fps", staged.fps.get(c, 8))),
			"loop": bool(old.get("loop", not c.begins_with("act-") and c != "blink" and c != "land")),
			"loops": int(old.get("loops", 2))}
	if not staged.clips.has(head_clip):
		head_clip = "walk"
	head_frame = clampi(head_frame, 0, staged.clips[head_clip].size() - 1)
	Customs._remove_tree(STAGING)
	if FramesImport.write(staged, name if name != "" else "My critter", STAGING, stride) != "":
		apply()
	_mtime = _modified_now()
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
		if not marks.get(c, {}).is_empty():
			clips[c]["head"] = marks[c]
	_json(cj, {"schema": 1, "faces": faces, "ground": FramesImport.GROUND + nudge, "stride_px": stride, "clips": clips})
	preview = Customs.show_staged(STAGING, SLOT)


func _modified(p: String) -> int:
	if DirAccess.dir_exists_absolute(p):
		var newest := 0
		for sub in [""] + Array(DirAccess.get_directories_at(p)):
			var d := p.path_join(sub)
			for f in DirAccess.get_files_at(d):
				newest = maxi(newest, FileAccess.get_modified_time(d.path_join(f)))
		return newest
	return FileAccess.get_modified_time(p)


func _modified_now() -> int:
	# The newest of the file, folder or sheets being brought in.
	if sheets.is_empty():
		return _modified(path)
	var newest := 0
	for sh in sheets:
		newest = maxi(newest, _modified(str(sh.path)))
	return newest


func _watch() -> void:
	if _watching:
		return
	_watching = true
	while _watching and active and is_instance_valid(w) and w.is_inside_tree():
		await w.get_tree().create_timer(2.0).timeout
		if not (_watching and active) or (staged.is_empty() and sheets.is_empty()):
			break
		var m := _modified_now()
		if m != _mtime and m != 0:
			_mtime = m
			reload("Your frames changed, so they were brought in again. Settings are kept.")
	_watching = false


func reload(note := "Brought in again from your file.") -> void:
	_watching = false
	if sheets.is_empty():
		open_file(path)
	else:
		restage_sheets()
	changed_note = note if error == "" else ""
	w.rebuild()


# --- Sprite sheets (E3) -------------------------------------------------------------------

# The moves a sheet can be, in the list's order: the cast's, then a few of its own.
const SHEET_MOVES := ["walk", "sit", "nap", "blink", "held", "thrown", "land", "climb",
	"act-wave", "act-dance", "act-spin", "act-stretch", "act-wiggle", "act-hop"]


static func guess_grid(size: Vector2i) -> Vector2i:
	# A strip of square frames, across or down; else one frame.
	if size.x <= 0 or size.y <= 0:
		return Vector2i.ONE
	if size.x >= size.y and size.x % size.y == 0:
		return Vector2i(int(float(size.x) / size.y), 1)
	if size.y > size.x and size.y % size.x == 0:
		return Vector2i(1, int(float(size.y) / size.x))
	return Vector2i.ONE


func add_sheet(p: String, clip := "") -> void:
	# A sheet for one move: the walk first, then the next move not taken.
	var g := guess_grid(FramesImport.sheet_size(p))
	if clip == "":
		var used := sheets.map(func(sh): return FramesImport.clip_name(str(sh.clip)))
		for m in SHEET_MOVES:
			if not m in used:
				clip = m
				break
	if sheets.is_empty() or path == "":
		path = p
	sheets.append({"path": p, "clip": clip, "cols": g.x, "rows": g.y, "count": 0, "fps": 8})
	restage_sheets()


func restage_sheets() -> void:
	_bring_in(FramesImport.stage_sheets(sheets))


func remove_sheet(i: int) -> void:
	sheets.remove_at(i)
	if sheets.is_empty():
		staged = {}
		path = ""
		preview = ""
		Customs.clear_staged(SLOT)
		w.rebuild(false)
		return
	path = str(sheets[0].path)
	restage_sheets()


func set_sheet(i: int, key: String, value) -> void:
	sheets[i][key] = value
	if key in ["cols", "rows"]:
		sheets[i]["count"] = 0   # every cell of the new grid
	restage_sheets()


func sheet_rows() -> Array:
	var c := K.c
	var rows := []
	for i in sheets.size():
		var n := i
		var sh: Dictionary = sheets[i]
		var size := FramesImport.sheet_size(str(sh.path))
		var cells := int(sh.cols) * int(sh.rows)
		var count := int(sh.count) if int(sh.count) > 0 else cells
		var v := K.vbox(8)
		var top := K.hbox(10)
		var tv := K.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(str(sh.path).get_file(), 15, c.ink, 800))
		tv.add_child(UI.label("%d x %d px, cut into %d frame%s" % [size.x, size.y, count, "" if count == 1 else "s"], 13, c.ink2, 400))
		top.add_child(tv)
		var clip := FramesImport.clip_name(str(sh.clip))
		var names := SHEET_MOVES.map(func(m): return MOVE_NAMES.get(m, str(m).trim_prefix("act-").capitalize() + " (its own move)"))
		top.add_child(K.dropdown(names, maxi(0, SHEET_MOVES.find(clip)), func(j): set_sheet(n, "clip", SHEET_MOVES[j])))
		top.add_child(K.button("Remove", "bq", "", true, func(): remove_sheet(n)))
		v.add_child(top)
		var grid := K.hbox(10)
		grid.add_child(UI.label("Columns", 13, c.ink2, 800))
		grid.add_child(K.stepper(str(sh.cols), func(): set_sheet(n, "cols", maxi(1, int(sh.cols) - 1)), func(): set_sheet(n, "cols", mini(64, int(sh.cols) + 1))))
		grid.add_child(UI.label("Rows", 13, c.ink2, 800))
		grid.add_child(K.stepper(str(sh.rows), func(): set_sheet(n, "rows", maxi(1, int(sh.rows) - 1)), func(): set_sheet(n, "rows", mini(64, int(sh.rows) + 1))))
		grid.add_child(UI.label("Frames", 13, c.ink2, 800))
		grid.add_child(K.stepper("All %d" % cells if count == cells else str(count),
			func(): set_sheet(n, "count", maxi(1, count - 1)),
			func(): set_sheet(n, "count", 0 if count + 1 >= cells else count + 1)))
		v.add_child(grid)
		rows.append(K.margins(v, 20, 12, 20, 12))
	var add := K.button("Add another sheet", "bs", "plus", true, _pick_sheet)
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rows.append(K.margins(add, 20, 10, 20, 12))
	return rows


func _sheets_page(body: VBoxContainer, header: Callable) -> void:
	# Sheets that don't make a critter yet (a grid that doesn't divide, no walk).
	var c := K.c
	var back := K.button("Bring an animation", "bq", "", true, func():
		sheets = []
		_watching = false
		w.rebuild(false))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(back)
	header.call(body, "Cut a sprite sheet", "Say how the sheet is laid out and which move it is.")
	if error != "":
		var l := UI.label(error, 14, c.dng_ink, 800)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
		body.add_child(l)
	body.add_child(K.section("Sprite sheets", K.card(sheet_rows())))
	var bar := K.hbox(10)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	bar.add_child(K.button("Cancel", "bs", "", true, close))
	body.add_child(K.card([K.margins(bar, 20, 14, 20, 14)]))


# --- Where's its head? (F3) ------------------------------------------------------------------

const HEAD_ART := Vector2(240, 224)


static func heads_on() -> bool:
	# Clothes for homemade critters come with the share way (R4).
	return Customs.way_on("share")


func head_marks_of(clip: String) -> Dictionary:
	# In the shape frame_data.gd reads.
	return {"clips": {clip: {"head": marks.get(clip, {})}}}


func head_shown(clip: String, frame: int) -> Variant:
	# The circle on this frame (Vector3 cx, cy, r): marked, or followed along
	# from the marks; null with none.
	return FrameData.head_at(head_marks_of(clip), clip, frame)


func marked(clip: String, frame: int) -> bool:
	return marks.get(clip, {}).has(str(frame))


func frame_image(clip: String, frame: int) -> Image:
	var p := STAGING.path_join("clips/%s/%d.png" % [clip, frame])
	return Image.load_from_file(p) if FileAccess.file_exists(p) else null


func suggest_head(clip: String, frame: int) -> Vector3:
	# Somewhere to start: near the top of the drawing, at the end it faces.
	var img := frame_image(clip, frame)
	if img == null:
		return Vector3(150, 120, 40)
	var u := Rect2(img.get_used_rect())
	var k := float(FramesImport.STORE)
	u = Rect2(u.position / k, u.size / k)
	var r := clampf(minf(u.size.x, u.size.y) * 0.28, 10.0, 80.0)
	var x := u.position.x + r * 1.1 if faces == "left" else u.end.x - r * 1.1
	return Vector3(x, u.position.y + r, r)


func mark(clip: String, frame: int, h: Vector3) -> void:
	# A mark on this frame (frame units), into clips.json at once.
	if not marks.has(clip):
		marks[clip] = {}
	var r := clampf(h.z, 4.0, 200.0)
	marks[clip][str(frame)] = [snappedf(clampf(h.x, 0.0, 300.0), 0.1), snappedf(clampf(h.y, 0.0, 280.0), 0.1), snappedf(r, 0.1)]
	_changed()


func unmark(clip: String, frame: int) -> void:
	marks.get(clip, {}).erase(str(frame))
	if marks.get(clip, {}).is_empty():
		marks.erase(clip)
	_changed()


func clear_marks(clip: String) -> void:
	marks.erase(clip)
	_changed()


func step_frame(by: int) -> void:
	var n: int = staged.clips[head_clip].size()
	head_frame = posmod(head_frame + by, n)
	w.rebuild()


func _head_card() -> Control:
	var c := K.c
	var clips := FrameData.clip_names(staged.clips)
	var n: int = staged.clips[head_clip].size()
	var v := K.vbox(10)
	var t := K.hbox(8)
	t.add_child(UI.label("Where's its head?", 17, c.ink, 600, true))
	t.add_child(K.pill("For clothes", c.track, c.acc_ink))
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(g)
	t.add_child(K.dropdown(clips.map(func(x): return _move_title(x)), maxi(0, clips.find(head_clip)), func(i):
		head_clip = clips[i]
		head_frame = 0
		w.rebuild()))
	v.add_child(t)
	var h := K.hbox(16)
	var well := PanelContainer.new()
	well.custom_minimum_size = HEAD_ART
	well.add_theme_stylebox_override("panel", K.box(c.ph_bg, 16, c.div, 2))
	well.add_child(HeadFrame.new(self))
	h.add_child(well)
	var side := K.vbox(10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(UI.wrap("Put the circle on its head in the first frame, then on any frame where the head moves. The frames in between follow along. A move with no marks shows no clothes.", 13, c.ink2, 360))
	side.add_child(K.stepper("Frame %d of %d%s" % [head_frame + 1, n, ", marked" if marked(head_clip, head_frame) else ""],
		func(): step_frame(-1), func(): step_frame(1)))
	var b := K.hbox(8)
	if marked(head_clip, head_frame):
		b.add_child(K.button("Unmark this frame", "bs", "", true, func(): unmark(head_clip, head_frame)))
	else:
		b.add_child(K.button("Mark this frame", "bs", "", true, func():
			var at = head_shown(head_clip, head_frame)
			mark(head_clip, head_frame, at if at != null else suggest_head(head_clip, head_frame))))
	var clear := K.button("Clear marks", "bq", "", true, func(): clear_marks(head_clip))
	clear.disabled = marks.get(head_clip, {}).is_empty()
	b.add_child(clear)
	side.add_child(b)
	var keys: Array = marks.get(head_clip, {}).keys().map(func(x): return int(x))
	keys.sort()
	side.add_child(UI.wrap("No marks: %s shows no clothes." % _move_title(head_clip) if keys.is_empty()
		else "Marked: frame%s %s. The others follow along." % ["" if keys.size() == 1 else "s", ", ".join(keys.map(func(x): return str(x + 1)))], 12, c.ink3, 360))
	h.add_child(side)
	v.add_child(h)
	return K.card([K.margins(v, 20, 18, 20, 18)])


func _move_title(clip: String) -> String:
	return MOVE_NAMES.get(clip, clip.trim_prefix("act-").capitalize())


class HeadFrame extends Control:
	## One frame of a move with its head circle: solid where this frame is
	## marked, dashed where it follows along. Drag inside to move it, the
	## handle on its right to size it; letting go marks this frame.
	var fs: RefCounted
	var tex: Texture2D
	var h = null                    # Vector3 (cx, cy, r), or null
	var grab := ""                  # move | r
	var from := Vector2.ZERO
	var start := Vector3.ZERO

	func _init(screen: RefCounted) -> void:
		fs = screen
		custom_minimum_size = HEAD_ART
		mouse_filter = Control.MOUSE_FILTER_STOP
		var img: Image = fs.frame_image(fs.head_clip, fs.head_frame)
		if img != null:
			tex = ImageTexture.create_from_image(img)
		h = fs.head_shown(fs.head_clip, fs.head_frame)

	func k() -> float:
		return custom_minimum_size.x / FrameData.FRAME.x

	func _draw() -> void:
		var c := K.c
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, FrameData.FRAME * k()), false)
		var shown: Vector3 = h if h != null else fs.suggest_head(fs.head_clip, fs.head_frame)
		var centre := Vector2(shown.x, shown.y) * k()
		var r := shown.z * k()
		var solid: bool = h != null and fs.marked(fs.head_clip, fs.head_frame)
		draw_circle(centre, r, Color(c.btn, 0.14))
		if solid:
			draw_arc(centre, r, 0.0, TAU, 48, c.btn, 2.0)
		else:
			for i in 24:
				draw_arc(centre, r, TAU * i / 24.0, TAU * (i + 0.5) / 24.0, 3, c.btn if h != null else c.ink3, 2.0)
		var hp := centre + Vector2(r, 0)
		draw_circle(hp, 6.0, c.knob)
		draw_circle(hp, 6.0, c.btn, false, 3.0)

	func _gui_input(e: InputEvent) -> void:
		var shown: Vector3 = h if h != null else fs.suggest_head(fs.head_clip, fs.head_frame)
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var centre := Vector2(shown.x, shown.y) * k()
				grab = ""
				if (centre + Vector2(shown.z * k(), 0)).distance_to(mb.position) <= 10.0:
					grab = "r"
				elif centre.distance_to(mb.position) <= shown.z * k() * 1.1:
					grab = "move"
				if grab != "":
					from = mb.position
					start = shown
					accept_event()
			elif grab != "":
				grab = ""
				accept_event()
				fs.mark(fs.head_clip, fs.head_frame, shown)
			return
		var mm := e as InputEventMouseMotion
		if mm == null or grab == "":
			return
		var du: Vector2 = (mm.position - from) / k()
		if grab == "move":
			h = Vector3(clampf(start.x + du.x, 0.0, 300.0), clampf(start.y + du.y, 0.0, 280.0), start.z)
		else:
			h = Vector3(start.x, start.y, clampf(start.z + du.x, 4.0, 200.0))
		accept_event()
		queue_redraw()


# --- The frames page (Frames.html) --------------------------------------------------

func _frames_page(body: VBoxContainer, header: Callable) -> void:
	var c := K.c
	var back := K.button("Bring an animation", "bq", "", true, func():
		staged = {}
		sheets = []
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

	if not sheets.is_empty():
		body.add_child(K.section("Sprite sheets", K.card(sheet_rows())))
	body.add_child(K.section("Its moves", K.card(move_rows())))
	if heads_on():
		body.add_child(_head_card())
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
		var sub := "%d frame%s" % [staged.clips[cl].size(), "" if staged.clips[cl].size() == 1 else "s"]
		if heads_on():
			sub += ", head marked" if not marks.get(cl, {}).is_empty() else ", shows no clothes"
		tv.add_child(UI.label(sub, 13, c.ink2, 400))
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
	Customs.clear_staged(SLOT)
	var cd = JSON.parse_string(FileAccess.get_file_as_string(STAGING.path_join("custom.json")))
	if typeof(cd) == TYPE_DICTIONARY:
		cd.merge({"name": n, "size": SIZES[size_i][1], "sound": sound}, true)
		_json(STAGING.path_join("custom.json"), cd)
	_json(STAGING.path_join("source.json"), {"path": path, "sheets": sheets} if not sheets.is_empty() else {"path": path})
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
	sheets = []
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
