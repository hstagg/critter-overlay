extends RefCounted
## Clothes drawn at runtime (docs/custom-critters-build-plan.md, P14 and
## F2): a GDScript port of design/wear/common.py, build.py and items_*.py.
## draw(id, m) returns the SVG text build.py writes for a head with metrics
## m, the keys of build.py's SPECIES (cx, cy, rx, ry, eye_y, eye_dx, eye_r,
## chin, side; a kit's "top" and "gap" are not used by any item), in the head
## drawing's own 300 x 280 frame. Dyes are applied afterwards, as for the
## shipped files (wear.gd svg_for_kit()).
##
## The built-in species keep their shipped files (art/wear/<item>/<species>.svg);
## homemade critters are drawn from their own head here. wear_draw_test.gd
## renders every item for every species both ways and fails on any drift, so
## a change to one copy must be made to the other.
##
## The port keeps the Python line for line, with two rules that keep the
## text the same:
## - Numbers are written as Python writes them: fmt()'s "{}" is str() of an
##   int or repr() of a float, "{:.1f}" and "{:.0f}" round half to even on the
##   exact value (Godot's own "%.1f" rounds half away, and off the float).
##   Ints stay ints where Python's do, so every division is a float one.
## - Generator expressions are loops building an Array first (_jN, _lN);
##   nested functions and lambdas are GDScript lambdas, called with call().

const LINE := "#6B4A3A"
const W := 4   # outline width, as the critter art

const IDS := [
	"bow", "bell_collar", "flower_clip", "glasses", "beanie", "scarf", "party_hat", "bandana",
	"strawberry_hat", "wizard_hat", "fish_bowtie", "paw_beret", "carrot_clip", "carrot_scarf",
	"sailor_hat", "swim_ring", "quill_apple", "autumn_leaves", "leaf_umbrella", "bubble_scarf",
	"acorn_cap", "acorn_pendant", "shell_clip", "kelp_scarf", "bamboo_hat", "bamboo_sprig",
	"cloud_scarf", "rainbow_bow",
	"heart_clip", "star_clip", "cherry_clip", "leaf_sprig", "pearl_necklace", "bead_necklace",
	"sunglasses", "heart_glasses", "monocle", "plaster", "rose_clip", "feather_clip", "heart_tag",
	"clover_clip", "fish_clip", "lily_pad",
	"baseball_cap", "bucket_hat", "flower_crown", "headphones", "pirate_bandana", "cowboy_hat",
	"alice_band", "tiara", "chef_hat", "bow_tie", "sweatband", "bee_antennae", "devil_horns", "halo",
	"visor", "lei", "necktie", "mushroom_hat", "santa_hat", "pumpkin_hat", "propeller_cap",
	"daisy_chain", "rain_hat",
	"frog_hood", "dino_hood", "bear_hood", "astronaut_helmet", "viking_helmet", "knight_helmet",
	"tricorn", "top_hat", "jester_hat", "mortarboard", "flower_bonnet", "lion_mane", "garden_hat",
	"disco_headphones", "aviator_cap", "confetti_crown", "lucky_charm",
	"moon_nightcap", "star_cape", "star_glasses", "director_beret",
]


static func draw(id: String, m: Dictionary) -> String:
	# The item's SVG for a head with metrics m, or "" for an unknown id.
	if not id in IDS:
		return ""
	return _call(id, m)


# --- Writing numbers as Python does ---------------------------------------------

static func fmt(tpl: String, args: Array) -> String:
	# Fills a template's "{}", "{:.1f}" and "{:.0f}" from args in order, as a
	# Python f-string would.
	var parts := tpl.split("{")
	var out: String = parts[0]
	var ai := 0
	for i in range(1, parts.size()):
		var p: String = parts[i]
		var close := p.find("}")
		var spec := p.substr(0, close)
		var v = args[ai]
		ai += 1
		if spec == ":.1f":
			out += _fixed(v, 1)
		elif spec == ":.0f":
			out += _fixed(v, 0)
		else:
			out += _plain(v)
		out += p.substr(close + 1)
	if ai != args.size():
		push_error("wear_draw: %d values for %d places in %s" % [args.size(), ai, tpl.left(60)])
	return out


static func _plain(v) -> String:
	# Python's str(): an int as it is, a float as its repr.
	if v is String:
		return v
	if v is int:
		return str(v)
	return _repr(float(v))


static func _negative(x: float) -> bool:
	# The sign bit, so -0.0 is written "-0.0" as Python does.
	return x < 0.0 or (x == 0.0 and PackedFloat64Array([x]).to_byte_array()[7] >= 128)


static func _repr(x: float) -> String:
	# Python's repr(): the fewest decimals that read back as x (the nearest
	# such number), with ".0" on whole numbers.
	var sign := "-" if _negative(x) else ""
	var a := absf(x)
	if a == floorf(a) and a < 1e15:
		return sign + str(int(a)) + ".0"
	if a < 1e-4 or a >= 1e15:
		return String.num_scientific(x)   # Python writes these with an exponent; never met here
	var d := 1
	while a * pow(10.0, d) < 1e18:   # 17 digits, and n stays an int
		var n := _digits(a, d)
		if _reads_back(n, d, a):
			return sign + _point(n, d)
		d += 1
	return String.num(x, 17)


static func _fixed(v, d: int) -> String:
	# Python's format(v, ".1f") or ".0f": the exact value rounded half to even.
	var x := float(v)
	return ("-" if _negative(x) else "") + _point(_digits(absf(x), d), d)


static func _point(n: int, d: int) -> String:
	# n / 10^d written with d decimals.
	var s := str(n)
	if d == 0:
		return s
	s = s.lpad(d + 1, "0")
	return s.left(s.length() - d) + "." + s.right(d)


static func _digits(a: float, d: int) -> int:
	# a * 10^d (a >= 0) rounded half to even, on the exact value: the product
	# is kept as p + e exactly (Dekker), so neither Godot's rounding (half
	# away, and off the rounded product) nor the product's own rounding shows.
	var b := 1.0
	for i in d:
		b *= 10.0   # exact up to 10^22
	var p := a * b
	var e := _product_error(a, b, p)
	if p >= 4503599627370496.0:   # 2^52: p is whole, e holds the rest
		return _half_even(int(p), e, 0.0)
	var k := floori(p)
	var t := p - k   # exact
	var s := t + e
	return _half_even(k, s, _sum_error(t, e, s))


static func _half_even(whole: int, f: float, err: float) -> int:
	# whole + f + err rounded half to even, err far smaller than f's last bit.
	var k := floori(f)
	var g := f - k
	var n := whole + k
	if g > 0.5 or (g == 0.5 and err > 0.0):
		return n + 1
	if g < 0.5 or (g == 0.5 and err < 0.0):
		return n
	return n if n % 2 == 0 else n + 1


static func _split(a: float) -> PackedFloat64Array:
	var c := 134217729.0 * a   # 2^27 + 1
	var hi := c - (c - a)
	return PackedFloat64Array([hi, a - hi])


static func _product_error(a: float, b: float, p: float) -> float:
	# a * b - p exactly, where p is the rounded product (Dekker's TwoProduct).
	var sa := _split(a)
	var sb := _split(b)
	return ((sa[0] * sb[0] - p) + sa[0] * sb[1] + sa[1] * sb[0]) + sa[1] * sb[1]


static func _sum_error(a: float, b: float, s: float) -> float:
	# a + b - s exactly, where s is the rounded sum (Knuth's TwoSum).
	var bb := s - a
	return (a - (s - bb)) + (b - bb)


static func _reads_back(n: int, d: int, a: float) -> bool:
	# Whether n / 10^d is nearer to a than to the floats either side of it.
	var b := 1.0
	for i in d:
		b *= 10.0
	var p := a * b
	var e := _product_error(a, b, p)
	var diff: float
	if p >= 4503599627370496.0:
		diff = float(n - int(p)) - e
	else:
		diff = (float(n) - p) - e
	var bits := PackedFloat64Array([a]).to_byte_array().decode_s64(0)
	var gap := (_from_bits(bits + 1) - a) if diff > 0.0 else (a - _from_bits(bits - 1))
	return absf(diff) < gap * b * 0.5


static func _from_bits(bits: int) -> float:
	var raw := PackedByteArray()
	raw.resize(8)
	raw.encode_s64(0, bits)
	return raw.decode_double(0)


static func _with(m: Dictionary, changes: Dictionary) -> Dictionary:
	# Python's {**m, ...}.
	var out := m.duplicate()
	out.merge(changes, true)
	return out


static func _call(id: String, m: Dictionary) -> String:
	match id:
		"bow":
			return i_bow(m)
		"bell_collar":
			return i_bell_collar(m)
		"flower_clip":
			return i_flower_clip(m)
		"glasses":
			return i_glasses(m)
		"beanie":
			return i_beanie(m)
		"scarf":
			return i_scarf(m)
		"party_hat":
			return i_party_hat(m)
		"bandana":
			return i_bandana(m)
		"strawberry_hat":
			return i_strawberry_hat(m)
		"wizard_hat":
			return i_wizard_hat(m)
		"fish_bowtie":
			return i_fish_bowtie(m)
		"paw_beret":
			return i_paw_beret(m)
		"carrot_clip":
			return i_carrot_clip(m)
		"carrot_scarf":
			return i_carrot_scarf(m)
		"sailor_hat":
			return i_sailor_hat(m)
		"swim_ring":
			return i_swim_ring(m)
		"quill_apple":
			return i_quill_apple(m)
		"autumn_leaves":
			return i_autumn_leaves(m)
		"leaf_umbrella":
			return i_leaf_umbrella(m)
		"bubble_scarf":
			return i_bubble_scarf(m)
		"acorn_cap":
			return i_acorn_cap(m)
		"acorn_pendant":
			return i_acorn_pendant(m)
		"shell_clip":
			return i_shell_clip(m)
		"kelp_scarf":
			return i_kelp_scarf(m)
		"bamboo_hat":
			return i_bamboo_hat(m)
		"bamboo_sprig":
			return i_bamboo_sprig(m)
		"cloud_scarf":
			return i_cloud_scarf(m)
		"rainbow_bow":
			return i_rainbow_bow(m)
		"heart_clip":
			return i_heart_clip(m)
		"star_clip":
			return i_star_clip(m)
		"cherry_clip":
			return i_cherry_clip(m)
		"leaf_sprig":
			return i_leaf_sprig(m)
		"pearl_necklace":
			return i_pearl_necklace(m)
		"bead_necklace":
			return i_bead_necklace(m)
		"sunglasses":
			return i_sunglasses(m)
		"heart_glasses":
			return i_heart_glasses(m)
		"monocle":
			return i_monocle(m)
		"plaster":
			return i_plaster(m)
		"rose_clip":
			return i_rose_clip(m)
		"feather_clip":
			return i_feather_clip(m)
		"heart_tag":
			return i_heart_tag(m)
		"clover_clip":
			return i_clover_clip(m)
		"fish_clip":
			return i_fish_clip(m)
		"lily_pad":
			return i_lily_pad(m)
		"baseball_cap":
			return i_baseball_cap(m)
		"bucket_hat":
			return i_bucket_hat(m)
		"flower_crown":
			return i_flower_crown(m)
		"headphones":
			return i_headphones(m)
		"pirate_bandana":
			return i_pirate_bandana(m)
		"cowboy_hat":
			return i_cowboy_hat(m)
		"alice_band":
			return i_alice_band(m)
		"tiara":
			return i_tiara(m)
		"chef_hat":
			return i_chef_hat(m)
		"bow_tie":
			return i_bow_tie(m)
		"sweatband":
			return i_sweatband(m)
		"bee_antennae":
			return i_bee_antennae(m)
		"devil_horns":
			return i_devil_horns(m)
		"halo":
			return i_halo(m)
		"visor":
			return i_visor(m)
		"lei":
			return i_lei(m)
		"necktie":
			return i_necktie(m)
		"mushroom_hat":
			return i_mushroom_hat(m)
		"santa_hat":
			return i_santa_hat(m)
		"pumpkin_hat":
			return i_pumpkin_hat(m)
		"propeller_cap":
			return i_propeller_cap(m)
		"daisy_chain":
			return i_daisy_chain(m)
		"rain_hat":
			return i_rain_hat(m)
		"frog_hood":
			return i_frog_hood(m)
		"dino_hood":
			return i_dino_hood(m)
		"bear_hood":
			return i_bear_hood(m)
		"astronaut_helmet":
			return i_astronaut_helmet(m)
		"viking_helmet":
			return i_viking_helmet(m)
		"knight_helmet":
			return i_knight_helmet(m)
		"tricorn":
			return i_tricorn(m)
		"top_hat":
			return i_top_hat(m)
		"jester_hat":
			return i_jester_hat(m)
		"mortarboard":
			return i_mortarboard(m)
		"flower_bonnet":
			return i_flower_bonnet(m)
		"lion_mane":
			return i_lion_mane(m)
		"garden_hat":
			return i_garden_hat(m)
		"disco_headphones":
			return i_disco_headphones(m)
		"aviator_cap":
			return i_aviator_cap(m)
		"confetti_crown":
			return i_confetti_crown(m)
		"lucky_charm":
			return i_lucky_charm(m)
		"moon_nightcap":
			return i_moon_nightcap(m)
		"star_cape":
			return i_star_cape(m)
		"star_glasses":
			return i_star_glasses(m)
		"director_beret":
			return i_director_beret(m)
	return ""

# --- Helpers (common.py) --------------------------------------------------------------
static func svg(body):
	return (('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -120 300 400" width="300" height="400">' + body) + '</svg>')

static func top(m, x):
	# y of the head's outline at x (upper half of its ellipse).
	var dx = (float((x - m.cx)) / m.rx)
	return (m.cy - (m.ry * sqrt(max(0.0, (1 - (dx * dx))))))

static func star(cx, cy, r, fill, stroke = LINE, sw = 3, rot = 0):
	var pts = []
	for i in range(10):
		var a = deg_to_rad(((rot - 90) + (i * 36)))
		var rr = (r if ((i % 2) == 0) else (r * 0.45))
		pts.append(fmt('{:.1f},{:.1f}', [(cx + (rr * cos(a))), (cy + (rr * sin(a)))]))
	return fmt('<polygon points="{}" fill="{}" stroke="{}" stroke-width="{}" stroke-linejoin="round"/>', [' '.join(PackedStringArray(pts)), fill, stroke, sw])

static func heart(cx, cy, s, fill, rot = 0, opacity = 1.0, stroke = LINE, sw = 3):
	var d = fmt('M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z', [cx, (cy + (s * 0.9)), (cx - (s * 1.25)), (cy + (s * 0.1)), (cx - (s * 0.9)), (cy - (s * 0.95)), cx, (cy - (s * 0.35)), (cx + (s * 0.9)), (cy - (s * 0.95)), (cx + (s * 1.25)), (cy + (s * 0.1)), cx, (cy + (s * 0.9))])
	var op = (fmt(' fill-opacity="{}"', [opacity]) if (opacity < 1) else '')
	return fmt('<path d="{}" fill="{}"{} stroke="{}" stroke-width="{}" stroke-linejoin="round" transform="rotate({} {:.1f} {:.1f})"/>', [d, fill, op, stroke, sw, rot, cx, cy])

static func clip_at(m, side, k = 0.45):
	# Where a hair clip sits: up on one side of the head.
	var x = (m.cx + ((side * m.rx) * k))
	return [x, (top(m, x) + 12)]

static func neck_arc(m, colour, width = 12, spread = 0.55, dip = 16):
	# A band under the chin, outlined.
	var cx = m.cx
	var y = (m.chin - 6)
	var half = (m.rx * spread)
	var d = fmt('M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f}', [(cx - half), (y - 6), cx, (y + dip), (cx + half), (y - 6)])
	return fmt('<path d="{}" stroke="#6B4A3A" stroke-width="{}" fill="none" stroke-linecap="round"/><path d="{}" stroke="{}" stroke-width="{}" fill="none" stroke-linecap="round"/>', [d, (width + (2 * W)), d, colour, width])


# --- Items (build.py) -----------------------------------------------------------------
static func i_bow(m: Dictionary) -> String:
	var x = (m.cx + (m.rx * 0.42))
	var y = (top(m, x) + 10)
	return svg(fmt('<g transform="translate({:.1f} {:.1f}) rotate(18)"><path d="M0 0 C -14 -18 -34 -16 -32 0 C -34 16 -14 18 0 0 Z" fill="#F7A8C4" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M0 0 C 14 -18 34 -16 32 0 C 34 16 14 18 0 0 Z" fill="#F7A8C4" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M-22 -4 C -16 -6 -10 -4 -6 -1 M22 -4 C 16 -6 10 -4 6 -1" stroke="#E07BA0" stroke-width="3" fill="none" stroke-linecap="round"/><circle cx="0" cy="0" r="8" fill="#F28DB2" stroke="#6B4A3A" stroke-width="4"/></g>', [x, y]))

static func i_bell_collar(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 6)
	var half = (m.rx * 0.55)
	var band = fmt('<path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="22" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f}" stroke="#E2554F" stroke-width="14" fill="none" stroke-linecap="round"/>', [(cx - half), (y - 6), cx, (y + 16), (cx + half), (y - 6), (cx - half), (y - 6), cx, (y + 16), (cx + half), (y - 6)])
	var by = (y + 14)
	var bell = fmt('<circle cx="{}" cy="{}" r="11" fill="#FFCF5C" stroke="#6B4A3A" stroke-width="4"/><path d="M{} {} H {}" stroke="#6B4A3A" stroke-width="3" stroke-linecap="round"/><circle cx="{}" cy="{}" r="2.5" fill="#6B4A3A"/><circle cx="{}" cy="{}" r="2.5" fill="#FFF4CC"/>', [cx, by, (cx - 7), (by + 2), (cx + 7), cx, (by + 6), (cx - 4), (by - 4)])
	return svg((band + bell))

static func i_flower_clip(m: Dictionary) -> String:
	var x = (m.cx - (m.rx * 0.46))
	var y = (top(m, x) + 12)
	var _j1 = []
	for a in range((-90), 270, 72):
		_j1.append(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="9" ry="7" transform="rotate({} {:.1f} {:.1f})" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="3"/>', [(x + (13 * cos(deg_to_rad(a)))), (y + (13 * sin(deg_to_rad(a)))), a, (x + (13 * cos(deg_to_rad(a)))), (y + (13 * sin(deg_to_rad(a))))]))
	var petals = ''.join(PackedStringArray(_j1))
	return svg((petals + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="8" fill="#FFD84D" stroke="#6B4A3A" stroke-width="3"/>', [x, y])))

static func i_glasses(m: Dictionary) -> String:
	var y = m.eye_y
	var r = (m.eye_r + 9)
	var lx = (m.cx - m.eye_dx)
	var rx_ = (m.cx + m.eye_dx)
	var _j1 = []
	for x in [lx, rx_]:
		_j1.append(fmt('<circle cx="{}" cy="{}" r="{}" fill="#DDEEFF" fill-opacity="0.35" stroke="#6B4A3A" stroke-width="5"/><path d="M{:.1f} {:.1f} q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>', [x, y, r, (x - (r * 0.45)), (y - (r * 0.5)), (r * 0.25), ((-r) * 0.18), (r * 0.5), ((-r) * 0.12)]))
	var lens = ''.join(PackedStringArray(_j1))
	var bridge = fmt('<path d="M{:.1f} {} Q {} {} {:.1f} {}" stroke="#6B4A3A" stroke-width="4" fill="none" stroke-linecap="round"/>', [(lx + r), (y - 2), m.cx, (y - 10), (rx_ - r), (y - 2)])
	var arms = fmt('<path d="M{:.1f} {} L {:.1f} {}" stroke="#6B4A3A" stroke-width="4" stroke-linecap="round"/><path d="M{:.1f} {} L {:.1f} {}" stroke="#6B4A3A" stroke-width="4" stroke-linecap="round"/>', [(lx - r), (y - 4), ((m.cx - m.rx) + 6), (y - 10), (rx_ + r), (y - 4), ((m.cx + m.rx) - 6), (y - 10)])
	return svg(((arms + bridge) + lens))

static func i_beanie(m: Dictionary) -> String:
	var cx = m.cx
	var hw = (m.rx * 0.78)
	var brim_y = (top(m, cx) + (m.ry * 0.38))
	var dome_top = (top(m, cx) - 22)
	var dome = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#7FB3E8" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), brim_y, (cx - hw), (dome_top + 6), (cx - (hw * 0.4)), dome_top, cx, dome_top, (cx + (hw * 0.4)), dome_top, (cx + hw), (dome_top + 6), (cx + hw), brim_y])
	var _j1 = []
	for dx in [((-hw) * 0.55), ((-hw) * 0.18), (hw * 0.18), (hw * 0.55)]:
		_j1.append(fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#5E95CF" stroke-width="3" fill="none" stroke-linecap="round"/>', [(cx + dx), (brim_y - 4), (cx + (dx * 0.9)), (dome_top + 18), (cx + (dx * 0.4)), (dome_top + 6)]))
	var knit = ''.join(PackedStringArray(_j1))
	var _j2 = []
	var _l3 = []
	for i in range(1, 9):
		_l3.append(((cx - hw) + (float((i * (2 * hw))) / 9)))
	for x in _l3:
		_j2.append(fmt('<path d="M{:.1f} {:.1f} v 12" stroke="#C9D8EA" stroke-width="3" stroke-linecap="round"/>', [x, (brim_y - 7)]))
	var brim = (fmt('<rect x="{:.1f}" y="{:.1f}" width="{:.1f}" height="22" rx="11" fill="#F3F7FC" stroke="#6B4A3A" stroke-width="4"/>', [((cx - hw) - 6), (brim_y - 12), ((2 * hw) + 12)]) + ''.join(PackedStringArray(_j2)))
	var pom = fmt('<circle cx="{}" cy="{:.1f}" r="14" fill="#F3F7FC" stroke="#6B4A3A" stroke-width="4"/>', [cx, (dome_top - 6)])
	return svg((((dome + knit) + brim) + pom))

static func i_scarf(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 4)
	var half = (m.rx * 0.62)
	var wrap_ = fmt('<path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} Z" fill="#E86A5C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - half), (y - 10), cx, (y + 22), (cx + half), (y - 10), ((cx + half) - 4), (y + 8), cx, (y + 40), ((cx - half) + 4), (y + 8)])
	var _j1 = []
	for dx in [((-half) * 0.6), ((-half) * 0.2), (half * 0.2), (half * 0.6)]:
		_j1.append(fmt('<path d="M{:.1f} {:.1f} l 4 -14" stroke="#FFF1E2" stroke-width="5" stroke-linecap="round"/>', [(cx + dx), (((y + 4) + (abs(dx) * (-0.12))) + 10)]))
	var stripes = ''.join(PackedStringArray(_j1))
	var tx = (cx + (half * 0.45))
	var tail = fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} Z" fill="#E86A5C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} H {:.1f}" stroke="#FFF1E2" stroke-width="5" stroke-linecap="round"/><path d="M{:.1f} {:.1f} l -2 7 M{:.1f} {:.1f} l 0 8 M{:.1f} {:.1f} l 2 7" stroke="#6B4A3A" stroke-width="3" stroke-linecap="round"/>', [(tx - 12), (y + 18), (tx + 12), (y + 18), (tx + 16), (y + 58), (tx - 6), (y + 60), (tx - 9), (y + 34), (tx + 13), (tx - 6), (y + 60), (tx + 2), (y + 60), (tx + 10), (y + 59)])
	return svg(((tail + wrap_) + stripes))

static func i_party_hat(m: Dictionary) -> String:
	var cx = (m.cx + 6)
	var base = (top(m, cx) + 8)
	var h = (74 * m.side)
	var w = (34 * m.side)
	var g = fmt('<g transform="rotate(-10 {} {:.1f})">', [cx, base])
	var cone = fmt('<path d="M{:.1f} {:.1f} L {} {:.1f} L {:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} Z" fill="#B59AF0" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - w), base, cx, (base - h), (cx + w), base, cx, (base + 10), (cx - w), base])
	var _j1 = []
	for f in [0.35, 0.62, 0.88]:
		_j1.append(fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f}" stroke="#FFCF5C" stroke-width="7" stroke-linecap="round"/>', [(cx - (w * f)), (base - (h * (1 - f))), (cx + ((w * f) * 0.2)), ((base - (h * (1 - f))) - 6)]))
	var stripes = ''.join(PackedStringArray(_j1))
	var pom = fmt('<circle cx="{}" cy="{:.1f}" r="10" fill="#F590B4" stroke="#6B4A3A" stroke-width="4"/>', [cx, ((base - h) - 4)])
	return svg(((((g + cone) + stripes) + pom) + '</g>'))

static func i_bandana(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 8)
	var half = (m.rx * 0.6)
	var tri = fmt('<path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} Z" fill="#5B8FD6" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - half), y, cx, (y + 12), (cx + half), y, (cx + 4), (y + 52), cx, (y + 56), (cx - 4), (y + 52)])
	var _j1 = []
	for _t2 in [[((-half) * 0.5), 12], [((-half) * 0.1), 18], [(half * 0.35), 12], [((-half) * 0.25), 32], [(half * 0.15), 34], [0, 46]]:
		var dx = _t2[0]
		var dy = _t2[1]
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="3.6" fill="#FFFFFF"/>', [(cx + dx), (y + dy)]))
	var dots = ''.join(PackedStringArray(_j1))
	var knot = fmt('<path d="M{:.1f} {:.1f} l 16 -10 l 2 12 Z M{:.1f} {:.1f} l 14 10 l -10 6 Z" fill="#5B8FD6" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [((cx + half) - 6), (y - 2), ((cx + half) - 6), (y - 2)])
	return svg(((tri + dots) + knot))

static func i_strawberry_hat(m: Dictionary) -> String:
	var cx = m.cx
	var hw = (m.rx * 0.82)
	var rim = (top(m, cx) + (m.ry * 0.42))
	var tip = (top(m, cx) - 30)
	var cap = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} Z" fill="#F2575D" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), rim, ((cx - hw) - 4), (tip + 18), (cx - (hw * 0.4)), tip, cx, tip, (cx + (hw * 0.4)), tip, ((cx + hw) + 4), (tip + 18), (cx + hw), rim, cx, (rim + 12), (cx - hw), rim])
	var seeds = ''
	var _s1 = [[(-0.55), 0.62], [(-0.2), 0.5], [0.2, 0.55], [0.55, 0.65], [(-0.38), 0.85], [0.02, 0.8], [0.4, 0.86], [(-0.05), 0.3], [0.32, 0.32], [(-0.35), 0.36]]
	for i in _s1.size():
		var fx = _s1[i][0]
		var fy = _s1[i][1]
		var sx = (cx + (fx * hw))
		var sy = (tip + (fy * (rim - tip)))
		seeds += fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="2.6" ry="4" fill="#FFE07A" transform="rotate({:.0f} {:.1f} {:.1f})"/>', [sx, sy, (fx * 30), sx, sy])
	var _j2 = []
	for dx in [(-34), (-16), 16, 34]:
		_j2.append(fmt('<path d="M{} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {} {:.1f} Z" fill="#6CC27A" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [cx, (tip + 6), (cx + (dx * 0.5)), (tip - 18), (cx + dx), (tip - 4), (cx + (dx * 0.6)), (tip + 6), cx, (tip + 6)]))
	var leaves = ''.join(PackedStringArray(_j2))
	var stem = fmt('<path d="M{} {:.1f} q 2 -14 10 -18" stroke="#6B4A3A" stroke-width="7" fill="none" stroke-linecap="round"/><path d="M{} {:.1f} q 2 -14 10 -18" stroke="#6CC27A" stroke-width="4" fill="none" stroke-linecap="round"/>', [cx, (tip - 2), cx, (tip - 2)])
	return svg((((cap + seeds) + stem) + leaves))

static func i_wizard_hat(m: Dictionary) -> String:
	var cx = m.cx
	var brim_y = (top(m, cx) + 14)
	var bw = (m.rx * 0.95)
	var h = (96 * m.side)
	var brim = fmt('<ellipse cx="{}" cy="{:.1f}" rx="{:.1f}" ry="15" fill="#5A4BB8" stroke="#6B4A3A" stroke-width="4"/>', [cx, brim_y, bw])
	var cone = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#6A5AD0" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - 36), (brim_y - 2), (cx - 26), (brim_y - (h * 0.5)), (cx - 8), (brim_y - (h * 0.8)), (cx + 6), (brim_y - h), (cx + 30), ((brim_y - h) - 6), (cx + 34), ((brim_y - h) + 12), (cx + 20), ((brim_y - h) + 8), (cx + 14), (brim_y - (h * 0.7)), (cx + 22), (brim_y - (h * 0.4)), (cx + 30), (brim_y - 20), (cx + 36), (brim_y - 2)])
	var band = fmt('<path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f}" stroke="#FFCF5C" stroke-width="8" fill="none" stroke-linecap="round"/>', [(cx - 34), (brim_y - 10), cx, (brim_y - 2), (cx + 34), (brim_y - 10)])
	var stars = ((star((cx - 8), (brim_y - (h * 0.38)), 9, '#FFCF5C') + star((cx + 12), (brim_y - (h * 0.62)), 6, '#FFF0C2', LINE, 3, 15)) + star((cx + 34), ((brim_y - h) + 14), 5, '#FFCF5C'))
	return svg((((brim + cone) + band) + stars))

static func i_fish_bowtie(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 2)
	var fish = ''
	for s in [(-1), 1]:
		var x0 = (cx + (s * 6))
		fish += fmt('<path d="M{} {} C {} {} {} {} {} {} C {} {} {} {} {} {} Z" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{} {} l {} -10 l 0 20 Z" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><circle cx="{}" cy="{}" r="2.6" fill="#6B4A3A"/><path d="M{} {} q {} 6 0 12 M{} {} q {} 6 0 12" stroke="#4F8FD0" stroke-width="2.5" fill="none" stroke-linecap="round"/>', [x0, y, (x0 + (s * 10)), (y - 14), (x0 + (s * 28)), (y - 12), (x0 + (s * 34)), y, (x0 + (s * 28)), (y + 12), (x0 + (s * 10)), (y + 14), x0, y, (x0 + (s * 32)), y, (s * 12), (x0 + (s * 9)), (y - 2), (x0 + (s * 16)), (y - 6), (s * 4), (x0 + (s * 22)), (y - 6), (s * 4)])
	var knot = fmt('<circle cx="{}" cy="{}" r="7" fill="#F590B4" stroke="#6B4A3A" stroke-width="4"/>', [cx, y])
	return svg((fish + knot))

static func i_paw_beret(m: Dictionary) -> String:
	var cx = (m.cx + 4)
	var base = (top(m, cx) + 18)
	var beret = fmt('<path d="M{} {} C {} {} {} {} {} {} C {} {} {} {} {} {} Q {} {} {} {} Z" fill="#C9506A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{} {} q 2 -8 8 -10" stroke="#6B4A3A" stroke-width="5" fill="none" stroke-linecap="round"/>', [(cx - 58), base, (cx - 70), (base - 40), (cx - 10), (base - 56), (cx + 30), (base - 44), (cx + 70), (base - 34), (cx + 62), (base - 4), (cx + 50), (base + 2), cx, (base + 10), (cx - 58), base, (cx + 2), (base - 50)])
	var px = (cx + 14)
	var py = (base - 22)
	var _j1 = []
	for _t2 in [[(-10), (-5)], [(-4), (-10)], [4, (-10)], [10, (-5)]]:
		var dx = _t2[0]
		var dy = _t2[1]
		_j1.append(fmt('<circle cx="{}" cy="{}" r="3.4" fill="#FCD9E6"/>', [(px + dx), (py + dy)]))
	var paw = (fmt('<ellipse cx="{}" cy="{}" rx="9" ry="7" fill="#FCD9E6"/>', [px, (py + 4)]) + ''.join(PackedStringArray(_j1)))
	return svg((beret + paw))

static func i_carrot_clip(m: Dictionary) -> String:
	var x = (m.cx + 26)
	var y = (top(m, (m.cx + 26)) + 6)
	return svg(fmt('<g transform="rotate(-35 {} {})"><path d="M{} {} Q {} {} {} {} L {} {} Q {} {} {} {} Z" fill="#F59A4A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{} {} l 5 1 M{} {} l 5 1" stroke="#C96F2A" stroke-width="2.5" stroke-linecap="round"/><path d="M{} {} q -10 -14 -6 -20 q 6 4 6 20 q 4 -16 12 -18 q 0 10 -12 18" fill="#6CC27A" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/></g>', [x, y, (x - 9), (y - 4), x, (y - 10), (x + 9), (y - 4), (x + 2), (y + 30), x, (y + 34), (x - 2), (y + 30), (x - 5), (y + 6), (x - 3), (y + 15), x, (y - 6)]))

static func i_carrot_scarf(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 4)
	var half = (m.rx * 0.62)
	var wrap_ = fmt('<path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} Z" fill="#F59A4A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - half), (y - 10), cx, (y + 22), (cx + half), (y - 10), ((cx + half) - 4), (y + 8), cx, (y + 40), ((cx - half) + 4), (y + 8)])
	var _j1 = []
	for dx in [((-half) * 0.7), ((-half) * 0.35), 0, (half * 0.35), (half * 0.7)]:
		_j1.append(fmt('<path d="M{:.1f} {:.1f} l 3 -12" stroke="#E07F2E" stroke-width="3" stroke-linecap="round"/>', [(cx + dx), (y + 10)]))
	var ribs = ''.join(PackedStringArray(_j1))
	var tx = (cx - (half * 0.45))
	var tail = fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} Z" fill="#F59A4A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} q -4 10 -10 12 q 8 -2 12 -10 M{:.1f} {:.1f} q 0 10 4 14 q 0 -8 -2 -14" fill="#6CC27A" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [(tx - 12), (y + 18), (tx + 12), (y + 18), (tx + 6), (y + 54), (tx - 14), (y + 52), (tx - 10), (y + 54), (tx - 2), (y + 54)])
	return svg(((tail + wrap_) + ribs))

static func i_sailor_hat(m: Dictionary) -> String:
	var cx = m.cx
	var base = (top(m, cx) + 10)
	var hat = fmt('<g transform="rotate(-8 {} {})"><path d="M{} {} C {} {} {} {} {} {} C {} {} {} {} {} {} Z" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><rect x="{}" y="{}" width="108" height="18" rx="9" fill="#3E6FC2" stroke="#6B4A3A" stroke-width="4"/><path d="M{} {} l 10 18 l 6 -12 Z" fill="#3E6FC2" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>{}</g>', [cx, base, (cx - 50), base, (cx - 52), (base - 30), (cx - 28), (base - 46), cx, (base - 46), (cx + 28), (base - 46), (cx + 52), (base - 30), (cx + 50), base, (cx - 54), (base - 12), (cx + 40), (base + 4), star(cx, (base - 26), 8, '#FFCF5C')])
	return svg(hat)

static func i_swim_ring(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin + 8)
	var rx = (m.rx * 0.86)
	var ry = 15
	var t = 18
	var per = ((2 * PI) * sqrt((float(((rx * rx) + (ry * ry))) / 2)))
	var dash = (float(per) / 8)
	var tube = fmt('<ellipse cx="{}" cy="{}" rx="{:.1f}" ry="{}" fill="none" stroke="#6B4A3A" stroke-width="{}"/><ellipse cx="{}" cy="{}" rx="{:.1f}" ry="{}" fill="none" stroke="#FFFFFF" stroke-width="{}"/><ellipse cx="{}" cy="{}" rx="{:.1f}" ry="{}" fill="none" stroke="#E2554F" stroke-width="{}" stroke-dasharray="{:.1f} {:.1f}"/><path d="M{:.1f} {:.1f} q {:.1f} 6 {:.1f} 4" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>', [cx, y, rx, ry, (t + (2 * W)), cx, y, rx, ry, t, cx, y, rx, ry, t, dash, dash, (cx - (rx * 0.55)), ((y + ry) - 2), (rx * 0.25), (rx * 0.5)])
	return svg(tube)

static func i_quill_apple(m: Dictionary) -> String:
	var x = (m.cx + (m.rx * 0.62))
	var y = (top(m, x) - 20)
	var apple = fmt('<g transform="rotate(14 {:.1f} {:.1f})"><path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#E2554F" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} q 3 -5 8 -5" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.7"/><path d="M{:.1f} {:.1f} q 1 -8 4 -12" stroke="#6B4A3A" stroke-width="3" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} q 12 -8 18 -1 q -9 8 -18 1 Z" fill="#6CC27A" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/></g>', [x, y, x, (y - 12), (x - 8), (y - 18), (x - 20), (y - 12), (x - 19), (y + 1), (x - 18), (y + 14), (x - 8), (y + 20), x, (y + 16), (x + 8), (y + 20), (x + 18), (y + 14), (x + 19), (y + 1), (x + 20), (y - 12), (x + 8), (y - 18), x, (y - 12), (x - 11), (y - 6), x, (y - 12), (x + 3), (y - 20)])
	return svg(apple)

static func i_autumn_leaves(m: Dictionary) -> String:
	var leaf = func(cx, cy, rot, fill, vein):
		return fmt('<g transform="rotate({} {:.1f} {:.1f})"><path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="{}" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} L {:.1f} {:.1f} M{:.1f} {:.1f} l -6 -5 M{:.1f} {:.1f} l 6 -5" stroke="{}" stroke-width="2.4" fill="none" stroke-linecap="round"/></g>', [rot, cx, cy, cx, (cy - 18), (cx + 12), (cy - 10), (cx + 12), (cy + 8), cx, (cy + 16), (cx - 12), (cy + 8), (cx - 12), (cy - 10), cx, (cy - 18), fill, cx, (cy - 12), cx, (cy + 22), cx, (cy - 2), cx, (cy + 6), vein])
	var x = (m.cx - (m.rx * 0.55))
	var y = (top(m, x) - 16)
	return svg((leaf.call((x - 10), (y + 4), (-40), '#F2994A', '#C2692A') + leaf.call((x + 8), (y - 4), 12, '#F6C453', '#C9962E')))

static func i_leaf_umbrella(m: Dictionary) -> String:
	var cx = (m.cx + 6)
	var y = (top(m, m.cx) - 18)
	var leaf = fmt('<path d="M{} {} Q{} {} {} {} Q{} {} {} {} Q{} {} {} {} Q{} {} {} {} Q{} {} {} {} Z" fill="#7CC36A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{} {} L{} {} M{} {} l-20 10 M{} {} l20 10" stroke="#4F9A45" stroke-width="2.6" fill="none" stroke-linecap="round"/><path d="M{} {} L{} {}" stroke="#4F9A45" stroke-width="4" stroke-linecap="round"/>', [(cx - 46), (y + 6), (cx - 40), (y - 30), cx, (y - 34), (cx + 40), (y - 30), (cx + 46), (y + 6), (cx + 30), (y - 2), (cx + 16), (y + 6), cx, (y - 4), (cx - 16), (y + 6), (cx - 30), (y - 2), (cx - 46), (y + 6), cx, (y - 30), cx, (y + 2), cx, (y - 18), cx, (y - 18), cx, (y + 2), (cx + 2), (y + 26)])
	return svg(leaf)

static func i_bubble_scarf(m: Dictionary) -> String:
	var out = neck_arc(m, '#5FB7D9', 14)
	var cx = m.cx
	var y = (m.chin - 2)
	var _s1 = [(-22), (-8), 8, 22]
	for i in _s1.size():
		var dx = _s1[i]
		out += fmt('<circle cx="{}" cy="{:.1f}" r="{}" fill="#FFFFFF" opacity="0.85"/>', [(cx + dx), ((y + 4) + (abs(dx) * (-0.2))), (3 + (i % 2))])
	return svg(out)

static func i_acorn_cap(m: Dictionary) -> String:
	var cx = m.cx
	var base = (top(m, m.cx) + 12)
	var cap = fmt('<path d="M{} {} Q{} {} {} {} Q{} {} {} {} Z" fill="#8A5A35" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - 38), base, (cx - 38), (base - 38), cx, (base - 40), (cx + 38), (base - 38), (cx + 38), base])
	var _j1 = []
	for k in range(3):
		for dx in [(-20), 0, 20]:
			if (abs(dx) < (34 - (k * 8))):
				_j1.append(fmt('<path d="M{} {} l6 -6 l6 6" stroke="#6E4528" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>', [((cx + dx) - 6), ((base - 8) - (k * 9))]))
	cap += ''.join(PackedStringArray(_j1))
	cap += fmt('<path d="M{} {} q2 -10 8 -12" stroke="#6B4A3A" stroke-width="4" fill="none" stroke-linecap="round"/>', [cx, (base - 40)])
	return svg(cap)

static func i_acorn_pendant(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin + 6)
	var cord = fmt('<path d="M{} {} Q{} {} {} {}" stroke="#B9874F" stroke-width="3" fill="none"/>', [(cx - 34), (y - 14), cx, (y + 6), (cx + 34), (y - 14)])
	var nut = fmt('<path d="M{} {} Q{} {} {} {} Q{} {} {} {} Z" fill="#C98B4E" stroke="#6B4A3A" stroke-width="3"/><path d="M{} {} Q{} {} {} {} Q{} {} {} {} Z" fill="#8A5A35" stroke="#6B4A3A" stroke-width="3"/>', [(cx - 9), (y + 2), (cx - 10), (y + 18), cx, (y + 22), (cx + 10), (y + 18), (cx + 9), (y + 2), (cx - 12), (y + 4), (cx - 12), (y - 6), cx, (y - 7), (cx + 12), (y - 6), (cx + 12), (y + 4)])
	return svg((cord + nut))

static func i_shell_clip(m: Dictionary) -> String:
	var _r1 = clip_at(m, (-1), 0.5)
	var x = _r1[0]
	var y = _r1[1]
	var d = fmt('M{} {} Q{} {} {} {} Q{} {} {} {} Z', [(x - 14), (y + 6), (x - 16), (y - 12), x, (y - 14), (x + 16), (y - 12), (x + 14), (y + 6)])
	var _j2 = []
	for dx in [(-9), (-3), 3, 9]:
		_j2.append(fmt('M{} {} L{} {}', [x, (y + 6), (x + dx), (y - 10)]))
	var rays = ' '.join(PackedStringArray(_j2))
	return svg(fmt('<path d="{}" fill="#F7C9C0" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><path d="{}" stroke="#D99A8E" stroke-width="2" fill="none"/>', [d, rays]))

static func i_kelp_scarf(m: Dictionary) -> String:
	var out = neck_arc(m, '#4E9A6A', 12)
	var cx = (m.cx + (m.rx * 0.3))
	var y = (m.chin + 4)
	out += fmt('<path d="M{} {} q8 10 0 20 q-8 10 2 20" stroke="#6B4A3A" stroke-width="20" fill="none" stroke-linecap="round"/><path d="M{} {} q8 10 0 20 q-8 10 2 20" stroke="#4E9A6A" stroke-width="12" fill="none" stroke-linecap="round"/>', [cx, y, cx, y])
	return svg(out)

static func i_bamboo_hat(m: Dictionary) -> String:
	var cx = m.cx
	var base = (top(m, m.cx) + 14)
	var w = (m.rx * 0.95)
	var hat = fmt('<path d="M{:.1f} {} L{} {} L{:.1f} {} Q{} {} {:.1f} {} Z" fill="#E6C27A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - w), base, cx, (base - 46), (cx + w), base, cx, (base + 10), (cx - w), base])
	var _j1 = []
	for dx in [((-w) * 0.6), ((-w) * 0.2), (w * 0.2), (w * 0.6)]:
		_j1.append(fmt('<path d="M{} {} L{:.1f} {}" stroke="#C49A4E" stroke-width="2" opacity="0.8"/>', [cx, (base - 46), (cx + dx), (base + 2)]))
	hat += ''.join(PackedStringArray(_j1))
	hat += fmt('<path d="M{:.1f} {} Q{} {} {:.1f} {}" stroke="#B5463C" stroke-width="5" fill="none"/>', [(cx - (w * 0.5)), (base - 20), cx, (base - 14), (cx + (w * 0.5)), (base - 20)])
	return svg(hat)

static func i_bamboo_sprig(m: Dictionary) -> String:
	var _r1 = clip_at(m, 1, 0.55)
	var x = _r1[0]
	var y = _r1[1]
	return svg(fmt('<path d="M{} {} L{} {}" stroke="#7DB352" stroke-width="5" stroke-linecap="round"/><path d="M{} {} q18 -12 26 -2 q-12 8 -26 2 Z" fill="#9CCB6B" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><path d="M{} {} q-16 -14 -24 -6 q10 10 24 6 Z" fill="#B8E082" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [x, (y + 10), (x + 4), (y - 16), (x + 3), (y - 8), (x + 2), (y - 14)]))

static func i_cloud_scarf(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 2)
	var pts = [[(cx - 34), (y - 6), 12], [(cx - 16), (y + 2), 14], [(cx + 4), (y + 4), 14], [(cx + 22), y, 13], [(cx + 36), (y - 8), 11]]
	var _j1 = []
	for _t2 in pts:
		var x = _t2[0]
		var yy = _t2[1]
		var r = _t2[2]
		_j1.append(fmt('<circle cx="{}" cy="{}" r="{}" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="7"/>', [x, yy, r]))
	var out = ''.join(PackedStringArray(_j1))
	var _j3 = []
	for _t4 in pts:
		var x = _t4[0]
		var yy = _t4[1]
		var r = _t4[2]
		_j3.append(fmt('<circle cx="{}" cy="{}" r="{}" fill="#FFFFFF"/>', [x, yy, r]))
	out += ''.join(PackedStringArray(_j3))
	return svg(out)

static func i_rainbow_bow(m: Dictionary) -> String:
	var _r1 = clip_at(m, (-1), 0.42)
	var x = _r1[0]
	var y = _r1[1]
	var _j2 = []
	var _s3 = ['#F7A8B8', '#FFD59A', '#B9E8B0', '#A9D4F5', '#C9B6F2']
	for i in _s3.size():
		var c = _s3[i]
		_j2.append(fmt('<path d="M{} {} L{} {} L{} {} Z M{} {} L{} {} L{} {} Z" fill="{}"/>', [x, y, (x - 22), ((y - 12) + (i * 5)), (x - 22), ((y - 8) + (i * 5)), x, y, (x + 22), ((y - 12) + (i * 5)), (x + 22), ((y - 8) + (i * 5)), c]))
	var stripes = ''.join(PackedStringArray(_j2))
	var outline = fmt('<path d="M{} {} L{} {} L{} {} Z M{} {} L{} {} L{} {} Z" fill="none" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [x, y, (x - 22), (y - 14), (x - 22), (y + 14), x, y, (x + 22), (y - 14), (x + 22), (y + 14)])
	return svg(((stripes + outline) + fmt('<circle cx="{}" cy="{}" r="6" fill="#F7A8B8" stroke="#6B4A3A" stroke-width="3"/>', [x, y])))


# --- Small items (items_small.py) -----------------------------------------------------
static func i_heart_clip(m: Dictionary) -> String:
	var _r1 = clip_at(m, 1)
	var x = _r1[0]
	var y = _r1[1]
	return svg((heart(x, y, 13, '#F590B4') + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="2.6" fill="#FFFFFF" opacity="0.8"/>', [(x - 5), (y - 4)])))

static func i_star_clip(m: Dictionary) -> String:
	var _r1 = clip_at(m, (-1))
	var x = _r1[0]
	var y = _r1[1]
	return svg((star(x, y, 15, '#FFD84D', LINE, 3, (-12)) + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="2" fill="#FFFFFF" opacity="0.8"/>', [(x - 3), (y - 3)])))

static func i_cherry_clip(m: Dictionary) -> String:
	var _r1 = clip_at(m, 1)
	var x = _r1[0]
	var y = _r1[1]
	return svg(fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6CC27A" stroke-width="3" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} q 10 -6 16 0 q -8 6 -16 0 Z" fill="#6CC27A" stroke="#6B4A3A" stroke-width="3"/><circle cx="{:.1f}" cy="{:.1f}" r="10" fill="#E4505C" stroke="#6B4A3A" stroke-width="4"/><circle cx="{:.1f}" cy="{:.1f}" r="10" fill="#E4505C" stroke="#6B4A3A" stroke-width="4"/><circle cx="{:.1f}" cy="{:.1f}" r="2.6" fill="#FFB3BA"/><circle cx="{:.1f}" cy="{:.1f}" r="2.6" fill="#FFB3BA"/>', [(x - 9), (y + 6), (x - 4), (y - 16), (x + 4), (y - 20), (x + 9), (y + 8), (x + 8), (y - 10), (x + 4), (y - 20), (x - 9), (y + 6), (x - 4), (y - 16), (x + 4), (y - 20), (x + 9), (y + 8), (x + 8), (y - 10), (x + 4), (y - 20), (x + 4), (y - 20), (x - 10), (y + 12), (x + 10), (y + 14), (x - 13), (y + 8), (x + 7), (y + 10)]))

static func i_leaf_sprig(m: Dictionary) -> String:
	var _r1 = clip_at(m, (-1), 0.38)
	var x = _r1[0]
	var y = _r1[1]
	var _j2 = []
	for a in [(-150), (-90), (-30)]:
		_j2.append(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="13" ry="6.5" transform="rotate({} {:.1f} {:.1f})" fill="#7FCF86" stroke="#6B4A3A" stroke-width="3"/><path d="M{:.1f} {:.1f} l {:.1f} {:.1f}" stroke="#4FA35C" stroke-width="2" stroke-linecap="round"/>', [(x + (13 * cos(deg_to_rad(a)))), (y + (13 * sin(deg_to_rad(a)))), a, (x + (13 * cos(deg_to_rad(a)))), (y + (13 * sin(deg_to_rad(a)))), x, y, (20 * cos(deg_to_rad(a))), (20 * sin(deg_to_rad(a)))]))
	var leaves = ''.join(PackedStringArray(_j2))
	return svg((leaves + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="4.5" fill="#A0703F" stroke="#6B4A3A" stroke-width="2"/>', [x, y])))

static func _beads(m, colours, r = 6.5, n = 9, sag = 18):
	var cx = m.cx
	var y = (m.chin - 4)
	var half = (m.rx * 0.52)
	var out = ''
	for i in range(n):
		var f = (float(i) / (n - 1))
		var x = ((cx - half) + ((2 * half) * f))
		var yy = ((y - 6) + (sag * (1 - pow(((2 * f) - 1), 2))))
		out += fmt('<circle cx="{:.1f}" cy="{:.1f}" r="{}" fill="{}" stroke="#6B4A3A" stroke-width="3"/>', [x, yy, r, colours[(i % colours.size())]])
		out += fmt('<circle cx="{:.1f}" cy="{:.1f}" r="{:.1f}" fill="#FFFFFF" opacity="0.8"/>', [(x - (r * 0.35)), (yy - (r * 0.35)), (r * 0.3)])
	return out

static func i_pearl_necklace(m: Dictionary) -> String:
	return svg(_beads(m, ['#FBF7F0'], 6, 11, 16))

static func i_bead_necklace(m: Dictionary) -> String:
	return svg(_beads(m, ['#F590B4', '#FFCF5C', '#7FBCF5', '#86D9B0', '#C8A8FF'], 7, 9, 18))

static func _two_lenses(m, lens, extra = ''):
	var y = m.eye_y
	var r = (m.eye_r + 9)
	var lx = (m.cx - m.eye_dx)
	var rx_ = (m.cx + m.eye_dx)
	var arms = fmt('<path d="M{:.1f} {} L {:.1f} {}" stroke="#6B4A3A" stroke-width="4" stroke-linecap="round"/><path d="M{:.1f} {} L {:.1f} {}" stroke="#6B4A3A" stroke-width="4" stroke-linecap="round"/>', [(lx - r), (y - 4), ((m.cx - m.rx) + 6), (y - 10), (rx_ + r), (y - 4), ((m.cx + m.rx) - 6), (y - 10)])
	var bridge = fmt('<path d="M{:.1f} {} Q {} {} {:.1f} {}" stroke="#6B4A3A" stroke-width="4" fill="none" stroke-linecap="round"/>', [((lx + r) - 2), (y - 2), m.cx, (y - 10), ((rx_ - r) + 2), (y - 2)])
	return svg(((((arms + bridge) + lens.call(lx, y, r)) + lens.call(rx_, y, r)) + extra))

static func i_sunglasses(m: Dictionary) -> String:
	var _lam1 = func(x, y, r):
		return fmt('<path d="M{:.1f} {:.1f} H {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#2B2330" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} l {:.1f} 0" stroke="#7A6E85" stroke-width="4" stroke-linecap="round"/>', [(x - r), (y - (r * 0.6)), (x + r), (x + r), (y + r), x, (y + (r * 0.9)), (x - r), (y + r), (x - r), (y - (r * 0.6)), (x - (r * 0.6)), (y - (r * 0.25)), (r * 0.5)])
	return _two_lenses(m, _lam1)

static func i_heart_glasses(m: Dictionary) -> String:
	var _lam1 = func(x, y, r):
		return (heart(x, (y - 2), (r * 0.95), '#F590B4', 0, 0.85) + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="3" fill="#FFFFFF" opacity="0.8"/>', [(x - (r * 0.4)), (y - (r * 0.4))]))
	return _two_lenses(m, _lam1)

static func i_monocle(m: Dictionary) -> String:
	var y = m.eye_y
	var r = (m.eye_r + 8)
	var x = (m.cx + m.eye_dx)
	return svg(fmt('<circle cx="{}" cy="{}" r="{}" fill="#DDEEFF" fill-opacity="0.35" stroke="#D9961A" stroke-width="5"/><circle cx="{}" cy="{}" r="{}" fill="none" stroke="#6B4A3A" stroke-width="1.5"/><path d="M{:.1f} {:.1f} q 10 30 -6 54" stroke="#D9961A" stroke-width="3" fill="none" stroke-dasharray="4 3" stroke-linecap="round"/><path d="M{:.1f} {:.1f} q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>', [x, y, r, x, y, r, (x + (r * 0.5)), (y + (r * 0.85)), (x - (r * 0.45)), (y - (r * 0.5)), (r * 0.25), ((-r) * 0.2), (r * 0.5), ((-r) * 0.12)]))

static func i_plaster(m: Dictionary) -> String:
	var x = (m.cx - (m.rx * 0.3))
	var y = (top(m, x) + 22)
	var strip = func(rot):
		var _j1 = []
		for dx in [(-15), 15]:
			for dy in [(-2), 2]:
				_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="1.2" fill="#C99A72"/>', [(x + dx), (y + dy)]))
		return ((fmt('<g transform="rotate({} {:.1f} {:.1f})"><rect x="{:.1f}" y="{:.1f}" width="44" height="14" rx="7" fill="#F7D3B0" stroke="#6B4A3A" stroke-width="3"/><rect x="{:.1f}" y="{:.1f}" width="14" height="12" fill="#EEC09A"/>', [rot, x, y, (x - 22), (y - 7), (x - 7), (y - 6)]) + ''.join(PackedStringArray(_j1))) + '</g>')
	return svg((strip.call(35) + strip.call((-35))))

static func i_rose_clip(m: Dictionary) -> String:
	var _r1 = clip_at(m, (-1))
	var x = _r1[0]
	var y = _r1[1]
	return svg(fmt('<path d="M{:.1f} {:.1f} q -16 4 -18 -6 q 10 -4 18 6 Z M{:.1f} {:.1f} q 16 4 18 -6 q -10 -4 -18 6 Z" fill="#6CC27A" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><circle cx="{:.1f}" cy="{:.1f}" r="13" fill="#E4505C" stroke="#6B4A3A" stroke-width="4"/><path d="M{:.1f} {:.1f} q 0 -9 7 -9 q 7 1 5 7 q -2 5 -7 3 q -3 -2 -1 -4" stroke="#A62A3C" stroke-width="2.5" fill="none" stroke-linecap="round"/>', [(x - 6), (y + 8), (x + 6), (y + 8), x, y, (x - 6), (y + 2)]))

static func i_feather_clip(m: Dictionary) -> String:
	var _r1 = clip_at(m, 1)
	var x = _r1[0]
	var y = _r1[1]
	var _j2 = []
	for k in [8, 16, 24, 32]:
		for s in [(-1), 1]:
			_j2.append(fmt('<path d="M{:.1f} {:.1f} l {} -6" stroke="#4F8FD0" stroke-width="2" stroke-linecap="round"/>', [x, (y - k), (s * 8)]))
	return svg(((fmt('<g transform="rotate(28 {:.1f} {:.1f})"><path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} L {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="2.5" stroke-linecap="round"/>', [x, y, x, (y + 4), (x - 14), (y - 10), (x - 10), (y - 34), x, (y - 46), (x + 10), (y - 34), (x + 14), (y - 10), x, (y + 4), x, (y + 8), x, (y - 40)]) + ''.join(PackedStringArray(_j2))) + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="5" fill="#FFCF5C" stroke="#6B4A3A" stroke-width="2.5"/></g>', [x, (y + 6)])))

static func i_heart_tag(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 6)
	return svg(((neck_arc(m, '#7C4DD6', 10) + heart(cx, (y + 18), 11, '#FFCF5C')) + fmt('<circle cx="{}" cy="{}" r="3" fill="none" stroke="#6B4A3A" stroke-width="2.5"/>', [cx, (y + 9)])))

static func i_clover_clip(m: Dictionary) -> String:
	var _r1 = clip_at(m, (-1))
	var x = _r1[0]
	var y = _r1[1]
	var _j2 = []
	for a in [(-90), 0, 90, 180]:
		_j2.append(heart((x + (9 * cos(deg_to_rad(a)))), (y + (9 * sin(deg_to_rad(a)))), 8, '#6CC27A', (a + 90)))
	var leaves = ''.join(PackedStringArray(_j2))
	return svg(((fmt('<path d="M{:.1f} {:.1f} q 6 10 2 18" stroke="#6B4A3A" stroke-width="4" fill="none" stroke-linecap="round"/>', [x, y]) + leaves) + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="3" fill="#4FA35C"/>', [x, y])))

static func i_fish_clip(m: Dictionary) -> String:
	var _r1 = clip_at(m, 1)
	var x = _r1[0]
	var y = _r1[1]
	return svg(fmt('<g transform="rotate(-20 {:.1f} {:.1f})"><path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} l 12 -10 l 0 20 Z" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><circle cx="{:.1f}" cy="{:.1f}" r="2.6" fill="#6B4A3A"/></g>', [x, y, (x - 16), y, (x - 8), (y - 12), (x + 8), (y - 12), (x + 14), y, (x + 8), (y + 12), (x - 8), (y + 12), (x - 16), y, (x + 12), y, (x - 8), (y - 2)]))

static func i_lily_pad(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + 6)
	var pad = fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} A 40 16 0 1 1 {:.1f} {:.1f} Z" fill="#6CC27A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round" transform="translate(0 -4)"/><path d="M{:.1f} {:.1f} q 12 -6 22 0 M{:.1f} {:.1f} q 12 2 18 8" stroke="#4FA35C" stroke-width="2.5" fill="none" stroke-linecap="round"/>', [cx, y, (cx + 10), (y - 16), (cx - 4), (y - 17), (cx - 24), (y - 18), (cx + 6), (y - 26)])
	var fx = (cx + 18)
	var fy = (y - 26)
	var _j1 = []
	for a in range(0, 360, 72):
		_j1.append(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="7" ry="5" fill="#F7A8C4" stroke="#6B4A3A" stroke-width="2.5"/>', [(fx + (7 * cos(deg_to_rad(a)))), (fy + (5 * sin(deg_to_rad(a))))]))
	var flower = ''.join(PackedStringArray(_j1))
	return svg(((pad + flower) + fmt('<circle cx="{}" cy="{}" r="4" fill="#FFD84D" stroke="#6B4A3A" stroke-width="2"/>', [fx, fy])))


# --- Medium items (items_medium.py) ---------------------------------------------------
static func _crown_y(m):
	return top(m, m.cx)

static func i_baseball_cap(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.32))
	var hw = (m.rx * 0.74)
	var dome = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#E4505C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} V {:.1f}" stroke="#B83A45" stroke-width="3"/><circle cx="{:.1f}" cy="{:.1f}" r="5" fill="#E4505C" stroke="#6B4A3A" stroke-width="3"/>', [(cx - hw), y, (cx - hw), (y - 50), (cx + hw), (y - 50), (cx + hw), y, cx, (y - 37), y, cx, (y - 38)])
	var peak = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx + (hw * 0.2)), (y - 4), ((cx + hw) + 30), (y - 8), ((cx + hw) + 34), (y + 6), (cx + (hw * 0.6)), (y + 12), (cx + (hw * 0.1)), (y + 4)])
	return svg(((dome + peak) + star((cx - 12), (y - 18), 8, '#FFFFFF', LINE, 2.5)))

static func i_bucket_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.36))
	var hw = (m.rx * 0.66)
	var brim = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} Z" fill="#9ED7A8" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [((cx - hw) - 20), (y + 6), cx, (y + 22), ((cx + hw) + 20), (y + 6), (cx + hw), (y - 6), (cx - hw), (y - 6)])
	var crown = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#9ED7A8" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), (y - 4), ((cx - hw) + 4), (y - 44), ((cx + hw) - 4), (y - 44), (cx + hw), (y - 4)])
	var _j1 = []
	for _t2 in [[((-hw) * 0.5), (-20)], [0, (-30)], [(hw * 0.5), (-18)], [((-hw) * 0.2), (-10)], [(hw * 0.25), (-6)]]:
		var dx = _t2[0]
		var dy = _t2[1]
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="4" fill="#FFFFFF"/>', [(cx + dx), (y + dy)]))
	var dots = ''.join(PackedStringArray(_j1))
	return svg(((brim + crown) + dots))

static func i_flower_crown(m: Dictionary) -> String:
	var cx = m.cx
	var y0 = (_crown_y(m) + 16)
	var out = ''
	var cols = ['#F7A8C4', '#FFFFFF', '#FFD84D', '#C8A8FF', '#F7A8C4', '#FFFFFF', '#FFD84D']
	var _s1 = [(-0.66), (-0.44), (-0.22), 0, 0.22, 0.44, 0.66]
	for i in _s1.size():
		var f = _s1[i]
		var x = (cx + (f * m.rx))
		var y = (top(m, x) + 12)
		out += fmt('<path d="M{:.1f} {:.1f} q 4 -10 12 -6" fill="#6CC27A" stroke="#6B4A3A" stroke-width="2.5"/>', [(x - 10), (y + 4)])
		var _j2 = []
		for a in range(0, 360, 72):
			_j2.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="5.5" fill="{}" stroke="#6B4A3A" stroke-width="2.5"/>', [(x + (6 * cos(deg_to_rad(a)))), (y + (6 * sin(deg_to_rad(a)))), cols[i]]))
		out += ''.join(PackedStringArray(_j2))
		out += fmt('<circle cx="{:.1f}" cy="{:.1f}" r="3.5" fill="#F59A4A"/>', [x, y])
	return svg(out)

static func i_headphones(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) - 6)
	var rx = (m.rx * 0.98)
	var band = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="16" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#B59AF0" stroke-width="9" fill="none" stroke-linecap="round"/>', [(cx - rx), m.cy, (cx - rx), (y - 10), (cx + rx), (y - 10), (cx + rx), m.cy, (cx - rx), m.cy, (cx - rx), (y - 10), (cx + rx), (y - 10), (cx + rx), m.cy])
	var _j1 = []
	for s in [(-1), 1]:
		_j1.append(fmt('<rect x="{:.1f}" y="{:.1f}" width="26" height="40" rx="12" fill="#7C4DD6" stroke="#6B4A3A" stroke-width="4"/><rect x="{:.1f}" y="{:.1f}" width="14" height="24" rx="7" fill="#C8A8FF"/>', [((cx + (s * rx)) - 13), (m.cy - 14), ((cx + (s * rx)) - 7), (m.cy - 6)]))
	var cups = ''.join(PackedStringArray(_j1))
	return svg((band + cups))

static func i_pirate_bandana(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.42))
	var hw = (m.rx * 0.86)
	var cap = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#E4505C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), y, (cx - hw), (y - 52), (cx + hw), (y - 52), (cx + hw), y, cx, (y + 10), (cx - hw), y])
	var _j1 = []
	for _t2 in [[((-hw) * 0.55), (-16)], [((-hw) * 0.1), (-32)], [(hw * 0.4), (-24)], [(hw * 0.15), (-8)], [((-hw) * 0.35), (-2)]]:
		var dx = _t2[0]
		var dy = _t2[1]
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="4.5" fill="#FFFFFF"/>', [(cx + dx), (y + dy)]))
	var dots = ''.join(PackedStringArray(_j1))
	var knot = fmt('<path d="M{:.1f} {:.1f} l 22 -4 l -4 14 Z M{:.1f} {:.1f} l 18 14 l -12 6 Z" fill="#E4505C" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [((cx + hw) - 6), (y - 4), ((cx + hw) - 6), (y - 4)])
	return svg(((cap + dots) + knot))

static func i_cowboy_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + 12)
	var bw = (m.rx * 1.05)
	var brim = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#C88A4E" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - bw), (y - 12), (cx - (bw * 0.6)), (y + 12), cx, (y + 10), (cx + (bw * 0.6)), (y + 12), (cx + bw), (y - 12), (cx + (bw * 0.7)), (y + 2), cx, y, (cx - (bw * 0.7)), (y + 2), (cx - bw), (y - 12)])
	var crown = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#D99A5B" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - 38), (y + 2), (cx - 42), (y - 40), (cx - 20), (y - 50), cx, (y - 40), (cx + 20), (y - 50), (cx + 42), (y - 40), (cx + 38), (y + 2)])
	var band = (fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#7A4A2A" stroke-width="7" fill="none"/>', [(cx - 38), (y - 8), cx, (y - 2), (cx + 38), (y - 8)]) + star(cx, (y - 8), 6, '#FFCF5C', LINE, 2))
	return svg(((crown + brim) + band))

static func i_alice_band(m: Dictionary) -> String:
	var cx = m.cx
	var rx = (m.rx * 0.86)
	var y = (_crown_y(m) + 14)
	var band = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="15" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#F590B4" stroke-width="8" fill="none" stroke-linecap="round"/>', [(cx - rx), (y + 34), cx, (y - 30), (cx + rx), (y + 34), (cx - rx), (y + 34), cx, (y - 30), (cx + rx), (y + 34)])
	var bx = (cx + (rx * 0.5))
	var by = (y + 4)
	var bow = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#F590B4" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><circle cx="{:.1f}" cy="{:.1f}" r="6" fill="#E07BA0" stroke="#6B4A3A" stroke-width="3"/>', [bx, by, (bx - 12), (by - 16), (bx - 28), (by - 12), (bx - 26), by, (bx - 28), (by + 12), (bx - 12), (by + 14), bx, by, bx, by, (bx + 12), (by - 16), (bx + 28), (by - 12), (bx + 26), by, (bx + 28), (by + 12), (bx + 12), (by + 14), bx, by, bx, by])
	return svg((band + bow))

static func i_tiara(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + 14)
	var w = (m.rx * 0.5)
	var pts = fmt('{:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f}', [(cx - w), y, (cx - (w * 0.7)), (y - 12), (cx - (w * 0.35)), (y - 6), cx, (y - 26), (cx + (w * 0.35)), (y - 6), (cx + (w * 0.7)), (y - 12), (cx + w), y])
	var _j1 = []
	for s in [(-1), 1]:
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="3.2" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="2"/>', [(cx + ((s * w) * 0.62)), (y - 4)]))
	return svg((fmt('<polygon points="{}" fill="#E8EEF7" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="3" fill="none"/><circle cx="{:.1f}" cy="{:.1f}" r="5" fill="#F590B4" stroke="#6B4A3A" stroke-width="2"/>', [pts, (cx - w), y, cx, (y + 6), (cx + w), y, cx, (y - 12)]) + ''.join(PackedStringArray(_j1))))

static func i_chef_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + 14)
	var hw = (m.rx * 0.42)
	var band = fmt('<rect x="{:.1f}" y="{:.1f}" width="{:.1f}" height="22" rx="4" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="4"/>', [(cx - hw), (y - 18), (2 * hw)])
	var _j1 = []
	for _t2 in [[((-hw) * 0.7), 18, 20], [(hw * 0.7), 18, 20], [0, 30, 24]]:
		var dx = _t2[0]
		var dy = _t2[1]
		var r = _t2[2]
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="{}" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="4"/>', [(cx + dx), ((y - 18) - dy), r]))
	var puffs = ''.join(PackedStringArray(_j1))
	var cover = fmt('<rect x="{:.1f}" y="{:.1f}" width="{:.1f}" height="24" fill="#FFFFFF"/>', [((cx - hw) + 3), (y - 40), ((2 * hw) - 6)])
	var _j3 = []
	for dx in [((-hw) * 0.5), 0, (hw * 0.5)]:
		_j3.append(fmt('<path d="M{:.1f} {:.1f} v 14" stroke="#E3DCD3" stroke-width="2.5"/>', [(cx + dx), (y - 14)]))
	var lines = ''.join(PackedStringArray(_j3))
	return svg((((puffs + cover) + band) + lines))

static func i_bow_tie(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 2)
	var _j1 = []
	for s in [(-1), 1]:
		for _t2 in [[14, (-4)], [19, 5]]:
			var dx = _t2[0]
			var dy = _t2[1]
			_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="2.2" fill="#FFFFFF"/>', [(cx + (s * dx)), (y + dy)]))
	return svg((fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z M{:.1f} {:.1f} L {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#E4505C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><rect x="{:.1f}" y="{:.1f}" width="14" height="16" rx="5" fill="#C93C48" stroke="#6B4A3A" stroke-width="3"/>', [cx, y, (cx - 26), (y - 13), (cx - 30), y, (cx - 26), (y + 13), cx, y, (cx + 26), (y - 13), (cx + 30), y, (cx + 26), (y + 13), (cx - 7), (y - 8)]) + ''.join(PackedStringArray(_j1))))

static func i_sweatband(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.38))
	var hw = (m.rx * 0.9)
	var d = fmt('M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}', [(cx - hw), y, cx, (y - 22), (cx + hw), y])
	return svg(fmt('<path d="{}" stroke="#6B4A3A" stroke-width="26" fill="none" stroke-linecap="round"/><path d="{}" stroke="#FFFFFF" stroke-width="18" fill="none" stroke-linecap="round"/><path d="{}" stroke="#7FBCF5" stroke-width="6" fill="none" stroke-linecap="round"/>', [d, d, d]))

static func i_bee_antennae(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + 16)
	var out = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="10" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#2B2330" stroke-width="5" fill="none" stroke-linecap="round"/>', [(cx - 40), (y + 4), cx, (y - 18), (cx + 40), (y + 4), (cx - 40), (y + 4), cx, (y - 18), (cx + 40), (y + 4)])
	for s in [(-1), 1]:
		var x0 = (cx + (s * 20))
		var y0 = (y - 8)
		out += fmt('<path d="M{:.1f} {:.1f} q {:.1f} -30 {:.1f} -40" stroke="#6B4A3A" stroke-width="4" fill="none" stroke-linecap="round"/>', [x0, y0, (s * 4), (s * 18)])
		out += fmt('<circle cx="{:.1f}" cy="{:.1f}" r="9" fill="#FFD84D" stroke="#6B4A3A" stroke-width="4"/><path d="M{:.1f} {:.1f} h 16" stroke="#6B4A3A" stroke-width="3.5"/>', [(x0 + (s * 18)), (y0 - 42), ((x0 + (s * 18)) - 8), (y0 - 42)])
	return svg(out)

static func i_devil_horns(m: Dictionary) -> String:
	var cx = m.cx
	var out = ''
	for s in [(-1), 1]:
		var x = (cx + ((s * m.rx) * 0.3))
		var y = (top(m, x) + 8)
		out += fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#E4505C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(x - 11), y, (x + (s * 4)), (y - 20), (x + (s * 14)), (y - 32), (x + (s * 10)), (y - 12), (x + 11), y])
	return svg(out)

static func i_halo(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) - 22)
	var rx = (m.rx * 0.55)
	return svg(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="{:.1f}" ry="12" fill="none" stroke="#6B4A3A" stroke-width="14"/><ellipse cx="{:.1f}" cy="{:.1f}" rx="{:.1f}" ry="12" fill="none" stroke="#FFE07A" stroke-width="8"/><path d="M{:.1f} {:.1f} q {:.1f} -4 {:.1f} -2" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>', [cx, y, rx, cx, y, rx, (cx - (rx * 0.5)), (y - 9), (rx * 0.3), (rx * 0.6)]))

static func i_visor(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.36))
	var hw = (m.rx * 0.88)
	var band = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="18" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#86D9B0" stroke-width="10" fill="none" stroke-linecap="round"/>', [(cx - hw), y, cx, (y - 22), (cx + hw), y, (cx - hw), y, cx, (y - 22), (cx + hw), y])
	var peak = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#86D9B0" fill-opacity="0.85" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - (hw * 0.6)), (y - 6), cx, (y + 26), (cx + (hw * 0.6)), (y - 6), cx, (y + 4), (cx - (hw * 0.6)), (y - 6)])
	return svg((band + peak))

static func i_lei(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 2)
	var half = (m.rx * 0.58)
	var out = ''
	var cols = ['#F7A8C4', '#FFD84D', '#FFFFFF', '#F59A4A', '#C8A8FF']
	for i in range(10):
		var f = (float(i) / 9)
		var x = ((cx - half) + ((2 * half) * f))
		var yy = ((y - 6) + (22 * (1 - pow(((2 * f) - 1), 2))))
		var _j1 = []
		for a in range(0, 360, 72):
			_j1.append(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="6" ry="4.5" transform="rotate({} {:.1f} {:.1f})" fill="{}" stroke="#6B4A3A" stroke-width="2"/>', [(x + (6 * cos(deg_to_rad(a)))), (yy + (6 * sin(deg_to_rad(a)))), a, (x + (6 * cos(deg_to_rad(a)))), (yy + (6 * sin(deg_to_rad(a)))), cols[(i % 5)]]))
		out += ''.join(PackedStringArray(_j1))
		out += fmt('<circle cx="{:.1f}" cy="{:.1f}" r="2.6" fill="#F59A4A"/>', [x, yy])
	return svg(out)

static func i_necktie(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 6)
	var _j1 = []
	for k in [26, 38, 50]:
		_j1.append(fmt('<path d="M{:.1f} {:.1f} l 16 -6" stroke="#FFCF5C" stroke-width="3.5" stroke-linecap="round"/>', [(cx - 8), (y + k)]))
	return svg(((neck_arc(m, '#FFFFFF', 8) + fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} Z" fill="#5B8FD6" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - 8), (y + 6), (cx + 8), (y + 6), (cx + 5), (y + 14), (cx + 12), (y + 48), cx, (y + 58), (cx - 12), (y + 48), (cx - 5), (y + 14)])) + ''.join(PackedStringArray(_j1))))

static func i_mushroom_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.3))
	var hw = (m.rx * 0.95)
	var cap = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#E4505C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), y, (cx - hw), (y - 66), (cx + hw), (y - 66), (cx + hw), y, cx, (y + 12), (cx - hw), y])
	var _j1 = []
	for _t2 in [[((-hw) * 0.55), (-16), 9], [((-hw) * 0.1), (-38), 11], [(hw * 0.45), (-24), 10], [(hw * 0.1), (-10), 6], [((-hw) * 0.32), (-34), 5]]:
		var dx = _t2[0]
		var dy = _t2[1]
		var r = _t2[2]
		_j1.append(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="{}" ry="{:.1f}" fill="#FFFFFF"/>', [(cx + dx), (y + dy), r, (r * 0.8)]))
	var spots = ''.join(PackedStringArray(_j1))
	return svg((cap + spots))

static func i_santa_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.35))
	var hw = (m.rx * 0.74)
	var body = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#E4505C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), y, (cx - (hw * 0.6)), (y - 60), (cx + (hw * 0.4)), (y - 80), ((cx + hw) + 22), (y - 40), (cx + (hw * 0.6)), (y - 40), (cx + hw), y])
	var trim = fmt('<rect x="{:.1f}" y="{:.1f}" width="{:.1f}" height="22" rx="11" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="4"/>', [((cx - hw) - 6), (y - 12), ((2 * hw) + 12)])
	var pom = fmt('<circle cx="{:.1f}" cy="{:.1f}" r="12" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="4"/>', [((cx + hw) + 24), (y - 38)])
	return svg(((body + trim) + pom))

static func i_pumpkin_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.36))
	var hw = (m.rx * 0.82)
	var _j1 = []
	for dx in [(-0.55), 0.55, (-0.2), 0.2]:
		_j1.append(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="{:.1f}" ry="30" fill="#F59A4A" stroke="#6B4A3A" stroke-width="4"/>', [(cx + (dx * hw)), (y - 22), (hw * 0.42)]))
	var lobes = ''.join(PackedStringArray(_j1))
	var mid = fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="{:.1f}" ry="31" fill="#F7A85A" stroke="#6B4A3A" stroke-width="4"/>', [cx, (y - 22), (hw * 0.34)])
	var stem = fmt('<path d="M{:.1f} {:.1f} q 2 -16 12 -18" stroke="#6B4A3A" stroke-width="10" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} q 2 -16 12 -18" stroke="#6CC27A" stroke-width="5" fill="none" stroke-linecap="round"/>', [(cx - 5), (y - 50), (cx - 5), (y - 50)])
	return svg(((lobes + mid) + stem))

static func i_propeller_cap(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.3))
	var hw = (m.rx * 0.7)
	var segs = ['#E4505C', '#FFD84D', '#5B8FD6', '#6CC27A']
	var out = ''
	for i in range(4):
		var a0 = (PI + (float((i * PI)) / 4))
		var a1 = (a0 + (float(PI) / 4))
		out += fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} A {:.1f} 44 0 0 1 {:.1f} {:.1f} Z" fill="{}" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [cx, y, (cx + (hw * cos(a0))), (y + (44 * sin(a0))), hw, (cx + (hw * cos(a1))), (y + (44 * sin(a1))), segs[i]])
	out += fmt('<path d="M{:.1f} {:.1f} H {:.1f}" stroke="#6B4A3A" stroke-width="4" stroke-linecap="round"/>', [(cx - hw), y, (cx + hw)])
	out += fmt('<path d="M{:.1f} {:.1f} v -10" stroke="#6B4A3A" stroke-width="4"/>', [cx, (y - 44)])
	out += fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="3"/><circle cx="{:.1f}" cy="{:.1f}" r="4" fill="#FFD84D" stroke="#6B4A3A" stroke-width="2"/>', [(cx - 30), (y - 58), cx, (y - 50), (cx + 30), (y - 58), cx, (y - 64), (cx - 30), (y - 58), cx, (y - 56)])
	return svg(out)

static func i_daisy_chain(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 2)
	var half = (m.rx * 0.58)
	var out = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6CC27A" stroke-width="4" fill="none"/>', [(cx - half), (y - 6), cx, (y + 26), (cx + half), (y - 6)])
	for i in range(7):
		var f = (float(i) / 6)
		var x = ((cx - half) + ((2 * half) * f))
		var yy = ((y - 6) + (16 * (1 - pow(((2 * f) - 1), 2))))
		var _j1 = []
		for a in range(0, 360, 45):
			_j1.append(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="5.5" ry="3.6" transform="rotate({} {:.1f} {:.1f})" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="2"/>', [(x + (7 * cos(deg_to_rad(a)))), (yy + (7 * sin(deg_to_rad(a)))), a, (x + (7 * cos(deg_to_rad(a)))), (yy + (7 * sin(deg_to_rad(a))))]))
		out += ''.join(PackedStringArray(_j1))
		out += fmt('<circle cx="{:.1f}" cy="{:.1f}" r="4" fill="#FFD84D" stroke="#6B4A3A" stroke-width="2"/>', [x, yy])
	return svg(out)

static func i_rain_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (_crown_y(m) + (m.ry * 0.34))
	var hw = (m.rx * 0.72)
	var brim = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [((cx - hw) - 26), (y + 2), cx, (y + 18), ((cx + hw) + 16), (y - 4), (cx + hw), (y - 12), cx, (y - 8), (cx - hw), (y - 8), ((cx - hw) - 26), (y + 2)])
	var crown = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#7FBCF5" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), (y - 6), (cx - hw), (y - 50), (cx + hw), (y - 50), (cx + hw), (y - 6)])
	var seam = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#4F8FD0" stroke-width="3" fill="none" stroke-dasharray="5 4"/>', [(cx - (hw * 0.7)), (y - 26), cx, (y - 40), (cx + (hw * 0.7)), (y - 26)])
	var drop = fmt('<path d="M{:.1f} {:.1f} q 6 8 0 12 q -6 -4 0 -12 Z" fill="#FFFFFF" opacity="0.85"/>', [(cx + (hw * 0.4)), (y - 30)])
	return svg((((brim + crown) + seam) + drop))


# --- Large items (items_large.py) -----------------------------------------------------
static func _hood(m, colour, inner = '#FFFFFF', pad = 16):
	# A hood round the head with a face opening; returns (svg body, top y).
	var cx = m.cx
	var cy = m.cy
	var rx = (m.rx + pad)
	var ry = (m.ry + pad)
	var fx = cx
	var fy = (cy + 12)
	var frx = (m.rx * 0.8)
	var fry = (m.ry * 0.74)
	var d = fmt('M{:.1f} {:.1f} A {:.1f} {:.1f} 0 1 1 {:.1f} {:.1f} A {:.1f} {:.1f} 0 1 1 {:.1f} {:.1f} Z M{:.1f} {:.1f} A {:.1f} {:.1f} 0 1 0 {:.1f} {:.1f} A {:.1f} {:.1f} 0 1 0 {:.1f} {:.1f} Z', [(cx - rx), cy, rx, ry, (cx + rx), cy, rx, ry, (cx - rx), cy, (fx - frx), fy, frx, fry, (fx + frx), fy, frx, fry, (fx - frx), fy])
	var rim = fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="{:.1f}" ry="{:.1f}" fill="none" stroke="{}" stroke-width="5"/>', [fx, fy, frx, fry, inner])
	var body = (fmt('<path d="{}" fill="{}" fill-rule="evenodd" stroke="#6B4A3A" stroke-width="4"/>', [d, colour]) + rim)
	return [body, (cy - ry)]

static func i_frog_hood(m: Dictionary) -> String:
	var _r1 = _hood(m, '#7FCF86', '#B9E9BE')
	var body = _r1[0]
	var ty = _r1[1]
	var cx = m.cx
	var _j2 = []
	for s in [(-1), 1]:
		_j2.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="20" fill="#7FCF86" stroke="#6B4A3A" stroke-width="4"/><circle cx="{:.1f}" cy="{:.1f}" r="11" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="3"/><circle cx="{:.1f}" cy="{:.1f}" r="5.5" fill="#2B2330"/>', [(cx + ((s * m.rx) * 0.42)), (ty + 8), (cx + ((s * m.rx) * 0.42)), (ty + 6), ((cx + ((s * m.rx) * 0.42)) + 2), (ty + 7)]))
	var eyes = ''.join(PackedStringArray(_j2))
	var _j3 = []
	for s in [(-1), 1]:
		_j3.append(fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="9" ry="6" fill="#F59C9C" opacity="0.6"/>', [(cx + (s * (m.rx + 4))), (m.cy + 30)]))
	var cheeks = ''.join(PackedStringArray(_j3))
	return svg(((body + eyes) + cheeks))

static func i_dino_hood(m: Dictionary) -> String:
	var _r1 = _hood(m, '#86C9E8', '#C9E8F5')
	var body = _r1[0]
	var ty = _r1[1]
	var cx = m.cx
	var spikes = ''
	var _s2 = [(-0.5), (-0.17), 0.17, 0.5]
	for i in _s2.size():
		var f = _s2[i]
		var x = (cx + (f * (m.rx + 16)))
		var y = (top(_with(m, {'rx': (m.rx + 16), 'ry': (m.ry + 16)}), x) + 2)
		spikes += fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} Z" fill="#F59A4A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(x - 13), (y + 6), x, (y - 22), (x + 13), (y + 6)])
	var _j3 = []
	for _t4 in [[((-m.rx) - 2), (-10), 6], [(m.rx + 4), 0, 5], [((-m.rx) * 0.6), ((-m.ry) - 4), 5]]:
		var dx = _t4[0]
		var dy = _t4[1]
		var r = _t4[2]
		_j3.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="{}" fill="#5FA8CF"/>', [(cx + dx), (m.cy + dy), r]))
	var spots = ''.join(PackedStringArray(_j3))
	return svg(((spikes + body) + spots))

static func i_bear_hood(m: Dictionary) -> String:
	var _r1 = _hood(m, '#B98A5A', '#E2C9A6')
	var body = _r1[0]
	var ty = _r1[1]
	var cx = m.cx
	var _j2 = []
	for s in [(-1), 1]:
		_j2.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="20" fill="#B98A5A" stroke="#6B4A3A" stroke-width="4"/><circle cx="{:.1f}" cy="{:.1f}" r="10" fill="#E2C9A6"/>', [(cx + ((s * m.rx) * 0.72)), (ty + 22), (cx + ((s * m.rx) * 0.72)), (ty + 22)]))
	var ears = ''.join(PackedStringArray(_j2))
	return svg((ears + body))

static func i_astronaut_helmet(m: Dictionary) -> String:
	var cx = m.cx
	var cy = (m.cy + 8)
	var r = (max(m.rx, m.ry) + 26)
	var glass = fmt('<circle cx="{:.1f}" cy="{:.1f}" r="{:.1f}" fill="#DDEEFF" fill-opacity="0.28" stroke="#6B4A3A" stroke-width="4"/>', [cx, cy, r])
	var shine = fmt('<path d="M{:.1f} {:.1f} A {:.1f} {:.1f} 0 0 1 {:.1f} {:.1f}" stroke="#FFFFFF" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.85"/>', [(cx - (r * 0.62)), (cy - (r * 0.3)), (r * 0.7), (r * 0.7), (cx - (r * 0.1)), (cy - (r * 0.7))])
	var collar = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="22" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#E8EEF7" stroke-width="14" fill="none" stroke-linecap="round"/>', [(cx - (r * 0.86)), (cy + (r * 0.5)), cx, (cy + (r * 0.9)), (cx + (r * 0.86)), (cy + (r * 0.5)), (cx - (r * 0.86)), (cy + (r * 0.5)), cx, (cy + (r * 0.9)), (cx + (r * 0.86)), (cy + (r * 0.5))])
	var light = fmt('<circle cx="{:.1f}" cy="{:.1f}" r="6" fill="#E4505C" stroke="#6B4A3A" stroke-width="2.5"/>', [(cx + (r * 0.7)), (cy + (r * 0.55))])
	return svg((((glass + shine) + collar) + light))

static func i_viking_helmet(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + (m.ry * 0.42))
	var hw = (m.rx * 0.82)
	var _j1 = []
	for s in [(-1), 1]:
		_j1.append(fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#FFF4CC" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx + ((s * hw) * 0.8)), (y - 18), (cx + (s * (hw + 30))), (y - 24), (cx + (s * (hw + 30))), (y - 60), (cx + (s * (hw + 10))), (y - 74), (cx + (s * (hw + 14))), (y - 50), (cx + (s * hw)), (y - 40), (cx + ((s * hw) * 0.6)), (y - 34)]))
	var horns = ''.join(PackedStringArray(_j1))
	var dome = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#A9B4C2" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), y, (cx - hw), (y - 62), (cx + hw), (y - 62), (cx + hw), y])
	var band = fmt('<rect x="{:.1f}" y="{:.1f}" width="{:.1f}" height="16" rx="8" fill="#D9961A" stroke="#6B4A3A" stroke-width="4"/>', [((cx - hw) - 4), (y - 12), ((2 * hw) + 8)])
	var _j2 = []
	for f in [(-0.66), (-0.33), 0, 0.33, 0.66]:
		_j2.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="2.5" fill="#FFF0C2"/>', [(cx + (f * hw)), (y - 4)]))
	var rivets = ''.join(PackedStringArray(_j2))
	var ridge = fmt('<path d="M{:.1f} {:.1f} V {:.1f}" stroke="#D9961A" stroke-width="7"/>', [cx, (y - 46), (y - 12)])
	return svg(((((horns + dome) + ridge) + band) + rivets))

static func i_knight_helmet(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + (m.ry * 0.5))
	var hw = (m.rx * 0.86)
	var dome = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#C5CEDA" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), y, (cx - hw), (y - 70), (cx + hw), (y - 70), (cx + hw), y])
	var visor = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="12" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#E8EEF7" stroke-width="6" fill="none" stroke-linecap="round"/>', [(cx - (hw * 0.9)), (y - 2), cx, (y - 24), (cx + (hw * 0.9)), (y - 2), (cx - (hw * 0.9)), (y - 2), cx, (y - 24), (cx + (hw * 0.9)), (y - 2)])
	var _j1 = []
	for _t2 in [[0, LINE, 18], [0, '#E4505C', 11], [1, '#F590B4', 5]]:
		var s = _t2[0]
		var c = _t2[1]
		var w = _t2[2]
		_j1.append(fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f}" stroke="{}" stroke-width="{}" fill="none" stroke-linecap="round"/>', [cx, (y - 52), (cx + (s * 10)), (y - 80), ((cx - 30) + (s * 6)), (y - 96), ((cx - 44) + (s * 8)), (y - 86), c, w]))
	var plume = ''.join(PackedStringArray(_j1))
	return svg(((plume + dome) + visor))

static func i_tricorn(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + 16)
	var w = (m.rx * 1.0)
	var hat = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#3B3346" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#D9961A" stroke-width="5" fill="none"/>', [(cx - w), (y - 4), (cx - (w * 0.5)), (y - 54), cx, (y - 50), (cx + (w * 0.5)), (y - 54), (cx + w), (y - 4), cx, (y - 22), (cx - w), (y - 4), (cx - (w * 0.92)), (y - 8), cx, (y - 26), (cx + (w * 0.92)), (y - 8)])
	var skull = fmt('<circle cx="{:.1f}" cy="{:.1f}" r="9" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="2.5"/><circle cx="{:.1f}" cy="{:.1f}" r="2" fill="#6B4A3A"/><circle cx="{:.1f}" cy="{:.1f}" r="2" fill="#6B4A3A"/>', [cx, (y - 34), (cx - 3), (y - 35), (cx + 3), (y - 35)])
	var feather = fmt('<path d="M{:.1f} {:.1f} q 30 -30 50 -14 q -24 -2 -50 14 Z" fill="#E4505C" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [(cx + (w * 0.5)), (y - 40)])
	return svg(((feather + hat) + skull))

static func i_top_hat(m: Dictionary) -> String:
	var cx = (m.cx + 4)
	var y = (top(m, cx) + 14)
	var bw = (m.rx * 0.72)
	var hw = (m.rx * 0.46)
	var h = 70
	var g = fmt('<g transform="rotate(8 {:.1f} {:.1f})">', [cx, y])
	var crown = fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} Z" fill="#3B3346" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), (y - 4), (cx - (hw * 0.92)), (y - h), cx, ((y - h) - 8), (cx + (hw * 0.92)), (y - h), (cx + hw), (y - 4)])
	var brim = fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="{:.1f}" ry="11" fill="#3B3346" stroke="#6B4A3A" stroke-width="4"/>', [cx, (y - 2), bw])
	var band = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#E4505C"/>', [(cx - hw), (y - 18), cx, (y - 12), (cx + hw), (y - 18), (cx + hw), (y - 30), cx, (y - 24), (cx - hw), (y - 30)])
	var _j1 = []
	for a in range(0, 360, 72):
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="5" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="2"/>', [(((cx + hw) - 4) + (6 * cos(deg_to_rad(a)))), ((y - 24) + (6 * sin(deg_to_rad(a))))]))
	var flower = (''.join(PackedStringArray(_j1)) + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="3.5" fill="#FFD84D"/>', [((cx + hw) - 4), (y - 24)]))
	return svg((((((g + crown) + brim) + band) + flower) + '</g>'))

static func i_jester_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + (m.ry * 0.36))
	var hw = (m.rx * 0.8)
	var out = ''
	for _t1 in [[(-1), '#7C4DD6'], [1, '#F59A4A'], [0, '#86D9B0']]:
		var s = _t1[0]
		var col = _t1[1]
		var tipx = (cx + (s * (hw + 26)))
		var tipy = ((y - 30) if s else (y - 72))
		out += fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="{}" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [((cx - (hw * 0.5)) + ((s * hw) * 0.5)), (y - 8), (cx + ((s * hw) * 0.7)), (tipy - 10), tipx, tipy, (cx + ((s * hw) * 0.3)), (y - 30), ((cx + (hw * 0.5)) + ((s * hw) * 0.5)), (y - 8), col])
		out += fmt('<circle cx="{:.1f}" cy="{:.1f}" r="8" fill="#FFD84D" stroke="#6B4A3A" stroke-width="3"/>', [tipx, tipy])
	var band = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="20" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#FFF4CC" stroke-width="12" fill="none" stroke-linecap="round"/>', [(cx - hw), y, cx, (y - 16), (cx + hw), y, (cx - hw), y, cx, (y - 16), (cx + hw), y])
	return svg((out + band))

static func i_mortarboard(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + (m.ry * 0.3))
	var hw = (m.rx * 0.55)
	var cap = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} Z" fill="#3B3346" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), y, cx, (y + 10), (cx + hw), y, (cx + hw), (y - 22), (cx - hw), (y - 22)])
	var board = fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} L {:.1f} {:.1f} Z" fill="#3B3346" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [cx, (y - 44), (cx + (hw * 1.6)), (y - 26), cx, (y - 10), (cx - (hw * 1.6)), (y - 26)])
	var tassel = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#FFCF5C" stroke-width="3.5" fill="none"/><path d="M{:.1f} {:.1f} h 10 l -2 16 h -6 Z" fill="#FFCF5C" stroke="#6B4A3A" stroke-width="2"/><circle cx="{:.1f}" cy="{:.1f}" r="4" fill="#FFCF5C"/>', [cx, (y - 27), (cx + (hw * 1.2)), (y - 26), (cx + (hw * 1.3)), (y + 6), ((cx + (hw * 1.3)) - 5), (y + 4), cx, (y - 27)])
	return svg(((cap + board) + tassel))

static func i_flower_bonnet(m: Dictionary) -> String:
	var cx = m.cx
	var rx = (m.rx + 10)
	var ry = (m.ry + 10)
	var cy = (m.cy - 6)
	var brim = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#FFF0C2" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - rx), (cy + 20), (cx - rx), ((cy - ry) - 10), (cx + rx), ((cy - ry) - 10), (cx + rx), (cy + 20), cx, (cy - (ry * 0.55)), (cx - rx), (cy + 20)])
	var _j1 = []
	for f in [(-0.7), (-0.35), 0, 0.35, 0.7]:
		_j1.append(fmt('<path d="M{:.1f} {:.1f} l 0 12" stroke="#E2C27A" stroke-width="3" stroke-linecap="round"/>', [(cx + (f * rx)), ((cy - ((ry * 0.9) * (1 - pow(abs(f), 2)))) + 6)]))
	var weave = ''.join(PackedStringArray(_j1))
	var _j2 = []
	for s in [(-1), 1]:
		_j2.append(fmt('<path d="M{:.1f} {:.1f} q {:.1f} 30 {:.1f} 52" stroke="#6B4A3A" stroke-width="10" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} q {:.1f} 30 {:.1f} 52" stroke="#F7A8C4" stroke-width="5" fill="none" stroke-linecap="round"/>', [(cx + (s * rx)), (cy + 20), (s * 6), (s * (-6)), (cx + (s * rx)), (cy + 20), (s * 6), (s * (-6))]))
	var ribbon = ''.join(PackedStringArray(_j2))
	var flowers = ''
	for _t3 in [[(-0.45), '#F7A8C4'], [(-0.2), '#FFFFFF'], [0.05, '#C8A8FF']]:
		var fx = _t3[0]
		var col = _t3[1]
		var x = (cx + (fx * rx))
		var y = ((cy - ((ry * 0.86) * (1 - (fx * fx)))) + 2)
		var _j4 = []
		for a in range(0, 360, 72):
			_j4.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="5.5" fill="{}" stroke="#6B4A3A" stroke-width="2"/>', [(x + (6 * cos(deg_to_rad(a)))), (y + (6 * sin(deg_to_rad(a)))), col]))
		flowers += (''.join(PackedStringArray(_j4)) + fmt('<circle cx="{:.1f}" cy="{:.1f}" r="3.5" fill="#FFD84D"/>', [x, y]))
	return svg((((ribbon + brim) + weave) + flowers))

static func i_lion_mane(m: Dictionary) -> String:
	var cx = m.cx
	var cy = (m.cy + 6)
	var n = 16
	var R = func(a, k):
		return [(cx + ((m.rx + k) * cos(a))), (cy + ((m.ry + k) * sin(a)))]
	var _l1 = []
	for i in range(n):
		_l1.append(R.call((float(((2 * PI) * i)) / n), 26))
	var pts = _l1
	var d = fmt('M{:.1f} {:.1f} ', [pts[0][0], pts[0][1]])
	for i in range(n):
		var _r2 = pts[((i + 1) % n)]
		var x2 = _r2[0]
		var y2 = _r2[1]
		d += fmt('A 15 15 0 0 1 {:.1f} {:.1f} ', [x2, y2])
	d += 'Z '
	var hx = cx
	var hy = m.cy
	var hrx = (m.rx - 1)
	var hry = (m.ry - 1)
	d += fmt('M{:.1f} {:.1f} A {:.1f} {:.1f} 0 1 0 {:.1f} {:.1f} A {:.1f} {:.1f} 0 1 0 {:.1f} {:.1f} Z', [(hx - hrx), hy, hrx, hry, (hx + hrx), hy, hrx, hry, (hx - hrx), hy])
	var _j3 = []
	var _l4 = []
	for i in range(n):
		_l4.append((float(((2 * PI) * (i + 0.5))) / n))
	for a in _l4:
		_j3.append(fmt('<path d="M{:.1f} {:.1f} L {:.1f} {:.1f}" stroke="#C47A2E" stroke-width="3" stroke-linecap="round"/>', [R.call(a, 14)[0], R.call(a, 14)[1], R.call(a, 30)[0], R.call(a, 30)[1]]))
	var tufts = ''.join(PackedStringArray(_j3))
	return svg((fmt('<path d="{}" fill="#E8A04F" fill-rule="evenodd" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [d]) + tufts))

static func i_garden_hat(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + 18)
	var bw = (m.rx * 1.2)
	var brim = fmt('<ellipse cx="{:.1f}" cy="{:.1f}" rx="{:.1f}" ry="16" fill="#F2D58A" stroke="#6B4A3A" stroke-width="4"/>', [cx, y, bw])
	var crown = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#F2D58A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - 44), (y - 4), (cx - 44), (y - 40), (cx + 44), (y - 40), (cx + 44), (y - 4)])
	var band = fmt('<path d="M{:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#86D9B0" stroke-width="8" fill="none"/>', [(cx - 43), (y - 12), cx, (y - 6), (cx + 43), (y - 12)])
	var _j1 = []
	for dx in range(((-int(bw)) + 16), (int(bw) - 10), 18):
		_j1.append(fmt('<path d="M{:.1f} {:.1f} l 4 8" stroke="#D9B45A" stroke-width="2.5" stroke-linecap="round"/>', [(cx + dx), (y + 2)]))
	var weave = ''.join(PackedStringArray(_j1))
	var _j2 = []
	for _t3 in [[28, 30], [40, 60]]:
		var dx = _t3[0]
		var r = _t3[1]
		_j2.append(fmt('<g transform="rotate({} {:.1f} {:.1f})"><path d="M{:.1f} {:.1f} h 12 l -6 24 Z" fill="#F59A4A" stroke="#6B4A3A" stroke-width="2.5" stroke-linejoin="round"/><path d="M{:.1f} {:.1f} q -6 -10 -2 -14 q 4 6 2 14 q 4 -10 10 -10 q -2 8 -10 10" fill="#6CC27A" stroke="#6B4A3A" stroke-width="2"/></g>', [r, (cx + dx), (y - 14), ((cx + dx) - 6), (y - 14), (cx + dx), (y - 15)]))
	var carrots = ''.join(PackedStringArray(_j2))
	return svg(((((brim + weave) + crown) + band) + carrots))


# --- Perk items (items_perk.py) -------------------------------------------------------
static func i_disco_headphones(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) - 6)
	var rx = (m.rx * 0.98)
	var band = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="18" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f}" stroke="#FFCF5C" stroke-width="10" fill="none" stroke-linecap="round"/>', [(cx - rx), m.cy, (cx - rx), (y - 10), (cx + rx), (y - 10), (cx + rx), m.cy, (cx - rx), m.cy, (cx - rx), (y - 10), (cx + rx), (y - 10), (cx + rx), m.cy])
	var _j1 = []
	for s in [(-1), 1]:
		_j1.append((fmt('<circle cx="{:.1f}" cy="{:.1f}" r="22" fill="#F590B4" stroke="#6B4A3A" stroke-width="4"/><circle cx="{:.1f}" cy="{:.1f}" r="12" fill="#FFCF5C" stroke="#6B4A3A" stroke-width="3"/>', [(cx + (s * rx)), (m.cy + 4), (cx + (s * rx)), (m.cy + 4)]) + star((cx + (s * rx)), (m.cy + 4), 7, '#FFFFFF', LINE, 2)))
	var cups = ''.join(PackedStringArray(_j1))
	var notes = fmt('<path d="M{:.1f} {:.1f} v -22 l 14 -4 v 22" stroke="#6B4A3A" stroke-width="3.5" fill="none"/><ellipse cx="{:.1f}" cy="{:.1f}" rx="6" ry="4.5" fill="#7C4DD6" stroke="#6B4A3A" stroke-width="2.5"/><ellipse cx="{:.1f}" cy="{:.1f}" rx="6" ry="4.5" fill="#7C4DD6" stroke="#6B4A3A" stroke-width="2.5"/>', [((cx + rx) + 20), (m.cy - 40), ((cx + rx) + 16), (m.cy - 40), ((cx + rx) + 30), (m.cy - 44)])
	return svg(((band + cups) + notes))

static func i_aviator_cap(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + (m.ry * 0.45))
	var hw = (m.rx * 0.9)
	var cap = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#B98A5A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), (y + 18), ((cx - hw) - 4), (y - 60), ((cx + hw) + 4), (y - 60), (cx + hw), (y + 18), ((cx + hw) - 10), (y + 34), ((cx + hw) - 22), (y + 30), ((cx + hw) - 20), (y + 4), cx, (y - 6), ((cx - hw) + 20), (y + 4), ((cx - hw) + 22), (y + 30), ((cx - hw) + 10), (y + 34), (cx - hw), (y + 18)])
	var seam = fmt('<path d="M{:.1f} {:.1f} V {:.1f}" stroke="#8C6440" stroke-width="3" stroke-dasharray="5 4"/>', [cx, (y - 40), (y - 4)])
	var _j1 = []
	for s in [(-1), 1]:
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="15" fill="#9FD6F0" stroke="#6B4A3A" stroke-width="5"/><circle cx="{:.1f}" cy="{:.1f}" r="15" fill="none" stroke="#D9961A" stroke-width="3"/><path d="M{:.1f} {:.1f} q 4 -4 9 -3" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>', [(cx + (s * 24)), (y - 18), (cx + (s * 24)), (y - 18), ((cx + (s * 24)) - 7), (y - 24)]))
	var goggles = ''.join(PackedStringArray(_j1))
	var strap = fmt('<path d="M{:.1f} {:.1f} H {:.1f}" stroke="#6B4A3A" stroke-width="6"/>', [(cx - 9), (y - 18), (cx + 9)])
	return svg((((cap + seam) + goggles) + strap))

static func i_confetti_crown(m: Dictionary) -> String:
	var cx = m.cx
	var y = (top(m, cx) + 14)
	var w = (m.rx * 0.55)
	var pts = fmt('{:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f} {:.1f},{:.1f}', [(cx - w), y, (cx - w), (y - 30), (cx - (w * 0.5)), (y - 14), cx, (y - 38), (cx + (w * 0.5)), (y - 14), (cx + w), (y - 30), (cx + w), y])
	var crown = fmt('<polygon points="{}" fill="#FFCF5C" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [pts])
	var band = fmt('<rect x="{:.1f}" y="{:.1f}" width="{:.1f}" height="10" fill="#F590B4" stroke="#6B4A3A" stroke-width="3"/>', [(cx - w), (y - 10), (2 * w)])
	var _j1 = []
	for _t2 in [[(-0.6), '#7FBCF5'], [0, '#86D9B0'], [0.6, '#C8A8FF']]:
		var f = _t2[0]
		var c = _t2[1]
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="3.5" fill="{}" stroke="#6B4A3A" stroke-width="1.5"/>', [(cx + (f * w)), (y - 5), c]))
	var gems = ''.join(PackedStringArray(_j1))
	var bits = ''
	var cols = ['#F590B4', '#7FBCF5', '#86D9B0', '#FFCF5C', '#C8A8FF']
	var _s3 = [[((-w) - 16), (-40), 20], [(w + 14), (-46), (-25)], [(-10), (-62), 35], [22, (-58), 10], [((-w) + 4), (-56), (-15)]]
	for i in _s3.size():
		var dx = _s3[i][0]
		var dy = _s3[i][1]
		var r = _s3[i][2]
		bits += fmt('<rect x="{:.1f}" y="{:.1f}" width="8" height="4" rx="1" fill="{}" transform="rotate({} {:.1f} {:.1f})"/>', [((cx + dx) - 4), ((y + dy) - 2), cols[(i % 5)], r, (cx + dx), (y + dy)])
	return svg((((bits + crown) + band) + gems))

static func i_lucky_charm(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 6)
	var half = (m.rx * 0.5)
	var _j1 = []
	for i in range(11):
		_j1.append(fmt('<circle cx="{:.1f}" cy="{:.1f}" r="2.6" fill="#FFCF5C" stroke="#6B4A3A" stroke-width="1.2"/>', [((cx - half) + (float(((2 * half) * i)) / 10)), ((y - 4) + (16 * (1 - pow(((float((2 * i)) / 10) - 1), 2))))]))
	var chain = ''.join(PackedStringArray(_j1))
	var py = (y + 26)
	var disc = fmt('<circle cx="{:.1f}" cy="{:.1f}" r="14" fill="#FFE07A" stroke="#6B4A3A" stroke-width="4"/>', [cx, py])
	var _j2 = []
	for a in [(-90), 0, 90, 180]:
		_j2.append(heart((cx + (5.5 * cos(deg_to_rad(a)))), (py + (5.5 * sin(deg_to_rad(a)))), 5.5, '#6CC27A', (a + 90), 1.0, LINE, 1.8))
	var leaves = ''.join(PackedStringArray(_j2))
	var shine = fmt('<path d="M{:.1f} {:.1f} q 3 -5 8 -6" stroke="#FFFFFF" stroke-width="2.5" fill="none" stroke-linecap="round"/>', [(cx - 9), (py - 6)])
	return svg((((chain + disc) + leaves) + shine))


# --- Items (items_pack.py: the Supporter Pack and the creator hat) --------------------
static func i_moon_nightcap(m: Dictionary) -> String:
	var cx = m.cx
	var hw = (m.rx * 0.8)
	var brim_y = (top(m, cx) + (m.ry * 0.36))
	var crown = (top(m, cx) - 34)
	var tip_x = (cx + (hw * 1.22))
	var tip_y = (brim_y - 2)
	var cap = fmt('<path d="M{:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} C {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#4B4C9A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - hw), brim_y, (cx - hw), (crown - 10), (cx + (hw * 0.5)), (crown - 34), (cx + (hw * 0.95)), (crown + 2), (cx + (hw * 1.12)), (crown + 18), (tip_x + 4), (tip_y - 20), tip_x, tip_y, (tip_x - 14), (tip_y - 18), (cx + (hw * 0.86)), (crown + 26), (cx + (hw * 0.7)), (crown + 22), (cx + (hw * 0.86)), (brim_y - 20), (cx + hw), (brim_y - 10), (cx + hw), brim_y])
	var mx = (cx - (hw * 0.3))
	var my = (crown + 24)
	var moon = fmt('<path d="M{:.1f} {:.1f} A 13 13 0 1 0 {:.1f} {:.1f} A 10 10 0 1 1 {:.1f} {:.1f} Z" fill="#FFE58A" stroke="#6B4A3A" stroke-width="3" stroke-linejoin="round"/>', [(mx + 4), (my - 13), (mx + 4), (my + 13), (mx + 4), (my - 13)])
	var dots = (star((cx + (hw * 0.18)), (crown + 10), 6, '#FFD45C', LINE, 2) + star((cx + (hw * 0.5)), (crown + 30), 4.5, '#FFF0C2', LINE, 2, 15))
	var brim = fmt('<rect x="{:.1f}" y="{:.1f}" width="{:.1f}" height="22" rx="11" fill="#E9E4F7" stroke="#6B4A3A" stroke-width="4"/>', [((cx - hw) - 6), (brim_y - 12), ((2 * hw) + 12)])
	var tassel = star((tip_x + 2), (tip_y + 10), 14, '#FFD45C', LINE, (W - 1), 10)
	return svg(((((cap + moon) + dots) + brim) + tassel))

static func i_star_cape(m: Dictionary) -> String:
	var cx = m.cx
	var y = (m.chin - 4)
	var half = (m.rx * 0.6)
	var cape = fmt('<path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f} L {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Q {:.1f} {:.1f} {:.1f} {:.1f} Z" fill="#4B4C9A" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/>', [(cx - half), (y - 10), cx, (y + 18), (cx + half), (y - 10), ((cx + half) + 16), (y + 30), (cx + (half * 0.5)), (y + 44), cx, (y + 40), (cx - (half * 0.5)), (y + 44), ((cx - half) - 16), (y + 30)])
	var collar = fmt('<path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f}" stroke="#E9E4F7" stroke-width="7" fill="none" stroke-linecap="round"/>', [(cx - half), (y - 10), cx, (y + 18), (cx + half), (y - 10)])
	var _j1 = []
	for _t2 in [[(-0.85), 22, 4.5], [(-0.4), 30, 3.5], [0.45, 28, 4], [0.9, 20, 3.5]]:
		var dx = _t2[0]
		var dy = _t2[1]
		var r = _t2[2]
		_j1.append(star((cx + (dx * half)), (y + dy), r, '#FFF0C2', LINE, 1.6, (dx * 40)))
	var dots = ''.join(PackedStringArray(_j1))
	var clasp = star(cx, (y + 12), 11, '#FFD45C', LINE, 3)
	return svg((((cape + collar) + dots) + clasp))

static func i_star_glasses(m: Dictionary) -> String:
	var y = m.eye_y
	var r = (m.eye_r + 15)
	var lx = (m.cx - m.eye_dx)
	var rx_ = (m.cx + m.eye_dx)
	var pts = func(x):
		var out = []
		for i in range(10):
			var a = deg_to_rad(((-90) + (i * 36)))
			var rr = (r if ((i % 2) == 0) else (r * 0.58))
			out.append(fmt('{:.1f},{:.1f}', [(x + (rr * cos(a))), ((y + 2) + (rr * sin(a)))]))
		return ' '.join(PackedStringArray(out))
	var _j1 = []
	for x in [lx, rx_]:
		_j1.append(fmt('<polygon points="{}" fill="#FFF3B0" fill-opacity="0.28" stroke="#6B4A3A" stroke-width="9" stroke-linejoin="round"/><polygon points="{}" fill="none" stroke="#FFC93C" stroke-width="4" stroke-linejoin="round"/>', [pts.call(x), pts.call(x)]))
	var lens = ''.join(PackedStringArray(_j1))
	var bridge = fmt('<path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f}" stroke="#6B4A3A" stroke-width="7" fill="none" stroke-linecap="round"/><path d="M{:.1f} {:.1f} Q {} {:.1f} {:.1f} {:.1f}" stroke="#FFC93C" stroke-width="3" fill="none" stroke-linecap="round"/>', [(lx + (r * 0.5)), (y - 4), m.cx, (y - 12), (rx_ - (r * 0.5)), (y - 4), (lx + (r * 0.5)), (y - 4), m.cx, (y - 12), (rx_ - (r * 0.5)), (y - 4)])
	var _j2 = []
	for x in [lx, rx_]:
		_j2.append(fmt('<path d="M{:.1f} {:.1f} l 5 -6" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>', [(x - (r * 0.35)), (y - (r * 0.2))]))
	var shine = ''.join(PackedStringArray(_j2))
	return svg(((bridge + lens) + shine))

static func i_director_beret(m: Dictionary) -> String:
	var cx = (m.cx - 4)
	var base = (top(m, cx) + 18)
	var beret = fmt('<path d="M{} {} C {} {} {} {} {} {} C {} {} {} {} {} {} Q {} {} {} {} Z" fill="#3B3346" stroke="#6B4A3A" stroke-width="4" stroke-linejoin="round"/><path d="M{} {} q 2 -8 8 -10" stroke="#6B4A3A" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M{} {} q 20 -16 48 -16" stroke="#57506A" stroke-width="4" fill="none" stroke-linecap="round"/>', [(cx - 58), base, (cx - 72), (base - 40), (cx - 8), (base - 58), (cx + 34), (base - 46), (cx + 72), (base - 36), (cx + 64), (base - 4), (cx + 52), (base + 2), cx, (base + 10), (cx - 58), base, (cx + 2), (base - 52), (cx - 40), (base - 30)])
	var px = (cx + 22)
	var py = (base - 26)
	var _j1 = []
	for i in range(4):
		_j1.append(fmt('<path d="M{} {} l 4 8" stroke="#FFFFFF" stroke-width="3"/>', [((px - 12) + (i * 8)), (py - 14)]))
	var clap = ((fmt('<g transform="rotate(-12 {} {})"><rect x="{}" y="{}" width="32" height="22" rx="3" fill="#FFFFFF" stroke="#6B4A3A" stroke-width="3"/><path d="M{} {} H {} M{} {} H {}" stroke="#C9C2D6" stroke-width="2.4" stroke-linecap="round"/><g transform="rotate(-16 {} {})"><rect x="{}" y="{}" width="32" height="8" rx="2" fill="#2B2330" stroke="#6B4A3A" stroke-width="2.5"/>', [px, py, (px - 16), (py - 6), (px - 14), (py + 4), (px + 14), (px - 14), (py + 10), (px + 6), (px - 16), (py - 6), (px - 16), (py - 14)]) + ''.join(PackedStringArray(_j1))) + '</g></g>')
	return svg((beret + clap))
