extends SceneTree
## Headless checks for codes.gd (docs/codes-plan.md): reading a paste, the
## signature check, the store in user://codes.json, and the export presets.
## The test key and the codes it signed live in admin.gd, the only other
## place that trusts them.
## Run: godot --headless --path godot --script res://codes_test.gd

const Codes := preload("res://codes.gd")
const Admin := preload("res://admin.gd")
const Wear := preload("res://wear.gd")
const Prop := preload("res://prop.gd")
const Species := preload("res://species.gd")

# The canary for each real key (mint.py canary): a kind-15 code signed with
# it, which grants nothing and so is safe to publish. A build carrying the
# wrong public key fails here.
const REAL_CANARIES := {
	1: "3W000-0AFS6-40J31-B6N86-YXHG3-JB6SN-NTQ95-W50PZ-XG68D-0EJWF-K3HYA-TXF53-7PZ81-X83EQ-62XT2-SD5ER-DVTRB-311CH-Y7H5Q-C34CN-GZG7R-S6QM",
}

var fails := 0
var checks := 0
var dir := OS.get_temp_dir().path_join("critter_codes_test")
var clock := 1_790_000_000.0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func code(name: String) -> String:
	return Admin.TEST_CODES[name]


func store(trust_test := true) -> RefCounted:
	var s = Codes.new()
	s.path = dir.path_join("codes.json")
	s.now_fn = func() -> float: return clock
	if trust_test:
		s.trust(Admin.TEST_KEYS)
	s.load_file()
	return s


func clean() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for n in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(n))


func changed(text: String, byte: int) -> String:
	# The same code with one bit of one byte changed.
	var b := Codes.read_paste(text)
	b[byte] ^= 1
	return Codes.encode(b)


func put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _init() -> void:
	clean()
	var sup := code("supporter")

	# --- Reading a paste.
	var b := Codes.read_paste(sup)
	check(b.size() == Codes.CODE_BYTES, "a code reads as 68 bytes")
	check(Codes.encode(b) == sup, "and writes back as the same text")
	var plain := sup.replace("-", "")
	check(Codes.read_paste(plain) == b, "without dashes")
	check(Codes.read_paste(sup.replace("-", " ")) == b, "with spaces")
	check(Codes.read_paste(plain.substr(0, 50) + "\r\n> " + plain.substr(50)) == b, "with an email's line break")
	check(Codes.read_paste("  " + sup.to_lower() + "\n") == b, "in lower case, with spaces around")
	check(Codes.read_paste(sup.replace("0", "O").replace("1", "I")) == b, "O read as 0, I as 1")
	check(Codes.read_paste(sup.replace("1", "l")) == b, "l read as 1")
	check(Codes.read_paste(plain.substr(0, 108)).is_empty(), "one character short is not a code")
	check(Codes.read_paste(plain + "0").is_empty(), "one character long is not a code")
	check(Codes.read_paste(plain.substr(0, 108) + "U").is_empty(), "U is never in a code")
	check(Codes.read_paste("").is_empty(), "nothing is not a code")
	var last := Codes.ALPHABET.find(plain[108])
	var odd := plain.substr(0, 108) + Codes.ALPHABET[last ^ 1]
	check(Codes.read_paste(odd).is_empty(), "a code's spare last bit is 0")
	check(Codes.info(b) == {"key": 15, "kind": Codes.SUPPORTER, "serial": 1}, "the header: test key, Supporter, serial 1")
	check(Codes.id_of(b) == "15:1:1", "known by key, kind and serial")
	check(Codes.id_of(Codes.read_paste(code("supporter_resigned"))) == "15:1:1", "a second signature is the same code")
	check(code("supporter_resigned") != sup, "though its text differs")

	# --- The signature.
	var s = store()
	for name in Admin.TEST_CODES:
		check(s.verify(Codes.read_paste(code(name))), "the test code '%s' checks out with the test key" % name)
	for i in [0, 1, 3, 4, 20, 35, 36, 50, 67]:
		check(not s.verify(Codes.read_paste(changed(sup, i))), "with byte %d changed it does not" % i)
	var as_key_1 := Codes.read_paste(sup)
	as_key_1[0] = 1 << 4 | Codes.SUPPORTER
	check(not s.verify(as_key_1), "naming another key, it does not")
	var real_only = store(false)
	for name in Admin.TEST_CODES:
		check(not real_only.verify(Codes.read_paste(code(name))), "with only the real keys trusted, '%s' does not" % name)
	check(not Codes.KEYS.has(Admin.TEST_KEYS.keys()[0]), "the player build never holds the test key")
	check(Admin.TEST_KEYS.keys() == [15], "the test key is number 15")
	for no in Codes.KEYS:
		check(no >= 1 and no <= 14, "real key %d is numbered 1 to 14" % no)

	# --- The canary: each real key signed one, and the key in this build reads it.
	check(s.verify(Codes.read_paste(code("canary"))), "the test canary checks out")
	check(Codes.info(Codes.read_paste(code("canary"))).kind == Codes.CANARY, "and is kind 15")
	if Codes.KEYS.is_empty():
		print("PENDING: no real key in codes.gd yet (docs/codes-plan.md, step 2), so no real canary to check")
	for no in Codes.KEYS:
		check(REAL_CANARIES.has(no), "key %d has its canary here" % no)
		var c := Codes.read_paste(REAL_CANARIES.get(no, ""))
		check(real_only.verify(c), "key %d's canary checks out against the key in codes.gd" % no)
		check(not c.is_empty() and Codes.info(c).key == no and Codes.info(c).kind == Codes.CANARY, "and is key %d's canary" % no)

	# --- Redeeming.
	clean()
	s = store()
	check(s.packs().is_empty(), "no codes, no packs")
	check(s.redeem(code("canary")).result == "wrong", "the canary isn't taken: it grants nothing")
	check(s.redeem(changed(sup, 40)).result == "wrong", "a changed code is wrong")
	check(s.redeem(plain.substr(0, 100)).result == "wrong", "a code cut short is wrong")
	check(s.packs().is_empty() and s.entries.is_empty(), "and nothing unlocks or is kept")
	var r: Dictionary = s.redeem(sup.to_lower().replace("-", " "))
	check(r.result == "ok" and r.kind == Codes.SUPPORTER and r.id == "15:1:1", "a Supporter code redeems")
	check(s.has_pack("supporter") and not s.has_pack("creator"), "it gives the Supporter Pack")
	check(s.entries.size() == 1 and s.entries[0].code == sup, "kept as its own text, however it was pasted")
	check(s.entries[0].at == int(clock) and s.entries[0].serial == 1, "with when and its header")
	check(s.redeem(sup).result == "again", "pasting it again: already redeemed")
	check(s.redeem(code("supporter_resigned")).result == "again", "its second signature too")
	check(s.redeem(code("supporter_2")).result == "ok", "another Supporter code redeems")
	check(s.entries.size() == 2, "and is kept")
	for item in Codes.PACKS.supporter.clothes + Codes.PACKS.supporter.showpieces:
		check(s.owns(item), "the pack holds %s" % item)
	for dye in Codes.PACKS.supporter.dyes:
		check(s.owns_dye(dye), "and the dye %s" % dye)
	for item in Codes.PACKS.creator.clothes:
		check(not s.owns(item), "but not the creator's %s" % item)
	check(not s.owns("party_hat") and not s.owns_dye("rose"), "nor anything from the Shop")
	check(s.purses().is_empty(), "Supporter codes pay no berries")

	# Reload: still there.
	s = store()
	check(s.has_pack("supporter") and s.held().size() == 2, "after a reload, still there")
	check(s.held()[0] == {"code": sup, "id": "15:1:1", "kind": 1, "known": true}, "listed, oldest first, with its text to copy")
	check(s.redeem(sup).result == "again", "and still already redeemed")

	# Creator.
	r = s.redeem(code("creator"))
	check(r.result == "ok" and r.kind == Codes.CREATOR, "a creator code redeems")
	check(s.has_pack("creator") and s.has_pack("supporter"), "it gives the creator pack and the Supporter Pack")
	for item in Codes.PACKS.creator.clothes:
		check(s.owns(item), "the creator holds %s" % item)
	check(s.purses() == {"15:2:1": 25000}, "and 25,000 berries for that code")
	s.redeem(code("creator_2"))
	check(s.purses() == {"15:2:1": 25000, "15:2:2": 25000}, "each creator code has its own purse")

	# --- Without the test key (the player build), test codes give nothing but stay in the file.
	var player = store(false)
	check(player.packs().is_empty() and player.held().is_empty(), "the player build takes no test code")
	player.save()
	check(store().held().size() == 4, "and keeps them in the file when it saves")

	# --- Editing the file unlocks nothing.
	clean()
	var forged := changed(code("creator"), 40)
	put(dir.path_join("codes.json"), JSON.stringify({"version": 1, "codes": [
		{"code": forged, "key": 15, "kind": 2, "serial": 1, "at": 0},
		{"code": sup, "key": 15, "kind": 2, "serial": 99, "at": 0},
		"not an entry", {"no": "code"}]}))
	s = store()
	check(not s.has_pack("creator") and s.purses().is_empty(), "an edited code in the file unlocks nothing")
	check(s.has_pack("supporter") and s.held().size() == 1 and s.held()[0].kind == 1, "a code is what its text says, not the fields beside it")
	check(s.redeem(code("creator")).result == "ok", "the real creator code still redeems")
	check(s.entries.size() == 5, "and nothing in the file was dropped")

	# --- A code of a kind this version doesn't know: kept, unlocks once known.
	clean()
	s = store()
	r = s.redeem(code("later_pack"))
	check(r.result == "later" and r.kind == 3, "a later pack's code is kept, and the note says to update")
	check(s.packs().is_empty() and s.entries.size() == 1, "it unlocks nothing yet")
	check(s.redeem(code("later_pack")).result == "again", "pasting it again: already redeemed")
	var newer = Codes.new()
	newer.path = s.path
	newer.trust(Admin.TEST_KEYS)
	newer.grants = Codes.GRANTS.duplicate()
	newer.grants[3] = {"packs": ["supporter"]}
	newer.load_file()
	check(newer.has_pack("supporter"), "a version that knows its kind unlocks it")
	check(newer.held()[0].known, "and lists it as known")

	# --- Revoked codes: refused when new, kept when already redeemed.
	clean()
	s = store()
	s.redeem(sup)
	var strict = Codes.new()
	strict.path = s.path
	strict.revoked = ["1:1", "1:2"]
	strict.trust(Admin.TEST_KEYS)
	strict.load_file()
	check(strict.has_pack("supporter"), "a revoked code already redeemed keeps what it gave")
	check(strict.redeem(sup).result == "again", "and is still already redeemed")
	check(strict.redeem(code("supporter_2")).result == "revoked", "a revoked code is refused when new")
	check(strict.entries.size() == 1, "and not kept")
	check(Codes.REVOKED.all(func(x): return typeof(x) == TYPE_STRING and x.count(":") == 1), "codes.gd lists revoked codes as kind:serial")

	# --- The file: a damaged one recovers, unknown keys survive, a newer one is never written.
	clean()
	s = store()
	s.redeem(sup)
	s.redeem(code("creator"))   # the second save: the first is now codes.json.bak
	put(s.path, "{ not json")
	var back = store()
	check(back.has_pack("supporter"), "a damaged file recovers from its .bak")
	check(Array(DirAccess.get_files_at(dir)).any(func(n): return n.begins_with("codes.json.corrupt-")), "and the damaged one is set aside")

	clean()
	put(dir.path_join("codes.json"), JSON.stringify({"version": 1, "later": {"x": 1}, "codes": [
		{"code": sup, "key": 15, "kind": 1, "serial": 1, "at": 5, "note": "from a later version"}]}))
	s = store()
	s.redeem(code("creator"))
	var d = JSON.parse_string(FileAccess.get_file_as_string(s.path))
	check(d.get("later") == {"x": 1.0}, "keys the file doesn't know survive a save")
	check(d.codes[0].get("note") == "from a later version", "and so do an entry's")
	check(d.codes.size() == 2 and d.version == 1, "beside the new code")

	clean()
	var future := JSON.stringify({"version": 2, "codes": [{"code": sup}]})
	put(dir.path_join("codes.json"), future)
	s = store()
	check(s.read_only and s.has_pack("supporter"), "a file from a newer version is read")
	s.redeem(code("creator"))
	check(FileAccess.get_file_as_string(s.path) == future, "but never written")

	# --- pack_included (a build sold through another store): the pack with no codes.
	clean()
	s = store()
	check(not s.has_pack("supporter"), "no codes, no pack")
	s.pack_included = true
	s.refresh()
	check(s.has_pack("supporter") and not s.has_pack("creator"), "pack_included unlocks the Supporter Pack")
	check(s.held().is_empty() and s.purses().is_empty(), "with no codes and no berries")
	check(s.redeem(code("creator")).result == "ok" and s.has_pack("creator"), "creator codes still redeem")
	check(not Codes.new().pack_included, "this build doesn't have pack_included")

	# --- The Admin page: packs for this session, and Forget codes.
	clean()
	s = store()
	s.set_session("supporter", true)
	check(s.has_pack("supporter") and not FileAccess.file_exists(s.path), "a session pack unlocks without a code, and isn't saved")
	s.set_session("supporter", false)
	check(not s.has_pack("supporter"), "and goes when switched off")
	s.set_session("creator", true)
	check(s.has_pack("creator") and s.purses().is_empty(), "a session creator gets no berries")
	s.set_session("creator", false)
	s.redeem(sup)
	s.redeem(code("creator"))
	s.forget()
	check(s.packs().is_empty() and s.entries.is_empty(), "Forget codes: nothing unlocked")
	check(not FileAccess.file_exists(s.path) and not FileAccess.file_exists(s.path + ".bak"), "codes.json and its .bak go")
	check(FileAccess.file_exists(s.path + ".before-forget"), "set aside as codes.json.before-forget")
	check(store().packs().is_empty(), "a reload brings nothing back")
	check(s.redeem(sup).result == "ok", "and the code redeems again")

	# --- Each pack's things exist: drawn for every species, in the catalogue as tier
	# "pack", the showpiece with its art, the dye marked as the pack's.
	for p in Codes.PACKS:
		for id in Codes.PACKS[p].clothes:
			check(Wear.has(id) and Wear.ITEMS[id][2] == "pack" and Wear.only(id) == "", "%s is in the catalogue, tier pack, for everyone" % id)
			for sp in Species.DATA:
				check(Wear.fits(id, sp), "%s is drawn for the %s" % [id, sp])
		for pid in Codes.PACKS[p].showpieces:
			check(Prop.PROPS.has(pid) and FileAccess.file_exists("res://art/props/%s.svg" % pid), "the showpiece %s is there" % pid)
		for dye in Codes.PACKS[p].dyes:
			check(Wear.DYES.has(dye) and Wear.DYES[dye].size() > 2 and Wear.DYES[dye][2] == p, "the dye %s is marked as the %s pack's" % [dye, p])
	for dye in Wear.DYES:
		check(Wear.DYES[dye].size() < 3 or Codes.pack_of(dye) == Wear.DYES[dye][2], "the dye %s is in the pack it says" % dye)
	check(Codes.PACKS.supporter.clothes.map(func(i): return Wear.slot(i)) == ["head", "neck", "face"], "the Supporter Pack: a hat, a neck item and a face item")

	# --- Pack things are never sold.
	for p in Codes.PACKS:
		for id in Codes.PACKS[p].clothes + Codes.PACKS[p].showpieces + Codes.PACKS[p].dyes:
			check(Codes.pack_of(id) == p, "%s is the %s pack's" % [id, p])
	check(Codes.pack_of("party_hat") == "" and Codes.pack_of("rose") == "" and Codes.pack_of("basket") == "", "Shop things are in no pack")

	# --- The export presets: the player build carries neither pack_included nor admin.
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg reads")
	var player_seen := false
	for sec in cfg.get_sections():
		if cfg.get_value(sec, "name", "") == "Windows Desktop":
			player_seen = true
			var tags: String = cfg.get_value(sec, "custom_features", "")
			for tag in ["pack_included", "admin"]:
				check(not tag in Array(tags.split(",", false)).map(func(t): return t.strip_edges()), "the player preset doesn't carry %s" % tag)
	check(player_seen, "the player preset is there")

	clean()
	print("codes_test: %d checks, %d failed" % [checks, fails])
	quit(0 if fails == 0 else 1)
