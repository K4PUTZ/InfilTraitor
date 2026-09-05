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
##   [13] S-3's rebuild path acquiring side effects — a perspective flip that
##       re-damages the pane it is only supposed to redraw.
##   [14] a cell's cut collapsing to one shape (the cell OFFSET being dropped
##       from the atom key), a PARTIAL cell being cut away entirely, or the cut
##       eating the pane's slivers.
##   [16] the opening FAMILY going malformed — an opening that does not leave the
##       struck cell, a pooled id with no shape, a pick that stops hashing, or the
##       SHEET's void drifting from the voxel cut (G-D34's whole point).
##   [15] the applied hole drifting from the opening it claims to be — a cell cut
##       that coverage() calls outside, or left whole that it calls PARTIAL — and
##       the shards NOT SURVIVING a later render pass, which is what kept
##       CRACK-03's rim off the screen for its entire life.

extends SceneTree

const ShotPunchTableClass = preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GlassMaterialsClass = preload("res://godot/scripts/systems/glass_materials.gd")
const GlassCrackClass = preload("res://godot/scripts/systems/destruction/glass_crack.gd")
const GlassCrackSpriteClass = preload("res://godot/scripts/overlays/glass_crack_sprite.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const GlassOpeningClass = preload("res://godot/scripts/systems/destruction/glass_opening.gd")
## B-2 [18] — the ring intensities the granularity split is measured against.
const GlassShatterClass = preload("res://godot/scripts/systems/destruction/glass_shatter.gd")

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
	test_the_sprite_transform_lands_on_the_voxels()
	test_the_pane_bounds_clip_the_sprite()
	test_the_occupancy_cut_reads_the_live_tilemap()
	test_sprite_spec_is_render_only()
	test_the_shard_rim_cuts_eight_distinct_shapes()
	test_the_opening_family_is_well_formed()
	test_only_the_four_orthogonal_neighbours_become_shards()
	test_the_armored_sheet_is_chosen_by_the_pane_not_the_weapon()
	test_the_craze_field_covers_the_pane_and_tiles()
	test_the_craze_field_is_cut_to_the_holes()

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

	## ⚠️ A GLASS MEMBER MUST RESOLVE TO ITS OWN NAME, UNCHANGED, AT EVERY DAMAGE
	## STATE — not merely to "not a decal" (Director, 2026-09-02: *"volta a
	## aparecer o quadrado em volta do decal"*).
	##
	## This used to accept the flat `"glass_cracked"`, on the belief that the
	## render path ignored it. It does not: `_set_voxel_cell()` takes the glass
	## branch only when `GlassMaterials.is_glass(material_name)`, and
	## `is_glass("glass_cracked")` is FALSE — so every CRACKED cell went to the
	## OPAQUE layer instead. The crack radius is a rectangle, so the whole web sat
	## inside a block of another material. Measured from one boot: the pre-flip
	## and post-round-trip frames of the S-3 capture differ by exactly that
	## rectangle, 1382 contiguous pixels.
	##
	## `DamageVariantBaker` reads the same function, so this one assertion covers
	## the baked-swap path too.
	var members: Array = ["glass", "glass_armored", "glass_screen_green"]
	var states := {"CRACKED": Voxel.DamageState.CRACKED, "DENTED": Voxel.DamageState.DENTED,
		"DESTROYED": Voxel.DamageState.DESTROYED, "INTACT": Voxel.DamageState.INTACT}
	var renamed: Array = []
	for member in members:
		for sname in states:
			for blast in [false, true]:
				var name: String = VoxelRendererClass.damage_variant_material(
					member, states[sname], blast, Voxel.CarvedSide.LEFT, 0)
				if name != member:
					renamed.append("%s/%s%s -> %s"
						% [member, sname, " blast" if blast else "", name])
	if renamed.is_empty():
		_pass("every glass member keeps its own name at every damage state (%d combinations) — so it stays on the GLASS layer"
			% (members.size() * states.size() * 2))
	else:
		_fail("a glass member is renamed by damage and would render OPAQUE: %s"
			% ", ".join(renamed.slice(0, 4)))

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
		"crack_color", "crack_strength", "crack_opacity", "crack_edge_feather"]
	var missing: Array = []
	for r in required:
		if not names.has(r):
			missing.append(r)
	if missing.is_empty():
		_pass("glass_crack.gdshader declares all %d uniforms GlassCrackSprite feeds" % required.size())
	else:
		_fail("glass_crack.gdshader is missing uniform(s): %s" % ", ".join(missing))

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
	var src := FileAccess.get_file_as_string("res://godot/shaders/glass_crack.gdshader")
	if src.contains("crack_opacity"):
		_pass("the sprite's opacity is a uniform — the Director's 90% is a dial, not a hardcode")
	else:
		_fail("glass_crack.gdshader has no crack_opacity uniform to set")
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

	## Any real sheet does — this test is about the TRANSFORM, and the transform is
	## built from the span, not from the art. `star_deep` v0 simply exists.
	var sheet := load(GlassCrackClass.sheet_path("star_deep", 0)) as Texture2D
	var shader := load("res://godot/shaders/glass_crack.gdshader") as Shader
	if sheet == null or shader == null:
		_fail("no fracture sheet / crack shader to build a sprite from")
		print("")
		return

	## ⚠️ A SECOND INSTRUMENT, BECAUSE THE REST OF THIS TEST CANNOT SEE THE BUG IT
	## WAS WRITTEN AFTER. Everything below compares the sprite's transform against
	## `glass_cell_face_pos()` — the same function that builds it — so it reported
	## 0.00000 px while the sheet sat HALF A RUN STEP right of the hole, for the
	## whole life of `GLASS_CRACK_FACE_CENTRE = (0, -6)`. The centre is a claim
	## about the ATOM, so the atom is what has to answer it: compose a main-face-
	## only glass atom and take the centroid of the pixels it actually drew.
	var probe = VoxelRendererClass.new()
	var centre_drift: Array = []
	for f in [Face.SW, Face.SE, Face.NW, Face.NE]:
		var atom: Image = probe._build_glass_pane_atom(f, false, false, 0)
		if atom == null:
			centre_drift.append("face %d: no atom" % f)
			continue
		var sx: float = 0.0
		var sy: float = 0.0
		var n: int = 0
		for y in range(atom.get_height()):
			for x in range(atom.get_width()):
				if atom.get_pixel(x, y).a > 0.5:
					sx += float(x) + 0.5
					sy += float(y) + 0.5
					n += 1
		if n == 0:
			centre_drift.append("face %d: empty atom" % f)
			continue
		## `map_to_local`'s own atom reference, the point the offset is added to.
		var measured := Vector2(sx / float(n), sy / float(n)) - Vector2(16.0, 28.0)
		var declared: Vector2 = VoxelRendererClass.glass_crack_face_centre(f)
		if measured.distance_to(declared) > 1.0:
			centre_drift.append("face %d: atom says %s, code says %s" % [f, measured, declared])
	probe.free()
	if centre_drift.is_empty():
		_pass("the face centre matches the atom's own drawn pixels on all 4 faces (within 1 px)")
	else:
		_fail("face centre disagrees with the composed atom: %s" % ", ".join(centre_drift))

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
	## `_glass_rim_atom_source()` stamps `tile_name` on every shard it registers.
	## Without the layer the engine prints an error per shard and the test still
	## runs — the kind of noise that trains an eye to skip a log.
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "tile_name")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
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

	## Every key `VoxelRenderer.spawn_glass_crack()` reads. A missing one is not a
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


## [14] CRACK-03 — THE SHARD RIM (Director, 2026-09-02: *"em vez de voxels
## cúbicos, a gente vai ter partes de voxel formando triângulos agudos apontando
## em direção ao centro do buraco"*).
##
## A hole is a rectangle of missing cells and reads as one however good the web
## over it is, so the cells bordering it stop being cubes. This pins the three
## things that are invisible on screen when they break:
##   · the eight masks are eight DIFFERENT shapes. If the direction were dropped
##     on the way to the atom they would all be the same wedge, and on a 1-voxel
##     hole nobody would see it;
##   · the cut never eats the top/side SLIVERS, which are what make a pane read
##     as one voxel thick;
##   · the FACE MASK is part of the atom key. It was not, for one run: the side
##     sliver marks the frontmost column of every GU, so a hole on a GU boundary
##     cut **5** of its 8 neighbours instead of 8.
func test_the_shard_rim_cuts_eight_distinct_shapes() -> void:
	print("[14] CRACK-04 — a cell's cut is its own piece of the opening, and the slivers survive\n")

	var r = VoxelRendererClass.new()
	var plain: Image = r._build_glass_pane_atom(Face.SW, false, false, 0)
	if plain == null:
		_fail("the intact glass atom did not build — nothing to cut")
		r.free()
		print("")
		return
	var full: int = _opaque_px(plain)

	## ⚠️ THE OFFSETS ARE READ OFF THE OPENING, NOT ASSUMED. CRACK-03 asked for
	## eight fixed directions; an opening has whatever partial cells its polygon
	## happens to cross, and that count is a property of the SHAPE. Asserting a
	## hardcoded 8 here would pass for `star_deep` and fail the family.
	var opening: String = "star_deep"
	var bounds: Rect2i = GlassOpeningClass.cell_bounds(opening)
	var partials: Array = []
	var fulls: Array = []
	for dl in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for dr in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var cov: int = GlassOpeningClass.coverage(opening, dr, dl)
			if cov == GlassOpeningClass.Coverage.PARTIAL:
				partials.append(Vector2i(dr, dl))
			elif cov == GlassOpeningClass.Coverage.FULL:
				fulls.append(Vector2i(dr, dl))
	if partials.size() >= 4:
		_pass("'%s' crosses %d cells partially and swallows %d whole" % [opening, partials.size(), fulls.size()])
	else:
		_fail("'%s' has only %d partial cells — an opening that intrudes on nothing is a rectangle again"
			% [opening, partials.size()])

	var shapes: Array = []
	var kept_all: Array = []
	for off in partials:
		var a: Image = r._build_glass_pane_atom(Face.SW, false, false, 0)
		r._cut_glass_opening(a, opening, off.x, off.y, Face.SW)
		shapes.append(a)
		kept_all.append(_opaque_px(a))

	var uncut: Array = []
	for i in range(shapes.size()):
		if kept_all[i] >= full:
			uncut.append(str(partials[i]))
	if uncut.is_empty():
		_pass("every partial cell loses glass (kept %d..%d of %d px)"
			% [kept_all.min(), kept_all.max(), full])
	else:
		_fail("cell(s) %s lost nothing — the opening is not reaching the atom" % ", ".join(uncut))

	## ⚠️ AND NONE OF THEM IS EMPTY. A partial cell that lost EVERYTHING is a cell
	## the coverage sampler should have called FULL, and it would read on screen as
	## a hole one voxel bigger than the opening — the failure that cannot be undone
	## by a later pass, since the glass is already gone.
	var emptied: Array = []
	for i in range(shapes.size()):
		if kept_all[i] == 0:
			emptied.append(str(partials[i]))
	if emptied.is_empty():
		_pass("no partial cell was cut away entirely — PARTIAL and FULL agree with the raster")
	else:
		_fail("cell(s) %s were cut to nothing but classified PARTIAL" % ", ".join(emptied))

	## Distinct pieces. Compared pairwise on the alpha mask, because "they all
	## removed something" is satisfied by one shape stamped many times — which is
	## exactly what the cut degrades to if `(dr, dl)` is dropped from the key.
	var identical: Array = []
	for i in range(shapes.size()):
		for j in range(i + 1, shapes.size()):
			if _same_alpha(shapes[i], shapes[j]):
				identical.append("%s==%s" % [partials[i], partials[j]])
	if identical.size() * 4 < shapes.size() * shapes.size():
		_pass("the %d pieces are shape-distinct (%d symmetric pairs, as a symmetric star should have)"
			% [shapes.size(), identical.size()])
	else:
		_fail("the pieces collapsed to one mask: %s — the cell offset is being dropped"
			% ", ".join(identical))

	## ⚠️ AND THE SAMPLER AGREES WITH THE RASTER, WHICH IS THE OTHER HALF.
	## `coverage()` classifies a cell on a 33x33 grid; `_cut_glass_opening()`
	## decides per ATOM PIXEL. Where they disagree the walk is wrong in a way
	## nothing else can see: a cell called NONE is never rastered at all, so a
	## spike thinner than the sampler's spacing is silently lost from the hole's
	## shape, and [15] cannot catch it because [15] compares the board against the
	## same sampler. This compares the sampler against the OTHER instrument.
	var leaks: Array = []
	for dl in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for dr in range(bounds.position.x, bounds.position.x + bounds.size.x):
			if GlassOpeningClass.coverage(opening, dr, dl) != GlassOpeningClass.Coverage.NONE:
				continue
			var probe: Image = r._build_glass_pane_atom(Face.SW, false, false, 0)
			r._cut_glass_opening(probe, opening, dr, dl, Face.SW)
			if _opaque_px(probe) < full:
				leaks.append("(%d,%d)" % [dr, dl])
	if leaks.is_empty():
		_pass("every cell the sampler calls NONE is cut by nothing — sampler and raster agree")
	else:
		_fail("cell(s) %s read NONE but the raster cuts them — the sampler is coarser than the cut"
			% ", ".join(leaks))

	## ⚠️ THE SLIVER RULE CHANGED ON 2026-09-04 AND THIS ASSERTION WITH IT.
	## CRACK-03 spared the top/side slivers wholesale, so a shard on a GU boundary
	## still read one voxel THICK. Right requirement, wrong scope: the side sliver
	## is a VERTICAL strip on the frontmost column, so where a hole crossed one it
	## survived standing in mid-air inside the opening — the vertical band the
	## Director marked in the middle of the bore.
	##
	## The rule is now "spare the slivers OUTSIDE the hole", which needs both
	## halves asserted, because either one alone passes for a broken build: sparing
	## everything passes the first, cutting everything passes the second.
	var with_slivers: Image = r._build_glass_pane_atom(Face.SW, true, true, 0)
	var sliver_px: int = _opaque_px(with_slivers) - full
	var cut_slivers: Image = r._build_glass_pane_atom(Face.SW, true, true, 0)
	r._cut_glass_opening(cut_slivers, opening, partials[0].x, partials[0].y, Face.SW)
	var kept_sliver: int = _opaque_px(cut_slivers) - kept_all[0]
	if sliver_px > 0 and kept_sliver > 0:
		_pass("a cut cell keeps %d of its %d sliver px — a shard on a GU boundary still reads 1 voxel thick"
			% [kept_sliver, sliver_px])
	else:
		_fail("the cut ate the slivers whole (%d of %d left) — the shard lost its thickness"
			% [kept_sliver, sliver_px])

	## ...and a cell the opening does not reach loses NOTHING, sliver included.
	## This is the half that catches an over-eager sliver cut, which would eat the
	## pane's thickness everywhere and look like a rendering change nobody ordered.
	var far := Vector2i(bounds.position.x + bounds.size.x + 3, 0)
	var far_atom: Image = r._build_glass_pane_atom(Face.SW, true, true, 0)
	var far_before: int = _opaque_px(far_atom)
	r._cut_glass_opening(far_atom, opening, far.x, far.y, Face.SW)
	if _opaque_px(far_atom) == far_before:
		_pass("a cell outside the opening loses nothing at all, slivers included")
	else:
		_fail("a cell %s outside the opening lost %d px — the sliver cut is reaching too far"
			% [far, far_before - _opaque_px(far_atom)])

	r.free()
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


func _opaque_px(img: Image) -> int:
	var n := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n


func _same_alpha(a: Image, b: Image) -> bool:
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if (a.get_pixel(x, y).a > 0.0) != (b.get_pixel(x, y).a > 0.0):
				return false
	return true


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
		var r = VoxelRendererClass.new()
		var base: int = GeometryCoordsClass.storey_level_base(0)
		var cross := 7
		var run0 := 0
		## Wide enough for the largest member (`crescent_wide` reaches 4.2 voxels)
		## with clearance, so a hole never touches the pane's own edge.
		var runs := 23
		var levels := 17
		var ts := _one_tile_tileset()
		## ⚠️ THE RENDERER'S OWN TileSet MUST BE THE LAYERS' TileSet. The shard
		## atoms register into `_tileset`, and a `set_cell()` naming a source the
		## LAYER's tileset does not have is silently ignored — the cell keeps its
		## old id and the swap looks like it worked. Found by this test's ancestor
		## on its first run.
		r._tileset = ts
		for lvl in range(base, base + levels):
			var layer := TileMapLayer.new()
			layer.tile_set = ts
			for run in range(run0, run0 + runs):
				layer.set_cell(Vector2i(run, cross), 0, Vector2i.ZERO)
			r._glass_layers[lvl] = layer
		r._glass_source_info[0] = {"material": "glass", "face": Face.SW, "mask": 0}

		var hit_run: int = run0 + runs / 2
		var hit_level: int = base + levels / 2
		var bounds: Rect2i = GlassOpeningClass.cell_bounds(opening)

		## Destruction's part, played here: every cell the opening swallows whole
		## is erased first. The renderer refuses to erase, on purpose — it would be
		## a second writer on voxel existence.
		var expect_partial: Dictionary = {}
		for dl in range(bounds.position.y, bounds.position.y + bounds.size.y):
			for dr in range(bounds.position.x, bounds.position.x + bounds.size.x):
				var cov: int = GlassOpeningClass.coverage(opening, dr, dl)
				if cov == GlassOpeningClass.Coverage.FULL:
					(r._glass_layers[hit_level + dl] as TileMapLayer).erase_cell(
						Vector2i(hit_run + dr, cross))
					r.note_glass_erased_for_rim(hit_level + dl, Vector2i(hit_run + dr, cross))
				elif cov == GlassOpeningClass.Coverage.PARTIAL:
					expect_partial[Vector2i(dr, dl)] = true
		if r._glass_rim_dirty.is_empty():
			(r._glass_layers[hit_level] as TileMapLayer).erase_cell(Vector2i(hit_run, cross))
			r.note_glass_erased_for_rim(hit_level, Vector2i(hit_run, cross))

		r.claim_glass_opening(hit_level, Vector2i(hit_run, cross), opening)
		var swapped: int = r.refresh_glass_rims()

		## Read the board back and compare SETS.
		var wrong: Array = []
		for dl in range(bounds.position.y - 1, bounds.position.y + bounds.size.y + 1):
			for dr in range(bounds.position.x - 1, bounds.position.x + bounds.size.x + 1):
				var layer := r._glass_layers.get(hit_level + dl) as TileMapLayer
				if layer == null:
					continue
				var sid: int = layer.get_cell_source_id(Vector2i(hit_run + dr, cross))
				var is_shard: bool = sid != -1 and not r._glass_source_info.has(sid)
				if is_shard != expect_partial.has(Vector2i(dr, dl)):
					wrong.append("(%d,%d)%s" % [dr, dl, " cut" if is_shard else " whole"])
		if wrong.is_empty():
			_pass("'%s': %d shard(s), and they are exactly the %d PARTIAL cells"
				% [opening, swapped, expect_partial.size()])
		else:
			_fail("'%s': %d cell(s) disagree with coverage(): %s"
				% [opening, wrong.size(), ", ".join(wrong)])

		## ⚠️ AND THE SHARDS MUST SURVIVE A RE-RENDER. This is the assertion whose
		## absence made CRACK-03 invisible for its whole life: the swap was correct,
		## the atoms were correct, and the CRACKED ring that a hole always crazes
		## re-placed those very cells with the intact atom a frame later. Measured
		## on the real map before the fix — `refresh_glass_rims()` said 12 cells
		## cut, the tilemap said 0.
		##
		## Simulated exactly as it happens: put the ORIGINAL source back on every
		## shard cell (that is all a re-render does), then run the seam that is
		## supposed to notice. Note it is run with NOTHING dirty, because the pass
		## that overwrites a shard flags no erase at all — which is why the repair
		## cannot live behind the dirty check.
		var shard_cells: Array = r._glass_shard_cells.keys()
		for k in shard_cells:
			(r._glass_layers[k.z] as TileMapLayer).set_cell(Vector2i(k.x, k.y), 0, Vector2i.ZERO)
		if r.count_glass_shards() != 0:
			_fail("'%s': the re-render simulation did not actually clear the shards" % opening)
		r.refresh_glass_rims()
		if r.count_glass_shards() == shard_cells.size() and shard_cells.size() > 0:
			_pass("'%s': all %d shard(s) survive a render pass that overwrote them"
				% [opening, shard_cells.size()])
		else:
			_fail("'%s': %d of %d shard(s) came back after a re-render — the hole heals"
				% [opening, r.count_glass_shards(), shard_cells.size()])

		## ⚠️ THE REBUILD PATH MUST PRODUCE THE SAME BOARD AS THE SHOT PATH.
		## There are two ways an opening reaches the tilemap — `claim` + the erase
		## flush (a live shot) and `apply_glass_opening_at()` (a perspective flip or
		## a load, where nothing is erased so nothing flags a rim). They were NOT
		## equivalent when written: the rebuild claimed into a flush that never ran
		## and the hole came back a rectangle, silently, for every opening. Two
		## paths for one feature need the assertion that they agree.
		var r2 = VoxelRendererClass.new()
		r2._tileset = ts
		for lvl2 in range(base, base + levels):
			var l2 := TileMapLayer.new()
			l2.tile_set = ts
			for run2 in range(run0, run0 + runs):
				l2.set_cell(Vector2i(run2, cross), 0, Vector2i.ZERO)
			r2._glass_layers[lvl2] = l2
		r2._glass_source_info[0] = {"material": "glass", "face": Face.SW, "mask": 0}
		## Same holes, but erased WITHOUT flagging a rim — which is exactly what a
		## rebuild looks like: the cells are simply never placed.
		for dl2 in range(bounds.position.y, bounds.position.y + bounds.size.y):
			for dr2 in range(bounds.position.x, bounds.position.x + bounds.size.x):
				if GlassOpeningClass.coverage(opening, dr2, dl2) == GlassOpeningClass.Coverage.FULL:
					(r2._glass_layers[hit_level + dl2] as TileMapLayer).erase_cell(
						Vector2i(hit_run + dr2, cross))
		var direct: int = r2.apply_glass_opening_at(hit_level, Vector2i(hit_run, cross), opening)
		## ⚠️ COMPARE THE SHAPE, NOT THE SOURCE ID. The two renderers register their
		## shard atoms into the same TileSet, so equivalent shards get DIFFERENT
		## ids — `_next_free_tileset_source_id()` skips whatever is already there.
		## The first version of this check compared ids and failed all twelve
		## openings with identical counts on identical cells, which is the shape of
		## a wrong instrument rather than a wrong build.
		var mismatch: Array = []
		for dl2 in range(bounds.position.y - 1, bounds.position.y + bounds.size.y + 1):
			for dr2 in range(bounds.position.x - 1, bounds.position.x + bounds.size.x + 1):
				var la := r._glass_layers.get(hit_level + dl2) as TileMapLayer
				var lb := r2._glass_layers.get(hit_level + dl2) as TileMapLayer
				if la == null or lb == null:
					continue
				var c := Vector2i(hit_run + dr2, cross)
				var sa: int = la.get_cell_source_id(c)
				var sb: int = lb.get_cell_source_id(c)
				## Class first: empty / intact / shard.
				var ca: int = 0 if sa == -1 else (1 if r._glass_source_info.has(sa) else 2)
				var cb: int = 0 if sb == -1 else (1 if r2._glass_source_info.has(sb) else 2)
				if ca != cb:
					mismatch.append("(%d,%d) %d!=%d" % [dr2, dl2, ca, cb])
					continue
				if ca != 2:
					continue
				## Both shards — then the CUT must be pixel-identical.
				var ia: Image = ((r._tileset.get_source(sa) as TileSetAtlasSource)
					.texture as ImageTexture).get_image()
				var ib: Image = ((r2._tileset.get_source(sb) as TileSetAtlasSource)
					.texture as ImageTexture).get_image()
				if not _same_alpha(ia, ib):
					mismatch.append("(%d,%d) shape" % [dr2, dl2])
		if mismatch.is_empty() and direct == swapped:
			_pass("'%s': the rebuild path lands the same %d shard(s) on the same cells" % [opening, direct])
		else:
			_fail("'%s': rebuild cut %d vs shot %d; cells differing: %s"
				% [opening, direct, swapped, ", ".join(mismatch) if not mismatch.is_empty() else "none"])
		_free_glass_layers(r2)
		r2.free()

		_free_glass_layers(r)
		r.free()
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
	## small polygons and a far one into large ones, and `CRAZE_RING_INTENSITY`
	## runs 1.0 at ring 0 down to 0.30 at ring 3 — so high intensity is the FINE
	## mesh. Inverted, everything above still passes and every picture is wrong.
	var per_ring: Array = []
	for r in range(GlassShatterClass.CRAZE_RING_INTENSITY.size()):
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
	var renderer = VoxelRendererClass.new()
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var cross := 7
	var run0 := 4
	var runs := 12
	var levels := 8
	var ts := _one_tile_tileset()
	for lvl in range(base, base + levels):
		var layer := TileMapLayer.new()
		layer.tile_set = ts
		for r in range(run0, run0 + runs):
			layer.set_cell(Vector2i(r, cross), 0, Vector2i.ZERO)
		renderer._glass_layers[lvl] = layer

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
		_free_glass_layers(renderer)
		renderer.free()
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

	_free_glass_layers(renderer)
	renderer.free()
	print("")

