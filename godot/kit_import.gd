extends RefCounted
## Turning a player's file into a kit (docs/custom-critters-build-plan.md,
## C4): the part of the importer with no screens, so the screens (after the
## C0 design session) only show what stage() found and call write().
##
## stage(path): reads a layered SVG (svg_clean.gd) or raster parts
## (raster_kit.gd), works out the body plan (the template's own mark, else
## the parts drawn), and lists what it found, what is missing, what didn't
## match a part and what was taken out. Pins the file doesn't carry (raster
## apps can't) come from the plan's template.
##
## write(staged, name, dest): a kit folder (custom.json, kit.json, parts/),
## moved so its main pose stands on the ground line (4.7 grounding), ready
## for customs.gd add_folder().

const Clean := preload("res://svg_clean.gd")
const Raster := preload("res://raster_kit.gd")
const KitData := preload("res://critters/kit/kit_data.gd")

const GROUND_SLACK := 6.0   # units: outlines and soft edges hang below the line
const MAIN_POSE := {"side": "walk", "blob": "walk", "front": "sit", "upright": "sit"}


static func template_pins(plan: String) -> Dictionary:
	var path := "res://templates/%s-1.svg" % plan
	if not FileAccess.file_exists(path):
		return {}
	return Clean.split(FileAccess.get_file_as_string(path)).pins


static func guess_plan(parts: Array) -> String:
	if "leg-near" in parts:
		return "upright"
	if "walk-body" in parts and ("leg-front" in parts or "leg-back" in parts):
		return "front" if "body" in parts and "head-side" in parts else "side"
	if "body" in parts and not ("leg-front" in parts or "leg-back" in parts):
		return "blob"
	return "side"


static func stage(path: String, plan_hint := "") -> Dictionary:
	var out := {"plan": "", "gait": "", "parts": {}, "pins": {}, "unmatched": [], "missing": [],
		"dropped": [], "warnings": [], "error": "", "template": "", "made_with": ""}
	var found := {}
	var ext := path.get_extension().to_lower()
	if ext == "svg":
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			out.error = "That file can't be opened."
			return out
		if f.get_length() > Clean.MAX_BYTES:
			out.error = "That drawing is over 2 MB."
			return out
		var text := Clean.text_of(f.get_buffer(f.get_length()))
		if text == "":
			out.error = "That file isn't a drawing saved as text (SVG)."
			return out
		var r := Clean.split(text)
		if r.error != "":
			out.error = r.error
			return out
		for p in r.parts:
			found[p] = {"svg": r.parts[p]}
		out.pins = r.pins
		out.unmatched = r.unmatched
		out.dropped = r.dropped
		out.template = r.template
		out.gait = r.gait
		out.made_with = "svg"
	else:
		var r := Raster.read(path)
		if r.error != "":
			out.error = r.error
			return out
		for p in r.parts:
			found[p] = {"png": r.parts[p]}
		out.unmatched = r.unmatched
		out.made_with = "ora" if ext == "ora" else "png"
	var plan := plan_hint
	if plan == "" and out.template != "":
		plan = out.template.get_slice("-", 0)
	if not KitData.PLANS.has(plan):
		plan = guess_plan(found.keys())
	out.plan = plan
	var pl: Dictionary = KitData.PLANS[plan]
	for p in found:
		if p in pl.required or p in pl.optional:
			out.parts[p] = found[p]
		else:
			out.unmatched.append(p)
	out.missing = pl.required.filter(func(p): return not out.parts.has(p))
	# Pins the file hasn't got: the template's.
	var defaults := template_pins(plan)
	for k in defaults:
		if not out.pins.has(k):
			out.pins[k] = defaults[k]
	if not out.gait in pl.gaits:
		out.gait = pl.gaits[0]
	return out


static func write(staged: Dictionary, name: String, dest: String, extra := {}) -> String:
	# The kit folder at dest. Returns "" if the kit can't be made (missing
	# parts), else dest.
	if not staged.missing.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(dest.path_join("parts"))
	for p in staged.parts:
		var part: Dictionary = staged.parts[p]
		if part.has("svg"):
			var f := FileAccess.open(dest.path_join("parts/%s.svg" % p), FileAccess.WRITE)
			f.store_string(part.svg)
			f.close()
		else:
			part.png.save_png(dest.path_join("parts/%s.png" % p))
	var kit := {"schema": 1, "plan": staged.plan, "gait": staged.gait, "faces": "left",
		"pins": staged.pins, "made_with": staged.made_with, "template": staged.template}
	_json(dest.path_join("kit.json"), kit)
	var d := {"schema": 2, "kind": "kit", "rev": 1, "name": name.strip_edges().left(40),
		"made": int(Time.get_unix_time_from_system()), "from": "import", "size": 1.0, "speed": 1.0,
		"visits": 1, "enabled": true, "sound": "kitten", "seen": {}}
	d.merge(extra, true)
	_json(dest.path_join("custom.json"), d)
	ground(dest, kit)
	return dest


static func ground(folder: String, kit: Dictionary) -> void:
	# 4.7: the main pose's lowest drawn point onto the ground line, by moving
	# every part and pin together (so the rig is unchanged), if it is off.
	var r := KitData.build(folder, kit)
	var pose: String = MAIN_POSE.get(kit.plan, "walk")
	var dy := KitData.GROUND - KitData._lowest(r, pose, true)
	if absf(dy) <= GROUND_SLACK:
		return   # the cast's feet sit a little into the line too
	for p in DirAccess.get_files_at(folder.path_join("parts")):
		var path := folder.path_join("parts/" + p)
		if p.ends_with(".svg"):
			var s := FileAccess.get_file_as_string(path)
			var a := s.find(">", s.find("<svg")) + 1
			var b := s.rfind("</svg>")
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(s.substr(0, a) + '<g transform="translate(0 %s)">' % dy + s.substr(a, b - a) + "</g></svg>")
			f.close()
		elif p.ends_with(".png"):
			var img := Image.load_from_file(path)
			var k := float(img.get_height()) / KitData.FRAME.y
			var moved := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
			moved.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, roundi(dy * k)))
			moved.save_png(path)
	for k in kit.pins:
		kit.pins[k] = [kit.pins[k][0], kit.pins[k][1] + dy]
	_json(folder.path_join("kit.json"), kit)


static func _json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
