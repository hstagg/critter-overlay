extends "res://critters/kitten.gd"
## The golden kitten: a special visitor, Legendary only. It is the approved
## kitten rig in a polished gold coat with glitter (art/golden_kitten/, made by
## design/studio/golden_rig.py from the kitten's own parts), so it moves and
## behaves exactly as the kitten does. It comes in three secret tiers within
## Legendary, picked on arrival by VARIANTS' weights (commonest first):
## glitter; lynx (ear tufts, a ruff of cheek fur); royal (cheek ruff, a heart
## gem, star-shine eyes).

const VARIANTS := [["glitter", 60.0], ["lynx", 30.0], ["royal", 10.0]]

static var _variant_textures := {}

var variant := "glitter"


static func pick_variant() -> String:
	var total := 0.0
	for v in VARIANTS:
		total += v[1]
	var r := randf() * total
	for v in VARIANTS:
		r -= v[1]
		if r <= 0.0:
			return v[0]
	return VARIANTS[0][0]


func _define() -> void:
	super()
	species = "golden_kitten"
	if not has_meta("variant_set"):
		variant = pick_variant()
	speed_range = Vector2(48.0, 72.0)   # v2.0: 60 px/s


func set_variant(v: String) -> void:
	variant = v
	set_meta("variant_set", true)


func _load_textures() -> void:
	if _variant_textures.has(variant):
		return
	var tex := {}
	for part in pivots.keys():
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://art/golden_kitten/%s/%s.svg" % [variant, part]), PART_SCALE)
		img.generate_mipmaps()
		tex[part] = ImageTexture.create_from_image(img)
	_variant_textures[variant] = tex


func _sprite(part: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _variant_textures[variant][part]
	s.centered = false
	s.position = -pivots[part] * PART_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprites.append(s)
	return s
