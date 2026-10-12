## ROOF RF-1 step 3b (2026-10-11) — `PaneFrame`: a cell and its pane coordinates go there and back for every face (the four vertical
## faces and the skylight's HORIZONTAL), u / v are the axes the glass code always used for a vertical pane (run, level), and a
## skylight's are (x, y) at a fixed level.
extends SceneTree

const PaneFrameRef = preload("res://godot/scripts/systems/destruction/pane_frame.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== PANE FRAME SELFTEST ==\n")
	var cell := Vector3i(13, 27, 90)
	for face: int in [Face.NW, Face.NE, Face.SE, Face.SW, PaneFrameRef.HORIZONTAL]:
		var uv: Vector2i = PaneFrameRef.to_uv(face, cell)
		var back: Vector3i = PaneFrameRef.to_cell(face, uv, PaneFrameRef.fixed_of(face, cell))
		_check(back == cell, "face %d: %s -> uv %s -> %s" % [face, cell, uv, back])
	_check(PaneFrameRef.to_uv(Face.SW, cell) == Vector2i(13, 90) and PaneFrameRef.fixed_of(Face.SW, cell) == 27,
		"NE / SW run along X: (x, level), fixed y")
	_check(PaneFrameRef.to_uv(Face.NW, cell) == Vector2i(27, 90) and PaneFrameRef.fixed_of(Face.NW, cell) == 13,
		"NW / SE run along Y: (y, level), fixed x")
	_check(PaneFrameRef.to_uv(PaneFrameRef.HORIZONTAL, cell) == Vector2i(13, 27) and PaneFrameRef.fixed_of(PaneFrameRef.HORIZONTAL, cell) == 90,
		"a skylight: (x, y), fixed level")
	_check(PaneFrameRef.HORIZONTAL == VoxelStore.PANE_HORIZONTAL - 1, "HORIZONTAL is the store's pane byte less one")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
