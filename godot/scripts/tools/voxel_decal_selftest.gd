## DESTRUCTION_MASTER_PLAN D32 — damage-decal placement selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/voxel_decal_selftest.gd
##
## What this suite exists to catch, stated as the bug it would have caught:
## before D32 every firearm hit on a wall painted its bullet hole on the voxel's
## TOP diamond, because apply_point_impact() never resolved which face was
## struck and the art had the mark baked on the top face. Nothing failed — it
## just rendered wrong. So the assertions here are about WHICH NAME a given
## (tier, cause, side) resolves to, and about every one of those names having a
## real asset behind it, rather than about the pixels.
##
## Deliberately NOT asserted here: what the decal looks like. That is verified
## on the asset side (the generator's own geometry checks) and by real capture.

extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

## ASSET_TREE_REFORM (2026-08-21): the manifest describes the decal CONTRACT
## (canvas, variant count, which families exist), not any one material's art, so
## it sits at the root of the material tree rather than inside a material folder.
const MANIFEST_PATH := "res://ASSETS/materials/manifest.json"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D32 — DAMAGE DECAL SELFTEST")
	print("=".repeat(70) + "\n")

	test_every_decal_name_has_an_asset()
	test_manifest_agrees_with_the_renderer()
	test_bullet_marks_the_struck_lateral_face_only()
	test_cracked_is_whole_voxel_for_a_blast()
	test_ceiling_carve_is_variantless()
	test_floor_dent_uses_the_real_material_art()
	test_variant_selects_distinct_names()
	test_unknown_material_falls_back_instead_of_composing_a_missing_name()
	test_shooter_gu_resolves_a_real_side()
	test_a_blast_never_resolves_to_a_bullet_mark()
	test_metal_and_wood_do_not_crack()
	test_hole_only_materials_get_no_decal_family()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ VOXEL DECAL SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ VOXEL DECAL SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## B6 — every impact-mark shape must have a REAL renderable asset behind it,
## in whichever path actually renders it, or the game silently repaints it
## flat concrete on the Director's screen instead of failing loudly here.
##
## D33 Part 4c (2026-08-03) retired impact_decal_names()/IMPACT_ASSET_TEMPLATE/
## the MATERIALS-registration this test used to check: no impact-mark
## pseudo-material is pre-registered in MATERIALS or backed by a per-name
## composites/ file any more. Every shape is composited LIVE now, from TWO
## possible asset sources depending on which path renders it:
##   - the photographic decal (DECAL_NAME_TEMPLATE) — Parts 3a-3d, when a
##     baked atom is available;
##   - the generic vector mark (GENERIC_MARK_TEMPLATE) — Part 4b, always
##     available as the fallback (bake OFF, or no baked atom for this cell).
## Ceiling ("_blast_dented_bottom") needs neither — it is a silhouette carve
## with no decal in ANY path (the camera never sees a voxel's underside).
func test_every_decal_name_has_an_asset() -> void:
	print("[1] Every impact-mark shape has a real asset behind both the baked path and the generic fallback (B6)\n")

	var checked := 0
	var missing: Array[String] = []
	var unrecognised: Array[String] = []

	for material in VoxelRendererClass.IMPACT_DECAL_MATERIALS:
		for variant in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
			for side in ["left", "right"]:
				## bullet CRACKED and bullet DENTED — both decal family "bullet",
				## both need the generic "bullet_cracked"/"bullet_dented" kind.
				_check_shape("%s_bullet_cracked_%s_%d" % [material, side, variant],
					"bullet", material, variant, "bullet_cracked", checked, missing, unrecognised)
				checked += 1
				_check_shape("%s_bullet_dented_%s_%d" % [material, side, variant],
					"bullet", material, variant, "bullet_dented", checked, missing, unrecognised)
				checked += 1
				_check_shape("%s_blast_dented_%s_%d" % [material, side, variant],
					"dent", material, variant, "blast_dent", checked, missing, unrecognised)
				checked += 1
			if VoxelRendererClass.IMPACT_CRACK_MATERIALS.has(material):
				_check_shape("%s_blast_cracked_all_%d" % [material, variant],
					"crack", material, variant, "blast_crack", checked, missing, unrecognised)
				checked += 1
			_check_shape("%s_blast_dented_top_%d" % [material, variant],
				"dent", VoxelRendererClass.IMPACT_FLOOR_MATERIAL, variant, "blast_dent",
				checked, missing, unrecognised)
			checked += 1
		## Ceiling: no decal in either path, just _is_impact_mark() recognition.
		checked += 1
		var ceiling_name := "%s_blast_dented_bottom" % material
		if not VoxelRendererClass._is_impact_mark(ceiling_name):
			unrecognised.append(ceiling_name)

	## The floor's own carved-TOP row (D26 — shared "earth" family, no bullets,
	## no crack tier).
	for variant in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
		_check_shape("%s_blast_dented_top_%d" % [VoxelRendererClass.IMPACT_FLOOR_MATERIAL, variant],
			"dent", VoxelRendererClass.IMPACT_FLOOR_MATERIAL, variant, "blast_dent",
			checked, missing, unrecognised)
		checked += 1

	if missing.is_empty():
		_pass("%d impact-mark shapes checked, every one has a real asset in whichever path renders it" % checked)
	else:
		_fail("%d of %d shapes missing an asset: %s"
			% [missing.size(), checked, ", ".join(missing.slice(0, 5))])

	if unrecognised.is_empty():
		_pass("all shape names classify as impact marks (right branch, baked lookup bypassed)")
	else:
		_fail("%d shape name(s) not recognised by _is_impact_mark(): %s"
			% [unrecognised.size(), ", ".join(unrecognised.slice(0, 5))])

	print("")


## Checks one (name, path) pair: the constructed pseudo-material name must
## classify as an impact mark, and BOTH the photographic decal (baked path)
## and the generic vector mark (Part 4b fallback path) it could resolve
## through must be real, loadable files.
func _check_shape(name: String, decal_family: String, decal_material: String, variant: int,
		generic_kind: String, _checked: int, missing: Array[String], unrecognised: Array[String]) -> void:
	if not VoxelRendererClass._is_impact_mark(name):
		unrecognised.append(name)
	## ASSET_TREE_REFORM: the template's first arg is the material FOLDER.
	var photo_path: String = VoxelRendererClass.DECAL_NAME_TEMPLATE % [
		decal_material, decal_family, decal_material, variant]
	if not FileAccess.file_exists(photo_path):
		missing.append(photo_path)
	var generic_path: String = VoxelRendererClass.GENERIC_MARK_TEMPLATE % [generic_kind, variant]
	if not FileAccess.file_exists(generic_path):
		missing.append(generic_path)


## The generator writes the manifest; the renderer hardcodes the same counts.
## A drift between them fails as a silent MATERIALS.find() miss at runtime, so
## it is asserted rather than trusted.
func test_manifest_agrees_with_the_renderer() -> void:
	print("[2] voxels/manifest.json agrees with VoxelRenderer's constants\n")

	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("manifest.json missing at %s — run tools/asset_generation/generate_voxel.py" % MANIFEST_PATH)
		print("")
		return
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("manifest.json is not a JSON object")
		print("")
		return

	var manifest_variants: int = int(parsed.get("variant_count", -1))
	if manifest_variants == VoxelRendererClass.IMPACT_DECAL_VARIANTS:
		_pass("variant_count %d matches IMPACT_DECAL_VARIANTS" % manifest_variants)
	else:
		_fail("variant_count %d != IMPACT_DECAL_VARIANTS %d — generator and renderer disagree"
			% [manifest_variants, VoxelRendererClass.IMPACT_DECAL_VARIANTS])

	var manifest_materials: Array = parsed.get("materials", [])
	if manifest_materials == Array(VoxelRendererClass.IMPACT_DECAL_MATERIALS):
		_pass("material list matches IMPACT_DECAL_MATERIALS (%s)" % ", ".join(manifest_materials))
	else:
		_fail("material list %s != IMPACT_DECAL_MATERIALS %s"
			% [manifest_materials, VoxelRendererClass.IMPACT_DECAL_MATERIALS])

	print("")


## D32.4 — the placement rule that replaces the top-face bug.
func test_bullet_marks_the_struck_lateral_face_only() -> void:
	print("[3] A bullet resolves to the lateral face it struck, never a top/bottom name\n")

	for side_name in [["left", Voxel.CarvedSide.LEFT], ["right", Voxel.CarvedSide.RIGHT]]:
		var side: int = side_name[1]
		for state_name in [["cracked", Voxel.DamageState.CRACKED],
				["dented", Voxel.DamageState.DENTED]]:
			var resolved: String = VoxelRendererClass.damage_variant_material(
				"concrete", state_name[1], false, side, 0)
			var expected := "concrete_bullet_%s_%s_0" % [state_name[0], side_name[0]]
			if resolved == expected:
				_pass("%s bullet on the %s face → %s" % [state_name[0], side_name[0], resolved])
			else:
				_fail("%s bullet on the %s face → %s, expected %s"
					% [state_name[0], side_name[0], resolved, expected])

	## The inverse of the original bug: a bullet must never land on a horizontal
	## face. TOP/BOTTOM are unreachable for a firearm (walls only, D32.4), so if
	## one is somehow passed, the result must not be a bullet decal on a
	## horizontal surface.
	var horizontal_ok := true
	for side in [Voxel.CarvedSide.TOP, Voxel.CarvedSide.BOTTOM]:
		for state in [Voxel.DamageState.CRACKED, Voxel.DamageState.DENTED]:
			var resolved: String = VoxelRendererClass.damage_variant_material(
				"concrete", state, false, side, 0)
			if resolved.contains("_bullet_"):
				horizontal_ok = false
				_fail("a bullet resolved to %s — horizontal faces take no bullet decal" % resolved)
	if horizontal_ok:
		_pass("no bullet decal resolves on a TOP or BOTTOM face")

	print("")


## D32.3 — "não existe voxel rachado só em uma face".
func test_cracked_is_whole_voxel_for_a_blast() -> void:
	print("[4] A blast-CRACKED voxel resolves to the whole-voxel name, whatever the side\n")

	## Driven on a material that actually cracks — D32.6 took metal and wood out
	## of the crack tier entirely, so asking metal here would test the fallback
	## rather than the rule.
	var material: String = VoxelRendererClass.IMPACT_CRACK_MATERIALS[0]
	var expected := "%s_blast_cracked_all_1" % material
	var names: Dictionary = {}
	for side in [Voxel.CarvedSide.NONE, Voxel.CarvedSide.LEFT, Voxel.CarvedSide.RIGHT,
			Voxel.CarvedSide.TOP, Voxel.CarvedSide.BOTTOM]:
		names[VoxelRendererClass.damage_variant_material(
			material, Voxel.DamageState.CRACKED, true, side, 1)] = true

	if names.size() == 1 and names.has(expected):
		_pass("all five sides resolve to the single name %s" % expected)
	else:
		_fail("blast CRACKED resolved to %d distinct name(s): %s" % [names.size(), names.keys()])

	print("")


## D32 — the ceiling carve carries no decal, so it carries no variant either.
func test_ceiling_carve_is_variantless() -> void:
	print("[5] The ceiling (BOTTOM) carve is one variantless name; the others are not\n")

	var bottom_names: Dictionary = {}
	for variant in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
		bottom_names[VoxelRendererClass.damage_variant_material(
			"wood", Voxel.DamageState.DENTED, true, Voxel.CarvedSide.BOTTOM, variant)] = true
	if bottom_names.size() == 1 and bottom_names.has("wood_blast_dented_bottom"):
		_pass("every variant of a BOTTOM carve resolves to wood_blast_dented_bottom")
	else:
		_fail("BOTTOM carve produced %d name(s): %s" % [bottom_names.size(), bottom_names.keys()])

	var top_names: Dictionary = {}
	for variant in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
		top_names[VoxelRendererClass.damage_variant_material(
			"wood", Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, variant)] = true
	if top_names.size() == VoxelRendererClass.IMPACT_DECAL_VARIANTS:
		_pass("a TOP (floor) carve still varies across %d names" % top_names.size())
	else:
		_fail("TOP carve collapsed to %d name(s) — the variant axis is dead there too"
			% top_names.size())

	print("")


## D34/E-SEAM-02 (Director, 2026-08-08) — a floor dent is named after the REAL
## material and wears that material's own decal art, exactly like a wall or a
## ceiling. `earth` survives only as the fallback family for a material with no
## `decal_dent_<m>_*` of its own. Both halves are asserted here (the naming AND
## the plan parser that reads it back) because the two have to agree for the
## right PNG to be loaded — _composite_floor_sunk_decal() feeds
## plan["base_material"] straight into DECAL_NAME_TEMPLATE.
func test_floor_dent_uses_the_real_material_art() -> void:
	print("[6b] Floor dents carry the real material, falling back to earth only without own art (D34)\n")

	## Materials WITH their own decal family name themselves.
	for material in VoxelRendererClass.IMPACT_DECAL_MATERIALS:
		var name: String = VoxelRendererClass.floor_damage_material(
			material, Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, 0)
		var expected := "%s_blast_dented_top_0" % material
		if name != expected:
			_fail("%s floor dent named '%s', expected '%s'" % [material, name, expected])
			continue
		var plan: Dictionary = VoxelRendererClass._floor_sunk_decal_plan(name)
		if String(plan.get("base_material", "")) != material:
			_fail("%s: plan read back base_material '%s'" % [material, plan.get("base_material", "")])
			continue
		## The file the compositor will actually open, derived the same way.
		var decal_path: String = VoxelRendererClass.DECAL_NAME_TEMPLATE % [
			plan["base_material"], plan["decal_family"],
			plan["base_material"], plan["variant"]]
		if FileAccess.file_exists(decal_path):
			_pass("%s floor dent -> '%s' -> %s (real asset on disk)" % [
				material, name, decal_path.get_file()])
		else:
			_fail("%s floor dent resolves '%s', which does not exist" % [material, decal_path])

	## A floor-only material (no facade, no decal family) still falls back to
	## the shared earth art — D25's rule, kept exactly where it still applies.
	var grass_name: String = VoxelRendererClass.floor_damage_material(
		"grass", Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, 0)
	var grass_plan: Dictionary = VoxelRendererClass._floor_sunk_decal_plan(grass_name)
	if grass_name == "earth_blast_dented_top_0" \
			and String(grass_plan.get("base_material", "")) == VoxelRendererClass.IMPACT_FLOOR_MATERIAL:
		_pass("grass (no decal art of its own) still falls back to the shared earth family")
	else:
		_fail("grass floor dent named '%s' (plan base '%s'), expected the earth fallback" % [
			grass_name, grass_plan.get("base_material", "")])

	print("")


## D32.5 — a variant that is accepted but ignored would pass every other test.
func test_variant_selects_distinct_names() -> void:
	print("[6] Each variant resolves to its own name, and the value survives set_damage()\n")

	var seen: Dictionary = {}
	for variant in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
		seen[VoxelRendererClass.damage_variant_material(
			"stone", Voxel.DamageState.DENTED, false, Voxel.CarvedSide.LEFT, variant)] = true
	if seen.size() == VoxelRendererClass.IMPACT_DECAL_VARIANTS:
		_pass("%d variants → %d distinct names" % [seen.size(), seen.size()])
	else:
		_fail("variants collapsed to %d name(s): %s" % [seen.size(), seen.keys()])

	## Round-trip through the Voxel, which is what the renderer actually reads.
	## LEAK-CYCLE-01: the stub needs its own local. Voxel holds its container by
	## instance id, so an inline _StubContainer.new() would be freed the moment
	## the constructor returned and set_damage() would call into a dead object.
	var stub := _StubContainer.new()
	var voxel := Voxel.new(Vector2i(3, 4), 2, stub)
	voxel.set_damage(Voxel.DamageState.DENTED, false, Voxel.CarvedSide.RIGHT, 2)
	if voxel.damage_variant == 2:
		_pass("Voxel.set_damage() stored variant 2")
	else:
		_fail("Voxel.set_damage() stored variant %d, expected 2" % voxel.damage_variant)

	## Read-once discipline, same as damage_is_blast and damage_carved_side: a
	## second hit must not swap the art out from under an existing mark.
	voxel.set_damage(Voxel.DamageState.DENTED, false, Voxel.CarvedSide.LEFT, 0)
	if voxel.damage_variant == 2:
		_pass("a repeat hit into the same state left the variant alone (read-once)")
	else:
		_fail("a repeat hit rewrote the variant to %d" % voxel.damage_variant)

	print("")


## The trap D26 documented: an unknown material composing a name that misses
## MATERIALS turns into source_id 0 and repaints the voxel flat concrete.
func test_unknown_material_falls_back_instead_of_composing_a_missing_name() -> void:
	print("[7] A material with no decal family falls back to a name that EXISTS\n")

	## D19/D20 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): "grass" replaces
	## "ground_concrete" as the example of a registered material outside
	## IMPACT_DECAL_MATERIALS — "concrete" now has a decal family (it's the
	## same unified material as the wall's), so it no longer fits this case.
	for material in ["glass", "grass", "not_a_material"]:
		var resolved: String = VoxelRendererClass.damage_variant_material(
			material, Voxel.DamageState.DENTED, true, Voxel.CarvedSide.LEFT, 1)
		if resolved.ends_with("_1"):
			_fail("%s composed a decal name (%s) it has no assets for" % [material, resolved])
		else:
			_pass("%s → %s (legacy path, no phantom decal name)" % [material, resolved])

	print("")


## D32.4 — the actual wiring: apply_point_impact() must resolve a side.
func test_shooter_gu_resolves_a_real_side() -> void:
	print("[8] carved_side_for() gives a firearm a lateral side, and NONE without a shooter\n")

	var target := Vector2i(10, 10)
	var from_left: int = BlastCalculator.carved_side_for(target, false, Vector2i(0, 10))
	var from_right: int = BlastCalculator.carved_side_for(target, false, Vector2i(20, 10))
	if from_left == Voxel.CarvedSide.LEFT and from_right == Voxel.CarvedSide.RIGHT:
		_pass("a shooter to screen-left marks LEFT, to screen-right marks RIGHT")
	else:
		_fail("sides resolved to %d / %d, expected LEFT(%d) / RIGHT(%d)"
			% [from_left, from_right, Voxel.CarvedSide.LEFT, Voxel.CarvedSide.RIGHT])

	var absent: int = BlastCalculator.carved_side_for(
		target, false, BlastCalculator.NO_EPICENTER_BIAS)
	if absent == Voxel.CarvedSide.NONE:
		_pass("no shooter supplied → NONE (pre-D32 fallback preserved for old callers)")
	else:
		_fail("absent shooter resolved to side %d instead of NONE" % absent)

	## The variant picker must be deterministic and in range — it is stored, so
	## a drifting value would change art on a re-run of the same shot.
	var a: int = BlastCalculator.decal_variant_for("SALT", 3, 7)
	var b: int = BlastCalculator.decal_variant_for("SALT", 3, 7)
	var in_range := a >= 0 and a < VoxelRendererClass.IMPACT_DECAL_VARIANTS
	if a == b and in_range:
		_pass("decal_variant_for() is deterministic and in range (got %d twice)" % a)
	else:
		_fail("decal_variant_for() gave %d then %d (range 0..%d)"
			% [a, b, VoxelRendererClass.IMPACT_DECAL_VARIANTS - 1])

	print("")


## D23, restated by the Director 2026-08-02: "explosão não gera buracos de
## balas, somente dented e cracked."
##
## This was already true when the Director raised it — every blast write in
## BlastCalculator passes from_blast=true, so the family was never in doubt.
## It is asserted anyway because the guarantee lives in a DEFAULT PARAMETER
## (set_damage's `from_blast`), and a future caller that forgets it inherits the
## bullet family silently, with no error and no failing test. Exhaustive over
## every material x tier x side rather than a spot check, since the whole point
## is that no corner of the matrix leaks.
func test_a_blast_never_resolves_to_a_bullet_mark() -> void:
	print("[9] No blast, on any material/tier/side, resolves to a bullet mark\n")

	var materials: Array[String] = VoxelRendererClass.IMPACT_DECAL_MATERIALS.duplicate()
	materials.append_array(["glass", "grass", VoxelRendererClass.IMPACT_FLOOR_MATERIAL])
	var offenders: Array[String] = []
	var checked := 0
	for material in materials:
		for state in [Voxel.DamageState.CRACKED, Voxel.DamageState.DENTED]:
			for side in [Voxel.CarvedSide.NONE, Voxel.CarvedSide.LEFT,
					Voxel.CarvedSide.RIGHT, Voxel.CarvedSide.TOP, Voxel.CarvedSide.BOTTOM]:
				for variant in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
					checked += 1
					var resolved: String = VoxelRendererClass.damage_variant_material(
						material, state, true, side, variant)
					## The bullet families are the D32 "_bullet_" names and D22's
					## original bare "<material>_dented"/"_cracked" pair.
					if resolved.contains("_bullet_") \
							or resolved == "%s_dented" % material \
							or resolved == "%s_cracked" % material:
						offenders.append("%s → %s" % [material, resolved])

	if offenders.is_empty():
		_pass("%d blast combinations checked, none resolved to a bullet mark" % checked)
	else:
		_fail("%d blast combination(s) resolved to a bullet mark: %s"
			% [offenders.size(), ", ".join(offenders.slice(0, 5))])

	print("")


## D32.6 — "metal e madeira não ficam rachados, só dented ou balas."
##
## Two halves that must agree: the DATA (crack_factor 0.0, so the tier is never
## reached) and the ASSETS (no crack decal generated). Asserting only one would
## leave the other free to drift — a non-zero crack_factor with no asset is the
## silent MATERIALS.find() miss, and an asset with a zero factor is dead art in
## the Director's queue.
func test_metal_and_wood_do_not_crack() -> void:
	print("[10] Metal and wood never blast-crack, in data AND in assets\n")

	for material in ["metal", "wood"]:
		var factor: float = MaterialResistanceTable.crack_factor(material)
		if is_zero_approx(factor):
			_pass("%s crack_factor is 0.0 — a blast can only destroy or dent it" % material)
		else:
			_fail("%s crack_factor is %.2f — a blast can still crack it" % [material, factor])

		var resolved: String = VoxelRendererClass.damage_variant_material(
			material, Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE, 0)
		if resolved.contains("_cracked_all_"):
			_fail("%s still resolves a whole-voxel crack decal (%s)" % [material, resolved])
		else:
			_pass("%s has no blast-crack decal (falls back to %s)" % [material, resolved])

	## ...and the materials that DO crack must still have theirs, or this rule
	## would pass just as well by deleting the feature.
	for material in VoxelRendererClass.IMPACT_CRACK_MATERIALS:
		var resolved: String = VoxelRendererClass.damage_variant_material(
			material, Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE, 0)
		if resolved == "%s_blast_cracked_all_0" % material:
			_pass("%s still cracks → %s" % [material, resolved])
		else:
			_fail("%s should still crack but resolved to %s" % [material, resolved])
		if MaterialResistanceTable.crack_factor(material) <= 0.0:
			_fail("%s is listed as a cracking material but its crack_factor is 0.0" % material)

	print("")


func test_hole_only_materials_get_no_decal_family() -> void:
	print("[11] MAT-SOFT-01 — a hole-only material never gets a decal family\n")

	## The guard against a well-meaning future edit, and it guards the ART side
	## specifically. ShotPunchTable.HOLE_ONLY_MATERIALS already makes fabric,
	## cardboard and plywood incapable of reaching CRACKED or DENTED; adding one
	## of them to IMPACT_DECAL_MATERIALS would not break anything visibly — it
	## would just commission 3 files per family that nothing can ever resolve.
	## Director, 2026-08-21: *"não vamos ter decals nos materiais moles."*
	for material in ShotPunchTable.HOLE_ONLY_MATERIALS:
		if VoxelRendererClass.IMPACT_DECAL_MATERIALS.has(material):
			_fail("%s is in IMPACT_DECAL_MATERIALS, but it can never reach a marked tier" % material)
		else:
			_pass("%s has no decal family, which matches its two-state tier rule" % material)
		if VoxelRendererClass.IMPACT_CRACK_MATERIALS.has(material):
			_fail("%s is listed as a cracking material" % material)

	## ...and the same assertion from the other end, with test [7]'s own
	## predicate: the PHOTOGRAPHIC path is the only one that ends in a variant
	## index, so a name carrying `_1` means 3 files per family were commissioned.
	## The legacy full-voxel name a hole-only material falls back to is not a
	## failure here — it is unreachable, because HOLE_ONLY_MATERIALS means these
	## tiers can never be produced in the first place. What this pins is that
	## nobody added the ART without noticing the tier can never fire.
	var composed: Array[String] = []
	for material in ShotPunchTable.HOLE_ONLY_MATERIALS:
		for state in [Voxel.DamageState.CRACKED, Voxel.DamageState.DENTED]:
			for blast in [true, false]:
				var resolved: String = VoxelRendererClass.damage_variant_material(
					material, state, blast, Voxel.CarvedSide.LEFT, 1)
				if resolved.ends_with("_1"):
					composed.append("%s tier %d blast=%s -> %s" % [material, state, blast, resolved])
	if composed.is_empty():
		_pass("no hole-only material composes a variant decal name, over 3 materials x 2 tiers x 2 causes")
	else:
		_fail("a hole-only material composed a variant decal name: %s" % ", ".join(composed))

	print("")


## Voxel needs a container for dirty propagation; this is the minimum contract
## it actually calls (see Voxel._parent_container_id's own doc). LEAK-CYCLE-01:
## a Voxel does NOT keep its container alive, so callers must hold the stub in a
## named local for as long as they touch the voxel.
class _StubContainer:
	var id: String = "STUB"
	func increment_dirty() -> void: pass
	func decrement_dirty() -> void: pass
