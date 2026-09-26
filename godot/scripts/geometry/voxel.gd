## Geometry Module — Voxel: thin index wrapper over one claim in VoxelStore
## RENDER3D R3D-1d: Voxel used to duplicate every field VoxelStore now packs. Since
## R3D-1c closed with all five readers on the store, that duplication was ~191 MB on the
## Moto for nothing the store didn't already answer. Voxel keeps its exact public surface
## (grid_pos, level, visible, damage_state, ..., set_damage(), set_visible()) so every
## existing caller (room.gd, agent_shot_controller.gd, blast_calculator.gd, glass_crack.gd,
## Slice/Slab/JunctionColumn) is unchanged — only what sits behind that surface moved to
## VoxelStore's packed arrays, addressed by `claim`.
class_name Voxel

## Kept in sync with VoxelStore's packing (state byte bits 1-2). Values pinned — see the
## historical note this enum used to carry: persisted base-coord damage dicts store these
## ordinals, so they never shift.
enum DamageState { INTACT = 0, CRACKED = 1, DESTROYED = 2, DENTED = 3 }
enum CarvedSide { NONE = 0, TOP = 1, BOTTOM = 2, LEFT = 3, RIGHT = 4 }

var grid_pos: Vector2i           ## voxel cell coordinate — addressing, not state
var level: int                   ## vertical storey index — addressing, not state
var dirty: bool = false          ## marked for TIC processing; per-wrapper, not store state

## The claim this wrapper resolves to in `VoxelStore.active`, or -1 before the store is
## built (assigned once, by `VoxelStore._fill()`, right after this wrapper's container is
## given a claim range) or on a detached `WorldDelta` projection, which is never a claim
## by design (see `_LocalState` below).
var claim: int = -1

## A voxel with no claim (`claim < 0`: before the store is built, or a detached copy such as the ones
## `WorldDelta.project_voxel()` handed out until R3D-END) has no store to read its damage fields from, but
## adding those fields directly to `Voxel` would make every one of PLAYGROUND's 216 104 REAL voxels pay
## for the few claimless voxels' storage. This lazy side object is that "somewhere
## else": null on every real (claimed) voxel, allocated only when a claimless voxel's fields
## are actually written.
class _LocalState:
	var damage_state: int = DamageState.INTACT
	var damage_is_blast: bool = false
	var damage_carved_side: int = CarvedSide.NONE
	var damage_variant: int = 0
	var damage_substrate: int = 0
	var visible: bool = true

var _local: _LocalState = null

## Back-reference for dirty propagation, held as an INSTANCE ID and never as a reference —
## see LEAK-CYCLE-01 (2026-08-17): storing the container itself closed a reference cycle
## (container holds `voxels`, each Voxel held the container back) that Godot's RefCounted
## never collects. GDScript has no shared interface type, so this is duck-typed:
## increment_dirty()/decrement_dirty() is the entire contract Voxel needs from its
## container (Slice, Slab or JunctionColumn).
var _parent_container_id: int = 0


func container_id() -> int:
	return _parent_container_id


func _init(p_grid_pos: Vector2i, p_level: int, parent_container):
	grid_pos = p_grid_pos
	level = p_level
	_parent_container_id = 0 if parent_container == null else parent_container.get_instance_id()


func _store() -> VoxelStore:
	return VoxelStore.active


func _local_state() -> _LocalState:
	if _local == null:
		_local = _LocalState.new()
	return _local


## visible: render state. DESTROYED forces this false — VoxelStore.set_damage() enforces
## that at the write, same rule the old set_damage() applied inline. A detached
## projection (claim < 0, no store) reads/writes its own `_local` copy instead — see
## `_LocalState`'s doc.
var visible: bool:
	get:
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			return (store.state[claim] & 1) == 1
		return _local.visible if _local != null else true
	set(v):
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			set_visible(v)
		else:
			_local_state().visible = v

## A direct assignment (as opposed to set_damage()) is a RAW field poke — no early
## return, no dirty flag, no soot-seed recording, exactly like the plain `var` this
## used to be. A real (claimed) voxel pokes the store's byte directly; a detached
## projection (claim < 0) pokes its own `_local` copy instead.
var damage_state: int:
	get:
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			return (store.state[claim] >> 1) & 3
		return _local.damage_state if _local != null else DamageState.INTACT
	set(v):
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			store.state[claim] = (store.state[claim] & ~0b0110) | ((v & 3) << 1)
			store._recompute_cell(claim)
		else:
			_local_state().damage_state = v

## D23 (Director, 2026-07-30): a DENTED/CRACKED mark reads differently depending on
## whether a bullet (round puncture) or a blast (irregular chip/crack) caused it.
var damage_is_blast: bool:
	get:
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			return (store.state[claim] & 8) != 0
		return _local.damage_is_blast if _local != null else false
	set(v):
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			store.state[claim] = (store.state[claim] & ~0b1000) | ((1 if v else 0) << 3)
		else:
			_local_state().damage_is_blast = v

## D25: which side of a blast-DENTED half-voxel faced the explosion. VIEW space — valid
## only for the perspective it was computed under; room._reapply_base_damage() recomputes
## it from persisted base-space direction on every rotation.
var damage_carved_side: int:
	get:
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			return (store.state[claim] >> 4) & 7
		return _local.damage_carved_side if _local != null else CarvedSide.NONE
	set(v):
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			store.state[claim] = (store.state[claim] & ~0b1110000) | ((v & 7) << 4)
		else:
			_local_state().damage_carved_side = v

## D32: which of the authored decal variants this mark uses — rolled once by the
## damaging caller, read-once on the transition into a damaged state.
var damage_variant: int:
	get:
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			return store.aux[claim] & 15
		return _local.damage_variant if _local != null else 0
	set(v):
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			store.aux[claim] = (store.aux[claim] & ~0x0F) | (v & 15)
		else:
			_local_state().damage_variant = v

## D3/§3.3: which pre-baked substrate crop this mark's decal sits on.
var damage_substrate: int:
	get:
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			return (store.aux[claim] >> 4) & 15
		return _local.damage_substrate if _local != null else 0
	set(v):
		var store: VoxelStore = _store()
		if store != null and claim >= 0:
			store.aux[claim] = (store.aux[claim] & ~0xF0) | ((v & 15) << 4)
		else:
			_local_state().damage_substrate = v


## Set visibility; no-op if unchanged; propagates dirty upward.
func set_visible(v: bool) -> void:
	var store: VoxelStore = _store()
	if store == null or claim < 0:
		push_error("[Voxel] set_visible: no active store or claim (claim=%d)" % claim)
		return
	if not store.set_visible(claim, v):
		return
	_set_dirty()


## Apply damage state; DESTROYED forces visible=false; propagates dirty upward. See
## VoxelStore.set_damage() for the read-once-on-transition rules (from_blast, carved_side,
## variant, substrate) this forwards to — identical to the old inline behaviour.
func set_damage(new_state: int, from_blast: bool = false,
		carved_side: int = CarvedSide.NONE, variant: int = 0, substrate: int = 0) -> void:
	var store: VoxelStore = _store()
	if store == null or claim < 0:
		push_error("[Voxel] set_damage: no active store or claim (claim=%d)" % claim)
		return
	if not store.set_damage(claim, new_state, from_blast, carved_side, variant, substrate):
		return
	_set_dirty()


## Clear dirty flag (called by TIC loop after render update)
func clear_dirty() -> void:
	if dirty:
		dirty = false
		instance_from_id(_parent_container_id).decrement_dirty()


## Internal: mark dirty and propagate
func _set_dirty() -> void:
	if not dirty:
		dirty = true
		instance_from_id(_parent_container_id).increment_dirty()


func _to_string() -> String:
	return "Voxel{pos=%s, level=%d, claim=%d, visible=%s, damage=%d}" \
		% [grid_pos, level, claim, visible, damage_state]
