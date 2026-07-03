## Geometry Module — Coordinate constants and conversions
## Ported from legacy coordinate system; validated by SLICE-00 Transform Canon
class_name GeometryCoords

## Voxel grid subdivisions per Gameplay Unit
const VOXELS_PER_UNIT_AXIS: int = 8

## Isometric tile dimensions (DIAMOND_DOWN layout)
const VOXEL_TILE_SIZE: Vector2i = Vector2i(32, 16)

## Pixel step per voxel row (vertical increment per level)
const VOXEL_STEP_PX: float = 20.0

## Storey height in pixels: 8 voxels × 20 px/voxel
const VOXEL_STOREY_HEIGHT_PX: float = 160.0

## Voxel atom dimensions
const VOXEL_ATOM_W: int = 32     ## width
const VOXEL_ATOM_H: int = 36     ## height: 16 top face + 20 side face
const VOXEL_TILE_H: int = 16     ## tile height (top face only)


## Derived texture origin constant (Transform Canon 3 from SLICE-00)
## = (VOXEL_ATOM_H - VOXEL_TILE_H) / 2
## = (36 - 16) / 2
## = (0, 10)
static func voxel_texture_origin() -> Vector2i:
	return Vector2i(0, int((VOXEL_ATOM_H - VOXEL_TILE_H) / 2.0))


## Gameplay Unit cell → voxel grid origin (Canon 4)
## Returns the top-left voxel cell of the given Gameplay Unit
## All 64 voxels of the GU are in the 8×8 box starting at this origin
static func gu_to_voxel_origin(gu: Vector2i) -> Vector2i:
	return gu * VOXELS_PER_UNIT_AXIS


## Voxel cell → parent Gameplay Unit (inverse of above)
## Returns the GU containing the given voxel cell
static func voxel_to_gu(v: Vector2i) -> Vector2i:
	return v / float(VOXELS_PER_UNIT_AXIS)


## Voxel cell → local offset within its Gameplay Unit
## Returns offset in range [0, 7] for both x and y
static func voxel_local(v: Vector2i) -> Vector2i:
	return v % VOXELS_PER_UNIT_AXIS


## All 64 voxel cells contained in a Gameplay Unit
## Returns array in scan order: y varies outer, x varies inner
static func gu_voxels(gu: Vector2i) -> Array[Vector2i]:
	var origin := gu_to_voxel_origin(gu)
	var result: Array[Vector2i] = []
	for dy in range(VOXELS_PER_UNIT_AXIS):
		for dx in range(VOXELS_PER_UNIT_AXIS):
			result.append(origin + Vector2i(dx, dy))
	return result
