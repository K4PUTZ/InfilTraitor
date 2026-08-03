## Geometry Module — Voxel Renderer: TileMapLayer-based voxel wall rendering
## Port from room.gd voxel functions, honoring Transform Canon
## Extends Node2D to add to scene tree
extends Node2D
class_name VoxelRenderer

## DESTRUCTION_MASTER_PLAN D15: emitted at the TIC, alongside the dirty pass,
## whenever a voxel is actually erased (destroyed). VFX/audio subscribe here
## instead of the destruction system knowing about them — with no subscriber
## this costs nothing. Never implemented until Part 3; added now.
signal voxel_destroyed(grid_pos: Vector2i, level: int, material_id: String)

var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")
## D33 Part 3a — the runtime decal compositor (Part 2) this file's
## _set_voxel_cell() now calls for full-voxel CRACKED impact marks.
const DecalCompositorClass = preload("res://godot/scripts/geometry/decal_compositor.gd")
## D33 Part 3b — the polygon-mask primitive for half-voxel DENTED impact marks.
const HalfVoxelCompositorClass = preload("res://godot/scripts/geometry/half_voxel_compositor.gd")

## TileSet source ID for voxels
const VOXEL_SOURCE_ID: int = 0

## Materials to load (in order). source_id == array index (see
## _build_voxel_tileset() and _set_voxel_cell()'s MATERIALS.find() fallback),
## so appending never disturbs the first 4 wall materials' existing ids.
##
## DESTRUCTION D2/D4: "earth_0".."earth_7" are the floor/slab palette —
## EarthVariantSelector.variant_for() picks one by index, matching
## generate_voxel.py's voxel_earth_N.png naming exactly (VOXEL_ASSET_TEMPLATE
## below is generic over material_name, so these load through the identical
## path the 4 wall materials already use — no new loader, per D2). They never
## go through the baked-lookup branch: floor voxels have no edge (D1), so
## _set_voxel_cell's `edge` argument is always null for them, same as any
## other material-only fallback placement.
##
## D22 (2026-07-30): "glass" is the 5th wall material — DESTROYED-only per the
## Director (no DENTED/CRACKED tier, MaterialResistanceTable keeps both
## factors at 0 for it), so it needs nothing beyond its own base atom here.
## The "_dented"/"_cracked" suffixed entries are impact-mark pseudo-materials,
## one pair per non-glass material — see IMPACT_ASSET_TEMPLATE below and
## damage_variant_material(). They load through this exact same mechanism
## (append-only, same MATERIALS.find() source_id resolution) but from a
## SEPARATE folder, and _set_voxel_cell() short-circuits them past the
## baked-lookup branch entirely — an impact mark is self-contained by design
## ("encaixado em qualquer lugar," Director), not tied to whatever facade the
## surrounding wall happens to bake.
## D23 (Director, 2026-07-30): "a granada produzindo buracos de bala não faz
## sentido [...] estados intermediários do material em explosões, mas não com
## furos redondos" — a blast's DENTED/CRACKED voxels get their OWN texture
## family (irregular chip/crack), never the bullet's round puncture. Same
## append-only mechanism, same folder, just a `_blast_` infix so both families
## sit side by side — see damage_variant_material()'s blast_sourced parameter.
## D32 (Director diagrams, 2026-08-02): the decal-composited impact family is
## APPENDED to this list by _static_init() instead of being typed out — 103
## names built from (material x tier x side x variant) is exactly the kind of
## list that rots when edited by hand, and the generator builds its filenames
## from the same three axes. The literal list below stays the literal list: it
## is the historical prefix, and MATERIALS is append-only (source_id == index),
## so every id already minted keeps its value.
const BASE_MATERIALS: Array[String] = [
	"concrete", "metal", "stone", "wood", "glass",
	"earth_0", "earth_1", "earth_2", "earth_3", "earth_4", "earth_5", "earth_6", "earth_7",
	"concrete_dented", "concrete_cracked", "metal_dented", "metal_cracked",
	"stone_dented", "stone_cracked", "wood_dented", "wood_cracked",
	"concrete_blast_dented", "concrete_blast_cracked", "metal_blast_dented", "metal_blast_cracked",
	"stone_blast_dented", "stone_blast_cracked", "wood_blast_dented", "wood_blast_cracked",
	## D25: the carved half-voxels, four per material — see the block comment
	## above damage_variant_material(). The flat "*_blast_dented" entries just
	## above them are superseded for any voxel whose carved side is known, but
	## stay in this array forever: MATERIALS is append-only (source_id == index),
	## and they remain the honest fallback when no epicentre bias was supplied.
	"concrete_blast_dented_top", "concrete_blast_dented_bottom",
	"concrete_blast_dented_left", "concrete_blast_dented_right",
	"metal_blast_dented_top", "metal_blast_dented_bottom",
	"metal_blast_dented_left", "metal_blast_dented_right",
	"stone_blast_dented_top", "stone_blast_dented_bottom",
	"stone_blast_dented_left", "stone_blast_dented_right",
	"wood_blast_dented_top", "wood_blast_dented_bottom",
	"wood_blast_dented_left", "wood_blast_dented_right",
	## FLOOR-DENT-01 (2026-08-01): plain-earth floors dent now (crater-rim
	## pockmarks, apply_crater_damage). A floor is only ever eaten from ABOVE,
	## so earth gets exactly the _top carve — the mirror of ceilings only ever
	## carving _bottom. Appended last: MATERIALS is append-only (source_id ==
	## index).
	"earth_blast_dented_top",
]

## D32 — the four wall materials the Director authors decals for. Glass is
## absent by D22 (DESTROYED-only) and brick is deferred; both were the
## Director's explicit call on 2026-08-02 ("vidro e tijolo deixa pra depois").
const IMPACT_DECAL_MATERIALS: Array[String] = ["concrete", "metal", "stone", "wood"]
## Fixed at three by the Director, same session. Must match `variant_count` in
## voxels/manifest.json — asserted by voxel_decal_selftest.gd rather than
## trusted, because a mismatch fails as a silent MATERIALS.find() miss.
const IMPACT_DECAL_VARIANTS: int = 3
## Every ground material's dent routes to this one shared asset (D26), so the
## floor family is built on "earth" and needs only the blast/dent/top corner of
## the matrix: floors take no bullets (D32.4) and have no crack tier.
const IMPACT_FLOOR_MATERIAL: String = "earth"
## D32.6 (Director, 2026-08-02): "metal e madeira não ficam rachados, só dented
## ou balas." Only these two fracture, so only these two get a blast-CRACKED
## decal — MaterialResistanceTable holds the matching crack_factor 0.0 for metal
## and wood, and voxel_decal_selftest asserts the two agree. Bullets are NOT
## gated by this: a firearm's CRACKED tier is a bullet mark on the struck face,
## which every material gets.
const IMPACT_CRACK_MATERIALS: Array[String] = ["concrete", "stone"]

## Built by _static_init(); see BASE_MATERIALS above for why it is not a const.
static var MATERIALS: Array[String] = []


static func _static_init() -> void:
	MATERIALS = BASE_MATERIALS.duplicate()
	for material in IMPACT_DECAL_MATERIALS:
		for name in impact_decal_names(material):
			if not MATERIALS.has(name):
				MATERIALS.append(name)
	for name in impact_decal_names(IMPACT_FLOOR_MATERIAL):
		if not MATERIALS.has(name):
			MATERIALS.append(name)


## D32 — every decal-composited pseudo-material name for `material`, in a fixed
## order so source ids are reproducible across runs.
##
## `_blast_dented_bottom` carries NO variant: a ceiling half voxel is silhouette
## only (an isometric camera never sees a voxel's underside), so there is no
## decal on it and nothing for a variant to vary. It is also already present in
## BASE_MATERIALS from D25 — same name, same asset, same meaning — which is why
## _static_init() de-duplicates instead of appending blindly.
##
## The floor material gets only the blast/dented/top row; asking for the rest
## would mint names with no asset behind them, and a missing asset is a
## push_error at boot (B6), not a silent fallback.
static func impact_decal_names(material: String) -> Array[String]:
	var names: Array[String] = []
	var is_floor: bool = material == IMPACT_FLOOR_MATERIAL
	for variant in range(IMPACT_DECAL_VARIANTS):
		if not is_floor:
			for side in ["left", "right"]:
				names.append("%s_bullet_cracked_%s_%d" % [material, side, variant])
				names.append("%s_bullet_dented_%s_%d" % [material, side, variant])
				names.append("%s_blast_dented_%s_%d" % [material, side, variant])
			if IMPACT_CRACK_MATERIALS.has(material):
				names.append("%s_blast_cracked_all_%d" % [material, variant])
		names.append("%s_blast_dented_top_%d" % [material, variant])
	if not is_floor:
		names.append("%s_blast_dented_bottom" % material)
	return names

## Voxel asset path template
## ASSET-LAYOUT-01 (Director, 2026-08-02) — the voxel source tree is split by
## WHAT THE PIPELINE DOES WITH A FILE, not by what it depicts:
##
##   materials/   one whole voxel per material            INPUT  (never overwritten)
##   halves/      the four carved substrates per material INPUT  (generated if absent)
##   decals/      the marks + broken faces + template     INPUT  (never overwritten)
##   composites/  material|half x decal                   OUTPUT (always rebuilt)
##
## The rule is worth the folders: everything in the first three is authorable and
## the generator refuses to clobber it, everything in the last is a pure
## derivative that can be deleted and rebuilt at any time. It also makes D33
## (moving compositing to load time) a folder deletion instead of a 126-file
## audit. Full layout: ASSETS/ISOMETRIC/source_assets/voxels/README.md.
const VOXEL_ASSET_ROOT: String = "res://ASSETS/ISOMETRIC/source_assets/voxels/"
const VOXEL_ASSET_TEMPLATE: String = VOXEL_ASSET_ROOT + "materials/voxel_%s.png"

## D22: impact-mark pseudo-materials load from their own folder, not
## alongside the base material atoms — the Director's dedicated drop point
## for the real photographic bakes ("pasta especial dentro de assets") once
## produced; placeholder vector marks live here meanwhile (generate_voxel.py).
## _IMPACT_SUFFIXES below is also what _set_voxel_cell() checks to bypass the
## baked-lookup branch for these pseudo-materials.
const IMPACT_ASSET_TEMPLATE: String = VOXEL_ASSET_ROOT + "composites/voxel_%s.png"
## D33 Part 3a — the RAW decal art (family, material, variant), same folder
## and filename shape generate_voxel.py's build_decal_family() authors into
## (DECAL_NAME = "decal_%s_%s_%d.png"). Composited at runtime onto the baked
## atom instead of loading a pre-composited voxel_%s.png from composites/ —
## _full_voxel_decal_plan()/_composite_full_voxel_decal() below are the seam.
const DECAL_NAME_TEMPLATE: String = VOXEL_ASSET_ROOT + "decals/decal_%s_%s_%d.png"
## "_blast_dented"/"_blast_cracked" already end with "_dented"/"_cracked", so
## they match the first two suffixes below without needing their own entries.
## D25's carved half-voxels do NOT — they end in the carved side — so each of
## the four gets its own entry here.
const _IMPACT_SUFFIXES: Array[String] = [
	"_dented", "_cracked",
	"_dented_top", "_dented_bottom", "_dented_left", "_dented_right",
]

## D25: Voxel.CarvedSide → the filename/material suffix for that carved side.
## Keyed by the enum so an unmapped value (NONE) falls through to the flat
## pre-D25 mark instead of composing a material name that has no asset.
const _CARVED_SIDE_SUFFIX: Dictionary = {
	Voxel.CarvedSide.TOP: "_top",
	Voxel.CarvedSide.BOTTOM: "_bottom",
	Voxel.CarvedSide.LEFT: "_left",
	Voxel.CarvedSide.RIGHT: "_right",
}


## D22: is `material_name` an impact-mark pseudo-material ("metal_dented" etc.)
## rather than a real base material? Used both to pick the asset folder at
## boot and to bypass the baked-lookup branch at render time.
static func _is_impact_mark(material_name: String) -> bool:
	## D32: the decal family's names all carry a `_bullet_`/`_blast_` infix and
	## END in a side or a variant index, so the suffix list below can no longer
	## recognise them on its own. Checking the infix first covers every D32 name
	## and every D23 blast name in one test; the suffix loop still covers D22's
	## original bullet pair ("<material>_dented"/"_cracked"), which has neither.
	if material_name.contains("_bullet_") or material_name.contains("_blast_"):
		return true
	for suffix in _IMPACT_SUFFIXES:
		if material_name.ends_with(suffix):
			return true
	return false


## D22/D23: which pseudo-material a voxel's damage_state should actually
## render as. INTACT and DESTROYED voxels are unaffected — DESTROYED never
## reaches here at all (voxel.visible gates it out before _set_voxel_cell is
## called). blast_sourced (voxel.damage_is_blast) picks the irregular
## chip/crack family instead of the bullet's round puncture — a blast's
## "not fully destroyed" voxels should never look like they took a clean shot.
## D25 (Director diagram, 2026-07-31): a blast-DENTED voxel is no longer an
## intact cube wearing a mark — it is a HALF voxel, carved on the side that
## faced the explosion, with a pre-baked broken face exposed in the cut
## ("o voxel fica com metade em alpha e acrescenta uma face pre-baked").
## carved_side is Voxel.CarvedSide in VIEW space; CarvedSide.NONE (no epicentre
## bias available) keeps the flat pre-D25 mark rather than guessing a side.
## D32 (Director diagrams, 2026-08-02) — the decal family supersedes all of the
## above for the four materials that have one, and the rules it encodes are the
## Director's placement rules, not conveniences:
##
##   - a BULLET marks exactly the ONE lateral face it struck, never a top face
##     (the bug this replaces: D22's art put the hole on the top diamond, so
##     every firearm hit on a wall painted its bullet hole on the roof);
##   - a CRACKED voxel wears its decal on ALL THREE visible faces, so the
##     `_all` name takes no side at all — "não existe voxel rachado só em uma
##     face";
##   - a ceiling's `_bottom` carve takes no variant, because it carries no
##     decal to vary.
##
## Anything that does not resolve to a real MATERIALS entry falls back to the
## pre-D32 name rather than being returned unchecked. That guard is load-bearing:
## _set_voxel_cell()'s MATERIALS.find() returns -1 for an unknown name and -1
## silently becomes source_id 0, repainting the voxel as flat "concrete" — the
## exact failure D26 hit on zoned floors.
static func damage_variant_material(base_material: String, damage_state: int,
		blast_sourced: bool = false, carved_side: int = Voxel.CarvedSide.NONE,
		variant: int = 0) -> String:
	var decal := _decal_material(base_material, damage_state, blast_sourced,
		carved_side, variant)
	if decal != "":
		return decal
	var infix := "_blast" if blast_sourced else ""
	match damage_state:
		Voxel.DamageState.DENTED:
			if blast_sourced and _CARVED_SIDE_SUFFIX.has(carved_side):
				return base_material + "_blast_dented" + String(_CARVED_SIDE_SUFFIX[carved_side])
			return base_material + infix + "_dented"
		Voxel.DamageState.CRACKED:
			return base_material + infix + "_cracked"
		_:
			return base_material


## D32 — the decal-family name for this (material, tier, cause, side, variant),
## or "" when the combination has no decal asset and the caller should fall back.
##
## Returning "" rather than a composed-but-missing name is the whole point: this
## function is the only place that knows which corners of the matrix were
## actually generated, so every miss is caught here instead of reaching
## MATERIALS.find() and turning into source_id 0.
static func _decal_material(base_material: String, damage_state: int,
		blast_sourced: bool, carved_side: int, variant: int) -> String:
	if not IMPACT_DECAL_MATERIALS.has(base_material) \
			and base_material != IMPACT_FLOOR_MATERIAL:
		return ""
	var v: int = posmod(variant, IMPACT_DECAL_VARIANTS)
	var composed := ""
	match damage_state:
		Voxel.DamageState.CRACKED:
			## A blast cracks the whole voxel — one name, no side (D32.3). A
			## bullet cracks the one face it hit, so a bullet with no known side
			## has nothing to render and falls through to the legacy mark.
			if blast_sourced:
				composed = "%s_blast_cracked_all_%d" % [base_material, v]
			elif _CARVED_SIDE_SUFFIX.has(carved_side):
				composed = "%s_bullet_cracked%s_%d" % [
					base_material, String(_CARVED_SIDE_SUFFIX[carved_side]), v]
		Voxel.DamageState.DENTED:
			if not _CARVED_SIDE_SUFFIX.has(carved_side):
				return ""
			var side := String(_CARVED_SIDE_SUFFIX[carved_side])
			if blast_sourced:
				## The ceiling carve is silhouette-only and therefore variantless.
				composed = "%s_blast_dented_bottom" % base_material \
					if carved_side == Voxel.CarvedSide.BOTTOM \
					else "%s_blast_dented%s_%d" % [base_material, side, v]
			else:
				composed = "%s_bullet_dented%s_%d" % [base_material, side, v]
		_:
			return ""
	return composed if composed != "" and MATERIALS.has(composed) else ""


## D33 Part 3a — recognizes exactly the FULL-VOXEL decal cases this slice
## wires (see PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 3): a bullet's
## CRACKED mark on the one lateral face it struck, or a blast's CRACKED mark
## on all three visible faces at once. Returns {} for anything else — DENTED
## is a half-voxel substrate (Part 3b, not yet built) and every non-impact
## name never reaches this function at all — and {} is exactly the signal
## _set_voxel_cell() reads as "fall through to today's path unchanged".
##
## Mirrors generate_voxel.py's build_decal_family(): LEFT pastes onto
## DecalCompositor.FACE_SW, RIGHT onto FACE_SE_MIRRORED (the two are NOT the
## same parallelogram — see that constant's own doc comment), and a blast's
## "_all_" name papers FACE_TOP + FACE_SW + FACE_SE in one composite. The RAW
## decal FAMILY on disk is "bullet" for both bullet cases and "crack" for the
## blast case (generate_voxel.py's DECAL_FAMILIES naming, distinct from the
## damage TIER also spelled "cracked" in the material name).
static func _full_voxel_decal_plan(material_name: String) -> Dictionary:
	for base in IMPACT_DECAL_MATERIALS:
		var prefix := base + "_"
		if not material_name.begins_with(prefix):
			continue
		var rest := material_name.substr(prefix.length())
		if rest.begins_with("bullet_cracked_left_"):
			var v := rest.substr("bullet_cracked_left_".length())
			if v.is_valid_int():
				return {
					"base_material": base, "decal_family": "bullet", "variant": v.to_int(),
					"targets": [DecalCompositorClass.FACE_SW],
				}
		elif rest.begins_with("bullet_cracked_right_"):
			var v := rest.substr("bullet_cracked_right_".length())
			if v.is_valid_int():
				return {
					"base_material": base, "decal_family": "bullet", "variant": v.to_int(),
					"targets": [DecalCompositorClass.FACE_SE_MIRRORED],
				}
		elif rest.begins_with("blast_cracked_all_"):
			var v := rest.substr("blast_cracked_all_".length())
			if v.is_valid_int():
				return {
					"base_material": base, "decal_family": "crack", "variant": v.to_int(),
					"targets": [DecalCompositorClass.FACE_TOP, DecalCompositorClass.FACE_SW, DecalCompositorClass.FACE_SE],
				}
	return {}


## D33 Part 3b — recognizes the wall-DENTED (half-voxel) decal cases: a
## bullet or a blast, carved LEFT or RIGHT. Floor ("_dented_top", sunk) and
## ceiling ("_dented_bottom", silhouette-only, no decal) are a further
## increment — see PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 3b —
## and fall through here exactly like everything Part 3a didn't cover.
##
## Raw decal FAMILY on disk: "bullet" for both bullet_cracked (Part 3a) and
## bullet_dented (this function) — one decal image, two different substrates
## and targets; "dent" (not "crack") for blast_dented — generate_voxel.py's
## build_decal_family() names it `decals[(material, "dent", variant)]`, kept
## in `dent` for BOTH the wall dented tier and the floor's own sunk dent.
static func _half_voxel_decal_plan(material_name: String) -> Dictionary:
	for base in IMPACT_DECAL_MATERIALS:
		var prefix := base + "_"
		if not material_name.begins_with(prefix):
			continue
		var rest := material_name.substr(prefix.length())
		if rest.begins_with("bullet_dented_left_"):
			var v := rest.substr("bullet_dented_left_".length())
			if v.is_valid_int():
				return {
					"base_material": base, "decal_family": "bullet", "variant": v.to_int(),
					"side": "left", "target": DecalCompositorClass.FACE_CUT_LEFT,
				}
		elif rest.begins_with("bullet_dented_right_"):
			var v := rest.substr("bullet_dented_right_".length())
			if v.is_valid_int():
				return {
					"base_material": base, "decal_family": "bullet", "variant": v.to_int(),
					"side": "right", "target": DecalCompositorClass.FACE_CUT_RIGHT,
				}
		elif rest.begins_with("blast_dented_left_"):
			var v := rest.substr("blast_dented_left_".length())
			if v.is_valid_int():
				return {
					"base_material": base, "decal_family": "dent", "variant": v.to_int(),
					"side": "left", "target": DecalCompositorClass.FACE_CUT_LEFT,
				}
		elif rest.begins_with("blast_dented_right_"):
			var v := rest.substr("blast_dented_right_".length())
			if v.is_valid_int():
				return {
					"base_material": base, "decal_family": "dent", "variant": v.to_int(),
					"side": "right", "target": DecalCompositorClass.FACE_CUT_RIGHT,
				}
	return {}


## FLOOR-DENT-01 (2026-08-01) — which material a damaged FLOOR voxel renders as.
##
## A floor has exactly ONE damage asset today: the carved-TOP pockmark, built on
## earth (a floor is only ever eaten from ABOVE — the mirror of a ceiling only
## ever carving BOTTOM). Every ground material shares it, which is D25's existing
## rule rather than a shortcut for floors: the broken face is deliberately
## decoupled from material colour, "one generic grey fracture serves every
## material", overridable per material by dropping a file in decals/.
##
## This is what keeps the zoned/baked branch honest. A zoned floor composing
## "ground_concrete_blast_dented_top" would miss MATERIALS entirely, and
## _set_voxel_cell()'s MATERIALS.find() returns -1 → source_id 0 → the voxel
## silently repaints as flat "concrete" — the exact failure render_slab()'s own
## comment warns about for ground_* names. Impact marks bypass the baked lookup
## by construction (_is_impact_mark()), so one asset serves both branches.
##
## Returns "" when there is no floor damage variant (INTACT, or a tier with no
## floor asset), meaning "keep whatever material you were going to use".
static func floor_damage_material(damage_state: int, is_blast: bool, carved_side: int,
		variant: int = 0) -> String:
	if damage_state == Voxel.DamageState.INTACT or damage_state == Voxel.DamageState.DESTROYED:
		return ""
	var composed := damage_variant_material(IMPACT_FLOOR_MATERIAL, damage_state,
		is_blast, carved_side, variant)
	return composed if MATERIALS.has(composed) else ""


## OCC-27 (2026-07-21, Director's call): occlusion ring alphas, consumed by the
## wireframe fill (occlusion_slice_panel.gd). Since OCC-21 occluded cells are
## ERASED (not ghosted), so these alphas no longer ride on tile alternatives —
## the wireframe fill is their only consumer. Bumped 3/6/9% -> 6/12/18% ->
## 8/16/24% across two follow-up asks the same session.
const GHOST_ALPHAS: Array[float] = [0.08, 0.16, 0.24]

## VL-01 — Six-bucket light painting (VOXEL_LIGHT_MASTER_PLAN, Director 2026-07-23).
##
## A lit/dark face is an ALTERNATIVE TILE, the exact mechanism OCC-02's ghosts
## pioneered: TileData carries a `modulate` per alternative and alternatives
## reuse the same atlas region — zero extra texture memory, nothing per
## fragment. Occlusion stopped PLACING ghost alternatives at OCC-21 (erase +
## wireframe fill), which left the alternative-id space free for lighting to
## own outright:
##
##   alt 0                 = bucket 5 (full lit), unflipped — the base tile
##   alt 1..5              = buckets 4..0, unflipped
##   alt 6..10             = buckets 4..0, H-flipped (junction mirror cells)
##   alt TRANSFORM_FLIP_H  = bucket 5, H-flipped (legacy virtual alternative,
##                           kept so the junction placement path is untouched)
##
## encode_light_alt()/decode_light_*() are the ONLY owners of this mapping —
## occlusion restore, light repaint and any future consumer round-trip through
## them. Never hand-build an alternative id.
## VL-02b: widened 6 → 12. Six could not carry the lamp term AND the new
## per-voxel surface/AO shading at once — axis factors collapsed into the same
## bucket as their neighbours and blast craters stayed invisible.
const LIGHT_BUCKET_COUNT: int = 12
## (LIGHT_ALT_FLIP_BASE lived here and was the flip offset of the bucket-only id
## run; FACE-SOOT-01 replaced it with SOOT_ALT_FLIP_BASE, which has to clear the
## whole bucket × soot space rather than just the buckets. Repo-wide grep before
## deleting it found this line as its only occurrence.)

## Bucket → modulate luminance. Bucket 0 must stay dark-but-readable (Director:
## full shadow still shows texture). Tunable; changes take effect on the next
## map load / rotation (alternatives are minted at source registration).
## Director 2026-07-24: lift the overall brightness a touch — mids raised, top
## pinned at 1.00. VL-D1 reserves the two DARKEST buckets (0.07, 0.13) for blast
## soot: the light term never maps below bucket 2 (ambient 0.15 → bucket 2 =
## 0.33), so soot's ×multiplier is what pushes a voxel down into 0-1. Approved
## light range (bucket 2+) is unchanged.
## VL-D1 reserves buckets 0-1 for blast soot; Director 2026-07-24 raised them
## (0.07/0.13 → 0.12/0.20) so scorch keeps a little texture instead of reading
## flat black. Light term still never maps below bucket 2 (ambient = 0.33).
## FLOOR-DEPTH-02 caveat: on a negative level these values are multiplied again
## by FLOOR_DEPTH_DIM, so a SOOTED voxel two levels down lands near 0.08 — below
## the readable floor this table is tuned to hold. That is why the depth dim is
## gentle, and why the soot ring of a freshly exposed crater floor is what
## actually governs whether its layers read apart (see the ring-by-depth note in
## TestZoneController._expose_below).
var bucket_luminance: Array[float] = [
	0.12, 0.20, 0.33, 0.40, 0.47, 0.54, 0.61, 0.69, 0.77, 0.85, 0.92, 1.00,
]


## FACE-SOOT-01 — the alternative id now carries (light bucket × per-face soot
## code × flip), not just (bucket × flip). One flat run per flip state:
##
##   raw = (LIGHT_BUCKET_COUNT - 1 - bucket) + LIGHT_BUCKET_COUNT * soot_slot
##   soot_slot = FACE_SOOT_CODE_CLEAN - soot_code   (so CLEAN → slot 0)
##
## raw == 0 is therefore "full lit, no soot" — the base tile — and the whole
## pre-FACE-SOOT-01 id range survives unchanged as the soot_slot-0 run, so a map
## with no destruction mints exactly the alternatives it minted before.
##
## HARD CEILING, verified in-engine rather than assumed: TRANSFORM_FLIP_H is
## 4096 (FLIP_V 8192, TRANSPOSE 16384), so a real alternative id must stay below
## 4096 or it collides with the transform bits Godot ORs into the same integer.
## The full space here is 12 buckets × 64 codes × 2 flips = 1536 ids, max 1535 —
## 2560 clear of the ceiling. Adding per-FACE LIGHT later (the other half of
## VOXEL_LIGHT_MASTER_PLAN's open item) would multiply the bucket axis by 12×12
## and BLOW that ceiling at 3456+; it would have to reuse this same soot code
## space rather than add a third axis. Recorded here because the id space is the
## real constraint on that feature, and nothing else in the codebase says so.
##
## The code itself is 2 bits per visible face — `top * 16 + se * 4 + sw`, ring
## 0..2 with 3 = clean — so the all-clean code is 63 and maps to modulate alpha
## 1.0, i.e. exactly the tile every untouched voxel already carries.
## VoxelLightField.encode_face_soot()/decode_face_soot() are its only readers.
const FACE_SOOT_CODE_CLEAN: int = 63
const FACE_SOOT_CODE_COUNT: int = 64
const SOOT_ALT_FLIP_BASE: int = LIGHT_BUCKET_COUNT * FACE_SOOT_CODE_COUNT


## (bucket, per-face soot code, flipped) → alternative id. Single source of truth.
static func encode_voxel_alt(bucket: int, soot_code: int, flipped: bool) -> int:
	var b: int = clampi(bucket, 0, LIGHT_BUCKET_COUNT - 1)
	var slot: int = FACE_SOOT_CODE_CLEAN - clampi(soot_code, 0, FACE_SOOT_CODE_COUNT - 1)
	var raw: int = (LIGHT_BUCKET_COUNT - 1 - b) + LIGHT_BUCKET_COUNT * slot
	if raw == 0:
		return TileSetAtlasSource.TRANSFORM_FLIP_H if flipped else 0
	return (SOOT_ALT_FLIP_BASE + raw) if flipped else raw


## alternative id → the raw (bucket, soot) index, flip stripped.
static func _decode_alt_raw(alt: int) -> int:
	if alt == 0 or alt == TileSetAtlasSource.TRANSFORM_FLIP_H:
		return 0
	return (alt - SOOT_ALT_FLIP_BASE) if alt >= SOOT_ALT_FLIP_BASE else alt


## VL-01: (bucket, flipped) → alternative id, for callers with no soot to carry.
static func encode_light_alt(bucket: int, flipped: bool) -> int:
	return encode_voxel_alt(bucket, FACE_SOOT_CODE_CLEAN, flipped)


## VL-01: alternative id → light bucket (0..LIGHT_BUCKET_COUNT-1).
static func decode_light_bucket(alt: int) -> int:
	return LIGHT_BUCKET_COUNT - 1 - (_decode_alt_raw(alt) % LIGHT_BUCKET_COUNT)


## FACE-SOOT-01: alternative id → per-face soot code (63 = clean).
static func decode_face_soot_code(alt: int) -> int:
	@warning_ignore("integer_division")
	var slot: int = _decode_alt_raw(alt) / LIGHT_BUCKET_COUNT
	return FACE_SOOT_CODE_CLEAN - slot


## VL-01: alternative id → is the cell H-flipped (junction mirror)?
static func decode_light_flipped(alt: int) -> bool:
	return alt >= SOOT_ALT_FLIP_BASE

## Cells currently ghosted → Array of {"level": int, "prev_alt": int}, so a cell leaving
## the occluded set is restored to EXACTLY the alternative it had. We remember what was
## there rather than re-deriving what "should" be there: re-running the bake lookup here
## would be a second live copy of the placement decision, and it would diverge from the
## real one the moment bake config changed.
var _ghosted_cells: Dictionary = {}

## Z-index base for wall layers (from room.gd context)
var _wall_base_z_index: int = 10

## Array of TileMapLayers [level_0, level_1, ...] — walls/blocks/props, unchanged
## by D17. Positive levels only; never touched by the floor work below.
var _voxel_layers: Array[TileMapLayer] = []

## DESTRUCTION D17/D18: floor/background layers, keyed by their true (negative)
## level. A SEPARATE dictionary rather than folding into _voxel_layers above —
## on purpose, not an oversight: GDScript's `array[-1]` means "last element",
## not "grow downward", so unifying storage would mean every one of
## _voxel_layers' many existing 0-indexed callers (walls, junctions, props,
## occlusion) would need to learn to ignore negative keys. Keeping floor levels
## in their own dictionary means ALL of that positive-level code needs zero
## changes — D17's whole point. get_layer()/_set_voxel_cell() are the two
## routing points that make the split invisible to every other caller.
## Never contiguous-from-zero (D18: lazy reveal) — a level exists here only
## once something has actually built it.
var _negative_voxel_layers: Dictionary = {}

## FLOOR-DEPTH-02 (Director, 2026-07-28): depth → tone. With all three ground
## levels wearing the same zone texture (D20), a crater lost every cue that it
## HAS layers; each level down now renders a step darker, indexed by depth
## (-level - 1, so FLOOR_TOP_LEVEL = index 0 = untouched). Deeper than the table
## clamps to its last entry — bedrock at -8 must still read as bedrock, not as a
## black hole.
##
## Applied as a NODE modulate on the level's own TileMapLayer, which is the only
## knob that reaches every cell of a depth: the per-tile alternatives are owned by
## the light-bucket system (bucket_luminance below) and the FIXED levels place
## cells with no Voxel at all, so neither could carry this uniformly. Composes
## multiplicatively with both — the soot ADDS to this rather than being lightened
## out of the way (Director, 2026-07-28: darker all the way down, losing the
## texture to shadow at the bottom is acceptable).
##
## Ramp chosen by measurement, not by eye — four candidates captured on the same
## real detonation with the map's flickering lamp held off so the lighting was
## identical across runs, then the level -2 / level -3 pixels segmented by their
## ratio against a no-dim reference (lit floor = 161/255 in every frame):
##
##   ramp                     level -2        level -3     step
##   none                  51.5 (31.9%)   54.7 (33.9%)     -3.2  ← inverted
##   0.82 / 0.66           42.5 (26.4%)   36.3 (22.5%)      6.2
##   0.70 / 0.45  (this)   36.8 (22.8%)   25.1 (15.6%)     11.7
##   0.55 / 0.28           29.3 (18.1%)   15.8 ( 9.8%)     13.5
##
## Note the first row: with no dim the deeper level came out BRIGHTER than the one
## above it (the soot BFS reaches it with a fainter ring), so there was not merely
## no depth cue — there was an inverted one. The chosen ramp nearly doubles the
## step of the gentle one; the strong one buys only 1.8 more grey levels and pays
## for it by crushing level -3 to 9.8% of the floor, where the texture is gone.
##
## Deeper entries (0.34, 0.28) are for the map's outer lateral cut. When D18's
## decorative storeys land (water, smoke, lava) they will need their own tone
## rule: a lava level is a light SOURCE, and this ramp would dim it into mud.
const FLOOR_DEPTH_DIM: Array[float] = [1.0, 0.70, 0.45, 0.34, 0.28]

## FLOOR-DEPTH-01 (Director, 2026-07-28): GU cell → {"material", "anchor"} of the
## floor zone declared over it, published by room_builder at build time.
##
## The FIXED ground levels place cells directly (render_fixed_earth_level — no
## Slab, no Voxel, D13), so unlike the destructible planes above them they have no
## container to read a zone material off. Without this table a crater's exposed
## bottom always fell back to the earth-variant hash, which is exactly the "chão
## com material padrão" the Director reported: the floor zone bake stopped at the
## surface. Empty for unzoned GUs, which keep rendering as plain earth.
var _floor_zone_by_gu: Dictionary = {}

## Runtime TileSet
var _tileset: TileSet

## Source ids registered by register_baked_atlas_page() — one full set per rebuild
## (every view rotation re-bakes). Unlike the four MATERIALS sources (built once,
## permanent), these are transient: clear() removes them so a rebuild doesn't leave
## the previous rotation's pages (and their minted ghosts) orphaned in _tileset
## forever. Left unpruned, source_count grows without bound across rotations.
var _baked_source_ids: Array[int] = []

## Visual grid offset (isometric screen space)
var _visual_grid_offset: Vector2

## DEBUG-02: Accumulated nudge offset (pixels). Applied to all layers for real-time measurement.
var debug_nudge: Vector2 = Vector2.ZERO

## Cached baking components (Item 7: caching hot-path objects)
var _bake_config = null       # Script ref, loaded once
var _baked_lookup = null      # BakedTileLookup instance, created once

## D33 Part 1: created lazily on first use (get_damage_composite_cache()) so a
## renderer that never composites a decal never pays for the Image pages.
var _damage_composite_cache: DamageCompositeCache = null

## D33 Part 3a: raw decal art loaded from disk once per path and kept for this
## renderer's lifetime (decals/ never changes mid-session, unlike the composite
## cache above, which is intentionally reset every build_from_layout() pass).
var _decal_image_cache: Dictionary = {}

## D33 Part 3b: base_material -> the flat MATERIALS atom's own lateral-face
## Color, read once and cached. See _flat_material_side_color()'s own comment
## for why this is the right source for a half-voxel's cut-face fill tone.
var _flat_side_color_cache: Dictionary = {}

## VL-03-PERF: Vector4i(source_id, coords.x, coords.y, alt_id) → true for every
## light-bucket alternative already minted. Cleared when sources are rebuilt
## (prune_baked_sources / clear) so it never points at a stale source.
var _minted_light_alts: Dictionary = {}

## BAKE-DIAG-01: placement counters, reset at the top of each render() call
var _diag_total_cells: int = 0
var _diag_baked_hits: int = 0
var _diag_generic_fallbacks: int = 0
var _diag_null_edge_cells: int = 0
var _diag_slice_count: int = 0


## Setup: builds tileset and prepares for rendering
func setup(visual_grid_offset: Vector2, wall_base_z_index: int = 10) -> void:
	_visual_grid_offset = visual_grid_offset
	_wall_base_z_index = wall_base_z_index
	_build_voxel_tileset()


## Set baked lookup (called by room_builder after baking completes)
## This is the key link between room_builder's populated lookup and live rendering
func set_baked_lookup(lookup) -> void:
	_baked_lookup = lookup
	print("[VOXEL] Baked lookup set: %s" % ("registered" if lookup != null else "null"))


## Register a baked atlas page as a source on this renderer's own TileSet.
## BAKE-LIVE-VERIFY-01-b Part 3: Fixes BUG B — pages now go on the right tileset.
## BAKE-DIAG-01: also fixes BUG C — a TileSetAtlasSource has zero valid tiles until
## create_tile() is called per atlas coordinate (mirrors what _build_voxel_tileset()
## already does for the material-only sources). Without this, set_cell() on this
## source silently no-ops visually: the cell records source_id/atlas_coords, the
## placement-side counters see a "baked hit", but nothing draws — which is exactly
## why every wall vanished with bake enabled while the lookup/placement counters
## reported 100% success.
## atlas_coords_used: every (col, row) the compositor actually wrote pixel data to.
## tile_modulate: per-tile tint realizing the blend mode on grayscale baked pages
## (OVERLORD-FIX-01: TEXTURE_ONLY = white, MULTIPLY = material base color).
## Returns the assigned source_id.
func register_baked_atlas_page(page_image: Image, atlas_coords_used: Array = [], tile_modulate: Color = Color.WHITE) -> int:
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(page_image)
	source.texture_region_size = Vector2i(32, 36)  # GeometryCoords.VOXEL_ATOM_W/H [BAKE-FIX-01]

	var source_id := _tileset.get_next_source_id()
	_tileset.add_source(source, source_id)
	_baked_source_ids.append(source_id)

	for coords in atlas_coords_used:
		if source.get_tile_at_coords(coords) != Vector2i(-1, -1):
			continue
		source.create_tile(coords)
		var tile_data: TileData = source.get_tile_data(coords, 0)
		if tile_data != null:
			tile_data.texture_origin = GeometryCoords.voxel_texture_origin()
			tile_data.modulate = tile_modulate
			## VL-03-PERF: light-bucket alts are now minted LAZILY on first use
			## (see _ensure_light_alt) — eager-minting all 22 per tile cost ~3s of
			## the ~5s rotation (280k create_alternative_tile calls). Nothing to do
			## here at build time.

	return source_id


## D33 Part 1: lazily creates this renderer's DamageCompositeCache. Public so
## a future Part 3 seam (and this part's own selftest) can reach it without
## reconstructing VoxelRenderer's setup sequence.
func get_damage_composite_cache() -> DamageCompositeCache:
	if _damage_composite_cache == null:
		_damage_composite_cache = DamageCompositeCache.new(self)
	return _damage_composite_cache


## D33 Part 1: registers an EMPTY dynamic page for runtime-composited decal
## atoms — same TileSetAtlasSource shape register_baked_atlas_page() uses
## (32x36 region), but with no tiles yet; add_damage_composite_tile() below
## creates them one at a time as DamageCompositeCache fills slots. Appends to
## _baked_source_ids on purpose: this page is exactly as transient as a baked
## facade page (one per build_from_layout() pass) and prune_baked_sources()
## already removes everything in that list — no second cleanup path to keep
## in sync.
func register_damage_composite_page(page_image: Image) -> int:
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(page_image)
	source.texture_region_size = Vector2i(32, 36)  # DamageCompositeCache.ATOM_W/H

	var source_id := _tileset.get_next_source_id()
	_tileset.add_source(source, source_id)
	_baked_source_ids.append(source_id)
	return source_id


## D33 Part 1: adds ONE tile to an already-registered dynamic page at
## `atlas_coords` (a no-op if it already exists — DamageCompositeCache never
## calls this twice for the same slot, but staying idempotent costs nothing)
## and re-uploads the page texture so DamageCompositeCache.store()'s blit is
## actually visible. Mirrors register_baked_atlas_page()'s per-tile setup
## (texture_origin) for one coordinate instead of a whole batch.
func add_damage_composite_tile(source_id: int, page_image: Image, atlas_coords: Vector2i) -> void:
	var source: TileSetAtlasSource = _tileset.get_source(source_id)
	if source == null:
		push_error("[D33] add_damage_composite_tile: source_id %d not registered" % source_id)
		return
	if source.get_tile_at_coords(atlas_coords) == Vector2i(-1, -1):
		source.create_tile(atlas_coords)
		var tile_data: TileData = source.get_tile_data(atlas_coords, 0)
		if tile_data != null:
			tile_data.texture_origin = GeometryCoords.voxel_texture_origin()
	(source.texture as ImageTexture).update(page_image)


## D33 Part 3a: raw decal art from disk, cached by path for this renderer's
## lifetime. Returns null (and push_error()s once) if the file is missing —
## the caller treats that exactly like "no baked atom here": fall through to
## today's generic path, never a crash.
func _load_decal_image(path: String) -> Image:
	if _decal_image_cache.has(path):
		return _decal_image_cache[path]
	var tex: Texture2D = load(path)
	if tex == null:
		push_error("[D33 Part 3a] missing decal asset: %s" % path)
		_decal_image_cache[path] = null
		return null
	var img := tex.get_image()
	_decal_image_cache[path] = img
	return img


## D33 Part 3a — the real seam: composites `plan`'s decal (see
## _full_voxel_decal_plan()) onto the baked atom this cell would have shown if
## undamaged, caches the result (Part 1), and returns
## {"source_id":, "atlas_coords":, "alternative_id":} — or {} if there is no
## baked atom to composite onto (unbaked map, BakeConfig off, an edge-less
## cell, or the decal file is missing), which the caller reads exactly like a
## baked-lookup miss: fall through to the generic MATERIALS path unchanged.
##
## Cache key is view-space grid_pos + level + the exact material_name string —
## safe specifically BECAUSE DamageCompositeCache is reset every
## build_from_layout() pass (Part 1): grid_pos never has to mean the same
## thing across two different rebuilds, because the cache never survives one.
## See PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §11 for why that simplification
## holds now that player rotation (the only thing that used to rebuild
## mid-session) is gone.
##
## Tint: baked facade PAGES are grayscale-plus-modulate (BakeCompositor;
## the real material colour is a per-tile TileData.modulate, never baked into
## the page's own pixels) — read back raw, the substrate would be colourless.
## Applied here, once, directly to the substrate's pixels before compositing,
## so the STORED composite already carries the real colour and the new tile
## registers with the default WHITE modulate — which is also why
## _ensure_light_alt()'s lazy light-bucket minting (unmodified, works on any
## source_id) keeps dimming this tile correctly: it derives its bucket
## multiplier from the tile's OWN alt-0 modulate, and multiplying
## already-tinted pixels by WHITE-times-luminance is the same final colour as
## multiplying grayscale pixels by tint-times-luminance.
func _composite_full_voxel_decal(plan: Dictionary, material_name: String, edge,
		slice_face: int, voxel_xy: Vector2i, level: int, grid_pos: Vector2i) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_tinted_baked_atom(edge, slice_face, voxel_xy, level)
	if resolved.is_empty():
		return {}

	var decal_path := DECAL_NAME_TEMPLATE % [plan["decal_family"], plan["base_material"], plan["variant"]]
	var decal_image := _load_decal_image(decal_path)
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(resolved["image"], decal_image, plan["targets"])
	var entry := cache.store(key, composite)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = resolved["alternative_id"]
	return entry


## D33 Part 3a/3b shared: resolves the baked atom this cell would show if
## undamaged and returns it with the baked page's own per-tile modulate
## already applied to its pixels (see _composite_full_voxel_decal()'s
## original doc comment for why: baked facade pages are grayscale-plus-
## modulate, not pre-tinted, so a raw readback would be colourless). Returns
## {} on any kind of miss (no baked atom here, unbaked map, BakeConfig off) —
## the caller's signal to fall through to the generic path.
func _resolve_tinted_baked_atom(edge, slice_face: int, voxel_xy: Vector2i, level: int) -> Dictionary:
	var substrate_result = _baked_lookup.resolve(edge, slice_face, voxel_xy, level)
	if substrate_result == null or substrate_result.source_id_int < 0:
		return {}
	var baked_source: TileSetAtlasSource = _tileset.get_source(substrate_result.source_id_int)
	if baked_source == null:
		return {}

	var region := Rect2i(substrate_result.atlas_coords * Vector2i(32, 36), Vector2i(32, 36))
	var substrate: Image = baked_source.texture.get_image().get_region(region)
	var base_tile_data: TileData = baked_source.get_tile_data(substrate_result.atlas_coords, 0)
	var base_modulate: Color = base_tile_data.modulate if base_tile_data != null else Color.WHITE
	for y in range(substrate.get_height()):
		for x in range(substrate.get_width()):
			var c := substrate.get_pixel(x, y)
			substrate.set_pixel(x, y, Color(
				c.r * base_modulate.r, c.g * base_modulate.g, c.b * base_modulate.b, c.a))

	return {"image": substrate, "alternative_id": substrate_result.alternative_id}


## D33 Part 3b: the flat MATERIALS atom's own lateral-face colour for
## `base_material`, read once from the ALREADY-LOADED flat texture and
## cached. This is the cut face's fill tone (generate_voxel.py:
## `_darken(base_color, SIDE_DARKEN)`), and reading it from the real flat
## atom — rather than re-deriving a darken factor against a baked tile's
## modulate — sidesteps a real ambiguity: it is not established whether a
## baked tile's own modulate already represents this exact darkened lateral
## tone or a pre-shader value voxel_face_shading.gdshader darkens further at
## render time, and guessing wrong here would over- or under-darken the cut
## face. The flat atom's own pixels are unambiguous: generate_voxel_atom()
## paints both lateral faces with exactly this tone, and MATERIALS[base_material]
## is that exact same generator's output, already loaded at boot.
func _flat_material_side_color(base_material: String) -> Color:
	if _flat_side_color_cache.has(base_material):
		return _flat_side_color_cache[base_material]
	var source_id: int = MATERIALS.find(base_material)
	var color := Color.WHITE
	if source_id >= 0:
		var source: TileSetAtlasSource = _tileset.get_source(source_id)
		if source != null and source.texture != null:
			## (8, 26): comfortably inside either lateral face's y-band
			## (16..35) regardless of the exact diamond silhouette, for any
			## of the flat wall materials this is ever called with.
			color = source.texture.get_image().get_pixel(8, 26)
	_flat_side_color_cache[base_material] = color
	return color


## D33 Part 3b — the half-voxel counterpart to _composite_full_voxel_decal():
## builds the DENTED substrate (cut face flat-filled, kept face/top read from
## the real baked atom — HalfVoxelCompositor.build_half_voxel_substrate()),
## pastes the decal onto the exposed cut face, caches, and returns the same
## {source_id, atlas_coords, alternative_id} shape. {} on any miss (no baked
## atom, missing decal file) falls through to the generic path unchanged.
func _composite_half_voxel_decal(plan: Dictionary, material_name: String, edge,
		slice_face: int, voxel_xy: Vector2i, level: int, grid_pos: Vector2i) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_tinted_baked_atom(edge, slice_face, voxel_xy, level)
	if resolved.is_empty():
		return {}

	var cut_fill := _flat_material_side_color(plan["base_material"])
	var half_substrate := HalfVoxelCompositorClass.build_half_voxel_substrate(
		resolved["image"], cut_fill, plan["side"])

	var decal_path := DECAL_NAME_TEMPLATE % [plan["decal_family"], plan["base_material"], plan["variant"]]
	var decal_image := _load_decal_image(decal_path)
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(half_substrate, decal_image, [plan["target"]])
	var entry := cache.store(key, composite)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = resolved["alternative_id"]
	return entry


## VL-03-PERF: mint ONE light-bucket alternative for one tile, on first use.
##
## Eager-minting all 22 alternatives (buckets 0..4 × flip) for all ~13k tiles
## cost ~3s of every rotation — over half the total — because every tile paid
## for buckets it never displayed. Most cells sit in only a handful of distinct
## buckets, so minting on demand is dramatically cheaper (measured below). The
## `_minted_light_alts` set makes the check O(1) and idempotent.
##
## alt 0 (full-lit, base) and TRANSFORM_FLIP_H (full-lit, H-flipped) are native
## Godot tiles — always valid, never minted here. Everything else is a dim
## bucket alternative created lazily.
##
## Two traps inherited from the ghost era, both silent:
##  - create_alternative_tile() returns a BLANK TileData — texture_origin must be
##    re-applied or the cell jumps 10 px the instant its bucket changes.
##  - the modulate must derive from the tile's BASE modulate (baked pages are
##    tinted per page), not hardcoded white.
func _ensure_light_alt(source_id: int, coords: Vector2i, alt_id: int) -> void:
	if alt_id == 0 or alt_id == TileSetAtlasSource.TRANSFORM_FLIP_H:
		return
	var key := Vector4i(source_id, coords.x, coords.y, alt_id)
	if _minted_light_alts.has(key):
		return
	_minted_light_alts[key] = true
	var source: TileSetAtlasSource = _tileset.get_source(source_id)
	if source == null:
		return
	var base_data: TileData = source.get_tile_data(coords, 0)
	var base_modulate: Color = base_data.modulate if base_data != null else Color.WHITE
	var bucket: int = decode_light_bucket(alt_id)
	var lum: float = bucket_luminance[bucket]
	source.create_alternative_tile(coords, alt_id)
	var alt_data: TileData = source.get_tile_data(coords, alt_id)
	if alt_data == null:
		push_error("[VL-03-PERF] Failed to create light alternative %d at %s" % [alt_id, coords])
		return
	alt_data.texture_origin = GeometryCoords.voxel_texture_origin()
	## FACE-SOOT-01: RGB stays exactly what it was — base tint × light bucket —
	## and the per-face soot code rides in ALPHA, which nothing else uses since
	## OCC-21 stopped placing ghost alternatives. Encoded as (code + 1) / 64 so
	## it is never 0 (a 0 alpha would erase the voxel before the shader could
	## read it) and so the clean code 63 lands on exactly 1.0 — an untouched
	## voxel's modulate is bit-identical to the pre-FACE-SOOT-01 one.
	##
	## base_modulate.a must be 1.0 for the shader to recover the code by dividing
	## it back out; it always is (Color.WHITE, or a MaterialDef.base_color, both
	## opaque). Loud-fail rather than render silently-wrong soot everywhere (B6).
	if not is_equal_approx(base_modulate.a, 1.0):
		push_error("[FACE-SOOT-01] Base tile modulate at %s is not opaque (a=%.3f) — the per-face soot code rides in alpha and cannot survive a non-opaque base" % [coords, base_modulate.a])
		return
	var soot_alpha: float = float(decode_face_soot_code(alt_id) + 1) / float(FACE_SOOT_CODE_COUNT)
	alt_data.modulate = Color(
		base_modulate.r * lum, base_modulate.g * lum, base_modulate.b * lum, soot_alpha)
	alt_data.flip_h = decode_light_flipped(alt_id)


## Getter for voxel layer at given level (for diagnostics). D17: negative
## levels (floor/background) route to _negative_voxel_layers; this is the
## single point that makes the split storage invisible to every caller.
func get_layer(level: int) -> TileMapLayer:
	if level < 0:
		return _negative_voxel_layers.get(level)
	if level >= _voxel_layers.size():
		return null
	return _voxel_layers[level]


## FLOAT-PROP-Z-01 — sentinel for "this GU has no wall/block geometry at all".
## Not -1: level -1 is a real (floor) level, and a caller comparing heights would
## silently treat an empty column as ground.
const EMPTY_COLUMN: int = -9999


## FLOAT-PROP-Z-01 — classify the geometry that actually overlaps a world-space
## rect (a prop's sprite), split by whether it is NEARER or FARTHER than that
## prop, so the caller can pick a z_index that sorts correctly against both.
##
## Returns {"behind_top_z": int, "covered_from_front": bool}; behind_top_z is
## EMPTY_COLUMN when nothing farther-or-equal overlaps.
##
## Works at VOXEL resolution, and that is the whole point. The first version of
## this asked "does GU X have geometry, and how tall is its column" — but walls
## are not per-GU columns: SliceGenerator puts a wall's slice in a single 8-voxel
## ROW, and the far slice of an edge lands one voxel INSIDE the neighbour GU. So
## a GU-granular test reported the weapon's own cell and its neighbour as
## "occupied to level 17" (real, but a thin row 128px off to the side) and buried
## the prop under the map. Measured on a real run, not reasoned about.
##
## Depth is OcclusionSet's POLICY O5 — (x + y) in view space, greater = nearer —
## applied at voxel scale, where it holds for the same reason it holds per GU:
## the same diamond, 8× finer.
##
## The per-voxel rect is approximate (the atom is 32×36 with a 16px top face; the
## anchor is the tile centre). ±10px of slop cannot change any answer here: the
## error this exists to prevent is a 128px-away slice counting as an occluder.
##
## Cost: (2·radius+1)² × layer count lookups — ~26k for a 16-voxel radius on
## PLAYGROUND's 24 layers. Called when a prop is placed and on every perspective
## rotation, NEVER per frame; a rotation already rebuilds the whole map (~3 s), so
## this is noise beside it. A per-frame caller would need a different design.
func classify_geometry_over_rect(center_voxel: Vector2i, world_rect: Rect2, radius: int) -> Dictionary:
	var result: Dictionary = {"behind_top_z": EMPTY_COLUMN, "covered_from_front": false}
	var ref_depth: int = center_voxel.x + center_voxel.y
	var atom_offset := Vector2(
		-float(GeometryCoords.VOXEL_ATOM_W) * 0.5,
		-float(GeometryCoords.VOXEL_ATOM_H) + float(GeometryCoords.VOXEL_TILE_H) * 0.5)
	var atom_size := Vector2(float(GeometryCoords.VOXEL_ATOM_W), float(GeometryCoords.VOXEL_ATOM_H))

	for vy in range(center_voxel.y - radius, center_voxel.y + radius + 1):
		for vx in range(center_voxel.x - radius, center_voxel.x + radius + 1):
			var cell := Vector2i(vx, vy)
			var nearer: bool = (vx + vy) > ref_depth
			## Top-down, stopping at this cell's highest OVERLAPPING voxel: that
			## one carries the greatest z the cell can contribute.
			for level in range(_voxel_layers.size() - 1, -1, -1):
				var layer: TileMapLayer = _voxel_layers[level]
				if layer == null:
					continue
				if layer.get_cell_source_id(cell) == -1:
					continue
				var anchor: Vector2 = layer.position + layer.map_to_local(cell)
				if not Rect2(anchor + atom_offset, atom_size).intersects(world_rect):
					continue
				if nearer:
					result["covered_from_front"] = true
				else:
					result["behind_top_z"] = maxi(int(result["behind_top_z"]), layer.z_index)
				break

	return result


## VL-D4 — screen/world anchor of one voxel cell (its N-vertex, same anchor
## `map_to_local()` gives for any tile), for overlays that need to draw AT a
## specific voxel (e.g. EmberOverlay's glow) without re-deriving the layer
## position formula themselves. Analytic, no empirical offset (project rule):
## reuses the REAL TileMapLayer's own `position` + `map_to_local()` — the exact
## transform Godot uses to render that cell — so this stays correct even if the
## layer-position formula ever changes. Good enough for a soft glow blob, which
## needs "roughly at this voxel," not pixel-exact face-centre alignment.
## Returns Vector2.ZERO if the level has no layer (caller's cell couldn't be
## there).
func voxel_world_position(grid_pos: Vector2i, level: int) -> Vector2:
	var layer := get_layer(level)
	if layer == null:
		return Vector2.ZERO
	return layer.position + layer.map_to_local(grid_pos)


## Number of voxel layers currently built (for OcclusionWireframeOverlay's per-column
## height scan — see get_layer()'s docstring for why callers must not assume LEVELS_PER_STOREY).
## Positive (wall) levels only, unchanged by D17 — occlusion's column scan has
## no reason to know about floor levels below it.
func get_layer_count() -> int:
	return _voxel_layers.size()


## OCC-03: Get the highest z_index across all voxel layers (used to render agent above all geometry).
## Returns: z_index of the topmost voxel layer, or WALL_BASE_Z_INDEX if no layers yet.
func get_max_voxel_z_index() -> int:
	if _voxel_layers.is_empty():
		return _wall_base_z_index
	# Each layer has z_index = _wall_base_z_index + level
	# Topmost layer is at index (_voxel_layers.size() - 1)
	return _wall_base_z_index + (_voxel_layers.size() - 1)


## Cells placed by the last render() pass. Reset at the top of every render().
## The B6 loud-fail guard in RoomBuilder reads this: a registry with slices that
## places zero cells means the render path did not run, and the game must not
## boot into a silently empty world. See OCC-FIX-01.
## FACE-SOOT-01 — how many tile alternatives lazy minting has actually created.
## The alternative-id SPACE is 1536 wide now (12 buckets × 64 per-face soot codes
## × 2 flips); what matters on a phone is how much of it a real map ever touches,
## and that is what this reports.
func minted_alt_count() -> int:
	return _minted_light_alts.size()


func get_placed_cell_count() -> int:
	return _diag_total_cells


## DEBUG-02: Apply real-time positional offset to all voxel layers.
## Accumulates nudges and shifts existing layers; new layers inherit the offset.
func apply_debug_nudge(delta: Vector2) -> void:
	debug_nudge += delta
	for layer in _voxel_layers:
		layer.position += delta
	for layer in _negative_voxel_layers.values():
		layer.position += delta


## Build runtime TileSet with 4 materials
## Honors Transform Canon: tile_size (32,16), DIAMOND_DOWN, texture_origin=(0,10)
func _build_voxel_tileset() -> void:
	_tileset = TileSet.new()
	_tileset.tile_size = GeometryCoords.VOXEL_TILE_SIZE
	_tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	_tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	
	# Add custom_data layer for tile name tracking
	_tileset.add_custom_data_layer(0)
	_tileset.set_custom_data_layer_name(0, "tile_name")
	_tileset.set_custom_data_layer_type(0, Variant.Type.TYPE_STRING)
	
	# Create TileSetAtlasSource for each material
	for mat_index in range(MATERIALS.size()):
		var material_name: String = MATERIALS[mat_index]
		var asset_path := (IMPACT_ASSET_TEMPLATE if _is_impact_mark(material_name) else VOXEL_ASSET_TEMPLATE) % material_name
		
		var texture := load(asset_path)
		if not texture:
			push_error("VoxelRenderer: missing texture for material '%s' at %s" % [material_name, asset_path])
			continue
		
		var atlas_source := TileSetAtlasSource.new()
		atlas_source.texture = texture
		atlas_source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		atlas_source.separation = Vector2i.ZERO
		atlas_source.margins = Vector2i.ZERO
		
		# Add tile at (0, 0) in atlas
		atlas_source.create_tile(Vector2i.ZERO)
		
		# Add to tileset first (required before setting custom_data)
		_tileset.add_source(atlas_source, mat_index)
		
		# Now get tile_data and set properties
		var tile_data: TileData = atlas_source.get_tile_data(Vector2i.ZERO, 0)
		if tile_data != null:
			# Set texture_origin (Transform Canon 3: from SLICE-00 verification)
			tile_data.texture_origin = GeometryCoords.voxel_texture_origin()
			# Set custom_data: tile_name = material_name
			tile_data.set_custom_data("tile_name", material_name)
			## VL-03-PERF: light-bucket alts minted lazily on first use — see
			## _ensure_light_alt (eager minting dominated rotation cost).


## Render all slices and junction columns from registry
## Creates cells in layers based on voxel positions and levels
func render(registry: EdgeRegistry, junction_columns: Array = []) -> void:
	# BAKE-DIAG-01: reset placement counters for this render pass
	_diag_total_cells = 0
	_diag_baked_hits = 0
	_diag_generic_fallbacks = 0
	_diag_null_edge_cells = 0

	_diag_slice_count = 0
	# Iterate all slices and render their voxels
	for slice in registry.all_slices():
		_diag_slice_count += 1
		# Try to get edge from registry (if available)
		var edge = registry.get_edge(slice.edge_id) if registry.has_method("get_edge") else null
		_render_slice(slice, edge)

	# Render junction columns.
	# INFILTRAITOR_SKIP_JUNCTIONS=1 renders the map with the filler columns
	# omitted — diff two captures to see exactly which pixels on screen belong
	# to junction columns and nothing else. This is how TOP-JUNCTION-06's
	# follow-up isolated their real screen footprint; keep it, it is the only
	# cheap way to answer "is this column doing anything?" for a given map.
	if OS.get_environment("INFILTRAITOR_SKIP_JUNCTIONS") != "1":
		for column in junction_columns:
			_render_junction_column(column, registry)


## BAKE-DIAG-01: prints a summary of the last render() pass — how many cells were
## placed, how many hit the baked lookup vs fell back to generic material, and the
## live tileset source count. Called by room_builder when BakeConfig.debug_bake_set_dump
## is on. This is the placement-side counterpart to the compositor/registration prints,
## and is what actually tells us whether baked results reach the screen at all.
func print_render_diagnostics() -> void:
	print("[BAKE-DIAG] render() summary: %d slices, %d cells placed (%d baked hits, %d generic fallbacks, %d cells with null edge)" % [
		_diag_slice_count, _diag_total_cells, _diag_baked_hits, _diag_generic_fallbacks, _diag_null_edge_cells
	])
	print("[BAKE-DIAG] voxel_renderer tileset source_count=%d, _baked_lookup=%s, _bake_config.enabled=%s" % [
		_tileset.get_source_count() if _tileset else -1,
		("set" if _baked_lookup != null else "NULL"),
		(_bake_config.enabled if _bake_config else "unloaded")
	])


## Render a solid block (SLICE-02: A-T2)
## Fills all 64 voxel positions of a GU across [start_level, start_level + storey_span).
## start_level=0 reproduces the old ground-anchored behavior; start_level>0 supports
## floating geometry (ceiling props, chandeliers, hanging objects — any block that
## doesn't start at floor 0).
func render_block(gu_cell: Vector2i, start_level: int, storey_span: int, material_name: String) -> void:
	# FIX-VOXEL-HEIGHT-01: multiply storey_span by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers(start_level * GeometryCoords.LEVELS_PER_STOREY + storey_span * GeometryCoords.LEVELS_PER_STOREY)
	
	# Get all voxel positions in this GU
	var voxel_positions: Array[Vector2i] = GeometryCoords.gu_voxels(gu_cell)
	
	# Render each voxel at each level in the span
	for level in range(start_level * GeometryCoords.LEVELS_PER_STOREY, (start_level + storey_span) * GeometryCoords.LEVELS_PER_STOREY):
		for voxel_pos in voxel_positions:
			_set_voxel_cell(voxel_pos, level, material_name)


## Render a single slice's voxels
func _render_slice(slice: Slice, edge = null) -> void:
	# Ensure we have enough layers
	# FIX-VOXEL-HEIGHT-01: multiply storey_count by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers(slice.storey_count * GeometryCoords.LEVELS_PER_STOREY)

	# For each voxel in the slice, set_cell at the appropriate layer
	for voxel in slice.voxels:
		if voxel.visible:
			# Derive local voxel position within 8×8 quad from grid position
			var voxel_xy = Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
			var render_material := damage_variant_material(slice.material, voxel.damage_state, voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant)
			_set_voxel_cell(voxel.grid_pos, voxel.level, render_material, edge, voxel_xy, slice.face)


## Render a junction column (BAKE-FIX-02: mirror-at-the-column implementation)
## By default: mirrors the neighboring wall voxel's atom (D-BAKE-2)
## If override_material is set and facade_enabled=false: renders flat material-only (D-BAKE-3)
## If override_material is set and facade_enabled=true: mirrors the override material's boundary atom (D-BAKE-3)
func _render_junction_column(column: JunctionResolver.JunctionColumn, registry: EdgeRegistry = null) -> void:
	# FIX-VOXEL-HEIGHT-01: multiply storey counts by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers(column.start_storey * GeometryCoords.LEVELS_PER_STOREY + column.storey_count * GeometryCoords.LEVELS_PER_STOREY)

	# Determine actual material to use (override if set, otherwise derived)
	var actual_material = column.override_material if column.override_material != "" else column.material
	
	for level_offset in range(column.storey_count * GeometryCoords.LEVELS_PER_STOREY):
		var level: int = column.start_storey * GeometryCoords.LEVELS_PER_STOREY + level_offset

		# Case 1: No facade (render flat material-only)
		if not column.facade_enabled:
			_set_voxel_cell(column.voxel_pos, level, actual_material)
		# Case 2: With facade (mirror neighbor's atom with H-flip)
		else:
			# OVERLORD-FIX-02: dedicated junction atoms — each half-face
			# CONTINUES its adjacent leg's plane. Try first; the legacy
			# neighbor-mirror path below remains the fallback.
			if _bake_config == null:
				_bake_config = load("res://godot/scripts/systems/bake_config.gd")
			if _baked_lookup == null:
				_baked_lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()
			if _bake_config and _bake_config.enabled:
				var junction_result = _baked_lookup.resolve_junction(column.voxel_pos, level)
				if junction_result and junction_result.source_id_int >= 0:
					_diag_total_cells += 1
					_diag_baked_hits += 1
					_voxel_layers[level].set_cell(column.voxel_pos, junction_result.source_id_int, junction_result.atlas_coords, 0)
					continue

			# BAKE-FIX-06: Find neighboring wall voxel and mirror its atom
			var neighbor_info = _find_neighbor_wall_voxel(column, registry)
			
			if neighbor_info:
				var neighbor_edge: Edge = neighbor_info["edge"]
				var neighbor_voxel: Voxel = neighbor_info["voxel"]
				
				# Resolve the neighbor voxel's baked atom (if baking enabled)
				var source_id: int = -1
				var atlas_coords: Vector2i = Vector2i.ZERO
				var alternative_id: int = 0
				
				if _bake_config == null:
					_bake_config = load("res://godot/scripts/systems/bake_config.gd")
				if _baked_lookup == null:
					_baked_lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()
				
				if _bake_config and _bake_config.enabled and neighbor_edge:
					# Get the voxel's local position within its slice
					var voxel_xy = Vector2i(neighbor_voxel.grid_pos.x % 8, neighbor_voxel.grid_pos.y % 8)
					var slice = registry.get_slice(neighbor_edge.slice_a_id) if registry.get_slice(neighbor_edge.slice_a_id) and neighbor_voxel in registry.get_slice(neighbor_edge.slice_a_id).voxels else registry.get_slice(neighbor_edge.slice_b_id)
					
					if slice:
						var result = _baked_lookup.resolve(neighbor_edge, slice.face, voxel_xy, level)
						if result and result.source_id_int >= 0:
							source_id = result.source_id_int
							atlas_coords = result.atlas_coords
							_diag_baked_hits += 1
							# JUNCTION-MIRROR-01 (2026-07-16, Director): a real baked
							# neighbor atom MUST be H-flipped — that is D-BAKE-2's
							# "mirror the last column". The no-flip TEST below stays
							# valid only for the generic material tile (its source art
							# isn't mirror-symmetric); leaving baked atoms unflipped
							# made lateral V-junction columns repeat the adjacent
							# slice's column verbatim instead of mirroring it.
							alternative_id = TileSetAtlasSource.TRANSFORM_FLIP_H

				_diag_total_cells += 1
				# TEST (no-flip hypothesis): fallback / no baked atom to mirror — use the
				# canonical, unflipped tile (alternative_id stays 0). Flipping a generic
				# material tile that isn't an actual mirrored neighbor atom serves no
				# purpose and, per pixel-symmetry probe, visibly shifts the silhouette
				# because the source art (voxel_<material>.png) isn't mirror-symmetric.
				if source_id < 0:
					_diag_generic_fallbacks += 1
					source_id = MATERIALS.find(actual_material)
					if source_id == -1:
						source_id = 0
					atlas_coords = Vector2i.ZERO
				
				# Set the cell with H-flipped alternative
				var layer: TileMapLayer = _voxel_layers[level]
				layer.set_cell(column.voxel_pos, source_id, atlas_coords, alternative_id)
			else:
				# No neighbor found: render flat material-only
				_set_voxel_cell(column.voxel_pos, level, actual_material)


## Set a voxel cell on the appropriate layer
## SEAM: Tries baked lookup first (if enabled and edge provided), falls back to material-only
## ROOF-BAKE-01/02c: flat_baked routes edge-less HORIZONTAL voxels (roof
## slabs) through BakedTileLookup.resolve_flat() — dedicated roof pages,
## keyed by the STRUCTURE-LOCAL offset passed in voxel_xy. Same fallback
## contract: any miss lands on the generic material atlas below.
func _set_voxel_cell(grid_pos: Vector2i, level: int, material_name: String,
                     edge = null, voxel_xy: Vector2i = Vector2i.ZERO,
                     slice_face: int = 0, flat_baked: bool = false) -> void:
	# D17: get_layer() routes negative levels to _negative_voxel_layers — the
	# caller must have ensured the layer first (_ensure_voxel_layers() for
	# level >= 0, _ensure_negative_voxel_layer() for level < 0), same contract
	# as before, now honored for both signs instead of hard-rejecting negative.
	var layer: TileMapLayer = get_layer(level)
	if layer == null:
		push_warning("VoxelRenderer._set_voxel_cell: level %d has no layer — call _ensure_voxel_layers()/_ensure_negative_voxel_layer() first" % level)
		return

	var source_id: int = -1
	var atlas_coords: Vector2i = Vector2i.ZERO
	var alternative_id: int = 0

	## D22: an impact-mark pseudo-material ("metal_dented" etc.) bypasses the
	## NORMAL baked-lookup branch below, full stop — it was never tied to
	## whatever baked facade the surrounding wall happens to use, since a
	## pre-composited voxel_%s.png (composites/) is self-contained ("encaixado
	## em qualquer lugar," Director). D33 Part 3a below is NOT that branch: for
	## the recognized full-voxel CRACKED cases, the decal is composited onto
	## the SAME baked atom the wall around it uses, on purpose — that is the
	## entire point of D33. DENTED (half-voxel) marks still fall straight
	## through to the generic path (Part 3b, not yet built).
	var is_impact_mark: bool = _is_impact_mark(material_name)

	# SEAM: Try baked lookup first (using cached instances)
	if _bake_config == null:
		_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	if _baked_lookup == null:
		_baked_lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()

	_diag_total_cells += 1
	if edge == null:
		_diag_null_edge_cells += 1

	if not is_impact_mark and _bake_config and _bake_config.enabled and edge != null:
		var result = _baked_lookup.resolve(edge, slice_face, voxel_xy, level)

		if result and result.source_id_int >= 0:
			source_id = result.source_id_int
			atlas_coords = result.atlas_coords
			alternative_id = result.alternative_id
			_diag_baked_hits += 1

	# ROOF-BAKE-01/02c: horizontal (edge-less) baked surfaces — roof slabs.
	# voxel_xy carries the STRUCTURE-LOCAL offset here (grid_pos − anchor),
	# the same container-local meaning it has for wall slices.
	if not is_impact_mark and source_id < 0 and flat_baked and _bake_config and _bake_config.enabled:
		var flat_result = _baked_lookup.resolve_flat(material_name, voxel_xy)
		if flat_result and flat_result.source_id_int >= 0:
			source_id = flat_result.source_id_int
			atlas_coords = flat_result.atlas_coords
			alternative_id = flat_result.alternative_id
			_diag_baked_hits += 1

	## D33 Part 3a: a full-voxel CRACKED impact mark (bullet on the struck
	## lateral face, or a blast on all three faces) whose underlying wall
	## resolves to a baked facade gets its decal composited onto THAT atom
	## instead of the flat generic material below. _full_voxel_decal_plan()
	## returns {} for everything this slice doesn't cover (DENTED — Part 3b —
	## and anything without a recognized shape), which falls through exactly
	## like before D33 existed; _composite_full_voxel_decal() itself returns
	## {} for "no baked atom here" (unbaked map, BakeConfig off, an edge-less
	## cell) or a missing decal file, same fall-through, never a crash.
	if is_impact_mark and _bake_config and _bake_config.enabled and edge != null:
		var plan := _full_voxel_decal_plan(material_name)
		if not plan.is_empty():
			var composite := _composite_full_voxel_decal(
				plan, material_name, edge, slice_face, voxel_xy, level, grid_pos)
			if not composite.is_empty():
				source_id = composite["source_id"]
				atlas_coords = composite["atlas_coords"]
				alternative_id = composite["alternative_id"]
				_diag_baked_hits += 1

		## D33 Part 3b: the half-voxel counterpart — wall DENTED (bullet or
		## blast, LEFT or RIGHT). Only reached when the full-voxel plan above
		## didn't match (CRACKED is full-voxel, DENTED is half-voxel; a name
		## is one or the other, never both). Floor ("_dented_top") and
		## ceiling ("_dented_bottom") remain a further increment —
		## _half_voxel_decal_plan() returns {} for them, same fall-through.
		if source_id < 0:
			var half_plan := _half_voxel_decal_plan(material_name)
			if not half_plan.is_empty():
				var half_composite := _composite_half_voxel_decal(
					half_plan, material_name, edge, slice_face, voxel_xy, level, grid_pos)
				if not half_composite.is_empty():
					source_id = half_composite["source_id"]
					atlas_coords = half_composite["atlas_coords"]
					alternative_id = half_composite["alternative_id"]
					_diag_baked_hits += 1

	# Fallback: material-only path
	if source_id < 0:
		_diag_generic_fallbacks += 1
		source_id = MATERIALS.find(material_name)
		if source_id == -1:
			source_id = 0  # Fallback to concrete
		atlas_coords = Vector2i.ZERO

	layer.set_cell(grid_pos, source_id, atlas_coords, alternative_id)




## BAKE-FIX-06: Find the neighbor wall voxel adjacent to a junction column
## Given the junction column and edge registry, finds the voxel belonging to one of
## the forming edges that is adjacent (not diagonal) to the column voxel.
## Returns: {"edge": Edge, "voxel": Voxel} or {} (empty dict) if not found
func _find_neighbor_wall_voxel(column: JunctionResolver.JunctionColumn, registry: EdgeRegistry) -> Dictionary:
	if not registry:
		return {}
	
	# Reconstruct the elbow GU from the diagonal cell (used for validation)
	var _elbow_gu = column.gu_cell - Face.delta(column.face_a) - Face.delta(column.face_b)
	
	# Get edges that created this junction
	var edge_a = registry.get_edge(column.edge_a_id) if column.edge_a_id else null
	var edge_b = registry.get_edge(column.edge_b_id) if column.edge_b_id else null
	
	if not edge_a or not edge_b:
		return {}
	
	# Get slices for both edges
	var slices_a = registry.slices_of_edge(edge_a.id)
	var slices_b = registry.slices_of_edge(edge_b.id)
	
	# Look for a voxel in slice_a or slice_b that is adjacent (not diagonal) to column.voxel_pos
	var candidate_slices = []
	candidate_slices.append_array(slices_a)
	candidate_slices.append_array(slices_b)
	
	var closest_voxel: Voxel = null
	var closest_edge: Edge = null
	var closest_distance: float = 999999.0
	
	for slice in candidate_slices:
		if slice and slice.voxels.size() > 0:
			for voxel in slice.voxels:
				if not voxel.visible:
					continue
				
				# Check if voxel is adjacent (not diagonal) to column.voxel_pos
				var dx = abs(voxel.grid_pos.x - column.voxel_pos.x)
				var dy = abs(voxel.grid_pos.y - column.voxel_pos.y)
				
				# Adjacent means exactly one of dx, dy is 1, the other is 0 (4-neighbor connectivity)
				if (dx == 1 and dy == 0) or (dx == 0 and dy == 1):
					var distance = sqrt(dx * dx + dy * dy)
					if distance < closest_distance:
						closest_distance = distance
						closest_voxel = voxel
						closest_edge = edge_a if slice in slices_a else edge_b
	
	if closest_voxel and closest_edge:
		return {"edge": closest_edge, "voxel": closest_voxel}
	
	return {}


## OCC-02/OCC-08 — apply the occluded-cell set as ghosts. THE single entry point.
##
## `occluded`: Vector2i (voxel COLUMN) → ring index, straight from OcclusionSet.
## OCC-08: the ring is an EDGE-GRAPH hop distance (0/1/2) from a triggering edge, not
## a voxel distance — every voxel belonging to the same edge shares one ring, so
## there is no per-voxel patchwork within a single wall to serrate. Every level of a
## ghosted column is ghosted: a wall covering the agent covers him from his feet to
## over his head, and the upper layers draw above him regardless of y-sort.
##
## Full restore, then full re-apply. The set is a few dozen columns and this runs on agent
## step / view change / map load — never per frame. Diffing would buy nothing and would
## add a second notion of "what is currently ghosted".
##
## O1: this never writes Voxel.visible, never sets a dirty flag, never persists. A ghost
## is a tile alternative and nothing more. If occlusion ever hid a voxel instead, a
## DESTROYED voxel would come back to life the moment the player rotated the camera over
## a crater — and that bug only reproduces under rotation, so it would survive for months.
func apply_occlusion(occluded: Dictionary) -> void:
	_restore_ghosted_cells()

	for cell in occluded.keys():
		var entry = occluded[cell]
		## OCC-10: min_level is where GHOSTING STARTS — the edge's own base band
		## (OcclusionSet.BASE_VISIBLE_LEVELS) sits below it and is never touched
		## here at all, left at its original full-opacity tile (Director's call:
		## the base always reads as solid footprint; only the rest ghosts).
		var min_level: int = int(entry.get("min_level", 0))
		## OCC-26 (2026-07-18): the erase stops at the occluding structure's OWN
		## top instead of running through every layer above it. Levels above an
		## occluded wall belong to someone else — concretely the roof's 1-voxel
		## border row, which the old open-ended loop erased along with the wall,
		## pushing the visible roof edge one voxel deeper (a ~4-px roofline seam
		## against the wireframe's top cap). Missing max_level (older callers,
		## tests) keeps the historical erase-to-top behavior.
		var max_level: int = int(entry.get("max_level", _voxel_layers.size() - 1))
		## OCC-21 dropped tile-alternative ghosting for erase+wireframe-fill (see
		## below) — `entry["ring"]` is no longer read here; ring-based visuals now
		## live entirely in occlusion_slice_panel.gd/occlusion_wireframe_overlay.gd.
		var restore_records: Array = []

		for level in range(min_level, mini(max_level + 1, _voxel_layers.size())):
			var layer: TileMapLayer = _voxel_layers[level]
			var source_id: int = layer.get_cell_source_id(cell)
			if source_id == -1:
				continue  ## nothing placed at this level of the column

			var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
			var prev_alt: int = layer.get_cell_alternative_tile(cell)

			## OCC-21 (2026-07-14): ERASE occluded cells entirely instead of ghosting.
			## The wireframe fill is now the sole visual representation. Store full
			## placement data (source, atlas, alt) for complete restoration later.
			restore_records.append({
				"level": level,
				"source_id": source_id,
				"atlas_coords": atlas_coords,
				"prev_alt": prev_alt
			})
			layer.erase_cell(cell)

		if not restore_records.is_empty():
			_ghosted_cells[cell] = restore_records


## OCC-02 — prove the restore is lossless, on the real map, not by argument.
##
## Snapshot every placed cell's (source, atlas, alternative) across every level; ghost the
## given set; release it; snapshot again; compare. Returns true iff the map is bit-identical
## afterwards.
##
## This is the invariant that matters most in the whole prompt. Ghosting runs on every agent
## step; if restore is lossy by even one alternative, the map degrades a little with each
## step the player takes — a corruption that accumulates invisibly and would be blamed on
## anything but occlusion months later.
func verify_ghost_roundtrip(occluded: Dictionary) -> bool:
	apply_occlusion({})          ## start from a clean, unghosted map
	var before := _snapshot_cells()
	apply_occlusion(occluded)
	apply_occlusion({})          ## release everything
	var after := _snapshot_cells()

	var ok := true
	if before.size() != after.size():
		push_error("[OCC-02] Round-trip changed the cell COUNT: %d → %d" % [before.size(), after.size()])
		ok = false
	else:
		for key in before.keys():
			if not after.has(key) or after[key] != before[key]:
				push_error("[OCC-02] Round-trip damaged cell %s: %s → %s" % [
					key, before[key], after.get(key, "<missing>")])
				ok = false
				break

	## Leave the map in the state the caller had: ghosts applied. A verification that
	## silently un-ghosts the world would make the very capture taken to prove ghosting
	## show none of it.
	apply_occlusion(occluded)
	return ok


## OCC-02: (level, cell) → [source_id, atlas_coords, alternative] for every placed cell.
func _snapshot_cells() -> Dictionary:
	var snap: Dictionary = {}
	for level in range(_voxel_layers.size()):
		var layer: TileMapLayer = _voxel_layers[level]
		for cell in layer.get_used_cells():
			snap[[level, cell]] = [
				layer.get_cell_source_id(cell),
				layer.get_cell_atlas_coords(cell),
				layer.get_cell_alternative_tile(cell),
			]
	return snap


## OCC-02: put every ghosted cell back to the exact alternative it had before we touched
## it. Reading the remembered value — not recomputing it — is what keeps occlusion a pure
## view layer over whatever placement decided (baked or generic).
func _restore_ghosted_cells() -> void:
	for cell in _ghosted_cells.keys():
		for record in _ghosted_cells[cell]:
			var level: int = record["level"]
			if level >= _voxel_layers.size():
				continue
			var layer: TileMapLayer = _voxel_layers[level]
			## OCC-21: restore from saved placement data, not current layer state
			## (the cell was erased, so layer queries would return -1)
			layer.set_cell(cell, record["source_id"], record["atlas_coords"], record["prev_alt"])
	_ghosted_cells.clear()


## VL-01 — repaint every placed voxel cell to its light bucket. Runs on
## lighting_rebuilt (map load, perspective rotation, light changes) — never per
## frame. Pure view layer, same contract as occlusion (O1): no Voxel state, no
## dirty flag, no persistence — placement decisions (source, atlas coords,
## flip) are read back from the cell and preserved; only the bucket changes.
## VL-02b — level → set of occupied cells, for the field's surface/AO shading.
## The renderer owns the tilemaps, so it owns this snapshot; a Dictionary set
## keeps the field's neighbour probes O(1) instead of a TileMap API call each.
## Includes negative (floor/slab) levels so floor craters shade like wall ones.
func build_occupancy() -> Dictionary:
	var occupancy: Dictionary = {}
	for level in range(_voxel_layers.size()):
		var level_set: Dictionary = {}
		for cell in _voxel_layers[level].get_used_cells():
			level_set[cell] = true
		occupancy[level] = level_set
	for level in _negative_voxel_layers.keys():
		var neg_set: Dictionary = {}
		for cell in _negative_voxel_layers[level].get_used_cells():
			neg_set[cell] = true
		occupancy[level] = neg_set
	## Cells hidden by occlusion are erased from the tilemap but are still SOLID
	## geometry — omitting them would make every ghosted column read as a cavity
	## and light up its neighbours the moment the agent walked past.
	for cell in _ghosted_cells.keys():
		for record in _ghosted_cells[cell]:
			var lvl: int = record["level"]
			if not occupancy.has(lvl):
				occupancy[lvl] = {}
			occupancy[lvl][cell] = true
	return occupancy


## VL-D3 — columns (x,y) covered by any wall/block/roof voxel (positive levels).
## A floor voxel in such a column was never sun-exposed; when a blast opens the
## wall above and exposes its top, it should read darker than always-open floor.
## Computed from the INTACT geometry right after a build (before reapply_damage),
## so it reflects the ORIGINAL cover, not the post-blast state.
func columns_with_structure() -> Dictionary:
	var cols: Dictionary = {}
	for level in range(_voxel_layers.size()):
		for cell in _voxel_layers[level].get_used_cells():
			cols[cell] = true
	return cols


## VL-03 — GU cell → Array[{level:int, cell:Vector2i}] for every currently
## placed voxel cell, rebuilt as a side effect of every FULL apply_light_field()
## pass (which already visits every cell — free to attach here). This is what
## lets apply_light_field_gus() repaint only a light's influence set without a
## whole-map scan: temporal lights (flicker/pulse, and future ember→char decay)
## toggle far too often to pay the full repaint's ~590ms every time. Stays
## correct between full passes because ghosting/destruction only ERASE cells
## (source_id -1, checked in the incremental path below) — they never add cells
## the index wouldn't already know about; any geometry change is followed by a
## full repaint anyway, which rebuilds this index from scratch.
var _placed_by_gu: Dictionary = {}


func apply_light_field(field) -> void:
	if field == null:
		return
	_placed_by_gu.clear()
	for level in range(_voxel_layers.size()):
		_apply_light_to_layer(_voxel_layers[level], level, field, true)
	for level in _negative_voxel_layers.keys():
		_apply_light_to_layer(_negative_voxel_layers[level], level, field, true)
	## Occluded cells are ERASED right now (OCC-21) and will come back from
	## _ghosted_cells records — retarget each stored alternative so releasing
	## occlusion cannot resurrect a stale bucket.
	for cell in _ghosted_cells.keys():
		for record in _ghosted_cells[cell]:
			var flipped: bool = decode_light_flipped(record["prev_alt"])
			record["prev_alt"] = encode_voxel_alt(
					field.bucket_for(cell, record["level"]),
					field.face_soot_code(cell, record["level"]), flipped)


## VL-03 — repaint ONLY the cells inside the given GU cells, using the index
## built by the last full apply_light_field() pass. For a temporal light
## (flicker/pulse) toggling: scopes the repaint to the light's own influence
## set instead of the whole map. Measured on PLAYGROUND's demo lamp (radius 7,
## 149 GUs, 29,180 voxels — a worst case: the radius fully overlaps a dense
## 2-storey wall row): ~75ms/toggle steady-state, down from the ~590-675ms a
## full rebuild cost for the same event (~88% reduction). A smaller or
## more open-area light touches far fewer voxels and costs proportionally
## less. Silently no-ops for a GU the index doesn't know about (nothing was
## ever placed there).
func apply_light_field_gus(field, gus: Array) -> void:
	if field == null or gus.is_empty():
		return
	var gu_set: Dictionary = {}
	for gu in gus:
		gu_set[gu] = true
		var placements = _placed_by_gu.get(gu)
		if placements == null:
			continue
		for entry in placements:
			var level: int = entry["level"]
			var cell: Vector2i = entry["cell"]
			var layer: TileMapLayer = get_layer(level)
			if layer == null:
				continue
			var source_id: int = layer.get_cell_source_id(cell)
			if source_id == -1:
				continue  ## erased — destroyed, or currently ghosted (handled below)
			var prev_alt: int = layer.get_cell_alternative_tile(cell)
			## FACE-SOOT-01: the whole id is the comparison now — the same light bucket
			## with different per-face soot is a different tile.
			var alt_id: int = encode_voxel_alt(field.bucket_for(cell, level),
					field.face_soot_code(cell, level), decode_light_flipped(prev_alt))
			if alt_id == prev_alt:
				continue
			var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
			_ensure_light_alt(source_id, atlas_coords, alt_id)
			layer.set_cell(cell, source_id, atlas_coords, alt_id)
	## Ghosted cells inside the affected GUs: retarget their stored alternative
	## too (same reasoning as apply_light_field()'s ghost retarget loop), so
	## un-ghosting later shows the bucket this toggle produced, not a stale one.
	for cell in _ghosted_cells.keys():
		if not gu_set.has(Vector2i(cell.x >> 3, cell.y >> 3)):
			continue
		for record in _ghosted_cells[cell]:
			var flipped: bool = decode_light_flipped(record["prev_alt"])
			record["prev_alt"] = encode_voxel_alt(
					field.bucket_for(cell, record["level"]),
					field.face_soot_code(cell, record["level"]), flipped)


func _apply_light_to_layer(layer: TileMapLayer, level: int, field, do_index: bool = false) -> void:
	for cell in layer.get_used_cells():
		if do_index:
			var gu := Vector2i(cell.x >> 3, cell.y >> 3)
			if not _placed_by_gu.has(gu):
				_placed_by_gu[gu] = []
			_placed_by_gu[gu].append({"level": level, "cell": cell})
		var prev_alt: int = layer.get_cell_alternative_tile(cell)
		## FACE-SOOT-01: see apply_light_field_gus() — compare the whole id.
		var alt_id: int = encode_voxel_alt(field.bucket_for(cell, level),
				field.face_soot_code(cell, level), decode_light_flipped(prev_alt))
		if alt_id == prev_alt:
			continue
		var source_id: int = layer.get_cell_source_id(cell)
		var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
		## VL-03-PERF: mint this bucket's alternative lazily, only now that a cell
		## actually needs it.
		_ensure_light_alt(source_id, atlas_coords, alt_id)
		layer.set_cell(cell, source_id, atlas_coords, alt_id)


## Process dirty slices only (TIC optimization)
func process_dirty(registry: EdgeRegistry) -> void:
	var dirty_slices := registry.dirty_slices()

	if dirty_slices.is_empty():
		return

	# Update cells for dirty voxels
	for slice in dirty_slices:
		# Try to get edge from registry
		var edge = registry.get_edge(slice.edge_id) if registry.has_method("get_edge") else null

		for voxel in slice.voxels:
			if voxel.dirty:
				# Update cell state based on voxel visibility
				if voxel.visible:
					var voxel_xy = Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
					var render_material := damage_variant_material(slice.material, voxel.damage_state, voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant)
					_set_voxel_cell(voxel.grid_pos, voxel.level, render_material, edge, voxel_xy, slice.face)
				else:
					# Clear cell
					if voxel.level < _voxel_layers.size():
						_voxel_layers[voxel.level].erase_cell(voxel.grid_pos)
						voxel_destroyed.emit(voxel.grid_pos, voxel.level, slice.material)

		# Clear all dirty flags in slice
		slice.clear_all_dirty()


## Slab-side counterpart to process_dirty() — DESTRUCTION_MASTER_PLAN Part 3.
## Until now nothing consumed SlabRegistry.dirty_slabs() on the render side:
## room.gd's _tic_slab_system() only cleared dirty flags. Re-render routes
## through the SAME per-voxel call each Slab's own original render used
## (render_slab()'s split — zone bake for a zoned floor, earth-hash otherwise —
## and render_slab_solid()'s fixed material for CEILING/INTERIOR) so a re-render
## after partial damage is pixel-identical to a fresh one for whatever voxels
## remain visible.
##
## Erase routes through get_layer() (sign-aware for both positive and
## negative levels) — process_dirty()'s raw `_voxel_layers[level]` indexing
## must NOT be copied here: GDScript arrays support Python-style negative
## indices, so a floor-level Voxel destroyed through that pattern would
## silently erase a cell from the wrong (last positive) layer instead of
## being a safe no-op.
func process_dirty_slabs(registry: SlabRegistry) -> void:
	var dirty_slabs := registry.dirty_slabs()
	if dirty_slabs.is_empty():
		return

	## FLOOR-ZONE fix (2026-07-28): a FLOOR Slab carrying a zone material re-renders
	## through the zone's baked page, exactly like render_slab() does — the branch
	## below used to send EVERY Role.FLOOR voxel down the earth-variant path, so a
	## dirty-but-surviving voxel of a zoned floor (a CRACKED one; a DESTROYED one
	## is erased instead) would come back as generic earth in the middle of an
	## otherwise concrete floor. Latent when written (craters only destroyed);
	## FLOOR-DENT-01 (2026-08-01) made floor damage real — crater-rim survivors
	## now carry DENTED with a carved TOP.
	if _bake_config == null:
		_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	for slab in dirty_slabs:
		var use_solid: bool = slab.role != Slab.Role.FLOOR
		var is_zoned_floor: bool = (not use_solid) and slab.material != "earth" \
				and _bake_config != null and _bake_config.enabled
		for voxel in slab.voxels:
			if not voxel.dirty:
				continue
			if voxel.visible:
				if use_solid or is_zoned_floor:
					var flat_baked: bool = slab.role == Slab.Role.CEILING or is_zoned_floor
					## D22: the substitution tags CEILING/INTERIOR exactly like a
					## wall (apply_container_damage).
					var render_material := damage_variant_material(slab.material, voxel.damage_state, voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant)
					## FLOOR-DENT-01: a zoned floor has no per-zone damage bake —
					## its dents route to the shared carved-TOP asset instead of
					## composing a "ground_*_blast_dented_top" name that MATERIALS
					## does not hold (which would repaint the voxel flat concrete).
					if is_zoned_floor:
						var floor_damaged := floor_damage_material(voxel.damage_state,
							voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant)
						if floor_damaged != "":
							render_material = floor_damaged
					_set_voxel_cell(voxel.grid_pos, voxel.level, render_material,
							null, voxel.grid_pos - slab.texture_anchor, 0, flat_baked)
				else:
					## FLOOR-DENT-01: a damaged floor voxel renders its carved
					## variant instead of a pristine earth variant — this branch
					## was unreachable for damage before (craters only destroyed)
					## and would silently repaint a dent as intact ground.
					var earth_material := floor_damage_material(voxel.damage_state,
						voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant)
					if earth_material == "":
						earth_material = "earth_%d" % EarthVariantSelector.variant_for(voxel.grid_pos, voxel.level)
					_set_voxel_cell(voxel.grid_pos, voxel.level, earth_material)
			else:
				var layer := get_layer(voxel.level)
				if layer != null:
					layer.erase_cell(voxel.grid_pos)
					voxel_destroyed.emit(voxel.grid_pos, voxel.level, slab.material)

		slab.clear_all_dirty()


## Ensure layers exist up to storey count (E1 equation from SLICE-00)
## Build one properly-configured voxel TileMapLayer node for a given level —
## positive (wall) or negative (D17: floor/background). Shared by
## _ensure_voxel_layers() and _ensure_negative_voxel_layer() so the position/
## z-index formula has exactly one owner; the two callers differ only in
## WHERE they file the result (_voxel_layers vs _negative_voxel_layers),
## never in HOW a layer is built.
## FACE-READ-01 — one shared ShaderMaterial for every voxel layer. Built lazily
## and reused: the shader is stateless (its uniforms are global tuning, not
## per-layer), so N layers share one material and one pipeline.
var _face_shading_material: ShaderMaterial


func _get_face_shading_material() -> ShaderMaterial:
	if _face_shading_material != null:
		return _face_shading_material
	var shader = load("res://godot/shaders/voxel_face_shading.gdshader")
	if shader == null:
		## B6 loud-fail: silently rendering undifferentiated voxels is exactly
		## the class of bug this project keeps paying for.
		push_error("[VoxelRenderer] FACE-READ-01: voxel_face_shading.gdshader failed to load — voxel faces will render flat")
		return null
	_face_shading_material = ShaderMaterial.new()
	_face_shading_material.shader = shader
	return _face_shading_material


func _build_voxel_layer_node(level: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = _tileset
	layer.name = "voxel_layer_%d" % level
	## FACE-READ-01: per-face shading, the one seam that reaches BOTH the
	## material-only and the baked tile paths — see the shader's own header.
	layer.material = _get_face_shading_material()

	# E1 equation from Transform Canon (SLICE-00)
	# Compensation between floor grid (256×128 tiles) and voxel grid (32×16 tiles):
	# TILE_OFFSET = (floor_half_w − voxel_half_w, floor_half_h) = (128−16, 64) = (112, 64).
	# NOTE: the pre-2026-07-02 value (112, 56) subtracted voxel_half_h on Y as well —
	# an 8px error, empirically measured and corrected via DEBUG-02 ruler + nudge session
	# (residual now zero). Do not "restore symmetry" to (112, 56); the asymmetry is correct.
	# Formula is sign-agnostic: a negative level correctly pushes the layer DOWN
	# on screen (subtracting a negative adds height), which is exactly D17's floor.
	const TILE_OFFSET: Vector2 = Vector2(112.0, 64.0)
	layer.position = Vector2(
		_visual_grid_offset.x + TILE_OFFSET.x + debug_nudge.x,
		_visual_grid_offset.y + TILE_OFFSET.y + debug_nudge.y - GeometryCoords.VOXEL_STEP_PX * float(level)
	)

	# Set rendering parameters
	layer.y_sort_origin = 1
	# Z-index: positive (wall/roof) levels stack above _wall_base_z_index as
	# before. Negative (D17 floor/background) levels render in the LEGACY FLOOR
	# SLOT instead: the whole floor-painted overlay ecosystem (shadows z=1,
	# FOW z=2, game tiles z=3, AP perimeter z=5, path z=6, selection z=7) was
	# designed against a floor at z<=0 and must draw ON the floor yet UNDER the
	# walls (z>=10). `_wall_base_z_index + level` put the earth floor's top at
	# z=9, burying all of them (first visible casualty: AP perimeter, Director
	# 2026-07-16). Formula: level+1 puts the walkable top face (-1) at z=0 and
	# bedrock (-8..-2) at -7..-1; floor_layer (legacy plane) sits below at -9.
	layer.z_index = (_wall_base_z_index + level) if level >= 0 else (level + 1)
	layer.visible = true

	## FLOOR-DEPTH-02: one tone step per level down. Positive (wall) levels are
	## never touched — depth is a ground concept, and a wall's own stack already
	## reads through its facade shading.
	if level < 0:
		var depth_index: int = mini(-level - 1, FLOOR_DEPTH_DIM.size() - 1)
		var dim: float = FLOOR_DEPTH_DIM[depth_index]
		layer.modulate = Color(dim, dim, dim, 1.0)

	# Add to scene tree
	add_child(layer)
	return layer


func _ensure_voxel_layers(storey_count: int) -> void:
	while _voxel_layers.size() < storey_count:
		var level := _voxel_layers.size()
		_voxel_layers.append(_build_voxel_layer_node(level))


## D17/D18: negative levels are never contiguous-from-zero and rarely all
## exist at once — callers ensure exactly the one level they need (the top
## destructible floor level, always; deeper fixed/cosmetic levels only once
## something has actually dug down to them). No "ensure up to N" variant on
## purpose: that shape would invite building a contiguous run nobody asked
## for, which is precisely what D18 forbids.
func _ensure_negative_voxel_layer(level: int) -> void:
	if level >= 0:
		push_error("VoxelRenderer._ensure_negative_voxel_layer: level %d is not negative" % level)
		return
	if _negative_voxel_layers.has(level):
		return
	_negative_voxel_layers[level] = _build_voxel_layer_node(level)


## DESTRUCTION D1/D2/D4 — render one Slab's voxels. Each voxel independently
## picks its earth variant via EarthVariantSelector.variant_for(grid_pos,
## level) — deterministic, so this is idempotent: calling it again on the
## same Slab places the exact same cells (D5's "nothing to pop" property).
## Not wired to any real map data yet (no MapSpec integration) — this is the
## render-side half of Part 2's core, consumed directly by whatever builds a
## Slab (today: only slab_generator.gd's manual/test construction).
func render_slab(slab: Slab) -> void:
	if slab.voxels.is_empty():
		return
	# All of one Slab's voxels share slab.level (SlabGenerator.generate()'s
	# invariant) — one layer to ensure, not a min/max scan. D17: negative
	# (floor) levels route to the negative-only ensure function.
	if slab.level < 0:
		_ensure_negative_voxel_layer(slab.level)
	else:
		_ensure_voxel_layers(slab.level + 1)

	# Floor-zone bake: a Slab whose material isn't the "earth" sentinel was
	# assigned a zone material by room_builder.gd's flood-fill (texture_anchor
	# set alongside it). Decided ONCE per Slab, not per voxel — every voxel in
	# a floor Slab shares one gu_cell (SlabGenerator generates one Slab per GU).
	#
	# Gated on _bake_config.enabled here (not just left to _set_voxel_cell's
	# own gate) because ground_* materials are deliberately absent from
	# MATERIALS: unlike render_slab_solid()'s CEILING materials (always a
	# real wall material — concrete/metal/stone/wood — so falling back to the
	# unbaked version of the SAME material is a harmless miss), a ground_*
	# name falling through to _set_voxel_cell's MATERIALS.find() would resolve
	# to -1 and silently default to MATERIALS[0] ("concrete") — a flat gray
	# floor instead of the expected earth look. With bake off, zoned floor
	# always falls back to EarthVariantSelector here instead.
	if _bake_config == null:
		_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var is_zoned: bool = slab.material != "earth" and _bake_config != null and _bake_config.enabled

	## FLOOR-DEPTH-01: skip voxels destruction already took. At build time this
	## changes nothing (a freshly generated Slab is entirely visible), but the
	## deep floor plane is now rendered ON EXPOSURE rather than at build, so this
	## function can run against a Slab that already has holes — twice, if a second
	## blast reaches the same GU, and once more after every perspective rotation
	## re-applies the damage registry. Without the skip each of those would place
	## a cell back into a hole and silently heal the crater.
	if is_zoned:
		for voxel in slab.voxels:
			if not voxel.visible:
				continue
			_set_voxel_cell(voxel.grid_pos, voxel.level, slab.material,
					null, voxel.grid_pos - slab.texture_anchor, 0, true)
		return

	for voxel in slab.voxels:
		if not voxel.visible:
			continue
		var variant_index: int = EarthVariantSelector.variant_for(voxel.grid_pos, voxel.level)
		var material_name: String = "earth_%d" % variant_index
		_set_voxel_cell(voxel.grid_pos, voxel.level, material_name)


## FLOOR-DEPTH-01 — put a deferred-render floor plane on screen.
##
## The deep floor Slab (GeometryCoords.FLOOR_DEEP_LEVEL) is generated at build but
## never rendered there: it is fully occluded by the plane above it, so its cells
## would cost tilemap memory and full-repaint time to draw nothing. This is the
## seam that pays that cost only once the plane above has actually opened — from
## the blast path, and again from the post-rotation damage replay.
##
## Idempotent by construction (render_slab skips destroyed voxels): calling it on
## an already-revealed, already-cratered plane re-places exactly the cells that
## are still there and leaves the holes alone.
func reveal_floor_slab(slab: Slab) -> void:
	render_slab(slab)


## DESTRUCTION — render one Slab's voxels using a single FIXED material for
## every voxel, no per-voxel hash. Sibling to render_slab() (the earth/floor
## path, which selects a variant per voxel) — kept separate rather than
## branching one function on material type, since the two have genuinely
## different per-voxel logic. For roof/ceiling Slabs (Slab.Role.CEILING):
## these reuse an EXISTING wall material 1:1 (concrete/metal/stone/wood),
## matching whatever structure they sit above, the same way render_block()
## already places one fixed material across a whole block — just through the
## Slab/Voxel container so every level is independently dirty-tracked
## (unlike a wall block, and unlike the floor's fixed-bedrock levels).
func render_slab_solid(slab: Slab) -> void:
	if slab.voxels.is_empty():
		return
	if slab.level < 0:
		_ensure_negative_voxel_layer(slab.level)
	else:
		_ensure_voxel_layers(slab.level + 1)

	# ROOF-BAKE-01/02c: ceiling slabs try the flat baked lookup (dedicated
	# roof pages keyed by STRUCTURE-LOCAL offset = grid_pos − texture_anchor,
	# carried on the Slab so re-renders need no builder context); floor/
	# interior solid slabs keep the generic path. Misses fall back to the
	# material atlas inside _set_voxel_cell, so this is safe with bake
	# disabled or combo unresolved.
	var flat_baked: bool = slab.role == Slab.Role.CEILING
	for voxel in slab.voxels:
		_set_voxel_cell(voxel.grid_pos, voxel.level, slab.material,
				null, voxel.grid_pos - slab.texture_anchor, 0, flat_baked)


## DESTRUCTION D13/D18 — render one FIXED floor level for one GU: no `Slab`,
## no `Voxel`, no dirty-tracking at all. D13's 7 non-destructible levels
## beneath the one real (Slab) destructible top are structurally incapable of
## ever being marked dirty precisely because they never go through Voxel in
## the first place — this function places cells directly, the same way
## render_block() does for wall material, just per-LEVEL (not per-storey) and
## through the earth-variant hash instead of one fixed material, so a fixed
## level reads as the same material family as the destructible level above it.
##
## D18: called once per level, on demand — never loops over a range itself.
## Whatever eventually decides "digging exposed level -4" (Part 3, not built
## yet) calls this once for that one level; nothing here assumes or builds a
## contiguous stack.
## FLOOR-DEPTH-01: levels down to FLOOR_ZONE_PAINT_MIN_LEVEL wear the floor
## zone's own baked texture instead of the earth hash, when the GU has a zone
## and the bake is on (same two conditions render_slab() applies to the
## destructible planes — a ground_* material is absent from MATERIALS, so
## letting one through with the bake off would resolve to MATERIALS[0] and paint
## the crater bottom flat concrete gray).
func render_fixed_earth_level(gu_cell: Vector2i, level: int) -> void:
	if level < 0:
		_ensure_negative_voxel_layer(level)
	else:
		_ensure_voxel_layers(level + 1)

	if _bake_config == null:
		_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var zone: Dictionary = _floor_zone_by_gu.get(gu_cell, {})
	var paint_zone: bool = (not zone.is_empty()) \
			and level >= GeometryCoords.FLOOR_ZONE_PAINT_MIN_LEVEL \
			and _bake_config != null and _bake_config.enabled

	if paint_zone:
		var zone_material: String = String(zone["material"])
		var zone_anchor: Vector2i = zone["anchor"]
		for voxel_pos in GeometryCoords.gu_voxels(gu_cell):
			_set_voxel_cell(voxel_pos, level, zone_material,
					null, voxel_pos - zone_anchor, 0, true)
		return

	for voxel_pos in GeometryCoords.gu_voxels(gu_cell):
		var variant_index: int = EarthVariantSelector.variant_for(voxel_pos, level)
		_set_voxel_cell(voxel_pos, level, "earth_%d" % variant_index)


## FLOOR-DEPTH-01 — publish one GU's declared floor zone, so the FIXED levels
## beneath the Slab planes can wear the same baked texture. material is the zone
## material ("earth" clears the entry — an unzoned GU must fall back to the
## earth hash, never to a stale zone from a previous map).
func set_floor_zone(gu_cell: Vector2i, material: String, anchor: Vector2i) -> void:
	if material == "" or material == "earth":
		_floor_zone_by_gu.erase(gu_cell)
		return
	_floor_zone_by_gu[gu_cell] = {"material": material, "anchor": anchor}


## FLOOR-DEPTH-01 — drop every published floor zone. Called by room_builder at the
## top of a build: a map switch (or a perspective rotation, which re-derives every
## GU's zone in the new frame) must not inherit the previous layout's table.
func clear_floor_zones() -> void:
	_floor_zone_by_gu.clear()


## Render a VoxelProp's footprint as a full solid fill (v1: whole-storey granularity only;
## sub-storey/partial-layer rendering is deferred to the destruction phase — see PROP-01 Item 0-A).
func render_prop(gu_cell: Vector2i, start_storey: int, prop_def) -> void:
	var material_name: String = prop_def.material_zones.get("default", "concrete")
	for footprint_offset in prop_def.footprint_gus:
		render_block(gu_cell + footprint_offset, start_storey, prop_def.storeys, material_name)


## Clear all layers and voxels
func clear() -> void:
	for layer in _voxel_layers:
		layer.clear()
	for layer in _negative_voxel_layers.values():
		layer.clear()
	## OCC-02: the cells those records point at no longer exist. Keeping them would make
	## the next restore write stale alternatives into freshly-rebuilt geometry — the
	## rotation path (clear() + render()) goes through here every time.
	_ghosted_cells.clear()
	## VL-03: same reasoning — the GU index would point at cells this cleared
	## tilemap no longer has. apply_light_field() rebuilds it from scratch on the
	## next full pass, which always follows clear()+render() in the rebuild flow.
	_placed_by_gu.clear()


## Remove every baked atlas source registered by the PREVIOUS bake pass, before the
## current one registers its own. Must run before register_baked_atlas_page() is called
## for a fresh pass — never from clear(), which runs AFTER _bake_textures() has already
## registered this pass's new sources (removing them there would delete what was just
## built). Without this, every view rotation left the prior rotation's pages (and their
## minted ghost alternatives) orphaned in _tileset forever: source_count grew without
## bound and every rotation re-triggered a full ghost-mint pass on top of the leak.
## The four MATERIALS sources (ids assigned once in _build_voxel_tileset()) are untouched.
func prune_baked_sources() -> void:
	for source_id in _baked_source_ids:
		if _tileset.has_source(source_id):
			_tileset.remove_source(source_id)
	_baked_source_ids.clear()
	## VL-03-PERF: those source ids are gone; their lazy-mint records must not
	## survive to alias a freshly-registered source at the same id next pass.
	_minted_light_alts.clear()
	## D33 Part 1: damage composite pages were just removed above (their ids
	## live in _baked_source_ids too — see register_damage_composite_page()).
	## The cache's own bookkeeping (Dictionary entries, in-memory Image pages)
	## is a separate object the loop above never touches; reset it here so the
	## next build_from_layout() pass starts genuinely empty instead of
	## resolving stale (source_id, atlas_coords) pairs that no longer exist.
	if _damage_composite_cache != null:
		_damage_composite_cache.reset()


func _to_string() -> String:
	return "VoxelRenderer{layers=%d, negative_layers=%d, tileset=%s}" % [
		_voxel_layers.size(), _negative_voxel_layers.size(), "valid" if _tileset else "null"
	]
