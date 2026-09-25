## DESTRUCTION_MASTER_PLAN D32 — damage-decal ART selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/voxel_decal_selftest.gd
##
## What this suite exists to catch: a decal family, a variant or a generic mark missing from disk, or the generator's manifest
## drifting from the constants the board reads. Nothing fails loudly otherwise — a mark is silently dropped.
## R3D-END END-4: the criteria about WHICH NAME a (tier, cause, side) resolves to went with the 2D name resolver
## (`damage_variant_material()` and its plan parsers); the board picks a decal by (family, material, variant) and this suite
## keeps the asset side of that.
##
## Deliberately NOT asserted here: what the decal looks like. That is verified
## on the asset side (the generator's own geometry checks) and by real capture.

extends SceneTree

const VoxelBoardClass = preload("res://godot/scripts/geometry/voxel_board.gd")

## ASSET_TREE_REFORM (2026-08-21): the manifest describes the decal CONTRACT
## (canvas, variant count, which families exist), not any one material's art, so
## it sits at the root of the material tree rather than inside a material folder.
const MANIFEST_PATH := "res://ASSETS/materials/manifest.json"
## A decal's path: (material folder, family, material, variant). The material appears twice on purpose (ASSET_TREE_REFORM).
const DECAL_NAME_TEMPLATE := "res://ASSETS/materials/%s/decals/decal_%s_%s_%d.png"
## The material-agnostic marks (D25) belong to no material, so they sit in a folder that cannot collide with one.
const GENERIC_MARK_TEMPLATE := "res://ASSETS/materials/_generic/decals/decal_generic_%s_%d.png"
## Must match GENERIC_MARK_VARIANTS in generate_voxel.py.
const GENERIC_MARK_VARIANT_COUNT: int = 3

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D32 — DAMAGE DECAL SELFTEST")
	print("=".repeat(70) + "\n")

	test_every_family_variant_has_an_asset()
	test_manifest_agrees_with_the_renderer()
	test_every_data_reachable_tier_has_art()

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


## B6 — every (family, material, variant) the board can draw must be a real file, and so must the generic marks the
## material-agnostic path takes.
func test_every_family_variant_has_an_asset() -> void:
	print("[1] Every decal family the board draws has all its variants on disk (B6)\n")
	var checked := 0
	var missing: Array[String] = []
	for material in VoxelBoardClass.IMPACT_DECAL_MATERIALS:
		var families: Array[String] = ["bullet", "dent"]
		if VoxelBoardClass.IMPACT_CRACK_MATERIALS.has(material):
			families.append("crack")
		for variant in range(VoxelBoardClass.IMPACT_DECAL_VARIANTS):
			for family in families:
				checked += 1
				var path: String = DECAL_NAME_TEMPLATE % [material, family, material, variant]
				if not FileAccess.file_exists(path):
					missing.append(path)
	## The floor's dent is the shared "earth" family (D26): no bullets, no crack tier.
	for variant in range(VoxelBoardClass.IMPACT_DECAL_VARIANTS):
		checked += 1
		var floor_path: String = DECAL_NAME_TEMPLATE % [
			VoxelBoardClass.IMPACT_FLOOR_MATERIAL, "dent", VoxelBoardClass.IMPACT_FLOOR_MATERIAL, variant]
		if not FileAccess.file_exists(floor_path):
			missing.append(floor_path)
	for kind in ["bullet_cracked", "bullet_dented", "blast_dent", "blast_crack"]:
		for variant in range(GENERIC_MARK_VARIANT_COUNT):
			checked += 1
			var generic_path: String = GENERIC_MARK_TEMPLATE % [kind, variant]
			if not FileAccess.file_exists(generic_path):
				missing.append(generic_path)
	if missing.is_empty():
		_pass("%d decal files checked, every one is on disk" % checked)
	else:
		_fail("%d of %d decal files missing: %s" % [missing.size(), checked, ", ".join(missing.slice(0, 5))])
	print("")


## The generator writes the manifest; the renderer hardcodes the same counts.
## A drift between them drops marks silently at runtime, so it is asserted
## rather than trusted.
func test_manifest_agrees_with_the_renderer() -> void:
	print("[2] voxels/manifest.json agrees with VoxelBoard's constants\n")

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
	if manifest_variants == VoxelBoardClass.IMPACT_DECAL_VARIANTS:
		_pass("variant_count %d matches IMPACT_DECAL_VARIANTS" % manifest_variants)
	else:
		_fail("variant_count %d != IMPACT_DECAL_VARIANTS %d — generator and renderer disagree"
			% [manifest_variants, VoxelBoardClass.IMPACT_DECAL_VARIANTS])

	var manifest_materials: Array = parsed.get("materials", [])
	if manifest_materials == Array(VoxelBoardClass.IMPACT_DECAL_MATERIALS):
		_pass("material list matches IMPACT_DECAL_MATERIALS (%s)" % ", ".join(manifest_materials))
	else:
		_fail("material list %s != IMPACT_DECAL_MATERIALS %s"
			% [manifest_materials, VoxelBoardClass.IMPACT_DECAL_MATERIALS])

	print("")


## MAT-COHERENCE-01 (Director, 2026-09-01: *"tem alguns materiais que não ficam
## rachados mesmo. Se estiver coisa sendo instanciada sem arte aí sim me avisa."*)
##
## Test [10] above answers that question for a HARDCODED pair, metal and wood.
## This answers it for EVERY material the resistance table actually loads, and it
## enumerates them the way the table itself does — walking `ASSETS/materials/<id>/
## <id>.json` rather than a list in this file, so a material added tomorrow is
## covered the day it lands instead of the day someone remembers this test.
##
## The invariant, in one line: **a non-zero factor is a promise the renderer has
## to be able to keep.** The two directions fail differently and both are silent:
##   - factor > 0 with no wired family and no art → the tier IS reachable and
##     resolves to a name nothing can load. That is the silent MATERIALS.find()
##     miss — flat concrete on the Director's screen, no error anywhere.
##   - factor == 0 with a family wired → dead art sitting in the Director's
##     queue, and a decal gate that reports PASS on files nothing will ever load.
##
## NOT a bug and deliberately allowed: a material with a non-zero dent_factor and
## NO wired family. It takes its marks through the material-agnostic GENERIC mark
## (D33 Part 4b), which is a real mark, not an absence — this asserts that the
## generic asset it will fall to actually exists, rather than assuming it.
func test_every_data_reachable_tier_has_art() -> void:
	print("[12] MAT-COHERENCE-01 — every tier the DATA can reach has art behind it\n")

	var ids: Array[String] = _declared_material_ids()
	if ids.is_empty():
		_fail("no material rows found under %s — the table's own scan would be empty too"
			% MaterialResistanceTable.RES_MATERIALS_DIR)
		print("")
		return

	var crack_offenders: Array[String] = []
	var dead_art: Array[String] = []
	var dent_offenders: Array[String] = []
	var cracking: Array[String] = []
	var generic_dent: Array[String] = []

	for material in ids:
		var crack: float = MaterialResistanceTable.crack_factor(material)
		var dent: float = MaterialResistanceTable.dent_factor(material)

		## ── CRACK ────────────────────────────────────────────────────────────
		if crack > 0.0:
			cracking.append("%s %.2f" % [material, crack])
			if not VoxelBoardClass.IMPACT_CRACK_MATERIALS.has(material):
				crack_offenders.append("%s (factor %.2f, not wired)" % [material, crack])
			else:
				for variant in range(VoxelBoardClass.IMPACT_DECAL_VARIANTS):
					var path: String = DECAL_NAME_TEMPLATE % [
						material, "crack", material, variant]
					if not FileAccess.file_exists(path):
						crack_offenders.append(path)
		elif VoxelBoardClass.IMPACT_CRACK_MATERIALS.has(material):
			dead_art.append("%s (crack_factor 0.0 but wired to crack)" % material)

		## ── DENT ─────────────────────────────────────────────────────────────
		if dent <= 0.0:
			continue
		var owns_family: bool = VoxelBoardClass.IMPACT_DECAL_MATERIALS.has(material) \
			or material == VoxelBoardClass.IMPACT_FLOOR_MATERIAL
		if owns_family:
			for variant in range(VoxelBoardClass.IMPACT_DECAL_VARIANTS):
				var path: String = DECAL_NAME_TEMPLATE % [
					material, "dent", material, variant]
				if not FileAccess.file_exists(path):
					dent_offenders.append(path)
		else:
			generic_dent.append("%s %.2f" % [material, dent])
			for variant in range(GENERIC_MARK_VARIANT_COUNT):
				var g: String = GENERIC_MARK_TEMPLATE % ["blast_dent", variant]
				if not FileAccess.file_exists(g):
					dent_offenders.append(g)

	if crack_offenders.is_empty():
		_pass("%d material(s) can crack and every one is wired with all %d variants on disk: %s" % [
			cracking.size(), VoxelBoardClass.IMPACT_DECAL_VARIANTS, ", ".join(cracking)])
	else:
		_fail("%d crack promise(s) the renderer cannot keep: %s"
			% [crack_offenders.size(), ", ".join(crack_offenders.slice(0, 5))])

	if dead_art.is_empty():
		_pass("no material is wired to a tier its own factor says it can never reach")
	else:
		_fail("%d dead wiring: %s" % [dead_art.size(), ", ".join(dead_art)])

	if dent_offenders.is_empty():
		_pass("every denting material resolves to real art — %d own a family, %d fall to the generic mark (%s)" % [
			ids.size() - generic_dent.size(), generic_dent.size(), ", ".join(generic_dent)])
	else:
		_fail("%d dent promise(s) the renderer cannot keep: %s"
			% [dent_offenders.size(), ", ".join(dent_offenders.slice(0, 5))])

	print("")


## The same walk MaterialResistanceTable._scan_dir() does — a directory whose
## name matches its own <id>.json. Mirrored rather than imported because the
## table keeps its parsed rows private, and because a test that enumerated from
## a list in this file would only ever check the materials someone remembered.
func _declared_material_ids() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(MaterialResistanceTable.RES_MATERIALS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var row := MaterialResistanceTable.RES_MATERIALS_DIR.path_join(entry).path_join(entry + ".json")
			if FileAccess.file_exists(row):
				out.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
