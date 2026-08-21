## Geometry Module — Edge Extractor: converts compiled map to Edge objects
## Ported from legacy geometry system; refined by SLICE-02 refactor (docs/history/)
class_name EdgeExtractor

const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

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

	# Cells that carry a "wall_" tile (exterior/room-perimeter walls). Used
	# alongside solidblock_occupancy for exposure culling: a solidblock_ cell
	# butting flush into one of these has no real gap there either.
	var wall_cells: Dictionary = {}  # Vector2i -> true
	
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
				
				wall_cells[cell] = true
				
				var face: int = _EDGE_BY_SUFFIX[suffix]
				
				# Determine the two cells involved (cell and its adjacent cell)
				var cell_a: Vector2i = cell
				var cell_b: Vector2i = cell + Face.delta(face)
				
				# Normalize to canonical order for deduplication
				# FIX-EXTERIOR-WALLS-01: exterior walls are always EXTERIOR_WALL_STOREYS tall (fixed height),
				# not derived from how many wall_levels array slots contain them (legacy N-floor stacking).
				# wall_levels now always has exactly one course (wall_tiles), so counting is unnecessary.
				var wall_storeys: int = MapCompilerClass.EXTERIOR_WALL_STOREYS
				var edge := Edge.between(cell_a, cell_b, 1, "concrete")
				
				# Assign fixed height to every exterior wall edge
				if edge.id not in edge_groups:
					edge_groups[edge.id] = {"edge_template": edge, "min_storey": 0, "max_storey": wall_storeys - 1}
				else:
					# If already tracked (shouldn't happen for walls, but guard anyway), ensure max_storey is wall_storeys-1
					edge_groups[edge.id]["max_storey"] = max(edge_groups[edge.id]["max_storey"], wall_storeys - 1)
			
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

			# Exterior/room walls are flush, full-height (up to
			# EXTERIOR_WALL_STOREYS) solid contact too — a solidblock_ cell
			# butting into one has no real gap there. Without this, a
			# divider ending flush against a wall (a true T-junction) is
			# miscounted as having an extra open face and gets wrongly
			# treated as a free corner needing a filler column.
			if wall_cells.has(neighbor_cell) and storey < MapCompilerClass.EXTERIOR_WALL_STOREYS:
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
		## M3-2b: the side has to be re-applied here. The third pass REBUILDS the
		## Edge to attach storey_count/start_storey, so anything set on the
		## template would be silently dropped — the same class of loss the
		## `edge_template` indirection has always risked, just newly reachable.
		if group.has("occupied_gu"):
			final_edge.set_occupied_gu(group["occupied_gu"])
		result["edges"].append(final_edge)

	_extract_panels(compiled, edge_groups, result)

	return result


## M3-2b — HALF-THICKNESS PANELS: a window pane, a curtain, a cardboard
## partition. One storey-face on ONE of the two GUs, authored as an absolute
## cell plus the face it points along.
##
## Emitted here rather than as a tile, because a panel is not a tile: it is a
## FACE, and every other edge in this file is born from geometry that already
## occupies a cell. A panel occupies none — that is the point of it.
##
## ⚠️ A panel whose edge ALREADY EXISTS is a loud failure, not a merge. Authoring
## a pane inside a wall that is already there is a mistake with two plausible
## meanings ("make that wall half thickness" vs "add a pane"), and guessing
## between them is exactly how the `ground_concrete`/`concrete` duplicate-row bug
## read at the time. `edge_groups` is keyed by `edge.id`, so the collision is
## detectable for free.
static func _extract_panels(compiled: Dictionary, edge_groups: Dictionary, result: Dictionary) -> void:
	var panels: Array = compiled.get("panel_instances", [])
	if panels.is_empty():
		return
	for panel in panels:
		if not (panel is Dictionary):
			continue
		var gu: Vector2i = Vector2i(panel.get("gu_cell", Vector2i.ZERO))
		var face_name: String = String(panel.get("face", "")).to_upper()
		if face_name not in _EDGE_BY_SUFFIX:
			push_error("[EdgeExtractor] panel at %s: unknown face %r — expected NW/NE/SE/SW" % [gu, face_name])
			continue
		var face: int = _EDGE_BY_SUFFIX[face_name]
		var neighbour: Vector2i = gu + Face.delta(face)
		var storeys: int = maxi(1, int(panel.get("storeys", 1)))
		var start_storey: int = maxi(0, int(panel.get("start_storey", 0)))
		var material: String = String(panel.get("material", "glass"))

		var edge := Edge.between(gu, neighbour, storeys, material, start_storey)
		if edge_groups.has(edge.id):
			push_error("[EdgeExtractor] panel at %s face %s collides with an existing wall edge (%s) — a pane cannot share a face with a wall. Remove one, or make the wall itself the panel."
				% [gu, face_name, edge.id])
			continue
		## The authored cell, resolved AFTER Edge.between()'s canonicalisation.
		## This is the line the whole schema decision exists to make correct.
		if not edge.set_occupied_gu(gu):
			continue
		edge_groups[edge.id] = {"edge_template": edge, "min_storey": start_storey,
			"max_storey": start_storey + storeys - 1, "occupied_gu": gu}
		result["edges"].append(edge)
