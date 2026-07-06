class_name Sigma01Map
extends RefCounted
## MAP SIGMA-01 — systematic test map, migrated to the data-driven MapSpec format.
##
## Authored entirely in PLAYABLE / INNER coordinates (18×36). MapCompiler applies the
## 5-tile buffer offset, so there is NO "+5" math here. This is a faithful port of the
## old room_layout_builder.gd hardcoded layout — same walls, dividers, crates, lights
## and patrols, just expressed without the buffer baked in.
##
## Zones (inner Y):
##   Zone C  y=0..8    · divider A at y=9   (gates x=4-5, x=12-13)
##   Zone B  y=10..24  · divider B at y=25  (gates x=2-3, x=14-15)
##   Zone A  y=26..29  · divider C at y=30  (single gate x=8-9)
##   Zone 0  y=31..35  (start area)


static func spec() -> Dictionary:
	return {
		"id":            "SIGMA_01",
		"inner_size":    Vector2i(18, 36),
		"buffer":        5,
		"floor_tile":    "floor_SE",
		"agent_start":   Vector2i(9, 34),
		"access_points": [
			{"cell": Vector2i(9, 35)},   ## south exit (SE border)
			{"cell": Vector2i(9, 0)},    ## north exit (NW border)
		],
		"dividers": [
			## Divider C — Zone A ↔ Zone 0 (single central gate x=8-9)
			{"material": "concrete", "cells": [
				Vector2i(1, 30), Vector2i(2, 30), Vector2i(3, 30), Vector2i(4, 30),
				Vector2i(5, 30), Vector2i(6, 30), Vector2i(7, 30),
				Vector2i(10, 30), Vector2i(11, 30), Vector2i(12, 30), Vector2i(13, 30),
				Vector2i(14, 30), Vector2i(15, 30), Vector2i(16, 30),
			]},
			## Divider B — Zone B ↔ Zone A (gates x=2-3, x=14-15; no central passage)
			{"material": "concrete", "cells": [
				Vector2i(1, 25),
				Vector2i(4, 25), Vector2i(5, 25), Vector2i(6, 25), Vector2i(7, 25),
				Vector2i(8, 25), Vector2i(9, 25), Vector2i(10, 25), Vector2i(11, 25),
				Vector2i(12, 25), Vector2i(13, 25),
				Vector2i(16, 25),
			]},
			## Divider A — Zone C ↔ Zone B (gates x=4-5, x=12-13)
			{"material": "concrete", "cells": [
				Vector2i(1, 9), Vector2i(2, 9), Vector2i(3, 9),
				Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9),
				Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9),
				Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9),
			]},
		],
		"props": [
			## Zone 0 — initial cover
			{"cell": Vector2i(3, 32),  "tile": "crate_SE"},
			{"cell": Vector2i(14, 32), "tile": "crate_SW"},
			## Zone B — central crates
			{"cell": Vector2i(7, 21),  "tile": "crate_NW"},
			{"cell": Vector2i(10, 21), "tile": "crate_NE"},
			## Zone B — warehouse (right shadow zone)
			{"cell": Vector2i(15, 13), "tile": "crate_SE"},
			{"cell": Vector2i(16, 13), "tile": "crate_SW"},
			{"cell": Vector2i(15, 14), "tile": "crate_NW"},
			## Zone B — pillars
			{"cell": Vector2i(5, 17),  "tile": "crate_NE"},
			{"cell": Vector2i(13, 17), "tile": "crate_SE"},
		],
		"lights": [
			{"x": 9, "y": 5,  "height": 5.0, "radius": 8, "intensity": 0.90},  ## Zone C
			{"x": 9, "y": 17, "height": 5.0, "radius": 7, "intensity": 0.85},  ## Zone B
			{"x": 9, "y": 28, "height": 5.0, "radius": 6, "intensity": 0.85},  ## Zone A
		],
		"patrols": [
			## ALPHA (α) — Zone A, lit corridor, E-W
			[Vector2i(2, 28), Vector2i(15, 28)],
			## BRAVO (β) — Zone B lit center, rectangular
			[Vector2i(4, 11), Vector2i(13, 11), Vector2i(13, 22), Vector2i(4, 22)],
			## CHARLIE (γ) — Zone B left shadow, short N-S
			[Vector2i(2, 14), Vector2i(2, 18)],
			## DELTA (δ) — Zone C upper room, E-W
			[Vector2i(2, 5), Vector2i(15, 5)],
		],
	}
