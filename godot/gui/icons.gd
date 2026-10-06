extends RefCounted
## Line icons and the tray icon, drawn from SVG at runtime (the same shapes
## as the design canvas, design/gui/parts.py and pages3.py).

const LINE := {
	"heart": '<path d="M12 19s-7-4.4-7-9.5A3.8 3.8 0 0 1 12 7.5a3.8 3.8 0 0 1 7 2C19 14.6 12 19 12 19z"/>',
	"monitor": '<rect x="3" y="4.5" width="18" height="12" rx="2.5"/><path d="M9 20h6M12 16.5V20"/>',
	"home": '<path d="M4 11.5 12 5l8 6.5V19a1 1 0 0 1-1 1h-4.5v-5h-5v5H5a1 1 0 0 1-1-1z"/>',
	"paw": '<circle cx="6.5" cy="10" r="1.8"/><circle cx="10" cy="6" r="1.8"/><circle cx="14.5" cy="6" r="1.8"/><circle cx="18" cy="10" r="1.8"/><path d="M7.5 17.5c0-3 2.2-5.5 4.5-5.5s4.5 2.5 4.5 5.5c0 1.8-1.5 2.3-2.8 2-1.1-.3-2.3-.3-3.4 0-1.3.3-2.8-.2-2.8-2z"/>',
	"mug": '<path d="M5 9h11v6a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4z"/><path d="M16 11h1.5a2.5 2.5 0 0 1 0 5H16"/><path d="M8.5 3.5c0 1.2 1 1.3 1 2.5M12.5 3.5c0 1.2 1 1.3 1 2.5"/>',
	"leaf": '<path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14z"/><path d="M5 19 13 11"/>',
	"sound": '<path d="M4 10v4h3l5 4V6L7 10z"/><path d="M15.5 9.5a3.5 3.5 0 0 1 0 5M18 7a7 7 0 0 1 0 10"/>',
	"mute": '<path d="M4 10v4h3l5 4V6L7 10z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
	"minus": '<path d="M5.5 12h13"/>',
	"plus": '<path d="M12 5.5v13M5.5 12h13"/>',
	"min": '<path d="M6 12h12"/>',
	"reset": '<path d="M5 12a7 7 0 1 0 2-4.9"/><path d="M5 4v4h4"/>',
	"info": '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>',
	"chevd": '<path d="M6 9l6 6 6-6"/>',
	"clock": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
	"trash": '<path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/>',
	"update": '<path d="M12 4v11M7.5 10.5 12 15l4.5-4.5M5 20h14"/>',
	"check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
	"box": '<path d="M4 8l8-4 8 4v8l-8 4-8-4z"/><path d="M4 8l8 4 8-4M12 12v8"/>',
	"arrow": '<path d="M5 12h14M13 6l6 6-6 6"/>',
	"star": '<path d="M12 4.5l2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5-3.6-3.5 5-.7z"/>',
	"sliders": '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
	"play": '<path d="M8 5.5v13l10-6.5z" fill="currentColor"/>',
	"pause": '<path d="M9 6v12M15 6v12"/>',
	"sparkle": '<path d="M12 3.5l1.8 5.2 5.2 1.8-5.2 1.8L12 17.5l-1.8-5.2L5 10.5l5.2-1.8z"/><path d="M18.5 16v4M16.5 18h4"/>',
	"power": '<path d="M12 4v8"/><path d="M7.2 7.2a7 7 0 1 0 9.6 0"/>',
	"close": '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
	"moon": '<path d="M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z"/>',
	"lock": '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>',
}

# Each tier has its own shape as well as its colour, so tiers read without colour.
const TIER_SHAPE := {
	"common": '<circle cx="10" cy="10" r="6.5"/>',
	"uncommon": '<path d="M10 3c4 3.2 5.6 6.2 5.6 8.6a5.6 5.6 0 0 1-11.2 0C4.4 9.2 6 6.2 10 3z"/>',
	"rare": '<path d="M10 2.5 16.8 10 10 17.5 3.2 10z"/>',
	"epic": '<path d="M10 2.4l2.3 4.8 5.2.6-3.9 3.6 1.1 5.2L10 14l-4.7 2.6 1.1-5.2-3.9-3.6 5.2-.6z"/>',
	"legendary": '<path d="M3 15.5h14l1.2-9.2-4.6 3.6L10 3.8 6.4 9.9 1.8 6.3z"/>',
}

static var _cache := {}


static func _texture(svg: String, scale: float) -> ImageTexture:
	var key := "%s@%s" % [svg.hash(), scale]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	img.load_svg_from_string(svg, scale)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func line(name: String, size: int, colour: Color) -> ImageTexture:
	var hex := "#" + colour.to_html(false)
	var body: String = LINE[name].replace("currentColor", hex)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [hex, body]
	return _texture(svg, size / 24.0)


static func badge(tier: String, size: int, fill: Color, line: Color, ghost := false) -> ImageTexture:
	# A tier badge; `ghost` is the dashed outline of one not yet found.
	var g := '<g fill="#%s" stroke="#%s" stroke-width="1.6" stroke-linejoin="round"%s>%s</g>' % [
		fill.to_html(false), line.to_html(false), ' stroke-dasharray="2.2 2"' if ghost else "", TIER_SHAPE[tier]]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" width="20" height="20">%s</svg>' % g
	return _texture(svg, size / 20.0)


static func sparkle(size: int) -> ImageTexture:
	# The gold four-point star on Legendary toasts.
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path d="M12 2l2.4 7.6L22 12l-7.6 2.4L12 22l-2.4-7.6L2 12l7.6-2.4z" fill="#FFD84D" stroke="#B8860B" stroke-width="1.4"/></svg>'
	return _texture(svg, size / 24.0)


static func tray(state: String, size: int) -> ImageTexture:
	# Drawn for 16 px, not scaled down from the critter art.
	var fur := "#D8CFC6" if state == "paused" else "#F6C28F"
	var eyes := '<circle cx="11.4" cy="18" r="2.4" fill="#2B2330"/><circle cx="20.6" cy="18" r="2.4" fill="#2B2330"/>'
	if state == "napping":
		eyes = '<path d="M8.8 18.2q2.6 2.2 5.2 0M18 18.2q2.6 2.2 5.2 0" stroke="#2B2330" stroke-width="2" fill="none" stroke-linecap="round"/>'
	var badge := ""
	if state == "paused":
		badge = '<circle cx="25" cy="25" r="6.5" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="1.8"/><path d="M23 22.4v5.2M27 22.4v5.2" stroke="#6B4A3A" stroke-width="1.9" stroke-linecap="round"/>'
	elif state == "napping":
		badge = '<circle cx="25" cy="7" r="6" fill="#E6EEF3" stroke="#6B4A3A" stroke-width="1.6"/><path d="M22.6 4.6h4.6l-4.6 4.8h4.6" stroke="#3E5670" stroke-width="1.7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
	var blush := "" if state == "paused" else '<ellipse cx="8.4" cy="22.4" rx="2.1" ry="1.3" fill="#F59C9C"/><ellipse cx="23.6" cy="22.4" rx="2.1" ry="1.3" fill="#F59C9C"/>'
	var svg := ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">'
		+ '<path d="M5.5 15 6.6 4.4l7 5.2z" fill="%s" stroke="#6B4A3A" stroke-width="2.2" stroke-linejoin="round"/>' % fur
		+ '<path d="M26.5 15 25.4 4.4l-7 5.2z" fill="%s" stroke="#6B4A3A" stroke-width="2.2" stroke-linejoin="round"/>' % fur
		+ '<ellipse cx="16" cy="18.5" rx="12.4" ry="10.4" fill="%s" stroke="#6B4A3A" stroke-width="2.2"/>' % fur
		+ blush + eyes + badge + '</svg>')
	return _texture(svg, size / 32.0)
