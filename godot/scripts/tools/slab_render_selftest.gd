## DESTRUCTION_MASTER_PLAN Part 2 — consumer wave selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/slab_render_selftest.gd
##
## Proves the D2/D4 core (EarthVariantSelector, landed in isolation) actually
## renders correctly once something consumes it: SlabGenerator builds real
## Voxels, VoxelRenderer.render_slab() places real TileMapLayer cells, and the
## cell each voxel actually got matches what the pure hash function predicted
## — the same round-trip discipline OCC-02 used for ghost restore.

extends SceneTree

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION Part 2 — Slab render consumer SELFTEST")
	print("=".repeat(70) + "\n")

	test_slab_generator_produces_64_voxels()
	test_render_slab_places_cells_matching_the_hash()
	test_render_slab_idempotent()
	test_d13_two_layer_floor_independent_containers()
	## FLOOR-DENT-01 (2026-08-01) — a dented floor voxel must place the carved
	## asset, on the plain-earth AND the zoned branch.
	test_floor_dent_places_carved_asset_on_both_branches()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ SLAB RENDER SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ SLAB RENDER SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func test_slab_generator_produces_64_voxels() -> void:
	print("[1] SlabGenerator.generate() — 64 voxels, correct grid positions\n")

	var registry := SlabRegistry.new()
	var gu := Vector2i(2, 2)
	var slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, 0, "earth", registry)

	if slab.voxels.size() == 64:
		_pass("Generated Slab has 64 voxels (VOXELS_PER_UNIT_AXIS^2)")
	else:
		_fail("Expected 64 voxels, got %d" % slab.voxels.size())

	var expected_positions: Array = GeometryCoordsClass.gu_voxels(gu)
	var actual_positions: Array = []
	for voxel in slab.voxels:
		actual_positions.append(voxel.grid_pos)

	var positions_match := true
	for pos in expected_positions:
		if not actual_positions.has(pos):
			positions_match = false
	if positions_match:
		_pass("All 64 voxel grid_pos match GeometryCoords.gu_voxels(gu) exactly")
	else:
		_fail("Voxel positions don't match gu_voxels(gu)")

	if registry.get_slab(slab.id) == slab:
		_pass("Slab registered in SlabRegistry under its own id")
	else:
		_fail("Slab not retrievable from registry by id")

	print("")


## The real round-trip: place cells for a real Slab, then read back each
## cell's source_id from the TileMapLayer and confirm it names the SAME
## material EarthVariantSelector.variant_for() predicts for that voxel — not
## a tautological check against the writer's own in-memory choice, an
## independent re-derivation compared against what actually landed on the layer.
func test_render_slab_places_cells_matching_the_hash() -> void:
	print("[2] render_slab() — every placed cell matches an independently re-derived hash\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var registry := SlabRegistry.new()
	var gu := Vector2i(0, 0)
	var slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, 0, "earth", registry)
	renderer.render_slab(slab)

	var layer: TileMapLayer = renderer.get_layer(0)
	if layer == null:
		_fail("Layer 0 was not created by render_slab()")
		renderer.queue_free()
		print("")
		return

	var mismatches := 0
	var checked := 0
	for voxel in slab.voxels:
		checked += 1
		var expected_variant: int = EarthVariantSelector.variant_for(voxel.grid_pos, voxel.level)
		var expected_source_id: int = VoxelRendererClass.MATERIALS.find("earth_%d" % expected_variant)
		var actual_source_id: int = layer.get_cell_source_id(voxel.grid_pos)
		if actual_source_id != expected_source_id:
			mismatches += 1

	if checked == 64 and mismatches == 0:
		_pass("64/64 placed cells' source_id match an independently re-derived EarthVariantSelector.variant_for() call")
	else:
		_fail("%d/%d cells mismatched the independently re-derived variant" % [mismatches, checked])

	renderer.queue_free()
	print("")


## D5's invariant, exercised at the render layer: calling render_slab() again
## must place the exact same cells — nothing to pop, nothing to re-roll.
func test_render_slab_idempotent() -> void:
	print("[3] render_slab() is idempotent — same Slab renders identically twice\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var registry := SlabRegistry.new()
	var slab := SlabGenerator.generate(Vector2i(1, 0), Slab.Role.FLOOR, 0, "earth", registry)

	renderer.render_slab(slab)
	var layer: TileMapLayer = renderer.get_layer(0)
	var first_pass: Array = []
	for voxel in slab.voxels:
		first_pass.append(layer.get_cell_source_id(voxel.grid_pos))

	renderer.render_slab(slab)
	var second_pass: Array = []
	for voxel in slab.voxels:
		second_pass.append(layer.get_cell_source_id(voxel.grid_pos))

	if first_pass == second_pass:
		_pass("Two render_slab() calls on the same Slab produced identical source_ids for all 64 cells")
	else:
		_fail("render_slab() is not idempotent — output changed on second call")

	renderer.queue_free()
	print("")


## D13: floor is TWO Slabs at the same gu_cell (destructible top, fixed
## bottom) — not one. Prove they're genuinely independent containers: marking
## the top dirty must never touch the bottom's dirty_count, matching the same
## cross-contamination check Part 1 already proved for Slice vs. Slab.
func test_d13_two_layer_floor_independent_containers() -> void:
	print("[4] D13 — destructible top Slab and fixed bottom Slab are independent containers\n")

	var registry := SlabRegistry.new()
	var gu := Vector2i(4, 4)
	var top_slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, 1, "earth", registry)   # destructible level
	var bottom_slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, 0, "earth", registry) # fixed bedrock level

	if top_slab.id != bottom_slab.id:
		_pass("Top and bottom Slabs at the same GU have distinct ids (%s vs %s)" % [top_slab.id, bottom_slab.id])
	else:
		_fail("Top and bottom Slabs collided on the same id")

	top_slab.voxels[0].set_damage(Voxel.DamageState.DESTROYED)

	if top_slab.dirty_count == 1 and bottom_slab.dirty_count == 0:
		_pass("Damaging the destructible (top) Slab left the fixed (bottom) Slab's dirty_count at 0")
	else:
		_fail("Cross-contamination: top.dirty_count=%d, bottom.dirty_count=%d" % [top_slab.dirty_count, bottom_slab.dirty_count])

	if registry.dirty_slabs().size() == 1 and registry.dirty_slabs()[0] == top_slab:
		_pass("SlabRegistry.dirty_slabs() reports only the top slab, never the fixed bedrock")
	else:
		_fail("dirty_slabs() reported the wrong set: %s" % [registry.dirty_slabs()])

	print("")


## FLOOR-DENT-01 — the render-side half, at source_id level rather than by
## eye. A DENTED floor voxel must place the carved-TOP asset through
## process_dirty_slabs(), and the check that matters is the ZONED branch: a
## zoned floor composing "ground_concrete_blast_dented_top" would miss
## MATERIALS, and _set_voxel_cell()'s MATERIALS.find() returns -1 → source_id
## 0 → the voxel silently repaints as flat "concrete" in the middle of the
## crater rim. Asserting "not source_id 0" alone would be a weak test (0 is
## also a legitimate id), so both branches are compared against the
## independently re-derived MATERIALS.find("earth_blast_dented_top").
func test_floor_dent_places_carved_asset_on_both_branches() -> void:
	print("[5] FLOOR-DENT — a dented floor voxel places the carved-TOP asset (both branches)\n")

	## D32 (2026-08-02): the carved floor asset is now one of three decal
	## composites, so the name carries the variant index. The assertion this
	## test exists for is UNCHANGED — a dented floor voxel must not fall
	## through to flat concrete — and the variant axis is asserted on top of
	## it: each variant must place its own render, proving the value survives
	## Voxel.damage_variant → damage_variant_material() rather than being
	## quietly dropped somewhere in between.
	##
	## D33 Part 4b (2026-08-03) changed WHERE this fixture's undented,
	## unstubbed renderer actually resolves the dent: no baked atom is ever
	## registered here (no _stub_baked_floor()), so the baked branch always
	## missed and every variant used to fall all the way through to its own
	## dedicated composites/ source_id (136/137/138) — three distinct SOURCE
	## IDS was a valid proxy for "three distinct renders" in that world.
	## _composite_generic_floor_sunk() now catches it first instead, using the
	## SAME dynamic-page architecture Part 1 already built for the baked
	## branches: multiple distinct composites share ONE page/source_id, at
	## different atlas_coords (measured: three variants placed source_id 139
	## at atlas_coords (0,0)/(1,0)/(2,0) — never three different source ids).
	## So (source_id, atlas_coords) is the pair that actually identifies a
	## placed tile now, matching how TileMapLayer itself distinguishes cells;
	## checking source_id alone stopped being a valid uniqueness proof the
	## moment the generic path got dynamic paging too.
	var concrete_id: int = VoxelRendererClass.MATERIALS.find("concrete")
	var generic_ids: Array[int] = []
	for variant in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
		generic_ids.append(VoxelRendererClass.MATERIALS.find("earth_blast_dented_top_%d" % variant))

	## material "earth" → the EarthVariantSelector branch;
	## "concrete" → the zoned/baked branch (bake enabled below).
	for material in ["earth", "concrete"]:
		var renderer := VoxelRendererClass.new()
		root.add_child(renderer)
		renderer.setup(Vector2.ZERO)

		var registry := SlabRegistry.new()
		var slab := SlabGenerator.generate(Vector2i(0, 0), Slab.Role.FLOOR, 0, material, registry)
		renderer.render_slab(slab)

		var placed: Array[Vector3i] = []   # (source_id, atlas_x, atlas_y) per variant
		for variant in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
			var target: Voxel = slab.voxels[variant]
			target.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, variant)
			renderer.process_dirty_slabs(registry)

			var layer: TileMapLayer = renderer.get_layer(0)
			var actual_id: int = layer.get_cell_source_id(target.grid_pos)
			var actual_coords: Vector2i = layer.get_cell_atlas_coords(target.grid_pos)
			placed.append(Vector3i(actual_id, actual_coords.x, actual_coords.y))
			if actual_id == concrete_id:
				_fail("%s: dented voxel fell through to source_id %d (concrete) — the silent MATERIALS.find() miss"
					% [material, actual_id])
			elif actual_id == -1:
				_fail("%s: dented voxel variant %d placed no cell at all" % [material, variant])
			else:
				_pass("%s: dented voxel variant %d placed source_id %d atlas_coords %s (not concrete, not unplaced)"
					% [material, variant, actual_id, actual_coords])

		## Three distinct (source_id, atlas_coords) pairs, not three copies of
		## one — a variant that is read but ignored downstream would still
		## pass every check above.
		var distinct: Dictionary = {}
		for tile in placed:
			distinct[tile] = true
		if distinct.size() == VoxelRendererClass.IMPACT_DECAL_VARIANTS:
			_pass("%s: the %d variants placed %d distinct (source_id, atlas_coords) tiles"
				% [material, VoxelRendererClass.IMPACT_DECAL_VARIANTS, distinct.size()])
		else:
			_fail("%s: variants collapsed to %d distinct tile(s) — damage_variant is not reaching the renderer"
				% [material, distinct.size()])

		## A neighbouring INTACT voxel must be untouched by the dent path. Only
		## "is not concrete and not one of the dented tiles just placed" is
		## asserted: what an intact ZONED voxel resolves to depends on bake
		## pages this synthetic fixture never registers, so its exact id here
		## is a fixture artefact, not a claim about real rendering.
		## Index past the voxels the variant loop above damaged — voxels[0..2]
		## are all DENTED now, so the old voxels[1] would no longer be intact.
		var neighbour: Voxel = slab.voxels[VoxelRendererClass.IMPACT_DECAL_VARIANTS]
		var neighbour_layer: TileMapLayer = renderer.get_layer(0)
		var neighbour_id: int = neighbour_layer.get_cell_source_id(neighbour.grid_pos)
		var neighbour_coords: Vector2i = neighbour_layer.get_cell_atlas_coords(neighbour.grid_pos)
		var neighbour_tile := Vector3i(neighbour_id, neighbour_coords.x, neighbour_coords.y)
		if not distinct.has(neighbour_tile) and not generic_ids.has(neighbour_id):
			_pass("%s: the INTACT neighbour was not painted with the carved asset" % material)
		else:
			_fail("%s: an INTACT neighbour was also painted with the carved asset" % material)

		renderer.queue_free()
	print("")
