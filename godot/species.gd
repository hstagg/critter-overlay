extends RefCounted
## The species table: one row per critter, carrying what v2.0 kept on each
## animal class (src/animals.py) and in its config defaults (src/config.py).
##
##   script       the rig, in critters/
##   sound        sounds/<name>.wav, played on pop and throw
##   pop          particle colours for the pop burst (v2.0 PARTICLE_COLORS)
##   idles        the behaviours it can do (v2.0 IDLE_WHITELIST, by v3 name)
##   rarity_max   the highest rarity tier it can spawn at (v2.0 rarity_max)
##   special      a visitor that does not come in groups (unicorn, golden kitten)
##
## Speeds, gait and proportions live in each species' own script, since they
## shape how it is drawn.

const DEFAULT := "kitten"

const DATA := {
	"kitten": {
		"script": preload("res://critters/kitten.gd"),
		"sound": "kitten",
		"pop": [Color8(230, 165, 105), Color8(245, 190, 130), Color8(255, 160, 160)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "scratch",
			"ear_flick", "tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen",
			"hunt", "chase_tail"],
		"rarity_max": "legendary",
		"special": false,
	},
	"rabbit": {
		"script": preload("res://critters/rabbit.gd"),
		"sound": "rabbit",
		"pop": [Color8(205, 198, 212), Color8(242, 180, 185), Color8(250, 248, 252)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "scratch",
			"ear_flick", "tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen",
			"nose_twitch", "stand_lookout"],
		"rarity_max": "legendary",
		"special": false,
	},
	"duckling": {
		"script": preload("res://critters/duckling.gd"),
		"sound": "duck",
		"pop": [Color8(248, 230, 80), Color8(255, 200, 50), Color8(240, 245, 220)],
		"idles": ["stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom", "scratch",
			"ear_flick", "tail_swish", "sneeze", "shake_off", "look_at_cursor", "listen",
			"preen", "peck_ground"],
		"rarity_max": "legendary",
		"special": false,
	},
}


static func has(id: String) -> bool:
	return DATA.has(id)


static func row(id: String) -> Dictionary:
	return DATA[id] if DATA.has(id) else DATA[DEFAULT]
