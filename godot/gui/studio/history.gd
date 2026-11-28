extends RefCounted
## Undo and redo for the Critter Studio (docs/custom-critters-build-plan.md,
## D3): before each action, a copy of the layers it is about to change (most
## change one). Undo puts them back and keeps what it replaced for redo. At
## most CAP actions are kept; a new action clears redo.
##
## A drag is one action: the canvas records once, when it begins.

const CAP := 200

var undos: Array = []              # [{part: shapes or null (no layer)}]
var redos: Array = []


func record(doc: Dictionary, parts: Array) -> void:
	undos.append(_snap(doc, parts))
	if undos.size() > CAP:
		undos.pop_front()
	redos.clear()


func can_undo() -> bool:
	return not undos.is_empty()


func can_redo() -> bool:
	return not redos.is_empty()


func undo(doc: Dictionary) -> Array:
	# The parts put back, or [] with nothing to undo.
	if undos.is_empty():
		return []
	var s: Dictionary = undos.pop_back()
	redos.append(_snap(doc, s.keys()))
	_restore(doc, s)
	return s.keys()


func redo(doc: Dictionary) -> Array:
	if redos.is_empty():
		return []
	var s: Dictionary = redos.pop_back()
	undos.append(_snap(doc, s.keys()))
	_restore(doc, s)
	return s.keys()


func clear() -> void:
	undos.clear()
	redos.clear()


static func _snap(doc: Dictionary, parts: Array) -> Dictionary:
	var out := {}
	for p in parts:
		out[p] = doc.layers[p].duplicate(true) if doc.layers.has(p) else null
	return out


static func _restore(doc: Dictionary, s: Dictionary) -> void:
	for p in s:
		if s[p] == null:
			doc.layers.erase(p)
		else:
			doc.layers[p] = s[p].duplicate(true)
