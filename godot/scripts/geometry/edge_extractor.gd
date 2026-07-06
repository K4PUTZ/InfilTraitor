## Geometry Module — Edge Extractor: converts compiled map to Edge objects
## Ported from legacy geometry system; refined by SLICE-02 refactor (docs/history/)
class_name EdgeExtractor

## Mapping from wall tile suffix to face direction (DIRECTION_GLOSSARY §6)
const _EDGE_BY_SUFFIX: Dictionary = {
	"NW": Face.NW,  ## (-1, 0)
	"NE": Face.NE,  ## (0, -1)
	"SE": Face.SE,  ## (+1, 0)
	"SW": Face.SW,  ## (0, +1)
}


## Extract edges and solid blocks from compiled map dictionary
## wall_levels format: [ [{"cell": Vec2i, "tile_name": "wall_NW"}, ...], [...], ... ]
## Each array index is a storey level; each entry is {"cell": ..., "tile_name": ...}
## Returns: {"edges": Array[Edge], "solid_blocks": Array[Dictionary]}
## Guard: invalid input returns empty result (no crash, no state change)
static func extract(compiled: Dictionary) -> Dictionary:
	var result := {
		"edges": [],
		"solid_blocks": []
	}
	
	# Guard: validate input structure
	if compiled.is_empty():
		push_error("[EdgeExtractor] extract() called with empty compiled map")
		return result
	
	if not compiled.has("wall_levels"):
		push_error("[EdgeExtractor] extract() missing required key 'wall_levels'")
		return result
	
	var wall_levels: Array = compiled["wall_levels"]
	if not (wall_levels is Array) or wall_levels.is_empty():
		push_error("[EdgeExtractor] wall_levels is not a non-empty Array")
		return result
	
	# Dictionary to merge duplicate edges by their canonical id
	# When the same physical edge is emitted from both adjacent GUs, track min and max storey
	var edge_groups: Dictionary = {}  # edge_canonical_key → {"edge_template": Edge, "min_storey": int, "max_storey": int}
	
	# Build occupancy map for solidblock_ entries: (cell, storey) -> material
	# Used for exposure culling: a face is only emitted if the neighbor is NOT occupied
	var solidblock_occupancy: Dictionary = {}  # (cell, storey) key -> material
	
	# First pass: scan all wall_levels to collect walls, solidblock occupancy, and legacy blocks
	for storey in range(wall_levels.size()):
		var level_data: Array = wall_levels[storey]
		if not (level_data is Array):
			continue
		
		# Each entry in level_data is a dict with "cell" and "tile_name"
		for entry in level_data:
			if not (entry is Dictionary):
				continue
			
			var cell: Vector2i = Vector2i(entry.get("cell", Vector2i.ZERO))
			var tile_name: String = String(entry.get("tile_name", ""))
			
			# Skip doors
			if tile_name.begins_with("doorOpen_"):
				continue
			
			# Check for wall tiles: "wall_NW", "wall_NE", "wall_SE", "wall_SW"
			if tile_name.begins_with("wall_"):
				var suffix := tile_name.substr(5)  # Remove "wall_" prefix
				
				if suffix not in _EDGE_BY_SUFFIX:
					push_warning("EdgeExtractor: unknown wall suffix '%s'" % suffix)
					continue
				
				var face: int = _EDGE_BY_SUFFIX[suffix]
				
				# Determine the two cells involved (cell and its adjacent cell)
				var cell_a: Vector2i = cell
				var cell_b: Vector2i = cell + Face.delta(face)
				
				# Normalize to canonical order for deduplication
				var edge := Edge.between(cell_a, cell_b, 1, "concrete")
				
				# Track min and max storey for this edge (walls default to min_storey=0)
				if edge.id not in edge_groups:
					edge_groups[edge.id] = {"edge_template": edge, "min_storey": 0, "max_storey": storey}
				else:
					# Update max storey
					edge_groups[edge.id]["max_storey"] = max(edge_groups[edge.id]["max_storey"], storey)
			
			# New real-edge solid blocks: "solidblock_stone", "solidblock_concrete", etc.
			elif tile_name.begins_with("solidblock_"):
				var material := tile_name.substr(11)  # Remove "solidblock_" prefix
				solidblock_occupancy["%d,%d,%d" % [cell.x, cell.y, storey]] = material
			
			# Legacy solid blocks (divider convention): "block_SE", "block_NW", etc.
			# Keep this branch untouched per Finding B (preserve legacy behavior)
			elif tile_name.begins_with("block_"):
				var material := tile_name.substr(6)  # Remove "block_" prefix
				
				# Convert GU coordinates to voxel footprint
				var voxel_origin := GeometryCoords.gu_to_voxel_origin(cell)
				
				var block := {
					"gu_cell": cell,
					"storey": storey,
					"voxel_origin": voxel_origin,
					"voxel_size": GeometryCoords.VOXELS_PER_UNIT_AXIS,
					"material": material,
					"tile_name": tile_name
				}
				result["solid_blocks"].append(block)
	
	# Second pass: emit edges for occupied solidblock_ cells with face culling
	for occupancy_key: String in solidblock_occupancy.keys():
		var parts = occupancy_key.split(",")
		var cell = Vector2i(int(parts[0]), int(parts[1]))
		var storey = int(parts[2])
		var material = solidblock_occupancy[occupancy_key]
		
		# Check all 4 face directions for exposure culling
		for face in [Face.NW, Face.NE, Face.SE, Face.SW]:
			var neighbor_cell = cell + Face.delta(face)
			var neighbor_key = "%d,%d,%d" % [neighbor_cell.x, neighbor_cell.y, storey]
			
			# Skip face if neighbor is also occupied by solidblock_ (buried, not exposed)
			if neighbor_key in solidblock_occupancy:
				continue
			
			# Face is exposed: emit an edge
			var edge = Edge.between(cell, neighbor_cell, 1, material)
			
			# Track in edge_groups using the same dedup mechanism as walls
			# For solidblock edges: BOTH min_storey and max_storey are tracked (can start at >0)
			if edge.id not in edge_groups:
				edge_groups[edge.id] = {"edge_template": edge, "min_storey": storey, "max_storey": storey}
			else:
				# Update both min and max storey
				edge_groups[edge.id]["min_storey"] = mini(edge_groups[edge.id]["min_storey"], storey)
				edge_groups[edge.id]["max_storey"] = maxi(edge_groups[edge.id]["max_storey"], storey)
	
	# Third pass: convert grouped edges to final Edge objects with storey_count and start_storey
	for edge_id: String in edge_groups.keys():
		var group = edge_groups[edge_id]
		var edge_template: Edge = group["edge_template"]
		var min_storey: int = group["min_storey"]
		var max_storey: int = group["max_storey"]
		
		# storey_count = (max storey - min storey + 1)
		# start_storey = min_storey (0 for walls, can be >0 for blocks)
		var storey_count := max_storey - min_storey + 1
		var start_storey := min_storey
		
		# Create final edge with correct storey count and start_storey
		var final_edge := Edge.new(edge_template.gu_a, edge_template.gu_b, storey_count, edge_template.material, start_storey)
		result["edges"].append(final_edge)
	
	return result
