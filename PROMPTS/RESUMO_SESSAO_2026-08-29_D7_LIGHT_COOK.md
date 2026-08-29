# RESUMO_SESSAO — 2026-08-29 · D-7 — THE LIGHT COOK (§7.4)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-29_D6_PART2_DELETION.md`
**Commits (pushed):** `[DOCS]` current_state auto-inventory · `[D-7]` the light cook.
**Gates at close:** lint ✅ · selftests **38 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅ · `INFILTRAITOR_LIGHT_COOK_GATE=1` → **0 of 206 096 cells differ**.
**VERSION:** unchanged at 0.9.107.

---

## Result

**`play_consequence_light()`'s freeze: 158 ms → 17.7 ms**, gate-proven identical
to a full re-derivation cell-for-cell.

## §7.4's premise was wrong — the measurement is the story

A clean same-binary A/B (`INFILTRAITOR_NO_LIGHT_COOK` toggles only the path):

- The real freeze is **158 ms**, not D-1's 201.9 ms estimate.
- It is `occupancy 42 · soot 31 · field.build 66 · apply 18` — **four map-wide
  walks**, not "one derive."
- The cook does NOT already do this work:
  - PHASE_WALK builds a **blast-scoped** occupancy (affected containers only).
  - `_phase_light` measures 0.1 ms only because `VoxelLightField.build()` is
    **lazy** — buckets are derived later, in `_phase_soot_wave`, per soot-ring cell.

**The first attempt (feed the cook's scoped occupancy into the room's incremental
`_stale_cells()` diff) was a 12× regression:** 158 → 1849 ms, because the diff saw
the whole rest of the map as changed. The equivalence gate still passed
(0/206096) — correct, catastrophically slow. Reverted.

## What shipped

- **`_phase_light`** builds a **map-wide** field from
  `voxel_renderer.build_occupancy(predict_destroyed)` (`predict_destroyed` =
  `s["blast_cells"] + s["weapon_cells"]`). Lazy build, so **+45 ms one cook step.**
- **`_phase_soot_wave`** records its changed-cell set (the one it emits to
  `waves["soot"]`) as `delta.light_changed_cells`.
- **`WorldDelta`**: `light_field`, `light_changed_cells`, `light_field_usable`.
  `usable` is FALSE when any input light is temporal (flicker/pulse/rotation).
- **`Room.play_consequence_light(delta)`** cooked path:
  `apply_light_field_cells(delta.light_field, delta.light_changed_cells)`. No
  `build_occupancy`, no `_build_soot_snapshot`, no `field.build`. The persistent
  `_voxel_light_field` is **not** adopted — nothing reads it before the next
  `lighting_rebuilt` (temporal lights excluded), which rebuilds it from scratch.
- **`DetonationPresenter.consequence_delta`** threads it. The controller holds a
  `WorldDelta` local from before the beat's awaits — `bump_world_revision()` can
  null `job.delta` out from under it (was a live SCRIPT ERROR, fixed).
- **Gate:** `INFILTRAITOR_LIGHT_COOK_GATE=1` forces the full re-derivation after
  and counts differing alt ids. **`INFILTRAITOR_NO_LIGHT_COOK=1`** forces the
  full path for an A/B.

## Cost the Director closed on

The cook's worst single step went 7–9 ms → **45 ms** (the occupancy walk,
atomic). It runs during aiming, once per cook; the cook already overruns the aim
window by ~336 ms and eats fuse frames, and the fuse is elastic by design
(§8.10). Director: *"Fechar assim."*

**Follow-up if it ever matters:** a base-occupancy cache in `VoxelRenderer`
(invalidated on `set_cell`/`erase_cell`) makes `build_occupancy(predict)` a
copy+subtract (~1 ms) and speeds up every repaint the room does, not just this
one. Its own change, its own gate.

## Evidence

- `INFILTRAITOR_LIGHT_COOK_GATE=1`: `0 of 206 096 cell(s) differ · derive 17.7 ms
  · VERDICT: PASS`.
- `[P-SLICE]` cook profile: LIGHT 0.1 → 45.0 ms; total 381 → 392 ms (within the
  ±40 ms run-to-run noise §8.8 documents); `[P-COOK] short by` 350 → 336 ms.
- 3× video: `d7_light_cook.mp4` (scratchpad).
- Selftests 38 clean, invariants, lint, CODEMAP.

## Still open

1. **Polish `throw_event`** (§8.13) — dome flash, GU/throw-range clamp, framing.
2. **Glass** — `MATERIALS_MASTER_PLAN` M4, end of the materials milestone.
3. Optional: the `VoxelRenderer` base-occupancy cache (above).
4. Untouched: `SOOT_STORAGE_REFORM` SS-4/SS-5, the glowing edge,
   `INFILTRAITOR_HIDE_VOXELS`, audio (incl. the swiffh).
