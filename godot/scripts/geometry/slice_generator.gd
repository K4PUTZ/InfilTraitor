## Geometry Module — Slice Generator: creates Slices and Voxels from Edges
## Port from room.gd _place_wall_voxels() and _voxel_slice_positions() logic
class_name SliceGenerator


## Generate slices and voxels for all edges; register in EdgeRegistry
static func generate(edges: Array, registry: EdgeRegistry) -> void:
	# For each edge, create 2 slices (A and B) with voxels
	for edge in edges:
		if not (edge is Edge):
			push_error("SliceGenerator.generate: non-Edge object in edges array")
			continue

		# Register the edge itself. Without this, EdgeRegistry.all_edges()
		# stays empty forever — JunctionResolver.resolve() iterates it to
		# find V-junctions, so a missing register_edge() here silently
		# produces zero corner columns regardless of how correct the
		# junction math is. register_edge() was defined but never called
		# anywhere in the codebase before this fix.
		registry.register_edge(edge)

		# Create slice A (on gu_a, face_a)
		var slice_a := _create_slice(edge, true, registry)
		if slice_a:
			registry.register_slice(slice_a)
		
		# Create slice B (on gu_b, face_b)
		var slice_b := _create_slice(edge, false, registry)
		if slice_b:
			registry.register_slice(slice_b)


## Internal: create one slice with its voxels
static func _create_slice(edge: Edge, is_side_a: bool, _registry: EdgeRegistry) -> Slice:
	var gu_cell := edge.gu_a if is_side_a else edge.gu_b
	var face := edge.face_a if is_side_a else edge.face_b
	
	var slice_id := "SLICE_%d_%d_%s" % [gu_cell.x, gu_cell.y, Face.to_string_name(face)]
	var slice := Slice.new(slice_id, gu_cell, face, edge.id, edge.storey_count, edge.material, edge.start_storey)
	
	# Generate voxel positions for this slice
	var voxel_positions := slice_voxel_positions(gu_cell, face)
	
	# Create voxels: each position × each storey level (use actual storey range)
	for level_offset in range(edge.storey_count):
		var level := edge.start_storey + level_offset
		for voxel_pos in voxel_positions:
			var voxel := Voxel.new(voxel_pos, level, slice)
			slice.voxels.append(voxel)
	
	return slice


## Return 8 voxel positions on one face of a Gameplay Unit
## These are the positions where voxels will be placed for rendering the wall
static func slice_voxel_positions(gu: Vector2i, face: int) -> Array[Vector2i]:
	var origin := GeometryCoords.gu_to_voxel_origin(gu)
	var result: Array[Vector2i] = []
	
	# For each face, we have a fixed edge (column or row) with 8 positions
	match face:
		Face.NW:
			# NW face: column 0 (left edge), varying rows
			var col := origin.x
			for j in range(GeometryCoords.VOXELS_PER_UNIT_AXIS):
				result.append(Vector2i(col, origin.y + j))
		
		Face.NE:
			# NE face: row 0 (top edge), varying columns
			var row := origin.y
			for i in range(GeometryCoords.VOXELS_PER_UNIT_AXIS):
				result.append(Vector2i(origin.x + i, row))
		
		Face.SE:
			# SE face: column 7 (right edge), varying rows
			var col := origin.x + GeometryCoords.VOXELS_PER_UNIT_AXIS - 1
			for j in range(GeometryCoords.VOXELS_PER_UNIT_AXIS):
				result.append(Vector2i(col, origin.y + j))
		
		Face.SW:
			# SW face: row 7 (bottom edge), varying columns
			var row := origin.y + GeometryCoords.VOXELS_PER_UNIT_AXIS - 1
			for i in range(GeometryCoords.VOXELS_PER_UNIT_AXIS):
				result.append(Vector2i(origin.x + i, row))
		
		_:
			push_error("SliceGenerator.slice_voxel_positions: invalid face %d" % face)
	
	return result
