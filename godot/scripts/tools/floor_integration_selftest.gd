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

	## Criterion 2: exactly TWO FLOOR Slabs per GU — the destructible surface at
	## FLOOR_TOP_LEVEL and, since FLOOR-DEPTH-01 (Director, 2026-07-28), the deep
	## plane at FLOOR_DEEP_LEVEL beneath it — and nothing at any other level.
	## Updated from "exactly one at -1", which was the D13 one-plane model this
	## replaced; the invariant being guarded is unchanged in kind (every GU gets
	## its full ground stack, no stray levels), only in count. Filtered by
	## Role.FLOOR: since DESTRUCTION-D1-ROOF, the registry also legitimately
	## holds Role.CEILING Slabs for real map blocks (2 per block-GU, at
	## positive levels) — this criterion is about the floor's own invariant,
	## not "the registry contains nothing else."
	var all_slabs: Array = room._slab_registry.all_slabs()
	var floor_slabs: Array = all_slabs.filter(func(s: Slab) -> bool: return s.role == Slab.Role.FLOOR)
	var expected_gu_count: int = room_size.x * room_size.y
	var expected_floor_slabs: int = expected_gu_count * 2
	if floor_slabs.size() == expected_floor_slabs:
		_pass("SlabRegistry has exactly %d FLOOR Slabs — two per GU (room_size %s)" % [floor_slabs.size(), room_size])
	else:
		_fail("SlabRegistry has %d FLOOR Slabs, expected %d (room_size %s)" % [floor_slabs.size(), expected_floor_slabs, room_size])

	var level_counts: Dictionary = {}
	for slab in floor_slabs:
		level_counts[slab.level] = int(level_counts.get(slab.level, 0)) + 1
	var expected_levels: Dictionary = {
		GeometryCoordsClass.FLOOR_TOP_LEVEL: expected_gu_count,
		GeometryCoordsClass.FLOOR_DEEP_LEVEL: expected_gu_count,
	}
	if level_counts == expected_levels:
		_pass("FLOOR Slabs sit only at levels %d and %d, %d of each (one per GU)" % [
			GeometryCoordsClass.FLOOR_TOP_LEVEL, GeometryCoordsClass.FLOOR_DEEP_LEVEL, expected_gu_count,
		])
	else:
		_fail("FLOOR Slab level distribution is %s, expected %s" % [level_counts, expected_levels])

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
	##
	## ZONE-AWARE since FLOOR-DEPTH-01 (2026-07-28). This criterion checked every
	## sampled GU against the earth-variant hash, which stopped being true for the
	## whole map the moment FLOOR-BAKE-01 landed PLAYGROUND's `floor_zones` concrete
	## rect: the center GU falls inside it and renders from a baked page, so the
	## check had been failing 64/192 on that GU alone (pre-existing red, unrelated
	## to the two-plane floor — confirmed by running this test against the
	## pre-change tree). The GU's real expectation is now derived the same way the
	## builder derives it: zoned → a baked source, unzoned → the earth hash.
	var zoned_gus: Dictionary = {}
	for zone: Dictionary in layout.get("floor_zone_instances", []):
		var zone_gu: Vector2i = zone.get("gu_cell", Vector2i.ZERO)
		var zone_size: Vector2i = zone.get("size", Vector2i.ONE)
		if String(zone.get("material", "")) == "":
			continue
		for zx in range(zone_size.x):
			for zy in range(zone_size.y):
				zoned_gus[zone_gu + Vector2i(zx, zy)] = true

	var layer: TileMapLayer = voxel_renderer.get_layer(GeometryCoordsClass.FLOOR_TOP_LEVEL)
	if layer == null:
		_fail("voxel_renderer.get_layer(%d) is null after a real build" % GeometryCoordsClass.FLOOR_TOP_LEVEL)
	else:
		@warning_ignore("integer_division")
		var center_gu := Vector2i(room_size.x / 2, room_size.y / 2)
		var sample_gus: Array[Vector2i] = [
			Vector2i(0, 0), Vector2i(room_size.x - 1, room_size.y - 1), center_gu,
		]
		var checked := 0
		var mismatches := 0
		var zoned_checked := 0
		for gu in sample_gus:
			var is_zoned: bool = zoned_gus.has(gu)
			for voxel_pos in GeometryCoordsClass.gu_voxels(gu):
				checked += 1
				var actual_source_id: int = layer.get_cell_source_id(voxel_pos)
				if is_zoned:
					## A baked page is registered AFTER the four material sources,
					## so its id is always past the end of MATERIALS.
					zoned_checked += 1
					if actual_source_id < VoxelRendererClass.MATERIALS.size():
						mismatches += 1
				else:
					var expected_variant: int = EarthVariantSelector.variant_for(
							voxel_pos, GeometryCoordsClass.FLOOR_TOP_LEVEL)
					var expected_source_id: int = VoxelRendererClass.MATERIALS.find("earth_%d" % expected_variant)
					if actual_source_id != expected_source_id:
						mismatches += 1
		if checked > 0 and mismatches == 0:
			_pass("%d cells across 3 real GUs (corners + center) match their expected source — %d from a floor-zone bake page, %d from an independently re-derived earth variant" % [
				checked, zoned_checked, checked - zoned_checked,
			])
		else:
			_fail("%d/%d cells mismatched on real PLAYGROUND floor cells" % [mismatches, checked])

	## Criterion 4b (FLOOR-DEPTH-01): the deep plane is GENERATED but NOT RENDERED
	## at build — it is fully occluded by the surface above it, and drawing it
	## eagerly would double the floor's cell count for zero pixels. Its Slab must
	## exist for an interior GU while its layer holds nothing there.
	var deep_gu := Vector2i(5, 5)
	var deep_slab: Slab = room._slab_registry.get_slab(
			Slab.make_id(deep_gu, Slab.Role.FLOOR, GeometryCoordsClass.FLOOR_DEEP_LEVEL))
	var deep_layer: TileMapLayer = voxel_renderer.get_layer(GeometryCoordsClass.FLOOR_DEEP_LEVEL)
	var deep_cell_source: int = -1
	if deep_layer != null:
		deep_cell_source = deep_layer.get_cell_source_id(GeometryCoordsClass.gu_to_voxel_origin(deep_gu))
	if deep_slab != null and deep_slab.voxels.size() == 64 and deep_cell_source == -1:
		_pass("Interior GU %s has a real deep Slab (64 voxels) at level %d with no cells rendered yet — deferred render contract holds" % [
			deep_gu, GeometryCoordsClass.FLOOR_DEEP_LEVEL,
		])
	else:
		_fail("Deep plane contract broken at GU %s: slab=%s cell_source=%d (expected a 64-voxel Slab and no rendered cell)" % [
			deep_gu, deep_slab, deep_cell_source,
		])

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
