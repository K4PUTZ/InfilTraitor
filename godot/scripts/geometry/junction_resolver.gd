## Geometry Module — Junction Resolver: fills V-junction corner columns
## Port from room.gd _build_voxel_junction_extras() logic
class_name JunctionResolver


## Container for a corner column at a V-junction
class JunctionColumn:
	var gu_cell: Vector2i         ## the corner GU that owns this column
	var voxel_pos: Vector2i       ## the voxel position of the column
	var storey_count: int         ## height (max adjacent edge storey)
	var voxels: Array[Voxel]      ## the voxel objects
	
	func _init(p_gu: Vector2i, p_voxel_pos: Vector2i, p_storey_count: int):
		gu_cell = p_gu
		voxel_pos = p_voxel_pos
		storey_count = p_storey_count
		voxels = []
	
	func _to_string() -> String:
		return "JunctionColumn{gu=%s, voxel=%s, storeys=%d}" % [gu_cell, voxel_pos, storey_count]


## Resolve V-junctions from a registry of edges
## Returns array of JunctionColumn objects
static func resolve(registry: EdgeRegistry) -> Array:
	var result: Array = []
	
	# Collect all touched vertices and their adjacent edges
	var vertices_to_edges: Dictionary = {}  # Vector2i (voxel vertex) → Array[Edge]
	
	for edge in registry.all_edges():
		var verts := _get_edge_vertices(edge)
		for vertex in verts:
			if vertex not in vertices_to_edges:
				vertices_to_edges[vertex] = []
			vertices_to_edges[vertex].append(edge)
	
	# For each vertex, check its 4 diagonal GU corners
	for vertex: Vector2i in vertices_to_edges.keys():
		var touching_edges: Array = vertices_to_edges[vertex]
		
		# Get the 4 GU cells at corners of this vertex
		var corner_gus := _get_corner_gus(vertex)
		
		for corner_gu in corner_gus:
			# Check if this corner is uncovered (missing one of its two covering edges)
			var edge_count := _count_edges_covering_corner(corner_gu, touching_edges, vertex)
			
			if edge_count == 1:
				# V-junction: exactly 1 edge covers this corner
				# Add a column with max adjacent storey count
				var max_storey := _max_storey_of_edges(touching_edges)
				var voxel_pos := _corner_gu_to_voxel(corner_gu, vertex)
				
				var column := JunctionColumn.new(corner_gu, voxel_pos, max_storey)
				result.append(column)
	
	return result


## Get the 4 voxel vertices touched by an edge
static func _get_edge_vertices(edge: Edge) -> Array:
	# The voxel vertices are derived from the GU vertices
	# Each GU cell corresponds to an 8×8 voxel region
	var vertices: Array = []
	
	var v_a := edge.gu_a * 8
	var v_b := edge.gu_b * 8
	
	# The edge connects two cells, creating 2 voxel vertices
	match edge.face_a:
		Face.SE:
			# SE: right edge of gu_a
			# Vertices: bottom-right of gu_a and bottom-left of gu_b
			vertices = [
				Vector2i(v_a.x + 7, v_a.y + 7),  # SE corner of gu_a
				Vector2i(v_b.x, v_b.y + 7)       # SW corner of gu_b
			]
		Face.SW:
			# SW: bottom edge of gu_a
			# Vertices: bottom-left of gu_a and top-left of gu_b
			vertices = [
				Vector2i(v_a.x, v_a.y + 7),      # SW corner of gu_a
				Vector2i(v_b.x, v_b.y)           # NW corner of gu_b
			]
	
	return vertices


## Get 4 GU cells at corners of a voxel vertex
## The vertex is surrounded by 4 GUs in an X pattern
static func _get_corner_gus(vertex: Vector2i) -> Array:
	# Find which GUs touch this vertex
	var voxel_x := vertex.x
	var voxel_y := vertex.y
	
	var gu_x := voxel_x / 8
	var gu_y := vertex.y / 8
	
	# The 4 GUs are: TL, TR, BR, BL
	var gus: Array = [
		Vector2i(gu_x - 1, gu_y - 1),  # Top-left
		Vector2i(gu_x, gu_y - 1),      # Top-right
		Vector2i(gu_x, gu_y),          # Bottom-right
		Vector2i(gu_x - 1, gu_y),      # Bottom-left
	]
	
	return gus


## Check how many edges from the list cover a corner GU
## An edge covers a corner if it touches one of the corner's two required edges
static func _count_edges_covering_corner(corner_gu: Vector2i, edges: Array, vertex: Vector2i) -> int:
	var count := 0
	
	for edge in edges:
		if _edge_covers_corner(edge, corner_gu, vertex):
			count += 1
	
	return count


## Check if an edge covers a corner GU at the given vertex
static func _edge_covers_corner(edge: Edge, corner_gu: Vector2i, vertex: Vector2i) -> bool:
	# An edge covers a corner if:
	# 1. One end of the edge is adjacent to corner_gu
	# 2. The edge's vertex matches the given vertex
	
	# Simplified: check if either gu_a or gu_b is adjacent to corner_gu
	# and the edge's voxel vertices include the given vertex
	
	var edge_verts := _get_edge_vertices(edge)
	if vertex not in edge_verts:
		return false
	
	# Also check that one GU is actually adjacent to the corner
	if (edge.gu_a.distance_to(corner_gu) <= 2 or edge.gu_b.distance_to(corner_gu) <= 2):
		return true
	
	return false


## Get max storey count from edge array
static func _max_storey_of_edges(edges: Array) -> int:
	var max_storey := 0
	for edge in edges:
		if edge is Edge:
			max_storey = max(max_storey, edge.storey_count)
	return max_storey


## Convert corner GU and vertex to voxel position
## This is the exact voxel cell at that corner
static func _corner_gu_to_voxel(corner_gu: Vector2i, vertex: Vector2i) -> Vector2i:
	var origin := GeometryCoords.gu_to_voxel_origin(corner_gu)
	
	# Determine which corner of the GU the vertex is at
	# and return the corresponding voxel position
	
	# Simple approach: the vertex maps directly to voxel coordinates
	# (corners are aligned between GU and voxel grids due to 8×8 mapping)
	var voxel_x := origin.x
	var voxel_y := origin.y
	
	# Check if vertex is at SE, NE, NW, or SW corner
	var local_x := vertex.x - voxel_x
	var local_y := vertex.y - voxel_y
	
	if local_x >= 4:
		voxel_x += 7
	if local_y >= 4:
		voxel_y += 7
	
	return Vector2i(voxel_x, voxel_y)
