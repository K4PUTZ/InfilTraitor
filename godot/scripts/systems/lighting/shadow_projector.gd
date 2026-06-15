## ShadowProjector — Line-of-Sight based shadow projection engine
##
## Computes shadow topology for a single light source using LOS classification.
## 
## Core rule: A cell in light range is fully_lit if LOS to it is clear,
## shadow if LOS is blocked by obstacle or wall edge.
##
## Features:
## - LOS-based occlusion (not quantized ray casting)
## - Wall edge checking via WallEdgeData
## - Cone/directional angle filtering
## - Penumbra pass for adjacent transitions
## - Auditable tile-by-tile results
##
## Does NOT:
## - blend shadows from multiple lights (caller does merge)
## - cache results (caller manages ShadowResult lifetime)
## - render visualization (that's ShadowOverlay's job)
## - perform soft/volumetric effects (future M2-15)

class_name ShadowProjector
extends Node

const ShadowResultClass = preload("res://godot/scripts/systems/lighting/shadow_result.gd")
const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")
const WallEdgeDataClass = preload("res://godot/scripts/world/wall_edge_data.gd")

## Reference to blocked cells dictionary (walls, obstacles)
var blocked_cells: Dictionary = {}

## Reference to blocked edges (walls between tiles)
var blocked_edges: Dictionary = {}

## Reference to room size for boundary checking
var room_size: Vector2i = Vector2i.ZERO

## Obstacle heights by cell (from tile types)
var obstacle_heights: Dictionary = {}

## Default obstacle height (if not in dictionary)
const OBSTACLE_HEIGHT_DEFAULT := 1.5

## Falloff ratio: cells within radius * near_band_ratio are fully_lit; beyond are dim
var near_band_ratio: float = 0.65

## Radius (Chebyshev) for deep_shadow classification (no adjacent lit cells)
var deep_shadow_radius: int = 2

## Minimum obstacle height to block light (below this, floor doesn't occlude)
var min_blocker_height: int = 1

func _ready() -> void:
	pass  # Passive service; initialized externally

## Main entry point: compute shadow result for one light via LOS classification
func project_light(light):
	if light == null or not light.active:
		return ShadowResultClass.new(light)
	
	var result = ShadowResultClass.new(light)
	
	# Phase 1: LOS-based classification (fully_lit / dim vs shadow)
	_classify_by_los(light, result)
	
	# Phase 2: Penumbra pass (shadow adjacent to fully_lit/dim → penumbra)
	_apply_penumbra_pass(result)
	
	# Phase 3: Deep shadow pass (shadow far from all lit → deep_shadow)
	_apply_deep_shadow_pass(result)
	
	return result

## Phase 1: Classify each cell as fully_lit or shadow based on LOS
func _classify_by_los(light, result) -> void:
	var light_pos: Vector2i = light.cell
	var radius: int = light.radius
	var light_type: String = light.light_type if light.has_method("get") or light.light_type != null else "omni"
	var cone_angle: float = light.cone_angle if light.has_method("get") or light.cone_angle != null else 60.0
	var light_direction_angle: float = light.direction_angle if light.has_method("get") or light.direction_angle != null else 0.0
	
	# Iterate all cells within radius
	for x in range(light_pos.x - radius, light_pos.x + radius + 1):
		for y in range(light_pos.y - radius, light_pos.y + radius + 1):
			var cell = Vector2i(x, y)
			
			# Boundary check
			if not _is_cell_inside_room(cell):
				continue
			
			# Skip light source itself
			if cell == light_pos:
				result.add_tile(cell, "fully_lit")
				continue
			
			# Distance check
			var dist = light_pos.distance_to(cell)
			if dist > float(radius):
				continue
			
			# Cone/directional angle check
			if light_type in ["cone", "directional"]:
				var cell_angle: float = atan2(float(cell.y - light_pos.y), float(cell.x - light_pos.x))
				var half_angle: float = deg_to_rad(cone_angle) / 2.0
				var angle_diff: float = _angle_difference(cell_angle, light_direction_angle)
				if abs(angle_diff) > half_angle:
					continue  # Outside cone, not classified
			
			# LOS classification with falloff
			if _los_blocked(light_pos, cell, light):
				result.add_tile(cell, "shadow")
			else:
				# Apply near-band falloff: close cells fully_lit, far cells dim
				var threshold: float = float(radius) * near_band_ratio
				if dist <= threshold:
					result.add_tile(cell, "fully_lit")
				else:
					result.add_tile(cell, "dim")

## Phase 2: Shadow tiles adjacent to fully_lit become penumbra
func _apply_penumbra_pass(result) -> void:
	var penumbra_cells: Array[Vector2i] = []
	
	# Find all shadow cells
	for shadow_cell in result.shadow_tiles.keys():
		# Check 4-neighborhood for fully_lit
		var neighbors: Array[Vector2i] = [
			shadow_cell + Vector2i.UP,
			shadow_cell + Vector2i.DOWN,
			shadow_cell + Vector2i.LEFT,
			shadow_cell + Vector2i.RIGHT,
		]
		
		for neighbor in neighbors:
			if result.fully_lit_tiles.has(neighbor):
				# This shadow is adjacent to fully_lit → penumbra
				penumbra_cells.append(shadow_cell)
				break
	
	# Re-classify penumbra cells
	for cell in penumbra_cells:
		result.shadow_tiles.erase(cell)
		result.add_tile(cell, "penumbra")

## Phase 3: Classify isolated shadow as deep_shadow
func _apply_deep_shadow_pass(result) -> void:
	var deep_shadow_cells: Array[Vector2i] = []
	
	# Find all shadow cells (penumbra is NOT shadow anymore after phase 2)
	for shadow_cell in result.shadow_tiles.keys():
		# Check Chebyshev radius around shadow cell for ANY lit cell (fully_lit or dim)
		var has_adjacent_lit: bool = false
		
		for dx in range(-deep_shadow_radius, deep_shadow_radius + 1):
			for dy in range(-deep_shadow_radius, deep_shadow_radius + 1):
				if dx == 0 and dy == 0:
					continue  # Skip self
				
				var check_cell: Vector2i = shadow_cell + Vector2i(dx, dy)
				
				# If any adjacent lit cell exists, keep as shadow (not deep_shadow)
				if result.fully_lit_tiles.has(check_cell) or result.dim_tiles.has(check_cell):
					has_adjacent_lit = true
					break
			
			if has_adjacent_lit:
				break
		
		# If NO lit cells in Chebyshev radius, mark as deep_shadow
		if not has_adjacent_lit:
			deep_shadow_cells.append(shadow_cell)
	
	# Re-classify deep shadow cells
	for cell in deep_shadow_cells:
		result.shadow_tiles.erase(cell)
		result.add_tile(cell, "deep_shadow")

## Check if obstacle height blocks light from given light height
func _obstacle_blocks_light(obstacle_h: int, light_h: int) -> bool:
	# Floor never blocks
	if obstacle_h < min_blocker_height:
		return false
	
	# Low cover doesn't block overhead light (can see over it)
	if obstacle_h < 2 and light_h >= 4:  # HEIGHT_HUMAN=2, HEIGHT_OVERHEAD=4
		return false
	
	# All other cases: obstacle blocks light
	return true

## Check if LOS from light to target is blocked
## Check if LOS from light to target is blocked (height-aware occlusion)
func _los_blocked(light_pos: Vector2i, target: Vector2i, light) -> bool:
	# Get light height for occlusion check (default HEIGHT_HUMAN=2)
	var light_height: int = light.height_class if light.has_method("get") or light.height_class != null else 2
	
	# March line from light to target using Bresenham
	var path: Array[Vector2i] = _bresenham_line(light_pos, target)
	
	# Check each cell along the path (excluding endpoints)
	for i in range(1, path.size() - 1):
		var cell = path[i]
		
		# Check if cell is blocked AND blocks light (height-aware)
		if blocked_cells.has(cell):
			var obstacle_height: int = _get_obstacle_height_class(cell)
			if _obstacle_blocks_light(obstacle_height, light_height):
				return true
	
	# Check edges along path for wall-blocking
	for i in range(path.size() - 1):
		var from_cell = path[i]
		var to_cell = path[i + 1]
		
		# Adjacent cells: check if edge is blocked
		if _are_adjacent(from_cell, to_cell):
			if WallEdgeDataClass.blocks_los(from_cell, to_cell, blocked_edges):
				return true
	
	return false

## Bresenham line algorithm - march from start to end
func _bresenham_line(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x: int = start.x
	var y: int = start.y
	var dx: int = abs(end.x - start.x)
	var dy: int = abs(end.y - start.y)
	var sx: int = 1 if end.x > start.x else -1
	var sy: int = 1 if end.y > start.y else -1
	var err: int = dx - dy
	
	while true:
		result.append(Vector2i(x, y))
		if x == end.x and y == end.y:
			break
		
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	
	return result

## Check if two cells are adjacent (4-neighborhood)
func _are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

## Normalize angle difference to [-PI, PI]
func _angle_difference(a: float, b: float) -> float:
	var diff: float = a - b
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff

## Get height class for obstacle (or default)
func _get_obstacle_height_class(cell: Vector2i) -> int:
	# If explicitly set, use it
	if obstacle_heights.has(cell):
		var h = obstacle_heights[cell]
		if h is int:
			return h
		# Convert float to height class
		if h >= 3.0:
			return 3  # Tall structure
		if h >= 2.0:
			return 2  # Human height
		if h >= 1.0:
			return 1  # Low cover
		return 0
	
	# Default: assume human-height obstacle
	return 2

## Boundary check
func _is_cell_inside_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < room_size.x and cell.y < room_size.y

## Set reference to blocked cells (call from room.gd)
func set_blocked_cells(cells: Dictionary) -> void:
	blocked_cells = cells

## Set reference to blocked edges (call from room.gd)
func set_blocked_edges(edges: Dictionary) -> void:
	blocked_edges = edges

## Set reference to obstacle heights (call from room.gd)
func set_obstacle_heights(heights: Dictionary) -> void:
	obstacle_heights = heights

## Set room size (call from room.gd)
func set_room_size(size: Vector2i) -> void:
	room_size = size
