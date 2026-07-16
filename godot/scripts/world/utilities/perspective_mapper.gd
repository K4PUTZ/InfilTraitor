## Perspective Mapper: static utility for isometric perspective transformations.
## Handles direction-based cell coordinate conversions and tile name suffix remapping.
## Extracted from room.gd (Task 04 modularization).
class_name PerspectiveMapper


## Suffix remapping for tile names across the 4 compass directions.
## E.g., tile_name "wall_NE" becomes "wall_SE" when viewed from East (E).
const SUFFIX_MAP := {
	"N": {"NE": "NE", "SE": "SE", "SW": "SW", "NW": "NW"},
	"E": {"NE": "SE", "SE": "SW", "SW": "NW", "NW": "NE"},
	"S": {"NE": "SW", "SE": "NW", "SW": "NE", "NW": "SE"},
	"W": {"NE": "NW", "SE": "NE", "SW": "SE", "NW": "SW"},
}


## Convert a view-space cell to base (North) orientation.
## Applies rotation based on direction:
##   "N" (North): identity
##   "E" (East): 90° CW → (y, h-1-x)
##   "S" (South): 180° → (w-1-x, h-1-y)
##   "W" (West): 270° CW → (w-1-y, x)
static func cell_to_base(view_cell: Vector2i, direction: String, base_size: Vector2i) -> Vector2i:
	if view_cell == Vector2i(-1, -1):  # INVALID_CELL
		return Vector2i(-1, -1)
	
	var w := base_size.x
	var h := base_size.y
	
	match direction:
		"E":
			return Vector2i(view_cell.y, h - 1 - view_cell.x)
		"S":
			return Vector2i(w - 1 - view_cell.x, h - 1 - view_cell.y)
		"W":
			return Vector2i(w - 1 - view_cell.y, view_cell.x)
		_:
			return view_cell


## Remap tile suffix from base (N) to target direction.
## Parses tile_name as "base_SUFFIX" and replaces SUFFIX per SUFFIX_MAP[direction].
## Returns unchanged name if not recognized.
static func remap_tile_name(tile_name: String, direction: String) -> String:
	if tile_name.is_empty():
		return tile_name
	
	var i := tile_name.rfind("_")
	if i < 0:
		return tile_name
	
	var base := tile_name.substr(0, i)
	var suffix := tile_name.substr(i + 1)
	
	if not SUFFIX_MAP.has(direction):
		return tile_name
	
	var suffix_map: Dictionary = SUFFIX_MAP[direction]
	if not suffix_map.has(suffix):
		return tile_name
	
	return "%s_%s" % [base, String(suffix_map[suffix])]


## Query whether direction is valid (in SUFFIX_MAP).
static func is_valid_direction(direction: String) -> bool:
	return SUFFIX_MAP.has(direction)


## Quarter-turn applied to directional light angles, matching `cell_from_base`.
static func perspective_angle_delta_deg(direction: String) -> float:
	match direction:
		"E": return 90.0
		"S": return 180.0
		"W": return -90.0
		_: return 0.0


## Size of the room as seen in view-space (swaps w/h for E and W).
static func rotated_size(base_size: Vector2i, direction: String) -> Vector2i:
	if direction == "E" or direction == "W":
		return Vector2i(base_size.y, base_size.x)
	return base_size


## Convert a base (North) cell to view-space, given the active direction.
## Inverse of cell_to_base — see that function's docstring for the rotation
## table. INVALID_CELL is the room.gd sentinel Vector2i(-1, -1).
static func cell_from_base(base_cell: Vector2i, direction: String, base_size: Vector2i) -> Vector2i:
	if base_cell == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var w := base_size.x
	var h := base_size.y
	match direction:
		"E":
			return Vector2i(h - 1 - base_cell.y, base_cell.x)
		"S":
			return Vector2i(w - 1 - base_cell.x, h - 1 - base_cell.y)
		"W":
			return Vector2i(base_cell.y, w - 1 - base_cell.x)
		_:
			return base_cell


## Full layout rotation: size, every cell field, every tile-name suffix, AND
## the two fields Task 04 dropped — enemy patrol routes and directional-light
## angles. This is the single place that performs a perspective rotation;
## room.gd and RoomBuilder must not reimplement any part of it.
static func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:
	var mapped := layout.duplicate(true)
	var base_size: Vector2i = layout.get("size", Vector2i.ZERO)
	mapped["size"] = rotated_size(base_size, direction)
	mapped["agent_start_cell"] = cell_from_base(layout.get("agent_start_cell", Vector2i.ZERO), direction, base_size)
	mapped["floor_tile_name"] = remap_tile_name(
		String(layout.get("floor_tile_name", "floor_SE")), direction)

	for key in ["wall_tiles", "structure_tiles"]:
		var src: Array = layout.get(key, [])
		var dst: Array = []
		for entry in src:
			var out := (entry as Dictionary).duplicate(true)
			out["cell"] = cell_from_base(out.get("cell", Vector2i(-1, -1)), direction, base_size)
			out["tile_name"] = remap_tile_name(String(out.get("tile_name", "")), direction)
			dst.append(out)
		mapped[key] = dst

	## Rotate every wall storey (wall_levels[f]); wall_tiles above stays == wall_levels[0].
	var rotated_levels: Array = []
	for level_src in layout.get("wall_levels", []):
		var level_dst: Array = []
		for entry in level_src:
			var out := (entry as Dictionary).duplicate(true)
			out["cell"] = cell_from_base(out.get("cell", Vector2i(-1, -1)), direction, base_size)
			out["tile_name"] = remap_tile_name(String(out.get("tile_name", "")), direction)
			level_dst.append(out)
		rotated_levels.append(level_dst)
	mapped["wall_levels"] = rotated_levels

	var blocked_cells: Array[Vector2i] = []
	for cell in layout.get("blocked_cells", []):
		blocked_cells.append(cell_from_base(cell, direction, base_size))
	mapped["blocked_cells"] = blocked_cells

	var blocked_edges: Array[Dictionary] = []
	for edge in layout.get("blocked_edges", []):
		blocked_edges.append({
			"from": cell_from_base(edge.get("from", Vector2i.ZERO), direction, base_size),
			"to": cell_from_base(edge.get("to", Vector2i.ZERO), direction, base_size),
		})
	mapped["blocked_edges"] = blocked_edges

	## Enemy defs: start_cell AND route rotate. Task 04's room_builder.gd copy
	## dropped route — that was the guard-patrol half of the reported bug.
	var enemy_defs: Array[Dictionary] = []
	for def in layout.get("enemy_defs", []):
		var out := (def as Dictionary).duplicate(true)
		out["start_cell"] = cell_from_base(out.get("start_cell", Vector2i.ZERO), direction, base_size)
		var route: Array[Vector2i] = []
		for cell in def.get("route", []):
			route.append(cell_from_base(cell, direction, base_size))
		out["route"] = route
		enemy_defs.append(out)
	mapped["enemy_defs"] = enemy_defs

	var exit_cells: Array[Vector2i] = []
	for cell in layout.get("exit_cells", []):
		exit_cells.append(cell_from_base(cell, direction, base_size))
	mapped["exit_cells"] = exit_cells

	## Map lights rotate by cell; directional/cone lights also rotate their angle
	## by the same quarter-turn so the cone covers the same (rotated) cells.
	## This angle line is the other half of the reported bug — absent in
	## room_builder.gd because perspective_angle_delta_deg didn't exist there.
	var angle_delta_deg := perspective_angle_delta_deg(direction)
	var light_sources: Array = []
	for light in layout.get("light_sources", []):
		var out := (light as Dictionary).duplicate(true)
		var rotated := cell_from_base(Vector2i(int(out.get("x", 0)), int(out.get("y", 0))), direction, base_size)
		out["x"] = rotated.x
		out["y"] = rotated.y
		if out.has("direction_deg"):
			out["direction_deg"] = fmod(float(out["direction_deg"]) + angle_delta_deg + 360.0, 360.0)
		light_sources.append(out)
	mapped["light_sources"] = light_sources

	## ROOF-BAKE-02a: solid_block_instances and voxel_prop_instances used to
	## pass through duplicate(true) UNROTATED while the walls they were
	## expanded into (structure_tiles / wall_levels above) rotated — so
	## anything consuming instance positions per-view (the roof slabs, first
	## visible casualty) landed on the WRONG structure in E/S/W views.
	##
	## A block footprint is a rectangle (gu_cell = NW corner + size), so its
	## rotated form is the axis-aligned box over the two rotated opposite
	## corners: origin = component-wise min, size = rotated_size(). Quarter
	## turns map rectangles to rectangles — no cell enumeration needed.
	var rotated_blocks: Array[Dictionary] = []
	for block in layout.get("solid_block_instances", []):
		var out := (block as Dictionary).duplicate(true)
		var base_gu: Vector2i = out.get("gu_cell", Vector2i.ZERO)
		var block_size: Vector2i = out.get("size", Vector2i.ONE)
		var c0 := cell_from_base(base_gu, direction, base_size)
		var c1 := cell_from_base(base_gu + block_size - Vector2i.ONE, direction, base_size)
		out["gu_cell"] = Vector2i(mini(c0.x, c1.x), mini(c0.y, c1.y))
		out["size"] = rotated_size(block_size, direction)
		rotated_blocks.append(out)
	mapped["solid_block_instances"] = rotated_blocks

	## Props rotate as points: every shipped PropDef has footprint_gus ==
	## [(0, 0)] (1×1), so gu_cell alone places them correctly. A future
	## multi-GU prop needs footprint-aware rotation here (the offsets live in
	## PropDef, which this static mapper deliberately has no registry access
	## to) — extend THIS function then, not the consumer.
	var rotated_props: Array = []
	for prop in layout.get("voxel_prop_instances", []):
		var out := (prop as Dictionary).duplicate(true)
		out["gu_cell"] = cell_from_base(out.get("gu_cell", Vector2i.ZERO), direction, base_size)
		rotated_props.append(out)
	mapped["voxel_prop_instances"] = rotated_props

	var buffer: int = layout.get("buffer", 0)
	mapped["buffer"] = buffer
	return mapped
