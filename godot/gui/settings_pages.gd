extends RefCounted
## The seven pages of the Settings window, built to the design canvas
## (design/gui/pages1.py and pages2.py). Each control writes to settings.gd
## through set(); main.gd applies the change.

const Palette := preload("res://gui/palette.gd")
const Icons := preload("res://gui/icons.gd")
const UI := preload("res://gui/ui.gd")
const K := preload("res://gui/controls.gd")
const Species := preload("res://species.gd")
const Settings := preload("res://settings.gd")
const CritterView := preload("res://gui/critter_view.gd")
const Collection := preload("res://gui/collection.gd")
const Wear := preload("res://wear.gd")

const REPO := "https://github.com/hstagg/critter-overlay"
const TIER_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

var w: Window                      # settings_window.gd
var shortcut_note := ""
var update_note := ""


func _init(win: Window) -> void:
	w = win


func S():
	return w.main.settings


func set_value(key: String, v, rebuild := false) -> void:
	S().set_value(key, v)
	if rebuild:
		w.rebuild()


func build(page: String, body: VBoxContainer) -> void:
	match page:
		"home": _home(body)
		"critters": _critters(body)
		"focus": _focus(body)
		"world": _world(body)
		"sound": _sound(body)
		"collection": _collection(body)
		"shop": _shop(body)
		"system": _system(body)


func header(body: VBoxContainer, title: String, sub: String, right: Control = null) -> void:
	var c := K.c
	var h := K.hbox(20)
	var t := K.vbox(6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label(title, 32, c.ink, 600, true))
	var s := UI.label(sub, 15, c.ink2, 400)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 400
	t.add_child(s)
	h.add_child(t)
	if right != null:
		right.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(right)
	body.add_child(h)


static func mins_text(m: float) -> String:
	if m >= 60.0 and fmod(m, 60.0) == 0.0:
		return "1 hour" if m == 60.0 else "%d hours" % int(m / 60.0)
	return "%d min" % int(m)


func _slider_row(title: String, desc: String, key: String, lo: float, hi: float, step: float,
		fmt: Callable, lo_text := "", hi_text := "", width := 260, rebuild := false) -> Control:
	var val := K.value_label(fmt.call(float(S().value(key))))
	var sl := K.slider(float(S().value(key)), lo, hi, step, width, func(x):
		val.text = fmt.call(x)
		set_value(key, int(x) if step >= 1.0 else snappedf(x, step)))
	if rebuild:
		sl.drag_ended.connect(func(_changed): w.rebuild())
	return K.row(title, desc, K.slider_row_control(sl, lo_text, hi_text, val))


func _toggle_row(title: String, desc: String, key: String, pill: Control = null, rebuild := false) -> Control:
	return K.row(title, desc, K.toggle(bool(S().value(key)), title, func(on): set_value(key, on, rebuild)), "", pill)


# ============================================================ HOME

func _home(body: VBoxContainer) -> void:
	var c := K.c
	var hour: int = Time.get_datetime_dict_from_system().hour
	var greeting := "Good morning" if hour < 12 else ("Good afternoon" if hour < 18 else "Good evening")
	header(body, greeting, "Your critters have been gathering while you work.")
	var s: Dictionary = w.main.status()

	# Three numbers.
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 16)
	var focused := _stat("Focused for", "mug")
	w.live["h_focus"] = focused[1]
	var fb := UI.bar(0.0, c.track, c.accent, 8)
	w.live["h_focus_bar"] = fb
	focused[2].add_child(fb)
	var fn := UI.label("", 13, c.ink2, 400)
	w.live["h_focus_next"] = fn
	focused[2].add_child(fn)
	stats.add_child(focused[0])

	var desk := _stat("On your desk", "paw")
	w.live["h_out"] = desk[1]
	var heads := K.hbox(-6)
	heads.custom_minimum_size.y = 26
	for sp in s.species_out.slice(0, 6):
		var ring := PanelContainer.new()
		ring.add_theme_stylebox_override("panel", K.box(Palette.species_tint(sp, w.dark), 13, c.surface, 2))
		ring.add_child(CritterView.make(sp, 24, 24, 0.27))
		heads.add_child(ring)
	desk[2].add_child(heads)
	var room := UI.label("", 13, c.ink2, 400)
	w.live["h_room"] = room
	desk[2].add_child(room)
	stats.add_child(desk[0])

	var luck := _stat("Rare luck", "sparkle")
	w.live["h_luck"] = luck[1]
	var pips := K.hbox(4)
	for i in 5:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(0, 8)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.add_child(p)
	w.live["h_pips"] = pips
	luck[2].add_child(pips)
	luck[2].add_child(UI.label("Grows the longer you stay" if S().value("focus.luck") else "Off in Focus settings", 13, c.ink2, 400))
	stats.add_child(luck[0])
	for i in stats.get_child_count():
		stats.get_child(i).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stats)

	# The desk: who is out now, the real critters, napping if you are away.
	var scene_head := K.hbox(8)
	var st := UI.label("On your desk now", 16, c.ink, 800)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_head.add_child(st)
	scene_head.add_child(K.button("Spawn now", "bs", "sparkle", true, func():
		w.main.spawn_now()
		w.rebuild()))
	scene_head.add_child(K.button("Resume" if w.main.paused else "Pause", "bs", "play" if w.main.paused else "pause", true, func():
		w.main.toggle_pause()
		w.rebuild()))
	var scene := PanelContainer.new()
	scene.custom_minimum_size.y = 170
	scene.add_theme_stylebox_override("panel", K.box(Color("#DCE3EA") if not w.dark else Color("#2A2F38"), 16))
	var strip := K.hbox(18)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.size_flags_vertical = Control.SIZE_SHRINK_END
	if s.desk.is_empty():
		var none := UI.label("Nobody out yet. Keep working and someone will wander in.", 14, c.ink2, 700)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		strip.add_child(none)
	for d in s.desk.slice(0, 7):
		var cell := K.vbox(4)
		if d.tier != "common":
			var t := Palette.tier(d.tier, w.dark)
			var chip := UI.chip("%s %s" % [d.tier.capitalize(), d.species], t.ink, t.tint)
			chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(chip)
		else:
			cell.add_child(Control.new())
		cell.add_child(CritterView.make(d.species, 80, 96, 0.9, "sit", d.napping))
		cell.alignment = BoxContainer.ALIGNMENT_END
		strip.add_child(cell)
	scene.add_child(K.margins(strip, 12, 10, 12, 4))
	var sc := K.vbox(14)
	sc.add_child(scene_head)
	sc.add_child(scene)
	body.add_child(K.card([K.margins(sc, 20, 18, 20, 20)]))

	# Rare Hour and recent sightings.
	var bottom := GridContainer.new()
	bottom.columns = 2
	bottom.add_theme_constant_override("h_separation", 16)
	var rh := PanelContainer.new()
	var rs := K.box(c.rh_bg, 20, c.rh_line, 2)
	rs.set_content_margin_all(18)
	rh.add_theme_stylebox_override("panel", rs)
	var rr := K.hbox(16)
	var moon := PanelContainer.new()
	moon.custom_minimum_size = Vector2(64, 64)
	moon.add_theme_stylebox_override("panel", K.box(c.surface, 20, c.outline, 2))
	moon.add_child(UI.icon(Icons.line("moon", 30, c.rh_ink)))
	moon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rr.add_child(moon)
	var rt := K.vbox(3)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rh_title := UI.label("", 16, c.ink, 800)
	var rh_text := UI.label("", 13, c.rh_text, 400)
	rh_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rh_when := UI.label("", 20, c.rh_ink, 600, true)
	w.live["h_rh_title"] = rh_title
	w.live["h_rh_text"] = rh_text
	w.live["h_rh_when"] = rh_when
	rt.add_child(rh_title)
	rt.add_child(rh_text)
	rt.add_child(rh_when)
	rr.add_child(rt)
	rh.add_child(rr)
	rh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(rh)

	var recent := K.vbox(0)
	var rhd := K.hbox(8)
	var rl := UI.label("Recent sightings", 16, c.ink, 800)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rhd.add_child(rl)
	var open := LinkButton.new()
	open.text = "Open collection"
	open.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	open.add_theme_color_override("font_color", c.acc_ink)
	open.add_theme_color_override("font_hover_color", c.acc_ink_h)
	open.add_theme_font_override("font", UI.font(800))
	open.add_theme_font_size_override("font_size", 13)
	open.pressed.connect(func(): w.go("collection"))
	rhd.add_child(open)
	recent.add_child(K.margins(rhd, 0, 0, 0, 4))
	var sightings: Array = w.main.economy.sightings.duplicate()
	sightings.reverse()
	if sightings.is_empty():
		recent.add_child(K.margins(UI.label("Rare visitors will show up here.", 13, c.ink2, 600), 0, 9, 0, 9))
	for i in mini(3, sightings.size()):
		var sg: Dictionary = sightings[i]
		var t := Palette.tier(sg.tier, w.dark)
		if i > 0:
			recent.add_child(K.divider())
		var line := K.hbox(12)
		line.custom_minimum_size.y = 38
		line.add_child(UI.icon(Icons.badge(sg.tier, 22, t.fill, c.badge_line)))
		var nm := UI.label("%s %s" % [sg.tier.capitalize(), Collection.species_name(sg.species).to_lower()], 14, t.ink, 800)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nm)
		line.add_child(UI.label(_when(int(sg.t)), 13, c.ink2, 400))
		recent.add_child(line)
	var rc := K.card([K.margins(recent, 20, 14, 20, 12)])
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(rc)
	body.add_child(bottom)


func _stat(label: String, icon: String) -> Array:
	var c := K.c
	var v := K.vbox(10)
	var top := K.hbox(8)
	top.add_child(UI.icon(Icons.line(icon, 18, c.acc_ink)))
	top.add_child(UI.label(label, 13, c.ink2, 800))
	v.add_child(top)
	var big := UI.label("", 34, c.ink, 600, true)
	v.add_child(big)
	var foot := K.vbox(8)
	v.add_child(foot)
	return [K.card([K.margins(v, 20, 18, 20, 18)]), big, foot]


static func _when(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	var now := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + bias)
	var hm := "%02d:%02d" % [d.hour, d.minute]
	if d.year == now.year and d.month == now.month and d.day == now.day:
		return "Today, " + hm
	var y := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + bias - 86400)
	if d.year == y.year and d.month == y.month and d.day == y.day:
		return "Yesterday, " + hm
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s, %s" % [d.day, months[d.month - 1], hm]


func refresh(live: Dictionary, s: Dictionary) -> void:
	# The Home page's live numbers, once a second.
	var c := K.c
	if live.has("h_focus"):
		live.h_focus.text = w._mins(s.focus_min)
		live.h_focus_bar.value = s.next_progress
		live.h_focus_next.text = s.next_text
		live.h_out.text = "%d of %d" % [s.out, s.max_out]
		var room: int = s.max_out - s.out
		live.h_room.text = "The desk is full" if room <= 0 else ("Room for one more" if room == 1 else "Room for %s more" % _words(room))
		live.h_luck.text = "x%.1f" % s.luck
		var filled := int(round((s.luck - 1.0) / 2.0 * 5.0))
		for i in 5:
			live.h_pips.get_child(i).add_theme_stylebox_override("panel", K.box(Palette.tier("rare", w.dark).fill if i < filled else c.track, 4))
		var rh: Dictionary = s.rare_hour
		if not rh.enabled:
			live.h_rh_title.text = "Rare Hour is off"
			live.h_rh_text.text = "Turn it on in World."
			live.h_rh_when.text = ""
		elif rh.on:
			live.h_rh_title.text = "Rare Hour is on"
			live.h_rh_text.text = "Until %s. Rare and better are %s." % [rh.end, rh.how]
			live.h_rh_when.text = "Ends in %s" % w._mins(rh.ends_in_min)
		else:
			live.h_rh_title.text = "Rare Hour tonight" if rh.start_h >= 17 else "Rare Hour today"
			live.h_rh_text.text = "%s to %s. Rare and better are %s." % [rh.start, rh.end, rh.how]
			live.h_rh_when.text = "Starts in %s" % w._mins(rh.starts_in_min)


static func _words(n: int) -> String:
	var words := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return words[n] if n < words.size() else str(n)


# ============================================================ CRITTERS

func _critters(body: VBoxContainer) -> void:
	var c := K.c
	header(body, "Critters", "Choose who visits and how each one behaves.",
		K.button("Reset all critters", "bq", "reset", true, func():
			S().reset_all_species()
			w.rebuild()))

	body.add_child(K.section("Everyone", K.card([
		_slider_row("Size", "Applies to every critter.", "critters.size", 80, 200, 5, func(x): return "%d px" % int(x), "80 px", "200 px", 240),
		_slider_row("Opacity", "Lower it if they distract you.", "critters.opacity", 50, 100, 5, func(x): return "%d%%" % int(x), "50%", "100%", 240),
	])))

	# The picker strip.
	var strip := K.hbox(14)
	for sp in _built(false):
		strip.add_child(_tile(sp))
	var specials := _built(true)
	if not specials.is_empty():
		var sep := Panel.new()
		sep.custom_minimum_size = Vector2(2, 60)
		sep.add_theme_stylebox_override("panel", K.box(c.line, 0))
		strip.add_child(sep)
		for sp in specials:
			strip.add_child(_tile(sp))
	strip.add_child(_your_own_tile())
	var choose := K.vbox(14)
	choose.add_child(K.card([K.margins(strip, 18, 16, 18, 12)]))
	choose.add_child(_species_detail(w.selected_species))
	body.add_child(K.section("Choose a critter", choose))


func _built(special: bool) -> Array:
	var out := []
	for sp in Species.DATA:
		if bool(Species.row(sp).get("special", false)) == special:
			out.append(sp)
	return out


func _tile(sp: String) -> Control:
	var c := K.c
	var on: bool = S().sp(sp, "enabled")
	var sel: bool = sp == w.selected_species
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(76, 96)
	b.tooltip_text = Collection.species_name(sp) + ("" if on else ", off")
	b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 12, c.acc_ink, 2))
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	var v := K.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(58, 58)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override("panel", K.box(Palette.species_tint(sp, w.dark), 29,
		c.outline if sel else c.chip_line, 3 if sel else 2, c.lip, 2 if sel else 0))
	well.add_child(CritterView.make(sp, 54, 54, 0.6))
	v.add_child(well)
	var name := UI.label(Collection.species_name(sp), 12, c.ink, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	if not on:
		var off := UI.label("Off", 11, c.ink3, 700)
		off.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(off)
		well.modulate.a = 0.45
	b.add_child(v)
	b.pressed.connect(func():
		w.selected_species = sp
		w.rebuild())
	return b


func _your_own_tile() -> Control:
	var c := K.c
	var v := K.vbox(6)
	v.custom_minimum_size.x = 76
	v.tooltip_text = "Your own critters, coming soon"
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(58, 58)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.add_theme_stylebox_override("panel", K.box(c.ph_bg, 29, c.dash, 2))
	var plus := UI.icon(Icons.line("plus", 24, c.ph_ink))
	well.add_child(plus)
	v.add_child(well)
	var name := UI.label("Your own", 12, c.ink3, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	var p := K.pill("Soon", c.track, c.acc_ink)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(p)
	return v


func _species_detail(sp: String) -> Control:
	var c := K.c
	var row: Dictionary = S().species(sp)
	var name := Collection.species_name(sp)
	var grid := K.hbox(28)

	var left := K.vbox(14)
	left.custom_minimum_size.x = 250
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(250, 250)
	well.add_theme_stylebox_override("panel", K.box(Palette.species_tint(sp, w.dark), 20))
	well.add_child(CritterView.make(sp, 250, 236, 1.7))
	left.add_child(well)
	var names := K.vbox(2)
	names.add_child(UI.label(name, 26, c.ink, 600, true))
	names.add_child(UI.label("Walks with %s" % Species.row(sp).get("gait", "its own gait"), 13, c.ink2, 400))
	left.add_child(names)
	var box := PanelContainer.new()
	var bs := K.box(c.ground, 16)
	bs.content_margin_left = 14
	bs.content_margin_right = 14
	bs.content_margin_top = 12
	bs.content_margin_bottom = 12
	box.add_theme_stylebox_override("panel", bs)
	var bv := K.vbox(10)
	box.add_child(bv)
	var r1 := K.hbox(8)
	var l1 := UI.label("Visits your desk", 14, c.ink, 800)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(l1)
	r1.add_child(K.toggle(row.enabled, "%s visits your desk" % name, func(on): set_value("species.%s.enabled" % sp, on, true)))
	bv.add_child(r1)
	var r2 := K.hbox(8)
	var l2 := UI.label("Pop sound", 14, c.ink, 800)
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(l2)
	r2.add_child(K.icon_button("play", "Play %s sound" % name.to_lower(), func(): w.main.preview_sound(sp)))
	r2.add_child(K.toggle(row.sound, "%s pop sound" % name, func(on): set_value("species.%s.sound" % sp, on)))
	bv.add_child(r2)
	left.add_child(box)
	var reset := K.button("Reset %s" % name.to_lower(), "bq", "reset", true, func():
		S().reset_species(sp)
		w.rebuild())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(reset)
	grid.add_child(left)

	var right := K.vbox(0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_block("How often it visits", "", K.seg(Settings.VISIT_NAMES, int(row.visits), func(i): set_value("species.%s.visits" % sp, i, true)),
		"How often this species is picked when critters arrive."))
	var speed_val := K.value_label(Settings.SPEED_NAMES[int(row.speed)], 120)
	right.add_child(_block("Speed", "", K.stepped(Settings.SPEED_NAMES, int(row.speed), func(i):
		speed_val.text = Settings.SPEED_NAMES[i]
		set_value("species.%s.speed" % sp, i)), "", speed_val))
	var act_val := K.value_label(Settings.ACTIVITY_NAMES[int(row.activity)], 120)
	right.add_child(_block("Activity", "", K.stepped(Settings.ACTIVITY_NAMES, int(row.activity), func(i):
		act_val.text = Settings.ACTIVITY_NAMES[i]
		set_value("species.%s.activity" % sp, i)),
		"How often this critter stops to groom, stretch or nap. Wired hardly stops. Narcoleptic naps all the time.", act_val))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for tr in Settings.TRAILS:
		var trail: String = tr
		chips.add_child(K.chip(trail.capitalize(), row.trail == trail, func(): set_value("species.%s.trail" % sp, trail, true)))
	right.add_child(_block("Trail", "", chips, "Only shows when rarity tiers are on."))
	# Can appear as: from and to, within the species' own cap.
	var cap := Settings.TIERS.find(Species.row(sp).get("rarity_max", "legendary"))
	var tiers := Settings.TIERS.slice(0, cap + 1)
	var icons := []
	for t in tiers:
		icons.append(Icons.badge(t, 18, Palette.tier(t, w.dark).fill, c.badge_line))
	var names_t := []
	for t in tiers:
		names_t.append(t.capitalize())
	var lo := maxi(0, tiers.find(row.tier_min))
	var hi := tiers.find(row.tier_max)
	if hi < 0:
		hi = tiers.size() - 1
	var rng := K.hbox(10)
	rng.add_child(UI.label("From", 14, c.ink2, 700))
	rng.add_child(K.dropdown(names_t, lo, func(i):
		set_value("species.%s.tier_min" % sp, tiers[i])
		if i > tiers.find(S().sp(sp, "tier_max")):
			set_value("species.%s.tier_max" % sp, tiers[i], true), icons))
	rng.add_child(UI.label("to", 14, c.ink2, 700))
	rng.add_child(K.dropdown(names_t, hi, func(i):
		set_value("species.%s.tier_max" % sp, tiers[i])
		if i < tiers.find(S().sp(sp, "tier_min")):
			set_value("species.%s.tier_min" % sp, tiers[i], true), icons))
	var tip := "Limit the rarity tiers this critter can roll."
	if cap < 4:
		tip += " %ss stop at %s." % [name, tiers[-1].capitalize()]
	right.add_child(_block("Can appear as", "", rng, tip, null, true))
	grid.add_child(right)

	var card := PanelContainer.new()
	var cs := K.box(c.surface, 20, c.line, 2)
	cs.content_margin_left = 20
	cs.content_margin_right = 24
	cs.content_margin_top = 20
	cs.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", cs)
	card.add_child(grid)
	return card


func _block(title: String, _value: String, ctl: Control, tip := "", value_label: Control = null, last := false) -> Control:
	var c := K.c
	var v := K.vbox(10)
	var top := K.hbox(6)
	var t := UI.label(title, 15, c.ink, 800)
	top.add_child(t)
	if tip != "":
		top.add_child(K.info(tip))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	if value_label != null:
		top.add_child(value_label)
	v.add_child(top)
	ctl.size_flags_horizontal = Control.SIZE_FILL
	v.add_child(ctl)
	var out := K.vbox(0)
	out.add_child(K.margins(v, 0, 14, 0, 14))
	if not last:
		out.add_child(K.divider())
	return out


# ============================================================ FOCUS

func _focus(body: VBoxContainer) -> void:
	var c := K.c
	header(body, "Focus", "Critters gather while you work and curl up for a nap when you step away.")
	var every := int(S().value("focus.gather_every_min"))
	var most := int(S().value("focus.max_out"))
	var nap := int(S().value("focus.nap_after_min"))
	var timer: bool = S().value("focus.mode") == "timer"

	# The explainer: the three steps.
	var steps := K.hbox(14)
	var sp: Array = _built(false)
	var a: String = sp[0]
	var b: String = sp[1 % sp.size()]
	var d: String = sp[2 % sp.size()]
	var first_line := ("Critters gather. One more every %s, up to %d." % [mins_text(every), most]) if not timer \
		else ("A group arrives every %s." % mins_text(int(S().value("focus.timer_every_min"))))
	steps.add_child(_step("While you work", first_line, [[b, 0.62], [a, 0.72], [d, 0.6]], Palette.species_tint("kitten", w.dark)))
	steps.add_child(_arrow())
	steps.add_child(_step("When you step away", "After %s quiet they curl up and nap." % ("a minute" if nap == 1 else "%d minutes" % nap), [[a, 0.74, true]], Palette.species_tint("otter", w.dark)))
	steps.add_child(_arrow())
	steps.add_child(_step("When you come back", "They wake with a stretch and carry on. Your luck keeps building.", [[a, 0.72], [b, 0.66]], Palette.species_tint("turtle", w.dark)))
	body.add_child(K.card([K.margins(steps, 20, 20, 20, 20)]))

	var mode_row := K.row("How critters arrive", "Gathering follows your focus. The timer brings a group every few minutes, whatever you are doing.",
		K.seg(["Gather while I work", "On a timer"], 1 if timer else 0, func(i): set_value("focus.mode", "timer" if i == 1 else "gather", true)))
	var start: int = S().value("focus.start_with")
	var start_row := K.row("Start with", "How many come out when you sit down.", K.stepper("%d critter%s" % [start, "" if start == 1 else "s"],
		func(): set_value("focus.start_with", maxi(0, start - 1), true),
		func(): set_value("focus.start_with", mini(most, start + 1), true)))
	body.add_child(K.section("While you work", K.card([
		mode_row,
		start_row,
		_slider_row("One more every", "", "focus.gather_every_min", 1, 30, 1, func(x): return mins_text(x), "1 min", "30 min", 260, true),
		_slider_row("At most", "The desk never gets busier than this.", "focus.max_out", 1, 25, 1, func(x): return "%d critter%s" % [int(x), "" if int(x) == 1 else "s"], "1", "25", 260, true),
		_toggle_row("Rarer the longer you stay", "Each focused stretch nudges up the odds of Rare and better. Resets after a long break.", "focus.luck"),
		_toggle_row("Pause in full-screen apps", "Hide critters during games, films and presentations.", "focus.pause_fullscreen", K.new_pill()),
	])))

	var tidy: int = S().value("focus.tidy_after_min")
	var tidy_opts := [0, 30, 60, 120]
	var privacy := PanelContainer.new()
	var ps := K.box(c.ground, 0)
	ps.corner_radius_bottom_left = 18
	ps.corner_radius_bottom_right = 18
	ps.content_margin_left = 20
	ps.content_margin_right = 20
	ps.content_margin_top = 12
	ps.content_margin_bottom = 12
	privacy.add_theme_stylebox_override("panel", ps)
	var pr := K.hbox(10)
	pr.add_child(UI.icon(Icons.line("lock", 18, c.outline)))
	pr.add_child(UI.label("Only the time since your last input is checked. Nothing you type or click is recorded.", 13, c.ink2, 400))
	privacy.add_child(pr)
	body.add_child(K.section("When you step away", K.card([
		_slider_row("Nap after", "Counts from your last key press or mouse movement.", "focus.nap_after_min", 1, 30, 1, func(x): return mins_text(x), "1 min", "30 min", 260, true),
		K.row("Tidy up after a long break", "Critters head home if you are gone a long time, and gather again when you return.",
			K.seg(["Never", "30 min", "1 hour", "2 hours"], maxi(0, tidy_opts.find(tidy)), func(i): set_value("focus.tidy_after_min", tidy_opts[i], true)), "", K.new_pill()),
		privacy,
	])))

	var timer_card := K.card([
		_slider_row("New group every", "", "focus.timer_every_min", 1, 60, 1, func(x): return mins_text(x), "1 min", "60 min", 260, true),
		_slider_row("Smallest group", "", "focus.timer_min", 1, 15, 1, func(x): return str(int(x)), "1", "15", 260),
		_slider_row("Largest group", "", "focus.timer_max", 1, 25, 1, func(x): return str(int(x)), "1", "25", 260),
	])
	if not timer:
		timer_card.modulate.a = 0.55
	body.add_child(K.section("Timer arrivals", timer_card, "Used when critters arrive on a timer"))

	body.add_child(K.section("Solo walkers", K.card([
		_toggle_row("Solo walkers", "Now and then a lone critter strolls along the edge of your screen.", "focus.solo"),
		_slider_row("One every", "", "focus.solo_every_min", 1, 60, 1, func(x): return mins_text(x), "1 min", "60 min"),
	])))


func _step(title: String, text: String, critters: Array, tint: Color) -> Control:
	var c := K.c
	var v := K.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art := PanelContainer.new()
	art.custom_minimum_size.y = 108
	art.add_theme_stylebox_override("panel", K.box(tint, 16))
	var row := K.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for cr in critters:
		var asleep: bool = cr.size() > 2 and cr[2]
		row.add_child(CritterView.make(cr[0], int(90 * cr[1]), 100, cr[1], "loaf" if asleep else "sit", asleep))
	art.add_child(row)
	v.add_child(art)
	v.add_child(UI.label(title, 15, c.ink, 800))
	var t := UI.label(text, 13, c.ink2, 400)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 150
	v.add_child(t)
	return v


func _arrow() -> Control:
	var a := UI.icon(Icons.line("arrow", 24, K.c.off_line))
	a.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return K.margins(a, 0, 44, 0, 0)


# ============================================================ WORLD

func _world(body: VBoxContainer) -> void:
	var c := K.c
	header(body, "World", "How the living world behaves, and how rare things get.")
	body.add_child(K.section("Living world", K.card([
		_toggle_row("Day and night pacing", "Livelier in the morning, sleepier late at night. Only their pace changes, never the colours.", "world.day_night"),
		_slider_row("Behaviour frequency", "How often they stop to groom, stretch, play or nap.", "world.behaviour_freq", 0.3, 2.0, 0.1, func(x): return "%.1fx" % x, "Calm", "Lively"),
		_toggle_row("Pair interactions", "Two critters close together may sniff, follow, play or groom.", "world.pairs"),
	])))

	# Rarity, with the odds.
	var odds := K.vbox(0)
	var oh := K.hbox(6)
	oh.add_child(UI.label("Odds", 15, c.ink, 800))
	oh.add_child(K.info("These are relative weights, so they do not need to add up to 100."))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oh.add_child(sp)
	oh.add_child(K.button("Reset odds", "bq", "reset", true, func():
		set_value("world.odds", Settings.DEFAULTS.world.odds.duplicate(), true)))
	odds.add_child(K.margins(oh, 0, 0, 0, 4))
	var w_odds: Dictionary = S().value("world.odds")
	var fr: Dictionary = S().odds()
	for i in Settings.TIERS.size():
		odds.add_child(_odds_row(Settings.TIERS[i], float(w_odds.get(Settings.TIERS[i], 0.0)), fr[Settings.TIERS[i]]))
	var foot := UI.label("Relative weights, so they do not need to add up to 100. The scale stretches at the low end so tiny odds are easy to set.", 12, c.ink2, 400)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	odds.add_child(K.margins(foot, 0, 4, 0, 0))
	var notes_opts := ["off", "rare", "epic", "legendary"]
	body.add_child(K.section("Rarity", K.card([
		_toggle_row("Rarity tiers", "Each critter rolls a tier when it arrives. Rarer ones glow softly and leave a trail.", "world.rarity"),
		K.margins(odds, 20, 14, 20, 16),
		_toggle_row("First arrival of the day", "The first critter after midnight is always Rare or better.", "world.first_bonus"),
		K.row("Rare sighting notes", "A small note in the corner when someone special arrives.",
			K.seg(["Off", "Rare and up", "Epic and up", "Legendary"], maxi(0, notes_opts.find(S().value("world.notes"))),
				func(i): set_value("world.notes", notes_opts[i], true))),
	])))

	# Rare Hour.
	var band := PanelContainer.new()
	var bs := K.box(c.rh_bg, 0)
	bs.corner_radius_top_left = 18
	bs.corner_radius_top_right = 18
	bs.set_content_margin_all(18)
	band.add_theme_stylebox_override("panel", bs)
	var br := K.hbox(16)
	var moon := PanelContainer.new()
	moon.custom_minimum_size = Vector2(56, 56)
	moon.add_theme_stylebox_override("panel", K.box(c.surface, 18, c.outline, 2))
	moon.add_child(UI.icon(Icons.line("moon", 28, c.rh_ink)))
	br.add_child(moon)
	var bt := K.vbox(3)
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.add_child(UI.label("Rare Hour", 16, c.ink, 800))
	bt.add_child(UI.label("Once a day, Rare and better become more likely for a while.", 13, c.rh_text, 400))
	br.add_child(bt)
	var tg := K.toggle(bool(S().value("world.rare_hour")), "Rare Hour", func(on): set_value("world.rare_hour", on))
	tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(tg)
	band.add_child(br)
	var hours := []
	for h in 24:
		hours.append("%02d:00" % h)
	var starts := K.dropdown(hours, int(S().value("world.rare_hour_start")), func(i): set_value("world.rare_hour_start", i),
		hours.map(func(_h): return Icons.line("clock", 18, c.acc_ink)))
	starts.custom_minimum_size.x = 120
	var lens := [30, 60, 120]
	var boosts := [1.5, 2.0, 3.0]
	body.add_child(K.section("Rare Hour", K.card([
		band,
		K.row("Starts at", "Your local time.", starts),
		K.row("Lasts", "", K.seg(["30 min", "1 hour", "2 hours"], maxi(0, lens.find(int(S().value("world.rare_hour_min")))),
			func(i): set_value("world.rare_hour_min", lens[i], true))),
		K.row("Boost", "How much likelier Rare and better become.", K.seg(["x1.5", "x2", "x3"], maxi(0, boosts.find(float(S().value("world.rare_hour_boost")))),
			func(i): set_value("world.rare_hour_boost", boosts[i], true))),
	])))


const ODDS_POWER := 2.5            # the odds sliders stretch the low end


func _odds_row(tier: String, weight: float, frac: float) -> Control:
	var c := K.c
	var t := Palette.tier(tier, w.dark)
	var h := K.hbox(16)
	h.custom_minimum_size.y = 40
	var name := K.hbox(10)
	name.custom_minimum_size.x = 150
	name.add_child(UI.icon(Icons.badge(tier, 22, t.fill, c.badge_line)))
	name.add_child(UI.label(tier.capitalize(), 14, t.ink, 800))
	h.add_child(name)
	var pct := UI.label("", 16, c.acc_ink, 600, true)
	pct.custom_minimum_size.x = 70
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hint := UI.label("", 13, c.ink2, 400)
	hint.custom_minimum_size.x = 90
	var show := func(wt: float, f: float):
		pct.text = ("%.1f%%" % wt) if wt < 10.0 else ("%d%%" % int(round(wt)))
		hint.text = "never" if f <= 0.0 else ("1 in %s" % _thousands(int(round(1.0 / f))) if f < 0.5 else "%d in 10" % int(round(f * 10.0)))
	show.call(weight, frac)
	var sl := K.slider(pow(weight / 100.0, 1.0 / ODDS_POWER) * 100.0, 0, 100, 0.1, 0, func(p):
		var wt := snappedf(100.0 * pow(p / 100.0, ODDS_POWER), 0.01)
		var odds: Dictionary = S().value("world.odds").duplicate()
		odds[tier] = wt
		set_value("world.odds", odds)
		show.call(wt, S().odds()[tier]))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.drag_ended.connect(func(_c): w.rebuild())
	h.add_child(sl)
	h.add_child(pct)
	h.add_child(hint)
	return h


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ============================================================ SOUND

func _sound(body: VBoxContainer) -> void:
	var c := K.c
	header(body, "Sound", "Little squeaks, peeps and bloops when you pop a critter.")
	var vol := K.hbox(12)
	vol.add_child(UI.icon(Icons.line("mute", 20, c.ink3)))
	var val := K.value_label("%d%%" % int(S().value("sound.volume")), 50)
	var sl := K.slider(float(S().value("sound.volume")), 0, 100, 5, 260, func(x):
		val.text = "%d%%" % int(x)
		set_value("sound.volume", int(x)))
	sl.drag_ended.connect(func(_c): w.main.preview_sound(w.selected_species))
	vol.add_child(sl)
	vol.add_child(UI.icon(Icons.line("sound", 20, c.ink3)))
	vol.add_child(val)
	body.add_child(K.section("Master", K.card([
		_toggle_row("Pop sounds", "Each critter makes its own little noise when you click to pop it.", "sound.pops"),
		K.row("Volume", "", vol),
	])))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	var all := _built(false) + _built(true)
	for sp in all:
		var on: bool = S().sp(sp, "sound")
		var r := K.hbox(14)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var av := PanelContainer.new()
		av.custom_minimum_size = Vector2(46, 46)
		av.add_theme_stylebox_override("panel", K.box(Palette.species_tint(sp, w.dark), 23))
		av.add_child(CritterView.make(sp, 46, 46, 0.5))
		r.add_child(av)
		var nm := UI.label(Collection.species_name(sp), 15, c.ink if on else c.ink3, 800)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nm)
		var spc: String = sp
		r.add_child(K.icon_button("play", "Play %s sound" % Collection.species_name(sp).to_lower(), func(): w.main.preview_sound(spc)))
		var tg := K.toggle(on, "%s sound" % Collection.species_name(sp), func(x): set_value("species.%s.sound" % spc, x, true))
		tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(tg)
		var cell := K.margins(r, 20, 12, 20, 12)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
	body.add_child(K.section("Every critter", K.card([grid]), "Press play to hear one"))


# ============================================================ COLLECTION

func _collection(body: VBoxContainer) -> void:
	var page = Collection.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(page)
	page.setup(w.main.economy)


# ============================================================ SHOP
# Design: "Critter Clothes" canvas, Shop B (dressing room), Harrison's pick.
# The critter stays in view on the left; clicking an item tries it on; then
# buy it, wear it, or put it back.

var shop_slot := "all"
var shop_try := ""                 # the item being tried on, or ""


func _shop(body: VBoxContainer) -> void:
	var c := K.c
	var eco = w.main.economy
	var berries := K.hbox(8)
	var bp := PanelContainer.new()
	var bs := K.box(c.surface, 16, c.line, 2)
	bs.content_margin_left = 12
	bs.content_margin_right = 16
	bs.content_margin_top = 6
	bs.content_margin_bottom = 6
	bp.add_theme_stylebox_override("panel", bs)
	berries.add_child(UI.icon(Icons.berry(26)))
	berries.add_child(UI.label("%s berries" % _thousands(eco.berries), 18, c.ink, 600, true))
	bp.add_child(berries)
	header(body, "Shop", "Pick something to try it on. Berries come from working; nothing here costs money.", bp)

	var sp: String = w.selected_species if Species.has(w.selected_species) else _built(false)[0]
	var worn: Array = eco.worn.get(sp, [])
	if shop_try != "" and not Wear.fits(shop_try, sp):
		shop_try = ""
	var trying: Array = worn.filter(func(x): return shop_try == "" or Wear.slot(x) != Wear.slot(shop_try))
	if shop_try != "":
		trying.append(shop_try)

	var row := K.hbox(20)
	row.add_child(_dressing_room(sp, worn, trying))
	row.add_child(_rail(sp, worn))
	body.add_child(row)


func _dressing_room(sp: String, worn: Array, trying: Array) -> Control:
	var c := K.c
	var eco = w.main.economy
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 320
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var cs := K.box(c.surface, 20, c.line, 2)
	cs.set_content_margin_all(2)
	card.add_theme_stylebox_override("panel", cs)
	var v := K.vbox(0)
	card.add_child(v)

	# The stage, with the species to dress.
	var stage := PanelContainer.new()
	var ss := K.box(Palette.species_tint(sp, w.dark), 0)
	ss.corner_radius_top_left = 18
	ss.corner_radius_top_right = 18
	stage.add_theme_stylebox_override("panel", ss)
	stage.custom_minimum_size = Vector2(316, 300)
	var layer := Control.new()
	stage.add_child(layer)
	var view := CritterView.make(sp, 316, 296, 2.0, "sit", false, -1, trying)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(view)
	var chips := K.hbox(6)
	chips.position = Vector2(12, 12)
	for s in _built(false) + _built(true):
		var spc: String = s
		chips.add_child(K.chip(Collection.species_name(s), s == sp, func():
			w.selected_species = spc
			w.rebuild()))
	layer.add_child(chips)
	v.add_child(stage)

	var info := K.vbox(10)
	if shop_try == "":
		info.add_child(UI.label("WEARING NOW", 12, c.acc_ink, 800))
		info.add_child(UI.label(", ".join(worn.map(func(x): return Wear.item_name(x))) if not worn.is_empty() else "Nothing yet", 20, c.ink, 600, true))
		var hint := UI.label("Pick something on the right to try it on.", 13, c.ink2, 400)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = 280
		info.add_child(hint)
		if not worn.is_empty():
			var off := K.button("Take everything off", "bq", "close", true, func():
				w.main.set_worn(sp, [])
				w.rebuild())
			off.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			info.add_child(off)
	else:
		var id := shop_try
		var owned: bool = eco.owns(id)
		var on: bool = id in worn
		var price := Wear.price(id)
		info.add_child(UI.label("TRYING ON", 12, c.acc_ink, 800))
		var tr := K.hbox(8)
		var nm := UI.label(Wear.item_name(id), 22, c.ink, 600, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.add_child(nm)
		tr.add_child(UI.label("Yours" if owned else "%s berries" % _thousands(price), 15, Palette.tier("uncommon", w.dark).ink if owned else c.ink, 800))
		info.add_child(tr)
		var btns := K.hbox(8)
		var main_btn: Button
		if on:
			main_btn = K.button("Take it off", "bs", "", false, func():
				w.main.set_worn(sp, worn.filter(func(x): return x != id))
				shop_try = ""
				w.rebuild())
		elif owned:
			main_btn = K.button("Wear it", "bp", "", false, func():
				w.main.set_worn(sp, worn.filter(func(x): return Wear.slot(x) != Wear.slot(id)) + [id])
				shop_try = ""
				w.rebuild())
		elif eco.berries >= price:
			main_btn = K.button("Buy for %s" % _thousands(price), "bp", "", false, func():
				if eco.buy(id, price):
					w.main.set_worn(sp, worn.filter(func(x): return Wear.slot(x) != Wear.slot(id)) + [id])
					shop_try = ""
				w.rebuild())
		else:
			main_btn = K.button("%s more berries" % _thousands(price - eco.berries), "bs", "", false)
			main_btn.disabled = true
			main_btn.tooltip_text = "Berries come from time spent working: about one a minute, plus gifts."
		main_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(main_btn)
		btns.add_child(K.button("Put back", "bs", "", false, func():
			shop_try = ""
			w.rebuild()))
		info.add_child(btns)
		var now := K.divider()
		info.add_child(now)
		var wl := UI.label("Wearing now: " + (", ".join(worn.map(func(x): return Wear.item_name(x))) if not worn.is_empty() else "nothing"), 13, c.ink2, 700)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.custom_minimum_size.x = 280
		info.add_child(wl)
		var note := UI.label("Trying on changes nothing until you buy or wear it. Every critter can wear everything.", 13, c.ink2, 400)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 280
		info.add_child(note)
	v.add_child(K.margins(info, 18, 16, 18, 18))
	return card


func _rail(sp: String, worn: Array) -> Control:
	var c := K.c
	var eco = w.main.economy
	var col := K.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var filters := ["all", "head", "neck", "face", "showpiece"]
	var labels := ["All", "Hats", "Neck", "Face", "Showpieces"]
	var have_show := Wear.ITEMS.keys().any(func(i): return Wear.ITEMS[i][2] == "showpiece")
	if not have_show:
		filters.pop_back()
		labels.pop_back()
	var seg := K.seg(labels, maxi(0, filters.find(shop_slot)), func(i):
		shop_slot = filters[i]
		w.rebuild())
	seg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(seg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var ids := Wear.ITEMS.keys()
	ids.sort_custom(func(a, b): return Wear.price(a) > Wear.price(b) or (Wear.price(a) == Wear.price(b) and a < b))
	for id in ids:
		if not Wear.fits(id, sp):
			continue
		if shop_slot == "showpiece" and Wear.ITEMS[id][2] != "showpiece":
			continue
		if shop_slot in ["head", "neck", "face"] and Wear.slot(id) != shop_slot:
			continue
		grid.add_child(_tile_item(id, sp, worn))
	col.add_child(grid)
	return col


func _tile_item(id: String, sp: String, worn: Array) -> Control:
	var c := K.c
	var eco = w.main.economy
	var picked := id == shop_try
	var owned: bool = eco.owns(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(140, 150)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "Try on the %s" % Wear.item_name(id).to_lower()
	var n := K.box(c.surface, 16, c.outline if picked else c.line, 3 if picked else 2, c.lip, 2 if picked else 0)
	b.add_theme_stylebox_override("normal", n)
	var hv := n.duplicate()
	hv.border_color = c.outline
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("focus", K.box(Color.TRANSPARENT, 16, c.acc_ink, 2))
	var v := K.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 3
	v.offset_right = -3
	v.offset_top = 3
	var well := PanelContainer.new()
	var ws := K.box(Palette.species_tint(sp, w.dark), 0)
	ws.corner_radius_top_left = 13
	ws.corner_radius_top_right = 13
	well.add_theme_stylebox_override("panel", ws)
	well.custom_minimum_size.y = 84
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(CritterView.make(sp, 130, 84, 0.62, "sit", false, -1, [id]))
	v.add_child(well)
	var t := K.vbox(2)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(UI.label(Wear.item_name(id), 13, c.ink, 800))
	var price_text := "Wearing" if id in worn else ("Yours" if owned else "%s berries" % _thousands(Wear.price(id)))
	t.add_child(UI.label(price_text, 12, Palette.tier("uncommon", w.dark).ink if owned else c.ink2, 700))
	v.add_child(K.margins(t, 10, 8, 10, 8))
	b.add_child(v)
	b.pressed.connect(func():
		shop_try = "" if picked else id
		w.rebuild())
	return b


# ============================================================ SYSTEM

func _system(body: VBoxContainer) -> void:
	var c := K.c
	header(body, "System", "Startup, shortcuts, updates and the small print.")
	body.add_child(K.section("Startup", K.card([
		K.row("Start with Windows", "Your critters are ready when you log in.", K.toggle(w.main.is_startup(), "Start with Windows", func(on): w.main.set_startup(on))),
	])))

	var rows := []
	for slot in 2:
		var key: Dictionary = S().value("system.pause_key" if slot == 0 else "system.spawn_key")
		var ctl := K.hbox(14)
		if w.capturing == slot:
			ctl.add_child(UI.label("Press the new keys" + ("" if slot == 0 else ", or Backspace to clear") + ". Esc cancels.", 13, c.acc_ink, 800))
		else:
			var names := Settings.key_text(key)
			if names.is_empty():
				ctl.add_child(UI.label("Not set", 13, c.ink3, 700))
			else:
				ctl.add_child(K.keys(names))
			var s := slot
			ctl.add_child(K.button("Change" if not names.is_empty() else "Set", "bs", "", true, func():
				shortcut_note = ""
				w.capture(s)))
		var state: int = w.main.shortcut_state(slot)
		var desc := "Works from any app." if slot == 0 else "Optional."
		if state == -1:
			desc = "Another app is using these keys. Pick different ones."
		rows.append(K.row("Pause or resume" if slot == 0 else "Spawn a critter", desc, ctl, "", null if slot == 0 else K.new_pill()))
	if shortcut_note != "":
		rows.append(K.margins(UI.label(shortcut_note, 13, c.dng_ink, 700), 20, 10, 20, 12))
	body.add_child(K.section("Shortcuts", K.card(rows)))

	var themes := ["system", "light", "dark"]
	var details := ["detailed", "simple"]
	body.add_child(K.section("Display", K.card([
		K.row("Theme", "Follows your Windows light or dark setting unless you pick one.",
			K.seg(["Match Windows", "Light", "Dark"], maxi(0, themes.find(S().value("system.theme"))), func(i): set_value("system.theme", themes[i]))),
		K.row("Animation detail", "Simple uses fewer animation layers on slower computers.",
			K.seg(["Detailed", "Simple"], maxi(0, details.find(S().value("system.detail"))), func(i): set_value("system.detail", details[i], true))),
	])))

	body.add_child(K.section("Collection", K.card([
		_toggle_row("Keep a Seen Log", "Records each critter and tier you meet, for your Collection.", "system.seen_log"),
		K.row("Clear the Seen Log", "Start your Collection again from nothing. This cannot be undone.",
			K.button("Clear", "bd", "trash", true, func():
				w.confirm("Clear the Seen Log?", "Every critter and tier you have met, and the sightings diary, will be forgotten. Berries and gifts are kept.", "Clear it", func():
					w.main.clear_seen_log()
					w.rebuild()))),
	])))

	# Custom critters: a placeholder until they arrive.
	var ph := PanelContainer.new()
	var pst := K.box(c.ph_bg, 20, c.dash, 2)
	pst.set_content_margin_all(18)
	ph.add_theme_stylebox_override("panel", pst)
	var pr := K.hbox(16)
	var bx := PanelContainer.new()
	bx.custom_minimum_size = Vector2(52, 52)
	bx.add_theme_stylebox_override("panel", K.box(c.surface, 16, c.dash, 2))
	bx.add_child(UI.icon(Icons.line("box", 26, c.ph_ink)))
	pr.add_child(bx)
	var pt := K.vbox(3)
	pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ptt := K.hbox(8)
	ptt.add_child(UI.label("Custom critters", 15, c.ink, 800))
	ptt.add_child(K.soon_pill())
	pt.add_child(ptt)
	pt.add_child(UI.label("Bring your own art and share critters with friends. This arrives in a later update.", 13, c.ink2, 400))
	pr.add_child(pt)
	var imp := K.button("Import a critter", "bs", "plus", true)
	imp.disabled = true
	imp.modulate.a = 0.6
	imp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(imp)
	ph.add_child(pr)
	body.add_child(K.section("Custom critters", ph))

	var up := K.hbox(8)
	up.add_child(K.button("What is new", "bq", "", true, func(): OS.shell_open(REPO + "/releases")))
	up.add_child(K.button("Check now", "bs", "update", true, func():
		update_note = "Checking..."
		w.main.check_for_updates(func(text):
			update_note = text
			w.rebuild())
		w.rebuild()))
	body.add_child(K.section("Updates", K.card([
		K.row("Version %s" % w.main.VERSION, update_note if update_note != "" else "Checks GitHub for a newer release when you press Check now.", up),
	])))

	body.add_child(K.section("Reset and quit", K.card([
		K.row("Reset all settings", "Critters, odds and shortcuts go back to how they started. Your Collection is kept.",
			K.button("Reset", "bs", "reset", true, func():
				w.confirm("Reset all settings?", "Every setting goes back to how it started. Your Collection, berries and gifts are kept.", "Reset", func():
					S().reset_all()
					w.rebuild()))),
		K.row("Quit Critter Overlay", "Closing this window keeps your critters running in the tray. Quit stops them completely.",
			K.button("Quit", "bd", "power", true, func(): w.main.quit_app())),
	])))

	var about := K.hbox(18)
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(64, 64)
	av.add_theme_stylebox_override("panel", K.box(Palette.species_tint("kitten", w.dark), 20, c.outline, 2))
	av.add_child(UI.icon(Icons.tray("running", 52)))
	about.add_child(av)
	var at := K.vbox(2)
	at.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	at.add_child(UI.label("Critter Overlay %s" % w.main.VERSION.substr(0, 3), 20, c.ink, 600, true))
	at.add_child(UI.label("Small companions for long days.", 13, c.ink2, 400))
	about.add_child(at)
	for l in [["Help", func(): OS.shell_open(REPO + "#readme")],
			["Credits and licences", func(): w.notice("Credits and licences", _credits())],
			["Privacy", func(): w.notice("Privacy", PRIVACY)]]:
		var lb := LinkButton.new()
		lb.text = l[0]
		lb.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		lb.add_theme_color_override("font_color", c.acc_ink)
		lb.add_theme_color_override("font_hover_color", c.acc_ink_h)
		lb.add_theme_font_override("font", UI.font(800))
		lb.add_theme_font_size_override("font_size", 13)
		lb.pressed.connect(l[1])
		lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		about.add_child(lb)
	body.add_child(K.section("About", K.margins(about, 4, 6, 4, 6)))


const PRIVACY := """Critter Overlay keeps everything on this computer.

To know when you are working, it checks how long it has been since your last key press or mouse movement. It never records which keys you press, what you type or where you click.

Your Collection, berries and settings are saved in this computer's app data folder and nowhere else.

The only time it goes online is when you press Check now under Updates, which asks GitHub for the newest version number."""


func _credits() -> String:
	var out := "Critter Overlay. Code and art by its author.\n\nFonts: Fredoka and Nunito, SIL Open Font License, when installed.\n\nBuilt with the Godot Engine.\n\n"
	out += Engine.get_license_text() + "\n\nThird-party components in Godot:\n\n"
	var info := Engine.get_copyright_info()
	for comp in info:
		out += "%s\n" % comp.name
		for part in comp.parts:
			out += "  %s (%s)\n" % [", ".join(part.copyright), part.license]
	return out
