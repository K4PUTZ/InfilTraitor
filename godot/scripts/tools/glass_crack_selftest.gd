## GLASS_MASTER_PLAN §8.1 / CRACK-01 — the CRACKED tier for glass.
## Rodar: python3 tools/persistent/run_selftests.py --only glass_crack
##
## §8.1 was written up as a CONTRADICTION: the art order's step 3 asked to raise
## `glass.json`'s `crack_factor` above 0 and add `glass` to
## `IMPACT_DECAL_MATERIALS`, which together make `voxel_decal_selftest` [12]
## demand `decal_crack_glass_{0,1,2}.png` — the per-voxel crack family G-D21
## explicitly folded into the fracture SHEET.
##
## The resolution (Director, 2026-09-02): glass reaches CRACKED by the route it
## ALREADY has — `ShotPunchTable.damage_state_for()` returns CRACKED for a
## sub-breach glass hit — and NOT through the blast `crack_factor` probability
## path. So `crack_factor` stays 0.0, `glass` stays out of both decal lists, and
## the whole [12] coupling is untouched. Glass is simply the first material whose
## CRACKED art is a sheet, not a decal family.
##
## This suite is the guard on that resolution — it fails if a future edit "fixes"
## §8.1 by commissioning the decal family, and (from CRACK-01 stages B/C) it
## grows to pin the render and the shot-path event.
##
## What each test catches:
##   [1] the CRACKED tier going unreachable for glass — the enum path breaking.
##   [2] a crack DECAL FAMILY appearing for glass — in data, in the wiring lists,
##       or on disk.
##   [3] the fracture SHEETS (the real CRACKED art) going missing or unimported.

extends SceneTree

const ShotPunchTableClass = preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GlassMaterialsClass = preload("res://godot/scripts/systems/glass_materials.gd")

const CRACK_DECAL_TEMPLATE := "res://ASSETS/materials/glass/decals/decal_crack_glass_%d.png"
const FRACTURE_TEMPLATE := "res://ASSETS/materials/glass/fracture_glass_%s.png"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS §8.1 / CRACK-01 — CRACKED TIER SELFTEST")
	print("=".repeat(70) + "\n")

	test_glass_reaches_cracked_through_the_shot_ladder()
	test_glass_has_no_crack_decal_family()
	test_the_fracture_sheets_are_the_cracked_art()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ GLASS CRACK-01 CRACKED-TIER SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ GLASS CRACK-01 CRACKED-TIER SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## [1] §8.1 — the CRACKED tier is reachable for glass without any of the
## `crack_factor` machinery. `damage_state_for()` is the shot ladder: below the
## breach it returns CRACKED, at or above it DESTROYED (G-D3: glass fractures, it
## never DENTS). If this ever stops returning CRACKED, CRACK-01's event has
## nothing valid to set on the surviving ring around a hole.
func test_glass_reaches_cracked_through_the_shot_ladder() -> void:
	print("[1] glass reaches CRACKED through damage_state_for(), sub-breach\n")

	var breach: float = ShotPunchTableClass.destroy_min("glass")
	var below: int = ShotPunchTableClass.damage_state_for(breach * 0.5, breach, "glass")
	var at_or_above: int = ShotPunchTableClass.damage_state_for(breach * 2.0, breach, "glass")

	if below == Voxel.DamageState.CRACKED:
		_pass("a sub-breach glass hit (punch %.2f < %.2f) is CRACKED" % [breach * 0.5, breach])
	else:
		_fail("a sub-breach glass hit resolved to %d, not CRACKED (%d) — the tier is unreachable"
			% [below, Voxel.DamageState.CRACKED])

	if at_or_above == Voxel.DamageState.DESTROYED:
		_pass("a breaching glass hit (punch %.2f >= %.2f) is DESTROYED, not CRACKED" % [breach * 2.0, breach])
	else:
		_fail("a breaching glass hit resolved to %d, expected DESTROYED (%d)"
			% [at_or_above, Voxel.DamageState.DESTROYED])

	## The DENTED rung must stay impossible (G-D3 / V-D) — pinned in full by
	## glass_shatter_selftest.test_glass_never_dents(); asserted here only at the
	## band edge this test already has the numbers for.
	var band: int = ShotPunchTableClass.damage_state_for(
		maxf(breach - 0.01, 0.0), breach, "glass")
	if band != Voxel.DamageState.DENTED:
		_pass("nothing in the sub-breach band DENTS glass (edge case punch %.2f -> %d)"
			% [maxf(breach - 0.01, 0.0), band])
	else:
		_fail("glass DENTED at punch %.2f — G-D3 says it never can" % maxf(breach - 0.01, 0.0))

	print("")


## [2] §8.1 — and it does so with NO crack decal family, on every axis a future
## edit could add one: the resistance data, the two wiring lists, the name the
## renderer composes, and the files on disk.
func test_glass_has_no_crack_decal_family() -> void:
	print("[2] glass has no crack DECAL family — data, wiring, and disk\n")

	var cf: float = MaterialResistanceTableClass.crack_factor("glass")
	if is_zero_approx(cf):
		_pass("glass crack_factor is 0.0 — the blast crack-probability path is deliberately not the route")
	else:
		_fail("glass crack_factor is %.2f — that path demands decal_crack_glass_* (voxel_decal_selftest [12])" % cf)

	if not VoxelRendererClass.IMPACT_CRACK_MATERIALS.has("glass"):
		_pass("glass is not in IMPACT_CRACK_MATERIALS (that list composes *_blast_cracked_all_*)")
	else:
		_fail("glass is in IMPACT_CRACK_MATERIALS — it would ask for a blast-crack decal family")

	if not VoxelRendererClass.IMPACT_DECAL_MATERIALS.has("glass"):
		_pass("glass is not in IMPACT_DECAL_MATERIALS (that list composes *_bullet_cracked_*)")
	else:
		_fail("glass is in IMPACT_DECAL_MATERIALS — it would ask for a bullet-crack decal family")

	## The name the renderer composes for a CRACKED glass voxel must never be a
	## decal path — it falls back to the flat "glass_cracked", which the glass
	## render path ignores in favour of _glass_atom_source.
	for blast in [false, true]:
		var name: String = VoxelRendererClass.damage_variant_material(
			"glass", Voxel.DamageState.CRACKED, blast, Voxel.CarvedSide.NONE, 0)
		if name.contains("decal_") or name.contains("/"):
			_fail("CRACKED glass (blast=%s) resolves to a decal path: %s" % [blast, name])
		else:
			_pass("CRACKED glass (blast=%s) resolves to the flat fallback '%s', not a decal" % [blast, name])

	var on_disk: Array = []
	for v in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
		if FileAccess.file_exists(CRACK_DECAL_TEMPLATE % v):
			on_disk.append(CRACK_DECAL_TEMPLATE % v)
	if on_disk.is_empty():
		_pass("no decal_crack_glass_*.png on disk — G-D21 folded the per-voxel family into the sheet")
	else:
		_fail("decal_crack_glass_*.png exists (%s) — the sheet IS the crack art; delete these" % ", ".join(on_disk))

	print("")


## [3] the fracture sheets are the actual CRACKED art (G-D14 / G-D21). Delivered
## and gated by check_decal.py already; pinned here so the suite that grows to
## test the crack RENDER fails loudly if its texture source vanishes.
func test_the_fracture_sheets_are_the_cracked_art() -> void:
	print("[3] the two fracture sheets exist, are imported, and are named as CRACK-01 expects\n")

	if Array(GlassMaterialsClass.FRACTURE_WIDTHS) == ["tight", "wide"]:
		_pass("GlassMaterials.FRACTURE_WIDTHS is [tight, wide] (G-D14's two hole sizes)")
	else:
		_fail("GlassMaterials.FRACTURE_WIDTHS is %s — CRACK-01 keys the render on exactly tight/wide"
			% str(GlassMaterialsClass.FRACTURE_WIDTHS))

	var tid: String = GlassMaterialsClass.fracture_texture_id("glass", "tight")
	if tid == "fracture_glass_tight":
		_pass("fracture_texture_id(glass, tight) == '%s'" % tid)
	else:
		_fail("fracture_texture_id(glass, tight) == '%s', expected fracture_glass_tight" % tid)

	for width in ["tight", "wide"]:
		var path: String = FRACTURE_TEMPLATE % width
		var import_path: String = path + ".import"
		if not FileAccess.file_exists(path):
			_fail("%s is missing — CRACK-01's render has no crack texture for '%s'" % [path, width])
		elif not FileAccess.file_exists(import_path):
			_fail("%s has no .import sidecar — Godot has not imported it, so it hard-errors at boot (B6)" % path)
		else:
			var tex := load(path) as Texture2D
			if tex == null:
				_fail("%s did not load as a Texture2D — the import is broken" % path)
			elif tex.get_width() != 1024 or tex.get_height() != 512:
				_fail("%s is %dx%d, expected 1024x512 (64x32-voxel page at TEX_AUTHORING_N=16)"
					% [path, tex.get_width(), tex.get_height()])
			else:
				_pass("%s is present, imported, and 1024x512" % path)

	print("")
