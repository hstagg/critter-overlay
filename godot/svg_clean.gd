extends RefCounted
## Makes a player's SVG safe to keep, and splits a layered drawing into kit
## parts (docs/custom-critters-build-plan.md, C2; problems P7, P8, P10).
##
## clean(text): parses with XMLParser and writes back only what is on the
## whitelist: drawing elements and presentation attributes, links only to
## things inside the file (url(#id), href="#id"). Scripts, foreign objects,
## pictures, text, entities and anything unknown are left out, and the
## result says what went, in plain words. Over MAX_BYTES or MAX_ELEMENTS is
## refused.
##
## split(text): the drawing's top-level groups are its layers. Each layer's
## name (Inkscape's label, Affinity's serif:id, or the id, with Illustrator's
## _x5F_ escapes and _1_ suffixes undone) is matched to a part name, through
## ALIASES for the common other names. Each part comes back as a whole SVG:
## the document's viewBox and <defs>, and only that layer (its transform
## kept, never hidden). A "pins" layer gives the pins (circles named
## pin-<name>); a "guide" layer is skipped.

const MAX_BYTES := 2 * 1024 * 1024
const MAX_ELEMENTS := 4000

const ELEMENTS := ["svg", "g", "path", "circle", "ellipse", "rect", "polygon", "polyline", "line",
	"defs", "clipPath", "mask", "linearGradient", "radialGradient", "stop", "use", "style",
	"filter", "feGaussianBlur"]
# Left out without a word: editor bookkeeping.
const QUIET := ["title", "desc", "metadata", "sodipodi:namedview", "inkscape:perspective",
	"inkscape:path-effect", "rdf:RDF"]
const SAID := {
	"text": "Text isn't drawn: convert text to paths before exporting.",
	"tspan": "Text isn't drawn: convert text to paths before exporting.",
	"image": "Pictures inside a drawing aren't used: draw the part instead.",
	"script": "A script was taken out.",
	"foreignObject": "Embedded web content was taken out.",
	"pattern": "Pattern fills aren't supported, so they were left out.",
	"symbol": "Symbols weren't used: expand them before exporting.",
	"marker": "Line markers (arrowheads) were left out.",
}
const ATTRS := ["id", "class", "d", "x", "y", "width", "height", "cx", "cy", "r", "rx", "ry",
	"x1", "y1", "x2", "y2", "points", "transform", "fill", "stroke", "stroke-width",
	"stroke-linejoin", "stroke-linecap", "stroke-miterlimit", "stroke-dasharray",
	"stroke-dashoffset", "stroke-opacity", "fill-opacity", "fill-rule", "clip-rule", "opacity",
	"clip-path", "mask", "filter", "offset", "stop-color", "stop-opacity", "gradientUnits",
	"gradientTransform", "spreadMethod", "fx", "fy", "fr", "viewBox", "preserveAspectRatio",
	"clipPathUnits", "maskUnits", "maskContentUnits", "href", "xlink:href", "stdDeviation",
	"display", "visibility", "style", "inkscape:label", "inkscape:groupmode", "serif:id",
	"color", "xmlns", "xmlns:xlink", "xmlns:inkscape", "xmlns:sodipodi", "xmlns:serif",
	"data-critter-template", "data-gait", "version"]
const ALIASES := {
	"body-walk": "walk-body", "walking-body": "walk-body", "walk": "walk-body",
	"sit-body": "body", "sitting-body": "body", "sit": "body", "sitting": "body",
	"loaf": "loaf-body", "nap": "loaf-body", "nap-body": "loaf-body", "sleep": "loaf-body",
	"stand": "stand-body", "standing": "stand-body",
	"eye": "eyes", "eyes-open": "eyes", "eyes-shut": "eyes-closed", "closed-eyes": "eyes-closed",
	"eye-closed": "eyes-closed", "blink": "eyes-closed",
	"mouth": "mouth-open", "open-mouth": "mouth-open", "beak-open": "mouth-open",
	"front-leg": "leg-front", "back-leg": "leg-back", "hind-leg": "leg-back", "leg-hind": "leg-back",
	"front-leg-far": "leg-front-far", "back-leg-far": "leg-back-far", "far-front-leg": "leg-front-far",
	"far-back-leg": "leg-back-far", "leg": "leg-near", "near-leg": "leg-near", "far-leg": "leg-far",
	"ear": "ear-l", "left-ear": "ear-l", "ear-left": "ear-l", "right-ear": "ear-r", "ear-right": "ear-r",
	"face": "head", "face-side": "head-side", "side-head": "head-side", "side-face": "head-side",
	"hat-layer": "head-front", "horns": "head-front", "mane": "back-extra", "shell": "back-extra",
	"bib": "front-extra", "wings": "wing", "wing-left": "wing-l", "wing-right": "wing-r",
	"left-wing": "wing-l", "right-wing": "wing-r", "pin": "pins", "joints": "pins",
}


# --- Text --------------------------------------------------------------------------

static func text_of(bytes: PackedByteArray) -> String:
	# The bytes as text, or "" if they aren't valid UTF-8. Checked here first:
	# the engine logs a line for every bad byte it meets, and a hostile file
	# can hold thousands (G3).
	var i := 0
	var n := bytes.size()
	while i < n:
		var b := bytes[i]
		var extra := 0
		if b < 0x80:
			i += 1
			continue
		elif b >= 0xC2 and b <= 0xDF:
			extra = 1
		elif b >= 0xE0 and b <= 0xEF:
			extra = 2
		elif b >= 0xF0 and b <= 0xF4:
			extra = 3
		else:
			return ""
		if i + extra >= n:
			return ""
		for k in extra:
			if bytes[i + 1 + k] & 0xC0 != 0x80:
				return ""
		i += 1 + extra
	return bytes.get_string_from_utf8()


# --- Cleaning -----------------------------------------------------------------------

static func clean(text: String) -> Dictionary:
	# {"svg": the clean text, "dropped": [plain words], "error": "" or why not}
	var r := parse(text)
	if r.error != "":
		return {"svg": "", "dropped": r.dropped, "error": r.error}
	return {"svg": write(r.root), "dropped": r.dropped, "error": ""}


static func parse(text: String) -> Dictionary:
	# The whitelisted tree: {"root": node, "dropped": [...], "error": ""}.
	# A node is {"tag", "attrs": {}, "kids": [], "text"}.
	var out := {"root": null, "dropped": [], "error": ""}
	if text.to_utf8_buffer().size() > MAX_BYTES:
		out.error = "That drawing is over 2 MB."
		return out
	if text.contains("<!ENTITY"):
		out.error = "That file defines entities, which aren't allowed."
		return out
	var xml := XMLParser.new()
	if xml.open_buffer(text.to_utf8_buffer()) != OK:
		out.error = "That file can't be read as SVG."
		return out
	var stack := []
	var quiet := 0                     # open guide layers: what is left out there isn't reported
	var skip := 0                      # depth inside a left-out element
	var count := 0
	var said := {}
	while xml.read() == OK:
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := xml.get_node_name()
				var empty := xml.is_empty()
				if skip > 0:
					if not empty:
						skip += 1
					continue
				if not tag in ELEMENTS or (tag == "use" and not _inside(xml)):
					if not tag in QUIET and quiet == 0:
						var why: String = SAID.get(tag, "A part the game can't draw (<%s>) was left out." % tag)
						if tag == "use":
							why = "A link to another file was taken out."
						if not said.has(why):
							said[why] = true
							out.dropped.append(why)
					if not empty:
						skip = 1
					continue
				count += 1
				if count > MAX_ELEMENTS:
					out.error = "That drawing has over %d shapes." % MAX_ELEMENTS
					return out
				var node := {"tag": tag, "attrs": _attrs(xml, out.dropped, said), "kids": [], "text": ""}
				node["guide"] = tag == "g" and normalise(layer_name(node)) in ["guide", "guides"]
				if node.guide and not empty:
					quiet += 1
				if stack.is_empty():
					if tag != "svg":
						out.error = "That file isn't an SVG drawing."
						return out
					out.root = node
				else:
					stack[-1].kids.append(node)
				if not empty:
					stack.append(node)
			XMLParser.NODE_ELEMENT_END:
				if skip > 0:
					skip -= 1
					continue
				if not stack.is_empty():
					if stack[-1].get("guide", false):
						quiet -= 1
					stack.pop_back()
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if skip == 0 and not stack.is_empty() and stack[-1].tag == "style":
					stack[-1].text += _safe_css(xml.get_node_data())
	if out.root == null and out.error == "":
		out.error = "That file isn't an SVG drawing."
	return out


static func _inside(xml: XMLParser) -> bool:
	# A <use> may only point at something in the same file.
	for i in xml.get_attribute_count():
		if xml.get_attribute_name(i) in ["href", "xlink:href"]:
			return xml.get_attribute_value(i).begins_with("#")
	return false


static func _attrs(xml: XMLParser, dropped: Array, said: Dictionary) -> Dictionary:
	var a := {}
	for i in xml.get_attribute_count():
		var k := xml.get_attribute_name(i)
		var v := xml.get_attribute_value(i)
		if not k in ATTRS and not k.begins_with("data-"):
			continue
		if k in ["href", "xlink:href"] and not v.begins_with("#"):
			continue
		if k == "style":
			v = _safe_css(v)
		elif v.contains("url(") and not _urls_inside(v):
			if not said.has("url"):
				said["url"] = true
				dropped.append("A link to another file was taken out.")
			continue
		if k == "filter" and v != "" and not v.begins_with("url(#"):
			continue
		a[k] = v
	return a


static func _urls_inside(v: String) -> bool:
	var i := v.find("url(")
	while i >= 0:
		var rest := v.substr(i + 4).strip_edges().trim_prefix("'").trim_prefix("\"")
		if not rest.begins_with("#"):
			return false
		i = v.find("url(", i + 4)
	return true


static func _safe_css(css: String) -> String:
	# No imports, no expressions, no links outside the file.
	var out := ""
	for decl in css.split(";"):
		var d := decl.strip_edges()
		if d == "":
			continue
		var low := d.to_lower()
		if low.contains("@import") or low.contains("expression(") or low.contains("javascript:"):
			continue
		if low.contains("url(") and not _urls_inside(d):
			continue
		out += d + ";"
	return out


static func write(n: Dictionary) -> String:
	var s: String = "<" + n.tag
	for k in n.attrs:
		s += ' %s="%s"' % [k, str(n.attrs[k]).xml_escape(true)]
	if n.kids.is_empty() and n.text == "":
		return s + "/>"
	s += ">" + str(n.text).xml_escape()
	for k in n.kids:
		s += write(k)
	return s + "</%s>" % n.tag


# --- Splitting into parts ---------------------------------------------------------

static func normalise(name: String) -> String:
	# One spelling for a layer name from any app (P7).
	var s := name
	var re := RegEx.create_from_string("_x([0-9A-Fa-f]{2})_")
	for m in re.search_all(s):
		s = s.replace(m.get_string(), char(m.get_string(1).hex_to_int()))
	s = s.to_lower().replace("(optional)", "").strip_edges()
	s = RegEx.create_from_string("(_\\d+_|_\\d+)$").sub(s, "")
	s = s.replace("_", "-").replace(" ", "-")
	while s.contains("--"):
		s = s.replace("--", "-")
	s = s.trim_prefix("-").trim_suffix("-")
	return ALIASES.get(s, s)


static func layer_name(n: Dictionary) -> String:
	for k in ["inkscape:label", "serif:id", "id"]:
		if n.attrs.has(k) and str(n.attrs[k]) != "":
			return str(n.attrs[k])
	return ""


static func split(text: String) -> Dictionary:
	# {"parts": {part: svg}, "pins": {name: [x, y]}, "unmatched": [names],
	#  "template": "side-1" or "", "gait": "", "dropped": [...], "error": ""}
	var out := {"parts": {}, "pins": {}, "unmatched": [], "template": "", "gait": "", "dropped": [], "error": ""}
	var r := parse(text)
	out.dropped = r.dropped
	if r.error != "":
		out.error = r.error
		return out
	var root: Dictionary = r.root
	out.template = str(root.attrs.get("data-critter-template", ""))
	out.gait = str(root.attrs.get("data-gait", ""))
	var defs := ""
	var head := {}
	for k in root.attrs:
		if not k.begins_with("data-") and not k.begins_with("inkscape:") and k != "serif:id":
			head[k] = root.attrs[k]
	if not head.has("xmlns"):
		head["xmlns"] = "http://www.w3.org/2000/svg"
	var layers := []
	for kid in root.kids:
		match kid.tag:
			"defs", "style":
				defs += write(kid)
			"g":
				layers.append(kid)
	for g in layers:
		var raw := layer_name(g)
		var part := normalise(raw)
		if part in ["guide", "guides", "background", "reference"]:
			continue
		if part == "pins":
			out.pins = _pins(g)
			continue
		if g.kids.is_empty():
			continue   # an empty layer: that part isn't drawn
		if part == "" or out.parts.has(part):
			out.unmatched.append(raw if raw != "" else "(a layer with no name)")
			continue
		var layer: Dictionary = g.duplicate(true)
		layer.attrs.erase("style")       # hidden in the template, shown as a part
		layer.attrs.erase("display")
		layer.attrs.erase("visibility")
		var doc := {"tag": "svg", "attrs": head, "kids": [], "text": ""}
		out.parts[part] = write(doc).trim_suffix("/>") + ">" + defs + write(layer) + "</svg>"
	if layers.is_empty():
		out.error = "No layers found. Start from a template, or name a group for each part."
	return out


static func _pins(g: Dictionary) -> Dictionary:
	# Circles named pin-<name> (or <name>), moved by a plain translate on the
	# layer if there is one.
	var off := _translate(str(g.attrs.get("transform", "")))
	var out := {}
	for c in g.kids:
		if c.tag != "circle":
			continue
		var name := layer_name(c).to_lower().trim_prefix("pin-").trim_prefix("pin_")
		if name == "":
			continue
		var at := Vector2(float(c.attrs.get("cx", "0")), float(c.attrs.get("cy", "0"))) + off \
			+ _translate(str(c.attrs.get("transform", "")))
		out[name] = [at.x, at.y]
	return out


static func _translate(t: String) -> Vector2:
	var m := RegEx.create_from_string("translate\\(\\s*([-0-9.eE]+)[\\s,]+([-0-9.eE]+)?").search(t)
	if m == null:
		return Vector2.ZERO
	return Vector2(float(m.get_string(1)), float(m.get_string(2)) if m.get_string(2) != "" else 0.0)
