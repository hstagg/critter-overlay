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


# --- The duckling as an upright kit (B3) -------------------------------------

const DUCKLING := "res://art/duckling/"
const DUCKLING_SHIFT := Vector2(0, -8)   # duckling.gd's BASE (150, 270) onto (150, 262)
const DUCKLING_PINS := {
	"head": [150, 196], "neck-sit": [150, 196], "neck-walk": [126, 196], "neck-loaf": [150, 220],
	"hip": [154, 244], "hip-far": [182, 244], "leg-near": [156, 244], "leg-far": [156, 244],
	"wing-l": [108, 206], "wing-r": [192, 206], "wing-side": [154, 208], "tuft": [150, 60],
	"eyes": [150, 132], "mouth-open": [150, 156], "tail": [230, 208], "tail-walk": [230, 208],
}
# A kit part -> the duckling's files that make it (its beak is drawn on the head).
const DUCKLING_PARTS := {
	"body": ["body"], "foot-l": ["foot-l"], "foot-r": ["foot-r"], "walk-body": ["walk-body"],
	"head": ["head", "beak-low", "beak"], "eyes": ["eyes"], "eyes-closed": ["eyes-closed"],
	"leg-near": ["leg-near"], "leg-far": ["leg-far"], "wing-l": ["wing-l"], "wing-r": ["wing-r"],
	"wing-side": ["wing-side"], "loaf-body": ["loaf-body"], "tuft": ["tuft"], "tail": ["tail"],
	"mouth-open": ["beak-in"],
}
const UPRIGHT_BARE := ["body", "head", "eyes", "leg-near", "wing-l"]


static func duckling_kit(dest: String, bare := false, gait := "waddle") -> String:
	# The duckling, or a bare upright kit (body, head, eyes, one leg, one wing).
	DirAccess.make_dir_recursive_absolute(dest.path_join("parts"))
	for part in (UPRIGHT_BARE if bare else DUCKLING_PARTS.keys()):
		var f := FileAccess.open(dest.path_join("parts/%s.svg" % part), FileAccess.WRITE)
		f.store_string(joined(DUCKLING_PARTS[part], DUCKLING, DUCKLING_SHIFT))
		f.close()
	var pins := {}
	for k in DUCKLING_PINS:
		pins[k] = [DUCKLING_PINS[k][0] + DUCKLING_SHIFT.x, DUCKLING_PINS[k][1] + DUCKLING_SHIFT.y]
	_json(dest.path_join("custom.json"), {"schema": 2, "kind": "kit", "rev": 1,
		"name": "Bare upright kit" if bare else "Duckling kit", "from": "test", "size": 1.0, "speed": 1.0,
		"visits": 1, "enabled": true, "sound": "duck", "pop": ["#F8E650", "#FFC832", "#F0F5DC"], "seen": {}})
	_json(dest.path_join("kit.json"), {"schema": 1, "plan": "upright", "gait": gait, "faces": "left",
		"pins": pins, "made_with": "svg"})
	return dest


# --- Blobs, drawn here (B4) -------------------------------------------------

const LINE := 'stroke="#6B4A3A" stroke-width="5" stroke-linejoin="round"'
const EYES := '<ellipse cx="128" cy="196" rx="9" ry="12" fill="#3A2A22"/><ellipse cx="168" cy="196" rx="9" ry="12" fill="#3A2A22"/><circle cx="131" cy="191" r="3.5" fill="#FFFFFF"/><circle cx="171" cy="191" r="3.5" fill="#FFFFFF"/><ellipse cx="116" cy="214" rx="9" ry="5" fill="#F29C9C" opacity="0.7"/><ellipse cx="180" cy="214" rx="9" ry="5" fill="#F29C9C" opacity="0.7"/>'
const BLOBS := {
	"slime": {
		"gait": "blob_bounce", "sound": "duck", "pop": ["#8EE07A", "#C6F2A8", "#5BBF4E"],
		"pins": {"eyes": [148, 198], "ear-l": [122, 152], "tail": [210, 250]},
		"parts": {
			"body": '<path d="M70 262 C64 212 96 150 150 150 C204 150 236 212 230 262 Z" fill="#8EE07A" %s/><ellipse cx="118" cy="182" rx="16" ry="9" fill="#FFFFFF" opacity="0.5"/>',
			"eyes": EYES,
			"ear-l": '<path d="M122 154 C116 132 112 120 104 112" fill="none" %s/><circle cx="104" cy="110" r="7" fill="#8EE07A" %s/>',
		},
	},
	"ghost": {
		"gait": "float", "sound": "otter", "pop": ["#F4F1FF", "#D9D2F5", "#B9AEE8"],
		"pins": {"eyes": [148, 190], "tail": [200, 250]},
		"parts": {
			"body": '<path d="M86 258 L86 170 C86 120 116 96 150 96 C184 96 214 120 214 170 L214 258 L194 242 L174 258 L150 242 L126 258 L106 242 Z" fill="#F4F1FF" %s/>',
			"eyes": '<ellipse cx="128" cy="176" rx="9" ry="12" fill="#3A2A22"/><ellipse cx="168" cy="176" rx="9" ry="12" fill="#3A2A22"/><circle cx="131" cy="171" r="3.5" fill="#FFFFFF"/><circle cx="171" cy="171" r="3.5" fill="#FFFFFF"/><ellipse cx="116" cy="194" rx="9" ry="5" fill="#F29C9C" opacity="0.7"/><ellipse cx="180" cy="194" rx="9" ry="5" fill="#F29C9C" opacity="0.7"/>',
			"mouth-open": '<ellipse cx="148" cy="214" rx="9" ry="12" fill="#6B4A3A"/>',
		},
	},
	"snake": {
		"gait": "slither", "sound": "hedgehog", "pop": ["#F2B45A", "#F8D48C", "#C97F2F"],
		"pins": {"eyes": [92, 214], "tail": [262, 246]},
		"parts": {
			"body": '<path d="M262 250 C230 262 200 236 172 250 C144 264 120 262 104 252 C78 252 62 236 64 214 C66 190 88 178 108 184 C126 190 132 212 126 236 C150 232 170 222 196 230 C222 238 246 232 268 236 Z" fill="#F2B45A" %s/><path d="M150 244 L160 236 M190 236 L200 230 M226 238 L236 234" fill="none" stroke="#C97F2F" stroke-width="4" stroke-linecap="round"/>',
			"eyes": '<ellipse cx="84" cy="208" rx="6" ry="8" fill="#3A2A22"/><ellipse cx="106" cy="208" rx="6" ry="8" fill="#3A2A22"/><circle cx="86" cy="205" r="2.5" fill="#FFFFFF"/><circle cx="108" cy="205" r="2.5" fill="#FFFFFF"/>',
			"tail": '<path d="M262 246 C274 244 282 236 286 228" fill="none" %s/>',
		},
	},
}


static func blob_kit(dest: String, which: String) -> String:
	# A slime (bounce, one antenna), a ghost (float, no head) or a snake
	# (slither), drawn in the cast's style: warm brown outline, blush.
	var b: Dictionary = BLOBS[which]
	DirAccess.make_dir_recursive_absolute(dest.path_join("parts"))
	for part in b.parts:
		var body: String = b.parts[part]
		while body.contains("%s"):
			body = body.replace("%s", LINE)
		var f := FileAccess.open(dest.path_join("parts/%s.svg" % part), FileAccess.WRITE)
		f.store_string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 280" width="300" height="280">%s</svg>' % body)
		f.close()
	_json(dest.path_join("custom.json"), {"schema": 2, "kind": "kit", "rev": 1, "name": which.capitalize(),
		"from": "test", "size": 1.0, "speed": 1.0, "visits": 1, "enabled": true, "sound": b.sound,
		"pop": b.pop, "seen": {}})
	_json(dest.path_join("kit.json"), {"schema": 1, "plan": "blob", "gait": b.gait, "faces": "left",
		"pins": b.pins, "made_with": "svg"})
	return dest


static func _json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
