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
const VoxelBoardClass = preload("res://godot/scripts/geometry/voxel_board.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

class MinimalRoom extends Node:
	var _edge_registry
	var _junction_columns
	var _slab_registry
	var _voxel_board
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
		_unknown_kind(layout, roof)
		_skylight(layout, roof)
		_thin(layout, roof)
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
	var renderer := VoxelBoardClass.new()
	room.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	room._voxel_board = renderer
	var builder := RoomBuilderClass.new(room)
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


## A roof of a `kind` the builder does not know is skipped LOUDLY and builds nothing: no slabs, no crash, and the rest of the
## map (the ring of blocks and their own roofs) still builds. Its `push_error` is the designed loud-fail, so the harness
## prints one "[RoomBuilder] roof kind 'pointed'" error line for this case.
func _unknown_kind(layout: Dictionary, roof: Dictionary) -> void:
	print("\n[unknown roof kind]")
	var bent: Dictionary = layout.duplicate(true)
	var bent_roofs: Array = bent["roof_instances"]
	(bent_roofs[0] as Dictionary)["kind"] = "pointed"
	var room := MinimalRoom.new()
	root.add_child(room)
	var renderer := VoxelBoardClass.new()
	room.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	room._voxel_board = renderer
	var builder := RoomBuilderClass.new(room)
	builder.build_from_layout(bent, bent.get("size", Vector2i.ZERO))
	var base_level: int = GeometryCoordsClass.storey_level_base(int(roof["storeys"]))
	var origin: Vector2i = roof["gu_cell"]
	var found: int = 0
	for dx: int in range(3):
		for dy: int in range(3):
			for level_offset: int in range(2):
				var slab: Slab = room._slab_registry.get_slab(Slab.make_id(origin + Vector2i(dx, dy), Slab.Role.CEILING, base_level + level_offset))
				if slab != null:
					found += 1
	_check(found == 0, "a 'pointed' roof builds no slab over its 3x3 GUs (found %d)" % found)
	_check(room._slab_registry.all_slabs().size() > 0, "the rest of the map still builds its slabs (the ring blocks' own roofs)")
	room.queue_free()


func _built_room(layout: Dictionary) -> MinimalRoom:
	var room := MinimalRoom.new()
	root.add_child(room)
	var renderer := VoxelBoardClass.new()
	room.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	room._voxel_board = renderer
	RoomBuilderClass.new(room).build_from_layout(layout, layout.get("size", Vector2i.ZERO))
	return room


## ROOF R-D5 / Q-S1 (2026-10-11) — a skylight is a horizontal window built like a wall's pane: its GUs hold the glass in the roof's
## LOWER layer only and nothing in the upper one; the rest of the roof is the frame, both layers; a glass roof is a skylight over its
## whole area; and the skylight's rectangle turns with the roof in every view (its centre GU stays the centre).
func _skylight(layout: Dictionary, roof: Dictionary) -> void:
	print("\n[skylight]")
	var base_level: int = GeometryCoordsClass.storey_level_base(int(roof["storeys"]))
	var origin: Vector2i = roof["gu_cell"]
	var centre: Vector2i = origin + Vector2i(1, 1)
	var with_sky: Dictionary = layout.duplicate(true)
	((with_sky["roof_instances"] as Array)[0] as Dictionary)["skylight"] = {"gu_cell": centre, "size": Vector2i.ONE, "material": "glass"}
	var room := _built_room(with_sky)
	var lower: Slab = room._slab_registry.get_slab(Slab.make_id(centre, Slab.Role.CEILING, base_level))
	var upper: Slab = room._slab_registry.get_slab(Slab.make_id(centre, Slab.Role.CEILING, base_level + 1))
	_check(lower != null and lower.material == "glass" and upper == null, "the skylight GU: glass in the lower layer, the upper layer empty")
	_check(lower != null and lower.pane_id.begins_with("PANE_SKY_") and lower.face == 4,
		"the skylight's slab is a horizontal pane (pane_id %s, face %d)" % [lower.pane_id if lower != null else "-", lower.face if lower != null else -1])
	var frame_slab: Slab = room._slab_registry.get_slab(Slab.make_id(origin, Slab.Role.CEILING, base_level))
	_check(frame_slab != null and frame_slab.pane_id == "" and frame_slab.face == -1, "a frame slab is no pane")
	var frame: int = 0
	for dx: int in range(3):
		for dy: int in range(3):
			var gu: Vector2i = origin + Vector2i(dx, dy)
			if gu == centre:
				continue
			for level_offset: int in range(2):
				var sl: Slab = room._slab_registry.get_slab(Slab.make_id(gu, Slab.Role.CEILING, base_level + level_offset))
				if sl != null and sl.material == "concrete":
					frame += 1
	_check(frame == 16, "the frame: 8 GUs x 2 layers of concrete round it (found %d)" % frame)
	room.queue_free()

	var all_glass: Dictionary = layout.duplicate(true)
	((all_glass["roof_instances"] as Array)[0] as Dictionary)["material"] = "glass"
	var room2 := _built_room(all_glass)
	var low_n: int = 0
	var up_n: int = 0
	for dx: int in range(3):
		for dy: int in range(3):
			var gu: Vector2i = origin + Vector2i(dx, dy)
			if room2._slab_registry.get_slab(Slab.make_id(gu, Slab.Role.CEILING, base_level)) != null:
				low_n += 1
			if room2._slab_registry.get_slab(Slab.make_id(gu, Slab.Role.CEILING, base_level + 1)) != null:
				up_n += 1
	_check(low_n == 9 and up_n == 0, "a glass roof is a whole-roof skylight: 9 lower-layer slabs, no upper (found %d / %d)" % [low_n, up_n])
	var ids: Dictionary = {}
	for dx: int in range(3):
		for dy: int in range(3):
			var sl: Slab = room2._slab_registry.get_slab(Slab.make_id(origin + Vector2i(dx, dy), Slab.Role.CEILING, base_level))
			if sl != null:
				ids[sl.pane_id] = true
	_check(ids.size() == 1 and not ids.has(""), "its 9 GUs are ONE pane (%s)" % str(ids.keys()))
	room2.queue_free()

	for direction: String in ["E", "S", "W"]:
		var mapped: Dictionary = PerspectiveMapperClass.layout_with_perspective(with_sky, direction)
		var r: Dictionary = (mapped["roof_instances"] as Array)[0]
		var sky: Dictionary = r.get("skylight", {})
		_check(not sky.is_empty() and sky["gu_cell"] == r["gu_cell"] + Vector2i(1, 1) and sky["size"] == Vector2i.ONE,
			"%s: the skylight turns with its roof (still the centre GU)" % direction)


## ROOF RF-2 (Director, 2026-10-14) — cardboard, fabric and plywood are ONE layer in a roof as in a wall: every GU holds the material in the
## LOWER layer only, the upper one empty (no pane: they are opaque). Concrete keeps both layers (the [RoomBuilder] case above).
func _thin(layout: Dictionary, roof: Dictionary) -> void:
	print("\n[thin roof]")
	var base_level: int = GeometryCoordsClass.storey_level_base(int(roof["storeys"]))
	var origin: Vector2i = roof["gu_cell"]
	for material: String in ["cardboard", "fabric", "plywood"]:
		var thin: Dictionary = layout.duplicate(true)
		((thin["roof_instances"] as Array)[0] as Dictionary)["material"] = material
		var room := _built_room(thin)
		var low_n: int = 0
		var up_n: int = 0
		var panes: int = 0
		for dx: int in range(3):
			for dy: int in range(3):
				var gu: Vector2i = origin + Vector2i(dx, dy)
				var low: Slab = room._slab_registry.get_slab(Slab.make_id(gu, Slab.Role.CEILING, base_level))
				if low != null and low.material == material:
					low_n += 1
					if low.pane_id != "":
						panes += 1
				if room._slab_registry.get_slab(Slab.make_id(gu, Slab.Role.CEILING, base_level + 1)) != null:
					up_n += 1
		_check(low_n == 9 and up_n == 0 and panes == 0,
			"a %s roof is one layer: 9 lower-layer slabs, no upper, no pane (found %d / %d / %d)" % [material, low_n, up_n, panes])
		room.queue_free()
