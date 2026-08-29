# DETONATION_PRESENTATION_MASTER_PLAN
## One commit, then only drawing — the choreographer's reform, 2026-08-27

**Status:** 🟢 **THE EXPLOSION DESIGN IS CLOSED — Director, 2026-08-29:**
*"isso conclui nosso design da explosão, com exceção do vidro… Fica pendente a
limpeza e a otimização do código + cook da luz."*

**DONE and shipped (§8.1–§8.13):** D-0…D-5, the fuse/boom pre-pass (§8.10),
D-6 **complete** — the presenter is the only path (part 1, §8.11) and the
choreographer + `BurnScheduler` + `FireGlowOverlay` + ~3 000 lines of dead burn
subsystem are deleted (part 2, §8.11) — and the light-lag defer (§8.12). The
event: fuse (grenade intact) → boom → one commit frame → the consequence channel
(smoke, plumes, brasa) → the light lands after the smoke clears.

**PENDING — engineering, not design:**
- **§7.4 — the light cook.** Compute the light field in the pure cook so
  `play_consequence_light()` becomes a pixel write with no ~202 ms freeze. §8.12
  only HIDES that freeze (defers it to a still scene); this removes it. Its own
  task — getting it wrong means the board's light is wrong everywhere.
- **Polish `throw_event`** — the capture action (§8.13).

**Out of scope here — `MATERIALS_MASTER_PLAN` M4:** glass, *"tem que quebrar muito
mais com a granada"* (the non-local pane break), end of the materials milestone.

---

⚠️ **D-4's symbolic fire (§5.1) was DOWNSCOPED by the Director on 2026-08-29** —
*"a gente já chegou num visual bem bom, só falta um pouquinho de brasa nos
materiais moles… o que a gente conseguir colocar de vermelho brilhando que vira
preto é lucro. De resto pode deixar assim mesmo."* The per-voxel vibrating
flame / incandescent voxel / ash-transmission spec is NOT built; what shipped is
a boosted ember on the cells the fire consumes (§8.8).
D-0's pacing rehearsal ships as three env overrides — **fabric 4 797 → 2 310 ms;
hard 2 940 → 878 ms**, single collapsed commit frame **18.55 ms measured**
against a predicted 20.1. **D-2 made the cook the owner of what the fire
consumes**, which killed §9.11e at its root: the cell probe goes from **350
RESTORED to 0 RESTORED · 0 VANISHED** against a control run from the same
binary. ⚠️ **§11.1's forced-opening proposal was VETOED by the Director on
2026-08-28** — only the passage CRITERION changed; see §11.1a.
**Authority:** the Director, 2026-08-27, after the timeline below was measured:
*"O sistema todo de explosão está caro e lento. Queremos algo mais dinâmico,
mais pa-pum… Menos é mais."* and, on being shown where the time goes: *"A
questão da luz permanece, vamos aplicar ela no final, depois da explosão
terminar. Pode fazer como você acha mais adequado. Faz sentido reformar o
coreografo, ele pode ser o nosso grande vilão."*

**Supersedes** [`FIRE_REBUILD_MASTER_PLAN.md`](FIRE_REBUILD_MASTER_PLAN.md).
Nothing there is retracted — §1 (the Director's fire spec, verbatim) and §2 (one
commit, then only drawing) are carried into §4 and §6 here in substance. A plan
named after the FIRE was the wrong container once the reform turned out to be
the whole presentation layer, which is the same argument
`BURN_THROUGH_MASTER_PLAN` was superseded under on 2026-08-21.

**Companions:** `PREDICTION_MASTER_PLAN` (owns the pure cook — **not touched by
this plan and load-bearing for it**), `PERFORMANCE_MASTER_PLAN` (owns the cell
plane and every frame-cost measurement), `MATERIALS_MASTER_PLAN` §3 (owns fire
and the passage rule), `SOOT_STORAGE_REFORM` (owns the scorch store).

---

## 1. THE MEASUREMENT THIS PLAN IS BUILT ON

One real PLAYGROUND boot per row, windowed, **no per-frame capture readback**
(`INFILTRAITOR_THROW_PROFILE=1` / `INFILTRAITOR_BURN_PROFILE=1`, 2026-08-27,
`8fa2b791`). Fabric at gu (31,3); the hard row is the default grenade at gu (3,5).

### 1.1 The timeline, end to end

```
+     0 ms  f=  0   BEAT 1 — fire lit
+   798 ms  f= 35   BEAT 0 — cooking done: 36 frame(s), 340.6 ms of work at 8 ms
+   809 ms  f= 35   COMMIT — 11.3 ms, 951 voxel(s) written
+   812 ms  f= 35   CENSUS · PERSIST — 1.92 ms
+   906 ms  f= 40   BEAT 2 ends — metal away, 5 flash frames
+  4797 ms  f=264   WAVES end — the blast is over
```

**951 voxels are destroyed, dented and cracked in 11.3 milliseconds. The event
takes 4.8 seconds.**

### 1.2 Where the 4.8 s goes

| beat | fabric | hard | the CPU inside it |
|---|---|---|---|
| cook (sliced; **0 in real play** — the human takes longer to choose) | 798 ms / 35 f | 780 ms / 35 f | 340.6 ms of work at an 8 ms budget |
| metal + flash | 5 f | 5 f | 0.76 ms |
| **commit** | — | — | **11.3 ms** |
| front (24 frames of cell writes) | 422 ms | 352 ms | **20.13 ms** total apply, worst frame 4.13 ms |
| fire | +53 f / ~900 ms | — | **12 ms** total across all 77 frames |
| soot ramp (4 × 8 f) | ~550 ms | ~550 ms | 4 × 1 914 plane writes |
| **light ramp (12 × 10 f)** | **~2 060 ms** | **~2 060 ms** | 176.5 ms derive, **in one frame** |

### 1.3 The three readings that decide this plan

1. **"Caro" is no longer true, and three performance waves are why.** Mean frame
   during the event is 17.4 ms. `_advance_burn` across the fire's whole 77 frames
   is **12 ms**. The entire cell-writing work of a 2 820-entry fabric plan is
   **20.13 ms**; on concrete, 5.68 ms. Zero TileSet alternatives are minted.
   Nobody re-measured the feeling after the waves shipped, so the word stayed.

2. **"Lento" is entirely true and it is entirely SCHEDULE.** 264 frames wrapped
   around 11.3 ms of work. The light ramp alone is 43% of the fabric event and
   **70% of the concrete one**, and it is the constant
   `consequence_light_seconds = 2.0`.

3. **There is exactly one real stall left: the 176 ms light derive**, paid in a
   single frame at the opening of the light beat (`play_consequence_light()`
   calls `_repaint_voxel_light_buckets(true, true)` with no `await` inside it).
   That is the only "caro" in the event, it is ~10 dropped frames, and §7.4 is
   about it.

### 1.4 ⚠️ And the number F-0 was going to spend a session getting is already here

`FIRE_REBUILD` §2.6.1 said *"concentrating the writes means ONE TileSet rebuild
instead of up to 24 — it should fit. 'Should fit' is not a number."* It is now
arithmetic off the same log:

```
commit (Voxel fields, 951 voxels)          11.3 ms
every cell write, summed over 24 frames    20.1 ms   (concrete: 5.7)
the fire's own consumption, all 77 frames  12.0 ms
                                           -------
one commit frame, fabric                  ~43 ms     ≈ 2 dropped frames
one commit frame, concrete                ~17 ms     ≈ 1 frame
```

Collapsing is **strictly cheaper than spreading**, not merely affordable: the
TileSet rebuild is charged per FRAME THAT WRITES, not per cell — the
choreographer's own header measured that and then built the opposite (*"a frame
costs ~120 ms whether it writes 60 cells or 600"*). One flush replaces 24.

⚠️ **This was a sum of per-frame applies, not a measurement of a collapsed
frame** — and §8.1 has since measured the real thing: **18.55 ms on fabric,
4.21 ms on hard, both CHEAPER than the sum.** The estimate held. What D-1 still
owes is the same frame with the fire's consumption folded into it (§6), which
does not exist yet.

---

## 2. WHAT IS NOT BEING REBUILT, AND WHY

Stated first, because the Director offered a from-scratch system and two pieces
must survive it. Both are exactly what the "pre-cook the important frames" idea
needs, and re-earning either would cost months.

**`build_plan()` is PURE and returns a `WorldDelta`; `commit()` is the only
writer** (`PREDICTION_MASTER_PLAN` §3). **The final state of the crater is
already computed before anything appears on screen.** The proposal in §4 does not
have to be built — it has to be USED. The 11-phase resumable state machine, the
cache keyed on `(signature, world_revision)`, and the pre-production that hides
340 ms under the fuse all stay untouched.

**P3 shipped: per-cell visual state left the TileSet and became a data texture**
(`PERFORMANCE_MASTER_PLAN` §2). *"A new effect is a new CHANNEL, not a multiplier
on the alternative space"* is already a property of the architecture. The
symbolic fire is cheap **by construction**, not by budget.

**Also untouched:** `BlastCalculator`'s resistance model and its rolls, the
material table, `PassageQuery`, the soot store (`SOOT_STORAGE_REFORM` SS-0…SS-3),
`ShrapnelOverlay`, `ExplosionFlashOverlay`, and every overlay's own look.

---

## 3. THE VILLAIN, NAMED PRECISELY

`DetonationChoreographer` is 933 lines doing **four** jobs. Three of them exist
only to spread 20 ms of work across 24 frames, and they are what this plan
removes.

| job today | fate |
|---|---|
| `flatten_plan()` · `_sort_key()` · `KIND_RADIUS_BIAS` · `front_jitter` — decide the ORDER cells are written in | **dies** |
| `_run_queue()` · `front_radius_for()` · `steps_within()` · `front_frames` · `band_voxels` — pace the front | **dies** |
| `_apply_entry()`'s cell writes (`destroy`/`expose`/`dented`/`cracked`/`soot`) | **survives as one loop inside the commit** — same calls, no frame boundaries |
| `_apply_entry()`'s VFX dispatch (`smoke`/`ember`/`debris`) | **survives and MOVES** — see §5 |
| `_fade_in_soot()` | **dies** — soot lands in the commit; its `set_cell()` loop is §9.11e's writer |

### 3.1 What dying kills, by construction

- **The ordering problem, whole.** `KIND_RADIUS_BIAS` has been re-derived three
  times (E-CLEAN, §13.4, E-ORDER-01 — the last of which found *"the hole opened
  before its own crack on five cells out of six"*). If everything lands on one
  frame there is no order to get wrong. This is the single largest simplification
  in the plan and it is free.
- **§9.11e's 350 restored cells.** Measured this session at 350 of 350, one frame:
  `_fade_in_soot()` re-places cells with a `source_id` read during the cook, onto
  holes the fire ate afterwards. With one commit frame there is no "afterwards".
- **The second mutation stream.** `BurnScheduler` (109 lines) + `_advance_burn`
  and its profiler (217 lines in `room.gd`) exist to write cells for 77 frames
  after the plan was computed. §6 moves that decision into the cook.
- **`front_frames` as a frame-denominated look value.** §14.1's whole failure
  mode — a performance wave silently retuning the blast's duration 4.9× — needs a
  duration counted in frames to bite. There is no front left to count.

### 3.2 Every consumer, listed before anything is deleted

CLAUDE.md's 2026-07-12 lesson is this exact shape, so the grep is in the plan
rather than in the commit that needs it.

| consumer | what it uses | disposition |
|---|---|---|
| `TestZoneController._start_waves()` | the whole class | the only runtime caller — rewired to the presenter |
| `TestZoneController._precook()` | `flatten_plan()` (W-PRECOOK warming) | needs a replacement source of "which alternatives will this blast need" |
| `TestZoneController._entries_playback_will_drop()` | `PLAYED_KINDS` | the drop-check survives against the new kind list |
| `detonation_choreographer_selftest.gd` | `flatten_plan`, `wave_table_for`, `front_radius_for`, `steps_within` | retired with the code it tests; its ordering assertions have nothing left to assert |
| `detonation_plan_selftest.gd` · `blast_purity_selftest.gd` | the plan's shape, not the class | **unaffected — and they are the regression net** |
| firearms (`apply_point_impact`) | nothing | **shares no machinery with this** (`PREDICTION_MASTER_PLAN` §2) |

---

## 4. THE ARCHITECTURE

> *"Em vez de fazer várias waves, podemos simplesmente calcular o estado final da
> cratera, colocar mais efeitos e fumaça por cima e simplesmente exibir o que
> sobra."* — the Director, 2026-08-27

**The inversion, in one line: today the WORLD is animated and the effects
decorate it. From here the world changes once, and the EFFECTS are what is
animated.**

| beat | frames | what happens | writes cells? |
|---|---|---|---|
| 0 · cook | 0 in real play | `build_plan()` → the final `WorldDelta`, **including what the fire consumes** and the passage | no |
| 1 · metal + flash | 5 | shrapnel out, negative strobe — unchanged, ratified 2026-08-26 | no |
| 2 · **THE COMMIT** | **1** | Voxel fields · every cell · expose · decals · **soot** | **yes, once** |
| 3 · consequence | N | smoke, embers, dust, debris, the symbolic fire — one channel, per-instance timing | no |
| 4 · the light lands | short | the Director's standing ruling, §7 | plane writes only |

**From beat 2 the board is FINAL.** Everything after it is drawing.

### 4.1 Why the crater does not need to be staged

The Director's fallback was *"calcular os 5 frames mais importantes no pre-cook e
soltar eles em alpha um depois do outro"*. §1.4 says the commit fits in ~43 ms, so
the staging is not needed — and it is worth writing down why it could never have
been done the obvious way:

⚠️ **A TileMapLayer cell cannot cross-fade.** It is set or it is erased. Anything
that fades in alpha has to be an OVERLAY drawn over a board that is already
final — which is the same conclusion as "one commit, then only drawing", reached
from the other side. The staged version is therefore **the documented fallback if
D-1 surprises us**, not a parallel design: it would be K overlay stages over the
same single commit.

### 4.2 The ordering does not vanish — it moves, into the Director's own axis

> *"Podemos deixar de fazer waves tão estritas e pensar em um sistema por GU de
> distância e por slice de altura."*

Ordering stops being *"on which frame do I write this cell"* and becomes *"when
does this instance light up"* — one float per instance, computed in the pure cook:

```
delay = RING_STEP_S * gu_ring
      + STOREY_BIAS_S * storey_from_impact
      + JITTER_S * fnv1a(cell)
```

That is the Director's proposal exactly, and the reason it is affordable is the
reason the current design is not: **a `delay` float on a MultiMesh instance costs
nothing, while a frame that writes cells costs 17 ms.** P7b already priced the
channel — collapsing every per-cell circle into one MultiMesh took the fire's
worst frame from 42.4 ms to 19.5 ms, and N instances cost what one costs.

The plan builder already computes `r` (radius in voxels) per entry and every entry
carries `cell` and `level`, so the GU ring and the storey are both derivable
where the entry is built — no new walk.

---

## 5. THE CONSEQUENCE CHANNEL

One overlay, one draw, per-instance timing. It carries what `_apply_entry()`
dispatches today (`smoke`, `ember`, `debris`) plus the symbolic fire, and it is
the only thing alive after beat 2.

### 5.1 The symbolic fire — §1 of the superseded plan, kept verbatim in intent

> ⚠️ **DOWNSCOPED 2026-08-29 — see §8.8.** Shown the shipped D-4a/b look, the
> Director closed the fire: *"a gente já chegou num visual bem bom, só falta um
> pouquinho de brasa nos materiais moles… o que a gente conseguir colocar de
> vermelho brilhando que vira preto é lucro. De resto pode deixar assim mesmo."*
> The spec below is NOT built as written. What shipped is a **boosted ember on
> every voxel the fire consumes** — `EmberOverlay` already ramps hot → red →
> charcoal, so "vermelho que vira preto" was a flag and two knobs, not a new
> overlay. The vibrating flame, the incandescent-voxel-left-behind and the
> visual ash-transmission are deliberately unbuilt.

The Director's spec (2026-08-27): a small flame vibrating ~0.5 s at the edge of
each hole, leaving an incandescent voxel; the glow darkening to black over ~1 s;
a puff of smoke upward for 1–2 s; and, before going out, a chance to pass the
ember on — *which destroys the voxel and turns it to ash*.

**Every state survives as the ANIMATION's own timeline rather than as world
state.** One ember animation, instanced per burning voxel, with per-instance
phase and per-instance smoke duration. The transmission that *"vira cinza"* is
decided in the cook (§6), never at play time — that is what keeps it out of the
second mutation stream.

What ships today is *"basicamente uma elipse com feather nas bordas e alpha"*
(the Director, on seeing `CircleField` over the burning region). **It is a
different thing, not a cheaper version of the above** — there is no per-voxel
flame in it to make smaller. This is the one part of the plan that is genuinely
new construction rather than deletion.

### 5.2 Durations in SECONDS, and this time the rule has teeth

§14.1's instruction — *"a change that alters frame cost silently retunes every
frame-denominated look value"* — is why every number in §5.1 is in seconds. It is
safe here in a way it was not before: the animation is per-instance and touches
no world state, so there is no commit cadence left to pin against a frame budget.

---

## 6. THE COOK OWNS WHAT THE FIRE CONSUMES

`_maybe_burn()` already decides which voxels burn and when, deterministically
(FNV-1a, inside the pure builder). Today it appends to `waves["burn"]`, a
SCHEDULE the room plays out over 1.38 s. It appends to the **delta** instead.

Consequences, in the order they matter:

1. `touched_this_blast` — the set that keeps this blast's own holes out of the
   soot wave — starts containing the fire's voxels, because it is built from the
   delta's projected state. **§9.11e dies at its actual root**, not behind a
   guard.
2. `blast_takes_share = 0.70` (F3/F4's split between "the blast took it" and "the
   fire will") becomes a **visual** attribution: everything is destroyed at once,
   and which voxels wear an ember is what tells the story.
3. `_advance_burn`, `BurnScheduler`, `BURN_COMMIT_INTERVAL_S`,
   `BURN_SUSPEND_REGION_LIGHT`, the burn profiler and the residue probe all lose
   their reason to exist.

⚠️ **THE PASSAGE MUST BE COMPUTED HERE, AND IT IS THE ITEM MOST LIKELY TO BE LOST.**
Today it EMERGES from the burn — measured live this session:

```
[E-BURN] fire out — 356 of 356 consumed over 1.38s · passage over 6 burnt edge(s):
         { "CROUCH": 1, "NONE": 3, "STANDING": 2 } · widest base storey 64/64 cells open
```

That is gameplay the agent walks through, it has a ratified rule
(`MATERIALS_MASTER_PLAN` §3.2: a CROUCH opening is both storey-faces of a pair
clear; STANDING is two stacked pairs), and with the burn gone `PassageQuery` has
to be run against the final delta inside the cook. **This is the Director's open
question 1 of the superseded plan and it is still open — see §9.**

---

## 7. THE LIGHT, AT THE END

> *"A questão da luz permanece, vamos aplicar ela no final, depois da explosão
> terminar. Pode fazer como você acha mais adequado."* — the Director, 2026-08-27

The ORDER is ratified and preserved: **soot, then light — scorch is what the
light is about to reveal** (§13.3). What is mine to decide is the shape, and here
is the decision with its reasoning, so it can be overturned on sight rather than
archaeology.

**7.1 The soot no longer needs a beat of its own.** §13.3's reason for moving it
late was that *"`_fade_in_soot()` ran the moment the wave ended, which is during
the fire, so decals appeared clean and scorch arrived while things were still
burning."* With no fire mutation stream there is nothing to arrive during. Soot
goes in the commit, where SS-3 already routes `scorch_writes`.

**7.2 The light ramp goes from 2.0 s to ~0.5 s**, landing as the smoke thins.
Reasoning: §14.2 measured that 96.8% of the ratified 2 s beat *was not a beat at
all* (640 of 661 changed cells skipped the ramp and arrived at the START), so the
2.0 s was never seen as 2.0 s of movement. It is a `var` and it is tuned on a
filmstrip by the Director, not settled here.

**7.3 The event's duration becomes ONE number.** Today it is four independent
ones (`front_frames`, the fire's span, `consequence_soot_seconds`,
`consequence_light_seconds`) that have each been retuned separately and twice
silently. After the reform there is a commit frame and a consequence length.

**7.4 ⚠️ The 176 ms derive is the last real stall, and it may be free.**
`play_consequence_light()` derives the whole board's light in one frame. But the
delta already knows the final occupancy — the cook's own WALK phase is 133 ms of
exactly that kind of work and already lights a PREDICTED crater correctly
(`PREDICTION_MASTER_PLAN` §8.8). **Whether the final light field can be computed
in the cook and applied as a pixel write is an open question, not a claim** — it
is §9's item 3 and it is scoped as its own task, because getting it wrong means
the board's light is wrong everywhere.

---

## 8. TASKS

| id | task | gate |
|---|---|---|
| ✅ **D-0** | **BUILT 2026-08-27 (§8.1) — fabric 4 797 → 2 310 ms, hard 2 940 → 878 ms.** The dress rehearsal — the new pacing on the OLD machinery.** `front_frames`, `consequence_soot_seconds`, `consequence_light_seconds` set to what §4 will produce. No architecture change, fully reversible. | The Director watches a 3× slow-motion video and says whether it is *pa-pum*. **This sets the target durations D-3 and D-5 build to, and it is cheap to be wrong here.** ⚠️ It also shows the crater arriving with no front — the one change in this plan that could read as broken (§9.4). |
| ✅ **D-1** | **MEASURED 2026-08-28 (§8.3).** ⛔ It corrects §8.1: the "18.55 ms collapsed frame" was an APPLY LOOP, not a frame. The real collapsed cell frame is **59.2 ms (fabric) / 31.6 ms (hard)**, and the commit frame is another 58.4 / 47.6. | ✅ Met, and the answer is that **the collapse fits** — §4.1's staged fallback is not needed. Instrument built: `INFILTRAITOR_EVENT_FRAMES=1` (`[E-FRAME]`), which keeps every frame of the event rather than bucketing them. ⚠️ The event's real worst frame is the **light derive at 201.9 ms** and neither D-1 nor D-3 touches it (§7.4). |
| ✅ **D-2** | **BUILT 2026-08-28 (§8.2).** The cook owns what the fire consumes (§6). ⚠️ The passage half changed shape: the bubble does NOT force an opening (§11.1a vetoes §11.1) — what shipped is `PassageQuery`'s criterion, amount instead of shape. | ✅ All three met. `blast_purity_selftest` + 39 others clean. **Cell probe `0 RESTORED · 0 VANISHED`** against a same-binary control that still reports **350 RESTORED**. The passage line is reported by `Room.report_blast_passage()` as `[E-PASSAGE]`, same shape, and both paths agree on the end state (STANDING ×3). |
| **D-2b** | **The pre-fabricated damage pattern** (§11.2) — an authored mask per (container class, ring, **material tier**) replacing `_select_deterministic()`'s hash ranking, authored in **voxel-local** coordinates (§11.3.4). Independent of the presentation reform. | **The Director looks at a crater.** ⚠️ Explicitly NOT gated on a millisecond: §11.2 measures the whole per-voxel determinism at 12.5% of a cook that is already 0 frames in real play. Plus: the **resistance ladder's selftests still pass** (§11.3.1), and **panels and `JunctionColumn` still take damage** (§11.3.3 — E-JUNCTION-01's exact regression). |
| ✅ **D-3** | **BUILT 2026-08-28 (§8.4).** `DetonationPresenter` behind `INFILTRAITOR_PRESENTER=1`, choreographer still default. One commit frame at **31.4 ms** (fabric) / 28.3 (hard); the consequence channel with the §4.2 delay. `DetonationEntryWriter` extracted first so both paths share the writing. | ✅ All met, plus D-5's early: cell probe `0 RESTORED · 0 VANISHED`, 40 selftests clean, and the **settled frame is pixel-identical (0 px)** between the two paths. ⚠️ One deliberate look regression: §7.1 removes the soot fade-in the Director asked for on 2026-08-19 — judge on the video before D-6. |
| ✅ **D-4** | **DONE — SMOKE (§8.6, §8.7) + THE BRASA (§8.8).** §8.7's plumes ship, and finding them exposed a P7b defect: `CircleField` had no `custom_aabb`, so every MultiMesh field had been culling its most distant particles since it shipped. Per-material `smoke_chance` and the height axis shipped. §8.8: the symbolic fire was **downscoped by the Director on 2026-08-29** to *"um pouquinho de brasa nos materiais moles"* — `_mark_burnt_embers()` flags the ember on every consumed voxel and the writer routes it through `EmberOverlay`'s boosted profile. No new overlay, no new wave kind. | ✅ The Director looked at the shipped D-4a/b and closed it: *"pode deixar assim mesmo"*. §8.8's brasa judged on the filmstrip. |
| ✅ **D-5** | **BUILT 2026-08-29 (§8.9).** `consequence_light_seconds` 2.0 → 0.5 — the D-0 rehearsal value. Soot was already in the commit (D-3/D-3b). One `var` default; `INFILTRAITOR_LIGHT_SECONDS` still overrides. | ✅ Met by containment, not by a single 0. Same binary, same `INFILTRAITOR_RNG_SEED`, 0.5 s vs 2.0 s: **every differing pixel is inside the crater bbox — 0 outside** (`>32`: 263 in / **0 out**). The literal "settled final frame" is unreachable because the 2.0 s control ramp outlives the capture's held-camera window; the destination is identical by construction — `play_consequence_light()`'s terminal `_write_cell_bucket(to_bucket[k])` loop is unconditional. |
| ✅ **D-6** | **Remove the old path** (§3.2). **Part 1 SHIPPED (§8.11):** everything runs the presenter, the `INFILTRAITOR_PRESENTER` gate is gone, `is_resolving_action()` rewired to a blast-lock the presenter releases when the smoke is up. **Part 2 SHIPPED (§8.11):** the choreographer + selftest, `BurnScheduler` + selftest, `FireGlowOverlay`, `_advance_burn`/`start_burn`/`_burn_precook`/`_burn_final_repaint`/`_burn_residue_probe`/`await_destruction_settled` + the whole `_burn_prof_*` wall + `_capture_two_fires` are gone; `waves["burn"]` dropped from `WorldDelta`; `cook_owns_fire` → deleted (always true); `INFILTRAITOR_NO_BURN` gate moved into `_maybe_burn`; `consequence_light_seconds` 0.5 → 1.0. ~3 000 net lines. | ✅ Repo-wide grep clean (only prose/history refs remain). Lint ✅, selftests **38 clean / 0 failed** ✅ (40 → 38), invariants ✅, CODEMAP ✅. 3× video: `d6_BEFORE_choreo.mp4` vs `d6_AFTER_presenter.mp4` — the whole event still plays (fuse → boom → crater → embers → plumes → soot → light). |
| ✅ **D-8** | **DEFER THE LIGHT DERIVE UNTIL THE SMOKE CLEARS (§8.12).** `DetonationPresenter._wait_for_smoke()` polls `SmokeSparkOverlay.smoke_count()` before `play_consequence_light()`. The Director saw the ~202 ms freeze reading as a stutter over drifting smoke. | ✅ The Director watched the real-time video: the freeze now lands on a still, empty scene (~5.0 s) and does not read. **Not §7.4** — the derive still costs 202 ms. |
| **§7.4** | **THE LIGHT COOK.** Compute the light field in the pure cook (the WALK phase already does 133 ms of that work and lights a predicted crater right — `PREDICTION_MASTER_PLAN` §8.8) and apply it as a pixel write. Removes the ~202 ms freeze D-8 only hides. | The board's light is pixel-identical to the current derive result, everywhere. Its own task — getting it wrong is wrong everywhere. |
| **D-7** | **The rhythm pass** the Director deferred (*"o ritmo ainda precisa melhorar"*). ⚠️ **Carries `SOOT_STORAGE_REFORM` SS-6** — now explicitly wanted (§11.3.4) and blocked on a capture action that rotates the view, which does not exist. | Video, 3× slow motion — the instrument that found every defect of the last four sessions. |

**Order rationale.** D-0 first because it is one session, fully reversible, and it
tells us what the rest is building toward — deciding the target durations AFTER
building the machinery is how `front_frames` got retuned three times. D-1 second
because §4.1's fallback branches there and nowhere else. D-6 last, because a
removal is irreversible and the replacement should be proven before the thing it
replaces is gone.

### 8.1 ✅ D-0 IS BUILT AND MEASURED — 2026-08-27

Three env overrides, no architecture: `INFILTRAITOR_FRONT_FRAMES`,
`INFILTRAITOR_SOOT_SECONDS`, `INFILTRAITOR_LIGHT_SECONDS`. Both pacings now run
from the same binary, so a before/after needs no stash — the discipline
`INFILTRAITOR_SOOT_STORE_READ` earned on 2026-08-27.

Rehearsal setting: `FRONT_FRAMES=1 · SOOT_SECONDS=0.15 · LIGHT_SECONDS=0.5`.

| flash → blast over | control | rehearsal |
|---|---|---|
| **hard** (concrete, no fire) | ~2 940 ms | **878 ms / 48 frames** |
| **fabric** (with fire) | 3 891 ms | **2 310 ms / 122 frames** |

#### ⚠️ AND `front_frames = 1` IS D-1's CELL-WRITE HALF, MEASURED RATHER THAN SUMMED

`front_radius_for()` returns `INF` on the last frame, so at 1 the entire queue
drains on frame 1. That is the collapsed commit frame's cell writes, today:

```
fabric   [E-WAVE] frame 1 front_r=inf cells=2820/2820 elapsed=31ms apply=18.548ms
hard     [E-WAVE] frame 1 front_r=inf cells=1559/1559 elapsed=11ms apply= 4.205ms
```

⛔ **READ §8.3 BEFORE USING THESE TWO NUMBERS.** They are `apply=` figures — the
CPU inside the loop — and D-1 measured the FRAMES they sit in at **59.2 ms** and
**31.6 ms**. The comparison below is still valid (both sides are apply loops) and
the conclusion still holds; what is wrong is calling either one "the collapsed
commit frame".

**18.55 ms against §1.4's predicted 20.13, and 4.21 against 5.68 — collapsed is
CHEAPER than spread, on both materials.** That is the "per frame that writes, not
per cell" model confirming itself: 24 flushes became one. So the single commit
frame lands at:

```
fabric   11.2 (commit) + 18.5 (cells) + ~12 (the fire's own consumption)  =  ~42 ms
hard     11.2           +  4.2                                            =  ~16 ms
```

**§1.4's estimate holds and D-1's risk is retired for the cell half.** What D-1
still owes is the real thing with the fire's consumption folded in (§6), which
does not exist yet.

#### The finding that sets the rest of the order

Of the fabric rehearsal's remaining 122 frames, **74 are the fire's schedule**
(1.38 s at 60 fps). Subtract them and fabric lands on 48 frames — **exactly the
hard number**. So:

```
control          4 797 ms
D-0 (pacing)     2 310 ms   fabric  ·   878 ms  hard
after D-2        ~ 880 ms   both, projected — the fire stops being a schedule
```

**D-0 buys half and D-2 buys most of the rest.** The consequence channel (§5) is
then free to spend as many drawing frames as the Director wants, because they
cost ~17 ms and write nothing.

#### What D-0 deliberately does NOT fix

`[E-FUME-ERASED] 350 of 1914` still fires under the rehearsal, unchanged. D-0
changes pacing, not architecture; §9.11e is D-2's. ✅ **Closed by D-2 — §8.2.**

### 8.2 ✅ D-2 IS BUILT AND MEASURED — 2026-08-28

`_maybe_burn()`'s rolls are untouched (BURNROLL / BURNLIFE / BURNSHARE), so WHICH
voxels the fire consumes is bit-identical — 356 of 356 on both paths. What moved
is WHERE the answer lands: a new **PHASE_BURN between WALK and SOOT**, folding the
fire into the Delta as DESTROYED damage. It has to sit there and nowhere else,
which is the finding that made the task bigger than "call `add_damage()` instead":
`_build_ember_wave()` used to run at the END of PHASE_SMOKE, **behind every
consumer a burnt voxel needs** — `touched_this_blast` (PACKAGE), the soot BFS
seeds (SOOT), `occupancy` (WALK, read by LIGHT), and `touched_voxels`
(VL-PERSIST). So it was reseeded from the Delta's projection instead of from the
packaged `destroy` wave, which is the same set by construction.

⚠️ **The entries are folded in ONE batch at the end of the phase.**
`add_damage()` folds immediately, so a burnt voxel folded mid-pass reads DESTROYED
to the next ember seed and silently stops lighting. That is what keeps the ember
set identical and makes this a change of ownership rather than of look.

`INFILTRAITOR_BURN_SCHEDULE=1` restores the old path whole, so every row below is
one binary, one map, two behaviours.

| fabric wall, gu (31,3) | control (legacy schedule) | **D-2** |
|---|---|---|
| commit | 951 voxels, 11.4 ms | **1 307 voxels, 12.4 ms** — exactly +356 |
| the fire | 356 of 356 over 1.37 s, as a schedule | **356 consumed IN THE COMMIT** |
| **`[E-FUME-ERASED]`** | **350 of 1 914** | **0 of 1 765** |
| **cell probe** | 1 163 erased · **350 RESTORED** (f127) | 1 169 erased · **0 RESTORED · 0 VANISHED** |
| passage, end state | STANDING ×3, base storey 64/64 | STANDING ×3, 100% removed — **the same** |
| flash → blast over | 4 981 ms / 266 f | **4 113 ms / 217 f** |
| hard wall, `[E-FUME-ERASED]` | 0 of 879 | **0 of 879** — untouched |

**The end state agreeing is the load-bearing row.** Both paths finish with the
same three STANDING passages over the same wall, which is what makes "the fire
moved houses" a defensible claim rather than "the fire changed".

**And the picture confirms it independently.** Frame 279 of the same filmstrip,
control vs D-2: **19 621 differing pixels in ONE bbox**, (536,146)–(712,435) — the
control has a slab of wall standing back across the top of the opening and D-2
does not. That is the 350 cells, seen. Both probe runs reproduced across two
boots (1 169 / 0 twice).

⚠️ **One number is not accounted for: 1 169 erased vs the control's 1 163.** Six
cells the new path erases and the old one did not, 0.5%, in the direction of MORE
erased. Named rather than explained — the two gates it could have poisoned
(RESTORED, VANISHED) are both 0 and the end state matches.

**What D-2 deliberately does NOT do:** remove `BurnScheduler`, `_advance_burn`,
`BURN_COMMIT_INTERVAL_S` or the burn profiler. They are the control, and a
removal is D-6's — proven before gone.

---

---

### 8.3 ✅ D-1 IS MEASURED — 2026-08-28, and it CORRECTS §8.1 and §1.4

Built for it: **`INFILTRAITOR_EVENT_FRAMES=1`**, the `[E-FRAME]` probe
(`Room.event_probe_arm/beat/report`). It keeps **every frame's gap** for the whole
event and records the beats as MARKS on that timeline, rather than bucketing
frames by beat — the first version did bucket them and was unreadable within one
run, because seven beats fire inside the commit frame alone, so `BEAT 3` came out
with zero frames while the frame that wrote 3 531 cells was charged to `SOOT RAMP`.
The beats are named off `TestZoneController._prof()` itself, so there is no second
list of beats to drift from the first.

Fabric gu (31,3) and the default hard grenade, `INFILTRAITOR_FRONT_FRAMES=1`, D-2
in force (the fire is inside the commit):

| the frame that… | §1.4 / §8.1 said | **measured FRAME** | the apply loop inside it |
|---|---|---|---|
| commits, fabric | ~43 ms | **58.4 ms** | 12.4 ms |
| writes every cell, fabric | "18.55 ms measured" | **59.2 ms** | 19.8 ms |
| commits, hard | ~17 ms | **47.6 ms** | 6.5 ms |
| writes every cell, hard | "4.21 ms measured" | **31.6 ms** | 4.4 ms |

⛔ **§8.1's "the single collapsed commit frame is 18.55 ms measured" IS WRONG, and
it is this plan's own mistake made on itself.** 18.55 was `[E-WAVE]`'s `apply=`
figure — the CPU *inside* the loop. The FRAME is 59.2 ms. The missing ~40 ms is
the TileMapLayer's own work for 3 531 changed cells, charged after the loop
returns and invisible to any probe inside it. §1.3 is built on exactly this
distinction and §8.1 still fell for it.

**The model survives, refined.** A writing frame costs roughly
`baseline + per_cell x K`, with baseline ~17 ms and per-cell ~10–12 µs (of which
only 3–6 µs is the apply loop):

```
fabric  3 531 cells   17 + 42 = 59   measured 59.2
hard    1 559 cells   17 + 15 = 32   measured 31.6
default pacing, 23 frames: 23x17 + 42 = 433   measured 404
```

So **collapsing does not make the per-cell work cheaper — it removes 22 baselines**,
~374 ms, which is the whole of the saving and is exactly what D-0 measured as a
duration win. "Cost is per frame that WRITES, not per cell" was half right: the
FIXED part is per frame, and there is a real per-cell part on top of it.

**Verdict: the collapse fits, and §4.1's staged fallback is NOT needed.** 59 ms is
~3.5 dropped frames on the single densest moment of the game's biggest event,
against 23 frames and 404 ms of spread. D-3 merging the commit frame into it
projects to **~85 ms on fabric** (`17 + 42 + the commit's own 12.4 + census +
persist`), not §1.4's 43 — and that projection is D-3's own gate, not a claim.

⚠️ **AND THE REAL WORST FRAME OF A DETONATION IS NEITHER OF THEM.** It is the
light derive: **201.9 ms (fabric) / 160.2 ms (hard)**, one frame, and §1.3 named
it at 176 ms before any of this. Nothing D-1 or D-3 does touches it — it is §7.4,
and it is now the only thing in the event above 60 ms.

```
[E-FRAME] detonation — 193 frame(s), 3686 ms, mean 19.1 · WORST 201.9 ms on frame 73
  f36  COMMIT    its frame  58.4 ms
  f41  BEAT 3    its frame  59.2 ms · (the whole queue, 3531/3531)
  f73  LIGHT     its frame 201.9 ms · then 120 f, 2183 ms
```

---

### 8.4 ✅ D-3 IS BUILT — 2026-08-28, behind `INFILTRAITOR_PRESENTER=1`

`DetonationPresenter` (211 lines against the choreographer's 933) does §4's three
beats: **one frame that writes every cell**, then N frames that write none, then
the light. It contains no `flatten_plan()`, no `_sort_key()`, no
`KIND_RADIUS_BIAS`, no `front_radius_for()`, no `front_frames` and no
`_fade_in_soot()` — §3.1's "the ordering problem stops existing" is literal.

**`DetonationEntryWriter` was extracted first**, unchanged in behaviour, and that
was the enabling move rather than tidying: §3's table says the cell writes and the
VFX dispatch SURVIVE the reform, two paths now need them, and D-3's own gate
demands both run from one binary. Copying `_apply_entry()` would have created the
second place for them to drift and left D-6 reconciling two versions instead of
deleting one file. The choreographer now delegates to it; the 40 selftests were
green across that step alone, before anything new existed.

| fabric gu (31,3) | choreographer, default | choreographer, `FRONT_FRAMES=1` | **presenter** |
|---|---|---|---|
| worst cell-writing frame | 29.1 ms (x23 frames) | **59.2 ms** | **31.4 ms** |
| apply inside it | — | 19.8 ms | **9.96 ms**, 3 584 cells |
| the whole event | 217 f / 4 069 ms | 193 f / 3 686 ms | **173 f / 3 332 ms** |
| consequence channel | — | — | 1 712 effects / 12 f / 214 ms |
| hard: commit frame · event | — | 31.6 ms · 190 f | **28.3 ms · 172 f / 3 183 ms** |

⚠️ **THE PRESENTER'S COMMIT FRAME IS HALF THE CHOREOGRAPHER'S COLLAPSED ONE, at a
slightly HIGHER cell count** (31.4 ms / 3 584 cells against 59.2 ms / 3 531). Two
causes, and only the first was designed: the presenter writes the real scorch once
where the choreographer writes clean and then repaints 1 765 cells four more times
(§7.1), and its apply loop is 9.96 ms against 19.8 — **the same cells written in
container order instead of radius-interleaved order**. `flatten_plan()`'s radial
sort was scattering writes across TileMapLayer quadrants. Nobody predicted that
and it is worth not forgetting: the ordering machinery was not free even inside
one frame.

**The gates, all three met:**
- **Cell probe green** — `1 169 erased · 0 RESTORED · 512 appeared · 0 VANISHED`,
  identical to D-2's numbers on the choreographer.
- `detonation_plan_selftest` + `blast_purity_selftest` untouched and passing, with
  the other 38.
- **And D-5's gate is already met, early: the settled frame is PIXEL-IDENTICAL —
  0 differing pixels** between the two paths, same map, same boot conditions. That
  zero is earned: the same comparison on the same two images reported **19 621
  differing pixels** for D-2's real change, so the instrument is not blind.

⚠️ **ONE LOOK REGRESSION — ✅ CLOSED THE SAME DAY BY D-3b (§8.5).** §7.1 puts
the scorch in the commit, so **the soot fade-in was gone** — and a fade-in is what
the Director asked for on 2026-08-19 (*"a fuligem pode ser processada depois do
fato, desde que apareça com fade in, e não de repente"*). The settled frame is
identical; what changed is that the scorch now ARRIVES with the crater instead of
ramping over 32 frames. This is §7.1 doing exactly what it says, but it overrides
a standing ruling and should be watched on the video before D-6 makes it
permanent.

⚠️ **The light is now 66% of the event and is untouched:** 202.9 ms in one frame,
then 120 frames and 2 190 ms. Everything else in a detonation is now under 32 ms.
§7.4 is no longer one item among several — it is the whole remaining problem.

---

### 8.5 ✅ D-3b — THE SCORCH FADES IN AGAIN, 2026-08-28

> Director: *"daria pra fazer a fuligem entrar com fade in de 4 ou 5 frames? Ou é
> muito trabalho pra pouca vantagem?"*

Cheap, and it gives back the 2026-08-19 ruling §7.1 had dropped. **5 steps, 4 drawn
frames, 2 407 cells, 79 ms of writes total; the event goes 173 → 178 frames
(3 332 → 3 404 ms).**

⚠️ **IT IS HALF OF `_fade_in_soot()` — the half that was never the problem.** That
function did two things: a `set_cell()` block re-placing tiles from a cook-time
`source_id` (§9.11e's writer, 350 cells put back onto holes the fire ate) and a
ladder walk that only touches the SOOT PLANE. §3 killed the function for the first
half. The presenter's commit frame has already placed every cell correctly with
live data, so only the ladder is needed and **there is no `set_cell()` in it at
all** — the fade comes back without the defect coming back with it.

⚠️ **§9.11a HAD TO BE CARRIED ACROSS, and it is why `soot_ramp_cells` is per-cell
rather than a flag.** The choreographer writes clean EVERYWHERE (`soot_clean`)
because its ramp repaints everything after. The presenter cannot: the soot wave
admits cells whose LIGHT BUCKET moved with their scorch unchanged — a cell in an
older crater across the map — and writing those clean and walking them back is the
Director's 2026-08-23 report (*"a segunda explosão influencia na fuligem da
primeira"*), measured at 180 cells flashing for five frames and returning to
exactly their old value. Only cells actually changing are allowed to start clean;
everything else is written at its real value in the commit and never goes clean.

`DetonationEntryWriter.lightened()` (moved off the choreographer) is the same
ratified ladder: faces lightened by k, k walking to zero, so a face landing on tone
0 climbs the whole ladder and one landing on tone 3 arrives in a single step.

**Gates re-run with the fade in: cell probe `0 RESTORED · 0 VANISHED`, and the
settled frame is still 0 px against the choreographer.**

---

### 8.6 🟠 D-4a — THE DESTRUCTION SMOKE, 2026-08-28

> Director: *"voxels destruídos soltam uma fumacinha, com tempo, intensidade e
> altura ligeiramente variando (isso esteve presente no código em algum momento)…
> Não é necessário que cada voxel destruído produza alguma coisa, vamos estipular
> uma chance maior ou menor conforme o tipo do material."*

**It was never missing.** `_append_voxel_smoke()` → `waves["smoke"]` →
the presenter → `SmokeSparkOverlay.add_smoke()` → `CircleField` is intact end to
end and fires on every damaged voxel: **~1 309 puffs on fabric, ~460 on concrete**,
measured. So *"vamos usar"* rather than rebuild — what shipped is the two axes the
spec asks for that genuinely did not exist, plus the diagnosis of why it does not
read.

**Built:**
- **`MaterialResistanceTable.smoke_chance()`**, a per-material row rolled FNV-1a
  per cell in the pure builder. Masonry 0.40, wood 0.30, plywood 0.28, glass and
  metal 0.15, cardboard 0.12, fabric 0.10 — the Director's own split, since this
  smoke is *"mais direta, que vai funcionar bem com materiais duros"* and soft
  materials get flames instead. Measured: concrete **460 → 171** puffs.
  ⚠️ The roll is placed BEFORE `smoked_gus` is marked, so a GU whose voxels all
  lose the roll still gets `_phase_smoke()`'s GU-level remainder — thinning per
  voxel, never per GU.
- **The HEIGHT axis.** `add_smoke()` has taken a `drift_scale` since E-SPARK-04
  and **no blast ever passed it** — every puff in every explosion rose at exactly
  the same rate. Now hashed per cell (0.65–1.55) in its own domain.
- `SMOKE_ALPHA_GAIN` / `SMOKE_SCALE_BASE` / `INFILTRAITOR_SMOKE_CHANCE` /
  `_FEATHER` — bracket knobs, so the look is picked off a video.

⛔ **THE FIRST FEATHER ATTEMPT DID NOTHING, AND TWO RENDERS "LOOKED BETTER" WITH
IT IN.** A feathered MESH with vertex alpha draws nothing on a
`MultiMeshInstance2D`: `MultiMesh.use_colors` supplies the instance colour and the
mesh's `ARRAY_COLOR` never reaches the fragment. Proved rather than argued — the
rim was temporarily set to OPAQUE RED and a real capture found **0 reddish pixels
on every frame**. The apparent improvement was run-to-run variance: `add_smoke()`
rolls offset, velocity, duration and radius with `randf_range`, so two boots never
match and no cross-boot screenshot pair can judge a subtle change.

**What works is a fragment shader**, and it needs a `varying` carrying the vertex
COLOR: a custom `canvas_item` shader initialises `COLOR` from `TEXTURE`, and a
MultiMeshInstance2D with no texture has nothing there. Same probe, **19 sampled
red pixels** — non-zero, so the path is real. P7b is untouched: its cost is CPU
submission per vertex, and this changes neither the vertex count nor the overdraw.

⚠️ **AND I FRAME-INDEXED A DETONATION TWICE WHILE PROBING**, which §14 already
documents as impossible — the cook is budgeted in ms, so the blast lands on a
different frame every boot. Both probes read one hardcoded frame, found nothing,
and had to be re-run scanning EVERY frame. The rule has now cost three sessions.

### 8.6a ⚠️ WHY IT STILL DOES NOT READ AS SMOKE — a LOOK question, for the Director

Isolated by forcing smoke GREEN and dust BLUE on one real concrete blast:

```
max GREEN (smoke) 162 sampled px      max BLUE (dust) 11   <- noise, pre-blast frame
```

**The dark discs in a crater are the SMOKE, not the dust** (`dust_speck_radius` is
2.6 px; they were never dust). And the smoke is dark because
`_vfx_smoke_color_for_material()` tints each puff with **the material's own
albedo** — VFX-01's ratified choice, *"wood reads as dark smoke, masonry as
light"*. On a dark floor material that yields a puff DARKER than the floor it sits
on, and smoke darker than its background reads as a hole, not as smoke.

That is a design decision, not a defect, and it is the Director's: **should a puff
ever be allowed to be darker than the surface it leaves?** Everything else is
tuned in minutes off the bracket knobs once that is answered.

---

### 8.7 ✅ D-4b — THE PLUMES, AND THE `CircleField` DEFECT THEY EXPOSED

> Director, 2026-08-28, with two annotated frames: *"queremos efetivamente que ela
> seja mais presente e maior, subindo e se dissipando, persistindo pelo menos mais
> 1 segundo depois da explosão… As areas afetadas pela explosão soltam uma fumaça
> no final. Não confundir com a fumaça da granada que já está funcionando, que são
> os pequenos círculos se expandindo do centro para fora."*

⚠️ **THAT SENTENCE RECLASSIFIES ALL OF §8.6.** The per-voxel puffs D-4a thinned and
varied are the ones the Director calls *already working*. What is missing is a
DIFFERENT effect — a few large columns rising off the affected areas at the end —
and no amount of tuning the puffs could have produced it. Half a session went into
the wrong population before the second drawing said so.

**Built, and provably in the plan:** `_append_plumes()` emits one column per damaged
GU (`PLUME_PUFFS` puffs from one point, staggered over `PLUME_SPAN_S`, each ~2x the
scale and 1.5x the lifetime of a puff, rising 1.7x harder). Seeded from the HIGHEST
damaged voxel of each GU, which is what puts a column on a WALL rather than always
on the floor — the Director's drawing has two of those. They ride in
`waves["smoke"]` with an explicit `at`, which `_delay_for()` honours and does NOT
clamp to the channel's span. Measured: **96 columns over 24 damaged GUs, last
released at 1.27 s**, and the channel now runs 78 frames instead of 14.
`detonation_plan_selftest` grew a `_check_plumes()` that keeps the two populations
apart: *8 plumes against 64 puffs, fewer, larger (base 6.89 vs 3.90, mean 4.54 vs
1.64), out to 1.20 s.*

### ✅ RESOLVED — and it was never the plumes: `MultiMesh` had no `custom_aabb`

The plumes did not draw. Bisected rather than guessed, four experiments:

| experiment | result | what it eliminated |
|---|---|---|
| per-voxel puffs given the PLUME's values (scale 6.5, dur 1.5, drift 1.7) | **127 magenta px** | the values |
| plume release time forced to `at = 0` | **0** | the late dispatch |
| probe inside `SmokeSparkOverlay` | **96 magenta in `_smoke`, 96 pushed per frame** | the entry path, `add_smoke`, a population cap |
| positions of both groups in one frame | magenta x **-492..325**, others x **-220..-36** | — this is the answer |

**Godot derives a MultiMesh's visibility bounds from its BASE MESH, and
`CircleField`'s base mesh is a circle of radius 1.** The per-instance transforms
carry the real positions and radii and are not in that box, so instances far from
the node origin are culled before they are drawn. The per-voxel puffs cluster
tightly and survived; the plumes spread four times wider and did not. One line —
`_mm.custom_aabb` — took them from **0 to 4 055 magenta pixels** on an otherwise
identical capture.

⛔ **THIS IS A P7b DEFECT, NOT A D-4 ONE.** Every `CircleField` has been silently
losing its most distant particles since P7b shipped — smoke, embers and dust alike.

⚠️ **AND IT IS WHY P7b's "0 differing pixels" GATE PASSED.** That gate is the
static `circle_gate` scene, whose circles all sit near the origin, so nothing it
draws is ever outside the box. **A green gate that cannot reach the failure is not
evidence** — the same lesson the atom gate already cost a session.

⚠️ **I REVERTED THE FEATHER ON A MISDIAGNOSIS AND PUT IT BACK.** It was blamed for
the plumes not drawing, and the red-rim probe's low count (19 px) was read as "the
shader barely works" when it was the AABB culling the same instances. The feather
never broke anything, and with the plumes finally visible it turned out to be
necessary: at `PLUME_ALPHA` 3.6 they rendered as *"a heap of hard-edged discs"* —
the exact failure `SMOKE_COLOR`'s own note predicts.

**Final tuning, Director 2026-08-28** (*"ficou ótimo, mas pode fazer toda a fumaça
com puffs menorzinhos e mais suaves"*) — applied to BOTH populations, which is what
"toda a fumaça" asks for:

| | before | shipped |
|---|---|---|
| `SMOKE_SCALE_BASE` (per-voxel) | 2.3 | **1.7** |
| `PLUME_SCALE` (columns) | 5.0 | **3.4** |
| `PLUME_ALPHA` | 3.6 → 1.9 | **1.7** |
| `PLUME_PUFFS` per column | 4 | **3** |
| feather (puffs and dust) | 0.55 | **0.75** |

⚠️ The overlay's own `smoke_start_radius` / `smoke_end_radius` were deliberately
NOT touched: they are shared with the muzzle flash and the firearm smoke, which the
Director has separately called correct. Size is changed on the BLAST side only.

⚠️ **The pacing question it raised is ANSWERED and the length is RATIFIED.** The
plumes push the event from 3.2 s to 4.3 s because the light waits for them.
Director: *"Pode deixar a luz ser atualizada só depois da fumaça mesmo… a mudança
de iluminação vai ser assumida como um evento da rodada. Faz parte da dinâmica de
turnos, mostrando as consequências de uma ação. Pode manter os 240 frames rodando
até a fumaça se dissipar. Esse tempo pode ser usado pra adiantar o cálculo da
iluminação."* So a future perf pass must not "fix" the 240 frames — and §7.4 gains
a new opening: that second is somewhere the light derive could be hidden.

⚠️ An attempt to start the light early was built and thrown away, and it hid a real
defect worth remembering: `Room.play_consequence_light()` is `-> void`, so calling
it without `await` returns `null`, a `if coro != null` guard never closes, and the
light was **restarted on every frame**. `[E-FRAME]` caught it at once (a dozen
`LIGHT` marks, frames at 92–100 ms against the usual 18); the PICTURE never would
have, because concurrent ramps converge on the same final state.

---

### 8.8 ✅ D-4 — THE BRASA, DOWNSCOPED, 2026-08-29

> Director, shown the shipped D-4a/b look: *"a gente já chegou num visual bem bom,
> só falta um pouquinho de brasa nos materiais moles, e pronto. Faz como você
> achar melhor, o que a gente conseguir colocar de vermelho brilhando que vira
> preto é lucro. De resto pode deixar assim mesmo."*

**§5.1's spec is not built, and it did not need to be.** `_build_ember_wave()`
already queues **exactly one ember on every voxel the fire consumes** — the proof
is structural: `_maybe_burn()` is only ever called from `_build_ember_wave()` /
`_climb_from()`, always immediately after that same cell gets its ember, so
`burnt ⊆ ember-wave cells`. Measured on the real PLAYGROUND fabric wall: **235 of
235 consumed voxels carry an ember.** And `EmberOverlay` already ramps yellow-hot
→ deep red → charcoal and hands a puff to the smoke overlay on death. "Vermelho
que vira preto" was **already on screen** — it was tuned small and dim for a
hard-material crater's crowding (E-EMBER-02).

**What shipped is a flag and two knobs:**

- **`DetonationPlanBuilder._mark_burnt_embers()`** — runs in PHASE_BURN right
  after `_commit_burn_to_delta()`, walks `waves["ember"]`, and sets `burnt: true`
  (plus `at`, the retired schedule's pace) on every entry whose cell is in
  `burnt`. `[E-BURNEMBER] 235 of 235`.
- **`EmberOverlay.burnt_ember_gain` (1.6)** and **`burnt_ember_cool_rate`
  (0.72)** — the boost a flagged ember gets: bigger radius, longer life, and the
  red held a touch longer before charcoal. `DetonationEntryWriter` reads them and
  passes them to `add_ember()` as `radius_scale`, a `duration_scale` multiplier
  and `cool_rate`.
- **An unflagged edge ember passes `1.0 / 1.0` and is byte-for-byte unchanged**,
  which is why **wood's ratified VL-D4 look is untouched** — wood has
  `burn_consumption == 0`, produces no `burnt` cells, and flags nothing.

**Works on both paths** — the writer is shared (D-3), and `ember` is already in
the choreographer's `PLAYED_KINDS`. The choreographer ignores `at` and paces the
flagged embers with its radial front; the presenter releases them by `at`, in the
order the fire spread. **No new overlay, no new wave kind, no new writer branch** —
the D-4b plume precedent.

⚠️ **A flagged ember sits ON the hole the fire opened**, which is the exact
opposite of `_build_ember_wave()`'s survivor predicate. `detonation_plan_selftest`
`test_7` pins that predicate for the UNFLAGGED embers; the new `test_11` pins the
inverse for the flagged ones (every flagged ember on a destroyed cell, carries
`at`; a concrete blast flags none). The two rules live side by side on purpose.

**Deferred, on the Director's instruction:** glass — *"tem que quebrar muito mais
com a granada, mas vamos fazer isso no final da milestone de materiais"*
(`MATERIALS_MASTER_PLAN` M4, the non-local pane break).

---

### 8.10 ✅ THE FUSE/BOOM PRE-PASS, 2026-08-29 (before D-6)

> Director, on the D-6 "before" video: *"the flash negativo está demorando muito
> depois da detonação. A cena fica praticamente vazia aos 1s"*, then the model
> correction: *"the grenade should be intact when cooking. This is where in real
> life we pull the pin, throw it, and wait for the boom. This period of anxiety
> can be delayed more or less at will to buy process time. Then, the grenade
> becomes shrapnels and everything else happens."*

- **`spawn_blast_burst()` + the camera shake moved from beat 1 to beat 2** (the
  boom, with the shrapnel and the strobe). They used to fire the instant the
  sequence started, so on a long cook the fireball had bloomed and decayed
  before the strobe.
- **The grenade sprite stays visible through the cook** and is hidden at the
  boom — the two call sites stopped hiding it early, and `_start_detonation_sequence()`
  took a `grenade` param.
- **`spawn_fuse_sputter()`** (was `spawn_cook_flame`) — a tiny grenade-sized
  flicker + the odd spark, spawned every frame of the cook and the owed lead
  frames.
- **`cook_budget_ms` 8 → 14** — on the 3× filmstrip the harness enters instantly,
  so the whole ~340 ms cook fell before the strobe; this brings the boom to
  ~0.45 s there. Real play has 0 cook frames either way.

Shipped `76b58a5c`. Cell probe unchanged; the commit now lands ~10 frames earlier
(the pre-pass shortened the visible cook).

### 8.11 🟠 D-6 PART 1 — THE PRESENTER IS THE ONLY PATH, 2026-08-29

**Shipped `e475284f`.** `_start_waves()` runs the presenter unconditionally;
`_start_presenter()`, the `INFILTRAITOR_PRESENTER` env gate and
`_active_choreographer` are gone (→ `_active_presenter`). `_warm_prediction()`
dropped `flatten_plan()`/`playback_queue` (the presenter writes in container
order); `detonation_prediction.gd` lost the field. `_entries_playback_will_drop()`
checks the new `DetonationPresenter.PLAYED_KINDS`. The controller's burn-wave
handoff (`start_burn` / `INFILTRAITOR_NO_BURN`) is removed.

**`is_resolving_action()` rewired.** Was `_burn_scheduler.is_burning()`; now a
`_blast_resolving` flag — `Room.begin_blast_lock()` at the fuse,
`Room.end_blast_lock()` from the presenter the instant every smoke entry is
dispatched. Director's answer 2: *"É pra travar durante o fogo mesmo, até o
momento que todas as fumaças estiverem instanciadas e subindo. A partir daí o
mundo pode continuar, inclusive a mudança da luz… essa mudança vai durar cerca de
1 segundo, onde vamos colocar um efeito sonoro pra marcar (swiffhh). De quebra
ganhamos tempo pra fazer o cálculo sem interferir na explosão."* — the Diablo II
"Den of Evil" effect. The turn advance (not built — no turn system yet) waits for
the light to land.

**Cell probe on the default path:** `1169 erased · 0 RESTORED · 512 appeared ·
0 VANISHED` — identical to every run since D-2.

#### Part 2 — what still has to go, and the Director's 3 answers

1. **`_burn_precook` (P7c):** *"Se a performance está ok, acredito que podemos
   remover. Mas é bom avaliar se o mecanismo ainda pode ser útil pra melhorar o
   desempenho."* — remove; its input (`burn_wave`) is empty since D-2, and the
   "pre-mint ahead of a staged reveal" idea already lives as W-PRECOOK. The
   *light-derive* precompute (§7.4) is a different mechanism.
2. **`is_resolving_action()`:** answered above — done in part 1.
   `consequence_light_seconds` → ~1.0 s (was 0.5) for the ~1 s Diablo-style
   transform; the swiffh SFX is deferred to the audio pass.
3. **`FireGlowOverlay`:** *"Se o glow não está aparecendo pode tirar."* — remove
   it; it only ever washed the edge of the `BURN_SUSPEND_REGION_LIGHT` frozen
   region, which goes with `_advance_burn`.

**The "before" 3× video is captured** (`d6_BEFORE_choreo.mp4`, the choreographer
path). Part 2's own gate is the "after" against it.

**Files part 2 deletes:** `detonation_choreographer.gd` (809),
`detonation_choreographer_selftest.gd` (441), `burn_scheduler.gd` (109),
`burn_scheduler_selftest.gd` (217), `fire_glow_overlay.gd`. **Rewires:** `room.gd`
(~700 lines of burn subsystem — `_advance_burn`, `start_burn`, `_burn_precook`,
`_burn_final_repaint`, `_burn_residue_probe`, `await_destruction_settled`, the
`_burn_prof_*` field wall, `BURN_*` consts, the `_process` call, the `_capture_two_fires`
action), `detonation_plan_builder.gd` (`cook_owns_fire` always true; `_maybe_burn`
gains the `INFILTRAITOR_NO_BURN` gate; `waves["burn"]` drops), `world_delta.gd`
(drop `"burn"` from the waves dict), plus comment refs in ~6 files. **Env vars
removed:** `INFILTRAITOR_PRESENTER`, `INFILTRAITOR_FRONT_FRAMES`,
`INFILTRAITOR_SOOT_SECONDS`, `INFILTRAITOR_BURN_SCHEDULE`, `INFILTRAITOR_BURN_PROFILE`,
`INFILTRAITOR_BURN_PRECOOK`. **`consequence_soot_seconds`** goes (choreographer-only).

#### Part 2 — SHIPPED 2026-08-29

Deleted, all five: `detonation_choreographer.gd` + selftest, `burn_scheduler.gd` +
selftest, `fire_glow_overlay.gd`. `room.gd` **9 722 → 8 484 lines** — the whole
burn subsystem (`_advance_burn`, `start_burn`, `_burn_precook`,
`_burn_final_repaint`, `_burn_residue_probe`, `await_destruction_settled`, the
`_burn_prof_*` wall, `BURN_SUSPEND_REGION_LIGHT`/`BURN_COMMIT_INTERVAL_S`,
`_burn_scheduler`/`_burn_pending`/`_burn_touched_edges`/`_burn_soot_gus`, the
`_capture_two_fires` capture + its `_tf_watch_*` helpers + `_report_two_fires_soot_drift`),
the `_process` call and its timing wrappers, the `_fire_glow_overlay` field and
its `add_child` + z-index wiring, and `begin_consequence_beat` /
`_consequence_pending` / `_consequence_light_done` (write-only once
`_burn_final_repaint` was gone). `detonation_plan_builder.gd`: `cook_owns_fire`
deleted (the `s["burnt"]` branch is now unconditional), `no_burn` static var + an
early return at the top of `_maybe_burn`, the census reads `burnt_cells` only.
`world_delta.gd`: `"burn"` dropped from `waves`. `detonation_prediction.gd` /
`test_zone_controller.gd` / `vfx_draw_probe.gd` comment rewires; `VfxDrawProbe.reset()`
moved from `start_burn()` to `Room.begin_blast_lock()`.

**Env vars removed:** `INFILTRAITOR_PRESENTER`, `INFILTRAITOR_FRONT_FRAMES`,
`INFILTRAITOR_SOOT_SECONDS`, `INFILTRAITOR_BURN_SCHEDULE`,
`INFILTRAITOR_BURN_PROFILE`, `INFILTRAITOR_BURN_PRECOOK`, plus the `INFILTRAITOR_BURN_END_GATE` / `_MAPWIDE_END` / `_RESIDUE_PROBE` /
`_PRECOOK_STAGES` / `TWO_FIRES*` diagnostics that lived inside the deleted funcs.
(`INFILTRAITOR_BURN_PROBE_*` stays — it belongs to `_capture_light_burn_probe`.)
`INFILTRAITOR_NO_BURN` survives, now read in `DetonationPlanBuilder`.
`consequence_light_seconds` **0.5 → 1.0** (§8.11 answer 2, the swiffh SFX still
deferred to audio).

**Gates:** lint ✅ · selftests **38 clean / 0 failed** ✅ (40 → 38) · invariants ✅ ·
CODEMAP ✅ (220 scripts). Repo-wide grep for every deleted symbol: only prose /
history references remain (`"the trap DetonationChoreographer's header warned
about"` and the like). **3× slow-motion gate:** `d6_AFTER_presenter.mp4`
(scratchpad, 240 frames @ 20 fps) against `d6_BEFORE_choreo.mp4` — the whole event
still plays: fuse sputter, boom strobe, orange fireball, crater in the wall,
embers cooling yellow → red → charcoal, plumes rising and drifting, soot on the
scorched face, light settling last. Net **~3 000 lines removed**.

---

### 8.9 ✅ D-5 — THE LIGHT RAMP TO ITS D-0 DURATION, 2026-08-29

`consequence_light_seconds` **2.0 → 0.5** — the value the Director watched in D-0's
pacing rehearsal and ratified. Soot was already in the commit (D-3) and the
fade-in ladder is D-3b's, so §7's remaining work was this one number. It is a
`var` (Rule 1) and `INFILTRAITOR_LIGHT_SECONDS` still overrides it, so a control
is one env var from the same binary.

**§14.2's reasoning holds:** 96.8% of the old 2 s beat was measured as *not a beat*
— 640 of 661 changed cells arrived at the START. And §8.7's ruling moved the
event's LENGTH onto the smoke (*"pode manter os 240 frames rodando até a fumaça se
dissipar"*), so a shorter light ramp does not shorten the event — the presenter
runs the ramp AFTER the consequence channel, so it lands as the smoke thins (§7.2).

**The gate, met by CONTAINMENT rather than a single 0.** Same binary, same
`INFILTRAITOR_RNG_SEED=77`, presenter, fabric gu (31,3), 0.5 s vs 2.0 s:

| frame 264 | inside crater bbox (430,0)–(870,400) | outside |
|---|---|---|
| pixels differ `>2` | 34 373 | **0** |
| `>16` | 2 195 | **0** |
| `>32` | 263 | **0** |
| `>64` | 2 | **0** |

**Nothing outside the crater moves.** Inside it, the difference is the 2.0 s
control's ramp still ~20% in progress at that frame — it lands around f280, past
the capture's held-camera window, which is why the literal "settled final frame,
0 px" is unreachable here. The destination is identical by construction:
`play_consequence_light()`'s terminal loop writes `int(to_bucket[k])` for every
moved cell, unconditionally, and `consequence_light_seconds` feeds only
`frames_per_step` — an intermediate count, never the endpoint.

⚠️ **`consequence_soot_seconds` is now dead on the presenter path** (only the
choreographer's soot ramp reads it) and goes with the choreographer in D-6. §7.3's
"one number" is D-6's to finish, not D-5's.

---

### 8.12 ✅ D-8 — THE LIGHT LAG, DEFERRED (NOT FIXED), 2026-08-29

> Director, watching the real-time video: *"Consigo claramente ver o lag pela
> fumaça, quando aparece 'light landed'. A fumaça dá uma pausinha quando entra.
> Vamos adiar a luz até o fim mesmo — a não ser que a gente consiga colocar a
> fumaça em uma thread separada que não seja afetada pela luz."*

A separate thread is not viable — Godot overlay `_draw()` and the derive are both
main-thread. So `DetonationPresenter._wait_for_smoke()`: after the consequence
channel, poll `SmokeSparkOverlay.smoke_count()` until it drops to
`light_smoke_slack` (4) or `light_smoke_max_s` (3.5 s) elapses, THEN
`play_consequence_light()`. The ~202 ms `_repaint_voxel_light_buckets()` still
costs 202 ms; the freeze now lands on a still, near-empty scene (~5.0 s on the
fabric filmstrip) instead of over drifting smoke (~3.2 s). Both new values are
`var` (Rule 1). **This is not §7.4** — see the task table.

### 8.13 ✅ `throw_event` — THE WHOLE EVENT IN ONE BOOT, 2026-08-29

`INFILTRAITOR_CAPTURE_ACTION=throw_event` (`Room._capture_throw_event_filmstrip()`) —
drives `enter_grenade_mode` → `_set_targeting_target` → wait out the prediction →
`execute_grenade_throw`, then grabs every frame at `--fixed-fps 60` through the
arc, the fuse, the boom, the consequence channel and the light. Encode the PNGs
at 60 fps for real-time playback. Envs:
`INFILTRAITOR_EVENT_{AGENT_CELL,TARGET_GU,FOCUS_GU,FRAMES_TOTAL,THROW_AT}`.

⚠️ **Rough edges, own follow-up:** the aim dome flashes ~1 frame before the throw
despite the `dev_vision` disable; `_set_targeting_target`'s throw-range clamp
mangles a far `TARGET_GU` (the agent's real GU on the reformed PLAYGROUND was
never worked out — a default throw lands at gu (21,8), concrete floor, dents not a
crater); the framing pulls in a lot of empty floor. The event IS captured every
run.

---

## 9. OPEN QUESTIONS

1. ~~**The passage — does the new fire owe `BURN_THROUGH`'s openings?**~~
   ✅ **CLOSED, but not the way §11 first said.** The 2026-08-27 answer was *"the
   cook GUARANTEES, and the bubble is what it guarantees from"*; the Director
   **vetoed the forced opening on 2026-08-28** (§11.1a). The cook guarantees
   nothing — the CRITERION changed, and D-2 shipped it. Left visible rather than
   struck through: this plan asserted the opposite for a day.
2. **Does the front's disappearance cost anything the Director wants?** §4 has the
   crater simply present when the flash clears. That is *pa-pum* by construction
   and it is also the removal of a look that was tuned three times. **D-0 answers
   this for the price of three constants.**
3. **Can the final light field be computed in the cook (§7.4)?** Scoped, not
   assumed. Getting it wrong means the board's light is wrong everywhere, so it
   is D-7 and not D-5.
4. **What replaces `flatten_plan()` for W-PRECOOK's warming?** The precook needs
   "which alternatives will this blast need" and currently reads it off the
   playback queue. The delta has the same information; the seam does not exist yet.

---

## 11. THE BUBBLE IS THE CONTRACT — Director, 2026-08-27

> *"A passagem abre quando a área de atuação da granada (bolha da mira) acerta
> a(s) slice(s) bloqueando a passagem. Podemos fazer a explosão deterministicamente
> abrir GUs e Slices englobadas na bolha, independente do que o efeito decorativo
> ou voxels visíveis indicarem. De fato, toda a explosão pode ser baseada em GUs e
> Slices, usando um algoritmo/animação comum para: destruídas, parcialmente
> destruídas (decalques), intactas, etc. Dessa forma não precisamos calcular toda
> a determinística da explosão, mas rodar um mecanismo de destruição
> pré-fabricado para slices e slabs, conforme a proximidade ao apicentro."*

This is **two proposals that look like one**, and they have different values,
different risks and different task sizes. Split here so neither is sold on the
other's argument.

### 11.1 ✅ THE PASSAGE CONTRACT — recommended without reservation

**What the player sees in the bubble is what opens.** Every Slice a bubble GU
covers that blocks a passage is opened, deterministically, regardless of what the
voxel rolls or the decorative effect produce.

**Why this is right, in the project's own idiom rather than as a new idea:**

- It is the same separation this engine already ratified twice. `OCCLUSION`'s O1:
  *"occlusion is VIEW, not STATE."* `LIGHT_MASTER_PLAN`: *"visual brightness ≠
  tactical visibility."* **Gameplay truth and visual truth are already allowed to
  differ here** — the passage joins that list rather than breaking a rule.
- It answers what `MATERIALS_MASTER_PLAN` §3.2a explicitly refused to decide —
  *"`PassageQuery` and the one policy question it refused to decide."*
- It removes a real failure mode: today a grenade placed correctly against a wall
  can fail to open anything because the count landed badly. In a turn-based
  tactical game where the player commits a turn to the throw, that is a coin flip
  wearing the costume of a simulation.
- **The prediction layer already exists to show it.** `build_plan()` is pure and
  the bubble is drawn from `BombDef`'s own radii, so "what the bubble promises" and
  "what the cook delivers" can be made the same object rather than two that agree
  by luck.

⚠️ **The bubble is SMALLER than the blast, and that is the useful shape.**
`aim_dome_radius_gu = 2.0`, while `frag_grenade.ring_multipliers` is
`[1.0, 0.6, 0.25, 0.0]` — four rings. So the bubble is the **guaranteed core** and
the blast fades beyond it. The contract reads: *inside the bubble, promised;
outside it, consequence.* Nothing has to be re-tuned for that to be true.

### 11.1a ⛔ THE FORCED OPENING IS VETOED — Director, 2026-08-28

§11.1 above proposed that the cook DESTROY whatever it takes to open a
storey-face the bubble covers. Asked directly whether a grenade at 0 GU from a
**concrete** wall should therefore open a standing passage on the spot, the
Director ruled **no — only the criterion changes**:

> *"A granada abre as edges que estiverem de 0 a 1 GU de distância do centro…
> essas aberturas vão ser normalmente autoradas… vamos ter um frame de uma porta,
> com uma cortina de pano. Nesse caso a granada vai destruir praticamente todo o
> pano, a passagem se abre, e o material duro destroi menos, como já funciona.
> Porém, se o jogador gastar 3 granadas no mesmo lugar com concreto, supostamente
> abriria uma passagem também."*
>
> *"Quantos voxels sobram individualmente não é importante para definir se a
> passagem está aberta ou não. Podem ficar sobras decorativas, porém precisamos
> ter mais ou menos uma noção de quantos voxels foram removidos pra aplicar a
> abertura."*

**So the breach points are AUTHORED, not forced.** A designer puts a fabric
curtain in a door frame; the grenade takes nearly all of it and the passage opens;
the concrete around it takes less, as it already does. Everything §11.1 wanted
still happens — a correctly placed grenade reliably opens a soft wall — but it
happens because the wall broke, never because the dome covered it.

**What was actually built (D-2):** `PassageQuery`'s predicate. The contiguous-run
rule is replaced by **`PASSAGE_MIN_REMOVED_FRACTION`, and the bar did not move** —
the run rule's 4 of 8 positions at full storey height IS 32 of 64 cells, so 0.50
is the same doorway with the shape requirement taken off it. The OVERLAP rule
survives (restated per position); contiguity and full-height do not, and their two
selftests are inverted in place with the ruling quoted.

**Three things this bought that the forced version would not have:**

1. **Accumulation for free.** Voxel damage persists, so *"3 granadas no mesmo
   lugar com concreto"* adds up to one fraction — no per-edge store, no
   accumulator, and nothing new that has to be kept base-keyed under rotation
   (§11.3.4's risk, avoided rather than managed).
2. **The 60-of-64 defect closed for good.** The run rule's own revision was forced
   by a wall reading NONE at 60 of 64 cells open; it then failed the same way
   whenever a survivor landed *inside* an opening and split it. That is now
   structurally impossible.
3. **The material stays the difficulty**, measured the same day: fabric **100%
   removed → STANDING ×3** on one grenade, concrete **3% → NONE ×3**.

⚠️ **`aim_dome_radius_gu` is now decoration for this purpose.** Nothing reads the
bubble to decide a passage, and no `ctx` plumbing was added for one. If the
guarantee is ever wanted back, it is a new task, not a dormant hook.

### 11.2 ⚠️ THE PRE-FABRICATED PATTERN — recommended, but NOT for the reason given

The stated motivation is *"não precisamos calcular toda a determinística da
explosão"*. Measured today, real PLAYGROUND, fabric at gu (31,3),
`INFILTRAITOR_PREDICTION_PROFILE=1`:

```
[P-SLICE] 48 step(s) · worst step 39.5 ms (phase WALK) · total 399.0 ms
  WALK      260.3 ms   65%   <- the map-wide voxel index walk
  SOOT       38.0 ms   10%
  SLICES     34.9 ms    9%   <- the per-voxel damage decision, walls
  PACKAGE    18.8 ms    5%
  SOOTWAVE   18.5 ms    5%
  FLOORS     12.3 ms    3%   <- the per-voxel damage decision, floors
  SMOKE       8.2 ms    2%
  EXPOSE      3.4 · ROOFS 2.5 · SETUP 1.6 · JUNCTIONS 0.1 · LIGHT 0.1
```

**The whole per-voxel determinism is SLICES + FLOORS + ROOFS + JUNCTIONS = 49.8 ms
of 399 — 12.5%.** The `WALK` that dominates is the map-wide occupancy/soot index,
which decides nothing about damage and is untouched by pre-fabrication. **And the
cook is already 0 frames in real play** (§1.2 — the 36 cooking frames only exist
because the harness presses Enter instantly; a human choosing a target takes
longer than the whole cook).

**So pre-fabrication replaces an eighth of a cost that is already hidden. That is
not a reason to do it.**

**The real reason to do it is the LOOK, and it is a good one.** `_select_deterministic()`
ranks a ring's voxels by FNV-1a hash and takes the first N. That is a *statistical
scatter*, and the Director has been fighting how it reads for weeks — E-CONTRAST
(three attempts), E-CLEAN, E-ORDER, *"os decals têm que estar no lugar do voxel
destruído imediatamente"*. **An authored mask is a direct lever on exactly that,
and a scatter is not.** *"Menos é mais"* is expressible as a pattern — few, large,
legible holes — and is not expressible as a count.

**And it is a much smaller change than "rebuild the explosion".** The ring model,
the material factors and the per-container grouping all stay; what changes is the
SELECTION inside one function:

```
today      _select_deterministic(group, container_id, salt, n, bias) -> Array
             ranks by hash (or by distance-then-hash), takes the first n

proposed   a pattern per (container class, ring, material tier), authored,
             looked up instead of ranked
```

### 11.3 The four risks — ✅ ALL FOUR ANSWERED BY THE DIRECTOR, 2026-08-27

Raised before anything was built, and ruled on the same day. The rulings are the
constraints D-2b builds under.

**1. The resistance ladder must survive.** ✅ *"Concordo, a escada deve existir."*
`destroy_factor` / `dent_factor` / `crack_factor` produce metal > stone >
concrete > wood > plywood > cardboard > fabric; it is ratified design and it has
selftests. So a pattern table needs a pattern **per material TIER** (or a pattern
plus a per-material threshold) — *"every material breaks the same shape"* is a
failure, not a simplification. **This is the design work of the proposal, not a
detail of it.**

**2. Firearms decide damage by a different model.** ✅ *"Sem problemas, faz sentido
que o dano seja diferente e o mecanismo também, mas tentamos preservar o que já
existe, as armas de fogo estão ok e não geram queima."*

Explosions and shots may diverge; what must not change is the firearm path that
already works (`apply_point_impact()`, `WEAPON_MASTER_PLAN` §6c). Verified in code
2026-08-27: **`start_burn()` has exactly one caller**, the grenade path in
`test_zone_controller.gd`, so no shot lights a fire today.

⚠️ **That is a statement of the CURRENT state, not a prohibition** — the Director's
own correction. A future incendiary round or molotov is not vetoed by this line;
it simply is not what firearms do now, so D-2b has nothing to preserve there
beyond leaving the path alone.

**3. A Slice is not always 128 voxels.** ✅ *"Sim, mas imagino que atender uma
quantidade menor de voxels seja uma consequência natural do mecanismo."*

Exactly right, and it is what makes the mechanism cheap rather than what
complicates it: a pattern is applied to **whatever voxels the container actually
has**, so half-thickness panels (M3-2b) and `JunctionColumn` (one voxel per level,
a third container class) fall out of the same lookup. **The gate is that they
still take damage at all** — E-JUNCTION-01 shipped on 2026-08-13 precisely because
junction columns had been taking none, and nobody noticed until the Director sent
a screenshot.

**4. Nothing stored may be view-space.** ✅ *"Sim, queremos um mapa de fuligem bem
planejado, simples e eficiente, que consiga lidar com as rotações."*

Two things fall under this, and they are the same rule twice:

- **The damage pattern** must be authored in voxel-local coordinates.
  `SOOT_STORAGE_REFORM` §1.1 lost a day to exactly this class of bug: a per-face
  format that was +Z/+X/+Y in VIEW space gave the two faces turned away from the
  camera a placeholder, which is a hole in the record the moment it is stored.
- **The soot map itself** — already built that way. SS-1's store is **base-keyed
  with a six-direction format** (the sixth is BOTTOM, because the ISOTROPIC ring
  is otherwise unrecoverable for a voxel scorched from underneath), and SS-2 made
  it the source of truth at **0 px** against a control that earned it.

⚠️ **So the Director's ruling is already half-built, and the unbuilt half has a
name and a blocker:** `SOOT_STORAGE_REFORM` **SS-6 — prove it under rotation**,
which *"needs a capture action that rotates the view, and none exists."* Its gate
is D24's own SE/SW histogram before and after a rotation to E, not a pixel diff.
**SS-6 is now explicitly wanted rather than deferred, and building that capture
action is its first step.** Rotation is suspended for PERFORMANCE, not abandoned.

### 11.4 How this changes the task list

It does **not** replace D-1…D-6. It changes what D-2 computes, and it adds one
independent task that is judged on the picture.

- ~~**D-2 gains the passage contract** (§11.1) — the cook guarantees openings from
  the bubble.~~ ⛔ **Vetoed 2026-08-28 (§11.1a).** D-2 shipped `PassageQuery`'s
  criterion instead: amount removed, not shape, and nothing forced.
- **New D-2b — the pre-fabricated pattern** (§11.2). Independent of the
  presentation reform, sequenced after it, and its gate is the Director looking at
  a crater, not a millisecond.


---

## 10. WHAT THIS PLAN DOES NOT CLAIM

- **It does not claim the explosion is slow because it is expensive.** §1.3 says
  the opposite, with numbers, and any task here that starts optimising CPU has
  misread this document.
- **It does not claim §9.11e needed an architecture to fix it.** One guard would
  stop the resurrection today. It is fixed *here* because the honest version
  requires the cook to own the fire's consumption (§6) — the Director's §5.3
  ruling is that a fire-consumed voxel SHOULD scorch, and a guard that skips
  erased cells would drop exactly that scorch.
- **It does not claim the pure cook or the cell plane need changing.** §2.
- **It does not claim D-1's number.** §1.4 is a sum of per-frame applies. The
  measurement of an actual collapsed frame does not exist yet.
