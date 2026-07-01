class_name WallSlice
## Container primário do sistema Voxel.
## Representa uma face de parede: 1 direção × 1 GU adjacente × N andares.
## Cada aresta de GAME UNIT produz 2 WallSlices (slice_index 0=inner, 1=outer).
## Voxels: 8 × (8 × storey_count) = 64 por andar.
##
## dirty_count: incrementado pelo caller quando VoxelRef.dirty é marcado.
##              Decrementado / zerado pelo TIC loop após processar (VOXEL-07).

var id:               String   = ""
var direction:        String   = ""          ## "NW" | "NE" | "SE" | "SW"
var slice_index:      int      = 0           ## 0 = inner (GU primário), 1 = outer (GU adjacente)
var gu_cell:          Vector2i = Vector2i.ZERO  ## GU primário (coordenada de gameplay)
var storey_count:     int      = 1
var voxels:           Array    = []          ## Array[VoxelRef], 64 × storey_count
var dirty_count:      int      = 0
var baked:            bool     = false
var parent_high_wall: String   = ""          ## id do HighWall pai; "" se standalone
var _parent_hw: HighWall       = null        ## set by HighWall._set_parent_hw() (VOXEL-07)

## Retorna o VoxelRef no índice linear dado, ou null se fora de bounds.
func get_voxel(index: int):
	if index < 0 or index >= voxels.size():
		return null
	return voxels[index]

## Número total de VoxelRefs neste slice (= 64 × storey_count em uso normal).
func total_voxel_count() -> int:
	return voxels.size()

## Marca todos os voxels como dirty e actualiza dirty_count.
## Usado em rebuild de sala ou debug — não chama set_visible.
func mark_all_dirty() -> void:
	for v in voxels:
		v.dirty = true
	dirty_count = voxels.size()


func _set_parent_hw(hw: HighWall) -> void:
	## Called from HighWall during slice append. Enables dirty propagation.
	_parent_hw = hw


func increment_dirty() -> void:
	## Increment dirty counter when child voxel is marked dirty.
	## Propagate upward to HighWall.
	dirty_count += 1
	if _parent_hw != null:
		_parent_hw.increment_dirty()


func clear_dirty() -> void:
	## Called from TIC loop after slice processed.
	## Recursively clear all voxel dirty flags.
	for voxel in voxels:
		voxel.clear_dirty()
	dirty_count = 0
