## MATERIALS_MASTER_PLAN M3-2b — half-thickness elements.
## Rodar: python3 tools/persistent/run_selftests.py --only half_thickness
##
## A normal wall is two voxels thick (D16): one storey-face on each of the two
## adjacent GUs. Fabric, cardboard, glass and plywood are HALF thickness — one
## face only. A glass window covers one face and leaves the opposite face empty
## inside the opening, which is what gives the reveal its depth.
##
## What this suite exists to catch, in order of how badly each would hurt:
##
##   1. THE CANONICALISATION TRAP. `Edge._init()` SWAPS gu_a and gu_b when the
##      face points NW or NE. So a boolean "side_a" on the mapfile would mean
##      different things for different walls depending on which way the author
##      drew them — correct at the author's end, wrong after a normalisation
##      nobody remembers. The side must be an ABSOLUTE GU CELL, and test 1 is
##      the proof that it survives the swap where a boolean would not.
##   2. Exactly one slice is BORN. Not two-then-destroy-one: a DESTROYED voxel
##      is a hole with soot and a history, an ABSENT one is geometry that never
##      existed, and every census, D24's soot-from-absence derivation and
##      PassageQuery read the difference.
##   3. The consumers tolerate a missing sibling — the shot ladder, the passage
##      query, and the junction resolver, each of which reaches for "the other
##      side" in its own way.

extends SceneTree

const PassageQueryClass = preload("res://godot/scripts/geometry/passage_query.gd")

var passed: int = 0
var failed: int = 0

## LEAK-CYCLE-01: a Voxel does not keep its container alive, so the registries
## these tests build have to outlive the voxels they hand out.
var _fixtures: Array = []


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("MATERIALS M3-2b — HALF-THICKNESS SELFTEST")
	print("=".repeat(70) + "\n")

	test_absolute_cell_survives_the_canonicalisation_swap()
	test_only_one_slice_is_born()
	test_full_thickness_is_unchanged_by_default()
	test_sibling_lookup_returns_null_cleanly()
	test_point_impact_terminates_without_a_sibling()
	test_passage_opens_on_the_only_face()
	test_junction_resolver_survives_a_half_thickness_edge()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ HALF-THICKNESS SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ HALF-THICKNESS SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## An edge drawn "backwards" — the direction that makes _init() swap.
func _swapped_edge(authored: Vector2i, other: Vector2i, storeys: int, material: String) -> Edge:
	return Edge.new(authored, other, storeys, material)


func test_absolute_cell_survives_the_canonicalisation_swap() -> void:
	print("TEST: [1] the authored ABSOLUTE CELL survives the swap a boolean would not")

	## Drawn from (5,5) toward (4,5): the delta points NW, so _init() swaps and
	## gu_a becomes (4,5) — the cell the author did NOT mean.
	var edge := _swapped_edge(Vector2i(5, 5), Vector2i(4, 5), 2, "glass")
	if edge.gu_a == Vector2i(4, 5) and edge.gu_b == Vector2i(5, 5):
		_pass("_init() swapped as expected: gu_a=%s gu_b=%s (author wrote (5,5) first)"
			% [edge.gu_a, edge.gu_b])
	else:
		_fail("fixture does not reproduce the swap: gu_a=%s gu_b=%s" % [edge.gu_a, edge.gu_b])
		print("")
		return

	## THE POINT. The author says "the pane sits on GU (5,5)".
	if not edge.set_occupied_gu(Vector2i(5, 5)):
		_fail("set_occupied_gu((5,5)) rejected a cell that IS gu_b")
	elif edge.occupied_gu() == Vector2i(5, 5):
		_pass("set_occupied_gu((5,5)) → B_ONLY, and occupied_gu() reads back (5,5)")
	else:
		_fail("occupied_gu() = %s, expected (5,5)" % edge.occupied_gu())

	## ...and the counterfactual, which is the whole argument for the design: a
	## mapfile that had said `side_a: true` would have put the pane on (4,5).
	if edge.occupied_sides == Edge.OccupiedSides.B_ONLY:
		_pass("a boolean `side_a` would have resolved to gu_a %s — the WRONG cell, silently"
			% edge.gu_a)
	else:
		_fail("expected B_ONLY, got %d" % edge.occupied_sides)

	## A cell that is neither must change nothing rather than pick a side.
	var stray := _swapped_edge(Vector2i(5, 5), Vector2i(4, 5), 2, "glass")
	var accepted: bool = stray.set_occupied_gu(Vector2i(9, 9))
	if not accepted and stray.occupied_sides == Edge.OccupiedSides.BOTH:
		_pass("a cell belonging to neither side is REFUSED and leaves the edge full thickness")
	else:
		_fail("stray cell was accepted (%s) or changed the edge (%d)"
			% [accepted, stray.occupied_sides])
	print("")


func test_only_one_slice_is_born() -> void:
	print("TEST: [2] exactly ONE slice is created — never two-then-destroy-one")

	var registry := EdgeRegistry.new()
	_fixtures.append(registry)
	var edge := _swapped_edge(Vector2i(5, 5), Vector2i(4, 5), 2, "glass")
	edge.set_occupied_gu(Vector2i(5, 5))
	SliceGenerator.generate([edge], registry)

	var faces: Array = registry.slices_of_edge(edge.id)
	if faces.size() == 1:
		_pass("slices_of_edge() = 1")
	else:
		_fail("expected 1 slice, got %d" % faces.size())
		print("")
		return

	if faces[0].gu_cell == Vector2i(5, 5):
		_pass("and it is on the AUTHORED cell (5,5), not on whichever GU won the sort")
	else:
		_fail("the slice landed on %s, not the authored (5,5)" % faces[0].gu_cell)

	## The absent side must be absent, not present-and-broken.
	if edge.slice_b_id != "" and edge.slice_a_id == "":
		_pass("only slice_b_id is backfilled (%s); slice_a_id stays empty" % edge.slice_b_id)
	else:
		_fail("backrefs wrong: slice_a_id=%r slice_b_id=%r" % [edge.slice_a_id, edge.slice_b_id])

	## Every voxel that DOES exist must be INTACT. This is the assertion that
	## separates "never created" from "created and destroyed", and it is the
	## rule §3.2b says must not be broken.
	var destroyed := 0
	for v in faces[0].voxels:
		if v.damage_state != Voxel.DamageState.INTACT:
			destroyed += 1
	if destroyed == 0:
		_pass("all %d voxels of the surviving face are INTACT — nothing was faked by pre-destroying"
			% faces[0].voxels.size())
	else:
		_fail("%d voxel(s) are already damaged — the absent side was faked, not omitted" % destroyed)
	print("")


func test_full_thickness_is_unchanged_by_default() -> void:
	print("TEST: [3] an edge nobody touched is still full thickness — by construction")
	var registry := EdgeRegistry.new()
	_fixtures.append(registry)
	var edge := Edge.between(Vector2i(0, 0), Vector2i(0, 1), 2, "concrete")
	SliceGenerator.generate([edge], registry)
	var faces: Array = registry.slices_of_edge(edge.id)
	if faces.size() == 2 and not edge.is_half_thickness():
		_pass("2 slices, is_half_thickness() false — the default costs existing maps nothing")
	else:
		_fail("default edge produced %d slice(s), is_half_thickness()=%s"
			% [faces.size(), edge.is_half_thickness()])
	print("")


func test_sibling_lookup_returns_null_cleanly() -> void:
	print("TEST: [4] sibling_slice() returns null CLEANLY — no push_error, no crash")
	var fx := _half_wall("fabric")
	var lone: Slice = fx["registry"].slices_of_edge(fx["edge"].id)[0]
	var sibling = fx["registry"].sibling_slice(lone.id)
	if sibling == null:
		_pass("sibling_slice('%s') → null" % lone.id)
	else:
		_fail("sibling_slice() returned %s for a one-faced edge" % sibling)
	print("")


func test_point_impact_terminates_without_a_sibling() -> void:
	print("TEST: [5] the shot ladder walks depth 0 and stops, instead of following a null")
	## plan_point_impact() steps to the sibling at depth 1. Both of its real
	## call sites were already guarded (§3.2c checked that), so what this pins is
	## that the guard is REACHED and the function returns rather than hanging or
	## faulting on a wall that has no second layer.
	var fx := _half_wall("fabric")
	var lone: Slice = fx["registry"].slices_of_edge(fx["edge"].id)[0]
	var plan: Array = BlastCalculator.plan_point_impact(
		lone, 0, 5.0, fx["registry"], "HALF-THICK-SALT")
	if plan.is_empty():
		_fail("plan_point_impact() produced nothing at punch 5.0 — the shot did not land at all")
		print("")
		return
	var depths: Dictionary = {}
	for e in plan:
		depths[int(e["depth"])] = true
	if not depths.has(1):
		_pass("%d plan entr(ies), all at depth 0 — nothing was written behind a wall that has no behind"
			% plan.size())
	else:
		## str() rather than passing the Array straight in: GDScript's `%` treats
		## an Array as the ARGUMENT LIST, so a 2-key dictionary against one `%s`
		## silently returns the format string unsubstituted — which is exactly
		## what the first red run of this test printed.
		_fail("plan reached depth 1 on a one-faced edge: depths=%s" % str(depths.keys()))
	print("")


func test_passage_opens_on_the_only_face() -> void:
	print("TEST: [6] clearing the ONLY face opens a CROUCH passage — 'both sides' means 'every side that EXISTS'")
	## The payoff, and the reason §3.2b calls this structural rather than lucky:
	## fabric and cardboard open a passage because they are one face thick, not
	## because a blast happened to reach through two.
	var fx := _half_wall("fabric")
	var lone: Slice = fx["registry"].slices_of_edge(fx["edge"].id)[0]

	var before: int = PassageQueryClass.passage_class(fx["edge"], fx["registry"])
	if before == PassageQueryClass.PassageClass.NONE:
		_pass("intact panel → NONE")
	else:
		_fail("intact panel → %s" % PassageQueryClass.class_name_of(before))

	for voxel in lone.voxels:
		if int(floor(float(voxel.level) / float(GeometryCoords.LEVELS_PER_STOREY))) == 0:
			voxel.set_damage(Voxel.DamageState.DESTROYED, false)
	var after: int = PassageQueryClass.passage_class(fx["edge"], fx["registry"])
	if after == PassageQueryClass.PassageClass.CROUCH:
		_pass("storey 0 of the only face cleared → CROUCH")
	else:
		_fail("→ %s, expected CROUCH" % PassageQueryClass.class_name_of(after))
	print("")


func test_junction_resolver_survives_a_half_thickness_edge() -> void:
	print("TEST: [7] JunctionResolver runs on an L where one leg is half thickness")
	## §3.2c's open item, measured rather than assumed: JunctionResolver iterates
	## all_edges() and reads face_a/face_b — it never looks at a slice, so it is
	## SIDE-BLIND and will still emit a full corner column beside a half-thickness
	## panel. What this test pins is that it does not CRASH and that the column
	## count is reported, so whoever decides "skip it or halve it" has the number.
	var registry := EdgeRegistry.new()
	_fixtures.append(registry)
	var full := Edge.between(Vector2i(4, 5), Vector2i(4, 6), 2, "concrete")
	var half := _swapped_edge(Vector2i(5, 5), Vector2i(4, 5), 2, "glass")
	half.set_occupied_gu(Vector2i(5, 5))
	SliceGenerator.generate([full, half], registry)

	var columns: Array = JunctionResolver.resolve(registry)
	_pass("resolve() returned %d column(s) without faulting" % columns.size())

	var half_material := 0
	for column in columns:
		if column.material == "glass":
			half_material += 1
	print("      (of those, %d derive from the half-thickness edge — §3.2c's open"
		% half_material)
	print("       'skip the column or halve it' decision, still the Director's)")
	print("")


## One 2-storey half-thickness edge whose pane sits on the AUTHORED cell (5,5),
## built through the real chain rather than by hand.
func _half_wall(material: String) -> Dictionary:
	var registry := EdgeRegistry.new()
	_fixtures.append(registry)
	var edge := _swapped_edge(Vector2i(5, 5), Vector2i(4, 5), 2, material)
	edge.set_occupied_gu(Vector2i(5, 5))
	SliceGenerator.generate([edge], registry)
	return {"edge": edge, "registry": registry}
