## VoxelStore — the packed voxel store, THE writer and the only place voxel state lives.
##
## RENDER3D R3D-1b (`RENDER3D_MASTER_PLAN` §4) built this as a SHADOW beside the `Voxel`
## objects: every claim's state in flat per-voxel arrays, contiguous per container, plus
## a derived dense grid that answers "is this cell occupied, and by which claim". R3D-1c
## moved every reader onto it, one subsystem at a time, gated against the objects.
##
## R3D-1d removed the objects. `Voxel` is now a thin wrapper (`claim: int` + this store) —
## it holds no state of its own, so there is nothing left to mirror. `set_damage()` /
## `set_visible()` below ARE the write seam; `Voxel.set_damage()` / `set_visible()` just
## forward to them and record dirty bookkeeping.
##
## Built from the registries after every board build (`Room._rebuild_voxel_store()`).
## `BoardProbe.write_store()` dumps it for `board_probe.py gate`.
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

## The active store — every `Voxel` wrapper reads and writes through this one. Static:
## a `Voxel` holds no reference to anything that could reach it.
static var active: VoxelStore = null

## R3D-13: the `STORE_GLASS` / `STORE_BLAST` comparison switches are deleted. Since R3D-1d `Voxel` has no state of its own,
## so `cells_of()` / `damage_of()` / `visible_of()` read the active store when it holds the container or voxel, and the
## objects otherwise (a selftest fixture, a store built for another board).
const CELL_STRIDE: int = 4

var claims: int = 0
var state := PackedByteArray()
var aux := PackedByteArray()
var mat := PackedByteArray()
var xyz := PackedInt32Array()
## RENDER3D R3D-14 — per claim, 0 = not a glass PANE voxel, else the pane's face + 1 (`Face`: NW 0, NE 1, SE 2, SW 3).
## What the renderer routes to its pane layer, decided once at build so the glass state can be asked of the store
## instead of a hidden `TileMapLayer`: a slice's voxel whose (band-resolved) material is glass, on the slice's face;
## a glass INTERIOR slab's voxel (a glazed partition), face NW as `render_slab_solid()` passes it. A CEILING or FLOOR
## slab and a junction column are never panes. Immutable after the build: presence is `pane != 0` AND visible.
var pane := PackedByteArray()
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


## ⚠️ WRITTEN FOR THE LOAD. The first version made three passes over every voxel, resolved
## each voxel's material by string (`material_at()` + a Dictionary lookup, 216 104 times)
## and called four helper functions per voxel: 3.26 s of the Moto's map load, +3.0–3.2 s
## boot to map (R3D-1c's A/B). This one reads each voxel's fields once per pass, resolves a
## material once per container (once per level on a banded slice), inlines the packing and
## the cell index, and fills the derived grid in the same pass.
func _fill(containers: Array) -> bool:
	## Pass 1 — each container's box, and the map's from the boxes.
	var boxes := PackedInt32Array()
	boxes.resize(containers.size() * 6)
	var total: int = 0
	var min_x: int = 1 << 30
	var min_y: int = 1 << 30
	var min_l: int = 1 << 30
	var max_x: int = -(1 << 30)
	var max_y: int = -(1 << 30)
	var max_l: int = -(1 << 30)
	for ci in range(containers.size()):
		var bx: int = 1 << 30
		var by: int = 1 << 30
		var bl: int = 1 << 30
		var ex: int = -(1 << 30)
		var ey: int = -(1 << 30)
		var el: int = -(1 << 30)
		for v: Voxel in containers[ci][0].voxels:
			var gp: Vector2i = v.grid_pos
			var lv: int = v.level
			if gp.x < bx: bx = gp.x
			if gp.x > ex: ex = gp.x
			if gp.y < by: by = gp.y
			if gp.y > ey: ey = gp.y
			if lv < bl: bl = lv
			if lv > el: el = lv
			total += 1
		var g: int = ci * 6
		boxes[g] = bx
		boxes[g + 1] = by
		boxes[g + 2] = bl
		boxes[g + 3] = ex
		boxes[g + 4] = ey
		boxes[g + 5] = el
		if ex >= bx:
			min_x = mini(min_x, bx)
			max_x = maxi(max_x, ex)
			min_y = mini(min_y, by)
			max_y = maxi(max_y, ey)
			min_l = mini(min_l, bl)
			max_l = maxi(max_l, el)
	claims = total
	state.resize(total)
	aux.resize(total)
	mat.resize(total)
	pane.resize(total)
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

	## Pass 2 — the claims and the grid.
	var claim: int = 0
	for ci in range(containers.size()):
		var container: Object = containers[ci][0]
		var voxels: Array = container.voxels
		var n: int = voxels.size()
		container_ids.append(str(container.get("id")))
		container_kinds.append(containers[ci][1])
		_by_instance[container.get_instance_id()] = ci
		var g: int = ci * 6
		var bx: int = boxes[g]
		var by: int = boxes[g + 1]
		var bl: int = boxes[g + 2]
		var nx: int = boxes[g + 3] - bx + 1 if n > 0 else 0
		var ny: int = boxes[g + 4] - by + 1 if n > 0 else 0
		var regular: bool = n == 0 or nx * ny * (boxes[g + 5] - bl + 1) == n
		_geom.append_array(PackedInt32Array([claim, n, bx, by, bl, nx, ny]))
		## The material once for the container, or once per level on a banded slice.
		var fixed_material: int = -1
		var banded: Slice = null
		var band_base: int = 0
		var by_level: Dictionary = {}
		## The pane byte of this container (see `pane`), once; per level on a banded slice.
		var fixed_pane: int = 0
		var pane_by_level: Dictionary = {}
		if container is Slice and (container as Slice).has_material_bands():
			banded = container
			band_base = GeometryCoords.storey_level_base(banded.start_storey)
		elif n > 0:
			var fixed_id: String = _voxel_material(container, voxels[0])
			fixed_material = _material(fixed_id)
			if GlassMaterials.is_glass(fixed_id):
				if container is Slice:
					fixed_pane = (container as Slice).face + 1
				elif container is Slab and (container as Slab).role == Slab.Role.INTERIOR:
					fixed_pane = Face.NW + 1
		for i in range(n):
			var v: Voxel = voxels[i]
			var gp: Vector2i = v.grid_pos
			var lv: int = v.level
			if regular and ((lv - bl) * ny + (gp.y - by)) * nx + (gp.x - bx) != i:
				regular = false
			## RENDER3D R3D-1d: this container's voxels are freshly generated here, every
			## build — `Room._rebuild_voxel_store()` nulls `VoxelStore.active` before
			## calling `build()`, so `v` cannot be reading a PREVIOUS store's claim. A
			## fresh voxel is always INTACT and visible; any real damage is replayed from
			## `room._base_damage` after this build finishes, through `set_damage()`,
			## which is the only place `state`/`aux` change again.
			var visible: int = 1
			state[claim] = visible | (Voxel.DamageState.INTACT << 1)
			aux[claim] = 0
			v.claim = claim
			if banded == null:
				mat[claim] = fixed_material
				if fixed_pane != 0:
					pane[claim] = fixed_pane
			else:
				if not by_level.has(lv):
					var band_id: String = banded.material_at(lv - band_base)
					by_level[lv] = _material(band_id)
					pane_by_level[lv] = banded.face + 1 if GlassMaterials.is_glass(band_id) else 0
				mat[claim] = by_level[lv]
				if int(pane_by_level[lv]) != 0:
					pane[claim] = int(pane_by_level[lv])
			var k: int = claim * 3
			xyz[k] = gp.x
			xyz[k + 1] = gp.y
			xyz[k + 2] = lv
			var cell: int = ((lv - l0) * h + (gp.y - y0)) * w + (gp.x - x0)
			if owner[cell] == -1:
				owner[cell] = claim
				occ[cell] = visible
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
			for i in range(n):
				var v2: Voxel = voxels[i]
				table[Vector3i(v2.grid_pos.x, v2.grid_pos.y, v2.level)] = _geom[ci * GEOM_STRIDE] + i
			_irregular[ci] = table
	if _material_index.size() > 256:
		push_error("[VoxelStore] build: %d materials — a byte holds 256" % _material_index.size())
		return false
	for cell: int in _multi:
		_resolve_cell(cell)
	return true


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


## True when a visible voxel occupies the cell. Bounds-checked: a flood can name a cell the
## store's box does not hold.
func has_cell(x: int, y: int, level: int) -> bool:
	if x < x0 or y < y0 or level < l0 or x >= x0 + w or y >= y0 + h or level >= l0 + nl:
		return false
	return occ[cell_index(x, y, level)] != 0


## SOOT-STAMP — a voxel that is not DESTROYED holds this cell, visible or not. Soot is
## stamped onto hidden voxels too, so a wall face a later event reveals comes up
## already scorched instead of needing a special case. `owner` prefers the visible
## claim of a shared cell, so a shared cell answers for its visible voxel first.
func has_solid(x: int, y: int, level: int) -> bool:
	if x < x0 or y < y0 or level < l0 or x >= x0 + w or y >= y0 + h or level >= l0 + nl:
		return false
	var claim: int = owner[cell_index(x, y, level)]
	return claim >= 0 and ((state[claim] >> 1) & 3) != Voxel.DamageState.DESTROYED


static func state_byte(v: Voxel) -> int:
	return (1 if v.visible else 0) | (v.damage_state << 1) \
		| ((1 if v.damage_is_blast else 0) << 3) | (v.damage_carved_side << 4)


static func aux_byte(v: Voxel) -> int:
	return (v.damage_variant & 15) | ((v.damage_substrate & 15) << 4)


## The claim a voxel is, or -1 when the store does not hold its container. RENDER3D
## R3D-1d: `_fill()` assigns `v.claim` directly at build time, so this is now a plain
## accessor — kept named for every existing caller (`mirror()`, the selftests, glass and
## the WALK) rather than inlining `v.claim` everywhere.
func claim_of(v: Voxel) -> int:
	return v.claim


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


## Writes a claim's visibility. Returns false (no-op) if unchanged — same early-return
## `Voxel.set_visible()` always had. THE write seam since R3D-1d; `Voxel.set_visible()`
## forwards here and then does its own dirty-flag bookkeeping.
func set_visible(claim: int, v: bool) -> bool:
	if claim < 0 or claim >= claims:
		push_error("[VoxelStore] set_visible: claim %d out of range (%d claims)" % [claim, claims])
		return false
	var new_bit: int = 1 if v else 0
	if (state[claim] & 1) == new_bit:
		return false
	state[claim] = (state[claim] & ~1) | new_bit
	_recompute_cell(claim)
	return true


## Writes a claim's damage state. Returns false (no-op) if `new_state` matches the
## current one — same early-return `Voxel.set_damage()` always had (also why `variant`/
## `carved_side`/`substrate` are read-once: a repeated call on an already-damaged claim
## never reaches this far). DESTROYED forces visible=false. THE write seam since R3D-1d.
##
## `variant`/`substrate` pack into one nibble each (real callers only ever need 0-4, per
## D32/D3 §3.3), and `carved_side` into 3 bits — R3D-1d made this the PERMANENT
## representation (it used to be a lossy shadow mirror beside the real, unbounded
## `Voxel` field). A value the packing cannot hold must abort loudly, never wrap silently
## into a different, valid-looking value — the exact failure `board_probe_selftest.gd`'s
## TEST 5 exists to catch.
func set_damage(claim: int, new_state: int, from_blast: bool, carved_side: int,
		variant: int, substrate: int) -> bool:
	if claim < 0 or claim >= claims:
		push_error("[VoxelStore] set_damage: claim %d out of range (%d claims)" % [claim, claims])
		return false
	if new_state < 0 or new_state > 3 or carved_side < 0 or carved_side > 7 \
			or variant < 0 or variant > 15 or substrate < 0 or substrate > 15:
		push_error("[VoxelStore] set_damage: claim %d holds a value the packing cannot: state %d, carved %d, variant %d, substrate %d"
			% [claim, new_state, carved_side, variant, substrate])
		return false
	var cur_state: int = (state[claim] >> 1) & 3
	if cur_state == new_state:
		return false
	var new_visible: int = 0 if new_state == Voxel.DamageState.DESTROYED else state[claim] & 1
	state[claim] = new_visible | (new_state << 1) | ((1 if from_blast else 0) << 3) \
		| (carved_side << 4)
	aux[claim] = (variant & 15) | ((substrate & 15) << 4)
	_recompute_cell(claim)
	return true


## Shared by `set_visible()`/`set_damage()`: refreshes the derived grid cell a claim's
## write may have changed — `_resolve_cell()` when other claims share the cell, else a
## direct `occ` write, exactly as `mirror()` (the R3D-1b/c shadow write) already did.
func _recompute_cell(claim: int) -> void:
	var cell: int = cell_index(xyz[claim * 3], xyz[claim * 3 + 1], xyz[claim * 3 + 2])
	if _multi.has(cell):
		_resolve_cell(cell)
	else:
		occ[cell] = state[claim] & 1


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


## The occupancy the world will have once the claims in `gone` (claim -> true) are no longer visible.
## Per CLAIM, where `occupancy_dict(predict_destroyed)` is per cell: a box corner is held by two slices and
## a junction column by the column plus the slices around it, the plan destroys them one claim at a time,
## and a cell is empty only when NO claim of it stays visible. Erasing the cell for the first destroyed
## claim emptied cells the committed world still holds (R3D-13: 9 and 17 cells after PLAYGROUND's two
## grenades), which put the cook's light 21 and 13 cells away from a full relight.
func occupancy_dict_after(gone: Dictionary) -> Dictionary:
	var out: Dictionary = occupancy_dict()
	for claim: int in gone:
		var i: int = claim * 3
		var x: int = xyz[i]
		var y: int = xyz[i + 1]
		var level: int = xyz[i + 2]
		var li: int = level - l0
		if li < PAD or li >= nl - PAD:
			continue
		var survives: bool = false
		var cell: int = cell_index(x, y, level)
		if _multi.has(cell):
			for other: int in _multi[cell]:
				if (state[other] & 1) and not gone.has(other):
					survives = true
					break
		if not survives:
			(out[level] as Dictionary).erase(Vector2i(x, y))
	return out


## RENDER3D R3D-14 — the face + 1 of the VISIBLE glass pane voxel that holds this cell, or 0 when none does. The glass
## state's one question (`VoxelRenderer._glass_cell_present()`, the crack's cut mask, the opening walk), answered from the
## claims. A cell two claims hold answers for the LAST visible pane of them: the layer this replaces was written in claim order
## and the last writer won (64 such corner cells on GLASS, whose atoms carried the later pane's face). Bounds-checked like `has_cell()`.
func glass_pane_face_at(x: int, y: int, level: int) -> int:
	if x < x0 or y < y0 or level < l0 or x >= x0 + w or y >= y0 + h or level >= l0 + nl:
		return 0
	var cell: int = cell_index(x, y, level)
	if occ[cell] == 0:
		return 0
	if _multi.has(cell):
		var list: PackedInt32Array = _multi[cell]
		for i in range(list.size() - 1, -1, -1):
			var claim: int = list[i]
			if (state[claim] & 1) == 1 and pane[claim] != 0:
				return pane[claim]
		return 0
	var owner_claim: int = owner[cell]
	if owner_claim >= 0 and (state[owner_claim] & 1) == 1:
		return pane[owner_claim]
	return 0


## True when a visible glass pane voxel holds the cell.
func has_glass_pane(x: int, y: int, level: int) -> bool:
	return glass_pane_face_at(x, y, level) != 0


## x, y, level and state byte of every voxel of `container`, in the container's own order
## (stride `CELL_STRIDE`). From the active store when it holds the container, else off the
## objects. State: bit 0 visible, bits 1–2 damage — `state_byte()`'s packing.
static func cells_of(container: Object, use_store: bool = true) -> PackedInt32Array:
	var out := PackedInt32Array()
	var store: VoxelStore = active
	if use_store and store != null:
		var ci: int = store._by_instance.get(container.get_instance_id(), -1)
		if ci >= 0:
			var g: int = ci * GEOM_STRIDE
			var offset: int = store._geom[g]
			var n: int = store._geom[g + 1]
			out.resize(n * CELL_STRIDE)
			for i in range(n):
				var claim: int = offset + i
				var o: int = i * CELL_STRIDE
				out[o] = store.xyz[claim * 3]
				out[o + 1] = store.xyz[claim * 3 + 1]
				out[o + 2] = store.xyz[claim * 3 + 2]
				out[o + 3] = store.state[claim]
			return out
	var voxels: Array = container.voxels
	out.resize(voxels.size() * CELL_STRIDE)
	for i in range(voxels.size()):
		var v: Voxel = voxels[i]
		var o: int = i * CELL_STRIDE
		out[o] = v.grid_pos.x
		out[o + 1] = v.grid_pos.y
		out[o + 2] = v.level
		out[o + 3] = state_byte(v)
	return out


## A voxel's damage state, from the active store when it holds the voxel.
static func damage_of(v: Voxel, use_store: bool = true) -> int:
	var store: VoxelStore = active
	if use_store and store != null:
		var claim: int = store.claim_of(v)
		if claim >= 0:
			return (store.state[claim] >> 1) & 3
	return v.damage_state


## A voxel's visibility, from the active store when it holds the voxel.
static func visible_of(v: Voxel) -> bool:
	var store: VoxelStore = active
	if store != null:
		var claim: int = store.claim_of(v)
		if claim >= 0:
			return (store.state[claim] & 1) == 1
	return v.visible


func container_count() -> int:
	return container_ids.size()


func container_claims(ci: int) -> Vector2i:
	return Vector2i(_geom[ci * GEOM_STRIDE], _geom[ci * GEOM_STRIDE + 1])


func irregular_containers() -> int:
	return _irregular.size()


func multi_cells() -> int:
	return _multi.size()


func bytes() -> int:
	return state.size() + aux.size() + mat.size() + pane.size() + xyz.size() * 4 + occ.size() \
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
