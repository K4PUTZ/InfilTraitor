# FIRE_REBUILD_MASTER_PLAN
## One commit, then only drawing — the explosion and its fire, 2026-08-27

**Status:** 🟡 **BRIEF + ARCHITECTURE. NOTHING BUILT, NOTHING REMOVED.**
The architecture (§2) is the Director's own proposal, ratified 2026-08-27, and it
rests on one measurement that inverts the old argument: **a committing frame now
costs 20 ms against 16.8 ms for one that commits nothing.** The frame budget is
idle; what is scarce is not time but *writes*.
**Authority:** the Director, 2026-08-27, after watching two 3× slow-motion
captures and reading the cell probe: *"Eu proponho que a gente remova esse
mecanismo atual, e trabalhe na continuação dessa explosão"*, followed by the full
spec in §1.
**Why now, measured rather than felt:** `PERFORMANCE_MASTER_PLAN` §9.11e — with
the fire, **350 of 1 163 destroyed cells come back on one frame**; without it,
**0 of 813**. The fire is not merely wrong-looking, it is undoing its own
destruction. The blast underneath it is clean.

---

## 1. THE DIRECTOR'S SPEC, VERBATIM IN SUBSTANCE

Soft materials explode with the **same dynamics as hard materials**, and then:

1. **Far more voxels are removed than on a hard material.** A soft material
   *"já começa bem destruído"*.
2. At the holes that open, the voxels **beside** them — the blast's edges — show
   **a small flame that vibrates for ~0.5 s**, then disappears, **leaving an
   incandescent voxel in its place**.
3. That flame, **before going out, propagates to nearby voxels in every
   direction except DOWN, with greater emphasis UPWARD**, as a fire would.
   ⚠️ *"atenção com slices internas das paredes, um voxel queimando fora vai
   sujar o de dentro"* — a voxel burning on the outside dirties the one inside.
4. **Propagation loses strength**, and the whole fire goes out over time.
5. Each incandescent voxel **loses its glow over 1 s**, darkening **until fully
   black**.
6. **Before going out, a voxel has a CHANCE to transmit the ember to a nearby
   voxel — and transmitting DESTROYS it: it disappears and becomes ash.**
7. On becoming black, a voxel **releases the little smoke upward for 1–2 s**, and
   ends.

### 1.1 What that is, as a machine

    INTACT ──blast──> DESTROYED (hole)
       │
       └──edge of a hole──> FLAME (~0.5 s, vibrating)
                              │  propagates: all dirs except −Z, biased +Z,
                              │  strength decaying per generation
                              ▼
                           INCANDESCENT (glow → black over 1 s)
                              │  chance, before going out, to pass the ember on
                              │  ⇒ THIS voxel is destroyed, becomes ash
                              ▼
                            BLACK ──> smoke upward, 1–2 s ──> done

Every state is **per voxel**, and every transition is **per voxel**. That is the
whole difference from what ships today.

### 1.2 What ships today, and why it is not a degraded version of this

One `CircleField` MultiMesh draws an **ellipse with a feathered alpha edge** over
the burning region (P7b, `PERFORMANCE_MASTER_PLAN` §12). The Director, on seeing
it: *"é basicamente uma elipse com feather nas bordas e alpha. Mas não é isso que
nós projetamos."* It is a different thing, not a cheaper version of §1.1 — there
is no per-voxel flame in it to make smaller.

---

## 2. THE ARCHITECTURE — Director-ratified 2026-08-27

*"Em vez de fazer várias waves, podemos simplesmente calcular o estado final da
cratera, colocar mais efeitos e fumaça por cima e simplesmente exibir o que
sobra. O fogo nos materiais pode ser só simbólico, mas eu acho que daria pra
fazer uma animação de brasa em um voxel por exemplo, e replicar ela várias vezes,
com duração da fumaça diferente."*

### 2.1 ⚠️ FIRST, THE NUMBER THIS PLAN WAS ABOUT TO ARGUE FROM IS STALE

The version of §2 this replaces argued the tension from
`PERFORMANCE_MASTER_PLAN` §8.15: *"a committing frame that mints costs ~360 ms;
one that mints NOTHING costs ~126 ms."* **That was true and is no longer.** The
perf wave shipped on 2026-08-26 and nobody re-read the sentences that rested on
it. Measured on 2026-08-27, this session's own two-fire run with
`INFILTRAITOR_BURN_PROFILE=1`:

```
frames during the fire: 77 · mean 17.1 ms · max 26 ms · total 1 316 ms — 7 committed
ATTRIB — committing frames:      6 x 20.0 ms =   120 ms
         NON-committing frames: 71 x 16.8 ms = 1 196 ms
MINT-SPLIT — committing frames that MINTED: 0 · that minted NOTHING: 6 x 20 ms
```

A committing frame costs **20 ms** against 16.8 ms for one that commits nothing —
a difference of **3 ms**, and zero mints. So **91% of the fire's wall clock
(1 196 of 1 316 ms) is frames doing nothing but passing.** The fire is not
expensive; it is LONG. Duration is schedule, not cost.

**Which inverts the question.** The frame budget is not the constraint — it is
sitting almost entirely idle. *"Bonito sem comprometer performance"* is cheap, as
long as the right thing is the expensive one.

### 2.2 The rule

> **A frame that WRITES CELLS is expensive and must be rare — ideally exactly
> one. A frame that only DRAWS costs ~17 ms and there are dozens spare.**

The structural error in the shipped design is not the number of waves. It is that
**the waves write cells for 24 frames and the fire keeps writing for 77 more** —
a second mutation stream running alongside the repaints. That is not a bug inside
the fire; it is the SHAPE of the fire, and §9.11e's 350 restored cells are what
the shape produces.

### 2.3 The explosion, as one commit and N cheap frames

| beat | frames | what happens | writes cells? |
|---|---|---|---|
| 0 · cook | ~0 (already async and PURE) | `build_plan()` computes the **final crater**, including what the fire would have consumed | no |
| 1 · flash | 1–2 | the strobe covers the screen | no |
| 2 · **THE COMMIT** | **1** | destroy, expose, decals, **soot**, light — all of it, behind the flash | **yes, once** |
| 3..N · consequence | 40–80 | smoke, embers, dust, debris | **no** |

**From beat 2 the board is FINAL.** Everything after it is drawing.

Nothing in beat 0 changes: the 11-phase resumable pure builder, `WorldDelta`, and
`commit()` are the parts of this system that work and they are what makes the
whole model possible — the final state is already computed before anything is
shown.

### 2.4 The fire, symbolic — and it is the cheap version, not the compromise

The cook already knows which voxels burn (the flammable ones edging holes).
Instead of a schedule that destroys them over seconds, **they are already gone in
the final state**, and the fire becomes purely visual: **one ember animation,
instanced per burning voxel, with per-instance phase and per-instance smoke
duration.**

That is one MultiMesh and one draw. P7b already proved the shape on this exact
engine — collapsing every per-cell circle into one MultiMesh took the fire's
worst frame from **42.4 ms to 19.5 ms**. **N embers cost what one costs.**

⚠️ **This retires §2's old proposal (burn state as per-cell data in the shader
plane) before it was built.** That existed to make a per-voxel flame affordable;
an instanced ember is affordable already and looks better, so the shader-plane
route is recorded as available and not planned. The spec's states (§1.1) survive
as the ANIMATION's own timeline rather than as world state — flame ~0.5 s,
incandescent fading 1 s, black, smoke 1–2 s, all per instance.

**What stays real state, and must:** which voxels are destroyed (the cook), and
the soot (the store, `SOOT_STORAGE_REFORM`). Ember transmission that *"destrói o
voxel e vira cinza"* is decided in the cook, not at play time — that is what
keeps it out of the second mutation stream.

### 2.5 What this kills by construction

- **§9.11e's 350 restored cells** — there is no second mutation stream left to
  fight the repaint.
- **"Voxels entering clean after the soot has landed"** — nothing enters after the
  commit, and the soot goes in the same commit. Since SS-2 the store is already
  the source of truth, so this needs no new mechanism.
- **The fire's map-wide final repaint** — there is no end-of-fire to repaint.
- **`KIND_RADIUS_BIAS` as a thing to defend.** Ordering stops being a clock
  problem: decals, holes and dents are simultaneous, and their relationship
  becomes a property of the drawing.

### 2.6 What it costs, and what must be measured before it is believed

1. **One commit frame becomes the worst frame of the event.** Today the writes are
   spread over 24 frames; concentrating them means ONE TileSet rebuild instead of
   up to 24 — and §2.1 measured **zero** mints happening today, so it should fit.
   *"Should fit"* is not a number. **F-0 measures it.**
2. ⚠️ **THE PASSAGE.** `[E-BURN] … passage over 6 burnt edge(s): { "CROUCH": 1,
   "NONE": 3, "STANDING": 2 } · widest base storey 64/64 cells open` — the agent
   walks through this. Today it EMERGES from the burn. With the burn gone it must
   be **computed in the cook**, and that is gameplay with its own plan
   (`BURN_THROUGH_MASTER_PLAN`), not a visual detail to be rediscovered later.
3. **The crater no longer reveals progressively.** That is the Director's explicit
   intent (*"simplesmente exibir o que sobra"*), and it means the VFX now carries
   the whole read of the event. If the flash does not cover the snap, the snap
   will be visible.

## 3. WHAT THE REMOVAL ACTUALLY TOUCHES

The Director asked for the current mechanism to be removed. Scoped before it is
done, because CLAUDE.md's 2026-07-12 lesson is exactly this shape — an
unrequested deletion of something that *looked* unused stopped every wall in the
game from rendering, because the linter cannot see cross-file writes.

Mentions live in **18 files**. The pieces:

- `BurnScheduler` (109 lines) + `burn_scheduler_selftest.gd`
- `Room.start_burn()` and the burn tick — **217 lines in `room.gd`** mention
  `_burn_*`, including the profiler, the residue probe, the final repaint, and
  `BURN_SUSPEND_REGION_LIGHT`
- `EmberOverlay` (382 lines) and its `CircleField` path
- `DetonationPlanBuilder._build_ember_wave()` and the `waves["burn"]` bucket
- `MaterialResistanceTable.flammability()` — **KEEP**, it is the material
  property the new system reads too
- every `INFILTRAITOR_BURN_*` env flag and the `[E-BURN]` / `[E-EMBER]` logging

⚠️ **AND ONE THING THAT MUST NOT BE LOST WITH IT.** The current burn opens
**passages** — `[E-BURN] fire out … passage over 6 burnt edge(s):
{ "CROUCH": 1, "NONE": 3, "STANDING": 2 } · widest base storey 64/64 cells open`.
That is gameplay, it has its own plan (`BURN_THROUGH_MASTER_PLAN`), and the agent
walks through it. §1.6's ember transmission also destroys voxels, so the new fire
can produce the same thing — but *"can"* is not *"does"*, and this is the item
most likely to be deleted by accident and missed for months.

---

## 4. TASKS — the measurement before the architecture

| id | task | gate |
|---|---|---|
| **F-0** | **Price the single commit frame.** Collapse the wave to one frame behind the flash, on a HARD material, nothing else changed. No fire, no removal. | The number §2.6.1 is missing: what one commit frame costs against today's 24. `INFILTRAITOR_BURN_PROFILE`-style attribution, and the worst frame of the event. **If it does not fit, the architecture changes here, before anything is built on it.** |
| **F-1** | **The instanced ember.** One MultiMesh, per-instance phase and smoke duration, over the voxels the cook marked as burning. Purely visual; no state, no mutation. | The Director looks at it. §1's flame/incandescent/black/smoke timeline has to read as a fire at 3× slow motion, and it is one draw call either way. |
| **F-2** | **The cook owns what the fire consumes** — soft materials start further destroyed (§1.1), and ember transmission's *"vira cinza"* is decided in `build_plan()`, not at play time. | `blast_purity_selftest`: still pure. The **cell probe**: `0 RESTORED, 0 VANISHED` — the gate the current fire fails 350 cells deep. |
| **F-3** | **The passage, computed** (§2.6.2). | `passage over N burnt edge(s)` reported by the new path, with the same shape as today's, or explicitly retired by the Director. |
| **F-4** | **Remove the old mechanism** (§3). | Repo-wide grep with a named caller list pasted into the commit. Cell probe green. 3× slow-motion video before and after. |
| **F-5** | **The rhythm pass** the Director deferred (*"o ritmo ainda precisa melhorar, mas isso a gente faz depois"*). | On video, 3× slow motion — the instrument that found every defect in this session. |

**Order rationale:** F-0 first because the whole architecture rests on one
unmeasured number, and it is cheap to get. F-1 second because the ember is the
part the Director has to LOOK at, and it is independent of the commit shape. F-4
last, because a removal is irreversible and the replacement should be proven
before the thing it replaces is gone.

---

## 5. OPEN QUESTIONS

1. **The passage** (§2.6.2) — does the new fire owe `BURN_THROUGH`'s openings, or
   is that feature retired with the old mechanism? It decides whether the cook has
   to guarantee connectivity or merely produce holes.
2. **Seconds or frames.** §1's durations are in SECONDS (0.5 / 1 / 1–2). This
   project has been burned both ways — `front_frames` silently retuned 5× by a
   perf change, and the burn's commit cadence deliberately pinned in seconds.
   Under §2.3 the answer is easier than it was: the animation is per-instance and
   touches no world state, so **seconds** is right for it and there is no cadence
   left to pin. Written down here so there are not three answers later.
3. ~~Can a per-cell shader effect carry a small vibrating flame?~~ **Moot** — §2.4
   retires the shader-plane route in favour of the instanced ember.
