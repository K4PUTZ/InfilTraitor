# SOOT_STORAGE_REFORM
## The soot map becomes the source of truth — plan, 2026-08-27

**Status:** 🟡 **PLAN. NOT STARTED.** No code has been written for this.
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

    Room._soot_map: Dictionary    ## level:int -> { Vector2i cell : int packed_face_code }

**Sparse — only scorched cells.** Absent means clean, which is also what
`_soot_image_for()` fills with (`FACE_SOOT_CODE_CLEAN`), so the two agree by
default rather than by a conversion.

**Packed code, not a `Vector3i` of three face rings.** `VoxelLightField.encode_face_soot()`
/ `decode_face_soot()` already exist and are already the format the plane, the
wave entries and the fade all speak. Min-wins per face is a decode → three
`mini()` → encode, which is what `merge_soot_field()` already does per cell.
Storing the packed int keeps one format in play instead of two.

**Memory is not the objection.** `SOOT_MASTER_PLAN` §3.2 priced the dense case at
~100 000 voxels × one int ≈ 0.8 MB; sparse it is far less — a blast's own
snapshot is ~2 000 cells. ⚠️ But GDScript `Dictionary` entries are not ints:
**measure the real footprint after a dozen detonations before declaring this
settled**, and if it matters, the fallback is the plane itself (§2.5).

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

### 3.3 Persistence

`SaveState.FORMAT_VERSION` 1 → 2, a new `soot` section, and `crater_floor_soot`
absorbed into it (or kept for one version and migrated — decide when writing
SS-4, not now). The file's own header already draws the line this reform has to
respect: **`_soot_index_cache` is a CACHE and must never be persisted** — it is
keyed by live `Voxel` references. `_soot_map` is keyed by coordinates and is
state. That distinction is already documented there; this plan does not get to
blur it.

### 3.4 Rotation — the one genuinely open coordinate question

`_base_damage` is keyed in BASE space precisely so a perspective rotation can
replay damage. `_soot_map` as specified is keyed in VIEW space (level, cell), so
**a rotation would produce a board with no soot** — today it re-derives, and
re-derivation is what this reform removes.

Rotation is dropped (`SOOT_MASTER_PLAN` §6 Q2, Director 2026-08-13: *"o jogo só
vai ter um lado"*), **"for now"**, and room's rotation code stays. Two honest
options:

- **(a) Key the store in base space**, exactly like `_base_damage`. The seam
  already exists — `PerspectiveMapperClass.cell_to_base()` is what
  `record_voxel_damage_to_base()` uses — so this is a mapping call on write and a
  projection on board build, not a new coordinate system. **Recommended.**
- **(b) Key in view space and `invalidate` on rotation**, accepting that scorch
  is lost on a feature that is not shipping, recorded loudly at the call site.

(a) costs one mapping call per scorched cell (~2 000 per blast) and closes the
question permanently. Take (b) only if (a) measures badly, and never silently.

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
| **SS-1** | **The store, in shadow.** `_soot_map` + `scorch_cell()`, written in parallel with the current derivation. **Nothing reads it yet.** | `INFILTRAITOR_SOOT_STORE_GATE=1` compares store against the derived snapshot every repaint and reports every divergent cell. Zero divergence on a real detonation and a real shot before SS-2 starts. |
| **SS-2** | **Flip the read.** `_build_soot_snapshot()` returns the store. | **Pixel-diff, `INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES=400`, 0 differing px.** A first blast on a clean board cannot look different — permanence changes nothing about it. ⚠️ Capture the "before" side by stashing the change and re-running, same binary, same map. |
| **SS-3** | **The commit seam.** Scorch leaves the prediction as a proposal; `delta.commit()` writes it; `bump_world_revision()`. | The two-fire capture: fire 1's region **0 flickered, 0 changed** across the whole of fire 2. Plus `run_selftests.py` clean, including the leak gate. |
| **SS-4** | **Persistence.** `SaveState` v2, `crater_floor_soot` absorbed. | `save_state_selftest` round-trips a sooted board; a load reproduces the board pixel-identically. |
| **SS-5** | **Subtraction.** Retire the repaint-side re-derivation and whatever §3.5's grep proves dead. | Repo-wide grep and a named caller list **pasted into the commit**, not summarised. 0-px gate again after. |
| **SS-6** | **The rotation decision** (§3.4) — base-space keying, or a loud invalidation. | If (a): rotate the view on a sooted board and read the scorch back. If (b): the limitation written at the call site and in this file. |

**Standing gate for every task** (`SOOT_MASTER_PLAN` §5's, unchanged): a real
detonation pixel-diffed before and after; the only acceptable differences are the
ones a task is explicitly for. ⚠️ And `weapon_fire` is **not** a deterministic
capture (691 px between two runs of identical code, §7) — the firearm path is
gated by the store-vs-derived comparison of SS-1, not by pixels.

---

## 6. Open questions for the Director

1. **Rotation keying (§3.4).** Recommendation is (a) base space, since the mapper
   seam already exists and it closes the question for good. Confirm, or accept
   (b) and its recorded loss.
2. **Does scorch survive a mission reload?** SS-4 assumes yes, because the
   Director asked for `base_damage` to be saved and scorch is the visual record
   of that same damage. If soot is meant to be a *session* look rather than
   mission state, SS-4 shrinks to nothing and should be dropped rather than
   built.
3. **Nothing else.** The look, the tones, the fade and its timing are ratified
   and out of scope by design.
