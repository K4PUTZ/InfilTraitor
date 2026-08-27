# SOOT_STORAGE_REFORM
## The soot map becomes the source of truth — plan, 2026-08-27

**Status:** 🟢 **SS-0 … SS-3 DONE — THE STORE IS THE SOURCE OF TRUTH AND THE
COMMIT IS ITS SEAM.** The repaint still derives (SS-5 removes that). Gates in
§5.1–§5.3. ⚠️ §5.1 carries a CORRECTION to a number SS-1 reported, and **§5.3 is
an open DESIGN question for the Director** that SS-3 surfaced: the store now keeps
scorch for voxels the fire consumed.
⚠️ **SS-0 demoted this plan's own headline motivation** — PERF-P3 already killed the §9.11a flicker, and the §9.11b guard is inert by default. Measured, not reasoned: §1.1b. The reform still stands, on the Director's design ask, on §1.2's structural wins, and on §3.4.
**Both open questions were answered the same day (§6), and one of them changed
the plan:** rotation was disabled for **performance**, not because the game is
single-sided, so the store is keyed in base space — and that forced out §2.1b,
**the per-face soot format is view-space and cannot survive a rotation.** The
save model is the Sonic-post one: scenario state lives from checkpoint to
checkpoint and dies with the level (§3.3).
**Authority:** Director's ruling, 2026-08-27 — *"vamos terminar de reformar isso e
aplicar a fuligem na área afetada de forma permanente, no mapa de fuligem,
conforme já planejamos."* Recorded as `SOOT_MASTER_PLAN` §3.2b, which asked for
this document before any code and is the reason it exists.
**Supersedes:** `SOOT_MASTER_PLAN` §3.3's recommendation (*"A first, B only when
the segment persistence layer lands"*) and the last sentence of §6 Q3. It does
**not** supersede that plan's study — §1 (what exists, measured), §2 (the
unifying idea) and §4b (why the fade is a ring-code ladder and not a shader
uniform) are still the record and are cited, not restated, here.

---

## 0. The one-paragraph version, and the finding that shapes the whole plan

**The store already exists. Twice, and one of the two is exactly the ruled
design, shipped, in miniature.**

- `VoxelRenderer._soot_images[level]` — an `FORMAT_RG8` `Image`, one texel per
  cell, **R = the per-face soot code**, G = the light bucket. It persists between
  frames, it is read back by `cell_soot_at()`, and `flush_cell_soot()` uploads it
  once per level per repaint. PERF-P2/P3 built it as a GPU projection, but it is
  physically a per-cell soot store.
- `Room._crater_floor_soot` — `level -> {cell: ring}`, written through
  `add_crater_floor_soot()` **min-wins**, never re-derived, replayed into every
  snapshot (`room.gd:3408-3411`), and **already persisted by `SaveState`**. It is
  stored, permanent and non-accumulating: the ruled Option B, for the one cell
  class that could not be derived.

So what makes soot "derived" today is **not the absence of a store**. It is that
every repaint recomputes the field from the whole board and then **overwrites**
the store from it. `_build_soot_snapshot()` produces a fresh Dictionary,
`VoxelLightField.build()` takes it, `apply_light_field*()` reads
`field.face_soot_code()` and writes `_write_cell_soot()`.

**The reform is therefore a change of AUTHORITY, not of data structure:** an
emitter writes scorch once; a repaint stops writing scorch at all. That reframing
is what makes it stageable behind a gate instead of a rewrite — see §5.

---

## 1. What this closes, and what it does not

⚠️ **READ §1.1b BEFORE §1.1.** §1.1 was written as this reform's motivation and
**SS-0 measured it dead** — PERF-P3 removed the defect, by a route that had
nothing to do with soot. §1.1 is kept as the record of why the ruling was framed
the way it was; §1.2, §3.4 and the Director's design ask are what carry the work
now.

### 1.1 The defect it WAS for (`PERFORMANCE_MASTER_PLAN` §9.11a/§9.11b)

The Director's report was *"a segunda explosão influencia na fuligem da
primeira"*, and the measurement is the sharpest evidence in the whole soot
record: with fire 1 on fabric at gu (31,3) and fire 2 on plywood at gu (35,3),
**180 cells in fire 1's settled crater went to near-clean for five frames and
came back to exactly their old value** — 0 permanent changes, an end state that
is bit-identical, and therefore invisible to every before/after instrument that
had been built.

The mechanism: `_phase_soot_wave()` admits a cell when `alt != prev_alt` **OR**
its soot code moved. A blast changes occupancy → changes shadow → moves the light
bucket of a cell in an old crater across the map. That cell enters the wave on
the **alt** half of that OR with its scorch completely unchanged, and the ramp
lightens it and walks it back.

§9.11b shipped a guard: a cell already carrying its target scorch is not ramped
(`[E-FUME] soot fade: N of M entry cell(s) already carry their target scorch`).
**That guard is correct and stays.** But it is a predicate defending against a
recomputation that should not be happening. **Stored soot cannot express the
failure at all, because nothing recomputes an untouched cell.**

### 1.1b ⛔ MEASURED AT SS-0, AND IT DEMOTES §1.1: PERF-P3 ALREADY KILLED THIS DEFECT

SS-0 set out to arm the instrument and instead answered a question nobody had
asked. **The §9.11a defect does not fire in the shipped build**, and the §9.11b
guard is **inert** — it skips zero cells.

The cause is `PERF-P3`, which shipped default-ON in the perf wave two days after
§9.11b was measured. Under `P3_CELL_BUCKET` (`voxel_renderer.gd:637`, default ON
— the env var must say `0` to disable it) `encode_light_alt()` returns
`alt_for_flip()`: **the light bucket does not travel in the alternative id at
all.** §9.11a's mechanism was *"that cell enters the wave on the **alt** half of
that OR, with its soot completely unchanged"* — and the alt now carries only the
flip, which a light change cannot move. The only remaining way into the wave is
the soot half, which is the correct half.

**Measured, the Director's own repro** (fabric gu (31,3), then plywood gu (35,3),
`INFILTRAITOR_CAPTURE_ACTION=two_fires`), two runs of one build differing only in
`INFILTRAITOR_P3`:

```
                  guard skipped (fire 2)   flicker in fire 1's block   in fire 2's own block
                                            gu 29-32                    gu 33-34
P3 ON (default)      0 of 1 985                    0                        106
P3 OFF             175 of 2 160                  175                         84
```

**175 skipped and 175 flickering, by two instruments that share no machinery** —
the same double count §9.11b got at 180/180. Every flickering GU in fire 1's
block reports `0 permanent here`: they flicker and come back, the §9.11a
signature exactly. The 106/84 in gu 33–34 are fire 2's own block (hundreds of
permanent changes each) and are its destruction, not fire 1's soot.

**Consequences, stated plainly rather than buried:**

1. **§1.1 is no longer this reform's motivation.** The headline defect is already
   dead in the shipped build, by a route that had nothing to do with soot. A plan
   that kept citing it would be justifying itself with a fixed bug.
2. **What actually carries the reform is unchanged and is enough:** the
   Director's ruling is a DESIGN ask (permanence — *"de forma permanente, no mapa
   de fuligem"*), not a bug report; §1.2's two structural wins stand on their own;
   and the rotation correction (§3.4) makes the map-wide repaint a **gameplay**
   cost again, which is a stronger performance argument than §1.1 ever was.
3. **The guard stays.** `INFILTRAITOR_P3=0` is a live diagnostic path, and the
   defect is real whenever it is taken. Inert-by-default is not dead.
4. ⚠️ **The instrument's headline VERDICT line cannot be trusted for this
   question.** It printed *"fire 1's region IS disturbed mid-flight"* in BOTH
   runs, because at `TF_WATCH_GU = 3` the watch set reaches gu 34 — fire 2's own
   block. The code's own comment already says this. **Read the per-GU histogram,
   never the verdict.**

⚠️ **AND THE CAPTURE ACTION OVERWRITES CITED EVIDENCE.** `two_fires` writes
`Screenshots/history/twofires_after_1.png` / `_2` — the hand-named, tracked
captures §9.11b cites as its proof, deliberately named so the 50-file `auto_`
rotation could not reach them. Both SS-0 runs clobbered them; both were restored
from git before committing, and the finding above lives in numbers rather than in
those frames. **Anyone running `two_fires` again must expect to overwrite them and
must restore them** — or the capture that proves 2026-08-24's finding becomes a
picture of a later run that says something else.

### 1.2 Two more defects it closes structurally rather than by discipline

- **`SOOT_MASTER_PLAN` §1.2 — the duplication.** S-DEDUP made both paths call one
  producer, which removes the drift by discipline. Under the reform the repaint
  path produces no soot whatsoever, so there is **one writer by construction**.
- **§1.3 — the deep layer.** Today a voxel still hidden when soot is derived
  reads a clean code once the expose path reveals it; S-DEEP fixed it by passing
  `also_visible` ("this blast is about to reveal these"). Under the reform the
  emitter writes scorch for the cells its rings reach **regardless of visibility
  at that instant**, and the value is simply already there when the cell is
  revealed. The special case dissolves rather than being maintained.

### 1.3 What it explicitly does NOT change

| property | §3.2's old Option B | **the ruled B, and this plan** |
|---|---|---|
| stored per-cell, never re-derived | ✅ | ✅ **this is the ask** |
| accumulates — two blasts get dirtier | ✅ | ❌ **NO. `SOOT_MASTER_PLAN` §6 Q3 stands** |

Director, 2026-08-13: *"Não precisa sujar mais, não vamos ter tantas explosões
assim."* Permanence and accumulation are separable and only the first was asked
for. **Min-wins on write is what keeps them separate:** an emitter writing into
an already-scorched cell resolves to the same tone it would have produced on a
clean one. `add_crater_floor_soot()` already works exactly this way.

Also unchanged: the look. The ring→darkening curve, the four tones, the feather,
the four-rung fade ladder and its timing are all ratified and are not in scope.
**Any pixel this reform moves on a first blast against a clean board is a bug**
— which is what makes §5's gate strong.

---

## 2. The architecture

### 2.1 The authoritative store

    Room._soot_map: Dictionary    ## level:int -> { Vector2i base_cell : int packed_base_faces }

**Sparse — only scorched cells.** Absent means clean, which is also what
`_soot_image_for()` fills with (`FACE_SOOT_CODE_CLEAN`), so the two agree by
default rather than by a conversion.

**Keyed in BASE space, and holding BASE-space faces.** Both halves of that are
forced by §3.4 (rotation returns), and the second half is the finding that costs
this plan a new format — see §2.1b. The store is a plain `int` in a Dictionary,
so it is **not** bound by the RG8 plane's one byte per cell.

**Memory is not the objection, and the checkpoint model (§3.3) bounds it.**
`SOOT_MASTER_PLAN` §3.2 priced the dense case at ~100 000 voxels × one int ≈
0.8 MB; sparse it is far less — a blast's own snapshot is ~2 000 cells — and the
store now lives for **one level run**, not a campaign. ⚠️ GDScript `Dictionary`
entries are still not ints: measure the real footprint after a dozen detonations
before declaring this settled. If it ever matters, the fallback is the plane
itself (§2.5) — which §2.1b now also rules out for a rotating game.

### 2.1b ⚠️ THE PER-FACE FORMAT IS VIEW-SPACE AND CANNOT SURVIVE A ROTATION

This is the one thing in the reform that is not a change of authority, and it
would have shipped silently, because today nothing stores faces long enough for
it to show.

`BlastCalculator._face_rings_for()` writes `Vector3i(top, SE, SW)` and its own
header says why there are three: *"Only three faces can ever be seen at once with
this camera… +Z is the top diamond, +X the SE face, +Y the SW face."* Those are
**view-space** axes. The face turned toward the hole takes `ring`; every other
face — including the two horizontal ones facing away from the camera — takes the
isotropic `faint` fallback, because they cannot be drawn and there is no reason
to compute them.

Derived per view, that is exactly right. **Stored, it is a hole in the record:**
after a rotation, two faces that were never written become visible, and the value
they present was a placeholder for "not drawn", not a measurement.

**The fix is a wider STORE format, not a wider plane.**

| | components | values | lives in |
|---|---|---|---|
| view format (unchanged) | top, SE, SW | 5³ = **125** | the RG8 plane's R byte, the wave entries, the fade |
| **store format (new)** | top + four horizontal BASE directions | 5⁵ = **3 125** | a plain `int` in `_soot_map` |

Bottom (−Z) is never drawn from any perspective and stays out; five components,
not six.

**The projection reuses D25's pair, and must not invent a second one.**
`carved_side_to_base_dir()` / `carved_side_from_base()` already convert between a
view-space face and a base-space direction for damage, and
`_carved_side_to_base_dir()`'s comment states the rule this plan is bound by:
*"there is no second rotation formula here to drift out of sync with the one in
PerspectiveMapper."* The emitter writes the base direction its BFS came from; the
board build picks the two horizontal base directions the current perspective maps
to SE and SW, and packs the 125-code view triple from them.

Net effect: the information the emitter already has (`toward`, the offset back to
the hole) stops being thrown away at the moment it is projected, which is the
only reason the current format loses it.

**The current path is measurably RIGHT about this, which is exactly why the risk
is invisible.** `DESTRUCTION_MASTER_PLAN` D24's FACE-SOOT-01 amendment records a
real PLAYGROUND measurement: *"SE/SW histograms swap correctly on rotation to
E."* That is re-derivation getting rotation right by recomputing. A stored
view-space triple would reproduce the histogram of the perspective it was written
in and be wrong in every other one — and nothing on screen today would tell you,
because nothing stores faces long enough to be asked.

**That measurement is also the instrument SS-6 should rebuild**: an SE/SW
histogram, before and after a rotation to E, is a sharper and cheaper gate than a
pixel diff of a rotated board, and it has precedent in this repo rather than
being invented here.

### 2.2 One writer

    Room.scorch_cell(level: int, cell: Vector2i, faces: Vector3i) -> void

Min-wins per face, the **only** mutation of `_soot_map`. Everything that scorches
goes through it:

| producer | today | after |
|---|---|---|
| blast rings BFS | `build_soot_field()` → snapshot | `build_soot_field()` → **proposal** → `scorch_cell()` |
| firearm rings BFS | same | same |
| self-soot (D33-SOOT-01, W-TUNE-01) | `apply_self_soot()` into the snapshot | writes through `scorch_cell()` |
| revealed fixed earth | `_scorch_revealed_fixed_cells()` | unchanged shape, writes through |
| crater floor | `_crater_floor_soot`, replayed | **absorbed** — it becomes ordinary stored soot |

`BlastCalculator.derive_soot_rings()` and `build_soot_field()` survive
**unchanged**. They stop being "the field" and become "the scorch this event
proposes". That is the whole point of S-DEDUP being done first: the sequence
(blast BFS → firearm BFS → min-wins merge → self-soot) is load-bearing and is
already written down exactly once.

### 2.3 The repaint stops writing scorch

Minimal-diff path, and it is available because of how the seam already sits:

`_build_soot_snapshot()` becomes **a read of the store**, not a derivation. Its
return shape does not change, so `VoxelLightField.build(occupancy, soot,
under_structure, face_soot)` keeps its contract, `_stale_cells()` keeps working,
`apply_light_field*()` keeps reading `field.face_soot_code()`, and the renderer's
plane keeps being written the same way. **Nothing downstream of that one
Dictionary has to move.**

`VoxelLightField` could later stop carrying soot entirely and let the renderer
read the store directly — but that is a second reform, it touches `_stale_cells()`
(which uses soot to invalidate the static-factor cache), and mixing it in would
destroy this plan's pixel gate. Recorded as available, not planned.

### 2.4 The fade stays presentation, and gets a better failure mode

`DetonationChoreographer._fade_in_soot()` writes intermediate lightened codes
straight into the plane with `_write_cell_soot()`. Under the reform **it must not
write the store** — the store already holds the target from commit time.

Consequence worth stating plainly: an interrupted or aborted ramp leaves the
PLANE too light, and the next repaint restores it from the store. Today an
interrupted ramp is indistinguishable from truth. That is a strict improvement
and it is free.

### 2.5 The fallback design, if §2.1 measures badly

The plane can BE the store: R already holds the code, `cell_soot_at()` already
reads it. Rejected as the primary because (a) the ramp writes transient values
into it, so truth and presentation would share one byte, and (b) an `Image`
read-back per cell is slower than a Dictionary lookup. Kept because it needs no
new memory at all.

---

## 3. What it costs — stated before it is built

### 3.1 Soot stops being pure — and `build_plan()` must not

`PREDICTION_MASTER_PLAN` §2.2 records the soot layer as pure, and calls that
*"a model to copy, not a problem to solve"*. The ruling gives that up
deliberately. **The purity that must survive is a different one:** `build_plan()`
is PURE and `delta.commit()` is the only writer. So the plan carries the proposed
scorch as data and the commit writes it — soot joins §2.1's mutation inventory as
one new writer, not seven.

⚠️ **NAMING TRAP.** `WorldDelta` already has a `"soot"` key (`world_delta.gd:80`)
— it is a **visual wave bucket**, the ordered list of cells whose scorch the
choreographer will paint. It is not state and must not become the mutation
payload. Give the new one a name that cannot be confused with it
(`scorch_writes`), or the first person to read this code will merge them.

### 3.2 The world revision

Any new committed mutation must call `room.bump_world_revision()` or
`PredictionCache` serves a stale plan (`PREDICTION_MASTER_PLAN`, and the standing
rule in memory). The soot commit is a new committed mutation.

### 3.3 Persistence — ✅ ANSWERED 2026-08-27: it is CHECKPOINT state, not a record

Director: *"o save game é temporário e independente do jogador. Isto é, o
progresso do personagem, tanto em skills quanto em história, é salvo
automaticamente, e corre por fora de uma sessão. Durante o jogo, vamos ter saves
em checkpoints específicos. Em caso de morte o jogador volta para esse ponto,
então precisamos salvar o estado do cenário nesses momentos. Acabou a fase,
acabou o save. Saiu da fase, acabou o save. É o mecanismo do Sonic, quando passa
nos postes de save."*

**Two stores, and only one of them is this one:**

| | what | lifetime | this reform? |
|---|---|---|---|
| player progression | skills, story | automatic, **outside a session** | ❌ untouched |
| scenario state | damage, scorch | **one level run**, checkpoint to checkpoint | ✅ this |

**Consequences, and they all make the reform smaller:**

- `SaveState` is a **run-scoped snapshot**, not an archive. There is no long-term
  format migration burden — a save never has to be read by a later build of the
  game, because it does not outlive the level.
- The store's memory is bounded by one level run (§2.1), not by a campaign.
- **`clear_run_state()` already exists and is already the "acabou a fase" half.**
  Its header quotes the Director's own *"lembrar de limpar em caso de reset,
  morte, etc"*, and it clears `_base_damage` and `_crater_floor_soot` in one
  place *"so a new persisted field has exactly one place to be forgotten from"*.
  `_soot_map` is that new field, and this is where it goes. ⚠️ **Leaving the map
  there on level exit is the failure this design has to avoid**, and it is
  invisible until the next level shows a crater that belongs to the last one.
- Still true, and still the line this plan must not blur: **`_soot_index_cache`
  is a CACHE and is never persisted** — it is keyed by live `Voxel` references.
  `_soot_map` is keyed by coordinates and is state.

Mechanically: `SaveState.FORMAT_VERSION` 1 → 2, a new `soot` section,
`crater_floor_soot` absorbed into it. Because saves do not outlive a level, the
absorption can be a clean break rather than a migration.

### 3.4 Rotation — ✅ ANSWERED 2026-08-27, and the answer is BASE SPACE

⚠️ **CORRECTION TO THE RECORD.** `SOOT_MASTER_PLAN` §6 Q2 carries rotation as
dropped on a design ground — *"o jogo só vai ter um lado"* — and several
downstream notes lean on that, calling the repaint path's map-wide cost
*"a debug-path cost, not a gameplay one."* Director, 2026-08-27: **rotation was
disabled for PERFORMANCE, and the intent is to keep it working.** *"a gente
desativou a rotação porque estava dando problemas de performance. O ideal era
manter ela funcionando."*

That is a different reason with a different consequence, and it settles §3.4 as
mandatory rather than recommended:

- **The store is keyed in BASE space**, exactly like `_base_damage`, through the
  seam that already exists (`PerspectiveMapper.cell_to_base()`, which is what
  `record_voxel_damage_to_base()` uses). One mapping call per scorched cell,
  ~2 000 per blast.
- **And it stores base-space FACES** — §2.1b, the finding this answer forced out.
  Keying alone would have produced a board that is sooty in the right cells and
  wrong on two faces of every one of them.
- The option of keying in view space and invalidating on rotation is **withdrawn,
  not deferred**: it silently discards a feature the Director intends to restore.

⚠️ **Beyond soot:** any other note that treats the repaint path as debug-only
inherits this correction. Not swept in this plan — flagged, so the next person to
lean on that phrase knows it is load-bearing again.

### 3.5 What becomes dead, and the grep that must precede deleting it

The `SOOT-INC` incremental index (`Room._soot_index_cache`, `_soot_fold_dirty()`,
`Voxel.soot_dirty`, `invalidate_soot_index()`) exists to make **re-derivation**
cheap — it cut the final repaint 286 → 149 ms. With no re-derivation on the
repaint path, its repaint role is gone. It is **not** obviously dead overall: the
detonation plan's own walk (`_phase_walk()`) produces the same seeds.

⚠️ **CLAUDE.md's 2026-07-12 rule applies in full here.** An unrequested deletion
that looked unused in one file stopped every wall in the game from rendering.
Nothing in §3.5 is deleted without a repo-wide grep and a named caller list, and
it happens in SS-5, **after** the picture is proven identical — never before.

---

## 4. What must NOT be built

1. **Accumulation.** §1.3. Two blasts on one spot do not get dirtier.
2. **A second producer.** The exact drift `SOOT_MASTER_PLAN` §1.2 documented. If
   a caller needs scorch, it calls `scorch_cell()`; it does not compute its own.
3. **A `soot_strength` shader uniform for the fade.** §4b rejected it because the
   uniform is global to the shared material and would flash every older crater
   clean. PERF-P2 removed that specific argument (the plane is per cell), and the
   ladder is kept anyway **because it is the look the Director ratified** — a
   change here is a look change smuggled into an architecture commit.
4. **Removing soot from `VoxelLightField` in the same wave.** §2.3.

---

## 5. Tasks, in order, with their gates

The order has one governing idea: **the store proves it reproduces the picture
before it owns the picture, and nothing is deleted until the picture is proven.**

| id | task | gate |
|---|---|---|
| ✅ **SS-0** | **Arm the instrument first.** The §9.11b two-fire watcher (`INFILTRAITOR_CAPTURE_ACTION=two_fires`, `INFILTRAITOR_TWO_FIRES_GUS`, `[TWO-FIRES-WATCH]`). | ✅ **DONE, and the red lever is NOT the one this row specified.** Reverting the guard proves nothing, because the guard is **inert by default** (§1.1b). The lever that works is `INFILTRAITOR_P3=0`: red **175 flickering / 175 skipped**, green **0 / 0**, two instruments agreeing to the cell. The instrument is validated — and the run demoted §1.1 from motivation to history. |
| ✅ **SS-1** | **The store, in shadow.** `Room._soot_map` + `scorch_cell()` / `absorb_scorch()`, base-keyed with the §2.1b five-direction format, produced in parallel by `BlastCalculator`'s `out_full` and **read by nothing but the gate**. | ✅ **PASSES on both real paths — see §5.1.** `INFILTRAITOR_SOOT_STORE_GATE=1`: **0 DERIVED-ONLY, 0 LIGHTER** on an agent shot and on two real fires; 4 new selftests prove the round-trip over 180 direction cases. ⚠️ The gate proves the format is LOSSLESS, not §2.1b — it projects back into the perspective it wrote in, so the two extra directions are never read. SS-6 is the other half. |
| ✅ **SS-2** | **Flip the read.** `_build_soot_snapshot()` returns `soot_store_projection()`; the derivation still runs and still feeds the store (SS-5 removes it). Also: the format grew a **sixth** direction, and the shot pre-cook stopped writing speculative scorch — §5.2. | ✅ **CONTROL 0 px, GATE 0 px** on a real concrete detonation at the 400-frame settle. No stash needed: `INFILTRAITOR_SOOT_STORE_READ=0` gives the old answer from the same binary. |
| ✅ **SS-3** | **The commit seam.** `WorldDelta.scorch_writes` carries the blast's scorch as data; `commit(room)` writes it through `absorb_scorch()`; the existing post-commit `bump_world_revision()` covers it. | ✅ **Fire 1's region: 0 changed, and 0 flicker in its own block** (gu 29–32); total flicker **106 → 24**, all of it in fire 2's neighbourhood. Selftests **40 clean / 0 failed** including the leak gate, and `blast_purity_selftest` now asserts the proposal is a proposal: **692 cell(s) on the Delta, 0 in the store** before commit. ⚠️ It also surfaced §5.3. |
| **SS-4** | **Checkpoint persistence** (§3.3). `SaveState` v2, `crater_floor_soot` absorbed, `_soot_map` added to `clear_run_state()`. | `save_state_selftest` round-trips a sooted board; a restore reproduces it pixel-identically; and **a cleared run state leaves zero scorch** — the "acabou a fase" half, which is the one that fails silently. |
| **SS-5** | **Subtraction.** Retire the repaint-side re-derivation and whatever §3.5's grep proves dead. | Repo-wide grep and a named caller list **pasted into the commit**, not summarised. 0-px gate again after. |
| **SS-6** | **Prove it under rotation** (§3.4, §2.1b). ⚠️ **Needs a capture action that rotates the view, and none exists** — `SOOT_MASTER_PLAN` §7.2 recorded that gap as moot when rotation was believed dropped, and the 2026-08-27 correction un-moots it. Build it here. | **Rebuild D24's own instrument** — the SE/SW histogram, before and after a rotation to E (§2.1b). The two horizontal faces hidden at emit time must present the ring the emitter actually measured, not the `faint` placeholder. This is the only gate that can catch §2.1b being wrong, and a histogram beats a pixel diff of a rotated board. |

### 5.1 SS-1 as built, and the instrument mistake it cost

**Shipped:** `Room._soot_map` (`level -> {base_cell: packed five-direction code}`,
sparse), `scorch_cell()` as its only writer with min-wins per direction,
`absorb_scorch()` for an event's whole proposal, `soot_store_view_faces()` for the
projection SS-2 will consume, and `out_full` threaded through
`derive_soot_rings()` → `merge_soot_field()` → `apply_self_soot()` /
`scorch_floor_cell()`. The view↔base direction map is built once per perspective
by the difference-of-two-rotated-points technique `carved_side_to_base_dir()`
already uses, and **loud-fails** (B6) if a unit step in view space does not land
on a unit step in base space.

**Measured, `INFILTRAITOR_SOOT_STORE_GATE=1`:**

```
agent shot   absorbs 1 · store    86 vs derived    86 — 0 DERIVED-ONLY, 0 LIGHTER
             absorbs 2 · store    86 vs derived    84 — 0 DERIVED-ONLY, 0 LIGHTER, 2 store-only
two fires    absorbs 1 · store 2 782 vs derived 2 782 — 0 DERIVED-ONLY, 0 LIGHTER
             absorbs 2 · store 5 731 vs derived 5 731 — 0 DERIVED-ONLY, 0 LIGHTER, 1 darker
```

Plus four selftests (92 PASS / 0 FAIL in `blast_calculator_selftest.gd`): the
five-direction record projects to today's triple across **180 (ring × direction ×
n_rings × falloff) cases**, it keeps the two directions the triple discards, the
base-5 pack round-trips inside 0..3124, and merging is min per direction.

⛔ **CORRECTION, SS-2: the `2 store-only` on the shot was NOT the reform — it
was a defect SS-1 shipped.** It was reported here, and to the Director, as
*"between two repaints of ONE shot the derivation lost two cells the store kept
— §1.3's family arriving on its own"*. It was not. `_shot_precook()` calls
`_build_soot_snapshot()` with `predict_destroyed` / `predict_damaged` to mint the
alternatives a shot WILL need, and SS-1 absorbed that **speculative** scorch into
the store. The two extra cells were damage the shot predicted and the world never
produced.

Harmless while nothing read the store, and fatal the moment SS-2 made it the
answer. The fix is an early return on the same "non-empty predict arguments mean
speculative" test this function's own cache-reuse guard already uses; a
prediction now neither writes the store nor reads it, the second half mattering
just as much, because the warm has to see the world as it WILL be.

Measured, same capture, with the fix:

```
before   absorbs 2 · store 86 vs derived 84 — 2 store-only
after    absorbs 1 · store 84 vs derived 84 — 0 store-only
```

**The genuine permanence signal in these runs is the two fires' `1 darker`,**
which is unchanged by the fix — a cell the store holds darker than the fresh
derivation would now paint it. One cell is not much of a headline, and saying so
is better than keeping a bigger number that turned out to be a bug.

**And the gate was wrong the first time, in a way worth recording.** It ran BEFORE
the absorb, on the argument that comparing the store against the dictionary that
had just filled it would be the self-comparison B3 forbids. A real two-fire
capture produced:

```
absorbs 1 · store 2 782 vs derived 5 731 — 2 949 DERIVED-ONLY, 20 LIGHTER
```

and not one of those was a loss: the 2 949 were fire 2's own new scorch, read
before fire 2 was absorbed, and the 20 lighter were cells fire 2 had just darkened
by adding holes near them. **The before-absorb ordering cannot tell "the store lost
this" from "the store has not been shown this yet"** — the only distinction the
gate exists to make. After the absorb it is still not a tautology, because the
whole format sits between the two sides: `out_faces` against
`full_faces_to_view(base→view(decode(encode(view→base(out_full)))))`. Equality
proves losslessness, which is SS-1's actual claim.

**One thing landed early on purpose:** `_soot_map` is registered in
`SaveState.clear_run_state()` now, though persistence itself is SS-4. That
function exists *"so a new persisted field has exactly one place to be forgotten
from"*, and under the checkpoint model (§3.3) forgetting is the half that fails
silently — a store left behind is last level's crater. The selftest asserts it,
and adding the field turned that suite red first (`RoomStub` had no `_soot_map`),
which is the red-before-green for the clear being wired at all.

---

### 5.2 SS-2 as built — the flip, and the gate that had to be earned first

**The store answers now.** `_build_soot_snapshot()` still derives (removing that
is SS-5's subtraction, deliberately separate so this step changes exactly one
thing: **who answers**), feeds the store, and then returns
`soot_store_projection()`. `INFILTRAITOR_SOOT_STORE_READ=0` returns the
derivation instead — the `INFILTRAITOR_P3` idiom — so the before/after diff runs
off ONE binary rather than a stash, which is a strictly better instrument than
rebuilding to compare.

⚠️ **The format grew a sixth component here, and the reason is worth reading.**
§2.1b specified five, on the argument that −Z is never drawn from any perspective
so storing it could not change a picture. True, and beside the point: SS-2 makes
the store answer the **isotropic** snapshot too, and `derive_soot_rings()` writes
`capped` there for a voxel reached from BELOW while every drawable face correctly
falls to `faint`. Over five components that case is unrecoverable, and the only
symptom would have been `soot_factor()` — and through it `_compute_bucket()`'s
jitter exemption — quietly reading lighter on cells scorched from underneath.
Found by working out the projection, not by a test going red. 5⁶ = 15 625, still
one int.

**The pixel gate, concrete gu (2,2), grenade cell 3,5, 400-frame settle:**

```
CONTROL  (READ=0 vs READ=0):  0 differing px
GATE     (READ=0 vs READ=1):  0 differing px
```

The control is not a formality and is not optional: a 0-px claim from a harness
that has not been shown deterministic is noise wearing a number. It was run
first, and it earned the second line.

**The real paths, with the flip active and the SS-1 gate still armed:**

```
agent shot   absorbs 1 · store    84 vs derived    84 — 0 DERIVED-ONLY, 0 LIGHTER
two fires    absorbs 1 · store 2 782 vs derived 2 782 — 0 DERIVED-ONLY, 0 LIGHTER
             absorbs 2 · store 5 731 vs derived 5 731 — 0/0, 1 darker
```

Selftests 93 PASS / 0 FAIL: the sixth component recovers the isotropic ring from
all six directions across 180 cases, and the from-below case is asserted on its
own so a reader sees WHY rather than only THAT.

**Still true and still SS-6's:** this gate projects the store back into the
perspective it wrote in, so the three extra directions are never read. Nothing
here proves §2.1b.

---

### 5.3 ⚠️ SS-3 SURFACED SOMETHING NOBODY ASKED ABOUT: the store keeps scorch for voxels that no longer exist

Routing the blast's plan-time scorch through the commit changed a number nobody
was watching. Same two-fire capture, same build, SS-2 versus SS-3:

```
SS-2   absorbs 2 · store 5 731 vs derived 5 731 —     0 store-only
SS-3   absorbs 4 · store 7 771 vs derived 5 731 — 2 040 store-only
```

`0 DERIVED-ONLY, 0 LIGHTER` throughout, so nothing is being lost — the store is
keeping **more**. Two different things are in that number and only one of them was
predicted:

**1. The revealed crater floor — legitimate, and it closes an old open question.**
On a plain concrete detonation the store-only cells are `240`, and the level
histogram is decisive: **224 of them on level 79**, one single level, matching the
census's `FLOOR/concrete destroyed 224` exactly. That is
`_scorch_revealed_fixed_cells()`'s output — scorch the detonation writes for cells
with no Voxel behind them, which the repaint path **cannot re-derive**, because it
only replays `_crater_floor_soot` and nothing populates that outside the rotation
replay.

This is `SOOT_MASTER_PLAN` §1.2's asymmetry, which that plan recorded as an
*"unverified prediction"* and then called MOOT because S-DEEP removed the cause
rather than testing the symptom. **It was not moot.** It is real, it is measured
here, and it runs the opposite way to the prediction: the crater floor is SOOTED
at blast time and the derivation loses it. The store keeps it, which is the reform
doing something the derivation structurally cannot.

**2. Scorch belonging to voxels the FIRE consumed — an open question, not a
finding.** The rest of the 2 040 are spread across wall levels 80–97. The blast's
scorch is computed against the world before the burn, the final repaint derives
against the world after it, and a destroyed voxel takes no soot — so the store
holds marks for surfaces that are gone.

⚠️ **This is a DESIGN question and it is not mine to answer.** Should a wall's
scorch outlive the wall? There is a case for yes (permanence is the whole ruling,
and the deep layer revealed behind it was genuinely in the fire) and a case for no
(the mark was on a surface that no longer exists). It also has a cost: 2 040 dead
cells after two fires, in a store whose lifetime is one level run.

**What is NOT known, and is not claimed:** whether any of this reaches the screen.
The 0-px gate in §5.2 is a detonation, and it stayed at 0 — the blast's own wave
paints those cells and no repaint in that run overwrote them. **A fire has not been
pixel-diffed under `READ=0` vs `READ=1`**, and a burn capture is not obviously
deterministic enough to try without earning a control first. Recorded as open
rather than reasoned into a conclusion.

---

**Standing gate for every task** (`SOOT_MASTER_PLAN` §5's, unchanged): a real
detonation pixel-diffed before and after; the only acceptable differences are the
ones a task is explicitly for. ⚠️ And `weapon_fire` is **not** a deterministic
capture (691 px between two runs of identical code, §7) — the firearm path is
gated by the store-vs-derived comparison of SS-1, not by pixels.

---

## 6. Questions — ✅ BOTH ANSWERED 2026-08-27, SAME DAY THEY WERE ASKED

1. ~~**Rotation keying.**~~ **Base space, and it is mandatory** — rotation was
   disabled for performance and is meant to return (§3.4). The answer forced
   §2.1b out into the open, which is the largest single change this plan took
   after being written.
2. ~~**Does scorch survive a reload?**~~ **Yes, within a level run** — it is
   checkpoint state on the Sonic-post model, discarded when the level ends or is
   left (§3.3). Player progression is a separate store this reform never touches.
3. ⚠️ **NEW, from SS-3 (§5.3): should a wall's scorch outlive the wall?** The
   store now holds marks for surfaces the fire consumed — 2 040 cells after two
   fires. Permanence argues yes and the deep layer revealed behind them really was
   in the fire; "the mark was on a surface that no longer exists" argues no. It is
   also memory, in a store that lives one level run. **Not decided, not
   implemented either way.**
4. **Nothing else.** The look, the tones, the fade and its timing are ratified
   and out of scope by design.

**Nothing blocks SS-0.**

---

## 7. One more thing the Director confirmed, and it is already the shipped shape

*"reformar completamente a fuligem pra ser só aplicada no fim das
explosões/tiros"* — soot arriving only at the END of an event is already how it
plays: `_run_queue()`'s soot step is the last thing a detonation does (E-FUME /
S-DEFER), and the firearm path defers the same way under the Director's
2026-08-19 ruling (*"a fuligem pode ser processada depois do fato, desde que
apareça com fade in, e não de repente"*).

What the reform changes is that it becomes **literal**: today "at the end" is
when the derived field is *presented*, and the field itself is recomputed
map-wide on every repaint in between. After SS-2 there is exactly one write, at
the end of the event, and nothing recomputes it afterwards. Recorded here so the
confirmation is not mistaken for a new requirement — it is the same requirement,
and the reform is what finally makes the implementation match it.
