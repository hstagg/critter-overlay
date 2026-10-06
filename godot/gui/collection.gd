extends VBoxContainer
## The Collection page of the Settings window (design: "Collection (Seen
## Log)" artboard): everyone you have met, by species and tier, and a diary of
## the rare ones. Each card shows the real critter, idling.

const Palette := preload("res://gui/palette.gd")
const Icons := preload("res://gui/icons.gd")
const UI := preload("res://gui/ui.gd")
const Species := preload("res://species.gd")

const TIERS := ["common", "uncommon", "rare", "epic", "legendary"]
const COLUMNS := 3
const CARD_W := 248
const WELL_H := 112

var economy: Node
var filter := "all"            # all | found | missing
var _dark := false
var _previews := []            # critters ticking in the cards
var cards := {}                # species -> its card
var focus := ""                # a species to outline (opened from a toast)


class Floor extends Node:
	## Just enough world for a critter that sits in a card.
	var floor_y := 0.0
	var left_x := -INF
	var right_x := INF
	func mouse_local() -> Vector2:
		return Vector2(-9999, -9999)


func _init() -> void:
	add_theme_constant_override("separation", 18)


func setup(e: Node) -> void:
	economy = e
	_dark = Palette.is_dark()
	_build()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for c in _previews:
		if is_instance_valid(c):
			c.tick(delta)


static func species_name(id: String) -> String:
	return "Golden kitten" if id == "golden" else id.capitalize()


func _built_species(special: bool) -> Array:
	var out := []
	for sp in Species.DATA:
		if bool(Species.row(sp).get("special", false)) == special:
			out.append(sp)
	return out


func _max_index(sp: String) -> int:
	return TIERS.find(Species.row(sp).get("rarity_max", "legendary"))


func _count(sp: String, tier: String) -> int:
	var k := "%s:%s" % [sp, tier]
	return int(economy.collection[k]["count"]) if economy.collection.has(k) else 0


# --- Building ------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_previews.clear()
	cards.clear()
	var c := Palette.colours(_dark)
	var col := self

	# Title and filter.
	var head := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 6)
	titles.add_child(UI.label("Collection", 32, c.ink, 600, true))
	titles.add_child(UI.label("Everyone you have met so far. Stay focused to meet the rare ones.", 15, c.ink2, 400))
	head.add_child(titles)
	head.add_child(_filter_bar(c))
	col.add_child(head)

	col.add_child(_progress(c))

	var regular := _built_species(false)
	col.add_child(UI.label("Critters", 19, c.ink, 600, true))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for sp in regular:
		var seen := _seen_total(sp)
		var complete := _found_tiers(sp) == _max_index(sp) + 1
		if filter == "found" and seen == 0:
			continue
		if filter == "missing" and complete:
			continue
		var card := _card(sp, c)
		cards[sp] = card
		grid.add_child(card)
	col.add_child(grid)

	var specials := _built_species(true)
	if not specials.is_empty():
		col.add_child(UI.label("Specials", 19, c.ink, 600, true))
		var sg := GridContainer.new()
		sg.columns = COLUMNS
		sg.add_theme_constant_override("h_separation", 14)
		for sp in specials:
			sg.add_child(_card(sp, c))
		col.add_child(sg)

	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	dh.add_child(UI.label("Sightings diary", 19, c.ink, 600, true))
	var hint := UI.label("Rare and better, newest first", 13, c.ink2, 600)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	dh.add_child(hint)
	col.add_child(dh)
	col.add_child(_diary(c))


func _filter_bar(c: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wrapper := PanelContainer.new()
	wrapper.add_theme_stylebox_override("panel", UI.box(c.track, 14, Color.TRANSPARENT, 0, 4))
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.add_child(row)
	for f in [["all", "All"], ["found", "Found"], ["missing", "Missing"]]:
		var b := Button.new()
		b.text = f[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(76, 32)
		var on: bool = filter == f[0]
		b.add_theme_stylebox_override("normal", UI.box(c.surface if on else Color.TRANSPARENT, 11, c.outline if on else Color.TRANSPARENT, 2 if on else 0))
		b.add_theme_stylebox_override("hover", UI.box(c.surface if on else c.div, 11, c.outline if on else Color.TRANSPARENT, 2 if on else 0))
		b.add_theme_stylebox_override("pressed", UI.box(c.surface, 11, c.outline, 2))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_override("font", UI.font(800))
		b.add_theme_font_size_override("font_size", 13)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, c.ink if on else c.ink2)
		var key: String = f[0]
		b.pressed.connect(func():
			filter = key
			_build())
		row.add_child(b)
	return wrapper


func _seen_total(sp: String) -> int:
	var n := 0
	for t in TIERS:
		n += _count(sp, t)
	return n


func _found_tiers(sp: String) -> int:
	var n := 0
	for i in _max_index(sp) + 1:
		if _count(sp, TIERS[i]) > 0:
			n += 1
	return n


func _progress(c: Dictionary) -> Control:
	var found := 0
	var total := 0
	var per := {}
	for t in TIERS:
		per[t] = [0, 0]
	for sp in Species.DATA:
		for i in _max_index(sp) + 1:
			total += 1
			per[TIERS[i]][1] += 1
			if _count(sp, TIERS[i]) > 0:
				found += 1
				per[TIERS[i]][0] += 1

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(c.surface, 20, c.line, 2, 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	card.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	left.add_child(UI.label("%d of %d found" % [found, total], 28, c.ink, 600, true))
	left.add_child(UI.bar(float(found) / maxf(total, 1), c.track, c.accent, 12))
	left.add_child(UI.label(_newest_line(), 13, c.ink2, 600))
	row.add_child(left)
	for t in TIERS:
		var tc := Palette.tier(t, _dark)
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 70
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 2)
		var b := UI.icon(Icons.badge(t, 26, tc.fill, c.badge_line))
		cell.add_child(b)
		var name := UI.label(t.capitalize(), 12, tc.ink, 800)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name)
		var n := UI.label("%d/%d" % per[t], 15, c.ink, 600, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(n)
		row.add_child(cell)
	return card


func _newest_line() -> String:
	if economy.sightings.is_empty():
		return "Nothing rare yet. Rare visitors get likelier the longer you stay focused."
	var s: Dictionary = economy.sightings[-1]
	return "Newest: %s %s %s, %s." % [_article(s.tier), s.tier.capitalize(), species_name(s.species).to_lower(), _when(int(s.t), true)]


static func _article(tier: String) -> String:
	return "an" if tier in ["uncommon", "epic"] else "a"


func _when(unix: int, lower := false) -> String:
	# "today at 14:02", "3 Oct, 21:18".
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	var now := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	var hm := "%02d:%02d" % [d.hour, d.minute]
	if d.year == now.year and d.month == now.month and d.day == now.day:
		return ("today at " if lower else "Today, ") + hm
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s, %s" % [d.day, months[d.month - 1], hm]


func _card(sp: String, c: Dictionary) -> Control:
	var seen := _seen_total(sp)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = CARD_W
	var cs := UI.box(c.surface, 18, c.outline if sp == focus else c.line, 3 if sp == focus else 2)
	card.add_theme_stylebox_override("panel", cs)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	# The well, with the critter idling in it (a silhouette until met).
	var well := PanelContainer.new()
	var ws := UI.box(Palette.species_tint(sp, _dark) if seen > 0 else c.ph_bg, 0)
	ws.corner_radius_top_left = 16
	ws.corner_radius_top_right = 16
	well.add_theme_stylebox_override("panel", ws)
	well.custom_minimum_size = Vector2(CARD_W - 4, WELL_H)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.custom_minimum_size = Vector2(CARD_W - 4, WELL_H)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(CARD_W - 4, WELL_H)
	view.add_child(vp)
	var floor := Floor.new()
	floor.floor_y = WELL_H - 8
	vp.add_child(floor)
	var critter = Species.row(sp)["script"].new()
	critter.idles = Species.row(sp)["idles"]
	vp.add_child(critter)
	critter.setup(floor, (CARD_W - 4) * 0.5, -1, "sit")
	critter.mode_left = INF
	if seen == 0:
		critter.modulate = Color(0, 0, 0, 0.18) if not _dark else Color(1, 1, 1, 0.2)
	_previews.append(critter)
	well.add_child(view)
	col.add_child(well)

	# Name, count, and a pip per tier.
	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 12)
	body.add_theme_constant_override("margin_top", 8)
	body.add_theme_constant_override("margin_bottom", 12)
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 8)
	body.add_child(bc)
	var nr := HBoxContainer.new()
	var nm := UI.label(species_name(sp) if seen > 0 else "Not yet met", 18, c.ink if seen > 0 else c.ink3, 600, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.add_child(nm)
	nr.add_child(UI.label("Seen %d" % seen, 12, c.ink2, 700))
	bc.add_child(nr)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 8)
	for i in TIERS.size():
		var t: String = TIERS[i]
		var tc := Palette.tier(t, _dark)
		var pip := VBoxContainer.new()
		pip.custom_minimum_size.x = 30
		pip.add_theme_constant_override("separation", 2)
		var under: Label
		if i > _max_index(sp):
			pip.add_child(UI.icon(Icons.line("lock", 18, c.dash)))
			pip.tooltip_text = "Not possible for this critter"
			under = UI.label("no", 11, c.ink3, 700)
		else:
			var n := _count(sp, t)
			if n == 0:
				pip.add_child(UI.icon(Icons.badge(t, 22, c.surface, c.dash, true)))
				under = UI.label("?", 11, c.ink3, 800)
			else:
				pip.add_child(UI.icon(Icons.badge(t, 22, tc.fill, c.badge_line)))
				under = UI.label("x%d" % n, 11, tc.ink, 800)
		under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pip.add_child(under)
		pips.add_child(pip)
	bc.add_child(pips)
	col.add_child(body)
	return card


func _diary(c: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(c.surface, 20, c.line, 2, 6))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	card.add_child(rows)
	if economy.sightings.is_empty():
		var empty := UI.label("No rare sightings yet. They will appear here, with the day and time.", 13, c.ink2, 600)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_top", 10)
		m.add_theme_constant_override("margin_bottom", 10)
		m.add_child(empty)
		rows.add_child(m)
		return card
	var seen_first := {}
	# First finds, oldest first, so the note marks the right sighting.
	for s in economy.sightings:
		var k := "%s:%s" % [s.species, s.tier]
		if not seen_first.has(k):
			seen_first[k] = s.t
	var list: Array = economy.sightings.duplicate()
	list.reverse()
	for i in mini(list.size(), 50):
		var s: Dictionary = list[i]
		var tc := Palette.tier(s.tier, _dark)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = 40
		row.add_child(UI.icon(Icons.badge(s.tier, 22, tc.fill, c.badge_line)))
		var nm := UI.label("%s %s" % [s.tier.capitalize(), species_name(s.species).to_lower()], 14, tc.ink, 800)
		nm.custom_minimum_size.x = 190
		row.add_child(nm)
		var first: bool = seen_first.get("%s:%s" % [s.species, s.tier], -1) == s.t
		var note := UI.label("First %s %s" % [s.tier.capitalize(), species_name(s.species).to_lower()] if first else "", 13, c.ink2, 600)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(note)
		row.add_child(UI.label(_when(int(s.t)), 13, c.ink2, 600))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 14)
		m.add_theme_constant_override("margin_right", 14)
		m.add_child(row)
		if i > 0:
			var sep := Panel.new()
			sep.custom_minimum_size.y = 2
			sep.add_theme_stylebox_override("panel", UI.box(c.div, 0))
			rows.add_child(sep)
		rows.add_child(m)
	return card
