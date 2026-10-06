## R3D-SURFACES `material_tints` (per-map colour of a material): the albedo -> base_color conversion on real rows, the section through
## FileMapSource and MapCompiler on the real SURFACES_GALLERY map, and a malformed tint being refused.
extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== MATERIAL TINTS SELFTEST ==\n")
	var registry = MaterialRegistryClass.new()
	registry.load_from_disk()
	var stripe = registry.registry["carpet_stripe"]
	_check(stripe.facade_mean > 100.0, "carpet_stripe records its facade mean (%.1f)" % stripe.facade_mean)
	var albedo := Color(0.30, 0.20, 0.10)
	var base: Color = stripe.base_color_for_albedo(albedo)
	var reads_as: Color = base * (stripe.facade_mean / 255.0)
	_check(absf(reads_as.r - albedo.r) < 0.01 and absf(reads_as.g - albedo.g) < 0.01 and absf(reads_as.b - albedo.b) < 0.01,
		"base_color x facade mean gives back the albedo (%s -> %s)" % [str(albedo), str(reads_as)])
	var grating = registry.registry["grating"]
	_check(grating.base_color_for_albedo(Color(0.9, 0.9, 0.9)).r <= 1.0, "a bright albedo on a dark facade clips to 1.0, never above")
	var flat = registry.registry["ceramic"]
	_check(flat.base_color_for_albedo(Color(0.4, 0.5, 0.6)).is_equal_approx(Color(0.4, 0.5, 0.6)), "a flat material (no facade) takes the albedo as is")
	_check(registry.registry["carpet_stripe_blue"].facade_mean == stripe.facade_mean, "a colour variant records its pattern's mean")

	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("SURFACES_GALLERY")
	_check((spec.get("material_tints", {}) as Dictionary).has("carpet"), "the gallery's `material_tints` reaches the runtime spec")
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var tints: Dictionary = layout.get("material_tints", {})
	_check(tints.has("carpet") and tints["carpet"] is Color, "MapCompiler forwards it as Colors (%s)" % str(tints))
	var bad_spec: Dictionary = spec.duplicate(true)
	bad_spec["material_tints"] = {"carpet": [2.0, 0.1, 0.1], "parquet": [0.5, 0.5], "tile": [0.5, 0.6, 0.7]}
	var bad: Dictionary = MapCompilerClass.compile(bad_spec).get("material_tints", {})
	_check(bad.size() == 1 and bad.has("tile"), "a channel above 1 and a 2-channel tint are refused (loudly), the good one stays (%s)" % str(bad.keys()))
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
