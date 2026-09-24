extends SceneTree

## BoardLook selftest (R3D-9, 2026-09-24) — the look constants have ONE owner.
##
## Two things it pins, both of which failed silently before there was an owner:
##   1. the 2D face shader's uniform defaults (which the 2D board falls back to if nothing pushes a value) are the
##      owner's values, parsed out of the shader source, so a retune in either place cannot drift from the other;
##   2. the 2D renderer's own ladder is the owner's ladder, and the 3D board's `_read_look()` no longer reaches into
##      the renderer for a ShaderMaterial (the source is asserted, the way `voxel_face_separation_selftest` does).

const SHADER_PATH: String = "res://godot/shaders/voxel_face_shading.gdshader"
const BOARD_PATH: String = "res://godot/scripts/geometry/board3d_live.gd"

var _fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("BOARD-LOOK SELFTEST")
	print("=".repeat(70) + "\n")
	_test_shader_defaults_are_the_owners()
	_test_ladder_is_shared()
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


func _shader_source() -> String:
	return FileAccess.get_file_as_string(SHADER_PATH)


## `uniform <type> <name> ... = <value>;` -> the text after `=` up to `;`.
func _uniform_default(source: String, name: String) -> String:
	var re := RegEx.new()
	re.compile("uniform\\s+\\w+\\s+%s\\b[^=;]*=\\s*([^;]+);" % name)
	var m: RegExMatch = re.search(source)
	return m.get_string(1).strip_edges() if m != null else ""


func _test_shader_defaults_are_the_owners() -> void:
	var source: String = _shader_source()
	_check(not source.is_empty(), "the 2D face shader source is readable")
	var names: Array[String] = ["face_top", "face_se", "face_sw"]
	for i in range(3):
		var text: String = _uniform_default(source, names[i])
		_check(text.is_valid_float() and is_equal_approx(text.to_float(), BoardLook.FACE_TONE[i]),
			"shader %s default (%s) == BoardLook.FACE_TONE[%d] (%s)" % [names[i], text, i, BoardLook.FACE_TONE[i]])
	var soot: String = _uniform_default(source, "soot_face_mult")
	var re := RegEx.new()
	re.compile("vec4\\(([^)]+)\\)")
	var m: RegExMatch = re.search(soot)
	var parts: PackedStringArray = m.get_string(1).split(",") if m != null else PackedStringArray()
	_check(parts.size() == 4, "the shader's soot_face_mult parses as a vec4 (got %d component(s))" % parts.size())
	for i in range(mini(parts.size(), 4)):
		_check(is_equal_approx(parts[i].strip_edges().to_float(), BoardLook.SOOT_FACE_MULT[i]),
			"shader soot_face_mult[%d] (%s) == BoardLook.SOOT_FACE_MULT[%d] (%s)"
				% [i, parts[i].strip_edges(), i, BoardLook.SOOT_FACE_MULT[i]])


func _test_ladder_is_shared() -> void:
	var owner: Array[float] = BoardLook.light_ladder()
	var renderer := VoxelRenderer.new()
	_check(owner.size() == 12, "the ladder has 12 buckets (got %d)" % owner.size())
	var same: bool = renderer.bucket_luminance.size() == owner.size()
	for i in range(mini(owner.size(), renderer.bucket_luminance.size())):
		same = same and is_equal_approx(renderer.bucket_luminance[i], owner[i])
	_check(same, "VoxelRenderer.bucket_luminance starts as BoardLook's ladder")
	renderer.free()


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
