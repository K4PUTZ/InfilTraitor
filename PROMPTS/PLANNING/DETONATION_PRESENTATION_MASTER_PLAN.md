# DETONATION_PRESENTATION_MASTER_PLAN
## One commit, then only drawing — the choreographer's reform, 2026-08-27

**Status:** 🟢 **D-0 BUILT AND MEASURED (§8.1) — and it carried half of D-1 with it.**
The pacing rehearsal ships as three env overrides; nothing architectural is
built and nothing is removed. **Fabric 4 797 → 2 310 ms; hard 2 940 → 878 ms**,
and the single collapsed commit frame is **18.55 ms measured** against a
predicted 20.1.
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
| 🟠 **D-1** | **HALF DONE (§8.1): the cell writes collapse to 18.55 ms (fabric) / 4.21 ms (hard), cheaper than spread.** Price the real commit frame. Collapse the queue to one frame behind the flash, hard material first, nothing else changed. | The real worst frame, against §1.4's predicted ~17 ms (concrete) / ~43 ms (fabric). `INFILTRAITOR_THROW_PROFILE`-style attribution. **If it does not fit, §4.1's staged fallback is where the architecture changes — before anything is built on it.** |
| **D-2** | **The cook owns what the fire consumes** (§6), and the passage with it (§6, subject to §9.1). | `blast_purity_selftest`: still pure. **Cell probe: `0 RESTORED, 0 VANISHED`** — the gate the current path fails 350 cells deep. `passage over N burnt edge(s)` reported by the new path with the same shape as today's, or explicitly retired by the Director. |
| **D-3** | **The presenter.** New class behind `INFILTRAITOR_PRESENTER=1`, old path still default. One commit frame; the consequence channel with per-instance `(GU ring, storey)` delay (§4.2, §5). | Cell probe green. `detonation_plan_selftest` + `blast_purity_selftest` untouched and passing — they are the net. Both paths runnable from one binary, so a before/after needs no stash. |
| **D-4** | **The symbolic fire** (§5.1) — one MultiMesh, per-instance phase and smoke duration, over the voxels the cook marked as burnt. Purely visual. | The Director looks at it. §5.1's flame → incandescent → black → smoke has to read as fire at 3× slow motion, and it is one draw call either way. |
| **D-5** | **The light lands** (§7). Soot into the commit; the ramp to its D-0 duration. | The final frame is **pixel-identical** to a control with only the pacing reverted — the destination must be untouched and only the path changed (the gate §14.2 earned). |
| **D-6** | **Remove the old path** (§3.2). | Repo-wide grep with the named consumer list pasted into the commit. Cell probe green. 3× slow-motion video before and after. Lint, 40 selftests, invariants, CODEMAP. |
| **D-7** | **The rhythm pass** the Director deferred (*"o ritmo ainda precisa melhorar"*), and §7.4 if it is real. | Video, 3× slow motion — the instrument that found every defect of the last three sessions. |

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
changes pacing, not architecture; §9.11e is D-2's.

---

---

## 9. OPEN QUESTIONS

1. **The passage — does the new fire owe `BURN_THROUGH`'s openings?** Today's
   burn opens `{ CROUCH: 1, NONE: 3, STANDING: 2 }` on a fabric blast. It decides
   whether the cook must GUARANTEE connectivity or merely produce holes and let
   `PassageQuery` report what happened. **Director's call, and D-2 is blocked on
   it in substance, not in schedule.**
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
