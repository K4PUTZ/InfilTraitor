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
