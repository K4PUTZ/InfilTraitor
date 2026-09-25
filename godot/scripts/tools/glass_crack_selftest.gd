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
##   [8] the crack coming back INSIDE the pane shader (glass_pane3d.gdshader) — CRACK-02 / G-D27 took
##       it out of the voxel because a crack drawn there inherits `dim`, `cover`
##       and the quad seams, and no tuning survives that; and a uniform the mirror feeds that
##       glass_crack3d.gdshader does not declare (dropped with no error).
##   [11] a crack bleeding past the frame of the pane it is on.
##   [12] G-D30's cut reading anything other than the live glass state (the store's pane cells), the
##       occupancy rows going upside down, or the dial collapsing to a boolean.
##   [13] S-3's rebuild path acquiring side effects — a perspective flip that
##       re-damages the pane it is only supposed to redraw.
##   [16] the opening FAMILY going malformed — an opening that does not leave the
##       struck cell, a pooled id with no shape, a pick that stops hashing, or the
##       SHEET's void drifting from the voxel cut (G-D34's whole point).
##   [15] the applied hole drifting from the opening it claims to be — a cell cut
##       that coverage() calls outside, or left whole that it calls PARTIAL — and
##       the rebuild path (a flip, a load) shaping different cells from the shot path.
##   [22] a rotation re-shaping every standing hole with the DEFAULT opening —
##       CRACK-04, GLASS §16.13. The mechanism was never broken; the ORDER was.
##       The perspective rebuild renders the pane intact, erases the recorded
##       holes back out of it and flushes, so unless it CLAIMS first the flush
##       sees a batch of unclaimed erases and invents a shape for each.
##
## R3D-END (END-2): [10] (the 2D sprite's transform on the wall-face basis), [14] (the shard ATOMS a cell's cut was
## drawn with) and [20] (the remnant atom) went with the 2D board, whose tiles they drew; the openings, the shaped
## cells, the occupancy and the sheet are what the 3D board draws from, and those stay pinned.

extends SceneTree

const ShotPunchTableClass = preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")
const VoxelBoardClass = preload("res://godot/scripts/geometry/voxel_board.gd")
const GlassMaterialsClass = preload("res://godot/scripts/systems/glass_materials.gd")
const GlassCrackClass = preload("res://godot/scripts/systems/destruction/glass_crack.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const GlassOpeningClass = preload("res://godot/scripts/systems/destruction/glass_opening.gd")
## B-2 [18] — the ring intensities the granularity split is measured against.
const GlassShatterClass = preload("res://godot/scripts/systems/destruction/glass_shatter.gd")
const GlassShardShapesClass = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")

const CRACK_DECAL_TEMPLATE := "res://ASSETS/materials/glass/decals/decal_crack_glass_%d.png"
## ⛔ The RETIRED round-hole pair, kept only so [3] can assert they are GONE.
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
	test_the_pane_bounds_clip_the_sprite()
	test_the_occupancy_cut_reads_the_live_tilemap()
	test_sprite_spec_is_render_only()
	test_the_opening_family_is_well_formed()
	test_only_the_four_orthogonal_neighbours_become_shards()
	test_the_armored_sheet_is_chosen_by_the_pane_not_the_weapon()
	test_the_craze_field_covers_the_pane_and_tiles()
	test_the_craze_field_is_cut_to_the_holes()
	test_an_unclaimed_hole_is_reshaped_and_the_replay_claims_first()

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

	if not VoxelBoardClass.IMPACT_CRACK_MATERIALS.has("glass"):
		_pass("glass is not in IMPACT_CRACK_MATERIALS (that list composes *_blast_cracked_all_*)")
	else:
		_fail("glass is in IMPACT_CRACK_MATERIALS — it would ask for a blast-crack decal family")

	if not VoxelBoardClass.IMPACT_DECAL_MATERIALS.has("glass"):
		_pass("glass is not in IMPACT_DECAL_MATERIALS (that list composes *_bullet_cracked_*)")
	else:
		_fail("glass is in IMPACT_DECAL_MATERIALS — it would ask for a bullet-crack decal family")

	## (R3D-END END-4: the assertion that a glass member keeps its own name at every damage state — so a CRACKED cell stayed on
	## the GLASS layer instead of going opaque — went with the 2D name resolver, `damage_variant_material()`, and the layer it
	## fed. On the 3D board a pane is a pane by `GlassMaterials.is_glass()` on the voxel's own material, which damage never
	## renames.)

	var on_disk: Array = []
	for v in range(VoxelBoardClass.IMPACT_DECAL_VARIANTS):
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
	print("[3] every (opening x variant) sheet exists, imports, and matches its span\n")

	if Array(GlassMaterialsClass.FRACTURE_WIDTHS) == ["tight", "wide"]:
		_pass("GlassMaterials.FRACTURE_WIDTHS is [tight, wide] (G-D14's two hole sizes)")
	else:
		_fail("GlassMaterials.FRACTURE_WIDTHS is %s — the crack keys the sheet on exactly tight/wide"
			% str(GlassMaterialsClass.FRACTURE_WIDTHS))

	## ⛔ `fracture_glass_{tight,wide}` ARE RETIRED (CRACK-04). They drew a ROUND
	## hole and no member of the opening family is round. What has to exist now is
	## one sheet per (opening, variant), and the CONTRACT is that the manifest and
	## the files agree — a manifest naming a sheet nobody generated resolves to
	## `load() == null` and a crack that silently does not draw.
	var mf := FileAccess.open("res://ASSETS/materials/glass/fracture_manifest.json",
		FileAccess.READ)
	if mf == null:
		_fail("fracture_manifest.json is missing — run tools/persistent/gen_fracture_sheet.py --all")
		print("")
		return
	var manifest = JSON.parse_string(mf.get_as_text())
	mf.close()
	if typeof(manifest) != TYPE_DICTIONARY or not manifest.has("openings"):
		_fail("fracture_manifest.json is not the expected shape")
		print("")
		return

	## ⚠️ EVERY OPENING IN THE FAMILY, not every opening in the manifest. Reading
	## the manifest's own key list would pass for a manifest that simply forgot a
	## member — the family is the authority on which sheets must exist.
	var missing: Array = []
	var bad_aspect: Array = []
	var checked: int = 0
	for id in GlassOpeningClass.ids():
		if not manifest["openings"].has(id):
			missing.append("%s (no manifest row)" % id)
			continue
		var span_arr: Array = manifest["openings"][id].get("span", [])
		for v in range(int(manifest.get("variants", 3))):
			var path: String = GlassCrackClass.sheet_path(id, v)
			if path == "" or not FileAccess.file_exists(path):
				missing.append("%s v%d" % [id, v])
				continue
			if not FileAccess.file_exists(path + ".import"):
				missing.append("%s v%d (no .import sidecar — hard-errors at boot, B6)" % [id, v])
				continue
			var tex := load(path) as Texture2D
			if tex == null:
				missing.append("%s v%d (did not load)" % [id, v])
				continue
			checked += 1
			## The page's aspect must match the span it is drawn for, or the web
			## arrives on the pane stretched. No pixel-SIZE contract (§13.3) — the
			## sheet is a sprite texture, so its dimensions are resolution.
			if tex.get_width() < 128 or tex.get_height() < 128:
				bad_aspect.append("%s v%d too small (%dx%d)" % [id, v, tex.get_width(), tex.get_height()])
			elif span_arr.size() == 2 and float(span_arr[1]) > 0.0:
				var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
				var want: float = float(span_arr[0]) / float(span_arr[1])
				if absf(aspect - want) > 0.05 * want:
					bad_aspect.append("%s v%d aspect %.2f vs span %.2f" % [id, v, aspect, want])
	if missing.is_empty():
		_pass("all %d (opening x variant) sheets exist, import and load" % checked)
	else:
		_fail("missing or broken sheet(s): %s" % ", ".join(missing))
	if bad_aspect.is_empty():
		_pass("every sheet's aspect matches the span the manifest draws it at")
	else:
		_fail("stretched sheet(s): %s" % ", ".join(bad_aspect))

	## ⚠️ AND THE RETIRED PAIR MUST BE GONE. Leaving them on disk is how a
	## fallback creeps back in: `load()` would succeed, so nothing would fail.
	for old_name in ["tight", "wide"]:
		var old_path: String = FRACTURE_TEMPLATE % old_name
		if FileAccess.file_exists(old_path):
			_fail("%s still exists — the round-hole sheets are retired (CRACK-04)" % old_path)
	if not FileAccess.file_exists(FRACTURE_TEMPLATE % "tight"):
		_pass("the retired round-hole sheets are gone from disk")

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


## RENDER3D R3D-1d: `Voxel` has no state of its own — every `set_damage()`/
## `set_visible()` call in this file needs an active `VoxelStore` built over the exact
## fixture slices it wrote voxels into.
func _activate_store(slices: Array) -> void:
	var edge_registry := EdgeRegistry.new()
	for slice in slices:
		edge_registry.register_slice(slice)
	VoxelStore.active = VoxelStore.build(edge_registry, SlabRegistry.new(), [])


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

	## RENDER3D R3D-1d: `Voxel` has no state of its own — set_damage() below needs
	## an active store built over this fixture.
	_activate_store(pane)
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
	print("[8] the crack is not the pane shader's, and glass_crack3d.gdshader draws it\n")

	## R3D-END (END-2): the 2D `glass_pane.gdshader` / `glass_crack.gdshader` went with the 2D board; the rule is the
	## same on the shaders the 3D board draws with.
	var pane_shader := load("res://godot/shaders/glass_pane3d.gdshader") as Shader
	if pane_shader == null:
		_fail("glass_pane3d.gdshader did not load as a Shader")
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
		_pass("glass_pane3d.gdshader declares no crack/fracture uniform — the web is not the voxel's any more")
	else:
		_fail("glass_pane3d.gdshader is drawing the crack again (%s) — G-D27 moved it off the pane"
			% ", ".join(leaked))

	var crack_shader := load("res://godot/shaders/glass_crack3d.gdshader") as Shader
	if crack_shader == null:
		_fail("glass_crack3d.gdshader did not load as a Shader — the crack has no renderer")
		print("")
		return
	var names: Array = []
	for prop in crack_shader.get_shader_uniform_list():
		names.append(prop.name)
	## Every uniform the mirror copies out of a crack's record, and the look dials: a name the shader does not declare
	## is dropped by `set_shader_parameter()` with no error.
	var required: Array = ["crack_color", "crack_strength", "crack_opacity", "crack_edge_feather"]
	required.append_array(GlassCrackMirror3D.MIRRORED)
	var missing: Array = []
	for r in required:
		if not names.has(r):
			missing.append(r)
	if missing.is_empty():
		_pass("glass_crack3d.gdshader declares all %d uniforms the mirror feeds it" % required.size())
	else:
		_fail("glass_crack3d.gdshader is missing uniform(s): %s" % ", ".join(missing))

	## ⚠️ WHAT G-D26 ACTUALLY REQUIRES, AND WHAT IT DOES NOT.
	##
	## This used to assert `render_mode blend_add`. The Director changed the sprite
	## to a 90%-opacity sticker on 2026-09-02 (*"deixar um pouquinho de
	## transparência passar"*), because additive SATURATES — the web's core blew
	## out to white and there was no transparency left to give. The blend mode is
	## his look dial and does not belong in a gate.
	##
	## G-D26's rule survives untouched, and it is asserted ABOVE instead: the crack
	## may not be drawn by the PANE shader. That is the whole content of it — a
	## per-voxel change to transparency frames the voxel against its untouched
	## neighbours. A sprite cannot do that whatever it blends with: it draws over
	## the pane in one continuous piece and the glass underneath is not modified.
	var src := FileAccess.get_file_as_string("res://godot/shaders/glass_crack3d.gdshader")
	if src.contains("crack_opacity"):
		_pass("the crack's opacity is a uniform — the Director's 90% is a dial, not a hardcode")
	else:
		_fail("glass_crack3d.gdshader has no crack_opacity uniform to set")
	if src.contains("discard"):
		_pass("the crack discards outside the pane bounds — G-D27's one named cost, paid")
	else:
		_fail("no pane clipping in glass_crack3d.gdshader: a crack near a frame will bleed over what is beside it")

	print("")


## A stand-in for VoxelBoard's CRACK-02 crack registry — records what
## GlassCrack.apply spawns and answers G-D24's geometric test, so the rule can be
## tested without a real renderer.
class MockRenderer:
	var cracks: Array = []            ## the spawned specs, in order
	var _next: int = 0

	## G-D24, exactly as VoxelBoard.glass_crack_covering() does it.
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

	## The same wall-face geometry VoxelBoard.glass_cell_face_pos() uses:
	## map_to_local's e1 (16,8) / e2 (-16,8), minus VOXEL_STEP_PX per level.
	func glass_cell_face_pos(level: int, cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x - cell.y) * 16.0,
			float(cell.x + cell.y) * 8.0 - 20.0 * float(relative_level(level)))


func test_apply_spawns_a_sprite_and_gd24_crosses() -> void:
	print("[9] GlassCrack.apply spawns ONE crack; a covered cell is DESTROYED (G-D24)\n")

	var pane := _pane(4, 9, 3)
	## RENDER3D R3D-1d: `Voxel` has no state of its own — `GlassCrack.apply()`'s
	## set_damage() calls below need an active store built over this fixture.
	_activate_store(pane)
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
## through the real `VoxelBoard`, so this builds one, gives it two glass levels
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
	print("[12] G-D30 — the cut is read off the store's glass panes, live\n")

	var renderer = VoxelBoardClass.new()
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var cross := 7
	var run0 := 4
	var runs := 10
	var levels := 6
	var brick_level: int = base + 2      ## a G-D9 band: a brick row of the SAME slice, so not a pane cell

	## R3D-END: the pane is a glass slice in the store (the glass state's only authority since R3D-14); until then this
	## hand-filled the hidden glass TileMapLayers.
	var board: Dictionary = _glass_board(run0, runs, cross, base, levels, {brick_level - base: "brick"})

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
		renderer.free()
		print("")
		return

	var occ: Image = _occ_image(renderer)
	if occ == null:
		_fail("the crack carries no occupancy image")
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
		_fail("%d brick cells read solid, %d glass cells read empty — the row convention or the store read is wrong"
			% [brick_solid, glass_gone])

	## G-D30's live re-cut: destroy a cell the crack was made over (destruction's write, then the erase seam the cook
	## calls), flush, and the SAME crack follows it. No "update the old sprites" pass.
	var victim := Vector2i(impact_run, cross)
	_destroy_glass(board, victim, impact_level)
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

	## ⚠️ THE DEFAULT IS 1.0 BY DIRECTOR RULING (G-D30, 2026-09-02: *"as versões com
	## o adesivo sem voxels atrás não funcionam, podemos descartar"*). The crack
	## lives on glass that exists. Pinned here because it is a one-character edit
	## away from a design the Director has already rejected, and nothing else would
	## notice.
	if is_equal_approx(renderer.glass_crack_hole_cut(), 1.0):
		_pass("the shipped cut defaults to 1.0 — the ruled value, not a placeholder")
	else:
		_fail("the shipped cut is %.2f, not the ruled 1.0 — a crack would draw over glass that is gone"
			% renderer.glass_crack_hole_cut())

	## The dial itself is CONTINUOUS and clamped: it is how the ends were compared
	## and how they can be compared again (INFILTRAITOR_GLASS_CRACK_CUT).
	renderer.set_glass_crack_hole_cut(2.5)
	var clamped: float = renderer.glass_crack_hole_cut()
	renderer.set_glass_crack_hole_cut(0.5)
	if is_equal_approx(clamped, 1.0) and is_equal_approx(renderer.glass_crack_hole_cut(), 0.5):
		_pass("glass_crack_hole_cut is a clamped 0..1 dial, and 0.5 is a real value")
	else:
		_fail("the cut dial did not clamp/hold: 2.5 -> %.2f, then 0.5 -> %.2f"
			% [clamped, renderer.glass_crack_hole_cut()])

	var src := FileAccess.get_file_as_string("res://godot/shaders/glass_crack3d.gdshader")
	if src.contains("mix(1.0, texture(crack_occupancy, occ_uv).r, crack_hole_cut)"):
		_pass("the shader mixes the occupancy by the dial — 0.5 is half a cut, not a rounded boolean")
	else:
		_fail("the cut is no longer a continuous mix in glass_crack3d.gdshader — G-D30 says it is a dial")

	renderer.free()
	VoxelStore.active = null
	print("")


## R3D-END — a one-pane board: a glass slice on the SW face (run along X) whose voxels ARE the pane cells, `runs` x
## `levels` at y = `cross`, with an optional G-D9 band (rel level -> material). `VoxelStore.active` is built over it,
## so every glass-state read (`_glass_cell_present()`, the crack occupancy, the opening walk) answers from it.
## Returns {"slice", "voxels": Vector3i -> Voxel} — the voxels are what destruction writes.
func _glass_board(run0: int, runs: int, cross: int, base: int, levels: int, bands: Dictionary = {}) -> Dictionary:
	@warning_ignore("integer_division")
	var storeys: int = maxi(1, (levels + GeometryCoordsClass.LEVELS_PER_STOREY - 1) / GeometryCoordsClass.LEVELS_PER_STOREY)
	var s := Slice.new("PANE_BOARD", GeometryCoordsClass.voxel_to_gu(Vector2i(run0, cross)), Face.SW,
		"PANE_BOARD_E", storeys, "glass")
	s.pane_id = "PANE_TEST"
	s.material_bands = bands
	var by_key: Dictionary = {}
	for lvl in range(base, base + levels):
		for run in range(run0, run0 + runs):
			var v := Voxel.new(Vector2i(run, cross), lvl, s)
			s.voxels.append(v)
			by_key[Vector3i(run, cross, lvl)] = v
	_activate_store([s])
	return {"slice": s, "voxels": by_key}


## Destruction's part, played on the store: the voxel at (cell, level) is DESTROYED (and so invisible).
func _destroy_glass(board: Dictionary, cell: Vector2i, level: int) -> void:
	(board["voxels"][Vector3i(cell.x, cell.y, level)] as Voxel).set_damage(
		Voxel.DamageState.DESTROYED, false, Voxel.CarvedSide.NONE, 0, 0)


func _occ_image(renderer) -> Image:
	if renderer._glass_cracks.is_empty():
		return null
	## The CPU-side copy the builder keeps — see its note. Asking the ImageTexture
	## would be a RenderingServer readback, and headless it can lag an update().
	return renderer._glass_cracks[0].get("occ_image")


## [13] CRACK-02 S-3 — `sprite_spec()` IS THE RENDER HALF, AND ONLY THAT.
##
## A perspective flip re-applies the CRACKED states through VL-PERSIST and then
## rebuilds the sprites; the rebuild must therefore change NOTHING about the
## voxels. Calling `apply()` there would set the states a second time and run
## G-D24 against the cracks it is in the middle of rebuilding — every crack would
## cross the one before it and the pane would come apart on a camera move. So the
## split is load-bearing, and this pins both halves of it.
func test_sprite_spec_is_render_only() -> void:
	print("[13] S-3 — sprite_spec() carries the whole render contract and touches no voxel\n")

	var pane := _pane(4, 9, 3)
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var hit := Vector2i(6 * 8 + 4, 31)
	var plan: Dictionary = GlassCrackClass.plan_pane_crack(pane, Face.SW, hit, base + 10, false)

	var before: Array = []
	for e in plan.cells:
		before.append(e.voxel.damage_state)
	var spec: Dictionary = GlassCrackClass.sprite_spec(plan)
	var changed := 0
	for i in range(plan.cells.size()):
		if plan.cells[i].voxel.damage_state != before[i]:
			changed += 1
	if changed == 0:
		_pass("sprite_spec() changed 0 of %d voxel states — a rebuild cannot re-damage the pane"
			% plan.cells.size())
	else:
		_fail("sprite_spec() changed %d voxel states — a perspective flip would re-run G-D24 on itself"
			% changed)

	## Every key `VoxelBoard.spawn_glass_crack()` reads. A missing one is not a
	## crash — GDScript would index a Dictionary and get null — so it is listed.
	var required := ["pane_id", "run_axis", "wide", "impact_run", "impact_level",
		"impact_cell", "radius", "span", "pane_lo", "pane_hi"]
	var missing: Array = []
	for k in required:
		if not spec.has(k):
			missing.append(k)
	if missing.is_empty():
		_pass("the spec carries all %d keys the renderer reads" % required.size())
	else:
		_fail("sprite_spec() is missing %s — the sprite would be built from nulls" % ", ".join(missing))

	## And `apply()` must be built ON it, not beside it: the same plan through
	## apply() has to spawn a crack described identically.
	var mock := MockRenderer.new()
	var res: Dictionary = GlassCrackClass.apply(mock, plan)
	if int(res.crack_id) != 0 and mock.cracks.size() == 1:
		var spawned: Dictionary = mock.cracks[0]
		var same := true
		for k in required:
			if spawned.get(k) != spec.get(k):
				same = false
				_fail("apply() spawned %s=%s but sprite_spec() says %s" % [k, spawned.get(k), spec.get(k)])
		if same:
			_pass("apply() spawns exactly what sprite_spec() describes — one definition, two callers")
	else:
		_fail("apply() did not spawn a crack for a plan with %d cells" % plan.cells.size())

	print("")


## [16] CRACK-04 / G-D34 — the family itself. These are the properties the
## renderer RELIES on, so they are asserted on the catalogue rather than
## rediscovered per hole.
func test_the_opening_family_is_well_formed() -> void:
	print("[16] CRACK-04 — every opening intrudes, stays bounded, and picks reproducibly\n")

	var bad: Array = []
	for id in GlassOpeningClass.ids():
		var poly: PackedVector2Array = GlassOpeningClass.polygon(id)
		if poly.size() < 6:
			bad.append("%s: %d verts" % [id, poly.size()])
			continue
		## An opening must reach PAST the struck cell, or it cuts nothing and the
		## hole is the rectangle CRACK-03 exists to remove.
		var r_max: float = 0.0
		for pt in poly:
			r_max = maxf(r_max, pt.length())
		if r_max <= 0.5:
			bad.append("%s: reach %.2f does not leave the struck cell" % [id, r_max])
		## ...and it must swallow the struck cell WHOLE. The centre point being
		## inside is the weaker claim and passes for an opening whose valleys cut
		## through the hit cell's corners — which is a state with no resolution,
		## because destruction has already removed that voxel entirely and the
		## opening wants to keep four slivers of it. [15] found exactly this on
		## three of the four small members.
		if GlassOpeningClass.coverage(id, 0, 0) != GlassOpeningClass.Coverage.FULL:
			bad.append("%s: does not swallow the struck cell (valley under %.3f)"
				% [id, GlassOpeningClass.MIN_VALLEY])
	if bad.is_empty():
		_pass("all %d openings are closed, contain the impact, and intrude on a neighbour"
			% GlassOpeningClass.ids().size())
	else:
		_fail("malformed opening(s): %s" % ", ".join(bad))

	## Every member of a pool must be a real opening — a typo in POOLS resolves to
	## an empty polygon, which cuts NOTHING and fails silently.
	var orphans: Array = []
	for size_class in ["small", "large"]:
		for id in GlassOpeningClass.pool(size_class):
			if not GlassOpeningClass.FAMILY.has(id):
				orphans.append("%s/%s" % [size_class, id])
	if orphans.is_empty():
		_pass("every pooled id exists in FAMILY — no pick can resolve to an empty polygon")
	else:
		_fail("pooled id(s) with no shape: %s" % ", ".join(orphans))

	## B4 / G-D32: the pick is a HASH, so the same key must give the same opening
	## forever. A `randf()` here reshapes a standing hole on every camera turn.
	var stable: bool = true
	var spread: Dictionary = {}
	for i in range(64):
		var key: String = "base_%d" % i
		var first: String = GlassOpeningClass.pick("small", key)
		if first != GlassOpeningClass.pick("small", key):
			stable = false
		spread[first] = true
	if stable:
		_pass("pick() is reproducible for a given base key — FNV-1a, not randf()")
	else:
		_fail("pick() returned different openings for the same key — the pool is being randomised")

	## ...and it must actually SPREAD. A hash that always returns member 0 is
	## reproducible and useless, and would pass the test above forever.
	if spread.size() >= 2:
		_pass("64 keys reached %d of the %d small openings" % [spread.size(), GlassOpeningClass.pool("small").size()])
	else:
		_fail("64 keys all resolved to one opening — the hash is not reaching the pool")

	## ⚠️ THE SHEET'S VOID AND THE VOXEL CUT MUST BE ONE POLYGON (G-D34). They are
	## consumed by different machines — `mask_image()` rasterises for the SHADER,
	## `contains()` is called per atom pixel on the CPU — and "they both come from
	## polygon()" is a claim about the code, not about the pixels. A transposed
	## axis or an off-by-half origin in the mask would leave the hole and the
	## decal's inner border describing two different shapes, which is the exact
	## thing the Director's ruling is about.
	var drift: Array = []
	for id in GlassOpeningClass.ids():
		var m: Dictionary = GlassOpeningClass.mask_image(id)
		if m.is_empty():
			drift.append("%s: no mask" % id)
			continue
		var img: Image = m["image"]
		var origin: Vector2 = m["origin"]
		var size: Vector2 = m["size"]
		var poly: PackedVector2Array = GlassOpeningClass.polygon(id)
		var wrong_texels: int = 0
		var checked: int = 0
		for ty in range(img.get_height()):
			for tx in range(img.get_width()):
				## Texel centre back to voxels — the inverse of what the shader does.
				var pt := Vector2(
					origin.x + (float(tx) + 0.5) / float(img.get_width()) * size.x,
					origin.y - (float(ty) + 0.5) / float(img.get_height()) * size.y)
				var in_mask: bool = img.get_pixel(tx, ty).r > 0.5
				var in_poly: bool = GlassOpeningClass.contains(poly, pt)
				checked += 1
				if in_mask != in_poly:
					wrong_texels += 1
		if wrong_texels > 0:
			drift.append("%s: %d/%d texels" % [id, wrong_texels, checked])
	if drift.is_empty():
		_pass("every opening's sheet mask agrees with its polygon texel for texel — one shape, two consumers")
	else:
		_fail("mask and polygon disagree: %s" % ", ".join(drift))

	## An unknown size class must be loud, not silently substituted.
	if GlassOpeningClass.pick("no_such_class", "k") == "":
		_pass("an unknown size class returns \"\" rather than a default that happens to exist")
	else:
		_fail("an unknown size class silently resolved to an opening")

	print("")


## [15] CRACK-04 — THE CELLS THAT GET CUT ARE EXACTLY THE OPENING'S PARTIAL SET.
##
## CRACK-03 asserted a fixed FOUR (the Director's diagram: the corners stay
## cubes). That number was never the rule — it was `star_deep`'s footprint under a
## per-cell wedge, and G-D34 replaced the wedge with a catalogue, so a different
## opening legitimately cuts a different set. What must hold for EVERY opening is
## the identity: the cells the walk swaps are the cells `coverage()` calls
## PARTIAL — no more (glass eaten that the round never reached) and no fewer (a
## boundary crossing a cell and leaving it a cube).
##
## ⚠️ Asserting a count would pass for one opening and be meaningless for the
## family; asserting "not eight" would pass for the whole life of any bug that
## cut seven. This asserts the SET.
func test_only_the_four_orthogonal_neighbours_become_shards() -> void:
	print("[15] the cut cells are exactly the opening's PARTIAL set, for every opening\n")

	## ⚠️ EVERY member, not just the small pool. The anchor defect this test found
	## (a claim matched by centroid instead of by membership) was invisible on all
	## seven SYMMETRIC openings and showed only on `chunk_bite` — so a suite that
	## covers one size class covers the easy half of the family by construction.
	for opening in GlassOpeningClass.ids():
		var r = VoxelBoardClass.new()
		var base: int = GeometryCoordsClass.storey_level_base(0)
		var cross := 7
		var run0 := 0
		## Wide enough for the largest member (`crescent_wide` reaches 4.2 voxels)
		## with clearance, so a hole never touches the pane's own edge.
		var runs := 23
		var levels := 17
		## R3D-END: the pane is a glass slice in the store; until then this hand-filled the hidden glass TileMapLayers.
		var board: Dictionary = _glass_board(run0, runs, cross, base, levels)

		@warning_ignore("integer_division")
		var hit_run: int = run0 + runs / 2
		@warning_ignore("integer_division")
		var hit_level: int = base + levels / 2
		var bounds: Rect2i = GlassOpeningClass.cell_bounds(opening)

		## Destruction's part, played here: every cell the opening swallows whole
		## is destroyed first. The renderer refuses to erase, on purpose — it would be
		## a second writer on voxel existence.
		var expect_partial: Dictionary = {}
		var swallowed: Array = []
		for dl in range(bounds.position.y, bounds.position.y + bounds.size.y):
			for dr in range(bounds.position.x, bounds.position.x + bounds.size.x):
				var cov: int = GlassOpeningClass.coverage(opening, dr, dl)
				if cov == GlassOpeningClass.Coverage.FULL:
					swallowed.append(Vector3i(hit_run + dr, cross, hit_level + dl))
				elif cov == GlassOpeningClass.Coverage.PARTIAL:
					expect_partial[Vector2i(dr, dl)] = true
		if swallowed.is_empty():
			swallowed.append(Vector3i(hit_run, cross, hit_level))
		for k: Vector3i in swallowed:
			_destroy_glass(board, Vector2i(k.x, k.y), k.z)
			r.note_glass_erased_for_rim(k.z, Vector2i(k.x, k.y))

		r.claim_glass_opening(hit_level, Vector2i(hit_run, cross), opening)
		var swapped: int = r.refresh_glass_rims()

		## Read the board back and compare SETS: a shaped cell is one the opening only intruded on.
		var wrong: Array = []
		for dl in range(bounds.position.y - 1, bounds.position.y + bounds.size.y + 1):
			for dr in range(bounds.position.x - 1, bounds.position.x + bounds.size.x + 1):
				var is_shard: bool = r._glass_shaped_cells.has(Vector3i(hit_run + dr, cross, hit_level + dl))
				if is_shard != expect_partial.has(Vector2i(dr, dl)):
					wrong.append("(%d,%d)%s" % [dr, dl, " cut" if is_shard else " whole"])
		if wrong.is_empty():
			_pass("'%s': %d shard(s), and they are exactly the %d PARTIAL cells"
				% [opening, swapped, expect_partial.size()])
		else:
			_fail("'%s': %d cell(s) disagree with coverage(): %s"
				% [opening, wrong.size(), ", ".join(wrong)])
		if r.count_glass_shards() == swapped:
			_pass("'%s': count_glass_shards() reads the same %d shaped cell(s) back" % [opening, swapped])
		else:
			_fail("'%s': count_glass_shards() reads %d, the walk cut %d" % [opening, r.count_glass_shards(), swapped])

		## ⚠️ THE REBUILD PATH MUST PRODUCE THE SAME BOARD AS THE SHOT PATH.
		## There are two ways an opening reaches the board — `claim` + the erase
		## flush (a live shot) and `apply_glass_opening_at()` (a perspective flip or
		## a load, where nothing is erased so nothing flags a rim). They were NOT
		## equivalent when written: the rebuild claimed into a flush that never ran
		## and the hole came back a rectangle, silently, for every opening. Two
		## paths for one feature need the assertion that they agree. Same store (the
		## same holes); a second renderer, with no rim flagged.
		var r2 = VoxelBoardClass.new()
		var direct: int = r2.apply_glass_opening_at(hit_level, Vector2i(hit_run, cross), opening)
		var mismatch: Array = []
		for dl2 in range(bounds.position.y - 1, bounds.position.y + bounds.size.y + 1):
			for dr2 in range(bounds.position.x - 1, bounds.position.x + bounds.size.x + 1):
				var key := Vector3i(hit_run + dr2, cross, hit_level + dl2)
				if r._glass_shaped_cells.has(key) != r2._glass_shaped_cells.has(key):
					mismatch.append("(%d,%d)" % [dr2, dl2])
		if mismatch.is_empty() and direct == swapped:
			_pass("'%s': the rebuild path shapes the same %d cell(s) as the shot path" % [opening, direct])
		else:
			_fail("'%s': rebuild cut %d vs shot %d; cells differing: %s"
				% [opening, direct, swapped, ", ".join(mismatch) if not mismatch.is_empty() else "none"])
		r2.free()
		r.free()
		VoxelStore.active = null
	_pass("all %d openings survived the round with no idempotence failure" % GlassOpeningClass.ids().size())
	print("")


## ── [17] CRACK-05 / G-D28 — THE `armored` SHEET ──────────────────────────────
##
## What this catches: an armoured pane going back to wearing a BULLET page — a
## painted bore over glass nothing pierced, which is what
## `shot_c02_screen_3_damage.png` recorded and what
## `ART_ORDER_GLASS_FRACTURE_CLASSES.md` §1 calls the priority of that order. And
## the two failures either side of it: ordinary glass acquiring a crushed core it
## has not earned, and the class being chosen by the WEAPON rather than by the
## pane's material.
func test_the_armored_sheet_is_chosen_by_the_pane_not_the_weapon() -> void:
	print("[17] CRACK-05 / G-D28 — a pane that STOPPED the round draws a crushed core\n")

	## ── The selector, all three of its cases. ────────────────────────────────
	var ok_sel := true
	## A hole was opened: the opening's own page wins, armoured or not. An
	## armoured pane CAN be pierced (G-D15's rifle pierce-and-prime), and when it
	## is there is a real hole for the sheet's void to be the shape of.
	if GlassCrackClass.sheet_id_for("crescent_wide", true, true) != "crescent_wide":
		_fail("a claimed opening lost to the armoured branch — a pierced armoured "
			+ "pane would draw a crushed core over a hole that exists")
		ok_sel = false
	if GlassCrackClass.sheet_id_for("", false, true) != GlassCrackClass.ARMORED_SHEET_TIGHT \
			or GlassCrackClass.sheet_id_for("", true, true) != GlassCrackClass.ARMORED_SHEET_WIDE:
		_fail("a crazed armoured pane does not select the armoured pair (got %s / %s)"
			% [GlassCrackClass.sheet_id_for("", false, true),
			GlassCrackClass.sheet_id_for("", true, true)])
		ok_sel = false
	## Ordinary glass that only crazed keeps the smallest member's page. ⚠️ This
	## is the half that would fail SILENTLY: a crushed white core on a pane a
	## round went straight through says the opposite of what happened.
	if GlassCrackClass.sheet_id_for("", false, false) != "chamfer_45" \
			or GlassCrackClass.sheet_id_for("", true, false) != "chamfer_45_wide":
		_fail("ordinary crazed glass no longer falls back to the chamfer_45 pages")
		ok_sel = false
	if ok_sel:
		_pass("sheet_id_for: opening wins > the armoured pair (tight/wide on G-D14's "
			+ "blowout split) > the smallest member's page")

	## ⚠️ AND THE SPAN MUST FOLLOW THE SAME PICK. The page and the quad were
	## chosen by two copies of this rule until CRACK-05; a span that still
	## answered `chamfer_45` would draw the armoured sheet at half scale, and
	## nothing would error.
	var span_arm: Vector2 = GlassCrackClass.sheet_span_for("", false, true)
	var span_plain: Vector2 = GlassCrackClass.sheet_span_for("", false, false)
	if span_arm != span_plain and span_arm.x > 0.0:
		_pass("the quad follows the sheet: armoured %s vs ordinary %s voxels"
			% [span_arm, span_plain])
	else:
		_fail("sheet_span_for returns %s for the armoured page and %s for the "
			% [span_arm, span_plain]
			+ "ordinary one — the span is not following the sheet id")

	## ── The three sheets, on disk and loading. ───────────────────────────────
	var bad: Array = []
	var n_sheets: int = 0
	for id in [GlassCrackClass.ARMORED_SHEET_TIGHT, GlassCrackClass.ARMORED_SHEET_WIDE]:
		for v in range(GlassCrackClass.variant_count()):
			var path: String = GlassCrackClass.sheet_path(String(id), v)
			if path == "":
				bad.append("%s v%d has no manifest row" % [id, v])
			elif not FileAccess.file_exists(path):
				bad.append("%s v%d missing (%s)" % [id, v, path])
			elif not FileAccess.file_exists(path + ".import"):
				bad.append("%s v%d has no .import sidecar (hard-errors at boot, B6)" % [id, v])
			elif load(path) as Texture2D == null:
				bad.append("%s v%d did not load" % [id, v])
			else:
				n_sheets += 1
	if bad.is_empty():
		_pass("all %d armoured sheets exist, import and load (2 calibre classes x %d)"
			% [n_sheets, GlassCrackClass.variant_count()])
	else:
		_fail("armoured sheet(s): %s — run tools/persistent/gen_fracture_sheet.py --all"
			% ", ".join(bad))

	## ⚠️ AND THE RIFLE'S PAGE MUST BE BIGGER. The two sheets differ in NOTHING but
	## the span — that is what makes one preset body serve both — so a manifest that
	## gave them the same number would silently collapse the calibre split.
	var s_t: Vector2 = GlassCrackClass.sheet_span_for("", false, true)
	var s_w: Vector2 = GlassCrackClass.sheet_span_for("", true, true)
	if s_w.x > s_t.x:
		_pass("the rifle's crush mark is a bigger page: %s vs %s voxels (G-D14)" % [s_w, s_t])
	else:
		_fail("armoured tight %s is not smaller than wide %s — the calibre split "
			% [s_t, s_w] + "has collapsed")

	## ⚠️ AND IT IS NOT AN OPENING. `GlassOpening.FAMILY` holds HOLES; a member
	## there is pickable by `pick()` and cuttable by `refresh_glass_rims()`, and
	## armoured glass is the one pane that must never lose a voxel (G-D15).
	var in_family: Array = []
	for id in [GlassCrackClass.ARMORED_SHEET_TIGHT, GlassCrackClass.ARMORED_SHEET_WIDE]:
		if GlassOpeningClass.FAMILY.has(id):
			in_family.append(String(id))
	if in_family.is_empty():
		_pass("both armoured ids are sheet ids and NOT openings — nothing can cut a "
			+ "voxel with either")
	else:
		_fail("%s in GlassOpening.FAMILY — they would become real holes, on the one "
			% ", ".join(in_family) + "class of pane that cannot have one")

	## ── The plan derives it from the PANE, not from the weapon. ──────────────
	##
	## G-D28's trigger is `glass_armored` and the INDESTRUCTIBLE screens; V-D's
	## per-placement override has to win over the material's own default, or the
	## GLASS map's `breakable` amber screen would wear a crushed core it cannot
	## earn.
	var cases: Array = [
		{"mat": "glass", "cls": GlassMaterialsClass.CLASS_UNSET, "want": false},
		{"mat": "glass_armored", "cls": GlassMaterialsClass.CLASS_UNSET, "want": true},
		{"mat": "glass_screen_green", "cls": GlassMaterialsClass.CLASS_UNSET, "want": true},
		{"mat": "glass_screen_amber", "cls": GlassMaterialsClass.Class.BREAKABLE, "want": false},
	]
	var wrong: Array = []
	for c in cases:
		var pane: Array = _pane(4, 5, 1, String(c["mat"]))
		for s in pane:
			s.glass_class = int(c["cls"])
		var base: int = GeometryCoordsClass.storey_level_base(0)
		var plan: Dictionary = GlassCrackClass.plan_pane_crack(
			pane, Face.SW, Vector2i(4 * 8 + 4, 3 * 8 + 7), base + 4, false)
		if bool(plan.get("armored", false)) != bool(c["want"]):
			wrong.append("%s/%d -> %s (wanted %s)"
				% [c["mat"], int(c["cls"]), plan.get("armored"), c["want"]])
	if wrong.is_empty():
		_pass("plan_pane_crack reads the class off the pane: plain no, armoured yes, "
			+ "screen yes, and V-D's `breakable` override wins")
	else:
		_fail("the armoured flag is wrong for %s" % ", ".join(wrong))

	## ⚠️ AND THE WEAPON MUST NOT REACH IT. `wide` is the hole-width axis (G-D14);
	## if it could flip this flag, a rifle on plain glass would draw a crushed core.
	var plain: Array = _pane(4, 5, 1, "glass")
	var b: int = GeometryCoordsClass.storey_level_base(0)
	var p_tight: Dictionary = GlassCrackClass.plan_pane_crack(
		plain, Face.SW, Vector2i(36, 31), b + 4, false)
	var p_wide: Dictionary = GlassCrackClass.plan_pane_crack(
		plain, Face.SW, Vector2i(36, 31), b + 4, true)
	if not bool(p_tight.get("armored", true)) and not bool(p_wide.get("armored", true)):
		_pass("the weapon's hole width cannot make a pane armoured (G-D28: chosen "
			+ "by MATERIAL/CLASS)")
	else:
		_fail("blowout reached the armoured flag: tight=%s wide=%s"
			% [p_tight.get("armored"), p_wide.get("armored")])
	print("")


## ── G-D35 B-2 — THE CRAZE FIELD ─────────────────────────────────────────────
func test_the_craze_field_covers_the_pane_and_tiles() -> void:
	print("[18] G-D35 B-2 — the craze FIELD is the pane's own rectangle, tiled\n")

	var pane := _pane(4, 9, 3)              ## 6 GU x 3 storeys = 48 x 24 voxels
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var plan: Dictionary = GlassCrackClass.plan_pane_field(pane, Face.SW, 0.55)

	if plan.is_empty():
		_fail("plan_pane_field returned {} for a solid glass pane")
		print("")
		return

	## ── 1. THE CENTRE IS A REAL CELL OF THE PANE ────────────────────────────
	## ⚠️ Not the pane's true middle: a pane with an even side has that on a half
	## voxel, and every other field in the record — the occupancy's world lookup
	## above all — is measured in WHOLE cells from this one anchor.
	var centre: Vector2i = plan["centre_cell"]
	var c_lvl: int = int(plan["centre_level"])
	var centre_is_real := false
	for sl in pane:
		for v in sl.voxels:
			if v.grid_pos == centre and v.level == c_lvl:
				centre_is_real = true
				break
	if centre_is_real:
		_pass("the quad's anchor %s level %d is a real voxel of the pane" % [centre, c_lvl])
	else:
		_fail("the anchor %s level %d is not on the pane — the occupancy walk would "
			% [centre, c_lvl] + "read the wrong cells")

	## ── 2. THE CLIP CANNOT CUT THE PANE ─────────────────────────────────────
	## ⚠️ ASSERTED OVER EVERY VOXEL, NOT OVER THE CORNERS. A bound that is right at
	## the corners and wrong in between is exactly the defect a four-point check
	## cannot see, and the pane is the thing the field must cover.
	var lo: Vector2 = plan["pane_lo"]
	var hi: Vector2 = plan["pane_hi"]
	var outside: int = 0
	for sl in pane:
		for v in sl.voxels:
			var off := Vector2(float(v.grid_pos.x - centre.x), float(v.level - c_lvl))
			if off.x < lo.x or off.x > hi.x or off.y < lo.y or off.y > hi.y:
				outside += 1
	if outside == 0:
		_pass("all 1152 pane voxels lie inside the field's clip bounds %s..%s" % [lo, hi])
	else:
		_fail("%d pane voxel(s) fall outside the clip — the field would be cut short" % outside)

	## ── 3. THE QUAD REACHES THE CLIP ────────────────────────────────────────
	## `Sprite2D.centered` makes the quad symmetric about the anchor, so a span
	## that merely equalled the pane's WIDTH would fall short on the far side of an
	## off-centre anchor — and the shortfall is invisible on a symmetric pane,
	## which is every fixture anyone writes first.
	var span: Vector2 = plan["span"]
	var half := span * 0.5
	if half.x >= maxf(absf(lo.x), absf(hi.x)) and half.y >= maxf(absf(lo.y), absf(hi.y)):
		_pass("the quad %s reaches the whole clip from a symmetric centre" % span)
	else:
		_fail("quad %s is too small for bounds %s..%s" % [span, lo, hi])

	## ── 4. AN OFF-CENTRE PANE, WHICH IS WHERE 3 ACTUALLY BITES ──────────────
	## An even-sided pane puts the anchor half a voxel off its own middle. Same
	## two assertions, on the case that can fail them.
	var odd := _pane(4, 8, 2)               ## 5 GU x 2 storeys = 40 x 16
	var p2: Dictionary = GlassCrackClass.plan_pane_field(odd, Face.SW, 0.9)
	var c2: Vector2i = p2["centre_cell"]
	var l2: int = int(p2["centre_level"])
	var lo2: Vector2 = p2["pane_lo"]
	var hi2: Vector2 = p2["pane_hi"]
	var out2: int = 0
	for sl in odd:
		for v in sl.voxels:
			var o := Vector2(float(v.grid_pos.x - c2.x), float(v.level - l2))
			if o.x < lo2.x or o.x > hi2.x or o.y < lo2.y or o.y > hi2.y:
				out2 += 1
	var h2: Vector2 = Vector2(p2["span"]) * 0.5
	if out2 == 0 and h2.x >= maxf(absf(lo2.x), absf(hi2.x)) \
			and h2.y >= maxf(absf(lo2.y), absf(hi2.y)):
		_pass("an asymmetric pane (bounds %s..%s) is covered too" % [lo2, hi2])
	else:
		_fail("asymmetric pane: %d voxel(s) outside, quad %s" % [out2, p2["span"]])

	## ── 5. G-D9's FRAME IS NOT PART OF THE FIELD ────────────────────────────
	## A banded window keeps its brick sill and head in these same slices. The
	## field must stop at the glass, not run over the masonry.
	var banded := _pane(4, 6, 2)
	for sl in banded:
		sl.material_bands = {0: "brick", 1: "brick", 14: "brick", 15: "brick"}
	var pb: Dictionary = GlassCrackClass.plan_pane_field(banded, Face.SW, 0.55)
	var lvl_lo_b: int = int(pb["centre_level"]) + int(Vector2(pb["pane_lo"]).y)
	var lvl_hi_b: int = int(pb["centre_level"]) + int(Vector2(pb["pane_hi"]).y)
	if lvl_lo_b == base + 2 and lvl_hi_b == base + 13:
		_pass("a G-D9 banded pane's field spans levels %d..%d — the brick sill and "
			% [lvl_lo_b, lvl_hi_b] + "head are outside it")
	else:
		_fail("banded field spans %d..%d, expected %d..%d (the brick rows are in it)"
			% [lvl_lo_b, lvl_hi_b, base + 2, base + 13])

	## ── 6. GRANULARITY RUNS THE RIGHT WAY (G-D37) ───────────────────────────
	## ⚠️ THE ONE THING NO GEOMETRY TEST CAN SEE. §16.2: a NEAR blast crazes into
	## small polygons and a far one into large ones, and `GLASS_CRAZE_FALLOFF`
	## runs 1.0 at ring 0 down toward 0.12 at ring 7 (G-D48) — so high intensity is
	## the FINE mesh. Inverted, everything above still passes and every picture is
	## wrong.
	var per_ring: Array = []
	for r in range(GlassShatterClass.GLASS_CRAZE_FALLOFF.size()):
		per_ring.append(GlassCrackClass.craze_bucket_for(
			GlassShatterClass.blast_craze_intensity(r)))
	var near: Array = per_ring[0]
	var far: Array = per_ring[per_ring.size() - 1]
	if near == GlassCrackClass.CRAZE_BUCKET_FINE and far == GlassCrackClass.CRAZE_BUCKET_COARSE:
		_pass("ring 0 (%.2f) crazes from the FINE bucket and ring %d (%.2f) from the COARSE"
			% [GlassShatterClass.blast_craze_intensity(0), per_ring.size() - 1,
			GlassShatterClass.blast_craze_intensity(per_ring.size() - 1)])
	else:
		_fail("granularity is inverted: ring 0 -> %s, last ring -> %s" % [near, far])

	## ⚠️ AND BOTH BUCKETS MUST BE REACHABLE, WHICH THE ENDS ALONE CANNOT SAY.
	## `CRAZE_FINE_MIN` shipped at 0.5 against a table of [1.0, 0.80, 0.55, 0.30],
	## which put THREE rings on the fine bucket and left the coarse one at ring 3
	## alone — half of G-D37's art almost never drawn, with both assertions above
	## still green. Art the balance cannot reach is art nobody will see.
	var fine_n: int = per_ring.count(GlassCrackClass.CRAZE_BUCKET_FINE)
	var coarse_n: int = per_ring.count(GlassCrackClass.CRAZE_BUCKET_COARSE)
	if fine_n >= 2 and coarse_n >= 2:
		_pass("both buckets are reachable from the ring table: %d fine, %d coarse"
			% [fine_n, coarse_n])
	else:
		_fail("the ring table reaches %d fine and %d coarse ring(s) — one of "
			% [fine_n, coarse_n] + "G-D37's two granularities is effectively unused")

	## ── 6b. EVERY PATTERN IN A BUCKET IS REACHABLE (Director's six) ─────────
	## ⚠️ THE SAME CLASS OF DEFECT ONE LEVEL DOWN, and the reason to assert it
	## rather than trust the modulo: a bucket the hash only ever lands on two of
	## would leave a third of the approved art undrawn, and nothing would fail. The
	## keys are real base keys' shape, swept.
	var seen: Dictionary = {}
	for gx in range(24):
		for gy in range(24):
			var key := "%d,%d,80" % [gx * 7, gy * 5]
			seen[GlassCrackClass.craze_sheet_id_for(1.0, key)] = true
			seen[GlassCrackClass.craze_sheet_id_for(0.3, key)] = true
	var roster: Array = GlassCrackClass.CRAZE_BUCKET_FINE + GlassCrackClass.CRAZE_BUCKET_COARSE
	var unreached: Array = []
	for id in roster:
		if not seen.has(id):
			unreached.append(id)
	if unreached.is_empty() and seen.size() == roster.size():
		_pass("all %d approved craze patterns are reachable, and nothing outside "
			% roster.size() + "the roster is: %s" % ", ".join(roster))
	else:
		_fail("craze patterns never picked: %s (and %d id(s) drawn in total)"
			% [", ".join(unreached), seen.size()])

	## ⚠️ AND THE PICK MUST BE STABLE IN THE KEY, which is what makes a standing
	## craze survive a camera turn. Same key twice, same sheet — asserted rather
	## than assumed, because §16.10 measured a variant CHANGING on a flip.
	var k := "88,87,80"
	if GlassCrackClass.craze_sheet_id_for(1.0, k) == GlassCrackClass.craze_sheet_id_for(1.0, k) \
			and GlassCrackClass.craze_sheet_id_for(1.0, k) != "":
		_pass("the pattern pick is pure in the base key (%s)"
			% GlassCrackClass.craze_sheet_id_for(1.0, k))
	else:
		_fail("the pattern pick is not stable in its key")

	## ── 7. THE FIELD IS NOT A FRACTURE, SO IT MUST NOT BE AN OPENING ────────
	## A field borrows `plan_pane_crack`'s vocabulary but none of its event: it
	## has no impact, no radius and no hole. `opening` here would put a bullet's
	## void in the middle of a blast craze.
	if not plan.has("opening") and not plan.has("radius"):
		_pass("the field plan carries no opening and no radius — it is not an impact")
	else:
		_fail("the field plan carries impact keys: %s" % plan.keys())

	print("")


## ── B-4b — THE CRAZE FIELD IS CUT TO THE HOLES' OWN POLYGONS ────────────────
func test_the_craze_field_is_cut_to_the_holes() -> void:
	print("[19] B-4b — a hole's polygon cuts the craze mesh, sub-cell\n")

	## ⚠️ WHY THIS TEST EXISTS AFTER B-4 WAS ABANDONED. The Director dropped the
	## PERFORATION (*"vamos usar o rachado sem furos"*), not the mask — and the
	## defect the mask fixes belongs to any hole from any source. A pane a ROUND
	## has holed and a later blast crazes has exactly the same shard cells, which
	## G-D30's per-CELL occupancy reads as full glass while most of each is gone.
	## That path has no capture (it needs a shot and a blast on one pane in one
	## boot), so it is pinned here instead of left as a claim.
	var renderer = VoxelBoardClass.new()
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var cross := 7
	var run0 := 4
	var runs := 12
	var levels := 8
	## R3D-END: the pane is a glass slice in the store; until then this hand-filled the hidden glass TileMapLayers.
	_glass_board(run0, runs, cross, base, levels)

	var c_run: int = run0 + runs / 2
	var c_lvl: int = base + levels / 2
	var spec := {
		"pane_id": "PANE_TEST", "run_axis": 0, "face": Face.SW,
		"centre_cell": Vector2i(c_run, cross), "centre_level": c_lvl,
		"centre_run": c_run,
		"pane_lo": Vector2(float(run0 - c_run), float(base - c_lvl)),
		"pane_hi": Vector2(float(run0 + runs - 1 - c_run), float(base + levels - 1 - c_lvl)),
		"span": Vector2(float(runs) + 1.0, float(levels) + 1.0),
		"intensity": 0.55, "sheet": "blast_coarse",
		"tile_span": Vector2(8.0, 8.0), "variant": 0,
	}
	var fid: int = renderer.spawn_glass_craze(spec)
	if fid == 0:
		_fail("spawn_glass_craze returned 0 — no field, so there is no mask to test")
		renderer.free()
		VoxelStore.active = null
		print("")
		return

	var rec: Dictionary = renderer._glass_cracks[renderer._glass_cracks.size() - 1]

	## ── 1. NO HOLES, NO CUT ─────────────────────────────────────────────────
	## ⚠️ The control, and it is the half that matters most: an empty mask must
	## paint NOTHING. A mask that cut something on a clean pane would be eating the
	## mesh everywhere, and the difference is sub-cell on screen.
	if int(rec.get("craze_mask_painted", -1)) == 0:
		_pass("a pane with no holes paints 0 mask texel(s) — the mesh is untouched")
	else:
		_fail("a clean pane painted %d mask texel(s)" % int(rec.get("craze_mask_painted", -1)))

	## ── 2. A LOGGED OPENING CUTS IT ─────────────────────────────────────────
	var hole_run: int = c_run + 2
	var hole_lvl: int = c_lvl - 1
	renderer._glass_applied_openings.append({
		"anchor": Vector3i(hole_run, cross, hole_lvl),
		"opening": "chamfer_45", "run_is_x": true})
	renderer.refresh_craze_opening_masks()
	var painted: int = int(rec.get("craze_mask_painted", -1))
	if painted > 0:
		_pass("one logged opening cuts %d mask texel(s) out of the mesh" % painted)
	else:
		_fail("a logged opening cut nothing — the field is still drawing over the hole")

	## ── 3. AND IT CUTS WHERE THE HOLE IS, NOT SOMEWHERE ELSE ────────────────
	## ⚠️ ASSERTED AS A POSITION, NOT A COUNT. "something was painted" passes for a
	## mask painted in the wrong corner, which is the failure a wrong origin or a
	## flipped axis actually produces — and §16.6 is this project's standing lesson
	## about exactly that.
	var img: Image = rec.get("craze_mask_image")
	if img != null:
		var k: int = renderer.CRAZE_MASK_TEXELS_PER_VOXEL
		var lo: Vector2 = rec["pane_lo"]
		var hi: Vector2 = rec["pane_hi"]
		## The hole's centre, in the mask's own texel frame.
		var mx: int = int(round((float(hole_run - c_run) - (lo.x - 0.5)) * float(k)))
		var my: int = int(round(((hi.y + 0.5) - float(hole_lvl - c_lvl)) * float(k)))
		var inside: bool = mx >= 0 and my >= 0 and mx < img.get_width() and my < img.get_height() \
			and img.get_pixel(mx, my).r > 0.5
		## And a cell four voxels away on the same row must be untouched.
		var fx: int = mx - 4 * k
		var far_clear: bool = fx < 0 or img.get_pixel(fx, my).r < 0.5
		if inside and far_clear:
			_pass("the cut lands ON the hole (texel %d,%d) and 4 voxels away is clear"
				% [mx, my])
		else:
			_fail("the cut is in the wrong place: hole texel painted=%s, far cell clear=%s"
				% [inside, far_clear])
	else:
		_fail("no mask image was built")

	renderer.free()
	VoxelStore.active = null
	print("")


## ── [22] CRACK-04 / GLASS §16.13 — THE REPLAY MUST CLAIM BEFORE IT FLUSHES ───
##
## Two halves, and they are asserted as IDENTITIES rather than as "the shapes
## differ": an unclaimed erase does not produce a WRONG hole, it produces the
## DEFAULT hole, and saying which one is what makes this a measurement.
##
## ⚠️ THE SECOND HALF IS A SOURCE-ORDER CHECK, AND THAT IS THE ONLY PLACE THE BUG
## EVER LIVED. `refresh_glass_rims()` has always honoured a claim; `_group_erased_
## into_regions()` has always fallen back to `GLASS_OPENING_DEFAULT` for a hole
## nobody claimed, which is right for a live event. The defect was that the
## perspective rebuild reached the flush with no claims at all, because
## `_reapply_base_damage()` ends in `process_dirty()` and the claim was only made
## afterwards. Measured on the GLASS map 2026-09-06, two recorded holes: the log
## read `2 region(s) [star_deep*, star_deep*]` before, `[notch_v, star_wild]`
## after. Nothing in the mechanism can catch an ordering mistake in its caller, so
## the caller's order is what this pins.
func test_an_unclaimed_hole_is_reshaped_and_the_replay_claims_first() -> void:
	print("[22] an unclaimed erase takes the DEFAULT opening; the rotation replay claims first\n")

	var default_id: String = VoxelBoardClass.GLASS_OPENING_DEFAULT
	## A member that a one-cell bore reaches (so the unclaimed fallback picks the
	## DEFAULT rather than the >2-member `star_deep_wide`) and whose cut set is not
	## the default's — otherwise the two halves are the same picture and the test
	## would pass for a build with no claim path at all.
	var subject: String = ""
	for opening in GlassOpeningClass.ids():
		if opening == default_id:
			continue
		if _full_cells(opening) > 2:
			continue
		if _partial_set(opening) != _partial_set(default_id):
			subject = opening
			break
	if subject == "":
		_fail("no opening is both small-bored and shaped differently from '%s' — the fixture cannot see the defect" % default_id)
		return
	_pass("subject opening '%s' is reachable: <=2 whole cells, and its cut set differs from '%s'"
		% [subject, default_id])

	## CLAIMED — the cut must be the SUBJECT's own partial set.
	var claimed: Dictionary = _cut_set_for(subject, true)
	if claimed == _partial_set(subject):
		_pass("claimed: the board holds exactly '%s'\u2019s %d PARTIAL cell(s)"
			% [subject, claimed.size()])
	else:
		_fail("claimed: board %s, expected '%s' %s" % [claimed.keys(), subject, _partial_set(subject).keys()])

	## UNCLAIMED — the cut must be the DEFAULT's partial set. This is what every
	## hole in the game looked like after one camera turn.
	var unclaimed: Dictionary = _cut_set_for(subject, false)
	if unclaimed == _partial_set(default_id):
		_pass("unclaimed: the board holds exactly '%s'\u2019s %d PARTIAL cell(s) — the shape is LOST, not merely wrong"
			% [default_id, unclaimed.size()])
	else:
		_fail("unclaimed: board %s, expected the default '%s' %s"
			% [unclaimed.keys(), default_id, _partial_set(default_id).keys()])

	## THE ORDER, in the caller that actually rebuilds a perspective.
	var src := FileAccess.get_file_as_string("res://godot/scripts/world/room.gd")
	if src == "":
		_fail("could not read room.gd to check the replay order")
		return
	var claim_at: int = src.find("\n\t\t_claim_base_openings()")
	var reapply_at: int = src.find("\n\t\t_reapply_base_damage()")
	if claim_at >= 0 and reapply_at >= 0 and claim_at < reapply_at:
		_pass("room.gd: _claim_base_openings() precedes _reapply_base_damage() in the perspective rebuild")
	else:
		_fail("room.gd: claim at %d, reapply at %d — the replay flushes before it claims, so every hole takes '%s'"
			% [claim_at, reapply_at, default_id])


## The cells an opening SWALLOWS — destruction's part, which the fixture plays.
func _full_cells(opening: String) -> int:
	var bounds: Rect2i = GlassOpeningClass.cell_bounds(opening)
	var n: int = 0
	for dl in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for dr in range(bounds.position.x, bounds.position.x + bounds.size.x):
			if GlassOpeningClass.coverage(opening, dr, dl) == GlassOpeningClass.Coverage.FULL:
				n += 1
	return n


## The cells an opening only INTRUDES on — the ones that become shards.
func _partial_set(opening: String) -> Dictionary:
	var bounds: Rect2i = GlassOpeningClass.cell_bounds(opening)
	var out: Dictionary = {}
	for dl in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for dr in range(bounds.position.x, bounds.position.x + bounds.size.x):
			if GlassOpeningClass.coverage(opening, dr, dl) == GlassOpeningClass.Coverage.PARTIAL:
				out[Vector2i(dr, dl)] = true
	return out


## Erase `opening`\u2019s whole cells on a fresh one-pane board, optionally claim it,
## flush, and return the offsets that came back as shards. Same fixture shape as
## [15]; the ONE variable is whether the claim is made.
func _cut_set_for(opening: String, claim: bool) -> Dictionary:
	var r = VoxelBoardClass.new()
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var cross := 7
	var run0 := 0
	var runs := 23
	var levels := 17
	## R3D-END: the pane is a glass slice in the store; until then this hand-filled the hidden glass TileMapLayers.
	var board: Dictionary = _glass_board(run0, runs, cross, base, levels)

	@warning_ignore("integer_division")
	var hit_run: int = run0 + runs / 2
	@warning_ignore("integer_division")
	var hit_level: int = base + levels / 2
	var bounds: Rect2i = GlassOpeningClass.cell_bounds(opening)
	var swallowed: Array = []
	for dl in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for dr in range(bounds.position.x, bounds.position.x + bounds.size.x):
			if GlassOpeningClass.coverage(opening, dr, dl) == GlassOpeningClass.Coverage.FULL:
				swallowed.append(Vector3i(hit_run + dr, cross, hit_level + dl))
	if swallowed.is_empty():
		swallowed.append(Vector3i(hit_run, cross, hit_level))
	for k: Vector3i in swallowed:
		_destroy_glass(board, Vector2i(k.x, k.y), k.z)
		r.note_glass_erased_for_rim(k.z, Vector2i(k.x, k.y))
	if claim:
		r.claim_glass_opening(hit_level, Vector2i(hit_run, cross), opening)
	r.refresh_glass_rims()

	var out: Dictionary = {}
	for key: Vector3i in r._glass_shaped_cells:
		out[Vector2i(key.x - hit_run, key.z - hit_level)] = true
	r.free()
	VoxelStore.active = null
	return out
