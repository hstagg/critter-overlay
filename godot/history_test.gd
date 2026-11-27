extends SceneTree
## Headless checks for the Studio's undo and redo (gui/studio/history.gd,
## docs/custom-critters-build-plan.md D3): across 50 mixed actions, undoing
## every one restores each earlier doc exactly and redoing brings each back;
## a new action clears redo; only the last 200 are kept.
## Run: godot --headless --path godot --script res://history_test.gd

const Tools := preload("res://gui/studio/tools.gd")
const History := preload("res://gui/studio/history.gd")
const Shapes := preload("res://studio/shapes.gd")

const PARTS := ["head", "eyes", "walk-body", "leg-front", "tail"]

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func text(doc: Dictionary) -> String:
	return JSON.stringify(doc, "", true)


func act(doc: Dictionary, h: RefCounted, rng: RandomNumberGenerator) -> void:
	# One random action of the kinds the canvas makes, recorded first.
	var part: String = PARTS[rng.randi() % PARTS.size()]
	var n := Tools.layer(doc, part).size()
	var kind := rng.randi() % 6 if n > 0 else 0
	var at := Vector2(rng.randf_range(20, 280), rng.randf_range(20, 260))
	h.record(doc, [part])
	match kind:
		0:
			Tools.add(doc, part, Tools.new_shape(Shapes.TYPES[rng.randi() % Shapes.TYPES.size()], at))
		1:
			Tools.move(doc, part, [rng.randi() % n], Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)))
		2:
			Tools.delete(doc, part, [rng.randi() % n])
		3:
			var i := rng.randi() % n
			Tools.edit_one(doc, part, i, Tools.layer(doc, part).duplicate(true), Tools.scaled(Tools.layer(doc, part)[i], Vector2i(1, 1), at, rng.randf() < 0.5), false)
		4:
			Tools.mirror(doc, part, [rng.randi() % n])
		5:
			Tools.duplicate_shapes(doc, part, [rng.randi() % n])


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261127
	var doc := Tools.blank("side")
	var h := History.new()
	var states := [text(doc)]
	for i in 50:
		act(doc, h, rng)
		states.append(text(doc))
	check(h.undos.size() == 50, "50 actions recorded (%d)" % h.undos.size())
	var undo_ok := true
	for i in range(49, -1, -1):
		h.undo(doc)
		if text(doc) != states[i]:
			undo_ok = false
			print("  undo to %d differs" % i)
	check(undo_ok, "undoing each of 50 actions restores the doc before it exactly")
	check(h.undo(doc).is_empty() and text(doc) == states[0], "nothing more to undo, and the doc is as it began")
	var redo_ok := true
	for i in range(1, 51):
		h.redo(doc)
		if text(doc) != states[i]:
			redo_ok = false
			print("  redo to %d differs" % i)
	check(redo_ok, "redoing each brings it back exactly")
	check(h.redo(doc).is_empty(), "nothing more to redo")

	# A new action after an undo clears redo.
	h.undo(doc)
	check(h.can_redo(), "an undo can be redone")
	act(doc, h, rng)
	check(not h.can_redo(), "a new action clears redo")

	# Only the last 200 are kept.
	var d2 := Tools.blank("side")
	var h2 := History.new()
	var at_50 := ""
	for i in 250:
		act(d2, h2, rng)
		if i == 49:
			at_50 = text(d2)
	check(h2.undos.size() == History.CAP, "capped at %d (%d)" % [History.CAP, h2.undos.size()])
	for i in History.CAP:
		h2.undo(d2)
	check(text(d2) == at_50 and not h2.can_undo(), "the oldest kept undo goes back to just after action 50")

	print("HISTORY TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
