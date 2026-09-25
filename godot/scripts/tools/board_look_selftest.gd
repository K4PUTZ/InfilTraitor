extends SceneTree

## BoardLook selftest (R3D-9, 2026-09-24) — the look constants have ONE owner.
##
## What it pins: the 3D board's `_read_look()` reads `BoardLook` and no longer reaches into the renderer for a ShaderMaterial
## (the source is asserted). (R3D-END END-4: the checks that the 2D face shader's uniform defaults and the 2D renderer's ladder
## were the owner's went with the shader and the ladder.)

const BOARD_PATH: String = "res://godot/scripts/geometry/board3d_live.gd"

var _fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("BOARD-LOOK SELFTEST")
	print("=".repeat(70) + "\n")
	_test_board_reads_no_renderer_shader()
	print("")
	if _fails == 0:
		print("[BOARD-LOOK] RESULT: PASS — all checks passed")
		quit(0)
	else:
		print("[BOARD-LOOK] RESULT: FAIL — %d check(s) failed" % _fails)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("[BOARD-LOOK] ✅ %s" % label)
	else:
		print("[BOARD-LOOK] ❌ %s" % label)
		_fails += 1


func _test_board_reads_no_renderer_shader() -> void:
	var source: String = FileAccess.get_file_as_string(BOARD_PATH)
	var start: int = source.find("func _read_look()")
	var end: int = source.find("\nfunc ", start + 1)
	var code_lines: PackedStringArray = []
	for line in source.substr(start, end - start).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	var body: String = "\n".join(code_lines)
	_check(start >= 0 and not body.is_empty(), "Board3DLive._read_look() found")
	_check(not body.contains("get_layer(") and not body.contains("ShaderMaterial") \
			and not body.contains("get_shader_parameter"),
		"_read_look() asks the 2D renderer for no layer and no ShaderMaterial")
	_check(body.contains("BoardLook."), "_read_look() reads BoardLook")
