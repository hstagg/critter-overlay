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


static func joined(files: Array) -> String:
	# Several of the kitten's SVGs (all in the same frame) as one.
	var inner := ""
	for name in files:
		var s := FileAccess.get_file_as_string(KITTEN + name + ".svg")
		var a := s.find(">", s.find("<svg")) + 1
		var b := s.rfind("</svg>")
		inner += s.substr(a, b - a)
	return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">%s</svg>' % inner


static func _json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
