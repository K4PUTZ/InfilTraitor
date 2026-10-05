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
## R3D-CLAIMS C4 adds a third mode BEFORE the store exists, so the generators make no object at all:
##
##   CELLS (what `SliceGenerator`, `SlabGenerator` and `JunctionColumn` fill, through `add_cell()`): `_cells` holds x, y, level per
##     voxel, 12 B each instead of an object (~4.3 us to make, ~990 B to keep on the Moto). `VoxelStore._fill()` reads them and the
##     container goes straight to RELEASED. A reader that asks for `voxels` BEFORE the store is built converts the container to FULL
##     (the objects it always had) and `Stats.from_cells` counts it, so a build-time reader that walks the board shows as a number.
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
	static var callers: Dictionary = {}         ## "file:line function" of whoever converted -> [containers, voxels]; debug builds only
	static var from_cells: int = 0              ## containers a reader turned from CELLS into full objects before the store was built
	static var from_cells_voxels: int = 0
	static var from_cells_callers: Dictionary = {}  ## same shape as `callers`

	static func reset() -> void:
		converted = 0
		converted_voxels = 0
		handles = 0
		converted_ids = {}
		callers = {}
		from_cells = 0
		from_cells_voxels = 0
		from_cells_callers = {}


## Sum of the children's dirty flags (a container with 0 is skipped by the TIC, which is the point of keeping it).
var dirty_count: int = 0

var _voxels: Array[Voxel] = []
var _sparse: Array = []
var _cells := PackedInt32Array()   ## CELLS mode: x, y, level per voxel
var _has_cells: bool = false
var _released: bool = false
## Where this container sits in the active store: its first claim, and its ordinal among the store's containers.
var _claim_offset: int = -1
var _ordinal: int = -1


## Every voxel of the container. In RELEASED mode this converts it to FULL (see the class doc).
var voxels: Array[Voxel]:
	get:
		if _released:
			_convert_to_full()
		elif _has_cells:
			_cells_to_objects()
		return _voxels
	set(value):
		_voxels = value
		_released = false
		_sparse = []
		_cells = PackedInt32Array()
		_has_cells = false


## CELLS mode: one voxel, by cell. The generators call this instead of `Voxel.new()` + `voxels.append()`.
func add_cell(x: int, y: int, level: int) -> void:
	_cells.append(x)
	_cells.append(y)
	_cells.append(level)
	_has_cells = true


func voxel_count() -> int:
	if _released:
		return _sparse.size()
	if _has_cells:
		return _cells.size() / 3
	return _voxels.size()


## Every voxel's cell as x, y, level triples, WITHOUT making a `Voxel` when the container is in CELLS mode (no copy: the array is
## shared, never write to it). A FULL container builds it from its objects. What `VoxelStore._fill()` reads.
func cells_packed() -> PackedInt32Array:
	if _has_cells or _released:
		return _cells
	var n: int = _voxels.size()
	var out := PackedInt32Array()
	out.resize(n * 3)
	for i in range(n):
		var v: Voxel = _voxels[i]
		out[i * 3] = v.grid_pos.x
		out[i * 3 + 1] = v.grid_pos.y
		out[i * 3 + 2] = v.level
	return out


## True when the container holds NO objects (CELLS or RELEASED): its cells are the truth and `voxels` would have to make them.
func has_cells_only() -> bool:
	return _has_cells or _released


## One voxel, by its index in this container's order (the order of its claims). FULL mode answers the persistent object;
## RELEASED mode makes the handle once and keeps it.
func voxel_at(i: int) -> Voxel:
	if _has_cells:
		_cells_to_objects()
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


## The cell of voxel `i` (x, y, level) WITHOUT making a `Voxel` when the container is released: the store holds it. A reader that
## walks a whole container for its cells (the cutaway's geometry, the roof footprints) asks this, not `voxels`.
func cell_at(i: int) -> Vector3i:
	if _has_cells or _released:
		return Vector3i(_cells[i * 3], _cells[i * 3 + 1], _cells[i * 3 + 2])
	var v: Voxel = _voxels[i]
	return Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)


func is_released() -> bool:
	return _released


func claim_offset() -> int:
	return _claim_offset


## Called by `VoxelStore` once the container's claims are assigned. Drops the persistent objects: from here a voxel is a handle.
func release_voxels(offset: int, ordinal: int) -> void:
	_claim_offset = offset
	_ordinal = ordinal
	if not _has_cells and not _released:
		_cells = cells_packed()   ## from the objects about to go: the container keeps its cells (12 B a voxel) for good
	var n: int = voxel_count()
	_sparse = []
	_sparse.resize(n)
	_voxels = []
	_has_cells = false
	_released = true


## Called by `VoxelStore` for a container it keeps in FULL mode: it still needs to know where it sits.
func bind_claims(offset: int, ordinal: int) -> void:
	_claim_offset = offset
	_ordinal = ordinal


## CELLS -> FULL, before a store exists: the objects the generators used to make, with no claim yet (`_fill()` assigns it).
func _cells_to_objects() -> void:
	var n: int = _cells.size() / 3
	var out: Array[Voxel] = []
	out.resize(n)
	## A store may already have bound this container (`bind_claims()`, without releasing it): its claims are `offset + i`, so the
	## objects made now are those claims, not claimless voxels.
	var bound: bool = _claim_offset >= 0
	for i in range(n):
		var v := Voxel.new(Vector2i(_cells[i * 3], _cells[i * 3 + 1]), _cells[i * 3 + 2], self)
		if bound:
			v.claim = _claim_offset + i
		out[i] = v
	_voxels = out
	_cells = PackedInt32Array()
	_has_cells = false
	Stats.from_cells += 1
	Stats.from_cells_voxels += n
	for frame in get_stack():
		if not str(frame.get("source", "")).ends_with("voxel_container.gd"):
			var who: String = "%s:%d %s" % [str(frame.get("source", "")).get_file(), int(frame.get("line", 0)), str(frame.get("function", ""))]
			var entry: Array = Stats.from_cells_callers.get(who, [0, 0])
			Stats.from_cells_callers[who] = [int(entry[0]) + 1, int(entry[1]) + n]
			break


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
	_cells = PackedInt32Array()
	_released = false
	Stats.converted += 1
	Stats.converted_voxels += n
	## Who asked for the whole container: the first frame outside this file (`get_stack()` is empty in a release build).
	for frame in get_stack():
		if not str(frame.get("source", "")).ends_with("voxel_container.gd"):
			var who: String = "%s:%d %s" % [str(frame.get("source", "")).get_file(), int(frame.get("line", 0)), str(frame.get("function", ""))]
			var entry: Array = Stats.callers.get(who, [0, 0])
			Stats.callers[who] = [int(entry[0]) + 1, int(entry[1]) + n]
			break
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
