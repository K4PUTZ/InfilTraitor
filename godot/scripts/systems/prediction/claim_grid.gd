## ClaimGrid - the detonation plan's `cell_to_voxel`, without the 215 000-entry Dictionary of `Voxel` objects.
##
## R3D-CLAIMS C2. The plan's WALK used to build `Dictionary[Vector3i -> Voxel]` over every claim of the board (and `VoxelStore.walk_cache`
## kept it for the store's life: ~21 MB, and every `Voxel` object in it alive). The answer is already in the store: its dense grid
## knows which claim holds a cell, so this object answers `voxel_at()` / `has()` / `size()` from the grid and hands back the container's own
## `Voxel` for that claim (made on request, one per claim). Same answers as the Dictionary, "the last claim of a cell wins" included:
## a cell two claims hold answers for the one that comes last in claim order, which is what assigning in walk order did.
##
## A plan built over a board with no matching store (a fixture) has no grid to ask; it fills `put()` as the old walk did.
class_name ClaimGrid
extends RefCounted

var _store: VoxelStore = null
var _dict: Dictionary = {}


## Backed by the store's grid: nothing is built, nothing is held.
static func of_store(store: VoxelStore) -> ClaimGrid:
	var grid := ClaimGrid.new()
	grid._store = store
	return grid


## Dictionary-backed: the object walk fills it with `put()`.
static func empty() -> ClaimGrid:
	return ClaimGrid.new()


func put(key: Vector3i, voxel: Voxel) -> void:
	_dict[key] = voxel


## The voxel at a cell, or null (a Dictionary's `get(key)` default).
func voxel_at(key: Vector3i) -> Voxel:
	if _store == null:
		return _dict.get(key)
	var claim: int = _store.last_claim_at(key.x, key.y, key.z)
	return null if claim < 0 else _store.voxel_of(claim)


func has(key: Vector3i) -> bool:
	if _store == null:
		return _dict.has(key)
	return _store.last_claim_at(key.x, key.y, key.z) >= 0


## The claim at a cell without making its `Voxel`, or -1.
func claim_at(key: Vector3i) -> int:
	if _store == null:
		var v: Voxel = _dict.get(key)
		return -1 if v == null else v.claim
	return _store.last_claim_at(key.x, key.y, key.z)


func size() -> int:
	return _store.distinct_cells() if _store != null else _dict.size()


func is_empty() -> bool:
	return size() == 0


func is_store_backed() -> bool:
	return _store != null
