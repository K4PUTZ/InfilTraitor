# Refactoring Sprint 04 — Completion Report

**Date:** June 5, 2026  
**Status:** ✅ Complete — All 4 refactors merged to main  
**Commit:** `c1151ca` — "Alpha After Refactor: 04-refactor sprint complete"

---

## Refactors Completed

### ✅ Refactor 01 — Consolidate `_edge_key()` into `WallEdgeData`
- **Scope:** 1 new file + remove duplicated function from 3 existing files
- **Changes:**
  - Created `scripts/world/wall_edge_data.gd` with canonical edge key generation
  - Removed `_edge_key()` from `guard_enemy.gd`, `enemy_phase_controller.gd`, `movement_overlay.gd`
  - All 5 call sites updated to use `WallEdgeData.edge_key()`
- **Benefit:** Single source of truth for edge identification; future-proof for partial walls (M2)

### ✅ Refactor 02 — Make Stats Data-Driven (No Hardcoded Maxima)
- **Scope:** 1 new file + change `const` to `var` in 2 files
- **Changes:**
  - Created `scripts/data/agent_stats.gd` — central stats container with fields for AP, HP, armor, vision, alert, difficulty tier
  - Changed `const MAX_AP := 2` → `var max_ap: int = 2` in `turn_manager.gd`
  - Changed `const MOVE_POINTS_PER_AP := 3` → `var move_points_per_ap: int = 3` in `turn_manager.gd`
  - Changed `const ALERT_MAX := 100`, `const ALERT_GAIN_WARNING := 20`, `const ALERT_GAIN_FULL := 45` → `var` in `room.gd`
  - All 8 reference sites updated
- **Benefit:** Foundation for difficulty tier scaling (M4+); no artificial ceilings blocking Freelance mode

### ✅ Refactor 03 — Replace Rectangular Cone with Angular FOV
- **Scope:** `guard_enemy.gd` only
- **Changes:**
  - Added 3 new fields: `fov_degrees` (90°), `fov_range` (8 tiles), `facing_angle_deg` (0–270°)
  - Added `_update_facing_angle()` — called at all 6 facing assignment sites
  - Replaced `evaluate_detection()` with angular FOV implementation using `atan2()`
  - New implementation computes `angle_ratio` for smooth falloff; same return dict keys for backward compatibility
- **Benefit:** 8-directional support (not just 4 cardinal); smooth cone without diagonal dead zones; foundation for guard behavior variations (M2)

### ✅ Refactor 04 — Replace Greedy `_step_toward()` with A* Pathfinding
- **Scope:** 1 new file + modify `guard_enemy.gd`
- **Changes:**
  - Created `scripts/navigation/guard_pathfinder.gd` — static A* implementation (87 lines)
  - Added 3 path caching fields to `guard_enemy.gd`: `_cached_target`, `_cached_path`, `_path_index`
  - Replaced greedy `_step_toward()` with A* version that replans on target change
  - A* uses Manhattan distance heuristic, respects `blocked_cells` and `blocked_edges`, returns optimal path
- **Benefit:** Guards navigate intelligently around obstacles; no more corner-stuck behavior; optimal (not greedy) routes

---

## Architecture Rules Locked

✅ **Rule 1:** Stats always data-driven (no hardcoded maxima)  
✅ **Rule 2:** Structure/content narratively separated (LLM-ready)  
✅ **Rule 3:** Generator receives tier, produces proportional encounters  
✅ **Rule 4:** Fatality rule proportional (teto + 1), not absolute  
✅ **Rule 5:** Communication systems pluggable (apito, rádio, alarme)  
✅ **Rule 6:** UI scales with variable actor count

---

## Files Created
- `godot/scripts/world/wall_edge_data.gd` (44 lines)
- `godot/scripts/data/agent_stats.gd` (40 lines)
- `godot/scripts/navigation/guard_pathfinder.gd` (87 lines)

## Files Modified
- `godot/scripts/agents/guard_enemy.gd` (+80 lines from refactors 03–04)
- `godot/scripts/systems/turn_manager.gd` (7 const → var changes)
- `godot/scripts/world/room.gd` (5 const → var changes)
- `godot/scripts/navigation/movement_overlay.gd` (1 reference updated)

## Total Diff
- **20 files changed** (including .uid files and BACKUP files)
- **+1819 insertions, −88 deletions** (net +1731)
- **3 new core files** + updates to 4 existing files

---

## Next Steps (M2 Continuation)

1. **Event-driven detection by tic** — Replace turn-based detection with edge-crossing events
2. **Noise system** — Terrain cost, terrain type, intensity degradation
3. **Confrontation system** — 4 cover states, flanking, peek mechanic
4. **Enemy state machine** — Complete FSM (patrol → suspicious → alert → chase)
5. **Communication system** — Apito (local), rádio (global), alarme (site-wide)

---

## Known Limitations (Intentional)

- Path caching assumes guard position changes per turn (true in current design)
- A* uses Manhattan distance; future optimization: LOS-based cost weighting
- FOV cone currently 90° fixed; future: scale by guard state (patrol/alert/chase)
- No diagonal movement yet (planned unlock as late-game skill)

---

**Status:** Ready for M2 M2 continuation. Architecture is stable, extensible, and ready for procedural generation and LLM integration.
