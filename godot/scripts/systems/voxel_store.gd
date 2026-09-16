## VoxelStore — the packed voxel store, in SHADOW beside the `Voxel` objects.
##
## RENDER3D R3D-1b (`RENDER3D_MASTER_PLAN` §4). R3D-1a measured the layouts and the
## Director confirmed B (2026-09-16): every claim's state in flat per-voxel arrays,
## contiguous per container, plus a derived dense grid that answers "is this cell
## occupied, and by which claim".
##
## SHADOW MEANT NOTHING READ IT (R3D-1b); R3D-1c moves readers onto it one at a time. It is built from the registries after every board
## build (`Room._rebuild_voxel_store()`), and every state change a `Voxel` makes is
## mirrored into it from the one seam that makes them (`Voxel.set_damage()` /
## `set_visible()`). `BoardProbe.write_store()` dumps it in the objects' own format, so
## `board_probe.py shadow` can require the two to be identical, value by value. Readers
## move onto it one subsystem at a time in R3D-1c; the objects go in R3D-1d.
## On by default since R3D-1c step 1 (`VOXEL_STORE=0` turns it off, and `active` stays
## null). Its first reader is the light field's occupancy (`VoxelRenderer.build_occupancy()`).
##
## A CLAIM is one `Voxel` in one container. PLAYGROUND holds 216 104 claims in 215 432
## cells: where two slices of one GU meet at a corner, both claim the cell, and under a
## blast their states diverge (R3D-1a). The store keeps both, exactly as the objects do.
##
## THE ARRAYS, per claim, in container order (slices, slabs, junction columns — the
## prediction WALK's order):
##   state  bit 0 visible · bits 1-2 damage · bit 3 blast · bits 4-6 carved side
##          (`BoardProbe`'s packing)
##   aux    variant (low nibble) · substrate (high nibble)
##   mat    index into `material_ids`, band-resolved on a slice, the override on a column
##   xyz    grid x, grid y, level
##
## THE DERIVED GRID, per cell of the padded bounds (2 cells and 2 levels of air on every
## side, as R3D-1a measured it, so a reader's ±1/±2 neighbour read needs no bounds check):
##   occ    1 when ANY claim of the cell is visible
##   owner  the first visible claim, else the first claim, else -1
## A cell more than one claim holds is listed in `_multi`, so a write can recompute it.
##
## FINDING A CLAIM FROM A VOXEL costs no field on `Voxel`. Each container's voxels are
## laid out in a regular box — level, then y, then x — so the claim is the container's
## offset plus arithmetic on the voxel's own cell. That is VERIFIED for every voxel when
## the store is built; a container whose order breaks it gets a lookup table instead,
## and is counted, so the arithmetic is never trusted blind.
class_name VoxelStore
extends RefCounted

const PAD: int = 2
const KIND_SLICE: int = 0
const KIND_SLAB: int = 1
const KIND_COLUMN: int = 2
const KIND_NAMES: PackedStringArray = ["slice", "slab", "column"]
## Per-container geometry record: offset, count, xmin, ymin, lmin, nx, ny.
const GEOM_STRIDE: int = 7

## The store every `Voxel` write mirrors into, or null when the shadow is off. Static,
## like `Voxel.soot_dirty`: a `Voxel` holds no reference to anything that could reach it.
static var active: VoxelStore = null

var claims: int = 0
var state := PackedByteArray()
var aux := PackedByteArray()
var mat := PackedByteArray()
var xyz := PackedInt32Array()
var material_ids := PackedStringArray()

var x0: int = 0
var y0: int = 0
var l0: int = 0
var w: int = 0
var h: int = 0
var nl: int = 0
var plane: int = 0
var occ := PackedByteArray()
var owner := PackedInt32Array()

## Containers, in claim order.
var container_ids := PackedStringArray()
var container_kinds := PackedByteArray()
var _geom := PackedInt32Array()
var _by_instance: Dictionary = {}       ## container instance id -> container ordinal
var _irregular: Dictionary = {}         ## container ordinal -> {Vector3i cell: claim}
var _multi: Dictionary = {}             ## cell index -> PackedInt32Array of claims
var _material_index: Dictionary = {}

## Counters `BoardProbe` reports. A write to a voxel whose container the store does not
## know is a write the store missed — the shadow has drifted, and the gate fails on it.
var writes_mirrored: int = 0
var writes_unknown_container: int = 0
var writes_misplaced: int = 0
var build_ms: float = 0.0


## Builds a store from the three registries, or returns null after a `push_error`.
static func build(edge_registry: EdgeRegistry, slab_registry: SlabRegistry,
		junction_columns: Array) -> VoxelStore:
	if edge_registry == null or slab_registry == null:
		push_error("[VoxelStore] build: a registry is missing (edges %s, slabs %s)"
			% [edge_registry != null, slab_registry != null])
		return null
	var t0: int = Time.get_ticks_usec()
	var store := VoxelStore.new()
	var containers: Array = []
	for slice: Slice in edge_registry.all_slices():
		containers.append([slice, KIND_SLICE])
	for slab: Slab in slab_registry.all_slabs():
		containers.append([slab, KIND_SLAB])
	for column: JunctionResolver.JunctionColumn in junction_columns:
		containers.append([column, KIND_COLUMN])
	if not store._fill(containers):
		return null
	store.build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	return store


func _fill(containers: Array) -> bool:
	var total: int = 0
	var min_x: int = 1 << 30
	var min_y: int = 1 << 30
	var min_l: int = 1 << 30
	var max_x: int = -(1 << 30)
	var max_y: int = -(1 << 30)
	var max_l: int = -(1 << 30)
	for entry: Array in containers:
		for v: Voxel in entry[0].voxels:
			total += 1
			min_x = mini(min_x, v.grid_pos.x)
			max_x = maxi(max_x, v.grid_pos.x)
			min_y = mini(min_y, v.grid_pos.y)
			max_y = maxi(max_y, v.grid_pos.y)
			min_l = mini(min_l, v.level)
			max_l = maxi(max_l, v.level)
	claims = total
	state.resize(total)
	aux.resize(total)
	mat.resize(total)
	xyz.resize(total * 3)
	if total == 0:
		return true
	x0 = min_x - PAD
	y0 = min_y - PAD
	l0 = min_l - PAD
	w = max_x - min_x + 1 + 2 * PAD
	h = max_y - min_y + 1 + 2 * PAD
	nl = max_l - min_l + 1 + 2 * PAD
	plane = w * h
	occ.resize(plane * nl)
	owner.resize(plane * nl)
	owner.fill(-1)

	var claim: int = 0
	for ci in range(containers.size()):
		var container: Object = containers[ci][0]
		var kind: int = containers[ci][1]
		var voxels: Array = container.voxels
		container_ids.append(str(container.get("id")))
		container_kinds.append(kind)
		_by_instance[container.get_instance_id()] = ci
		var bx: int = 1 << 30
		var by: int = 1 << 30
		var bl: int = 1 << 30
		var ex: int = -(1 << 30)
		var ey: int = -(1 << 30)
		var el: int = -(1 << 30)
		for v: Voxel in voxels:
			bx = mini(bx, v.grid_pos.x)
			ex = maxi(ex, v.grid_pos.x)
			by = mini(by, v.grid_pos.y)
			ey = maxi(ey, v.grid_pos.y)
			bl = mini(bl, v.level)
			el = maxi(el, v.level)
		var nx: int = ex - bx + 1 if not voxels.is_empty() else 0
		var ny: int = ey - by + 1 if not voxels.is_empty() else 0
		var regular: bool = nx * ny * (el - bl + 1) == voxels.size() or voxels.is_empty()
		_geom.append_array(PackedInt32Array([claim, voxels.size(), bx, by, bl, nx, ny]))
		for i in range(voxels.size()):
			var v: Voxel = voxels[i]
			if regular and ((v.level - bl) * ny + (v.grid_pos.y - by)) * nx + (v.grid_pos.x - bx) != i:
				regular = false
			state[claim] = state_byte(v)
			aux[claim] = aux_byte(v)
			mat[claim] = _material(_voxel_material(container, v))
			xyz[claim * 3] = v.grid_pos.x
			xyz[claim * 3 + 1] = v.grid_pos.y
			xyz[claim * 3 + 2] = v.level
			var cell: int = cell_index(v.grid_pos.x, v.grid_pos.y, v.level)
			if owner[cell] == -1:
				owner[cell] = claim
			elif _multi.has(cell):
				## A packed array read out of a Dictionary is a copy: grow it, then store it back.
				var list: PackedInt32Array = _multi[cell]
				list.append(claim)
				_multi[cell] = list
			else:
				_multi[cell] = PackedInt32Array([owner[cell], claim])
			claim += 1
		if not regular:
			var table: Dictionary = {}
			for i in range(voxels.size()):
				var v2: Voxel = voxels[i]
				table[Vector3i(v2.grid_pos.x, v2.grid_pos.y, v2.level)] = _geom[ci * GEOM_STRIDE] + i
			_irregular[ci] = table
	if _material_index.size() > 256:
		push_error("[VoxelStore] build: %d materials — a byte holds 256" % _material_index.size())
		return false
	_rebuild_grid()
	return true


## The derived grid, from the claims alone.
func _rebuild_grid() -> void:
	for claim in range(claims):
		var cell: int = cell_index(xyz[claim * 3], xyz[claim * 3 + 1], xyz[claim * 3 + 2])
		if _multi.has(cell):
			continue
		owner[cell] = claim
		occ[cell] = state[claim] & 1
	for cell: int in _multi:
		_resolve_cell(cell)


func _resolve_cell(cell: int) -> void:
	var list: PackedInt32Array = _multi[cell]
	var first_visible: int = -1
	for claim in list:
		if state[claim] & 1:
			first_visible = claim
			break
	occ[cell] = 1 if first_visible >= 0 else 0
	owner[cell] = first_visible if first_visible >= 0 else list[0]


func cell_index(x: int, y: int, level: int) -> int:
	return ((level - l0) * h + (y - y0)) * w + (x - x0)


static func state_byte(v: Voxel) -> int:
	return (1 if v.visible else 0) | (v.damage_state << 1) \
		| ((1 if v.damage_is_blast else 0) << 3) | (v.damage_carved_side << 4)


static func aux_byte(v: Voxel) -> int:
	return (v.damage_variant & 15) | ((v.damage_substrate & 15) << 4)


## The claim a voxel is, or -1 when the store does not hold its container.
func claim_of(v: Voxel) -> int:
	var ci: int = _by_instance.get(v.container_id(), -1)
	if ci < 0:
		return -1
	if _irregular.has(ci):
		return int((_irregular[ci] as Dictionary).get(Vector3i(v.grid_pos.x, v.grid_pos.y, v.level), -1))
	var g: int = ci * GEOM_STRIDE
	return _geom[g] + ((v.level - _geom[g + 4]) * _geom[g + 6] + (v.grid_pos.y - _geom[g + 3])) \
		* _geom[g + 5] + (v.grid_pos.x - _geom[g + 2])


## Called by `Voxel` after every state change. A voxel with no container (a
## `WorldDelta` projection) is not a claim and is skipped without counting.
func mirror(v: Voxel) -> void:
	if v.container_id() == 0:
		return
	var claim: int = claim_of(v)
	if claim < 0:
		writes_unknown_container += 1
		return
	if xyz[claim * 3] != v.grid_pos.x or xyz[claim * 3 + 1] != v.grid_pos.y \
			or xyz[claim * 3 + 2] != v.level:
		writes_misplaced += 1
		return
	state[claim] = state_byte(v)
	aux[claim] = aux_byte(v)
	var cell: int = cell_index(v.grid_pos.x, v.grid_pos.y, v.level)
	if _multi.has(cell):
		_resolve_cell(cell)
	else:
		occ[cell] = state[claim] & 1
	writes_mirrored += 1


## How many cells of the derived grid disagree with a grid rebuilt from the claims now.
func grid_mismatches() -> int:
	var expected_occ := PackedByteArray()
	expected_occ.resize(occ.size())
	var expected_owner := PackedInt32Array()
	expected_owner.resize(owner.size())
	expected_owner.fill(-1)
	for claim in range(claims):
		var cell: int = cell_index(xyz[claim * 3], xyz[claim * 3 + 1], xyz[claim * 3 + 2])
		var visible: bool = (state[claim] & 1) == 1
		if expected_owner[cell] == -1:
			expected_owner[cell] = claim
			expected_occ[cell] = 1 if visible else 0
		elif visible and expected_occ[cell] == 0:
			expected_owner[cell] = claim
			expected_occ[cell] = 1
	var mismatches: int = 0
	for cell in range(occ.size()):
		if occ[cell] != expected_occ[cell] or owner[cell] != expected_owner[cell]:
			mismatches += 1
	return mismatches


## RENDER3D R3D-1c — `VoxelRenderer.build_occupancy()`'s shape (level -> {Vector2i: true}),
## read from the claims: a cell is occupied when any of its claims is visible. Every level
## the store spans gets an entry, empty or not. `predict_destroyed` omits cells, keyed
## Vector3i(x, y, level), exactly as the tile-based version does.
##
## ⚠️ WRITTEN FOR THE COOK'S LIGHT STEP, which calls it once per detonation over the whole
## map. The first version tested every claim against `predict_destroyed` (a `Vector3i`
## built and looked up 216 104 times) and fetched its level's set by key per claim: the
## LIGHT step went 45 → 82 ms on desktop against the tile read. So the predicted cells —
## a few hundred — are erased AFTER the pass, and a level's set is found by index.
func occupancy_dict(predict_destroyed: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var sets: Array = []
	sets.resize(nl)
	for li in range(nl):
		var level_set: Dictionary = {}
		sets[li] = level_set
		if li >= PAD and li < nl - PAD:
			out[l0 + li] = level_set
	var st: PackedByteArray = state
	var p: PackedInt32Array = xyz
	var base: int = l0
	var i: int = 0
	for claim in range(claims):
		if st[claim] & 1:
			sets[p[i + 2] - base][Vector2i(p[i], p[i + 1])] = true
		i += 3
	for key: Vector3i in predict_destroyed:
		var li: int = key.z - base
		if li >= 0 and li < nl:
			(sets[li] as Dictionary).erase(Vector2i(key.x, key.y))
	return out


func container_count() -> int:
	return container_ids.size()


func container_claims(ci: int) -> Vector2i:
	return Vector2i(_geom[ci * GEOM_STRIDE], _geom[ci * GEOM_STRIDE + 1])


func irregular_containers() -> int:
	return _irregular.size()


func multi_cells() -> int:
	return _multi.size()


func bytes() -> int:
	return state.size() + aux.size() + mat.size() + xyz.size() * 4 + occ.size() \
		+ owner.size() * 4 + _geom.size() * 4


func _material(material_id: String) -> int:
	if not _material_index.has(material_id):
		_material_index[material_id] = material_ids.size()
		material_ids.append(material_id)
	return int(_material_index[material_id])


## A claim's material, the way `BoardProbe` and the mesher resolve it.
static func _voxel_material(container: Object, v: Voxel) -> String:
	if container is Slice:
		var slice: Slice = container
		return slice.material_at(v.level - GeometryCoords.storey_level_base(slice.start_storey))
	if container is JunctionResolver.JunctionColumn:
		var column: JunctionResolver.JunctionColumn = container
		return column.override_material if column.override_material != "" else column.material
	return str(container.get("material"))
