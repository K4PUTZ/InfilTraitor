# RESUMO_SESSAO — 2026-08-07c (Task 4 / E-PLAN — DetonationPlanBuilder, shipped)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-07_E_SOOT_TASK3.md`, which
closed with Task 3 done and Task 4 as the next action.
**VERSION:** 0.9.90 (unchanged — no version bump requested).
**Commit:** pending (see next message).
**Mode:** Solo mode.

---

## What shipped

`EXPLOSION_REBUILD_MASTER_PLAN.md` Task 4 (E-PLAN): `DetonationPlanBuilder.
build_plan()`, a new class in
`godot/scripts/systems/destruction/detonation_plan_builder.gd`. It runs the
full real resolution pipeline for one grenade detonation (flood → affected
containers → `apply_container_damage()`/`apply_crater_damage()` →
`stamp_container_soot()`/`stamp_crater_soot()` — all Task 2/3's own,
unchanged writers), composes that with a whole-map derive-from-holes soot
pass, queries ONE `VoxelLightField` build, and packages everything into the
`DetonationPlan` dictionary shape from §6.1 (`destroy`/`dented`/`cracked`/
`smoke`/`soot`, each `ring -> Array[...]`) — **without ever touching the
live TileMapLayer.**

## The one real design question, resolved by reading the code, not guessed

§2 says waves must do "no compositing, no lookup... " — meaning a plan
entry has to arrive with its final `(source_id, atlas_coords, alt)` already
resolved. The open question was HOW to get that without either (a) a risky
refactor of `_set_voxel_cell()` (the function every damage/floor-reveal
render path funnels through, used everywhere from base wall rendering to
occlusion) or (b) letting the "hitch" simply mean painting the tiles for
real ahead of the wave that's supposed to reveal them.

Reading `_set_voxel_cell()` end to end showed it was ALREADY a pure
resolution cascade (baked lookup → D33 live-compositing fallback → flat
material-only last resort) with exactly ONE side-effecting line
(`layer.set_cell()`) at the very end. A trailing `apply: bool = true`
parameter — default preserves every existing caller byte-for-byte — turns
that one line into a `return` of the resolved triple instead. Same seam
added to `render_slab()`/`render_fixed_earth_level()`/`reveal_floor_slab()`
(the exposure-fallback paths) and, via a Task-3-style pure extraction,
`apply_damage_voxel_swap()` split into `resolve_damage_voxel_swap()` (the
pure lookup) + a thin apply wrapper. No design tension needed raising with
the Director this time — the mechanical seam was low-risk enough to just
build and prove with the existing seam-selftest suite (32/32 still clean
after the change, before Task 4's own new file even existed).

## What shipped, concretely

- **`VoxelRenderer._set_voxel_cell()`** gained `apply: bool = true`,
  returns `Dictionary` (was `void`) — `{}` when applying (existing callers
  ignore it, unaffected), `{"source_id","atlas_coords","alternative_id"}`
  when resolving only.
- **`VoxelRenderer.resolve_damage_voxel_swap()`** — new, the pure half of
  `apply_damage_voxel_swap()` (now a thin `resolve + set_cell` wrapper,
  unchanged signature/return type, every existing caller unaffected).
- **`render_slab()`/`render_fixed_earth_level()`/`reveal_floor_slab()`**
  gained the same `apply` seam, returning `Array` of resolved per-voxel
  entries when false.
- **`BlastCalculator._vertical_ring_for()` → `vertical_ring_for()`** —
  promoted from private to public: `DetonationPlanBuilder` is a second,
  cross-file consumer of D14's exact ring formula, needed to group wave
  entries by the same per-voxel ring `apply_container_damage()` computes
  internally.
- **`BlastCalculator.crater_ring_for()`** — new, extracted out of
  `stamp_crater_soot()`'s own inline ring-band formula (pure extraction,
  behavior-preserving) so floor destroy/dent wave-grouping and floor soot
  banding can never disagree about which ring a floor voxel is in.
- **`DetonationPlanBuilder.build_plan(bomb_def, source_gu, ctx)`** — the
  new orchestrator. `ctx` is a plain Dictionary (edge_registry,
  slab_registry, voxel_renderer, blocked_edges/cells, lights,
  shadow_results, under_structure, deep_layer_unlocked), matching the
  project's MinimalRoom precedent so this runs identically against a real
  `room.gd` or a trimmed selftest scaffold. Composes the blast's stamped
  soot with a WHOLE-MAP `derive_soot_rings()`/`apply_self_soot()` pass
  (closing the exact gap Task 3's own closure note flagged as unbuilt —
  "this compositional step belongs in the first real caller, not in
  room.gd"). Occupancy for the light field comes from `Voxel.visible`
  directly (a new `_voxel_occupancy()`), never from
  `VoxelRenderer.build_occupancy()` — that reads the live TileMapLayer,
  which still shows every voxel this blast just destroyed as solid since
  nothing has erased it yet. `smoke_ring_weights` gets its first real
  consumer (flagged "still unread" since Task 2).

## Real evidence, not reasoning

New selftest `detonation_plan_selftest.gd` boots real PLAYGROUND (Task 1b's
MinimalRoom scaffold) and calls `build_plan()` for a real detonation at the
GU of PLAYGROUND's first real concrete wall slice (not a hand-picked
coordinate — can't silently stop testing anything after a map edit).

**Real wave census** (this exact run, printed by the selftest — the Task 4
gate itself):

| Wave | ring0 | ring1 | ring2 | ring3 | total |
|---|---|---|---|---|---|
| destroy | 102 | 14 | 4 | — | 120 |
| dented | 20 | 8 | — | — | 28 |
| cracked | — | 12 | 4 | — | 16 |
| smoke | 1 | 1 | 3 | 5 | 10 |
| soot | 180 | 136 | 157 | 88 | 561 |

Matches D1's "muito/menos/quase nada" shape for real: dented stops at ring
1 (`dent_ring_weights[2]=0.0` in the real JSON), cracked never touches ring
0 (`crack_ring_weights[0]=0.0`) — asserted for every zero-weight ring, not
eyeballed off the table above.

**"Never touches the live TileMapLayer" is proven, not asserted**: the
selftest snapshots every one of PLAYGROUND's 108,576 placed cells'
`(source_id, atlas_coords, alt)` before and after `build_plan()` and asserts
byte-identity. Also proven: 64 floor-reveal `expose` entries resolved (real
tiles, never applied) under the destroy waves that actually opened a
crater; 44 dented/cracked entries all carry a real non-negative
`source_id`/`atlas_coords`/`alt`, never a placeholder; every smoke entry's
`duration`/`scale` matches `frag_grenade.json`'s own `smoke_ring_weights`
element for element.

**One real bug caught mid-implementation, fixed before the first green
run**: the first pass of `_build_ctx()` fed `builder.get_light_sources()`'s
raw map-data Dictionaries (`{x,y,height,radius,intensity}`) straight into
`VoxelLightField.build()`, which crashed
(`VoxelLightField._lamp_intensity`: `Invalid access to property 'active' on
a Dictionary`) — a real room never does this; `LightingController.
_setup_lights_from_layout()` converts each dict into a real `LightSource`
object first. Fixed by replicating that exact conversion in the selftest
(the scaffold has no `LightingController` to lean on) — `DetonationPlan-
Builder`'s own contract (`ctx["lights"]` = already-real `LightSource`
objects, matching `LightRegistry.get_active_lights()`'s shape) was correct
all along; the selftest's first draft violated it.

## One documented, honest gap

`_resolve_damaged_tile()`'s Slab live-compositing-fallback branch resolves
the same shared material name the live pipeline would, but does not
reproduce `_process_dirty_slab_voxel()`'s full zoned-floor branching.
Flagged in the source, not silently assumed correct — Task 1b's own bake
measured **zero** unresolved atoms across all three element classes on real
PLAYGROUND material, so this is real plumbing for a case nothing real hits
today.

## Verification (per CLAUDE.md's evidence discipline)

- `project_lint.py`: 186 files, 0 errors.
- `run_selftests.py`: 32/32 clean. New `detonation_plan_selftest.gd`: 6/6
  own assertions (census/resolved-triples/no-mutation/exposure/smoke-
  weights/ring-gates). Every pre-existing `_set_voxel_cell()`/
  `apply_damage_voxel_swap()` seam selftest (`decal_seam_selftest.gd`,
  `half_voxel_seam_selftest.gd`, `ceiling_carve_seam_selftest.gd`,
  `floor_sunk_seam_selftest.gd`, `generic_mark_seam_selftest.gd`,
  `damage_atom_bake_selftest.gd`) still passes unchanged — the resolve/apply
  split is behavior-preserving for firearms' live D33 path too.
- `check_invariants.py`: OK. `gen_codemap.py --check`: clean (186 scripts).
- No visual capture — same reasoning as Task 2/3: nothing calls
  `layer.set_cell()` yet by design, so there is nothing to screenshot. The
  printed census and the byte-identity snapshot diff are this task's real
  evidence. Deferred to Task 5, where a detonation first becomes visible.

## State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**, Task 0/1a/1b/2/3/4
  done.
- **Task 5 (E-WAVE) is the next concrete action** — `DetonationChoreographer`
  (walk the 15-wave table at 40 ms/wave, play back Task 4's plan entries as
  pure `set_cell()`/`erase_cell()` calls), reconnecting
  `TestZoneController.detonate_active()` for real. Also Task 5's job:
  `room._gu_blast_count`/D2's `deep_layer_unlocked` wiring, the stamped-blast
  event/replay list for rotation persistence, `record_voxel_damage_to_base()`
  calls, a real smoke color per material, and §6.3's deferred-soot-compute
  decision (background thread vs. synchronous-after-wave-1).
- Explosive destruction is still fully invisible end-to-end
  (`detonate_active()` not yet rewired). Firearms unaffected, untouched this
  session (proven by the unchanged seam-selftest suite, not just claimed).
- Pushed to `main` (pending — see next message).
