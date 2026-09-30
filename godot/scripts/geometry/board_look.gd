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

## A CHARRED face (`BlastCalculator.FACE_SOOT_CHAR`): what fire and embers leave. Far below soot tone 0 (0.38): dark, with the
## material's texture still reading through (0.03 was solid black). A RANGE since 2026-09-30 (Director: they were all too dark, a
## wider scale with slightly lighter tones, randomised): each voxel takes `lerp(MIN, MAX, h * h)` for a hash `h` in [0, 1), so most
## stay dark and some read lighter. 0.14 was the single value tuned by eye; the mean of this range is ~0.167.
const SOOT_CHAR_MIN: float = 0.10
const SOOT_CHAR_MAX: float = 0.30


## The charred multiplier for a hash `h` in [0, 1): the same formula the shaders use.
static func char_mult(h: float) -> float:
	return lerpf(SOOT_CHAR_MIN, SOOT_CHAR_MAX, h * h)

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


## ── THE COLOUR GRADE (PROPS_TIER4_PLAN D-P2, `ACTOR` D68) ─────────────────────────────────────────────────────────────────────────
## One grade for the whole board's look, INSIDE the board's own shaders: walls, floors and decals (`Board3DLive`), prop meshes and voxel
## fragments (`prop_mesh3d.gdshader`). Not a full-screen pass: the handsets are pixel-bound, so it costs nothing where it is not used.
## At the identity values below the function is ABSENT from the compiled shader (zero cost, the pixels are byte-identical to before);
## a non-identity grade is baked into the shader text as constants, so a change is a new look, not a per-frame uniform.
##
## Saturation multiplies the distance from luma, contrast multiplies the distance from mid grey, lift adds to every channel, all in
## gamma (display) space. `INFILTRAITOR_GRADE=sat,contrast,lift` (a `DevFlags` key on the device) tries a look without an edit.
const GRADE_SATURATION: float = 1.0
const GRADE_CONTRAST: float = 1.0
const GRADE_LIFT: float = 0.0

static var _shader_cache: Dictionary = {}


## The active grade as (saturation, contrast, lift): the dev flag when set, else the constants.
static func grade_params() -> Vector3:
	var raw: String = OS.get_environment("INFILTRAITOR_GRADE")
	var loop := Engine.get_main_loop() as SceneTree
	if raw == "" and loop != null:
		var flags: Node = loop.root.get_node_or_null("/root/DevFlags")
		if flags != null:
			raw = String(flags.value("GRADE", ""))
	var parts: PackedStringArray = raw.split(",")
	if parts.size() == 3 and parts[0].is_valid_float() and parts[1].is_valid_float() and parts[2].is_valid_float():
		return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	return Vector3(GRADE_SATURATION, GRADE_CONTRAST, GRADE_LIFT)


static func grade_enabled() -> bool:
	var g: Vector3 = grade_params()
	return not (is_equal_approx(g.x, 1.0) and is_equal_approx(g.y, 1.0) and is_zero_approx(g.z))


## `code` with the grade applied to its final `ALBEDO` (before the closing brace of `fragment()`, the last one in the text), or `code`
## untouched at the identity.
static func apply_grade(code: String) -> String:
	if not grade_enabled():
		return code
	var g: Vector3 = grade_params()
	var fn := "\nconst vec3 GRADE = vec3(%s, %s, %s);\nvec3 grade_linear(vec3 lin) {\n	vec3 c = pow(max(lin, vec3(0.0)), vec3(1.0 / 2.2));\n	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));\n	c = mix(vec3(l), c, GRADE.x);\n	c = (c - 0.5) * GRADE.y + 0.5 + GRADE.z;\n	return pow(clamp(c, 0.0, 1.0), vec3(2.2));\n}\n" % [_f(g.x), _f(g.y), _f(g.z)]
	var at: int = code.find("void fragment()")
	var last: int = code.rfind("}")
	if at < 0 or last < 0:
		push_error("[BoardLook] apply_grade: no fragment() to grade")
		return code
	return code.substr(0, at) + fn + code.substr(at, last - at) + "	ALBEDO = grade_linear(ALBEDO);\n" + code.substr(last)


## A shader FILE with the grade applied, cached (one `Shader` per path).
static func graded_shader(path: String) -> Shader:
	if _shader_cache.has(path):
		return _shader_cache[path]
	var src: Shader = load(path)
	var out: Shader = src
	if grade_enabled():
		out = Shader.new()
		out.code = apply_grade(src.code)
	_shader_cache[path] = out
	return out


static func _f(v: float) -> String:
	var t: String = "%f" % v
	return t

