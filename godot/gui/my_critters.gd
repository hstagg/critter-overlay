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
var importer: RefCounted           # importer.gd


func _init(win: Window) -> void:
	w = win
	importer = Importer.new()
	importer.w = win


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
	w.rebuild(false)


func build(body: VBoxContainer, header: Callable) -> void:
	importer.w = w
	if importer.editing != "":
		var editing_new: bool = importer.editing == "new"
		header.call(body, "Use a picture" if editing_new else "Change picture",
			"Take the background out, give it a name and pick which way it faces. Nothing is kept until you press %s." % ("Keep" if editing_new else "Save"))
		body.add_child(importer.editor())
		return
	if view == "detail" and Customs.all.has(selected):
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
	if str(d.get("from", "")) == "file":
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
	right.add_child(w.pages._block("Pop sound", "", _sound_row(id), "Borrow a critter's sound, or add your own: a WAV or OGG, 2 seconds at most.",
		null, Customs.kind(d) != "kit"))
	if Customs.kind(d) == "kit":
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
		actions.add_child(K.button("Share", "bs", "", true, func(): _later("Share")))
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


static func _made_line(d: Dictionary) -> String:
	var from := str(d.get("from", ""))
	if from.begins_with("v2:"):
		return "Came over from v2.0"
	var when := ""
	var made := int(d.get("made", 0))
	if made > 0:
		var t := Time.get_date_dict_from_unix_time(made)
		when = " on %d %s" % [t.day, ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][t.month - 1]]
	if from == "file":
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
	else:
		_later(WORDS[badge(Customs.all[id])][0])


func _later(what: String) -> void:
	# A way that is on (admin build or --studio) but whose screens aren't built.
	w.confirm(what, "%s comes in a later step of the Studio build. It shows here because every way is on in this build." % what, "OK", func(): pass)


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
			["Procreate, Krita, Photoshop and more", "Walks, sits and naps"], "Get started", func(): _later("Draw in your own app")])
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
		row.add_child(K.button("Add", "bs", "", true, func(): _later("Adding a code")))
		body.add_child(K.section("Got one from someone?", K.card([
			K.row("Got a code?", "Paste a CRIT1- code someone sent you.", row),
			K.row("Got a file?", "A .critter file someone shared.", K.button("Open a .critter file", "bs", "box", true, func(): _later("Opening a .critter file"))),
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
