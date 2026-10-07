extends Node
## One-click updates. Asks GitHub for the newest release, downloads its
## installer into the app data folder in the background, checks it against
## the SHA-256 GitHub publishes for the asset, and runs it when asked: from
## the update note or Settings (and the app comes back by itself), or
## quietly when the user quits.
##
## The installer (installer/installer-v3.iss) does the rest. /UPDATE=1 makes
## it wait for this process to let go of its mutex; /RELAUNCH=PATH starts the
## app again when it is done, whether the install went through or not.
## pending in update.json says which version we were heading for, so the
## next launch knows how it went (on_launch).
##
## Rate limits: GitHub allows 60 API calls an hour per address without a
## login, and an address is often shared. Checks send the last ETag (a 304
## costs nothing), stop until the reset time when told to, and Check now
## reaches GitHub at most once a minute. The download is not an API call.
##
## The download resumes: a .part file grows with Range requests across
## sleeps and dropped connections (Fetch, below). Once complete it is hashed
## off the main thread and renamed to the .exe; the .exe is hashed again just
## before it runs.
##
## The hash catches a corrupt or cut-short download. It does not protect
## against someone who can publish releases on the repo; a code-signing
## check belongs here once releases are signed.

signal changed   # state or release; download progress is polled

const API_URL := "https://api.github.com/repos/hstagg/critter-overlay/releases/latest"
const RELEASES_URL := "https://github.com/hstagg/critter-overlay/releases/latest"
const ASSET := "CritterOverlaySetup-%s.exe"
const RETRY := [60.0, 300.0, 1800.0]    # s before resuming a dropped download
const MAX_BAD := 3                      # downloads of one version that fail the hash
const MAX_TRIES := 2                    # installs of one version that did not take
const MANUAL_GAP := 60                  # s between Check now calls that reach GitHub

var api_url := API_URL
var dir := "user://updates"
var version := ""                       # the running build's
var auto_download := true               # Settings > Updates: Download for me
var installed := false                  # an installed copy (not the editor, not a bare export)
var allow_http := false                 # tests serve the release from 127.0.0.1
var now_fn := func() -> int: return int(Time.get_unix_time_from_system())

## idle | checking | current | offline | busy | available | downloading
## | verifying | ready | installing | failed
var state := "idle"
var note := ""                          # current: when; busy, failed: why
var release := {}                       # read_release() of the newest release
var fetch: Fetch = null

var _store := {}                        # update.json: etag, release, rate_until, last_net, bad, tries, pending
var _drops := 0
var _retry_in := -1.0
var _verify_task := -1
var _verify_hash := ""


func _ready() -> void:
	installed = installed or _installed_copy()
	var f := FileAccess.get_file_as_string(_path("update.json"))
	var d = JSON.parse_string(f) if f != "" else null
	_store = d if typeof(d) == TYPE_DICTIONARY else {}
	for k in ["bad", "tries"]:
		if typeof(_store.get(k)) != TYPE_DICTIONARY:
			_store[k] = {}
	release = _store.get("release", {}) if typeof(_store.get("release")) == TYPE_DICTIONARY else {}


# --- Pure parts (tested in updater_test.gd) ---------------------------------------

static func newer(a: String, b: String) -> bool:
	var x := a.split(".")
	var y := b.split(".")
	for i in 3:
		var p := int(x[i]) if i < x.size() else 0
		var q := int(y[i]) if i < y.size() else 0
		if p != q:
			return p > q
	return false


static func read_release(d, allow_http := false) -> Dictionary:
	# The newest release as this file uses it, or {} if it is not one to
	# offer. url is "" when there is no installer to fetch and check (no
	# asset by the expected name, or no SHA-256 from GitHub): then the update
	# note only links to the release page.
	if typeof(d) != TYPE_DICTIONARY or d.get("draft", false) or d.get("prerelease", false):
		return {}
	var v := str(d.get("tag_name", "")).trim_prefix("v")
	if RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$").search(v) == null:
		return {}
	var page := str(d.get("html_url", ""))
	var out := {"version": v, "page": page if page.begins_with("https://") else RELEASES_URL,
		"url": "", "size": 0, "sha256": ""}
	var assets = d.get("assets", [])
	if typeof(assets) != TYPE_ARRAY:
		return out
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY or str(a.get("name", "")) != ASSET % v:
			continue
		var url := str(a.get("browser_download_url", ""))
		var digest := str(a.get("digest", "")).to_lower()
		var size := int(a.get("size", 0))
		var sha := digest.trim_prefix("sha256:")
		var ok_url := url.begins_with("https://") or (allow_http and url.begins_with("http://127.0.0.1"))
		if ok_url and digest.begins_with("sha256:") and sha.length() == 64 and sha.is_valid_hex_number() and size > 0:
			out.url = url
			out.size = size
			out.sha256 = sha
	return out


static func headers_dict(headers: PackedStringArray) -> Dictionary:
	var out := {}
	for h in headers:
		var i := h.find(":")
		if i > 0:
			out[h.substr(0, i).strip_edges().to_lower()] = h.substr(i + 1).strip_edges()
	return out


static func rate_limit_until(code: int, h: Dictionary, now: int) -> int:
	# When GitHub will answer again after a 403 or 429, or 0 if this is not
	# a rate limit.
	if code != 403 and code != 429:
		return 0
	if h.has("retry-after"):
		return now + maxi(int(h["retry-after"]), 1)
	if str(h.get("x-ratelimit-remaining", "")) == "0" and h.has("x-ratelimit-reset"):
		return maxi(int(h["x-ratelimit-reset"]), now + 1)
	return now + 60 if code == 429 else 0


# --- Launch ----------------------------------------------------------------------

func on_launch() -> Dictionary:
	# After an install: {"result": "updated" | "failed", "version": ...}, or
	# {} when none was under way. Old installers are tidied away either way.
	var p = _store.get("pending", {})
	_store.erase("pending")
	var out := {}
	if typeof(p) == TYPE_DICTIONARY and p.has("to"):
		if not newer(str(p.to), version):
			out = {"result": "updated", "version": version}
		else:
			out = {"result": "failed", "version": str(p.to)}
			state = "failed"
			note = "The update to %s did not finish. Your critters and Collection are fine." % p.to
	_tidy()
	_save()
	return out


func _tidy() -> void:
	# Installers for this version or older, and their logs, are done with.
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		var m := RegEx.create_from_string("^(?:CritterOverlaySetup|install)-(\\d+\\.\\d+\\.\\d+)").search(f)
		if m != null and not newer(m.get_string(1), version):
			da.remove(f)


# --- Checking --------------------------------------------------------------------

func check(manual: bool, done := Callable()) -> void:
	# done(ok): ok when GitHub answered (a new release or not).
	if state in ["checking", "installing"]:
		if done.is_valid():
			done.call(false)
		return
	var now: int = now_fn.call()
	var until := int(_store.get("rate_until", 0))
	if now < until:
		_to("busy", "GitHub is busy. Try again after %s." % _clock(until))
		if done.is_valid():
			done.call(false)
		return
	if manual and now - int(_store.get("last_net", 0)) < MANUAL_GAP and state not in ["offline", "busy", "idle"]:
		_after_check()
		if done.is_valid():
			done.call(true)
		return
	_to("checking")
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	var headers := ["User-Agent: CritterOverlay/" + version, "Accept: application/vnd.github+json"]
	if str(_store.get("etag", "")) != "" and not release.is_empty():
		headers.append("If-None-Match: " + str(_store.etag))
	req.request_completed.connect(func(result, code, hs, body):
		req.queue_free()
		var ok := _on_checked(result, code, hs, body)
		if done.is_valid():
			done.call(ok))
	if req.request(api_url, headers) != OK:
		req.queue_free()
		_to("offline")
		if done.is_valid():
			done.call(false)


func _on_checked(result: int, code: int, hs: PackedStringArray, body: PackedByteArray) -> bool:
	var now: int = now_fn.call()
	if result != HTTPRequest.RESULT_SUCCESS:
		_to("offline")
		return false
	var h := headers_dict(hs)
	if code == 200:
		release = read_release(JSON.parse_string(body.get_string_from_utf8()), allow_http)
		_store.release = release
		_store.etag = str(h.get("etag", ""))
	elif code != 304:
		var until := rate_limit_until(code, h, now)
		if until > 0:
			_store.rate_until = until
			_save()
			_to("busy", "GitHub is busy. Try again after %s." % _clock(until))
		else:
			_to("offline")
		return false
	_store.last_net = now
	_save()
	_after_check()
	return true


func _after_check() -> void:
	if fetch != null or _verify_task >= 0:
		return   # already on its way
	if release.is_empty() or not newer(str(release.version), version):
		_to("current", "Checked at %s." % _clock(int(_store.get("last_net", now_fn.call()))))
		return
	if one_click() and FileAccess.file_exists(_exe()):
		_to("ready")
		return
	_to("available")
	if auto_download and one_click():
		download()


func resume() -> void:
	# At start-up, between daily checks: carry on from what was known (a
	# download to finish, an installer ready).
	if state == "idle" and not release.is_empty():
		_after_check()


func retry() -> void:
	# Settings > Updates > Try again, after a failure.
	if release.is_empty():
		check(true)
	else:
		_to("idle")
		_after_check()


func one_click() -> bool:
	# The newest release can be downloaded, checked and installed from here.
	if release.is_empty() or str(release.get("url", "")) == "" or not installed:
		return false
	var v := str(release.version)
	return int(_store.bad.get(v, 0)) < MAX_BAD and int(_store.tries.get(v, 0)) < MAX_TRIES


# --- Downloading -----------------------------------------------------------------

func download() -> void:
	if not one_click() or fetch != null or _verify_task >= 0:
		return
	if FileAccess.file_exists(_exe()):
		_to("ready")
		return
	DirAccess.make_dir_recursive_absolute(dir)
	_retry_in = -1.0
	fetch = Fetch.new(str(release.url), _part(), int(release.size), "CritterOverlay/" + version)
	_to("downloading")


func cancel() -> void:
	# Stops for now; the .part stays, so the next download carries on.
	if fetch != null:
		fetch.close()
		fetch = null
	_retry_in = -1.0
	_to("available")


func progress() -> Vector2i:
	# Bytes so far and in all, while downloading.
	if fetch != null:
		return Vector2i(fetch.got, fetch.size)
	var size := int(release.get("size", 0))
	return Vector2i(size, size) if state in ["verifying", "ready"] else Vector2i(0, size)


func _process(delta: float) -> void:
	if fetch != null:
		var r := fetch.step()
		if r == Fetch.DONE:
			fetch = null
			_drops = 0
			_verify()
		elif r == Fetch.INTERRUPTED:
			fetch = null
			_drops += 1
			if _drops <= RETRY.size():
				_retry_in = RETRY[_drops - 1]   # stays "downloading", waiting
			else:
				_drops = 0
				_to("offline")                 # the next check carries on
		elif r == Fetch.FAILED:
			var why := fetch.error
			fetch = null
			_to("failed", "The download stopped (%s). Try again later." % why)
	if _retry_in > 0.0:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_retry_in = -1.0
			if state == "downloading":
				download()
	if _verify_task >= 0 and WorkerThreadPool.is_task_completed(_verify_task):
		WorkerThreadPool.wait_for_task_completion(_verify_task)
		_verify_task = -1
		_verified(_verify_hash)


func _verify() -> void:
	# Off the main thread: hashing 30 MB at once would make the critters stutter.
	_to("verifying")
	var p := ProjectSettings.globalize_path(_part())
	_verify_hash = ""
	_verify_task = WorkerThreadPool.add_task(func(): _verify_hash = FileAccess.get_sha256(p))


func _verified(sha: String) -> void:
	var v := str(release.version)
	if sha != "" and sha == str(release.sha256):
		DirAccess.rename_absolute(_part(), _exe())
		_to("ready")
		return
	DirAccess.remove_absolute(_part())
	_store.bad[v] = int(_store.bad.get(v, 0)) + 1
	_save()
	if one_click():
		_to("downloading")
		_retry_in = 5.0
	else:
		_to("failed", "The download of %s did not match what GitHub published, so it was not installed." % v)


# --- Installing ------------------------------------------------------------------

func per_user() -> bool:
	# Installed in the user's own folder: an update needs no admin prompt.
	var local := OS.get_environment("LOCALAPPDATA").replace("\\", "/").to_lower()
	return local != "" and OS.get_executable_path().replace("\\", "/").to_lower().begins_with(local + "/")


func install(relaunch: bool) -> String:
	# Starts the installer and returns "", or why it could not. The caller
	# saves everything and quits straight after.
	if state != "ready":
		return "No update is ready."
	var v := str(release.version)
	var exe := ProjectSettings.globalize_path(_exe())
	if FileAccess.get_sha256(exe) != str(release.sha256):
		DirAccess.remove_absolute(exe)
		_store.bad[v] = int(_store.bad.get(v, 0)) + 1
		_save()
		_to("failed", "The downloaded update was changed after it was checked, so it was not installed.")
		return note
	_store.tries[v] = int(_store.tries.get(v, 0)) + 1
	_store.pending = {"from": version, "to": v, "at": now_fn.call()}
	_save()
	var args := ["/SILENT" if relaunch else "/VERYSILENT", "/SP-", "/SUPPRESSMSGBOXES", "/NORESTART",
		"/CLOSEAPPLICATIONS", "/UPDATE=1", "/LOG=" + ProjectSettings.globalize_path(_path("install-%s.log" % v))]
	if relaunch:
		args.append("/RELAUNCH=" + OS.get_executable_path())
	if OS.create_process(exe, args) <= 0:
		_store.erase("pending")
		_save()
		_to("failed", "Windows would not start the installer. Try again, or download it yourself.")
		return note
	_to("installing")
	return ""


# --- Small things ----------------------------------------------------------------

func _to(s: String, n := "") -> void:
	var was := [state, note]
	state = s
	note = n
	if was != [state, note]:
		changed.emit()


func _installed_copy() -> bool:
	# Only a build the installer put there can be updated by the installer.
	return OS.get_name() == "Windows" and OS.has_feature("template") \
		and FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("unins000.exe"))


func _path(f: String) -> String:
	return dir.path_join(f)


func _exe() -> String:
	return _path(ASSET % str(release.get("version", "")))


func _part() -> String:
	return _exe() + ".part"


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_path("update.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_store, " "))


static func _clock(unix: int) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	return Time.get_time_string_from_unix_time(unix + bias * 60).substr(0, 5)


# --- The download ----------------------------------------------------------------

class Fetch extends RefCounted:
	## One file over HTTP(S), resumable: follows redirects (GitHub sends the
	## download on to its own servers), asks for the bytes it lacks with
	## Range, and appends them to the .part file. Polled a few milliseconds
	## a frame, so the critters keep moving.
	enum {RUNNING, DONE, INTERRUPTED, FAILED}
	const MAX_REDIRECTS := 5

	var url := ""
	var path := ""
	var size := 0
	var agent := ""
	var got := 0
	var error := ""
	var stall_ms := 30000       # no progress for this long: interrupted
	var http := HTTPClient.new()
	var _file: FileAccess
	var _phase := "connect"    # connect | request | body
	var _redirects := 0
	var _restarted := false
	var _last := 0
	var _done := false

	func _init(from: String, to: String, total: int, user_agent: String) -> void:
		url = from
		path = to
		size = total
		agent = user_agent
		if FileAccess.file_exists(path):
			got = FileAccess.open(path, FileAccess.READ).get_length()
		if got > size:
			DirAccess.remove_absolute(path)
			got = 0
		_done = got == size
		if not _done:
			_connect()

	func step(budget_ms := 6) -> int:
		if _done:
			return DONE
		var until := Time.get_ticks_msec() + budget_ms
		while Time.get_ticks_msec() < until:
			http.poll()
			var st := http.get_status()
			if st in [HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT,
					HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR]:
				if _phase == "body" and got == size:
					return _finish()
				return _stop(INTERRUPTED, "connection lost")
			if st in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING]:
				return _wait()
			if _phase == "connect":
				var hs := ["User-Agent: " + agent, "Accept: application/octet-stream"]
				if got > 0:
					hs.append("Range: bytes=%d-" % got)
				if http.request(HTTPClient.METHOD_GET, _split(url).path, hs) != OK:
					return _stop(INTERRUPTED, "request failed")
				_phase = "request"
				_last = Time.get_ticks_msec()
				continue
			if _phase == "request":
				if not http.has_response():
					return _wait()
				var r := _head()
				if r != RUNNING:
					return r
				continue
			if st == HTTPClient.STATUS_BODY:
				var chunk := http.read_response_body_chunk()
				if chunk.is_empty():
					return _wait()
				_file.store_buffer(chunk)
				got += chunk.size()
				_last = Time.get_ticks_msec()
				if got > size:
					DirAccess.remove_absolute(path)
					return _stop(FAILED, "larger than expected")
				continue
			# The whole body has come (STATUS_CONNECTED).
			return _finish() if got == size else _stop(INTERRUPTED, "ended early")
		return RUNNING

	func close() -> void:
		if _file != null:
			_file.close()
			_file = null
		http.close()

	func _head() -> int:
		var code := http.get_response_code()
		var h := {}
		var raw := http.get_response_headers_as_dictionary()
		for k in raw:
			h[str(k).to_lower()] = str(raw[k])
		if code in [301, 302, 303, 307, 308]:
			_redirects += 1
			var loc: String = h.get("location", "")
			if _redirects > MAX_REDIRECTS or loc == "":
				return _stop(FAILED, "too many redirects")
			url = loc if "://" in loc else _split(url).origin + loc
			return RUNNING if _connect() else _stop(FAILED, "bad redirect")
		if code == 206:
			# The rest, appended; unless it is not the part asked for.
			if not str(h.get("content-range", "")).begins_with("bytes %d-" % got):
				return RUNNING if not _restarted and _restart() else _stop(FAILED, "bad range")
			_file = FileAccess.open(path, FileAccess.READ_WRITE)
			if _file != null:
				_file.seek_end()
		elif code == 200:
			got = 0                  # the server sent it all: start over
			_file = FileAccess.open(path, FileAccess.WRITE)
		elif code == 416 and not _restarted:
			return RUNNING if _restart() else _stop(FAILED, "bad range")
		else:
			return _stop(FAILED, "HTTP %d" % code)
		if _file == null:
			return _stop(FAILED, "cannot write the download")
		_phase = "body"
		return RUNNING

	func _restart() -> bool:
		_restarted = true
		DirAccess.remove_absolute(path)
		got = 0
		return _connect()

	func _connect() -> bool:
		close()
		var u := _split(url)
		_phase = "connect"
		_last = Time.get_ticks_msec()
		if u.is_empty():
			return false
		return http.connect_to_host(u.host, u.port, TLSOptions.client() if u.tls else null) == OK

	func _wait() -> int:
		if Time.get_ticks_msec() - _last > stall_ms:
			return _stop(INTERRUPTED, "stalled")
		return RUNNING

	func _finish() -> int:
		close()
		_done = true
		return DONE

	func _stop(r: int, why: String) -> int:
		close()
		error = why
		return r

	static func _split(u: String) -> Dictionary:
		# https://host[:port]/path?query -> parts; {} if it is not one.
		var m := RegEx.create_from_string("^(https?)://([^/:]+)(?::(\\d+))?(/.*)?$").search(u)
		if m == null:
			return {}
		var tls := m.get_string(1) == "https"
		var port := int(m.get_string(3)) if m.get_string(3) != "" else (443 if tls else 80)
		var p := m.get_string(4) if m.get_string(4) != "" else "/"
		var origin := "%s://%s" % [m.get_string(1), m.get_string(2)] + (":" + m.get_string(3) if m.get_string(3) != "" else "")
		return {"tls": tls, "host": m.get_string(2), "port": port, "path": p, "origin": origin}
