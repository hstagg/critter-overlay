extends RefCounted
## Use a picture and Change picture, on My critters (gui/my_critters.gd;
## docs/sticker-critters-beta-plan.md): a file picker, then the picture with
## its background taken out, walking in a preview, with a name, which way it
## faces and a size. Nothing is saved until Keep (customs.gd does the work).
##
## my_critters.gd keeps one of these, so the half-made critter survives the
## page being rebuilt after each choice.

const Customs := preload("res://customs.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")
const CritterView := preload("res://gui/critter_view.gd")

const CUTS := [["As it is", -1], ["Gentle", 15], ["Normal", 30], ["Strong", 60]]   # flood-fill tolerance
const SIZES := [["Small", 0.8], ["Normal", 1.0], ["Big", 1.3]]
const PREVIEW_SIZE := Vector2i(220, 170)
const PREVIEW_SCALE := 1.4

var w: Window                      # settings_window.gd
var editing := ""                  # "" | "new" | the id of a kept critter being edited
var source: Image                  # the picked picture, fitted to 512 px
var picture: Image                 # source after the cut-out, as it would be kept
var cut := 2
var faces := "right"
var size_i := 1
var name := ""
var error := ""


func editor() -> Control:
	# The picture being made or changed, in a card, with any error above it.
	var c := K.c
	var rows := []
	if error != "":
		rows.append(K.margins(UI.label(error, 13, c.dng_ink, 700), 20, 14, 20, 0))
	rows.append(K.margins(_editor(c), 0, 12, 0, 0))
	return K.card(rows)


func _editor(c: Dictionary) -> Control:
	var h := K.hbox(18)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", K.box(c.track, 16))
	well.custom_minimum_size = Vector2(PREVIEW_SIZE)
	var view = CritterView.make(Customs.PREVIEW, PREVIEW_SIZE.x, PREVIEW_SIZE.y, PREVIEW_SCALE, "walk")
	if view.critter != null:
		# Walks to and fro inside the well.
		view.critter.world.left_x = PREVIEW_SIZE.x * 0.3 / PREVIEW_SCALE
		view.critter.world.right_x = PREVIEW_SIZE.x * 0.7 / PREVIEW_SCALE
	well.add_child(view)
	h.add_child(well)

	var form := K.vbox(10)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(K.text_field(name, "Its name", 40, func(t): name = t))
	if editing == "new":
		form.add_child(_choice("Background", K.seg(CUTS.map(func(x): return x[0]), cut, func(i):
			cut = i
			_refresh()), c))
	form.add_child(_choice("Faces", K.seg(["Left", "Right"], 1 if faces == "right" else 0, func(i):
		faces = "right" if i == 1 else "left"
		_refresh()), c))
	form.add_child(_choice("Size", K.seg(SIZES.map(func(x): return x[0]), size_i, func(i):
		size_i = i
		_refresh()), c))
	var buttons := K.hbox(10)
	buttons.add_child(K.button("Keep" if editing == "new" else "Save", "bp", "check", true, keep))
	buttons.add_child(K.button("Cancel", "bq", "", true, cancel))
	form.add_child(buttons)
	h.add_child(form)
	return K.margins(h, 20, 6, 20, 16)


func _choice(label: String, control: Control, c: Dictionary) -> Control:
	var r := K.hbox(12)
	var l := UI.label(label, 13, c.ink2, 700)
	l.custom_minimum_size.x = 86
	r.add_child(l)
	r.add_child(control)
	return r


# --- Actions ------------------------------------------------------------------

func pick() -> void:
	var fd := FileDialog.new()
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Pictures"])
	fd.title = "Pick a picture"
	fd.file_selected.connect(func(path):
		open_file(path)
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	w.add_child(fd)
	fd.popup_centered_ratio(0.6)


func open_file(path: String) -> void:
	# A picked (or, for the Admin page and tests, given) picture into the editor.
	error = Customs.check_file(path)
	var img: Image = Customs.load_picture(path) if error == "" else null
	if img == null:
		if error == "":
			error = "That picture can't be opened, or is over 4096 pixels a side."
		w.rebuild()
		return
	error = ""
	source = img
	cut = 0 if Customs.has_transparency(img) else 2
	faces = "right"
	size_i = 1
	name = path.get_file().get_basename().replace("_", " ").replace("-", " ").strip_edges().capitalize().left(40)
	editing = "new"
	_refresh()


func edit(id: String) -> void:
	var d: Dictionary = Customs.all[id]
	var img := Image.load_from_file(str(d["_dir"]).path_join("image.png"))
	if img == null or img.is_empty():
		return
	source = img
	cut = 0
	faces = str(d.get("faces", "right"))
	size_i = 0 if float(d.get("size", 1.0)) < 0.9 else (2 if float(d.get("size", 1.0)) > 1.15 else 1)
	name = str(d.get("name", ""))
	editing = id
	_refresh()


func _refresh() -> void:
	picture = source if CUTS[cut][1] < 0 else Customs.remove_background(source, CUTS[cut][1])
	picture = Customs.trim(picture)
	Customs.set_preview(picture, faces, SIZES[size_i][1])
	w.rebuild()


func keep() -> void:
	var n := name.strip_edges()
	if n == "":
		n = "My critter"
	if editing == "new":
		Customs.add(n, [picture], {"faces": faces, "size": SIZES[size_i][1]})
	elif Customs.all.has(editing):
		Customs.all[editing]["name"] = n
		Customs.all[editing]["faces"] = faces
		Customs.all[editing]["size"] = SIZES[size_i][1]
		Customs.save(editing)
	cancel()


func cancel() -> void:
	editing = ""
	source = null
	picture = null
	error = ""
	Customs.clear_preview()
	w.rebuild()
