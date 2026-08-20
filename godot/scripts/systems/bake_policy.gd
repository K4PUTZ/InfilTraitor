## BakePolicy — Shared deterministic rules for texture baking
##
## Ensures the bake pass and lookup pass use identical:
## - Texture assignment (material ID + surface class → texture ID)
## - Variant seeding (edge + material → [0, 4) variant)
##
## D20 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): texture identity is a
## (material, surface_class) pair, mechanically derived — no per-material
## dict to keep in sync, matching MAPFILE_REFERENCE.md's existing M6 prefix
## canon (`facade_<material>`). SLICE (walls/roofs, reprojected from the same
## source) always resolves to `facade_<id>`. A missing asset (e.g. a material
## with no wall facade) is handled the same way it always was:
## TextureResolver.resolve() falls back to Tier.NONE and every caller already
## treats that as "fall back to the generic atlas".
##
## D34/E-SEAM-01 (Director, 2026-08-08) — **amends D20's SLAB half.** D20 sent
## EVERY floor zone down the `slab_<id>` photographic path, which is what made
## a concrete floor unable to read as the same material as a concrete wall
## (they were literally different art: `facade_concrete` grayscale+tinted vs
## `slab_concrete`, an unrelated ground photo at WHITE). The Director's model
## instead: **a floor is a roof at the base of the scene** — same bake, same
## grayscale source, same multiply tint, so wall/roof/floor of one material
## all read as that material. Which family a SLAB request resolves to is
## therefore derived from the MATERIAL, not from the surface alone:
##
##   has_facade == true  -> `facade_<id>`, the SLICE family (concrete, metal,
##                          stone, wood today)
##   has_facade == false -> `slab_<id>`, the photographic exception, kept on
##                          purpose for organic/wild ground (grass, dirt,
##                          sand, gravel) where hue IS the material identity
##                          and a grayscale source cannot carry it
##
## `has_facade` is consulted for SLAB only; SLICE resolves to `facade_<id>`
## regardless. This also retires the never-read `MaterialDef.slab_full_color`
## flag — the same split is derivable from `has_facade`, so there is no second
## field to keep in sync with it (E-SEAM-03).

class_name BakePolicy

## SLICE = vertical face (walls, and roofs — a roof reprojects its material's
## own wall facade, D20's second correction: "ceiling" in the SLAB row below
## refers to the future damage-atom pool, not the base roof render).
## SLAB = horizontal face (floor zones only, today).
enum SurfaceClass { SLICE, SLAB }

## SLICE (vertical, walls/roofs) texture id for a material.
static func facade_for_material(material_id: String) -> String:
	return "facade_" + material_id


## SLAB (horizontal) texture id for a material — the PHOTOGRAPHIC family only.
## D34: reaching this for a `has_facade` material is a bug, not a fallback —
## go through texture_for_material() so the has_facade split is applied once,
## in one place, on both sides of the seam (B1).
static func slab_for_material(material_id: String) -> String:
	return "slab_" + material_id


## (material_id, surface_class, has_facade) → texture id, the one call sites
## that already know their surface_class should use instead of picking a
## function by hand. See this file's header for why `has_facade` decides the
## SLAB case (D34/E-SEAM-01).
##
## `has_facade` is deliberately REQUIRED rather than defaulted: a wrong guess
## here is silent (TextureResolver returns Tier.NONE and the surface quietly
## degrades to the generic atlas — no error, no crash, just the wrong pixels),
## which is exactly the failure mode this seam already produced once.
static func texture_for_material(material_id: String, surface_class: int,
		has_facade: bool) -> String:
	if surface_class == SurfaceClass.SLAB and not has_facade:
		return slab_for_material(material_id)
	return facade_for_material(material_id)


## D35/E-EARTH-01 (2026-08-08) — filename stem of the CANONICAL voxel atom for
## a material, i.e. the `voxel_<stem>.png` under `source_assets/voxels/
## materials/` that B3 reads a silhouette's alpha from. Identity for every
## material except `earth`, whose atom ships as eight surface variants
## (`voxel_earth_0..7.png`, the EarthVariantSelector palette) and has no
## unsuffixed file.
##
## Pointing earth at variant 0 is safe and is not a shortcut: **alpha is the
## only channel a canonical atom's masking ever reads** (the same reasoning
## already recorded for concrete reusing its wall atom on the floor bake), and
## all eight earth variants carry byte-identical alpha to every other voxel
## atom in the project — verified directly, not assumed, since every atom is
## the same 32x36 isometric cube silhouette.
##
## Deliberately a policy function rather than a copied `voxel_earth.png`:
## `materials/` is an INPUT directory (ASSET-LAYOUT-01, "never overwritten"),
## and a duplicate file there would be a derived artifact masquerading as
## authored art.
## MAT-REG-01 (2026-08-21): the four newcomers alias to concrete's atom, for
## the reason already recorded above rather than a new one. ALPHA IS THE ONLY
## CHANNEL A CANONICAL ATOM'S MASKING READS, and all 17 shipped atoms are 32x36
## with byte-identical alpha (measured, md5 884d98981cee) — so a per-material
## file would be 17 copies of one silhouette, and `materials/` is an INPUT
## directory where a derived duplicate would masquerade as authored art.
## `glass` is absent because voxel_glass.png genuinely exists.
const CANONICAL_ATOM_ALIASES: Dictionary = {
	"earth": "earth_0",
	"brick": "concrete",
	"cardboard": "concrete",
	"fabric": "concrete",
	"plywood": "concrete",
}


static func canonical_voxel_atom_for(material_id: String) -> String:
	return String(CANONICAL_ATOM_ALIASES.get(material_id, material_id))


## Deterministic variant selection. Stable across runs: NEVER uses instance identity.
static func variant_for(edge, material_id: String) -> int:
	var edge_key: String = edge.key_string() if edge.has_method("key_string") else str(edge)
	return abs(("%s_%s" % [edge_key, material_id]).hash()) % 4
