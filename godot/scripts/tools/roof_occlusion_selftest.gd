## R3D-7 — the roof half of the occlusion set: a roof an origin stands UNDER opens by ADJACENCY of its slabs, the way
## a wall opens by adjacency of its edges (Director, 2026-09-20). Reach ROOF_REACH (6) slabs from the slab above the
## origin, the last ROOF_FADE (2) fading (rings 1 and 2); everything nearer is ring 0. Corner-touching slabs count as
## adjacent (square rings). A roof nobody stands under stays solid.
##
## Every fixture is real: Slabs from SlabGenerator in a SlabRegistry, handed to OcclusionSet.recompute() exactly as
## room.gd hands them (CEILING slabs only), and the assertions read the cells the set itself returns.
##
## RED-BEFORE-GREEN is built in: with the old stripe rule (reveal only within MAX_RING = 2 of the origin's x+y) the
## slab 3 away is NOT revealed, so test [1] fails; with reach 3 the slab 5 away is revealed and test [2] fails.
extends SceneTree

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")
const OcclusionSetMod = preload("res://godot/scripts/systems/occlusion_set.gd")

var _failures: int = 0


func _initialize() -> void:
	print("\n== ROOF OCCLUSION SELFTEST ==\n")
	_test_row_reach_and_fade()
	_test_corners_are_adjacent()
	_test_outside_stays_solid()
	_test_hover_origin_adds_its_own_disc()
	_test_a_disconnected_roof_is_left_alone()
	if _failures == 0:
		print("\n[SUCCESS] ROOF OCCLUSION SELFTEST PASS — all tests")
		quit(0)
	else:
		print("\n[FAILURE] %d check(s) failed" % _failures)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


## A rectangle of roofed GUs, two levels each (as room_builder makes them), at the roof of a 3-storey height.
func _roof_slabs(gus: Array) -> Array:
	var registry := SlabRegistry.new()
	var base: int = GeometryCoordsMod.storey_level_base(3)
	for gu: Vector2i in gus:
		for level_offset: int in range(2):
			SlabGenerator.generate(gu, Slab.Role.CEILING, base + level_offset, "concrete", registry)
	var out: Array = []
	for slab in registry.all_slabs():
		if slab.role == Slab.Role.CEILING:
			out.append(slab)
	return out


## The ring the set gives the roof of `gu`, or -1 when that roof is not in the set.
func _ring_of(occ, gu: Vector2i) -> int:
	var cell: Vector2i = GeometryCoordsMod.gu_voxels(gu)[0]
	var cells: Dictionary = occ.get_occluded_cells()
	return int(cells[cell]["ring"]) if cells.has(cell) else -1


## Origins the way room.gd builds them: a TYPED Array[Vector2i]. An untyped one aborts recompute() with a script
## error and leaves the set empty, which is the vacuous pass occlusion_set_selftest.gd's header is about.
func _origins(cells: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		out.append(cell)
	return out


func _row(length: int) -> Array:
	var gus: Array = []
	for x: int in range(length):
		gus.append(Vector2i(x, 0))
	return gus


func _test_row_reach_and_fade() -> void:
	print("[1] a row of 12 roofed GUs, origin under the first: reach, fade, then solid")
	var occ = OcclusionSetMod.new()
	occ.recompute(_origins([Vector2i(0, 0)]), [], Vector2i(20, 20), [], _roof_slabs(_row(12)))
	for d: int in range(4):
		_check(_ring_of(occ, Vector2i(d, 0)) == 0, "slab %d away: ring 0 (open)" % d)
	_check(_ring_of(occ, Vector2i(4, 0)) == 1, "slab 4 away: ring 1 (fading)")
	_check(_ring_of(occ, Vector2i(5, 0)) == 2, "slab 5 away: ring 2 (faintest)")
	_check(_ring_of(occ, Vector2i(6, 0)) == -1, "slab 6 away: out of reach, stays solid")
	_check(_ring_of(occ, Vector2i(11, 0)) == -1, "slab 11 away: stays solid")


func _test_corners_are_adjacent() -> void:
	print("[2] a 9x9 roof, origin under its corner: the far corner slabs are square rings away")
	var gus: Array = []
	for x: int in range(9):
		for y: int in range(9):
			gus.append(Vector2i(x, y))
	var occ = OcclusionSetMod.new()
	occ.recompute(_origins([Vector2i(0, 0)]), [], Vector2i(20, 20), [], _roof_slabs(gus))
	_check(_ring_of(occ, Vector2i(3, 3)) == 0, "the diagonal slab (3,3) is 3 square rings away: open (6 by edges)")
	_check(_ring_of(occ, Vector2i(5, 5)) == 2, "(5,5) is 5 square rings away: the faintest ring")
	_check(_ring_of(occ, Vector2i(6, 6)) == -1, "(6,6) is 6 rings away: stays solid")
	_check(_ring_of(occ, Vector2i(8, 8)) == -1, "the far corner (8,8) stays solid")


func _test_outside_stays_solid() -> void:
	print("[3] an origin NOT under the roof opens nothing")
	var occ = OcclusionSetMod.new()
	occ.recompute(_origins([Vector2i(20, 20)]), [], Vector2i(30, 30), [], _roof_slabs(_row(6)))
	_check(occ.get_occluded_cells().is_empty(), "no occluded cell at all")


func _test_hover_origin_adds_its_own_disc() -> void:
	print("[4] the hover cell is a second origin: its disc joins the agent's")
	var occ = OcclusionSetMod.new()
	occ.recompute(_origins([Vector2i(0, 0), Vector2i(11, 0)]), [], Vector2i(20, 20), [], _roof_slabs(_row(12)))
	_check(_ring_of(occ, Vector2i(0, 0)) == 0 and _ring_of(occ, Vector2i(11, 0)) == 0, "both origins' slabs are open")
	_check(_ring_of(occ, Vector2i(5, 0)) == 2 and _ring_of(occ, Vector2i(6, 0)) == 2, "each disc fades at its own edge")


func _test_a_disconnected_roof_is_left_alone() -> void:
	print("[5] a roof that is not connected to the origin's roof stays solid")
	var gus: Array = _row(4)
	gus.append(Vector2i(10, 0))
	gus.append(Vector2i(11, 0))
	var occ = OcclusionSetMod.new()
	occ.recompute(_origins([Vector2i(0, 0)]), [], Vector2i(20, 20), [], _roof_slabs(gus))
	_check(_ring_of(occ, Vector2i(3, 0)) == 0, "the connected roof opens")
	_check(_ring_of(occ, Vector2i(10, 0)) == -1 and _ring_of(occ, Vector2i(11, 0)) == -1, "the separate roof stays solid")
