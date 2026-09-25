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
## _edge_registry, _junction_columns, _slab_registry, _voxel_renderer,
## _wall_height_edges, plus generic Node methods (add_child/remove_child).
## Not room.gd itself: that
## carries a full game's worth of UI/controller dependencies this test has no
## business booting just to verify the floor-building loop.
class MinimalRoom extends Node:
	var _edge_registry
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	@warning_ignore("unused_private_class_variable")
	var _wall_height_edges
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
	var structure_layer := TileMapLayer.new()
	structure_layer.tile_set = floor_tileset
	room.add_child(structure_layer)

	var voxel_renderer := VoxelRendererClass.new()
	room.add_child(voxel_renderer)
	voxel_renderer.setup(Vector2.ZERO)
	room._voxel_renderer = voxel_renderer

	var builder := RoomBuilderClass.new(room)
	builder.setup(structure_layer, TileSet.new())
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

	## Criterion 4: the floor the board draws — the store's FLOOR_TOP_LEVEL claims on a sample of real GUs (corners +
	## center) carry the material the map declares for that GU, re-derived here from the layout: a floor-zone GU its
	## zone's material, every other GU the "earth" sentinel. R3D-END: until then this read the TILE each voxel was placed
	## as (a baked page vs the earth-variant hash), which was the 2D board's; the 3D board draws each claim's material.
	var zoned_material: Dictionary = {}
	for zone: Dictionary in layout.get("floor_zone_instances", []):
		var zone_gu: Vector2i = zone.get("gu_cell", Vector2i.ZERO)
		var zone_size: Vector2i = zone.get("size", Vector2i.ONE)
		if String(zone.get("material", "")) == "":
			continue
		for zx in range(zone_size.x):
			for zy in range(zone_size.y):
				zoned_material[zone_gu + Vector2i(zx, zy)] = String(zone["material"])

	var store: VoxelStore = VoxelStore.build(room._edge_registry, room._slab_registry, room._junction_columns)
	if store == null:
		_fail("VoxelStore.build() over the real build returned null")
	else:
		@warning_ignore("integer_division")
		var center_gu := Vector2i(room_size.x / 2, room_size.y / 2)
		var sample_gus: Array[Vector2i] = [
			Vector2i(0, 0), Vector2i(room_size.x - 1, room_size.y - 1), center_gu,
		]
		var level: int = GeometryCoordsClass.FLOOR_TOP_LEVEL
		var checked := 0
		var mismatches := 0
		var zoned_checked := 0
		for gu in sample_gus:
			var expected: String = String(zoned_material.get(gu, "earth"))
			if zoned_material.has(gu):
				zoned_checked += 64
			for voxel_pos in GeometryCoordsClass.gu_voxels(gu):
				checked += 1
				var owner_claim: int = store.owner[store.cell_index(voxel_pos.x, voxel_pos.y, level)] \
					if store.has_cell(voxel_pos.x, voxel_pos.y, level) else -1
				if owner_claim < 0 or store.material_ids[store.mat[owner_claim]] != expected:
					mismatches += 1
		if checked > 0 and zoned_checked > 0 and mismatches == 0:
			_pass("%d floor cells across 3 real GUs (corners + center) hold their declared material in the store — %d zoned, %d earth" % [
				checked, zoned_checked, checked - zoned_checked,
			])
		else:
			_fail("%d/%d floor cells mismatched in the store (zoned cells checked: %d — the center GU must be zoned on PLAYGROUND)" % [
				mismatches, checked, zoned_checked])

	## Criterion 4b (FLOOR-DEPTH-01): the deep plane is GENERATED at build — its Slab must exist for an interior GU.
	## (R3D-END: the "no cell rendered there yet" half was a 2D tile read and went with the 2D board.)
	var deep_gu := Vector2i(5, 5)
	var deep_slab: Slab = room._slab_registry.get_slab(
			Slab.make_id(deep_gu, Slab.Role.FLOOR, GeometryCoordsClass.FLOOR_DEEP_LEVEL))
	if deep_slab != null and deep_slab.voxels.size() == 64:
		_pass("Interior GU %s has a real deep Slab (64 voxels) at level %d" % [
			deep_gu, GeometryCoordsClass.FLOOR_DEEP_LEVEL,
		])
	else:
		_fail("Deep plane missing at GU %s: slab=%s (expected a 64-voxel Slab)" % [deep_gu, deep_slab])

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

	room.queue_free()
	print("")
