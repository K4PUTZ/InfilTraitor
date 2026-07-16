## DESTRUCTION D1-ROOF — real map roof integration selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/roof_integration_selftest.gd
##
## Drives the REAL RoomBuilder.build_from_layout() against the REAL PLAYGROUND
## map (FileMapSource + MapCompiler, the exact path room.gd::load_map() uses)
## and confirms real roofs land above the real concrete/stone/wood/metal
## blocks it actually contains (maps/PLAYGROUND.map.json's "blocks" section).

extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

class MinimalRoom extends Node:
	var _edge_registry
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	var map_id: String = "TEST"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D1-ROOF — Real map roof integration SELFTEST (PLAYGROUND)")
	print("=".repeat(70) + "\n")

	## ROOF-BAKE-01: this suite verifies roof GEOMETRY truth (registry, borders,
	## adjacency, materials) via generic material source ids. With bake enabled,
	## ceiling cells now legitimately carry BAKED source ids instead — the baked
	## path has its own end-to-end suite (roof_bake_selftest.gd), so bake is
	## explicitly off here to keep these assertions meaning what they say.
	var bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var bake_was_enabled: bool = bake_config.enabled
	bake_config.enabled = false

	test_real_playground_blocks_get_real_roofs()

	bake_config.enabled = bake_was_enabled

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ ROOF INTEGRATION SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ ROOF INTEGRATION SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func test_real_playground_blocks_get_real_roofs() -> void:
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("PLAYGROUND")
	if spec.is_empty():
		_fail("FileMapSource.get_runtime_spec('PLAYGROUND') returned empty")
		return

	var raw_blocks: Array = spec.get("blocks", [])
	print("  PLAYGROUND spec has %d raw block declarations\n" % raw_blocks.size())
	if raw_blocks.is_empty():
		_fail("PLAYGROUND spec has no 'blocks' section — nothing to verify roofs against")
		return

	var layout: Dictionary = MapCompilerClass.compile(spec)
	if layout.is_empty():
		_fail("MapCompiler.compile() on the real PLAYGROUND spec returned empty")
		return

	var solid_block_instances: Array = layout.get("solid_block_instances", [])
	if solid_block_instances.size() == raw_blocks.size():
		_pass("MapCompiler forwarded exactly %d solid_block_instances, matching the raw spec count" % solid_block_instances.size())
	else:
		_fail("solid_block_instances has %d entries, spec declared %d" % [solid_block_instances.size(), raw_blocks.size()])

	var room_size: Vector2i = layout.get("size", Vector2i.ZERO)

	var room := MinimalRoom.new()
	root.add_child(room)

	var floor_tileset: TileSet = load("res://godot/resources/tilesets/tileset_blocks.tres")
	var floor_layer := TileMapLayer.new()
	var structure_layer := TileMapLayer.new()
	floor_layer.tile_set = floor_tileset
	structure_layer.tile_set = floor_tileset
	room.add_child(floor_layer)
	room.add_child(structure_layer)

	var voxel_renderer := VoxelRendererClass.new()
	room.add_child(voxel_renderer)
	voxel_renderer.setup(Vector2.ZERO)
	room._voxel_renderer = voxel_renderer

	var builder := RoomBuilderClass.new(room)
	builder.setup(floor_layer, structure_layer, TileSet.new())
	builder.build_registry(floor_tileset)

	var t_start := Time.get_ticks_usec()
	builder.build_from_layout(layout, room_size)
	var build_ms := (Time.get_ticks_usec() - t_start) / 1000.0
	print("\n  build_from_layout() wall time: %.2f ms\n" % build_ms)

	## Criterion: every real block instance has a real, independently
	## re-derived roof — correct GU, correct level (storeys * LEVELS_PER_STOREY),
	## correct material, and it is a genuine Slab (Role.CEILING) in the registry,
	## not just a rendered cell.
	## Map-wide roofed-GU set — mirrors room_builder.gd's own adjacency
	## computation exactly, so this test's expectations track the real fix
	## (border suppressed on any side with a real neighbour, from ANY
	## solid_block_instances entry) instead of assuming every 1x1 block gets
	## a full untouched border, which stopped being true the moment the
	## adjacency fix landed (PLAYGROUND's 5-in-a-row same-material test
	## blocks are real neighbours of each other).
	var roofed_gu_cells: Dictionary = {}
	for b in solid_block_instances:
		var b_gu: Vector2i = b.get("gu_cell", Vector2i.ZERO)
		var b_size: Vector2i = b.get("size", Vector2i.ONE)
		for ox in range(b_size.x):
			for oy in range(b_size.y):
				roofed_gu_cells[b_gu + Vector2i(ox, oy)] = true

	var checked_blocks := 0
	var geometry_mismatches := 0
	var registry_mismatches := 0
	var material_mismatches := 0
	var border_size_mismatches := 0
	var border_coverage_mismatches := 0
	var no_self_overlap_between_neighbours := true

	for block_instance in solid_block_instances:
		var block_gu_base: Vector2i = block_instance.get("gu_cell", Vector2i.ZERO)
		var block_size: Vector2i = block_instance.get("size", Vector2i.ONE)
		var block_storeys: int = int(block_instance.get("storeys", 1))
		var block_material: String = String(block_instance.get("material", "concrete"))
		var roof_base_level: int = block_storeys * GeometryCoordsClass.LEVELS_PER_STOREY
		var expected_source_id: int = VoxelRendererClass.MATERIALS.find(block_material)

		for rx in range(block_size.x):
			for ry in range(block_size.y):
				checked_blocks += 1
				var roof_gu := block_gu_base + Vector2i(rx, ry)
				var slab_id := "SLAB_%d_%d_%s_%d" % [roof_gu.x, roof_gu.y, Slab.role_name(Slab.Role.CEILING), roof_base_level]
				var registered_slab: Slab = room._slab_registry.get_slab(slab_id)
				if registered_slab == null:
					registry_mismatches += 1
					continue
				if registered_slab.material != block_material:
					material_mismatches += 1

				var layer: TileMapLayer = voxel_renderer.get_layer(roof_base_level)
				if layer == null:
					geometry_mismatches += 1
					continue
				for voxel_pos in GeometryCoordsClass.gu_voxels(roof_gu):
					if layer.get_cell_source_id(voxel_pos) != expected_source_id:
						geometry_mismatches += 1
						break

				## D1-ROOF border fix, corrected 2026-07-16: expected border is
				## per-side, computed against the SAME map-wide roofed_gu_cells
				## set room_builder.gd uses — a side is bordered (independently
				## re-derived, not trusted from the registered Slab) only if
				## NO other roofed GU sits there, from any block declaration.
				var has_west: bool = roofed_gu_cells.has(roof_gu + Vector2i(-1, 0))
				var has_east: bool = roofed_gu_cells.has(roof_gu + Vector2i(1, 0))
				var has_north: bool = roofed_gu_cells.has(roof_gu + Vector2i(0, -1))
				var has_south: bool = roofed_gu_cells.has(roof_gu + Vector2i(0, 1))
				var expected_width: int = 8 + (0 if has_west else 1) + (0 if has_east else 1)
				var expected_height: int = 8 + (0 if has_north else 1) + (0 if has_south else 1)
				var expected_voxel_count: int = expected_width * expected_height
				if registered_slab.voxels.size() != expected_voxel_count:
					border_size_mismatches += 1

				## Real neighbour-collision check: this GU's voxel set must
				## share ZERO positions with any of its real roofed neighbours'
				## Slabs — the actual bug 15/49 blocks had before the fix.
				for neighbour_offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var neighbour_gu := roof_gu + neighbour_offset
					if not roofed_gu_cells.has(neighbour_gu):
						continue
					var neighbour_slab_id := "SLAB_%d_%d_%s_%d" % [neighbour_gu.x, neighbour_gu.y, Slab.role_name(Slab.Role.CEILING), roof_base_level]
					var neighbour_slab: Slab = room._slab_registry.get_slab(neighbour_slab_id)
					if neighbour_slab == null:
						continue
					var own_positions: Dictionary = {}
					for v in registered_slab.voxels:
						own_positions[v.grid_pos] = true
					for nv in neighbour_slab.voxels:
						if own_positions.has(nv.grid_pos):
							no_self_overlap_between_neighbours = false

				## Only a GU whose side genuinely has no roofed neighbour needs
				## the border-coverage (reaches into the wall's outer slice)
				## check — a suppressed side has no border voxel to find.
				if not has_west and not has_north:
					var neighbour_border_voxel: Vector2i = GeometryCoordsClass.gu_to_voxel_origin(roof_gu) - Vector2i(1, 1)
					if layer.get_cell_source_id(neighbour_border_voxel) != expected_source_id:
						border_coverage_mismatches += 1

	if checked_blocks > 0 and registry_mismatches == 0 and material_mismatches == 0 and geometry_mismatches == 0:
		_pass("All %d block-GUs (%d raw block declarations) have a real, registered, independently-verified roof Slab at the correct level with matching material" % [checked_blocks, raw_blocks.size()])
	else:
		_fail("%d GUs checked: %d not registered, %d wrong material, %d geometry mismatches" % [
			checked_blocks, registry_mismatches, material_mismatches, geometry_mismatches,
		])

	if checked_blocks > 0 and border_size_mismatches == 0 and border_coverage_mismatches == 0:
		_pass("All %d block roofs have exactly the border footprint their real map-wide adjacency predicts, borders reach the neighbour GU's wall-slice column where genuinely external" % checked_blocks)
	else:
		_fail("%d/%d roofs wrong voxel count (vs. adjacency-derived expectation), %d border-coverage cells not placed" % [
			border_size_mismatches, checked_blocks, border_coverage_mismatches,
		])

	## The actual bug this whole fix exists for: real adjacent blocks (e.g.
	## PLAYGROUND's 5-in-a-row same-material test fixtures) must share ZERO
	## voxel positions between their roof Slabs — this is what 15/49 blocks
	## got wrong before the map-wide adjacency fix landed.
	if no_self_overlap_between_neighbours:
		_pass("Zero shared voxel positions between any two real, roofed, adjacent block-GUs on the actual map")
	else:
		_fail("At least one pair of real adjacent block roofs shares voxel positions — the corruption the fix was meant to prevent")

	## Sanity: roof levels are independently destructible, same as the
	## isolated selftest already proved — spot-check on one real block here.
	var sample_block: Dictionary = solid_block_instances[0]
	var sample_gu: Vector2i = sample_block.get("gu_cell", Vector2i.ZERO)
	var sample_storeys: int = int(sample_block.get("storeys", 1))
	var sample_level: int = sample_storeys * GeometryCoordsClass.LEVELS_PER_STOREY
	var sample_slab_id := "SLAB_%d_%d_%s_%d" % [sample_gu.x, sample_gu.y, Slab.role_name(Slab.Role.CEILING), sample_level]
	var sample_slab: Slab = room._slab_registry.get_slab(sample_slab_id)
	if sample_slab != null:
		sample_slab.voxels[0].set_damage(Voxel.DamageState.DESTROYED)
		if sample_slab.dirty_count == 1 and room._slab_registry.dirty_slabs().size() == 1:
			_pass("A real roof Slab from the actual map is independently destructible (damaged 1/64 voxels, dirty_count=1)")
		else:
			_fail("Damaging a real roof Slab produced unexpected registry state")
	else:
		_fail("Could not locate the first real block's roof Slab by id for the destructibility spot-check")

	room.queue_free()
	print("")
