## Geometry Module — Edge Extractor: converts compiled map to Edge objects
## Port from subcube_geometry.gd build() logic
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
static func extract(compiled: Dictionary) -> Dictionary:
	var result := {
		"edges": [],
		"solid_blocks": []
	}
	
	if not compiled.has("wall_levels"):
		return result
	
	var wall_levels: Array = compiled["wall_levels"]
	
	# Dictionary to merge duplicate edges by their canonical id
	# When the same physical edge is emitted from both adjacent GUs, take the max storey
	var edge_groups: Dictionary = {}  # edge_canonical_key → {"edge_template": Edge, "max_storey": int}
	
	# First pass: collect all edges with storey levels
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
				
				# Track max storey for this edge
				if edge.id not in edge_groups:
					edge_groups[edge.id] = {"edge_template": edge, "max_storey": storey}
				else:
					# Update max storey
					edge_groups[edge.id]["max_storey"] = max(edge_groups[edge.id]["max_storey"], storey)
			
			# Solid blocks: "block_concrete", "block_metal", etc.
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
	
	# Second pass: convert grouped edges to final Edge objects with storey_count
	for edge_id: String in edge_groups.keys():
		var group = edge_groups[edge_id]
		var edge_template: Edge = group["edge_template"]
		var max_storey: int = group["max_storey"]
		
		# storey_count = max storey index + 1 (since storey is 0-indexed)
		var storey_count := max_storey + 1
		
		# Create final edge with correct storey count
		var final_edge := Edge.new(edge_template.gu_a, edge_template.gu_b, storey_count, "concrete")
		result["edges"].append(final_edge)
	
	return result
