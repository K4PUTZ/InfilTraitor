## Geometry Module — Voxel: single 32×32 voxel in a wall slice
## Port from voxel_ref.gd with damage state tracking
class_name Voxel

## CRACKED = flat surface mark, voxel stays full height ("voxel atingido ficou
## só marcado com a textura especial da bala"). DENTED = sunken special piece,
## more severe than CRACKED but short of DESTROYED ("1 voxel ficou meio
## afundado, pecinha especial com textura da bala") — DESTRUCTION_MASTER_PLAN
## D22 (Director, 2026-07-30). Appended rather than inserted so existing
## ordinals (used in persisted base-coord damage dicts) never shift.
enum DamageState { INTACT = 0, CRACKED = 1, DESTROYED = 2, DENTED = 3 }

var grid_pos: Vector2i           ## voxel cell coordinate
var level: int                   ## vertical storey index
var visible: bool = true         ## render state
var dirty: bool = false          ## marked for TIC processing
var damage_state: int = DamageState.INTACT
var face_atlas_rect: Rect2i      ## assigned by BakeSystem (VOXEL-08), null until baked
## VL-D1/D24: soot is NOT a field on Voxel — it is derived fresh every repaint
## from which nearby voxels are currently absent (room._build_soot_snapshot()
## -> BlastCalculator.derive_soot_rings()), never stored here. A destroyed
## voxel's absence already survives rotation via room._base_damage, so there
## is nothing extra to persist for soot to travel with the hole.

## DESTRUCTION_MASTER_PLAN D23 (Director, 2026-07-30): a DENTED/CRACKED mark
## reads differently depending on what caused it — a bullet leaves a round
## puncture, a blast leaves an irregular chip/crack ("a gente pode criar
## estados intermediários do material em explosões, mas não com furos
## redondos"). Sets which texture family VoxelRenderer.damage_variant_material()
## picks. Irrelevant for INTACT/DESTROYED (a hole is a hole regardless of
## cause), so only DENTED/CRACKED callers need to pass true.
var damage_is_blast: bool = false

## Back-reference for dirty propagation. Untyped on purpose: D1
## (DESTRUCTION_MASTER_PLAN) makes Voxel the single class shared by wall voxels
## (parent = Slice, owned by an Edge) and floor/ceiling/interior voxels (parent =
## Slab, D1 — no edge). GDScript has no shared interface type, so this holds
## either; both implement increment_dirty()/decrement_dirty()/id, which is the
## only contract Voxel actually needs from its container.
var _parent_container


func _init(p_grid_pos: Vector2i, p_level: int, parent_container):
	grid_pos = p_grid_pos
	level = p_level
	_parent_container = parent_container


## Set visibility; no-op if unchanged; propagates dirty upward
func set_visible(v: bool) -> void:
	if visible == v:
		return
	visible = v
	_set_dirty()


## Apply damage state; DESTROYED forces visible=false; propagates dirty upward.
## from_blast only matters for DENTED/CRACKED (see damage_is_blast above) and
## is read once, on the transition into that state — reapplying the same
## state (D20 stacking a second hit into an already-DENTED voxel, say) keeps
## whichever source marked it first, same as the early-return already did for
## damage_state itself.
func set_damage(new_state: int, from_blast: bool = false) -> void:
	if damage_state == new_state:
		return
	damage_state = new_state
	damage_is_blast = from_blast
	if new_state == DamageState.DESTROYED:
		visible = false
	_set_dirty()


## Clear dirty flag (called by TIC loop after render update)
func clear_dirty() -> void:
	if dirty:
		dirty = false
		_parent_container.decrement_dirty()


## Internal: mark dirty and propagate
func _set_dirty() -> void:
	if not dirty:
		dirty = true
		_parent_container.increment_dirty()


func _to_string() -> String:
	return "Voxel{pos=%s, level=%d, visible=%s, damage=%d}" % [grid_pos, level, visible, damage_state]
