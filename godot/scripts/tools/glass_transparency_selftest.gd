## GLASS_MASTER_PLAN G1 — glass transparency routing selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only glass_transparency
##
## Born as the round-trip proof of G1's routing of glass cells onto their own tile layers (G-D1); what it still pins is
## the glass STATE and grouping those layers used to carry, now asked of the store and the grouper.
##
## R3D-END (END-1): the tests that read which TILE LAYER a glass voxel landed on ([1] Option A's mirror, [1b] the seam
## cull, [2] lazy sublayers, [3] concrete on the opaque layer, [4] a destroyed pane cell erased from its layer) went with
## the 2D board: no tile is written any more, and the glass state lives in the `VoxelStore` (R3D-14). [7] now reads the
## store's pane cells; [12] reads the plan's tile-less entry. END-2 took [11] (per-member pane atoms and the tint in their
## BLUE channel: the 3D board tints each member's material directly). What is left, worst first:
##
##   5. Intact glass dropped from `build_occupancy()` — the light field would stop seeing the pane.
##   7. A G-D9 brick band read as pane glass (or the reverse) — a brick sill that cracks and rains shards.
##   6/10. Panes grouped wrong (`GlassPaneGrouper`) — a plain pane merged into an armoured one defeats the armour.
##   8. Glass occluding (O7) — the cutaway would ghost a see-through pane.
##   9. A pane larger than the fracture sheet accepted silently (G-D23).
##   12. A damaged glass voxel yielding an opaque plan entry (GLASS-OLIVE).

extends SceneTree

const VoxelBoardClass = preload("res://godot/scripts/geometry/voxel_board.gd")
const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")

var passed: int = 0
var failed: int = 0
var _fixtures: Array = []


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS G1 — TRANSPARENCY ROUTING SELFTEST")
	print("=".repeat(70) + "\n")

	test_intact_glass_still_blocks_light()
	test_glass_pane_ids_group_the_surface()
	test_material_bands_route_per_level()
	test_glass_does_not_occlude()
	test_pane_size_ceiling_is_enforced()
	test_two_glass_materials_are_two_panes()
	test_a_damaged_glass_voxel_yields_no_opaque_tile_entry()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ GLASS G1 TRANSPARENCY SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ GLASS G1 TRANSPARENCY SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## A slice on the SW face (varies in x, matching the fixture's `24 + pos`), its 8
## face voxels populated at `level`. `storeys` sets how many level-bands
## `_register_slice()` ensures opaque layers for.
func _make_slice(id: String, material: String, level: int, storeys: int = 1) -> Slice:
	var slice := Slice.new(id, Vector2i(3, 3), Face.SW, "", storeys, material)
	for pos in range(8):
		var v := Voxel.new(Vector2i(24 + pos, 31), level, slice)
		slice.voxels.append(v)
	_fixtures.append(slice)
	return slice


func _fresh_renderer() -> VoxelBoard:
	var r := VoxelBoardClass.new()
	root.add_child(r)
	r.setup(Vector2.ZERO)
	return r


## GLASS G2 — GlassPaneGrouper.assign() stamps a pane_id on every glass slice:
## a block is one pane, contiguous coplanar panels union, a lone panel is its own.
func test_glass_pane_ids_group_the_surface() -> void:
	print("[6] GlassPaneGrouper: block = one pane, coplanar panels union, lone panel alone\n")
	var reg := EdgeRegistry.new()

	## Two SW glass panels adjacent along the SW run axis (x) — one pane.
	var run_a := Slice.new("S_RUN_A", Vector2i(3, 3), Face.SW, "E_RUN_A", 1, "glass")
	var run_b := Slice.new("S_RUN_B", Vector2i(4, 3), Face.SW, "E_RUN_B", 1, "glass")
	## An SW glass panel one step away ACROSS the plane (y) — NOT the same pane.
	var off_plane := Slice.new("S_OFF", Vector2i(3, 4), Face.SW, "E_OFF", 1, "glass")
	## A lone SE glass panel, far away — its own pane.
	var lone := Slice.new("S_LONE", Vector2i(20, 20), Face.SE, "E_LONE", 1, "glass")
	## A concrete slice — must stay blank.
	var wall := Slice.new("S_WALL", Vector2i(3, 3), Face.NW, "E_WALL", 1, "concrete")
	## Faces around a glass block authored as THREE adjacent 1×1 declarations —
	## one pane (flood fill), not three (PLAYGROUND's own convention).
	var blk_a := Slice.new("S_BLK_A", Vector2i(30, 30), Face.SW, "E_BLK_A", 1, "glass")
	var blk_b := Slice.new("S_BLK_B", Vector2i(32, 30), Face.NE, "E_BLK_B", 1, "glass")
	for s in [run_a, run_b, off_plane, lone, wall, blk_a, blk_b]:
		reg._slices[s.id] = s
	_fixtures.append_array([run_a, run_b, off_plane, lone, wall, blk_a, blk_b])

	var blocks: Array = [
		{"gu_cell": Vector2i(30, 30), "size": Vector2i(1, 1), "storeys": 1, "material": "glass"},
		{"gu_cell": Vector2i(31, 30), "size": Vector2i(1, 1), "storeys": 1, "material": "glass"},
		{"gu_cell": Vector2i(32, 30), "size": Vector2i(1, 1), "storeys": 1, "material": "glass"},
	]
	GlassPaneGrouper.assign(reg, blocks)

	if run_a.pane_id != "" and run_a.pane_id == run_b.pane_id:
		_pass("the two coplanar-adjacent SW panels share a pane_id (%s)" % run_a.pane_id)
	else:
		_fail("coplanar SW panels not unioned: %s vs %s" % [run_a.pane_id, run_b.pane_id])

	if off_plane.pane_id != "" and off_plane.pane_id != run_a.pane_id:
		_pass("the across-the-plane SW panel is a different pane")
	else:
		_fail("across-the-plane panel wrongly joined: %s" % off_plane.pane_id)

	if lone.pane_id != "" and lone.pane_id != run_a.pane_id and lone.pane_id != off_plane.pane_id:
		_pass("the lone SE panel is its own pane (%s)" % lone.pane_id)
	else:
		_fail("lone panel pane_id wrong: %s" % lone.pane_id)

	if wall.pane_id == "":
		_pass("the concrete slice keeps a blank pane_id")
	else:
		_fail("concrete slice got a pane_id: %s" % wall.pane_id)

	if blk_a.pane_id.begins_with("PANE_BLOCK_") and blk_a.pane_id == blk_b.pane_id:
		_pass("a block spelled as 3 adjacent 1x1 declarations is one pane (%s)" % blk_a.pane_id)
	else:
		_fail("glass block faces not one pane: %s vs %s" % [blk_a.pane_id, blk_b.pane_id])

	print("")


## GLASS G-D9 (GLASS_MASTER_PLAN §9) — a MULTI-MATERIAL SLICE: base glass with a
## brick sill (rel 0-1) and head (rel 14-15) over 2 storeys. The brick bands must
## land on the OPAQUE layer and the glass middle on the pane sublayers, from the
## SAME slice, keyed by `material_at(rel_level)`.
func test_material_bands_route_per_level() -> void:
	print("[7] G-D9: a brick-capped glass window routes brick opaque, glass to the pane\n")

	## The accessor itself.
	var s := Slice.new("S_BANDS", Vector2i(3, 3), Face.SW, "E_BANDS", 2, "glass")
	s.material_bands = {0: "brick", 1: "brick", 14: "brick", 15: "brick"}
	var acc_ok := s.material_at(0) == "brick" and s.material_at(1) == "brick" \
		and s.material_at(7) == "glass" and s.material_at(14) == "brick" and s.material_at(15) == "brick"
	if acc_ok:
		_pass("Slice.material_at(): brick at the sill/head levels, glass between")
	else:
		_fail("Slice.material_at() wrong: 0=%s 7=%s 15=%s" % [s.material_at(0), s.material_at(7), s.material_at(15)])

	## The store the board draws: which of the SAME slice's voxels are glass PANE cells, keyed by `material_at(rel_level)`.
	## R3D-END: until then this read which TILE layer each level landed on (opaque vs the glass sublayers).
	var base: int = GeometryCoords.PLAYABLE_LEVEL
	var slice := Slice.new("SLICE_BANDS_RENDER", Vector2i(3, 3), Face.SW, "", 2, "glass")
	slice.material_bands = {0: "brick", 1: "brick", 14: "brick", 15: "brick"}
	for lvl_off in range(16):
		for pos in range(8):
			slice.voxels.append(Voxel.new(Vector2i(24 + pos, 31), base + lvl_off, slice))
	_fixtures.append(slice)
	var registry := EdgeRegistry.new()
	registry.register_slice(slice)
	var store: VoxelStore = VoxelStore.build(registry, SlabRegistry.new(), [])

	for probe: Array in [[0, "brick sill"], [7, "glass middle"], [15, "brick head"]]:
		var rel: int = int(probe[0])
		var cells: int = 0
		var panes: int = 0
		for pos in range(8):
			if store.has_cell(24 + pos, 31, base + rel):
				cells += 1
			if store.has_glass_pane(24 + pos, 31, base + rel):
				panes += 1
		var want_panes: int = 8 if rel == 7 else 0
		if cells == 8 and panes == want_panes:
			_pass("the %s (rel %d) holds 8 cells, %d of them glass pane cells" % [probe[1], rel, panes])
		else:
			_fail("%s wrong: %d cells, %d pane cells (expected 8, %d)" % [probe[1], cells, panes, want_panes])
	print("")


## GLASS — OcclusionSet policy O7 (Director 2026-08-31): a glass slice must
## contribute NOTHING to occlusion. A glass pane is see-through, so the agent
## behind it is already visible; and a glass pane is drawn as a pane, not as a
## wall the cutaway could ghost — the wireframe would draw over a still-solid pane. Control run first: the SAME cells as concrete DO occlude, so an empty
## glass result is the filter working, not a broken fixture.
func test_glass_does_not_occlude() -> void:
	print("[8] O7: a glass slice contributes nothing to OcclusionSet\n")
	var OcclusionSetMod = preload("res://godot/scripts/systems/occlusion_set.gd")
	## Agent at gu (5,5) → voxel centre (44,44), depth 88. Occluder cells sit at
	## depth 92-96 (camera side) and levels PLAYABLE_LEVEL .. +5 (a real wall span).
	var agent_cell := Vector2i(5, 5)
	var cells := [Vector2i(46, 46), Vector2i(47, 46), Vector2i(46, 47), Vector2i(48, 48)]

	var occ_c = OcclusionSetMod.new()
	occ_c.recompute(agent_cell, _occ_slices(cells, "concrete"), Vector2i(100, 100))
	var n_concrete: int = occ_c.get_occluded_cells().size()
	if n_concrete > 0:
		_pass("control: %d concrete cells occlude the agent" % n_concrete)
	else:
		_fail("control produced ZERO occlusion — fixture is wrong, the glass result proves nothing")

	var occ_g = OcclusionSetMod.new()
	occ_g.recompute(agent_cell, _occ_slices(cells, "glass"), Vector2i(100, 100))
	var n_glass: int = occ_g.get_occluded_cells().size()
	if n_glass == 0:
		_pass("the SAME cells as glass produce ZERO occluded cells (O7)")
	else:
		_fail("glass still occludes %d cells — the O7 filter is not applied" % n_glass)

	## A G-D9 brick-capped window (base material glass) is excluded whole.
	var banded := _occ_slices(cells, "glass")
	for s in banded:
		s.material_bands = {0: "brick", 5: "brick"}
	var occ_b = OcclusionSetMod.new()
	occ_b.recompute(agent_cell, banded, Vector2i(100, 100))
	if occ_b.get_occluded_cells().size() == 0:
		_pass("a base-glass banded window (brick sill/head) is excluded too")
	else:
		_fail("a base-glass banded window still occludes %d cells" % occ_b.get_occluded_cells().size())
	print("")


## Occluder fixture: one synthetic edge per cell, a real wall level span
## (PLAYABLE_LEVEL .. +5 — the bottom BASE_VISIBLE_LEVELS never ghost, so it must
## be taller than that), material configurable.
func _occ_slices(cells: Array, material: String) -> Array:
	var out: Array = []
	for cell: Vector2i in cells:
		var s := Slice.new(
			"OCC_S_%d_%d" % [cell.x, cell.y],
			GeometryCoords.voxel_to_gu(cell), 0,
			"OCC_E_%d_%d" % [cell.x, cell.y], 1, material)
		for lvl in range(6):
			s.voxels.append(Voxel.new(cell, GeometryCoords.PLAYABLE_LEVEL + lvl, s))
		_fixtures.append(s)
		out.append(s)
	return out


func test_intact_glass_still_blocks_light() -> void:
	print("[5] build_occupancy() still reports intact glass as solid\n")
	var r := _fresh_renderer()
	var level: int = GeometryCoords.PLAYABLE_LEVEL
	var registry := EdgeRegistry.new()
	registry.register_slice(_make_slice("SLICE_GLASS_OCC", "glass", level))
	r.register_geometry(registry)
	## RENDER3D R3D-2: build_occupancy() reads VoxelStore.active alone now — needs a
	## store built over this fixture's registry.
	VoxelStore.active = VoxelStore.build(registry, SlabRegistry.new(), [])

	var occ: Dictionary = r.build_occupancy()
	var at_level: Dictionary = occ.get(level, {})
	if at_level.size() == 8:
		_pass("build_occupancy() reports 8 solid cells at the glass level")
	else:
		_fail("build_occupancy() reports %d cells at the glass level, expected 8" % at_level.size())
	r.queue_free()
	VoxelStore.active = null
	print("")


## GLASS G-D23 — A PANE HAS A MAXIMUM SIZE, and something has to hold the map to
## it. Director, 2026-09-01: *"convencionamos que toda vidraça vai ter um tamanho
## máximo […] Precisando, usa-se um frame divisório e começa outra vidraça."*
##
## The bound is DERIVED, not chosen: the fracture sheet is
## a 64-column x 32-row window (`_compute_facade_key()`'s, on the 2D board) and G-D23 clamps it at
## the edge instead of mirroring, so a pane wider than the sheet has a far half
## that can never crack — silently, which is the failure mode this project keeps
## paying for. `GlassPaneGrouper` unions panels by coplanar adjacency with no size
## bound at all, so a long run of `panels` entries becomes ONE pane and nothing
## says a word.
##
## Asserted through `oversize_panes()` rather than by reading stderr: a selftest
## cannot intercept `push_error`, and a rule observable only in a log is a rule
## nothing gates.
func test_pane_size_ceiling_is_enforced() -> void:
	print("[9] G-D23: a pane larger than the fracture sheet is reported, not accepted\n")

	var limit_gu: int = GlassPaneGrouper.MAX_PANE_RUN_GU
	var limit_st: int = GlassPaneGrouper.MAX_PANE_STOREYS

	## EXACTLY at the ceiling — must pass. A test that only proves the rejection
	## half would also pass if the rule rejected everything.
	var at_limit: Array = _panel_run(0, limit_gu - 1, limit_st, "AT")
	var at_bad: Array = GlassPaneGrouper.oversize_panes(at_limit)
	if at_bad.is_empty():
		_pass("a pane at exactly %d GU x %d storeys is accepted" % [limit_gu, limit_st])
	else:
		_fail("the pane at the ceiling was rejected: %s" % [at_bad])

	## One GU too wide.
	var wide: Array = _panel_run(0, limit_gu, limit_st, "WIDE")
	var wide_bad: Array = GlassPaneGrouper.oversize_panes(wide)
	if wide_bad.size() == 1 and int(wide_bad[0]["run_gu"]) == limit_gu + 1:
		_pass("a %d GU run is reported (run_gu=%d)" % [limit_gu + 1, wide_bad[0]["run_gu"]])
	else:
		_fail("expected one oversize pane at %d GU, got %s" % [limit_gu + 1, wide_bad])

	## One storey too tall.
	var tall: Array = _panel_run(0, limit_gu - 1, limit_st + 1, "TALL")
	var tall_bad: Array = GlassPaneGrouper.oversize_panes(tall)
	if tall_bad.size() == 1 and int(tall_bad[0]["storeys"]) == limit_st + 1:
		_pass("a %d-storey pane is reported (storeys=%d)" % [limit_st + 1, tall_bad[0]["storeys"]])
	else:
		_fail("expected one oversize pane at %d storeys, got %s" % [limit_st + 1, tall_bad])

	## THE DIVIDER IS THE FIX, and it has to actually work. ⚠️ A G-D9 `bands` entry
	## does NOT split a pane — a banded window is still base-glass and the
	## union-find joins it to its neighbours regardless (found on the real map:
	## widening GLASS's big pane bridged the gap to the banded window and the two
	## merged into one 12 GU pane). A real divider is a NON-GLASS panel or a gap,
	## which is what the two separated runs below model.
	var left: Array = _panel_run(0, limit_gu - 1, limit_st, "L")
	var right: Array = _panel_run(20, 20 + limit_gu - 1, limit_st, "R")
	var split_bad: Array = GlassPaneGrouper.oversize_panes(left + right)
	if split_bad.is_empty():
		_pass("two %d GU panes either side of a non-glass divider both pass" % limit_gu)
	else:
		_fail("the split pair was rejected: %s" % [split_bad])
	print("")


## A run of SW-face panel slices sharing one pane_id, `gu_lo..gu_hi` along X at
## y=3, `storeys` tall. Voxels are not needed — `oversize_panes()` measures the
## pane from `gu_cell`, `start_storey` and `storey_count`, which is what the real
## grouper has at the moment it runs.
func _panel_run(gu_lo: int, gu_hi: int, storeys: int, tag: String) -> Array:
	var out: Array = []
	for gx in range(gu_lo, gu_hi + 1):
		var sl := Slice.new("S_%s_%d" % [tag, gx], Vector2i(gx, 3), Face.SW,
			"E_%s_%d" % [tag, gx], storeys, "glass")
		sl.pane_id = "PANE_%s" % tag
		out.append(sl)
	return out


## G-D16 / V-B — TWO GLASS MATERIALS ARE TWO PANES.
##
## The union-find matched on face and adjacency and never on material, which was
## invisible while glass was a single id. The moment it became a family a plain
## pane touching an armoured one would have merged into ONE pane carrying two
## resistances and two behaviour classes — and `plan_pane_shatter` would then
## flood a won roll straight out of the ordinary glass and through the armour,
## defeating it with no error and nothing on screen to explain why.
##
## The banded case is pinned in the SAME test on purpose, because it is the
## distinction that makes the rule right rather than merely strict: a G-D9 window
## is BASE glass with brick bands, so it still joins its plain-glass neighbours.
## Base material, not per-level material — which is exactly why §G-D23 says a
## `bands` entry is not a divider.
func test_two_glass_materials_are_two_panes() -> void:
	print("[10] G-D16: two glass MATERIALS never share a pane; a banded one still joins\n")
	var reg := EdgeRegistry.new()
	## Four SW panels in one adjacent run: glass, glass, glass_armored, glass.
	## The armoured one must split the run into two panes AND be alone in its own.
	var a := Slice.new("V_A", Vector2i(3, 7), Face.SW, "V_EA", 1, "glass")
	var b := Slice.new("V_B", Vector2i(4, 7), Face.SW, "V_EB", 1, "glass")
	var armored := Slice.new("V_ARM", Vector2i(5, 7), Face.SW, "V_EARM", 1, "glass_armored")
	var d := Slice.new("V_D", Vector2i(6, 7), Face.SW, "V_ED", 1, "glass")
	## A BANDED glass panel adjacent to `a` — base glass, so it must still join.
	var banded := Slice.new("V_BAND", Vector2i(2, 7), Face.SW, "V_EBAND", 1, "glass")
	banded.material_bands = {0: "brick", 1: "brick"}
	for sl in [a, b, armored, d, banded]:
		reg._slices[sl.id] = sl
	_fixtures.append_array([a, b, armored, d, banded])
	GlassPaneGrouper.assign(reg, [])

	if armored.pane_id != "" and armored.pane_id != a.pane_id and armored.pane_id != d.pane_id:
		_pass("the glass_armored panel is its own pane (%s), splitting the run" % armored.pane_id)
	else:
		_fail("glass_armored merged with plain glass: armored=%s a=%s d=%s"
			% [armored.pane_id, a.pane_id, d.pane_id])

	if a.pane_id == b.pane_id and a.pane_id != "":
		_pass("the two plain-glass neighbours still share a pane (%s)" % a.pane_id)
	else:
		_fail("plain glass neighbours no longer union: %s vs %s" % [a.pane_id, b.pane_id])

	if d.pane_id != "" and d.pane_id != a.pane_id:
		_pass("the glass beyond the armoured panel is a SEPARATE pane (%s) — the armour divides the run"
			% d.pane_id)
	else:
		_fail("the run was not divided: d=%s a=%s" % [d.pane_id, a.pane_id])

	if banded.pane_id == a.pane_id:
		_pass("a G-D9 banded window is BASE glass and still joins its neighbours — a `bands` entry is not a divider (G-D23)")
	else:
		_fail("the banded panel stopped joining: banded=%s a=%s" % [banded.pane_id, a.pane_id])
	print("")


## ── [12] GLASS-OLIVE (2026-09-06) — THE RESOLVE-ONLY SEAM NAMES ITS LAYER ────
##
## The plan-level half of the resolve-only seam: DetonationPlanBuilder's per-voxel entry for a damaged voxel. A GLASS-family
## container yields NO entry at all (a cracked pane's whole visual is the craze web, G-D27), and a concrete control still
## yields one. (R3D-END END-4: the renderer-level half — `_set_voxel_cell(apply = false)` returning no atom for glass — went with
## the placement.)
##
## The failure this guards was silent in both directions (GLASS-OLIVE, 2026-09-06): a glass atom stamped on the opaque layer
## rendered as a flat YELLOW rectangle with no push_error anywhere, so it is asserted as an identity on both sides.
func test_a_damaged_glass_voxel_yields_no_opaque_tile_entry() -> void:
	print("[12] a CRACKED glass voxel resolves to NO opaque tile (GLASS-OLIVE)\n")
	var r := _fresh_renderer()
	var level: int = GeometryCoords.PLAYABLE_LEVEL
	var registry := EdgeRegistry.new()
	var glass_slice := _make_slice("SLICE_GLASS_D", "glass", level)
	var concrete_slice := _make_slice("SLICE_CONCRETE_D", "concrete", level)
	registry.register_slice(glass_slice)
	registry.register_slice(concrete_slice)
	r.register_geometry(registry)

	## The consumer: DetonationPlanBuilder's per-voxel entry. R3D-END: no tile is resolved any more, so the entry is the
	## placeholder that carries the voxel key; a GLASS-family container still yields NO entry at all (a cracked pane's
	## whole visual is the craze web, G-D27), and the concrete control still yields one.
	var glass_entry: Dictionary = DetonationPlanBuilderClass._resolve_damaged_tile_or_none(glass_slice)
	if glass_entry.is_empty():
		_pass("a damaged glass voxel yields NO opaque entry")
	else:
		_fail("a damaged glass voxel yielded an opaque entry %s" % [glass_entry])

	var concrete_entry: Dictionary = DetonationPlanBuilderClass._resolve_damaged_tile_or_none(concrete_slice)
	if not concrete_entry.is_empty() and bool(concrete_entry.get("no_tile", false)):
		_pass("the concrete control still yields its (tile-less) entry")
	else:
		_fail("the concrete control yielded %s — the guard is eating non-glass damage" % [concrete_entry])

	r.queue_free()
	print("")
