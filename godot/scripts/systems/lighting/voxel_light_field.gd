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
var ambient_intensity: float = 0.15        ## floor term when a map HAS lights
var no_lights_bucket: int = -1             ## <0 = top bucket; maps w/o lights stay lit
var vertical_gu_per_storey: float = 0.5    ## level distance → GU-equivalent scale
## Falloff shape (canon #4: binary-dominant — mostly full-lit or full-shadow,
## not a smooth ramp). Within inner_full_ratio × radius the lamp reads at full
## strength; beyond it, a quick ramp to 0 at the radius edge.
var inner_full_ratio: float = 0.45

## VL-02b — SURFACE SHADING. Light alone could not make a blast crater read: two
## voxels a few centimetres apart get the same lamp distance, and the only
## occlusion term available (ShadowProjector) is GU-resolution — 8×8 voxels, far
## too coarse to shadow a hole. These per-voxel geometry terms supply the local
## contrast instead. Purely visual; GU tactical shadows are untouched (canon).
##
## Axis factors: with the fixed camera each atom shows a top diamond and a front
## face, so orienting brightness by WHICH face is exposed gives the silhouette
## its 3D read (standard voxel practice). Top catches most light, the two lateral
## axes differ so the two visible sides of a block never read flat.
## Director 2026-07-24: widen the SE↔SW spread for a stronger 3D read, lifting
## overall brightness at the same time — so the two lateral factors move DOWN
## for contrast while ambient/bucket floors move UP to keep the scene readable.
var face_top_factor: float = 1.00
var face_se_factor: float = 0.74           ## +X neighbour empty → SE-ish face shows
var face_sw_factor: float = 0.48           ## +Y neighbour empty → SW-ish face shows
var face_enclosed_factor: float = 0.30     ## nothing exposed (interior fill)
## Cavity AO: a voxel ringed by solid neighbours at its own level sits in a pit,
## so light does not reach it. This is what actually darkens the inside of a
## crater — the newly-exposed faces of a blast hole keep their axis factor, but
## the recessed ones behind them fall away, and the hole reads as depth.
var ao_strength: float = 0.55              ## 0 = no AO, 1 = full darkening at 4/4

## VL-D1 — blast soot. A per-voxel scorch that MULTIPLIES the light term, so a
## sooted face still reads brighter in light than in shadow (soot modulates, it
## doesn't paint flat black). Ring 0 (touching the hole) is darkest. The values
## push a lit voxel down into the reserved dark buckets (bucket_luminance 0..1),
## which is what makes the crater halo read; tune against a real capture.
## Director 2026-07-24: soot need not go near-black — let a bit of texture show
## through. Lifted from [0.10,0.28,0.55]; paired with the raised dark buckets.
var soot_darkening: Array[float] = [0.16, 0.36, 0.60]  ## ring 0/1/2 multiplier

## VL-D3 — floor voxels that sat under a wall/block never saw the sun, so when a
## blast exposes their top they read darker than always-open floor. A gentle
## multiplier (Director: "uma sombrinha um pouco mais forte pra diferenciar").
var under_structure_factor: float = 0.68

var _lights: Array = []                    ## Array[LightSource] (active set)
var _shadow_by_light: Dictionary = {}      ## light instance_id -> ShadowResult
var _top_wall_level: int = 0               ## highest built voxel layer (OVERHEAD anchor)
var _occupancy: Dictionary = {}            ## level:int -> {Vector2i: true}
var _soot: Dictionary = {}                 ## level:int -> {Vector2i: ring}
var _under_structure: Dictionary = {}      ## {Vector2i: true} floor cols under structure (VL-D3)
var _bucket_cache: Dictionary = {}         ## Vector3i(cell.x, cell.y, level) -> int
var _lamp_cache: Dictionary = {}           ## Vector3i(gu.x, gu.y, level) -> float (VL-PERF)


## Rebuild the field from the current lighting state. Called from room on every
## lighting_rebuilt (map load, perspective rotation, light change) — the cache
## resets because any input may have moved.
## top_wall_level: the highest built voxel layer (VoxelRenderer.get_layer_count()
## − 1) — where an OVERHEAD lamp hangs. NOT the ceiling-fixture height
## (max_floors), which is an 8-storey render artifact that would place the lamp
## far above the real walls and zero out every contribution via vertical falloff.
## occupancy: level -> set of occupied cells, supplied by VoxelRenderer (it owns
## the tilemaps). Drives the surface/AO terms above; empty = shading disabled.
## soot: level -> {cell: ring}, from the blast (VL-D1); empty = no scorch.
## under_structure: {cell: true} floor columns that had a wall above at load
## (VL-D3); their floor voxels read darker once exposed.
func build(lights: Array, shadow_results: Array, top_wall_level: int,
		occupancy: Dictionary = {}, soot: Dictionary = {},
		under_structure: Dictionary = {}) -> void:
	_lights = lights
	_top_wall_level = maxi(top_wall_level, 0)
	_occupancy = occupancy
	_soot = soot
	_under_structure = under_structure
	_shadow_by_light.clear()
	_bucket_cache.clear()
	_lamp_cache.clear()
	for result in shadow_results:
		if result != null and result.source_light != null:
			_shadow_by_light[result.source_light.get_instance_id()] = result


## Bucket for one voxel cell at one layer level. 0 = darkest … N-1 = full lit.
func bucket_for(cell: Vector2i, level: int) -> int:
	var key := Vector3i(cell.x, cell.y, level)
	if _bucket_cache.has(key):
		return _bucket_cache[key]
	var bucket: int = _compute_bucket(cell, level)
	_bucket_cache[key] = bucket
	return bucket


func _compute_bucket(cell: Vector2i, level: int) -> int:
	var top_bucket: int = VoxelRenderer.LIGHT_BUCKET_COUNT - 1
	## The lamp term is a GU-resolution quantity (the falloff is measured GU→GU),
	## so all 64 voxels of a GU column at one level share it — compute once per
	## (GU, level) and cache. This was the repaint's hot loop: the sqrt-per-light
	## ran 108k× when ~5k distinct (GU, level) pairs would do (VL-PERF).
	var gu := Vector2i(cell.x >> 3, cell.y >> 3)
	var intensity: float = _lamp_intensity(gu, level, top_bucket)
	## VL-02b: local geometry contrast — the term that makes craters read.
	intensity *= surface_factor(cell, level)
	## VL-D1: blast soot — scorch the voxels ringing a hole.
	intensity *= soot_factor(cell, level)
	## VL-D3: floor that was under a wall reads darker once exposed.
	if level < 0 and _under_structure.has(cell):
		intensity *= under_structure_factor
	return clampi(roundi(intensity * float(top_bucket)), 0, top_bucket)


## Lamp-only intensity for a GU column at one level, cached per (GU, level).
func _lamp_intensity(gu: Vector2i, level: int, top_bucket: int) -> float:
	var key := Vector3i(gu.x, gu.y, level)
	if _lamp_cache.has(key):
		return _lamp_cache[key]
	## A map with no lights reads as fully lit rather than pitch black, but still
	## takes the surface shading in the caller — that gives an unlit test map its
	## geometry read.
	var intensity: float = 1.0 if no_lights_bucket < 0 else float(no_lights_bucket) / float(top_bucket)
	if not _lights.is_empty():
		intensity = ambient_intensity
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
			## VL-03: energy_multiplier carries the temporal state (flicker/pulse).
			var lamp_energy := float(light.visual_energy) * float(light.energy_multiplier)
			intensity = maxf(intensity, lamp_energy * _falloff(d, radius))
	_lamp_cache[key] = intensity
	return intensity


## VL-D1 — soot multiplier for a voxel (1.0 = clean). Public for vision modes /
## tests. Ring 0 (touching a hole) is darkest; missing = clean.
func soot_factor(cell: Vector2i, level: int) -> float:
	var level_soot = _soot.get(level)
	if level_soot == null:
		return 1.0
	var ring = level_soot.get(cell, -1)
	if ring < 0:
		return 1.0
	return soot_darkening[clampi(ring, 0, soot_darkening.size() - 1)]


## VL-02b — per-voxel surface shading from neighbour occupancy: axis factor for
## whichever face is exposed, times cavity AO. Public so vision modes and tests
## can inspect it independently of the lamp term.
##
## Screen geometry (DIAMOND_DOWN, N view): column +1 → (+16,+8) and row +1 →
## (−16,+8), so BOTH +X and +Y move toward the viewer, and level+1 moves up.
## A voxel therefore shows its top face when level+1 is empty, its SE-ish face
## when +X is empty, and its SW-ish face when +Y is empty.
func surface_factor(cell: Vector2i, level: int) -> float:
	if _occupancy.is_empty():
		return 1.0
	## VL-PERF: fetch each level's occupancy set ONCE (the hot loop re-fetched
	## _occupancy.get(level) ~9× per voxel). Only 4 levels are ever touched here.
	var s_here: Variant = _occupancy.get(level)
	var s_above: Variant = _occupancy.get(level + 1)
	var exposed_top: bool = s_above == null or not s_above.has(cell)
	var exposed_se: bool = s_here == null or not s_here.has(cell + Vector2i(1, 0))
	var exposed_sw: bool = s_here == null or not s_here.has(cell + Vector2i(0, 1))

	## The brightest visible face wins — that is the one the camera actually sees.
	var factor: float = face_enclosed_factor
	var best_face: int = -1                       ## 0 = top, 1 = SE, 2 = SW
	if exposed_top and face_top_factor >= factor:
		factor = face_top_factor
		best_face = 0
	if exposed_se and face_se_factor >= factor:
		factor = face_se_factor
		best_face = 1
	if exposed_sw and face_sw_factor >= factor:
		factor = face_sw_factor
		best_face = 2
	if best_face < 0:
		return factor
	return factor * (1.0 - ao_strength * _face_occlusion(cell, level, best_face))


## Fraction (0..1) of the hemisphere in front of a visible face that is blocked
## by nearby solid voxels — contact/ambient occlusion at voxel resolution.
##
## Counting the voxel's OWN lateral neighbours (the obvious first cut, and what
## VL-02b shipped first) is wrong for this geometry: a flush wall voxel already
## has solid neighbours all along the wall plane, so it darkened exactly as much
## as a recess and holes stayed invisible. What separates a notch from a flush
## face is the geometry ringing the EMPTY cell the face looks out into — a blast
## notch is walled on several sides, open air is not. Sampling there is what
## makes a crater read as depth rather than as a recoloured patch.
func _face_occlusion(cell: Vector2i, level: int, face: int) -> float:
	var outward: Vector2i = cell
	var outward_level: int = level
	var ring: Array = []
	match face:
		0:  ## top face — hemisphere is the level above
			outward_level = level + 1
			ring = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		1:  ## SE-ish face — hemisphere is the +X cell
			outward = cell + Vector2i(1, 0)
			ring = [Vector2i(0, 1), Vector2i(0, -1)]
		_:  ## SW-ish face — hemisphere is the +Y cell
			outward = cell + Vector2i(0, 1)
			ring = [Vector2i(1, 0), Vector2i(-1, 0)]

	## VL-PERF: fetch the three touched level sets once instead of per-neighbour.
	var s_out: Variant = _occupancy.get(outward_level)
	var s_up: Variant = _occupancy.get(outward_level + 1)
	var s_down: Variant = _occupancy.get(outward_level - 1)
	var blocked: int = 0
	var total: int = ring.size() + 2
	if s_out != null:
		for delta in ring:
			if s_out.has(outward + delta):
				blocked += 1
	## Vertical pair: for the lateral faces the cells directly above/below the
	## opening; for the top face the cell two levels up (an overhang) and the
	## opening's own far side.
	if s_up != null and s_up.has(outward):
		blocked += 1
	if face != 0:
		if s_down != null and s_down.has(outward):
			blocked += 1
	elif s_out != null and s_out.has(outward + Vector2i(1, 1)):
		blocked += 1
	return float(blocked) / float(total)


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


## VL-01's border-guess facing factor was REMOVED by VL-02b. It inferred a wall's
## axis from a cell's position inside its GU (local_x/local_y on 0 or 7), which
## only holds for slice-built walls — solid blocks and slabs have interior cells
## on no border at all — and it could not see destruction: a blown-open voxel
## kept whatever factor its original position implied. surface_factor() derives
## the same intent from real neighbour occupancy instead, so it stays correct as
## geometry changes.
