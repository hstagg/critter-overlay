extends RefCounted
## Click-through regions for the critter windows.
##
## On Windows the passthrough polygon is a window region: clicks outside it
## reach the window below, and nothing outside it is drawn. Every change to a
## region makes the compositor redraw the window, and for a frame the newly
## covered area shows as an edge or a box. So a region is never shaped to the
## critter. It is the whole window, with a small hole under the pointer when
## the pointer is over the window but not over the critter; clicks through
## the hole land on whatever is below. The hole is the only part that changes
## from frame to frame, and the pointer covers it.

const HOLE_FROM := Vector2(-4, -4)   # the hole about the pointer's tip,
const HOLE_TO := Vector2(12, 14)     # mostly under the arrow so its edges stay hidden


static func polygon(size: Vector2, hole: Rect2) -> PackedVector2Array:
	# The window's outline, then a zero-width bridge to the hole and round it.
	# Windows fills the region even-odd, so the hole, inside both, is left out.
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), Vector2.ZERO])
	if hole.has_area():
		poly.append_array([hole.position, Vector2(hole.end.x, hole.position.y), hole.end,
			Vector2(hole.position.x, hole.end.y), hole.position, Vector2.ZERO])
	return poly


static func inside_even_odd(poly: PackedVector2Array, pt: Vector2) -> bool:
	# The fill rule Windows applies to the region.
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var a := poly[i]
		var b := poly[j]
		if (a.y > pt.y) != (b.y > pt.y) and pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


static func selftest() -> int:
	# Holes in the middle and against each edge, and no hole: every point in
	# the window outside the hole must be in the region, and none inside it.
	var size := Vector2(200, 200)
	var holes := [Rect2(), Rect2(50, 60, 16, 18), Rect2(0, 0, 12, 14), Rect2(188, 186, 12, 14), Rect2(90, 0, 3, 3)]
	var fails := 0
	var checks := 0
	for hole in holes:
		var poly := polygon(size, hole)
		for x in range(0, 200):
			for y in range(0, 200, 2):
				var pt := Vector2(x + 0.5, y + 0.5)
				checks += 1
				if inside_even_odd(poly, pt) == hole.has_point(pt):
					fails += 1
	print("SELFTEST passthrough: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	return fails
