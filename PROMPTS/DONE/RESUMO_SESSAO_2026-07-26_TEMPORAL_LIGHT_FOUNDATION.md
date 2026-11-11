# RESUMO_SESSAO — 2026-07-26 (ALPHA TEMPORAL LIGHT FOUNDATION, SESSION CLOSE)

**Active master plan:** `PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md` —
**✅ SHIPPED** this session (VL-01 → VL-D5). Item 6 (metal denting/warping)
and the 4-view perspective prebuild are the only pieces still open, both
explicitly deferred (see the plan's own closing section).
**VERSION at session start:** 0.9.68
**VERSION at session end:** 0.9.81
**Mode:** Solo mode.
**Screenshot session:** not toggled; all captures via direct off-screen
`INFILTRAITOR_AUTO_SCREENSHOT=1`/`INFILTRAITOR_CAPTURE_ACTION=...` runs.

---

## Executive Summary

Closed the blocker the previous session (GRENADE_FOUNDATION, 2026-07-22)
named and paused on: destruction was mechanically correct but invisible,
because every voxel rendered fully lit regardless of damage. This session
built the whole voxel FACE lighting plane from nothing — brightness buckets,
GU-resolution occlusion reuse, blast-visual readability (soot, crater,
directional bias, ember→char) — then, prompted by a real Director concern
about perspective-rotation cost on mobile, found and fixed a genuine
self-inflicted performance regression (eager alt-minting), profiled the rest
of the rotation cost, cut it ~80%, and built the destruction-persistence
registry that makes rotation safe to use at all with a mutable world. A late
investigation into "does stone need its own soot system" concluded it
already had one — material-agnostic since VL-D1 — and the real ask was
answered by reporting that finding plus a small global tuning pass, not by
writing new code. Every item below closed with a real capture, probe, or
selftest cited next to it — no criterion marked done on code-reading alone.

## Wave Table

| ID | What | Status |
|---|---|---|
| VL-01 | Static 6-bucket voxel face lighting (`VoxelLightField`, unified alt encoder replacing `GHOST_ALT_IDS`, PLAYGROUND demo lamps) | ✅ |
| VL-02 | Readability pass: per-axis face shading (top/SE/SW), cavity AO, overhead-overlay z-index fix, floor blast extended to slabs | ✅ |
| VL-02d | Contrast/brightness tune; flicker mechanism proven correct but too slow to enable yet | ✅ |
| VL-D1 | Blast soot rings around holes (`Voxel.soot_ring`, `compute_soot_rings` BFS) — material-agnostic from day one | ✅ |
| VL-D2 | Contiguous radial floor crater (replaced ring/hash scatter); narrowed + lightened same session | ✅ |
| VL-03-PERF → VL-PERF-BAKE | Rotation cost investigation: lazy alt minting (−3.0s), bake-source cache across rotations (−0.73s), lamp/static-factor caching (−0.33s). **~5.7s → ~1.15s off-screen throttled (−80%)** | ✅ |
| VL-PERSIST | Destruction (holes + soot) survives perspective rotation via a base-coordinate registry — no 4-view prebuild needed | ✅ |
| VL-D3 | Under-wall floor darkening (darken at load, reveal naturally on exposure) | ✅ |
| VL-03 | Incremental light-field repaint (`apply_light_field_gus`, per-GU index, static-factor/lamp cache split) — flicker demo lamp ENABLED for the first time | ✅ |
| VL-D4 | Wood: directional destruction bias (general-purpose) + `EmberOverlay` glow→char VFX | ✅ |
| VL-D5 | Stone: confirmed the existing material-agnostic soot system already covers the ask; global soot-opacity tuning only | ✅ |

## Decisions (Director-ratified)

1. **Visual brightness ≠ tactical visibility stays inviolable.** Every new
   mechanism (buckets, soot, ember) reads `LightSource.visual_energy`, never
   `tactical_energy`; confirmed explicitly that `_rebuild_all_shadows_and_
   exposure()` never depended on `energy_multiplier`, so skipping it for a
   temporal toggle loses nothing real.
2. **6 buckets → 12**, mid-session, when VL-02's axis/AO/soot terms collided
   into the same bucket at 6 and blast craters stopped reading. Confirmed via
   captures before and after.
3. **Binary-dominant falloff, no additive multi-lamp blending** — the
   original VL-01 canon — held through every later addition.
4. **4-view perspective prebuild is deferred to the project's finishing/
   optimization pass, not now.** Explicit Director reasoning: prebuilding
   turns "1 world state → 1 render" into "1 world state → 4 synchronized
   renders," a permanent sync tax on every future world-mutation feature,
   and the destruction system is still immature enough that freezing the
   render architecture around 4 views would be premature. The VL-PERSIST
   base-coordinate registry (built instead, now) is the shared prerequisite
   either way.
5. **No per-material soot system for stone.** Found the ask was already
   satisfied by VL-D1's material-agnostic mechanism; Director's call was a
   small global opacity tune (`[0.16,0.36,0.60] → [0.20,0.40,0.63]`), not new
   per-material plumbing.
6. **Ember is a screen-space overlay, never a tile-modulate encoding** — a
   light-bucket alternative's modulate is shared by every voxel at that
   `(source, atlas_coords, alt_id)`, which is exactly what makes VL-01/VL-03
   cheap; a per-voxel independent time-varying glow structurally cannot live
   there without breaking that sharing.

## Evidence

- `project_lint.py`: 0 real errors, every stage this session (147 files at
  close).
- Selftests, all green at session close: `bake_selftest` 19/19,
  `blast_calculator_selftest` 16/16 (10 pre-existing + 6 new this session:
  soot-spread, min-ring-wins, crater core/rim/beyond, directional-bias
  prefers-near-side, no-bias-sentinel-unchanged), `floor_integration_selftest`
  9/9, `roof_bake_selftest` 8/8, `voxel_persist_selftest` 2/2 (new),
  `voxel_light_incremental_selftest` 5/5 (new).
- Real captures (non-exhaustive): `auto_2026-07-24_17-48-29` (floor light
  pool falloff), `occ_view_N/E/S/W` (rotation-coherent lighting, ghost
  round-trip IDENTICAL all 4 views), `auto_2026-07-24_20-19-44` (narrowed
  crater + crater-floor soot), `auto_2026-07-24_22-40-49` (under-wall floor
  darkening), `auto_2026-07-26_11-51-08`/`11-50-49` (flicker ON vs OFF-phase,
  same GUs, brightness delta 43.1→20.0), `auto_2026-07-26_13-27-43`/`13-28-42`
  (wood ember glow at ~0.75s vs ~2.6s post-blast — vivid glow → faded, charred
  wood revealed), `auto_2026-07-26_14-33-01` (softened soot opacity, VL-D5).
- Hard numbers, not impressions: rotation `~5.7s → ~1.15s` (off-screen
  throttled); flicker toggle `~590-675ms → ~75ms` (149 GUs, 29,180 voxels,
  worst-case dense-wall overlap); stone soot bucket math `11→2/4/7` (ring
  0/1/2, 67%/53%/31% darkening) confirmed against a real detonation's soot
  histogram (1134 stone voxels tagged from one blast).
- New dev tooling, kept (matches existing `INFILTRAITOR_CAPTURE_ACTION`
  precedent): `INFILTRAITOR_CAPTURE_DETONATE_INDEX` (any of the 4 test-zone
  grenades, `test_zone_detonate` now frames the camera on that grenade's own
  cell instead of a fixed row-centre that put wood/stone off-screen).

## Next Session

- **Metal (VL-D backlog item 6):** the one explicitly deferred material.
  Needs a denting/warping GEOMETRY design pass first (wood/stone destroy into
  holes; metal is asked to deform in place) before any lighting/VFX work —
  `EmberOverlay` itself should need no changes, just a faster glow/cool
  timing and a different seed condition.
- **4-view perspective prebuild:** deliberately parked until world mechanics
  mature and instant rotation proves a real gameplay need (Director's own
  trigger condition, recorded in the plan). The VL-PERSIST registry is ready
  to be reused as-is when that day comes.
- Resuming `DESTRUCTION_MASTER_PLAN.md` proper (cover rule, noise-on-digging,
  rubble-as-terrain, breach-as-clue — all named open in the 2026-07-22
  session, none touched this session) is now unblocked: destruction is
  visible, persists through rotation, and rotation itself is fast enough not
  to fight iteration.
