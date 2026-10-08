extends RefCounted
## The GUI's colours, light and dark, from the design canvas
## (design/gui/theme.py is the source; keep the two in step).

const LIGHT := {
	"ground": "#F7F3FC", "side": "#EDE5F8", "surface": "#FFFFFF", "raised": "#FFFFFF", "line": "#E4DAF2",
	"div": "#F1EBF9", "track": "#ECE3F7", "ink": "#251A35", "ink2": "#5D5173", "ink3": "#6A5F83",
	"ink_body": "#3D3152", "acc_ink": "#6B3FC0", "btn_ink": "#FFFFFF", "btn_lip": "#4B2A8C",
	"sec_line": "#D5C8E8", "nav_h": "#E2D6F3", "tip_bg": "#2F2143", "tip_ink": "#F7F1FF",
	"dng_bg": "#FFF0F2", "dng_ink": "#A3283F", "accent": "#A07EEA", "outline": "#4A3466", "lip": "#4A3466",
	"btn": "#7C4DD6", "sp_kitten": "#F3E6D6", "dash": "#C8BBDC", "badge_line": "#4A3466", "ph_bg": "#F5F0FB",
	"off_line": "#B1A3C8", "chip_line": "#DCD0EC", "chip_sel": "#F2EBFD", "knob": "#FFFFFF", "dng_line": "#EDB7C1",
	"ok_ring": "#DDF3E8", "ph_ink": "#8F84A6", "acc_ink_h": "#4F2B93", "zz": "#5C6F86",
	"rh_bg": "#E9EEFC", "rh_line": "#9FB2EC", "rh_text": "#3F4C78", "rh_ink": "#33479A",
}
const DARK := {
	"ground": "#1C1524", "side": "#150F1C", "surface": "#271E31", "raised": "#32283F", "line": "#3D3150",
	"div": "#32283F", "track": "#3A2E4A", "ink": "#F5EFFC", "ink2": "#CBBFDD", "ink3": "#A99DBE",
	"ink_body": "#E0D7EC", "acc_ink": "#C8A8FF", "btn_ink": "#FFFFFF", "btn_lip": "#2E1858",
	"sec_line": "#4D3F62", "nav_h": "#241B2F", "tip_bg": "#F0E8FB", "tip_ink": "#251A35",
	"dng_bg": "#3A1A26", "dng_ink": "#FF9DB0", "accent": "#9C78E8", "outline": "#BBA6E0", "lip": "#0F0A15",
	"btn": "#7C4DD6", "sp_kitten": "#80746E", "dash": "#55466C", "badge_line": "#1A1124", "ph_bg": "#211A2B",
	"off_line": "#6E5F86", "chip_line": "#4A3D5E", "chip_sel": "#3C2D57", "knob": "#F5EFFC", "dng_line": "#6A2C3F",
	"ok_ring": "#1E3A2E", "ph_ink": "#8C80A2", "acc_ink_h": "#DEC9FF", "zz": "#A9BBDD",
	"rh_bg": "#1D2442", "rh_line": "#5C6FB0", "rh_text": "#B8C5EE", "rh_ink": "#A9BBFF",
}
# tier: fill, light tint, light ink, dark tint, dark ink ("fresh" is not a
# tier: the green for New and Yours, once Uncommon's)
const TIERS := {
	"common": ["#D9CEC2", "#F3EEE8", "#66594C", "#3A3330", "#DCCFC2"],
	"fresh": ["#86D9B0", "#E0F6EB", "#22795A", "#183A2E", "#8FE3BA"],
	"rare": ["#7FBCF5", "#E1EFFD", "#2363A8", "#182D47", "#9CCBFA"],
	"epic": ["#F590B4", "#FDE7EF", "#A62A5C", "#45192C", "#FFA6C6"],
	"legendary": ["#FFCF5C", "#FFF2CC", "#8C5A00", "#3D2E0C", "#FFD77A"],
}
# The well behind each critter, light; dark is mixed towards #2E2338.
const SPECIES_TINT := {"kitten": "#F3E6D6", "rabbit": "#EFE4F4", "duckling": "#FBF0CF", "turtle": "#E4F1DF",
	"hedgehog": "#F1E3D6", "squirrel": "#F6E1D1", "otter": "#E6EEF3", "panda": "#E9ECE4", "unicorn": "#F1E6F7",
	"golden": "#FAF0CC"}
const STATUS := {"running": "#4FB286", "paused": "#C9A13B", "napping": "#6C8DB0"}


# "system", "light" or "dark", from Settings > System > Theme.
static var theme := "system"


static func is_dark() -> bool:
	match theme:
		"light":
			return false
		"dark":
			return true
	return DisplayServer.is_dark_mode()


static func colours(dark: bool) -> Dictionary:
	var src := DARK if dark else LIGHT
	var out := {}
	for k in src:
		out[k] = Color(src[k])
	return out


static func tier(name: String, dark: bool) -> Dictionary:
	var t: Array = TIERS[name]
	return {"fill": Color(t[0]), "tint": Color(t[3] if dark else t[1]), "ink": Color(t[4] if dark else t[2])}


static func species_tint(id: String, dark: bool) -> Color:
	var c := Color(SPECIES_TINT.get(id, "#EDE5F8"))
	return c.lerp(Color("#2E2338"), 0.54) if dark else c
