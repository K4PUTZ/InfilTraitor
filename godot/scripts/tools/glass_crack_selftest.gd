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
##   [8] the crack coming back INSIDE glass_pane.gdshader — CRACK-02 / G-D27 took
##       it out of the voxel because a crack drawn there inherits `dim`, `cover`
##       and the quad seams, and no tuning survives that.
##   [10] the sheet shearing off the voxels — the CRACK-01-B/C bug, now pinned
##       against the SPRITE'S OWN TRANSFORM instead of a shader inverse.
##   [11] a crack bleeding past the frame of the pane it is on.
##   [12] G-D30's cut reading anything other than the live glass tilemap, the
##       occupancy rows going upside down, or the dial collapsing to a boolean.

extends SceneTree

const ShotPunchTableClass = preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GlassMaterialsClass = preload("res://godot/scripts/systems/glass_materials.gd")
const GlassCrackClass = preload("res://godot/scripts/systems/destruction/glass_crack.gd")
const GlassCrackSpriteClass = preload("res://godot/scripts/overlays/glass_crack_sprite.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

const CRACK_DECAL_TEMPLATE := "res://ASSETS/materials/glass/decals/decal_crack_glass_%d.png"
const FRACTURE_TEMPLATE := "res://ASSETS/materials/glass/fracture_glass_%s.png"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS §8.1 / CRACK-01+02 — CRACKED TIER AND THE CRACK SPRITE")
	print("=".repeat(70) + "\n")

	test_glass_reaches_cracked_through_the_shot_ladder()
	test_glass_has_no_crack_decal_family()
	test_the_fracture_sheets_are_the_cracked_art()
	test_plan_pane_crack_marks_standing_glass_in_radius()
	test_plan_pane_crack_skips_destroyed_and_banded_frame()
	test_plan_pane_crack_run_axis_follows_the_face()
	test_wide_for_blowout_splits_the_arsenal()
	test_the_glass_shaders_split_the_crack_out()
	test_apply_spawns_a_sprite_and_gd24_crosses()
	test_the_sprite_transform_lands_on_the_voxels()
	test_the_pane_bounds_clip_the_sprite()
	test_the_occupancy_cut_reads_the_live_tilemap()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ GLASS CRACK-02 SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ GLASS CRACK-02 SELFTEST FAILED\n")
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
	print("[3] the two fracture sheets exist, import, and match the span they are drawn at\n")

	if Array(GlassMaterialsClass.FRACTURE_WIDTHS) == ["tight", "wide"]:
		_pass("GlassMaterials.FRACTURE_WIDTHS is [tight, wide] (G-D14's two hole sizes)")
	else:
		_fail("GlassMaterials.FRACTURE_WIDTHS is %s — the crack keys the sheet on exactly tight/wide"
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
			_fail("%s is missing — the crack sprite has no texture for '%s'" % [path, width])
		elif not FileAccess.file_exists(import_path):
			_fail("%s has no .import sidecar — Godot has not imported it, so it hard-errors at boot (B6)" % path)
		else:
			var tex := load(path) as Texture2D
			if tex == null:
				_fail("%s did not load as a Texture2D — the import is broken" % path)
			else:
				## ⚠️ NO PIXEL-SIZE CONTRACT SINCE CRACK-02 (§13.3). The sheet is a
				## SPRITE's texture scaled to GlassCrack.SHEET_SPAN_*, so its
				## dimensions are resolution, not geometry; `check_decal.py` owns
				## the art gate (aspect, ink, origin) and pinning 1024x512 here
				## would reject good free-size art from the other side.
				## What still matters at RUNTIME is that it is not degenerate.
				var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
				var span: Vector2 = GlassCrackClass.sheet_span(width == "wide")
				var want: float = span.x / span.y
				if tex.get_width() < 128 or tex.get_height() < 128:
					_fail("%s is %dx%d — too small to carry a web at any span"
						% [path, tex.get_width(), tex.get_height()])
				elif absf(aspect - want) > 0.05 * want:
					_fail("%s is %dx%d (aspect %.2f) but its span is %.0fx%.0f (aspect %.2f) — it arrives on the pane stretched"
						% [path, tex.get_width(), tex.get_height(), aspect, span.x, span.y, want])
				else:
					_pass("%s is present, imported, %dx%d, and matches its %.0fx%.0f-voxel span"
						% [path, tex.get_width(), tex.get_height(), span.x, span.y])

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

	## A banded pane: brick sill (rel 0-1), head (rel top-1..top) AND a mid-pane
	## brick transom at rel 8-9, in the SAME slices — a fracture must not cross the
	## frame. ⚠️ The transom is what makes this test mean anything: the sill and
	## head sit outside the (tightened) crack radius, so a fixture with only those
	## would pass vacuously — banded and unbanded would return the same cells.
	var banded := _pane(4, 9, 3)
	var top: int = 3 * 8 - 1
	for s in banded:
		s.material_bands = {0: "brick", 1: "brick", 8: "brick", 9: "brick",
			top - 1: "brick", top: "brick"}
	var b_cells: int = GlassCrackClass.plan_pane_crack(banded, Face.SW, hit, hit_level, true).cells.size()
	var brick_in_web := 0
	for e in GlassCrackClass.plan_pane_crack(banded, Face.SW, hit, hit_level, true).cells:
		var rel: int = int(e.level) - base
		if rel <= 1 or rel == 8 or rel == 9 or rel >= top - 1:
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


func test_the_glass_shaders_split_the_crack_out() -> void:
	print("[8] the crack left glass_pane.gdshader, and glass_crack.gdshader took it\n")

	var pane_shader := load("res://godot/shaders/glass_pane.gdshader") as Shader
	if pane_shader == null:
		_fail("glass_pane.gdshader did not load as a Shader")
		print("")
		return

	## ⚠️ CRACK-02 / G-D27 — THE PANE SHADER MUST CARRY NO CRACK AT ALL.
	## CRACK-01 put the web in here and the Director rejected it three times; the
	## third rejection was the mechanism, not the tuning: a crack drawn by the
	## voxel shader inherits the atom's `dim`, the coverage alpha and the quad
	## seams. Any crack uniform reappearing on this shader is that design coming
	## back, whatever it is called.
	var pane_names: Array = []
	for prop in pane_shader.get_shader_uniform_list():
		pane_names.append(prop.name)
	var leaked: Array = []
	for n in pane_names:
		if String(n).contains("crack") or String(n).contains("fracture"):
			leaked.append(n)
	if leaked.is_empty():
		_pass("glass_pane.gdshader declares no crack/fracture uniform — the web is not the voxel's any more")
	else:
		_fail("glass_pane.gdshader is drawing the crack again (%s) — G-D27 moved it to a sprite"
			% ", ".join(leaked))

	var crack_shader := load("res://godot/shaders/glass_crack.gdshader") as Shader
	if crack_shader == null:
		_fail("glass_crack.gdshader did not load as a Shader — the crack has no renderer")
		print("")
		return
	var names: Array = []
	for prop in crack_shader.get_shader_uniform_list():
		names.append(prop.name)
	var required := ["crack_sheet", "crack_span", "crack_pane_lo", "crack_pane_hi",
		"crack_color", "crack_strength", "crack_edge_feather"]
	var missing: Array = []
	for r in required:
		if not names.has(r):
			missing.append(r)
	if missing.is_empty():
		_pass("glass_crack.gdshader declares all %d uniforms GlassCrackSprite feeds" % required.size())
	else:
		_fail("glass_crack.gdshader is missing uniform(s): %s" % ", ".join(missing))

	## G-D26 stays in force and is now enforced by the BLEND MODE rather than by
	## arithmetic inside someone else's shader: `blend_add` is
	## `dst.rgb += src.rgb * src.a`, so the glass behind is untouched by
	## construction and a cracked voxel cannot frame itself.
	var src := FileAccess.get_file_as_string("res://godot/shaders/glass_crack.gdshader")
	if src.contains("render_mode blend_add"):
		_pass("the crack sprite is `render_mode blend_add` — additive by construction (G-D26)")
	else:
		_fail("glass_crack.gdshader is not blend_add — the crack would modulate the pane (G-D26 retracted G-D19 for exactly this)")
	if src.contains("discard"):
		_pass("the sprite discards outside the pane bounds — G-D27's one named cost, paid")
	else:
		_fail("no pane clipping in glass_crack.gdshader: a crack near a frame will bleed over what is beside it")

	print("")


## A stand-in for VoxelRenderer's CRACK-02 crack registry — records what
## GlassCrack.apply spawns and answers G-D24's geometric test, so the rule can be
## tested without a real renderer.
class MockRenderer:
	var cracks: Array = []            ## the spawned specs, in order
	var _next: int = 0

	## G-D24, exactly as VoxelRenderer.glass_crack_covering() does it.
	func glass_crack_covering(pane_id: String, run: int, level: int) -> int:
		for c in cracks:
			if String(c["pane_id"]) != pane_id:
				continue
			var r: Vector2i = c["radius"]
			if absi(run - int(c["impact_run"])) > r.x:
				continue
			if absi(level - int(c["impact_level"])) > r.y:
				continue
			return int(c["id"])
		return 0

	func spawn_glass_crack(spec: Dictionary) -> int:
		_next += 1
		var rec := spec.duplicate()
		rec["id"] = _next
		cracks.append(rec)
		return _next

	func relative_level(level: int) -> int:
		return level - GeometryCoordsClass.storey_level_base(0)

	## The same wall-face geometry VoxelRenderer.glass_cell_face_pos() uses:
	## map_to_local's e1 (16,8) / e2 (-16,8), minus VOXEL_STEP_PX per level.
	func glass_cell_face_pos(level: int, cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x - cell.y) * 16.0,
			float(cell.x + cell.y) * 8.0 - 20.0 * float(relative_level(level)))


func test_apply_spawns_a_sprite_and_gd24_crosses() -> void:
	print("[9] GlassCrack.apply spawns ONE crack; a covered cell is DESTROYED (G-D24)\n")

	var pane := _pane(4, 9, 3)
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var mock := MockRenderer.new()

	## First crack, centred.
	var hit1 := Vector2i(6 * 8 + 4, 31)
	var lvl1: int = base + 10
	var plan1: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit1, lvl1, false)
	var r1: Dictionary = GlassCrackClass.apply(mock, plan1)
	if r1.crazed == plan1.cells.size() and r1.crossed == 0 and mock.cracks.size() == 1:
		_pass("first crack: %d cells crazed, 0 crossings, exactly ONE sprite spawned" % r1.crazed)
	else:
		_fail("first crack: crazed %d / crossed %d / sprites %d (expected %d / 0 / 1)"
			% [r1.crazed, r1.crossed, mock.cracks.size(), plan1.cells.size()])

	var cracked_1 := 0
	for e in plan1.cells:
		if e.voxel.damage_state == Voxel.DamageState.CRACKED:
			cracked_1 += 1
	if cracked_1 == plan1.cells.size():
		_pass("every cell in the web is now CRACKED (%d)" % cracked_1)
	else:
		_fail("%d of %d web cells reached CRACKED" % [cracked_1, plan1.cells.size()])

	## ⚠️ THE ORDER TEST. `apply` must resolve every crossing BEFORE registering
	## its own crack, or the fracture crosses itself and destroys its own web.
	## r1.crossed == 0 above is that check; this makes the reason explicit.
	if r1.crossed == 0 and int(r1.crack_id) == 1:
		_pass("a fracture does not cross ITSELF — the registry is written after the test, not before")
	else:
		_fail("the new crack was registered before its own crossing test (crossed=%d)" % r1.crossed)

	## Second crack, overlapping — the shared cells cross.
	var hit2 := Vector2i(6 * 8 + 4 + 6, 31)
	var plan2: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit2, lvl1, false)
	var r2: Dictionary = GlassCrackClass.apply(mock, plan2)
	if r2.crossed > 0:
		_pass("second crack: %d cells fell inside the first crack's region -> DESTROYED (G-D24)" % r2.crossed)
	else:
		_fail("second overlapping crack produced 0 crossings — G-D24 never fired")

	if r2.fallen.size() == r2.crossed and not r2.fallen.is_empty():
		_pass("the %d crossed voxels are DESTROYED and handed to GlassFall" % r2.fallen.size())
	else:
		_fail("fallen list has %d, crossed count %d" % [r2.fallen.size(), r2.crossed])

	var still_standing := 0
	for f in r2.fallen:
		for s in pane:
			for v in s.voxels:
				if v.grid_pos == f.grid_pos and v.level == int(f.level) \
						and v.damage_state != Voxel.DamageState.DESTROYED:
					still_standing += 1
	if still_standing == 0:
		_pass("no crossed cell survived as CRACKED — the piece drops out, it does not re-craze")
	else:
		_fail("%d crossed cells are still standing" % still_standing)

	## A crack on ANOTHER pane must not cross this one, however close the coords.
	var other := _pane(4, 9, 3)
	for s in other:
		s.pane_id = "PANE_OTHER"
	var plan3: Dictionary = GlassCrackClass.plan_pane_crack(other, Face.SW, hit1, lvl1, false)
	var r3: Dictionary = GlassCrackClass.apply(mock, plan3)
	if r3.crossed == 0:
		_pass("a crack on a DIFFERENT pane crosses nothing, at identical coordinates")
	else:
		_fail("%d cells crossed across a pane boundary — the registry is not keyed by pane" % r3.crossed)

	print("")


## [10] THE BUG THAT SHIPPED IN CRACK-01-B/C, STILL PINNED — WITH THE BASIS IN ITS
## NEW JOB (Director, 2026-09-02: *"as linhas não se encontram e estão todas
## embaralhadas"*).
##
## CRACK-01 had the shader INVERT a canvas delta into (run, level) per fragment,
## and the first build used voxel_face_shading's GROUND-PLANE inverse, which
## answers a different question: on a vertical face the vertical screen axis is
## LEVEL, not ground depth. CRACK-02 does not invert anything — `GlassCrackSprite`
## bakes the FORWARD basis into the node's Transform2D — so this test now asserts
## the transform itself lands the sheet on the voxels, and keeps the ground-plane
## inverse as a CONTROL THAT MUST BE WRONG, so a test that recovered everything
## trivially could not pass.
func test_the_sprite_transform_lands_on_the_voxels() -> void:
	print("[10] the crack sprite's transform IS the wall-face basis (and the ground plane is not)\n")

	var sheet := load(FRACTURE_TEMPLATE % "tight") as Texture2D
	var shader := load("res://godot/shaders/glass_crack.gdshader") as Shader
	if sheet == null or shader == null:
		_fail("no fracture sheet / crack shader to build a sprite from")
		print("")
		return

	var mock := MockRenderer.new()
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var origin_cell := Vector2i(112, 87)
	var origin_level: int = base + 10
	var impact: Vector2 = mock.glass_cell_face_pos(origin_level, origin_cell)
	var span := Vector2(20.0, 10.0)

	var sprite = GlassCrackSpriteClass.new()
	sprite.setup(sheet, span, impact, 0, Vector2(-1000, -1000), Vector2(1000, 1000), shader)

	var w := float(sheet.get_width())
	var h := float(sheet.get_height())
	var worst := 0.0
	var ground_worst_run := 0.0
	for dr in range(-6, 7):
		for dl in range(-5, 6):
			## Where the VOXEL is, walked by the renderer's own geometry.
			var want: Vector2 = mock.glass_cell_face_pos(
				origin_level + dl, Vector2i(origin_cell.x + dr, origin_cell.y))
			## Where the SPRITE puts that (run, level) offset — the texture-space
			## point for it, through the node's transform. Sprite2D is centred, so
			## texture space runs -w/2..w/2 and UV.y grows downward.
			var local := Vector2(float(dr) / span.x * w, -float(dl) / span.y * h)
			var got: Vector2 = sprite.transform * local
			worst = maxf(worst, (got - want).length())

			## THE CONTROL — the ground-plane inverse the first build used.
			var d: Vector2 = want - impact
			var ground_run: float = d.x / 32.0 + d.y / 16.0
			ground_worst_run = maxf(ground_worst_run, absf(ground_run - float(dr)))

	if worst < 0.001:
		_pass("the sprite quad lands on every voxel over 13x11 offsets (worst %.5f px)" % worst)
	else:
		_fail("the sprite quad drifts from the voxels by up to %.4f px — the sheet will shear" % worst)

	if ground_worst_run > 1.0:
		_pass("the ground-plane inverse is off by up to %.2f voxels of sheet column — the shear that scrambled the web"
			% ground_worst_run)
	else:
		_fail("the ground-plane control only drifted %.4f — this test is not exercising the failure it exists for"
			% ground_worst_run)

	## And the shear is a function of LEVEL alone: same cell, one level down.
	var same_cell_down: Vector2 = mock.glass_cell_face_pos(origin_level - 1, origin_cell) - impact
	var shear: float = same_cell_down.x / 32.0 + same_cell_down.y / 16.0
	if absf(shear - 1.25) < 0.001:
		_pass("one level down shears the ground-plane column by exactly 1.25 voxels")
	else:
		_fail("expected a 1.25-voxel shear per level, measured %.4f" % shear)

	sprite.free()
	print("")


## [11] G-D27's ONE NAMED COST — a sprite is a rectangle and a pane is not.
## `plan_pane_crack` reports the pane's own extent as (run, level) offsets from
## the impact, and that is what clips the sprite. Two things have to hold: a hit
## at the pane's EDGE must produce a bound that stops the web there, and a hole
## the round already made must NOT shrink the pane.
func test_the_pane_bounds_clip_the_sprite() -> void:
	print("[11] the pane's own extent clips the crack sprite (G-D27's named cost)\n")

	var pane := _pane(4, 9, 3)             ## runs 32..79, 3 storeys from base
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var run_lo := 4 * 8
	var run_hi := 9 * 8 + 7

	## A hit hard against the pane's left edge.
	var hit := Vector2i(run_lo, 31)
	var hit_level: int = base + 4
	var plan: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit, hit_level, false)
	var lo: Vector2 = plan["pane_lo"]
	var hi: Vector2 = plan["pane_hi"]
	if is_equal_approx(lo.x, 0.0) and is_equal_approx(hi.x, float(run_hi - run_lo)):
		_pass("an edge hit reports pane_lo.x = 0 and pane_hi.x = %d — nothing draws past the frame" % (run_hi - run_lo))
	else:
		_fail("edge hit reported run bounds (%.1f, %.1f), expected (0, %d)" % [lo.x, hi.x, run_hi - run_lo])
	if is_equal_approx(lo.y, float(base - hit_level)) and is_equal_approx(hi.y, float(base + 3 * 8 - 1 - hit_level)):
		_pass("the level bounds span the pane's %d levels, measured from the impact" % (3 * 8))
	else:
		_fail("level bounds (%.1f, %.1f), expected (%d, %d)"
			% [lo.y, hi.y, base - hit_level, base + 3 * 8 - 1 - hit_level])

	## ⚠️ A HOLE IS NOT A SMALLER PANE. Destroy the whole left column and the
	## extent must not move — otherwise every second hit shrinks the web.
	for s in pane:
		for v in s.voxels:
			if v.grid_pos.x <= run_lo + 1:
				v.set_damage(Voxel.DamageState.DESTROYED, false, Voxel.CarvedSide.NONE, 0, 0)
	var holed: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit, hit_level, false)
	if holed["pane_lo"] == lo and holed["pane_hi"] == hi:
		_pass("destroying the pane's edge column leaves the extent unchanged — a hole is still part of the pane")
	else:
		_fail("the extent moved after a hole: (%s, %s) vs (%s, %s)"
			% [holed["pane_lo"], holed["pane_hi"], lo, hi])

	## A G-D9 brick band is NOT pane: the extent stops at the glass.
	var banded := _pane(4, 9, 3)
	for s in banded:
		s.material_bands = {0: "brick", 1: "brick", 22: "brick", 23: "brick"}
	var b: Dictionary = GlassCrackClass.plan_pane_crack(banded, Face.SW, hit, hit_level, false)
	if float(b["pane_lo"].y) > lo.y and float(b["pane_hi"].y) < hi.y:
		_pass("a brick sill/head pulls the level bounds in (%.0f..%.0f vs %.0f..%.0f)"
			% [float(b["pane_lo"].y), float(b["pane_hi"].y), lo.y, hi.y])
	else:
		_fail("the brick bands did not shrink the pane extent: %.0f..%.0f"
			% [float(b["pane_lo"].y), float(b["pane_hi"].y)])

	print("")


## [12] G-D30 — THE OCCUPANCY CUT, AGAINST A REAL RENDERER.
##
## The claim is that the sprite's cut is read off the GLASS TILEMAP — the live
## authority every erase seam already writes — rather than off a parallel plane
## that could drift from it. That claim is only worth anything if it is exercised
## through the real `VoxelRenderer`, so this builds one, gives it two glass levels
## of actual cells, and reads the image the sprite is handed.
##
## Three things it pins, and each one is a §13 promise:
##   · the row/column convention (`crack_occ_origin` is (run_min, level_max), so
##     row 0 is the HIGHEST level) — invisible on screen until a cut lands on the
##     wrong side of the pane;
##   · §13.5's "a banded pane clips for free" — a G-D9 brick band is not on the
##     glass layer, so the web is cut off it with nobody asking;
##   · G-D30's "a second event re-cuts every existing crack" — erase a cell that
##     was standing when the crack was made, and the SAME crack's occupancy
##     follows.
func test_the_occupancy_cut_reads_the_live_tilemap() -> void:
	print("[12] G-D30 — the cut is read off the glass tilemap, live\n")

	var renderer = VoxelRendererClass.new()
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var cross := 7
	var run0 := 4
	var runs := 10
	var levels := 6
	var brick_level: int = base + 2      ## a G-D9 band: simply never placed

	var ts := _one_tile_tileset()
	for lvl in range(base, base + levels):
		var layer := TileMapLayer.new()
		layer.tile_set = ts
		if lvl != brick_level:
			for r in range(run0, run0 + runs):
				layer.set_cell(Vector2i(r, cross), 0, Vector2i.ZERO)
		renderer._glass_layers[lvl] = layer

	var impact_run: int = run0 + 5
	var impact_level: int = base + 3
	var cid: int = renderer.spawn_glass_crack({
		"pane_id": "PANE_TEST", "run_axis": 0, "wide": false,
		"impact_run": impact_run, "impact_level": impact_level,
		"impact_cell": Vector2i(impact_run, cross),
		"radius": Vector2i(4, 4), "span": Vector2(20.0, 10.0),
		"pane_lo": Vector2(float(run0 - impact_run), float(base - impact_level)),
		"pane_hi": Vector2(float(run0 + runs - 1 - impact_run), float(base + levels - 1 - impact_level)),
	})
	if cid == 0:
		_fail("spawn_glass_crack returned 0 — no sprite, so there is no cut to test")
		_free_glass_layers(renderer)
		renderer.free()
		print("")
		return

	var occ: Image = _occ_image(renderer)
	if occ == null:
		_fail("the crack carries no occupancy image")
		_free_glass_layers(renderer)
		renderer.free()
		print("")
		return

	if occ.get_width() == runs and occ.get_height() == levels:
		_pass("the occupancy is the pane's own rectangle, %dx%d cells" % [runs, levels])
	else:
		_fail("occupancy is %dx%d, expected %dx%d"
			% [occ.get_width(), occ.get_height(), runs, levels])

	## Row 0 must be the HIGHEST level — `crack_occ_origin` is (run_min, level_max)
	## and the shader indexes `j = origin.y - level_off`.
	var brick_row: int = (base + levels - 1) - brick_level
	var brick_solid := 0
	var glass_gone := 0
	for j in range(occ.get_height()):
		for i in range(occ.get_width()):
			var lit: bool = occ.get_pixel(i, j).r > 0.5
			if j == brick_row and lit:
				brick_solid += 1
			elif j != brick_row and not lit:
				glass_gone += 1
	if brick_solid == 0 and glass_gone == 0:
		_pass("row %d (the brick band) reads EMPTY and every glass row reads solid — §13.5's free clip, and row 0 is the top level"
			% brick_row)
	else:
		_fail("%d brick cells read solid, %d glass cells read empty — the row convention or the tilemap read is wrong"
			% [brick_solid, glass_gone])

	## G-D30's live re-cut: erase a cell the crack was made over, flush, and the
	## SAME crack follows it. No "update the old sprites" pass.
	var victim := Vector2i(impact_run, cross)
	renderer.erase_glass_cell(impact_level, victim)
	var rebuilt: int = renderer.refresh_glass_crack_occupancy()
	occ = _occ_image(renderer)
	var col: int = impact_run - run0
	var row: int = (base + levels - 1) - impact_level
	if rebuilt > 0 and occ != null and occ.get_pixel(col, row).r < 0.5:
		_pass("erasing a standing cell re-cuts the crack that was already there (%d rebuilt)" % rebuilt)
	else:
		_fail("the existing crack did not follow the erase — rebuilt=%d" % rebuilt)

	## And a second refresh with nothing erased must do NOTHING: the flag is what
	## keeps the cook's per-cell erase loop from being quadratic.
	if renderer.refresh_glass_crack_occupancy() == 0:
		_pass("a refresh with no erase since the last one is a no-op")
	else:
		_fail("refresh_glass_crack_occupancy rebuilt with nothing dirty — the cook's erase loop would be quadratic")

	## The dial is CONTINUOUS and clamped (G-D30: the open question is fiction, so
	## it is not a boolean).
	renderer.set_glass_crack_hole_cut(2.5)
	var clamped: float = renderer.glass_crack_hole_cut()
	renderer.set_glass_crack_hole_cut(0.5)
	if is_equal_approx(clamped, 1.0) and is_equal_approx(renderer.glass_crack_hole_cut(), 0.5):
		_pass("glass_crack_hole_cut is a clamped 0..1 dial, and 0.5 is a real value")
	else:
		_fail("the cut dial did not clamp/hold: 2.5 -> %.2f, then 0.5 -> %.2f"
			% [clamped, renderer.glass_crack_hole_cut()])

	var src := FileAccess.get_file_as_string("res://godot/shaders/glass_crack.gdshader")
	if src.contains("mix(1.0, texture(crack_occupancy, occ_uv).r, crack_hole_cut)"):
		_pass("the shader mixes the occupancy by the dial — 0.5 is half a cut, not a rounded boolean")
	else:
		_fail("the cut is no longer a continuous mix in glass_crack.gdshader — G-D30 says it is a dial")

	_free_glass_layers(renderer)
	renderer.free()
	print("")


## One 32x36 white tile, enough for `set_cell` to make `get_cell_source_id`
## answer. The occupancy read only ever asks whether a cell is occupied.
func _one_tile_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 36)
	var src := TileSetAtlasSource.new()
	var img := Image.create(32, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(32, 36)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src, 0)
	return ts


func _occ_image(renderer) -> Image:
	if renderer._glass_cracks.is_empty():
		return null
	## The CPU-side copy the builder keeps — see its note. Asking the ImageTexture
	## would be a RenderingServer readback, and headless it can lag an update().
	return renderer._glass_cracks[0].get("occ_image")


## The layers are hand-made here, not built by the renderer, so nothing else
## owns them — SELFTEST LEAK GATE: a bare Object needs freeing.
func _free_glass_layers(renderer) -> void:
	for l in renderer._glass_layers.values():
		if l != null and is_instance_valid(l):
			(l as TileMapLayer).free()
	renderer._glass_layers.clear()
