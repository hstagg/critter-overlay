extends SceneTree
## Headless checks for updater.gd: reading a release, rate limits, the
## resumable download against a small local server (redirects, dropped
## connections, Range, a corrupt file), ETags, and the launch after an install.
## Run: godot --headless --path godot --script res://updater_test.gd

const Updater := preload("res://updater.gd")
const Fetch := Updater.Fetch

var fails := 0
var checks := 0
var server := Server.new()
var tmp := OS.get_temp_dir().path_join("critter_updater_test")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # the root is in the tree from the first frame
	_pure()
	if not server.start():
		check(false, "the test server can listen on 127.0.0.1")
		quit(1)
		return
	_fetches()
	await _updater()
	await _launch()
	print("updater_test: %d checks, %d failed" % [checks, fails])
	quit(0 if fails == 0 and checks > 0 else 1)


# --- Pure parts ------------------------------------------------------------------

func _release(v := "3.0.1", extra := {}) -> Dictionary:
	var asset := {"name": "CritterOverlaySetup-%s.exe" % v, "size": server.payload.size(),
		"digest": "sha256:" + server.sha, "browser_download_url": "https://github.com/x/y/releases/download/v%s/a.exe" % v}
	asset.merge(extra, true)
	return {"tag_name": "v" + v, "draft": false, "prerelease": false,
		"html_url": "https://github.com/hstagg/critter-overlay/releases/tag/v" + v, "assets": [asset]}


func _pure() -> void:
	check(Updater.newer("3.0.1", "3.0.0") and Updater.newer("3.1", "3.0.9") and Updater.newer("10.0.0", "9.9.9"), "newer versions")
	check(not Updater.newer("3.0.0", "3.0.0") and not Updater.newer("2.9.9", "3.0.0"), "not newer")

	var r := Updater.read_release(_release())
	check(r.version == "3.0.1" and r.size == server.payload.size() and r.sha256 == server.sha and r.url.begins_with("https://"), "a good release reads whole (%s)" % [r])
	check(Updater.read_release(JSON.parse_string(JSON.stringify(_release()))).size == server.payload.size(), "sizes survive JSON's floats")
	var d := _release()
	d.prerelease = true
	check(Updater.read_release(d).is_empty(), "pre-releases are not offered")
	d = _release()
	d.draft = true
	check(Updater.read_release(d).is_empty(), "drafts are not offered")
	d = _release()
	d.tag_name = "v3.0.1-beta"
	check(Updater.read_release(d).is_empty(), "odd tags are not offered")
	check(Updater.read_release(null).is_empty() and Updater.read_release("x").is_empty(), "rubbish is not a release")
	r = Updater.read_release(_release("3.0.1", {"name": "CritterOverlaySetup-3.0.0.exe"}))
	check(r.version == "3.0.1" and r.url == "", "an asset for another version is not fetched")
	r = Updater.read_release(_release("3.0.1", {"digest": null}))
	check(r.url == "", "no digest, no one-click install")
	r = Updater.read_release(_release("3.0.1", {"digest": "sha1:" + server.sha.substr(0, 40)}))
	check(r.url == "", "only SHA-256 digests count")
	r = Updater.read_release(_release("3.0.1", {"digest": "sha256:zz" + server.sha.substr(2)}))
	check(r.url == "", "a digest must be hex")
	r = Updater.read_release(_release("3.0.1", {"browser_download_url": "http://evil.example/a.exe"}))
	check(r.url == "", "plain http is refused")
	r = Updater.read_release(_release("3.0.1", {"browser_download_url": "http://127.0.0.1:1/a.exe"}), true)
	check(r.url != "", "the tests' local server is allowed when asked")

	var h := Updater.headers_dict(PackedStringArray(["ETag: W/\"abc\"", "X-RateLimit-Remaining: 0", "bad"]))
	check(h.get("etag") == "W/\"abc\"" and h.get("x-ratelimit-remaining") == "0" and h.size() == 2, "headers by lower-case name")
	check(Updater.rate_limit_until(200, {}, 100) == 0, "a 200 is not a limit")
	check(Updater.rate_limit_until(403, {"x-ratelimit-remaining": "0", "x-ratelimit-reset": "500"}, 100) == 500, "403 waits until the reset")
	check(Updater.rate_limit_until(403, {"retry-after": "30"}, 100) == 130, "Retry-After wins")
	check(Updater.rate_limit_until(429, {}, 100) == 160, "a bare 429 waits a minute")
	check(Updater.rate_limit_until(403, {"x-ratelimit-remaining": "12"}, 100) == 0, "some other 403 is not a limit")


# --- The download ----------------------------------------------------------------

func _pump(f) -> int:
	var until := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < until:
		server.step()
		var r: int = f.step(2)
		if r != Fetch.RUNNING:
			return r
		OS.delay_usec(200)
	return -1


func _file_is_payload(p: String) -> bool:
	return FileAccess.get_sha256(p) == server.sha


func _fetches() -> void:
	DirAccess.make_dir_recursive_absolute(tmp)
	var part := tmp.path_join("fetch.part")
	DirAccess.remove_absolute(part)
	var size := server.payload.size()
	var go := "http://127.0.0.1:%d/go" % server.port

	server.hits.clear()
	var f = Fetch.new(go, part, size, "test")
	check(_pump(f) == Fetch.DONE and _file_is_payload(part), "a download through a redirect arrives whole")
	check(server.hits.size() == 2 and server.hits[0][0] == "/go" and server.hits[1][0] == "/file", "the redirect is followed (%s)" % [server.hits])

	DirAccess.remove_absolute(part)
	server.drop_at = 100000
	f = Fetch.new(go, part, size, "test")
	var r := _pump(f)
	var had: int = f.got
	check(r == Fetch.INTERRUPTED and had > 0 and had <= 100000, "a dropped connection stops with part of the file (%d, %d bytes)" % [r, had])
	server.hits.clear()
	f = Fetch.new(go, part, size, "test")
	check(f.got == had, "a new download starts from the part already here")
	check(_pump(f) == Fetch.DONE and _file_is_payload(part), "and resumes to the whole file")
	check(server.hits.size() == 2 and server.hits[1][1] == had, "asking only for the rest (%s)" % [server.hits])

	_write(part, server.payload.slice(0, 50000))
	server.ignore_range = true
	f = Fetch.new(go, part, size, "test")
	check(_pump(f) == Fetch.DONE and _file_is_payload(part), "a server that sends it all from the start is fine too")
	server.ignore_range = false

	_write(part, server.payload + PackedByteArray([1, 2, 3]))
	f = Fetch.new(go, part, size, "test")
	check(f.got == 0, "a part larger than the file is thrown away")
	check(_pump(f) == Fetch.DONE and _file_is_payload(part), "and fetched again")

	server.hits.clear()
	f = Fetch.new(go, part, size, "test")
	check(_pump(f) == Fetch.DONE and server.hits.is_empty(), "a complete part needs no network")

	DirAccess.remove_absolute(part)
	f = Fetch.new("http://127.0.0.1:%d/missing" % server.port, part, size, "test")
	check(_pump(f) == Fetch.FAILED and f.error == "HTTP 404", "a missing file fails (%s)" % f.error)

	f = Fetch.new("http://127.0.0.1:1/nothing", part, size, "test")
	f.stall_ms = 3000
	r = _pump(f)
	check(r == Fetch.INTERRUPTED, "nobody listening is a dropped connection, to retry later (%d %s)" % [r, f.error])
	DirAccess.remove_absolute(part)


func _write(p: String, bytes: PackedByteArray) -> void:
	var w := FileAccess.open(p, FileAccess.WRITE)
	w.store_buffer(bytes)
	w.close()


# --- The updater, whole ----------------------------------------------------------

func _fresh(dir_name: String, v := "3.0.0") -> Node:
	var d := tmp.path_join(dir_name)
	_wipe(d)
	var u = Updater.new()
	u.dir = d
	u.version = v
	u.api_url = "http://127.0.0.1:%d/release" % server.port
	u.allow_http = true
	u.installed = true
	root.add_child(u)
	return u


func _wipe(d: String) -> void:
	var da := DirAccess.open(d)
	if da != null:
		for f in da.get_files():
			da.remove(f)
	DirAccess.make_dir_recursive_absolute(d)


func _until(u, states: Array, secs := 15.0) -> void:
	var until := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < until and not u.state in states:
		server.step()
		await process_frame


func _updater() -> void:
	server.release_json = JSON.stringify(_release("3.0.1", {"browser_download_url": "http://127.0.0.1:%d/go" % server.port}))
	var u = _fresh("one")
	u.check(false)
	await _until(u, ["ready", "failed", "offline", "current"])
	check(u.state == "ready", "a newer release downloads and checks out (%s %s)" % [u.state, u.note])
	check(FileAccess.file_exists(u.dir.path_join("CritterOverlaySetup-3.0.1.exe")) and not FileAccess.file_exists(u.dir.path_join("CritterOverlaySetup-3.0.1.exe.part")), "the checked file is the .exe; no .part is left")
	check(u.progress() == Vector2i(server.payload.size(), server.payload.size()), "progress is full when ready")

	# Again, an hour later: the ETag goes with it and a 304 is enough.
	server.hits.clear()
	u.now_fn = func() -> int: return int(Time.get_unix_time_from_system()) + 3600
	u.check(false)
	await _until(u, ["ready", "failed", "offline", "current", "available"])
	check(server.hits.size() == 1 and server.hits[0][2], "the second check sends If-None-Match (%s)" % [server.hits])
	check(u.state == "ready", "and a 304 keeps what we know (%s)" % u.state)

	# Check now twice in a minute reaches GitHub once.
	server.hits.clear()
	u.check(true)
	check(server.hits.is_empty() and u.state == "ready", "Check now within a minute answers from what it has")

	# Someone changes the file after it was checked: it is not run.
	var exe: String = u.dir.path_join("CritterOverlaySetup-3.0.1.exe")
	_write(exe, server.payload.slice(1))
	var err: String = u.install(true)
	check(err != "" and u.state == "failed" and not FileAccess.file_exists(exe), "a changed installer is refused and removed (%s)" % err)
	u.queue_free()

	# Tell me: nothing downloads by itself.
	u = _fresh("tell")
	u.auto_download = false
	u.check(false)
	await _until(u, ["available", "failed", "offline", "current"])
	check(u.state == "available" and u.fetch == null, "Tell me stops at available (%s)" % u.state)
	u.download()
	check(u.state == "downloading", "Download starts it")
	u.cancel()
	check(u.state == "available" and u.fetch == null, "Cancel stops it")
	u.queue_free()

	# Not an installed copy (the editor, a bare export): no one-click.
	u = _fresh("dev")
	u.installed = false
	u.check(false)
	await _until(u, ["available", "failed", "offline", "current"])
	check(u.state == "available" and not u.one_click() and u.fetch == null, "a copy the installer did not put there only links to the release")
	u.queue_free()

	# Up to date.
	u = _fresh("current", "3.0.1")
	u.check(false)
	await _until(u, ["available", "failed", "offline", "current"])
	check(u.state == "current" and u.note.begins_with("Checked at"), "the same version is up to date (%s)" % u.note)
	u.queue_free()

	# A corrupt download is thrown away and counted.
	server.corrupt = true
	u = _fresh("corrupt")
	u.check(false)
	await _until(u, ["ready", "failed", "offline", "current"], 3.0)
	check(u._store.bad.get("3.0.1", 0) == 1 and not FileAccess.file_exists(u.dir.path_join("CritterOverlaySetup-3.0.1.exe")), "a download that does not match the hash is not kept")
	check(u.state == "downloading" and u.fetch == null, "and is fetched again shortly")
	u._store.bad["3.0.1"] = Updater.MAX_BAD
	check(not u.one_click(), "after three bad downloads only the link is offered")
	server.corrupt = false
	u.queue_free()

	# Rate limited: it waits, without asking again.
	server.api_status = 403
	server.api_headers = ["X-RateLimit-Remaining: 0", "X-RateLimit-Reset: %d" % (int(Time.get_unix_time_from_system()) + 600)]
	u = _fresh("limited")
	u.check(false)
	await _until(u, ["busy", "failed", "offline", "current", "ready"])
	check(u.state == "busy" and "Try again after" in u.note, "a rate limit says when (%s %s)" % [u.state, u.note])
	server.hits.clear()
	u.check(true)
	check(u.state == "busy" and server.hits.is_empty(), "and does not ask again until then")
	server.api_status = 200
	server.api_headers = []
	u.queue_free()

	# Offline.
	u = _fresh("offline")
	u.api_url = "http://127.0.0.1:1/release"
	var said := [null]
	u.check(false, func(ok): said[0] = ok)
	await _until(u, ["offline", "current", "failed"])
	check(u.state == "offline" and said[0] == false, "no network is offline, and not a success (so the daily check tries again)")
	u.queue_free()
	await process_frame


func _launch() -> void:
	# After the installer: did the new version start?
	var d := tmp.path_join("launch")
	_wipe(d)
	for f in ["CritterOverlaySetup-3.0.1.exe", "install-3.0.1.log", "CritterOverlaySetup-3.0.2.exe.part"]:
		_write(d.path_join(f), PackedByteArray([1]))
	_write(d.path_join("update.json"), JSON.stringify({"pending": {"from": "3.0.0", "to": "3.0.1"}, "tries": {"3.0.1": 1}}).to_utf8_buffer())
	var u = Updater.new()
	u.dir = d
	u.version = "3.0.1"
	root.add_child(u)
	var out: Dictionary = u.on_launch()
	check(out.get("result") == "updated" and out.get("version") == "3.0.1", "the new version starting is a success (%s)" % [out])
	check(not FileAccess.file_exists(d.path_join("CritterOverlaySetup-3.0.1.exe")) and not FileAccess.file_exists(d.path_join("install-3.0.1.log")), "its installer and log are tidied away")
	check(FileAccess.file_exists(d.path_join("CritterOverlaySetup-3.0.2.exe.part")), "a download of something newer is kept")
	check(u.on_launch().is_empty(), "and it is said once")
	u.queue_free()

	_write(d.path_join("update.json"), JSON.stringify({"pending": {"from": "3.0.0", "to": "3.0.1"}, "tries": {"3.0.1": 1}}).to_utf8_buffer())
	u = Updater.new()
	u.dir = d
	u.version = "3.0.0"
	root.add_child(u)
	out = u.on_launch()
	check(out.get("result") == "failed" and u.state == "failed", "the old version starting means it did not take (%s)" % [out])
	u.installed = true
	u.release = {"version": "3.0.1", "url": "https://x", "size": 1, "sha256": ""}
	check(u.one_click(), "one failure: it can be tried again")
	u._store.tries["3.0.1"] = Updater.MAX_TRIES
	check(not u.one_click(), "two: only the link")
	u.queue_free()
	await process_frame


# --- A small HTTP server ---------------------------------------------------------

class Server:
	var tcp := TCPServer.new()
	var port := 0
	var conns := []
	var payload := PackedByteArray()
	var sha := ""
	var release_json := ""
	var etag := "W/\"v301\""
	var api_status := 200
	var api_headers := []
	var drop_at := -1           # the next /file reply stops after this many body bytes
	var corrupt := false        # /file sends a byte wrong
	var ignore_range := false   # /file always sends the whole file
	var hits := []              # [path, range start or -1, If-None-Match sent]

	func _init() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		payload.resize(300000)
		for i in payload.size():
			payload[i] = rng.randi() & 0xFF
		var hc := HashingContext.new()
		hc.start(HashingContext.HASH_SHA256)
		hc.update(payload)
		sha = hc.finish().hex_encode()

	func start() -> bool:
		for p in range(18761, 18800):
			if tcp.listen(p, "127.0.0.1") == OK:
				port = p
				return true
		return false

	func step() -> void:
		while tcp.is_connection_available():
			conns.append({"peer": tcp.take_connection(), "in": "", "out": PackedByteArray(), "replied": false})
		for c in conns.duplicate():
			var peer: StreamPeerTCP = c.peer
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				conns.erase(c)
				continue
			if not c.replied:
				var n := peer.get_available_bytes()
				if n > 0:
					c.in += (peer.get_data(n)[1] as PackedByteArray).get_string_from_ascii()
				if "\r\n\r\n" in c.in:
					c.out = _reply(c.in)
					c.replied = true
			if c.replied:
				if not c.out.is_empty():
					var r: Array = peer.put_partial_data(c.out)
					if r[0] == OK and r[1] > 0:
						c.out = c.out.slice(r[1])
				if c.out.is_empty():
					peer.disconnect_from_host()
					conns.erase(c)

	func _reply(req: String) -> PackedByteArray:
		var lines := req.split("\r\n")
		var path := lines[0].get_slice(" ", 1)
		var from := -1
		var inm := ""
		for l in lines:
			var low := l.to_lower()
			if low.begins_with("range: bytes="):
				from = int(l.substr(13).trim_suffix("-"))
			elif low.begins_with("if-none-match:"):
				inm = l.substr(14).strip_edges()
		hits.append([path, from, inm != ""])
		if path == "/release":
			if api_status != 200:
				return _http(api_status, PackedByteArray(), api_headers)
			if inm == etag:
				return _http(304, PackedByteArray(), ["ETag: " + etag])
			return _http(200, release_json.to_utf8_buffer(), ["ETag: " + etag])
		if path == "/go":
			return _http(302, PackedByteArray(), ["Location: http://127.0.0.1:%d/file" % port])
		if path == "/file":
			var body := payload.duplicate()
			if corrupt:
				body[1000] = body[1000] ^ 0xFF
			var code := 200
			var extra := []
			if from >= 0 and not ignore_range:
				if from >= body.size():
					return _http(416, PackedByteArray(), [])
				code = 206
				extra.append("Content-Range: bytes %d-%d/%d" % [from, body.size() - 1, body.size()])
				body = body.slice(from)
			var out := _http(code, body, extra)
			if drop_at >= 0:
				out = out.slice(0, out.size() - body.size() + drop_at)
				drop_at = -1
			return out
		return _http(404, PackedByteArray(), [])

	func _http(code: int, body: PackedByteArray, extra: Array) -> PackedByteArray:
		var head := "HTTP/1.1 %d X\r\nContent-Length: %d\r\nConnection: close\r\n" % [code, body.size()]
		for e in extra:
			head += e + "\r\n"
		return (head + "\r\n").to_utf8_buffer() + body
