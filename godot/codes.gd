extends RefCounted
## Codes (docs/codes-plan.md, D33): a code unlocks the Supporter Pack, or
## gives a creator their perks. Codes are checked offline against the public
## keys below; the private key never comes near the app or the repo
## (tools/codes/mint.py makes the codes).
##
## A code is 68 bytes, pasted as 109 Crockford base32 characters:
##   header     byte 0: key number (high 4 bits) and kind (low 4 bits);
##              bytes 1 to 3: the serial, big-endian, counted per kind
##   signature  ECDSA P-256 over SHA-256 of "CritterOverlay code v1", a zero
##              byte, then the header; raw r then s
## A code is known by its header, not its text: ECDSA allows a second valid
## signature for the same header, so two texts can be one code.
##
## Redemptions live in their own file, user://codes.json, written through
## save_file.gd. Not in economy.json: that save drops keys it doesn't know,
## and Start over rewrites it, and neither may ever take a purchase away.
## Every code is checked again on load, so editing the file unlocks nothing.
## Pack things are never copied into the economy's `owned`; economy.gd asks
## owns() and owns_dye() here.

const SaveFile := preload("res://save_file.gd")

const DOMAIN := "CritterOverlay code v1"
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # Crockford: no I, L, O, U
const CODE_BYTES := 68
const CODE_CHARS := 109
const FILE_VERSION := 1

# Public keys by key number (1 to 14; 15 is the test key, which only admin.gd
# trusts), base64 DER. A key is never removed, so every code ever sold keeps
# working; a new key takes the next number.
const KEYS := {
	1: "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEUU90IX2LGZ8bdlicTAjRuLoxFptPpE6AR1bT25/h7WLjpNQ8Fmp7/0Izi68IHqdhWf38M4foinihPan1PFcZdA==",   # made 2026-11-26
}

# Codes that leaked badly, as "kind:serial": none can be redeemed from then
# on, and anyone who already redeemed one keeps what it gave.
const REVOKED := []

# The pack's itch.io page: the one link to it, from System > Codes before
# anything is unlocked.
const PACK_PAGE := "https://critteroverlay.itch.io/supporter-pack"

const SUPPORTER := 1
const CREATOR := 2
const CANARY := 15       # signed by each real key for the tests; grants nothing

# What each kind of code grants. Kinds 3 to 13 are for later packs, 14 is
# spare. A code of a kind not listed here is kept and unlocks once a version
# that knows its kind runs.
const GRANTS := {
	SUPPORTER: {"packs": ["supporter"]},
	CREATOR: {"packs": ["supporter", "creator"], "berries": 25000},
}

# What each pack holds: clothes (wear.gd ids, tier "pack" in the catalogue,
# drawn by design/wear/items_pack.py), showpieces (prop.gd ids) and dyes
# (wear.gd DYES ids, marked with their pack).
const PACKS := {
	"supporter": {"name": "Supporter Pack", "clothes": ["moon_nightcap", "star_cape", "star_glasses"],
		"showpieces": ["moon_cradle"], "dyes": ["royal"]},
	"creator": {"name": "Creator pack", "clothes": ["director_beret"], "showpieces": [], "dyes": []},
}

var path := "user://codes.json"
var keys: Dictionary = KEYS.duplicate()   # trusted; the Admin page and the tests add the test key
var revoked: Array = REVOKED
var grants: Dictionary = GRANTS
# A build sold through another store has the pack without a code.
var pack_included := OS.has_feature("pack_included")
var session := {}                 # the Admin page's packs for this session: pack -> true
var entries := []                 # as saved: {"code", "key", "kind", "serial", "at"}
var read_only := false            # the file is from a newer version: never write over it
var now_fn := func() -> float: return Time.get_unix_time_from_system()

var _extra := {}                  # keys of the file this version doesn't know, kept on save
var _good := {}                   # "key:kind:serial" -> kind, for each entry that checks out
var _packs := {}                  # pack -> true
var _crypto_keys := {}            # key number -> CryptoKey


# --- The text -------------------------------------------------------------------

static func read_paste(text: String) -> PackedByteArray:
	# A pasted code to its 68 bytes, or empty if it can't be one: upper case,
	# only letters and digits (spaces, dashes and an email's line breaks go),
	# O read as 0 and I or L as 1.
	var t := ""
	for c in text.to_upper():
		if (c >= "0" and c <= "9") or (c >= "A" and c <= "Z"):
			t += c
	t = t.replace("O", "0").replace("I", "1").replace("L", "1")
	if t.length() != CODE_CHARS:
		return PackedByteArray()
	var out := PackedByteArray()
	var acc := 0
	var bits := 0
	for c in t:
		var v := ALPHABET.find(c)
		if v < 0:
			return PackedByteArray()   # a U
		acc = acc << 5 | v
		bits += 5
		if bits >= 8:
			bits -= 8
			out.append(acc >> bits & 0xFF)
		acc &= (1 << bits) - 1
	if acc != 0:
		return PackedByteArray()       # the spare last bit is always 0
	return out


static func encode(b: PackedByteArray) -> String:
	# 68 bytes as the code's text, in groups of 5 joined by dashes.
	var t := ""
	var acc := 0
	var bits := 0
	for x in b:
		acc = acc << 8 | x
		bits += 8
		while bits >= 5:
			bits -= 5
			t += ALPHABET[acc >> bits & 31]
		acc &= (1 << bits) - 1
	if bits > 0:
		t += ALPHABET[acc << (5 - bits) & 31]
	var groups := PackedStringArray()
	for i in range(0, t.length(), 5):
		groups.append(t.substr(i, 5))
	return "-".join(groups)


static func info(b: PackedByteArray) -> Dictionary:
	return {"key": b[0] >> 4, "kind": b[0] & 15, "serial": b[1] << 16 | b[2] << 8 | b[3]}


static func id_of(b: PackedByteArray) -> String:
	# Which code this is: its key, kind and serial.
	var i := info(b)
	return "%d:%d:%d" % [i.key, i.kind, i.serial]


# --- Checking -------------------------------------------------------------------

func trust(more: Dictionary) -> void:
	# More public keys by number (the Admin page and the tests: the test key).
	keys.merge(more, true)
	_crypto_keys.clear()
	refresh()


func verify(b: PackedByteArray) -> bool:
	# Whether these bytes are a code signed by the trusted key it names.
	if b.size() != CODE_BYTES:
		return false
	var key := _crypto_key(b[0] >> 4)
	if key == null:
		return false
	var m := DOMAIN.to_ascii_buffer()
	m.append(0)
	m.append_array(b.slice(0, 4))
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(m)
	return Crypto.new().verify(HashingContext.HASH_SHA256, h.finish(), _der(b.slice(4)), key)


func _crypto_key(no: int) -> CryptoKey:
	if not _crypto_keys.has(no):
		var k: CryptoKey = null
		if keys.has(no):
			k = CryptoKey.new()
			var b64: String = keys[no]
			var pem := "-----BEGIN PUBLIC KEY-----\n"
			for i in range(0, b64.length(), 64):
				pem += b64.substr(i, 64) + "\n"
			if k.load_from_string(pem + "-----END PUBLIC KEY-----\n", true) != OK:
				push_warning("codes: key %d does not load" % no)
				k = null
		_crypto_keys[no] = k
	return _crypto_keys[no]


static func _der(sig: PackedByteArray) -> PackedByteArray:
	# The raw r and s as the DER the check takes: SEQUENCE { INTEGER r, INTEGER s }.
	var body := PackedByteArray()
	for half in [sig.slice(0, 32), sig.slice(32, 64)]:
		var n: PackedByteArray = half
		while n.size() > 1 and n[0] == 0:
			n = n.slice(1)
		if n[0] >= 0x80:
			n.insert(0, 0)
		body.append(0x02)
		body.append(n.size())
		body.append_array(n)
	var out := PackedByteArray([0x30, body.size()])
	out.append_array(body)
	return out


# --- Redeeming ------------------------------------------------------------------

func redeem(text: String) -> Dictionary:
	# {"result": "ok" | "later" | "again" | "revoked" | "wrong", "kind", "id"}.
	# "later": a real code of a kind this version doesn't know, kept until a
	# version that does. The canary grants nothing, so it isn't taken.
	var b := read_paste(text)
	if not verify(b) or b[0] & 15 == CANARY:
		return {"result": "wrong", "kind": 0, "id": ""}
	var i := info(b)
	var id := id_of(b)
	var out := {"kind": i.kind, "id": id}
	if _good.has(id):
		out.result = "again"
	elif "%d:%d" % [i.kind, i.serial] in revoked:
		out.result = "revoked"
	else:
		entries.append({"code": encode(b), "key": i.key, "kind": i.kind, "serial": i.serial,
			"at": int(now_fn.call())})
		refresh()
		save()
		out.result = "ok" if grants.has(i.kind) else "later"
	return out


func refresh() -> void:
	# Which entries check out, and the packs they give.
	_good = {}
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var b := read_paste(str(e.get("code", "")))
		if verify(b) and b[0] & 15 != CANARY and not _good.has(id_of(b)):
			_good[id_of(b)] = b[0] & 15
	_packs = session.duplicate()
	if pack_included:
		_packs["supporter"] = true
	for id in _good:
		for p in grants.get(_good[id], {}).get("packs", []):
			_packs[p] = true


func set_session(pack: String, on: bool) -> void:
	# The Admin page: a pack on or off for this session, without a code.
	if on:
		session[pack] = true
	else:
		session.erase(pack)
	refresh()


func held() -> Array:
	# The codes that check out, oldest first: {"code", "id", "kind", "known"}.
	var out := []
	var seen := {}
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var b := read_paste(str(e.get("code", "")))
		if b.is_empty() or not _good.has(id_of(b)) or seen.has(id_of(b)):
			continue
		seen[id_of(b)] = true
		out.append({"code": encode(b), "id": id_of(b), "kind": b[0] & 15, "known": grants.has(b[0] & 15)})
	return out


# --- What they give -------------------------------------------------------------

func has_pack(pack: String) -> bool:
	return _packs.has(pack)


func packs() -> Array:
	return _packs.keys()


func owns(id: String) -> bool:
	# A pack's piece of clothing or showpiece.
	for p in _packs:
		if PACKS.has(p) and (id in PACKS[p].clothes or id in PACKS[p].showpieces):
			return true
	return false


func owns_dye(dye: String) -> bool:
	for p in _packs:
		if PACKS.has(p) and dye in PACKS[p].dyes:
			return true
	return false


static func pack_of(id: String) -> String:
	# The pack a piece of clothing, showpiece or dye comes in, or "": pack
	# things are never sold.
	for p in PACKS:
		if id in PACKS[p].clothes or id in PACKS[p].showpieces or id in PACKS[p].dyes:
			return p
	return ""


func purses() -> Dictionary:
	# "key:kind:serial" -> berries, for each code that pays some (economy.gd
	# pays each once).
	var out := {}
	for id in _good:
		var n := int(grants.get(_good[id], {}).get("berries", 0))
		if n > 0:
			out[id] = n
	return out


# --- The file -------------------------------------------------------------------

func load_file() -> void:
	entries = []
	_extra = {}
	read_only = false
	var d = SaveFile.read(path)
	if d != null:
		var v = d.get("version", FILE_VERSION)
		if typeof(v) in [TYPE_INT, TYPE_FLOAT] and int(v) > FILE_VERSION:
			read_only = true
			push_warning("codes: the file is from a newer version; not writing it")
		if typeof(d.get("codes")) == TYPE_ARRAY:
			entries = d.codes
		for k in d:
			if not k in ["version", "codes"]:
				_extra[k] = d[k]
	refresh()


func save() -> void:
	if read_only:
		return
	var d := _extra.duplicate()
	d["version"] = FILE_VERSION
	d["codes"] = entries
	SaveFile.write(path, d)


func forget() -> void:
	# The Admin page: this PC's codes set aside as codes.json.before-forget,
	# so the redeem flow can be tried again.
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".before-forget")
	for p in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	entries = []
	_extra = {}
	session = {}
	read_only = false
	refresh()
