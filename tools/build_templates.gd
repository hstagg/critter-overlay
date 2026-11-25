extends SceneTree
## Builds the Part kit templates (docs/custom-critters-build-plan.md, C1):
## godot/templates/<plan>-1.svg and <plan>-1-guide.png, one per body plan.
##
##   godot --headless --path godot --script <abs path>/tools/build_templates.gd
##
## Each template is the plan's example critter (the kitten, otter, duckling,
## or the slime), split into one Inkscape layer per part, named with the
## part (and "(optional)" for optional parts), so an untouched template
## imports as that critter. Under the parts: a locked guide layer (the
## critter faint, the frame, the ground line, notes). On top: a "pins" layer
## of small named circles. Layers for poses other than the one the template
## shows are hidden. The PNG is the same picture at 2x (600 x 560) for
## raster apps.
##
## A published version never changes (P22): a change is a new file, -2.

const Fixtures := preload("res://critters/kit/fixtures.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const VERSION := 1
const OUT := "res://templates/"

# The pose each template shows; the parts of other poses are hidden layers.
const SHOWN := {
	"side": ["walk-body", "leg-front", "leg-back", "leg-front-far", "leg-back-far", "head", "eyes",
		"ear-l", "ear-r", "tail", "head-front", "wing", "back-extra", "front-extra"],
	"front": ["body", "foot-l", "foot-r", "paws", "head", "eyes", "ear-l", "ear-r", "tail", "head-front", "front-extra"],
	"upright": ["body", "foot-l", "foot-r", "head", "eyes", "wing-l", "wing-r", "tuft", "head-front", "front-extra"],
	"blob": ["body", "eyes", "head", "ear-l", "ear-r", "tail", "head-front", "back-extra"],
}
# Drawing order, back to front (the rigs' order).
const ORDER := ["tail", "leg-front-far", "leg-back-far", "leg-far", "back-extra", "body", "foot-l", "foot-r",
	"walk-body", "loaf-body", "stand-body", "paws", "front-extra", "wing-l", "wing-r", "wing", "wing-side",
	"leg-front", "leg-back", "leg-near", "ear-l", "ear-r", "tuft", "head", "eyes", "eyes-closed", "mouth-open",
	"nose", "head-side", "eye-side", "eye-side-closed", "loaf-eyes", "loaf-eyes-closed", "head-front",
	"groom-paws", "scratch-foot"]
# Side-on: the kitten's head and tail are drawn where it sits; the template
# shows it walking, so they are moved there (the rig is the same either way).
const HEAD_PARTS := ["head", "eyes", "eyes-closed", "ear-l", "ear-r", "mouth-open", "nose", "head-front"]
const NOTES := {
	"side": "Side-on: draw it walking, facing left, feet on the line.",
	"front": "Faces you: draw it sitting facing you. Walking parts are hidden layers.",
	"upright": "Upright: draw it standing facing you, on the line.",
	"blob": "Blob: no legs. Draw it facing left, resting on the line.",
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var tmp := "user://template_build"
	for plan in ["side", "front", "upright", "blob"]:
		var dest := tmp.path_join(plan)
		match plan:
			"side":
				Fixtures.kitten_kit(dest)
			"front":
				Fixtures.otter_kit(dest)
			"upright":
				Fixtures.duckling_kit(dest)
			"blob":
				Fixtures.blob_kit(dest, "slime")
		var kit = JSON.parse_string(FileAccess.get_file_as_string(dest.path_join("kit.json")))
		var svg := template(plan, dest, kit)
		var name := "%s-%d" % [plan, VERSION]
		var f := FileAccess.open(OUT + name + ".svg", FileAccess.WRITE)
		f.store_string(svg)
		f.close()
		var img := Image.new()
		img.load_svg_from_string(svg, 2.0)
		img.save_png(ProjectSettings.globalize_path(OUT + name + "-guide.png"))
		print("TEMPLATE ", name, " ", img.get_size())
	_remove(ProjectSettings.globalize_path(tmp))
	quit()


func _remove(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_remove(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func inner(path: String) -> String:
	var s := FileAccess.get_file_as_string(path)
	var a := s.find(">", s.find("<svg")) + 1
	return s.substr(a, s.rfind("</svg>") - a)


func template(plan: String, folder: String, kit: Dictionary) -> String:
	var pl: Dictionary = KitData.PLANS[plan]
	var pins: Dictionary = kit.pins.duplicate(true)
	var shift := {}
	if plan == "side":
		var d := Vector2(pins["neck-walk"][0] - pins["head"][0], pins["neck-walk"][1] - pins["head"][1])
		var t := Vector2(pins["tail-walk"][0] - pins["tail"][0], pins["tail-walk"][1] - pins["tail"][1])
		for p in HEAD_PARTS:
			shift[p] = d
			if pins.has(p):
				pins[p] = [pins[p][0] + d.x, pins[p][1] + d.y]
		pins["head"] = pins["neck-walk"]
		shift["tail"] = t
		pins["tail"] = pins["tail-walk"]
	# Legs drawn in one place and hung on their hips (the kitten's) are drawn
	# on their hips here, so the artist sees each one where it goes.
	var hips := {"leg-front": "hip-front", "leg-back": "hip-back", "leg-front-far": "hip-front-far",
		"leg-back-far": "hip-back-far", "leg-near": "hip", "leg-far": "hip-far"}
	for leg in hips:
		if pins.has(leg) and pins.has(hips[leg]):
			var h: Array = pins[hips[leg]]
			shift[leg] = Vector2(h[0] - pins[leg][0], h[1] - pins[leg][1])
			pins[leg] = h
	var layers := ""
	var faint := ""
	for part in ORDER:
		var file := folder.path_join("parts/%s.svg" % part)
		var known: bool = part in pl.required or part in pl.optional
		if not known:
			continue
		var art := inner(file) if FileAccess.file_exists(file) else ""
		if shift.has(part) and art != "":
			art = '<g transform="translate(%s %s)">%s</g>' % [shift[part].x, shift[part].y, art]
		var label: String = part if part in pl.required else part + " (optional)"
		var shown: bool = part in SHOWN[plan]
		layers += '<g inkscape:groupmode="layer" inkscape:label="%s" id="%s"%s>%s</g>\n' % [
			label, part, "" if shown else ' style="display:none"', art]
		if shown and art != "":
			faint += art
	var pin_marks := ""
	for k in pins:
		pin_marks += '<circle id="pin-%s" cx="%s" cy="%s" r="3" fill="#E0457B" stroke="#FFFFFF" stroke-width="1"/>' % [k, pins[k][0], pins[k][1]]
	var guide := '<g inkscape:groupmode="layer" inkscape:label="guide" id="guide" sodipodi:insensitive="true">' \
		+ '<rect x="0.5" y="0.5" width="299" height="279" fill="none" stroke="#B8A8A0" stroke-width="1" stroke-dasharray="4 4"/>' \
		+ '<line x1="0" y1="262" x2="300" y2="262" stroke="#8FB8E0" stroke-width="1.5"/>' \
		+ '<g opacity="0.22">%s</g>' % faint \
		+ '<text x="8" y="16" font-size="9" fill="#7A6A62" font-family="sans-serif">%s Keep lines bold; overlap parts at the joints.</text>' % NOTES[plan] \
		+ '<text x="8" y="276" font-size="8" fill="#7A6A62" font-family="sans-serif">Ground line: y 262. Pins (pink dots) are the joints: move them if your joints are elsewhere.</text>' \
		+ '</g>\n'
	return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" ' \
		+ 'xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" viewBox="0 0 300 280" width="300" height="280" ' \
		+ 'data-critter-template="%s-%d" data-gait="%s">\n' % [plan, VERSION, kit.gait]) \
		+ guide + layers \
		+ '<g inkscape:groupmode="layer" inkscape:label="pins" id="pins">%s</g>\n</svg>\n' % pin_marks
