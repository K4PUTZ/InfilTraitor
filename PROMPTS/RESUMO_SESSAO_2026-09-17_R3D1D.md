# SESSION SUMMARY — 2026-09-17
## RENDER3D: R3D-1d CLOSED — `VoxelStore` is the writer, `Voxel` is a thin claim wrapper, Moto remeasured

**Director's request:** *"Vamos seguir com R3D-1d."* R3D-1c had closed the day before with
all five readers on the store; R3D-1d is the stage that removes the ~216 104 `Voxel`
objects themselves (~191 MB on the Moto, R3D-0).

**Full record:** [`RENDER3D_MASTER_PLAN`](PLANNING/RENDER3D_MASTER_PLAN.md) v1.6, the
R3D-1d section and the status block at the top.

---

## 1. The plan, and the Director's call on `Voxel`'s fate

R3D-1d's own text had left one thing open: "the `Voxel` class becomes an index or a
transient view, or is deleted, as R3D-1a decides" — it hadn't, actually. Asked directly,
the Director picked **a thin index wrapper**: `Voxel.new()` keeps its exact call shape
everywhere (`.set_damage()`, `.damage_state`, `Slice.get_voxel(i)`, …), but behind that
surface it becomes `claim:int` + a `VoxelStore` reference, not a second copy of state.

A staged plan (5 steps, mirroring R3D-1c's own methodology — one subsystem at a time,
`BoardProbe` first, Moto timing second, never a batch rewrite) was written to
`/Users/mateus/.claude/plans/rosy-gathering-rain.md` and approved before any code moved.

## 2. Step 1 — `VoxelStore` becomes the writer (commit `75b97af6`)

- `VoxelStore.set_damage()` / `set_visible()` write the packed `state`/`aux` arrays
  directly. **Range-validated, never a silent wrap:** an out-of-range `variant`/
  `carved_side`/`substrate` aborts loudly (`push_error`, no write) instead of getting
  masked into a different, valid-looking value — the exact failure
  `board_probe_selftest.gd`'s own TEST 5 exists to catch, and would have caught silently
  passing under a naive `&15` mask.
- `godot/scripts/geometry/voxel.gd` rewritten: the seven duplicated damage/visibility
  fields are gone. `claim:int` plus computed properties (`get`/`set` blocks) read/write
  through `VoxelStore.active` by claim — same public surface, zero caller-visible change.
- **A detached `WorldDelta` projection** (`project_voxel()`, no container, no claim) still
  needs to hold its own field values with nothing to read from a store. Solved with a lazy
  `_LocalState` side object (`_local: _LocalState = null`) — costs one null reference on
  every real voxel, and only the rare, ephemeral projection actually allocates it.
- **The real casualty count:** the plan estimated ~10 selftests building raw `Voxel`
  objects (from a `Voxel.new(` grep); the real number was **16**, because several tests
  build real geometry through generators and only THEN call `set_damage()`/`set_visible()`
  without ever building a `VoxelStore` over the fixture — invisible to that grep. Every one
  was updated in this same step (never batched): each now builds a `VoxelStore` over its
  own fixture (or the real registries, for the four tests that boot a real Room) before
  writing, since a claimless `Voxel` now refuses a write loudly instead of silently no-oping.
- **A real cross-fixture bug found and fixed along the way** (not caused by the
  architecture change, but only visible once writes went through a shared active store):
  several tests built TWO synthetic fixtures back-to-back and read the first one's result
  AFTER the second fixture's own `VoxelStore.build()` had already replaced
  `VoxelStore.active` — the first fixture's voxels were reading the wrong store's arrays by
  the time they were checked. Fixed by reordering every such test to read a fixture
  immediately after applying to it, before building the next one.
- **Gates:** `project_lint` 0 errors, `run_selftests.py` 57/57, `check_invariants`,
  `gen_codemap --check`, `board_probe.py gate` — all pass.

## 3. Steps 2-4 — explored, then DEFERRED to R3D-2 (Director, same session)

The plan's step 2 was migrating `cell_to_voxel`/`damaged_voxels` (5 independent local
dicts across `room.gd`, `blast_calculator.gd`, `detonation_plan_builder.gd`,
`agent_shot_controller.gd`, `weapon_bench_controller.gd`) from `Voxel`-object VALUES to
bare `claim:int`. A dedicated research pass mapped every read/write site before touching
anything, and surfaced two findings that changed the cost/benefit:

1. **`detonation_plan_builder.gd` structurally resists the migration.** Its
   `damaged_voxels` can legitimately hold **claim==-1 detached projections**
   (`WorldDelta.project_voxel()`, the W-PRECOOK-02 precook path) — a bare int has nowhere
   to read the projected state from. And `cell_to_voxel` is read back as a full live
   `Voxel` object in at least four places (`_phase_package`'s `touched_voxels` for
   VL-PERSIST, `delta.state_of()`/`projection_of()`, `.container_id()`) — none of which
   migrate to a bare int without either a claim→Voxel resolver on `VoxelStore` or a
   `WorldDelta` API change, neither of which existed.
2. **The memory case for the other four files evaporated once Step 1 landed.** `Voxel`'s
   properties already dispatch through `VoxelStore` by claim — reading `voxel.damage_state`
   off a `Voxel` sitting in a dict already *is* a claim-keyed read, wearing a clean
   accessor. Storing a bare `claim:int` instead would only move the bit-unpacking
   (`(store.state[claim]>>1)&3`, …) into every call site by hand — worse legibility, same
   cost, and for memory that was never the problem (these dicts hold tens of entries per
   shot/detonation, not 215 432).

Presented to the Director in two rounds (first: reduced scope vs. full scope with a new
claim→Voxel resolver; then, after starting the reduced-scope work and hitting the same
"no real benefit" wall in the "safe" files too: skip straight to Step 5). **The Director's
call: skip steps 2-4 entirely, formally deferred to R3D-2** — which re-keys the plan and
`WorldDelta` around a render-neutral store read anyway, so this rides along with that
redesign instead of paying for it twice. Documented in the master plan (commit
`3daf9447`) with the reasoning, not just the decision, so a future reader doesn't have to
re-derive it.

## 4. Step 5 — the Moto remeasure (device connected mid-session, commit `f68118cc`)

No `adb` in the agent's own environment; found it under
`/opt/homebrew/share/android-commandlinetools/platform-tools/adb` once the Director
connected the Moto g04s (`ZF524T5TG5`). Exported and installed the current build, then
ran R3D-0's own instrument (`alloc objects|packed|bytes <count>` scenario step, read by
`device_run.py --mem-poll`):

| run | `alloc packed 215432` (control, ~0.82 MB expected) | `alloc objects 215432` |
|---|---|---|
| b | +0.83 MB | **+87.2 MB** |
| c | +0.85 MB | **+140.2 MB** |
| d | +0.84 MB | **+100.4 MB** |

- The control lands within 0.02 MB of expected every run — the instrument is calibrated.
- **215 432 thin `Voxel` wrappers cost 87–140 MB, median ~100 MB (~424–682 B each,
  median ~465 B) — against R3D-0's ~190 MB / ~925 B for the old object. Roughly half.**
- 3 single boots, not R3D-0's 16 interleaved (the device arrived mid-session) — the spread
  is real run-to-run variance (R3D-0 hit the same zram-compression confound and needed the
  16-boot median to see through it), so this is a confirmatory remeasure, not a new
  headline number to re-cite precisely elsewhere.
- **Hot-loop risk check** (packed-array access vs. object field read, the plan's own named
  risk): one real PLAYGROUND grenade detonation ran 220 frames / 20.1 s wall clock, mean
  91.3 ms, worst 298.3 ms — same order as R3D-1c step 5's closing numbers (18.0–18.4 s per
  grenade). Not an exact A/B (different seed/count, one boot), but no regression signal.
- Logs (local, not tracked): `/tmp/r3d1d_step1_memcheck_{b,c,d}.log`,
  `/tmp/r3d1d_step1_grenade2.log`.
- The device's `dev_flags.cfg` was removed after measuring, so the Director's next normal
  boot doesn't land in a scenario.

## 5. R3D-1d is CLOSED

Step 1 is the architectural change; steps 2-4 are deferred to R3D-2 with the reasoning on
record; step 5 confirms the win. Commits, in order: `75b97af6` (step 1),
`3daf9447` (docs: step 1 closed, steps 2-4 deferred), `f68118cc` (docs: step 5 measured,
closed).

## 6. Next session

1. **R3D-2** — render-neutral world state: the plan/`WorldDelta` re-keyed around a store
   read, `build_occupancy()` becomes a store read plus the predicted-destroyed overlay,
   plane writes iterate the store not `layer.get_used_cells()`. This absorbs the
   `cell_to_voxel`/`damaged_voxels`/plan-key migration deferred above.
2. The rotation / SaveState damage-loss task (R3D-1b finding), if the Director starts it.
3. The junction column id task (from R3D-0), if the Director starts it.
4. The VoxelStore shadow-mirror cleanup flagged mid-session (`mirror()`/
   `writes_mirrored`/`writes_unknown_container`/`writes_misplaced` in `voxel_store.gd` are
   now dead weight since `Voxel` writes go straight through `set_damage()`/`set_visible()`
   — a pending chip, not yet started).
