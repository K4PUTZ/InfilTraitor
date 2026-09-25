## FLOOR-BAKE-01 — floor-zone photographic ground bake selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/floor_zone_bake_selftest.gd
##
## R3D-END END-4: the compositor and the baked lookup are gone, and with them criteria [1]-[3] (the shared page family, the
## resolved atoms, pixel continuity, isotropy and the full-colour modulate) and [4] (END-1). What survives is the data
## contract:
##   5. ROTATION: building the E view puts a zone's Slab material at the
##      correctly-rotated GU, exactly like roof's block rotation
##
## The expectation is re-derived locally (own rotation math), never read back from the code under test.

extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelBoardClass = preload("res://godot/scripts/geometry/voxel_board.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")

## LEVEL-RENUMBER — was a hand-copied `-1`. A mirrored constant that does not
## follow the thing it mirrors is a second producer, which is the drift this
## project keeps paying for; it reads the real one now.
const FLOOR_TOP_LEVEL: int = GeometryCoords.FLOOR_TOP_LEVEL  ## mirrors room_builder.gd
class MinimalRoom extends Node:
	@warning_ignore("unused_private_class_variable")
	var _edge_registry
	@warning_ignore("unused_private_class_variable")
	var _junction_columns
	var _slab_registry
	var _voxel_board
	@warning_ignore("unused_private_class_variable")
	var _wall_height_edges
	var map_id: String = "TEST"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("FLOOR-BAKE-01 — Floor-zone baked-surface SELFTEST")
	print("=".repeat(70) + "\n")

	test_5_rotated_view_zones_follow_declared_material()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ FLOOR ZONE BAKE SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ FLOOR ZONE BAKE SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## Boot the real FLOOR_ZONES_TEST map through the exact room.gd::load_map()
## path, optionally rotated. Returns {room, renderer, layout} or empty.
func _build_test_map(direction: String) -> Dictionary:
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("FLOOR_ZONES_TEST")
	if spec.is_empty():
		_fail("FileMapSource.get_runtime_spec('FLOOR_ZONES_TEST') returned empty")
		return {}
	var layout: Dictionary = MapCompilerClass.compile(spec)
	if direction != "N":
		layout = PerspectiveMapperClass.layout_with_perspective(layout, direction)

	var room := MinimalRoom.new()
	root.add_child(room)
	var floor_tileset: TileSet = load("res://godot/resources/tilesets/tileset_blocks.tres")
	var structure_layer := TileMapLayer.new()
	structure_layer.tile_set = floor_tileset
	room.add_child(structure_layer)
	var voxel_board := VoxelBoardClass.new()
	room.add_child(voxel_board)
	voxel_board.setup(Vector2.ZERO)
	room._voxel_board = voxel_board
	var builder := RoomBuilderClass.new(room)
	builder.setup(structure_layer, TileSet.new())
	builder.build_registry(floor_tileset)
	builder.build_from_layout(layout, layout.get("size", Vector2i.ZERO))
	return {"room": room, "renderer": voxel_board, "layout": layout}


func test_5_rotated_view_zones_follow_declared_material() -> void:
	print("[TEST 5] E view: every declared zone's Slab exists at its ROTATED GU with its declared material")
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("FLOOR_ZONES_TEST")
	var base_layout: Dictionary = MapCompilerClass.compile(spec)
	var base_zones: Array = base_layout.get("floor_zone_instances", [])
	var base_size: Vector2i = base_layout.get("size", Vector2i.ZERO)

	if base_zones.is_empty():
		_fail("FLOOR_ZONES_TEST has zero floor_zone_instances — cannot test rotation")
		return

	var built := _build_test_map("E")
	if built.is_empty():
		return
	var room: MinimalRoom = built["room"]

	## Own rotation math (E = 90 CW): base (x, y) -> (h-1-y, x); a
	## rectangle's rotated NW corner = (h - y0 - sy, x0), size swaps.
	var missing := 0
	var wrong_material := 0
	for z in base_zones:
		var gu: Vector2i = z.get("gu_cell", Vector2i.ZERO)
		var size: Vector2i = z.get("size", Vector2i.ONE)
		var material: String = String(z.get("material", ""))
		var rot_gu := Vector2i(base_size.y - gu.y - size.y, gu.x)
		var rot_size := Vector2i(size.y, size.x)
		for rx in range(rot_size.x):
			for ry in range(rot_size.y):
				var slab_id := "SLAB_%d_%d_%s_%d" % [rot_gu.x + rx, rot_gu.y + ry, Slab.role_name(Slab.Role.FLOOR), FLOOR_TOP_LEVEL]
				var slab: Slab = room._slab_registry.get_slab(slab_id)
				if slab == null:
					missing += 1
					continue
				if slab.material != material:
					wrong_material += 1

	if missing == 0 and wrong_material == 0:
		_pass("All %d declared zones have a FLOOR Slab at their independently-rotated E-view position with the correct material" % [base_zones.size()])
	else:
		_fail("E view: %d rotated zone-GUs missing a FLOOR Slab, %d with wrong material" % [missing, wrong_material])

	room.queue_free()
