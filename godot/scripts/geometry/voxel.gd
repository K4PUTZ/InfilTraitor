## Geometry Module — Voxel: single 32×32 voxel in a wall slice
## Port from voxel_ref.gd with damage state tracking
class_name Voxel

enum DamageState { INTACT = 0, CRACKED = 1, DESTROYED = 2 }

var grid_pos: Vector2i           ## voxel cell coordinate
var level: int                   ## vertical storey index
var visible: bool = true         ## render state
var dirty: bool = false          ## marked for TIC processing
var damage_state: int = DamageState.INTACT
var face_atlas_rect: Rect2i      ## assigned by BakeSystem (VOXEL-08), null until baked
## VL-D1: blast soot ring. -1 = clean; 0 = adjacent to a hole (darkest scorch),
## rising to fainter outer rings. Set by BlastCalculator.compute_soot_rings()
## and consumed by VoxelLightField as a per-voxel darkening on top of the light
## bucket. Rides on the Voxel itself so it shares the damage's fate through
## perspective rotation — soot and its hole travel together.
var soot_ring: int = -1

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


## Apply damage state; DESTROYED forces visible=false; propagates dirty upward
func set_damage(new_state: int) -> void:
	if damage_state == new_state:
		return
	damage_state = new_state
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
