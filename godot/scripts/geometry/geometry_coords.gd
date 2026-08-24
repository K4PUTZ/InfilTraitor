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

## Render levels per storey (vertical granularity): one storey = 8 TileMapLayer levels
## Canonical per VOXEL_MASTER_PLAN.md line 85: "8 voxels × 8 levels = 64 VoxelRefs per slice"
const LEVELS_PER_STOREY: int = 8

## LEVEL-RENUMBER (Director, 2026-08-24): *"seria melhor a gente só usar valores
## positivos e convencionar que o andar 10 vai ser sempre o jogável, o que for pra
## cima vai ser 11 em diante e temos até o andar 0 para criar possibilidades de
## efeitos subterrâneos."*
##
## EVERY render level is now >= 0. The playable storey is 10, so its voxel levels
## are 80..87; the ground beneath it is storey 9 (72..79), and storeys 0..8 are
## unbuilt headroom for underground work. Upper storeys count on from 11.
##
## What this buys is not a bug fix — the residue that made §10.2 look like a
## negative-level problem was `_placed_by_gu` staleness, and renumbering would not
## have prevented it. What the SIGN cost was a second store: `_voxel_layers` was an
## Array and `_negative_voxel_layers` a Dictionary, `get_layer()` branched between
## them, and every map-wide walk had to remember to iterate both. One non-negative
## axis is one Array and one index.
##
## ⚠️ NOT a mapfile concern: `.map.json` stores no level at all (checked — zero
## `level` keys, zero negative numbers), so this is a runtime numbering change with
## no migration and no section version bump.
const PLAYABLE_STOREY: int = 10
const PLAYABLE_LEVEL: int = PLAYABLE_STOREY * LEVELS_PER_STOREY

## Texture authoring resolution: flat texels per voxel
## Pinned by BAKE-01 Tile Anatomy Audit; example N=16 → 1024×512 facades, 128×128 slices
## DO NOT use hardcoded multiples (64*N, 32*N); always reference this constant.
const TEX_AUTHORING_N: int = 16

## Voxel atom dimensions
const VOXEL_ATOM_W: int = 32     ## width
const VOXEL_ATOM_H: int = 36     ## height: 16 top face + 20 side face
const VOXEL_TILE_H: int = 16     ## tile height (top face only)

## ── Ground stack (D13/D17/D18 + FLOOR-DEPTH-01, Director 2026-07-28) ──────────
## The level map beneath the walkable plane, in one place — room_builder,
## VoxelRenderer and the blast path all used to spell these out independently
## (or, worse, as a bare -1 / level - 1).
##
##   FLOOR_TOP_LEVEL   (-1) real Slab, destructible, wears the floor-zone bake.
##   FLOOR_DEEP_LEVEL  (-2) real Slab, destructible ONLY inside the blast's own
##                          GU (see BlastCalculator.DEEP_FLOOR_CRATER_FACTOR).
##                          Rendered on exposure, not at build. Also wears the
##                          bake: the two structural planes are the "concrete".
##   -3 .. -8               fixed cosmetic ground (no Slab, no Voxel), plain
##                          earth — the dirt UNDER the concrete.
const FLOOR_TOP_LEVEL: int = -1
const FLOOR_DEEP_LEVEL: int = -2
## Deepest level that gets the floor zone's baked texture instead of the
## earth-variant hash.
##
## Was -3 for a few hours on 2026-07-28 (D20, "pintar a terceira camada com a
## mesma textura"), moved to -2 the same day: Director asked for the first two
## layers to read as concrete and the third as earth. This is the FREE half of
## that request — the earth variants are already in the material atlas and cost
## nothing to place, whereas a photographic dirt would be another baked ground
## material at ~18 MB of atlas (measured; see D21).
const FLOOR_ZONE_PAINT_MIN_LEVEL: int = FLOOR_DEEP_LEVEL


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


## All 64 voxel cells contained in a Gameplay Unit
## Returns array in scan order: y varies outer, x varies inner
static func gu_voxels(gu: Vector2i) -> Array[Vector2i]:
	var origin := gu_to_voxel_origin(gu)
	var result: Array[Vector2i] = []
	for dy in range(VOXELS_PER_UNIT_AXIS):
		for dx in range(VOXELS_PER_UNIT_AXIS):
			result.append(origin + Vector2i(dx, dy))
	return result
