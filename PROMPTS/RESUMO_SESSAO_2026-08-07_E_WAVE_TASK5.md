# RESUMO_SESSAO — 2026-08-07d (Task 5 / E-WAVE — DetonationChoreographer, shipped)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-07_E_PLAN_TASK4.md`, which
closed with Task 4 done and Task 5 as the next action.
**VERSION:** 0.9.90 (unchanged — no version bump requested).
**Commit:** pending (see next message).
**Mode:** Solo mode.

---

## What shipped

`EXPLOSION_REBUILD_MASTER_PLAN.md` Task 5 (E-WAVE): **grenades detonate for
real now.** `DetonationChoreographer` plays back Task 4's `DetonationPlan`
as the real 15-wave sequence from §1's table, and
`TestZoneController.detonate_active()` is reconnected end to end. Phase A
of this plan (bake + calculation + waves on the current right-click
trigger) is functionally complete.

## A real bug, caught by the capture itself

The first real run scheduled all 15 `SceneTreeTimer`s correctly (verified
via a diagnostic print per timer — every one showed its own delay and a
real `SceneTreeTimer` instance) but **not one `timeout` ever fired**.

`DetonationChoreographer`'s own first-draft doc comment had assumed a
`SceneTreeTimer`'s `timeout` connection holding a bound `Callable` would be
enough, on its own, to keep the choreographer (`RefCounted`, not a `Node`)
alive for the whole ~600 ms sequence. Measured false:
`detonate_active()`'s local `choreographer` variable was the ONLY
reference, and it went out of scope the instant the function returned —
before a single wave applied. Root-caused by adding diagnostic prints at
`start()` (proving scheduling worked) then at `_apply_wave()` (proving it
never ran) and reasoning from there, not by guessing at a fix. Fixed by
`TestZoneController` holding an explicit `_active_choreographer` reference,
cleared via the class's own new `finished` signal once the last wave
lands. The class's own header comment was rewritten to record the measured
finding instead of the wrong assumption, so the next reader doesn't repeat
it.

## What shipped, concretely

- **`DetonationChoreographer`** (new,
  `godot/scripts/systems/destruction/detonation_choreographer.gd`) — the
  static 15-entry `WAVE_TABLE` from §1, each wave on its own independent
  `SceneTreeTimer` from t=0 (never chained/awaited — "a slow wave never
  delays the next"), `wave_interval_ms` a `var` at 40 (Q5). `_apply_wave()`
  is the ONLY place in the whole pipeline that calls `layer.set_cell()`/
  `erase_cell()`/`SmokeSparkOverlay.add_smoke()`. Prints `[E-WAVE] wave
  N/15 kind=... ring=... cells=... elapsed=...ms apply=...ms` per wave —
  the Task 5 gate's own "measured per-wave ms" evidence, on every real
  detonation.
- **`SmokeSparkOverlay.add_smoke()`** gained a trailing `duration_scale:
  float = 1.0` (both pre-existing callers unaffected) so smoke waves can
  make farther rings' puffs genuinely linger less, not just look smaller.
- **`DetonationPlanBuilder.build_plan()`** now also returns
  `"touched_voxels"` (`Array[Voxel]`) — Task 5's persistence seam, so
  `detonate_active()` calls `room.record_voxel_damage_to_base()` for real
  without re-deriving the affected set with a second flood pass.
- **`room._gu_blast_count: Dictionary`** (new, cleared on map load) — D2's
  floor-layer memory, threaded into `build_plan()`'s
  `ctx["deep_layer_unlocked"]`.
- **`TestZoneController.detonate_active()`** rebuilds a real `ctx` from
  the live room (real `LightSource` objects from
  `room._lighting_controller`, unlike the selftest scaffold's hand
  conversion), calls `build_plan()`, increments `_gu_blast_count`,
  persists `touched_voxels`, hands the plan to a
  `DetonationChoreographer`.

## One documented, deliberate scope decision

VFX-01's per-voxel dust/spark/chip debris no longer fires for blast-caused
destruction (the choreographer erases cells directly, bypassing
`VoxelRenderer.process_dirty()`'s `voxel_destroyed` signal, and the plan's
destroy entries carry no material to dispatch debris from). The bigger
reason: the OLD immediate-smoke half of that same dispatch would have
doubled up with the new staged smoke waves (D5) if left connected.
Firearms are unaffected — still the signal-driven path. Flagged for a
future task if the Director wants blast debris back (needs material
threaded onto destroy plan entries).

## Real evidence — captured and measured, not reasoned about

Real detonation on PLAYGROUND's metal wall (`INFILTRAITOR_CAPTURE_
DETONATE_INDEX=1`):

| Wave | ring0 | ring1 | ring2 | ring3 |
|---|---|---|---|---|
| destroy | 899 | 2 | 0 | — |
| dented | 38 | 62 | — | — |
| cracked | — | 0 | 0 | — |
| smoke | 1 | 4 | 7 | 10 |
| soot | 217 | 708 | 513 | 389 |

`cracked` correctly always 0 — metal's `crack_factor` is 0. Real per-wave
elapsed timestamps from the same run: 8/9/9/9/127/127/127/243/243/243/267/
304/431/438/443 ms (target cadence 0/40/.../560 ms) — real frame-quantization
drift, not compounding delay (wave 15 landed 443 ms after t0, not
15×whatever wave 14 took). Apply cost per wave: sub-1 ms for all but the two
biggest (899-cell destroy: 8.4 ms; 708-cell soot: 8.9 ms) — confirming
Task 0's own finding that the expensive part was always the old per-cell
*resolution*, which this whole rebuild eliminated from the wave path.

Visual: `Screenshots/history/e_wave_detonation.png` — a dark, irregular
scorch crater clearly visible on the floor, distinct from the clean tile
pattern around it. The first real, on-screen grenade damage since the
2026-08-05 reset.

## Verification (per CLAUDE.md's evidence discipline)

- `project_lint.py`: 188 files, 0 errors.
- `run_selftests.py`: 33/33 clean. New `detonation_choreographer_selftest.gd`
  drives `_apply_wave()` directly, in `WAVE_TABLE` order, against a real
  PLAYGROUND plan, and asserts every resulting cell (erasures, exposed
  reveals, dented, cracked, soot) matches its plan entry exactly, plus a
  real smoke-puff count on `SmokeSparkOverlay`. Every pre-existing
  selftest, including every `_set_voxel_cell()`/`apply_damage_voxel_swap()`
  seam test, still passes unchanged.
- `check_invariants.py`: OK. `gen_codemap.py --check`: clean (188 scripts).
- A separate real `weapon_fire` capture confirms firearms are unaffected.

## State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**, Task 0 through Task 5
  done. Phase A is functionally complete.
- **Task 6 (the tuning pass) is the next concrete action** — Director
  reviews the real capture/census and moves §4.2's ring-weight numbers
  (every one is a first-pass placeholder). Also where two flagged, real
  design questions get picked up if wanted: blast debris VFX (needs
  material threaded onto destroy plan entries) and §6.3's deferred-soot-
  compute question (not needed yet — measured plan cost is small).
- Stamped-blast soot's rotation-persistence (an event-replay list) stays
  deliberately unbuilt — camera rotation is still disabled (ROTATE-KILL-01),
  so it's currently unreachable to even test. Damage STATE (not soot)
  already survives rotation via the existing `record_voxel_damage_to_base()`
  path.
- Pushed to `main` (pending — see next message).
