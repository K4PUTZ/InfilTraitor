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

var _parent_slice: Slice         ## back-reference for dirty propagation


func _init(p_grid_pos: Vector2i, p_level: int, parent_slice: Slice):
	grid_pos = p_grid_pos
	level = p_level
	_parent_slice = parent_slice


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
		_parent_slice.decrement_dirty()


## Internal: mark dirty and propagate
func _set_dirty() -> void:
	if not dirty:
		dirty = true
		_parent_slice.increment_dirty()


func _to_string() -> String:
	return "Voxel{pos=%s, level=%d, visible=%s, damage=%d}" % [grid_pos, level, visible, damage_state]
