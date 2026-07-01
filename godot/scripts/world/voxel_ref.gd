class_name VoxelRef
## Estado de um voxel individual no plano de render Voxel (VOXEL series).
## Uma instância por posição × nível vertical dentro de um WallSlice.
##
## Renderização:  room._voxel_layers[level].set_cell / erase_cell (VOXEL-04+).
## Dirty flag:    set_visible / set_damage marcam dirty = true.
##                O TIC loop processa voxels com dirty = true (VOXEL-07).
## Propagação:    dirty_count no WallSlice pai é incrementado pelo caller —
##                não há back-reference nesta classe (vem em VOXEL-06/07).
## face_atlas_rect: preenchido pelo BakeSystem em VOXEL-08; ignorado até lá.

## Estados de dano. Usar com set_damage().
const DAMAGE_INTACT:    int = 0   ## visual completo
const DAMAGE_CRACKED:   int = 1   ## overlay de dano (VOXEL-10)
const DAMAGE_DESTROYED: int = 2   ## invisível; erase_cell no próximo TIC

var grid_pos:        Vector2i = Vector2i.ZERO
var level:           int      = 0
var visible:         bool     = true
var dirty:           bool     = false
var damage_state:    int      = DAMAGE_INTACT
var face_atlas_rect: Rect2i   = Rect2i()   ## set by BakeSystem (VOXEL-08)
var _parent_slice: WallSlice  = null        ## set by WallSlice._set_parent_voxel() (VOXEL-07)

func _init(pos: Vector2i, lv: int) -> void:
	grid_pos = pos
	level    = lv


func _set_parent_slice(slice: WallSlice) -> void:
	## Called from WallSlice during voxel append. Enables dirty propagation.
	_parent_slice = slice

## Altera visibilidade. No-op se o valor não muda (não suja dirty).
## Propaga dirty_count ao WallSlice pai se existir (VOXEL-07).
func set_visible(v: bool) -> void:
	if visible == v:
		return
	visible = v
	dirty   = true
	if _parent_slice != null:
		_parent_slice.increment_dirty()


## Aplica estado de dano. DAMAGE_DESTROYED força visible = false.
## Propaga dirty_count ao WallSlice pai se existir (VOXEL-07).
func set_damage(state: int) -> void:
	damage_state = clamp(state, DAMAGE_INTACT, DAMAGE_DESTROYED)
	if damage_state == DAMAGE_DESTROYED:
		visible = false
	dirty = true
	if _parent_slice != null:
		_parent_slice.increment_dirty()

## Limpa o dirty flag após o TIC ter aplicado o estado ao TileMapLayer.
func clear_dirty() -> void:
	dirty = false
