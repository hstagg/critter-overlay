extends RefCounted
## Test kits made from the cast's own art (docs/custom-critters-build-plan.md,
## B1): the kitten as a side-on kit, and a bare kit with only the required
## parts. kit_test.gd compares them with the real kitten, and the Admin page
## spawns them. Not in the player build (export_presets.cfg leaves it out),
## so only tests and admin.gd may preload it.
##
## The kitten's sitting pose is several parts (body, feet, paws) and its nap
## three (loaf body, paws, tail); a kit has one drawing per pose, so those
## are joined into one SVG each, in the kitten's drawing order.

const KITTEN := "res://art/kitten/"

# The kitten's pins, from kitten.gd's constants.
const KITTEN_PINS := {
	"head": [150, 190], "neck-walk": [112, 198], "neck-sit": [150, 190], "neck-loaf": [150, 212],
	"hip-front": [116, 224], "hip-back": [196, 224], "hip-front-far": [134, 224], "hip-back-far": [214, 224],
	"leg-front": [118, 224], "leg-back": [118, 224], "leg-front-far": [118, 224], "leg-back-far": [118, 224],
	"tail": [200, 226], "tail-walk": [226, 192], "tail-sit": [200, 226],
	"ear-l": [100, 76], "ear-r": [200, 76], "eyes": [150, 124], "mouth-open": [150, 152],
	"scratch-foot": [194, 252],
}
const KITTEN_PARTS := {
	"walk-body": ["walk-body"], "head": ["head"], "eyes": ["eyes"], "eyes-closed": ["eyes-closed"],
	"leg-front": ["leg-front"], "leg-back": ["leg-back"], "leg-front-far": ["leg-front-far"],
	"leg-back-far": ["leg-back-far"], "ear-l": ["ear-l"], "ear-r": ["ear-r"], "tail": ["tail"],
	"mouth-open": ["mouth-open"], "scratch-foot": ["scratch-foot"],
	"body": ["body", "foot-l", "foot-r", "paws"],
	"loaf-body": ["loaf-body", "loaf-paws", "loaf-tail"],
}
const BARE := ["walk-body", "head", "eyes", "leg-front", "leg-back"]


static func kitten_kit(dest: String, bare := false, gait := "trot") -> String:
	# Writes the kitten (or the bare kit) as a kit folder at dest. Returns dest.
	DirAccess.make_dir_recursive_absolute(dest.path_join("parts"))
	var parts := BARE if bare else KITTEN_PARTS.keys()
	for part in parts:
		var f := FileAccess.open(dest.path_join("parts/%s.svg" % part), FileAccess.WRITE)
		f.store_string(joined(KITTEN_PARTS[part]))
		f.close()
	var name := "Bare kit" if bare else "Kitten kit"
	_json(dest.path_join("custom.json"), {"schema": 2, "kind": "kit", "rev": 1, "name": name,
		"from": "test", "size": 1.0, "speed": 1.0, "visits": 1, "enabled": true, "sound": "kitten",
		"pop": ["#E6A569", "#F5BE82", "#FFA0A0"], "seen": {}})
	_json(dest.path_join("kit.json"), {"schema": 1, "plan": "side", "gait": gait, "faces": "left",
		"pins": KITTEN_PINS, "made_with": "svg"})
	return dest


static func joined(files: Array, folder := KITTEN, shift := Vector2.ZERO) -> String:
	# Several of a species' SVGs (all in the same frame) as one, moved by
	# shift so its feet stand on the kit frame's ground point (150, 262).
	var inner := ""
	for name in files:
		var s := FileAccess.get_file_as_string(folder + name + ".svg")
		var a := s.find(">", s.find("<svg")) + 1
		var b := s.rfind("</svg>")
		inner += s.substr(a, b - a)
	if shift != Vector2.ZERO:
		inner = '<g transform="translate(%s %s)">%s</g>' % [shift.x, shift.y, inner]
	return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">%s</svg>' % inner


# --- The otter as a faces-you kit (B2) -----------------------------------------

const OTTER := "res://art/otter/"
const OTTER_SHIFT := Vector2(26, -8)   # otter.gd's BASE (124, 270) onto (150, 262)
# otter.gd's constants, before the shift.
const OTTER_PINS := {
	"head": [124, 174], "neck-sit": [124, 174], "neck-walk": [122, 217], "neck-loaf": [122, 227],
	"hip-front": [133, 244.4], "hip-back": [210, 244.4], "hip-front-far": [145, 244.4], "hip-back-far": [222, 244.4],
	"leg-front": [133, 244.4], "leg-back": [210, 244.4], "leg-front-far": [145, 244.4], "leg-back-far": [222, 244.4],
	"tail": [140, 226], "tail-sit": [140, 226], "tail-walk": [140, 226],
	"ear-l": [77.2, 97], "ear-r": [170.8, 97], "eyes": [124, 124], "mouth-open": [124, 168],
	"eye-side": [92.5, 176.8], "groom-paws": [124, 270],
}
const OTTER_PARTS := ["body", "head", "eyes", "eyes-closed", "walk-body", "leg-front", "leg-back",
	"leg-front-far", "leg-back-far", "head-side", "eye-side", "eye-side-closed", "loaf-body",
	"ear-l", "ear-r", "foot-l", "foot-r", "paws", "tail", "mouth-open", "groom-paws"]
const ONE_FACE := ["body", "head", "eyes", "walk-body", "leg-front", "leg-back", "ear-l"]


static func otter_kit(dest: String, one_face := false, gait := "slide") -> String:
	# The otter (or a one-face kit: no side face, one ear, no nap drawing).
	DirAccess.make_dir_recursive_absolute(dest.path_join("parts"))
	for part in (ONE_FACE if one_face else OTTER_PARTS):
		var f := FileAccess.open(dest.path_join("parts/%s.svg" % part), FileAccess.WRITE)
		f.store_string(joined([part], OTTER, OTTER_SHIFT))
		f.close()
	var pins := {}
	for k in OTTER_PINS:
		pins[k] = [OTTER_PINS[k][0] + OTTER_SHIFT.x, OTTER_PINS[k][1] + OTTER_SHIFT.y]
	var name := "One-face kit" if one_face else "Otter kit"
	_json(dest.path_join("custom.json"), {"schema": 2, "kind": "kit", "rev": 1, "name": name,
		"from": "test", "size": 1.0, "speed": 1.0, "visits": 1, "enabled": true, "sound": "otter",
		"pop": ["#8B5E3C", "#C49A6C", "#F2D7B6"], "seen": {}})
	_json(dest.path_join("kit.json"), {"schema": 1, "plan": "front", "gait": gait, "faces": "left",
		"pins": pins, "made_with": "svg"})
	return dest


static func _json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
