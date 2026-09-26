## BoardLook — the one owner of the board's look constants (R3D-9, 2026-09-24).
##
## Until now the same numbers lived in three places: the 2D face shader's uniform defaults, `Board3DLive`'s
## fallbacks, and (for the light ladder) `VoxelBoard`. The 3D board read them by asking the 2D renderer's ground
## layer for its `ShaderMaterial`, which made the 3D board depend on a node the 3D path is meant to outlive.
## Now both boards read this; the 2D face shader gets these values pushed as uniforms until R3D-END deletes it, and
## `board_look_selftest` parses the shader's defaults so a change there cannot drift from here.
class_name BoardLook
extends RefCounted

## Soot ring 0..3 (0 = the darkest), multiplied into a face's colour. SOOT-STAMP 2026-09-22 (lighter, softer).
const SOOT_FACE_MULT: Array[float] = [0.38, 0.60, 0.76, 0.90]

## Per-face brightness, index 0 = top, 1 = the SE side, 2 = the SW side (a face can only be darkened against the art).
const FACE_TONE: Array[float] = [1.0, 0.975, 0.945]

## The light ladder: brightness of light bucket 0..11. A function (not a const) because the PERF-P3 diagnostic
## `INFILTRAITOR_FLAT_LIGHT=1` flattens it to 1.0 and has to take effect before the first material.
static func light_ladder() -> Array[float]:
	var ladder: Array[float] = [
		0.12, 0.20, 0.33, 0.40, 0.47, 0.54, 0.61, 0.69, 0.77, 0.85, 0.92, 1.00,
	]
	if OS.get_environment("INFILTRAITOR_FLAT_LIGHT") == "1":
		for i in range(ladder.size()):
			ladder[i] = 1.0
		print("[P3-DIAG] INFILTRAITOR_FLAT_LIGHT — light ladder flattened to 1.00")
	return ladder
