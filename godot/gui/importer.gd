extends RefCounted
## Settings › System › Custom critters (docs/sticker-critters-beta-plan.md):
## the homemade critters, each with its own on/off, how often it visits, Edit
## and Delete; and Import a critter: a file picker, then the picture with its
## background taken out, walking in a preview, with a name, which way it
## faces and a size. Nothing is saved until Keep (customs.gd does the work).
##
## settings_pages.gd keeps one of these, so the half-made critter survives
## the page being rebuilt after each choice.

const Customs := preload("res://customs.gd")
const Settings := preload("res://settings.gd")
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


func section() -> Control:
	var c := K.c
	var rows := []
	var imp := K.button("Import a critter", "bs", "plus", true, pick)
	imp.disabled = editing != ""
	imp.add_theme_color_override("font_disabled_color", c.ink2)   # the default grey vanishes on light
	rows.append(K.row("Import a critter",
		"A PNG, JPG or WebP. One animal on a plain background works best, or a picture that is already cut out.", imp))
	if error != "":
		rows.append(K.margins(UI.label(error, 13, c.dng_ink, 700), 20, 0, 20, 12))
	if editing != "":
		rows.append(_editor(c))
	var ids := Customs.ids()
	ids.sort_custom(func(a, b): return int(Customs.all[a].get("made", 0)) < int(Customs.all[b].get("made", 0)))
	for id in ids:
		rows.append(_row(id, c))
	if ids.is_empty() and editing == "":
		rows.append(K.margins(UI.label("None yet. Critters you made in v2.0 come over by themselves.", 13, c.ink2, 400), 20, 0, 20, 14))
	return K.section("Custom critters", K.card(rows), "Beta")


func _row(id: String, c: Dictionary) -> Control:
	var d: Dictionary = Customs.all[id]
	var h := K.hbox(14)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", K.box(c.track, 12))
	well.custom_minimum_size = Vector2(72, 64)
	well.add_child(CritterView.make(id, 72, 64, 0.8, "sit", false, -1, [], true))
	h.add_child(well)
	var text := K.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UI.label(str(d.get("name", "Homemade critter")), 15, c.ink, 800)
	title.clip_text = true
	text.add_child(title)
	var count := int(d.get("seen", {}).get("count", 0))
	var from := "From v2.0" if str(d.get("from", "")).begins_with("v2:") else "Made here"
	text.add_child(UI.label("%s · %s" % [from, "not met yet" if count == 0 else "visited %d time%s" % [count, "" if count == 1 else "s"]], 13, c.ink2, 400))
	h.add_child(text)
	var visits := K.dropdown(Settings.VISIT_NAMES, clampi(int(d.get("visits", 1)), 0, 3), func(i):
		Customs.all[id]["visits"] = i
		Customs.save(id))
	visits.tooltip_text = "How often it visits"
	visits.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(visits)
	var on := K.toggle(bool(d.get("enabled", true)), "%s visits your desk" % d.get("name", ""), func(v):
		Customs.all[id]["enabled"] = v
		Customs.save(id))
	on.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(on)
	var edit := K.button("Edit", "bq", "", true, func(): _edit(id))
	edit.disabled = editing != ""
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(edit)
	var del := K.button("", "bd", "trash", true, func():
		w.confirm("Delete %s?" % d.get("name", "this critter"), "It stops visiting and its picture is deleted from this computer. This can't be undone.", "Delete", func():
			Customs.remove(id)
			w.rebuild()))
	del.tooltip_text = "Delete"
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(del)
	return K.margins(h, 20, 10, 20, 10)


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
	var field := LineEdit.new()
	field.text = name
	field.placeholder_text = "Its name"
	field.max_length = 40
	field.add_theme_font_override("font", UI.font(700))
	field.add_theme_font_size_override("font_size", 14)
	var fs := K.box(c.surface, 12, c.sec_line, 2)
	fs.content_margin_left = 12
	fs.content_margin_right = 12
	fs.content_margin_top = 8
	fs.content_margin_bottom = 8
	var ff := fs.duplicate()
	ff.border_color = c.acc_ink
	field.add_theme_stylebox_override("normal", fs)
	field.add_theme_stylebox_override("focus", ff)
	field.add_theme_color_override("font_color", c.ink)
	field.add_theme_color_override("font_placeholder_color", c.ink2)
	field.add_theme_color_override("caret_color", c.acc_ink)
	field.text_changed.connect(func(t): name = t)
	form.add_child(field)
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


func _edit(id: String) -> void:
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
