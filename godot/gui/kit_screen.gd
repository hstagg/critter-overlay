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
## A layer it didn't recognise can be named as a part (kit_import.gd stage()'s
## assign). Joints (Kit.html, P4): the art in its main pose with the pins as
## dots (pins_panel.gd's names and limits), dragged within 4.7's box; a
## dragged pin is kept in the staged kit (kit_import.gd move_pin) and laid
## over the file's again on Reload. Where's its head? (F1): the measured
## ellipse on the head with a hat to try on, moved and sized by dragging; it
## shows only once homemade critters can wear clothes (the share way, R4),
## and goes into kit.json "head" on Keep.

const Customs := preload("res://customs.gd")
const KitImport := preload("res://kit_import.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")
const CritterView := preload("res://gui/critter_view.gd")
const Pins := preload("res://gui/studio/pins_panel.gd")
const Wear := preload("res://wear.gd")

const STAGING := "user://kit_staging"
const SLOT := "kit"                # its own Customs.show_staged() slot
const GUIDE := "https://github.com/hstagg/critter-overlay/blob/main/docs/making-critters.md"   # moves with the repo, as settings_pages.gd REPO
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
var assign := {}                   # layer name -> part, for layers not recognised
var path := ""                     # the file being brought in
var replacing := ""                # a kept critter's id, for Bring in a new version
var staged := {}                   # kit_import.gd stage()
var preview := ""                  # Customs.staged_id(SLOT) once written, else ""
var name := ""
var gait := ""
var size_i := 1
var speed := 1.0
var sound := "kitten"
var error := ""
var changed_note := ""
var moved := {}                    # joints dragged on this page (kit_import.gd move_pin), kept on Reload
var head_adj := {}                 # Where's its head?: kit_import.gd adjusted_head()'s adj
var keep_head := {}                # a kept critter's head, laid over its new version
var art_pose := "walk"             # the pose the joints are shown in
var hat := "beanie"                # the hat tried on
var rig := {}                      # kit_data.gd build() of the staged kit, for the art
var dy := 0.0                      # how far grounding moved the staged art
var _mtime := 0
var _watching := false


func _init(win: Window, owner: RefCounted) -> void:
	w = win
	my = owner


func start(id := "") -> void:
	# From Make a critter (a new kit), or Bring in a new version of `id`.
	active = true
	plan_set = false
	assign = {}
	moved = {}
	head_adj = {}
	keep_head = {}
	rig = {}
	replacing = id
	step = "choose"
	error = ""
	changed_note = ""
	path = ""
	if id != "":
		var d: Dictionary = Customs.all[id]
		plan = str(d.get("_kit", {}).get("plan", "side"))
		name = str(d.get("name", ""))
		# Its dragged joints and its head come with it to the new version.
		var km = d.get("_kit", {}).get("moved", {})
		moved = km.duplicate(true) if typeof(km) == TYPE_DICTIONARY else {}
		var kh = d.get("_kit", {}).get("head", {})
		keep_head = kh if typeof(kh) == TYPE_DICTIONARY else {}
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
	Customs.clear_staged(SLOT)
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
		K.row("How to make a critter", "The part names, what each missing part costs, and how to save from your app.",
			K.button("Open the guide", "bq", "arrow", true, func(): OS.shell_open(GUIDE))),
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
	staged = KitImport.stage(path, plan if plan_set else "", assign)
	if staged.error == "" and not plan_set and staged.template == "" and staged.plan != plan:
		staged = KitImport.stage(path, plan, assign)
	if staged.error != "":
		return
	plan = staged.plan
	if not gait in KitData.PLANS[plan].gaits:
		gait = staged.gait
	staged.gait = gait
	KitImport.with_moved(staged, moved)
	_write_staging()


func _write_staging() -> void:
	# The staged kit into the staging folder, and the critter walking from it.
	preview = ""
	rig = {}
	Customs.clear_staged(SLOT)
	if not staged.missing.is_empty():
		return
	_clear_staging()
	staged["head_adj"] = head_adj
	if KitImport.write(staged, name if name != "" else "My critter", STAGING) == "":
		return
	var kit = JSON.parse_string(FileAccess.get_file_as_string(STAGING.path_join("kit.json")))
	if typeof(kit) != TYPE_DICTIONARY:
		return
	if not keep_head.is_empty():
		# Bring in a new version: the kept critter's head, as a nudge from the new measure.
		head_adj = KitImport.head_adj_between(staged.head_measured, keep_head)
		keep_head = {}
		staged["head_adj"] = head_adj
		kit["head"] = KitImport.adjusted_head(staged.head_measured, head_adj)
		_json(STAGING.path_join("kit.json"), kit)
	dy = 0.0   # grounding moves every pin and part alike
	for k in staged.pins:
		if kit.pins.has(k):
			dy = float(kit.pins[k][1]) - float(staged.pins[k][1])
			break
	rig = KitData.build(STAGING, kit)
	preview = Customs.show_staged(STAGING, SLOT)


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

	# The art with its joints, beside the critter walking (Kit.html).
	var top := K.hbox(20)
	top.add_child(_joints_card())
	top.add_child(_preview_card())
	body.add_child(K.card([K.margins(top, 20, 18, 20, 18)]))
	var checks := K.vbox(8)
	checks.add_child(UI.label("What it can do", 17, c.ink, 600, true))
	for line in check_lines(staged):
		var l := UI.label(line[1], 13, {"ok": c.ink_body, "need": c.dng_ink, "cost": c.ink2, "note": c.ink2}[line[0]], 700 if line[0] == "need" else 400)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 600
		checks.add_child(l)
	body.add_child(K.card([K.margins(checks, 20, 18, 20, 18)]))
	var named := name_rows()
	if not named.is_empty():
		body.add_child(K.section("Layers it didn't recognise", K.card(named)))

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
	if heads_on() and not rig.is_empty():
		body.add_child(_head_card())

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


# --- Joints (C4, P4) -----------------------------------------------------------------

const ART := Vector2(300, 260)     # px: the art and the preview, side by side at one size
const HEAD_PINS := ["eyes", "ear-l", "ear-r", "tuft", "mouth-open", "nose"]   # drawn on the head
const SIT_ONLY := ["neck-sit", "wing-l", "tuft"]
const WALK_ONLY := ["neck-walk", "hip-front", "hip-back", "hip"]
const PIN_PART := {"neck-walk": "head", "neck-sit": "head", "hip-front": "leg-front", "hip-back": "leg-back",
	"hip": "leg-near", "tail": "tail", "ear-l": "ear-l", "ear-r": "ear-r", "eyes": "eyes", "wing-l": "wing-l", "tuft": "tuft"}
var _view: Control                 # the preview's critter_view.gd
var view_mode := "walk"            # walk | sit | nap


func poses() -> Array:
	# The poses the joints can be shown in: faces-you and upright critters
	# have joints that only show sitting, or only walking.
	return ["walk", "sit"] if plan in ["front", "upright"] else ["walk"]


func _pose() -> String:
	return art_pose if art_pose in poses() else "walk"


func shown_pins() -> Array:
	# The plan's joints (pins_panel.gd) that have a part to turn, in this pose.
	if rig.is_empty():
		return []
	var pose := _pose()
	var out := []
	for p in Pins.PINS.get(plan, []):
		if not staged.parts.has(PIN_PART.get(p, "")):
			continue
		if poses().size() > 1 and ((pose == "walk" and p in SIT_ONLY) or (pose == "sit" and p in WALK_ONLY)):
			continue
		if p in HEAD_PINS and pose == "walk" and rig.get("two_faces", false):
			continue   # walking shows its side face, which has no such joint
		out.append(p)
	return out


func _shift(pin: String) -> Vector2:
	# From the file's frame to the art as shown: grounding, and a joint on
	# the head drawn where the head sits in this pose.
	var off := Vector2(0, dy)
	if pin in HEAD_PINS and rig.head_at.has(_pose()):
		off += rig.head_at[_pose()] - rig.head_pivot
	return off


func pin_shown_at(pin: String) -> Vector2:
	return KitImport.pin_now(staged, pin) + _shift(pin)


func pin_box_shown(pin: String) -> Rect2:
	var r := KitImport.pin_box(staged, pin)
	r.position += _shift(pin)
	return r


func clamp_shown(pin: String, u: Vector2) -> Vector2:
	return KitImport.clamp_pin(staged, pin, u - _shift(pin)) + _shift(pin)


func drag_pin(pin: String, u: Vector2) -> void:
	# A joint let go at u (on the art): kept in the staged kit, and the
	# critter beside it walks with it at once.
	KitImport.move_pin(staged, pin, u - _shift(pin))
	moved = staged.moved.duplicate(true)
	_write_staging()
	w.rebuild()


func reset_pins() -> void:
	moved = {}
	KitImport.with_moved(staged, moved)
	_write_staging()
	w.rebuild()


func art_parts() -> Array:
	# [ImageTexture, offset] for each part drawn in the shown pose, back to front.
	var out := []
	if rig.is_empty():
		return out
	for pair in KitData._placed(rig, _pose()):
		out.append([ImageTexture.create_from_image(pair[0]), pair[1]])
	return out


func _joints_card() -> Control:
	var c := K.c
	var v := K.vbox(8)
	var head := K.hbox(8)
	head.add_child(UI.label("Joints", 15, c.ink, 800))
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(g)
	if poses().size() > 1:
		head.add_child(K.seg(["Walking", "Sitting"], poses().find(_pose()), func(i):
			art_pose = poses()[i]
			w.rebuild()))
	v.add_child(head)
	var well := PanelContainer.new()
	well.custom_minimum_size = ART
	well.add_theme_stylebox_override("panel", K.box(c.ph_bg, 18, c.div, 2))
	if rig.is_empty():
		well.add_child(_centred("Its joints show once the needed parts are drawn."))
	else:
		well.add_child(JointsArt.new(self))
	v.add_child(well)
	v.add_child(UI.wrap("Drag a dot to move a joint. Legs swing from the hips and the head turns at the neck. Each stays near where it was drawn.", 12, c.ink2, ART.x))
	if not moved.is_empty():
		var b := K.button("Put the joints back", "bq", "", true, reset_pins)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(b)
	return v


func _preview_card() -> Control:
	var c := K.c
	var v := K.vbox(8)
	var head := K.hbox(8)
	head.add_child(UI.label("How it moves", 15, c.ink, 800))
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(g)
	head.add_child(K.seg(["Walk", "Sit", "Nap"], ["walk", "sit", "nap"].find(view_mode), func(i):
		view_mode = ["walk", "sit", "nap"][i]
		w.rebuild()))
	v.add_child(head)
	var well := PanelContainer.new()
	well.custom_minimum_size = ART
	well.add_theme_stylebox_override("panel", K.box(c.track, 18))
	_view = null
	if preview != "":
		_view = CritterView.make(preview, int(ART.x), int(ART.y) - 4, 1.1, "walk" if view_mode == "walk" else "sit", view_mode == "nap")
		well.add_child(_view)
	else:
		well.add_child(_centred("It can walk once the needed parts are drawn."))
	v.add_child(well)
	var moves := K.hbox(6)
	for m in [["Blink", "blink"], ["Look around", "look"]]:
		var mv: String = m[1]
		var b := K.button(m[0], "bs", "", true, func(): play(mv))
		b.disabled = _view == null
		moves.add_child(b)
	v.add_child(moves)
	return v


func play(move: String) -> void:
	if _view == null or _view.get("critter") == null:
		return
	var cr: Node2D = _view.critter
	if move == "blink":
		cr.blink_in = 0.0
	elif cr.can_do("sit_and_look"):
		cr.wake_up()
		cr.start_behaviour("sit_and_look", 2.4)


func _centred(text: String) -> Control:
	var l := UI.label(text, 14, K.c.ink2, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return K.margins(l, 16, 16, 16, 16)


class JointsArt extends Control:
	## The art as drawn in the shown pose, the joints as dots on it. A dot is
	## dragged within its box (drawn dashed while held) and kept on release.
	const VIEW := Rect2(0, 20, 300, 260)   # frame units shown (Kit.html's viewBox)
	var ks: RefCounted
	var parts := []
	var held := ""
	var at := Vector2.ZERO               # the held dot, in frame units

	func _init(screen: RefCounted) -> void:
		ks = screen
		parts = ks.art_parts()
		custom_minimum_size = ART
		mouse_filter = Control.MOUSE_FILTER_STOP

	func k() -> float:
		return custom_minimum_size.x / VIEW.size.x

	func to_px(u: Vector2) -> Vector2:
		return (u - VIEW.position) * k()

	func _draw() -> void:
		var c := K.c
		for pair in parts:
			draw_texture_rect(pair[0], Rect2(to_px(pair[1]), KitData.FRAME * k()), false)
		var font := UI.font(800)
		for p in ks.shown_pins():
			var pin: String = p
			var here: Vector2 = at if pin == held else ks.pin_shown_at(pin)
			var pt := to_px(here)
			if pin == held:
				var b: Rect2 = ks.pin_box_shown(pin)
				var q := PackedVector2Array([to_px(b.position), to_px(Vector2(b.end.x, b.position.y)), to_px(b.end), to_px(Vector2(b.position.x, b.end.y))])
				for i in 4:
					draw_dashed_line(q[i], q[(i + 1) % 4], c.acc_ink, 1.3, 4.0)
			var on: bool = pin == held or ks.moved.has(pin)
			draw_circle(pt, 7.0, c.acc_ink if on else c.knob)
			draw_circle(pt, 7.0, c.outline, false, 2.0)
			var label: String = Pins.pin_name(ks.plan, pin)[0]
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var tp := pt + Vector2(10, -10)
			draw_rect(Rect2(tp - Vector2(4, 12), Vector2(tw + 8, 16)), c.tip_bg)
			draw_string(font, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c.tip_ink)

	func pin_under(px: Vector2) -> String:
		var best := ""
		var bd := 14.0
		for p in ks.shown_pins():
			var d := to_px(ks.pin_shown_at(p)).distance_to(px)
			if d <= bd:
				bd = d
				best = p
		return best

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				held = pin_under(mb.position)
				if held != "":
					at = ks.pin_shown_at(held)
					accept_event()
					queue_redraw()
			elif held != "":
				var pin := held
				held = ""
				accept_event()
				if at.distance_to(ks.pin_shown_at(pin)) > 0.5:
					ks.drag_pin(pin, at)
				else:
					queue_redraw()
			return
		var mm := e as InputEventMouseMotion
		if mm == null:
			return
		if held != "":
			at = ks.clamp_shown(held, mm.position / k() + VIEW.position)
			accept_event()
			queue_redraw()
		else:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pin_under(mm.position) != "" else Control.CURSOR_ARROW


# --- Where's its head? (F1) ------------------------------------------------------------

const HATS := [["Beanie", "beanie"], ["Bow", "bow"], ["Glasses", "glasses"]]
const HEAD_ART := Vector2(220, 200)


static func heads_on() -> bool:
	# Clothes for homemade critters come with the share way (R4).
	return Customs.way_on("share")


func head_now() -> Dictionary:
	# The head clothes will sit on: the measure, with the player's adjustment.
	if not staged.has("head_measured"):
		return {}
	return KitImport.adjusted_head(staged.head_measured, head_adj)


func set_head(m: Dictionary) -> void:
	# Where's its head? let go: kept as a nudge from the measure, so a
	# redrawn head keeps it. Into kit.json "head" on Keep.
	head_adj = KitImport.head_adj_between(staged.head_measured, m)
	staged["head_adj"] = head_adj
	w.rebuild()


func fit_head() -> void:
	head_adj = {}
	staged["head_adj"] = head_adj
	w.rebuild()


func head_parts() -> Array:
	# The head as drawn (its own frame, where clothes are measured), ears behind.
	var out := []
	var imgs: Dictionary = rig.images
	for part in ["ear-r", "ear-l", "head", "eyes", "head-front"]:
		if imgs.has(part) and staged.parts.has(part):
			out.append(ImageTexture.create_from_image(imgs[part]))
	if not staged.parts.has("head") and imgs.has("body"):
		out.push_front(ImageTexture.create_from_image(imgs["body"]))   # a blob's head is its body
	return out


func _head_card() -> Control:
	var c := K.c
	var h := K.hbox(20)
	var well := PanelContainer.new()
	well.custom_minimum_size = HEAD_ART
	well.add_theme_stylebox_override("panel", K.box(c.ph_bg, 18, c.div, 2))
	well.add_child(HeadArt.new(self))
	h.add_child(well)
	var v := K.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := K.hbox(8)
	t.add_child(UI.label("Where's its head?", 17, c.ink, 600, true))
	t.add_child(K.pill("For clothes", c.track, c.acc_ink))
	v.add_child(t)
	v.add_child(UI.wrap("Hats and clothes sit on this circle, fitted to the head layer. Drag it to move it, and pull a handle to size it, until the hat looks right.", 13, c.ink2, 380))
	var row := K.hbox(10)
	row.add_child(UI.label("Try on", 13, c.ink2, 800))
	row.add_child(K.seg(HATS.map(func(x): return x[0]), maxi(0, HATS.map(func(x): return x[1]).find(hat)), func(i):
		hat = HATS[i][1]
		w.rebuild()))
	var again := K.button("Fit again", "bq", "", true, fit_head)
	again.disabled = head_adj.is_empty()
	row.add_child(again)
	v.add_child(row)
	h.add_child(v)
	return K.card([K.margins(h, 20, 18, 20, 18)])


class HeadArt extends Control:
	## The head with its clothes ellipse and the hat tried on. Drag inside to
	## move it; the handles on its right and bottom size it.
	var ks: RefCounted
	var parts := []
	var m := {}                     # the head now (frame units)
	var view := Rect2()             # frame units shown, fixed while the page is
	var hat_tex: Texture2D
	var hat_m := {}                 # the head the hat was drawn for
	var grab := ""                  # move | rx | ry
	var from := Vector2.ZERO
	var start := {}

	func _init(screen: RefCounted) -> void:
		ks = screen
		parts = ks.head_parts()
		m = ks.head_now()
		custom_minimum_size = HEAD_ART
		mouse_filter = Control.MOUSE_FILTER_STOP
		var meas: Dictionary = ks.staged.head_measured
		var side := maxf(float(meas.rx), float(meas.ry)) * 3.4
		view = Rect2(float(meas.cx) - side * 0.5, float(meas.cy) - side * 0.6, side, side * custom_minimum_size.y / custom_minimum_size.x)
		_hat()

	func _hat() -> void:
		hat_tex = null
		hat_m = m.duplicate()
		var svg: String = Wear.svg_for_kit(ks.hat, m)
		if svg == "":
			return
		var img := Image.new()
		if img.load_svg_from_string(svg, clampf(k(), 0.2, 2.0)) == OK:
			hat_tex = ImageTexture.create_from_image(img)

	func k() -> float:
		return custom_minimum_size.x / view.size.x

	func to_px(u: Vector2) -> Vector2:
		return (u - view.position) * k()

	func handles() -> Dictionary:
		return {"rx": to_px(Vector2(m.cx + m.rx, m.cy)), "ry": to_px(Vector2(m.cx, m.cy + m.ry))}

	func _draw() -> void:
		var c := K.c
		for t in parts:
			draw_texture_rect(t, Rect2(to_px(Vector2.ZERO), KitData.FRAME * k()), false)
		var centre := to_px(Vector2(m.cx, m.cy))
		var r := Vector2(m.rx, m.ry) * k()
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(centre + Vector2(cos(a) * r.x, sin(a) * r.y))
		for i in 48:
			if i % 2 == 0:
				draw_line(pts[i], pts[i + 1], c.btn, 2.5)
		if hat_tex != null:
			# Drawn for hat_m; while dragging it follows the head's move and size.
			var s := Vector2(float(m.rx) / float(hat_m.rx), float(m.ry) / float(hat_m.ry))
			var hc := Vector2(hat_m.cx, hat_m.cy)
			var tl := Vector2(m.cx, m.cy) + (Vector2(0, -120) - hc) * s
			draw_texture_rect(hat_tex, Rect2(to_px(tl), Vector2(300, 400) * s * k()), false)
		for hp in handles().values():
			draw_circle(hp, 6.0, c.knob)
			draw_circle(hp, 6.0, c.btn, false, 3.0)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab = ""
				var hs := handles()
				for h in hs:
					if (hs[h] as Vector2).distance_to(mb.position) <= 10.0:
						grab = h
				if grab == "":
					var d: Vector2 = (mb.position - to_px(Vector2(m.cx, m.cy))) / (Vector2(m.rx, m.ry) * k())
					if d.length() <= 1.15:
						grab = "move"
				if grab != "":
					from = mb.position
					start = m.duplicate()
					accept_event()
			elif grab != "":
				grab = ""
				accept_event()
				ks.set_head(m)
			return
		var mm := e as InputEventMouseMotion
		if mm == null or grab == "":
			return
		var du: Vector2 = (mm.position - from) / k()
		var want := start.duplicate()
		match grab:
			"move":
				want.cx = float(start.cx) + du.x
				want.cy = float(start.cy) + du.y
			"rx":
				want.rx = maxf(8.0, float(start.rx) + du.x)
			"ry":
				want.ry = maxf(8.0, float(start.ry) + du.y)
		var meas: Dictionary = ks.staged.head_measured
		m = KitImport.adjusted_head(meas, KitImport.head_adj_between(meas, want))   # within the adjustment's limits
		accept_event()
		queue_redraw()


func name_rows() -> Array:
	# A drop-down per layer not recognised: leave it out, or which part it is.
	var rows := []
	var pl: Dictionary = KitData.PLANS[plan]
	var open: Array = (pl.required + pl.optional).filter(func(p): return not staged.parts.has(p))
	for layer in staged.unmatched:
		var ln: String = layer
		var names := ["Leave it out"] + open.map(func(p): return str(PART_WORDS.get(p, p)).capitalize())
		rows.append(K.row(ln, "Which part is this layer?", K.dropdown(names, 0, func(i):
			if i > 0:
				assign[ln] = open[i - 1]
				reload("%s is now the %s." % [ln, PART_WORDS.get(open[i - 1], open[i - 1])]))))
	return rows


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
		out.append(["note", "Not recognised: %s. Say which part each is, below." % ", ".join(st.unmatched)])
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
	Customs.clear_staged(SLOT)
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
