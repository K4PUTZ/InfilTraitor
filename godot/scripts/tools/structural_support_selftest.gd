## Selftest — StructuralSupport (ROOF_MASTER_PLAN R-D12, G1): what has no support is found, what is held is not. Synthetic fixtures answer the RULE (a post, a stump,
## a bridge, a hanging chain, the order of a cascade); the REAL case (the post the blast on ROOF_LAB leaves) is the `roof_post` take's `[STRUCT]` line.
extends SceneTree

const GROUND: int = 80

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("StructuralSupport SELFTEST")
	print("=".repeat(70) + "\n")
	_rule()
	_overlay()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(ok: bool, m: String) -> void:
	if ok:
		passed += 1
		print("  ✓ " + m)
	else:
		failed += 1
		print("  ✗ " + m)


func _put(grid: ClaimGrid, cells: Array) -> void:
	for c: Vector3i in cells:
		grid.put(c, Voxel.new(Vector2i(c.x, c.y), c.z, null))


func _column(x: int, y: int, from_level: int, to_level: int) -> Array:
	var out: Array = []
	for level in range(from_level, to_level + 1):
		out.append(Vector3i(x, y, level))
	return out


func _rule() -> void:
	## A post of 16 voxels standing on the ground plane: held.
	var grid := ClaimGrid.empty()
	var post: Array = _column(5, 5, GROUND, GROUND + 15)
	_put(grid, post)
	_check(StructuralSupport.unsupported(grid, GROUND, post, {}).is_empty(), "a post standing on the ground plane is held (0 of 16 loose)")
	## The same post with its foot gone: a 15-voxel chain with no end at the ground: all loose.
	grid = ClaimGrid.empty()
	var floating: Array = _column(5, 5, GROUND + 1, GROUND + 15)
	_put(grid, floating)
	var loose: Dictionary = StructuralSupport.unsupported(grid, GROUND, floating, {Vector3i(5, 5, GROUND): true})
	_check(loose.size() == 15, "a post whose foot a blast took: all 15 voxels have no support (%d)" % loose.size())
	## The case the Director saw: a post cut in two places, a lone voxel and a 3-voxel stump hanging in the air, the rest gone.
	grid = ClaimGrid.empty()
	var stump: Array = [Vector3i(5, 5, GROUND + 7), Vector3i(5, 5, GROUND + 12), Vector3i(5, 5, GROUND + 13), Vector3i(5, 5, GROUND + 14)]
	_put(grid, stump)
	loose = StructuralSupport.unsupported(grid, GROUND, stump, {})
	_check(loose.size() == 4, "a lone voxel and a 3-voxel stump in the air: 4 of 4 loose (%d)" % loose.size())
	## Full glue: a bridge between two grounded walls holds, whatever it is made of; cut one end and it is still held by the other; cut both and it falls.
	grid = ClaimGrid.empty()
	var left: Array = _column(0, 0, GROUND, GROUND + 7)
	var right: Array = _column(6, 0, GROUND, GROUND + 7)
	var bridge: Array = []
	for x in range(1, 6):
		bridge.append(Vector3i(x, 0, GROUND + 7))
	_put(grid, left)
	_put(grid, right)
	_put(grid, bridge)
	_check(StructuralSupport.unsupported(grid, GROUND, bridge, {}).is_empty(), "a bridge between two grounded walls is held")
	grid = ClaimGrid.empty()
	_put(grid, left)
	_put(grid, bridge)
	_check(StructuralSupport.unsupported(grid, GROUND, bridge, {}).is_empty(), "cut one end and it is still held by the other (glue, no beam physics)")
	grid = ClaimGrid.empty()
	_put(grid, bridge)
	_check(StructuralSupport.unsupported(grid, GROUND, bridge, {}).size() == 5, "cut both ends: all 5 voxels loose")
	## The cascade: steps from the voxel that touches what broke (the foot), growing up the post.
	grid = ClaimGrid.empty()
	_put(grid, floating)
	loose = StructuralSupport.unsupported(grid, GROUND, floating, {Vector3i(5, 5, GROUND): true})
	_check(int(loose[Vector3i(5, 5, GROUND + 1)]) == 0 and int(loose[Vector3i(5, 5, GROUND + 15)]) == 14, "the cascade runs up the post: step 0 at the foot, 14 at the head (%d, %d)" % [int(loose[Vector3i(5, 5, GROUND + 1)]), int(loose[Vector3i(5, 5, GROUND + 15)])])


## RF-G G2: the roof islands ask the walk about the world a prediction leaves (`ClaimGrid.overlay`): a roof on two walls, one wall destroyed on the Delta, then both.
func _overlay() -> void:
	var grid := ClaimGrid.empty()
	var left: Array = _column(0, 0, GROUND, GROUND + 7)
	var right: Array = _column(6, 0, GROUND, GROUND + 7)
	var roof: Array = []
	for x in range(0, 7):
		roof.append(Vector3i(x, 0, GROUND + 8))
	_put(grid, left)
	_put(grid, right)
	_put(grid, roof)
	_check(StructuralSupport.unsupported(grid, GROUND, roof, {}).is_empty(), "a roof on two walls: held")
	grid.overlay[Vector3i(0, 0, GROUND + 3)] = Voxel.DamageState.DESTROYED
	_check(StructuralSupport.unsupported(grid, GROUND, roof, {}).is_empty(), "one wall cut on the prediction: the roof is still held by the other")
	grid.overlay[Vector3i(6, 0, GROUND + 3)] = Voxel.DamageState.DESTROYED
	_check(StructuralSupport.unsupported(grid, GROUND, roof, {}).size() == 7, "both walls cut on the prediction: the 7 roof voxels (they hold each other) have no support")
	_check(grid.damage_at(Vector3i(0, 0, GROUND + 3)) == Voxel.DamageState.DESTROYED and grid.damage_at(Vector3i(0, 0, GROUND + 2)) >= 0, "the overlay answers for its cells only")
