extends RefCounted
## Settings › My critters (docs/custom-critters-build-plan.md, A2), laid out
## as approved in A0 (design/studio/my-critters/): one grid of every
## homemade critter with filter chips by how it was made, one detail view for
## every kind, and the Make a critter chooser, which is the page itself while
## there are none.
##
## A way of making that is still behind its switch (Customs.way_on, plan P20)
## shows nothing to players. In the admin build, and with --studio, every way
## is on, and those not built yet open a placeholder.
##
## settings_pages.gd keeps one of these, so the view, the filter and a
## half-made picture (importer.gd) survive the page being rebuilt.

const Customs := preload("res://customs.gd")
const Settings := preload("res://settings.gd")
const Species := preload("res://species.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")
const CritterView := preload("res://gui/critter_view.gd")
const Importer := preload("res://gui/importer.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")
const Share := preload("res://share.gd")

# Each kind's words, everywhere (A0): badge, Edit button, the detail's line.
const WORDS := {
	"Shapes": ["Edit shapes", "Built from shapes"],
	"Drawn": ["Bring in a new version", "Drawn in your own app"],
	"Animated": ["Change frames", "An animation"],
	"Picture": ["Change picture", "Made from a picture"],
}
const BADGES := ["Shapes", "Drawn", "Animated", "Picture"]
const SIZES := [["Small", 0.8], ["Normal", 1.0], ["Big", 1.3]]
const SPEEDS := [0.5, 0.75, 1.0, 1.4, 2.0]
const SPEED_NAMES := ["snail", "slow", "average", "fast", "rapid"]
const CARD := Vector2(150, 196)
const NEW_FOR := 3 * 86400   # a critter is New for three days, until it visits

var w: Window                      # settings_window.gd
var view := "list"                 # list | make | detail
var filter := "All"                # All or a badge
var selected := ""                 # the critter the detail view shows
var sharing := false               # the detail view's Share card is open
var share_note := ""               # what the last Copy code or Save as a file did
var staged := {}                   # a critter from someone, before Install (share.gd stage_install)
const STAGING := "user://custom_staging"
var importer: RefCounted           # importer.gd
var kit_screen: RefCounted         # kit_screen.gd: Draw in your own app


func _init(win: Window) -> void:
	w = win
	importer = Importer.new()
	importer.w = win
	kit_screen = load("res://gui/kit_screen.gd").new(win, self)


static func badge(d: Dictionary) -> String:
	return Customs.badge(d)


static func count() -> int:
	return Customs.ids().size()


static func newest() -> String:
	# The most recently made critter, or "".
	var ids := Customs.ids()
	ids.sort_custom(func(a, b): return int(Customs.all[a].get("made", 0)) > int(Customs.all[b].get("made", 0)))
	return "" if ids.is_empty() else ids[0]


static func thumb_texture(id: String) -> Texture2D:
	var img := Image.load_from_file(Customs.thumb(id)) if FileAccess.file_exists(Customs.thumb(id)) else null
	return null if img == null or img.is_empty() else ImageTexture.create_from_image(img)


func open(which := "list", id := "") -> void:
	view = which
	selected = id
	w.go("my_critters")


func _go(which: String, id := "") -> void:
	view = which
	selected = id
	sharing = false
	share_note = ""
	w.rebuild(false)


func build(body: VBoxContainer, header: Callable) -> void:
	importer.w = w
	if importer.editing != "":
		var editing_new: bool = importer.editing == "new"
		header.call(body, "Use a picture" if editing_new else "Change picture",
			"Take the background out, give it a name and pick which way it faces. Nothing is kept until you press %s." % ("Keep" if editing_new else "Save"))
		body.add_child(importer.editor())
		return
	if kit_screen.active:
		kit_screen.build(body, header)
	elif view == "install" and not staged.is_empty():
		_install(body)
	elif view == "detail" and Customs.all.has(selected):
		_detail(body)
	elif view == "make" or count() == 0:
		_make(body, header, count() == 0)
	else:
		_grid(body, header)


# --- The grid -------------------------------------------------------------------

func _grid(body: VBoxContainer, header: Callable) -> void:
	var c := K.c
	header.call(body, "My critters", "Every critter you have made or been given. They visit your desk with everyone else.",
		K.button("Make a critter", "bp", "plus", true, func(): _go("make")))
	var ids := Customs.ids()
	ids.sort_custom(func(a, b): return int(Customs.all[a].get("made", 0)) > int(Customs.all[b].get("made", 0)))
	var counts := {}
	for id in ids:
		var b := badge(Customs.all[id])
		counts[b] = int(counts.get(b, 0)) + 1
	if filter != "All" and not counts.has(filter):
		filter = "All"
	if error_text() != "":
		body.add_child(UI.label(error_text(), 13, c.dng_ink, 700))
	if counts.size() > 1:
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_child(K.chip("All %d" % ids.size(), filter == "All", func():
			filter = "All"
			w.rebuild()))
		for b in BADGES:
			if counts.has(b):
				var bb: String = b
				chips.add_child(K.chip("%s %d" % [bb, counts[bb]], filter == bb, func():
					filter = bb
					w.rebuild()))
		body.add_child(chips)
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for id in ids:
		if filter == "All" or badge(Customs.all[id]) == filter:
			grid.add_child(_card(id))
	body.add_child(grid)


func error_text() -> String:
	return str(importer.error)


func _card(id: String) -> Control:
	var c := K.c
	var d: Dictionary = Customs.all[id]
	var on := bool(d.get("enabled", true))
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = str(d.get("name", "")) + ("" if on else ", off")
	var n := K.box(c.surface, 18, c.line, 2)
	var hv := K.box(c.surface, 18, c.outline, 2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 18, c.acc_ink, 2))
	b.pressed.connect(func(): _go("detail", id))
	var v := K.vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.custom_minimum_size = Vector2(CARD.x - 20, 104)
	well.add_theme_stylebox_override("panel", K.box(c.track, 14))
	var tex := thumb_texture(id)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(CARD.x - 36, 88)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(K.margins(pic, 8, 8, 8, 8))
	else:
		# No thumb.png yet (kits and frame critters until their importers'
		# screens write one): the critter itself, sitting.
		var view := CritterView.make(id, int(CARD.x - 20), 104, 0.55, "sit")
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(view)
	if not on:
		well.modulate.a = 0.45
	v.add_child(well)
	var name := UI.label(str(d.get("name", "Homemade critter")), 15, c.ink, 800)
	name.clip_text = true
	name.custom_minimum_size.x = CARD.x - 20
	v.add_child(name)
	var tags := HFlowContainer.new()
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_theme_constant_override("v_separation", 4)
	tags.add_child(K.pill(badge(d), c.track, c.acc_ink))
	if not on:
		tags.add_child(K.pill("Off", c.track, c.ink3))
	elif _is_new(d):
		tags.add_child(K.new_pill())
	v.add_child(tags)
	if str(d.get("from", "")) == "file" or bool(d.get("friend", false)):
		v.add_child(UI.label("From a friend", 12, c.ink3, 700))
	b.add_child(K.margins(v, 10, 10, 10, 10))
	return b


static func _is_new(d: Dictionary) -> bool:
	return int(d.get("seen", {}).get("count", 0)) == 0 \
		and int(Time.get_unix_time_from_system()) - int(d.get("made", 0)) < NEW_FOR


# --- One critter ----------------------------------------------------------------

func _detail(body: VBoxContainer) -> void:
	var c := K.c
	var id := selected
	var d: Dictionary = Customs.all[id]
	var name := str(d.get("name", "Homemade critter"))
	var b := badge(d)
	var back := K.button("My critters", "bq", "", true, func(): _go("list"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(back)

	var grid := K.hbox(28)
	var left := K.vbox(14)
	left.custom_minimum_size.x = 250
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(250, 250)
	well.add_theme_stylebox_override("panel", K.box(c.track, 20))
	well.add_child(CritterView.make(id, 250, 236, 1.2, "sit"))
	left.add_child(well)
	var names := K.vbox(2)
	var title := UI.label(name, 26, c.ink, 600, true)
	title.clip_text = true
	title.custom_minimum_size.x = 250
	names.add_child(title)
	names.add_child(UI.label(_made_line(d), 13, c.ink2, 400))
	left.add_child(names)
	var box := PanelContainer.new()
	var bs := K.box(c.ground, 16)
	bs.set_content_margin_all(12)
	bs.content_margin_left = 14
	bs.content_margin_right = 14
	box.add_theme_stylebox_override("panel", bs)
	var bv := K.vbox(10)
	box.add_child(bv)
	var r1 := K.hbox(8)
	var l1 := UI.label("Visits your desk", 14, c.ink, 800)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(l1)
	r1.add_child(K.toggle(bool(d.get("enabled", true)), "%s visits your desk" % name, func(on):
		_store(id, "enabled", on)
		w.rebuild()))
	bv.add_child(r1)
	var spawn := K.button("Spawn one now", "bs", "sparkle", true, func(): w.main.spawn_homemade(id))
	spawn.tooltip_text = "Free: your own critters don't cost berries."
	bv.add_child(spawn)
	left.add_child(box)
	grid.add_child(left)

	var right := K.vbox(0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(w.pages._block("How often it visits", "", K.seg(Settings.VISIT_NAMES, clampi(int(d.get("visits", 1)), 0, 3), func(i):
		_store(id, "visits", i)
		w.rebuild()), "How often it is picked when critters arrive."))
	var size_i := _nearest(SIZES.map(func(x): return x[1]), float(d.get("size", 1.0)))
	right.add_child(w.pages._block("Size", "", K.seg(SIZES.map(func(x): return x[0]), size_i, func(i):
		_store(id, "size", SIZES[i][1])
		w.rebuild())))
	var speed_i := _nearest(SPEEDS, float(d.get("speed", 1.0)))
	var speed_val := K.value_label(SPEED_NAMES[speed_i], 120)
	right.add_child(w.pages._block("Speed", "", K.stepped(SPEED_NAMES, speed_i, func(i):
		speed_val.text = SPEED_NAMES[i]
		_store(id, "speed", SPEEDS[i])), "", speed_val))
	var dresses := Customs.kind(d) == "kit" or (Customs.kind(d) == "frames" and FrameData.has_head(d.get("_clips", {})))
	right.add_child(w.pages._block("Pop sound", "", _sound_row(id), "Borrow a critter's sound, or add your own: a WAV or OGG, 2 seconds at most.",
		null, not dresses))
	if dresses:
		var shop := K.button("Open the Shop", "bs", "heart", true, func():
			w.selected_species = id
			w.go("shop"))
		shop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		right.add_child(w.pages._block("Clothes", "", shop, "Anything from the Shop that fits %s's head." % name, null, true))
	grid.add_child(right)

	var card := PanelContainer.new()
	var cs := K.box(c.surface, 20, c.line, 2)
	cs.content_margin_left = 20
	cs.content_margin_right = 24
	cs.content_margin_top = 20
	cs.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", cs)
	card.add_child(grid)
	body.add_child(card)

	var actions := K.hbox(10)
	actions.add_child(K.button(WORDS[b][0], "bp", "", true, func(): _edit(id)))
	if Customs.way_on("share"):
		actions.add_child(K.button("Share", "bs", "", true, func():
			sharing = not sharing
			share_note = ""
			w.rebuild()))
	actions.add_child(K.button("Make a copy", "bs", "", true, func():
		var nid := Customs.make_copy(id)
		if nid != "":
			_go("detail", nid)))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(gap)
	actions.add_child(K.button("Delete %s" % name.left(20), "bd", "trash", true, func():
		w.confirm("Delete %s?" % name, "It stops visiting and is deleted from this computer. This can't be undone.", "Delete", func():
			Customs.remove(id)
			_go("list"))))
	body.add_child(actions)
	if sharing and Customs.way_on("share"):
		body.add_child(_share_card(id))


static func _made_line(d: Dictionary) -> String:
	var from := str(d.get("from", ""))
	if from.begins_with("v2:"):
		return "Came over from v2.0"
	var when := ""
	var made := int(d.get("made", 0))
	if made > 0:
		var t := Time.get_date_dict_from_unix_time(made)
		when = " on %d %s" % [t.day, ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][t.month - 1]]
	if from == "file" or bool(d.get("friend", false)):
		return "From a friend, added" + when
	return WORDS[badge(d)][1] + when


static func _nearest(values: Array, x: float) -> int:
	var best := 0
	for i in values.size():
		if absf(float(values[i]) - x) < absf(float(values[best]) - x):
			best = i
	return best


static func _store(id: String, key: String, v) -> void:
	Customs.all[id][key] = v
	Customs.save(id)


func _sound_row(id: String) -> Control:
	var d: Dictionary = Customs.all[id]
	var h := K.hbox(10)
	var names := Customs.SOUNDS.map(func(s): return str(s).capitalize())
	var own := Customs.own_sound_path(d) != ""
	if own:
		names.append("Its own")
	var cur := str(d.get("sound", "kitten"))
	var sel := names.size() - 1 if cur == "own" and own else maxi(0, Customs.SOUNDS.find(cur))
	h.add_child(K.dropdown(names, sel, func(i):
		_store(id, "sound", "own" if i >= Customs.SOUNDS.size() else Customs.SOUNDS[i])
		w.main.preview_sound(id)))
	h.add_child(K.icon_button("play", "Play its sound", func(): w.main.preview_sound(id)))
	h.add_child(K.button("Add your own", "bq", "plus", true, func(): _pick_sound(id)))
	return h


func _pick_sound(id: String) -> void:
	var fd := FileDialog.new()
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.filters = PackedStringArray(["*.wav, *.ogg ; Sounds"])
	fd.title = "Pick a sound"
	fd.file_selected.connect(func(path):
		var why := Customs.set_sound(id, path)
		fd.queue_free()
		if why != "":
			w.confirm("That sound can't be used", why, "OK", func(): pass)
			return
		w.main.preview_sound(id)
		w.rebuild())
	fd.canceled.connect(fd.queue_free)
	w.add_child(fd)
	fd.popup_centered_ratio(0.6)


func _edit(id: String) -> void:
	if badge(Customs.all[id]) == "Picture":
		importer.edit(id)
	elif badge(Customs.all[id]) == "Drawn" and Customs.way_on("kit"):
		kit_screen.start(id)
	else:
		_later(WORDS[badge(Customs.all[id])][0])


func _later(what: String) -> void:
	# A way that is on (admin build or --studio) but whose screens aren't built.
	w.confirm(what, "%s comes in a later step of the Studio build. It shows here because every way is on in this build." % what, "OK", func(): pass)


# --- Sharing (G1, G2) -----------------------------------------------------------

func _share_card(id: String) -> Control:
	var c := K.c
	var d: Dictionary = Customs.all[id]
	var name := str(d.get("name", "it"))
	var rows := []
	var shapes_path := str(d["_dir"]).path_join("shapes.json")
	if FileAccess.file_exists(shapes_path):
		rows.append(K.row("Copy its code", "A short CRIT1- code anyone can paste into Make a critter. Send it however you like.",
			K.button("Copy code", "bs", "check", true, func(): _copy_code(id))))
	var desc := "A .critter file with everything %s is made of, to send to a friend." % name
	if Customs.kind(d) == "sticker":
		desc += " Made from a picture: only share pictures you're happy for others to have."   # decision 5
	rows.append(K.row("Save as a file", desc, K.button("Save as a file", "bs", "box", true, func(): _save_file(id))))
	if share_note != "":
		rows.append(K.margins(UI.label(share_note, 13, c.acc_ink, 700), 20, 10, 20, 14))
	return K.section("Share %s" % name, K.card(rows))


func _copy_code(id: String) -> void:
	var j = JSON.parse_string(FileAccess.get_file_as_string(str(Customs.all[id]["_dir"]).path_join("shapes.json")))
	if typeof(j) != TYPE_DICTIONARY:
		share_note = "Its shapes can't be read, so there's no code for it."
	else:
		DisplayServer.clipboard_set(Share.encode_code(j, str(Customs.all[id].get("name", ""))))
		share_note = "Copied. Paste it anywhere to send it."
	w.rebuild()


func _save_file(id: String) -> void:
	var fd := FileDialog.new()
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.filters = PackedStringArray(["*.critter ; Critter files"])
	fd.current_file = str(Customs.all[id].get("name", "critter")).strip_edges().replace("/", "-").replace("\\", "-") + ".critter"
	fd.title = "Save as a file"
	fd.file_selected.connect(func(path):
		fd.queue_free()
		var why := Share.export_critter(id, path, str(w.main.VERSION))
		share_note = why if why != "" else "Saved as %s." % path.get_file()
		w.rebuild())
	fd.canceled.connect(fd.queue_free)
	w.add_child(fd)
	fd.popup_centered_ratio(0.6)


# --- Dropping a file (C5) --------------------------------------------------------

static func route(path: String) -> String:
	# Which importer a dropped file goes to: picture, kit, frames, install,
	# or "" (with the way still off, or a kind nothing reads).
	var ext := path.get_extension().to_lower()
	var to := ""
	if DirAccess.dir_exists_absolute(path):
		# A folder of PNG layers, or of numbered frames (0.png, 1.png...).
		to = "frames" if FileAccess.file_exists(path.path_join("0.png")) else "kit"
	elif ext in Customs.EXTENSIONS:
		to = "picture"
	elif ext in ["svg", "zip", "ora"]:
		to = "kit"
	elif ext in ["gif", "apng", "json", "aseprite", "ase"]:
		to = "frames"
	elif ext == "critter":
		to = "install"
	var way: String = {"picture": "", "kit": "kit", "frames": "frames", "install": "share", "": "-"}[to]
	return to if way == "" or Customs.way_on(way) else ""


func drop(path: String) -> String:
	# Opens the importer for a dropped file; returns where it went.
	var to := route(path)
	match to:
		"picture":
			importer.open_file(path)
		"kit":
			kit_screen.start()
			kit_screen.open_file(path)
		"frames":
			_later("Bring an animation")
		"install":
			install_file(path)
		_:
			importer.error = "That kind of file can't be brought in. Use a picture, a drawing with layers or a .critter file."
			_go("list")
	return to


# --- A critter from someone (G1, G2; design/studio/import/Install.html) -----------

func install_file(path: String) -> void:
	# A .critter file into the install view; nothing is written to the store yet.
	staged = Share.stage_install(path, str(w.main.VERSION) if w.main != null else "0.0.0", STAGING)
	staged["file"] = path.get_file()
	staged["code"] = false
	_stage_preview()


func add_code(code: String) -> void:
	var back := Share.decode_code(code)
	staged = {"name": back.name, "meta": {}, "kind": "kit", "error": back.error, "warnings": back.warnings,
		"folder": "", "v2": false, "code": true, "file": ""}
	if back.error == "":
		Share.clear_dir(STAGING)
		staged.folder = Share.write_builder_kit(back.shapes, back.name if back.name != "" else "Shared critter", STAGING)
		if staged.folder == "":
			staged.error = "That code doesn't make a critter this app can draw."
	_stage_preview()


func _stage_preview() -> void:
	staged["preview"] = Customs.show_staged(staged.folder) if staged.error == "" and staged.folder != "" and not staged.v2 else ""
	view = "install"
	w.rebuild(false)


func _pick_critter_file() -> void:
	var fd := FileDialog.new()
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.filters = PackedStringArray(["*.critter ; Critter files"])
	fd.title = "Open a .critter file"
	fd.file_selected.connect(func(path):
		fd.queue_free()
		install_file(path))
	fd.canceled.connect(fd.queue_free)
	w.add_child(fd)
	fd.popup_centered_ratio(0.6)


static func taken_name(name: String) -> String:
	# "Noodle" if no critter has that name, else "Noodle 2", "Noodle 3"...
	var names := Customs.ids().map(func(i): return str(Customs.all[i].get("name", "")).to_lower())
	if not name.to_lower() in names:
		return name
	var n := 2
	while ("%s %d" % [name, n]).to_lower() in names:
		n += 1
	return "%s %d" % [name, n]


func _install(body: VBoxContainer) -> void:
	# The install view, drawn as a card on My critters (the design shows a
	# dialog; a view survives the page being rebuilt and works with drops).
	var c := K.c
	var st := staged
	var err := str(st.error)
	var name := str(st.name if st.name != "" else "Shared critter")
	var newer := err.contains("newer")
	var title := ""
	if newer:
		title = "%s needs a newer version" % name
	elif err != "":
		title = "This file can't be opened" if not st.code else "That code can't be used"
	else:
		title = ("Add %s?" if st.code else "Install %s?") % name
	var sub := ""
	if err != "":
		sub = err
	elif st.code:
		sub = "Someone sent you a critter code. Here's the critter it makes. Nothing is added until you press Add."
	elif st.kind == "sticker" or st.v2:
		sub = "Someone sent you a critter made from a picture. Nothing is added until you press Install."
	else:
		sub = "Someone sent you a critter. Here it is walking. Nothing is added until you press Install."
	var card := K.vbox(16)
	var t := UI.label(title, 24, c.ink, 600, true)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(t)
	var sl := UI.label(sub, 14, c.ink2, 400)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size.x = 420
	card.add_child(sl)
	if err != "":
		var after := "Nothing was added. Updates come through the System page, and your critters all stay." if newer \
			else "Nothing was added. If a code came with it, you can paste that into Make a critter instead."
		card.add_child(UI.label(after, 13, c.ink2, 700))
		var row := K.hbox(10)
		if newer:
			row.add_child(K.button("Check for updates", "bp", "update", true, func():
				_end_install()
				w.go("system")))
		row.add_child(K.button("OK", "bs", "", true, _end_install))
		card.add_child(row)
		body.add_child(K.card([K.margins(card, 28, 24, 28, 24)]))
		return
	var h := K.hbox(24)
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(240, 200)
	well.add_theme_stylebox_override("panel", K.box(c.track, 18))
	if str(st.get("preview", "")) != "":
		well.add_child(CritterView.make(st.preview, 240, 196, 1.0, "walk"))
	h.add_child(well)
	var info := K.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(name, 20, c.ink, 600, true))
	var word := "Picture" if st.v2 or st.kind == "sticker" else ("Shapes" if st.code else ("Animated" if st.kind == "frames" else "Drawn"))
	var bp := K.pill(word, c.track, c.acc_ink)
	bp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(bp)
	if st.code:
		info.add_child(UI.label("Codes don't say who made them.", 13, c.ink2, 400))
	else:
		var author := str(st.meta.get("author", ""))
		info.add_child(UI.label("Made by " + author if author != "" else "Who made it isn't said.", 13, c.ink2, 400))
		var lic := str(st.meta.get("licence", ""))
		info.add_child(UI.label(lic if lic != "" else "No licence given", 13, c.ink2, 400))
		if bool(st.meta.get("ai_made", false)):
			info.add_child(UI.label("Made with AI help", 13, c.ink2, 400))
	var moves := "Slides along" if word == "Picture" else ("Plays its own frames" if st.kind == "frames" else "Walks, sits and naps")
	info.add_child(UI.label(moves, 13, c.ink2, 700))
	h.add_child(info)
	card.add_child(h)
	var final_name := taken_name(name)
	if final_name != name:
		card.add_child(_note("You already have a %s" % name, "This one will be added next to it as %s. Yours stays as it is." % final_name))
	if word == "Picture":
		card.add_child(_note("Made from a picture", "It's someone's own picture, so only pass it on if they're happy for others to have it."))
	card.add_child(UI.label("Only install critters from people you trust.", 13, c.ink2, 700))
	var buttons := K.hbox(10)
	if st.code and Customs.way_on("shapes"):
		buttons.add_child(K.button("Edit in the Studio first", "bq", "", true, func(): _later("Edit in the Studio")))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	buttons.add_child(K.button("Cancel", "bs", "", true, _end_install))
	buttons.add_child(K.button("Add" if st.code else "Install", "bp", "check", true, func(): confirm_install()))
	card.add_child(buttons)
	body.add_child(K.card([K.margins(card, 28, 24, 28, 24)]))


func _note(title: String, text: String) -> Control:
	var c := K.c
	var v := K.vbox(4)
	v.add_child(UI.label(title, 14, c.ink, 800))
	var l := UI.label(text, 13, c.ink2, 400)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 400
	v.add_child(l)
	var p := PanelContainer.new()
	var s := K.box(c.ground, 14)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	p.add_child(v)
	return p


func confirm_install() -> String:
	# Writes the staged critter to the store under a free name. Returns its id.
	Customs.clear_staged()
	var name := taken_name(str(staged.name if staged.name != "" else "Shared critter"))
	if not staged.v2 and staged.folder != "":
		var cj: String = staged.folder.path_join("custom.json")
		var d = JSON.parse_string(FileAccess.get_file_as_string(cj))
		if typeof(d) == TYPE_DICTIONARY:
			d["name"] = name
			if staged.code:
				d["friend"] = true   # still from "shapes": a code is a builder critter
			var f := FileAccess.open(cj, FileAccess.WRITE)
			f.store_string(JSON.stringify(d, "\t"))
			f.close()
	var id := Share.install(staged)
	staged = {}
	_go("detail" if id != "" else "list", id)
	return id


func _end_install() -> void:
	Customs.clear_staged()
	Share.clear_dir(STAGING)
	staged = {}
	_go("list")


# --- Make a critter -------------------------------------------------------------

func _make(body: VBoxContainer, header: Callable, first: bool) -> void:
	var c := K.c
	if first:
		header.call(body, "My critters", "Make a critter of your own and it will visit your desk with everyone else. Pick by what you have.")
	else:
		var back := K.button("My critters", "bq", "", true, func(): _go("list"))
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(back)
		header.call(body, "Make a critter", "Pick by what you have. Every way ends the same: a critter that visits your desk with the rest.")
	if error_text() != "":
		body.add_child(UI.label(error_text(), 13, c.dng_ink, 700))
	if Customs.way_on("shapes"):
		body.add_child(_way_card("Build from shapes",
			"Put a critter together from circles, ovals, hearts and other shapes, right here. Pick its colours, eyes and how it walks.",
			["Walks, sits and naps", "Nothing to install"], "Start building", func(): _later("Build from shapes"), "No drawing app? Start here"))
	var ways := []
	if Customs.way_on("kit"):
		ways.append(["Draw in your own app", "Get a template, draw each body part on its own layer, then bring the file back.",
			["Procreate, Krita, Photoshop and more", "Walks, sits and naps"], "Get started", func(): kit_screen.start()])
	if Customs.way_on("frames"):
		ways.append(["Bring an animation", "A GIF, an animated PNG or a folder of frames. It plays exactly as you drew it.",
			["Plays your frames", "Pixel art welcome"], "Pick a file", func(): _later("Bring an animation")])
	ways.append(["Use a picture", "One picture of a critter, with the background taken out. It slides along as it is. The quickest way.",
		["PNG, JPG or WebP", "Slides along"], "Pick a picture", func():
			view = "list"   # once kept, the new critter shows in the grid
			importer.pick()])
	for x in ways:
		body.add_child(_way_card(x[0], x[1], x[2], x[3], x[4]))
	if Customs.way_on("share"):
		var code := [""]
		var row := K.hbox(10)
		var field := K.text_field("", "CRIT1-…", 4000, func(t): code[0] = t)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
		row.add_child(K.button("Add", "bs", "", true, func(): add_code(code[0])))
		body.add_child(K.section("Got one from someone?", K.card([
			K.row("Got a code?", "Paste a CRIT1- code someone sent you.", row),
			K.row("Got a file?", "A .critter file someone shared.", K.button("Open a .critter file", "bs", "box", true, _pick_critter_file)),
		])))


func _way_card(title: String, desc: String, tags: Array, button: String, on_press: Callable, kicker := "") -> Control:
	var c := K.c
	var v := K.vbox(8)
	if kicker != "":
		v.add_child(UI.label(kicker.to_upper(), 12, c.acc_ink, 500, true))
	var top := K.hbox(16)
	var text := K.vbox(6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, 20 if kicker != "" else 17, c.ink, 600, true))
	var dl := UI.label(desc, 13, c.ink2, 400)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = 300
	text.add_child(dl)
	var tr := HFlowContainer.new()
	tr.add_theme_constant_override("h_separation", 6)
	for t in tags:
		tr.add_child(K.pill(str(t), c.track, c.acc_ink))
	text.add_child(tr)
	top.add_child(text)
	var b := K.button(button, "bp" if kicker != "" or title == "Use a picture" else "bs", "", true, on_press)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(b)
	v.add_child(top)
	return K.card([K.margins(v, 20, 16, 20, 16)])
