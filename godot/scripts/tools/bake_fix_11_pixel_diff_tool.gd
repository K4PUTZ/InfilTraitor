## BAKE-FIX-14: Real Pixel-by-Pixel Alpha Comparison (B3 Closure, Attempt 9)
##
## CORRECTION (vs BAKE-FIX-11/13): Prior attempts either compared layout-dictionary
## keys (no pixels at all) or called a generic-image accessor hardcoded to return
## null, so the comparison branch never executed.
##
## CORRECTION (post-implementation review, same day): an earlier version of this file
## compared the baked atom against `BakeCompositor.get_canonical_voxel_atom()`, which
## read the exact same in-memory Image (`_voxel_atoms[material_id]`, loaded once via
## `Image.load()`) that `_get_canonical_alpha()` already reads from to WRITE each baked
## atom's alpha in the first place — a tautological self-comparison that could not fail
## regardless of whether the real generic rendering path ever diverges. Fixed: the
## canonical side is now loaded independently via `load(VoxelRenderer.VOXEL_ASSET_TEMPLATE
## % material).get_image()` — the actual Godot resource-import pipeline VoxelRenderer's
## generic (non-baked) path uses (`_build_voxel_tileset()`), a genuinely different code
## path from BakeCompositor's raw `Image.load()`. If the two ever diverge (e.g. import
## settings change to lossy/VRAM compression, or the bake loop misindexes a pixel), this
## comparison can now actually catch it.
##
## - "Baked" side: Image atoms produced by BakeCompositor.bake() (real compositing).
## - "Generic" side: the real voxel texture loaded via VoxelRenderer's own resource path
##   (res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_<material>.png via `load()`).
##   No SubViewport is needed: `Texture2D.get_image()` decodes the already-imported
##   resource without any GPU/rendering-server draw call, so this works headless.
##
## What B3 actually requires ("alpha comes exclusively from the canonical material
## atlas, never synthesized"): every baked atom's alpha channel must exactly equal the
## canonical texture's alpha channel, pixel-by-pixel, for every material and every atom
## in every strip. RGB is allowed to differ (facade luminance/pattern shading is
## intentionally baked into RGB) but is reported per-material regardless.
##
## Run: godot --headless --script godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd

extends SceneTree

const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var _test_results: Array = []


func _init() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FIX-14: Real Pixel-by-Pixel Alpha Comparison (B3 Closure, Attempt 9)")
	print("=".repeat(80))
	print("Baked atom Image vs canonical voxel texture (VoxelRenderer's own load path)")
	print("=".repeat(80) + "\n")

	var registry = MaterialRegistryClass.new()
	registry.register_defaults()
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("PLAYGROUND")

	if map_spec == null or map_spec.is_empty():
		_record_result("Map loading", "FAIL", "Could not load PLAYGROUND")
		_print_summary()
		quit(1)
		return

	_record_result("Map loading", "PASS", "Loaded PLAYGROUND map")
	print("✓ Loaded PLAYGROUND map\n")

	print("Calling BakeCompositor.bake()...")
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(registry)
	var resolver = TextureResolverClass.new()
	var baked_atlas = compositor.bake(map_spec, resolver)

	if baked_atlas == null or baked_atlas.strips.is_empty():
		_record_result("BakeCompositor.bake()", "FAIL", "No strips produced")
		_print_summary()
		quit(1)
		return

	_record_result("BakeCompositor.bake()", "PASS", "Produced %d strips" % baked_atlas.strips.size())
	print("✓ BakeCompositor produced %d master strips\n" % baked_atlas.strips.size())

	_test_alpha_matches_canonical(baked_atlas)

	_print_summary()
	quit(0 if _all_pass() else 1)


## Load the canonical voxel texture the same way VoxelRenderer's generic path does —
## via load() (Godot's resource/import pipeline), NOT BakeCompositor's raw Image.load().
func _load_canonical_via_renderer_path(material_id: String) -> Image:
	var path = VoxelRendererClass.VOXEL_ASSET_TEMPLATE % material_id
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	return texture.get_image()


## Real test: every baked atom's alpha must equal the canonical texture's alpha,
## pixel-by-pixel, where "canonical" is loaded independently of BakeCompositor.
func _test_alpha_matches_canonical(baked_atlas) -> void:
	print("[TEST] Baked Atom Alpha vs Canonical Voxel Texture (per material, per atom)")
	print("-".repeat(80) + "\n")

	var materials_tested: Array = []
	var grand_total_pixels: int = 0
	var grand_alpha_mismatches: int = 0
	var grand_rgb_differences: int = 0

	for strip_key in baked_atlas.strips:
		var strip = baked_atlas.strips[strip_key]
		var material_id: String = strip.material_id

		if strip.atoms == null or strip.atoms.is_empty():
			_record_result("Atoms present for '%s'" % material_id, "FAIL",
				"strip '%s' has no atoms — cannot verify alpha" % strip_key)
			continue

		var canonical: Image = _load_canonical_via_renderer_path(material_id)

		if canonical == null:
			_record_result("Canonical texture for '%s'" % material_id, "FAIL",
				"load(%s) returned null or has no Image data" % [VoxelRendererClass.VOXEL_ASSET_TEMPLATE % material_id])
			continue

		if material_id in materials_tested:
			pass
		else:
			materials_tested.append(material_id)
		print("  Material: %s (strip: %s, %d atoms)" % [material_id, strip_key, strip.atoms.size()])

		var strip_alpha_mismatches := 0
		var strip_rgb_diffs := 0
		var strip_pixels := 0
		var first_mismatch := ""

		for atom_idx in range(strip.atoms.size()):
			var baked_atom: Image = strip.atoms[atom_idx]
			if not (baked_atom is Image):
				_record_result("Atom type for %s[%d]" % [material_id, atom_idx], "FAIL",
					"strip.atoms[%d] is not an Image (got %s)" % [atom_idx, typeof(baked_atom)])
				continue
			if baked_atom.get_width() != canonical.get_width() or baked_atom.get_height() != canonical.get_height():
				_record_result("Atom size for %s[%d]" % [material_id, atom_idx], "FAIL",
					"Baked %dx%d vs canonical %dx%d" % [baked_atom.get_width(), baked_atom.get_height(), canonical.get_width(), canonical.get_height()])
				continue

			for y in range(baked_atom.get_height()):
				for x in range(baked_atom.get_width()):
					var b := baked_atom.get_pixel(x, y)
					var c := canonical.get_pixel(x, y)
					strip_pixels += 1

					if abs(b.a - c.a) > 0.001:
						strip_alpha_mismatches += 1
						if first_mismatch == "":
							first_mismatch = "atom[%d] (%d,%d): baked_a=%.4f canonical_a=%.4f" % [atom_idx, x, y, b.a, c.a]

					if b.r != c.r or b.g != c.g or b.b != c.b:
						strip_rgb_diffs += 1

		grand_total_pixels += strip_pixels
		grand_alpha_mismatches += strip_alpha_mismatches
		grand_rgb_differences += strip_rgb_diffs

		if strip_pixels == 0:
			_record_result("Alpha match: %s" % material_id, "FAIL",
				"0 pixels were actually compared (all atoms skipped) — no real evidence for this material")
			print("    ✗ No pixels compared — every atom was skipped\n")
			continue

		var rgb_pct = 100.0 * strip_rgb_diffs / strip_pixels
		print("    Pixels checked: %d" % strip_pixels)
		print("    Alpha mismatches: %d" % strip_alpha_mismatches)
		print("    RGB differences: %d (%.1f%%) — expected if facade luminance/pattern shading applies to '%s'" % [strip_rgb_diffs, rgb_pct, material_id])

		if strip_alpha_mismatches == 0:
			_record_result("Alpha match: %s" % material_id, "PASS",
				"%d pixels, 0 alpha mismatches (RGB diffs: %d, %.1f%% — facade shading, not alpha)" % [strip_pixels, strip_rgb_diffs, rgb_pct])
			print("    ✓ Alpha matches canonical exactly\n")
		else:
			_record_result("Alpha match: %s" % material_id, "FAIL",
				"%d/%d pixels mismatch alpha; first: %s" % [strip_alpha_mismatches, strip_pixels, first_mismatch])
			print("    ✗ Alpha differs from canonical — first mismatch: %s\n" % first_mismatch)

	if materials_tested.is_empty():
		_record_result("Coverage", "FAIL", "No materials were actually tested")
		return

	print("-".repeat(80))
	print("Materials tested: %s" % [materials_tested])
	print("Grand total: %d pixels, %d alpha mismatches, %d RGB differences" % [grand_total_pixels, grand_alpha_mismatches, grand_rgb_differences])

	if grand_total_pixels == 0:
		_record_result("Overall alpha-from-canon", "FAIL", "0 total pixels compared — no real evidence")
	elif grand_alpha_mismatches == 0:
		_record_result("Overall alpha-from-canon", "PASS",
			"%d pixels across %d materials, 0 alpha mismatches" % [grand_total_pixels, materials_tested.size()])
	else:
		_record_result("Overall alpha-from-canon", "FAIL",
			"%d/%d pixels mismatch alpha across %d materials" % [grand_alpha_mismatches, grand_total_pixels, materials_tested.size()])


func _record_result(test_name: String, status: String, detail: String) -> void:
	_test_results.append({"name": test_name, "status": status, "detail": detail})


func _all_pass() -> bool:
	for result in _test_results:
		if result["status"] != "PASS":
			return false
	return true


func _print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FIX-14: Alpha-from-Canon Comparison Results")
	print("=".repeat(80))

	var pass_count = 0
	var fail_count = 0

	for result in _test_results:
		if result["status"] == "PASS":
			pass_count += 1
			print("✓ %s: %s" % [result["name"], result["detail"]])
		else:
			fail_count += 1
			print("✗ %s: %s" % [result["name"], result["detail"]])

	print("\n" + "-".repeat(80))
	print("Results: %d PASS, %d FAIL" % [pass_count, fail_count])

	if fail_count == 0 and pass_count > 0:
		print("\n✓ B3 EVIDENCE: baked alpha is pixel-identical to the independently-loaded canonical voxel texture")
	else:
		print("\n✗ B3 NOT SUPPORTED BY EVIDENCE — see mismatches above")

	print("=".repeat(80) + "\n")
