## EarthVariantSelector — DESTRUCTION_MASTER_PLAN D2/D4 core.
##
## Floor/slab voxels don't have corners or continuous facade planes to project
## (unlike walls) — they're just a small pre-authored palette of voxel atoms,
## scattered across the grid by a deterministic hash of position. This is the
## whole mechanism: no shear, no junction compositor, no per-map baking step.
##
## Determinism is the entire point (D5): hash(x, y, level) is recomputed
## identically forever, never stored. A voxel's look never changes just
## because a neighbour got destroyed and exposed it — there is nothing to
## "pop" because nothing was ever assigned; it's re-derived the same way
## every time it's looked at.
class_name EarthVariantSelector

const VARIANT_COUNT: int = 8

const ASSET_PATH_TEMPLATE: String = "res://ASSETS/ISOMETRIC/source_assets/voxels/materials/voxel_earth_%d.png"


## Deterministic variant index in [0, VARIANT_COUNT) for one voxel position.
## Same (grid_pos, level) always returns the same index — on every machine,
## every run, forever. Reuses FacadeSampler's pinned FNV-1a (B4) rather than
## a second copy of the algorithm.
static func variant_for(grid_pos: Vector2i, level: int) -> int:
	var key := "%d,%d,%d" % [grid_pos.x, grid_pos.y, level]
	var hash_val: int = FacadeSampler._fnv1a_hash(key)
	return hash_val % VARIANT_COUNT


## Asset path for one variant index, matching generate_voxel.py's output
## naming (voxel_earth_0.png .. voxel_earth_7.png).
static func variant_asset_path(variant_index: int) -> String:
	return ASSET_PATH_TEMPLATE % variant_index
