class_name PlaygroundMap
extends RefCounted
## PLAYGROUND — the reference artwork mockup.
##
## A hand-authored "default" level whose only job is to exercise EVERY artwork case so
## the director can verify the tiles behave before any procedural generation exists.
## Authored in PLAYABLE / INNER coordinates (18×36); MapCompiler applies the buffer.
##
## Artwork coverage:
##   • Outer room  → all 4 wall corners (NW/NE/SW/SE) + 4 straight edges automatically.
##   • Doors       → one on each of the 4 sides (doorOpen_NW/SE/SW/NE).
##   • Divider     → block_SE internal wall with two gate gaps.
##   • Crates      → 4 orientations as stacks 1/2/3/4 (south cluster) — height-graded shadows.
##   • Columns     → all 4 orientations in a row (north cluster) — the "pillar" artwork.
##   • Lights      → north + south sources so the prop clusters cast shadow/penumbra.
##   • Guards      → one patrol each side of the divider, lit lanes.
##
## Coordinates are tunable by the director; only the structure is fixed.


static func spec() -> Dictionary:
	return {
		"id":            "PLAYGROUND",
		"inner_size":    Vector2i(18, 36),
		"buffer":        5,
		"floor_tile":    "floor_SE",
		"wall_height":   2,                   ## external perimeter is double-height (second storey)
		"ceiling_floors": 3,                  ## ceiling lamp / temporal knob hang at 3 storeys (independent of walls)
		"agent_start":   Vector2i(9, 33),
		## One door per side — exercises every doorOpen_* variant.
		"access_points": [
			{"cell": Vector2i(9, 0)},    ## NW (top)
			{"cell": Vector2i(9, 35)},   ## SE (bottom)
			{"cell": Vector2i(0, 17)},   ## SW (left)
			{"cell": Vector2i(17, 17)},  ## NE (right)
		],
		"dividers": [
			## Mid divider at y=18 — gates at x=4-5 and x=12-13.
			{"cells": [
				Vector2i(1, 18), Vector2i(2, 18), Vector2i(3, 18),
				Vector2i(6, 18), Vector2i(7, 18), Vector2i(8, 18),
				Vector2i(9, 18), Vector2i(10, 18), Vector2i(11, 18),
				Vector2i(14, 18), Vector2i(15, 18), Vector2i(16, 18),
			]},
		],
		"props": [
			## North cluster — all 4 block orientations (pillars).
			{"cell": Vector2i(4, 7),  "tile": "block_SE"},
			{"cell": Vector2i(6, 7),  "tile": "block_SW"},
			{"cell": Vector2i(8, 7),  "tile": "block_NW"},
			{"cell": Vector2i(10, 7), "tile": "block_NE"},
			## South cluster — crate stacks 1/2/3/4 to exercise height-graded shadows.
			## `stack` N renders N crate sprites and casts a taller (longer) real shadow.
			{"cell": Vector2i(4, 30),  "tile": "crate_SE", "stack": 1},
			{"cell": Vector2i(6, 30),  "tile": "crate_SW", "stack": 2},
			{"cell": Vector2i(8, 30),  "tile": "crate_NW", "stack": 3},
			{"cell": Vector2i(10, 30), "tile": "crate_NE", "stack": 4},
		],
		## Central vertical rail — lights snap to slots for uniform shadows.
		"light_tracks": [
			{"id": "central", "cells": [Vector2i(9, 6), Vector2i(9, 17), Vector2i(9, 29)]},
		],
		"lights": [
			{"track": "central", "slot": 0, "height": 5.0, "radius": 8, "intensity": 0.90},  ## north
			{"track": "central", "slot": 2, "height": 5.0, "radius": 8, "intensity": 0.90},  ## south
			## Special (free): a cone spot over the north columns, pointing south into
			## the room — demonstrates directional shadows + perspective angle rotation.
			{"x": 9, "y": 9, "type": "cone", "direction_deg": 90, "cone_deg": 80,
			 "height_class": 3, "radius": 7, "intensity": 0.85},
		],
		"patrols": [
			## North room — E-W
			[Vector2i(2, 10), Vector2i(15, 10)],
			## South room — E-W
			[Vector2i(2, 26), Vector2i(15, 26)],
		],
	}
