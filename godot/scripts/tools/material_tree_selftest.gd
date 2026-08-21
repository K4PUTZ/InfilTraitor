## ASSET_TREE_REFORM — the invariant the per-material tree makes possible.
## Rodar: python3 tools/persistent/run_selftests.py --only material_tree
##
## WHY THIS TEST EXISTS, stated as the bug it would have caught. Before
## 2026-08-21 a material's art was scattered across four flat directories, so
## "does concrete have everything it needs" could only be answered by grepping
## four folders and knowing which files each one owed. `glass` sat in
## `BASE_MATERIALS` and NOT in `BakeCompositor.VOXEL_MATERIALS` for months and
## nothing saw it, because no glass block had ever been placed — the moment one
## was, B6 fired with `voxel_glass.png` on disk the whole time.
##
## One folder per material turns that into a structural question, and this is the
## test that asks it:
##
##   1. every REGISTERED material has a folder;
##   2. every FOLDER is a registered material (no orphan art nothing can reach);
##   3. every material that claims `has_facade` has its facade file;
##   4. every material in `IMPACT_DECAL_MATERIALS` has a complete decal family.
##
## Deliberately reads the REAL tree and the REAL registry, not a fixture: the
## property under test is that the two agree on this machine, right now.

extends SceneTree

const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

const MATERIALS_ROOT := "res://ASSETS/materials"

## Not a material — the material-agnostic decal family (D25) lives here, and the
## leading underscore is what keeps it from ever colliding with a material id.
const GENERIC_DIR := "_generic"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("ASSET_TREE_REFORM — MATERIAL TREE SELFTEST")
	print("=".repeat(70) + "\n")

	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()
	var registered: Array = registry.list_materials()
	registered.sort()

	var folders: Array[String] = _material_folders()

	test_every_registered_material_has_a_folder(registered, folders)
	test_every_folder_is_a_registered_material(registered, folders)
	test_facade_materials_have_their_facade(registry, registered)
	test_decal_materials_have_a_complete_family()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ MATERIAL TREE SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ MATERIAL TREE SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## ⚠️ `FileAccess.file_exists()` ALONE, and never `ResourceLoader.exists()`.
##
## MEASURED 2026-08-21, after the first version of this test passed green with
## `facade_wood.png` deleted from disk:
##
##     present: ResourceLoader.exists=true   FileAccess.file_exists=true
##     ABSENT : ResourceLoader.exists=true   FileAccess.file_exists=false
##
## `ResourceLoader` answers from the COMPILED `.ctex` in `.godot/imported/`,
## which survives its source being deleted. So `ResourceLoader.exists(p) or
## FileAccess.file_exists(p)` — the obvious-looking belt-and-braces version — is
## strictly WEAKER than either alone: the lenient half always wins the `or`, and
## the test reports a file that is not there. This is check_facade.py's
## dest_files-vs-mtime lesson in a second costume: ask the question that
## actually matters, which here is "is the ART on disk".
func _source_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## Every subdirectory of the tree except the generic family.
func _material_folders() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(MATERIALS_ROOT)
	if dir == null:
		_fail("cannot open %s — the material tree does not exist" % MATERIALS_ROOT)
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with(".") and entry != GENERIC_DIR:
			out.append(entry)
		entry = dir.get_next()
	out.sort()
	return out


## ⚠️ THE WEAK DIRECTION, and it is labelled rather than quietly counted. Since
## the reform, `MaterialRegistry` DERIVES its roster by walking this same tree,
## so on the res:// tier alone this check is close to a tautology — deleting a
## folder deletes the registration with it, and both sides agree by construction
## (measured: hiding `wood/` entirely left this green).
##
## It is kept because it is NOT tautological on the tier that matters for the
## future: `user://materials/<id>/<id>.json` registers a material with no res://
## folder, which is exactly the downloadable-pack case the reform exists to
## enable. The check that carries real weight today is the OPPOSITE direction
## below, which fires on a folder whose row is missing or unparseable.
func test_every_registered_material_has_a_folder(registered: Array, folders: Array[String]) -> void:
	print("TEST: every registered material has a folder in the tree (weak direction — see note)")
	var missing: Array[String] = []
	for material in registered:
		if not folders.has(String(material)):
			missing.append(String(material))
	if missing.is_empty():
		_pass("%d registered material(s), all present as folders" % registered.size())
	else:
		_fail("registered but with NO folder: %s — their art cannot be found at all"
			% ", ".join(missing))
	print("")


func test_every_folder_is_a_registered_material(registered: Array, folders: Array[String]) -> void:
	print("TEST: every folder is a registered material — no orphan art")
	## The other direction, and it is the one that would have caught glass: art
	## on disk that nothing can reach because the id was never registered renders
	## as the generic fallback and reports nothing.
	var orphans: Array[String] = []
	for folder in folders:
		if not registered.has(folder):
			orphans.append(folder)
	if orphans.is_empty():
		_pass("%d folder(s), every one a registered material" % folders.size())
	else:
		_fail("folders with NO registration: %s — art nothing can resolve" % ", ".join(orphans))
	print("")


func test_facade_materials_have_their_facade(registry, registered: Array) -> void:
	print("TEST: a material that claims has_facade has its facade file")
	var missing: Array[String] = []
	var checked := 0
	for material in registered:
		var def = registry.get_material(String(material))
		if def == null or not def.has_facade:
			continue
		checked += 1
		var path := "%s/%s/facade_%s.png" % [MATERIALS_ROOT, material, material]
		if not _source_exists(path):
			missing.append(String(material))
	if missing.is_empty():
		_pass("%d material(s) claim has_facade, all %d files present" % [checked, checked])
	else:
		_fail("has_facade with no facade on disk: %s — TextureResolver returns Tier.NONE "
			% ", ".join(missing) + "and the surface renders silently wrong")
	print("")


func test_decal_materials_have_a_complete_family() -> void:
	print("TEST: every material wired for decals has a COMPLETE family")
	## The runtime hashes a voxel's coordinates into 0..IMPACT_DECAL_VARIANTS-1
	## and loads whichever it lands on, so a gap is a boot-time B6 error rather
	## than a fallback. This is the same property check_decal.py asserts from the
	## outside; having it in the suite means it runs on every commit.
	var broken: Array[String] = []
	var checked := 0
	for material in VoxelRendererClass.IMPACT_DECAL_MATERIALS:
		for family in ["bullet", "dent", "crack"]:
			var present := 0
			for i in range(VoxelRendererClass.IMPACT_DECAL_VARIANTS):
				var path := "%s/%s/decals/decal_%s_%s_%d.png" % [
					MATERIALS_ROOT, material, family, material, i]
				if _source_exists(path):
					present += 1
			## A family a material does not claim at all is fine — D32.6 says
			## metal and wood never crack. A PARTIAL family is not.
			if present == 0:
				continue
			checked += 1
			if present != VoxelRendererClass.IMPACT_DECAL_VARIANTS:
				broken.append("%s/%s (%d of %d)" % [material, family, present,
					VoxelRendererClass.IMPACT_DECAL_VARIANTS])
	if broken.is_empty():
		_pass("%d claimed decal family/families, every one complete" % checked)
	else:
		_fail("incomplete decal families: %s" % ", ".join(broken))
	print("")
