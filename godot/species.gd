extends RefCounted
## The species table: one row per critter, carrying what v2.0 kept on each
## animal class (src/animals.py) and in its config defaults (src/config.py).
##
##   script       the rig, in critters/
##   sound        sounds/<name>.wav, played on pop and throw
##   pop          particle colours for the pop burst (v2.0 PARTICLE_COLORS)
##   idles        the behaviours it can do (v2.0 IDLE_WHITELIST, by v3 name)
##   rarity_max   the highest tier it can arrive at: Epic for the everyday
##                species, Legendary for the special visitors
##   versions     its Rare and Epic looks: tier -> art folder in art/<species>/
##                (none yet: it arrives in its Common look with the tier's glow)
##   special      a Legendary visitor, never in groups (unicorn, golden kitten);
##                its colour variants are its script's VARIANTS
##   gait         how it walks, in words, for Settings
##
## Speeds, gait and proportions live in each species' own script, since they
## shape how it is drawn.

const DEFAULT := "kitten"

const DATA := {
	"kitten": {
		"gait": "a pounce-pause",
		"script": preload("res://critters/kitten.gd"),
		"sound": "kitten",
		"pop": [Color8(230, 165, 105), Color8(245, 190, 130), Color8(255, 160, 160)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "scratch",
			"ear_flick", "tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen",
			"hunt", "chase_tail"],
		"rarity_max": "epic",
		"special": false,
	},
	"rabbit": {
		"gait": "a hop",
		"script": preload("res://critters/rabbit.gd"),
		"sound": "rabbit",
		"pop": [Color8(205, 198, 212), Color8(242, 180, 185), Color8(250, 248, 252)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "scratch",
			"ear_flick", "tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen",
			"nose_twitch", "stand_lookout"],
		"rarity_max": "epic",
		"special": false,
	},
	"duckling": {
		"gait": "a waddle",
		"script": preload("res://critters/duckling.gd"),
		"sound": "duck",
		"pop": [Color8(248, 230, 80), Color8(255, 200, 50), Color8(240, 245, 220)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "scratch",
			"ear_flick", "tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen",
			"preen", "peck_ground"],
		"rarity_max": "epic",
		"special": false,
	},
	"hedgehog": {
		"gait": "a snuffle",
		"script": preload("res://critters/hedgehog.gd"),
		"sound": "hedgehog",
		"pop": [Color8(135, 92, 60), Color8(205, 165, 122), Color8(245, 220, 180)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "scratch",
			"ear_flick", "sneeze", "shake_off", "look_at_cursor", "listen",
			"snuffle", "ball_up"],
		"rarity_max": "epic",
		"special": false,
	},
	"turtle": {
		"gait": "a plod",
		"script": preload("res://critters/turtle.gd"),
		"sound": "turtle",
		"pop": [Color8(75, 148, 75), Color8(100, 175, 90), Color8(180, 220, 100)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "sneeze", "shake_off",
			"look_at_cursor", "listen", "head_tuck"],
		"versions": {"rare": "sprout", "epic": "hatchling"},
		"rarity_max": "epic",
		"special": false,
	},
	"squirrel": {
		"gait": "a dart and freeze",
		"script": preload("res://critters/squirrel.gd"),
		"sound": "squirrel",
		"pop": [Color8(224, 130, 63), Color8(244, 176, 122), Color8(255, 240, 221)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "ear_flick",
			"tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen", "chitter"],
		"versions": {"rare": "cinnamon"},
		"rarity_max": "epic",
		"special": false,
	},
	"otter": {
		"gait": "a slide",
		"script": preload("res://critters/otter.gd"),
		"sound": "otter",
		"pop": [Color8(125, 85, 55), Color8(192, 158, 125), Color8(215, 195, 168)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "ear_flick",
			"tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen", "belly_roll"],
		"rarity_max": "epic",
		"special": false,
	},
	"panda": {
		"gait": "a lumber",
		"script": preload("res://critters/panda.gd"),
		"sound": "panda",
		"pop": [Color8(242, 242, 242), Color8(59, 52, 55), Color8(160, 160, 160)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "ear_flick",
			"sneeze", "shake_off", "look_at_cursor", "listen", "panda_roll"],
		"versions": {"rare": "bamboo", "epic": "brown"},
		"rarity_max": "epic",
		"special": false,
	},
	# Special visitors: Legendary only, never in groups, each in secret
	# colour tiers chosen by its own script (VARIANTS).
	"unicorn": {
		"gait": "a glide",
		"script": preload("res://critters/unicorn.gd"),
		"sound": "unicorn",
		"pop": [Color8(245, 166, 200), Color8(198, 156, 240), Color8(255, 240, 170)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "tail_swish", "sneeze",
			"shake_off", "look_at_cursor", "listen", "prance"],
		"rarity_max": "legendary",
		"special": true,
	},
	"golden_kitten": {
		"gait": "a pounce-pause",
		"script": preload("res://critters/golden_kitten.gd"),
		"sound": "golden_kitten",
		"pop": [Color8(250, 210, 96), Color8(255, 240, 180), Color8(214, 150, 40)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "scratch",
			"ear_flick", "tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen",
			"hunt", "chase_tail"],
		"rarity_max": "legendary",
		"special": true,
	},
}


static func is_special(id: String) -> bool:
	return bool(row(id).get("special", false))


static func version_for(id: String, tier: String) -> String:
	# The art folder for this species at this tier, "" for its Common look.
	return row(id).get("versions", {}).get(tier, "")


static func variants(id: String) -> Array:
	# A Legendary visitor's colour variants, commonest first.
	var consts: Dictionary = row(id)["script"].get_script_constant_map()
	if not consts.has("VARIANTS"):
		return []
	return consts["VARIANTS"].map(func(v): return v[0])


static func has(id: String) -> bool:
	return DATA.has(id)


static func row(id: String) -> Dictionary:
	return DATA[id] if DATA.has(id) else DATA[DEFAULT]
