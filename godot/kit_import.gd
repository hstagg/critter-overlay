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
##
## The kit page's own changes go on the staged kit and so survive Reload:
## joints the player dragged (move_pin(), within 4.7's box, kept in
## staged.moved and laid over the file's pins by with_moved()), and Where's
## its head? (staged.head_adj: a move and a stretch of the measured ellipse,
## so a redrawn head keeps the player's nudge; adjusted_head()).

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


static func stage(path: String, plan_hint := "", assign := {}) -> Dictionary:
	# assign: {layer name: part} for layers the player has named on the kit
	# page (C4); a layer given a part the file already has replaces it.
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
	for layer in assign:
		var to := str(assign[layer])
		if found.has(layer) and (to in pl.required or to in pl.optional):
			found[to] = found[layer]
			found.erase(layer)
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


# --- Joints and the head, from the kit page (C4, F1) ---------------------------------

const HIPS := ["hip-front", "hip-back", "hip"]
const HEAD_ADJ_MOVE := 60.0         # units the head's ellipse may move from its measure
const HEAD_ADJ_K := Vector2(0.5, 2.0)


static func neck_of(plan: String) -> String:
	return "neck-sit" if plan == "upright" else "neck-walk"


static func carries_head(plan: String, pin: String) -> bool:
	# The neck the head is drawn on (pins_panel.gd's rule): dragging it moves
	# the head's own pivot too, so the head stays where it was drawn.
	return pin == ("neck-walk" if plan == "side" else "neck-sit")


static func base_pins(staged: Dictionary) -> Dictionary:
	# Where each joint was before any drag: the file's or the template's,
	# with kit_data.gd's defaults for the rest. Vector2s.
	var p := KitData.pins({"plan": staged.plan, "pins": staged.get("file_pins", staged.pins)})
	p.erase("warnings")
	return p


static func pin_box(staged: Dictionary, pin: String) -> Rect2:
	# 4.7: within PIN_SLACK of where it was, inside the frame.
	var c: Vector2 = base_pins(staged).get(pin, Vector2(150, 150))
	var r := Rect2(c - Vector2.ONE * KitData.PIN_SLACK, Vector2.ONE * KitData.PIN_SLACK * 2.0)
	return r.intersection(Rect2(Vector2.ZERO, KitData.FRAME))


static func pin_now(staged: Dictionary, pin: String) -> Vector2:
	var v = staged.pins.get(pin)
	if typeof(v) == TYPE_ARRAY and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return base_pins(staged).get(pin, Vector2(150, 150))


static func clamp_pin(staged: Dictionary, pin: String, p: Vector2) -> Vector2:
	# Where a joint dragged to p may go: inside its box, a hip below the neck.
	var r := pin_box(staged, pin)
	var q := p.clamp(r.position, r.end)
	if pin in HIPS:
		var neck := pin_now(staged, neck_of(staged.plan))
		q.y = maxf(q.y, minf(neck.y + 1.0, r.end.y))
	return q.round()


static func move_pin(staged: Dictionary, pin: String, p: Vector2) -> Vector2:
	# A dragged joint, in the file's frame, kept inside its box (and a hip
	# below the neck). Recorded in staged.moved. Returns where it went.
	if not staged.has("file_pins"):
		staged["file_pins"] = staged.pins.duplicate(true)
	var q := clamp_pin(staged, pin, p)
	if not staged.has("moved"):
		staged["moved"] = {}
	staged.moved[pin] = [q.x, q.y]
	if carries_head(staged.plan, pin):
		staged.moved["head"] = [q.x, q.y]
	staged.pins.merge(staged.moved, true)
	return q


static func with_moved(staged: Dictionary, moved: Dictionary) -> void:
	# After a (re)stage: the joints the player dragged, over the file's.
	staged["file_pins"] = staged.pins.duplicate(true)
	staged["moved"] = {}
	for k in moved:
		if k != "head":
			move_pin(staged, k, Vector2(moved[k][0], moved[k][1]))
	if moved.has("head") and not staged.moved.has("head"):
		staged.moved["head"] = moved["head"]
		staged.pins["head"] = moved["head"]


static func adjusted_head(m: Dictionary, adj: Dictionary) -> Dictionary:
	# The measured head ellipse moved by (dx, dy) and stretched by (kx, ky)
	# about its centre; the eyes stay where they were measured.
	var out := m.duplicate()
	if adj.is_empty():
		return out
	var dx := clampf(float(adj.get("dx", 0.0)), -HEAD_ADJ_MOVE, HEAD_ADJ_MOVE)
	var dy := clampf(float(adj.get("dy", 0.0)), -HEAD_ADJ_MOVE, HEAD_ADJ_MOVE)
	var kx := clampf(float(adj.get("kx", 1.0)), HEAD_ADJ_K.x, HEAD_ADJ_K.y)
	var ky := clampf(float(adj.get("ky", 1.0)), HEAD_ADJ_K.x, HEAD_ADJ_K.y)
	var cy := float(m.cy)
	out.cx = float(m.cx) + dx
	out.cy = cy + dy
	out.rx = float(m.rx) * kx
	out.ry = float(m.ry) * ky
	out.top = out.cy + (float(m.top) - cy) * ky
	out.chin = out.cy + (float(m.chin) - cy) * ky
	out.side = clampf(0.5 + 0.5 * out.rx / 92.0, 0.8, 1.0)
	return out


static func head_adj_between(measured: Dictionary, wanted: Dictionary) -> Dictionary:
	# The adjustment that takes one head to another (a kept critter's head,
	# laid over a new version of its drawing).
	if measured.is_empty() or wanted.is_empty():
		return {}
	return {"dx": float(wanted.cx) - float(measured.cx), "dy": float(wanted.cy) - float(measured.cy),
		"kx": float(wanted.rx) / maxf(1.0, float(measured.rx)), "ky": float(wanted.ry) / maxf(1.0, float(measured.ry))}


# --- Writing ---------------------------------------------------------------------------

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
		"pins": staged.pins.duplicate(true), "made_with": staged.made_with, "template": staged.template}
	if not staged.get("moved", {}).is_empty():
		kit["moved"] = staged.moved.duplicate(true)   # the joints dragged on the kit page, in the file's frame
	_json(dest.path_join("kit.json"), kit)
	var d := {"schema": 2, "kind": "kit", "rev": 1, "name": name.strip_edges().left(40),
		"made": int(Time.get_unix_time_from_system()), "from": "import", "size": 1.0, "speed": 1.0,
		"visits": 1, "enabled": true, "sound": "kitten", "seen": {}}
	d.merge(extra, true)
	_json(dest.path_join("custom.json"), d)
	ground(dest, kit)
	# F1: the head's metrics, for clothes, with the player's adjustment from
	# Where's its head? (staged.head_adj). staged.head_measured keeps the
	# measure, for the kit page to draw and adjust from.
	kit = JSON.parse_string(FileAccess.get_file_as_string(dest.path_join("kit.json")))
	var r := KitData.build(dest, kit)
	staged["head_measured"] = r.head.duplicate()
	kit["head"] = adjusted_head(r.head, staged.get("head_adj", {}))
	_json(dest.path_join("kit.json"), kit)
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
