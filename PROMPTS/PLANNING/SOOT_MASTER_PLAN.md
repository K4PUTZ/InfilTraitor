# SOOT_MASTER_PLAN
## One soot mechanism for explosives and firearms — study, 2026-08-12

**Status:** 🟢 **FIVE OF SIX TASKS BUILT 2026-08-12/13** — see §5. S-LOCAL was
dropped on its own measurement, not deferred. **The fade's mid-ramp is now
proven** — `Screenshots/history/soot_fade_beat_2026-08-13.png` (44-frame
filmstrip, `--fixed-fps 60`, grenade 2): the ring spreads across frames 28-32
outside the smoke plume, no glitch/pop between rungs. What is left is not
code: the repaint path still has no trustworthy pixel gate (§7's `weapon_fire`
non-determinism), and §6 Q2/Q3 are now both answered (rotation dropped,
accumulation not needed). ⚠️ **Q2's answer is CORRECTED 2026-08-27 — rotation was
disabled for PERFORMANCE, not because the game is single-sided, and is meant to
return**; see the annotation on Q2 itself and the two places that reasoned from
the old premise (§1.5, §3.1's cost bullet, §7.2's un-mooted gap).
**2026-08-27: a SECOND phase now exists** — the Director
ruled that the soot map becomes the source of truth (§3.2b). Ruled, not started.
Written first as a study, on the Director's request: *"Da uma estudada no jeito
mais eficiente que nos permita ter fuligem realista sem comprometer a
performance."*

**SUPERSEDES `EXPLOSION_REBUILD_MASTER_PLAN` §5 (E-SOOT)** as of 2026-08-13:
that section's authored ring-tone stamp is deleted, not merely disabled
(§2.0.1, S-KILL-STAMP). `PREDICTION_MASTER_PLAN` §2.2's purity finding still
holds and was deliberately preserved — soot is still a pure derived field, which
is exactly why Option B (§3.2) was NOT taken.

⚠️ **THAT LAST CLAUSE IS OVERTAKEN BY A DIRECTOR RULING, 2026-08-27 — see §3.2b.**
The soot map becomes the source of truth, so soot stops being pure and Option B's
STORAGE half is now the target. Purity was a means, not the goal, and the ruling
is about a defect purity cannot fix (§9.11a). **Not started**: everything in this
file that describes A as the shipped answer and B as unnecessary — §3.3, §5's task
table, §6 Q3's last sentence — is annotated in place rather than rewritten,
because the reform wants its own plan first. Read §3.2b before building any of it,
and note especially that the ruled B is permanent but **NOT** accumulating.

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

**Unverified prediction from that asymmetry:** a fresh crater floor should look
CLEAN right after the blast and SOOTED after a rotation. No capture action
rotates the camera, so it was never measured — and **S-DEEP made it moot rather
than tested**: both paths now write `EXPLOSED_FLOOR_SOOT_RING` through the same
helper (`BlastCalculator.scorch_floor_cell()`), so the asymmetry that would have
produced it is gone. Recorded because "we removed the cause" and "we proved the
symptom" are different claims, and only the first one is true here.

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

⚠️ **CORRECTED 2026-08-27 — "rotation is a debug feature now" was a reading of a
ruling that has since been corrected.** Rotation was disabled for **performance**
and is meant to return (§6 Q2's annotation). That inverts the significance of
this section rather than retiring it: this design constraint was never
optional-because-rotation-is-gone, it was **load-bearing all along**, and the
storage reform has to satisfy it by other means. It does, and the means is
[`SOOT_STORAGE_REFORM.md`](SOOT_STORAGE_REFORM.md) §3.4/§2.1b — store in BASE
space, and store base-space FACES, because the `Vector3i(top, SE, SW)` triple is
view-space. The second half is the part §1.5 could not have predicted: this
section knew soot had to survive rotation, and assumed re-derivation was the only
way to get it.

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

### 2.0 What the A/B/C measured — and the correction it forces

Before writing any of §2, the three configurations were rendered on the same real
throw (same binary, same map, 400-frame settle). Evidence:
`Screenshots/history/e_soot_abc_stamp_vs_bfs.png`.

    A  today: BFS + self-soot                 baseline
    B  stamp + BFS + self         A vs B:  43 135 px differ, max delta 69
    C  stamp only (§2's rule)     A vs C:  77 168 px differ, max delta 84
                                  B vs C:  36 277 px differ, max delta 84

### 2.0.1 ⛔ DIRECTOR'S VERDICT, 2026-08-12 — the stamp is REJECTED, A ships

*"O A está ótimo, bem orgânico, alguns voxels aleatórios no último ring, parece
natural. Pra mim passa assim. (…) Os outros dois (…) estão muito esquisitos, a
fuligem parece um monte de quadradinhos (…) fica muito artificial, parecendo
glitch. Outro problema grave é que fica muito forte por GUs, mas de repente na GU
do lado não tem nada."*

**This retires §2's whole direction before a line of it was written, and the
last sentence explains why in mechanism terms rather than taste.**
`stamp_container_soot()` and `stamp_crater_soot()` are called **once per
container** — per slice, per slab, i.e. **per GU** — and each stamps its own
voxels from its own distance ramp. Adjacent GUs are separate calls with no
continuity between them, so a hard GU boundary is not a bug in the stamp, it is
the shape of the stamp. That is exactly "muito forte por GUs, mas de repente na
GU do lado não tem nada", and no tuning of the tone table can remove it.

The BFS has no such seam because it propagates through the voxel grid and never
knows what a container is.

**So the plan inverts: the stamp is deleted, not promoted.** Everything below
that argued for a distance-keyed rule is kept as the record of a direction that
was measured and rejected — the measurement is the useful part.

What survives of the original goal: soot is still to become ONE producer shared
by the detonation and repaint paths, still fixes the deep-layer defect (§1.3),
and still gets the fade (§4b). It simply keeps the mechanism that already looks
right instead of replacing it.

---

**§2's "one rule absorbs all three" is too strong as written, and C is the proof.**
The stamp alone is not a drop-in for today — it is a substantially different
picture, and a worse one in a specific way: it paints BROAD, even coverage the
BFS structurally cannot (the BFS needs holes), but it does not deliver the dark
irregular CORE the BFS produces around real destruction. B, with both, reads most
like a real burn: wide scorch with a hot centre.

So the two are complementary **in practice**, not redundant, and the honest
target is one rule with TWO TERMS — a distance falloff for coverage plus a
stronger term where the surface actually broke — rather than deleting two of
three producers. That is still one mechanism, one code path and one tone curve;
it is not "keep the BFS". The dark core has to come out of the rule, not out of a
second traversal.

Why the stamp's core is weak is worth checking before tuning it: `frag_grenade`'s
`soot_ring_tones` already starts at 0 (the darkest tone), so the ramp is not the
obvious culprit. `stamp_crater_soot()` writes only `Vector3i(tone, CLEAN, CLEAN)`
— **the top face alone** — which is a real candidate and is cheap to test.

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

⚠️ **THAT LAST SENTENCE IS NO LONGER TRUE, 2026-08-27.** It rests entirely on §6
Q2's "rotation is dropped", and the Director has corrected the reason: rotation
was disabled for **performance** and is meant to return. A rotation that comes
back makes the repaint path a **gameplay** path, and the map-wide walk this
bullet dismisses is charged to it. Nothing else about Option A changes — it
shipped, it works, and its wins are real — but its cost has to be re-read with
this premise removed.

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

### 3.2b ⛔ DIRECTOR'S RULING, 2026-08-27 — **B IS NOW THE TARGET**, and it is a
### DIFFERENT B from the one §3.2 above describes

Asked to disambiguate *"vamos terminar de reformar isso e aplicar a fuligem na
área afetada de forma permanente, no mapa de fuligem, conforme já planejamos"*,
the Director chose **stop re-deriving; the soot map becomes the source of truth.**

⚠️ **READ THIS BEFORE BUILDING §3.2 AS WRITTEN.** §3.2 bundles two properties that
are separable, and the ruling takes one and not the other:

| property | §3.2's B | the ruled B |
|---|---|---|
| stored per-cell, never re-derived | ✅ yes | ✅ **yes — this is the ask** |
| accumulates (two blasts get dirtier) | ✅ yes | ❌ **no — §6 Q3 still stands** |

**Permanence and accumulation are different things.** Permanence is a blast's
scorch never being recomputed or disturbed by a later blast. Accumulation is it
getting darker each time. §6 Q3 (Director, 2026-08-13: *"Não precisa sujar mais,
não vamos ter tantas explosões assim"*) answered ACCUMULATION and is **not
reversed** — an emitter writing into an already-scorched cell still resolves
min-wins to the same tone it would have produced on a clean one.

So §3.2's bullet *"naturally cumulative: two blasts on one spot get dirtier"* is
the one part of it that must NOT be built.

**What the ruling is actually solving** is §9.11a's shape: the soot wave is
rebuilt from a whole-map snapshot on every blast, so a cell in an OLD crater on
the far side of the map can re-enter the wave because its light bucket moved, and
be lightened and walked back — a flash of exactly the kind the fade mechanism was
chosen to avoid. Stored soot cannot express that failure, because nothing
recomputes an untouched cell.

**Everything §3.2 lists under "Cost, stated plainly" still applies in full** and
is the reason this has not been started: soot stops being pure, joins
`WorldDelta.commit()`, grows `PREDICTION_MASTER_PLAN` §2.1's mutation inventory,
and must persist beside `room._base_damage`.

**Status: ruled, NOT started (2026-08-27).** It wants its own plan first — §3.3
below and §5's task table both describe A as the shipped answer and B as
unnecessary, and under this ruling both need rewriting rather than patching.
Session: `PROMPTS/RESUMO_SESSAO_2026-08-27_PACING_AND_ORDER.md` §5.

➡️ **THAT PLAN NOW EXISTS: [`SOOT_STORAGE_REFORM.md`](SOOT_STORAGE_REFORM.md)**
(2026-08-27, still 🟡 not started). Read it before building any of this. Its
opening finding changes the shape of the work: **the store already exists twice**
— `VoxelRenderer._soot_images` (RG8, R = the per-face code, one texel per cell)
and `room._crater_floor_soot` (stored, min-wins, permanent, already persisted by
`SaveState`, i.e. the ruled B shipped in miniature for the one cell class that
could not be derived). So the reform is a change of AUTHORITY, not of data
structure: an emitter writes scorch once, and the repaint stops writing scorch at
all. That file carries the staging (SS-0…SS-6), the gates, the rotation-keying
question, and the list of what must NOT be built.

### 3.3 Recommendation — ⚠️ SUPERSEDED BY §3.2b (2026-08-27)

Kept because the reasoning is the record of why A shipped first, and A's wins
are all still real and all still in place. The conclusion — "revisit B when
segments land" — is what the ruling overtakes: B is now the target, ahead of the
segment layer rather than behind it.

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

## 4b. The fade-in, and the obvious mechanism that is wrong

Director, 2026-08-12: *"queremos aplicar um tween up de opacidade, pra ela não
surgir de repente."*

**The tempting answer is a shader uniform, and it must be rejected.**
`voxel_face_shading.gdshader` already applies soot as a per-face multiply
(`soot_face_mult = vec4(0.33, 0.47, 0.69, 0.84)`, plus `soot_clean_mult = 1.0`),
so a `soot_strength` uniform lerping each multiplier toward 1.0 would give a
perfectly smooth ramp at zero per-cell cost — no re-minting, no `set_cell`,
nothing.

It is wrong because **that uniform is global to the material every voxel layer
shares.** Ramping 0 → 1 does not fade the NEW soot in; it first wipes every
existing scorch on the map to clean and then brings the lot back. A crater from
an earlier grenade, or any firearm mark, would visibly flash clean and re-darken.
Recorded here so the next reader does not rediscover the idea and ship it.

**The mechanism that is correct: ramp the per-face RING CODE.** The codes are
already a discrete ladder — 0, 1, 2, 3, and 4 = clean — so a cell whose final
tone is ring 0 fades `clean → 3 → 2 → 1 → 0`, and one whose final tone is ring 3
fades `clean → 3` in a single step. Darker cells therefore take longer to arrive,
which reads as soot *settling* rather than as a uniform dissolve, and it is
per-cell correct: nothing that is already sooted is touched.

Its cost is the P-WARM lesson applied a third time: each ramp step writes new
`(source, coords, alt)` triples, and any frame that mints one pays the TileSet
rebuild. **So every ramp code is minted in ONE pass before the ramp starts**, and
the steps themselves are then plain `set_cell`s. One rebuild, hidden under the
smoke, instead of one per step.

`FACE_SOOT_CODE_COUNT`'s ceiling is real and already measured — 5 tones "were
asked for and do not fit" (shader header, PERF-02 B3-2) — so 4 + clean is the
resolution the ramp has to work with. It is enough for a fade; it is not enough
for a slow dissolve, and that is a constraint, not a tuning choice.

### 4b.1 The Director's own proposal, recorded rather than dismissed

Director, 2026-08-12: *"eu tinha pensado em calcular o frame com a fuligem,
exportar e sobrepor com tween em cima da cena."*

Render the sooted result to a texture, cross-fade it over the live scene, then
swap the real tiles in underneath. **It solves the exact objection that killed
the shader uniform** — the old soot is present in BOTH images, so it cannot
flash — and it gives a genuinely continuous fade instead of four steps. It is the
better idea on quality.

Two things in this project's current shape stop it, and both are structural
rather than fixable in passing:

1. **The scene is animating under the fade.** Soot starts once the smoke is
   rising, so a frozen snapshot would carry baked-in smoke that also renders
   live underneath — every puff drawn twice, diverging as it drifts. Capturing
   only the voxel layers would avoid that, but they are not isolated: overlays
   interleave with them BY z_index (`AIM_Z_DOME`, the smoke, the embers, the
   agent), so there is no subtree to snapshot.
2. **The camera moves during it.** A screen-space overlay slides out of
   alignment with the shake.

Both dissolve if voxel rendering ever moves into its own SubViewport — which is a
real option, and this is a real argument for it. Until then the ring-code ramp is
the one that does not need the scene graph to change.

**Judge it with the filmstrip.** Four steps under smoke may read perfectly well
or may pop; that is a question for frame-by-frame evidence, not for either of us
predicting. If it pops, this section is the alternative to come back to.

---

## 5. Tasks

Ratified by the Director 2026-08-12: *"vamos gastar um tempo agora deixando a
fuligem unificada e coerente com todo o sistema (...) De resto pode planejar como
você achar mais adequado e implementar."*

**REVISED after §2.0.1.** The stamp is deleted rather than promoted, so there is
no new rule to write and no new class. What is left is subtraction, one defect,
one polish, and the Director's two asks.

| id | task | why |
|---|---|---|
| ✅ **S-FEATHER** `abf7add` | A faint scorch tail past the last tone | the one look note on A: *"um pouco de fuligem bem levinha expandindo pra fora, como um feather"* |
| ✅ **S-KILL-STAMP** `0c787d9` | Delete `stamp_container_soot()`, `stamp_crater_soot()`, their 3 call sites and `stamp_soot_enabled` | §2.0.1 — rejected on sight, and dormant code with an inverted default is a trap |
| ✅ **S-DEEP** `1a0c8b5` | Newly-exposed voxels take soot | §1.3, the defect the Director reported |
| ✅ **S-DEDUP** `46c50d0` | One producer for detonation and repaint; absorb `_crater_floor_soot` | §1.2's drift, already real |
| ✅ **S-DEFER** `cb5a344` | Soot starts once the smoke is rising | Director's ask |
| ✅ **S-FADE** `cb5a344` | The ring-code ramp of §4b | Director's ask |

**Order: S-FEATHER → S-KILL-STAMP → S-DEEP → S-DEDUP → S-DEFER → S-FADE.**
**All six landed in that order.** S-DEFER and S-FADE converged into one commit,
as predicted once it was clear that ramping the codes IS deferring them: the soot
step was already the last thing `_run_queue()` does, so what was missing was
never the timing, only the fade.

S-FEATHER first because it is the only outstanding note on a look the Director
has already accepted, and because it is very likely one parameter:
`derive_soot_rings()` already caps every distance past `intensity_rings` at the
faintest tone, so a longer reach at the same intensity IS a feather. Measure
before believing that.

S-LOCAL is **dropped from the schedule.** §1.4 measured it at 57 ms against 1.2 s
of slack, and with the stamp gone the remaining producers are the ones that must
not be disturbed. It stays recorded in §3.1 as available, not planned.

**Gate for every task:** a real detonation pixel-diffed before and after at
`INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES=400`. Soot is a look; the only
acceptable differences are the ones a task is explicitly for.

---

## 6. Open questions for the Director

1. **The stamp** — confirmed reformable rather than deleted: its job (a ring that
   destroys nothing still scorches) becomes the base rule in §2. Nothing to
   decide unless §2's rule is rejected.
2. **Rotation — ✅ ANSWERED 2026-08-13: dropped, for now.** Director: "Rotação
   por enquanto está descartada, o jogo só vai ter um lado." Confirms what §1.5
   already flagged as in question. Doesn't change anything Option A does — the
   plan never depended on the answer — but it does retire the §1.2/§7.2 rotation
   capture gap below: there's no rotation to prove the repaint path against
   while this stands. "For now," so `room.gd`'s rotation/repaint code stays;
   nothing here is a request to remove it.

   ⚠️ **THE REASON IS CORRECTED, 2026-08-27, AND THE REASON IS THE PART THAT
   MATTERED.** Director: *"a gente desativou a rotação porque estava dando
   problemas de performance. O ideal era manter ela funcionando."* Rotation was
   turned off as a **performance** measure, not because the game is
   single-sided — so it is suspended, not designed away, and the §7.2 capture
   gap this row retired is **un-retired**.

   Consequences, and they are not confined to this file: anything that leans on
   this row to call the repaint path *"a debug-path cost, not a gameplay one"*
   (§3.1's Option A bullet does, verbatim) is resting on a premise that no
   longer holds. And for the storage reform it is decisive — stored soot must be
   keyed in BASE space, **and must store base-space FACES**, because the
   `Vector3i(top, SE, SW)` format is view-space and loses the two faces turned
   away from the camera. Full account:
   [`SOOT_STORAGE_REFORM.md`](SOOT_STORAGE_REFORM.md) §2.1b and §3.4.
3. **Accumulation — ✅ ANSWERED 2026-08-13: no.** Director: "Não precisa sujar
   mais, não vamos ter tantas explosões assim." Two blasts on one spot do not
   need to leave a dirtier mark than one.

   ⚠️ **The last sentence of this answer is SUPERSEDED — see §3.2b (2026-08-27).**
   It used to read: *"Option A (derived, non-accumulating soot) stays as the
   shipped design; Option B (stored per-voxel state, needing the segment
   persistence layer) is not needed."* The Director has since ruled that the soot
   map becomes the source of truth, which is Option B's STORAGE half.

   **The accumulation answer itself is untouched and still governs.** Permanence
   and accumulation are separable, and only the first was asked for: stored soot
   that resolves min-wins is permanent and NON-accumulating. Do not read the
   ruling as reversing this row.

---

## 7. What to verify before building

Red-before-green, in this order:

1. ~~That `occupancy` can be produced without the full walk.~~ **DONE, and it
   cannot** — §1.4. This was checked before the plan was handed over precisely
   because it gated the headline, and it demoted performance from the reason to
   a side effect.
2. ~~The §1.2 rotation prediction — needs a capture action that rotates the
   view.~~ ~~**MOOT, 2026-08-13 — §6 Q2: rotation is dropped, for now.** No
   capture action to build against a feature that isn't shipping.~~ Not deleted
   from the record: if rotation returns, this is still the first thing to
   check.

   ⛔ **UN-MOOTED 2026-08-27. Rotation did not go away — it was turned off for
   performance and is meant to return** (§6 Q2's annotation). The last sentence
   above is now operative, and this is once again a real gap: **there is still no
   capture action that rotates the view.** Building one is
   [`SOOT_STORAGE_REFORM.md`](SOOT_STORAGE_REFORM.md)'s SS-6, and it is the only
   gate that can catch a stored per-face format being view-space (§2.1b there).
3. A pixel diff of one real detonation, before and after, at the 400-frame
   settle CLAUDE.md records as deterministic. Soot is a look; the gate is that
   the look survives the refactor except where §1.3's defect is deliberately
   fixed.
4. That the unified rule in §2 actually reproduces the current look on a wall
   hit by a firearm, not just on a blast — the two paths have never shared a
   tone curve, so "coherent" has to be shown, not assumed.
