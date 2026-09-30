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
	_test_grade()
	_test_charred_range()
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


## THE GRADE (PROPS_TIER4_PLAN D-P2): at the identity the shader text is untouched; a real grade is injected ahead of the last brace.
func _test_grade() -> void:
	var code: String = "shader_type spatial;\nvoid fragment() {\n	ALBEDO = vec3(0.5);\n}\n"
	OS.set_environment("INFILTRAITOR_GRADE", "")
	_check(BoardLook.apply_grade(code) == code and not BoardLook.grade_enabled(), "grade: the identity leaves the shader text untouched (zero cost)")
	OS.set_environment("INFILTRAITOR_GRADE", "1.2,1.1,0.05")
	var graded: String = BoardLook.apply_grade(code)
	_check(BoardLook.grade_enabled() and graded.contains("const vec3 GRADE = vec3(1.200000, 1.100000, 0.050000);")
		and graded.contains("vec3 grade_linear(vec3 lin)"), "grade: a real grade bakes its constants and the function in")
	var last_brace: int = graded.rfind("}")
	_check(graded.find("ALBEDO = grade_linear(ALBEDO);") > graded.find("ALBEDO = vec3(0.5);") and graded.find("ALBEDO = grade_linear(ALBEDO);") < last_brace,
		"grade: applied to the final ALBEDO, inside fragment()")
	OS.set_environment("INFILTRAITOR_GRADE", "nonsense")
	_check(not BoardLook.grade_enabled(), "grade: a malformed flag is ignored, not half-applied")
	OS.set_environment("INFILTRAITOR_GRADE", "")


## THE CHARRED RANGE (D-P5): mostly dark, some lighter, always inside [MIN, MAX], the same formula everywhere.
func _test_charred_range() -> void:
	var lo: float = BoardLook.char_mult(0.0)
	var hi: float = BoardLook.char_mult(0.999999)
	_check(is_equal_approx(lo, BoardLook.SOOT_CHAR_MIN) and hi <= BoardLook.SOOT_CHAR_MAX + 1.0e-6, "charred: h=0 is the darkest (%.2f), h->1 the lightest (%.2f)" % [lo, hi])
	var below_mid: int = 0
	for i in range(1000):
		if BoardLook.char_mult(float(i) / 1000.0) < (BoardLook.SOOT_CHAR_MIN + BoardLook.SOOT_CHAR_MAX) * 0.5:
			below_mid += 1
	_check(below_mid > 650, "charred: most tones sit below the middle of the range (%d of 1000): dark with some lighter" % below_mid)

