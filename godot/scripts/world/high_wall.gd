class_name HighWall
## Container secundário do sistema Voxel.
## Agrupa WallSlices nomeados + voxels de junção extra (V-junction corners).
## Unidade de baking secundário: uma textura cobre todos os voxels constituintes.
##
## dirty_count: soma dos dirty_counts dos slices filhos.
##              Gerido pelo VoxelRegistry / TIC loop (VOXEL-06 / VOXEL-07).
## voxel_bounds: bounding box em coordenadas de voxel; preenchido em VOXEL-04
##               quando os slices são adicionados.

var id:              String     = ""
var slices:          Array      = []     ## Array[WallSlice]
var junction_extras: Array      = []     ## Array[VoxelRef] — colunas extra de V-junction
var bake_texture:    Texture2D  = null   ## atribuído pelo BakeSystem (VOXEL-08)
var baked:           bool       = false
var dirty_count:     int        = 0
var voxel_bounds:    Rect2i     = Rect2i()   ## preenchido em VOXEL-04

## Retorna o WallSlice com o id dado, ou null se não encontrado.
func get_slice(slice_id: String):
	for s in slices:
		if s.id == slice_id:
			return s
	return null

## Número total de VoxelRefs (slices + extras de junção).
func total_voxel_count() -> int:
	var n: int = junction_extras.size()
	for s in slices:
		n += s.total_voxel_count()
	return n

## Todos os VoxelRefs em ordem: slices primeiro, extras de junção por último.
## Usado pelo BakeSystem para iterar num único passo (VOXEL-08/09).
func all_voxels() -> Array:
	var out: Array = []
	for s: WallSlice in slices:
		out.append_array(s.voxels)
	out.append_array(junction_extras)
	return out
