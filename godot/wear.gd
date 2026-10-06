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
const SLOTS := ["neck", "face", "head"]   # drawn in this order, head on top

# id: [name, slot, tier, (only this species)]
const ITEMS := {
	"bow": ["Ribbon bow", "head", "small"],
	"bell_collar": ["Bell collar", "neck", "small"],
	"flower_clip": ["Daisy clip", "head", "small"],
	"glasses": ["Round glasses", "face", "small"],
	"beanie": ["Bobble beanie", "head", "medium"],
	"scarf": ["Knitted scarf", "neck", "medium"],
	"party_hat": ["Party hat", "head", "medium"],
	"bandana": ["Spotty bandana", "neck", "medium"],
	"strawberry_hat": ["Strawberry hat", "head", "large"],
	"wizard_hat": ["Wizard hat", "head", "large"],
	"fish_bowtie": ["Fishbone bow tie", "neck", "medium", "kitten"],
	"paw_beret": ["Paw-print beret", "head", "large", "kitten"],
	"carrot_clip": ["Carrot hair clip", "head", "small", "rabbit"],
	"carrot_scarf": ["Carrot scarf", "neck", "medium", "rabbit"],
	"sailor_hat": ["Sailor hat", "head", "medium", "duckling"],
	"swim_ring": ["Swim ring", "neck", "large", "duckling"],
}


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
