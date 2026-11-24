extends SceneTree
## Headless checks for svg_clean.gd (docs/custom-critters-build-plan.md, C2):
## the shipped templates split into their parts and pins; Inkscape,
## Affinity and Illustrator naming all match; hostile files are cleaned or
## refused; what comes out parses and draws.
## Run: godot --headless --path godot --script res://svg_clean_test.gd

const Clean := preload("res://svg_clean.gd")
const KitData := preload("res://critters/kit/kit_data.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func draws(svg: String) -> bool:
	var img := Image.new()
	return img.load_svg_from_string(svg, 0.5) == OK and img.get_used_rect().size.x > 0


const HEAD := '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 300 280" width="300" height="280">'
const DOT := '<circle cx="150" cy="150" r="40" fill="#F6C28F" stroke="#6B4A3A" stroke-width="4"/>'


func _init() -> void:
	# --- The templates: each splits into its plan's parts and pins.
	for plan in ["side", "front", "upright", "blob"]:
		var text := FileAccess.get_file_as_string("res://templates/%s-1.svg" % plan)
		var r := Clean.split(text)
		var pl: Dictionary = KitData.PLANS[plan]
		check(r.error == "" and r.dropped.is_empty(), "%s template splits cleanly (%s %s)" % [plan, r.error, r.dropped])
		check(r.template == "%s-1" % plan, "%s template names its version" % plan)
		var missing: Array = pl.required.filter(func(p): return not r.parts.has(p))
		check(missing.is_empty(), "%s template has every required part (missing %s)" % [plan, missing])
		var strays: Array = r.parts.keys().filter(func(p): return not (p in pl.required or p in pl.optional))
		check(strays.is_empty() and r.unmatched.is_empty(), "%s template has no strays (%s %s)" % [plan, strays, r.unmatched])
		check(r.pins.has("eyes") and r.pins.size() >= pl.pins.size(), "%s template's pins come through (%d)" % [plan, r.pins.size()])
		var bad := 0
		for p in r.parts:
			if not draws(r.parts[p]):
				bad += 1
		check(bad == 0, "every %s part draws on its own (%d don't)" % [plan, bad])

	# --- Other apps' layer names.
	var affinity := HEAD + '<g id="Walk_Body" serif:id="walk body">%s</g><g id="Head1" serif:id="Head">%s</g><g serif:id="Eyes">%s</g></svg>' % [DOT, DOT, DOT]
	var ra := Clean.split(affinity)
	check(ra.parts.has("walk-body") and ra.parts.has("head") and ra.parts.has("eyes"), "Affinity's serif:id names match (%s)" % str(ra.parts.keys()))
	var illustrator := HEAD + '<g id="leg_x5F_front_1_">%s</g><g id="leg_x5F_back">%s</g><g id="Eyes_x5F_closed_2_">%s</g><g id="Front_x20_Leg_x20_Far">%s</g></svg>' % [DOT, DOT, DOT, DOT]
	var ri := Clean.split(illustrator)
	check(ri.parts.has("leg-front") and ri.parts.has("leg-back") and ri.parts.has("eyes-closed") and ri.parts.has("leg-front-far"),
		"Illustrator's escaped ids match (%s)" % str(ri.parts.keys()))
	var inkscape := HEAD.replace("<svg ", '<svg xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" ') \
		+ '<g inkscape:groupmode="layer" inkscape:label="Tail (optional)" id="layer3" transform="translate(10 0)">%s</g>' % DOT \
		+ '<g inkscape:groupmode="layer" inkscape:label="Ear" id="layer4" style="display:none">%s</g>' % DOT \
		+ '<g inkscape:groupmode="layer" inkscape:label="Doodles" id="layer5">%s</g></svg>' % DOT
	var rk := Clean.split(inkscape)
	check(rk.parts.has("tail") and rk.parts.has("ear-l"), "Inkscape labels match, \"(optional)\" and aliases too (%s)" % str(rk.parts.keys()))
	check(rk.parts.get("tail", "").contains("translate(10 0)"), "a layer's transform is kept")
	check(not rk.parts.get("ear-l", "").contains("display:none"), "a hidden layer comes out shown")
	check(rk.unmatched.is_empty() and rk.parts.has("doodles"), "an unknown layer is kept under its own name for the importer to ask about")
	check(Clean.normalise("Body_x5F_walk_3_") == "walk-body", "an alias after unescaping")
	var nolayers := Clean.split(HEAD + DOT + "</svg>")
	check(nolayers.error.begins_with("No layers found"), "a drawing with no layers says so")

	# --- Hostile files.
	var bomb := '<?xml version="1.0"?><!DOCTYPE svg [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">]>' + HEAD + '<g id="body"><text>&b;</text></g></svg>'
	check(Clean.clean(bomb).error != "", "an entity bomb is refused")
	var nasty := HEAD + '<script>alert(1)</script><g id="body" onload="alert(1)">' + DOT \
		+ '<use xlink:href="http://example.com/x.svg#a"/><use href="file:///C:/secret.svg#b"/>' \
		+ '<foreignObject><div xmlns="http://www.w3.org/1999/xhtml">hi</div></foreignObject>' \
		+ '<image href="data:image/png;base64,AAAA" width="10" height="10"/>' \
		+ '<rect width="10" height="10" fill="url(http://example.com/g)" style="fill:url(https://x/y);stroke:#000"/>' \
		+ '<style>@import url(http://example.com/a.css); .a{fill:#f00}</style>' \
		+ '<text>Hi</text></g></svg>'
	var c := Clean.clean(nasty)
	check(c.error == "", "a file with nasties is cleaned, not refused")
	for bad in ["<script", "onload", "example.com", "file:///", "foreignObject", "<image", "@import", "https://"]:
		check(not c.svg.contains(bad), "%s is gone" % bad)
	check(c.svg.contains("<circle") and c.svg.contains(".a{fill:#f00}"), "the drawing and its own styles stay")
	check(c.dropped.size() >= 4, "what went is said in plain words (%s)" % str(c.dropped))
	check(draws(c.svg), "the clean file draws")
	var many := HEAD
	for i in 50000:
		many += '<path d="M0 0h1v1z"/>'
	many += "</svg>"
	check(Clean.clean(many).error != "", "50,000 paths are refused")
	var big := HEAD + "<!--" + "x".repeat(10 * 1024 * 1024) + "--></svg>"
	check(Clean.clean(big).error.contains("2 MB"), "10 MB is refused")
	check(Clean.clean("<html><body>hi</body></html>").error != "", "not an SVG is refused")
	check(Clean.clean("").error != "", "an empty file is refused")
	var round := Clean.clean(Clean.clean(nasty).svg)
	check(round.error == "" and round.svg == c.svg, "cleaning is stable: the clean output re-parses to itself")

	print("SVG CLEAN TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
