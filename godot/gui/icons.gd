extends RefCounted
## Line icons and the tray icon, drawn from SVG at runtime (the same shapes
## as the design canvas, design/gui/parts.py and pages3.py).

const LINE := {
	"star": '<path d="M12 4.5l2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5-3.6-3.5 5-.7z"/>',
	"sliders": '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
	"play": '<path d="M8 5.5v13l10-6.5z" fill="currentColor"/>',
	"pause": '<path d="M9 6v12M15 6v12"/>',
	"sparkle": '<path d="M12 3.5l1.8 5.2 5.2 1.8-5.2 1.8L12 17.5l-1.8-5.2L5 10.5l5.2-1.8z"/><path d="M18.5 16v4M16.5 18h4"/>',
	"power": '<path d="M12 4v8"/><path d="M7.2 7.2a7 7 0 1 0 9.6 0"/>',
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
