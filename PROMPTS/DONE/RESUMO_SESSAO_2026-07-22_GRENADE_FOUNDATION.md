# RESUMO_SESSAO — 2026-07-22 (ALPHA GRENADE FOUNDATION, SESSION CLOSE)

**Active master plan:** `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` — Part
3 ("the trigger") landed this session, plan **⏸️ PAUSED again** at close
(Director's call: lighting is the next real blocker, not more destruction
mechanics — see Part 3's own status block for why).
**VERSION at session start:** 0.9.66
**VERSION at session end:** 0.9.67
**Mode:** Solo mode.
**Screenshot session:** not toggled; all captures via direct off-screen
`INFILTRAITOR_AUTO_SCREENSHOT=1`/`INFILTRAITOR_CAPTURE_ACTION=...` runs.

---

## Executive Summary

Two halves. First, four concrete bugs reported against the 0.9.66
TEST-ZONE/grenade-context-menu work (default map, floor grid, context-menu
background box, Escape hierarchy) — all root-caused from real code reading,
not guessed, and each fix verified with a real capture or a real input-event
replay, not code-reading alone. Second, the actual destruction trigger
(`DESTRUCTION_MASTER_PLAN` Part 3) — preceded by a Director-requested web
research pass on how other engines/games handle blast-radius destruction
(Minecraft, XCOM 2, Teardown, Rainbow Six Siege), then a formal plan-mode
design pass, then implementation, then real-map verification. Session closed
on the Director's own call once the mechanism was proven correct at the
data/engine level: lighting (every voxel renders fully lit regardless of
damage) is now the real blocker to *seeing* what destruction already does,
not any remaining destruction logic.

## Wave table

| ID | What | Status |
|---|---|---|
| PLAYGROUND-DEFAULT-01 | `room.gd`'s `@export var map_id` default restored `TEXTURES` → `PLAYGROUND` (the destruction test zone) | ✅ |
| GU-GRID-01 | Floor GU-boundary grid, lost when earth-voxel Slab floor started painting over the legacy floor art's baked-in grid. First attempt reused `VoxelRulerOverlay`'s (F3) per-voxel line family filtered to boundary-only — visibly failed (lines crossed mid-cell instead of closing). Redone with `selection_overlay.gd`'s proven 4-point diamond math instead; new file `gu_grid_overlay.gd`, black, always-on, z=1 | ✅ |
| CTXMENU-BOX-01 | `DetonateContextMenu`'s black 85%-opacity background wasn't rendering — root cause: `Panel` (not a `Container`) + `reset_size()` always resolves to (0,0), since only `Container` subtypes auto-fit to children. Swapped to `PanelContainer` (same pattern `$HUD/TopBar` already uses) | ✅ |
| ESC-STACK-01 | Escape always opened the Main Menu instead of cancelling the grenade context menu — `InputController._input()` (runs before `room._unhandled_input()`) handled `ui_pause` unconditionally. New `ModalStack` (`godot/scripts/ui/modal_stack.gd`): any modal pushes on open, pops on close; Escape always targets the top. Generalizes past the 2-level case — Main Menu → Controls nests the same way. Fixed a real dormant bug in passing: `WindowBase.request_close()` only emitted a signal nothing listened to; "New Game" and "Back" didn't actually close their panels | ✅ |
| DESTRUCTION-PART3-01 | The grenade trigger itself — see `DESTRUCTION_MASTER_PLAN.md` Part 3's own status block for full detail | ✅ (foundation) |

## Decisions (Director-ratified)

1. **Bugs before features.** All four fixes above landed and were verified
   before any destruction-physics code was written, per explicit Director
   ordering.
2. **Research real precedent before designing new mechanics** (explicit
   Director ask, same instinct as the 2026-07-21 occlusion-wireframe
   session): Minecraft's ray/resistance model, XCOM 2's ring-based
   percentage falloff, Teardown's per-material toughness tiers, and Rainbow
   Six Siege's soft/reinforced wall classes were compared before writing
   `BlastCalculator` — see `DESTRUCTION_MASTER_PLAN.md` Part 3 for which
   pieces of each were actually borrowed.
3. **GU-based ring falloff, not exact distance** — ring 0 (source GU) max
   damage, decreasing per ring, bomb-type-defined range/table.
4. **Walls block/reduce propagation** — chosen explicitly over "ignore
   walls, distance only," reusing `movement_overlay.gd`'s existing
   blocked-edge gate rather than inventing partial-transmission machinery.
5. **Wireframe preview shows only the outer perimeter** of the max-range
   footprint, not per-ring opacity — chosen explicitly over the denser
   alternative.
6. **Deterministic (FNV-1a hash-and-rank) voxel selection, no RNG** —
   mirrors the existing `EarthVariantSelector` precedent exactly.
7. **Metal maps to the existing (previously 100%-inert) `DamageState.
   CRACKED`**, not a new enum value — "pode ser distorcido," not destroyed.
8. **Fire/smoke explicitly deferred** to a later session — "por enquanto
   fica só a explosão."
9. **Session closed on lighting, not on destruction being "finished."**
   Cover rule, noise-on-digging, rubble-as-terrain and breach-as-clue (Part
   3's own original scope) remain open — deferred, not forgotten. Next
   destruction session should not resume until lighting can sell the damage
   visually; building more mechanics on an invisible effect was the
   Director's named reason to stop here.

## Evidence

- `project_lint.py`: 143 files, 0 real errors (every stage this session).
- Full regression, unchanged: `slab_geometry_selftest.gd` 15/15,
  `roof_slab_selftest.gd` 15/15, `slab_render_selftest.gd` 8/8,
  `earth_variant_selftest.gd` 6/6, `floor_integration_selftest.gd` 9/9,
  `roof_integration_selftest.gd` 5/5, `negative_storey_selftest.gd` 12/12,
  `fixed_floor_selftest.gd` 5/5, `bake_selftest.gd` 19/19.
- New: `blast_calculator_selftest.gd`, 11/11 PASS.
- Real captures: `Screenshots/history/auto_2026-07-22_19-21-21.png` (grid +
  context-menu box fixed), `auto_2026-07-22_19-22-11.png` /
  `auto_2026-07-22_19-22-54.png` (Escape targets context menu, then falls
  back to Main Menu correctly when nothing else is open),
  `auto_2026-07-22_19-52-09.png` (GU grid redone, clean diamonds),
  `auto_2026-07-22_21-51-42.png` (blast wireframe on menu-open).
- Real-map destruction proof: `TileMapLayer.get_cell_source_id()` read back
  as `-1` (erased) on 18 real destroyed voxels across 18 real `Slice`s from
  an actual PLAYGROUND detonation, with damage counts matching the ring
  falloff exactly (33/128 ring 1, 14/128 ring 2, 3/128 ring 3). No
  screenshot conclusively *shows* a crater yet — flagged honestly as an open
  item in `DESTRUCTION_MASTER_PLAN.md`, not glossed over.

## Next session

Lighting/shading on damaged voxels, so destruction is visible, is the named
prerequisite before any further `DESTRUCTION_MASTER_PLAN` work (cover rule,
noise, rubble, breach-as-clue, blast-number tuning, fire/smoke).
