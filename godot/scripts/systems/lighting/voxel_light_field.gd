## VoxelLightField — per-voxel light BUCKET data (VL-01, VOXEL_LIGHT_MASTER_PLAN).
##
## The single seam between tactical lighting (LightRegistry / ShadowProjector,
## GU resolution) and every VISUAL consumer. VoxelRenderer.apply_light_field()
## reads it to repaint faces; future vision modes (thermal / night / X-ray)
## query it instead of touching tilemaps. Canon split preserved: this consumes
## LightSource.visual_energy, never tactical_energy — visual brightness is not
## tactical visibility.
##
## Deterministic and discrete: same lights + same layout always produce the
## same bucket per (cell, level). No per-frame work — built on lighting_rebuilt,
## queried lazily with a cache.

class_name VoxelLightField
extends RefCounted

## Tuning — all `var` (Rule 1). Starting values Director-ratified 2026-07-23.
var ambient_intensity: float = 0.10        ## floor term when a map HAS lights
var no_lights_bucket: int = 5              ## maps with zero lights stay full lit
var facing_dark_ratio: float = 0.60        ## Q3: mild penalty, faces pointing away
var vertical_gu_per_storey: float = 0.5    ## level distance → GU-equivalent scale
## Falloff shape (canon #4: binary-dominant — mostly full-lit or full-shadow,
## not a smooth ramp). Within inner_full_ratio × radius the lamp reads at full
## strength; beyond it, a quick ramp to 0 at the radius edge.
var inner_full_ratio: float = 0.45

var _lights: Array = []                    ## Array[LightSource] (active set)
var _shadow_by_light: Dictionary = {}      ## light instance_id -> ShadowResult
var _top_wall_level: int = 0               ## highest built voxel layer (OVERHEAD anchor)
var _bucket_cache: Dictionary = {}         ## Vector3i(cell.x, cell.y, level) -> int


## Rebuild the field from the current lighting state. Called from room on every
## lighting_rebuilt (map load, perspective rotation, light change) — the cache
## resets because any input may have moved.
## top_wall_level: the highest built voxel layer (VoxelRenderer.get_layer_count()
## − 1) — where an OVERHEAD lamp hangs. NOT the ceiling-fixture height
## (max_floors), which is an 8-storey render artifact that would place the lamp
## far above the real walls and zero out every contribution via vertical falloff.
func build(lights: Array, shadow_results: Array, top_wall_level: int) -> void:
	_lights = lights
	_top_wall_level = maxi(top_wall_level, 0)
	_shadow_by_light.clear()
	_bucket_cache.clear()
	for result in shadow_results:
		if result != null and result.source_light != null:
			_shadow_by_light[result.source_light.get_instance_id()] = result


## Bucket for one voxel cell at one layer level. 0 = darkest … 5 = full lit.
func bucket_for(cell: Vector2i, level: int) -> int:
	if _lights.is_empty():
		return no_lights_bucket
	var key := Vector3i(cell.x, cell.y, level)
	if _bucket_cache.has(key):
		return _bucket_cache[key]
	var bucket: int = _compute_bucket(cell, level)
	_bucket_cache[key] = bucket
	return bucket


func _compute_bucket(cell: Vector2i, level: int) -> int:
	## Voxel cell → owning GU: floor division by 8 (>> stays a floor for
	## negative floor-plane cells, unlike integer /).
	var gu := Vector2i(cell.x >> 3, cell.y >> 3)
	var intensity: float = ambient_intensity
	for light in _lights:
		if not light.active:
			continue
		## GU-level occlusion gate: reuse the ShadowProjector's result for this
		## light — a GU it marks shadowed receives nothing from it.
		var shadow = _shadow_by_light.get(light.get_instance_id())
		if shadow != null and shadow.is_shadowed(gu):
			continue
		var radius := maxf(float(light.radius), 0.001)
		var d_gu := Vector2(light.cell - gu).length()
		if d_gu > radius:
			continue
		var d_lvl := absf(float(level - _anchor_level(light))) \
				/ float(GeometryCoords.LEVELS_PER_STOREY) * vertical_gu_per_storey
		var d := sqrt(d_gu * d_gu + d_lvl * d_lvl)
		var falloff := _falloff(d, radius)
		var term: float = float(light.visual_energy) * falloff * _facing_factor(cell, gu, light, level)
		intensity = maxf(intensity, term)
	return clampi(roundi(intensity * float(VoxelRenderer.LIGHT_BUCKET_COUNT - 1)),
			0, VoxelRenderer.LIGHT_BUCKET_COUNT - 1)


## Binary-dominant falloff (canon #4): a bright plateau out to inner_full_ratio ×
## radius, then a fast linear ramp to 0 at the edge. Keeps most in-range voxels
## near full-lit and most out-of-range voxels at ambient, rather than smearing
## everything through the middle buckets.
func _falloff(d: float, radius: float) -> float:
	var inner := radius * inner_full_ratio
	if d <= inner:
		return 1.0
	if d >= radius:
		return 0.0
	return 1.0 - (d - inner) / (radius - inner)


## Q1 (Director-ratified 2026-07-23): height_class → anchor voxel level.
## OVERHEAD anchors at the ceiling of the map's fixture height (max_floors from
## the compiled layout — same source the ceiling_lift formula uses).
func _anchor_level(light) -> int:
	match light.height_class:
		LightSource.HEIGHT_FLOOR:
			return 0
		LightSource.HEIGHT_LOW_COVER:
			return 2
		LightSource.HEIGHT_HUMAN:
			return 4
		LightSource.HEIGHT_TALL_STRUCTURE:
			return 6
		_:
			return _top_wall_level


## Q3 v1 facing factor. With the fixed S-side camera, a wall cell's visible
## side face points SE (+X axis) when the cell sits on a GU column border and
## SW (+Y axis) on a row border (vertex-aligned compass, DIRECTION_GLOSSARY).
## A face whose lamp sits behind it gets facing_dark_ratio; corner cells take
## the friendlier of their two faces. Floor-plane cells (level < 0) and
## interior cells face UP — no penalty.
func _facing_factor(cell: Vector2i, gu: Vector2i, light, level: int) -> float:
	if level < 0:
		return 1.0
	var local_x: int = cell.x - (gu.x << 3)
	var local_y: int = cell.y - (gu.y << 3)
	var on_col_border: bool = local_x == 0 or local_x == 7
	var on_row_border: bool = local_y == 0 or local_y == 7
	if not on_col_border and not on_row_border:
		return 1.0
	var factor: float = 0.0
	if on_col_border:
		factor = maxf(factor, 1.0 if light.cell.x >= gu.x else facing_dark_ratio)
	if on_row_border:
		factor = maxf(factor, 1.0 if light.cell.y >= gu.y else facing_dark_ratio)
	return factor
