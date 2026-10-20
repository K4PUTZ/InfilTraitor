## VoxelWeakness — the voxels a corrosive liquid has eaten into (M6, Director 2026-10-19: corrosion WEAKENS a voxel). A weakened voxel keeps its look (the
## corrosion mark is its CRACKED decal) and its place, but breaks easier: a shot or a pellet that lands on it punches `punch_gain` times harder, and a
## blast ring that reaches it (destroy weight above zero) takes it whole.
##
## It is a sparse set keyed by the voxel's addressing (`grid_pos.x`, `grid_pos.y`, `level`), the same key `Room._base_damage` uses, so it survives rotation
## (camera-only) and rides the checkpoint (`SaveState` "weakened"). Static, like the other catalogues the destruction code reads: one world at a time, the room
## clears it with the map.
##
## No class_name on purpose: a new class_name is invisible to a headless run until the editor rebuilds the global class cache (callers preload this file).
extends RefCounted

## How much harder a round lands on a weakened voxel (Rule 1: a var, difficulty scaling later).
static var punch_gain: float = 2.0

## A corrosive eats a handful of voxels, never a map's worth: a checkpoint (a file a player can edit) is not trusted past this.
const MAX_CELLS: int = 100000

static var _cells: Dictionary = {}     ## Vector3i (x, y, level) -> true


static func clear() -> void:
	_cells.clear()


static func mark(key: Vector3i) -> void:
	if _cells.size() >= MAX_CELLS and not _cells.has(key):
		push_warning("[VoxelWeakness] mark: %d weakened voxels already, this one is ignored" % _cells.size())
		return
	_cells[key] = true


static func is_weak_key(key: Vector3i) -> bool:
	return not _cells.is_empty() and _cells.has(key)


static func is_weak(voxel: Voxel) -> bool:
	return not _cells.is_empty() and _cells.has(Vector3i(voxel.grid_pos.x, voxel.grid_pos.y, voxel.level))


## The multiplier a round's punch takes on `voxel`: `punch_gain` when weakened, 1.0 otherwise.
static func gain_of(voxel: Voxel) -> float:
	return punch_gain if is_weak(voxel) else 1.0


static func count() -> int:
	return _cells.size()


## `[[x, y, level], ...]` for a checkpoint.
static func to_save() -> Array:
	var out: Array = []
	for key: Vector3i in _cells:
		out.append([key.x, key.y, key.z])
	return out


## Restores a checkpoint's list. `SaveState.validate()` has refused a malformed file before this runs; a bad row that still gets here is skipped.
static func from_save(rows: Variant) -> void:
	_cells.clear()
	if typeof(rows) != TYPE_ARRAY:
		return
	for r in rows as Array:
		if _cells.size() >= MAX_CELLS:
			break
		if typeof(r) == TYPE_ARRAY and (r as Array).size() >= 3:
			_cells[Vector3i(int(r[0]), int(r[1]), int(r[2]))] = true
