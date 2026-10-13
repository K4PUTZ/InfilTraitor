## RubblePresets — how a voxel a shot broke crumbles (ROOF_MASTER_PLAN R-D9, Director 2026-10-12).
##
## A broken voxel is replaced, on the frame the round lands, by a block of DIVISION³ sub-voxels sitting exactly where it was (the hole
## is never shown before they go). The whole block then crumbles out of the wall and piles on the floor. HOW it crumbles is one of three
## fall presets (the project's three-variant scheme), picked per voxel by a B4 FNV-1a hash of its cell, so the same wall breaks the same
## way on every run:
##   0 TOPPLE — the top layer leaves first, the block peels down from above;
##   1 SLUMP  — the bottom gives first and the block sags almost straight down at the wall's foot;
##   2 SPILL  — the face nearest the shooter leaves first and the block spills further out.
## A preset gives each sub-voxel a release delay (seconds after the hold) and a multiplier on its push. `SPEED` scales a material's
## push (concrete crumbles, wood and board spill further). `var`, rule 1.
class_name RubblePresets
extends RefCounted

const DIVISION: int = 4
const VARIANTS: int = 3
const TOPPLE: int = 0
const SLUMP: int = 1
const SPILL: int = 2

static var SPEED: Dictionary = {
	"concrete": 0.9, "stone": 0.9, "brick": 1.0, "metal": 0.7,
	"wood": 1.3, "plywood": 1.3, "cardboard": 1.5, "fabric": 1.1, "generic": 1.0,
}
## Materials whose broken voxels do NOT crumble (Director, 2026-10-12: stone gives a hole and the bullet-hole dust, nothing falls; cardboard,
## metal and fabric shed no particles at all from a shot — metal keeps its sparks, which are light, not debris).
static var NO_FALL: Array[String] = ["stone", "cardboard", "metal", "fabric"]
static var LAYER_STEP_S: float = 0.045   ## seconds between two layers of a block leaving
static var JITTER_S: float = 0.03        ## a hashed extra delay per sub-voxel, so a layer does not leave as one slab


## Which of the three presets a voxel wears (B4: hashed on its cell, never `randf()`).
static func variant_of(cell: Vector2i, level: int) -> int:
	return FacadeSampler._fnv1a_hash("RUBBLEVAR|%d,%d,%d" % [cell.x, cell.y, level]) % VARIANTS


## (release delay s, push multiplier) of one sub-voxel. `height` 0..DIVISION-1 is its layer from the bottom, `outward` 0..1 how far
## toward the shooter it sits in the block, `h01` a hashed number in [0, 1) of its own.
static func shape(material: String, variant: int, height: int, outward: float, h01: float) -> Vector2:
	var top: float = float(DIVISION - 1)
	var speed: float = float(SPEED.get(material, SPEED["generic"]))
	var delay: float
	var push: float
	match variant:
		SLUMP:
			delay = float(height) * LAYER_STEP_S
			push = 0.35
		SPILL:
			delay = (1.0 - outward) * top * LAYER_STEP_S
			push = 1.6
		_:
			delay = (top - float(height)) * LAYER_STEP_S
			push = 1.0
	return Vector2(delay + h01 * JITTER_S, push * speed)


## SPLINTERS (Director, 2026-10-12, wood): a broken voxel does not crumble afterwards. On the frame of the impact its block of sub-voxels
## splits three ways, by a hash of each cube: some FLY (thrown against the shot at once, a little farther than a crumble, and land),
## some STAY where they were (the ragged rim of the hole, saved with the pile) and the rest are GONE (the hollow of the crater). The
## cubes on the block's edge in the struck face's plane stay far more often, so the hole reads as splintered around its mouth.
static var SPLINTERS: Array[String] = ["wood", "plywood"]
const FLY: int = 0
const STAY: int = 1
const GONE: int = 2
static var STAY_EDGE: float = 0.55      ## chance a cube on the block's edge (in the face's plane) stays
static var STAY_INNER: float = 0.12     ## ... and one inside it
static var FLY_SHARE: float = 0.55      ## of the cubes that do not stay, the share that flies (the rest are gone)
## Per material: plywood (madeirite) is wood with more destruction and more splinters (Director, 2026-10-12).
static var FLY_SHARE_OF: Dictionary = {"plywood": 0.8}
## Plywood's splinters are darker and vary more from cube to cube (Director, 2026-10-12): a lower point on the ramp and a wider brightness jitter.
static var RAMP_OF: Dictionary = {"plywood": 0.15}
static var JITTER_OF: Dictionary = {"plywood": 0.14}
## Plywood: an open, airy break (Director, 2026-10-12): only a share of the broken voxels get a block of sub-voxels at all (the others are plain
## empty holes), the blocks that do are mostly hollow, the rim is thin and the thrown pieces keep the facade's texture (the floor noise of
## black stains and mixed wood tones). Wood keeps the defaults above.
static var BLOCK_SHARE_OF: Dictionary = {"plywood": 0.35}
static var STAY_EDGE_OF: Dictionary = {"plywood": 0.40}
static var STAY_INNER_OF: Dictionary = {"plywood": 0.05}
static var FLY_TEXTURED_OF: Dictionary = {"plywood": true}
## The most broken voxels of one shot that turn into blocks on one frame (the rest follow on the next ones).
const BLOCKS_PER_FRAME: int = 5
static var FLY_SPEED: Vector2 = Vector2(1.8, 3.2)   ## a flying splinter's push multiplier, min..max (a crumble is 0.35-1.6 x the material's speed)
static var FLY_DELAY_S: float = 0.04    ## the most a splinter waits after the impact, so they do not leave as one slab


## Whether this broken voxel gets a block of sub-voxels at all (hashed on its cell, B4).
static func block_kept(material: String, cell: Vector2i, level: int) -> bool:
	var share: float = float(BLOCK_SHARE_OF.get(material, 1.0))
	if share >= 1.0:
		return true
	return float(FacadeSampler._fnv1a_hash("SPLBLOCK|%d,%d,%d" % [cell.x, cell.y, level]) % 1000) / 1000.0 < share


static func splinter_role(material: String, cell: Vector2i, level: int, a: int, b: int, cc: int, x_normal: bool) -> int:
	var top: int = DIVISION - 1
	var lateral: int = cc if x_normal else a
	var edge: bool = lateral == 0 or lateral == top or b == 0 or b == top
	var h: int = FacadeSampler._fnv1a_hash("SPLINTER|%d,%d,%d|%d,%d,%d" % [cell.x, cell.y, level, a, b, cc])
	var u: float = float(h % 1000) / 1000.0
	if u < float((STAY_EDGE_OF.get(material, STAY_EDGE) if edge else STAY_INNER_OF.get(material, STAY_INNER))):
		return STAY
	return FLY if float(FacadeSampler._fnv1a_hash("SPLFLY|%d" % h) % 1000) / 1000.0 < float(FLY_SHARE_OF.get(material, FLY_SHARE)) else GONE


## (release delay s, push multiplier) of a flying splinter, from a hashed number in [0, 1).
static func splinter_shape(h01: float) -> Vector2:
	return Vector2(h01 * FLY_DELAY_S, lerpf(FLY_SPEED.x, FLY_SPEED.y, h01))
