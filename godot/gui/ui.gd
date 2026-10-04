extends RefCounted
## Building blocks shared by the GUI windows: the design's rounded panels,
## its two typefaces, labels and chips.


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


static func font(weight: int, display := false) -> SystemFont:
	# The design's Fredoka (headings) and Nunito (text) when installed, else
	# Segoe UI.
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Fredoka", "Segoe UI"] if display else ["Nunito", "Segoe UI"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	return f


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
