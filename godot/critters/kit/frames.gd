extends "res://critters/critter.gd"
## A frame critter: drawn frame by frame in the player's own app
## (docs/custom-critters-build-plan.md, 4.6, 5.4, E1). It keeps everything
## critter.gd does with movement (modes, walking, edges, throws, climbing,
## spinning dizzy, pairs) and swaps the part rig for one sprite on its atlas
## (frame_data.gd). What it is doing picks the clip:
##
##   walk  walk (required)       sit   sit, else walk's first frame
##   nap   nap, else sit         held  held, else sit
##   thrown  thrown, else held   climbing  climb, else walk
##   sitting, now and then: blink, played once
##   its own moves: act-<name>, as the behaviour clip:<name>
##
## Clothes (F3): drawn once for a reference head, then moved and scaled each
## frame to the head marked in clips.json (frame_data.gd head_at()). On a
## clip with no marks they are hidden; with no marks at all, nothing fits.
##
## Walking frames follow the distance walked (stride_px a cycle), so feet
## don't skate. The art faces left; "faces": "right" flips it.

const Customs := preload("res://customs.gd")
const FrameData := preload("res://critters/kit/frame_data.gd")
const REF_HEIGHT := 226.0      # kit_data.gd's: the kitten's height
const REF_SCALE := 0.45
# The head clothes are drawn for: kit_data.gd's default head metrics.
const REF_HEAD := {"cx": 150.0, "cy": 130.0, "rx": 70.0, "ry": 60.0, "top": 70.0, "chin": 190.0,
	"eye_y": 130.0, "eye_dx": 28.0, "eye_r": 14.0, "side": 1.0}

var atlas := {}
var sheet: Sprite2D
var faces_right := false
var clip := ""
var clip_t := 0.0
var last_dt := 0.0
var clips := {}                 # clips.json
var wear_pivot: Node2D          # the clothes, moved to the marked head each frame


func _define() -> void:
	var d: Dictionary = Customs.all.get(species, {})
	var c: Dictionary = d.get("_clips", {})
	clips = c
	atlas = FrameData.atlas(Customs.tex_key(species), str(d.get("_dir", "")), c)
	faces_right = str(c.get("faces", "left")) == "right"
	var ground := clampf(float(c.get("ground", 262.0)), 100.0, 280.0)
	base_pt = Vector2(150, ground)
	ground_y = ground
	pivots = {}
	walk_legs = []
	head_at = {}
	tail_at = {}
	ear_parts = []
	sit_parts = []
	var walk: Rect2 = atlas.bounds.get("walk", Rect2(100, 100, 100, 162))
	var tall := maxf(40.0, ground - walk.position.y)
	critter_scale = clampf(REF_SCALE * REF_HEIGHT / tall, 0.3, 0.7) * clampf(float(d.get("size", 1.0)), 0.5, 2.0)
	# A walk cycle carries it stride_px units: critter.gd's cycle is
	# 4 x leg_len x sin(stride_deg).
	stride_deg = 18.0
	leg_len = clampf(float(c.get("stride_px", 100.0)), 10.0, 600.0) / (4.0 * sin(deg_to_rad(stride_deg)))
	speed_range = Vector2(38.0, 62.0) * clampf(float(d.get("speed", 1.0)), 0.5, 2.0)
	head_height = tall * 0.75 * PART_SCALE * critter_scale
	var hb := {}
	for pose_name in ["walk", "sit", "loaf", "stand"]:
		var src: String = {"walk": "walk", "sit": "sit", "loaf": "nap", "stand": "sit"}[pose_name]
		var b: Rect2 = atlas.bounds.get(src, atlas.bounds.get("sit", walk))
		hb[pose_name] = b.grow(4.0)
	hit_bounds = hb


func body_centre_px() -> float:
	return hit_bounds["walk"].size.y * 0.5 * PART_SCALE * critter_scale


func head_top_px() -> float:
	return (ground_y - hit_bounds["walk"].position.y) * PART_SCALE * critter_scale


func _load_textures() -> void:
	pass   # frame_data.gd's atlas


func _build_rig() -> void:
	legs_node = Node2D.new()
	legs_near = Node2D.new()
	body = Node2D.new()
	sit_body = Node2D.new()
	torso_in.add_child(body)
	sheet = Sprite2D.new()
	sheet.texture = atlas.texture
	sheet.centered = false
	sheet.region_enabled = true
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sheet.position = -base_pt * PART_SCALE
	body.add_child(sheet)
	_sprites.append(sheet)
	wear_pivot = Node2D.new()
	body.add_child(wear_pivot)
	_show("walk", 0)


func wear(items: Array, dyes: Dictionary = {}) -> void:
	for n in _wear_nodes:
		_sprites.erase(n)
		n.queue_free()
	_wear_nodes.clear()
	worn = Wear.ordered(items)
	perk_moves = Wear.perk_behaviours(worn)
	if wear_pivot == null or not FrameData.has_head(clips):
		return
	var ref_r := sqrt(float(REF_HEAD.rx) * float(REF_HEAD.ry))
	for id in worn:
		if not Wear.fits(id, species):
			continue
		var dye: String = dyes.get(id, "")
		var key := "wear:%s:%s:%s:%s" % [id, species, art_key(), dye]
		if not _wear_textures.has(key):
			var img := Image.new()
			img.load_svg_from_string(Wear.svg_for_kit(id, REF_HEAD, dye), PART_SCALE)
			img.generate_mipmaps()
			_wear_textures[key] = ImageTexture.create_from_image(img)
		var s := Sprite2D.new()
		s.texture = _wear_textures[key]
		s.centered = false
		# Placed so the reference head's centre sits on the pivot, which is
		# scaled by the marked radius over the reference's.
		s.position = (Vector2(0, -WEAR_HEADROOM) - Vector2(REF_HEAD.cx, REF_HEAD.cy)) * PART_SCALE
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		wear_pivot.add_child(s)
		_sprites.append(s)
		_wear_nodes.append(s)
	wear_pivot.set_meta("ref_r", ref_r)
	_show(clip if clip != "" else "walk", 0)


func _set_pose(p: String) -> void:
	if p == pose:
		return
	pose = p
	_kick_squash(-1.2)


func _act_pose(_b: String) -> String:
	return "sit"


func tick(delta: float) -> void:
	last_dt = delta
	super(delta)


func clip_length(b: String) -> float:
	# How long a clip:<name> behaviour plays: its frames, at its speed, times its loops.
	var c := "act-" + b.trim_prefix("clip:")
	if not atlas.regions.has(c):
		return 1.0
	return atlas.regions[c].size() / atlas.fps[c] * atlas.loops[c]


func which_clip() -> String:
	# The clip for what it is doing now, through the fallbacks.
	var want := "walk"
	if act.begins_with("clip:"):
		want = "act-" + act.trim_prefix("clip:")
	elif held:
		want = "held"
	elif airborne:
		want = "thrown"
	elif pose == "walk":
		want = "climb" if climbing else "walk"
	elif pose == "loaf":
		want = "nap"
	else:
		want = "blink" if blink_left > 0.0 and atlas.regions.has("blink") else "sit"
	var chain := {"climb": "walk", "thrown": "held", "held": "sit", "nap": "sit", "blink": "sit", "sit": "walk"}
	while not atlas.regions.has(want) and chain.has(want):
		want = chain[want]
	return want if atlas.regions.has(want) else "walk"


func _apply(p: Dictionary) -> void:
	# critter.gd's _apply for the body only: height, squash, facing, the
	# torso's turn; then the frame.
	position.y = world.floor_y - air_y - lift - p.get("float", 0.0) * zoom
	var sq := squash
	var flip := (1.0 if facing < 0 else -1.0) * (-1.0 if faces_right else 1.0)
	scale = Vector2(critter_scale * zoom * (1.0 + (1.0 - sq) * 0.6) * flip, critter_scale * zoom * sq)
	var pivot: Vector2 = p.torso_pivot
	torso.position = (pivot - base_pt + Vector2(0, p.torso_dy)) * PART_SCALE
	torso_in.position = -(pivot - base_pt) * PART_SCALE
	torso.rotation = deg_to_rad(p.torso_rot)
	var c := which_clip()
	if c != clip:
		clip = c
		clip_t = 0.0
	clip_t += last_dt
	var n: int = atlas.regions[c].size()
	var i := 0
	if c == "walk" and pose == "walk" and not climbing:
		i = int(gait * n) % n               # by distance: the feet keep pace
	elif c == "walk" and pose != "walk":
		i = 0                               # sitting with no sit clip: the first walk frame
	elif not atlas.loop[c]:
		# Played its loops, then holds the last frame.
		var played := int(clip_t * atlas.fps[c])
		i = played % n if played < n * atlas.loops[c] else n - 1
	else:
		i = int(clip_t * atlas.fps[c]) % n
	_show(c, i)


func _show(c: String, i: int) -> void:
	sheet.region_rect = atlas.regions[c][i]
	if wear_pivot == null or _wear_nodes.is_empty():
		return
	var h = FrameData.head_at(clips, c, i)
	wear_pivot.visible = h != null
	if h != null:
		wear_pivot.position = (Vector2(h.x, h.y) - base_pt) * PART_SCALE
		wear_pivot.scale = Vector2.ONE * (h.z / float(wear_pivot.get_meta("ref_r", 64.8)))
