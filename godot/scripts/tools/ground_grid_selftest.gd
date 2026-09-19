## GroundGrid selftest — RENDER3D R3D-5a.
## Run: python3 tools/persistent/run_selftests.py --only ground_grid_selftest
##
## The claim: `GroundGrid` IS the lattice the floor TileMapLayer gives, so replacing the layer's
## `map_to_local()` with it in input and in every actor's placement changes nothing. Asserted against a
## real TileMapLayer on the game's own TileSet — not against the formula's own output — for a range of
## cells (negative ones included) and for random points, including the exact algorithm `Room` uses to
## pick a tile under a click (`_screen_to_tile`).

extends SceneTree

const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")
const TILESET_PATH := "res://godot/resources/tilesets/tileset_blocks.tres"
const OFFSET := Vector2(-37.0, 21.0)  ## any offset: the room's VISUAL_GRID_OFFSET must not matter

var passed: int = 0
var failed: int = 0
var _layer: TileMapLayer = null


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GROUND-GRID — the cell lattice, against the real tilemap SELFTEST")
	print("=".repeat(70) + "\n")
	_layer = TileMapLayer.new()
	_layer.tile_set = load(TILESET_PATH)
	root.add_child(_layer)
	test_map_to_local_matches_the_tilemap()
	test_cell_containing_matches_the_room_pick()
	test_cell_center_round_trips()
	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	quit(0 if failed == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  ✓ PASS: ", msg)
	else:
		failed += 1
		print("  ✗ FAIL: ", msg)


func test_map_to_local_matches_the_tilemap() -> void:
	print("[1] map_to_local equals the TileMapLayer's, cell for cell")
	var bad: int = 0
	var n: int = 0
	for x: int in range(-30, 80):
		for y: int in range(-30, 80):
			n += 1
			if GroundGridRef.map_to_local(Vector2i(x, y)) != _layer.map_to_local(Vector2i(x, y)):
				bad += 1
	_check(bad == 0, "%d of %d cells differ" % [bad, n])


## The algorithm `Room._screen_to_tile` runs, verbatim, against the real layer — the reference the new
## lattice must reproduce. Returns INVALID (-9999, -9999) as the room does.
func _room_pick(lp: Vector2) -> Vector2i:
	var logical_lp: Vector2 = lp - OFFSET
	var seed_cell: Vector2i = _layer.local_to_map(logical_lp)
	var best := seed_cell
	var best_dist: float = INF
	var found: bool = false
	for dc: int in [-1, 0, 1]:
		for dr: int in [-1, 0, 1]:
			var c: Vector2i = seed_cell + Vector2i(dc, dr)
			var center: Vector2 = _layer.map_to_local(c) + Vector2(0.0, 64.0) + OFFSET
			var d: Vector2 = lp - center
			var dist: float = absf(d.x) / 128.0 + absf(d.y) / 64.0
			if dist <= 1.0 and dist < best_dist:
				best_dist = dist
				best = c
				found = true
	return best if found else Vector2i(-9999, -9999)


func test_cell_containing_matches_the_room_pick() -> void:
	print("[2] cell_containing agrees with the room's own tile pick on random points")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260918
	var bad: int = 0
	var ties: int = 0
	var n: int = 20000
	for i: int in range(n):
		var p := Vector2(rng.randf_range(-3000.0, 6000.0), rng.randf_range(-2000.0, 5000.0))
		var want: Vector2i = _room_pick(p)
		var got: Vector2i = GroundGridRef.cell_containing_with_offset(p - Vector2.ZERO, OFFSET)
		if want != got:
			## An exact shared edge is decided by a tie-break; count it apart from a real disagreement.
			var d: Vector2 = p - GroundGridRef.cell_center(want, OFFSET)
			if absf(absf(d.x) / 128.0 + absf(d.y) / 64.0 - 1.0) < 1e-6:
				ties += 1
			else:
				bad += 1
	_check(bad == 0, "%d of %d random points pick a different cell (%d exact-edge ties set aside)" % [bad, n, ties])


func test_cell_center_round_trips() -> void:
	print("[3] every cell's centre resolves back to that cell")
	var bad: int = 0
	for x: int in range(-20, 60):
		for y: int in range(-20, 60):
			var c := Vector2i(x, y)
			if GroundGridRef.cell_containing_with_offset(GroundGridRef.cell_center(c, OFFSET), OFFSET) != c:
				bad += 1
	_check(bad == 0, "%d cell centres do not round-trip" % bad)
