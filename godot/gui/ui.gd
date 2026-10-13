extends RefCounted
## Building blocks shared by the GUI windows: the design's rounded panels,
## its two typefaces, labels and chips.


static func scale() -> float:
	# The primary screen's display scale: Windows reports 96 dpi for 100%,
	# 144 for 150%. Critters and windows are drawn this much larger, so a
	# size setting looks the same on every screen.
	return clampf(DisplayServer.screen_get_dpi(DisplayServer.get_primary_screen()) / 96.0, 1.0, 3.0)


static func fit(base: Vector2, room := 0.95) -> float:
	# The scale for a window this size: the display scale, smaller if that
	# would not fit the work area (a small or low-resolution screen).
	var u := Vector2(DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen()).size)
	return minf(scale(), minf(u.x * room / base.x, u.y * room / base.y))


static func box(bg: Color, radius: int, border := Color.TRANSPARENT, bw := 0, pad := 0, shadow := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	if shadow.a > 0.0:
		s.shadow_color = shadow
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 4)
	return s


static var _fonts := {}


static func font(weight: int, display := false) -> Font:
	# The design's fonts, bundled in godot/fonts (SIL Open Font License):
	# Fredoka for headings, Nunito for text, at the weight asked for. Segoe UI
	# draws any character they lack.
	var key := "%s%d" % ["d" if display else "t", weight]
	if not _fonts.has(key):
		var segoe := SystemFont.new()
		segoe.font_names = PackedStringArray(["Segoe UI"])
		segoe.font_weight = weight
		var file: FontFile = load("res://fonts/Fredoka.ttf" if display else "res://fonts/Nunito.ttf")
		if file == null:
			push_warning("ui: a bundled font did not load; using Segoe UI")
			_fonts[key] = segoe
			return segoe
		if file.fallbacks.is_empty():
			file.fallbacks = [segoe]
		var v := FontVariation.new()
		v.base_font = file
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = v
	return _fonts[key]


static func label(text: String, size: int, colour: Color, weight := 400, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight, display))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


static func wrap(text: String, size: int, colour: Color, width: float) -> Label:
	var l := label(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func chip(text: String, ink: Color, bg: Color, border := Color.TRANSPARENT, size := 12) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, 8, border, 1 if border.a > 0.0 else 0)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, size, ink, 800))
	return p


static func bar(value: float, track: Color, fill: Color, height := 7) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.value = value
	b.custom_minimum_size.y = height
	b.add_theme_stylebox_override("background", box(track, height / 2))
	b.add_theme_stylebox_override("fill", box(fill, height / 2))
	return b


static func icon(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
