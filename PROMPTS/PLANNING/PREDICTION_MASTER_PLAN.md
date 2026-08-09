# PREDICTION_MASTER_PLAN
## Simulate without committing: the engine's pure-prediction, pre-production and cache layer — v1.0

**Date opened:** 2026-08-09
**Status:** 🟢 **BUILDING. Task 1 (P-PLAY) shipped 2026-08-09 — see §8.1.** The
blast went from 3 frames to 24 and the expanding front is visible for the first
time. Tasks 2–6 (the purity refactor, the Delta, slicing, the cache, the
"cooking" beat) are planned and unbuilt. Every number below is measured on a
real PLAYGROUND detonation; every claim about what mutates comes from reading
the actual writers, not from the plan text of another document.
**Opened by:** the Director, 2026-08-09, when the explosion's pre-production
question turned out to be an engine question:

> *"Quero fazer da maneira mais definitiva e bem planejada, em quantas etapas
> forem necessárias. Não temos pressa e sim, a necessidade de deixar a engine
> perfeita. Vamos fazer um master plan para essa otimização. Isso vai ser
> fundamental para outros processos de previsão do game, inteligência dos
> guardas, informações no HUD etc. Queremos um cache e a pré-produção
> profissionais."*

**Relationship to other plans.** This plan owns *how the engine computes a
consequence without causing it*, and the cache/pre-production machinery around
that. It does not own what any particular consequence IS —
`EXPLOSION_REBUILD_MASTER_PLAN` still owns blast rules,
`DESTRUCTION_MASTER_PLAN` still owns damage semantics,
`AI_MASTER_PLAN` still owns guard behaviour. Explosions are this layer's first
consumer and its proving ground, not its owner.

---

## 0. The one-sentence idea

Today the only way to find out what a grenade does is **to detonate it**. The
engine has no way to ask *"what would happen if"* — so anything that needs a
preview (a throw arc, a HUD damage estimate, a guard weighing a route) has no
seam to ask through, and the one caller that exists pays the whole cost inside
the frame the player is watching.

This plan gives the engine a **pure `simulate()` that returns a Delta**, a
**`commit()` that applies one**, and a **cache** that lets a Delta be computed
early, held, discarded, and recomputed cheaply.

---

## 1. The measurement that opened this plan

Real PLAYGROUND, grenade index 0 (concrete), off-screen capture harness,
2026-08-09. Instrumentation added and **reverted before commit** (`grep -n
E-PREPROD-SPIKE` comes back empty).

### 1.1 Where a detonation's time goes

`DetonationPlanBuilder.build_plan()` blocks for **166–171 ms** (two runs:
166.4 ms, 170.7 ms) and **none of it appears in any existing log** — `[E-WAVE]`
starts its clock *after* `build_plan()` returns, so every performance
discussion this project has had about detonations has been measuring the
cheap half.

| # | Phase | Cost | Mutates Voxel state? | Scope |
|---|---|---|---|---|
| 1 | `flood_gu_rings` + `find_affected_containers` | 1.5 ms | no | blast |
| 2 | `apply_container_damage` × N + `apply_crater_damage` | **40.9 ms** | **YES** | blast |
| 3 | soot: index + `derive_soot_rings` ×2 + merge + `apply_self_soot` | **66.1 ms** | no (see §2.2) | **whole map** |
| 4 | `_voxel_occupancy` + `VoxelLightField.build()` | 35.2 ms | no | **whole map** |
| 5 | package + `_resolve_damaged_tile` per damaged voxel | 8.8 ms | no | blast |
| 6 | expose + soot-only wave + GU smoke remainder | 8.5 ms | no | blast |
| | **total** | **170.7 ms** | | |

Two consequences worth stating before any design:

- **The two map-wide phases (3 and 4) are 101 ms of the 171** and they do not
  get cheaper with a smaller grenade. They walk every voxel in the map. Any
  "make the blast smaller to make it faster" instinct is wrong here.
- **Only phase 2 mutates.** That is 41 ms of the 171 — the *cheap* part is the
  dangerous part. This inverts the assumption the pre-production idea started
  from.

### 1.2 Where the playback goes wrong

```
[E-WAVE] frame 1 cells=92/2185   elapsed=13ms   apply=2.865ms  dt=10.0ms   quota_target=92
[E-WAVE] frame 2 cells=2149/2185 elapsed=257ms  apply=21.109ms dt=226.0ms  quota_target=2149
[E-WAVE] frame 3 cells=2185/2185 elapsed=385ms  apply=0.579ms  dt=148.0ms  quota_target=2185
```

**The whole blast is three frames.** Frame 2 alone applies 2 057 of the 2 185
steps.

The cause is structural, not a tuning miss.
`DetonationChoreographer.cells_due_now()` derives its quota from
`elapsed_ms / sequence_ms` with `sequence_ms = 240`. One slow frame puts
`elapsed` past the deadline, and the quota becomes *the entire queue*. The
class documents this as intentional ("when frames are expensive the quota drags
the sequence forward"), and it is exactly the behaviour the Director described
as *"de repente a explosão já está toda construída"*.

**This is a separate defect from §1.1 and has a separate, much cheaper fix.**
Do not let the prediction work below block it — see §6.

---

## 2. The mutation inventory

The load-bearing survey. A plan that gets this wrong produces a `simulate()`
that silently damages the map.

### 2.1 Everything that writes Voxel state in the blast pipeline

Exactly **two functions**, seven call sites:

| Writer | File:line | Live callers |
|---|---|---|
| `apply_container_damage()` | `blast_calculator.gd:609–881` | `detonation_plan_builder.gd:171` (slices), `:187` (roofs) |
| `apply_crater_damage()` | `blast_calculator.gd:882–1103` | `detonation_plan_builder.gd:221` (floors) |

`Voxel.set_damage()` (`voxel.gd:103`) is the single write primitive, and its
whole surface is:

```
damage_state · damage_is_blast · damage_carved_side · damage_variant
· damage_substrate · visible (only when DESTROYED) · dirty (+ the parent
container's dirty counter, via _set_dirty())
```

Seven fields, one of them a counter on the container. That is the complete set
a Delta must carry and a rollback would have to restore.

### 2.2 The soot layer is ALREADY pure — this was the session's best finding

`derive_soot_rings()` (`:1104`), `stamp_container_soot()` (`:1259`),
`stamp_crater_soot()` (`:1316`) and `apply_self_soot()` (`:1398`) **never write
to a Voxel.** Every one of them reads Voxel state and writes only into the
`out_snapshot` / `out_faces` dictionaries the caller supplies. Verified by
scanning lines 1104–1400 for any `set_damage` / `.damage_* =` / `.visible =` /
`.dirty =` write: **zero hits.**

So phase 3's 66 ms — the single most expensive phase — is already exactly the
shape this plan wants everything to have: expensive, map-wide, and free of side
effects. It is a **model to copy, not a problem to solve.**

### 2.3 Firearms do not share the blast mutators

I flagged this as a risk to the Director before checking it, and **the check
reversed it.** Firearms do not call `apply_container_damage()` at all. D26/D27
replaced the old `find_affected_containers()` + `apply_container_damage()`
ring-scatter for CONE with N discrete pellet impacts, and D30 routed LINE
through the same path. `WeaponBenchController.fire_active()` mutates through
`BlastCalculator.apply_point_impact()` (`blast_calculator.gd:420`) — a
different function.

**Consequence: making the two blast mutators pure does not touch the firearm
path.** What genuinely stays shared, and must not be moved without its own
decision:

- `MaterialResistanceTable` — read by both. CLAUDE.md's standing warning holds.
- `derive_soot_rings()` / `apply_self_soot()` — also called by `room.gd:2172–2185`
  (the repaint path). Already pure, so this is a compatibility constraint, not
  a risk.
- `blast_calculator_selftest.gd` calls both mutators directly at ~10 sites.
  Those pin today's behaviour and must keep passing **unchanged** — they are
  the regression net for the purity refactor, not collateral to be updated.

### 2.4 What makes a prediction valid, and when it dies

`set_damage()` early-returns when `damage_state == new_state`, and D32/D3's
read-once rule means a second hit must not re-roll variant or substrate. So a
blast's outcome **depends on prior damage state**. A cached prediction is
therefore only valid against the world revision it was computed on.

Inputs a Delta depends on, all of which must key the cache (§5.2):

- every voxel's damage fields inside the blast's reach
- `room._gu_blast_count[gu]` (D2's deep-layer gate)
- the light field's inputs (lights, shadow results, `under_structure`)
- blocked edges / blocked cells
- the bomb definition
- the active perspective, for anything that resolves through view space

**Determinism is what makes pre-production safe.** Every roll in this pipeline
is an FNV-1a hash of a stable key (cell, container id, salt), never `randf()`.
So `simulate()` on an unchanged world returns a byte-identical Delta every
time — which is the property that lets a plan be computed early and trusted at
commit. §11's verification contract makes this an asserted invariant rather
than an assumption.

---

## 3. The architecture

### 3.1 Three concepts, named once

**`WorldDelta`** — a plain, inspectable description of *what would change*.
Never a mutation. Carries per-voxel damage field changes, the soot
snapshot/faces, the resolved tile triples, and the VFX descriptors (smoke,
expose). Today's `DetonationPlan` is already ~80% of this — it is a Delta that
happens to have been produced by mutating first.

**`simulate(action, world) -> WorldDelta`** — pure. Reads world state, writes
nothing. Deterministic (§2.4).

**`commit(delta, world)`** — applies a Delta's field writes to the real Voxels
and bumps the world revision. Cheap: it is a loop of field assignments, no
rolls, no resolution, no lookups.

The split is the whole plan. Everything else is machinery around it.

### 3.2 Why "pure simulate" and not "snapshot + restore"

Snapshot/restore was the cheaper-looking option and is rejected on evidence:

- It requires enumerating the restore set *perfectly*. A single missed field
  leaks permanent damage into the map, and the failure is **silent** — the same
  failure mode as the GPU-flush bug, which bit two independent call sites and
  was only ever caught by a real windowed capture.
- The restore set is not just the blast's voxels. Phase 3 is map-wide.
- It makes every future consumer (guard AI, HUD) pay the same risk. A guard
  evaluating four routes per turn would snapshot/restore four times per guard.
- It is strictly more code than purity, because a pure writer needs no undo.

Purity is also the only version of this that can ever run **off the main
thread** or **speculatively in parallel**, which §7's consumers will want.

### 3.3 The shape of the purity refactor

`apply_container_damage()` and `apply_crater_damage()` keep their signatures,
their rolls, their ring maths and their hash salts **byte for byte**. What
changes is the destination of the write: instead of calling
`voxel.set_damage(...)`, they append to an out-dictionary keyed by
`Vector3i(x, y, level)`.

The existing mutating behaviour is preserved as a thin wrapper that calls the
pure version and commits its result immediately — so `blast_calculator_selftest.gd`'s
~10 direct call sites keep passing untouched, which is exactly the regression
net this refactor needs.

Concretely:

```
simulate_container_damage(voxels, …) -> Dictionary   # pure, new
apply_container_damage(voxels, …)                    # = commit(simulate(…)), unchanged behaviour
```

The reads are the subtle part, not the writes: both functions currently read
`voxel.damage_state` **as they go** (a voxel destroyed earlier in the same pass
changes what a later voxel does — the cascade in `apply_container_damage()`'s
own neighbour logic). The pure version must therefore read through an overlay
that answers *"state as of this simulation so far"*, not *"state on the real
Voxel"*. **This is the single highest-risk detail in the refactor** and it gets
its own task and its own red-before-green test (Task 2).

### 3.4 What the Delta must expose for non-explosion consumers

A guard asking "what happens if I shoot at that wall" and a HUD asking "how
much of this cover survives" need *summaries*, not tile triples. The Delta
therefore carries the existing `[E-PLAN]` census as a first-class field rather
than as a `print()` — same numbers, queryable:

```
delta.census  →  per (surface, material): destroyed / dented / cracked
delta.touched →  Array[Vector3i]
delta.cost_ms →  what it took to compute (for the budget in §5.4)
```

---

## 4. Pre-production

### 4.1 What it is

Computing a Delta **before** the player commits to the action, so the cost is
paid during a moment the player is not watching a frozen camera.

With §3 in place this is safe by construction: a pre-produced Delta that is
never committed has changed nothing.

### 4.2 The Director's flow, restated

> *"No momento em que o jogador clicar em 'detonate', a parábola com a bolha
> indicativa já vai ter sido criada, e o mouse já vai estar sobre a GU
> selecionada. Quando ele der um hover (ou clicar na GU a primeira vez, no caso
> do celular) a gente já pode disparar a 'pré-produção'. No momento que ele
> atirar a granada, a parábola com o objeto já pode ser acionada, e a granada
> voa, caindo na GU marcada. Se por acaso o cálculo ainda não tiver sido
> finalizado, travamos o sistema aqui para ele finalizar. A granada fica
> 'cooking' no chão, até soltar a cena."*

Mapped onto the machinery:

| Moment | What happens |
|---|---|
| hover / first tap on a GU | `request_prediction(action)` — starts or reuses a time-sliced simulate |
| hover moves to another GU | previous request **cancelled**, not completed; cache keeps whatever finished |
| throw released | grenade tweens along the arc — free wall-clock for the simulate to finish |
| grenade lands, Delta ready | `commit()` + play the sequence |
| grenade lands, Delta NOT ready | **"cooking"**: the grenade sits, the sequence waits, no frozen camera |

The "cooking" beat is not a fallback. It is the honest visual for
*"the engine is still thinking"*, and it is the reason this design never needs
to hide a stall.

### 4.3 Time-slicing

A simulate must be interruptible at phase boundaries and cheap to abandon. The
six phases in §1.1 are the natural slice points; phases 3 and 4 (the map-wide
ones, 101 ms) need to subdivide further — by container for phase 3, by level
for phase 4.

**Budget per frame is a `var`, and the §1.2 lesson applies in reverse:** this
work writes no TileMapLayer cells, so unlike the choreographer it really is
per-work, not per-frame. Slicing it genuinely helps.

### 4.4 The cost target

Nothing here is worth doing if a hover costs 171 ms. The target is that a
prediction never blocks a frame by more than **one slice budget** (proposal:
4 ms, ~a quarter of a 60 fps frame), and that a full prediction completes
within the time a throw arc takes to play (~400–600 ms). Both are measurable
gates, not aspirations — see §8.

---

## 5. The cache

### 5.1 Why a cache at all

The Director's own reason, and it is the right one:

> *"O jogador pode decidir mudar de GU na última hora (é o mais provável, a
> gente só pára de ficar mexendo quando acerta a que estava buscando), então
> temos que jogar fora e começar de novo rapidamente."*

A player sweeping a cursor over ten GUs generates ten predictions, nine of them
discarded. Without a cache, coming back to a GU pays full price again — and
coming back is the common case, because the sweep is a comparison.

### 5.2 Key

```
(action_signature, world_revision)
```

`action_signature` = the action's own identity (for a blast: bomb id + target
GU + perspective). `world_revision` = a monotonic counter on the room, bumped
by **every committed mutation** — a detonation, a shot, a map load, a
perspective change, anything in §2.4's dependency list.

Bumping the revision invalidates the whole cache at once. That is deliberately
blunt: a precise dependency graph is a second system to get wrong, and the
common case (nothing changed while the player hovers) is served perfectly by
the blunt version. **Flagged as revisitable, not as final.**

### 5.3 Eviction

A Delta for one blast holds ~2 185 entries. Entries are small (a Vector3i key
and ~7 fields) but this is not free at scale.

Proposal: **LRU, bounded by entry count, default 8 predictions.** A cursor
sweep of eight GUs is a realistic worst case and eight Deltas is on the order
of 17 000 entries — acceptable. Anything larger is a symptom of a consumer
that should be asking for a census rather than a full Delta.

### 5.4 The workload is one cursor, not a guard swarm — settled 2026-08-09

This section used to argue that twelve guards evaluating candidate actions per
turn was the load that sized the cache. **The Director closed that (Q3): guard
AI is out of scope, gets its own system if it ever needs one, and is naturally
bounded anyway** — turn-based, TIC-based, AP-capped, each guard resolving its
own options individually.

So the sizing case is the one in §5.1: a player sweeping a cursor across GUs
and coming back to compare. §5.3's 8 entries covers that with room, and is a
settled number rather than a provisional one.

The seam stays pure and generic, which is what leaves the door open for reuse
(§7) — but nothing in this cache is shaped around a consumer that may never
arrive.

---

## 6. The playback defect — separable, and it should ship first

§1.2's three-frame collapse is **not** a prediction problem. It is the
choreographer's pacing rule, it has a self-contained fix, and it is what the
Director actually sees. It should not wait behind the refactor.

### 6.1 The fix

Pace the queue by **step count against a frame budget**, not by wall-clock
against a deadline. The blast then always takes the same number of frames
regardless of how expensive any one frame turned out to be, which is precisely
what "todos os frames bem visíveis, na duração certa" asks for.

The §1.2 measurement that must not be forgotten while doing this: **a frame
costs what it costs whether it writes 60 cells or 600**, because the cost is
Godot rebuilding dirtied `TileMapLayer`s once per frame. So the number of
frames is the thing being tuned, never the cells per frame. Reading the
`apply=` column while tuning this will make the blast slower while every log
number improves — that error has already been made once on this system.

### 6.2 The concentric-ripple question, answered honestly

> *"A gente consegue fazer o flow dos efeitos da explosão afetando círculos
> concêntricos de dentro para fora em volta do epicentro, como ondas na água de
> um lago?"*

**The radial ordering already exists and already ships.** E-RADIAL-01
(commit `04bfed1`) sorts every plan entry by its own distance from the
epicentre — that is exactly an expanding front. The reason it does not read
that way on screen is §1.2: the front expands across 2 185 steps and the queue
drains in 3 frames, so the eye sees two states, not a wave.

So: **fixing §6.1 produces the ripple with no new feature.** What is genuinely
new, and worth adding on top, is making the bands *legible*:

- **Radius quantization** — snap the front to discrete bands (proposal: one
  band per voxel of radius) so the wave advances in visible steps instead of a
  continuous smear. `front_jitter` (0.9) already ragged-edges the circle so
  bands will not read as machined rings.
- **Multiple ripples** — a second, weaker front trailing the first, if the
  Director wants a real lake-ripple read rather than a single expanding shell.
  **This is a look decision, not a technical one: Q1 in §10.**

### 6.3 The two tuning asks that ride along

Both are `var` edits with capture gates, and both belong to this same pass:

- *"Aumentar um pouco as dimensões e a duração do efeito do fogo"* —
  `blast_burst_*` in `room.gd:475–483`.
- *"Estender um pouco mais a duração do camera shake"* —
  `SHAKE_SECONDS` (0.7) in `test_zone_controller.gd:62`.

Note the existing comment on `SHAKE_SECONDS`: it was tuned to die with the
smoke, so extending it means extending the smoke's tail too or the camera will
be shaking at a settled scene. Flagged so the two move together.

---

## 7. The other consumers

Named now so the seam is designed for them, **built later, and not in this
plan's task list.**

- **Guard AI.** ⚠️ **Explicitly deferred by the Director 2026-08-09 (Q3), and
  possibly never a consumer of this layer at all** — *"se for necessário
  construímos um sistema separado."* Its load is bounded by construction
  (turn/TIC/AP, one guard at a time), so it imposes no requirement here. Listed
  only so the seam is not accidentally shaped in a way that would exclude it.
  `AI_MASTER_PLAN`'s FSM (Rule 4) and alert meter (Rule 5) are untouched either
  way — prediction would feed a decision, never make one.
- **HUD.** Damage/coverage estimates before committing an action. Needs the
  census and nothing else.
- **Targeting UI (Phase B of the explosion plan).** The blast-radius bubble is
  a prediction consumer, and the hover that drives it is §4.2's trigger.

**The constraint every one of these imposes on the design:** a consumer must be
able to ask for a *cheap summary* without paying for a *full Delta*. That is
why §3.4 splits them.

---

## 8. Tasks, in order

Sequenced so that the thing the Director can SEE ships first, and the risky
refactor lands behind a regression net.

| # | Task | Deliverable | Gate |
|---|---|---|---|
| **1** | ✅ **DONE 2026-08-09 — P-PLAY**, see §8.1 | Frame-count pacing (`front_frames`), band quantization (`band_voxels`), fire/shake tuning. `cells_due_now()` retired. No prediction work. | **Met.** 24 frames exactly on the real blast, heaviest frame 13.5% (was 94%); front advances 1.0→25.0 band by band; 3 pixel-diffed captures. Director sign-off pending on the look. |
| **2** | **P-PURE** — the purity refactor | `simulate_container_damage()` / `simulate_crater_damage()`; existing mutators become `commit(simulate(…))`. §3.3's read-overlay is the hard part. | **`blast_calculator_selftest.gd` passes with ZERO edits** — it is the net, not collateral. Plus a new red-before-green test: `simulate()` on a real PLAYGROUND blast leaves all 7 fields of every voxel untouched, asserted by before/after field snapshot over the full affected set. Byte-identical Delta from `simulate()` and from the committed path. |
| **3** | **P-DELTA** — `WorldDelta` as a real type | Today's plan Dictionary becomes an inspectable Delta with §3.4's census as a field. `DetonationPlanBuilder` produces one; `commit()` consumes one. | `run_selftests.py` clean. A real detonation is pixel-identical to the pre-refactor one — the same 0-differing-pixels gate Task 1a of the explosion plan used. |
| **4** | **P-SLICE** — time-sliced simulate | Phases interruptible and cancellable; map-wide phases 3/4 subdivided. | Measured: no single frame blocked >4 ms during a full prediction; full prediction completes <600 ms. Cancellation proven to leave zero state behind. |
| **5** | **P-CACHE** — the cache | §5's keyed, revision-invalidated LRU. `request_prediction()` / cancel / reuse. Sized for one cursor, not for guard AI (Q3). | A scripted 10-GU cursor sweep: measured hit rate on return-to-a-previous-GU, and a proof that every committed mutation invalidates. |
| **6** | **P-COOK** — the "cooking" beat | §4.2's wiring for the detonate path that exists TODAY (context menu), so the flow is real before Phase B's throw arc exists. | Real capture: camera never freezes; the 171 ms is gone from the visible beat. |

**Phase B of `EXPLOSION_REBUILD_MASTER_PLAN` (throw arc, bubble, hover) plugs
into Task 5's seam and is planned there, not here.**

### 8.1 Task 1 (P-PLAY) closure — 2026-08-09

Shipped as specified, with the Director's Q1/Q2 answers taken as given
(visible bands; ~0.4 s / 24 frames).

**What changed.** `cells_due_now()` is gone. `front_radius_for()` advances the
front linearly in **frame index** and snaps it down to a `band_voxels`
multiple; `steps_within()` scans the already-sorted queue up to that radius.
`sequence_ms` and `min_cells_per_frame` are deleted — no wall-clock term
survives anywhere in the pacing path, which is the property that makes the
collapse unreachable rather than merely unlikely.

**The real blast, before → after** (same grenade, same map, same harness). The
24-frame column is what shipped first and what the Director then judged too
slow; the 5-frame column is what stands (Q2's re-answer).

| | before | 24 frames | **shipped (5)** |
|---|---|---|---|
| frames | **3** (whatever the clock said) | 24 | **5** |
| heaviest single frame | 2 057 / 2 185 (**94%**) | 294 / 2 185 (13.5%) | 952 / 2 072 (**45.9%**) |
| front radius per frame | not a concept | 1.0 → 2.0 → … → 25.0 → ∞ | 5.0 → 10.0 → 15.0 → 20.0 → ∞ |
| per-frame cells (real map) | 92 / 2 057 / 36 | — | 278 / 604 / 952 / 203 / 35 |

**45.9% on one frame is the honest price of the speed, and it is not the
collapse coming back.** A radial front advances at a constant rate through
SPACE — that is what makes it read as a shockwave — while the cells in each
band follow the annulus area, so the middle band dominates whenever the frame
count is small. Pacing by equal WORK per frame would flatten the profile and
was rejected: it would make the wave crawl through dense regions and jump
through sparse ones, which is not what an explosion does.

**Captures** (hand-named, rotation-proof): `p_play_fast_f2.png` … `f5.png`, one
per frame of the shipped 5-frame sequence, taken through
`INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES`.

**The capture that matters most is `p_play_fast_f5.png`, and it is bad news for
the look, not for the pacing:** the crater is complete (2 072/2 072) and the
scene is still fully washed by the negative flash. See Q5 — at 5 frames the
whole sequence finishes inside the flash's 0.32 s fade.

**Three things worth recording because they are easy to misread later:**

1. **`elapsed` in the `[E-WAVE]` log is harness time, not blast time.** The
   off-screen capture harness renders at ~8 fps, so a 5-frame blast logs
   ~620 ms there and is ~83 ms at 60 fps. Duration scaling with frame rate is
   the deliberate trade in the choreographer's header.
2. **The 24-frame captures understated the flash overlap** (`p_play_front_*`,
   now superseded and deleted). At ~8 fps, frame 11 lands 1.3 s in — long past
   the flash. At 60 fps the same frame lands at 183 ms, inside it. Any future
   judgement about what the player SEES during a blast has to correct for the
   harness's frame rate or it will be wrong in this exact direction.
3. **A frame applying zero cells is legitimate**, not a stall — the front is
   crossing empty space between a dense band and a sparse rim. Documented on
   `steps_within()`; the last frame's `INF` guarantees termination regardless.

**Selftest.** `detonation_choreographer_selftest` test 5 was **replaced, not
relaxed.** Its third assertion had been pinning the bug verbatim ("past the
deadline the whole queue is due at once — the blast finishes on time at any
frame rate"). Four assertions now stand in its place: exact frame count with no
wall-clock input, a bound on the heaviest frame, front monotonicity, and
band-boundary alignment.

**One threshold moved, and the reason is recorded in the test itself so it is
not mistaken for weakening.** 5b first shipped at "< 50% of the queue on any
one frame", written while `front_frames` was 24 (even split 4.2%, measured
13.5%). At 5 frames the even split is 20% and a healthy sequence measures
45.9% on the real map, 53.7% on the fixture — so a flat 50% fails correct code.
The bound is now 70%, anchored to the collapse it exists to catch (94%) rather
than to any even-split multiple, and the test prints the full per-frame profile
so the distribution is visible instead of hidden behind a pass. **5a is the
primary guard** — the collapse's real signature was a frame count that ignored
`front_frames` entirely, and 5a makes that unrepresentable.

**Not done, and not silently dropped:** §6.2's optional second trailing ripple.
The Director chose visible bands over multiple ripples, so it was not built.

### 8.2 P-STROBE — the detonation becomes three beats (2026-08-09)

Q5's answer, and it went further than the question asked. The detonation is no
longer one beat with a fade running under it:

| beat | what | length |
|---|---|---|
| 1 · FIRE | burst + camera shake, alone | `burst_lead_frames` = 3 frames |
| 2 · STROBE | white → negative → white → negative, fire still burning under it | 4 held frames |
| 3 · DESTRUCTION | the radial front, with no flash over it at all | `front_frames` = 5 frames |

**The timed fade is deleted, not shortened** — `flash()`, `_process()`,
`flash_fade_seconds`, `flash_fade_power`, `flash_peak_alpha` and
`flash_max_step_seconds` are all gone, replaced by `hold_frame(mode)` +
`clear()`, driven one frame at a time by the caller.

**Why that deletion is a simplification and not a cleanup:** the last of those
vars is the E-FLASH-03 fix. The frame the flash started on was also the frame
the destruction landed on, measured at **150 ms** against 8–17 ms for its
neighbours, so the fade advanced by that whole delta and burned half its curve
in one step. **A frame-driven strobe cannot express that bug** — there is no
curve to burn, and a slow frame makes a strobe frame *last* longer, which is
correct, rather than skipping most of it. The measurement is preserved in the
overlay's header as the reason never to put a wall-clock term back.

**Verified by luminance, not by eye.** Each frame of the sequence was captured
separately and measured against an undetonated baseline of **61.9** — the scene
is DARK, so a negative frame is the *bright* one (~193 predicted):

| wait | mean luminance | reading |
|---|---|---|
| 2, 3 | 62.6, 63.5 | normal — beat 1, fire alone |
| 4 | 237.3 | **WHITE** |
| 5 | 176.3 | **NEGATIVE** (short of 193 because HUD/dev overlays draw above the negative layer and are not inverted) |
| 6 | 236.9 | **WHITE** |
| 7 | 177.1 | **NEGATIVE** |
| 8 | 62.8 | normal — beat 3, destruction clean |

Captures: `p_strobe_1_fire_only.png`, `p_strobe_2_white.png`,
`p_strobe_3_negative.png`, `p_strobe_4_clean_destruction.png`. The negative
frame also confirms E-NATIVE-01's layer ordering survived — the world inverts
while the fire on top stays orange, because the negative layer sits BELOW
ember/smoke.

**One assumption, flagged rather than buried.** "Depois do último frame" of the
fire has no referent any more: E-NATIVE-01 deleted the authored 4-frame
fireball, so the fire is particle overlays with 0.5–1.25 s lifetimes and
waiting for its true end would put the strobe a full second after the bang. It
is read as "after the burst has visibly established itself" —
`burst_lead_frames = 3`, a starting value for the Director's eye, not a derived
one.

**And one instruction that was already satisfied, measured rather than
assumed:** "o fogo… permanece acontecendo durante os 4 frames do flash". The
whole strobe is 3 + 4 = 7 frames ≈ 117 ms at 60 fps, against a fire whose
*shortest* ember already lived 400 ms. The lifetime bump that shipped
(0.40–1.05 → 0.50–1.25 s) is therefore for the look the Director asked for, not
to cover the strobe — recorded because "extend it so it covers X" is exactly
the kind of line that later gets re-read as a constraint.

**Known and not fixed:** `hold_frame()` runs no timer, so a caller that never
calls `clear()` leaves a frame held. That is the deliberate cost of the caller
owning every frame; the bound is `Room.clear()`, which every map reload and
perspective change already routes through.

### 8.3 P-FILM — the filmstrip rig (2026-08-09)

Director: *"queria ver se a gente consegue fazer um filmstrip com todos os
frames da explosão pra analisar a sequência com mais calma."*

`tools/persistent/build_filmstrip.py` + a `detonation_filmstrip` capture action
in `room.gd`. One command, one contact sheet:

```
python3 tools/persistent/build_filmstrip.py --frames 24 --grenade 2 --cols 6
```

**Two design points, both of which the obvious version gets wrong** — and both
were live mistakes in this session's own earlier captures:

1. **ONE detonation, not one boot per frame.** Every capture before this was a
   separate Godot boot, i.e. a separate blast. `Room.spawn_blast_burst()`
   places embers with `randf_range()`, so a strip stitched from separate runs
   shows the fire jumping between tiles. Every frame now comes from one blast.
2. **`--fixed-fps 60` is load-bearing, not tidiness.** A full GPU→CPU readback
   per frame drags real frame time to a crawl. The destruction front and the
   strobe are frame-driven and survive that exactly — but fire and smoke
   advance on DELTA, so at the harness's real ~8 fps they age ~7× too fast per
   frame and the strip would misrepresent precisely the effect being judged.
   `--fixed-fps` pins every delta to 1/60 s.

One capture artifact found and fixed by looking at the first sheet:
`detonate_active()` is called directly (it needs the `_active_index` that
`open_menu_for()` sets), which never reaches the button handler that normally
closes the menu — so "Detonate (Enter) / Cancel (Esc)" sat over the blast in
every tile. `_context_menu.close()` now follows the call.

**What the first clean sheet shows, frame by frame** — the three beats are
exactly as specified: frames 0–2 fire alone with the floor intact, frames 3–6
white/negative/white/negative, frames 7–11 the destruction, frames 12+ the
smoke tail.

**And what it surfaced that the Director should decide (Q6):** the two WHITE
strobe frames are effectively total white-outs. Measured on the real frames,
centre crop, brightness out of 765:

| frame | range | max saturation |
|---|---|---|
| 3 (white) | **643–765** | 97 |
| 4 (negative) | 174–765 | 94 |
| 5 (white) | **651–765** | 90 |

A white frame compresses the entire image into the top 16% of the brightness
range. The fire is genuinely still rendered (saturation 97 proves colour is
present) but has almost no contrast against it — so *"o fogo… permanece
acontecendo durante os 4 frames do flash"* holds on the negative frames and is
visually lost on the white ones. `strobe_white_alpha` (currently 1.0) is the
one lever.

---

## 9. Explicitly out of scope

- **Threading.** Purity makes off-thread simulation *possible*; nothing here
  schedules it. A separate decision when a real workload demands it.
- **Rewriting the firearm path.** §2.3 established it does not share the blast
  mutators. `apply_point_impact()` gets the same treatment only if a consumer
  needs to predict a shot — not pre-emptively.
- **A precise dependency graph for cache invalidation.** §5.2 ships the blunt
  world-revision version on purpose.
- **Guard AI or HUD consumers themselves.** §7 designs the seam for them and
  stops there.
- **`MaterialResistanceTable` tuning.** Shared with firearms; untouched by this
  plan, per CLAUDE.md's standing warning.

---

## 10. Open questions for the Director

### Q1 — ✅ ANSWERED 2026-08-09. Visible bands.

One expanding front, quantized into discrete bands (`band_voxels = 1.0`) —
chosen over both a continuous front and a genuine second trailing ripple. The
trailing ripple is therefore **not built**, and if it is ever wanted it needs
its own decision about what the second wave carries, since destruction can only
happen once per voxel.

### Q2 — ✅ ANSWERED 2026-08-09, then RE-ANSWERED the same day on the real thing. 5 frames.

First answer was 24 frames, reasoned from 60 fps (≈0.4 s). The Director ran it
and rejected it: *"ficou ótima a explosão, mas está muito lenta, tem que ter
mais ou menos 1/5 dessa duração (desconsidere a fumaça que já está boa)."*
`front_frames = 24 → 5`.

**Why the 60 fps arithmetic was wrong, and it is this plan's own measurement
that should have caught it:** a blast frame is by definition a frame that
dirties a `TileMapLayer`, which is the expensive kind (§1.2). Duration is
`front_frames × the cost of a blast frame`, never `front_frames × 16.7 ms`.
Frame-count pacing is still right — it is what makes every frame visible — but
its duration must be judged on the running game, never computed from a target
frame rate.

**Smoke deliberately untouched:** puffs are emitted as queue steps, but each
one's lifetime is set in `DetonationPlanBuilder`, so a 5× faster front emits
the same cloud sooner without shortening it.

**Surfaced by the change, and NOT decided here — see Q5.** At 5 frames the
entire destruction completes inside the negative flash's own 0.32 s fade, so
the expanding front is hidden under it.

### Q5 — ✅ ANSWERED 2026-08-09. Shorten it, and separate the three beats. See §8.2.

> *"Com certeza, vamos encurtar o flash. E também vamos tentar o seguinte:
> separar o fogo, do flash, da destruição. A duração do fogo está boa. Depois
> do último frame, entra: 1 flash frame branco, 1 frame negativo, outro frame
> branco, outro frame negativo. O fogo se extende mais um pouco e permanece
> acontecendo durante os 4 frames do flash. Em seguida: frame positivo com a
> destruição limpa acontecendo."*

The answer went past (b) — the flash is not merely shorter, the timed fade is
gone entirely and the detonation is three explicit beats. Shipped as P-STROBE,
recorded in §8.2. Original framing kept below.

<details><summary>Original framing, 2026-08-09</summary>

`ExplosionFlashOverlay.flash_fade_seconds` is 0.32 s. At `front_frames = 5` the
whole sequence is ~83 ms at 60 fps, so **100% of the destruction now happens
under the flash** — real capture `p_play_fast_f5.png` shows the crater already
complete (2072/2072) with the scene still fully washed.

At 24 frames roughly the last fifth of the sequence was clear of it; at 5,
none is. So the radial front built this session is, at the shipped numbers,
invisible.

Recorded honestly: **the harness captures that closed Task 1 understated this.**
They were taken at ~8 fps, where frame 11 lands 1.3 s after the flash is gone;
at 60 fps that same frame lands at 183 ms, inside it.

Options: (a) leave it — an explosion that is a flash, then an aftermath, is a
legitimate read; (b) shorten `flash_fade_seconds` so the front clears it;
(c) drop `flash_peak_alpha` so the front shows through.

*Assumed if unanswered:* nothing — this is a look call and the Director is
actively tuning.

</details>

### Q3 — ✅ ANSWERED 2026-08-09. Out of scope; do not size the cache for it.

> *"A IA dos guardas ainda não vamos entrar por enquanto. Se for necessário
> construímos um sistema separado. Considerando que trabalhamos sempre por
> turno e por TIC, com limite de AP, acredito que a performance não tem muitas
> travas limitantes. E cada guarda vai processar suas opções individualmente (a
> não ser em casos de comunicação, alarmes, etc). Enfim, vamos focar na
> explosão por enquanto, só deixando a porta aberta para reaproveitar o que for
> útil posteriormente."*

**This retires §5.4's sizing pressure entirely.** The load I had assumed —
twelve guards each evaluating several candidate actions — is not the workload:
the game is turn-based and TIC-based with an AP ceiling, and each guard
resolves its own options individually. That is naturally serialized and
naturally bounded, so it does not need a cache built around it, and it may not
share this one at all ("um sistema separado" if it comes to that).

**Consequences, applied:**

- **§5.3's LRU sizing is now a player-facing question only** — the real worst
  case is one cursor sweeping GUs, not N guards × M actions. 8 entries is
  comfortably right for that and is no longer provisional.
- **§3.4's census/Delta split stays**, but its justification changes: it exists
  for the HUD and for cheap previews, not to protect a cache from guard AI.
- **§7's "designed for them" framing is downgraded to "not designed against
  them."** The seam stays generic and pure, which is what keeps the door open;
  nothing further is shaped around a consumer that may never arrive.
- **Task 5's gate loses its AI clause.** It is measured on a scripted cursor
  sweep alone.

### Q6 — How white should the white strobe frames be? 🟡 NEW 2026-08-09, one number

§8.3's measurement: at `strobe_white_alpha = 1.0` a white frame puts the whole
image in the top 16% of the brightness range, so the fire that is supposed to
keep burning through the strobe is rendered but invisible. Options: leave it
(a white-out is a legitimate strobe), or drop the alpha to ~0.85 so the world
and the fire read through it.

*Assumed if unanswered:* nothing — the Director is actively tuning the look and
now has the filmstrip to judge it from.

### Q4 — Does the "cooking" beat get its own visual? 🟢 Task 6 only

A grenade waiting on the engine is a fuse burning. Is that a real animation you
want to author, or is the existing prop plus the smoke enough?

---

## 11. Verification contract

Non-negotiable, per CLAUDE.md's evidence discipline. Every task closes against
these, with pasted literal output — never a reasoned expectation.

1. `project_lint.py` — zero real compile errors, zero new warnings in any file
   touched.
2. `run_selftests.py` — clean. **Baseline for this plan: 33/33 clean,
   `project_lint` 190 files / 0 errors, measured 2026-08-09 before any work.**
3. `check_invariants.py` + `gen_codemap.py --check` — clean.
4. **The purity invariant, asserted not assumed:** after any `simulate()`, a
   before/after snapshot of all 7 mutable fields (§2.1) across the entire
   affected set must be identical. This is the test that makes the whole plan
   safe, and it is red-before-green against the CURRENT code.
5. **The determinism invariant:** two `simulate()` calls on an unchanged world
   return byte-identical Deltas. §2.4 argues this is already true; the test is
   what keeps it true.
6. **Real captures, hand-named** (`p_play_*.png`, `p_cook_*.png`) so they
   survive the 50-file `auto_` rotation — CLAUDE.md's own rule for anything
   cited long-term.
7. **A green selftest does not close a task.** The real PLAYGROUND path runs
   and its real numbers get read. This project has already shipped a feature
   that passed its fixture with 69 dents and produced zero on the real map.

---

## 12. What this plan does NOT claim

- That 171 ms is slow on the Director's machine in a real window. It was
  measured in the off-screen capture harness. **The phase RATIO is what to
  trust; the absolute constant is not.** Phase 2/3/4 being 87% of the cost is
  robust; "171 ms" is not.
- That the six phases are the right slice boundaries. They are the obvious
  ones; Task 4 measures whether phases 3 and 4 subdivide cleanly.
- That the cache sizes in §5.3 are right. They are proposals pending Q3.
