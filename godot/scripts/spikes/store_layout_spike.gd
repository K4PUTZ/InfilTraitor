## StoreLayoutSpike — RENDER3D R3D-1a: which packed layout holds the voxel store.
##
## A SPIKE, never a mode. It reads the live registries after a real map load, builds
## every candidate layout beside today's objects, checks each candidate's answers
## against the objects', and times three hot readers on each. It writes nothing back.
## The decision rule it serves was committed before it ran (`RENDER3D_MASTER_PLAN`
## R3D-1a, commit `43af4062`).
##
## THE LAYOUTS
##  - O  today: `Voxel` objects in their containers, and the dictionaries today's
##       readers build from them (`occupancy[level][Vector2i]`, the mesher's
##       `Vector3i → material`).
##  - A  one dense grid over the padded cell bounds: a state, aux and material byte and
##       an `int32` reference per cell. FLAT, with a level stride, rather than one array
##       per level: the same bytes, and no per-level fetch in a hot loop. A cell two
##       containers claim keeps its first claim in the grid and the second in an
##       overflow table (6 ints per entry) — R3D-0's collision census.
##  - Ac A allocated per (level, 32×32 chunk) only where a voxel exists, behind a flat
##       chunk directory.
##  - B  every claim in flat per-voxel arrays (state, aux, material, xyz), contiguous per
##       container, plus a derived dense grid: an occupancy byte and the owning claim.
##
## STATE BYTE (A, Ac, B): bit 0 visible, bits 1–2 damage, bit 3 blast, bits 4–6 carved
## side — `BoardProbe`'s packing. A and Ac add bit 7: ANY claim of this cell is visible,
## which is what occupancy asks. AUX: variant in the low nibble, substrate in the high.
##
## THE KERNELS — the read pattern of each hot reader, with everything a layout does not
## change left out, and each answering a checksum that must equal O's:
##  - T1 `VoxelLightField.bucket_for()`'s occupancy reads: `surface_factor()`'s three
##       neighbours, then `_face_occlusion()`'s ring for the face that wins. Once per
##       visible cell.
##  - T2 the mesher's scan (`Board3DLive._build_chunk()`): per occupied cell, three
##       neighbour reads and the glass rule, faces appended to a flat array. Merge and
##       upload are the same for every layout.
##  - T3 the prediction WALK's reads (`DetonationPlanBuilder._phase_walk()`): per claim,
##       visible, damage, blast, cell and the container's material flammability,
##       classified into its buckets. The Delta projection and the dictionaries the
##       WALK builds are left out — they exist because there is no store.
##
## PADDING: the bounds grow by 2 cells and 2 levels on every side, so every neighbour
## read of ±1/±2 is in range and no kernel carries a bounds check. The memory reported
## is the padded arrays' real size.
extends RefCounted

const PAD: int = 2
const CHUNK_SHIFT: int = 5
const CHUNK_MASK: int = 31
const CHUNK_CELLS: int = 1024
const BIT_VISIBLE: int = 1
const BIT_OCCUPIED: int = 0x80
const DAMAGE_DESTROYED: int = 2
const DAMAGE_DENTED: int = 3
const DAMAGE_CRACKED: int = 1
const OVERFLOW_STRIDE: int = 6
## `Board3DLive.DIR_STEP` — top (+level), SE (+x), SW (+y), in its (x, level, y) keys.
const DIR_STEP: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)]

var _room: Node = null
var _log: PackedStringArray = []

## --- inputs every layout shares --------------------------------------------
var _material_ids: PackedStringArray = []
var _material_index: Dictionary = {}
var _glass: PackedByteArray = []            ## per material index
var _flammability: PackedFloat32Array = []  ## per material index
var _containers: Array = []                 ## [container, base material index]
var _claims: int = 0
var _x0: int = 0
var _y0: int = 0
var _l0: int = 0
var _w: int = 0
var _h: int = 0
var _nl: int = 0
var _plane: int = 0
var _ft: float = 1.0
var _fse: float = 0.74
var _fsw: float = 0.48
var _fenc: float = 0.30
var _t1_cells: PackedInt32Array = []        ## visible cells, x y level triples

## --- O ------------------------------------------------------------------------
var _o_occ: Dictionary = {}                 ## level -> {Vector2i: true}
var _o_mesh: Dictionary = {}                ## Vector3i -> material index
var _o_by_chunk: Dictionary = {}            ## Vector2i -> {Vector3i: true}

## --- A ------------------------------------------------------------------------
var _a_state: PackedByteArray = []
var _a_aux: PackedByteArray = []
var _a_mat: PackedByteArray = []
var _a_ref: PackedInt32Array = []
var _a_overflow: PackedInt32Array = []      ## flat index, state, aux, mat, ref, container

## --- Ac -----------------------------------------------------------------------
var _c_cw: int = 0
var _c_ch: int = 0
var _c_dir: PackedInt32Array = []           ## (level, chunk) -> slot or -1
var _c_slots: PackedInt32Array = []         ## slot -> level index, chunk x, chunk y
var _c_slot_count: int = 0
var _c_state: PackedByteArray = []
var _c_aux: PackedByteArray = []
var _c_mat: PackedByteArray = []
var _c_ref: PackedInt32Array = []
var _c_overflow: PackedInt32Array = []

## --- B ------------------------------------------------------------------------
var _b_offset: PackedInt32Array = []        ## per container: first claim, then count
var _b_state: PackedByteArray = []
var _b_aux: PackedByteArray = []
var _b_mat: PackedByteArray = []
var _b_xyz: PackedInt32Array = []
var _b_occ: PackedByteArray = []            ## derived: any visible claim
var _b_owner: PackedInt32Array = []         ## derived: first visible claim, else first claim


## Builds every layout, checks identity, times the kernels. Returns the summary.
##
## A COROUTINE: it yields one frame between kernels, OUTSIDE every timed window. On the
## Moto the whole run is a minute or more, and one blocked frame that long is a frame the
## OS may treat as a hung app.
func run(room: Node, reps: int) -> Dictionary:
	_room = room
	var t0: int = Time.get_ticks_usec()
	if not _collect():
		return {}
	var t_collect: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_build_o()
	await room.get_tree().process_frame
	_build_a()
	await room.get_tree().process_frame
	_build_c()
	await room.get_tree().process_frame
	_build_b()
	await room.get_tree().process_frame
	## Wall time, so it includes the four yielded frames.
	var t_build: float = float(Time.get_ticks_usec() - t0) / 1000.0 - t_collect
	_say("map %s — %d claim(s), %d container(s), %d material(s); bounds x %d+%d y %d+%d levels %d+%d (padded %d); collect %.0f ms, build %.0f ms" % [
		str(room.get("map_id")), _claims, _containers.size(), _material_ids.size(),
		_x0, _w, _y0, _h, _l0, _nl, PAD, t_collect, t_build])
	_report_memory()

	var layouts: PackedStringArray = ["O", "A", "Ac", "B"]
	var kernels: PackedStringArray = ["T1", "T2", "T3"]
	var answers: Dictionary = {}
	var times: Dictionary = {}
	for layout in layouts:
		for kernel in kernels:
			## An Array, not a PackedFloat64Array: a packed array read out of a Dictionary
			## is a copy, and an append to it would be lost.
			times["%s %s" % [layout, kernel]] = []
	## Warm-up, then `reps` timed passes. The layouts are INTERLEAVED inside each pass so a
	## phone warming up or throttling moves every layout together.
	for rep in range(reps + 1):
		for kernel in kernels:
			for layout in layouts:
				await room.get_tree().process_frame
				var t: int = Time.get_ticks_usec()
				var answer: Array = _run_kernel(layout, kernel)
				var ms: float = float(Time.get_ticks_usec() - t) / 1000.0
				var key: String = "%s %s" % [layout, kernel]
				if rep == 0:
					answers[key] = answer
				else:
					(times[key] as Array).append(ms)
	var identical: bool = true
	for kernel in kernels:
		var reference: Array = answers["O %s" % kernel]
		for layout in layouts:
			var got: Array = answers["%s %s" % [layout, kernel]]
			var same: bool = got == reference
			identical = identical and same
			_say("identity %s %-2s %s %s" % [kernel, layout, "==" if same else "!=", got])
	var summary: Dictionary = {"identical": identical}
	for kernel in kernels:
		var line: String = "timing %s median of %d:" % [kernel, reps]
		for layout in layouts:
			var key: String = "%s %s" % [layout, kernel]
			var median: float = _median(times[key])
			summary[key] = median
			line += " %s %.1f ms (%s)" % [layout, median, _join_ms(times[key])]
		_say(line)
	if not identical:
		push_error("[StoreLayoutSpike] a layout's kernel does not reproduce O's answer — its timings do not count (see the identity lines)")
	return summary


func log_lines() -> PackedStringArray:
	return _log


func _say(line: String) -> void:
	_log.append(line)
	print("[R3D1A] %s" % line)


# ── collection ────────────────────────────────────────────────────────────────

func _collect() -> bool:
	var edge_registry: EdgeRegistry = _room.get("_edge_registry")
	var slab_registry: SlabRegistry = _room.get("_slab_registry")
	var columns: Array = _room.get("_junction_columns")
	if edge_registry == null or slab_registry == null:
		push_error("[StoreLayoutSpike] no registries on the Room — run after a map load")
		return false
	## The WALK's container order: slices, slabs, junction columns.
	for slice in edge_registry.all_slices():
		_containers.append([slice, _material(str(slice.material))])
	for slab in slab_registry.all_slabs():
		_containers.append([slab, _material(str(slab.material))])
	for column in columns:
		_containers.append([column, _material(str(column.material))])
	var field: VoxelLightField = _room.get("_voxel_light_field")
	if field != null:
		_ft = field.face_top_factor
		_fse = field.face_se_factor
		_fsw = field.face_sw_factor
		_fenc = field.face_enclosed_factor
	var min_x: int = 1 << 30
	var min_y: int = 1 << 30
	var min_l: int = 1 << 30
	var max_x: int = -(1 << 30)
	var max_y: int = -(1 << 30)
	var max_l: int = -(1 << 30)
	for entry: Array in _containers:
		for v: Voxel in entry[0].voxels:
			_claims += 1
			min_x = mini(min_x, v.grid_pos.x)
			max_x = maxi(max_x, v.grid_pos.x)
			min_y = mini(min_y, v.grid_pos.y)
			max_y = maxi(max_y, v.grid_pos.y)
			min_l = mini(min_l, v.level)
			max_l = maxi(max_l, v.level)
	if _claims == 0:
		push_error("[StoreLayoutSpike] the registries hold no voxels")
		return false
	_x0 = min_x - PAD
	_y0 = min_y - PAD
	_l0 = min_l - PAD
	_w = max_x - min_x + 1 + 2 * PAD
	_h = max_y - min_y + 1 + 2 * PAD
	_nl = max_l - min_l + 1 + 2 * PAD
	_plane = _w * _h
	return true


func _material(material_id: String) -> int:
	if not _material_index.has(material_id):
		_material_index[material_id] = _material_ids.size()
		_material_ids.append(material_id)
		_glass.append(1 if GlassMaterials.is_glass(material_id) else 0)
		_flammability.append(MaterialResistanceTable.flammability(material_id))
	return int(_material_index[material_id])


## A claim's material as a store would hold it: band-resolved on a slice, the override on
## a column. The mesher draws this one; the WALK reads the container's base material.
func _voxel_material(container: Object, v: Voxel) -> int:
	if container is Slice:
		var slice: Slice = container
		return _material(slice.material_at(v.level - GeometryCoords.storey_level_base(slice.start_storey)))
	if container is JunctionResolver.JunctionColumn:
		var column: JunctionResolver.JunctionColumn = container
		return _material(column.override_material if column.override_material != "" else column.material)
	return _material(str(container.get("material")))


static func _state_byte(v: Voxel) -> int:
	return (1 if v.visible else 0) | (v.damage_state << 1) | ((1 if v.damage_is_blast else 0) << 3) \
		| (v.damage_carved_side << 4)


static func _aux_byte(v: Voxel) -> int:
	return (v.damage_variant & 15) | ((v.damage_substrate & 15) << 4)


# ── building ──────────────────────────────────────────────────────────────────

func _build_o() -> void:
	var seen: Dictionary = {}
	for entry: Array in _containers:
		for v: Voxel in entry[0].voxels:
			if not v.visible:
				continue
			if not _o_occ.has(v.level):
				_o_occ[v.level] = {}
			_o_occ[v.level][v.grid_pos] = true
			var key := Vector3i(v.grid_pos.x, v.level, v.grid_pos.y)
			_o_mesh[key] = _voxel_material(entry[0], v)
			var chunk := Vector2i(v.grid_pos.x >> CHUNK_SHIFT, v.grid_pos.y >> CHUNK_SHIFT)
			if not _o_by_chunk.has(chunk):
				_o_by_chunk[chunk] = {}
			(_o_by_chunk[chunk] as Dictionary)[key] = true
			var cell_key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			if not seen.has(cell_key):
				seen[cell_key] = true
				_t1_cells.append(v.grid_pos.x)
				_t1_cells.append(v.grid_pos.y)
				_t1_cells.append(v.level)


func _build_a() -> void:
	var cells: int = _plane * _nl
	_a_state.resize(cells)
	_a_aux.resize(cells)
	_a_mat.resize(cells)
	_a_ref.resize(cells)
	_a_ref.fill(-1)
	var claim: int = 0
	for ci in range(_containers.size()):
		var entry: Array = _containers[ci]
		for v: Voxel in entry[0].voxels:
			var i: int = ((v.level - _l0) * _h + (v.grid_pos.y - _y0)) * _w + (v.grid_pos.x - _x0)
			var state: int = _state_byte(v)
			var mat: int = _voxel_material(entry[0], v)
			if _a_ref[i] == -1:
				_a_state[i] = state | (BIT_OCCUPIED if v.visible else 0)
				_a_aux[i] = _aux_byte(v)
				_a_mat[i] = mat
				_a_ref[i] = claim
			else:
				if v.visible:
					_a_state[i] = _a_state[i] | BIT_OCCUPIED
				_a_overflow.append_array(PackedInt32Array([i, state, _aux_byte(v), mat, claim, ci]))
			claim += 1


func _build_c() -> void:
	_c_cw = (_w + CHUNK_MASK) >> CHUNK_SHIFT
	_c_ch = (_h + CHUNK_MASK) >> CHUNK_SHIFT
	_c_dir.resize(_nl * _c_ch * _c_cw)
	_c_dir.fill(-1)
	for entry: Array in _containers:
		for v: Voxel in entry[0].voxels:
			var d: int = ((v.level - _l0) * _c_ch + ((v.grid_pos.y - _y0) >> CHUNK_SHIFT)) * _c_cw \
				+ ((v.grid_pos.x - _x0) >> CHUNK_SHIFT)
			if _c_dir[d] == -1:
				_c_dir[d] = _c_slot_count
				_c_slot_count += 1
				_c_slots.append_array(PackedInt32Array([v.level - _l0, (v.grid_pos.x - _x0) >> CHUNK_SHIFT,
					(v.grid_pos.y - _y0) >> CHUNK_SHIFT]))
	var slots: int = _c_slot_count
	_c_state.resize(slots * CHUNK_CELLS)
	_c_aux.resize(slots * CHUNK_CELLS)
	_c_mat.resize(slots * CHUNK_CELLS)
	_c_ref.resize(slots * CHUNK_CELLS)
	_c_ref.fill(-1)
	var claim: int = 0
	for ci in range(_containers.size()):
		var entry: Array = _containers[ci]
		for v: Voxel in entry[0].voxels:
			var rx: int = v.grid_pos.x - _x0
			var ry: int = v.grid_pos.y - _y0
			var slot: int = _c_dir[((v.level - _l0) * _c_ch + (ry >> CHUNK_SHIFT)) * _c_cw + (rx >> CHUNK_SHIFT)]
			var i: int = slot * CHUNK_CELLS + ((ry & CHUNK_MASK) << CHUNK_SHIFT) + (rx & CHUNK_MASK)
			var state: int = _state_byte(v)
			var mat: int = _voxel_material(entry[0], v)
			if _c_ref[i] == -1:
				_c_state[i] = state | (BIT_OCCUPIED if v.visible else 0)
				_c_aux[i] = _aux_byte(v)
				_c_mat[i] = mat
				_c_ref[i] = claim
			else:
				if v.visible:
					_c_state[i] = _c_state[i] | BIT_OCCUPIED
				_c_overflow.append_array(PackedInt32Array([i, state, _aux_byte(v), mat, claim, ci]))
			claim += 1


func _build_b() -> void:
	_b_state.resize(_claims)
	_b_aux.resize(_claims)
	_b_mat.resize(_claims)
	_b_xyz.resize(_claims * 3)
	_b_occ.resize(_plane * _nl)
	_b_owner.resize(_plane * _nl)
	_b_owner.fill(-1)
	var claim: int = 0
	for entry: Array in _containers:
		_b_offset.append(claim)
		_b_offset.append((entry[0].voxels as Array).size())
		for v: Voxel in entry[0].voxels:
			_b_state[claim] = _state_byte(v)
			_b_aux[claim] = _aux_byte(v)
			_b_mat[claim] = _voxel_material(entry[0], v)
			_b_xyz[claim * 3] = v.grid_pos.x
			_b_xyz[claim * 3 + 1] = v.grid_pos.y
			_b_xyz[claim * 3 + 2] = v.level
			var i: int = ((v.level - _l0) * _h + (v.grid_pos.y - _y0)) * _w + (v.grid_pos.x - _x0)
			if v.visible:
				if _b_occ[i] == 0:
					_b_owner[i] = claim
				_b_occ[i] = 1
			elif _b_owner[i] == -1:
				_b_owner[i] = claim
			claim += 1


# ── memory ────────────────────────────────────────────────────────────────────

func _report_memory() -> void:
	var a: int = _a_state.size() + _a_aux.size() + _a_mat.size() + _a_ref.size() * 4 + _a_overflow.size() * 4
	var c: int = _c_dir.size() * 4 + _c_slots.size() * 4 + _c_state.size() + _c_aux.size() \
		+ _c_mat.size() + _c_ref.size() * 4 + _c_overflow.size() * 4
	var b_arrays: int = _b_offset.size() * 4 + _b_state.size() + _b_aux.size() + _b_mat.size()
	var b_xyz: int = _b_xyz.size() * 4
	var b_grid: int = _b_occ.size() + _b_owner.size() * 4
	var unpadded: int = (_w - 2 * PAD) * (_h - 2 * PAD) * (_nl - 2 * PAD)
	_say("memory A %.2f MB (%d cells padded, %d unpadded; %d overflow claim(s)) · Ac %.2f MB (%d of %d chunk-levels allocated) · B %.2f MB (claims %.2f + xyz %.2f + derived grid %.2f; without xyz %.2f)" % [
		_mb(a), _a_state.size(), unpadded, _thirds(_a_overflow.size(), OVERFLOW_STRIDE),
		_mb(c), _c_slot_count, _c_dir.size(),
		_mb(b_arrays + b_xyz + b_grid), _mb(b_arrays), _mb(b_xyz), _mb(b_grid), _mb(b_arrays + b_grid)])
	_say("memory O objects: %d claims × 925 B (Moto, R3D-0) = %.1f MB · × 1 540 B (desktop debug) = %.1f MB" % [
		_claims, _mb(_claims * 925), _mb(_claims * 1540)])


## An exact whole division, written so it raises no INTEGER_DIVISION warning.
static func _thirds(total: int, stride: int) -> int:
	return floori(float(total) / float(stride))


static func _mb(bytes: int) -> float:
	return float(bytes) / 1048576.0


# ── kernels ───────────────────────────────────────────────────────────────────

func _run_kernel(layout: String, kernel: String) -> Array:
	match kernel + layout:
		"T1O":
			return _t1_o()
		"T1A":
			return _t1_flat(_a_state, BIT_OCCUPIED)
		"T1Ac":
			return _t1_c()
		"T1B":
			return _t1_flat(_b_occ, 1)
		"T2O":
			return _t2_o()
		"T2A":
			return _t2_a()
		"T2Ac":
			return _t2_c()
		"T2B":
			return _t2_b()
		"T3O":
			return _t3_o()
		"T3A":
			return _t3_a()
		"T3Ac":
			return _t3_c()
		"T3B":
			return _t3_b()
	push_error("[StoreLayoutSpike] no kernel %s for %s" % [kernel, layout])
	return []


## Which face `surface_factor()` picks: -1 enclosed, 0 top, 1 SE, 2 SW.
func _best_face(top: bool, se: bool, sw: bool) -> int:
	var factor: float = _fenc
	var best: int = -1
	if top and _ft >= factor:
		factor = _ft
		best = 0
	if se and _fse >= factor:
		factor = _fse
		best = 1
	if sw and _fsw >= factor:
		best = 2
	return best


func _t1_o() -> Array:
	var cells: PackedInt32Array = _t1_cells
	var occ: Dictionary = _o_occ
	var sum: int = 0
	var i: int = 0
	while i < cells.size():
		var cell := Vector2i(cells[i], cells[i + 1])
		var level: int = cells[i + 2]
		i += 3
		var s_here: Variant = occ.get(level)
		var s_above: Variant = occ.get(level + 1)
		var top: bool = s_above == null or not s_above.has(cell)
		var se: bool = s_here == null or not s_here.has(cell + Vector2i(1, 0))
		var sw: bool = s_here == null or not s_here.has(cell + Vector2i(0, 1))
		var best: int = _best_face(top, se, sw)
		var blocked: int = 0
		if best >= 0:
			var outward: Vector2i = cell
			var outward_level: int = level
			if best == 0:
				outward_level = level + 1
			elif best == 1:
				outward = cell + Vector2i(1, 0)
			else:
				outward = cell + Vector2i(0, 1)
			var s_out: Variant = occ.get(outward_level)
			var s_up: Variant = occ.get(outward_level + 1)
			var s_down: Variant = occ.get(outward_level - 1)
			if s_out != null:
				if best == 0:
					if s_out.has(outward + Vector2i(1, 0)): blocked += 1
					if s_out.has(outward + Vector2i(-1, 0)): blocked += 1
					if s_out.has(outward + Vector2i(0, 1)): blocked += 1
					if s_out.has(outward + Vector2i(0, -1)): blocked += 1
				elif best == 1:
					if s_out.has(outward + Vector2i(0, 1)): blocked += 1
					if s_out.has(outward + Vector2i(0, -1)): blocked += 1
				else:
					if s_out.has(outward + Vector2i(1, 0)): blocked += 1
					if s_out.has(outward + Vector2i(-1, 0)): blocked += 1
			if s_up != null and s_up.has(outward):
				blocked += 1
			if best != 0:
				if s_down != null and s_down.has(outward):
					blocked += 1
			elif s_out != null and s_out.has(outward + Vector2i(1, 1)):
				blocked += 1
		sum += (best + 1) * 16 + blocked
	return [_thirds(cells.size(), 3), sum]


## A and B share this: both answer occupancy from one flat byte grid.
func _t1_flat(grid: PackedByteArray, bit: int) -> Array:
	var cells: PackedInt32Array = _t1_cells
	var w: int = _w
	var plane: int = _plane
	var sum: int = 0
	var i: int = 0
	while i < cells.size():
		var here: int = ((cells[i + 2] - _l0) * _h + (cells[i + 1] - _y0)) * w + (cells[i] - _x0)
		i += 3
		var top: bool = (grid[here + plane] & bit) == 0
		var se: bool = (grid[here + 1] & bit) == 0
		var sw: bool = (grid[here + w] & bit) == 0
		var best: int = _best_face(top, se, sw)
		var blocked: int = 0
		if best >= 0:
			var out: int = here + plane if best == 0 else (here + 1 if best == 1 else here + w)
			if best == 0:
				if grid[out + 1] & bit: blocked += 1
				if grid[out - 1] & bit: blocked += 1
				if grid[out + w] & bit: blocked += 1
				if grid[out - w] & bit: blocked += 1
			elif best == 1:
				if grid[out + w] & bit: blocked += 1
				if grid[out - w] & bit: blocked += 1
			else:
				if grid[out + 1] & bit: blocked += 1
				if grid[out - 1] & bit: blocked += 1
			if grid[out + plane] & bit:
				blocked += 1
			if best != 0:
				if grid[out - plane] & bit:
					blocked += 1
			elif grid[out + 1 + w] & bit:
				blocked += 1
		sum += (best + 1) * 16 + blocked
	return [_thirds(cells.size(), 3), sum]


## Ac's occupancy read, written out at every use as production code would inline it:
## the chunk directory, then the slot. A helper function per read cost Ac a third of its
## T1 time on desktop in the first run — a cost of the spike, not of the layout.
func _t1_c() -> Array:
	var cells: PackedInt32Array = _t1_cells
	var dir: PackedInt32Array = _c_dir
	var st: PackedByteArray = _c_state
	var cw: int = _c_cw
	var ch: int = _c_ch
	var sum: int = 0
	var i: int = 0
	while i < cells.size():
		var rx: int = cells[i] - _x0
		var ry: int = cells[i + 1] - _y0
		var li: int = cells[i + 2] - _l0
		i += 3
		var t_s: int = dir[((li + 1) * ch + (ry >> CHUNK_SHIFT)) * cw + (rx >> CHUNK_SHIFT)]
		var top: bool = not (t_s >= 0 and (st[t_s * CHUNK_CELLS + ((ry & CHUNK_MASK) << CHUNK_SHIFT) + (rx & CHUNK_MASK)] & BIT_OCCUPIED) != 0)
		var e_s: int = dir[(li * ch + (ry >> CHUNK_SHIFT)) * cw + ((rx + 1) >> CHUNK_SHIFT)]
		var se: bool = not (e_s >= 0 and (st[e_s * CHUNK_CELLS + ((ry & CHUNK_MASK) << CHUNK_SHIFT) + ((rx + 1) & CHUNK_MASK)] & BIT_OCCUPIED) != 0)
		var s_s: int = dir[(li * ch + ((ry + 1) >> CHUNK_SHIFT)) * cw + (rx >> CHUNK_SHIFT)]
		var sw: bool = not (s_s >= 0 and (st[s_s * CHUNK_CELLS + (((ry + 1) & CHUNK_MASK) << CHUNK_SHIFT) + (rx & CHUNK_MASK)] & BIT_OCCUPIED) != 0)
		var best: int = _best_face(top, se, sw)
		var blocked: int = 0
		if best >= 0:
			var ox: int = rx + (1 if best == 1 else 0)
			var oy: int = ry + (1 if best == 2 else 0)
			var ol: int = li + (1 if best == 0 else 0)
			var _slot: int = 0
			if best == 0:
				_slot = dir[(ol * ch + (oy >> CHUNK_SHIFT)) * cw + ((ox + 1) >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + ((oy & CHUNK_MASK) << CHUNK_SHIFT) + ((ox + 1) & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
				_slot = dir[(ol * ch + (oy >> CHUNK_SHIFT)) * cw + ((ox - 1) >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + ((oy & CHUNK_MASK) << CHUNK_SHIFT) + ((ox - 1) & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
				_slot = dir[(ol * ch + ((oy + 1) >> CHUNK_SHIFT)) * cw + (ox >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + (((oy + 1) & CHUNK_MASK) << CHUNK_SHIFT) + (ox & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
				_slot = dir[(ol * ch + ((oy - 1) >> CHUNK_SHIFT)) * cw + (ox >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + (((oy - 1) & CHUNK_MASK) << CHUNK_SHIFT) + (ox & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
			elif best == 1:
				_slot = dir[(ol * ch + ((oy + 1) >> CHUNK_SHIFT)) * cw + (ox >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + (((oy + 1) & CHUNK_MASK) << CHUNK_SHIFT) + (ox & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
				_slot = dir[(ol * ch + ((oy - 1) >> CHUNK_SHIFT)) * cw + (ox >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + (((oy - 1) & CHUNK_MASK) << CHUNK_SHIFT) + (ox & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
			else:
				_slot = dir[(ol * ch + (oy >> CHUNK_SHIFT)) * cw + ((ox + 1) >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + ((oy & CHUNK_MASK) << CHUNK_SHIFT) + ((ox + 1) & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
				_slot = dir[(ol * ch + (oy >> CHUNK_SHIFT)) * cw + ((ox - 1) >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + ((oy & CHUNK_MASK) << CHUNK_SHIFT) + ((ox - 1) & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
			_slot = dir[((ol + 1) * ch + (oy >> CHUNK_SHIFT)) * cw + (ox >> CHUNK_SHIFT)]
			if _slot >= 0 and (st[_slot * CHUNK_CELLS + ((oy & CHUNK_MASK) << CHUNK_SHIFT) + (ox & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
				blocked += 1
			if best != 0:
				_slot = dir[((ol - 1) * ch + (oy >> CHUNK_SHIFT)) * cw + (ox >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + ((oy & CHUNK_MASK) << CHUNK_SHIFT) + (ox & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
			else:
				_slot = dir[(ol * ch + ((oy + 1) >> CHUNK_SHIFT)) * cw + ((ox + 1) >> CHUNK_SHIFT)]
				if _slot >= 0 and (st[_slot * CHUNK_CELLS + (((oy + 1) & CHUNK_MASK) << CHUNK_SHIFT) + ((ox + 1) & CHUNK_MASK)] & BIT_OCCUPIED) != 0:
					blocked += 1
		sum += (best + 1) * 16 + blocked
	return [_thirds(cells.size(), 3), sum]


func _t2_o() -> Array:
	var occ: Dictionary = _o_mesh
	var glass: PackedByteArray = _glass
	var faces := PackedInt32Array()
	var sum: int = 0
	for chunk: Vector2i in _o_by_chunk:
		for key: Vector3i in (_o_by_chunk[chunk] as Dictionary):
			var material: int = occ[key]
			var own_glass: int = glass[material]
			for dir: int in range(3):
				var neighbour: int = occ.get(key + DIR_STEP[dir], -1)
				if neighbour != -1 and not (glass[neighbour] == 1 and own_glass == 0):
					continue
				faces.append(dir)
				faces.append(key.y if dir == 0 else (key.x if dir == 1 else key.z))
				faces.append(material)
				sum += dir * 7 + material
	return [_thirds(faces.size(), 3), sum]


func _t2_a() -> Array:
	var state: PackedByteArray = _a_state
	var mat: PackedByteArray = _a_mat
	var glass: PackedByteArray = _glass
	var w: int = _w
	var plane: int = _plane
	var faces := PackedInt32Array()
	var sum: int = 0
	## Every level but the padding. A full-map scan is every chunk; a remesh walks the same
	## loop over its chunks' rows.
	for li in range(PAD, _nl - PAD):
		for ry in range(PAD, _h - PAD):
			var i: int = (li * _h + ry) * w + PAD
			var end: int = i + w - 2 * PAD
			while i < end:
				if state[i] & BIT_OCCUPIED:
					var material: int = mat[i]
					var own_glass: int = glass[material]
					var n: int = i + plane
					if not (state[n] & BIT_OCCUPIED) or (glass[mat[n]] == 1 and own_glass == 0):
						faces.append(0)
						faces.append(li + _l0)
						faces.append(material)
						sum += material
					n = i + 1
					if not (state[n] & BIT_OCCUPIED) or (glass[mat[n]] == 1 and own_glass == 0):
						faces.append(1)
						faces.append((i % w) + _x0)
						faces.append(material)
						sum += 7 + material
					n = i + w
					if not (state[n] & BIT_OCCUPIED) or (glass[mat[n]] == 1 and own_glass == 0):
						faces.append(2)
						faces.append(ry + _y0)
						faces.append(material)
						sum += 14 + material
				i += 1
	return [_thirds(faces.size(), 3), sum]


func _t2_c() -> Array:
	var state: PackedByteArray = _c_state
	var mat: PackedByteArray = _c_mat
	var glass: PackedByteArray = _glass
	var faces := PackedInt32Array()
	var sum: int = 0
	for slot in range(_c_slot_count):
		var li: int = _c_slots[slot * 3]
		var cx: int = _c_slots[slot * 3 + 1]
		var cy: int = _c_slots[slot * 3 + 2]
		var base: int = slot * CHUNK_CELLS
		## The next chunk along each axis, resolved once per chunk: a face on the chunk's
		## far edge reads its neighbour there.
		var up_slot: int = _c_dir[((li + 1) * _c_ch + cy) * _c_cw + cx] if li + 1 < _nl else -1
		var east_slot: int = _c_dir[(li * _c_ch + cy) * _c_cw + cx + 1] if cx + 1 < _c_cw else -1
		var south_slot: int = _c_dir[(li * _c_ch + cy + 1) * _c_cw + cx] if cy + 1 < _c_ch else -1
		for ly in range(CHUNK_CELLS >> CHUNK_SHIFT):
			for lx in range(CHUNK_CELLS >> CHUNK_SHIFT):
				var i: int = base + (ly << CHUNK_SHIFT) + lx
				if not (state[i] & BIT_OCCUPIED):
					continue
				var material: int = mat[i]
				var own_glass: int = glass[material]
				var n: int = -1
				if up_slot >= 0:
					n = up_slot * CHUNK_CELLS + (ly << CHUNK_SHIFT) + lx
				if n < 0 or not (state[n] & BIT_OCCUPIED) or (glass[mat[n]] == 1 and own_glass == 0):
					faces.append(0)
					faces.append(li + _l0)
					faces.append(material)
					sum += material
				if lx < CHUNK_MASK:
					n = i + 1
				elif east_slot >= 0:
					n = east_slot * CHUNK_CELLS + (ly << CHUNK_SHIFT)
				else:
					n = -1
				if n < 0 or not (state[n] & BIT_OCCUPIED) or (glass[mat[n]] == 1 and own_glass == 0):
					faces.append(1)
					faces.append((cx << CHUNK_SHIFT) + lx + _x0)
					faces.append(material)
					sum += 7 + material
				if ly < CHUNK_MASK:
					n = i + CHUNK_MASK + 1
				elif south_slot >= 0:
					n = south_slot * CHUNK_CELLS + lx
				else:
					n = -1
				if n < 0 or not (state[n] & BIT_OCCUPIED) or (glass[mat[n]] == 1 and own_glass == 0):
					faces.append(2)
					faces.append((cy << CHUNK_SHIFT) + ly + _y0)
					faces.append(material)
					sum += 14 + material
	return [_thirds(faces.size(), 3), sum]


func _t2_b() -> Array:
	var occ: PackedByteArray = _b_occ
	var owner: PackedInt32Array = _b_owner
	var state: PackedByteArray = _b_state
	var mat: PackedByteArray = _b_mat
	var xyz: PackedInt32Array = _b_xyz
	var glass: PackedByteArray = _glass
	var w: int = _w
	var plane: int = _plane
	var faces := PackedInt32Array()
	var sum: int = 0
	for claim in range(_claims):
		if not (state[claim] & BIT_VISIBLE):
			continue
		var x: int = xyz[claim * 3]
		var y: int = xyz[claim * 3 + 1]
		var level: int = xyz[claim * 3 + 2]
		var i: int = ((level - _l0) * _h + (y - _y0)) * w + (x - _x0)
		## A cell two claims hold is drawn once, by its owner.
		if owner[i] != claim:
			continue
		var material: int = mat[claim]
		var own_glass: int = glass[material]
		var n: int = i + plane
		if not occ[n] or (glass[mat[owner[n]]] == 1 and own_glass == 0):
			faces.append(0)
			faces.append(level)
			faces.append(material)
			sum += material
		n = i + 1
		if not occ[n] or (glass[mat[owner[n]]] == 1 and own_glass == 0):
			faces.append(1)
			faces.append(x)
			faces.append(material)
			sum += 7 + material
		n = i + w
		if not occ[n] or (glass[mat[owner[n]]] == 1 and own_glass == 0):
			faces.append(2)
			faces.append(y)
			faces.append(material)
			sum += 14 + material
	return [_thirds(faces.size(), 3), sum]


## T3's buckets, in one array: visible, blast seed, weapon seed, damaged, flammable, and a
## checksum over the seeds' cells.
func _t3_o() -> Array:
	var visible: int = 0
	var blast: int = 0
	var weapon: int = 0
	var damaged: int = 0
	var flammable: int = 0
	var cells: int = 0
	for entry: Array in _containers:
		var burns: bool = _flammability[int(entry[1])] > 0.0
		for v: Voxel in entry[0].voxels:
			var state: int = v.damage_state
			if burns:
				flammable += 1
			if not v.visible or state == DAMAGE_DESTROYED:
				if v.damage_is_blast:
					blast += 1
				else:
					weapon += 1
				cells += (v.grid_pos.x * 31 + v.grid_pos.y) * 31 + v.level
			elif state == DAMAGE_DENTED or state == DAMAGE_CRACKED:
				damaged += 1
			if v.visible:
				visible += 1
	return [visible, blast, weapon, damaged, flammable, cells]


## A's walk: every grid cell, then the overflow. The container's base material comes from
## the claim's container, which the grid does not hold — a production store keeps a
## per-claim container reference; here the reference is the claim ordinal, and the
## container's flammability is read through `claim_burns`.
func _t3_a() -> Array:
	return _t3_grid(_a_state, _a_ref, _a_overflow, _claim_burns())


func _t3_c() -> Array:
	return _t3_grid(_c_state, _c_ref, _c_overflow, _claim_burns())


var _burns_by_claim: PackedByteArray = []
func _claim_burns() -> PackedByteArray:
	if _burns_by_claim.is_empty():
		_burns_by_claim.resize(_claims)
		for ci in range(_containers.size()):
			var start: int = _b_offset[ci * 2]
			var burns: int = 1 if _flammability[int(_containers[ci][1])] > 0.0 else 0
			for claim in range(start, start + _b_offset[ci * 2 + 1]):
				_burns_by_claim[claim] = burns
	return _burns_by_claim


## The grid does not know each claim's cell coordinates without arithmetic, so the seed
## checksum is taken from the claim's own coordinates in B's xyz — the same numbers O
## sums, reached through the reference the grid does hold.
func _t3_grid(state: PackedByteArray, ref: PackedInt32Array, overflow: PackedInt32Array,
		burns_by_claim: PackedByteArray) -> Array:
	var xyz: PackedInt32Array = _b_xyz
	var visible: int = 0
	var blast: int = 0
	var weapon: int = 0
	var damaged: int = 0
	var flammable: int = 0
	var cells: int = 0
	var n: int = state.size()
	for i in range(n):
		var claim: int = ref[i]
		if claim < 0:
			continue
		var s: int = state[i]
		if burns_by_claim[claim]:
			flammable += 1
		var dmg: int = (s >> 1) & 3
		if not (s & BIT_VISIBLE) or dmg == DAMAGE_DESTROYED:
			if s & 8:
				blast += 1
			else:
				weapon += 1
			cells += (xyz[claim * 3] * 31 + xyz[claim * 3 + 1]) * 31 + xyz[claim * 3 + 2]
		elif dmg == DAMAGE_DENTED or dmg == DAMAGE_CRACKED:
			damaged += 1
		if s & BIT_VISIBLE:
			visible += 1
	var o: int = 0
	while o < overflow.size():
		var s2: int = overflow[o + 1]
		var claim2: int = overflow[o + 4]
		o += OVERFLOW_STRIDE
		if burns_by_claim[claim2]:
			flammable += 1
		var dmg2: int = (s2 >> 1) & 3
		if not (s2 & BIT_VISIBLE) or dmg2 == DAMAGE_DESTROYED:
			if s2 & 8:
				blast += 1
			else:
				weapon += 1
			cells += (xyz[claim2 * 3] * 31 + xyz[claim2 * 3 + 1]) * 31 + xyz[claim2 * 3 + 2]
		elif dmg2 == DAMAGE_DENTED or dmg2 == DAMAGE_CRACKED:
			damaged += 1
		if s2 & BIT_VISIBLE:
			visible += 1
	return [visible, blast, weapon, damaged, flammable, cells]


func _t3_b() -> Array:
	var state: PackedByteArray = _b_state
	var xyz: PackedInt32Array = _b_xyz
	var visible: int = 0
	var blast: int = 0
	var weapon: int = 0
	var damaged: int = 0
	var flammable: int = 0
	var cells: int = 0
	for ci in range(_containers.size()):
		var start: int = _b_offset[ci * 2]
		var burns: bool = _flammability[int(_containers[ci][1])] > 0.0
		for claim in range(start, start + _b_offset[ci * 2 + 1]):
			var s: int = state[claim]
			if burns:
				flammable += 1
			var dmg: int = (s >> 1) & 3
			if not (s & BIT_VISIBLE) or dmg == DAMAGE_DESTROYED:
				if s & 8:
					blast += 1
				else:
					weapon += 1
				cells += (xyz[claim * 3] * 31 + xyz[claim * 3 + 1]) * 31 + xyz[claim * 3 + 2]
			elif dmg == DAMAGE_DENTED or dmg == DAMAGE_CRACKED:
				damaged += 1
			if s & BIT_VISIBLE:
				visible += 1
	return [visible, blast, weapon, damaged, flammable, cells]


static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var mid: int = sorted.size() >> 1
	if sorted.size() % 2 == 1:
		return sorted[mid]
	return (sorted[mid - 1] + sorted[mid]) / 2.0


static func _join_ms(values: Array) -> String:
	var parts: PackedStringArray = []
	for v in values:
		parts.append("%.0f" % v)
	return "/".join(parts)
