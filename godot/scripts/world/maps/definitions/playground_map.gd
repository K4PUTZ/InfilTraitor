class_name PlaygroundMap
extends RefCounted
## GEOMETRY TEST — 8×8 room with 1×1 central test cell surrounded by wall edges.
##
## Purpose: Minimal geometry validation for wall-floor junction alignment and corner gap fill.
## Uses a minimal outer perimeter + 4 divider walls on the edges of the central test cell.
## Walls use edge-based placement, exercising the straddle/nudge principle.
##
## Map: 8×8 inner playable area.
## Test cell: (4, 4) — the center (accessible from 4 sides).
## Wall cells: (4,3), (5,4), (4,5), (3,4) — one on each cardinal edge of the test cell.
##
## NOTE: Dividers place block_SE tiles which render walls via subcube geometry.
## The block geometry will sit on edges via the subcube descriptor system.


static func spec() -> Dictionary:
	return {
		"id":           "PLAYGROUND",
		"inner_size":   Vector2i(8, 8),
		"buffer":       1,
		"floor_tile":   "floor_SE",
		"wall_height":  2,
		"agent_start":  Vector2i(4, 4),
		"access_points": [
			{"cell": Vector2i(4, 0)},  # top access
			{"cell": Vector2i(4, 7)},  # bottom access
			{"cell": Vector2i(0, 4)},  # left access
			{"cell": Vector2i(7, 4)},  # right access
		],
		## Four walls surrounding the center cell (4, 4).
		## Placing blocks on the 4 cardinal neighbors creates wall faces on shared edges.
		"dividers": [
			{"cells": [
				Vector2i(4, 3),  ## North wall (north of center)
				Vector2i(5, 4),  ## East wall (east of center)
				Vector2i(4, 5),  ## South wall (south of center)
				Vector2i(3, 4),  ## West wall (west of center)
			]},
		],
	}
