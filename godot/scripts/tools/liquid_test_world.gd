## LiquidTestWorld (2026-10-19) — the synthetic voxel worlds the liquid selftests build their bodies in, now that a body takes its shape from the world
## (`FluidContainer`) instead of a typed rectangle. Laid out as the game lays a map: the floor slabs at levels 78-79 (the floor top is 80), a pit dug `dig`
## levels with its bed at 79 - dig, a one-voxel divider from the bed to the floor top, a RAISED pipe standing on the floor (its bore's bottom 2 over the floor
## top, its roof 12 over that), a grating's bars. Positions in GU, the world's raw grid (no buffer: a selftest's own coordinates).
extends RefCounted

const ContainerClass = preload("res://godot/scripts/systems/fluid_container.gd")

var solid: Dictionary = {}     ## Vector3i (x, y, level) -> true


func is_solid(x: int, y: int, level: int) -> bool:
	return solid.has(Vector3i(x, y, level))


## The floor slabs over `box` (GU), with every `pits` rect (GU) dug `dig` levels.
func lay(box: Rect2i, pits: Array, dig: int = 4) -> void:
	solid.clear()
	for x in range(box.position.x * 8, box.end.x * 8):
		for y in range(box.position.y * 8, box.end.y * 8):
			var in_pit: bool = false
			for pit: Rect2i in pits:
				if pit.has_point(Vector2i(x >> 3, y >> 3)):
					in_pit = true
			if in_pit:
				solid[Vector3i(x, y, 79 - dig)] = true
			else:
				solid[Vector3i(x, y, 78)] = true
				solid[Vector3i(x, y, 79)] = true


## A one-voxel wall along y at voxel column `x`, over GU rows [y0, y1), from the bed (76) to the floor top.
func divider(x: int, y0: int, y1: int) -> void:
	for y in range(y0 * 8, y1 * 8):
		for lv in range(76, 80):
			solid[Vector3i(x, y, lv)] = true


## A raised pipe along y over GU columns [x0, x0 + 2) and rows [y0, y1): its axis 8 voxels over the floor, radius 8, bore 6; PLUGGED at its back (the first
## two voxel rows, as PIPE_LAB's pipes are), its mouth at y1.
func raised_pipe(x0: int, y0: int, y1: int) -> void:
	var axis: float = float(x0 * 8 + 8)
	for x in range(x0 * 8, x0 * 8 + 16):
		for y in range(y0 * 8, y1 * 8):
			var v: float = absf(float(x) + 0.5 - axis)
			if v > 6.0:
				for lv in range(80, 96):
					solid[Vector3i(x, y, lv)] = true
			elif y < y0 * 8 + 2:
				for lv in range(80, 96):   ## the plug
					solid[Vector3i(x, y, lv)] = true
			else:
				for lv in range(80, 82):
					solid[Vector3i(x, y, lv)] = true
				solid[Vector3i(x, y, 94)] = true


## A grating's bars: every other voxel column across GU [x0, x1) in voxel row `y`, from the bed to the floor top.
func bars(x0: int, x1: int, y: int) -> void:
	for x in range(x0 * 8, x1 * 8, 2):
		for lv in range(76, 80):
			solid[Vector3i(x, y, lv)] = true


## A body in this world: the flood from `seed` (GU) under `brim_level`, its plane with `fluid`'s sources / sinks / fill. Returns {box, plane, info, rect}.
func body(seed: Vector2, fluidity: float, fluid: Dictionary = {}, brim_level: int = 80, cell: float = 0.5) -> Dictionary:
	var box = ContainerClass.new()
	box.setup(Callable(self, "is_solid"), 70, 110)
	box.flood(Vector2i(floori(seed.x * 8.0), floori(seed.y * 8.0)), brim_level)
	var info: Dictionary = {}
	var plane = box.build_plane(cell, fluidity, brim_level, info)
	if plane == null:
		return {}
	plane.dig = float(80 - int(info["base"]))
	plane.add_inputs(fluid)
	return {"box": box, "plane": plane, "info": info, "rect": info["rect"], "brim": brim_level}
