# SOOT_MASTER_PLAN
## One soot mechanism for explosives and firearms — study, 2026-08-12

**Status:** 🟡 STUDY — nothing built. Written on the Director's request:
*"Da uma estudada no jeito mais eficiente que nos permita ter fuligem realista
sem comprometer a performance."*

**Supersedes nothing yet.** `EXPLOSION_REBUILD_MASTER_PLAN` §5 (E-SOOT) and
`PREDICTION_MASTER_PLAN` §2.2 remain the standing record until this is ratified.

---

## 0. The one-paragraph version

There are three live soot mechanisms, one dormant, and one side store, and the
whole assembly is implemented twice. They are not arbitrary: each covers a
different *evidence* that a surface should be scorched. What makes them
collapsible is that all three already write the same two accumulators with the
same min-wins rule — they are three producers of one field, not three fields.
**The case for reforming them is correctness and consistency, not speed** — see
§1.4, where the first draft of this plan claimed a 133 ms saving and the
measurement cut it to ~41 ms of a 210 ms prediction that already finishes with
1.2 s to spare. The reform is worth doing because the current model is wrong in
ways the Director has already seen on screen, not because it is slow.

---

## 1. What exists today, measured

### 1.1 The five writers

| # | mechanism | evidence it covers | live? |
|---|---|---|---|
| 1 | `derive_soot_rings()` from blast holes | proximity to a hole | yes, 4 rings |
| 2 | `derive_soot_rings()` from firearm holes | same, weaker | yes, 3 rings |
| 3 | `apply_self_soot()` | *this voxel itself* was marked | yes, 1 faint ring |
| 4 | `stamp_crater_soot()` / `stamp_container_soot()` | *within blast radius at all* | **dormant** |
| 5 | `room._crater_floor_soot` | revealed crater floor (non-Voxel cells) | yes, repaint only |

1 and 2 are the same function at different parameters — one mechanism, not two.

**Why 3 exists** (D33-SOOT-01): `derive_soot_rings()` only ever seeds from
DESTROYED voxels. pistol/metal, pistol/stone and shotgun/metal can never cross
`PUNCH_DESTROY_MIN`, so those combinations never produce a hole to seed from and
their marks came out pristine.

**Why 4 exists** (§5.2, and the Director restated it on 2026-08-12): *"o stamp a
gente criou porque o ring 3 não estava sendo pintado, por falta de voxels
destruídos, que era o critério do mecanismo primário."* `frag_grenade`'s
`destroy_ring_weights[3]` is 0.0, so ring 3 destroys nothing and derivation alone
can never reach it.

**Both 3 and 4 are therefore patches for the same root limitation: the primary
mechanism keys on destruction rather than on exposure.**

### 1.2 The duplication

The trio runs in two independent places that must agree by hand:

- `DetonationPlanBuilder._phase_soot()` — the detonation path
- `room.gd` ~2435–2475 — the repaint path (perspective rotation)

They already disagree. `BlastCalculator.EXPOSED_FLOOR_SOOT_RING` appears in
exactly one place in the project — `room.gd:382`, in the rotation replay. The
plan builder has no equivalent.

**Unverified prediction from that asymmetry, worth testing before it is designed
around:** a fresh crater floor should look CLEAN right after the blast and
SOOTED after a rotation. No capture action rotates the camera, so this has not
been measured. It is consistent with the confirmed second-blast defect below.

### 1.3 The confirmed defect it produces

Two grenades on one GU unlock D2's deep floor layer. Measured on PLAYGROUND,
second blast against first:

    destroy  244 -> 482      expose  640 -> 1280      smoke  484 -> 887
    soot     512 ->  240   <- halves while everything else doubles

`derive_soot_rings()` skips any voxel that is `not voxel.visible`. The deep layer
is still hidden when soot is derived; it only becomes visible through the expose
path afterwards, by which point `_alt_for()` reads a clean `face_soot_code`.
Evidence: `Screenshots/history/e_soot_second_blast_deep.png` — sand-coloured
voxels inside a blackened crater.

### 1.4 The cost — and the claim this plan had to retract before shipping

`_phase_walk()` traverses **every voxel of every container in the map** to
produce `cell_to_voxel` (the BFS's index), `blast_cells`/`weapon_cells` (its
seeds), `damaged_voxels` (self-soot's input), plus `occupancy` for the light
field and `under_structure`. Three of those five outputs exist for soot, which
made "soot's global shape is what forces a 133 ms walk" an attractive headline.
**It is wrong, and the measurement is what caught it.**

`occupancy` is genuinely map-wide — `VoxelLightField._static_factor()` reads it
for neighbour-based surface shading — so the walk survives soot's removal. A/B on
a real PLAYGROUND detonation, soot's outputs skipped inside the walk:

    phase        with soot     without      delta
    WALK          159.0 ms     117.8 ms     -41.2 ms
    SOOT           10.2 ms       0.0 ms     -10.2 ms
    SOOTWAVE        5.7 ms       0.0 ms      -5.7 ms
    TOTAL         235.4 ms     168.4 ms     -67.0 ms

(PACKAGE's 10.2 → 0.5 ms in the same run is an artefact, not a saving — it reads
`cell_to_voxel` and simply finds nothing when the index is empty. It would still
need a lookup, though a blast-local one would do.)

So soot's total share is **~57 ms of 235 ms**, of which ~41 ms is its footprint
inside the walk. Real, but a quarter of what the first draft claimed.

**And it buys nothing the player can feel.** P-WARM's timeline measures the
prediction finishing at +765 ms against a fuse that ends at ~+2030 ms — 1.2 s of
slack, and beat 0 (cooking) runs zero frames. Trimming 57 ms from a budget with
1 200 ms spare is not a reason to touch the most-verified file in the project.

**The reason to do this work is §1.1–§1.3: three patches for one root
limitation, two implementations that already disagree, and a defect the Director
can see on screen.** Performance is a side effect, and a modest one.

For the record, this is the second time this pipeline's cost has been
misattributed by reasoning instead of measuring — `PREDICTION_MASTER_PLAN` §8.8
had to retract §1.1's "soot derivation is 66 ms" the same way.

### 1.5 Why soot is global at all

`voxel.gd:20` states the reason outright: soot is derived fresh every repaint
"never stored here… a destroyed voxel's absence already survives rotation via
room._base_damage, so there is nothing extra to persist for soot to travel with
the hole."

**Soot is a derived global field specifically so that rotation needs no soot
persistence.** That is the whole design constraint, and it is the one the
Director has just put in question — rotation is a debug feature now, and the
segment back/forward system will need a state layer regardless.

---

## 2. The unifying idea

All three live mechanisms approximate one physical quantity: **how much blast a
face saw.** Three proxies:

- distance from the source            → the stamp
- propagation through openings        → the BFS
- "it was damaged, so it was exposed" → self-soot

A single rule covers all three if it keys on **exposure** instead of on
destruction:

    soot(face) = tone_curve[effective_ring] , for every face the emitter reaches

where *reach* is computed with the same wall-aware flood the damage already
uses. Then:

- a ring that destroys nothing still scorches — **the stamp's job, absorbed**;
- soot travels through a breach and stops at intact walls — **the BFS's job**,
  and more honestly than "distance from a hole";
- a dented voxel with no hole nearby is inside the reach by definition —
  **self-soot's job, absorbed**;
- a revealed crater floor is inside the reach — **§1.3's defect, absorbed**.

### 2.1 Coherent across explosives and firearms

The Director's requirement: *"queremos um sistema de fuligem que seja coerente
tanto nos explosivos quanto nas armas de fogo, para a aparência ficar similar."*

One emitter type, two callers:

| | origin | reach | tone curve |
|---|---|---|---|
| grenade | epicentre GU | bomb's rings | `BombDef.soot_ring_tones` |
| firearm | impact voxel | 1–2 voxels | the same table's tail |

Same code, same tones, same per-face falloff — so the *look* matches by
construction rather than by two tables being kept in sync. The Director's
allowance for *"dois dispositivos diferentes"* is then only about **where an
emitter is placed**, not about how soot is computed.

---

## 3. Two ways to build it

### 3.1 Option A — local derivation, soot stays PURE (recommended first)

Keep soot a derived field; stop deriving it map-wide. An emitter knows its own
reach, and the damage phases already hold the containers it touched, so the
derivation walks *those* voxels instead of all ~100 000.

- kills soot's need for `cell_to_voxel`, `blast_cells`, `weapon_cells` and
  `damaged_voxels` — i.e. most of the 133 ms walk;
- `PREDICTION_MASTER_PLAN` §2.2's purity property is untouched, and §2.2 calls
  that property "a model to copy, not a problem to solve";
- no persistence, no new mutation in §2.1's inventory, no rotation decision
  needed;
- the repaint path still rebuilds globally — acceptable while rotation is
  debug-only, and it can call the same producer, which ends the duplication.

**Cost:** soot from a PREVIOUS blast is still re-derived on repaint, so the
repaint path keeps a map-wide walk. That is a debug-path cost, not a gameplay
one.

### 3.2 Option B — soot becomes accumulated per-voxel state

A voxel carries its own packed per-face soot code. An emitter *adds* to what is
already there (min-wins). Nothing is ever re-derived.

- the repaint path disappears entirely — it reads stored codes;
- the duplication cannot come back, because there is only one writer;
- naturally cumulative: two blasts on one spot get dirtier, which the current
  model cannot express at all.

**Cost, stated plainly:** soot stops being pure. It becomes a real mutation and
must go through `WorldDelta.commit()` like every other write —
`PREDICTION_MASTER_PLAN` §2.1's mutation inventory grows, and every guarantee
built on "the soot layer is pure" needs re-checking. It also must persist beside
`room._base_damage`. Memory is not the obstacle (~100 000 voxels × one packed
int ≈ 0.8 MB); the architectural review is.

### 3.3 Recommendation

**A first, B only when the segment persistence layer lands.**

A gets every correctness win in §2 — one rule, coherent across explosives and
firearms, ring 3 scorches without destroying, the revealed crater floor stops
being pristine — while leaving `PREDICTION_MASTER_PLAN`'s purity property and the
rotation question both untouched. Its ~57 ms is a bonus, not the case.

B's unique benefit is accumulation: two blasts on one spot leaving a dirtier mark
than one, which the current model cannot express at all. That is a look the
Director has not asked for, and it costs soot's purity — so it should wait for
the persistence layer the segment system needs anyway, rather than inventing one
for it.

**Do A as one contained task with a pixel-diff gate. Revisit B when segments
land.**

---

## 4. Deferral, and why it is probably not needed

The Director: *"podemos deixar a fuligem aparecer depois que a fumaça já foi
disparada, e evitar sobrecarregar o cálculo da pré-produção."*

Worth recording that this permission exists, and that Option A likely makes it
unnecessary: with the map-wide walk gone, soot's own arithmetic is ~10 ms, which
already fits inside pre-production's second of slack (measured: the prediction
finishes at ~+765 ms against a fuse that ends at ~+2030 ms). The **visual**
ordering — soot fading in after the smoke — is already how it plays
(`_run_queue()`'s end-of-sequence soot step, E-FUME) and does not depend on when
it is computed.

So deferral stays available as a lever, not as a requirement.

---

## 5. Open questions for the Director

1. **The stamp** — confirmed reformable rather than deleted: its job (a ring that
   destroys nothing still scorches) becomes the base rule in §2. Nothing to
   decide unless §2's rule is rejected.
2. **Rotation** — this plan deliberately does NOT depend on the answer.
   Option A works either way. Recorded because §1.5 shows the current design was
   shaped entirely by it.
3. **Accumulation** — should two blasts on one spot leave a dirtier mark than
   one? Today they cannot. That is the only thing Option B buys that A does not.

---

## 6. What to verify before building

Red-before-green, in this order:

1. ~~That `occupancy` can be produced without the full walk.~~ **DONE, and it
   cannot** — §1.4. This was checked before the plan was handed over precisely
   because it gated the headline, and it demoted performance from the reason to
   a side effect.
2. The §1.2 rotation prediction — needs a capture action that rotates the view.
   Cheap, and it either confirms the duplication is already visibly wrong or
   removes an argument from this plan.
3. A pixel diff of one real detonation, before and after, at the 400-frame
   settle CLAUDE.md records as deterministic. Soot is a look; the gate is that
   the look survives the refactor except where §1.3's defect is deliberately
   fixed.
4. That the unified rule in §2 actually reproduces the current look on a wall
   hit by a firearm, not just on a blast — the two paths have never shared a
   tone curve, so "coherent" has to be shown, not assumed.
