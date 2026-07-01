class_name VoxelRegistry
extends RefCounted
## Centralized registry for all voxel wall containers.
## Responsibilities:
## ✓ Store WallSlice instances with string-based lookup
## ✓ Store HighWall instances with string-based lookup
## ✓ Build HighWall aggregates from WallSlice + JunctionExtra data
## ✓ Provide iteration API for TIC loop and baking system
## Does NOT:
## ✗ Render voxels (TileMapLayer handles that)
## ✗ Calculate dirty flags (VoxelRef/WallSlice/HighWall handle that)
## ✗ Apply state changes (TIC loop handles that)
## Pure data storage and queries for the voxel system.

const WallSliceClass   = preload("res://godot/scripts/world/wall_slice.gd")
const HighWallClass    = preload("res://godot/scripts/world/high_wall.gd")
const VoxelRefClass    = preload("res://godot/scripts/world/voxel_ref.gd")

var _slices: Dictionary = {}          # slice_id (String) → WallSlice
var _high_walls: Dictionary = {}      # high_wall_id (String) → HighWall
var _max_voxels_per_level: int = 0

signal slice_registered(slice)
signal high_wall_registered(high_wall)


func setup(max_voxels_per_level: int) -> void:
	## Initialize registry with max voxels per level (used for validation).
	_max_voxels_per_level = max_voxels_per_level
	_slices.clear()
	_high_walls.clear()


func register_slice(slice: WallSlice) -> void:
	## Register a WallSlice in the index. Called from _place_wall_voxels().
	if slice.id.is_empty():
		push_warning("VoxelRegistry: attempt to register slice with empty id")
		return
	_slices[slice.id] = slice
	slice_registered.emit(slice)


func register_high_wall(high_wall: HighWall) -> void:
	## Register a HighWall in the index. Called from _build_high_walls().
	if high_wall.id.is_empty():
		push_warning("VoxelRegistry: attempt to register high_wall with empty id")
		return
	_high_walls[high_wall.id] = high_wall
	high_wall_registered.emit(high_wall)


func get_slice(slice_id: String) -> WallSlice:
	## Retrieve a WallSlice by id. Returns null if not found.
	return _slices.get(slice_id, null)


func get_high_wall(high_wall_id: String) -> HighWall:
	## Retrieve a HighWall by id. Returns null if not found.
	return _high_walls.get(high_wall_id, null)


func all_slices() -> Array[WallSlice]:
	## Return all registered WallSlices. Used by TIC loop.
	var result: Array[WallSlice] = []
	for slice in _slices.values():
		result.append(slice)
	return result


func all_high_walls() -> Array[HighWall]:
	## Return all registered HighWalls. Used by TIC loop and baking.
	var result: Array[HighWall] = []
	for hw in _high_walls.values():
		result.append(hw)
	return result


func total_slices() -> int:
	## Total count of registered slices.
	return _slices.size()


func total_high_walls() -> int:
	## Total count of registered high walls.
	return _high_walls.size()


func is_empty() -> bool:
	## True if no containers registered.
	return _slices.is_empty() and _high_walls.is_empty()


func clear() -> void:
	## Clear all registrations. Called on room rebuild.
	_slices.clear()
	_high_walls.clear()
