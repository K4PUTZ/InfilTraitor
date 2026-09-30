## Selftest — PropVoxelizer (PROPS_TIER4_PLAN P1): a model keeps its SHAPE when it becomes board voxels.
## Synthetic meshes only (a table built from boxes), so it runs on a clone without the local-only ASSETS.
extends SceneTree

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("PropVoxelizer SELFTEST")
	print("=".repeat(70) + "\n")
	_test_unit_cube()
	_test_table_keeps_top_and_legs()
	_test_zones_and_determinism()
	_test_box_fit_placeholder()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _pass(m: String) -> void:
	passed += 1
	print("  ✓ " + m)


func _fail(m: String) -> void:
	failed += 1
	print("  ✗ " + m)


func _box_part(size: Vector3, centre: Vector3) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	return {"mesh": mesh, "xf": Transform3D(Basis.IDENTITY, centre)}


## A voxel-sized cube sitting exactly on a cell is exactly one voxel (and does not bleed into its neighbours).
func _test_unit_cube() -> void:
	print("[1] a cube of one voxel, centred in a cell")
	var v: float = PropVoxelizer.voxel_size()
	var r: Dictionary = PropVoxelizer.voxelize([_box_part(Vector3.ONE * v * 0.9, Vector3(0.5 * v, 0.5 * v, 0.5 * v))])
	if r["cells"].size() == 1 and r["cells"][0] == Vector3i(0, 0, 0):
		_pass("one cell at (0,0,0)")
	else:
		_fail("expected exactly (0,0,0), got %s" % [r["cells"]])
	## A plate lying exactly on a level boundary must not mark the cell BELOW the floor.
	var plate: Dictionary = PropVoxelizer.voxelize([_box_part(Vector3(0.3, 0.02, 0.3), Vector3(0.0, 0.01, 0.0))])
	var below: bool = false
	for c: Vector3i in plate["cells"]:
		if c.y < 0:
			below = true
	if not below and plate["cells"].size() > 0:
		_pass("a plate on the floor marks no cell under it (%d cells)" % plate["cells"].size())
	else:
		_fail("a plate on the floor leaked below Y = 0 or marked nothing")
	print("")


## A table (a thin top on four thin legs): the voxels are the top and the legs, NOT a solid block, and the legs are four separate columns.
func _test_table_keeps_top_and_legs() -> void:
	print("[2] a table keeps its top plate and its four legs")
	var top_y: float = 0.68   ## a 0.03 plate inside one voxel layer (0.625-0.75)
	var parts: Array = [_box_part(Vector3(0.95, 0.03, 0.59), Vector3(0.0, top_y, 0.0))]
	for lx in [-0.42, 0.42]:
		for lz in [-0.24, 0.24]:
			parts.append(_box_part(Vector3(0.05, 0.6, 0.05), Vector3(lx, 0.3, lz)))
	var r: Dictionary = PropVoxelizer.voxelize(parts)
	var cells: Array = r["cells"]
	var v: float = PropVoxelizer.voxel_size()
	var top_layer: int = floori(top_y / v)
	var in_top: int = 0
	var below_top: Array = []
	var max_y: int = 0
	for c: Vector3i in cells:
		max_y = maxi(max_y, c.y)
		if c.y >= top_layer:
			in_top += 1
		else:
			below_top.append(c)
	var has_under_centre: bool = false
	for c: Vector3i in below_top:
		if c.x == 0 and c.z == 0:
			has_under_centre = true
	## Connected components (4-neighbourhood in X/Z across all layers below the top) = the legs.
	var xz: Dictionary = {}
	for c: Vector3i in below_top:
		xz[Vector2i(c.x, c.z)] = true
	var seen: Dictionary = {}
	var components: int = 0
	for k: Vector2i in xz:
		if seen.has(k):
			continue
		components += 1
		var queue: Array = [k]
		seen[k] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cur + d
				if xz.has(nb) and not seen.has(nb):
					seen[nb] = true
					queue.append(nb)
	var top_wide: bool = in_top >= 30   ## 0.95 x 0.59 GU is ~8 x 5 voxels
	if top_wide and components == 4 and not has_under_centre and max_y >= top_layer and max_y <= top_layer + 1:
		_pass("top layer %d voxels wide, 4 separate legs, hollow underneath (%d cells in all)" % [in_top, cells.size()])
	else:
		_fail("table shape wrong: top=%d components=%d under_centre=%s max_y=%d top_layer=%d total=%d"
			% [in_top, components, has_under_centre, max_y, top_layer, cells.size()])
	## Not a block: a solid 8 x 5 x 5 would be 200 voxels.
	if cells.size() < 120 and in_top <= 60:
		_pass("a shape, not the bounding box (%d cells, a solid block would be ~290)" % cells.size())
	else:
		_fail("%d cells looks like a solid block" % cells.size())
	print("")


## Zones follow the surface, the output is sorted, and the same model gives the same answer twice.
func _test_zones_and_determinism() -> void:
	print("[3] zones by surface, sorted output, determinism")
	var parts: Array = [_box_part(Vector3(0.4, 0.05, 0.4), Vector3(0.0, 0.5, 0.0)),
		_box_part(Vector3(0.06, 0.45, 0.06), Vector3(0.0, 0.225, 0.0))]
	var a: Dictionary = PropVoxelizer.voxelize(parts)
	var b: Dictionary = PropVoxelizer.voxelize(parts)
	var same: bool = a["cells"] == b["cells"] and a["zones"] == b["zones"]
	var zones_seen: Dictionary = {}
	for z in a["zones"]:
		zones_seen[int(z)] = true
	var sorted_ok: bool = true
	var prev := Vector3i(-1, -1, -1)
	for c: Vector3i in a["cells"]:
		if c.y < prev.y or (c.y == prev.y and (c.z < prev.z or (c.z == prev.z and c.x < prev.x))):
			sorted_ok = false
		prev = c
	if same and sorted_ok and zones_seen.size() == 2:
		_pass("deterministic, sorted (y, z, x), two parts give two zones")
	else:
		_fail("same=%s sorted=%s zones=%s" % [same, sorted_ok, zones_seen.keys()])
	print("")


## A prop with no model voxelizes from its box: the slot's generic is a box of fragments.
func _test_box_fit_placeholder() -> void:
	print("[4] the placeholder box")
	var r: Dictionary = PropVoxelizer.for_model("", Vector3.ZERO, Vector3(0.5, 0.25, 0.375))
	var maxx: int = -99
	var minx: int = 99
	var maxy: int = 0
	for c: Vector3i in r["cells"]:
		maxx = maxi(maxx, c.x)
		minx = mini(minx, c.x)
		maxy = maxi(maxy, c.y)
	## 0.5 wide = 4 voxels, 0.25 high = 2 voxels, 0.375 deep = 3 voxels; solid (a box's faces fill its volume only at this size).
	if r["cells"].size() > 0 and maxx - minx + 1 == 4 and maxy == 1:
		_pass("a 4 x 2 x 3 box: %d cells" % r["cells"].size())
	else:
		_fail("box voxelization wrong: %d cells, x %d..%d, top y %d" % [r["cells"].size(), minx, maxx, maxy])
	print("")
