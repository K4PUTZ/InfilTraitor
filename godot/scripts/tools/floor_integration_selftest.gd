## DESTRUCTION_MASTER_PLAN Part 2 — real map integration selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/floor_integration_selftest.gd
##
## Drives the REAL RoomBuilder.build_from_layout() against a REAL compiled map
## (PLAYGROUND, via FileMapSource + MapCompiler — the exact same path
## room.gd::load_map() uses), not a synthetic map_spec. Proves the floor
## integration lands correctly end-to-end: every GU gets a real Slab at
## level -1, cells round-trip against an independently re-derived hash, and
## the existing wall/prop pipeline is unaffected.

extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

## Minimal RoomBuilder target — RoomBuilder only ever reads/writes
## _edge_registry, _junction_columns, _slab_registry, _voxel_renderer, plus
## generic Node methods (add_child/remove_child). Not room.gd itself: that
## carries a full game's worth of UI/controller dependencies this test has no
## business booting just to verify the floor-building loop.
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
	print("DESTRUCTION Part 2 — Real map floor integration SELFTEST (PLAYGROUND)")
	print("=".repeat(70) + "\n")

	test_real_playground_map_gets_a_real_floor()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ FLOOR INTEGRATION SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ FLOOR INTEGRATION SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func test_real_playground_map_gets_a_real_floor() -> void:
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("PLAYGROUND")
	if spec.is_empty():
		_fail("FileMapSource.get_runtime_spec('PLAYGROUND') returned empty — cannot run a real-map test")
		return

	var layout: Dictionary = MapCompilerClass.compile(spec)
	if layout.is_empty():
		_fail("MapCompiler.compile() on the real PLAYGROUND spec returned empty")
		return

	var room_size: Vector2i = layout.get("size", Vector2i.ZERO)
	if room_size == Vector2i.ZERO:
		_fail("Compiled PLAYGROUND layout has no size")
		return
	print("  PLAYGROUND compiled: size=%s\n" % room_size)

	var room := MinimalRoom.new()
	root.add_child(room)

	## Same tileset room.gd's real _ready() loads (TILESET_PATH) before ever
	## calling build_from_layout() — _place() needs floor_layer.tile_set to
	## resolve tile names via tile_registry.gd, same as the real boot.
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
	## Same call room.gd's real _ready() makes right after loading the
	## tileset (room.gd:459) — populates _tile_ids from TileData custom_data,
	## which _place() needs to resolve "floor_SE" and friends.
	builder.build_registry(floor_tileset)

	var t_start := Time.get_ticks_usec()
	builder.build_from_layout(layout, room_size)
	var build_ms := (Time.get_ticks_usec() - t_start) / 1000.0
	print("  build_from_layout() wall time: %.2f ms\n" % build_ms)

	## Criterion 1: registry is real and never null, per the D1 fix (was
	## previously only published inside the edges-conditional).
	if room._slab_registry != null:
		_pass("room._slab_registry is non-null after a real build_from_layout() call")
	else:
		_fail("room._slab_registry is null — the unconditional publish didn't land")
		room.queue_free()
		return

	## Criterion 2: exactly one FLOOR Slab per GU (room_size.x * room_size.y),
	## all at the destructible top level (-1), none anywhere else. Filtered by
	## Role.FLOOR: since DESTRUCTION-D1-ROOF, the registry also legitimately
	## holds Role.CEILING Slabs for real map blocks (2 per block-GU, at
	## positive levels) — this criterion is about the floor's own invariant,
	## not "the registry contains nothing else."
	var all_slabs: Array = room._slab_registry.all_slabs()
	var floor_slabs: Array = all_slabs.filter(func(s: Slab) -> bool: return s.role == Slab.Role.FLOOR)
	var expected_gu_count: int = room_size.x * room_size.y
	if floor_slabs.size() == expected_gu_count:
		_pass("SlabRegistry has exactly %d FLOOR Slabs — one per GU (room_size %s)" % [floor_slabs.size(), room_size])
	else:
		_fail("SlabRegistry has %d FLOOR Slabs, expected %d (room_size %s)" % [floor_slabs.size(), expected_gu_count, room_size])

	var all_at_top_level := true
	for slab in floor_slabs:
		if slab.level != -1:
			all_at_top_level = false
	if all_at_top_level:
		_pass("Every registered FLOOR Slab is at level -1 (the destructible top, D13)")
	else:
		_fail("At least one FLOOR Slab is not at level -1")

	## Sanity, not previously checked: the registry's non-floor remainder is
	## exactly the roof Slabs DESTRUCTION-D1-ROOF adds (2 per block-GU) —
	## confirms the two producers coexist without one silently swallowing the
	## other's count.
	var ceiling_slabs: Array = all_slabs.filter(func(s: Slab) -> bool: return s.role == Slab.Role.CEILING)
	if all_slabs.size() == floor_slabs.size() + ceiling_slabs.size():
		_pass("Registry total (%d) == FLOOR (%d) + CEILING (%d), no untracked third category" % [
			all_slabs.size(), floor_slabs.size(), ceiling_slabs.size(),
		])
	else:
		_fail("Registry total %d does not equal FLOOR %d + CEILING %d" % [
			all_slabs.size(), floor_slabs.size(), ceiling_slabs.size(),
		])

	## Criterion 3: no Slab is dirty (nothing has been damaged) — registry
	## population must not itself mark anything dirty.
	if room._slab_registry.dirty_slabs().is_empty():
		_pass("Zero dirty Slabs immediately after build — population doesn't self-damage")
	else:
		_fail("%d Slabs are dirty immediately after build — should be zero" % room._slab_registry.dirty_slabs().size())

	## Criterion 4: real, independently re-derived cell round-trip on a
	## sample of real GUs from the real map — same discipline as
	## slab_render_selftest.gd, now against real map coordinates.
	var layer: TileMapLayer = voxel_renderer.get_layer(-1)
	if layer == null:
		_fail("voxel_renderer.get_layer(-1) is null after a real build")
	else:
		@warning_ignore("integer_division")
		var center_gu := Vector2i(room_size.x / 2, room_size.y / 2)
		var sample_gus: Array[Vector2i] = [
			Vector2i(0, 0), Vector2i(room_size.x - 1, room_size.y - 1), center_gu,
		]
		var checked := 0
		var mismatches := 0
		for gu in sample_gus:
			for voxel_pos in GeometryCoordsClass.gu_voxels(gu):
				checked += 1
				var expected_variant: int = EarthVariantSelector.variant_for(voxel_pos, -1)
				var expected_source_id: int = VoxelRendererClass.MATERIALS.find("earth_%d" % expected_variant)
				var actual_source_id: int = layer.get_cell_source_id(voxel_pos)
				if actual_source_id != expected_source_id:
					mismatches += 1
		if checked > 0 and mismatches == 0:
			_pass("%d cells across 3 real GUs (corners + center) match an independently re-derived variant" % checked)
		else:
			_fail("%d/%d cells mismatched on real PLAYGROUND floor cells" % [mismatches, checked])

	## Criterion 5: the existing wall pipeline is unaffected — walls still
	## exist on positive levels if PLAYGROUND has any, and junction columns
	## (if any) were still published to room._junction_columns as before.
	if room._edge_registry != null and not room._edge_registry.all_edges().is_empty():
		var junctions: int = room._junction_columns.size() if room._junction_columns != null else 0
		_pass("room._edge_registry: %d real edges, room._junction_columns: %d — wall pipeline unaffected" % [
			room._edge_registry.all_edges().size(), junctions,
		])
	else:
		print("  (no edges on this map/layout — wall-pipeline check skipped, not a failure)\n")

	## Criterion 6: D18 border amendment (dev-only) — a corner GU (always on
	## the perimeter) has all 8 levels; a real interior GU (room is 30x20, so
	## (5,5) is safely inside) has only the top level, still lazy.
	var corner_gu := Vector2i(0, 0)
	var corner_levels_built := 0
	for level in range(-8, 0):
		if voxel_renderer.get_layer(level) != null:
			var l: TileMapLayer = voxel_renderer.get_layer(level)
			if l.get_cell_source_id(GeometryCoordsClass.gu_to_voxel_origin(corner_gu)) >= 0:
				corner_levels_built += 1
	if corner_levels_built == 8:
		_pass("Corner GU (0,0) has all 8 levels built (D18 border amendment)")
	else:
		_fail("Corner GU (0,0) has %d/8 levels built, expected all 8" % corner_levels_built)

	var interior_gu := Vector2i(5, 5)
	var interior_fixed_built := false
	for level in range(-8, -1):  # -8..-2, the fixed levels
		var l: TileMapLayer = voxel_renderer.get_layer(level)
		if l != null and l.get_cell_source_id(GeometryCoordsClass.gu_to_voxel_origin(interior_gu)) >= 0:
			interior_fixed_built = true
	if not interior_fixed_built:
		_pass("Interior GU (5,5) has no fixed levels built — still lazy (D18 unaffected by the border amendment)")
	else:
		_fail("Interior GU (5,5) unexpectedly has a fixed level built — border amendment leaked past the perimeter")

	room.queue_free()
	print("")
