## ShadowProjector — Grid-based shadow projection engine
##
## Computes shadow topology for a single light source.
## 
## Features:
## - Deterministic grid projection
## - Height-aware occlusion
## - Simple ray casting (no complex physics)
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

## Maximum shadow length (in tiles) from light source
const SHADOW_LENGTH_MAX := 8

## 8-direction quantization for deterministic ray casting
const SHADOW_DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

## Reference to blocked cells dictionary (walls, obstacles)
var blocked_cells: Dictionary = {}

## Reference to room size for boundary checking
var room_size: Vector2i = Vector2i.ZERO

## Obstacle heights by cell (from tile types)
var obstacle_heights: Dictionary = {}

## Default obstacle height (if not in dictionary)
const OBSTACLE_HEIGHT_DEFAULT := 1.5

func _ready() -> void:
	pass  # Passive service; initialized externally

## Main entry point: compute shadow result for one light
func project_light(light):
	if light == null or not light.active:
		return ShadowResultClass.new(light)
	
	var result = ShadowResultClass.new(light)
	
	# Phase 1: Direct illumination from light source
	_project_direct_light(light, result)
	
	# Phase 2: Shadow casting from obstacles
	_project_shadows(light, result)
	
	return result

## Phase 1: Mark all tiles in light radius as illuminated
func _project_direct_light(light, result) -> void:
	var light_pos: Vector2i = light.cell
	var radius: int = light.radius
	
	# Iterate all cells within radius
	for x in range(light_pos.x - radius, light_pos.x + radius + 1):
		for y in range(light_pos.y - radius, light_pos.y + radius + 1):
			var cell = Vector2i(x, y)
			
			# Boundary check
			if not _is_cell_inside_room(cell):
				continue
			
			# Distance check (inclusive radius boundary)
			var dist = light_pos.distance_to(cell)
			if dist > float(radius):
				continue
			
			# Slightly prefer closer tiles (will be overridden by shadows)
			result.add_tile(cell, "fully_lit")

## Phase 2: Cast shadows from blocked cells
func _project_shadows(light, result) -> void:
	var light_pos: Vector2i = light.cell
	var light_height: int = light.height_class  # Used for height comparison
	
	# Iterate blocked cells (walls, obstacles)
	for blocked_cell in blocked_cells.keys():
		var obstacle_height: int = _get_obstacle_height_class(blocked_cell)
		
		# Obstacle must be higher than light to cast shadow
		# (or equal height and blocking line of sight)
		if obstacle_height < light_height:
			continue
		
		# Distance check: only shadow within projected range
		var dist_vec: Vector2i = blocked_cell - light_pos
		var dist: float = dist_vec.length()
		if dist < 0.1 or dist > float(SHADOW_LENGTH_MAX):
			continue
		
		# Cast shadow ray from light through obstacle
		_cast_shadow_ray(light, blocked_cell, result)

## Cast a shadow ray in direction away from light
func _cast_shadow_ray(light, obstacle_cell: Vector2i, result) -> void:
	var light_pos: Vector2i = light.cell
	var direction_vec: Vector2i = obstacle_cell - light_pos
	
	# Quantize to nearest cardinal/diagonal direction (for determinism)
	var quantized_dir: Vector2i = _quantize_direction(direction_vec)
	
	# Project shadow along this ray
	var shadow_length: int = SHADOW_LENGTH_MAX
	var current_cell: Vector2i = obstacle_cell + quantized_dir
	
	for step in range(shadow_length):
		if not _is_cell_inside_room(current_cell):
			break
		
		# Stop if we hit another obstacle
		if blocked_cells.has(current_cell):
			break
		
		# Mark as shadow
		result.add_tile(current_cell, "shadow")
		
		# Next cell along ray
		current_cell += quantized_dir

## Quantize direction vector to nearest 8-direction
func _quantize_direction(vec: Vector2i) -> Vector2i:
	if vec == Vector2i.ZERO:
		return Vector2i.DOWN
	
	var angle: float = atan2(float(vec.y), float(vec.x))
	var idx: int = int(round(angle / (PI / 4.0))) % 8
	var clamped_idx: int = ((idx % 8) + 8) % 8
	
	return SHADOW_DIRS[clamped_idx]

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

## Set reference to obstacle heights (call from room.gd)
func set_obstacle_heights(heights: Dictionary) -> void:
	obstacle_heights = heights

## Set room size (call from room.gd)
func set_room_size(size: Vector2i) -> void:
	room_size = size
