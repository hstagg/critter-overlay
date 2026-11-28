extends RefCounted
## The Studio's own icons, from the D0 design (design/studio/builder/icons.js),
## drawn in the app's line style (24 grid, 2 px round strokes) as gui/icons.gd
## draws its own. Anything gui/icons.gd already has is used from there.

const Icons := preload("res://gui/icons.gd")

const LINE := {
	"back": '<path d="M14.5 6l-6 6 6 6"/>',
	"move": '<path d="M6 4l5.5 15 2.2-6.3L20 10.5z"/>',
	"ellipse": '<ellipse cx="12" cy="12" rx="8.5" ry="6"/>',
	"rect": '<rect x="3.5" y="6" width="17" height="12" rx="3.5"/>',
	"tri": '<path d="M12 5l8 14H4z"/>',
	"drop": '<path d="M12 4c3.2 4 6 7 6 10a6 6 0 0 1-12 0c0-3 2.8-6 6-10z"/>',
	"blob": '<path d="M6.5 16c-2.5-3.5-.5-9.5 5-10 5-.5 8.5 2.5 7.8 6.5-.6 3.6-3 6-7.3 6-2.6 0-4.3-.8-5.5-2.5z"/>',
	"stroke": '<path d="M4 17c2.5-7 6-7 8-3s5.5 4 8-6"/>',
	"eye": '<ellipse cx="12" cy="12" rx="5.5" ry="7"/><circle cx="13.6" cy="9.6" r="1.6" fill="currentColor" stroke="none"/>',
	"hand": '<path d="M8 13V7a1.5 1.5 0 0 1 3 0v4.5M11 11V5.5a1.5 1.5 0 0 1 3 0V11M14 11V7a1.5 1.5 0 0 1 3 0v7c0 3.6-2.6 6-6 6-2.4 0-4-1-5.4-3L4 14.3a1.5 1.5 0 0 1 2.4-1.8L8 14"/>',
	"undo": '<path d="M9 7.5L5 11.5l4 4"/><path d="M5 11.5h9.5a4.5 4.5 0 0 1 0 9H12"/>',
	"redo": '<path d="M15 7.5l4 4-4 4"/><path d="M19 11.5H9.5a4.5 4.5 0 0 0 0 9H12"/>',
	"fwd": '<rect x="4" y="9" width="10" height="10" rx="2"/><rect x="10" y="5" width="10" height="10" rx="2" fill="currentColor" fill-opacity=".25"/>',
	"bwd": '<rect x="10" y="5" width="10" height="10" rx="2"/><rect x="4" y="9" width="10" height="10" rx="2" fill="currentColor" fill-opacity=".25"/>',
	"mirror": '<path d="M12 4v16"/><path d="M9 7.5L4 17h5zM15 7.5L20 17h-5z"/>',
	"dup": '<rect x="8" y="8" width="11" height="11" rx="2.5"/><path d="M5 15.5V6.5A1.5 1.5 0 0 1 6.5 5h9"/>',
	"del": '<path d="M5 7h14M10 7V5h4v2M7 7l1 12.5h8L17 7"/>',
	"show": '<path d="M2.5 12S6 6 12 6s9.5 6 9.5 6S18 18 12 18 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.6"/>',
	"hide": '<path d="M4 4l16 16M9.9 6.3A9 9 0 0 1 12 6c6 0 9.5 6 9.5 6a16 16 0 0 1-3 3.6M6.3 8.2A16 16 0 0 0 2.5 12S6 18 12 18a9 9 0 0 0 3.2-.6"/>',
	"unlock": '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 6.8-1.2"/>',
	"auto": '<path d="M12 4v3M12 17v3M4 12h3M17 12h3M6.3 6.3l2.1 2.1M15.6 15.6l2.1 2.1M6.3 17.7l2.1-2.1M15.6 8.4l2.1-2.1"/>',
	"max": '<rect x="6" y="6" width="12" height="12" rx="2"/>',
	"snap": '<path d="M4 18h16"/><path d="M12 4v9M8.5 9.5L12 13l3.5-3.5"/>',
	"sym": '<path d="M12 3.5v17" stroke-dasharray="2 2.5"/><path d="M9 8c-3 0-5 2-5 4s2 4 5 4zM15 8c3 0 5 2 5 4s-2 4-5 4z"/>',
	"grip": '<path d="M19 13l-6 6M19 17l-2 2M19 9l-10 10"/>',
}

static var _cache := {}


static func line(name: String, size: int, colour: Color) -> Texture2D:
	if not LINE.has(name):
		return Icons.line(name, size, colour)   # heart, star, plus, lock, close, min...
	var hex := "#" + colour.to_html(false)
	var key := "%s:%d:%s" % [name, size, hex]
	if not _cache.has(key):
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [
			hex, str(LINE[name]).replace("currentColor", hex)]
		var img := Image.new()
		img.load_svg_from_string(svg, size / 24.0)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
