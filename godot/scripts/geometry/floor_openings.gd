## FloorOpenings — a real opening in the floor (R3D-SURFACES SM-6b, 2026-10-06, DS-18): which voxel cells of a GU the floor does NOT have.
##
## A grating is not a dark texture, it is an object with holes: `SlabGenerator` skips the cells this returns, on BOTH floor levels (the top
## plane and the deep one beneath it), so a shaft runs through the ground and the camera sees the void at its bottom. It is the very state the
## buffer ring's missing deep plane and a crater already are (cells that do not exist), so the mesher, the light planes, the occupancy and the
## destruction already cope with it.
##
## An opening is a rectangle of WHOLE GUs (`gu`, `size`, in raw GU) of one of two patterns:
##  - `slats`: bars of one voxel (1/8 GU, ~12 cm) running along `axis` ("x" or "z"), a bar every `pitch` voxels (2: one bar, one gap), inside a
##    one-voxel FRAME that is always floor. The bars are floor voxels of the opening's `material`, so they are walkable, shootable-through
##    gaps, and a grenade takes them like any floor.
##  - `open`: nothing at all, frame included: a bare shaft (a pit; a hazard for the gameplay milestone, not built).
## Pure and deterministic, so the selftest pins it without a board.
class_name FloorOpenings
extends RefCounted

const PATTERNS: PackedStringArray = ["slats", "open"]
const AXES: PackedStringArray = ["x", "z"]
const DEFAULT_PITCH: int = 2
const DEFAULT_MATERIAL: String = "steel_dark"


## The opening's GU rectangle, with defaults filled and a loud error (and an empty `{}`) for a bad one.
static func normalise(raw: Dictionary) -> Dictionary:
	var gu = raw.get("gu_cell", null)
	var size = raw.get("size", Vector2i.ONE)
	var pattern: String = String(raw.get("pattern", "slats"))
	var axis: String = String(raw.get("axis", "x"))
	var pitch: int = int(raw.get("pitch", DEFAULT_PITCH))
	if not (gu is Vector2i) or not (size is Vector2i) or size.x < 1 or size.y < 1 or not PATTERNS.has(pattern) or not AXES.has(axis) or pitch < 2:
		push_error("[FloorOpenings] %s needs `gu` (whole GU), `size` >= 1 x 1, pattern in %s, axis in %s, pitch >= 2; skipped" % [str(raw), PATTERNS, AXES])
		return {}
	return {"rect": Rect2i(gu, size), "pattern": pattern, "axis": axis, "pitch": pitch,
			"material": String(raw.get("material", DEFAULT_MATERIAL))}


## The voxel cells (x, y) of GU `gu` that the opening carves away: a Dictionary used as a set. Empty when `gu` is outside the opening.
static func carved_cells(opening: Dictionary, gu: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	var rect: Rect2i = opening["rect"]
	if not rect.has_point(gu):
		return out
	var unit: int = GeometryCoords.VOXELS_PER_UNIT_AXIS
	var vox_origin := Vector2i(rect.position.x * unit, rect.position.y * unit)
	var vox_size := Vector2i(rect.size.x * unit, rect.size.y * unit)
	for cell: Vector2i in GeometryCoords.gu_voxels(gu):
		var local: Vector2i = cell - vox_origin
		if String(opening["pattern"]) == "open":
			out[cell] = true
			continue
		var on_frame: bool = local.x == 0 or local.y == 0 or local.x == vox_size.x - 1 or local.y == vox_size.y - 1
		if on_frame:
			continue
		var across: int = local.y if String(opening["axis"]) == "x" else local.x
		if across % int(opening["pitch"]) != 0:
			out[cell] = true
	return out
