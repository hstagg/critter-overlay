extends RefCounted
## The GUI's colours, light and dark, from the design canvas
## (design/gui/theme.py is the source; keep the two in step).

const LIGHT := {
	"ground": "#F7F3FC", "side": "#EDE5F8", "surface": "#FFFFFF", "raised": "#FFFFFF", "line": "#E4DAF2",
	"div": "#F1EBF9", "track": "#ECE3F7", "ink": "#251A35", "ink2": "#5D5173", "ink3": "#6A5F83",
	"ink_body": "#3D3152", "acc_ink": "#6B3FC0", "btn_ink": "#FFFFFF", "btn_lip": "#4B2A8C",
	"sec_line": "#D5C8E8", "nav_h": "#E2D6F3", "tip_bg": "#2F2143", "tip_ink": "#F7F1FF",
	"dng_bg": "#FFF0F2", "dng_ink": "#A3283F", "accent": "#A07EEA", "outline": "#4A3466", "lip": "#4A3466",
	"btn": "#7C4DD6", "sp_kitten": "#F3E6D6",
}
const DARK := {
	"ground": "#1C1524", "side": "#150F1C", "surface": "#271E31", "raised": "#32283F", "line": "#3D3150",
	"div": "#32283F", "track": "#3A2E4A", "ink": "#F5EFFC", "ink2": "#CBBFDD", "ink3": "#A99DBE",
	"ink_body": "#E0D7EC", "acc_ink": "#C8A8FF", "btn_ink": "#FFFFFF", "btn_lip": "#2E1858",
	"sec_line": "#4D3F62", "nav_h": "#241B2F", "tip_bg": "#F0E8FB", "tip_ink": "#251A35",
	"dng_bg": "#3A1A26", "dng_ink": "#FF9DB0", "accent": "#9C78E8", "outline": "#BBA6E0", "lip": "#0F0A15",
	"btn": "#7C4DD6", "sp_kitten": "#80746E",
}
# tier: fill, light tint, light ink, dark tint, dark ink
const TIERS := {
	"common": ["#D9CEC2", "#F3EEE8", "#66594C", "#3A3330", "#DCCFC2"],
	"uncommon": ["#86D9B0", "#E0F6EB", "#22795A", "#183A2E", "#8FE3BA"],
	"rare": ["#7FBCF5", "#E1EFFD", "#2363A8", "#182D47", "#9CCBFA"],
	"epic": ["#F590B4", "#FDE7EF", "#A62A5C", "#45192C", "#FFA6C6"],
	"legendary": ["#FFCF5C", "#FFF2CC", "#8C5A00", "#3D2E0C", "#FFD77A"],
}
const STATUS := {"running": "#4FB286", "paused": "#C9A13B", "napping": "#6C8DB0"}


static func colours(dark: bool) -> Dictionary:
	var src := DARK if dark else LIGHT
	var out := {}
	for k in src:
		out[k] = Color(src[k])
	return out


static func tier(name: String, dark: bool) -> Dictionary:
	var t: Array = TIERS[name]
	return {"fill": Color(t[0]), "tint": Color(t[3] if dark else t[1]), "ink": Color(t[4] if dark else t[2])}
