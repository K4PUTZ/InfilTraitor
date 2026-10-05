## Geometry Module — VoxelContainer: what `Slice`, `Slab`, `JunctionColumn` and `PropBlock` share, the voxels and their dirty count.
##
## R3D-CLAIMS C2. A container used to OWN every `Voxel` object it generated, for the life of the board: ~296 000 of them on
## PLAYGROUND, ~990 B each on the Moto (~270 MB of a 1.30 GB peak). Since R3D-1d a `Voxel` holds no state (its fields are read
## and written through `VoxelStore`, by `claim`), so the object is only a handle, and a handle can be made again when someone
## asks for it. A container therefore has two modes:
##
##   FULL (the default, and every fixture): `_voxels` holds the objects, exactly as before. A selftest that builds a container
##     with `container.voxels.append(Voxel.new(...))` is in this mode and never leaves it.
##   RELEASED (a live board, after `VoxelStore.build(..., release_objects = true)`): the objects are gone; `_sparse` has one slot
##     per claim, null until `voxel_at(i)` makes the handle (cached, so a claim keeps ONE object: a Dictionary keyed by `Voxel`
##     stays consistent). `voxels` converts the container to FULL, reusing the handles it already made, for the readers that
##     walk a whole container; `Stats` counts those, so a reader that walks the whole board shows up as a number, not as ~270 MB.
##
## A reader that wants one claim asks `voxel_at(i)`; one that wants a count asks `voxel_count()`; one that wants the whole
## container (a blast over an affected slice) reads `voxels`, as it always did.
class_name VoxelContainer
extends RefCounted

## How many containers were converted to FULL after being released, and how many handles were made one at a time: what the
## release saves is measured against these. Reset by `reset_stats()`.
class Stats:
	static var converted: int = 0
	static var converted_voxels: int = 0
	static var handles: int = 0
	static var converted_ids: Dictionary = {}   ## container id -> true, for the first 64 only

	static func reset() -> void:
		converted = 0
		converted_voxels = 0
		handles = 0
		converted_ids = {}


## Sum of the children's dirty flags (a container with 0 is skipped by the TIC, which is the point of keeping it).
var dirty_count: int = 0

var _voxels: Array[Voxel] = []
var _sparse: Array = []
var _released: bool = false
## Where this container sits in the active store: its first claim, and its ordinal among the store's containers.
var _claim_offset: int = -1
var _ordinal: int = -1


## Every voxel of the container. In RELEASED mode this converts it to FULL (see the class doc).
var voxels: Array[Voxel]:
	get:
		if _released:
			_convert_to_full()
		return _voxels
	set(value):
		_voxels = value
		_released = false
		_sparse = []


func voxel_count() -> int:
	return _sparse.size() if _released else _voxels.size()


## One voxel, by its index in this container's order (the order of its claims). FULL mode answers the persistent object;
## RELEASED mode makes the handle once and keeps it.
func voxel_at(i: int) -> Voxel:
	if not _released:
		return _voxels[i]
	var v = _sparse[i]
	if v == null:
		var store: VoxelStore = VoxelStore.active
		if store == null or _ordinal < 0 or _ordinal >= store.containers.size() or store.containers[_ordinal] != self:
			push_error("[VoxelContainer] voxel_at: the active store does not hold this container (%s)" % str(get("id")))
			return null
		v = store.make_voxel(_claim_offset + i, self)
		_sparse[i] = v
		Stats.handles += 1
	return v


func is_released() -> bool:
	return _released


func claim_offset() -> int:
	return _claim_offset


## Called by `VoxelStore` once the container's claims are assigned. Drops the persistent objects: from here a voxel is a handle.
func release_voxels(offset: int, ordinal: int) -> void:
	_claim_offset = offset
	_ordinal = ordinal
	if _released:
		return
	var n: int = _voxels.size()
	_sparse = []
	_sparse.resize(n)
	_voxels = []
	_released = true


## Called by `VoxelStore` for a container it keeps in FULL mode: it still needs to know where it sits.
func bind_claims(offset: int, ordinal: int) -> void:
	_claim_offset = offset
	_ordinal = ordinal


func _convert_to_full() -> void:
	var store: VoxelStore = VoxelStore.active
	var n: int = _sparse.size()
	if store == null or _ordinal < 0 or _ordinal >= store.containers.size() or store.containers[_ordinal] != self:
		push_error("[VoxelContainer] cannot rebuild the voxels of %s: the active store does not hold it" % str(get("id")))
		return
	var out: Array[Voxel] = []
	out.resize(n)
	for i in range(n):
		var v = _sparse[i]
		if v == null:
			v = store.make_voxel(_claim_offset + i, self)
		out[i] = v
	_voxels = out
	_sparse = []
	_released = false
	Stats.converted += 1
	Stats.converted_voxels += n
	if Stats.converted_ids.size() < 64:
		Stats.converted_ids[str(get("id"))] = true


## Called by child Voxel when it becomes dirty
func increment_dirty() -> void:
	dirty_count += 1


## Called by child Voxel when it clears dirty
func decrement_dirty() -> void:
	if dirty_count > 0:
		dirty_count -= 1


## Clear every child's dirty flag (TIC entry point from the registries). A released container clears the store's bits without
## making a single handle.
func clear_all_dirty() -> void:
	if _released:
		var store: VoxelStore = VoxelStore.active
		if store != null and _claim_offset >= 0:
			for c in range(_claim_offset, _claim_offset + _sparse.size()):
				store.dirty_bits[c] = 0
		dirty_count = 0
		return
	for voxel in _voxels:
		if voxel.dirty:
			voxel.dirty = false
	dirty_count = 0
