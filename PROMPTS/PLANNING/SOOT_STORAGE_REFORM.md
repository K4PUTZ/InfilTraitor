# SOOT_STORAGE_REFORM
## The soot map becomes the source of truth — plan, 2026-08-27

**Status:** 🟡 **PLAN. NOT STARTED.** No code has been written for this.
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

### 1.1 The defect it is for (`PERFORMANCE_MASTER_PLAN` §9.11a/§9.11b)

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
| **SS-0** | **Arm the instrument first.** The §9.11b two-fire watcher already exists (`INFILTRAITOR_CAPTURE_ACTION=two_fires`, `INFILTRAITOR_TWO_FIRES_GUS`, `[TWO-FIRES-WATCH]`, sampling fire 1's region every frame). | **Red-before-green on the instrument itself:** with the §9.11b guard temporarily reverted it must report the 180-cell flicker; with it restored, 0. An instrument that cannot see the defect class proves nothing about removing it. |
| **SS-1** | **The store, in shadow.** `_soot_map` + `scorch_cell()`, in the base-space five-face format of §2.1b, written in parallel with the current derivation. **Nothing reads it yet.** | `INFILTRAITOR_SOOT_STORE_GATE=1` compares the store's **view projection** against the derived snapshot every repaint and reports every divergent cell. Zero divergence on a real detonation and a real shot before SS-2 starts. ⚠️ This gate is what proves the §2.1b projection, and it can only prove it in the perspective the capture runs in — SS-6 is the other half. |
| **SS-2** | **Flip the read.** `_build_soot_snapshot()` returns the store. | **Pixel-diff, `INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES=400`, 0 differing px.** A first blast on a clean board cannot look different — permanence changes nothing about it. ⚠️ Capture the "before" side by stashing the change and re-running, same binary, same map. |
| **SS-3** | **The commit seam.** Scorch leaves the prediction as a proposal; `delta.commit()` writes it; `bump_world_revision()`. | The two-fire capture: fire 1's region **0 flickered, 0 changed** across the whole of fire 2. Plus `run_selftests.py` clean, including the leak gate. |
| **SS-4** | **Checkpoint persistence** (§3.3). `SaveState` v2, `crater_floor_soot` absorbed, `_soot_map` added to `clear_run_state()`. | `save_state_selftest` round-trips a sooted board; a restore reproduces it pixel-identically; and **a cleared run state leaves zero scorch** — the "acabou a fase" half, which is the one that fails silently. |
| **SS-5** | **Subtraction.** Retire the repaint-side re-derivation and whatever §3.5's grep proves dead. | Repo-wide grep and a named caller list **pasted into the commit**, not summarised. 0-px gate again after. |
| **SS-6** | **Prove it under rotation** (§3.4, §2.1b). ⚠️ **Needs a capture action that rotates the view, and none exists** — `SOOT_MASTER_PLAN` §7.2 recorded that gap as moot when rotation was believed dropped, and the 2026-08-27 correction un-moots it. Build it here. | Scorch a board, rotate, and read the faces back: the two horizontal faces that were hidden at emit time must present the ring the emitter actually measured, not the `faint` placeholder. This is the only gate that can catch §2.1b being wrong. |

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
3. **Nothing else.** The look, the tones, the fade and its timing are ratified
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
