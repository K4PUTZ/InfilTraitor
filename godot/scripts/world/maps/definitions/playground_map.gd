class_name PlaygroundMap
extends RefCounted
## CALIBRATION MAP — 1 interior floor tile, 1-storey outer wall on all 4 sides.
## inner_size (3,3): outer_rect perimeter = 8 wall cells (4 corners + 4 straight),
## single floor tile at raw (2,2). All 4 face directions (NW/NE/SE/SW) are exercised.
## Total raw grid: 5×5 (inner 3×3 + buffer 1 per edge).


static func spec() -> Dictionary:
	return {
		"id":           "PLAYGROUND",
		"inner_size":   Vector2i(3, 3),
		"buffer":       1,
		"floor_tile":   "floor_SE",
		"wall_height":  1,
		"agent_start":  Vector2i(1, 1),
		"access_points": [],
	}
