extends RefCounted
## Saving a Studio critter (docs/custom-critters-build-plan.md, D6, P4;
## design/studio/builder/Save.html): the short dialog over the Studio (name,
## how it walks, size, pop sound, Send it to my desk now, Keep) and keep(),
## which does the saving with no window.
##
## keep() checks the doc (every needed part drawn), writes the critter's
## folder with share.gd write_builder_kit() (shapes.json, the parts the app
## writes, kit.json with its pins) into a staging folder, sets its size and
## sound, makes its card picture from the real rig (kit_data.gd build(), the
## sitting pose), then adds it to the store or, when editing, puts the new
## parts, shapes.json, kit.json and picture over the old ones in place and
## bumps its rev, so its textures are made again. Its name, size and sound
## change; everything else in custom.json (visits, sightings, on or off, its
## own sound) is kept.

const Customs := preload("res://customs.gd")
const Share := preload("res://share.gd")
const Writer := preload("res://studio/shape_svg.gd")
const KitData := preload("res://critters/kit/kit_data.gd")
const LP := preload("res://gui/studio/layers_panel.gd")
const K := preload("res://gui/controls.gd")
const UI := preload("res://gui/ui.gd")

const STAGING := "user://studio_save"
const SIZES := [["Small", 0.8], ["Normal", 1.0], ["Big", 1.3]]   # as the importers have them
const MAX_NAME := 24
# Each gait in a line, with the critter it comes from (4.5).
const GAIT_WORDS := {
	"trot": ["Trot", "A steady walk, like the kitten"], "hop": ["Hop", "Springs along, like the rabbit"],
	"waddle": ["Waddle", "Rocks side to side, like the duckling"], "plod": ["Plod", "Slow and steady, like the turtle"],
	"scurry": ["Scurry", "Quick little steps, like the hedgehog"], "dart": ["Dart", "Dashes, then freezes, like the squirrel"],
	"slide": ["Slide", "Slides along on its belly, like the otter"], "bounce": ["Bounce", "A springy step, like the unicorn"],
	"sway": ["Sway", "Rolls from side to side, like the panda"], "blob_bounce": ["Bounce", "Squashes, springs and lands"],
	"glide": ["Glide", "Glides along with a wobble"], "float": ["Float", "Hovers off the ground and bobs along"],
	"slither": ["Slither", "Wiggles along like a snake"],
}

var st: Window                     # studio_window.gd
var name := ""
var gait := ""
var size_i := 1
var sound := "kitten"
var send := true
var after := Callable()            # what happens once it is kept (Save and go back)


func _init(studio: Window, after_keep := Callable()) -> void:
	st = studio
	name = st.critter_name
	gait = st.gait
	size_i = st.size_i
	sound = st.sound
	send = st.editing_id == ""
	after = after_keep


static func clean_name(n: String) -> String:
	var t := n.strip_edges().left(MAX_NAME)
	return t if t != "" else "My critter"


static func gaits(plan: String) -> Array:
	return KitData.PLANS.get(plan, KitData.PLANS.side).gaits


# --- Saving ---------------------------------------------------------------------------

static func keep(doc: Dictionary, critter_name: String, gait_id: String, opts: Dictionary, editing_id := "") -> String:
	# Saves it. Returns its id, or "" if it can't be saved (a needed part is
	# missing). opts: "size" (a multiplier) and "sound".
	var d: Dictionary = Writer.clean_doc(doc).doc
	if not LP.needed(d).is_empty():
		return ""
	var n := clean_name(critter_name)
	# Staged in a folder named after it: add_folder() names the store's
	# folder after the one it copies (with a random tail).
	var key := Customs._new_key(n)
	var stage := STAGING.path_join(key.left(key.length() - 7))
	Share.clear_dir(STAGING)
	if Share.write_builder_kit(d, n, stage, gait_id) == "":
		Share.clear_dir(STAGING)
		return ""
	var thumb := card_picture(stage)
	if thumb != null:
		Customs.make_thumb(thumb, stage)
	var size := float(opts.get("size", 1.0))
	var snd := str(opts.get("sound", "kitten"))
	var id := ""
	if editing_id != "" and Customs.all.has(editing_id):
		id = editing_id
		var folder := str(Customs.all[id]["_dir"])
		Customs._remove_tree(folder.path_join("parts"))
		Customs._remove_tree(folder.path_join("cache"))
		Customs._copy_tree(stage.path_join("parts"), folder.path_join("parts"))
		for f in ["shapes.json", "kit.json", "thumb.png"]:
			if FileAccess.file_exists(stage.path_join(f)):
				DirAccess.copy_absolute(stage.path_join(f), folder.path_join(f))
		var dd: Dictionary = Customs.all[id]
		dd["name"] = n
		dd["size"] = size
		if snd != "own" or Customs.own_sound_path(dd) != "":
			dd["sound"] = snd
		Customs._read_extras(dd)
		Customs.bump_rev(id)
	else:
		var cj := stage.path_join("custom.json")
		var meta = JSON.parse_string(FileAccess.get_file_as_string(cj))
		if typeof(meta) == TYPE_DICTIONARY:
			meta["size"] = size
			meta["sound"] = snd if snd in Customs.SOUNDS else "kitten"
			var f := FileAccess.open(cj, FileAccess.WRITE)
			f.store_string(JSON.stringify(meta, "\t"))
			f.close()
		id = Customs.add_folder(stage)
	Share.clear_dir(STAGING)
	return id


static func card_picture(folder: String) -> Image:
	# Its sitting pose as the rig puts it together (the parts it was given
	# and the ones made for it), cropped: the card picture.
	var kit = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("kit.json")))
	if typeof(kit) != TYPE_DICTIONARY:
		return null
	var img := pose_image(KitData.build(folder, kit), "sit")
	var used := img.get_used_rect()
	return img.get_region(used) if used.size.x > 0 else null


static func pose_image(r: Dictionary, pose: String) -> Image:
	# A pose with the legs at rest, back to front, over the frame and its
	# headroom (x -60 to 360, y -120 to 280), at KitData.PART_SCALE.
	var k := KitData.PART_SCALE
	var origin := Vector2(60, 120)
	var out := Image.create(roundi(420 * k), roundi(400 * k), false, Image.FORMAT_RGBA8)
	var imgs: Dictionary = r.images
	var pv: Dictionary = r.pivots
	var put := func(part: String, off: Vector2) -> void:
		if imgs.has(part):
			var im: Image = imgs[part]
			out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(((origin + off) * k).round()))
	var legs_on: bool = pose == "walk" or (pose == "sit" and r.sit_parts.is_empty())
	var body_parts: Array = []
	match pose:
		"walk":
			body_parts = ["back-extra", "walk-body", "wing-side", "wing", "front-extra"]
		"sit":
			body_parts = ["wing-r"] + r.sit_parts + ["wing-l"] if not r.sit_parts.is_empty() else ["back-extra", "walk-body", "wing", "front-extra"]
		"loaf":
			body_parts = ["loaf-body"]
	if r.tail_at.has(pose):
		put.call("tail", r.tail_at[pose] - pv.get("tail", Vector2.ZERO))
	if legs_on:
		for spec in r.walk_legs:
			if str(spec[0]).ends_with("far"):
				put.call(spec[0], spec[1] - pv[spec[0]])
	for part in body_parts:
		if pv.has(part) or part in ["wing", "wing-side", "wing-l", "wing-r"]:
			put.call(part, Vector2.ZERO if part in ["wing", "wing-side", "wing-l", "wing-r"] else KitData.BASE - pv[part])
	if legs_on:
		for spec in r.walk_legs:
			if not str(spec[0]).ends_with("far"):
				put.call(spec[0], spec[1] - pv[spec[0]])
	if r.head_at.has(pose):
		var off: Vector2 = r.head_at[pose] - r.head_pivot
		for part in r.ear_parts + ["head", "eyes-closed" if pose == "loaf" and imgs.has("eyes-closed") else "eyes", "head-front"]:
			put.call(part, off)
	return out


# --- The dialog ------------------------------------------------------------------------

func build() -> Control:
	var c := K.c
	var v := K.vbox(14)
	v.custom_minimum_size.x = 520
	var head := K.vbox(4)
	head.add_child(UI.label("Save your changes" if st.editing_id != "" else "Nearly ready", 24, c.ink, 600, true))
	head.add_child(UI.wrap("Give your critter a name and pick how it gets about. You can change all of this later on its page in My critters.", 13, c.ink2, 500))
	v.add_child(head)
	var nr := K.hbox(10)
	var count := UI.label("%d of %d" % [name.length(), MAX_NAME], 12, c.ink3, 700)
	var field := K.text_field(name, "Its name", MAX_NAME, func(t):
		name = t
		count.text = "%d of %d" % [t.length(), MAX_NAME])
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.add_child(field)
	nr.add_child(count)
	v.add_child(_labelled("Name", nr))
	var gs := gaits(st.doc.plan)
	if not gait in gs:
		gait = gs[0]
	var line := UI.label(GAIT_WORDS.get(gait, ["", ""])[1], 13, c.ink2, 500)
	var gv := K.vbox(6)
	gv.add_child(K.seg(gs.map(func(g): return GAIT_WORDS.get(g, [str(g).capitalize()])[0]), gs.find(gait), func(i):
		gait = gs[i]
		st.gait = gait
		st.rebuild_overlay()))
	gv.add_child(line)
	v.add_child(_labelled("How it walks", gv))
	v.add_child(_labelled("Size", K.seg(SIZES.map(func(x): return x[0]), size_i, func(i):
		size_i = i
		st.rebuild_overlay())))
	var sounds: Array = Customs.SOUNDS.duplicate()
	if st.editing_id != "" and Customs.all.has(st.editing_id) and Customs.own_sound_path(Customs.all[st.editing_id]) != "":
		sounds.append("own")
	v.add_child(_labelled("Pop sound", K.dropdown(sounds.map(func(x): return "Its own" if x == "own" else str(x).capitalize()),
		maxi(0, sounds.find(sound)), func(i): sound = sounds[i])))
	var sr := K.hbox(12)
	var sl := K.vbox(2)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.add_child(UI.label("Send it to my desk now", 14, c.ink, 800))
	sl.add_child(UI.label("It walks on as soon as you keep it. The Studio stays open.", 12, c.ink2, 500))
	sr.add_child(sl)
	sr.add_child(K.toggle(send, "Send it to my desk now", func(on): send = on))
	v.add_child(sr)
	var bar := K.hbox(10)
	bar.add_child(K.button("Back to the shapes", "bs", "", false, st.close_overlay))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	bar.add_child(K.button("Keep %s" % clean_name(name) if st.editing_id == "" else "Save", "bp", "check", false, press_keep))
	v.add_child(bar)
	return v


func _labelled(title: String, ctl: Control) -> Control:
	var v := K.vbox(6)
	v.add_child(UI.label(title, 13, K.c.ink2, 800))
	v.add_child(ctl)
	return v


func press_keep() -> String:
	st.critter_name = clean_name(name)
	st.gait = gait
	st.size_i = size_i
	st.sound = sound
	var id := keep(st.doc, st.critter_name, gait, {"size": SIZES[size_i][1], "sound": sound}, st.editing_id)
	st.kept(id, send, after)
	return id
