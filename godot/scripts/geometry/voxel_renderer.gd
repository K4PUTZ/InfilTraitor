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
## D-ARCH-01: Variant registry for pre-baked damage voxels
const VoxelVariantRegistryClass = preload("res://godot/scripts/systems/voxel_variant_registry.gd")
## D19/D20 (EXPLOSION_REBUILD_MASTER_PLAN): SurfaceClass enum for resolve_flat().
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")

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
##
## D33 Part 4c (2026-08-03): every impact-mark pseudo-material name (D22's
## bare "_dented"/"_cracked", D23's "_blast_" infix, D25's carved-side
## suffixes, D32's decal-family side+variant names) USED to live here too —
## first as a hand-typed literal tail, later appended by _static_init() —
## each backed by its own pre-composited PNG in composites/ and its own
## boot-time TileSetAtlasSource. That whole mechanism is gone: every one of
## those names is now resolved PURELY BY STRING at render time in
## _set_voxel_cell() (_full_voxel_decal_plan/_half_voxel_decal_plan/
## _ceiling_carve_plan/_floor_sunk_decal_plan/_generic_flat_mark_plan below),
## composited live onto either a baked atom (Parts 3a-3d) or the flat atom
## right here in MATERIALS (Part 4b) — never pre-registered, never loaded
## from a per-name file. BASE_MATERIALS is real base materials ONLY now.
##
## D35/E-EARTH-01 (2026-08-08): bare `"earth"` joined the list — earth is a
## buildable material now (walls, blocks, roofs), and without an entry here a
## bake-OFF earth wall resolved `MATERIALS.find("earth") == -1` and fell to
## MATERIALS[0], painting itself flat concrete. That matters: bake-OFF is the
## SHIPPED canon (`BakeConfig.enabled` defaults false for release), so this is
## the release path, not a dev-only fallback. Distinct from the
## `earth_0..earth_7` entries above, which are EarthVariantSelector's per-cell
## surface palette for the UNZONED ground and stay exactly as they were.
## APPENDED, never inserted: MATERIALS[0] is the last-resort fallback and every
## other index is looked up by name, so order changes are gratuitous risk.
## MAT-REG-01 (2026-08-21): the four newcomers are APPENDED, obeying the rule
## the comment above already states — MATERIALS[0] is the last-resort fallback
## and every other index is looked up by name, so an insertion is gratuitous
## risk. Registration here is what makes the material-agnostic GENERIC MARK path
## reachable for them (`_resolve_flat_material_atom()` resolves through
## MATERIALS.find()), which is why a material with no authored decal family
## still takes a visible bullet mark.
const BASE_MATERIALS: Array[String] = [
	"concrete", "metal", "stone", "wood", "glass",
	"earth_0", "earth_1", "earth_2", "earth_3", "earth_4", "earth_5", "earth_6", "earth_7",
	"earth",
	"brick", "cardboard", "fabric", "plywood",
]

## D32 — the four wall materials the Director authors decals for. Glass is
## absent by D22 (DESTROYED-only) and brick is deferred; both were the
## Director's explicit call on 2026-08-02 ("vidro e tijolo deixa pra depois").
## M2c (2026-08-21): `brick` joins, its nine decals delivered and measured. The
## comment this replaced said "glass and brick deferred" — glass still is, and by
## a different rule: D22 gives it no marked tier at all, so it is not waiting on
## art (MATERIALS_MASTER_PLAN M4b).
const IMPACT_DECAL_MATERIALS: Array[String] = ["concrete", "metal", "stone", "wood", "brick"]
## Fixed at three by the Director, same session. Must match `variant_count` in
## voxels/manifest.json — asserted by voxel_decal_selftest.gd rather than
## trusted, because a mismatch fails as a silent MATERIALS.find() miss.
const IMPACT_DECAL_VARIANTS: int = 3
## D33 Part 4a — must match GENERIC_MARK_VARIANTS in generate_voxel.py.
## Independent of IMPACT_DECAL_VARIANTS above on purpose: the generic marks
## are material-agnostic, so nothing forces the two counts to match, they
## just both happen to be 3 today.
const GENERIC_MARK_VARIANT_COUNT: int = 3
## D3/§3.3 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06) — how many pre-baked
## substrate crops the atom-bake model offers per (material, damage name).
## Independent of IMPACT_DECAL_VARIANTS on purpose (same reasoning as
## GENERIC_MARK_VARIANT_COUNT above): a decal-art axis and a substrate-crop
## axis have no reason to share a count, they just both happen to be 3 today.
const DAMAGE_SUBSTRATE_VARIANTS: int = 3
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
## D32.6 — only rigid MINERAL materials fracture; metal and wood dent instead.
## Brick is one (crack_factor 0.12), so it cracks like concrete and stone.
const IMPACT_CRACK_MATERIALS: Array[String] = ["concrete", "stone", "brick"]

## D33 Part 4c: used to be built by _static_init() appending
## impact_decal_names()'s ~97 generated names on top of BASE_MATERIALS —
## both gone now (see BASE_MATERIALS' own comment above). MATERIALS is just
## the base materials themselves; kept as a mutable static var (not a const
## alias of BASE_MATERIALS) purely so existing MATERIALS.find()/.has() call
## sites elsewhere in this file don't need to change.
static var MATERIALS: Array[String] = []


static func _static_init() -> void:
	MATERIALS = BASE_MATERIALS.duplicate()

## Voxel asset path template
## ASSET-LAYOUT-01 (Director, 2026-08-02) — the voxel source tree is split by
## WHAT THE PIPELINE DOES WITH A FILE, not by what it depicts:
##
##   materials/   one whole voxel per material            INPUT  (never overwritten)
##   halves/      the four carved substrates per material INPUT  (generated if absent)
##   decals/      the marks + broken faces + template     INPUT  (never overwritten)
##   composites/  material|half x decal                   RETIRED (D33 Part 4c, 2026-08-03)
##
## composites/ was a pure OUTPUT derivative — always rebuilt, deletable at
## any time — which is exactly what made D33 (moving compositing to load
## time) a folder deletion instead of a 126-file audit once every consumer
## moved off it (Parts 3a-3d for baked cells, Part 4b for flat/generic ones).
## Full layout: ASSETS/ISOMETRIC/source_assets/voxels/README.md.
const VOXEL_ASSET_ROOT: String = "res://ASSETS/ISOMETRIC/source_assets/voxels/"
## ASSET_TREE_REFORM (2026-08-21): one folder per material. The material id
## appears TWICE — once as the folder, once in the filename — because the
## Director's ruling is that only the folders move: a file still says what it is
## when it is out of its directory, which is the cheap defence against art being
## hand-dropped into the wrong place (a wrong atom fails silently).
const MATERIAL_ASSET_ROOT: String = "res://ASSETS/materials/"
const VOXEL_ASSET_TEMPLATE: String = MATERIAL_ASSET_ROOT + "%s/voxel_%s.png"

## D33 Part 3a — the RAW decal art (family, material, variant), same folder
## and filename shape generate_voxel.py's build_decal_family() authors into
## (DECAL_NAME = "decal_%s_%s_%d.png"). Composited at runtime onto the baked
## atom instead of loading a pre-composited voxel_%s.png from composites/ —
## _full_voxel_decal_plan()/_composite_full_voxel_decal() below are the seam.
## ASSET_TREE_REFORM (2026-08-21): a material's decals live with the rest of its
## art. Args are (material folder, family, material, variant) — the material
## appears twice for the Director's ratified reason: only the FOLDERS moved, so
## a decal still names itself when it is out of its directory.
const DECAL_NAME_TEMPLATE: String = MATERIAL_ASSET_ROOT + "%s/decals/decal_%s_%s_%d.png"
## D33 Part 4a — the material-agnostic VECTOR mark decals (kind, variant),
## same folder generate_voxel.py's build_decal_family() writes
## GENERIC_MARK_KINDS into. Loaded by _load_decal_image() exactly like the
## photographic family above — same cache, same "missing file -> {} -> fall
## through" contract — only the template and the kind space differ.
## The material-agnostic family (D25) belongs to no material, so it gets a folder
## that cannot collide with one — the leading underscore is deliberate.
const GENERIC_MARK_TEMPLATE: String = MATERIAL_ASSET_ROOT + "_generic/decals/decal_generic_%s_%d.png"
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
## _decal_material() returning "" (base_material outside the decal family, or
## no resolvable carved_side) falls back to the pre-D32 name instead. D33 Part
## 4c retired the days when an unrecognised name could reach
## _set_voxel_cell()'s last-resort MATERIALS.find() and repaint the voxel flat
## concrete (the D26 failure this comment used to warn about): every name
## either function can produce is now composited live by one of the plan
## parsers below, baked or generic.
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
## or "" when base_material/damage_state/carved_side don't form a real
## combination at all (e.g. DENTED with no resolvable carved_side — nothing to
## render a decal ON).
##
## D33 Part 4c (2026-08-03): used to also return "" whenever `composed` named a
## corner of the matrix composites/ never generated a file for (checked via
## MATERIALS.has(composed) — MATERIALS held every valid decal-family name back
## when each one needed its own boot-time composites/-backed TileSetAtlasSource).
## That check is gone along with composites/ itself: every name this function
## can compose is now ALWAYS renderable, either via the baked path (Parts
## 3a-3d, when a baked atom is available) or the generic vector-mark fallback
## (Part 4b, always available) — verified exhaustively by
## voxel_decal_selftest.gd's own asset check and generic_mark_seam_selftest.gd.
## A bullet only ever strikes a LATERAL face (D32.4 — "a BULLET marks exactly
## the ONE lateral face it struck, never a top face"); TOP/BOTTOM are
## structurally unreachable for a firearm in real gameplay
## (BlastCalculator.carved_side_for() never returns them for a shooter), but
## this function validates it explicitly rather than relying on that upstream
## guarantee — D33 Part 4c removed the MATERIALS.has(composed) check that used
## to catch a wrongly-constructed "..._bullet_..._top_N"/"..._bottom_N" name
## as a side effect (composites/ simply never had that file), so the
## restriction has to be real here now.
static func _is_lateral_side(carved_side: int) -> bool:
	return carved_side == Voxel.CarvedSide.LEFT or carved_side == Voxel.CarvedSide.RIGHT


static func _decal_material(base_material: String, damage_state: int,
		blast_sourced: bool, carved_side: int, variant: int) -> String:
	if not IMPACT_DECAL_MATERIALS.has(base_material) \
			and base_material != IMPACT_FLOOR_MATERIAL:
		return ""
	var v: int = posmod(variant, IMPACT_DECAL_VARIANTS)
	var composed := ""
	match damage_state:
		Voxel.DamageState.CRACKED:
			## A blast cracks the whole voxel — one name, no side (D32.3), and
			## only for materials D32.6 lets crack at all (metal/wood never do —
			## explicit here now, see _is_lateral_side()'s own comment for why
			## this can no longer lean on the retired MATERIALS.has() check). A
			## bullet cracks the one lateral face it hit, so a bullet with no
			## resolvable lateral side has nothing to render and falls through
			## to the legacy mark.
			if blast_sourced:
				if IMPACT_CRACK_MATERIALS.has(base_material):
					composed = "%s_blast_cracked_all_%d" % [base_material, v]
			elif _is_lateral_side(carved_side):
				composed = "%s_bullet_cracked%s_%d" % [
					base_material, String(_CARVED_SIDE_SUFFIX[carved_side]), v]
		Voxel.DamageState.DENTED:
			if not _CARVED_SIDE_SUFFIX.has(carved_side):
				return ""
			var side := String(_CARVED_SIDE_SUFFIX[carved_side])
			if blast_sourced:
				## A blast can dent any of the four sides (floor TOP, ceiling
				## BOTTOM, wall LEFT/RIGHT) — unlike a bullet, never restricted
				## to lateral. The ceiling carve is silhouette-only and
				## therefore variantless.
				composed = "%s_blast_dented_bottom" % base_material \
					if carved_side == Voxel.CarvedSide.BOTTOM \
					else "%s_blast_dented%s_%d" % [base_material, side, v]
			elif _is_lateral_side(carved_side):
				composed = "%s_bullet_dented%s_%d" % [base_material, side, v]
		_:
			return ""
	return composed


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


## D33 Part 3c — recognizes the floor-sunk DENTED case.
##
## D34/E-SEAM-02: this used to key on the literal "earth_blast_dented_top_"
## prefix, because floor_damage_material() renamed every floor dent to the
## shared earth family. Now that it names by the REAL material, this parser
## extracts `base_material` like every other one in this file — over
## IMPACT_DECAL_MATERIALS *plus* IMPACT_FLOOR_MATERIAL, since "earth" is still
## the fallback family for a material with no decal art of its own.
##
## Still mutually exclusive with its neighbours by construction, which the
## dispatch in _set_voxel_cell() relies on: _half_voxel_decal_plan matches only
## "_left_"/"_right_", _ceiling_carve_plan only the exact "_blast_dented_bottom"
## (no side, no variant), and _generic_flat_mark_plan only the exact
## "_blast_dented" — none of which a "..._blast_dented_top_N" name can satisfy.
##
## `zone_material` is still threaded separately through _set_voxel_cell(): the
## name now says which DECAL family to paste, but resolve_flat() needs the real
## zoned material to find the right baked page, and those two differ whenever
## the fallback fires (a grass floor dents with earth art on a grass substrate).
static func _floor_sunk_decal_plan(material_name: String) -> Dictionary:
	var families: Array[String] = IMPACT_DECAL_MATERIALS.duplicate()
	families.append(IMPACT_FLOOR_MATERIAL)
	for base in families:
		var prefix := "%s_blast_dented_top_" % base
		if not material_name.begins_with(prefix):
			continue
		var v := material_name.substr(prefix.length())
		if not v.is_valid_int():
			continue
		return {"base_material": base, "decal_family": "dent", "variant": v.to_int()}
	return {}


## D33 Part 3d — recognizes the ceiling DENTED case: no decal, no variant at
## all (build_decal_family()'s own reasoning: "an isometric camera never
## sees a voxel's underside, so there is no exposed surface for a decal to
## land on" — just a silhouette carve). Unlike the floor case, the REAL
## material IS recoverable directly from the name here: there is no shared
## substitute the way floor's "earth" is one — "concrete_blast_dented_bottom"
## already says "concrete", so no separate zone_material threading is needed.
static func _ceiling_carve_plan(material_name: String) -> Dictionary:
	for base in IMPACT_DECAL_MATERIALS:
		if material_name == "%s_blast_dented_bottom" % base:
			return {"base_material": base}
	return {}


## D33 Part 4b — recognizes the OLD, pre-decal-family full-voxel names
## (D22/D23: "<material>_dented", "_cracked", "_blast_dented", "_blast_cracked",
## no side, no variant in the name at all) that damage_variant_material() still
## falls back to whenever _decal_material() returns "" — a bullet/blast with no
## resolvable carved_side, or a base_material outside IMPACT_DECAL_MATERIALS.
## Every one of these is a FULL-VOXEL top-face mark (D22's original
## generate_impact_mark()/generate_blast_mark() only ever drew at the top
## diamond's centre); "dented" is the only tier that needs its own alpha-cut
## variant (see _composite_generic_flat_mark()'s doc comment), everything
## else is exact-string-matched so there is no ordering hazard between e.g.
## "_dented" and "_blast_dented".
static func _generic_flat_mark_plan(material_name: String) -> Dictionary:
	for base in IMPACT_DECAL_MATERIALS:
		if material_name == "%s_blast_dented" % base:
			return {"base_material": base, "mark_family": "blast", "dented": true}
		elif material_name == "%s_blast_cracked" % base:
			return {"base_material": base, "mark_family": "blast", "dented": false}
		elif material_name == "%s_dented" % base:
			return {"base_material": base, "mark_family": "bullet", "dented": true}
		elif material_name == "%s_cracked" % base:
			return {"base_material": base, "mark_family": "bullet", "dented": false}
	return {}


## FLOOR-DENT-01 (2026-08-01) — which material a damaged FLOOR voxel renders as.
## A floor has exactly ONE damage shape: the carved-TOP pockmark (a floor is
## only ever eaten from ABOVE — the mirror of a ceiling only ever carving
## BOTTOM).
##
## D34/E-SEAM-02 (Director, 2026-08-08) — `base_material` is NEW, and it
## reverses D26. Every floor dent used to be renamed to the shared "earth"
## family unconditionally, so a concrete floor wore an earth pockmark while
## `decal_dent_concrete_*` sat on disk being used by concrete WALLS. That was
## D25's "one generic grey fracture serves every material" rule, written when
## the floor was only ever earth; the Director's unification ("produzam os
## decals de cada tipo corretamente") retires it for materials that have their
## own art. The naming now matches the CEILING case, which already carried its
## real material ("concrete_blast_dented_bottom") and needed no substitution.
##
## `IMPACT_FLOOR_MATERIAL` survives as the FALLBACK, not the rule: a material
## outside IMPACT_DECAL_MATERIALS has no `decal_dent_<m>_*` family on disk, and
## D25's shared fracture is exactly right for it. `earth` itself lands here by
## that path, so an unzoned floor is unchanged.
##
## Returns "" when there is no floor damage variant (INTACT, or a tier with no
## floor asset), meaning "keep whatever material you were going to use". D33
## Part 4c: no longer separately checks MATERIALS.has(composed) — see
## _decal_material()'s own comment for why that check is retired entirely.
static func floor_damage_material(base_material: String, damage_state: int,
		is_blast: bool, carved_side: int, variant: int = 0) -> String:
	if damage_state == Voxel.DamageState.INTACT or damage_state == Voxel.DamageState.DESTROYED:
		return ""
	var family: String = base_material if IMPACT_DECAL_MATERIALS.has(base_material) \
			else IMPACT_FLOOR_MATERIAL
	return damage_variant_material(family, damage_state, is_blast, carved_side, variant)


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
## gentle, and why a freshly exposed crater floor is given
## BlastCalculator.EXPOSED_FLOOR_SOOT_RING soot on reveal — that is what
## actually governs whether its layers read apart.
## Still a `var` (Rule 1 — stats are never `const`); the initialiser is a function
## only so the diagnostic below can take effect BEFORE the first mint or the first
## layer material, which is the one thing a later assignment could not do.
var bucket_luminance: Array[float] = _initial_bucket_luminance()


static func _initial_bucket_luminance() -> Array[float]:
	var ladder: Array[float] = [
		0.12, 0.20, 0.33, 0.40, 0.47, 0.54, 0.61, 0.69, 0.77, 0.85, 0.92, 1.00,
	]
	if OS.get_environment("INFILTRAITOR_FLAT_LIGHT") == "1":
		for i in range(ladder.size()):
			ladder[i] = 1.0
		print("[P3-DIAG] INFILTRAITOR_FLAT_LIGHT — bucket_luminance flattened to 1.00 on BOTH paths")
	return ladder

## PERF-P3 DIAGNOSTIC — `INFILTRAITOR_FLAT_LIGHT=1` flattens the ladder to all
## 1.00, for BOTH delivery paths at once: `_ensure_light_alt()` bakes it into the
## modulate and `_get_layer_material()` pushes the same array to the shader.
##
## It is a DISCRIMINATOR, not a feature. With every bucket worth the same, the
## VALUE a fragment ends up with can no longer depend on WHICH bucket it read —
## so if P3-on and P3-off still disagree under it, the difference is structural
## and is not the cell lookup; and if they agree, the lookup is the whole story.

## PERF-P3 — THE LIGHT BUCKET LEAVES THE ALTERNATIVE ID.
##
## With this on, `encode_light_alt()` returns the FLIP and nothing else, the
## bucket is written to the cell plane's G channel, and `_ensure_light_alt()`
## early-returns on every id it is handed — so a light change mints NOTHING and
## triggers no TileSet rebuild. §8.15 measured that rebuild at ~240 ms per
## committing frame of a fire, ~3.1 s of a ~6.3 s burn, blind to how many
## alternatives the frame mints.
##
## ⚠️ **DEFAULT OFF — P3 DOES NOT RENDER CORRECTLY YET (§8.19).** Opt IN with
## `INFILTRAITOR_P3=1`. The plumbing below is complete and its DATA is verified
## end to end; what is not verified is the picture.
##
## Measured 2026-08-23, `--fixed-fps 60`, PLAYGROUND, against a control proven at
## **0 differing pixels** (P3 off is bit-identical to the committed build):
##
##   P3 on vs shipped:  165 754 px differ (17.985%), max channel delta 105
##
## Every delta is a multiple of 3 (FACE-READ-03's residue snap), the differences
## sit on WALL FACADES rather than the floor, and the on/off RATIOS are ratios of
## `bucket_luminance` entries — 2.12 = 0.85/0.40, 2.50 = 1.00/0.40, 0.55 =
## 0.47/0.85. **So the two paths are applying DIFFERENT BUCKETS to the same
## pixel**, which makes this a cell-recovery mismatch and not an arithmetic one.
##
## The switch stays because it is the instrument: it puts both sides in ONE binary
## and one map, which is a stricter form of what §5.5 asks for than stashing the
## diff.
## §12.13 — DEFAULT ON since 2026-08-26. Opt OUT with `INFILTRAITOR_P3=0`.
##
## It shipped gated OFF while §3.3's floor residual was open. §12.9 closed it: the
## cell recovery reads 100.000% on every level, two reconstruction-free
## instruments agree, and the picture differs from the alternative path by 415 px
## at max channel delta 3 — one FACE-READ-03 residue step, against a 0-px control.
##
## The opt-out is kept rather than deleted: it is what puts both sides of the A/B
## in ONE binary and one map, which §5.5 argues is stricter than stashing the
## change and re-running, and every future light-path measurement wants it.
static var P3_CELL_BUCKET: bool = OS.get_environment("INFILTRAITOR_P3") != "0"


## ABLATION — `INFILTRAITOR_NO_LIGHT=1` REMOVES THE LIGHT SYSTEM FROM THE RUN.
##
## Director, 2026-08-26: *"eu queria testar desligando essas duas features por
## default ... e rodando o game só com materiais básicos e voxels, sem
## iluminação"*. A DISCRIMINATOR, not a feature, and not a look mode — the same
## standing of instrument as `INFILTRAITOR_FLAT_LIGHT` and `INFILTRAITOR_P3`
## above, and the exact light-side counterpart of `INFILTRAITOR_FAST_BOOT`
## (which does this for the bake).
##
## `INFILTRAITOR_FLAT_LIGHT` is NOT this. It flattens `bucket_luminance` to 1.00
## and every cell still derives its bucket, still writes both planes, still mints
## its alternative and still pays the map-wide walk — it changes the PICTURE and
## not one microsecond of the work. This removes the work:
##
##   · `Room._repaint_voxel_light_buckets()` and its scoped sibling return at the
##     top, so `build_occupancy()`, `_build_soot_snapshot()` and
##     `VoxelLightField.build()` never run;
##   · all three `apply_light_field*()` entries return, so the walk over every
##     placed cell — 609 ms of the 646 ms measured in §10.1 — never happens;
##   · `_ensure_light_alt()` returns, so no light alternative is ever minted and
##     the TileSet rebuild that §8.15 priced at ~240 ms per committing frame has
##     nothing to rebuild for.
##
## Every voxel therefore sits at alternative 0: its base atom, unlit, unsooted.
## The board is WRONG on purpose. Nothing about this is shippable and no gate,
## census or pixel diff taken under it means anything about the real build.
static var LIGHT_DISABLED: bool = OS.get_environment("INFILTRAITOR_NO_LIGHT") == "1"


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
## Adding per-FACE LIGHT later (the other half of VOXEL_LIGHT_MASTER_PLAN's open
## item) would multiply the bucket axis by 12×12 and BLOW that ceiling; it would
## have to reuse this same soot code space rather than add a third axis.
## Recorded here because the id space is the real constraint on that feature,
## and nothing else in the codebase says so.
##
## PERF-02 B3-2 (2026-08-04): THE CEILING IS NOW THE BINDING CONSTRAINT on how
## many soot tones exist, and it is why the Director's request for five was
## built as four. Measured against the real engine constant, per face-code
## count: 64 codes → max id 1535 · 125 → 2999 · 170 → 4079 · **216 → 5183,
## over**. Five tones per face need 6³ = 216. Four need 5³ = 125. The alpha
## carrier the code rides in is NOT the limit — a 216-level carrier was probed
## on a real capture and decoded pixel-identically — so anyone revisiting this
## should target the flip axis (it consumes half the space by adding
## SOOT_ALT_FLIP_BASE, where Godot's own TRANSFORM_FLIP_H bit could carry it
## instead), not the alpha packing.
##
## The code is base-5 per visible face — `top * 25 + se * 5 + sw`, ring 0..3
## with 4 = clean — so the all-clean code is 124 and maps to modulate alpha
## 1.0, i.e. exactly the tile every untouched voxel already carries.
## VoxelLightField.encode_face_soot()/decode_face_soot() are its only readers.
const FACE_SOOT_CODE_CLEAN: int = 124
const FACE_SOOT_CODE_COUNT: int = 125
const SOOT_ALT_FLIP_BASE: int = LIGHT_BUCKET_COUNT * FACE_SOOT_CODE_COUNT


## (bucket, per-face soot code, flipped) → alternative id. Single source of truth.
## PERF-P2b — the alternative id carries BUCKET AND FLIP ONLY.
##
## `soot_code` is still a parameter and is still folded into the layout, but the
## only value any caller passes is FACE_SOOT_CODE_CLEAN: the per-face scorch now
## lives in the per-level soot plane (`_write_cell_soot()`), sampled by
## `voxel_face_shading.gdshader`. The layout is UNCHANGED on purpose — SOOT_ALT_
## FLIP_BASE, `decode_light_bucket()` and `decode_light_flipped()` all keep
## working bit-for-bit, so nothing downstream had to learn a new id.
##
## What changed is the SIZE of the space actually used: 12 buckets x 125 soot
## codes x 2 flips = up to 3 000 alternatives per tile becomes 12 x 2 = 24.
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
##
## PERF-P3: under `P3_CELL_BUCKET` the bucket does not travel here at all — the
## id carries the FLIP and nothing else. Both returned values (0 and
## TRANSFORM_FLIP_H) are NATIVE Godot tiles that `_ensure_light_alt()` already
## refuses to mint, so minting goes to zero without that function changing.
##
## ⚠️ Callers must write the bucket to the plane BEFORE their `alt_id == prev_alt`
## comparison. Once the bucket leaves the id, a light-only change leaves the id
## EQUAL and the caller `continue`s — which is correct, and is exactly why the
## write cannot sit after it. PERF-P2 hit this first with soot and the comment at
## each site says so.
static func encode_light_alt(bucket: int, flipped: bool) -> int:
	if P3_CELL_BUCKET:
		return alt_for_flip(flipped)
	return encode_voxel_alt(bucket, FACE_SOOT_CODE_CLEAN, flipped)


## The flip, as an alternative id, with no visual state attached.
static func alt_for_flip(flipped: bool) -> int:
	return TileSetAtlasSource.TRANSFORM_FLIP_H if flipped else 0


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

## LEVEL-RENUMBER stage A — ONE store, keyed by level, sparse.
##
## This replaces `_voxel_layers` (an Array of positive levels) and
## `_negative_voxel_layers` (a Dictionary of negative ones). D17's note explained
## the split honestly: *"GDScript's `array[-1]` means 'last element', not 'grow
## downward', so unifying storage would mean every one of _voxel_layers' many
## existing 0-indexed callers would need to learn to ignore negative keys."*
##
## That reasoning was right, and the Director's renumber is what retires it —
## with no level below zero there is nothing for an index to collide with. Stage A
## unifies the store while the numbering is UNCHANGED, so the census can prove the
## refactor alone changes nothing; stage B then moves the numbers.
##
## What the split cost was not correctness but repetition: every map-wide walk in
## this file and in `room.gd` came in pairs, one loop for each store, and a walk
## that forgot its second half was a silent bug with no symptom until someone
## looked at the right voxel.
var _layers: Dictionary = {}               ## level:int -> TileMapLayer, sparse

## GLASS G1 (GLASS_MASTER_PLAN §3.2) — glass cells do NOT live in `_layers`. They
## render on their own MUL + ADD blend sublayers, one pair per level that actually
## contains glass, drawn immediately above that level's opaque layer. Built lazily
## by `_ensure_glass_sublayers()`; a map with no glass builds none. Rule 8 holds —
## the voxels still arrive via `set_cell()`, only the layer's compositing changes.
var _glass_layers: Dictionary = {}         ## level:int -> TileMapLayer (one per glass level)
## GLASS G1 — the rasterising container (Director's "container rasterizado"): a
## BackBufferCopy snapshots the scene just before the glass draws, and every glass
## fragment reads THAT snapshot and applies the tint once (glass_pane.gdshader).
## Overlapping voxel faces — the top row carries a dim top sliver, the front
## column a dim side sliver — all read the same snapshot, so there is no
## double-tint. Lazy.
var _glass_backbuffer: BackBufferCopy = null
var _glass_composite_z: int = -9999        ## z for the backbuffer + every glass layer
## GLASS G-D18b (Director 2026-08-31: *"no caso do vidro ser transparente, acho
## que podemos deixar o agente ser renderizado atrás e ficar parcialmente coberto
## pelo vidro"*). OCC-03 bumps the agent one z above the tallest opaque layer so a
## wall never HIDES him — but glass hides nothing, so the agent should read as
## BEHIND a pane he stands behind, faintly tinted, exactly like a guard already
## does (`enemies_root.z_index = 10`, never bumped). room.gd calls `set_glass_over_z()`
## with `agent.z_index + 1` so the whole glass composite (backbuffer + every pane
## layer) sits just above him.
var _glass_composite_z_floor: int = -9999
## Atlas sources in `_tileset` for the glass pane atoms. GLASS G1 GEOMETRY
## (Director's diagram, 2026-08-31): a glass voxel paints its MAIN face always,
## its TOP face only when nothing (no glass) is above it, and its SIDE face only
## on the frontmost column — the camera-facing end of the pane. Top and side
## render DIM, and that dimness IS the thickness read (no invented strips, no
## ground ledge). Painting only the exposed faces is what kills the "serrilhado"
## — with transparency every hidden face that gets drawn shows through as a
## doubled ghost. The rule generalises by exposure to L-walls and glass cubes.
##
## So four faces × four masks (main / +top / +side / +top+side) = 16 sources.
## `_glass_atom_source[face][mask]`, mask = (want_top << 1) | want_side.
var _glass_atom_source: Dictionary = {}       ## Face int -> { mask:int -> source_id:int }
## Back-compat alias — the SW main-only source id (diagnostics / selftest).
var _glass_frosted_source_id: int = -1
## GLASS G1 GEOMETRY — how far the dim top/side slivers recede into the atom, as
## a fraction of a voxel. A half-thickness pane reads with a thin sliver; tune
## with the capture, not by reasoning.
const GLASS_FACE_SLIVER_FRAC: float = 0.55
## Dimness of the top and side face slivers (rides the atom's RED channel;
## glass_pane.gdshader multiplies by it). Director: *"diminuir o brilho das
## faces de topo e de lateral ... para diferenciar esses planos"*.
const GLASS_DIM_TOP: float = 0.60
const GLASS_DIM_SIDE: float = 0.78
## The five calibration knobs the glass sublayer shaders expose, mirrored here so
## `set_glass_shader_param()` (the blind-strip capture action) can drive them and
## every freshly-built sublayer inherits the current value. Defaults match
## glass_shading.gdshaderinc.
var _glass_shader_params: Dictionary = {
	## Defaults track glass_shading.gdshaderinc — the Director's pick on the
	## parallelogram strip was "painel 005": sheen mode, mul 0.60, add 0.20, blue.
	"glass_mul_strength": 0.60,
	"glass_add_strength": 0.20,
	"glass_add_threshold": 0.55,
	"glass_add_mode": 1.0,
	"glass_tint": Color(0.47, 0.63, 0.90),
}

## LEVEL-RENUMBER — the ground plane: the lowest level that counts as WALL rather
## than floor/bedrock. Stage A keeps it at 0 so the numbering is untouched; stage B
## moves it to GeometryCoords.PLAYABLE_LEVEL and every level with it. Every
## "is this a wall level" test in this file goes through here, so stage B is one
## constant rather than a sweep of sign checks.
var _ground_plane_level: int = GeometryCoords.PLAYABLE_LEVEL


## Every built level, ascending. The single replacement for the paired
## positive-then-negative walks this file used to be full of.
func level_keys() -> Array:
	var out: Array = _layers.keys()
	out.sort()
	return out


## Built levels at or above the ground plane — walls, blocks, props. D18's lazy
## reveal means floor levels are sparse, so this is not "the rest of the array".
func wall_level_keys() -> Array:
	var out: Array = []
	for level in level_keys():
		if level >= _ground_plane_level:
			out.append(level)
	return out


func ground_plane_level() -> int:
	return _ground_plane_level


## LEVEL-RENUMBER — A RENDER LEVEL IS NOT A FACADE SHEET ROW, and conflating them
## is what the renumber exposed.
##
## `BakedTileLookup` indexes a facade page BY LEVEL: level 0 is the sheet's bottom
## row and each level up advances the atlas window, wrapping rows. That axis has
## its own origin — zero — and always did; it only ever coincided with the render
## level because the render level also started at zero.
##
## Measured when it did not: with the ground plane at 80 the lookup read level 80
## as sheet row 16, so the wall's first two levels rendered another storey's
## texture and levels 82 and up fell off the page entirely — **2 112 cells gone,
## silently, with no warning and no script error**, because a resolve that finds
## nothing simply places nothing.
##
## Same class as `bake_compositor.gd`'s `start_level` and `room_builder`'s
## `level_start`/`level_end`: texture space, origin zero, never shifted.
##
## ⚠️ AND THE BAKE SHEET IS NOT THE ONLY AXIS LIKE THIS. Every level-keyed HASH in
## the project has the same property, and invariant **B4 pins them**: the earth
## variant (`EarthVariantSelector.variant_for`) and the generic damage mark
## (`_generic_variant_for`) both multiply the level into an FNV-style mix, so
## feeding them an absolute level would silently repaint the ground with different
## variants. Measured: **52 224 floor cells changed source id** before this was
## applied to them — a board that looks fine and is not the one that was there.
func relative_level(level: int) -> int:
	return level - _ground_plane_level


## The highest built WALL level, as a level number — not a count. Overhead lamps
## anchor to it (VoxelLightField.build()), so it has to be the real level.
func top_wall_level() -> int:
	var walls: Array = wall_level_keys()
	return walls[walls.size() - 1] if not walls.is_empty() else _ground_plane_level

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
var _damage_variant_registry = null  # D-ARCH-01: VoxelVariantRegistry for pre-baked damage variants

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

## PERF-01: source_id (int) -> the FULL baked facade page as a CPU Image,
## read once via Texture2D.get_image() and reused for every voxel that reads
## from the same page. get_image() on a GPU-resident ImageTexture is a
## synchronous GPU->CPU readback — measured at 1738ms of one big blast's
## 1771ms total spent tinting (98%), across 197 calls that were almost
## entirely re-reading the SAME handful of pages voxel by voxel. Safe to
## cache for a page's whole lifetime: register_baked_atlas_page() is the
## only writer of a facade source's `.texture` (ImageTexture.create_from_image(),
## once, at bake time) — unlike DamageCompositeCache's pages, nothing ever
## calls .texture.update() on a facade page afterward, so a snapshot never
## goes stale until the page itself is gone. Reset alongside
## prune_baked_sources() below, same lifecycle as _minted_light_alts and
## _damage_composite_cache — a fresh build_from_layout() pass assigns new
## source_ids, so a cached image at an old id would silently answer for the
## wrong page.
var _baked_source_image_cache: Dictionary = {}

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


## Set damage variant registry (called by room_builder after variants are generated)
## D-ARCH-01: Maps (voxel_pos, material, damage_state, side, variant) → pre-baked source ID
func set_damage_variant_registry(registry) -> void:
	_damage_variant_registry = registry
	if registry != null:
		print("[VOXEL] Damage variant registry set (pre-baked variants available)")
	else:
		print("[VOXEL] Damage variant registry cleared")


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
## (32x36 region), but with no tiles yet; create_damage_composite_tile() below
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
## calls this twice for the same slot, but staying idempotent costs nothing).
## Mirrors register_baked_atlas_page()'s per-tile setup (texture_origin) for
## one coordinate instead of a whole batch.
##
## PERF-02 A1: this used to re-upload the whole page texture too, which is
## why one blast paid 197 uploads of the same 2048x2048 pages (~876ms
## measured). The upload moved to upload_damage_composite_page(), batched per
## page by DamageCompositeCache.flush_dirty_pages(); tile creation stayed here
## because the caller places the cell immediately and cannot wait for a flush.
func create_damage_composite_tile(source_id: int, atlas_coords: Vector2i) -> void:
	var source: TileSetAtlasSource = _tileset.get_source(source_id)
	if source == null:
		push_error("[D33] create_damage_composite_tile: source_id %d not registered" % source_id)
		return
	if source.get_tile_at_coords(atlas_coords) == Vector2i(-1, -1):
		source.create_tile(atlas_coords)
		var tile_data: TileData = source.get_tile_data(atlas_coords, 0)
		if tile_data != null:
			tile_data.texture_origin = GeometryCoords.voxel_texture_origin()


## PERF-02 A1: re-uploads one whole composite page so every blit
## DamageCompositeCache.store() made into it since the last upload becomes
## visible. Called only through DamageCompositeCache.flush_dirty_pages() —
## per touched page, once, instead of per stored atom.
func upload_damage_composite_page(source_id: int, page_image: Image) -> void:
	var source: TileSetAtlasSource = _tileset.get_source(source_id)
	if source == null:
		push_error("[D33] upload_damage_composite_page: source_id %d not registered" % source_id)
		return
	(source.texture as ImageTexture).update(page_image)


## PERF-02 A1: pushes every pending composite blit to the GPU. Every render
## path that can composite a damaged voxel must call this before the frame it
## draws in — an un-uploaded slot renders as transparent, not as stale pixels,
## so a missed flush shows up as a missing voxel rather than a wrong-looking
## one. Cheap and safe to call when nothing is pending (returns 0 without
## touching the GPU).
func flush_damage_composite_pages() -> int:
	if _damage_composite_cache == null:
		return 0
	return _damage_composite_cache.flush_dirty_pages()


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
##
## [D-ARCH-01] This function is FALLBACK-ONLY. Normal damage rendering uses
## apply_damage_voxel_swap() (pre-baked tile lookup). This is only called if
## apply_damage_voxel_swap() fails or when rendering directly to _set_voxel_cell()
## (e.g., test scenarios or unusual map configs). 
## D3/§3 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): `edge == null` is the
## atom-bake caller's signal (DamageVariantBaker) — there is no real wall
## cell to resolve a substrate against, only a chosen synthetic crop of
## `plan["base_material"]`'s own facade sheet. Resolves via resolve_flat()
## instead of the edge-based resolve() in that case (SLICE surface_class,
## matching what walls always use) — confirmed by direct code reading that
## resolve()'s column_in_run derivation requires a REAL, run-registered Edge,
## which a synthetic bake-time call has no reason to fabricate.
## E-CONTRAST-03 (Director, 2026-08-13): `shade_brightness` defaults to 1.0
## (adjust_bcs() no-op, skipped entirely — every pre-existing caller is
## byte-identical). The one caller that passes a real value is
## DamageVariantBaker's CRACKED-blast bake, for the atom D6 registers under
## FLOOR *and* WALL/CEILING from the same composite (see that file's own
## note) — floor-only damage bake was the ask, but a shared atom cannot be
## darkened on one registration and not the others, and the Director's own
## call was that a slightly darker wall CRACKED tile is an acceptable side
## effect, not a second problem to solve.
func _composite_full_voxel_decal(plan: Dictionary, material_name: String, edge,
		slice_face: int, voxel_xy: Vector2i, level: int, grid_pos: Vector2i,
		shade_brightness: float = 1.0) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_tinted_baked_atom(edge, slice_face, voxel_xy, level) \
			if edge != null \
			else _resolve_tinted_baked_atom_flat(plan["base_material"], voxel_xy, BakePolicyClass.SurfaceClass.SLICE)
	if resolved.is_empty():
		return {}

	var decal_path := DECAL_NAME_TEMPLATE % [plan["base_material"],
		plan["decal_family"], plan["base_material"], plan["variant"]]
	var decal_image := _load_decal_image(decal_path)
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(resolved["image"], decal_image, plan["targets"])
	if not is_equal_approx(shade_brightness, 1.0):
		composite.adjust_bcs(shade_brightness, 1.0, 1.0)
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
	return _tint_baked_atom(_baked_lookup.resolve(edge, slice_face, voxel_xy, relative_level(level)))


## D33 Part 3c: the flat/edge-less counterpart — zoned FLOOR materials AND
## ceiling (roof-underside) carves both resolve through
## resolve_flat(zone_material, voxel_xy) (ROOF-BAKE-01/02c's seam), never
## resolve(). `zone_material` must be the REAL ground material (e.g. "grass"),
## not the damage pseudo-name — see _composite_floor_sunk_decal()'s own
## comment for why those are two different strings for a floor.
## D19/D20 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): `surface_class`
## defaults to SLICE (the ceiling caller's correct, unchanged behavior — a
## roof carve reads the wall's own facade); the floor caller passes SLAB.
func _resolve_tinted_baked_atom_flat(zone_material: String, voxel_xy: Vector2i,
		surface_class: int = BakePolicyClass.SurfaceClass.SLICE) -> Dictionary:
	return _tint_baked_atom(_baked_lookup.resolve_flat(zone_material, voxel_xy, surface_class))


## D33 Part 3a/3b/3c shared: extracts and tints a TileLookupResult's atom
## (or {} for a null/miss result) — see the doc comment this replaced on
## _resolve_tinted_baked_atom() for why the tint has to be applied here.
##
## PERF-01: the page-wide Image behind `baked_source.texture` is read via
## _baked_source_image_cache (see that var's own comment for why caching a
## GPU->CPU readback here is safe) instead of calling
## `baked_source.texture.get_image()` fresh on every voxel — that readback,
## not the tint math, was the real cost measured in this function.
func _tint_baked_atom(substrate_result) -> Dictionary:
	if substrate_result == null or substrate_result.source_id_int < 0:
		return {}
	var baked_source: TileSetAtlasSource = _tileset.get_source(substrate_result.source_id_int)
	if baked_source == null:
		return {}

	var region := Rect2i(substrate_result.atlas_coords * Vector2i(32, 36), Vector2i(32, 36))
	var full_img: Image = _baked_source_image_cache.get(substrate_result.source_id_int)
	if full_img == null:
		full_img = baked_source.texture.get_image()
		_baked_source_image_cache[substrate_result.source_id_int] = full_img
	var substrate: Image = full_img.get_region(region)
	var base_tile_data: TileData = baked_source.get_tile_data(substrate_result.atlas_coords, 0)
	var base_modulate: Color = base_tile_data.modulate if base_tile_data != null else Color.WHITE
	substrate = _tint_image_rgb(substrate, base_modulate)

	return {"image": substrate, "alternative_id": substrate_result.alternative_id}


## PERF-01: multiplies `image`'s RGB channels by `modulate` (alpha
## untouched) — the same Color-multiply-and-requantize `_tint_baked_atom()`
## did per-pixel via get_pixel()/set_pixel() before this, measured at
## ~3.4s across one big blast's ~965 tinted atoms (99.8% of
## process_dirty+process_dirty_slabs' time). Operates on the raw byte
## buffer instead — see tint_baked_atom_selftest.gd for the pixel-identity
## proof against the original loop. Mutates and returns `image`.
##
## floori(), not roundi(): Image.set_pixel() on an 8-bit format TRUNCATES
## the float->byte conversion rather than rounding it (measured empirically
## — byte=127, mod=0.5 -> get_pixel/set_pixel round-trips to 63, i.e.
## floor(63.5), not round(63.5)=64). Matching that exactly is the whole
## point: this function exists to be pixel-identical to the loop it
## replaces, not merely close.
static func _tint_image_rgb(image: Image, _modulate: Color) -> Image:
	if _modulate.is_equal_approx(Color.WHITE):
		return image
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	var mr := _modulate.r
	var mg := _modulate.g
	var mb := _modulate.b
	var i := 0
	var n := data.size()
	while i < n:
		## Same divide/multiply/clamp/scale sequence get_pixel()+set_pixel()
		## run per channel (not the shortcut `data[i] * mr`, which is the same
		## real number but not always the same FLOAT after rounding — a
		## modulate > 1.0 needs the clamp to land on the exact same side of an
		## integer boundary the original loop does; see the selftest's
		## "modulate above 1.0" case).
		data[i] = floori(clampf((float(data[i]) / 255.0) * mr, 0.0, 1.0) * 255.0)
		data[i + 1] = floori(clampf((float(data[i + 1]) / 255.0) * mg, 0.0, 1.0) * 255.0)
		data[i + 2] = floori(clampf((float(data[i + 2]) / 255.0) * mb, 0.0, 1.0) * 255.0)
		# data[i + 3] (alpha) left untouched, matching the original loop.
		i += 4
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)
	return image


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
## D3/§3 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): `edge == null` is the
## atom-bake caller's signal, same as _composite_full_voxel_decal() above —
## see that function's doc comment for why resolve_flat() replaces resolve()
## in that case.
func _composite_half_voxel_decal(plan: Dictionary, material_name: String, edge,
		slice_face: int, voxel_xy: Vector2i, level: int, grid_pos: Vector2i) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_tinted_baked_atom(edge, slice_face, voxel_xy, level) \
			if edge != null \
			else _resolve_tinted_baked_atom_flat(plan["base_material"], voxel_xy, BakePolicyClass.SurfaceClass.SLICE)
	if resolved.is_empty():
		return {}

	var cut_fill := _flat_material_side_color(plan["base_material"])
	var half_substrate := HalfVoxelCompositorClass.build_half_voxel_substrate(
		resolved["image"], cut_fill, plan["side"])

	var decal_path := DECAL_NAME_TEMPLATE % [plan["base_material"],
		plan["decal_family"], plan["base_material"], plan["variant"]]
	var decal_image := _load_decal_image(decal_path)
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(half_substrate, decal_image, [plan["target"]])
	var entry := cache.store(key, composite)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = resolved["alternative_id"]
	return entry


## D33 Part 3c — the floor counterpart: builds the sunk substrate
## (HalfVoxelCompositor.build_floor_sunk_substrate() — no cut_fill parameter,
## it samples the resolved atom's own top tone), pastes the "dent" family
## decal onto FACE_SUNK_TOP, caches, returns the usual shape.
##
## D34/E-SEAM-02: the decal family comes from the PLAN now (the real material,
## or "earth" when that material has no art of its own), not from the
## IMPACT_FLOOR_MATERIAL constant unconditionally — a concrete floor gets the
## same `decal_dent_concrete_*` its walls already use.
##
## `zone_material` stays a separate parameter: it is what resolve_flat() needs
## to find the right baked page, and it is NOT always the decal family (a grass
## floor resolves a grass substrate but pastes the earth-family dent).
## E-CONTRAST-03 (Director, 2026-08-13): a real two-blast PLAYGROUND capture
## showed FLOOR DENTED/CRACKED decal atoms reading noticeably brighter than
## their surroundings — a baked-art brightness issue, not the per-cell soot
## pass (which runs after any set_cell(), independent of which tile a cell
## shows — see this file's own header). Floor only, since firearms never
## reach a Slab (WEAPON_MASTER_PLAN's aim model) — there is no shared-tuning
## risk the way a wall atom would have. `shade_brightness` defaults to 1.0
## (adjust_bcs() no-op, skipped), so every pre-existing caller (the live D33
## per-cell fallback included — this function serves both) is unaffected
## unless DamageVariantBaker's floor bake explicitly asks for less.
func _composite_floor_sunk_decal(plan: Dictionary, material_name: String, zone_material: String,
		voxel_xy: Vector2i, level: int, grid_pos: Vector2i,
		shade_brightness: float = 1.0) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_tinted_baked_atom_flat(zone_material, voxel_xy,
			BakePolicyClass.SurfaceClass.SLAB)
	if resolved.is_empty():
		return {}

	var floor_substrate := HalfVoxelCompositorClass.build_floor_sunk_substrate(resolved["image"])

	var decal_path := DECAL_NAME_TEMPLATE % [plan["base_material"],
		plan["decal_family"], plan["base_material"], plan["variant"]]
	var decal_image := _load_decal_image(decal_path)
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(
		floor_substrate, decal_image, [DecalCompositorClass.FACE_SUNK_TOP])
	if not is_equal_approx(shade_brightness, 1.0):
		composite.adjust_bcs(shade_brightness, 1.0, 1.0)
	var entry := cache.store(key, composite)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = resolved["alternative_id"]
	return entry


## D33 Part 3d — carves the baked atom's underside along a deterministic
## jagged profile (HalfVoxelCompositor.carve_ceiling_silhouette() — a direct
## port of generate_dented_voxel()'s "bottom" branch, its FNV-1a hash
## included for byte-for-byte determinism), no decal ever pasted — there is
## nothing to paste onto; the camera never sees this face. Caches, returns
## the usual shape. {} on any miss (no baked atom here), same fall-through
## as everywhere else in this file.
func _composite_ceiling_carve(plan: Dictionary, material_name: String, voxel_xy: Vector2i,
		level: int, grid_pos: Vector2i) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_tinted_baked_atom_flat(plan["base_material"], voxel_xy)
	if resolved.is_empty():
		return {}

	var carved := HalfVoxelCompositorClass.carve_ceiling_silhouette(resolved["image"])
	var entry := cache.store(key, carved)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = resolved["alternative_id"]
	return entry


## D33 Part 4b — the flat (unbaked/generic) counterpart to _tint_baked_atom():
## `base_material`'s own flat atom is already the real colour (BASE_MATERIALS
## carries no per-tile modulate, unlike a baked page), so there is no tint
## step at all here — just hand back the already-boot-loaded image. {} only
## if `base_material` somehow isn't a registered MATERIALS entry (B6: should
## never happen for anything _generic_flat_mark_plan/_half_voxel_decal_plan/
## _floor_sunk_decal_plan/_ceiling_carve_plan hand back).
func _resolve_flat_material_atom(base_material: String) -> Dictionary:
	var source_id: int = MATERIALS.find(base_material)
	if source_id < 0:
		return {}
	var source: TileSetAtlasSource = _tileset.get_source(source_id)
	if source == null or source.texture == null:
		return {}
	return {"image": source.texture.get_image(), "alternative_id": 0}


## D33 Part 4b — deterministic variant pick for the generic path's OLD
## non-suffixed names, which (unlike the decal family) carry no variant index
## at all in the string. A fixed formula over (grid_pos, level) instead of
## always variant 0 buys the visual variety the 12 generic decals already
## support, at zero cost — same cell always resolves to the same variant, no
## new state to persist. Godot's own hash() is intentionally NOT used here
## (unlike HalfVoxelCompositor's ported _hash01/FNV-1a): this selects which of
## 3 already-generated PNGs to show, a cosmetic choice with no golden-fixture
## behind it, not a pixel value that has to reproduce identically forever.
func _generic_variant_for(grid_pos: Vector2i, level: int) -> int:
	return posmod(grid_pos.x * 928371 + grid_pos.y * 123457 + level * 7919, GENERIC_MARK_VARIANT_COUNT)


## D33 Part 4b — how big a hole punch_generic_alpha_hole() cuts, keyed by
## mark_family. Must match generate_voxel.py's _GENERIC_HOLE_RADIUS exactly
## (equality-tested by generic_mark_compositor_equality_selftest.gd).
const _GENERIC_HOLE_RADIUS: Dictionary = {"bullet": 2.0, "blast": 3.0}


## D33 Part 4b — the ACTUAL alpha cut for the full-voxel fallback-of-fallback
## DENTED case (no known carved side, so nothing else conveys "material is
## gone"). Applied to the runtime COMPOSITE, never to a static decal: source-
## over blending (_paste_decal's own blend math) can only ever ADD coverage,
## so an alpha=0 region baked into a decal PNG leaves an opaque substrate
## completely unchanged instead of punching a hole through it — measured via
## generic_mark_seam_selftest.gd sampling the real composited pixel before
## this existed. Port of generate_voxel.py's punch_generic_alpha_hole(),
## same centre (16, 8) — the top-face diamond centre FACE_TOP always projects
## onto, matching D22's original _MARK_CENTER.
func _punch_generic_alpha_hole(image: Image, mark_family: String, variant: int) -> Image:
	var img: Image = image.duplicate()
	var cx := 16.0
	var cy := 8.0
	var seed_value := variant * 173 + 29
	var ox := (HalfVoxelCompositorClass._hash01(seed_value, 1, 401) - 0.5) * 2.0
	var oy := (HalfVoxelCompositorClass._hash01(seed_value, 2, 402) - 0.5) * 1.5
	var r: float = _GENERIC_HOLE_RADIUS[mark_family]
	var x0 := maxi(0, int(cx + ox - r) - 1)
	var x1 := mini(img.get_width(), int(cx + ox + r) + 2)
	var y0 := maxi(0, int(cy + oy - r) - 1)
	var y1 := mini(img.get_height(), int(cy + oy + r) + 2)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := (x + 0.5) - (cx + ox)
			var dy := (y + 0.5) - (cy + oy)
			if dx * dx + dy * dy <= r * r:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
	return img


## D33 Part 4b — the generic vector-mark counterpart to the OLD,
## pre-decal-family fallback (_generic_flat_mark_plan()'s "<material>_dented"
## etc — always a FACE_TOP-only mark). The substrate is the flat MATERIALS
## atom and the decal is one of the 12 material-agnostic marks instead of the
## photographic family — see PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part
## 4a for why a generic voxel must never wear photographic art. `dented`
## additionally punches the real alpha-cut hole (see
## _punch_generic_alpha_hole()'s own doc comment for why that has to happen
## here and not in the decal art). See
## _composite_generic_full_voxel_cracked() just below for this function's
## sibling: the DECAL-FAMILY full-voxel CRACKED shapes
## (_full_voxel_decal_plan()'s own names), which this function does NOT cover.
func _composite_generic_flat_mark(plan: Dictionary, material_name: String,
		grid_pos: Vector2i, level: int) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_flat_material_atom(plan["base_material"])
	if resolved.is_empty():
		return {}

	var mark_family: String = plan["mark_family"]
	var kind: String
	if mark_family == "bullet":
		kind = "bullet_dented" if plan["dented"] else "bullet_cracked"
	else:
		kind = "blast_dent" if plan["dented"] else "blast_crack"
	var variant := _generic_variant_for(grid_pos, relative_level(level))
	var decal_image := _load_decal_image(GENERIC_MARK_TEMPLATE % [kind, variant])
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(
		resolved["image"], decal_image, [DecalCompositorClass.FACE_TOP])
	if plan["dented"]:
		composite = _punch_generic_alpha_hole(composite, mark_family, variant)
	var entry := cache.store(key, composite)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = 0
	return entry


## D33 Part 4b — the generic counterpart to _composite_full_voxel_decal():
## reuses _full_voxel_decal_plan() as-is (a bullet's CRACKED mark on the one
## lateral face it struck, or a blast's CRACKED mark on all three visible
## faces) — same targets, same variant, flat MATERIALS atom instead of a
## tinted baked one, generic decal instead of photographic. CRACKED never
## carves and never punches a hole (that is _composite_generic_flat_mark()'s
## DENTED-only job) — pure ink on every target face.
func _composite_generic_full_voxel_cracked(plan: Dictionary, material_name: String,
		grid_pos: Vector2i, level: int) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_flat_material_atom(plan["base_material"])
	if resolved.is_empty():
		return {}

	var kind: String = "bullet_cracked" if plan["decal_family"] == "bullet" else "blast_crack"
	var variant: int = posmod(int(plan["variant"]), GENERIC_MARK_VARIANT_COUNT)
	var decal_image := _load_decal_image(GENERIC_MARK_TEMPLATE % [kind, variant])
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(
		resolved["image"], decal_image, plan["targets"])
	var entry := cache.store(key, composite)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = 0
	return entry


## D33 Part 4b — the generic counterpart to _composite_half_voxel_decal():
## builds the SAME carved silhouette (HalfVoxelCompositor.build_half_voxel_substrate())
## from the flat MATERIALS atom instead of a tinted baked one, pastes the
## generic mark onto the exposed cut face — no alpha-cut needed here (unlike
## _composite_generic_flat_mark()'s DENTED case): the carve itself already
## represents the missing material.
func _composite_generic_half_voxel(plan: Dictionary, material_name: String,
		grid_pos: Vector2i, level: int) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_flat_material_atom(plan["base_material"])
	if resolved.is_empty():
		return {}

	var cut_fill := _flat_material_side_color(plan["base_material"])
	var half_substrate := HalfVoxelCompositorClass.build_half_voxel_substrate(
		resolved["image"], cut_fill, plan["side"])

	var kind: String = "bullet_dented" if plan["decal_family"] == "bullet" else "blast_dent"
	## The plan already carries the REAL variant the baked branch would have
	## used (parsed straight from the pseudo-material name) — reuse it rather
	## than _generic_variant_for()'s grid_pos hash, which does not vary across
	## the different variant NAMES this same cell might be asked to render
	## and would otherwise collapse every variant onto one composite.
	var variant: int = posmod(int(plan["variant"]), GENERIC_MARK_VARIANT_COUNT)
	var decal_image := _load_decal_image(GENERIC_MARK_TEMPLATE % [kind, variant])
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(half_substrate, decal_image, [plan["target"]])
	var entry := cache.store(key, composite)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = 0
	return entry


## D33 Part 4b — the generic counterpart to _composite_floor_sunk_decal().
## The DECAL here stays material-agnostic (a procedural vector mark — D33 §5
## Part 4: a generic voxel must never wear the photographic decal art), which
## is the half of D25's rule that survives D34.
##
## D34/E-SEAM-02: the SUBSTRATE no longer does. It was hardcoded to the flat
## "earth_0" atom for every material, so with bake OFF a damaged concrete floor
## turned into a patch of dirt. It now uses the struck material's own flat
## atom, falling back to earth_0 when that material has none — the same
## fallback shape as the baked branch, one step down the tier ladder.
func _composite_generic_floor_sunk(plan: Dictionary, material_name: String,
		grid_pos: Vector2i, level: int, zone_material: String = "") -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved: Dictionary = {}
	if zone_material != "" and zone_material != IMPACT_FLOOR_MATERIAL:
		resolved = _resolve_flat_material_atom(zone_material)
	if resolved.is_empty():
		resolved = _resolve_flat_material_atom("earth_0")
	if resolved.is_empty():
		return {}

	var floor_substrate := HalfVoxelCompositorClass.build_floor_sunk_substrate(resolved["image"])

	## Same reasoning as _composite_generic_half_voxel(): reuse the REAL
	## variant _floor_sunk_decal_plan() already parsed from the name.
	var variant: int = posmod(int(plan["variant"]), GENERIC_MARK_VARIANT_COUNT)
	var decal_image := _load_decal_image(GENERIC_MARK_TEMPLATE % ["blast_dent", variant])
	if decal_image == null:
		return {}

	var composite := DecalCompositorClass.compose_decal_voxel(
		floor_substrate, decal_image, [DecalCompositorClass.FACE_SUNK_TOP])
	var entry := cache.store(key, composite)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = 0
	return entry


## D33 Part 4b — the generic counterpart to _composite_ceiling_carve(): no
## decal ever (the camera never sees this face, same reasoning as the baked
## branch), just the silhouette carve on the flat atom instead of a tinted
## baked one.
func _composite_generic_ceiling(plan: Dictionary, material_name: String,
		grid_pos: Vector2i, level: int) -> Dictionary:
	var key := "%d,%d,%d,%s" % [grid_pos.x, grid_pos.y, level, material_name]
	var cache := get_damage_composite_cache()
	if cache.has(key):
		return cache.resolve(key)

	var resolved := _resolve_flat_material_atom(plan["base_material"])
	if resolved.is_empty():
		return {}

	var carved := HalfVoxelCompositorClass.carve_ceiling_silhouette(resolved["image"])
	var entry := cache.store(key, carved)
	if entry.is_empty():
		return {}
	entry["alternative_id"] = 0
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
## How many light-bucket alternatives have been minted on this renderer so far.
## Diagnostics: P-WARM reports how many a blast's warm-up added, which is the
## number that used to be paid one frame at a time during the blast itself.
func minted_light_alt_count() -> int:
	return _minted_light_alts.size()


func _ensure_light_alt(source_id: int, coords: Vector2i, alt_id: int) -> void:
	## ABLATION — see LIGHT_DISABLED. Minting is gated here rather than only at
	## the apply sites because DetonationChoreographer mints directly.
	if LIGHT_DISABLED:
		return
	if alt_id == 0 or alt_id == TileSetAtlasSource.TRANSFORM_FLIP_H:
		return
	var key := Vector4i(source_id, coords.x, coords.y, alt_id)
	if _minted_light_alts.has(key):
		return
	_minted_light_alts[key] = true
	_alts_minted += 1
	if _mint_trace:
		print("[MINT] source=%d coords=%s alt=%d" % [source_id, coords, alt_id])
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
	return _layers.get(level)


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
			var _walls_desc: Array = wall_level_keys()
			_walls_desc.reverse()
			for level in _walls_desc:
				var layer: TileMapLayer = _layers[level]
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
	return wall_level_keys().size()


## OCC-03: Get the highest z_index across all voxel layers (used to render agent above all geometry).
## Returns: z_index of the topmost voxel layer, or WALL_BASE_Z_INDEX if no layers yet.
func get_max_voxel_z_index() -> int:
	var walls: Array = wall_level_keys()
	if walls.is_empty():
		return _wall_base_z_index
	# Each layer has z_index = _wall_base_z_index + (level - ground plane)
	return _wall_base_z_index + (top_wall_level() - _ground_plane_level)


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
	for layer in _layers.values():
		layer.position += delta
	## GLASS G1 — the sublayers register pixel-exact with their opaque siblings;
	## a nudge that moved one and not the other would split them.
	for l in _glass_layers.values():
		(l as TileMapLayer).position += delta


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
	# D33 Part 4c: MATERIALS holds only real base materials now — no impact-mark
	# pseudo-material ever needs a boot-time entry or a composites/ load anymore.
	for mat_index in range(MATERIALS.size()):
		var material_name: String = MATERIALS[mat_index]
		## D35/E-EARTH-01: the atlas entry is keyed by MATERIAL id but loaded
		## from the CANONICAL atom's filename — they differ only for `earth`,
		## which ships as eight variants and has no unsuffixed file (see
		## BakePolicy.canonical_voxel_atom_for()).
		## The canonical atom id is BOTH the folder and the filename stem: an
		## aliased material (brick -> concrete, D34) reads concrete's atom out of
		## concrete's own folder, which is what "alias" has always meant.
		var atom_id := BakePolicyClass.canonical_voxel_atom_for(material_name)
		var asset_path := VOXEL_ASSET_TEMPLATE % [
			BakePolicyClass.material_folder_for_atom(atom_id), atom_id]

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

	## GLASS G1 GEOMETRY — 16 extra atlas sources: four faces (SW/SE/NW/NE) ×
	## four face masks (main-only / +top / +side / +top+side). Each atom's alpha
	## is that face's wall parallelogram (the fundamental domain of the face's
	## voxel lattice, on its own diamond edge) so a stack tiles seam-to-seam with
	## NO overlap (a translucent atom over a translucent one DOUBLE-TINTS the
	## overlap, the "serrilhado"). `+top` adds the dim iso top-face sliver, `+side`
	## the dim iso side-face sliver — the voxel's OWN faces, not invented shapes;
	## painting only the exposed ones is what stops the ghosting. The frosted
	## PATTERN is not in the atom — the shader samples it by world position. RGB
	## carries the per-face dim (1.0 main, GLASS_DIM_TOP / GLASS_DIM_SIDE for the
	## slivers); glass_pane.gdshader multiplies by it. Alpha is the silhouette.
	_glass_atom_source.clear()
	var ok := true
	var next_id: int = MATERIALS.size()
	for face in [Face.SW, Face.SE, Face.NW, Face.NE]:
		_glass_atom_source[face] = {}
		for mask in range(4):
			var want_top: bool = (mask & 0b10) != 0
			var want_side: bool = (mask & 0b01) != 0
			var atom := _build_glass_pane_atom(face, want_top, want_side)
			if atom == null:
				ok = false
				break
			var src := TileSetAtlasSource.new()
			src.texture = ImageTexture.create_from_image(atom)
			src.texture_region_size = Vector2i(atom.get_width(), atom.get_height())
			src.separation = Vector2i.ZERO
			src.margins = Vector2i.ZERO
			src.create_tile(Vector2i.ZERO)
			_tileset.add_source(src, next_id)
			var td: TileData = src.get_tile_data(Vector2i.ZERO, 0)
			if td != null:
				td.texture_origin = GeometryCoords.voxel_texture_origin() + _GLASS_ATOM_ORIGIN_NUDGE
				td.set_custom_data("tile_name", "glass")
			(_glass_atom_source[face] as Dictionary)[mask] = next_id
			next_id += 1
		if not ok:
			break
	if ok:
		## Back-compat alias: the SW main-only source, used by diagnostics/selftest.
		_glass_frosted_source_id = _glass_atom_source[Face.SW][0]
	else:
		## B6 loud-fail: without the atoms glass panes would silently disappear.
		push_error("[VoxelRenderer] GLASS-G1: glass pane atom build failed — glass panes will not render")
		_glass_atom_source.clear()
		_glass_frosted_source_id = -1


## GLASS G1 GEOMETRY — extra texture_origin offset for the pane atoms, ON TOP of
## `voxel_texture_origin()`. It is **0** by design: `_build_glass_pane_atom`'s
## `face_q` is byte-for-byte the material atom's own side-face parallelogram
## (verified against `voxel_concrete.png` — alpha rows 8..36, left half), so the
## glass renders exactly where an opaque wall would. The old default (0,20) was
## leftover compensation for a `+shift` the atom no longer applies, and it lifted
## every pane a level off the ground (Director, 2026-08-31: *"o bloco todo de
## vidro está deslocado pra cima ... flutuando na base"*). `INFILTRAITOR_GLASS_
## ATOM_NUDGE="x,y"` overrides it for a tuning pass only.
static var _GLASS_ATOM_ORIGIN_NUDGE: Vector2i = _read_glass_atom_nudge()
static func _read_glass_atom_nudge() -> Vector2i:
	var raw := OS.get_environment("INFILTRAITOR_GLASS_ATOM_NUDGE")
	if raw.contains(","):
		var p := raw.split(",")
		if p.size() == 2 and p[0].is_valid_int() and p[1].is_valid_int():
			return Vector2i(p[0].to_int(), p[1].to_int())
	return Vector2i.ZERO


## GLASS G1 GEOMETRY — build the 32×36 glass pane atom for one face and one
## face mask. Alpha is the silhouette, RGB carries the per-face dim.
##
##   MAIN face  — always. The parallelogram on the face's own diamond edge,
##                extending VOXEL_STEP_PX down. RGB 1.0 (full see-through).
##   TOP sliver — only when `want_top` (the voxel has no glass above it). The
##                pane's top edge extruded into the GU by the pane's thickness
##                (a parallelogram — its back edge stays PARALLEL to its front
##                edge, so voxel-to-voxel the slivers meet with no sawtooth).
##                RGB GLASS_DIM_TOP.
##   SIDE sliver — only when `want_side` (the voxel is the frontmost column).
##                The frontmost column's outer vertical edge extruded into the
##                GU by the same thickness vector. RGB GLASS_DIM_SIDE.
##
## `d_vec` is the pane's thickness in screen space — a fraction of the depth to
## the opposite diamond edge (SW/SE recede UP/away from the camera). The main
## face stays crisp; a sliver fills only where the main face is absent, so
## nothing double-covers and the container never double-tints. NW/NE slivers are
## computed but their extrusion comes toward the camera (back walls) — the
## tested case is SW/SE.
func _build_glass_pane_atom(face: int, want_top: bool = false, want_side: bool = false) -> Image:
	var w: int = GeometryCoords.VOXEL_ATOM_W          # 32
	var h: int = GeometryCoords.VOXEL_ATOM_H          # 36
	var step: float = GeometryCoords.VOXEL_STEP_PX    # 20
	## Cube-atom diamond vertices, the reference every voxel atom shares.
	var vn := Vector2(16.0, 0.0)
	var ve := Vector2(32.0, 8.0)
	var vs := Vector2(16.0, 16.0)
	var vw := Vector2(0.0, 8.0)
	var down := Vector2(0.0, step)
	var f: float = GLASS_FACE_SLIVER_FRAC
	## `ea`,`eb` — the face's diamond edge, `ea` the far end, `eb` the frontmost
	## column's end. `d_vec` — the thickness extrusion into the GU (toward the
	## opposite edge), scaled to the pane's half thickness.
	var ea: Vector2
	var eb: Vector2
	var d_vec: Vector2
	match face:
		Face.SW: ea = vw; eb = vs; d_vec = (ve - vs) * f
		Face.SE: ea = ve; eb = vs; d_vec = (vw - vs) * f
		Face.NW: ea = vn; eb = vw; d_vec = (vs - vw) * f
		Face.NE: ea = vn; eb = ve; d_vec = (vs - ve) * f
		_: return null
	## The main face parallelogram (diamond edge, extending `step` down).
	var face_q: PackedVector2Array = [ea, eb, eb + down, ea + down]
	## The top sliver: the top edge extruded into the GU by the thickness.
	var top_q: PackedVector2Array = [ea, eb, eb + d_vec, ea + d_vec]
	## The side sliver: the frontmost column's outer vertical edge (at `eb`)
	## extruded into the GU by the same thickness.
	var side_q: PackedVector2Array = [eb, eb + d_vec, eb + d_vec + down, eb + down]

	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var a_face: float = clampf(_signed_dist_in_quad(p, face_q) + 0.5, 0.0, 1.0)
			var rgb: float = 1.0
			var a: float = a_face
			if a_face < 0.5:
				var a_top: float = clampf(_signed_dist_in_quad(p, top_q) + 0.5, 0.0, 1.0) if want_top else 0.0
				var a_side: float = clampf(_signed_dist_in_quad(p, side_q) + 0.5, 0.0, 1.0) if want_side else 0.0
				if a_top >= a_side and a_top > 0.0:
					a = a_top
					rgb = GLASS_DIM_TOP
				elif a_side > 0.0:
					a = a_side
					rgb = GLASS_DIM_SIDE
			if a > 0.0:
				out.set_pixel(x, y, Color(rgb, rgb, rgb, a))
	return out


## Signed distance from `p` to the boundary of convex quad `q` (CW or CCW):
## positive inside, negative outside, magnitude ≈ px to the nearest edge.
func _signed_dist_in_quad(p: Vector2, q: PackedVector2Array) -> float:
	var centroid := (q[0] + q[1] + q[2] + q[3]) * 0.25
	var d: float = 1e9
	for i in range(4):
		var a := q[i]
		var b := q[(i + 1) % 4]
		var edge := b - a
		var n := Vector2(-edge.y, edge.x).normalized()
		## Point the normal inward (toward the centroid).
		if n.dot(centroid - a) < 0.0:
			n = -n
		d = min(d, n.dot(p - a))
	return d


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
	## LEVEL-RENUMBER — `start_level` is a STOREY index despite its name (see the
	## docstring: "start_level=0 reproduces the old ground-anchored behavior"), so
	## it goes through the same origination helper every other storey does. Callers
	## keep passing 0 for the ground storey and keep meaning it.
	for level in range(GeometryCoords.storey_level_base(start_level),
			GeometryCoords.storey_level_base(start_level + storey_span)):
		for voxel_pos in voxel_positions:
			_set_voxel_cell(voxel_pos, level, material_name)


## Render a single slice's voxels
func _render_slice(slice: Slice, edge = null) -> void:
	# Ensure we have enough layers
	# FIX-VOXEL-HEIGHT-01: multiply storey_count by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers(slice.storey_count * GeometryCoords.LEVELS_PER_STOREY)
	## GLASS G-D9 — a slice's material is now per-level. `_slice_is_glassy()` is
	## true when the base OR any band is glass, so the diag and the geometry
	## still fire for a brick-capped window.
	if _slice_is_glassy(slice) and OS.get_environment("INFILTRAITOR_GLASS_DIAG") == "1":
		print("[GLASS-DIAG] slice %s face=%s gu=%s storeys=%d voxels=%d pane=%s bands=%s" % [
			slice.id, Face.to_string_name(slice.face), slice.gu_cell,
			slice.storey_count, slice.voxels.size(),
			slice.pane_id if slice.pane_id != "" else "<none>",
			slice.material_bands if slice.has_material_bands() else "{}"])

	## GLASS G1 GEOMETRY — the top level of a lone pane paints its dim top sliver;
	## the frontmost column paints its dim side sliver. G-D9: "top" is the highest
	## level that is actually GLASS, not the slice top (a brick head sits above it).
	var glass_top_level: int = _slice_top_glass_level(slice)
	var slice_level_base: int = GeometryCoords.storey_level_base(slice.start_storey)

	# For each voxel in the slice, set_cell at the appropriate layer
	for voxel in slice.voxels:
		if voxel.visible:
			# Derive local voxel position within 8×8 quad from grid position
			var voxel_xy = Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
			var vmat := slice.material_at(voxel.level - slice_level_base)
			var render_material := damage_variant_material(vmat, voxel.damage_state, voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant)
			var glass_mask: int = _glass_face_mask(voxel.grid_pos, voxel.level, slice.face, glass_top_level) \
				if vmat == "glass" else 0
			_set_voxel_cell(voxel.grid_pos, voxel.level, render_material, edge,
				voxel_xy, slice.face, false, "", BakePolicyClass.SurfaceClass.SLICE,
				true, glass_mask)


## GLASS G-D9 — true when this slice renders any glass at all (base material, or
## any level band). Non-banded glass slices answer via the base check with zero
## dictionary work.
func _slice_is_glassy(slice: Slice) -> bool:
	if slice.material == "glass":
		return true
	for m in slice.material_bands.values():
		if m == "glass":
			return true
	return false


## GLASS G-D9 — the highest RENDER level of this slice whose material is glass,
## or a large negative sentinel when the slice has no glass at all. For a plain
## glass pane this is simply the slice top; for a brick-capped window it is one
## level below the head band.
func _slice_top_glass_level(slice: Slice) -> int:
	if not _slice_is_glassy(slice):
		return -99999
	var base: int = GeometryCoords.storey_level_base(slice.start_storey)
	var span: int = slice.storey_count * GeometryCoords.LEVELS_PER_STOREY
	if not slice.has_material_bands():
		return base + span - 1
	for rel in range(span - 1, -1, -1):
		if slice.material_at(rel) == "glass":
			return base + rel
	return -99999


## GLASS G1 GEOMETRY — the face mask for one glass voxel. Bit 1 = paint the dim
## top sliver: nothing (no glass) above it — for a lone pane, the top level. Bit
## 0 = paint the dim side sliver: the frontmost column. NW/SE faces vary in the
## y grid coord, NE/SW in x; both screen axes carry a +south component, so the
## column nearest the camera is always pos 7 (max coord along the varying axis).
func _glass_face_mask(grid_pos: Vector2i, level: int, face: int, top_level: int) -> int:
	var mask: int = 0
	if level == top_level:
		mask |= 0b10
	var pos: int = posmod(grid_pos.y, 8) if (face == Face.NW or face == Face.SE) \
		else posmod(grid_pos.x, 8)
	if pos == GeometryCoords.VOXELS_PER_UNIT_AXIS - 1:
		mask |= 0b01
	return mask


## Render a junction column (BAKE-FIX-02: mirror-at-the-column implementation)
## By default: mirrors the neighboring wall voxel's atom (D-BAKE-2)
## If override_material is set and facade_enabled=false: renders flat material-only (D-BAKE-3)
## If override_material is set and facade_enabled=true: mirrors the override material's boundary atom (D-BAKE-3)
func _render_junction_column(column: JunctionResolver.JunctionColumn, registry: EdgeRegistry = null) -> void:
	# FIX-VOXEL-HEIGHT-01: multiply storey counts by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers((column.start_storey + column.storey_count) * GeometryCoords.LEVELS_PER_STOREY)

	# Determine actual material to use (override if set, otherwise derived)
	var actual_material = column.override_material if column.override_material != "" else column.material
	
	for level_offset in range(column.storey_count * GeometryCoords.LEVELS_PER_STOREY):
		var level: int = GeometryCoords.storey_level_base(column.start_storey) + level_offset

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
				var junction_result = _baked_lookup.resolve_junction(column.voxel_pos, relative_level(level))
				if junction_result and junction_result.source_id_int >= 0:
					_diag_total_cells += 1
					_diag_baked_hits += 1
					(_layers[level] as TileMapLayer).set_cell(column.voxel_pos, junction_result.source_id_int, junction_result.atlas_coords, 0)
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
						var result = _baked_lookup.resolve(neighbor_edge, slice.face, voxel_xy, relative_level(level))
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
				var layer: TileMapLayer = _layers[level]
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
## D33 Part 3c: `zone_material`, when non-empty, is the REAL zoned ground
## material (e.g. "grass") a damaged FLOOR voxel's `material_name`
## no longer carries — floor_damage_material() always renames it to the
## shared "earth_blast_dented_top_N" (D26), so resolve_flat() would look up
## the wrong (nonexistent) zone if given `material_name` directly. Every
## other caller passes "" (the default) and nothing changes for them.
## D19/D20 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): `surface_class`
## disambiguates the flat_baked resolve_flat() call below (SLICE for roof
## slabs, SLAB for floor zones) — needed since material unification means a
## material id like "concrete" no longer says by itself which texture family
## it means. Defaults to SLICE (today's roof/wall behavior); the edge/wall
## branch above never reads it. Every floor-zone caller passes SLAB.
## EXPLOSION_REBUILD_MASTER_PLAN Task 4/E-PLAN (2026-08-07) — `apply` is the
## resolve-only seam DetonationPlanBuilder needs: every branch below still
## computes the SAME source_id/atlas_coords/alternative_id it always did
## (baked lookup, D33 live-compositing fallback, or the flat material-only
## last resort), but when `apply` is false the ONE side-effecting line
## (`layer.set_cell()`) is skipped and the resolved triple is returned
## instead — the whole point of §2's "no compositing, no lookup... inside a
## wave": a pre-compute pass can resolve every affected cell's final tile
## WITHOUT touching the live TileMapLayer, and a later wave (Task 5) turns
## the returned triple into a real set_cell() call with zero further lookup.
## Trailing + defaulted true, so every existing caller (all of them) is
## byte-for-byte unaffected — the return value they've always ignored (void)
## is simply an ignorable empty Dictionary now instead.
func _set_voxel_cell(grid_pos: Vector2i, level: int, material_name: String,
                     edge = null, voxel_xy: Vector2i = Vector2i.ZERO,
                     slice_face: int = 0, flat_baked: bool = false,
                     zone_material: String = "",
                     surface_class: int = BakePolicyClass.SurfaceClass.SLICE,
                     apply: bool = true, glass_mask: int = 0) -> Dictionary:
	# D17: get_layer() routes negative levels to _negative_voxel_layers — the
	# caller must have ensured the layer first (_ensure_voxel_layers() for
	# level >= 0, _ensure_negative_voxel_layer() for level < 0), same contract
	# as before, now honored for both signs instead of hard-rejecting negative.
	var layer: TileMapLayer = get_layer(level)
	if layer == null:
		push_warning("VoxelRenderer._set_voxel_cell: level %d has no layer — call _ensure_voxel_layers()/_ensure_negative_voxel_layer() first" % level)
		return {}

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

	## GLASS G-D9 — on a banded edge the facade key's material component is
	## per-level, not `edge.material`. Resolve it here in RENDER space (no
	## `_ground_plane_level` dependency) and hand it to the lookup as an override;
	## "" for every ordinary edge, which the lookup treats as "ask edge.material".
	var edge_material_override: String = ""
	if edge != null and edge is Edge and edge.has_material_bands():
		edge_material_override = edge.material_at(level - GeometryCoords.storey_level_base(edge.start_storey))

	if not is_impact_mark and _bake_config and _bake_config.enabled and edge != null:
		## LEVEL-RENUMBER — sheet space, not render space. See `sheet_level()`.
		## This is the MAIN wall placement path and the last of the four to be
		## found: the first sweep missed it because it sits inside
		## `_set_voxel_cell()` rather than beside the other three.
		var result = _baked_lookup.resolve(edge, slice_face, voxel_xy, relative_level(level), -1, edge_material_override)

		if result and result.source_id_int >= 0:
			source_id = result.source_id_int
			atlas_coords = result.atlas_coords
			alternative_id = result.alternative_id
			_diag_baked_hits += 1

	# ROOF-BAKE-01/02c: horizontal (edge-less) baked surfaces — roof slabs.
	# voxel_xy carries the STRUCTURE-LOCAL offset here (grid_pos − anchor),
	# the same container-local meaning it has for wall slices.
	if not is_impact_mark and source_id < 0 and flat_baked and _bake_config and _bake_config.enabled:
		var flat_result = _baked_lookup.resolve_flat(material_name, voxel_xy, surface_class)
		if flat_result and flat_result.source_id_int >= 0:
			source_id = flat_result.source_id_int
			atlas_coords = flat_result.atlas_coords
			alternative_id = flat_result.alternative_id
			_diag_baked_hits += 1

	## D-ARCH-01 NOTE: This is now FALLBACK-ONLY rendering for damaged voxels.
	## Normal damage rendering uses apply_damage_voxel_swap() (pre-baked tile
	## swaps) in the dirty render pass. The D33 compositing paths below are only
	## reached if apply_damage_voxel_swap() fails or returns false (e.g., variant
	## not found, registry uninitialized). Kept for robustness and tested via
	## seam selftests.
	##
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

	## D33 Part 3c/3d: the edge-less (flat_baked) counterparts — floor-sunk
	## DENTED and ceiling DENTED. Both always arrive with edge == null
	## (ROOF-BAKE-01/02c: edge-less baked surfaces) and flat_baked == true,
	## so this is the edge-less half of the SAME "is this an impact mark on a
	## baked surface" question above. Tried in either order — the two plan
	## parsers never both match the same name (ceiling ends in
	## "_dented_bottom" with no variant; floor is always
	## "earth_blast_dented_top_N") — ceiling first since it needs no
	## zone_material at all.
	if is_impact_mark and _bake_config and _bake_config.enabled and edge == null and flat_baked:
		if source_id < 0:
			var ceiling_plan := _ceiling_carve_plan(material_name)
			if not ceiling_plan.is_empty():
				var ceiling_composite := _composite_ceiling_carve(
					ceiling_plan, material_name, voxel_xy, level, grid_pos)
				if not ceiling_composite.is_empty():
					source_id = ceiling_composite["source_id"]
					atlas_coords = ceiling_composite["atlas_coords"]
					alternative_id = ceiling_composite["alternative_id"]
					_diag_baked_hits += 1

		## zone_material == "" means either an unzoned floor (plain earth —
		## never baked, nothing to preserve) or a non-floor flat_baked case
		## (interior) — either way, skip rather than resolve_flat() against
		## an empty string.
		if source_id < 0 and zone_material != "":
			var floor_plan := _floor_sunk_decal_plan(material_name)
			if not floor_plan.is_empty():
				var floor_composite := _composite_floor_sunk_decal(
					floor_plan, material_name, zone_material, voxel_xy, level, grid_pos)
				if not floor_composite.is_empty():
					source_id = floor_composite["source_id"]
					atlas_coords = floor_composite["atlas_coords"]
					alternative_id = floor_composite["alternative_id"]
					_diag_baked_hits += 1

	## D33 Part 4b — the generic/vector counterpart: reached whenever this cell
	## is an impact mark and NONE of the baked branches above resolved it
	## (BakeConfig off — the release canon — an unbaked map, or simply no
	## baked atom for this specific cell). Composites a material-agnostic
	## PROCEDURAL vector mark onto the flat MATERIALS atom instead of falling
	## straight to the composites/-backed MATERIALS.find() below — see
	## PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 4 for why a generic
	## voxel must never wear the photographic decal art. Purely string-driven
	## (no edge/flat_baked gating needed: the five plan parsers below are
	## mutually exclusive by construction, same guarantee the baked branches
	## above already rely on), so all five are tried unconditionally in the
	## same order as the baked branches. {} on any miss (should not happen —
	## B6: the 12 generic decals are unconditional, unlike the photographic
	## family) falls through to the last-resort composites/ fallback, which
	## Part 4c retires once this path is proven with a real bake-OFF capture.
	if is_impact_mark and source_id < 0:
		var generic_cracked_plan := _full_voxel_decal_plan(material_name)
		if not generic_cracked_plan.is_empty():
			var generic_cracked_composite := _composite_generic_full_voxel_cracked(
				generic_cracked_plan, material_name, grid_pos, level)
			if not generic_cracked_composite.is_empty():
				source_id = generic_cracked_composite["source_id"]
				atlas_coords = generic_cracked_composite["atlas_coords"]
				alternative_id = generic_cracked_composite["alternative_id"]

		if source_id < 0:
			var generic_flat_plan := _generic_flat_mark_plan(material_name)
			if not generic_flat_plan.is_empty():
				var generic_flat_composite := _composite_generic_flat_mark(
					generic_flat_plan, material_name, grid_pos, level)
				if not generic_flat_composite.is_empty():
					source_id = generic_flat_composite["source_id"]
					atlas_coords = generic_flat_composite["atlas_coords"]
					alternative_id = generic_flat_composite["alternative_id"]

		if source_id < 0:
			var generic_wall_plan := _half_voxel_decal_plan(material_name)
			if not generic_wall_plan.is_empty():
				var generic_wall_composite := _composite_generic_half_voxel(
					generic_wall_plan, material_name, grid_pos, level)
				if not generic_wall_composite.is_empty():
					source_id = generic_wall_composite["source_id"]
					atlas_coords = generic_wall_composite["atlas_coords"]
					alternative_id = generic_wall_composite["alternative_id"]

		if source_id < 0:
			var generic_ceiling_plan := _ceiling_carve_plan(material_name)
			if not generic_ceiling_plan.is_empty():
				var generic_ceiling_composite := _composite_generic_ceiling(
					generic_ceiling_plan, material_name, grid_pos, level)
				if not generic_ceiling_composite.is_empty():
					source_id = generic_ceiling_composite["source_id"]
					atlas_coords = generic_ceiling_composite["atlas_coords"]
					alternative_id = generic_ceiling_composite["alternative_id"]

		if source_id < 0:
			var generic_floor_plan := _floor_sunk_decal_plan(material_name)
			if not generic_floor_plan.is_empty():
				var generic_floor_composite := _composite_generic_floor_sunk(
					generic_floor_plan, material_name, grid_pos, level, zone_material)
				if not generic_floor_composite.is_empty():
					source_id = generic_floor_composite["source_id"]
					atlas_coords = generic_floor_composite["atlas_coords"]
					alternative_id = generic_floor_composite["alternative_id"]

	# Fallback: material-only path
	if source_id < 0:
		_diag_generic_fallbacks += 1
		source_id = MATERIALS.find(material_name)
		if source_id == -1:
			source_id = 0  # Fallback to concrete
		atlas_coords = Vector2i.ZERO

	## GLASS G1 — a glass VERTICAL face does not live on the opaque layer. Route it
	## to this level's MUL/ADD blend sublayers so the background shows through
	## (G-D1). `damage_variant_material()` returns "glass" for every visible glass
	## state (D22: no marked tier), so this catches wall slices, panels and the
	## vertical faces of a glass block. `flat_baked` HORIZONTAL glass — a roof or a
	## glazed floor zone — stays opaque for G1: a see-through roof is out of scope
	## and it kept the roof-coverage geometry intact. The sublayers build lazily,
	## so a map with no vertical glass builds none.
	if material_name == "glass" and not _glass_atom_source.is_empty() and not flat_baked:
		## GLASS G1 GEOMETRY — one of the four per-face masks (main / +top / +side
		## / +top+side). The main face is always present; the dim slivers are
		## added only where the voxel's top or camera-facing side is exposed. The
		## container lets the atoms overlap without tint².
		var face_atoms: Dictionary = _glass_atom_source.get(slice_face, {})
		var glass_src: int = int(face_atoms.get(glass_mask, face_atoms.get(0, _glass_frosted_source_id)))
		if glass_src < 0:
			glass_src = _glass_frosted_source_id
		if not apply:
			return {"source_id": glass_src,
				"atlas_coords": Vector2i.ZERO, "alternative_id": 0}
		_ensure_glass_sublayers(level)
		(_glass_layers[level] as TileMapLayer).set_cell(grid_pos, glass_src, Vector2i.ZERO, 0)
		## Clear any opaque cell a prior state left here (e.g. the calibration
		## control preview) — an intact pane must be a true gap.
		layer.erase_cell(grid_pos)
		note_external_write(level, grid_pos)
		return {}

	if not apply:
		return {"source_id": source_id, "atlas_coords": atlas_coords, "alternative_id": alternative_id}
	layer.set_cell(grid_pos, source_id, atlas_coords, alternative_id)
	## PERF-10 — THE PLACEMENT SEAM IS ALSO A BOARD WRITE THE LIGHT FIELD CANNOT
	## SEE. Rule 8 makes this the only way a Wall or Slab voxel reaches the
	## tilemap, which is exactly why the note belongs here rather than at each of
	## its callers: damage variants, re-renders after destruction and the shot's
	## own dirty pass all funnel through it, and none of them move occupancy or
	## soot in a way `_stale_cells()` could notice. Measured: the SHOT's scoped
	## repaint left 3 144 cells disagreeing with a full apply without this.
	note_external_write(level, grid_pos)
	return {}




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
		var max_level: int = int(entry.get("max_level", top_wall_level()))
		## OCC-21 dropped tile-alternative ghosting for erase+wireframe-fill (see
		## below) — `entry["ring"]` is no longer read here; ring-based visuals now
		## live entirely in occlusion_slice_panel.gd/occlusion_wireframe_overlay.gd.
		var restore_records: Array = []

		for level in range(min_level, max_level + 1):
			var layer: TileMapLayer = _layers.get(level)
			if layer == null:
				continue
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
			note_external_write(level, cell)

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
	for level in wall_level_keys():
		var layer: TileMapLayer = _layers[level]
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
## OCC-GHOST-DESTROY — A DESTROYED VOXEL HAS NOTHING TO RESTORE, and not saying so
## is how one voxel gets destroyed TWICE.
##
## `_ghosted_cells` remembers a cell's exact placement so un-ghosting can put it
## back. If the voxel is destroyed WHILE ghosted, that memory becomes a promise to
## re-create geometry that no longer exists — and `_restore_ghosted_cells()` keeps
## the promise, because it restores from the saved record precisely so it does not
## have to consult live layer state (OCC-21).
##
## The sequence behind the reported defect (Director, 2026-08-23: *"algumas areas
## queimam e soltam fumaça uma segunda vez"*):
##
##   1. occlusion ghosts a cell — erased, placement remembered
##   2. a blast destroys that voxel: `process_dirty()` erases it, sees
##      `already_gone`, and correctly does NOT emit `voxel_destroyed`
##   3. the agent moves on and `_restore_ghosted_cells()` PUTS THE CELL BACK
##   4. the next dirty pass finds geometry there, erases it, and emits
##      `voxel_destroyed` — smoke, debris and sparks for a voxel that died in an
##      earlier blast
##
## ⚠️ The emit guards at both erase sites are CORRECT and are not the bug: in step
## 4 the cell really was there. The flag was never finalised, and this finalises it
## at the moment of destruction — the only place that knows.
func forget_ghost_record(cell: Vector2i, level: int) -> void:
	var records = _ghosted_cells.get(cell)
	if records == null:
		return
	for i in range(records.size() - 1, -1, -1):
		if int(records[i]["level"]) == level:
			records.remove_at(i)
	if (records as Array).is_empty():
		_ghosted_cells.erase(cell)


func _restore_ghosted_cells() -> void:
	for cell in _ghosted_cells.keys():
		for record in _ghosted_cells[cell]:
			var level: int = record["level"]
			if not _layers.has(level):
				continue
			var layer: TileMapLayer = _layers[level]
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
## `predict_destroyed` (W-PRECOOK, 2026-08-19) omits cells a shot is ABOUT to
## destroy, so the caller can build the light field for the world as it will be
## rather than as it is. Empty = the live world, which is every existing caller.
##
## It exists to warm the TileSet alternative cache during the aim window: the
## measured cost of a shot is 412 `create_alternative_tile()` calls landing on
## the impact frame, and an alternative minted early is one not minted late.
## A WRONG prediction costs nothing but a cache miss — `_ensure_light_alt()`
## still mints on demand — which is why this is safe to do speculatively.
func build_occupancy(predict_destroyed: Dictionary = {}) -> Dictionary:
	var occupancy: Dictionary = {}
	## ⚠️ ONE loop, and the prediction now reaches FLOOR levels too. The paired
	## version applied `predict_destroyed` to positive levels only and rebuilt
	## negative ones verbatim — so a predicted crater floor stayed solid in the
	## predicted occupancy. Harmless while the prediction only ever named wall
	## cells; a latent wrong answer the moment it did not.
	for level in level_keys():
		var level_set: Dictionary = {}
		for cell in (_layers[level] as TileMapLayer).get_used_cells():
			if predict_destroyed.has(Vector3i(cell.x, cell.y, level)):
				continue
			level_set[cell] = true
		occupancy[level] = level_set
	## Cells hidden by occlusion are erased from the tilemap but are still SOLID
	## geometry — omitting them would make every ghosted column read as a cavity
	## and light up its neighbours the moment the agent walked past.
	for cell in _ghosted_cells.keys():
		for record in _ghosted_cells[cell]:
			var lvl: int = record["level"]
			if not occupancy.has(lvl):
				occupancy[lvl] = {}
			occupancy[lvl][cell] = true
	## GLASS G1 — glass cells left `_layers` for their own blend sublayers, but
	## intact glass still BLOCKS light exactly as it did before G1: whether an
	## intact pane should transmit light is a separate decision (G-D8 touches only
	## the BROKEN pane). Adding the sublayer cells back here keeps the light field
	## byte-identical to the opaque era.
	for level in _glass_layers:
		var gmul := _glass_layers[level] as TileMapLayer
		for cell in gmul.get_used_cells():
			if predict_destroyed.has(Vector3i(cell.x, cell.y, level)):
				continue
			if not occupancy.has(level):
				occupancy[level] = {}
			occupancy[level][cell] = true
	return occupancy


## VL-D3 — columns (x,y) covered by any wall/block/roof voxel (positive levels).
## A floor voxel in such a column was never sun-exposed; when a blast opens the
## wall above and exposes its top, it should read darker than always-open floor.
## Computed from the INTACT geometry right after a build (before reapply_damage),
## so it reflects the ORIGINAL cover, not the post-blast state.
func columns_with_structure() -> Dictionary:
	var cols: Dictionary = {}
	for level in wall_level_keys():
		for cell in (_layers[level] as TileMapLayer).get_used_cells():
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
## PERF-10 §10.2 — O(1) membership for the index above, so a cell can be added
## incrementally without scanning its GU's list. Cleared and rebuilt with it.
var _placed_index: Dictionary = {}         ## Vector3i(cell.x, cell.y, level) -> true

## PERF-10 — CELLS WRITTEN TO THE BOARD BY SOMEONE OTHER THAN AN APPLY PASS.
##
## The stale-driven apply rests on "a cell whose value changed was invalidated in
## VoxelLightField, therefore it is in the stale set". That property covers every
## change the FIELD causes and none that a direct board write causes — and
## `DetonationChoreographer` is documented as *"the ONLY place a plan ever reaches
## set_cell()"*, writing the plan's own alternative and scorch straight onto the
## layer. Measured: without this the ending's gate failed by 200 cells, every one
## of them a cell the blast's own wave had written.
##
## So the writer names what it wrote, and the next full-coverage apply unions it
## into the set it walks. This is the seam that lets the map-wide walk retire —
## the walk WAS this bookkeeping, done by brute force every time.
var _externally_written: Dictionary = {}   ## Vector3i(cell.x, cell.y, level) -> true


## See `_externally_written`. Called by whoever writes a cell outside an apply.
func note_external_write(level: int, cell: Vector2i) -> void:
	_externally_written[Vector3i(cell.x, cell.y, level)] = true


## PERF-P3 measurement seam — WHAT IS THE MAP-WIDE APPLY ACTUALLY MADE OF?
##
## `INFILTRAITOR_APPLY_SPLIT_PROBE=1`. PERFORMANCE_MASTER_PLAN §1.2 charges
## ~1 080 ms to `apply` and P3 proposes to remove it by making a light change a
## pixel write. That is only true of the part that IS `set_cell()` +
## `_ensure_light_alt()`. Nothing on record split the term, so P3's size was
## being estimated against a figure that includes work P3 cannot reach.
##
## THREE PHASES, ordered so each one can only measure itself:
##
##   A · WARM — touch `field.bucket_for()` on every placed cell and nothing
##       else. VoxelLightField caches per (cell, level) and derives on FIRST
##       TOUCH (`_compute_bucket` -> `_lamp_intensity` x `_static_factor`), so
##       whichever pass runs first is charged the whole derivation. Paying it
##       here is what stops it from hiding inside the apply.
##   B · APPLY — the real pass, field cache already warm: walk + `set_cell()`
##       + minting.
##   C · APPLY AGAIN — every cell is now at its target alternative, so every one
##       takes the `continue`. This is the WALK alone.
##
## B minus C is the write-and-mint half, and it is the only half P3 removes.
##
## An earlier version of this probe ran only B and C and called C "walk only".
## It is not: C is walk plus a WARM field cache, and B was carrying the
## derivation. That version reported 760 ms of "writes+mints" on a repaint that
## wrote zero cells and minted zero alternatives — the number was real, the name
## on it was wrong, and phase A is what gives it its own name.
var _apply_cells_seen: int = 0
var _apply_cells_written: int = 0


func apply_light_field(field) -> void:
	if LIGHT_DISABLED:
		return
	if field == null:
		return
	if OS.get_environment("INFILTRAITOR_APPLY_SPLIT_PROBE") == "1":
		_apply_split_probe(field)
		return
	_apply_light_field_pass(field)


func _apply_split_probe(field) -> void:
	var warm_t0: int = Time.get_ticks_usec()
	for level in level_keys():
		for cell in (_layers[level] as TileMapLayer).get_used_cells():
			field.bucket_for(cell, level)
	var warm_us: int = Time.get_ticks_usec() - warm_t0
	var mints_before: int = _minted_light_alts.size()
	var b0: int = Time.get_ticks_usec()
	_apply_light_field_pass(field)
	var b_us: int = Time.get_ticks_usec() - b0
	var seen: int = _apply_cells_seen
	var written: int = _apply_cells_written
	var minted: int = _minted_light_alts.size() - mints_before
	var c0: int = Time.get_ticks_usec()
	_apply_light_field_pass(field)
	var c_us: int = Time.get_ticks_usec() - c0
	print("[APPLY-SPLIT] %d cells · derivation %.1f ms · apply %.1f ms (%d written, %d minted) · walk-only %.1f ms · writes+mints %.1f ms"
		% [seen, float(warm_us) / 1000.0, float(b_us) / 1000.0, written, minted,
		float(c_us) / 1000.0, float(b_us - c_us) / 1000.0])
	if _apply_cells_written != 0:
		push_warning("[APPLY-SPLIT] the walk-only pass wrote %d cell(s) — it is not walk-only, so the split above is not trustworthy"
			% _apply_cells_written)


func _apply_light_field_pass(field) -> void:
	_apply_cells_seen = 0
	_apply_cells_written = 0
	_placed_by_gu.clear()
	_placed_index.clear()
	for level in level_keys():
		_apply_light_to_layer(_layers[level], level, field, true)
	## Occluded cells are ERASED right now (OCC-21) and will come back from
	## _ghosted_cells records — retarget each stored alternative so releasing
	## occlusion cannot resurrect a stale bucket.
	for cell in _ghosted_cells.keys():
		for record in _ghosted_cells[cell]:
			var flipped: bool = decode_light_flipped(record["prev_alt"])
			var ghost_soot: int = field.face_soot_code(cell, record["level"])
			## PERF-P2: the cell is erased right now, but un-ghosting restores it
			## from this record — and the soot plane is where its scorch lives.
			_write_cell_soot(int(record["level"]), cell, ghost_soot)
			## PERF-P3: and its light, for the same reason. §5.1 named the ghost
			## store as the reader with real teeth — it remembers `prev_alt` to
			## restore a cell EXACTLY. Once the id stops carrying the bucket, the
			## record alone no longer describes the cell, so the plane has to be
			## kept in step here or an un-ghosted cell comes back lit by whatever
			## the plane last happened to hold.
			var ghost_bucket: int = field.bucket_for(cell, record["level"])
			_write_cell_bucket(int(record["level"]), cell, ghost_bucket)
			record["prev_alt"] = encode_light_alt(ghost_bucket, flipped)
	## PERF-P2 — ONE upload per level per repaint, at the end, after the ghost
	## records have had their say. Never one upload per cell.
	flush_cell_soot()
	## PERF-10 — this pass repainted every cell there is, so it repainted every
	## cell the accumulator names. `apply_light_field_gus()` deliberately does NOT
	## do this: it covers some GUs, and the staleness outside them is exactly what
	## the accumulator exists to remember.
	if field.has_method("clear_stale_accum"):
		field.clear_stale_accum()
	_externally_written.clear()


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
## `soot_lighten` (W-SOOT-01, 2026-08-19) tones every face DOWN by that many
## rungs before writing, clamped at clean — the same ladder
## DetonationChoreographer._lightened() walks for the blast's soot fade.
##
## It exists so soot can arrive AFTER the fact without arriving suddenly, which
## is the Director's own condition: *"a fuligem pode ser processada depois do
## fato, desde que apareça com fade in, e não de repente."* Stepping it from
## `steps-1` down to 0 fades soot in from a field built ONCE, instead of
## rebuilding the field per step — the rebuild is the expensive half (a map-wide
## soot snapshot), and doing it N times would cost more than not deferring at all.
## Cells actually written by the last scoped apply. The CPU inside this function
## is not the whole cost — every `set_cell` also makes the TileMapLayer resubmit,
## and that lands in the frame outside any profiler scope here. Counting the
## writes is how that invisible half gets a number.
var _scoped_writes: int = 0

## How many TileSet ALTERNATIVES were actually created. `create_alternative_tile`
## rebuilds the TileSet, and that cost lands in the frame outside any profiler
## scope in this file — the suspected other half of the shot's impact frame
## (258 ms of measured work inside a 522 ms frame).
var _alts_minted: int = 0
## INFILTRAITOR_MINT_TRACE=1 prints every alternative actually created. The count
## alone cannot say WHY a warm missed; the (coords, alt) pair can.
var _mint_trace: bool = OS.get_environment("INFILTRAITOR_MINT_TRACE") == "1"


## PERF-10 §10.2 — `_placed_by_gu` MEMBERSHIP, in O(1).
##
## The index was rebuilt only by the full pass and only ever READ by the scoped
## one, so a cell placed since that pass — a crater floor revealed by a blast is
## exactly that — was invisible to every scoped apply. The residue probe measured
## 92 of 119 disagreeing cells as never-indexed. Maintaining it wherever cells are
## visited is what stops that class existing, and the membership set is what makes
## an incremental add cheap enough to do unconditionally.
func _index_placed(level: int, cell: Vector2i) -> void:
	var key := Vector3i(cell.x, cell.y, level)
	if _placed_index.has(key):
		return
	_placed_index[key] = true
	var gu := Vector2i(cell.x >> 3, cell.y >> 3)
	if not _placed_by_gu.has(gu):
		_placed_by_gu[gu] = []
	_placed_by_gu[gu].append({"level": level, "cell": cell})


## PERF-10 — THE APPLY, DRIVEN BY THE FIELD'S OWN STALE SET.
##
## Identical per-cell body to `_apply_light_to_layer()`; the only difference is
## which cells it visits. §10.1 priced the map-wide pass at ~610 ms of walk to
## write 96 cells of 205 384 — the writes and the mints together came to 37 ms,
## and -3 ms on a second sample. The walk IS the stall, so the fix is to walk the
## work instead of the board.
##
## Correctness rests on one property, and it already has a standing gate:
## `VoxelLightField._stale_cells()` erases exactly the cache entries the incoming
## occupancy and soot invalidate, so a cell whose value CHANGES must have been
## invalidated — otherwise `bucket_for()` would have returned the old cached
## number and `INFILTRAITOR_LIGHT_EQUIV_PROBE` would not report `0 differ`. So
## **changed implies in the set**, which is what driving an apply from it needs.
##
## ⚠️ It indexes what it visits (see `_index_placed()`), because a cell-driven
## pass never rebuilds `_placed_by_gu` the way the map-wide one does, and letting
## the index rot would trade this stall for §10.2's defect.
func apply_light_field_cells(field, cells: Dictionary) -> void:
	if LIGHT_DISABLED:
		return
	if field == null:
		return
	_apply_cells_seen = 0
	_apply_cells_written = 0
	## The field's stale set plus every cell written behind its back. Unioned into
	## a local so the caller's dictionary is never mutated.
	var visit: Dictionary = {}
	for k in cells.keys():
		visit[k] = true
	for k in _externally_written.keys():
		visit[k] = true
	for key in visit.keys():
		var level: int = key.z
		var layer: TileMapLayer = get_layer(level)
		if layer == null:
			continue
		var cell := Vector2i(key.x, key.y)
		var source_id: int = layer.get_cell_source_id(cell)
		if source_id == -1:
			continue   ## erased — destroyed, or ghosted and handled below
		_apply_cells_seen += 1
		_index_placed(level, cell)
		var prev_alt: int = layer.get_cell_alternative_tile(cell)
		var full_soot: int = field.face_soot_code(cell, level)
		## PERF-P2/P3 — both writes BEFORE the alt comparison, for the reason
		## `apply_light_field_gus()` spells out: once soot and bucket left the
		## alternative id, a change in either leaves `alt_id == prev_alt`.
		_write_cell_soot(level, cell, full_soot)
		var full_bucket: int = field.bucket_for(cell, level)
		_write_cell_bucket(level, cell, full_bucket)
		var alt_id: int = encode_light_alt(full_bucket,
				decode_light_flipped(prev_alt))
		if alt_id == prev_alt:
			continue
		var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
		_ensure_light_alt(source_id, atlas_coords, alt_id)
		layer.set_cell(cell, source_id, atlas_coords, alt_id)
		_apply_cells_written += 1
	## Ghost records, restricted to the same set. A record outside it keeps its
	## stored alternative, and that is correct by the same property the walk rests
	## on: a bucket that did not change needs no retarget.
	for gcell in _ghosted_cells.keys():
		for record in _ghosted_cells[gcell]:
			var glevel: int = int(record["level"])
			if not visit.has(Vector3i(gcell.x, gcell.y, glevel)):
				continue
			var flipped: bool = decode_light_flipped(record["prev_alt"])
			var ghost_soot: int = field.face_soot_code(gcell, glevel)
			_write_cell_soot(glevel, gcell, ghost_soot)
			var ghost_bucket: int = field.bucket_for(gcell, glevel)
			_write_cell_bucket(glevel, gcell, ghost_bucket)
			record["prev_alt"] = encode_light_alt(ghost_bucket, flipped)
	flush_cell_soot()
	field.clear_stale_accum()
	_externally_written.clear()


func apply_light_field_gus(field, gus: Array, soot_lighten: int = 0) -> void:
	if LIGHT_DISABLED:
		return
	if field == null or gus.is_empty():
		return
	_scoped_writes = 0
	_alts_minted = 0
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
			var soot_code: int = field.face_soot_code(cell, level)
			if soot_lighten > 0:
				soot_code = VoxelLightField.encode_face_soot(_lighten_faces(
					VoxelLightField.decode_face_soot(soot_code), soot_lighten))
			## PERF-P2 — BEFORE the alt comparison, deliberately. Once soot stops
			## riding in the alternative id, a soot-only change leaves `alt_id`
			## equal to `prev_alt`, and a write placed after the `continue` would
			## be skipped exactly when it is the only thing that changed.
			_write_cell_soot(level, cell, soot_code)
			## PERF-P3 — the bucket, for the identical reason and in the same
			## place: once it leaves the alternative id, a light-only change
			## leaves `alt_id` equal to `prev_alt` and the `continue` below
			## fires. The write has to be on this side of it.
			var bucket: int = field.bucket_for(cell, level)
			_write_cell_bucket(level, cell, bucket)
			var alt_id: int = encode_light_alt(bucket,
					decode_light_flipped(prev_alt))
			if alt_id == prev_alt:
				continue
			var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
			_ensure_light_alt(source_id, atlas_coords, alt_id)
			layer.set_cell(cell, source_id, atlas_coords, alt_id)
			_scoped_writes += 1
	## Ghosted cells inside the affected GUs: retarget their stored alternative
	## too (same reasoning as apply_light_field()'s ghost retarget loop), so
	## un-ghosting later shows the bucket this toggle produced, not a stale one.
	for cell in _ghosted_cells.keys():
		if not gu_set.has(Vector2i(cell.x >> 3, cell.y >> 3)):
			continue
		for record in _ghosted_cells[cell]:
			var flipped: bool = decode_light_flipped(record["prev_alt"])
			var ghost_soot: int = field.face_soot_code(cell, record["level"])
			## PERF-P2: the cell is erased right now, but un-ghosting restores it
			## from this record — and the soot plane is where its scorch lives.
			_write_cell_soot(int(record["level"]), cell, ghost_soot)
			## PERF-P3: and its light, for the same reason. §5.1 named the ghost
			## store as the reader with real teeth — it remembers `prev_alt` to
			## restore a cell EXACTLY. Once the id stops carrying the bucket, the
			## record alone no longer describes the cell, so the plane has to be
			## kept in step here or an un-ghosted cell comes back lit by whatever
			## the plane last happened to hold.
			var ghost_bucket: int = field.bucket_for(cell, record["level"])
			_write_cell_bucket(int(record["level"]), cell, ghost_bucket)
			record["prev_alt"] = encode_light_alt(ghost_bucket, flipped)
	flush_cell_soot()


## W-PRECOOK — mint every TileSet alternative the given field would need inside
## `gus`, WITHOUT writing a single cell. Returns how many were actually created.
##
## This is the whole point of the shot's pre-production: `create_alternative_tile()`
## rebuilds the TileSet and is the measured cost of firing (412 calls, ~264 ms
## outside any profiler scope in the shot). Doing them during the aim window
## leaves the impact frame with plain `set_cell()` calls against alternatives
## that already exist.
##
## ⚠️ MINTS IN ONE FRAME, AND SPREADING IT IS THE WRONG INSTINCT.
##
## `create_alternative_tile()` makes the TileSet rebuild, and MEASURED
## 2026-08-19 that rebuild is charged ONCE PER FRAME THAT MINTS, not once per
## mint. A first version budgeted 4 ms and yielded — 442 alternatives spread over
## ~11 frames, and every one of those frames cost ~205 ms instead of 16. Roughly
## 2 s of stutter to avoid a single 200 ms one.
##
## The same measurement explains two earlier mysteries at a stroke: the impact
## frame's unaccounted ~264 ms (412 mints, one rebuild) and why the soot fade was
## catastrophic (four steps, each re-minting in its own frames, each paying a
## rebuild). So the rule for this whole subsystem is: mint as much as possible in
## as FEW frames as possible, ideally one.
##
## IT DOES NOT YIELD, AND SO IT CANNOT BE CANCELLED. An earlier signature took a
## `SceneTree` and a `still_valid` Callable, and its doc claimed cancellation was
## "still honoured" — it was not, and could not be: once the budgeted, frame-
## spread version was removed (it was the regression above) there is no point
## inside this function at which a caller could interleave. Both parameters were
## dropped rather than left as a promise nothing keeps. Cancellation lives where
## it can actually happen, in Room._run_shot_precook()'s token checks around
## this call.
func warm_light_alts_for_gus(field, gus: Array, extra_placements: Array = []) -> int:
	if LIGHT_DISABLED:
		return 0
	if field == null or gus.is_empty():
		return 0
	var minted: int = 0
	for gu in gus:
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
				continue
			var prev_alt: int = layer.get_cell_alternative_tile(cell)
			var alt_id: int = encode_light_alt(field.bucket_for(cell, level),
					decode_light_flipped(prev_alt))
			if alt_id == prev_alt:
				continue
			var before: int = _alts_minted
			_ensure_light_alt(source_id, layer.get_cell_atlas_coords(cell), alt_id)
			minted += _alts_minted - before

	## ⚠️ THE LOOP ABOVE CANNOT SEE THE ATOMS THE SHOT IS ABOUT TO CREATE.
	##
	## It reads the coords each cell has NOW, and a DENTED or CRACKED voxel does
	## not keep them — it moves to a damage-VARIANT atom, whose light alternative
	## is therefore minted for the first time on the frame the wall breaks.
	## Measured 2026-08-19: 17 such mints on the impact frame and 19 more on the
	## soot pass, and because the TileSet rebuild is charged once per FRAME THAT
	## MINTS, those 17 cost the same rebuild 412 would have.
	##
	## `extra_placements` is that future, resolved by the caller through
	## VoxelRenderer.resolve_damage_swap_for() from a
	## BlastCalculator.plan_point_impact() entry:
	## {"level": int, "cell": Vector2i, "source_id": int, "atlas_coords": Vector2i}.
	##
	## `flipped` is FALSE by construction rather than by assumption:
	## apply_damage_voxel_swap() places the variant at alternative 0, so the
	## repaint that follows it reads prev_alt = 0 and carries no flip.
	for placement in extra_placements:
		var plevel: int = int(placement["level"])
		var pcell: Vector2i = placement["cell"]
		var palt: int = encode_light_alt(field.bucket_for(pcell, plevel), false)
		var pbefore: int = _alts_minted
		_ensure_light_alt(int(placement["source_id"]), placement["atlas_coords"], palt)
		minted += _alts_minted - pbefore
	return minted


## One rung down the soot ladder: every face `by` tones fainter, clamped at
## clean. A face already clean stays clean, so a cell only fades on the faces it
## is actually going to be dirty on. Deliberately identical in behaviour to
## DetonationChoreographer._lightened() — the blast and the firearm must fade the
## same way or the two look like different materials.
static func _lighten_faces(faces: Vector3i, by: int) -> Vector3i:
	var clean: int = BlastCalculator.FACE_SOOT_CLEAN
	return Vector3i(mini(faces.x + by, clean), mini(faces.y + by, clean),
		mini(faces.z + by, clean))


func _apply_light_to_layer(layer: TileMapLayer, level: int, field, do_index: bool = false) -> void:
	for cell in layer.get_used_cells():
		_apply_cells_seen += 1
		if do_index:
			_index_placed(level, cell)
		var prev_alt: int = layer.get_cell_alternative_tile(cell)
		## FACE-SOOT-01: see apply_light_field_gus() — compare the whole id.
		var full_soot: int = field.face_soot_code(cell, level)
		## PERF-P2 — before the comparison, for apply_light_field_gus()'s reason.
		_write_cell_soot(level, cell, full_soot)
		## PERF-P3 — see apply_light_field_gus(): before the comparison.
		var full_bucket: int = field.bucket_for(cell, level)
		_write_cell_bucket(level, cell, full_bucket)
		var alt_id: int = encode_light_alt(full_bucket,
				decode_light_flipped(prev_alt))
		if alt_id == prev_alt:
			continue
		var source_id: int = layer.get_cell_source_id(cell)
		var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
		## VL-03-PERF: mint this bucket's alternative lazily, only now that a cell
		## actually needs it.
		_ensure_light_alt(source_id, atlas_coords, alt_id)
		layer.set_cell(cell, source_id, atlas_coords, alt_id)
		_apply_cells_written += 1


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
				_process_dirty_slice_voxel(voxel, slice, edge)

		# Clear all dirty flags in slice
		slice.clear_all_dirty()

	## PERF-02 A1: one upload per page this batch composited into, instead of
	## one per composited atom.
	flush_damage_composite_pages()


## PERF-01: the per-voxel body process_dirty() runs for every dirty voxel in
## a slice — extracted so process_dirty_async() can share the exact same
## logic instead of a second copy drifting from this one over time.
func _process_dirty_slice_voxel(voxel: Voxel, slice: Slice, edge) -> void:
	# Update cell state based on voxel visibility
	if voxel.visible:
		## D-ARCH-01: Try pre-baked damage variant swap first (single-frame ID swap)
		if voxel.damage_state != Voxel.DamageState.INTACT and _damage_variant_registry != null:
			if apply_damage_voxel_swap(voxel, slice, voxel.level):
				return  # Swap succeeded, no need for fallback
		
		## Fallback: render via material lookup (original behavior)
		var voxel_xy = Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
		## GLASS G-D9 — the material is per-level on a banded slice.
		var vmat := slice.material_at(voxel.level - GeometryCoords.storey_level_base(slice.start_storey))
		var render_material := damage_variant_material(vmat, voxel.damage_state, voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant)
		var glass_mask: int = 0
		if vmat == "glass":
			glass_mask = _glass_face_mask(voxel.grid_pos, voxel.level, slice.face, _slice_top_glass_level(slice))
		_set_voxel_cell(voxel.grid_pos, voxel.level, render_material, edge, voxel_xy,
			slice.face, false, "", BakePolicyClass.SurfaceClass.SLICE, true, glass_mask)
	else:
		## GLASS G1 — a destroyed glass voxel is erased from the glass pane layer,
		## not the opaque layer it never lived on. Same `already_gone` guard and
		## `voxel_destroyed` contract as the opaque branch below. G-D9: gate on the
		## per-level material, not the slice base — a brick-band voxel takes the
		## ordinary opaque path below.
		var vmat_gone := slice.material_at(voxel.level - GeometryCoords.storey_level_base(slice.start_storey))
		if vmat_gone == "glass" and _glass_layers.has(voxel.level):
			var gpane := _glass_layers[voxel.level] as TileMapLayer
			var g_gone: bool = gpane.get_cell_source_id(voxel.grid_pos) == -1
			gpane.erase_cell(voxel.grid_pos)
			note_external_write(voxel.level, voxel.grid_pos)
			forget_ghost_record(voxel.grid_pos, voxel.level)
			if not g_gone:
				voxel_destroyed.emit(voxel.grid_pos, voxel.level, vmat_gone)
			return
		# Clear cell
		if _layers.has(voxel.level):
			## ⚠️ THE SIGNAL MEANS "A VOXEL JUST DISAPPEARED", NOT "WE PROCESSED A
			## DESTROYED VOXEL", and conflating the two cost a real bug.
			##
			## Measured 2026-08-19, on the Director's report that firing a shot
			## re-smoked every voxel two earlier grenades had destroyed: two
			## grenades dispatched 0 `voxel_destroyed` (the choreographer paints
			## its own cells and never emits), and the next shot dispatched 498 —
			## while destroying 5 voxels of its own. The blast's voxels were still
			## flagged dirty, the shot's pass is the only unfiltered one in the
			## game, and it re-emitted for every one of them.
			##
			## The flag leak is fixed at its source too (see
			## TestZoneController's commit site), but this guard is what makes the
			## whole CLASS impossible: re-processing an already-erased cell is now
			## a no-op instead of a second explosion of VFX, whatever leaves a
			## stale flag in future.
			var _vlayer: TileMapLayer = _layers[voxel.level]
			var already_gone: bool = _vlayer.get_cell_source_id(voxel.grid_pos) == -1
			_vlayer.erase_cell(voxel.grid_pos)
			note_external_write(voxel.level, voxel.grid_pos)
			## See forget_ghost_record(): a destroyed voxel must not be restorable.
			forget_ghost_record(voxel.grid_pos, voxel.level)
			if not already_gone:
				voxel_destroyed.emit(voxel.grid_pos, voxel.level, slice.material)


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
			if voxel.dirty:
				_process_dirty_slab_voxel(voxel, slab, use_solid, is_zoned_floor)

		slab.clear_all_dirty()

	## PERF-02 A1: see process_dirty()'s own flush.
	flush_damage_composite_pages()


## PERF-01: the per-voxel body process_dirty_slabs() runs for every dirty
## voxel in a slab — extracted so process_dirty_slabs_async() can share the
## exact same logic instead of a second copy drifting from this one over
## time. `use_solid`/`is_zoned_floor` are computed once per slab by the
## caller (constant across every voxel in it), not re-derived per voxel.
func _process_dirty_slab_voxel(voxel: Voxel, slab: Slab, use_solid: bool, is_zoned_floor: bool) -> void:
	if voxel.visible:
		## D-ARCH-01: Try pre-baked damage variant swap first (single-frame ID swap)
		if voxel.damage_state != Voxel.DamageState.INTACT and _damage_variant_registry != null:
			if apply_damage_voxel_swap(voxel, slab, voxel.level):
				return  # Swap succeeded, no need for fallback
		
		## Fallback: render via material lookup (original behavior)
		if use_solid or is_zoned_floor:
			var flat_baked: bool = slab.role == Slab.Role.CEILING or is_zoned_floor
			## D22: the substitution tags CEILING/INTERIOR exactly like a
			## wall (apply_container_damage).
			var render_material := damage_variant_material(slab.material, voxel.damage_state, voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant)
			## FLOOR-DENT-01: a zoned floor routes its dents to the carved-TOP
			## asset. D34/E-SEAM-02: named by the zone's REAL material now, so
			## a concrete floor wears the concrete dent — materials with no
			## decal art of their own still fall back to earth, inside
			## floor_damage_material().
			if is_zoned_floor:
				var floor_damaged := floor_damage_material(slab.material,
					voxel.damage_state, voxel.damage_is_blast,
					voxel.damage_carved_side, voxel.damage_variant)
				if floor_damaged != "":
					render_material = floor_damaged
			## D33 Part 3c: pass slab.material (the REAL zone) separately from
			## render_material — the two still differ whenever the earth
			## fallback fires; _set_voxel_cell()'s own comment on
			## `zone_material` explains why resolve_flat() needs the real one.
			_set_voxel_cell(voxel.grid_pos, voxel.level, render_material,
					null, voxel.grid_pos - slab.texture_anchor, 0, flat_baked,
					slab.material if is_zoned_floor else "")
		else:
			## FLOOR-DENT-01: a damaged floor voxel renders its carved
			## variant instead of a pristine earth variant — this branch
			## was unreachable for damage before (craters only destroyed)
			## and would silently repaint a dent as intact ground.
			## This branch is the UNZONED floor (slab.material == "earth"), so
			## D34's real-material naming resolves to the earth family anyway —
			## passed explicitly rather than assumed, so a future zoned case
			## reaching here names itself correctly instead of silently
			## rendering as dirt.
			var earth_material := floor_damage_material(slab.material,
				voxel.damage_state, voxel.damage_is_blast,
				voxel.damage_carved_side, voxel.damage_variant)
			if earth_material == "":
				earth_material = "earth_%d" % EarthVariantSelector.variant_for(
					voxel.grid_pos, relative_level(voxel.level))
			_set_voxel_cell(voxel.grid_pos, voxel.level, earth_material)
	else:
		## GLASS G1 — a glass INTERIOR slab voxel (a glazed partition — the only
		## slab kind G1 routes to the glass pane layer; roofs and glazed floor
		## zones stay opaque) is erased from the pane layer, mirroring the slice.
		var glass_on_pane: bool = slab.material == "glass" \
			and not (slab.role == Slab.Role.CEILING or is_zoned_floor) \
			and _glass_layers.has(voxel.level)
		if glass_on_pane:
			var gpane := _glass_layers[voxel.level] as TileMapLayer
			var g_gone: bool = gpane.get_cell_source_id(voxel.grid_pos) == -1
			gpane.erase_cell(voxel.grid_pos)
			note_external_write(voxel.level, voxel.grid_pos)
			forget_ghost_record(voxel.grid_pos, voxel.level)
			if not g_gone:
				voxel_destroyed.emit(voxel.grid_pos, voxel.level, slab.material)
			return
		var layer := get_layer(voxel.level)
		if layer != null:
			## Same idempotence guard as the slice path — see its note. A floor
			## or roof voxel erased twice is one destruction, not two.
			var was_there: bool = layer.get_cell_source_id(voxel.grid_pos) != -1
			layer.erase_cell(voxel.grid_pos)
			note_external_write(voxel.level, voxel.grid_pos)
			## See forget_ghost_record(): a destroyed voxel must not be restorable.
			forget_ghost_record(voxel.grid_pos, voxel.level)
			if was_there:
				voxel_destroyed.emit(voxel.grid_pos, voxel.level, slab.material)


## D11 — how long one async render batch may run before yielding a frame.
##
## This REPLACES the old `voxels_per_frame = 150` count, and the reason is
## measured: that number was chosen when a voxel cost ~3.7ms, and PERF-01/02
## took it to ~0.9ms without the count following. The result was the opposite
## of a spread — the wall pass finished inside a single frame without ever
## yielding, and the slab pass ran ONE 135ms batch, i.e. a ~7fps frame. That
## is exactly the "engasgada" the Director reported.
##
## A time budget adapts to whatever a voxel costs today, and to the fact that
## voxel costs are wildly uneven (erasing a DESTROYED voxel is nearly free;
## compositing a DENTED one runs a decal paste). The NUMBER itself is measured,
## not the obvious "half a 60fps frame" guess (8ms) it started at — D11 also
## does per-voxel-STATE stages (DESTROYED, then DENTED, then the rest), and
## real profiling on the dev capture harness found each yield disproportionately
## expensive whenever a batch had composited a damage-composite atlas page
## (flush_damage_composite_pages() re-uploads the touched page's whole texture
## before the frame draws — cheap CPU-side per PERF-02's own numbers, but the
## frame that then renders it was measured far slower than an untouched one on
## this harness). An 8ms budget forces a yield roughly every 1-2 decal-heavy
## voxels, which multiplies that per-yield cost by voxel count instead of
## amortizing it. Measured end-to-end detonation wall-clock at several budgets
## on the same real blast: 8ms → 8940ms, 40ms → 2674ms, 50ms → 2663ms,
## 100ms → 1375ms, 200ms → 995ms, effectively-unbounded (no in-stage yield at
## all) → 853ms. 200ms was chosen off that curve: it already sits within ~8%
## of the unbounded floor (i.e. batching finer buys almost nothing further),
## while still yielding when a stage's total work genuinely needs it — the
## measured blast triggered exactly one yield at this setting, not zero — so a
## much larger future blast still gets spread across multiple frames instead of
## one long block, which is the hard requirement PERF-01 shipped this async
## path to satisfy in the first place.
var render_frame_budget_ms: float = 200.0

## Async counterpart to process_dirty(): identical per-voxel logic
## (_process_dirty_slice_voxel()), but yields a frame every
## `render_frame_budget_ms` of wall time instead of running the whole dirty set
## in one synchronous call. process_dirty() itself is untouched and stays
## synchronous — _tic_voxel_system() (small per-step deltas),
## _reapply_base_damage() (map rebuild/rotation) and
## slab_render_selftest.gd all call it expecting immediate completion, and
## none of them showed the multi-second stall this exists to avoid. Only
## TestZoneController.detonate_active() and
## WeaponBenchController.fire_active() — the two big-batch, player-triggered
## paths — use this one.
## D11 — `states` filters which DamageStates this pass renders, so a caller can
## run the same dirty set in stages (destroyed first, then dented, then the
## rest) instead of one undifferentiated sweep. Empty = everything, which is
## the pre-D11 behaviour and what every non-staged caller still gets.
##
## Dirty flags are cleared PER VOXEL when a filter is active — `clear_all_dirty()`
## would drop the flags of the voxels this stage deliberately skipped, and the
## next stage would then find nothing to do.
func process_dirty_async(registry: EdgeRegistry, states: Array = []) -> void:
	var dirty_slices := registry.dirty_slices()
	if dirty_slices.is_empty():
		return

	var filtered: bool = not states.is_empty()
	var batch_start: int = Time.get_ticks_usec()
	for slice in dirty_slices:
		var edge = registry.get_edge(slice.edge_id) if registry.has_method("get_edge") else null
		for voxel in slice.voxels:
			if voxel.dirty and (not filtered or states.has(voxel.damage_state)):
				_process_dirty_slice_voxel(voxel, slice, edge)
				if filtered:
					voxel.clear_dirty()
				if float(Time.get_ticks_usec() - batch_start) / 1000.0 >= render_frame_budget_ms:
					## PERF-02 A1: flush BEFORE yielding, not only at the end —
					## this pass is about to let a frame draw, and a composite
					## slot whose page hasn't been uploaded yet samples
					## transparent. Batching to the end of the whole pass would
					## make every damaged voxel invisible for the ~2s the async
					## spread takes, trading a freeze for a hole. One upload per
					## touched page per frame still collapses the 197 measured
					## uploads to a handful.
					flush_damage_composite_pages()
					await get_tree().process_frame
					## Restart the clock AFTER the frame wait, so the wait
					## itself is not charged against the next batch's budget.
					batch_start = Time.get_ticks_usec()
		## D11: only safe when this pass took every dirty voxel — see the
		## per-voxel clear above for the filtered case.
		if not filtered:
			slice.clear_all_dirty()

	flush_damage_composite_pages()


## Async counterpart to process_dirty_slabs() — see process_dirty_async()'s
## doc for why this is a second entry point rather than a parameter on the
## synchronous original.
func process_dirty_slabs_async(registry: SlabRegistry, states: Array = []) -> void:
	var dirty_slabs := registry.dirty_slabs()
	if dirty_slabs.is_empty():
		return

	if _bake_config == null:
		_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var filtered: bool = not states.is_empty()
	var batch_start: int = Time.get_ticks_usec()
	for slab in dirty_slabs:
		var use_solid: bool = slab.role != Slab.Role.FLOOR
		var is_zoned_floor: bool = (not use_solid) and slab.material != "earth" \
				and _bake_config != null and _bake_config.enabled
		for voxel in slab.voxels:
			if voxel.dirty and (not filtered or states.has(voxel.damage_state)):
				_process_dirty_slab_voxel(voxel, slab, use_solid, is_zoned_floor)
				if filtered:
					voxel.clear_dirty()
				if float(Time.get_ticks_usec() - batch_start) / 1000.0 >= render_frame_budget_ms:
					## PERF-02 A1: see process_dirty_async()'s own pre-yield flush.
					flush_damage_composite_pages()
					await get_tree().process_frame
					batch_start = Time.get_ticks_usec()
		## D11: see process_dirty_async()'s own note.
		if not filtered:
			slab.clear_all_dirty()

	flush_damage_composite_pages()


## Ensure layers exist up to storey count (E1 equation from SLICE-00)
## Build one properly-configured voxel TileMapLayer node for a given level —
## positive (wall) or negative (D17: floor/background). Shared by
## _ensure_voxel_layers() and _ensure_negative_voxel_layer() so the position/
## z-index formula has exactly one owner; the two callers differ only in
## WHERE they file the result (_voxel_layers vs _negative_voxel_layers),
## never in HOW a layer is built.
## FACE-READ-01 — the per-face shading material.
##
## ⚠️ PERF-P2 (2026-08-22): this used to be ONE material shared by every voxel
## layer, on the stated grounds that *"the shader is stateless (its uniforms are
## global tuning, not per-layer)"*. That stopped being true the moment the SOOT
## CODE moved out of the alternative id and into a per-LEVEL data texture — the
## texture IS a per-layer uniform. So there is now one material per level, all
## sharing the same compiled Shader resource; the tuning uniforms keep their
## defaults on every one of them.
var _layer_materials: Dictionary = {}   ## level -> ShaderMaterial


## PERF-P2 — the per-cell soot plane: one R8 texture per LEVEL, one texel per
## cell, carrying the same 0..124 base-5 face code the alternative's alpha used
## to carry (top*25 + se*5 + sw, 4 = clean per face, 124 = fully clean).
##
## WHY A TEXTURE AT ALL, and it is not "because textures are fast": a
## TileMapLayer has exactly one per-cell channel — the alternative id — and
## every distinct (bucket, soot) pair spent one. PERFORMANCE_MASTER_PLAN §1.4:
## up to 3 000 alternatives per tile, each a `create_alternative_tile()` and a
## TileSet rebuild charged once per FRAME THAT MINTS.
##
## Sized by a CONSTANT and loud-failing past it (B6) rather than growing: a
## silently-clamped cell would render clean soot with no error, which is exactly
## the failure mode this project keeps paying for. 512 covers a 64x64 GU board;
## PLAYGROUND is 46x24 with its buffer.
## ⚠️ CELLS GO NEGATIVE, and the first version of this plane did not know that.
##
## The map's BUFFER (Rule 7 — applied only in MapCompiler) puts real geometry at
## negative voxel coordinates: measured by making the shader print its recovered
## cell, the fragments along every GU seam resolve to cells like (-8, 8). Indexed
## from zero, ~110 000 fragments of a 921 600-pixel frame — about 12% — fell
## outside the plane and silently took the "clean" fallback, which is invisible
## exactly until something near them is sooty. That is the shape of bug this
## project keeps paying for, and it shipped in PERF-P2.
##
## So the plane carries an ORIGIN: everything indexes `cell + ORIGIN`, and the
## shader is passed the same offset.
## PERF-P3 — the G-channel value meaning "no bucket was ever written here".
## Deliberately outside 0..LIGHT_BUCKET_COUNT-1 so it can never be mistaken for a
## real bucket; the shader clamps it to full-lit for rendering.
const BUCKET_UNWRITTEN: int = 255
const SOOT_PLANE_ORIGIN: Vector2i = Vector2i(64, 64)
const SOOT_TEX_SIZE: int = 512
## PERF-P3: FORMAT_RG8 — R = the per-face soot code (0..124), G = the light
## bucket (0..11). One texel per cell, one texture per level. Both writers do a
## read-modify-write so neither channel can erase the other.
var _soot_images: Dictionary = {}     ## level -> Image (FORMAT_RG8)
var _soot_textures: Dictionary = {}   ## level -> ImageTexture
var _soot_dirty: Dictionary = {}      ## level -> true, cleared by flush_cell_soot()
var _soot_out_of_range_reported: bool = false


func _soot_image_for(level: int) -> Image:
	if _soot_images.has(level):
		return _soot_images[level]
	var img := Image.create(SOOT_TEX_SIZE, SOOT_TEX_SIZE, false, Image.FORMAT_RG8)
	## R = CLEAN, not zero: zero soot is "ring 0 on all three faces", the darkest
	## scorch there is, so an unvisited cell would come up black.
	##
	## G = **BUCKET_UNWRITTEN (255), a SENTINEL, not bucket 11.** Filling with 11
	## would render an unwritten cell full-lit, which is the correct PICTURE and a
	## terrible diagnostic: "never written" and "genuinely full lit" would be the
	## same byte, and this project has now paid twice for a fallback that folds a
	## missing value onto a legitimate one (§3.3's `hint_default_white` reading as
	## clean; PERF-P2 shipping ~110 000 fragments silently taking the clean
	## fallback). The shader still CLAMPS 255 down to 11, so the picture is
	## unchanged — but the plane, and debug paint mode 3, can now tell them apart.
	img.fill(Color8(FACE_SOOT_CODE_CLEAN, BUCKET_UNWRITTEN, 0, 255))
	_soot_images[level] = img
	_soot_textures[level] = ImageTexture.create_from_image(img)
	return img


## Record one cell's soot code. Cheap and idempotent: an unchanged code does not
## dirty the level, so a repaint that only moves light uploads nothing.
func _write_cell_soot(level: int, cell: Vector2i, code: int) -> void:
	var p := cell + SOOT_PLANE_ORIGIN
	if p.x < 0 or p.y < 0 or p.x >= SOOT_TEX_SIZE or p.y >= SOOT_TEX_SIZE:
		if not _soot_out_of_range_reported:
			_soot_out_of_range_reported = true
			push_error("[VoxelRenderer] PERF-P2: cell %s is outside the %dx%d soot plane — raise SOOT_TEX_SIZE" % [cell, SOOT_TEX_SIZE, SOOT_TEX_SIZE])
		return
	var img := _soot_image_for(level)
	var c: int = clampi(code, 0, FACE_SOOT_CODE_CLEAN)
	var was: Color = img.get_pixel(p.x, p.y)
	if was.r8 == c:
		return
	## PERF-P3: G is the light bucket and belongs to `_write_cell_bucket()` —
	## carried through unchanged rather than rewritten, so a soot pass cannot
	## silently relight a cell.
	img.set_pixel(p.x, p.y, Color8(c, was.g8, 0, 255))
	_soot_dirty[level] = true


## PERF-P3 — record one cell's light bucket. The exact counterpart of
## `_write_cell_soot()`, down to the idempotence: an unchanged bucket does not
## dirty the level, so a repaint that only moves soot uploads nothing.
func _write_cell_bucket(level: int, cell: Vector2i, bucket: int) -> void:
	var p := cell + SOOT_PLANE_ORIGIN
	if p.x < 0 or p.y < 0 or p.x >= SOOT_TEX_SIZE or p.y >= SOOT_TEX_SIZE:
		if not _soot_out_of_range_reported:
			_soot_out_of_range_reported = true
			push_error("[VoxelRenderer] PERF-P3: cell %s is outside the %dx%d cell plane — raise SOOT_TEX_SIZE" % [cell, SOOT_TEX_SIZE, SOOT_TEX_SIZE])
		return
	var img := _soot_image_for(level)
	var b: int = clampi(bucket, 0, LIGHT_BUCKET_COUNT - 1)
	var was: Color = img.get_pixel(p.x, p.y)
	if was.g8 == b:
		return
	img.set_pixel(p.x, p.y, Color8(was.r8, b, 0, 255))
	_soot_dirty[level] = true


## What the plane currently says about one cell's light bucket — the counterpart
## of `cell_soot_at()`, and the record P3 leaves in place of the alternative id
## (§5.1: something has to keep BEING that record).
func cell_bucket_at(level: int, cell: Vector2i) -> int:
	var p := cell + SOOT_PLANE_ORIGIN
	if p.x < 0 or p.y < 0 or p.x >= SOOT_TEX_SIZE or p.y >= SOOT_TEX_SIZE:
		return BUCKET_UNWRITTEN
	if not _soot_images.has(level):
		return BUCKET_UNWRITTEN
	return (_soot_images[level] as Image).get_pixel(p.x, p.y).g8


## Upload whatever changed. Returns how many levels were re-uploaded — one
## upload per level per repaint, never one per cell.
## What the plane currently says about one cell. The plan builder needs it to
## decide whether a blast changes a cell's scorch at all, now that the answer is
## no longer visible in the alternative id.
func cell_soot_at(level: int, cell: Vector2i) -> int:
	var p := cell + SOOT_PLANE_ORIGIN
	if p.x < 0 or p.y < 0 or p.x >= SOOT_TEX_SIZE or p.y >= SOOT_TEX_SIZE:
		return FACE_SOOT_CODE_CLEAN
	if not _soot_images.has(level):
		return FACE_SOOT_CODE_CLEAN
	return (_soot_images[level] as Image).get_pixel(p.x, p.y).r8


## PERF-P3 GATE — the cell plane as a WRITE-ANYTHING scratch surface.
##
## `_write_cell_soot()` clamps to the 0..124 soot code space and skips a write
## that does not change the byte. Both are right for soot and wrong for the
## gate: the gate needs codes that are unique per marked cell (so a pixel can
## name the cell it came from) and it needs the fill to actually land. These
## three are the only writers that bypass that, they are only ever called from
## `Room._capture_cell_index_gate()`, and they leave the plane meaningless for
## soot — the gate boot is a throwaway process and never renders a real frame
## after running.
func debug_fill_cell_plane(level: int, value: int) -> void:
	var img := _soot_image_for(level)
	img.fill(Color8(clampi(value, 0, 255), BUCKET_UNWRITTEN, 0, 255))
	_soot_dirty[level] = true


## Drive the shader's gate branch on EVERY level at once. A level whose material
## was never built is not skipped quietly — it cannot have drawn anything, so it
## has no cells for the gate to mark either.
func debug_set_cell_paint(on: bool) -> void:
	debug_set_cell_paint_mode(1.0 if on else 0.0)


## 0 = off (the shipping value), 1 = paint the plane byte at the recovered cell,
## 2 = paint the recovered cell itself (x and y mod 256), 3 = paint the plane's
## G channel, i.e. the LIGHT BUCKET as the SAMPLER sees it (PERF-P3).
func debug_set_cell_paint_mode(mode: float) -> void:
	for level in _layer_materials.keys():
		(_layer_materials[level] as ShaderMaterial).set_shader_parameter(
			"cell_debug_paint", mode)


## The rect one cell's quad occupies in LAYER-LOCAL space, taken from Godot's
## own numbers rather than from the shader's constants.
##
## This is the whole reason the gate can be trusted: `quad_to_map` in the shader
## encodes `map_to_local(cell) + (-16, -28)` as a literal, and a gate that
## checked the shader against that same literal would be checking the shader
## against itself. Here the offset comes from `texture_region_size` and the
## TileData's own `texture_origin`, read off the live TileSet — so if the two
## ever disagree, the gate is what says so.
func debug_cell_quad_rect(level: int, cell: Vector2i) -> Rect2:
	var layer: TileMapLayer = get_layer(level)
	if layer == null:
		return Rect2()
	var source_id: int = layer.get_cell_source_id(cell)
	if source_id == -1:
		return Rect2()
	var src := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null:
		return Rect2()
	var region: Vector2 = Vector2(src.texture_region_size)
	var td: TileData = src.get_tile_data(layer.get_cell_atlas_coords(cell),
			layer.get_cell_alternative_tile(cell))
	var origin: Vector2 = Vector2(td.texture_origin) if td != null else Vector2.ZERO
	return Rect2(layer.map_to_local(cell) - region * 0.5 - origin, region)


## PERF-P3-GATE §3.3 — THE CENSUS THAT TESTS THE GATE ITSELF.
##
## §3.3's residual (floor 81% against walls 96-100%) named one remaining lead: the
## gate's reference rect is a RECONSTRUCTION of Godot's draw rect, and
## `debug_cell_quad_rect()` falls back to `texture_origin` (0, 0) whenever
## `get_tile_data()` returns null. Every tile on this map carries (0, 10), so a
## null is a silent 10 px error — squarely inside the observed 2-8 px spread.
##
## `alt 0` and `TRANSFORM_FLIP_H` are NATIVE Godot tiles that no
## `create_alternative_tile()` ever produced (see `_ensure_light_alt()`), which is
## exactly the population most likely to answer null. This counts it instead of
## arguing about it: how many placed cells resolve TileData, how many do not, and
## which alternative ids the nulls belong to.
func debug_tiledata_census() -> Dictionary:
	var total: int = 0
	var nulls: int = 0
	var null_by_alt: Dictionary = {}
	var origins: Dictionary = {}
	for level in level_keys():
		total += _census_level(_layers[level], null_by_alt, origins)
	for alt in null_by_alt.keys():
		nulls += int(null_by_alt[alt])
	return {"total": total, "nulls": nulls, "null_by_alt": null_by_alt,
		"origins": origins}


func _census_level(layer: TileMapLayer, null_by_alt: Dictionary,
		origins: Dictionary) -> int:
	if layer == null or layer.tile_set == null:
		return 0
	var n: int = 0
	for cell in layer.get_used_cells():
		var source_id: int = layer.get_cell_source_id(cell)
		if source_id == -1:
			continue
		var src := layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if src == null:
			continue
		n += 1
		var alt: int = layer.get_cell_alternative_tile(cell)
		var td: TileData = src.get_tile_data(layer.get_cell_atlas_coords(cell), alt)
		if td == null:
			null_by_alt[alt] = int(null_by_alt.get(alt, 0)) + 1
		else:
			var o: Vector2i = td.texture_origin
			origins[o] = int(origins.get(o, 0)) + 1
	return n


## PERF-P3 — is the bucket actually IN the plane? Histograms what the plane holds
## against what the alternative id says, over every placed cell. Under P3 the id
## carries only the flip, so `alt_bucket` collapses to one value and the PLANE is
## the only record — which is precisely the claim that needs a census rather than
## a reading of the code.
func debug_bucket_census() -> Dictionary:
	var plane_hist: Dictionary = {}
	var alt_hist: Dictionary = {}
	var cells: int = 0
	var disagree: int = 0
	var mism: Array = []
	var layers: Array = []
	for level in level_keys():
		layers.append([level, _layers[level]])
	for pair in layers:
		var level: int = pair[0]
		var layer: TileMapLayer = pair[1]
		if layer == null:
			continue
		for cell in layer.get_used_cells():
			cells += 1
			var b: int = cell_bucket_at(level, cell)
			plane_hist[b] = int(plane_hist.get(b, 0)) + 1
			var ab: int = decode_light_bucket(layer.get_cell_alternative_tile(cell))
			alt_hist[ab] = int(alt_hist.get(ab, 0)) + 1
			## ⚠️ PER-CELL, not just per-histogram. Two histograms can match
			## exactly while every cell in them is wrong — the first version of
			## this census compared only the totals and read as a pass.
			if ab != b:
				disagree += 1
				if mism.size() < 8:
					mism.append({"level": level, "cell": cell, "plane": b, "alt": ab})
	return {"cells": cells, "plane": plane_hist, "alt": alt_hist,
		"disagree": disagree, "samples": mism,
		"levels_with_image": _soot_images.size()}


## PERF-P3 — IS EVERY ATOM ALIGNED TO THE `mod` GRID THE SHADER ASSUMES?
##
## `voxel_face_shading.gdshader` recovers the atom-local pixel as
## `mod(UV / TEXTURE_PIXEL_SIZE, atom_size)`, which is only the atom-local pixel
## if every tile's region starts at a multiple of `atom_size` in the atlas. Godot
## puts a tile at `margins + coords * (texture_region_size + separation)`, so the
## condition is that margins AND (region + separation) are both multiples of
## (32, 36). §3.3 checked the region SIZE and never checked the origin.
##
## A misaligned source makes `mod` WRAP inside a single quad, which splits one
## quad across two recovered cells — and the recovery is supposed to be per-tile.
func debug_atlas_alignment() -> Dictionary:
	var bad: Array = []
	var checked: int = 0
	if _tileset == null:
		return {"checked": 0, "bad": bad}
	for i in range(_tileset.get_source_count()):
		var sid: int = _tileset.get_source_id(i)
		var src := _tileset.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		checked += 1
		var m: Vector2i = src.margins
		var sep: Vector2i = src.separation
		var reg: Vector2i = src.texture_region_size
		var pitch: Vector2i = reg + sep
		var ok: bool = (m.x % 32 == 0 and m.y % 36 == 0
			and pitch.x % 32 == 0 and pitch.y % 36 == 0)
		if not ok and bad.size() < 12:
			bad.append({"source": sid, "margins": m, "separation": sep,
				"region": reg, "pitch": pitch})
	return {"checked": checked, "bad": bad}


## PERF-P3 §12.8 — THE ATLAS ORIGIN OF EVERY TILE THAT ACTUALLY DRAWS.
##
## `debug_atlas_alignment()` above checks the SOURCE's declared `margins` and
## `region + separation`, and concludes every tile must therefore land on the
## shader's `mod(32, 36)` grid. That is an inference, and mode 6 contradicted it
## in the rendered pixel: along one scanline, inside a run where `local.x` ramped
## continuously, `local.y` moved by exactly 8.
##
## So this stops inferring and reads the real thing — per PLACED CELL, the atlas
## origin Godot will use, `margins + coords * (region + separation)` — and
## histograms it modulo the atom. Anything other than (0, 0) is a tile whose
## `mod` wraps INSIDE its own quad, which splits one quad across two recovered
## cells and is exactly the failure the gate has been reporting as a floor
## residual.
##
## Keyed by level, because the whole point is that the floor and the walls differ.
func debug_tile_atlas_origins() -> Dictionary:
	var by_level: Dictionary = {}
	if _tileset == null:
		return by_level
	for level in level_keys():
		var layer: TileMapLayer = _layers[level]
		if layer == null:
			continue
		var hist: Dictionary = {}
		var spans: Dictionary = {}
		var regions: Dictionary = {}
		var texsizes: Dictionary = {}
		for cell in layer.get_used_cells():
			var sid: int = layer.get_cell_source_id(cell)
			if sid == -1:
				continue
			var src := _tileset.get_source(sid) as TileSetAtlasSource
			if src == null:
				continue
			var coords: Vector2i = layer.get_cell_atlas_coords(cell)
			var pitch: Vector2i = src.texture_region_size + src.separation
			var origin: Vector2i = src.margins + coords * pitch
			var key := Vector2i(origin.x % 32, origin.y % 36)
			hist[key] = int(hist.get(key, 0)) + 1
			## §12.8 — HOW MANY ATLAS CELLS THIS TILE SPANS.
			## `texture_region_size` is the size of ONE atlas cell; a tile may span
			## several (`set_tile_size_in_atlas`), and then its DRAWN region is
			## bigger than `atom_size` and the shader's `mod` wraps INSIDE the quad
			## — in the interior, where no boundary test can see it. Never checked.
			var span: Vector2i = src.get_tile_size_in_atlas(coords)
			var skey := Vector2i(span.x, span.y)
			spans[skey] = int(spans.get(skey, 0)) + 1
			## §12.8 — the REGION SIZE the tiles on THIS level actually use, and the
			## texture they use it against. The gate reports both per SOURCE; a level
			## that mixes two of them is invisible there and fatal here, because
			## `atom_size` is one global uniform for every layer.
			var rk := Vector3i(src.texture_region_size.x, src.texture_region_size.y, sid)
			regions[rk] = int(regions.get(rk, 0)) + 1
			var tex: Texture2D = src.texture
			var tk := Vector2i(tex.get_width(), tex.get_height()) if tex != null else Vector2i(-1, -1)
			texsizes[tk] = int(texsizes.get(tk, 0)) + 1
		by_level[level] = {"origin_mod": hist, "atlas_span": spans,
			"regions": regions, "tex_sizes": texsizes}
	return by_level


## PERF-P3 — DOES EACH LAYER'S `layer_origin` UNIFORM STILL MATCH THE LAYER?
##
## It is captured once, in `_build_voxel_layer_node()`, right after `add_child()`.
## Anything that MOVES a layer afterwards — a changed `_visual_grid_offset`, a
## `debug_nudge`, a reparent, a rotation that rebuilds geometry — leaves the
## uniform describing where the layer USED to be, and the shader then recovers a
## cell offset by exactly that drift. A whole layer reading cells that hold no
## voxel is what that looks like on screen.
func debug_layer_origin_drift() -> Array:
	var out: Array = []
	var pairs: Array = []
	for level in level_keys():
		pairs.append([level, _layers[level]])
	for pair in pairs:
		var level: int = pair[0]
		var layer: TileMapLayer = pair[1]
		if layer == null:
			continue
		var mat := layer.material as ShaderMaterial
		if mat == null:
			continue
		var stored = mat.get_shader_parameter("layer_origin")
		var actual: Vector2 = layer.get_global_transform().origin
		var drift: Vector2 = actual - (stored if stored != null else Vector2.ZERO)
		if drift.length() > 0.001:
			out.append({"level": level, "stored": stored, "actual": actual,
				"drift": drift})
	return out


func flush_cell_soot() -> int:
	if _soot_dirty.is_empty():
		return 0
	var n: int = 0
	for level in _soot_dirty.keys():
		var tex = _soot_textures.get(level)
		if tex != null:
			(tex as ImageTexture).update(_soot_images[level])
			n += 1
	_soot_dirty.clear()
	return n


func _get_layer_material(level: int) -> ShaderMaterial:
	if _layer_materials.has(level):
		return _layer_materials[level]
	var shader = load("res://godot/shaders/voxel_face_shading.gdshader")
	if shader == null:
		## B6 loud-fail: silently rendering undifferentiated voxels is exactly
		## the class of bug this project keeps paying for.
		push_error("[VoxelRenderer] FACE-READ-01: voxel_face_shading.gdshader failed to load — voxel faces will render flat")
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_soot_image_for(level)
	mat.set_shader_parameter("cell_soot", _soot_textures[level])
	mat.set_shader_parameter("cell_soot_size", Vector2(float(SOOT_TEX_SIZE), float(SOOT_TEX_SIZE)))
	mat.set_shader_parameter("cell_plane_origin",
		Vector2(float(SOOT_PLANE_ORIGIN.x), float(SOOT_PLANE_ORIGIN.y)))
	## PERF-P3 — the ladder has ONE definition and this is how it reaches the
	## shader. `bucket_luminance` is a `var` (Rule 1), and its existing contract is
	## that changes take effect on the next map load / rotation — unchanged here,
	## because that is also when layer materials are built.
	mat.set_shader_parameter("bucket_lum", PackedFloat32Array(bucket_luminance))
	mat.set_shader_parameter("p3_enabled", 1.0 if P3_CELL_BUCKET else 0.0)
	_layer_materials[level] = mat
	return mat


func _build_voxel_layer_node(level: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = _tileset
	layer.name = "voxel_layer_%d" % level
	## FACE-READ-01: per-face shading, the one seam that reaches BOTH the
	## material-only and the baked tile paths — see the shader's own header.
	layer.material = _get_layer_material(level)

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
		## LEVEL-RENUMBER — RELATIVE, and this is the one the cell census could
		## never have caught: it records what each cell holds, not where its layer
		## sits. Left absolute, every layer would draw eighty steps too high and
		## the whole board would leave the screen, with a byte-identical census.
		## The gate grew a `pos=` column the moment this was found.
		_visual_grid_offset.y + TILE_OFFSET.y + debug_nudge.y 			- GeometryCoords.VOXEL_STEP_PX * float(relative_level(level))
	)

	## §12.12 — TWO INSTRUMENTS FOR THE FRAME'S LAST 15 ms, both default absent.
	##
	## With P3 and P7b in, a fire frame is ~20 ms of which the engine's own
	## `render cpu` is 4.4 and the VFX `_draw()` is 3.5. The rest is unattributed,
	## and the frame probe reports **~12 000 draw calls** — one per rendering
	## quadrant per layer, across 32 layers.
	##
	## `INFILTRAITOR_HIDE_VOXELS=1` prices the layers by removing them, the same
	## way §3.4 priced the VFX. The board is meaningless under it; the frame time
	## is not.
	##
	## `INFILTRAITOR_QUADRANT=<n>` sweeps `rendering_quadrant_size`. ⚠️ A previous
	## attempt at ONE quadrant per layer measured a **45% regression** (15 928 ms
	## of burn against 10 986) because every `set_cell()` then rebuilds the whole
	## layer's draw list — see `voxel_face_shading.gdshader`'s `vertex()`. That
	## measurement predates P3, which removed the minting and most of the writes,
	## so the trade-off is worth RE-measuring rather than assuming. It is a sweep,
	## not a fix, until a number says otherwise.
	var quad_env := OS.get_environment("INFILTRAITOR_QUADRANT")
	if quad_env.is_valid_int():
		layer.rendering_quadrant_size = maxi(quad_env.to_int(), 1)
	if OS.get_environment("INFILTRAITOR_HIDE_VOXELS") == "1":
		layer.visible = false

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
	## LEVEL-RENUMBER — the same two bands, addressed from the ground plane instead
	## of from zero. `rel` is the old level number: 0 for the wall base, -1 for the
	## walkable top face, -8 for the deepest bedrock, so both branches below are
	## byte-for-byte the arithmetic they were and the census can prove it.
	var rel: int = level - _ground_plane_level
	layer.z_index = (_wall_base_z_index + rel) if rel >= 0 else (rel + 1)
	layer.visible = true

	## FLOOR-DEPTH-02: one tone step per level down. Positive (wall) levels are
	## never touched — depth is a ground concept, and a wall's own stack already
	## reads through its facade shading.
	if rel < 0:
		var depth_index: int = mini(-rel - 1, FLOOR_DEPTH_DIM.size() - 1)
		var dim: float = FLOOR_DEPTH_DIM[depth_index]
		layer.modulate = Color(dim, dim, dim, 1.0)

	# Add to scene tree
	add_child(layer)
	## PERF-P5 — the shader recovers a cell from a LAYER-LOCAL position, and what
	## its vertex stage can see is canvas space (see voxel_face_shading.gdshader).
	## This is the offset between the two. Set AFTER add_child so the global
	## transform is real rather than the pre-parented one.
	var lmat := layer.material as ShaderMaterial
	if lmat != null:
		lmat.set_shader_parameter("layer_origin", layer.get_global_transform().origin)
	return layer


## LEVEL-RENUMBER — `storey_count` is a COUNT of wall levels, kept as such because
## every caller computes it from `storey_count * LEVELS_PER_STOREY`. It ensures the
## contiguous run from the ground plane upward; `_ensure_layer()` is the per-level
## form the sparse floor levels need.
func _ensure_voxel_layers(storey_count: int) -> void:
	for i in range(storey_count):
		_ensure_layer(_ground_plane_level + i)


## D17/D18: negative levels are never contiguous-from-zero and rarely all
## exist at once — callers ensure exactly the one level they need (the top
## destructible floor level, always; deeper fixed/cosmetic levels only once
## something has actually dug down to them). No "ensure up to N" variant on
## purpose: that shape would invite building a contiguous run nobody asked
## for, which is precisely what D18 forbids.
func _ensure_negative_voxel_layer(level: int) -> void:
	if level >= _ground_plane_level:
		push_error("VoxelRenderer._ensure_negative_voxel_layer: level %d is not below the ground plane (%d)"
			% [level, _ground_plane_level])
		return
	_ensure_layer(level)


## LEVEL-RENUMBER — the one creation seam. Idempotent, and sparse by construction:
## D18's lazy reveal means a level exists only once something has built it, which
## a Dictionary expresses directly where an Array had to be grown contiguously.
func _ensure_layer(level: int) -> void:
	if _layers.has(level):
		return
	_layers[level] = _build_voxel_layer_node(level)


## GLASS G1 — the frosted / sheen sublayer pair for one level. Idempotent, lazy:
## called from `_set_voxel_cell()` the first time a glass cell lands on `level`,
## so a map with no glass builds nothing. The opaque layer for `level` already
## exists by the time this runs (every render path ensures its wall layers before
## its voxel loop), so the sublayers are added to the tree AFTER it and — sharing
## its z_index — composite over it and under everything a level up.
func _ensure_glass_sublayers(level: int) -> void:
	if _glass_frosted_source_id < 0:
		return
	## Backbuffer + glass sit above the tallest opaque voxel layer so glass
	## composites over every wall behind it — AND, per G-D18b, above the agent
	## (`_glass_composite_z_floor` = agent.z_index + 1, set by room.gd) so he reads
	## as behind a pane he stands behind. `render()` keeps adding opaque layers as
	## it goes, so this is recomputed on every glass level and the nodes are moved
	## to the end of the tree to stay after any opaque layer added since.
	var z: int = maxi(maxi(get_max_voxel_z_index(), _wall_base_z_index), _glass_composite_z_floor)
	if z > _glass_composite_z:
		_glass_composite_z = z
	if _glass_backbuffer == null:
		_glass_backbuffer = BackBufferCopy.new()
		_glass_backbuffer.name = "glass_backbuffer"
		_glass_backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(_glass_backbuffer)
	_glass_backbuffer.z_index = _glass_composite_z
	move_child(_glass_backbuffer, -1)
	for l in _glass_layers.values():
		(l as TileMapLayer).z_index = _glass_composite_z
		move_child(l, -1)
	if _glass_layers.has(level):
		return
	var gl := _build_glass_sublayer_node(level)
	_glass_layers[level] = gl


## GLASS G-D18b — raise the whole glass composite (backbuffer + every pane layer)
## to at least `z`, and re-apply it if the sublayers already exist. room.gd calls
## this with `agent.z_index + 1` after OCC-03 sets the agent's z, so a pane the
## agent stands behind draws OVER him (a faint tint) instead of him popping in
## front of it. Idempotent; a no-op when glass is already at or above `z`.
func set_glass_over_z(z: int) -> void:
	_glass_composite_z_floor = maxi(_glass_composite_z_floor, z)
	if _glass_composite_z_floor <= _glass_composite_z:
		return
	_glass_composite_z = _glass_composite_z_floor
	if _glass_backbuffer != null:
		_glass_backbuffer.z_index = _glass_composite_z
		move_child(_glass_backbuffer, -1)
	for l in _glass_layers.values():
		(l as TileMapLayer).z_index = _glass_composite_z
		move_child(l, -1)


## GLASS G1 — one glass pane layer (one per level), a direct child of the
## renderer, drawn just after the backbuffer. Transform copied verbatim from
## `_build_voxel_layer_node()` so the pane registers pixel-exact with the opaque
## geometry.
func _build_glass_sublayer_node(level: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = _tileset
	layer.name = "glass_layer_%d" % level
	layer.material = _make_glass_material()
	## One tile per texture region — nothing to bleed from — so linear filtering
	## is safe and softens the frost + the feathered silhouette.
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	const TILE_OFFSET: Vector2 = Vector2(112.0, 64.0)
	layer.position = Vector2(
		_visual_grid_offset.x + TILE_OFFSET.x + debug_nudge.x,
		_visual_grid_offset.y + TILE_OFFSET.y + debug_nudge.y \
			- GeometryCoords.VOXEL_STEP_PX * float(relative_level(level))
	)

	var quad_env := OS.get_environment("INFILTRAITOR_QUADRANT")
	if quad_env.is_valid_int():
		layer.rendering_quadrant_size = maxi(quad_env.to_int(), 1)
	if OS.get_environment("INFILTRAITOR_HIDE_VOXELS") == "1":
		layer.visible = false

	layer.y_sort_origin = 1
	layer.z_index = _glass_composite_z

	add_child(layer)
	move_child(layer, -1)
	return layer


## GLASS G1 — a ShaderMaterial for a glass pane layer, its uniforms seeded from
## the current `_glass_shader_params` (so a mid-run change via
## `set_glass_shader_param` survives into any layer built afterwards).
func _make_glass_material() -> ShaderMaterial:
	var shader = load("res://godot/shaders/glass_pane.gdshader")
	if shader == null:
		push_error("[VoxelRenderer] GLASS-G1: glass_pane.gdshader failed to load — glass will render flat")
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_apply_glass_params_to(mat)
	## The frosted grain, sampled by world position (see the shader). Bound once
	## here — it is not a calibration knob.
	var frost_tex := load(MATERIAL_ASSET_ROOT + "glass/facade_glass.png")
	if frost_tex != null:
		mat.set_shader_parameter("glass_frost_tex", frost_tex)
	return mat


func _apply_glass_params_to(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	for key in _glass_shader_params:
		mat.set_shader_parameter(key, _glass_shader_params[key])


## GLASS G1 — the blind-strip capture action drives the calibration knobs through
## here. Sets the value on every live sublayer AND records it so later sublayers
## inherit it. `name` is one of the `_glass_shader_params` keys.
func set_glass_shader_param(name: String, value) -> void:
	_glass_shader_params[name] = value
	for l in _glass_layers.values():
		(l as TileMapLayer).material.set_shader_parameter(name, value)


## GLASS G1 — levels that currently hold a glass sublayer pair. Sorted, for the
## selftest and diagnostics.
func glass_level_keys() -> Array:
	var out: Array = _glass_layers.keys()
	out.sort()
	return out


## GLASS G3 — erase one glass pane cell. A glass voxel renders on `_glass_layers`,
## not `_layers`, so the detonation writer's "destroy" wave (which only knows
## `get_layer()` → the opaque stack) leaves a blast-shattered pane on screen.
## The shot path already handles this in `_process_dirty_slice_voxel`; this is
## the same erase for the cook, callable per destroyed cell. Returns true if a
## cell was actually removed. A no-op when the level has no glass sublayer.
func erase_glass_cell(level: int, cell: Vector2i) -> bool:
	if not _glass_layers.has(level):
		return false
	var g := _glass_layers[level] as TileMapLayer
	var was_there: bool = g.get_cell_source_id(cell) != -1
	g.erase_cell(cell)
	note_external_write(level, cell)
	forget_ghost_record(cell, level)
	return was_there


## GLASS G1 — the blind strip needs a same-boot CONTROL: glass exactly as it
## rendered before G1, a solid pale-blue cube. Hiding the pane layer alone just
## leaves a hole (glass no longer writes the opaque layer), so this transiently
## paints the opaque cube back onto every glass cell and hides the pane + the
## backbuffer. `enable=false` undoes both. Capture-only — never on the play path.
func set_glass_opaque_preview(enable: bool) -> void:
	var opaque_glass_id: int = MATERIALS.find("glass")
	for level in _glass_layers:
		var gpane := _glass_layers[level] as TileMapLayer
		var opaque := get_layer(level)
		for cell in gpane.get_used_cells():
			if enable:
				if opaque != null and opaque_glass_id >= 0:
					opaque.set_cell(cell, opaque_glass_id, Vector2i.ZERO, 0)
			elif opaque != null:
				opaque.erase_cell(cell)
		gpane.visible = not enable
	if _glass_backbuffer != null:
		_glass_backbuffer.visible = not enable


## DESTRUCTION D1/D2/D4 — render one Slab's voxels. Each voxel independently
## picks its earth variant via EarthVariantSelector.variant_for(grid_pos,
## level) — deterministic, so this is idempotent: calling it again on the
## same Slab places the exact same cells (D5's "nothing to pop" property).
## Not wired to any real map data yet (no MapSpec integration) — this is the
## render-side half of Part 2's core, consumed directly by whatever builds a
## Slab (today: only slab_generator.gd's manual/test construction).
## EXPLOSION_REBUILD_MASTER_PLAN Task 4/E-PLAN (2026-08-07) — `apply` mirrors
## _set_voxel_cell()'s own resolve-only seam: DetonationPlanBuilder's floor-
## reveal exposure fallback (§2 — "destroying a voxel exposes geometry behind
## it, which must fall back to the material atlas") needs to resolve the
## deep floor Slab's tiles WITHOUT painting them onto the live TileMapLayer
## before the destroy wave that exposes them actually fires. Returns
## Array[{"grid_pos":Vector2i, "level":int, "source_id":int,
## "atlas_coords":Vector2i, "alternative_id":int}] when apply is false (one
## entry per currently-visible voxel), empty when apply is true (existing
## callers all ignore the return value already).
func render_slab(slab: Slab, apply: bool = true) -> Array:
	var resolved: Array = []
	if slab.voxels.is_empty():
		return resolved
	# All of one Slab's voxels share slab.level (SlabGenerator.generate()'s
	# invariant) — one layer to ensure, not a min/max scan. D17: negative
	# (floor) levels route to the negative-only ensure function.
	_ensure_layer(slab.level)

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
			var result := _set_voxel_cell(voxel.grid_pos, voxel.level, slab.material,
					null, voxel.grid_pos - slab.texture_anchor, 0, true,
					"", BakePolicyClass.SurfaceClass.SLAB, apply)
			if not apply and not result.is_empty():
				resolved.append({"grid_pos": voxel.grid_pos, "level": voxel.level,
					"source_id": result["source_id"], "atlas_coords": result["atlas_coords"],
					"alternative_id": result["alternative_id"]})
		return resolved

	for voxel in slab.voxels:
		if not voxel.visible:
			continue
		var variant_index: int = EarthVariantSelector.variant_for(
			voxel.grid_pos, relative_level(voxel.level))
		var material_name: String = "earth_%d" % variant_index
		var result2 := _set_voxel_cell(voxel.grid_pos, voxel.level, material_name,
				null, Vector2i.ZERO, 0, false, "", BakePolicyClass.SurfaceClass.SLICE, apply)
		if not apply and not result2.is_empty():
			resolved.append({"grid_pos": voxel.grid_pos, "level": voxel.level,
				"source_id": result2["source_id"], "atlas_coords": result2["atlas_coords"],
				"alternative_id": result2["alternative_id"]})
	return resolved


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
func reveal_floor_slab(slab: Slab, apply: bool = true) -> Array:
	return render_slab(slab, apply)


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
	_ensure_layer(slab.level)

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
## EXPLOSION_REBUILD_MASTER_PLAN Task 4/E-PLAN (2026-08-07) — `apply` mirrors
## render_slab()'s own resolve-only seam, for the OTHER exposure-fallback
## branch (_expose_below()'s "no real Slab below — paint the fixed earth
## plane directly" case). See render_slab()'s doc for the full rationale;
## same return shape (Array of resolved per-voxel entries, empty when apply
## is true).
func render_fixed_earth_level(gu_cell: Vector2i, level: int, apply: bool = true) -> Array:
	var resolved: Array = []
	_ensure_layer(level)

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
			var result := _set_voxel_cell(voxel_pos, level, zone_material,
					null, voxel_pos - zone_anchor, 0, true,
					"", BakePolicyClass.SurfaceClass.SLAB, apply)
			if not apply and not result.is_empty():
				resolved.append({"grid_pos": voxel_pos, "level": level,
					"source_id": result["source_id"], "atlas_coords": result["atlas_coords"],
					"alternative_id": result["alternative_id"]})
		return resolved

	for voxel_pos in GeometryCoords.gu_voxels(gu_cell):
		var variant_index: int = EarthVariantSelector.variant_for(
			voxel_pos, relative_level(level))
		var result2 := _set_voxel_cell(voxel_pos, level, "earth_%d" % variant_index,
				null, Vector2i.ZERO, 0, false, "", BakePolicyClass.SurfaceClass.SLICE, apply)
		if not apply and not result2.is_empty():
			resolved.append({"grid_pos": voxel_pos, "level": level,
				"source_id": result2["source_id"], "atlas_coords": result2["atlas_coords"],
				"alternative_id": result2["alternative_id"]})
	return resolved


## FLOOR-DEPTH-01 — publish one GU's declared floor zone, so the FIXED levels
## beneath the Slab planes can wear the same baked texture. material is the zone
## material ("earth" clears the entry — an unzoned GU must fall back to the
## earth hash, never to a stale zone from a previous map).
func set_floor_zone(gu_cell: Vector2i, zone_material: String, anchor: Vector2i) -> void:
	if zone_material == "" or zone_material == "earth":
		_floor_zone_by_gu.erase(gu_cell)
		return
	_floor_zone_by_gu[gu_cell] = {"material": zone_material, "anchor": anchor}


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
	for layer in _layers.values():
		layer.clear()
	## GLASS G1 — the rotation path is clear()+render(); a glass sublayer keeping
	## its pre-rotation cells would leave a pane floating where the old view had
	## one. The nodes stay (like the opaque layers) — only the cells go.
	for l in _glass_layers.values():
		(l as TileMapLayer).clear()
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


## Thin wrapper: the same resolution, reading the tuple off a live Voxel. This
## is what every RENDER path calls, because by then the damage is written.
func resolve_damage_voxel_swap(voxel: Voxel, container) -> Dictionary:
	return resolve_damage_swap_for(container, voxel.damage_state,
		voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant,
		voxel.damage_substrate)


## D-ARCH-01: Apply damage to a voxel by swapping tile IDs (no runtime compositing).
## Called immediately after voxel.set_damage() to render the damage mark.
## Looks up a pre-baked damage variant and swaps the cell's tile in one call;
## on a miss, returns false so the caller's own fallback line renders it via
## D33 runtime compositing.
##
## `render_material`/`material_for_key` are derived exactly the way the
## fallback line right below each call site already derives them
## (damage_variant_material() for a Slice or a solid Slab, floor_damage_material()
## for a FLOOR Slab regardless of zoning — see _process_dirty_slab_voxel()'s own
## branching) — the lookup and its fallback can never name a cell differently
## because they call the same functions.
##
## D3/§3.1 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): the registry lost its
## per-cell dimension — `element_class` ("WALL"/"CEILING"/"FLOOR", the same
## three DamageVariantBaker.bake_all() enumerates) plus
## `voxel.damage_substrate` (the pre-baked atom this specific mark's decal
## sits on) now identify the atom instead of `grid_pos`/`level`. INTERIOR
## Slabs get no baked atoms (DamageVariantBaker's own scope note — they never
## reach the baked D33 path in the first place), so they're keyed under
## "INTERIOR" purely to keep the lookup honest about what it's asking for;
## it always misses and falls back exactly as it does today.
##
## Parameters:
##   container: the Slice or Slab this voxel belongs to
##   damage_state/is_blast/carved_side/variant/substrate: set_damage()'s own
##     five arguments, in order — read off a live Voxel by the wrapper, or
##     PREDICTED by BlastCalculator.plan_point_impact() before the shot.
##
## Returns: {"source_id":int, "atlas_coords":Vector2i} on a hit, {} on a miss
## (registry uninitialized, unknown container type, or no registered variant
## — the caller's own fallback line renders it, unchanged).
##
## EXPLOSION_REBUILD_MASTER_PLAN Task 4/E-PLAN (2026-08-07) — extracted out of
## apply_damage_voxel_swap() (now a thin wrapper below) so DetonationPlan-
## Builder's pre-compute pass can resolve WHICH atom a damaged voxel maps to
## WITHOUT touching the live TileMapLayer — the whole point of §2's "no
## compositing, no lookup... inside a wave": every branch here is the exact
## same lookup the live D-ARCH-01 render path uses, so the two can never
## disagree about which atom a given (voxel, container) resolves to. Pure
## extraction, same reasoning as Task 3's vertical_ring_for() split.
##
## W-PRECOOK-02 (2026-08-19) — the same lookup with the damage tuple passed IN
## rather than read off a Voxel, so a caller can ask WHICH ATOM a voxel WILL
## land on before anything is written to it. That is the shot's warm: a DENTED
## voxel moves to a damage-variant atom, and the light alternative for that atom
## is otherwise minted on the frame the wall breaks.
##
## The five arguments after `container` are set_damage()'s own five, in order —
## the same shape BlastCalculator.plan_point_impact() emits.
func resolve_damage_swap_for(container, damage_state: int, is_blast: bool,
		carved_side: int, variant: int, substrate: int) -> Dictionary:
	if _damage_variant_registry == null:
		return {}  # Registry not initialized, cannot swap

	var render_material: String
	var material_for_key: String
	var element_class: String
	if container is Slice:
		render_material = damage_variant_material(container.material, damage_state,
			is_blast, carved_side, variant)
		material_for_key = container.material
		element_class = "WALL"
	elif container is Slab:
		if container.role == Slab.Role.FLOOR:
			## D9 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06) made the ATOM
			## material-real: the substrate crop under the decal comes from the
			## GU's actual ground material, so two real materials bake two
			## genuinely different atoms. The registry key's material component
			## must therefore be the real zone material (`container.material` —
			## "earth" itself for a genuinely unzoned floor), or every material
			## would collide into one slot.
			##
			## D34/E-SEAM-02: the NAME is material-real now too (it used to be
			## renamed to the shared earth family unconditionally), so both
			## halves of the key finally agree on which material this is.
			material_for_key = container.material
			render_material = floor_damage_material(material_for_key,
				damage_state, is_blast,
				carved_side, variant)
			element_class = "FLOOR"
		elif container.role == Slab.Role.CEILING:
			if carved_side == Voxel.CarvedSide.TOP:
				## D16 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06) — a roof
				## struck from ABOVE (D15's roof-throw) carves its TOP face,
				## the same signal apply_crater_damage()'s _roll_floor_dent()
				## already hardcodes for a floor crater (see its own doc:
				## "a floor is only ever eaten from above, the mirror of a
				## ceiling only ever carving BOTTOM"). This voxel is really a
				## floor-family mark sitting on a CEILING container, so it
				## routes through the FLOOR naming/key path instead of the
				## CEILING one below — reusing floor_damage_material() and,
				## for the atom key, the real ground material at this GU
				## (not container.material, the ROOF's own material: the
				## floor beneath a roof can be a different real material).
				## Falls back to "earth" for an unzoned GU, matching
				## render_fixed_earth_level()'s own _floor_zone_by_gu rule.
				## BOTTOM (a ceiling hit from underneath, the ordinary case)
				## is unaffected — falls through to the unchanged branch below.
				var zone: Dictionary = _floor_zone_by_gu.get(container.gu_cell, {})
				material_for_key = String(zone.get("material", "earth"))
				## D34/E-SEAM-02: named from the REAL ground material at this
				## GU — the same value the key uses, computed first so the two
				## cannot drift.
				render_material = floor_damage_material(material_for_key,
					damage_state, is_blast,
					carved_side, variant)
				element_class = "FLOOR"
			else:
				render_material = damage_variant_material(container.material, damage_state,
					is_blast, carved_side, variant)
				material_for_key = container.material
				element_class = "CEILING"
		else:
			render_material = damage_variant_material(container.material, damage_state,
				is_blast, carved_side, variant)
			material_for_key = container.material
			element_class = "INTERIOR"
	else:
		return {}  # Unknown container type

	var variant_key := VoxelVariantRegistryClass.make_variant_key(
		element_class, material_for_key, render_material, substrate)
	return _damage_variant_registry.get_variant(variant_key)


## D-ARCH-01: Apply damage to a voxel by swapping tile IDs (no runtime
## compositing). Called immediately after voxel.set_damage() to render the
## damage mark. Thin wrapper over resolve_damage_voxel_swap() (Task 4/E-PLAN,
## 2026-08-07) — this function is now just "resolve, then place at alt 0"
## (the separate map-wide light repaint fixes up the real alt afterward, same
## as every other placement path); on a miss it returns false so the caller's
## own fallback line renders it via D33 runtime compositing.
func apply_damage_voxel_swap(voxel: Voxel, container, level: int) -> bool:
	var entry := resolve_damage_voxel_swap(voxel, container)
	if entry.is_empty():
		return false  # No pre-baked variant — caller's fallback line renders it
	var layer := get_layer(level)
	if layer == null:
		return false
	layer.set_cell(voxel.grid_pos, entry["source_id"], entry["atlas_coords"], 0)
	return true

## D-ARCH-01: Pre-bake all damage variants at load time
## No runtime compositing — single-frame ID swap at detonation
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
	## PERF-01: same reasoning — a cached page Image at a source_id that's
	## about to be reused by this pass's fresh register_baked_atlas_page()
	## calls would silently answer for the wrong page's pixels.
	_baked_source_image_cache.clear()
	## PERF-02 A3: same reasoning again — the resized decal images DecalCompositor
	## caches are keyed by this build's decal Image objects, which this pass is
	## about to stop using.
	DecalCompositorClass.clear_work_cache()


func _to_string() -> String:
	return "VoxelRenderer{layers=%d, negative_layers=%d, tileset=%s}" % [
		wall_level_keys().size(), _layers.size() - wall_level_keys().size(), "valid" if _tileset else "null"
	]
