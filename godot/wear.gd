extends RefCounted
## The clothes catalogue (design: Focus Economy, section 7, "Shop"). Each item
## is drawn once per species, fitted to its head, by design/wear/build.py,
## into art/wear/<item>/<species>.svg, and rides the head through every pose.
## A critter wears at most one item per slot.
##
## Some items belong to one species (a fourth field): they are sold only once
## that species has been met, and are drawn only for critters whose design
## is final (design decision, 2026-10-06).
##
## Homemade kit critters ("custom:<id>") have no shipped files: their clothes
## are drawn at runtime from their own head (wear_draw.gd, the port of
## build.py; docs/custom-critters-build-plan.md, P14 and F2). They never get
## species-only items or FITS_BADLY ones, and a hood hides KIT_HOOD_HIDES.
## Frame critters wear nothing yet (F3).
##
## Prices are by hours of focus, a wide spread (game design rules, D28): at
## about 115 berries a steady focus hour (tools/economy_sim.py; fewer in a
## first session), small 50 is about half an hour, medium 250 a couple of
## hours, large 1,500 a working day or two, a showpiece 8,000 about 70 hours
## and a perk 20,000 about 175: something to buy straight away, and goals
## that take weeks.

const WearDraw := preload("res://wear_draw.gd")

const PRICES := {"small": 50, "medium": 250, "large": 1500, "showpiece": 8000, "perk": 20000}   # D28 (2026-10-26)

# Perk items (design decision, 2026-10-06): the critter wearing one gets something
# extra. A behaviour joins its idles; luck multiplies the luck that species'
# visitors roll with.
const PERKS := {
	"disco_headphones": {"behaviour": "dance", "text": "Dances now and then"},
	"aviator_cap": {"behaviour": "fly", "text": "Takes off and floats about"},
	"confetti_crown": {"behaviour": "celebrate", "text": "Celebrates with confetti"},
	"lucky_charm": {"luck": 1.5, "text": "Its kind arrive luckier"},
}

# Visitors bringing a present (design decision, 2026-10-06): the chance an arrival
# wears an item, by its tier (almost never Common, still rare at Legendary),
# and which item, cheaper ones likelier. One not yet owned is a free gift.
const BRING_CHANCE := {"common": 0.0002, "rare": 0.004, "epic": 0.012, "legendary": 0.03}
const BRING_PRICE_POWER := 0.75     # weight ~ (50 / price) ^ this

# Dyes (economy design: repeatable sinks). A dye swaps an item's main colour
# (art/wear/dyes.json, written by the generator) when its art is loaded. Each
# colour is bought once per item. Treats call a chosen species next.
const DYES := {
	"rose": ["Rose", "#F590B4"], "sky": ["Sky", "#7FBCF5"], "mint": ["Mint", "#86D9B0"],
	"sunshine": ["Sunshine", "#FFCF5C"], "lilac": ["Lilac", "#B59AF0"], "cocoa": ["Cocoa", "#B98A5A"],
	"midnight": ["Midnight", "#3B3346"],
}
const DYE_PRICE := 50
const TREAT_PRICE := 40
const SLOTS := ["neck", "face", "head"]   # drawn in this order, head on top

# Items hidden from homemade critters because they look wrong on some heads,
# filled in from the contact sheet (Admin, "Make the clothes contact sheet").
const FITS_BADLY: Array = []
# A homemade critter's parts a hood hides (P14): its ears, the tuft, and
# anything drawn over the head.
const KIT_HOOD_HIDES := ["ear-l", "ear-r", "tuft", "head-front"]

# id: [name, slot, tier, (only this species)], written by design/wear/build.py.
static var ITEMS: Dictionary = _load()


static func _load() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://art/wear/catalogue.json"))
	return d if typeof(d) == TYPE_DICTIONARY else {}


static var HIDES: Dictionary = _load_hides()
static var MAINS: Dictionary = _load_json("res://art/wear/dyes.json")


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func dyeable(id: String) -> bool:
	return MAINS.has(id)


static func svg(id: String, species: String, dye := "") -> String:
	# The item's art for this species, in a dye's colour if given.
	return _dyed(FileAccess.get_file_as_string("res://art/wear/%s/%s.svg" % [id, species]), id, dye)


static func svg_for_kit(id: String, metrics: Dictionary, dye := "") -> String:
	# The item drawn for a homemade critter's head (kit_data.gd head_metrics(),
	# in the head drawing's frame), in a dye's colour if given; "" for an
	# item kits can't wear.
	if not for_kits(id):
		return ""
	return _dyed(_drawn_to_size(id, metrics), id, dye)


# The kitten's head size, √(rx·ry) of design/wear/build.py SPECIES; the items
# are drawn for heads about this size.
const KIT_REF_HEAD := 82.5


static func _drawn_to_size(id: String, m: Dictionary) -> String:
	# The items have fixed sizes, so on a head smaller than the kitten's they
	# cover its face. For such a head the item is drawn on a copy enlarged to
	# the kitten's size about the head's centre, then scaled back down whole.
	# Larger heads are drawn as they are (wear_draw.gd places items on them).
	var s := sqrt(float(m.rx) * float(m.ry)) / KIT_REF_HEAD
	if s >= 1.0:
		return WearDraw.draw(id, m)
	var cx := float(m.cx)
	var cy := float(m.cy)
	var big := m.duplicate()
	for k in ["rx", "ry", "eye_dx", "eye_r"]:
		big[k] = float(m[k]) / s
	for k in ["eye_y", "chin", "top"]:
		if m.has(k):
			big[k] = cy + (float(m[k]) - cy) / s
	var text := WearDraw.draw(id, big)
	var open := text.find(">") + 1
	var close := text.rfind("</svg>")
	var g := '<g transform="translate(%.3f %.3f) scale(%.4f) translate(%.3f %.3f)">' % [cx, cy, s, -cx, -cy]
	return text.substr(0, open) + g + text.substr(open, close - open) + "</g></svg>"


static func _dyed(text: String, id: String, dye: String) -> String:
	if dye != "" and DYES.has(dye) and MAINS.has(id):
		text = text.replacen(MAINS[id], DYES[dye][1])
	return text


static func for_kits(id: String) -> bool:
	# Whether homemade critters may wear an item: not one species' own, not
	# on FITS_BADLY.
	return has(id) and only(id) == "" and not id in FITS_BADLY and id in WearDraw.IDS


static func _load_hides() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://art/wear/hides.json")) if FileAccess.file_exists("res://art/wear/hides.json") else null
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func hides(id: String, species: String) -> Array:
	# Parts of the wearer hidden while it is on (a hood hides the ears). For
	# a homemade critter, the hoods (the items that hide ears on some species)
	# hide KIT_HOOD_HIDES.
	if species.begins_with("custom:"):
		return KIT_HOOD_HIDES if HIDES.has(id) and for_kits(id) else []
	return HIDES.get(id, {}).get(species, [])


static func has(id: String) -> bool:
	return ITEMS.has(id)


static func item_name(id: String) -> String:
	return ITEMS[id][0] if ITEMS.has(id) else id


static func slot(id: String) -> String:
	return ITEMS[id][1] if ITEMS.has(id) else "head"


static func price(id: String) -> int:
	return PRICES[ITEMS[id][2]] if ITEMS.has(id) else 0


static func only(id: String) -> String:
	# The one species an item is for, or "".
	return ITEMS[id][3] if ITEMS.has(id) and ITEMS[id].size() > 3 else ""


static func unlocked(id: String, collection: Dictionary) -> bool:
	# A species' own item is on sale once that species has been met.
	var sp := only(id)
	if sp == "":
		return true
	for key in collection:
		if key.begins_with(sp + ":"):
			return true
	return false


static func perk_behaviours(items: Array) -> Array:
	var out := []
	for id in items:
		if PERKS.has(id) and PERKS[id].has("behaviour"):
			out.append(PERKS[id].behaviour)
	return out


static func luck_mult(items: Array) -> float:
	var m := 1.0
	for id in items:
		if PERKS.has(id):
			m *= float(PERKS[id].get("luck", 1.0))
	return m


static func fits(id: String, species: String) -> bool:
	# Whether this species can wear the item (and so be offered it). A
	# homemade critter can if it is a kit critter and the item is for kits.
	if species.begins_with("custom:"):
		var d: Dictionary = load("res://customs.gd").all.get(species, {})
		if str(d.get("kind", "")) == "frames":   # F3: only with its head marked
			return for_kits(id) and load("res://critters/kit/frame_data.gd").has_head(d.get("_clips", {}))
		return str(d.get("kind", "")) == "kit" and for_kits(id)
	return FileAccess.file_exists("res://art/wear/%s/%s.svg" % [id, species])


static func ordered(items: Array) -> Array:
	# One per slot, in drawing order.
	var by_slot := {}
	for id in items:
		if has(id):
			by_slot[slot(id)] = id
	var out := []
	for s in SLOTS:
		if by_slot.has(s):
			out.append(by_slot[s])
	return out
