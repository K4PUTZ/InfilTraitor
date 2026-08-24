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
## Director 2026-07-26: one more small step the same direction — stone's own
## dark, high-detail texture already reads as "scorched enough" at full
## strength (VL-D5 finding: the mechanism is materially strong, up to 84%
## darkening at ring 0, correct and confirmed by probe — the ask was to ease
## the overall opacity a touch, not to fix a broken effect).
## FACE-SOOT-01 (Director, 2026-08-01): soot is no longer folded into the light
## BUCKET — it is delivered per FACE and applied in the shader (see
## encode_face_soot() below and voxel_face_shading.gdshader). It had to move: a
## bucket is ONE scalar per cell, so as long as soot lived inside it the three
## faces of a voxel could not carry different amounts of scorch by construction.
## This array therefore no longer reaches the renderer — it stays here as the
## canonical ring→darkening curve that the shader's `soot_face_mult` is
## calibrated against, and as the value `soot_factor()` still reports to probes,
## selftests and (future) vision modes.
## PERF-02 B3-2: ring 0/1/2/3 multiplier. The first three are UNCHANGED, so a
## firearm's 3-ring scorch renders exactly as it did; ring 3 is new and only a
## blast reaches it (see Room.blast_soot_rings), which is what makes the bomb's
## extra distance a real gradient step instead of a flat band of the faintest
## tone. Isotropic reference curve — the shader's per-face multipliers are
## calibrated against it, not derived from it.
var soot_darkening: Array[float] = [0.20, 0.40, 0.63, 0.80]

## VL-D3 — floor voxels that sat under a wall/block never saw the sun, so when a
## blast exposes their top they read darker than always-open floor. A gentle
## multiplier (Director: "uma sombrinha um pouco mais forte pra diferenciar").
var under_structure_factor: float = 0.68

## FACE-READ-01 (Director, 2026-07-31) — per-voxel micro brightness variation.
## *"Não é necessário que o material seja composto de voxels com a mesma
## aparência exata [...] podemos diminuir um pouquinho o brilho do voxel todo
## pra dar uma micro diferenciada."*
##
## Unlike the three-tone atom art (generate_voxel.py), this lives in the light
## field, so it reaches EVERY surface including the photographically baked ones
## — measured necessary: the atom-art change moved only 0.25% of a real
## detonation capture, confined to the impact-mark and D25 carved voxels, which
## are the only ones that bypass the baked lookup. A baked wall takes its pixels
## from the facade page and never sees a change made here in art.
##
## DEFAULT 0 — OFF, and it should stay off unless the luminance channel itself
## changes. This mechanism cannot be made "micro" where it matters, and that is
## a property of the channel, not of the tuning:
##
##   1. As a MULTIPLIER on the continuous factor it is invisible. A 10% jitter
##      moved only 19% of crater pixels, by a mean of 1.15/255, and *lowered*
##      the region's standard deviation — the 12-bucket quantisation ate it.
##   2. As a ±1 step on the QUANTISED index it always lands, but
##      VoxelRenderer.bucket_luminance is compressed at the dark end
##      (0.12 → 0.20 → 0.33 = +67%, +65% per step, against +8% at the top), so
##      one step is a far bigger perceptual jump in shadow than in light.
##      Measured against a neutral capture, stratified by brightness: 6.7% in
##      the darkest band falling to 4.1% in the brightest — strongest exactly
##      where the Director reported it reading as noise ("veja nas zonas mais
##      escuras como varia demais").
##
## The per-FACE shader (godot/shaders/voxel_face_shading.gdshader) does the same
## job correctly because it MULTIPLIES colour instead of stepping an index, so
## its effect is perceptually flat: measured 1.6% → 3.3% across the same
## brightness bands. Face differentiation is also what the Director actually
## asked for — *"o grande segredo é só diferenciar as 3 faces de cada voxel."*
##
## Kept rather than deleted because the mechanism is sound and would become
## usable the moment the luminance ramp gains resolution at its dark end; the
## measurements above are what a future attempt needs in order not to repeat
## this. If re-enabled, note that SOOTED VOXELS ARE EXEMPT in _compute_bucket()
## — also measured: jittering them erased the crater rings outright (mean
## luminance 41.1 → 26.6, mid-tone band 9% → 0% of pixels), because soot lives
## in this same channel and only spans buckets 0-2.
##
## Deterministic per voxel via the project's FNV-1a hash — B4 discipline, so it
## is stable across rebuilds and identical between an incremental and a fresh
## build. Purely visual: LIGHT_MASTER_PLAN's canon split means brightness is
## never tactical visibility, so this cannot move a gameplay number.
var micro_jitter_buckets: int = 0

var _lights: Array = []                    ## Array[LightSource] (active set)
var _shadow_by_light: Dictionary = {}      ## light instance_id -> ShadowResult
var _top_wall_level: int = 0               ## highest built voxel layer (OVERHEAD anchor)
var _occupancy: Dictionary = {}            ## level:int -> {Vector2i: true}
var _soot: Dictionary = {}                 ## level:int -> {Vector2i: ring}
## FACE-SOOT-01 — level -> {Vector2i: Vector3i(ring_top, ring_se, ring_sw)},
## from BlastCalculator.derive_soot_rings()'s out_faces. Empty = no directional
## data, in which case face_soot_code() falls back to the voxel's own ring on all
## three faces (exactly the pre-FACE-SOOT-01 behaviour), which is what keeps the
## crater-floor cells merged by room._build_soot_snapshot() rendering correctly.
var _face_soot: Dictionary = {}
var _under_structure: Dictionary = {}      ## {Vector2i: true} floor cols under structure (VL-D3)
var _bucket_cache: Dictionary = {}         ## Vector3i(cell.x, cell.y, level) -> int

## PERF-10 — THE STALE SET, ACCUMULATED, so an apply can be driven by it.
##
## `build(geometry_only)` already computes exactly which cached cells the incoming
## occupancy/soot invalidate (`_stale_cells()`), uses it to erase cache entries and
## then throws it away. §10.1 measured the map-wide apply at ~610 ms of WALK to
## write 96 cells of 205 384, so that discarded set is the difference between a
## walk over the board and a walk over the work.
##
## ⚠️ ACCUMULATED, NOT PER-BUILD, and that is the whole correctness argument. A
## fire runs many scoped builds before its final repaint, and each one's stale set
## is only the delta since the PREVIOUS build. The final repaint's job is to fix
## staleness accumulated across all of them, so the set has to be a union — reset
## only when something actually repaints every cell it names.
##
## `_stale_total` means "everything is stale": a non-geometry_only build cleared
## the caches wholesale, so no subset describes the work and the caller must fall
## back to the map-wide apply. It is the honest answer, not a failure.
var _stale_accum: Dictionary = {}          ## Vector3i -> true, since the last full apply
var _stale_total: bool = true              ## true = no subset is valid; walk everything
var _lamp_cache: Dictionary = {}           ## Vector3i(gu.x, gu.y, level) -> float (VL-PERF)
## VL-03 — surface_factor × soot_factor × under_structure_factor for one voxel,
## cached SEPARATELY from the lamp term and NOT cleared by clear_caches(). None
## of those three terms depend on which lights are on — only geometry/soot/cover
## do — so a temporal light toggle (which changes ONLY energy_multiplier) can
## reuse every one of these across the toggle. Measured need: a single flicker
## toggle over a 149-GU/29k-voxel influence set cost ~84ms recomputing this
## exact product from scratch every time (clear_caches() used to nuke
## _bucket_cache wholesale) — this cache is what makes the toggle cheap.
var _static_factor_cache: Dictionary = {}  ## Vector3i(cell.x, cell.y, level) -> float


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
## face_soot: level -> {cell: Vector3i(top, se, sw)} (FACE-SOOT-01); optional,
## and absent entries fall back to the voxel's own isotropic ring.
## PERF-03 — `geometry_only` says: LIGHTS, SHADOWS, top_wall_level and cover are
## unchanged since the last build; only occupancy and soot moved. That is
## exactly a detonation (TestZoneController.detonate_active() repaints directly
## and never re-runs the shadow projector), and it is what lets this keep the
## caches instead of dropping them. Defaults FALSE, so every other caller —
## map load, perspective rotation, real light changes — keeps the unconditional
## clear it always had.
##
## Why it pays: measured on a real PLAYGROUND blast, the repaint walked 106,847
## cells to change 1,303 of them, and spent 362ms inside bucket_for() because
## build() had just emptied the cache that would have answered for all of them.
## _static_factor's own doc already anticipated this reuse ("a detonation no
## longer has to invalidate the light bucket of every voxel it scorches") — the
## wholesale clear here is what defeated it.
func build(lights: Array, shadow_results: Array, top_wall_level: int,
		occupancy: Dictionary = {}, soot: Dictionary = {},
		under_structure: Dictionary = {}, face_soot: Dictionary = {},
		geometry_only: bool = false) -> void:
	var stale: Dictionary = {}
	if geometry_only:
		stale = _stale_cells(occupancy, soot, face_soot)
		for skey in stale:
			_stale_accum[skey] = true
	else:
		## Every cache is about to be dropped, so every cell is stale and the
		## accumulator cannot describe the work any more.
		_stale_total = true
		_stale_accum.clear()
	_lights = lights
	_top_wall_level = maxi(top_wall_level, 0)
	_occupancy = occupancy
	_soot = soot
	_face_soot = face_soot
	_under_structure = under_structure
	_shadow_by_light.clear()
	if geometry_only:
		## _lamp_cache survives untouched: _lamp_intensity() reads lights,
		## shadows and the anchor level, none of which this path may change.
		for key in stale:
			_bucket_cache.erase(key)
			_static_factor_cache.erase(key)
	else:
		_bucket_cache.clear()
		_lamp_cache.clear()
		_static_factor_cache.clear()  ## geometry/soot/cover may have changed — see build() callers
	for result in shadow_results:
		if result != null and result.source_light != null:
			_shadow_by_light[result.source_light.get_instance_id()] = result


## PERF-03 — every cached key the incoming occupancy/soot invalidate, and NOT
## one more. Both halves are derived from what the cached values actually read,
## traced in the code rather than guessed:
##
##  - `_static_factor(cell, level)` reads occupancy through surface_factor()
##    (cell, cell+X, cell+Y at `level` and `level+1`) and _face_occlusion()
##    (an outward cell at `level`/`level+1`, its 4-neighbour ring, and one
##    level above/below that). The widest XY offset any of those reaches is
##    ±1, and the widest level offset is +2. INVERTING that: a change at
##    (c, L) can invalidate any cell within Chebyshev 1 in XY and levels
##    L-2 .. L+1. That is the neighbourhood expanded below.
##  - the soot term enters only through _compute_bucket()'s micro-jitter
##    exemption, at exactly (cell, level) with no neighbourhood — soot has not
##    been part of _static_factor since FACE-SOOT-01.
func _stale_cells(occupancy: Dictionary, soot: Dictionary,
		face_soot: Dictionary = {}) -> Dictionary:
	var stale: Dictionary = {}
	for level in _union_keys(_occupancy, occupancy):
		var before: Variant = _occupancy.get(level)
		var after: Variant = occupancy.get(level)
		if before == after:
			continue
		for cell in _symmetric_difference(before, after):
			for dz in range(-2, 2):
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						stale[Vector3i(cell.x + dx, cell.y + dy, level + dz)] = true
	for level in _union_keys(_soot, soot):
		var before_soot: Variant = _soot.get(level)
		var after_soot: Variant = soot.get(level)
		if before_soot == after_soot:
			continue
		for cell in _symmetric_difference(before_soot, after_soot):
			stale[Vector3i(cell.x, cell.y, level)] = true
	## PERF-10 — ⚠️ AND THE FACE TRIPLES, WHICH THIS USED TO MISS ENTIRELY.
	##
	## The paragraph above is right that soot reaches the BUCKET only through the
	## jitter exemption. But `VoxelRenderer` does not write a bucket alone — it
	## writes `field.face_soot_code(cell, level)`, which reads `_face_soot`, and a
	## cell whose per-face triple moves while its isotropic RING stays put was
	## invisible here. Harmless while every apply was map-wide and re-derived
	## every cell anyway; the moment an apply is driven by this set, those cells
	## are silently skipped. Measured: exactly 7 of them survived the union with
	## the choreographer's own writes, every one a clean-to-sooted face change.
	for level in _union_keys(_face_soot, face_soot):
		var before_faces: Variant = _face_soot.get(level)
		var after_faces: Variant = face_soot.get(level)
		if before_faces == after_faces:
			continue
		for cell in _symmetric_difference(before_faces, after_faces):
			stale[Vector3i(cell.x, cell.y, level)] = true
	return stale


## PERF-10 — the accumulated stale set, or the statement that no subset is valid.
## `has_stale_subset()` false means a caller MUST use the map-wide apply.
func has_stale_subset() -> bool:
	return not _stale_total


func stale_cells() -> Dictionary:
	return _stale_accum


## Called by whichever apply just repainted every cell the set names — the
## map-wide one (which repaints strictly more) or the stale-driven one. A SCOPED
## apply must never call this: it covered some GUs, and the staleness outside them
## is exactly what the accumulator exists to remember.
func clear_stale_accum() -> void:
	_stale_accum.clear()
	_stale_total = false


static func _union_keys(a: Dictionary, b: Dictionary) -> Array:
	var keys: Dictionary = {}
	for k in a:
		keys[k] = true
	for k in b:
		keys[k] = true
	return keys.keys()


## Cells present in exactly one of the two sets, plus cells whose VALUE differs
## (soot stores a ring per cell, so a cell can be in both and still have moved).
## A null side means "that level had nothing", which makes every cell on the
## other side a difference.
static func _symmetric_difference(before: Variant, after: Variant) -> Array:
	var out: Array = []
	if before != null:
		for cell in before:
			if after == null or not after.has(cell):
				out.append(cell)
			elif typeof(before) == TYPE_DICTIONARY and before[cell] != after[cell]:
				out.append(cell)
	if after != null:
		for cell in after:
			if before == null or not before.has(cell):
				out.append(cell)
	return out


## VL-03 — clear ONLY the LAMP-dependent caches, keeping the geometry-dependent
## _static_factor_cache untouched (surface/soot/cover did not change). Call this
## after mutating a light in place (a temporal toggle changes energy_multiplier
## on the SAME LightSource instance already in _lights) and before recomputing
## buckets for its influence set — a full build() re-derives everything from
## scratch and would also wipe _static_factor_cache, which is the ~84ms/toggle
## this split exists to avoid paying twice a second.
func clear_caches() -> void:
	_bucket_cache.clear()
	_lamp_cache.clear()


## VL-03 — every GU within a light's radius. The vertical term only ever makes
## the effective distance LARGER (_lamp_intensity's sqrt(d_gu²+d_lvl²) against
## `radius`), so a flat 2D radius query on the GU plane never misses a GU this
## light could reach — it may over-include a few at the boundary, which just
## costs a few extra no-op repaints, never a missed one. This is what scopes an
## incremental repaint to exactly what a temporal light's toggle can change.
func gus_in_light_range(light) -> Array:
	var gus: Array = []
	var r: int = maxi(int(ceil(light.radius)), 0)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if Vector2(dx, dy).length() <= light.radius:
				gus.append(light.cell + Vector2i(dx, dy))
	return gus


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
	intensity *= _static_factor(cell, level)
	## FACE-READ-01: nudge the QUANTISED bucket, after rounding — nudging the
	## continuous value before it was measured to be swallowed by the rounding
	## (see micro_jitter_buckets). Sooted voxels are deliberately EXEMPT: their
	## read comes from the ring gradient, which lives in this same 12-bucket
	## channel and only spans buckets 0-2, so noise there does not enrich it, it
	## eats it. Measured 2026-07-31 on the real crater: jittering sooted voxels
	## too dropped the region's mean luminance 41.1 → 26.6 and emptied the
	## mid-tone band (9% → 0% of pixels), i.e. it flattened the very gradient the
	## Director asked to preserve ("mais perto do centro da explosão, mais escura
	## a face; quanto mais distante, menos opacidade").
	var bucket: int = roundi(intensity * float(top_bucket))
	if is_equal_approx(soot_factor(cell, level), 1.0):
		bucket += micro_jitter_offset(cell, level)
	return clampi(bucket, 0, top_bucket)


## VL-03 — surface × soot × under-structure, cached per voxel and independent of
## which lights are on/off. Split out from _compute_bucket so a temporal light
## toggle (clear_caches(), NOT build()) can reuse this across every voxel in its
## influence set instead of re-deriving surface_factor's several occupancy
## lookups from scratch on every single toggle.
func _static_factor(cell: Vector2i, level: int) -> float:
	var key := Vector3i(cell.x, cell.y, level)
	if _static_factor_cache.has(key):
		return _static_factor_cache[key]
	## VL-02b: local geometry contrast — the term that makes craters read.
	var factor: float = surface_factor(cell, level)
	## FACE-SOOT-01: soot is NO LONGER multiplied in here. It rides the cell's
	## own modulate alpha as a per-face code (encode_face_soot()) and is applied
	## by the shader, because one bucket cannot hold three different amounts of
	## scorch. Everything else about this cache is unchanged — and dropping soot
	## from it makes the cache MORE reusable, not less, since a detonation no
	## longer has to invalidate the light bucket of every voxel it scorches.
	## VL-D3: floor that was under a wall reads darker once exposed.
	if level < GeometryCoords.PLAYABLE_LEVEL and _under_structure.has(cell):
		factor *= under_structure_factor
	_static_factor_cache[key] = factor
	return factor


## FACE-READ-01 — deterministic per-voxel bucket offset in
## [-micro_jitter_buckets, +micro_jitter_buckets]. Public so a capture/probe can
## read it directly, same as soot_factor() and surface_factor().
func micro_jitter_offset(cell: Vector2i, level: int) -> int:
	if micro_jitter_buckets <= 0:
		return 0
	var key := "MICROJITTER:%d,%d,%d" % [cell.x, cell.y, level]
	var span: int = micro_jitter_buckets * 2 + 1
	return int(FacadeSampler._fnv1a_hash(key) % span) - micro_jitter_buckets


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


## FACE-SOOT-01 — the per-face scorch for one voxel, packed into the 6-bit code
## the renderer hands to the shader through the cell's modulate ALPHA.
##
## Layout: `top * 16 + se * 4 + sw`, each ring 0..2 with 3 = clean, so an
## untouched voxel is 63 — which maps to alpha 1.0 and therefore to the SAME
## alternative tile it uses today. That is deliberate: the whole clean map keeps
## its existing 12 light alternatives and only scorched voxels ever mint more.
##
## Why alpha and not the R/G/B packing VOXEL_LIGHT_MASTER_PLAN proposed: that
## plan assumed `modulate` was "a grayscale multiply" with three free channels.
## It is not — on the baked path (BakeConfig.enabled, the live default) the pages
## are grayscale by B2 and the MATERIAL'S COLOUR lives in exactly those RGB
## channels (`BakeCompositor._modulate_for_mode()` returns `material.base_color`
## for MULTIPLY), while on the material path the colour lives in the texture.
## Packing three luminances into RGB destroys the material colour on the first
## path and splats it to one channel on the second. Alpha is genuinely free —
## occlusion stopped placing ghost alternatives at OCC-21 — and it leaves both
## colour paths untouched.
func face_soot_code(cell: Vector2i, level: int) -> int:
	var level_faces = _face_soot.get(level)
	if level_faces != null:
		var faces = level_faces.get(cell)
		if faces != null:
			return encode_face_soot(faces)
	## No directional data (crater-floor cells, or a caller that supplied only the
	## isotropic snapshot): fall back to the voxel's own ring on all three faces.
	var level_soot = _soot.get(level)
	if level_soot == null:
		return VoxelRenderer.FACE_SOOT_CODE_CLEAN
	var ring: int = int(level_soot.get(cell, -1))
	if ring < 0 or ring >= BlastCalculator.FACE_SOOT_CLEAN:
		return VoxelRenderer.FACE_SOOT_CODE_CLEAN
	return encode_face_soot(Vector3i(ring, ring, ring))


## The code layout lives on VoxelRenderer (it owns the alternative-id space this
## packs into) and is referenced from function bodies only — a `const` here
## pointing at it and back would be a parse-time cycle between the two classes.
## PERF-02 B3-2: base is FACE_SOOT_CLEAN + 1 (5 — four real tones plus clean),
## was 4. Derived from the constant rather than written as a literal so the two
## can never drift; the same base appears in voxel_face_shading.gdshader, which
## cannot import it and states the coupling in its own comment.
const FACE_SOOT_BASE: int = BlastCalculator.FACE_SOOT_CLEAN + 1


static func encode_face_soot(faces: Vector3i) -> int:
	var t: int = clampi(faces.x, 0, BlastCalculator.FACE_SOOT_CLEAN)
	var se: int = clampi(faces.y, 0, BlastCalculator.FACE_SOOT_CLEAN)
	var sw: int = clampi(faces.z, 0, BlastCalculator.FACE_SOOT_CLEAN)
	return t * FACE_SOOT_BASE * FACE_SOOT_BASE + se * FACE_SOOT_BASE + sw


static func decode_face_soot(code: int) -> Vector3i:
	var c: int = clampi(code, 0, VoxelRenderer.FACE_SOOT_CODE_COUNT - 1)
	@warning_ignore("integer_division")
	var top: int = c / (FACE_SOOT_BASE * FACE_SOOT_BASE)
	@warning_ignore("integer_division")
	var se: int = (c / FACE_SOOT_BASE) % FACE_SOOT_BASE
	return Vector3i(top, se, c % FACE_SOOT_BASE)


## VL-D1 — soot multiplier for a voxel (1.0 = clean). Public for vision modes /
## tests. Ring 0 (touching a hole) is darkest; missing = clean.
##
## FACE-SOOT-01: this no longer feeds the light bucket (see _static_factor) — it
## is the isotropic reference curve the shader's per-face multipliers are
## calibrated against, and what probes/selftests read to reason about scorch.
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
## LEVEL-RENUMBER — these four are HEIGHTS ABOVE THE WALKABLE PLANE, not level
## numbers, and they were only ever written as 0/2/4/6 because the plane sat at
## zero. `_lamp_intensity()` takes `level - _anchor_level(light)`, so leaving them
## absolute would put every lamp eighty levels below the geometry it lights —
## measured at 13 668 cells with a changed light bucket before this was fixed.
## The default branch is already a real level and stays one.
func _anchor_level(light) -> int:
	match light.height_class:
		LightSource.HEIGHT_FLOOR:
			return GeometryCoords.PLAYABLE_LEVEL
		LightSource.HEIGHT_LOW_COVER:
			return GeometryCoords.PLAYABLE_LEVEL + 2
		LightSource.HEIGHT_HUMAN:
			return GeometryCoords.PLAYABLE_LEVEL + 4
		LightSource.HEIGHT_TALL_STRUCTURE:
			return GeometryCoords.PLAYABLE_LEVEL + 6
		_:
			return _top_wall_level


## VL-01's border-guess facing factor was REMOVED by VL-02b. It inferred a wall's
## axis from a cell's position inside its GU (local_x/local_y on 0 or 7), which
## only holds for slice-built walls — solid blocks and slabs have interior cells
## on no border at all — and it could not see destruction: a blown-open voxel
## kept whatever factor its original position implied. surface_factor() derives
## the same intent from real neighbour occupancy instead, so it stays correct as
## geometry changes.
