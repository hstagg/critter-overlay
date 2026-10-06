extends RefCounted
## The clothes catalogue (design: Focus Economy, section 7, "Shop"). Each item
## is drawn once per species, fitted to its head, by design/wear/build.py,
## into art/wear/<item>/<species>.svg, and rides the head through every pose.
## A critter wears at most one item per slot.
##
## Some items belong to one species (a fourth field): they are sold only once
## that species has been met, and are drawn only for critters whose design
## is final (Harrison, 2026-10-06).
##
## Prices are by hours of work (economy design): small 50 berries (under an
## hour), medium 400 (one to three workdays), large 1,200 (about a week),
## showpiece 4,000 (two to four weeks).

const PRICES := {"small": 50, "medium": 400, "large": 1200, "showpiece": 4000}

# Dyes (economy design: repeatable sinks). A dye swaps an item's main colour
# (art/wear/dyes.json, written by the generator) when its art is loaded. Each
# colour is bought once per item. Treats call a chosen species next.
const DYES := {
	"rose": ["Rose", "#F590B4"], "sky": ["Sky", "#7FBCF5"], "mint": ["Mint", "#86D9B0"],
	"sunshine": ["Sunshine", "#FFCF5C"], "lilac": ["Lilac", "#B59AF0"], "cocoa": ["Cocoa", "#B98A5A"],
	"midnight": ["Midnight", "#3B3346"],
}
const DYE_PRICE := 100
const TREAT_PRICE := 60
const SLOTS := ["neck", "face", "head"]   # drawn in this order, head on top

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
	var text := FileAccess.get_file_as_string("res://art/wear/%s/%s.svg" % [id, species])
	if dye != "" and DYES.has(dye) and MAINS.has(id):
		text = text.replacen(MAINS[id], DYES[dye][1])
	return text


static func _load_hides() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://art/wear/hides.json")) if FileAccess.file_exists("res://art/wear/hides.json") else null
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func hides(id: String, species: String) -> Array:
	# Parts of the wearer hidden while it is on (a hood hides the ears).
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


static func fits(id: String, species: String) -> bool:
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
