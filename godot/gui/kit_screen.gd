extends RefCounted
## Draw in your own app (docs/custom-critters-build-plan.md, C4), laid out
## as design/studio/import/Choose.html and Kit.html: pick a body and a file
## (an SVG with layers, a folder or zip of PNG layers, an .ora), then the
## kit page: the critter walking from that file, what it can do (parts found,
## what each missing part costs, what was taken out, layers not recognised),
## its body, gait, size, speed and sound, and Keep. kit_import.gd does the
## work; this only shows what stage() found.
##
## Nothing reaches the store until Keep: the kit is written to a staging
## folder and shown through Customs.show_staged(). The file is watched every
## 2 s while the page is open, and a change brings it in again with the
## name and settings kept (Reload). "Bring in a new version" opens it for a
## kept critter (source.json says where it came from) and Keep replaces
## that critter's drawing.
##
## Not yet: dragging the joints, giving an unrecognised layer a part name,
## and Where's its head? (the design's Kit.html has all three).

const Customs := preload("res://customs.gd")
const KitImport := preload("res://kit_import.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")
const CritterView := preload("res://gui/critter_view.gd")

const STAGING := "user://kit_staging"
const PLANS := [
	["side", "Side-on", "Four legs, seen from the side, like the kitten. Trots or hops."],
	["front", "Faces you", "Sits facing you and walks side-on, like the otter."],
	["upright", "Upright", "Stands on two legs, like the duckling. Waddles or hops."],
	["blob", "Blob", "No legs. Slimes, ghosts, snakes and fish. Bounces, slides or floats."],
]
const SIZES := [["Small", 0.8], ["Normal", 1.0], ["Big", 1.3]]
# What a move needs, in the player's words (customs.gd NEEDS).
const MOVE_WORDS := {"yawn": "yawning", "sneeze": "sneezing", "ear_flick": "ear flicks", "tail_swish": "tail swishes",
	"chase_tail": "chasing its tail", "nose_twitch": "nose twitches", "stand_lookout": "standing up to look",
	"groom": "grooming", "scratch": "scratching", "preen": "preening", "peck_ground": "pecking"}
const PART_WORDS := {"walk-body": "walking body", "leg-front": "front leg", "leg-back": "back leg",
	"leg-front-far": "far front leg", "leg-back-far": "far back leg", "loaf-body": "napping body",
	"stand-body": "standing body", "mouth-open": "open mouth", "ear-l": "left ear", "ear-r": "right ear",
	"head-side": "head from the side", "eye-side": "eye from the side", "eyes-closed": "closed eyes",
	"eye-side-closed": "closed side eye", "leg-near": "near leg", "leg-far": "far leg", "wing-l": "left wing",
	"wing-r": "right wing", "wing-side": "wing from the side", "groom-paws": "grooming paws",
	"scratch-foot": "scratching foot", "head-front": "front of the head"}

var w: Window                      # settings_window.gd
var my: RefCounted                 # my_critters.gd
var active := false
var step := "choose"               # choose | kit
var plan := "side"
var plan_set := false              # changed on the kit page: wins over a template's own body
var path := ""                     # the file being brought in
var replacing := ""                # a kept critter's id, for Bring in a new version
var staged := {}                   # kit_import.gd stage()
var preview := ""                  # Customs.STAGED once written, else ""
var name := ""
var gait := ""
var size_i := 1
var speed := 1.0
var sound := "kitten"
var error := ""
var changed_note := ""
var _mtime := 0
var _watching := false


func _init(win: Window, owner: RefCounted) -> void:
	w = win
	my = owner


func start(id := "") -> void:
	# From Make a critter (a new kit), or Bring in a new version of `id`.
	active = true
	plan_set = false
	replacing = id
	step = "choose"
	error = ""
	changed_note = ""
	path = ""
	if id != "":
		var d: Dictionary = Customs.all[id]
		plan = str(d.get("_kit", {}).get("plan", "side"))
		name = str(d.get("name", ""))
		var src = JSON.parse_string(FileAccess.get_file_as_string(str(d["_dir"]).path_join("source.json"))) \
			if FileAccess.file_exists(str(d["_dir"]).path_join("source.json")) else null
		if typeof(src) == TYPE_DICTIONARY and FileAccess.file_exists(str(src.get("path", ""))):
			open_file(str(src.path))
			return
	w.rebuild(false)


func close() -> void:
	active = false
	_watching = false
	staged = {}
	Customs.clear_staged()
	preview = ""
	_clear_staging()
	w.rebuild(false)


func build(body: VBoxContainer, header: Callable) -> void:
	if step == "kit" and not staged.is_empty():
		_kit_page(body, header)
	else:
		_choose_page(body, header)


# --- Choose (Choose.html) ---------------------------------------------------------

func _choose_page(body: VBoxContainer, header: Callable) -> void:
	var c := K.c
	var back := K.button("Make a critter", "bq", "", true, close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(back)
	header.call(body, "Draw in your own app", "Pick a body, draw each part on its own layer, then bring the file back here.")
	if error != "":
		body.add_child(_note(error, "", c.dng_ink))
	var rows := []
	for p in PLANS:
		var pid: String = p[0]
		var r := K.hbox(14)
		var well := PanelContainer.new()
		well.custom_minimum_size = Vector2(64, 56)
		well.add_theme_stylebox_override("panel", K.box(c.track, 12))
		var cast: String = {"side": "kitten", "front": "otter", "upright": "duckling", "blob": ""}[pid]
		if cast != "":
			well.add_child(CritterView.make(cast, 64, 56, 0.35, "sit"))
		r.add_child(well)
		var tv := K.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(p[1], 15, c.ink, 800))
		var dl := UI.label(p[2], 13, c.ink2, 400)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 280
		tv.add_child(dl)
		r.add_child(tv)
		r.add_child(K.chip("Picked" if plan == pid else "Pick", plan == pid, func():
			plan = pid
			w.rebuild()))
		rows.append(K.margins(r, 18, 10, 18, 10))
	body.add_child(K.section("Its body", K.card(rows)))
	body.add_child(K.section("Start from a template", K.card([
		K.row("Get the drawing templates", "One file for each body, with a layer per part and a faint critter to draw over. Works in Inkscape, Krita, Procreate, Photoshop, Affinity and more.",
			K.button("Get the templates", "bs", "update", true, _save_templates)),
	])))
	var pick := K.hbox(10)
	pick.add_child(K.button("Pick a file", "bp", "plus", true, _pick_file))
	pick.add_child(K.button("Pick a folder", "bs", "box", true, _pick_folder))
	body.add_child(K.section("Bring it in", K.card([
		K.row("Your drawing", "An SVG with a layer per part, a folder or zip of PNG layers, or a Krita, GIMP or MyPaint .ora file. Photoshop (.psd) files can't be read: export the layers as PNGs first.", pick),
	])))


func _pick_file() -> void:
	_dialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.svg, *.zip, *.ora ; Drawings"], "Pick your drawing", open_file)


func _pick_folder() -> void:
	_dialog(FileDialog.FILE_MODE_OPEN_DIR, [], "Pick the folder of PNG layers", open_file)


func _save_templates() -> void:
	_dialog(FileDialog.FILE_MODE_OPEN_DIR, [], "Where should the templates go?", func(dir: String):
		var n := 0
		for p in PLANS:
			for f in ["%s-1.svg" % p[0], "%s-1-guide.png" % p[0]]:
				var bytes := FileAccess.get_file_as_bytes("res://templates/" + f)
				var out := FileAccess.open(dir.path_join(f), FileAccess.WRITE)
				if out != null and not bytes.is_empty():
					out.store_buffer(bytes)
					n += 1
		changed_note = ""
		error = "" if n == 8 else "Some templates couldn't be saved there."
		if n == 8:
			OS.shell_open(dir)
		w.rebuild())


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


# --- Bringing it in ------------------------------------------------------------------

func open_file(p: String) -> void:
	# A file or folder through kit_import.gd stage(), then the kit page.
	path = p
	var first := staged.is_empty()
	_restage()
	if staged.error != "":
		error = staged.error
		step = "choose"
		staged = {}
	else:
		error = ""
		step = "kit"
		if first and name == "":
			name = p.get_file().get_basename().replace("_", " ").replace("-", " ").strip_edges().capitalize().left(40)
		_mtime = _modified(p)
		_watch()
	w.rebuild(false)


func _restage() -> void:
	# A file from a template knows its body; any other drawing takes the one
	# picked, unless the body was changed on the kit page.
	staged = KitImport.stage(path, plan if plan_set else "")
	if staged.error == "" and not plan_set and staged.template == "" and staged.plan != plan:
		staged = KitImport.stage(path, plan)
	if staged.error != "":
		return
	plan = staged.plan
	if not gait in KitData.PLANS[plan].gaits:
		gait = staged.gait
	staged.gait = gait
	preview = ""
	Customs.clear_staged()
	if staged.missing.is_empty():
		_clear_staging()
		if KitImport.write(staged, name if name != "" else "My critter", STAGING) != "":
			preview = Customs.show_staged(STAGING)


func _modified(p: String) -> int:
	if DirAccess.dir_exists_absolute(p):
		var newest := 0
		for f in DirAccess.get_files_at(p):
			newest = maxi(newest, FileAccess.get_modified_time(p.path_join(f)))
		return newest
	return FileAccess.get_modified_time(p)


func _watch() -> void:
	# Reload: every 2 s while the kit page is open, look for a newer file.
	if _watching:
		return
	_watching = true
	while _watching and active and step == "kit" and is_instance_valid(w) and w.is_inside_tree():
		await w.get_tree().create_timer(2.0).timeout
		if not (_watching and active and step == "kit"):
			break
		var m := _modified(path)
		if m != _mtime and m != 0:
			_mtime = m
			reload("Your file changed, so it was brought in again. Name and settings are kept.")
	_watching = false


func reload(note := "Brought in again from your file.") -> void:
	_restage()
	changed_note = note if staged.error == "" else staged.error
	if staged.error != "":
		step = "choose"
		error = staged.error
		staged = {}
	w.rebuild()


# --- The kit page (Kit.html) --------------------------------------------------------

func _kit_page(body: VBoxContainer, header: Callable) -> void:
	var c := K.c
	var back := K.button("Draw in your own app", "bq", "", true, func():
		step = "choose"
		_watching = false
		w.rebuild(false))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(back)
	header.call(body, "Bring in a new version" if replacing != "" else "Your drawing",
		"From %s. Keep this page open while you draw: it's brought in again whenever you save the file." % path.get_file())
	if changed_note != "":
		body.add_child(_note(changed_note, "", c.acc_ink))

	var top := K.hbox(20)
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(320, 260)
	well.add_theme_stylebox_override("panel", K.box(c.track, 18))
	if preview != "":
		well.add_child(CritterView.make(preview, 320, 256, 1.1, "walk"))
	else:
		var l := UI.label("It can walk once the needed parts are drawn.", 14, c.ink2, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		well.add_child(l)
	top.add_child(well)
	var checks := K.vbox(8)
	checks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checks.add_child(UI.label("What it can do", 17, c.ink, 600, true))
	for line in check_lines(staged):
		var l := UI.label(line[1], 13, {"ok": c.ink_body, "need": c.dng_ink, "cost": c.ink2, "note": c.ink2}[line[0]], 700 if line[0] == "need" else 400)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 300
		checks.add_child(l)
	top.add_child(checks)
	body.add_child(K.card([K.margins(top, 20, 18, 20, 18)]))

	var pl: Dictionary = KitData.PLANS[plan]
	var gaits: Array = pl.gaits
	var rows := [
		K.row("Its body", "Picked from your file. Change it if it's wrong.", K.seg(PLANS.map(func(x): return x[1]), PLANS.map(func(x): return x[0]).find(plan), func(i):
			plan = PLANS[i][0]
			plan_set = true
			reload("Brought in again as %s." % PLANS[i][1].to_lower()))),
		K.row("How it walks", "", K.dropdown(gaits.map(func(g): return str(g).replace("_", " ").capitalize()), maxi(0, gaits.find(gait)), func(i):
			gait = gaits[i]
			reload("It now walks with a %s." % str(gait).replace("_", " ")))),
		K.row("Size", "", K.seg(SIZES.map(func(x): return x[0]), size_i, func(i):
			size_i = i
			w.rebuild())),
		K.row("Pop sound", "Borrow a critter's sound. Add your own on its page once it's kept.", K.dropdown(Customs.SOUNDS.map(func(x): return str(x).capitalize()),
			maxi(0, Customs.SOUNDS.find(sound)), func(i): sound = Customs.SOUNDS[i])),
	]
	body.add_child(K.card(rows))

	var bar := K.hbox(10)
	var field := K.text_field(name, "Its name", 40, func(t): name = t)
	field.custom_minimum_size.x = 260
	bar.add_child(field)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	if not staged.missing.is_empty():
		bar.add_child(UI.label("Draw the needed parts to keep it.", 13, c.dng_ink, 700))
	bar.add_child(K.button("Cancel", "bs", "", true, close))
	var keep_b := K.button("Save" if replacing != "" else "Keep", "bp", "check", true, func(): keep())
	keep_b.disabled = not staged.missing.is_empty()
	bar.add_child(keep_b)
	body.add_child(K.card([K.margins(bar, 20, 14, 20, 14)]))


static func check_lines(st: Dictionary) -> Array:
	# [kind, words]: ok (found), need (a required part missing), cost (an
	# optional part missing and the moves it takes away), note (taken out,
	# not recognised).
	var out := []
	var pl: Dictionary = KitData.PLANS[st.plan]
	out.append(["ok", "Found %d part%s: %s." % [st.parts.size(), "" if st.parts.size() == 1 else "s", ", ".join(st.parts.keys().map(func(p): return PART_WORDS.get(p, p)))]])
	for p in st.missing:
		out.append(["need", "Needed: the %s. It can't walk without it." % PART_WORDS.get(p, p)])
	for p in pl.optional:
		if st.parts.has(p):
			continue
		var lost := []
		for b in Customs.NEEDS:
			var n: Dictionary = Customs.NEEDS[b]
			if n.has("plans") and not st.plan in n.plans:
				continue
			var needs_it: bool = p in n.get("parts", []) or (n.has("any") and n.any.all(func(x): return x == p or not st.parts.has(x)) and p in n.any)
			if needs_it and MOVE_WORDS.has(b) and not MOVE_WORDS[b] in lost:
				lost.append(MOVE_WORDS[b])
		if not lost.is_empty():
			out.append(["cost", "No %s: no %s." % [PART_WORDS.get(p, p), " or ".join(lost)]])
	if not st.dropped.is_empty():
		out.append(["note", "Left out of the file: %s." % ", ".join(st.dropped)])
	if not st.unmatched.is_empty():
		out.append(["note", "Not recognised: %s. Name a layer after a part (see the template) to use it." % ", ".join(st.unmatched)])
	return out


func keep() -> String:
	# Into the store (or over the critter being replaced). Returns its id.
	if staged.is_empty() or not staged.missing.is_empty():
		return ""
	var n := name.strip_edges() if name.strip_edges() != "" else "My critter"
	_clear_staging()
	if KitImport.write(staged, n, STAGING, {"size": SIZES[size_i][1], "speed": speed, "sound": sound}) == "":
		return ""
	_json(STAGING.path_join("source.json"), {"path": path})
	Customs.clear_staged()
	var id := ""
	if replacing != "" and Customs.all.has(replacing):
		# Bring in a new version: the new drawing, its name and settings kept.
		id = replacing
		var folder := str(Customs.all[id]["_dir"])
		Customs._remove_tree(folder.path_join("parts"))
		Customs._copy_tree(STAGING.path_join("parts"), folder.path_join("parts"))
		for f in ["kit.json", "source.json"]:
			DirAccess.copy_absolute(STAGING.path_join(f), folder.path_join(f))
		Customs._read_extras(Customs.all[id])
		Customs.bump_rev(id)
	else:
		id = Customs.add_folder(STAGING)
	_clear_staging()
	active = false
	_watching = false
	staged = {}
	preview = ""
	if id != "":
		my.selected = id
		my.view = "detail"
	w.rebuild(false)
	return id


func _note(title: String, text: String, colour: Color) -> Control:
	var v := K.vbox(4)
	var t := UI.label(title, 14, colour, 800)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 400
	v.add_child(t)
	if text != "":
		v.add_child(UI.label(text, 13, K.c.ink2, 400))
	return K.card([K.margins(v, 18, 12, 18, 12)])


static func _json(p: String, d: Dictionary) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()


static func _clear_staging() -> void:
	Customs._remove_tree(STAGING)
