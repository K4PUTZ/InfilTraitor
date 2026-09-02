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
const GlassCrackClass = preload("res://godot/scripts/systems/destruction/glass_crack.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

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
	test_plan_pane_crack_marks_standing_glass_in_radius()
	test_plan_pane_crack_skips_destroyed_and_banded_frame()
	test_plan_pane_crack_run_axis_follows_the_face()
	test_wide_for_blowout_splits_the_arsenal()
	test_the_glass_shader_loads()
	test_apply_stamps_the_plane_and_gd24_crosses()

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


## ── CRACK-01 §B — the pure planner ──────────────────────────────────────────

## One SW-face glass panel pane, `storeys` tall, along X at gu y=3 — mirrors
## glass_shatter_selftest._pane(). `pane_id` stamped, every voxel visible.
func _pane(gx_lo: int, gx_hi: int, storeys: int, material: String = "glass") -> Array:
	var slices: Array = []
	var base: int = GeometryCoordsClass.storey_level_base(0)
	for gx in range(gx_lo, gx_hi + 1):
		var s := Slice.new("PANE_S_%d" % gx, Vector2i(gx, 3), Face.SW, "PANE_E_%d" % gx, storeys, material)
		s.pane_id = "PANE_TEST"
		for lvl_off in range(storeys * 8):
			for i in range(8):
				s.voxels.append(Voxel.new(Vector2i(gx * 8 + i, 3 * 8 + 7), base + lvl_off, s))
		slices.append(s)
	return slices


func test_plan_pane_crack_marks_standing_glass_in_radius() -> void:
	print("[4] plan_pane_crack marks the standing glass inside the crack radius\n")

	var pane := _pane(4, 9, 3)              ## 6 GU × 3 storeys = 1152 voxels
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var hit := Vector2i(6 * 8 + 4, 31)      ## mid-pane
	var hit_level: int = base + 12

	var tight: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit, hit_level, false)
	var wide: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit, hit_level, true)

	if tight.cells.size() > 0 and wide.cells.size() > tight.cells.size():
		_pass("tight web %d cells, wide web %d — wider hole, wider web (G-D14)"
			% [tight.cells.size(), wide.cells.size()])
	else:
		_fail("tight %d / wide %d — wide must reach further than tight"
			% [tight.cells.size(), wide.cells.size()])

	## Every returned cell is within the wide radius of the impact, on the run axis
	## and in level.
	var r := GlassCrackClass.CRACK_RADIUS_WIDE
	var outside := 0
	for e in wide.cells:
		var dr: int = absi(int(e.cell.x) - hit.x)
		var dl: int = absi(int(e.level) - hit_level)
		if dr > r.x or dl > r.y:
			outside += 1
	if outside == 0:
		_pass("all %d wide-web cells are inside the (%d,%d) radius of the impact"
			% [wide.cells.size(), r.x, r.y])
	else:
		_fail("%d wide-web cells fell outside the crack radius" % outside)

	if int(wide.impact_run) == hit.x and int(wide.run_axis) == 0:
		_pass("impact_run %d and run_axis 0 (X) match the SW face" % wide.impact_run)
	else:
		_fail("impact_run %s / run_axis %s, expected %d / 0" % [wide.impact_run, wide.run_axis, hit.x])

	print("")


func test_plan_pane_crack_skips_destroyed_and_banded_frame() -> void:
	print("[5] plan_pane_crack skips DESTROYED voxels and a G-D9 brick frame\n")

	var pane := _pane(4, 9, 3)
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var hit := Vector2i(6 * 8 + 4, 31)
	var hit_level: int = base + 10

	var full: int = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit, hit_level, true).cells.size()

	## Punch a hole: DESTROY a 3×3 block around the hit.
	for s in pane:
		for v in s.voxels:
			if absi(v.grid_pos.x - hit.x) <= 1 and absi(v.level - hit_level) <= 1:
				v.set_damage(Voxel.DamageState.DESTROYED, false, Voxel.CarvedSide.NONE, 0, 0)
	var holed: int = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit, hit_level, true).cells.size()
	if holed < full and holed == full - 9:
		_pass("a 9-voxel hole drops exactly those 9 from the web (%d -> %d)" % [full, holed])
	else:
		_fail("hole dropped %d cells, expected 9 (%d -> %d)" % [full - holed, full, holed])

	## A banded pane: brick sill (rel 0-1) and head (rel top-1..top) in the SAME
	## slices — a fracture must not cross the frame.
	var banded := _pane(4, 9, 3)
	var top: int = 3 * 8 - 1
	for s in banded:
		s.material_bands = {0: "brick", 1: "brick", top - 1: "brick", top: "brick"}
	var b_cells: int = GlassCrackClass.plan_pane_crack(banded, Face.SW, hit, hit_level, true).cells.size()
	var brick_in_web := 0
	for e in GlassCrackClass.plan_pane_crack(banded, Face.SW, hit, hit_level, true).cells:
		var rel: int = int(e.level) - base
		if rel <= 1 or rel >= top - 1:
			brick_in_web += 1
	if brick_in_web == 0 and b_cells < full:
		_pass("the brick sill/head are not in the web (%d cells vs %d unbanded)" % [b_cells, full])
	else:
		_fail("%d brick-band cells leaked into the web (%d total)" % [brick_in_web, b_cells])

	print("")


func test_plan_pane_crack_run_axis_follows_the_face() -> void:
	print("[6] the run axis is X for SW/NE, Y for SE/NW (matches GlassShatter)\n")

	var base: int = GeometryCoordsClass.storey_level_base(0)
	var hit := Vector2i(50, 31)
	var hit_level: int = base + 8

	## _pane() always authors an SW face; for the SE check, re-face its slices.
	var sw := _pane(4, 9, 2)
	var sw_plan: Dictionary = GlassCrackClass.plan_pane_crack(sw, Face.SW, hit, hit_level, false)
	if int(sw_plan.run_axis) == 0 and int(sw_plan.impact_run) == hit.x:
		_pass("SW face -> run_axis 0 (X), impact_run = grid_pos.x (%d)" % hit.x)
	else:
		_fail("SW face gave run_axis %s / impact_run %s" % [sw_plan.run_axis, sw_plan.impact_run])

	var se := _pane(4, 9, 2)
	for s in se:
		s.face = Face.SE
	var se_plan: Dictionary = GlassCrackClass.plan_pane_crack(se, Face.SE, hit, hit_level, false)
	if int(se_plan.run_axis) == 1 and int(se_plan.impact_run) == hit.y:
		_pass("SE face -> run_axis 1 (Y), impact_run = grid_pos.y (%d)" % hit.y)
	else:
		_fail("SE face gave run_axis %s / impact_run %s, expected 1 / %d"
			% [se_plan.run_axis, se_plan.impact_run, hit.y])

	print("")


func test_wide_for_blowout_splits_the_arsenal() -> void:
	print("[7] wide_for_blowout: pistol/pellet -> tight, rifle -> wide (G-D14)\n")

	var cases := {"pistol": 0.0, "shotgun": 0.0, "assault_rifle": 0.65}
	var want := {"pistol": false, "shotgun": false, "assault_rifle": true}
	var ok := true
	for wid in cases:
		var got: bool = GlassCrackClass.wide_for_blowout(cases[wid])
		if got != want[wid]:
			ok = false
			_fail("%s (blowout %.2f) -> wide=%s, expected %s" % [wid, cases[wid], got, want[wid]])
	if ok:
		_pass("blowout 0.0 -> tight, 0.65 -> wide — exactly the shipped split")

	print("")


func test_the_glass_shader_loads() -> void:
	print("[8] glass_pane.gdshader loads and takes CRACK-01's uniforms\n")

	var shader := load("res://godot/shaders/glass_pane.gdshader") as Shader
	if shader == null:
		_fail("glass_pane.gdshader did not load as a Shader")
		print("")
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	## Set every CRACK-01 uniform once — a name the shader does not declare is a
	## silent no-op in Godot, so this pins the wiring contract the renderer relies
	## on rather than proving compilation (which needs a real draw).
	mat.set_shader_parameter("glass_crack_plane_size", Vector2(512, 512))
	mat.set_shader_parameter("glass_crack_group_cap", 16.0)
	mat.set_shader_parameter("glass_layer_rel_level", 0.0)
	mat.set_shader_parameter("glass_sheet_voxels", Vector2(64, 32))
	mat.set_shader_parameter("glass_crack_see_through", 0.5)
	var props: Array = shader.get_shader_uniform_list()
	var names: Array = []
	for p in props:
		names.append(p.name)
	var required := ["glass_crack_plane", "glass_crack_groups", "glass_fracture_tight",
		"glass_fracture_wide", "glass_layer_origin", "glass_sheet_voxels"]
	var missing: Array = []
	for r in required:
		if not names.has(r):
			missing.append(r)
	if missing.is_empty():
		_pass("the shader declares all %d CRACK-01 uniforms the renderer feeds" % required.size())
	else:
		_fail("the shader is missing uniform(s): %s" % ", ".join(missing))

	print("")


## A stand-in for VoxelRenderer's crack-plane API — records what GlassCrack.apply
## writes, so G-D24 can be tested without a real renderer.
class MockRenderer:
	var plane: Dictionary = {}       ## Vector3i(cell.x, cell.y, level) -> gid
	var groups: Array = []           ## [{run, rel_level, axis, wide}]
	var _next: int = 0
	func alloc_glass_crack_group() -> int:
		_next = (_next % 16) + 1
		return _next
	func set_glass_crack_group(gid: int, run: int, rel: int, axis: int, wide: bool) -> void:
		while groups.size() < gid:
			groups.append({})
		groups[gid - 1] = {"run": run, "rel_level": rel, "axis": axis, "wide": wide}
	func write_glass_crack_cell(level: int, cell: Vector2i, gid: int) -> void:
		var k := Vector3i(cell.x, cell.y, level)
		if gid == 0:
			plane.erase(k)
		else:
			plane[k] = gid
	func glass_crack_group_at(level: int, cell: Vector2i) -> int:
		return int(plane.get(Vector3i(cell.x, cell.y, level), 0))
	func flush_glass_crack() -> int:
		return 0
	func relative_level(level: int) -> int:
		return level - GeometryCoordsClass.storey_level_base(0)


func test_apply_stamps_the_plane_and_gd24_crosses() -> void:
	print("[9] GlassCrack.apply stamps the plane; a crossed cell is DESTROYED (G-D24)\n")

	var pane := _pane(4, 9, 3)
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var mock := MockRenderer.new()

	## First crack, centred.
	var hit1 := Vector2i(6 * 8 + 4, 31)
	var lvl1: int = base + 10
	var plan1: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit1, lvl1, false)
	var r1: Dictionary = GlassCrackClass.apply(mock, plan1)
	if r1.crazed == plan1.cells.size() and r1.crossed == 0 and mock.plane.size() == r1.crazed:
		_pass("first crack: %d cells stamped, 0 crossings, plane holds them all" % r1.crazed)
	else:
		_fail("first crack: crazed %d / crossed %d / plane %d (expected %d / 0 / same)"
			% [r1.crazed, r1.crossed, mock.plane.size(), plan1.cells.size()])

	var cracked_1 := 0
	for e in plan1.cells:
		if e.voxel.damage_state == Voxel.DamageState.CRACKED:
			cracked_1 += 1
	if cracked_1 == plan1.cells.size():
		_pass("every stamped voxel is now CRACKED (%d)" % cracked_1)
	else:
		_fail("%d of %d stamped voxels reached CRACKED" % [cracked_1, plan1.cells.size()])

	## Second crack, overlapping — the shared cells cross.
	var hit2 := Vector2i(6 * 8 + 4 + 6, 31)
	var plan2: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit2, lvl1, false)
	var r2: Dictionary = GlassCrackClass.apply(mock, plan2)
	if r2.crossed > 0:
		_pass("second crack: %d cells crossed the first web -> DESTROYED (G-D24)" % r2.crossed)
	else:
		_fail("second overlapping crack produced 0 crossings — G-D24 never fired")

	var destroyed := 0
	for f in r2.fallen:
		destroyed += 1
	for e in plan2.cells:
		if e.voxel.damage_state == Voxel.DamageState.DESTROYED:
			pass
	if destroyed == r2.crossed and not r2.fallen.is_empty():
		_pass("the %d crossed voxels are DESTROYED and handed to GlassFall" % destroyed)
	else:
		_fail("fallen list has %d, crossed count %d" % [destroyed, r2.crossed])

	## A crossed cell is cleared from the plane (0), not left pointing at a group.
	var still_pointing := 0
	for f in r2.fallen:
		if mock.glass_crack_group_at(int(f.level), f.grid_pos) != 0:
			still_pointing += 1
	if still_pointing == 0:
		_pass("every crossed cell is cleared from the crack plane")
	else:
		_fail("%d crossed cells still carry a group id" % still_pointing)

	print("")
