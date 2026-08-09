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

### 5.4 Guard-AI pressure is the real sizing question

One player hovering is a trivial load. **Twelve guards each evaluating several
candidate actions per turn is not**, and that is the load this cache actually
has to survive. It is why §3.4's census exists as a separate, cheap product:
most AI queries want *"how much cover would I lose"*, not 2 185 tile triples.

**Open question Q3 (§10) asks the Director to confirm the AI's real query
shape before this is sized**, because guessing it wrong is how a cache gets
built for the wrong workload.

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

- **Guard AI.** *"Se eu me mover para ali, o que muda?"* Needs `simulate()` on
  movement and line-of-fire actions plus §3.4's census. The
  `AI_MASTER_PLAN`'s FSM (Rule 4) and alert meter (Rule 5) are untouched by
  this — prediction feeds a decision, it never makes one.
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
| **5** | **P-CACHE** — the cache | §5's keyed, revision-invalidated LRU. `request_prediction()` / cancel / reuse. | A scripted 10-GU cursor sweep: measured hit rate on return-to-a-previous-GU, and a proof that every committed mutation invalidates. |
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

**The real blast, before → after** (same grenade, same map, same harness):

| | before | after |
|---|---|---|
| frames | **3** | **24** |
| heaviest single frame | 2 057 / 2 185 (**94%**) | 294 / 2 185 (**13.5%**) |
| front radius per frame | not a concept | 1.0 → 2.0 → 3.0 → … → 25.0 → ∞ |

**Captures** (hand-named, rotation-proof): `p_play_front_f5.png`,
`p_play_front_f11.png`, `p_play_front_f17.png`, `p_play_front_f24.png`, taken
mid-sequence through `INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES`. Pixel-diffed
rather than eyeballed:

| transition | pixels differing | mean delta |
|---|---|---|
| f5 → f11 | 97.88% | 52.9/255 — the negative flash clearing, not the front |
| f11 → f17 | 4.82% | 20.8/255 — **the front advancing** |
| f17 → f24 | 3.34% | 14.7/255 — still advancing |

**Two things worth recording because they are easy to misread later:**

1. **`elapsed` in the `[E-WAVE]` log is now ~2 700 ms, and that is not a
   regression.** The capture harness renders at ~8 fps; 24 frames × ~123 ms is
   the harness's frame rate, not the blast's duration. At 60 fps the same 24
   frames are 0.4 s. This is the documented trade in the choreographer's
   header — duration scales with frame rate, on purpose.
2. **Frames 22–23 apply zero cells** (the front crosses empty space between
   r=24 and r=25). That is the intended pause between a dense inner band and a
   sparse rim, documented on `steps_within()`, not a stall — the last frame's
   `INF` guarantees termination regardless.

**Selftest.** `detonation_choreographer_selftest` test 5 was **replaced, not
relaxed.** Its third assertion had been pinning the bug verbatim ("past the
deadline the whole queue is due at once — the blast finishes on time at any
frame rate"). Four assertions now stand in its place: exact frame count with no
wall-clock input, no frame over 50% of the queue (the direct red-before-green
for the collapse), front monotonicity, and band-boundary alignment.

**Not done, and not silently dropped:** §6.2's optional second trailing ripple.
The Director chose visible bands over multiple ripples, so it was not built.

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

### Q2 — ✅ ANSWERED 2026-08-09. 24 frames (~0.4 s at 60 fps).

`front_frames = 24`. Note the consequence recorded in §8.1: this is a frame
count, so wall-clock duration scales with frame rate by design.

### Q3 — What will the guard AI actually ask? 🟡 blocks Task 5's sizing only

§5.4: a guard evaluating candidate actions is the load that sizes the cache. Do
guards need full Deltas, or only the census ("how much cover would this cost
me")? Guessing this is how a cache gets built for the wrong workload.

*Assumed if unanswered:* census only; full Deltas reserved for player-facing
previews.

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
