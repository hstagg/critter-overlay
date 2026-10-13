extends RefCounted
## Reading and writing the player's JSON saves (settings.json, economy.json)
## so that neither a bad write nor a damaged file loses their progress.
##
##   - write: the new text goes to <file>.tmp; the old file, if it reads,
##     becomes <file>.bak; then <file>.tmp becomes <file>. A crash at any
##     point leaves a complete copy in one of the three.
##   - read: the first of <file>, <file>.tmp, <file>.bak that is a JSON
##     object. A file that exists but does not read is first copied aside as
##     <file>.corrupt-<unix time>, so it can be recovered by hand; it is never
##     simply overwritten.


static func read(path: String) -> Variant:
	# The saved object, or null when there is nothing readable.
	for p in [path, path + ".tmp", path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if typeof(d) == TYPE_DICTIONARY:
			if p != path:
				push_warning("%s: read from %s" % [path.get_file(), p.get_file()])
			return d
		_set_aside(p)
	return null


static func write(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("cannot write %s: %s" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, " "))
	f.close()
	if FileAccess.file_exists(path):
		if typeof(JSON.parse_string(FileAccess.get_file_as_string(path))) == TYPE_DICTIONARY:
			if FileAccess.file_exists(path + ".bak"):
				DirAccess.remove_absolute(path + ".bak")
			DirAccess.rename_absolute(path, path + ".bak")
		else:
			_set_aside(path)
			DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("cannot save %s: %s" % [path, error_string(err)])
		return false
	return true


static func _set_aside(p: String) -> void:
	# Once per damaged file: a copy with the same bytes is already kept.
	var text := FileAccess.get_file_as_string(p)
	var base := p.get_file() + ".corrupt-"
	for n in DirAccess.get_files_at(p.get_base_dir()):
		if n.begins_with(base) and FileAccess.get_file_as_string(p.get_base_dir().path_join(n)) == text:
			return
	var to := "%s.corrupt-%d" % [p, int(Time.get_unix_time_from_system())]
	if DirAccess.copy_absolute(p, to) == OK:
		push_warning("%s could not be read; kept as %s" % [p.get_file(), to.get_file()])
	else:
		push_warning("%s could not be read or kept aside" % p.get_file())
