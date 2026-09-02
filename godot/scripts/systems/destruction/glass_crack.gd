## GlassCrack — GLASS_MASTER_PLAN CRACK-01 (§8, G-D14 / G-D19 / G-D21 / G-D24).
##
## A round that lands on a pane and does NOT breach the voxel (a weak hit, or a
## rifle round whose shatter roll was lost) leaves the pane STANDING and crazes
## the glass around the hole. That is this file: given the pane, the hit and the
## weapon's hole width, it returns the still-standing glass cells to mark CRACKED
## and the anchor the web radiates from.
##
## PURE by construction — it takes slice lists, never the registry — so the shot
## path applies the result the way `agent_shot_controller` applies
## `GlassShatter.plan_pane_shatter()`, and the selftest hands it a synthetic
## frame (PREDICTION_MASTER_PLAN's rule for `build_plan()`).
##
## The RENDER is world-space (G-D21 amended 2026-09-02, §8.2): the caller writes a
## crack GROUP id into `VoxelRenderer`'s per-level crack plane for every cell here
## and one texel into the groups strip (`impact_run`, `impact_rel_level`,
## `run_axis`, `wide`). `glass_pane.gdshader` reanchors the fracture sheet onto
## the impact — a subtraction, no atom minted.
##
## G-D24 — a cell already carrying a DIFFERENT crack group, reached by this
## fracture, is not returned here: the caller DESTROYS it (crossed cracks drop
## the piece), and it falls through `GlassFall` like any other break.
class_name GlassCrack

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")

## G-D14 — the crack web's reach, per hole width, as (run, level) voxel radii.
## This is the set of voxels that enter the CRACKED state — so it is also where
## G-D19's flat 50% see-through applies, which is why it is kept LOCAL to the
## impact rather than run out to the sheet's own 32×16 edge: a rifle round crazes
## a wide patch, not the whole pane. The sheet texture still extends further; a
## cell just outside this radius simply is not cracked. `tight` falls short of
## `wide` on purpose (a pistol makes a small web). All `static var` — the
## Director tunes them on the GLASS map.
static var CRACK_RADIUS_TIGHT := Vector2i(6, 5)
static var CRACK_RADIUS_WIDE := Vector2i(12, 9)

## `WeaponDef.blowout` at or above this takes the WIDE sheet (rifle-class). The
## shipped arsenal: pistol/shotgun 0.0, assault rifle 0.65 — so the split is
## exactly pistol/pellet → tight, rifle → wide (G-D14).
static var WIDE_BLOWOUT_MIN: float = 0.5


static func wide_for_blowout(blowout: float) -> bool:
	return blowout >= WIDE_BLOWOUT_MIN


## Pure. `pane_slices` share one `pane_id`; `face` fixes the run axis (X for
## SW/NE, Y for SE/NW — the same rule GlassShatter uses). `hit_grid_pos` /
## `hit_level` are the struck voxel. Returns:
##   cells       Array[{level:int, cell:Vector2i}] — standing glass to mark CRACKED
##   run_axis    0 (run along X) or 1 (along Y)
##   impact_run  the struck voxel's coord along the run axis
##   hit_level   passed through, for the caller's rel-level conversion
##   wide        passed through, picks the sheet
static func plan_pane_crack(pane_slices: Array, face: int, hit_grid_pos: Vector2i,
		hit_level: int, wide: bool) -> Dictionary:
	var run_is_x: bool = (face == Face.SW or face == Face.NE)
	var impact_run: int = hit_grid_pos.x if run_is_x else hit_grid_pos.y
	var radius: Vector2i = CRACK_RADIUS_WIDE if wide else CRACK_RADIUS_TIGHT
	var cells: Array = []
	for s in pane_slices:
		var s_base: int = GeometryCoordsMod.storey_level_base(s.start_storey)
		for v in s.voxels:
			if v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			## A G-D9 banded pane keeps its brick sill/head in these same slices —
			## a fracture does not cross the frame.
			if not GlassMaterials.is_glass(s.material_at(v.level - s_base)):
				continue
			var run: int = v.grid_pos.x if run_is_x else v.grid_pos.y
			if absi(run - impact_run) > radius.x:
				continue
			if absi(v.level - hit_level) > radius.y:
				continue
			cells.append({"level": v.level, "cell": v.grid_pos})
	return {
		"cells": cells,
		"run_axis": 0 if run_is_x else 1,
		"impact_run": impact_run,
		"hit_level": hit_level,
		"wide": wide,
	}
