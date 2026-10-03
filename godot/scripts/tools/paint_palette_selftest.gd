## PaintPalette selftest — a surface declared `material@paint` wears that paint, and `repaint()` recolours exactly those.
## Run: python3 tools/persistent/run_selftests.py --only paint_palette_selftest
extends SceneTree

const GRENADE := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"

var passed: int = 0
var failed: int = 0


## The two board calls `PropMesh3D` makes, and nothing else.
class StubBoard extends Node3D:
	func register_prop_light_material(_m: ShaderMaterial) -> void:
		pass

	func unregister_prop_light_material(_m: ShaderMaterial) -> void:
		pass

	func material_facade_texture(_id: String) -> Texture2D:
		return null


func _initialize() -> void:
	print("\n" + "=".repeat(70))
	print("PAINT-PALETTE SELFTEST")
	print("=".repeat(70) + "\n")
	_test_split()
	_test_repaint()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  ✓ PASS: ", msg)
	else:
		failed += 1
		print("  ✗ FAIL: ", msg)


func _test_split() -> void:
	print("[1] the spec splits at the separator")
	var a: Dictionary = PaintPalette.split_spec("painted_metal@olive_drab")
	_check(a["material"] == "painted_metal" and a["paint"] == "olive_drab", "material@paint")
	var b: Dictionary = PaintPalette.split_spec("steel_dark")
	_check(b["material"] == "steel_dark" and b["paint"] == "", "no paint")
	_check(PaintPalette.color_of("olive_drab") == PaintPalette.PAINTS["olive_drab"], "a known paint answers its colour")


func _test_repaint() -> void:
	print("[2] repaint recolours the painted surfaces and only those")
	var board := StubBoard.new()
	root.add_child(board)
	var prop := PropMesh3D.new()
	board.add_child(prop)
	var model: Dictionary = prop.build_model(board, GRENADE, Vector3.ZERO, Vector3(0.2, 0.2, 0.2),
		{"Green": "painted_metal@olive_drab", "DarkGreen": "painted_metal@olive_drab", "DarkGrey": "steel_dark"}, "metal")
	_check(not model.is_empty(), "the model loads")
	var painted: Array = []
	var plain: Array = []
	for mi in prop.find_children("*", "MeshInstance3D", true, false):
		var node := mi as MeshInstance3D
		for s in range(node.mesh.get_surface_count()):
			var m := node.get_surface_override_material(s) as ShaderMaterial
			(painted if m.get_shader_parameter("albedo") == PaintPalette.PAINTS["olive_drab"] else plain).append(m)
	_check(painted.size() >= 1 and plain.size() >= 1, "%d painted surface(s), %d plain" % [painted.size(), plain.size()])
	var plain_before: Array = plain.map(func(m: ShaderMaterial) -> Color: return m.get_shader_parameter("albedo"))
	prop.repaint("sand")
	_check(painted.all(func(m: ShaderMaterial) -> bool: return m.get_shader_parameter("albedo") == PaintPalette.PAINTS["sand"]),
		"every painted surface now wears sand")
	var plain_after: Array = plain.map(func(m: ShaderMaterial) -> Color: return m.get_shader_parameter("albedo"))
	_check(plain_before == plain_after, "the unpainted surfaces did not change")
	board.free()
