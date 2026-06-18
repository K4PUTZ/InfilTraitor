## ShadowProjector — Geometric (tiered + penumbra) floor-shadow projection
##
## For each light, classifies reachable cells (clear LOS within radius) as
## fully_lit / dim, then casts a *geometric* shadow from each occluding object:
## the shadow falls in the grid direction away from the light, with a length
## derived from object-height tier × light-height factor × a mild distance
## stretch (deterministic, not random). The shadow tip softens to penumbra.
##
## Slice 1 (VIS-01): object shadows from blocked_cells. Wall-edge floor shadows
## and multi-tile silhouette width are future work.
##
## Does NOT:
## - blend shadows from multiple lights (ExposureSystem max-merges per cell)
## - cache results (caller manages ShadowResult lifetime)
## - render visualization (that's ShadowOverlay's job)

class_name ShadowProjector
extends Node

const ShadowResultClass = preload("res://godot/scripts/systems/lighting/shadow_result.gd")
const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")
const WallEdgeDataClass = preload("res://godot/scripts/world/wall_edge_data.gd")

## Reference to blocked cells dictionary (objects/props that occlude + cast)
var blocked_cells: Dictionary = {}

## Reference to blocked edges (walls between tiles) — used for LOS reach
var blocked_edges: Dictionary = {}

## Reference to room size for boundary checking
var room_size: Vector2i = Vector2i.ZERO

## Obstacle height classes by cell (from tile semantics)
var obstacle_heights: Dictionary = {}

## Falloff ratio: cells within radius * near_band_ratio are fully_lit; beyond are dim
var near_band_ratio: float = 0.65

## Minimum obstacle height to occlude the light's reach (LOS)
var min_blocker_height: int = 1

## --- Geometric shadow tunables (stats → var, not const; scale with tiers) ---
## Base shadow length (tiles) by object height class.
var height_tier_length: Dictionary = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4}
## Light-height factor: a higher light casts a shorter shadow.
var light_height_factor: Dictionary = {0: 1.6, 1: 1.4, 2: 1.2, 3: 0.9, 4: 0.6}
## Mild lengthening with light→object distance (grazing rays reach further).
var distance_stretch: float = 0.06
## Hard cap on a projected shadow's length.
var max_shadow_length: int = 6

func _ready() -> void:
	pass  # Passive service; initialized externally

## Main entry point: compute shadow result for one light
func project_light(light):
	if light == null or not light.active:
		return ShadowResultClass.new(light)

	var result = ShadowResultClass.new(light)
	_classify_reach(light, result)          # Phase 1: lit / dim
	_cast_geometric_shadows(light, result)  # Phase 2: object shadows (+ tip penumbra)
	return result

## Phase 1: cells with clear LOS within radius become fully_lit / dim.
func _classify_reach(light, result) -> void:
	var light_pos: Vector2i = light.cell
	var radius: int = light.radius
	var light_type: String = light.light_type
	var dir_angle: float = light.direction_angle
	var cone_angle: float = light.cone_angle

	for x in range(light_pos.x - radius, light_pos.x + radius + 1):
		for y in range(light_pos.y - radius, light_pos.y + radius + 1):
			var cell := Vector2i(x, y)
			if not _is_cell_inside_room(cell):
				continue
			if cell == light_pos:
				result.add_tile(cell, "fully_lit")
				continue
			var dist: float = light_pos.distance_to(cell)
			if dist > float(radius):
				continue
			if light_type in ["cone", "directional"]:
				if not _within_cone(light_pos, cell, dir_angle, cone_angle):
					continue
			# Only directly-lit (clear-LOS) cells are illuminated.
			if _los_blocked(light_pos, cell, light):
				continue
			if dist <= float(radius) * near_band_ratio:
				result.add_tile(cell, "fully_lit")
			else:
				result.add_tile(cell, "dim")

## Phase 2: cast a geometric shadow from each occluding object.
## A shadow is cast for any object with height tier > 0 (a crate casts a short
## shadow even if a guard can see over it — that is the LOS gate, not this one).
func _cast_geometric_shadows(light, result) -> void:
	var light_pos: Vector2i = light.cell
	var radius: int = light.radius
	var light_h: int = light.height_class
	var light_type: String = light.light_type
	var dir_angle: float = light.direction_angle
	var cone_angle: float = light.cone_angle

	for obstacle in blocked_cells.keys():
		var delta := Vector2(obstacle - light_pos)
		var dist: float = delta.length()
		if dist < 0.5 or dist > float(radius):
			continue
		if light_type in ["cone", "directional"]:
			if not _within_cone(light_pos, obstacle, dir_angle, cone_angle):
				continue
		var obj_h: int = _get_obstacle_height_class(obstacle)
		var length: int = _shadow_length(obj_h, light_h, dist)
		if length <= 0:
			continue
		_stamp_shadow_line(result, light_pos, obstacle, length)

## Deterministic shadow length: object-height tier × light-height factor × distance.
func _shadow_length(obj_h: int, light_h: int, dist: float) -> int:
	var base: float = float(height_tier_length.get(obj_h, obj_h))
	if base <= 0.0:
		return 0
	var lh: int = clampi(light_h, 0, 4)
	var lfac: float = float(light_height_factor.get(lh, 1.0))
	var stretch: float = 1.0 + dist * distance_stretch
	return clampi(int(round(base * lfac * stretch)), 1, max_shadow_length)

## Stamp the shadow line away from the light; the tip softens to penumbra.
func _stamp_shadow_line(result, light_pos: Vector2i, obstacle: Vector2i, length: int) -> void:
	var dir := Vector2(obstacle - light_pos).normalized()
	var pos := Vector2(obstacle)
	var prev: Vector2i = obstacle
	for i in range(1, length + 1):
		pos += dir
		var cell := Vector2i(roundi(pos.x), roundi(pos.y))
		if cell == prev:
			continue
		prev = cell
		if not _is_cell_inside_room(cell):
			break
		if blocked_cells.has(cell):
			continue  # don't shadow another solid object
		if i == length and length >= 2:
			result.add_tile(cell, "penumbra")  # soft tip
		else:
			result.add_tile(cell, "shadow")

## --- LOS / occlusion helpers (reach phase) -------------------------------

## Whether an obstacle of given height blocks the light's REACH (LOS).
func _obstacle_blocks_light(obstacle_h: int, light_h: int) -> bool:
	if obstacle_h < min_blocker_height:
		return false
	if obstacle_h < 2 and light_h >= 4:  # can see over low cover from overhead
		return false
	return true

## Whether LOS from light to target is blocked (height-aware).
func _los_blocked(light_pos: Vector2i, target: Vector2i, light) -> bool:
	var light_height: int = light.height_class
	var path: Array[Vector2i] = _bresenham_line(light_pos, target)
	for i in range(1, path.size() - 1):
		var cell := path[i]
		if blocked_cells.has(cell):
			if _obstacle_blocks_light(_get_obstacle_height_class(cell), light_height):
				return true
	for i in range(path.size() - 1):
		if _are_adjacent(path[i], path[i + 1]):
			if WallEdgeDataClass.blocks_los(path[i], path[i + 1], blocked_edges):
				return true
	return false

## --- Geometry primitives -------------------------------------------------

func _within_cone(light_pos: Vector2i, cell: Vector2i, dir_angle: float, cone_angle_deg: float) -> bool:
	var cell_angle: float = atan2(float(cell.y - light_pos.y), float(cell.x - light_pos.x))
	var half: float = deg_to_rad(cone_angle_deg) / 2.0
	return abs(_angle_difference(cell_angle, dir_angle)) <= half

## Bresenham line algorithm — march from start to end
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

## Get height class for obstacle (or default to human height)
func _get_obstacle_height_class(cell: Vector2i) -> int:
	if obstacle_heights.has(cell):
		var h = obstacle_heights[cell]
		if h is int:
			return h
		if h >= 3.0:
			return 3
		if h >= 2.0:
			return 2
		if h >= 1.0:
			return 1
		return 0
	return 2

## Boundary check
func _is_cell_inside_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < room_size.x and cell.y < room_size.y

## --- Setters (call from LightingController) -------------------------------

func set_blocked_cells(cells: Dictionary) -> void:
	blocked_cells = cells

func set_blocked_edges(edges: Dictionary) -> void:
	blocked_edges = edges

func set_obstacle_heights(heights: Dictionary) -> void:
	obstacle_heights = heights

func set_room_size(size: Vector2i) -> void:
	room_size = size
