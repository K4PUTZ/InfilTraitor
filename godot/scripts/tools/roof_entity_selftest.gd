## R3D-7 — the free-standing `roofs` entity, end to end on the real OCCLUSION_ROOM map: FileMapSource reads the
## section, MapCompiler forwards `roof_instances` offset by the board buffer, PerspectiveMapper rotates it (the
## ROOF-BAKE-02a lesson: without an explicit rotation the roof lands on the wrong GUs in the E/S/W views), and
## RoomBuilder turns it into two CEILING slabs per GU at the height it names, through the same code a block's roof
## uses, with NO walls beneath it.
extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

class MinimalRoom extends Node:
	var _edge_registry
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	@warning_ignore("unused_private_class_variable")
	var _wall_height_edges
	var map_id: String = "TEST"

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== ROOF ENTITY SELFTEST (OCCLUSION_ROOM) ==\n")
	var bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var bake_was_enabled: bool = bake_config.enabled
	bake_config.enabled = false

	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("OCCLUSION_ROOM")
	_check(not spec.is_empty(), "FileMapSource reads OCCLUSION_ROOM")
	_check((spec.get("roofs", []) as Array).size() == 1, "the `roofs` section reaches the runtime spec (1 roof)")
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var roofs: Array = layout.get("roof_instances", [])
	_check(roofs.size() == 1, "MapCompiler forwards 1 roof_instance")
	if roofs.size() == 1:
		var roof: Dictionary = roofs[0]
		var buffer: int = int(layout.get("buffer", spec.get("buffer", 1)))
		print("    roof: %s" % str(roof))
		_check(roof["size"] == Vector2i(3, 3) and int(roof["storeys"]) == 3 and roof["kind"] == "flat"
			and roof["material"] == "concrete", "size 3x3, 3 storeys, concrete, flat")
		_check(roof["gu_cell"] != Vector2i(11, 11), "gu_cell is offset by the board buffer (%s, not the file's (11, 11))" % str(roof["gu_cell"]))
		_rotation(layout)
		_builder(layout, roof)
	bake_config.enabled = bake_was_enabled
	if _failures == 0:
		print("\n[SUCCESS] ROOF ENTITY SELFTEST PASS — all checks")
		quit(0)
	else:
		print("\n[FAILURE] %d check(s) failed" % _failures)
		quit(1)


## Each view: the roof rectangle equals the rectangle the SAME footprint rotates to as a block (they share the math),
## and it stays inside the ring of blocks it was declared inside.
func _rotation(layout: Dictionary) -> void:
	print("\n[rotation]")
	var base_size: Vector2i = layout.get("size", Vector2i.ZERO)
	for direction: String in ["N", "E", "S", "W"]:
		var mapped: Dictionary = layout if direction == "N" else PerspectiveMapperClass.layout_with_perspective(layout, direction)
		var roof: Dictionary = (mapped["roof_instances"] as Array)[0]
		var source: Dictionary = (layout["roof_instances"] as Array)[0]
		var c0: Vector2i = PerspectiveMapperClass.cell_from_base(source["gu_cell"], direction, base_size) if direction != "N" else source["gu_cell"]
		var c1: Vector2i = PerspectiveMapperClass.cell_from_base(source["gu_cell"] + source["size"] - Vector2i.ONE, direction, base_size) if direction != "N" else source["gu_cell"] + source["size"] - Vector2i.ONE
		var expected := Vector2i(mini(c0.x, c1.x), mini(c0.y, c1.y))
		_check(roof["gu_cell"] == expected and roof["size"] == Vector2i(3, 3),
			"%s: the roof is at %s (3x3), where its own corners rotate to" % [direction, str(expected)])
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-(1 << 20), -(1 << 20))
		for block: Dictionary in mapped.get("solid_block_instances", []):
			var g: Vector2i = block["gu_cell"]
			lo = Vector2i(mini(lo.x, g.x), mini(lo.y, g.y))
			hi = Vector2i(maxi(hi.x, g.x), maxi(hi.y, g.y))
		var inside: bool = roof["gu_cell"].x > lo.x and roof["gu_cell"].y > lo.y \
			and roof["gu_cell"].x + 2 < hi.x and roof["gu_cell"].y + 2 < hi.y
		_check(inside, "%s: the roof is inside the ring of blocks (%s..%s)" % [direction, str(lo), str(hi)])


func _builder(layout: Dictionary, roof: Dictionary) -> void:
	print("\n[RoomBuilder]")
	var room := MinimalRoom.new()
	root.add_child(room)
	var tileset: TileSet = load("res://godot/resources/tilesets/tileset_blocks.tres")
	var floor_layer := TileMapLayer.new()
	var structure_layer := TileMapLayer.new()
	floor_layer.tile_set = tileset
	structure_layer.tile_set = tileset
	room.add_child(floor_layer)
	room.add_child(structure_layer)
	var renderer := VoxelRendererClass.new()
	room.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	room._voxel_renderer = renderer
	var builder := RoomBuilderClass.new(room)
	builder.setup(floor_layer, structure_layer, TileSet.new())
	builder.build_registry(tileset)
	builder.build_from_layout(layout, layout.get("size", Vector2i.ZERO))

	var base_level: int = GeometryCoordsClass.storey_level_base(int(roof["storeys"]))
	var origin: Vector2i = roof["gu_cell"]
	var found: int = 0
	for dx: int in range(3):
		for dy: int in range(3):
			var gu: Vector2i = origin + Vector2i(dx, dy)
			for level_offset: int in range(2):
				var slab: Slab = room._slab_registry.get_slab(Slab.make_id(gu, Slab.Role.CEILING, base_level + level_offset))
				if slab != null and slab.material == "concrete":
					found += 1
	_check(found == 18, "18 concrete CEILING slabs (9 GUs x 2 levels) at level %d.. over the interior (found %d)" % [base_level, found])
	## No walls beneath: the interior GUs are not blocks, so no solid block claims them.
	var blocked: bool = false
	for block: Dictionary in layout.get("solid_block_instances", []):
		var g: Vector2i = block["gu_cell"]
		if g.x >= origin.x and g.x < origin.x + 3 and g.y >= origin.y and g.y < origin.y + 3:
			blocked = true
	_check(not blocked, "no block stands under the roof (it is free-standing)")
	room.queue_free()
