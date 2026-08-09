## DamageVariantBaker — EXPLOSION_REBUILD_MASTER_PLAN Task 1b (E-BAKE, 2026-08-06)
##
## Pre-bakes CRACKED/DENTED/MARKED damage-decal ATOMS once per map load —
## replaces D-ARCH-01's per-CELL bake (which this class used to be:
## bake_wall_voxel()/bake_ceiling_voxel()/bake_zoned_floor_voxel(), called
## once per placed Voxel, 71,296 cells × N variants — infeasible, see
## EXPLOSION_REBUILD_MASTER_PLAN §0). The new model's whole premise: a
## damaged voxel no longer shows ITS OWN facade under the decal, it shows a
## randomly chosen crop of that material's facade — so the bake surface
## collapses from cells × variants to materials × damage-type × decal ×
## substrate, ~207-279 atoms for the WHOLE MAP, not per cell.
##
## Drives the SAME compositor functions the D33 live-compositing path uses
## (VoxelRenderer._composite_full_voxel_decal() etc.) — same pixels, computed
## once here instead of lazily at hit time — via a synthetic, edge-free
## substrate crop (VoxelRenderer._composite_full_voxel_decal()'s own doc
## comment explains why `edge == null` triggers resolve_flat() there instead
## of the edge-based resolve()). Results register into a VoxelVariantRegistry
## keyed by (element_class, material, damage_material_name, substrate_variant)
## — no cell dimension — that VoxelRenderer.apply_damage_voxel_swap() consults
## before falling back to D33 runtime compositing.
##
## Scope is derived from what VoxelRenderer._set_voxel_cell()'s own dispatch
## actually reaches, same as the retired per-cell version:
##   - WALL (element_class "WALL", any `has_facade` material): DENTED
##     blast+bullet(mark) (2 sides × 3 decal variants each) + CRACKED
##     bullet(mark) (2 sides × 3 variants) + CRACKED blast (3 variants, only
##     materials with crack_factor > 0 — D10's derived rule, not the
##     hardcoded IMPACT_CRACK_MATERIALS list this file used to lean on).
##     D12 (2026-08-06): bullet marks bake BOTH shapes (cracked full-voxel
##     AND dented half-voxel) — confirmed with the Director, since
##     ShotPunchTable.damage_state_for() genuinely produces either outcome
##     and the whole point of D12 was moving bullets fully off live
##     compositing.
##   - CEILING (element_class "CEILING", any `has_facade` material): DENTED
##     blast-bottom, a silhouette carve with **1 shape** today (not D7's
##     eventual 3 irregular cut shapes — HalfVoxelCompositor.
##     carve_ceiling_silhouette() takes no shape parameter yet; that art/code
##     doesn't exist, so this bakes what's real rather than pretending 3
##     variants exist). D6: CRACKED is universal — the SAME wall CRACKED-blast
##     atom (already a 3-face composite, D6's "bakes onto all three visible
##     faces at once") is additionally registered under "CEILING" with no
##     re-compositing.
##   - FLOOR (element_class "FLOOR", only materials actually used as a real
##     floor zone — D9): DENTED blast-top, 3 variants. The registry NAME is
##     always the shared "earth_blast_dented_top_N" pseudo-name
##     (floor_damage_material()'s own rule, unchanged) but the ATOM's
##     substrate is the GU's REAL ground material (D9) — so the registry key's
##     material component must be the real material, not the naming
##     constant, or every real floor material would collide into one slot.
##     FLOOR CRACKED is not composited here: §3.2's roster makes CRACKED
##     universal (floor + wall + ceiling, D6) and the wall's CRACKED-blast atom
##     IS that atom, so a floor material with crack_factor > 0 gets it
##     registered a second time under "FLOOR" from the same composite —
##     see _bake_wall_and_marked()'s `is_floor_material`. Both halves of the
##     old reason this was skipped are gone: D34/E-SEAM-02 made
##     floor_damage_material() material-real (a concrete floor asks for
##     "concrete_blast_cracked_all_N", not the "earth" sentinel), and
##     E-CRACK-01 gave apply_crater_damage() a real crack tier, so a floor
##     voxel can reach CRACKED at all.
##   - INTERIOR slabs and plain (unzoned) earth floors: skipped entirely,
##     same reasoning as the retired version — neither ever reaches the baked
##     D33 path, so there is nothing expensive to pre-bake for them.
##
## Soot is never part of this: it is a per-cell modulate-alpha code
## (VoxelLightField.encode_face_soot()) applied by the light-repaint pass
## after any set_cell(), independent of which tile a cell shows.

class_name DamageVariantBaker
extends RefCounted

var _renderer: VoxelRenderer
var _registry: VoxelVariantRegistry
var _material_registry
var _compositor

## Fixed, deterministic crops of a material's own facade sheet — the "random
## voxels from the facades" the master plan's §0 describes, made concrete as
## 3 arbitrary but fixed (col, row) positions. room_builder.gd's bake step
## must force these exact positions into the base wall/roof/floor bake's
## combo_usage before BakeCompositor.bake() runs (BakeCompositor bakes
## SPARSELY — only real placement usage gets composed — so an unforced
## position resolves only by accident).
const SUBSTRATE_POSITIONS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(20, 0), Vector2i(40, 0)]

## Cache-key-only (VoxelRenderer._composite_*'s own cache is keyed on
## grid_pos/level/material_name, never reaches pixel math — confirmed by
## direct code reading). Any fixed level works; 0 is arbitrary.
const BAKE_LEVEL: int = 0

## §3.5/D13 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): a sibling directory
## to BakeCompositor's own BAKE_CACHE_PATH — same encode/decode/load/save
## mechanism (reused via `_compositor`, not duplicated), separate directory
## because an atom and a wall/roof/floor SHEET page are conceptually
## different cache entries even though they share a format.
const DAMAGE_CACHE_PATH: String = "user://damage_atom_cache/"

var _atom_seq: int = 0


func _init(renderer: VoxelRenderer, registry: VoxelVariantRegistry, material_registry, compositor) -> void:
	_renderer = renderer
	_registry = registry
	_material_registry = material_registry
	_compositor = compositor


## Bakes every reachable atom for the map's declared materials. `floor_materials`
## should be the subset of `declared_materials` actually used by a real
## floor_zone (D9 scope — baking a FLOOR atom for a material that's never a
## floor would just be unused bloat). Returns the total atom count, for the
## load-time capture this task's own gate asks for.
func bake_all(declared_materials: Array[String], floor_materials: Array[String] = []) -> int:
	var start_ms := Time.get_ticks_msec()
	var total := 0
	for material in declared_materials:
		var md = _material_registry.get_material(material) if _material_registry else null
		if md == null:
			push_warning("[DamageVariantBaker] declared material '%s' not registered — skipping" % material)
			continue
		if md.has_facade:
			## E-CRACK-01: a material that is ALSO a real floor zone gets the
			## universal CRACKED-blast atom registered under "FLOOR" as well —
			## see _bake_wall_and_marked()'s own note. Passed down rather than
			## handled in the floor loop below so the atom is registered from
			## the same composite, with no second slot allocation.
			total += _bake_wall_and_marked(material, floor_materials.has(material))
			total += _bake_ceiling(material)
	for material in floor_materials:
		if not declared_materials.has(material):
			push_warning("[DamageVariantBaker] floor material '%s' baked without being declared — add it to the map's damage_materials section" % material)
			continue
		total += _bake_floor(material)
	var elapsed_ms := Time.get_ticks_msec() - start_ms
	print("[DamageVariantBaker] Baked %d atoms across %d declared material(s), %d floor material(s) in %d ms" % [
		total, declared_materials.size(), floor_materials.size(), elapsed_ms])
	return total


## WALL DENTED (blast + bullet/mark) and CRACKED (bullet/mark always; blast
## only when D10's derived rule allows it) — every name
## VoxelRenderer.damage_variant_material() can produce for a wall voxel of
## this material, mirrored from the retired _wall_variant_names()'s gating
## but D10-derived (crack_factor > 0) instead of the hardcoded
## IMPACT_CRACK_MATERIALS list.
func _bake_wall_and_marked(material: String, is_floor_material: bool = false) -> int:
	var baked := 0
	var crack_eligible: bool = MaterialResistanceTable.crack_factor(material) > 0.0
	var sides := [Voxel.CarvedSide.LEFT, Voxel.CarvedSide.RIGHT]
	for variant in range(VoxelRenderer.IMPACT_DECAL_VARIANTS):
		for side in sides:
			baked += _bake_wall_name(material, VoxelRenderer.damage_variant_material(
				material, Voxel.DamageState.DENTED, true, side, variant))
			baked += _bake_wall_name(material, VoxelRenderer.damage_variant_material(
				material, Voxel.DamageState.DENTED, false, side, variant))
			baked += _bake_wall_name(material, VoxelRenderer.damage_variant_material(
				material, Voxel.DamageState.CRACKED, false, side, variant))
		if crack_eligible:
			## D6: this exact atom (a 3-face composite) also serves CEILING —
			## register it a second time under that element_class, no
			## re-compositing.
			##
			## E-CRACK-01 (2026-08-08): and FLOOR, for the same reason and by the
			## same ratified rule — §3.2's roster row is literally "CRACKED
			## (universal — floor + wall + ceiling, D6)". The registration was
			## missing only because nothing could ever produce a cracked floor
			## voxel until apply_crater_damage() grew its crack tier this session;
			## this file's old header called that out honestly ("unreachable in
			## practice today"), and it is reachable now. A floor voxel shows its
			## TOP face, which this composite already papers (FACE_TOP + FACE_SW
			## + FACE_SE in one atom) — the identical argument D6 made for
			## CEILING, not a new claim about the art.
			baked += _bake_wall_name(material, VoxelRenderer.damage_variant_material(
				material, Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE, variant),
				true, is_floor_material)
	return baked


func _bake_wall_name(material: String, name: String, also_ceiling: bool = false,
		also_floor: bool = false) -> int:
	if name == "":
		return 0
	var baked := 0
	for substrate in range(VoxelRenderer.DAMAGE_SUBSTRATE_VARIANTS):
		var pos: Vector2i = SUBSTRATE_POSITIONS[substrate]
		var entry := _composite_cached(_atom_disk_key(material, name, substrate),
				func(): return _composite_wall_name(name, pos))
		if entry.is_empty():
			continue
		_registry.register(
			VoxelVariantRegistry.make_variant_key("WALL", material, name, substrate),
			entry["source_id"], entry["atlas_coords"])
		baked += 1
		if also_ceiling:
			_registry.register(
				VoxelVariantRegistry.make_variant_key("CEILING", material, name, substrate),
				entry["source_id"], entry["atlas_coords"])
			baked += 1
		if also_floor:
			_registry.register(
				VoxelVariantRegistry.make_variant_key("FLOOR", material, name, substrate),
				entry["source_id"], entry["atlas_coords"])
			baked += 1
	return baked


## Resolves one name through the same plan parsers _set_voxel_cell() uses —
## mutually exclusive by construction (VoxelRenderer._full_voxel_decal_plan()'s
## own comment), so trying them in order is safe. `edge = null` is the
## atom-bake signal both compositor functions now branch on.
func _composite_wall_name(name: String, pos: Vector2i) -> Dictionary:
	var full_plan := VoxelRenderer._full_voxel_decal_plan(name)
	if not full_plan.is_empty():
		return _renderer._composite_full_voxel_decal(
			full_plan, name, null, 0, pos, BAKE_LEVEL, _next_synthetic_grid_pos())
	var half_plan := VoxelRenderer._half_voxel_decal_plan(name)
	if not half_plan.is_empty():
		return _renderer._composite_half_voxel_decal(
			half_plan, name, null, 0, pos, BAKE_LEVEL, _next_synthetic_grid_pos())
	return {}


## CEILING DENTED — a silhouette carve, one shape today (see this file's own
## header comment on D7's 3-shape target not being implemented yet).
func _bake_ceiling(material: String) -> int:
	var name := "%s_blast_dented_bottom" % material
	var ceiling_plan := VoxelRenderer._ceiling_carve_plan(name)
	if ceiling_plan.is_empty():
		return 0
	var baked := 0
	for substrate in range(VoxelRenderer.DAMAGE_SUBSTRATE_VARIANTS):
		var pos: Vector2i = SUBSTRATE_POSITIONS[substrate]
		var entry := _composite_cached(_atom_disk_key(material, name, substrate),
				func(): return _renderer._composite_ceiling_carve(
					ceiling_plan, name, pos, BAKE_LEVEL, _next_synthetic_grid_pos()))
		if entry.is_empty():
			continue
		_registry.register(
			VoxelVariantRegistry.make_variant_key("CEILING", material, name, substrate),
			entry["source_id"], entry["atlas_coords"])
		baked += 1
	return baked


## FLOOR DENTED — substrate from `material`'s own real facade (D9). D34/
## E-SEAM-02: the NAME is `material`'s too now ("concrete_blast_dented_top_N"),
## not the shared "earth_..." pseudo-name — floor_damage_material() still
## substitutes earth for materials with no decal art of their own, so a
## floor-only material (grass/dirt/sand/gravel) bakes exactly what it did
## before under a name that says so.
func _bake_floor(material: String) -> int:
	var baked := 0
	for variant in range(VoxelRenderer.IMPACT_DECAL_VARIANTS):
		var name: String = VoxelRenderer.floor_damage_material(
			material, Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, variant)
		if name == "":
			continue
		var floor_plan := VoxelRenderer._floor_sunk_decal_plan(name)
		if floor_plan.is_empty():
			continue
		for substrate in range(VoxelRenderer.DAMAGE_SUBSTRATE_VARIANTS):
			var pos: Vector2i = SUBSTRATE_POSITIONS[substrate]
			var entry := _composite_cached(_atom_disk_key(material, name, substrate),
					func(): return _renderer._composite_floor_sunk_decal(
						floor_plan, name, material, pos, BAKE_LEVEL, _next_synthetic_grid_pos()))
			if entry.is_empty():
				continue
			_registry.register(
				VoxelVariantRegistry.make_variant_key("FLOOR", material, name, substrate),
				entry["source_id"], entry["atlas_coords"])
			baked += 1
	return baked


## §3.5/D13: check the cross-session disk cache before doing any real work;
## on a HIT, skip straight to registering the cached pixels into THIS
## room-load's fresh atlas (cheap: a blit + slot allocation, not the
## substrate-resolve/decal-load/compositing math `produce` would otherwise
## do) — this is what makes a second load of the same materials ~free, this
## task's own gate. On a MISS, run `produce` for real and persist its raw
## pixels for next time. Deliberately NOT keyed by element_class: a WALL and
## a CEILING atom that share the same (material, name, substrate) — D6's
## universal CRACKED case — are the identical pixels, one disk entry for both.
func _composite_cached(disk_key: String, produce: Callable) -> Dictionary:
	var cache := _renderer.get_damage_composite_cache()
	if _compositor:
		var cached_img: Image = _compositor._disk_cache_load(disk_key, DAMAGE_CACHE_PATH)
		if cached_img != null:
			return cache.store(disk_key, cached_img)

	var entry: Dictionary = produce.call()
	if entry.is_empty():
		return {}

	if _compositor:
		var raw_img: Image = cache.get_image_at(entry["source_id"], entry["atlas_coords"])
		if raw_img != null:
			_compositor._disk_cache_save(disk_key, raw_img, DAMAGE_CACHE_PATH)
	return entry


## (material, name, substrate) — no element_class (see _composite_cached()'s
## doc comment on why) — hashed the same way BakeCompositor's own page cache
## keys are (_fnv1a_64), reused via `_compositor` rather than duplicated.
func _atom_disk_key(material: String, name: String, substrate: int) -> String:
	var key_input := "%s|%s|%d|v%d" % [material, name, substrate, _compositor.BAKE_CODE_VERSION]
	return _compositor._fnv1a_64(key_input.to_utf8_buffer())


## Uniqueness is all that matters here — VoxelRenderer's damage-composite
## cache keys on (grid_pos, level, material_name), never reads grid_pos as a
## real position (confirmed: it never reaches pixel math). A running counter
## is the cheapest way to guarantee two different atoms never collide in
## that cache.
func _next_synthetic_grid_pos() -> Vector2i:
	_atom_seq += 1
	return Vector2i(_atom_seq, 0)
