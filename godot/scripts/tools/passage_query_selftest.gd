## MATERIALS_MASTER_PLAN M3-2 — PassageQuery selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only passage_query
##
## Synthetic fixtures only (a hand-built Edge through SliceGenerator), the same
## discipline as blast_calculator_selftest.gd. What it pins is the RULE, which is
## the part that has already been read wrong three times:
##
##   - the unit that stacks is the STOREY, not the voxel level (M3-0);
##   - BOTH storey-faces of a pair must be clear, not either one;
##   - STANDING needs two STACKED storeys, not two clear ones anywhere;
##   - "both" means "every face that EXISTS", which is what half-thickness
##     elements will need (M3-2b) and what makes this query survive them.

extends SceneTree

const PassageQueryClass = preload("res://godot/scripts/geometry/passage_query.gd")

var passed: int = 0
var failed: int = 0

## LEAK-CYCLE-01: a Voxel does NOT keep its container alive, so the registries
## these tests build have to outlive the voxels they hand out. Held here for the
## duration of the run rather than in each test's locals.
var _fixtures: Array = []


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("MATERIALS M3-2 — PassageQuery SELFTEST")
	print("=".repeat(70) + "\n")

	test_intact_wall_is_no_passage()
	test_one_side_clear_is_not_a_passage()
	test_both_sides_of_one_storey_is_crouch()
	test_two_stacked_storeys_is_standing()
	test_two_unstacked_storeys_is_only_crouch()
	test_incomplete_destruction_still_opens_a_passage()
	test_scattered_damage_is_not_a_passage()
	test_a_column_is_clear_only_through_its_full_height()
	test_standing_needs_the_two_runs_to_OVERLAP()
	test_half_thickness_edge_opens_on_its_only_face()
	test_clear_storeys_reports_where_ascending()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ PASSAGE QUERY SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ PASSAGE QUERY SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## One edge between (0,0) and (0,1), `storeys` tall, both slices generated.
func _wall(storeys: int) -> Dictionary:
	var registry := EdgeRegistry.new()
	var edge := Edge.between(Vector2i(0, 0), Vector2i(0, 1), storeys, "concrete")
	SliceGenerator.generate([edge], registry)
	_fixtures.append(registry)
	return {"edge": edge, "registry": registry}


## Destroy one storey-face: every voxel of `storey` on `slice`.
func _clear_storey_face(slice: Slice, storey: int) -> int:
	var n: int = 0
	for voxel in slice.voxels:
		if int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY))) != storey:
			continue
		voxel.set_damage(Voxel.DamageState.DESTROYED, false)
		n += 1
	return n


func _both_faces(fixture: Dictionary) -> Array:
	return fixture["registry"].slices_of_edge(fixture["edge"].id)


func _check(fixture: Dictionary, expected: int, label: String) -> void:
	var got: int = PassageQueryClass.passage_class(fixture["edge"], fixture["registry"])
	if got == expected:
		_pass("%s → %s" % [label, PassageQueryClass.class_name_of(got)])
	else:
		_fail("%s → %s, expected %s" % [label,
			PassageQueryClass.class_name_of(got), PassageQueryClass.class_name_of(expected)])


func test_intact_wall_is_no_passage() -> void:
	print("TEST: an intact wall offers nothing")
	var w := _wall(2)
	var faces: Array = _both_faces(w)
	if faces.size() == 2:
		_pass("SliceGenerator built both storey-faces (%d voxels each)" % faces[0].voxels.size())
	else:
		_fail("expected 2 slices on the edge, got %d" % faces.size())
	_check(w, PassageQueryClass.PassageClass.NONE, "intact 2-storey wall")
	print("")


func test_one_side_clear_is_not_a_passage() -> void:
	print("TEST: ONE side clear is not a passage — the Director's rule is the PAIR")
	## This is the case every wrong reading of the rule got wrong: a wall is 2
	## voxels thick (D16), and blowing the near face off leaves the far one
	## standing. You are looking at damage, not at a doorway.
	var w := _wall(2)
	var faces: Array = _both_faces(w)
	var n: int = _clear_storey_face(faces[0], GeometryCoords.PLAYABLE_STOREY + 0)
	_check(w, PassageQueryClass.PassageClass.NONE,
		"storey 0 cleared on ONE face (%d voxels)" % n)
	print("")


func test_both_sides_of_one_storey_is_crouch() -> void:
	print("TEST: both storey-faces of one storey → CROUCH")
	var w := _wall(2)
	var faces: Array = _both_faces(w)
	_clear_storey_face(faces[0], GeometryCoords.PLAYABLE_STOREY + 0)
	_check(w, PassageQueryClass.PassageClass.NONE, "still only one face down")
	_clear_storey_face(faces[1], GeometryCoords.PLAYABLE_STOREY + 0)
	_check(w, PassageQueryClass.PassageClass.CROUCH, "both faces of storey 0")
	print("")


func test_two_stacked_storeys_is_standing() -> void:
	print("TEST: two STACKED pairs → STANDING (the agent is 1.41 storeys tall)")
	var w := _wall(2)
	var faces: Array = _both_faces(w)
	for f in faces:
		_clear_storey_face(f, GeometryCoords.PLAYABLE_STOREY + 0)
	_check(w, PassageQueryClass.PassageClass.CROUCH, "one pair down")
	for f in faces:
		_clear_storey_face(f, GeometryCoords.PLAYABLE_STOREY + 1)
	_check(w, PassageQueryClass.PassageClass.STANDING, "storeys 0 and 1, both faces")
	print("")


func test_two_unstacked_storeys_is_only_crouch() -> void:
	print("TEST: two clear storeys that are NOT stacked are two windows, not a door")
	var w := _wall(3)
	var faces: Array = _both_faces(w)
	for f in faces:
		_clear_storey_face(f, GeometryCoords.PLAYABLE_STOREY + 0)
		_clear_storey_face(f, GeometryCoords.PLAYABLE_STOREY + 2)
	_check(w, PassageQueryClass.PassageClass.CROUCH, "storeys 0 and 2 clear, storey 1 intact")
	## ...and closing the gap turns it into a doorway, which proves the previous
	## assertion is about ADJACENCY and not about the count.
	for f in faces:
		_clear_storey_face(f, GeometryCoords.PLAYABLE_STOREY + 1)
	_check(w, PassageQueryClass.PassageClass.STANDING, "storey 1 cleared as well")
	print("")


## Destroy storey `storey` on every face, EXCEPT the given face positions.
func _clear_storey_except(fixture: Dictionary, storey: int, keep_positions: Array) -> void:
	var width: int = GeometryCoords.VOXELS_PER_UNIT_AXIS
	for slice in _both_faces(fixture):
		for i in range(slice.voxels.size()):
			var voxel: Voxel = slice.voxels[i]
			if int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY))) != storey:
				continue
			if keep_positions.has(i % width):
				continue
			voxel.set_damage(Voxel.DamageState.DESTROYED, false)


func test_incomplete_destruction_still_opens_a_passage() -> void:
	print("TEST: a passage is an OPENING, not a demolition (Director, 2026-08-21)")
	## *"Vamos habilitar passagens em destruição incompleta, não precisa estar
	## totalmente destruído, desde que tenha uma lógica visual razoável."*
	##
	## The bar this replaced never fired on the real map: a grenade at a plywood
	## wall's base left the storey 60 of 64 cells open and the query still said
	## NONE, because four voxels survived.
	var w := _wall(2)
	_clear_storey_except(w, GeometryCoords.PLAYABLE_STOREY + 0, [7])
	_check(w, PassageQueryClass.PassageClass.CROUCH,
		"7 of 8 columns clear, one intact column left standing")
	print("")


func test_scattered_damage_is_not_a_passage() -> void:
	print("TEST: SCATTERED damage is not a passage — contiguity is the visual logic")
	## The assertion that stops the new rule from being a bare percentage. Both
	## walls below lose the SAME NUMBER of cells; only one of them is a doorway.
	var scattered := _wall(2)
	_clear_storey_except(scattered, GeometryCoords.PLAYABLE_STOREY + 0, [1, 3, 5, 7])
	_check(scattered, PassageQueryClass.PassageClass.NONE,
		"4 of 8 columns clear but ALTERNATING — the widest run is 1")

	var contiguous := _wall(2)
	_clear_storey_except(contiguous, GeometryCoords.PLAYABLE_STOREY + 0, [4, 5, 6, 7])
	_check(contiguous, PassageQueryClass.PassageClass.CROUCH,
		"the same 4 columns clear, ADJACENT this time")
	print("")


func test_a_column_is_clear_only_through_its_full_height() -> void:
	print("TEST: a column counts only when the WHOLE storey height is clear")
	## Otherwise a knee-high gap the length of the wall would read as a doorway.
	var w := _wall(2)
	_clear_storey_except(w, GeometryCoords.PLAYABLE_STOREY + 0, [])
	_check(w, PassageQueryClass.PassageClass.CROUCH, "storey 0 fully open")

	## Put one voxel back in each of the 8 columns, at different heights: every
	## cell but eight is still gone, and not one column is clear through.
	var width: int = GeometryCoords.VOXELS_PER_UNIT_AXIS
	for slice in _both_faces(w):
		for i in range(slice.voxels.size()):
			var voxel: Voxel = slice.voxels[i]
			if int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY))) \
					!= GeometryCoords.PLAYABLE_STOREY:
				continue
			var position: int = i % width
			var level_in_storey: int = int(float(i) / float(width))
			if level_in_storey == position:
				voxel.set_damage(Voxel.DamageState.DENTED, false)
	_check(w, PassageQueryClass.PassageClass.NONE,
		"one survivor per column, on a diagonal — 56 of 64 cells gone, no column clear through")
	print("")


func test_standing_needs_the_two_runs_to_OVERLAP() -> void:
	print("TEST: STANDING needs the two storeys' openings to LINE UP")
	## Two wide gaps at opposite ends of the wall are two crouch holes, not
	## something to walk through upright.
	var offset := _wall(2)
	_clear_storey_except(offset, GeometryCoords.PLAYABLE_STOREY + 0, [4, 5, 6, 7])
	_clear_storey_except(offset, GeometryCoords.PLAYABLE_STOREY + 1, [0, 1, 2, 3])
	_check(offset, PassageQueryClass.PassageClass.CROUCH,
		"storey 0 open on the left, storey 1 open on the right — no continuous opening")

	var aligned := _wall(2)
	_clear_storey_except(aligned, GeometryCoords.PLAYABLE_STOREY + 0, [4, 5, 6, 7])
	_clear_storey_except(aligned, GeometryCoords.PLAYABLE_STOREY + 1, [4, 5, 6, 7])
	_check(aligned, PassageQueryClass.PassageClass.STANDING,
		"the same 4 columns on both storeys — one opening, two storeys tall")
	print("")


func test_half_thickness_edge_opens_on_its_only_face() -> void:
	print("TEST: M3-2b forward-compat — an edge with ONE storey-face opens on that one")
	## Half-thickness elements do not exist yet (SliceGenerator creates both
	## slices unconditionally), so this fixture takes one away the way the
	## builder eventually will: the slice is never registered and the edge's
	## backref is empty. NOT by pre-destroying it — that is the rule §3.2b says
	## must never be broken, and it would make this test assert nothing.
	var registry := EdgeRegistry.new()
	var edge := Edge.between(Vector2i(0, 0), Vector2i(0, 1), 2, "fabric")
	SliceGenerator.generate([edge], registry)
	_fixtures.append(registry)
	var lone: Slice = registry.get_slice(edge.slice_a_id)
	registry._slices.erase(edge.slice_b_id)
	edge.slice_b_id = ""

	var faces: Array = registry.slices_of_edge(edge.id)
	if faces.size() == 1:
		_pass("the edge now has exactly one storey-face, as a fabric panel will")
	else:
		_fail("expected 1 slice after removing the sibling, got %d" % faces.size())

	var before: int = PassageQueryClass.passage_class(edge, registry)
	if before == PassageQueryClass.PassageClass.NONE:
		_pass("intact half-thickness panel is still NONE")
	else:
		_fail("intact half-thickness panel reported %s"
			% PassageQueryClass.class_name_of(before))

	_clear_storey_face(lone, GeometryCoords.PLAYABLE_STOREY + 0)
	var after: int = PassageQueryClass.passage_class(edge, registry)
	if after == PassageQueryClass.PassageClass.CROUCH:
		_pass("clearing its ONLY face opens a CROUCH passage — 'both sides' means 'every side that exists'")
	else:
		_fail("half-thickness panel with its one face cleared reported %s, expected CROUCH"
			% PassageQueryClass.class_name_of(after))
	print("")


func test_clear_storeys_reports_where_ascending() -> void:
	print("TEST: clear_storeys() says WHERE, ascending — reachability is the caller's question")
	var w := _wall(3)
	var faces: Array = _both_faces(w)
	for f in faces:
		_clear_storey_face(f, GeometryCoords.PLAYABLE_STOREY + 2)
		_clear_storey_face(f, GeometryCoords.PLAYABLE_STOREY + 0)
	var open: Array[int] = PassageQueryClass.clear_storeys(w["edge"], w["registry"])
	## LEVEL-RENUMBER — the storeys this reports are absolute and the playable one
	## is 10 now, so the expectation moves with it. The PROPERTY under test is
	## unchanged: ascending, and independent of destruction order.
	if open == [GeometryCoords.PLAYABLE_STOREY, GeometryCoords.PLAYABLE_STOREY + 2]:
		_pass("clear_storeys() = %s — ascending, and independent of the order they were destroyed in" % str(open))
	else:
		_fail("clear_storeys() = %s, expected [0, 2]" % str(open))
	print("")
