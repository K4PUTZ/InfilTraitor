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
	test_one_surviving_voxel_closes_the_passage()
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
	var n: int = _clear_storey_face(faces[0], 0)
	_check(w, PassageQueryClass.PassageClass.NONE,
		"storey 0 cleared on ONE face (%d voxels)" % n)
	print("")


func test_both_sides_of_one_storey_is_crouch() -> void:
	print("TEST: both storey-faces of one storey → CROUCH")
	var w := _wall(2)
	var faces: Array = _both_faces(w)
	_clear_storey_face(faces[0], 0)
	_check(w, PassageQueryClass.PassageClass.NONE, "still only one face down")
	_clear_storey_face(faces[1], 0)
	_check(w, PassageQueryClass.PassageClass.CROUCH, "both faces of storey 0")
	print("")


func test_two_stacked_storeys_is_standing() -> void:
	print("TEST: two STACKED pairs → STANDING (the agent is 1.41 storeys tall)")
	var w := _wall(2)
	var faces: Array = _both_faces(w)
	for f in faces:
		_clear_storey_face(f, 0)
	_check(w, PassageQueryClass.PassageClass.CROUCH, "one pair down")
	for f in faces:
		_clear_storey_face(f, 1)
	_check(w, PassageQueryClass.PassageClass.STANDING, "storeys 0 and 1, both faces")
	print("")


func test_two_unstacked_storeys_is_only_crouch() -> void:
	print("TEST: two clear storeys that are NOT stacked are two windows, not a door")
	var w := _wall(3)
	var faces: Array = _both_faces(w)
	for f in faces:
		_clear_storey_face(f, 0)
		_clear_storey_face(f, 2)
	_check(w, PassageQueryClass.PassageClass.CROUCH, "storeys 0 and 2 clear, storey 1 intact")
	## ...and closing the gap turns it into a doorway, which proves the previous
	## assertion is about ADJACENCY and not about the count.
	for f in faces:
		_clear_storey_face(f, 1)
	_check(w, PassageQueryClass.PassageClass.STANDING, "storey 1 cleared as well")
	print("")


func test_one_surviving_voxel_closes_the_passage() -> void:
	print("TEST: one surviving voxel in an otherwise open storey-face closes it")
	## The sharpest form of "clear". A storey-face is 64 voxels; leaving one
	## standing has to read as NONE, or a wall with a single stubborn column
	## reports a doorway.
	var w := _wall(2)
	var faces: Array = _both_faces(w)
	for f in faces:
		for voxel in f.voxels:
			if int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY))) != 0:
				continue
			voxel.set_damage(Voxel.DamageState.DESTROYED, false)
	_check(w, PassageQueryClass.PassageClass.CROUCH, "storey 0 fully open")

	## Put ONE voxel back. set_damage() does not clamp (the segment-rewind system
	## needs to walk a voxel back), which is exactly what makes this expressible.
	var survivor: Voxel = null
	for voxel in faces[0].voxels:
		if int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY))) == 0:
			survivor = voxel
			break
	survivor.set_damage(Voxel.DamageState.DENTED, false)
	_check(w, PassageQueryClass.PassageClass.NONE,
		"one voxel at %s restored to DENTED" % survivor.grid_pos)
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

	_clear_storey_face(lone, 0)
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
		_clear_storey_face(f, 2)
		_clear_storey_face(f, 0)
	var open: Array[int] = PassageQueryClass.clear_storeys(w["edge"], w["registry"])
	if open == [0, 2]:
		_pass("clear_storeys() = %s — ascending, and independent of the order they were destroyed in" % str(open))
	else:
		_fail("clear_storeys() = %s, expected [0, 2]" % str(open))
	print("")
