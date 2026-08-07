# RESUMO_SESSAO — 2026-08-07 (Task 2 / E-RING — ring/falloff calculation, shipped)

**Continues:** `RESUMO_SESSAO_2026-08-06_E_BAKE_TASK1B.md`, which closed with
Task 1b done and Task 2 as the next action.
**VERSION:** 0.9.90 (unchanged — no version bump requested).
**Commit:** `a3f58ee` — `[E-RING] Task 2 — ring/falloff calculation: D14
spherical falloff, per-tier weights, D2/D16/D17 parameter surface`.
**Mode:** Solo mode.

---

## What shipped

`EXPLOSION_REBUILD_MASTER_PLAN.md` Task 2 (E-RING): the ring/falloff
**calculation** layer — how much of each damage tier (destroy/dent/crack) a
voxel gets, across a 4th ring, D14's spherical vertical falloff, D16's
blast-side atom routing, D17's slab-pierce multiplier, and D2's two-layer
floor gate. Confirmed via research before writing code: **neither
`apply_container_damage()` nor `apply_crater_damage()` has a live caller
today** (`TestZoneController.detonate_active()` stayed disconnected since
2026-08-05, commit `d412480`) — so this task is calculation-layer only,
proven by selftest, with `room` state (`_gu_blast_count`) and the actual
reconnection deferred to Task 5 (E-WAVE). Confirmed with the Director via
`AskUserQuestion` before implementing.

- **`frag_grenade.json`/`BombDef`**: 4th ring
  (`ring_multipliers: [1.0, 0.6, 0.25, 0.0]`) plus `destroy_ring_weights`/
  `dent_ring_weights`/`crack_ring_weights: Array[float]` (new per-tier
  gates) and `soot_ring_tones`/`smoke_ring_weights` (parsed now, consumed
  starting Task 3).
- **D14 (spherical falloff)**: `apply_container_damage()`'s vertical-ring
  step is now `absi(level_offset) / LEVELS_PER_STOREY` for wall AND roof —
  the `is_roof` per-raw-level branch (and its "deliberate asymmetry, not an
  oversight" doc comment) is retired.
- **Per-tier weights**: `destroy_ring_weights`/`dent_ring_weights`/
  `crack_ring_weights` replace the single `ring_multipliers[ring]` scaling
  read that used to drive all three tiers identically.
  `ring_multipliers` keeps its other job (range cap) unchanged.
- **D2 (two floor layers)**: `apply_crater_damage()` gains
  `deep_layer_unlocked: bool = false` — the principled replacement for the
  removed PERF-02 B4 hack ("skip FLOOR_-2 entirely"). Gates
  `GeometryCoords.FLOOR_DEEP_LEVEL` voxels out entirely (not just narrowed)
  when false.
- **D17 (slab-pierce multiplier)**: `apply_crater_damage()` gains
  `slab_pierce_multiplier: float = 1.0`, scaling both the destroy
  probability and the dent probability in the crater's rim band. Trailing +
  defaulted, byte-for-byte inert at 1.0 — a future calibration knob (no
  stacked-slab scenario exists in any real map today, confirmed via a
  research pass on `SlabRegistry`/`Slab`).
- **D16 (blast-side atom routing)**: needed **zero changes** to
  `apply_crater_damage()` — its DENTED path already hardcoded
  `CarvedSide.TOP` unconditionally, already correct for a roof struck from
  above. Entirely a render-side fix: `VoxelRenderer.
  apply_damage_voxel_swap()`'s CEILING branch now checks
  `damage_carved_side == TOP` first and routes through the FLOOR
  naming/key path (`floor_damage_material()`, the GU's real ground material
  via `_floor_zone_by_gu`, falling back to `"earth"` when unzoned) instead
  of the ordinary CEILING path. BOTTOM (the normal "hit from underneath"
  case) is unchanged.
- **D9 (real-material floor lookup)**: confirmed already fully wired
  *before* this task (`git show d412480~1` shows the pre-reset caller
  already passing a real material, never a hardcoded `"earth"`) — this
  task's job was proving it with a real regression test, not building it.

## The real numbers, not projections

- **75 assertions pass** in `blast_calculator_selftest.gd` (69 pre-existing
  + 6 new), **0 fail**.
- **9 assertions pass** in `damage_atom_bake_selftest.gd` (8 pre-existing +
  1 new multi-assertion test), **0 fail**.
- **31/31 selftests clean** project-wide.
- Concrete numbers from the new tests, not synthetic placeholders: wood
  floor dent count **10** vs concrete floor dent count **49** (D9, tracking
  each material's real `dent_factor` — 0.03 vs 0.15 — from the reformed
  one-row-per-material table); `slab_pierce_multiplier` 3.0 destroyed
  **129** rim voxels vs **79** at the 1.0 default; `deep_layer_unlocked`
  gate: **58** deep-level voxels destroyed when unlocked, **0** when not.

## One real bug caught by the tests themselves, not by manual review

`damage_atom_bake_selftest.gd`'s first draft of the D16 routing test
(`test_5_ceiling_top_routes_as_floor`) re-used one real PLAYGROUND `Voxel`
for both the TOP and BOTTOM halves of the check: `set_damage(DENTED, ...,
TOP, ...)`, then later `set_damage(DENTED, ..., BOTTOM, ...)` on the same
voxel. `Voxel.set_damage()` (`voxel.gd:105`) no-ops when
`new_state == damage_state` — since the voxel was already `DENTED` from the
first call, the second call was silently dropped and `carved_side` stayed
stuck at `TOP`. This produced a real, honest FAIL (not a crash, not a false
green): the BOTTOM assertion compared the actual painted tile
(`layer.get_cell_atlas_coords()`) against the independently-derived CEILING
key's expected atlas coords and they genuinely didn't match — `source_id`
happened to agree (both atoms share one atlas page) but `atlas_coords` read
`(54, 3)` (the TOP/FLOOR atom, still painted from the first half) instead of
the expected `(63, 0)`. Fixed by resetting `damage_state` to `INTACT`
between the two calls, matching how a real voxel only ever transitions out
of `INTACT` once. Re-ran and confirmed both halves pass with genuinely
distinct, real atlas coordinates (`(54, 3)` for TOP/FLOOR vs `(63, 0)` for
BOTTOM/CEILING) — proof the routing fix works, not just that the test no
longer crashes.

## Two corrections found by reading the actual code, not the plan summary

Both surfaced during this task's pre-implementation research and were
folded into the plan (and the master plan's own Task 2 row) before any code
was written, per CLAUDE.md's "ask, don't guess" discipline:

1. **D14's "roof pierces as one unit" (part of D17) falls out for free —
   confirmed, not assumed.** A dedicated selftest
   (`test_roof_two_levels_same_ring_group`) proves two Slabs at levels 0/1
   (mirroring `ROOF_LEVEL_COUNT = 2`) land in the identical ring group under
   the new spherical step, where the old per-raw-level roof stepping would
   have split them across ring 0 and ring 1.
2. **The master plan's own Task 2 row text implied `apply_crater_damage()`
   would also read the new per-tier weight arrays via "the §4.3
   effective-ring formula."** Reading the actual function (a radial/
   distance model, never a ring index — floors "keep the ring model" was
   never true per the function's own doc comment) showed this doesn't apply:
   `apply_crater_damage()` only gained `deep_layer_unlocked` and
   `slab_pierce_multiplier`, not the ring-weight arrays. The approved,
   research-backed plan (not the master plan row's looser summary) is what
   got built; the master plan row itself has been corrected to match in
   this same session.

## State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**, Task 0/1a/1b/2 done.
- **Task 3 (E-SOOT) is the next concrete action** — per-voxel authored soot
  codes, first real consumer of Task 2's parsed-but-unread
  `soot_ring_tones`/`smoke_ring_weights`.
- Explosive destruction is still a no-op end-to-end
  (`detonate_active()` not yet rewired to `BlastCalculator` — Task 5's job).
  Firearms unaffected, untouched this session.
- Pushed to `main` (pending — see next message).
