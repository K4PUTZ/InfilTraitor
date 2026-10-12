## RubblePresets — how a voxel a shot broke splits into chips (ROOF_MASTER_PLAN R-D9, Director 2026-10-12).
##
## A broken voxel is replaced, on the frame the round lands, by DIVISION³ sub-voxels sitting exactly where it was (the hole is never
## shown before the chips leave). After the hold, a few of them fall as chips and the rest turn to dust. WHICH ones fall is a preset:
## three per material (the project's three-variant scheme), each a fixed mask over the sub-voxel lattice, picked per voxel by a B4
## FNV-1a hash of its cell, so the same wall breaks the same way on every run. No facade on a chip (flat colour, the wall's tone).
##
## `CHIP_SHARE` is the share of a voxel that falls as chips, per material (`generic` for anything not listed): concrete and stone
## spall a few small flakes, wood and board shed more. `var`, rule 1.
class_name RubblePresets
extends RefCounted

const DIVISION: int = 4
const VARIANTS: int = 3

static var CHIP_SHARE: Dictionary = {
	"concrete": 0.06, "stone": 0.06, "brick": 0.09, "metal": 0.04,
	"wood": 0.16, "plywood": 0.16, "cardboard": 0.22, "fabric": 0.10, "generic": 0.10,
}

static var _cache: Dictionary = {}   ## "material|variant" -> PackedByteArray (DIVISION³, 1 = a chip)


## The chip mask of one preset: index = (a * DIVISION + b) * DIVISION + c for sub-voxel (x a, level b, y c). At least one chip.
static func mask(material: String, variant: int) -> PackedByteArray:
	var key: String = "%s|%d" % [material, variant]
	if _cache.has(key):
		return _cache[key]
	var share: float = float(CHIP_SHARE.get(material, CHIP_SHARE["generic"]))
	var n: int = DIVISION * DIVISION * DIVISION
	var out := PackedByteArray()
	out.resize(n)
	var chips: int = 0
	var base: int = FacadeSampler._fnv1a_hash("RUBBLE|%s|%d" % [material, variant])
	for i in range(n):
		if float(FacadeSampler._fnv1a_continue(base, str(i)) % 10000) / 10000.0 < share:
			out[i] = 1
			chips += 1
	if chips == 0:
		out[base % n] = 1
	_cache[key] = out
	return out


## Which of the three presets a voxel wears (B4: hashed on its cell, never `randf()`).
static func variant_of(cell: Vector2i, level: int) -> int:
	return FacadeSampler._fnv1a_hash("RUBBLEVAR|%d,%d,%d" % [cell.x, cell.y, level]) % VARIANTS
