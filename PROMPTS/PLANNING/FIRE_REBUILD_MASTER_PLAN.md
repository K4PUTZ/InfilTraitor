# FIRE_REBUILD_MASTER_PLAN
## The fire is rebuilt as a per-voxel state machine — brief, 2026-08-27

**Status:** 🟡 **BRIEF CAPTURED. NOTHING BUILT, NOTHING REMOVED.**
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

## 2. ⚠️ THE ARCHITECTURAL TENSION, STATED BEFORE ANY CODE

**Performance is the standing priority in this project, and §1 asks for exactly
the shape that was optimised away.**

`PERFORMANCE_MASTER_PLAN` §12/P7b found that **VFX cost is per-VERTEX submission,
not per particle**, and collapsed every per-cell circle into ONE MultiMesh —
taking the fire's worst frame from **42.4 ms to 19.5 ms**. A literal reading of
§1 (a flame node per burning voxel, a glow per ember, a smoke puff per black
voxel) rebuilds precisely the cost that collapse removed, and on hundreds of
voxels at once.

**So the rebuild has to be cheap BY CONSTRUCTION, not budgeted.** The proposal,
to be ratified before anything is built:

**Burn state becomes PER-CELL DATA, not per-cell nodes.** This engine already has
the mechanism and has already paid for it twice: PERF-P2 moved soot into a
per-level `RG8` image sampled by `voxel_face_shading.gdshader`, and PERF-P3 moved
the light bucket into the same image's second channel. A cell's burn state
(FLAME / INCANDESCENT / BLACK plus a phase byte) is the same kind of value, and
the same trick applies: **N voxels burning cost one texture upload per level per
frame, exactly like N voxels being sooty do.**

What that buys, item by item against §1:

| spec item | as per-cell data |
|---|---|
| flame vibrating ~0.5 s | a phase byte the shader animates; no node, no particle |
| incandescent, glow → black over 1 s | a second byte the shader maps to emission |
| propagation, biased up, decaying | a CPU pass over a small frontier — the BFS shape `derive_soot_rings()` already has |
| ember transmission destroys the voxel | a real committed mutation, through `WorldDelta.commit()` |
| smoke upward 1–2 s | **the one thing that stays a particle**, and it is already `add_smoke()` |

⚠️ **This is a PROPOSAL and it changes what §1 looks like on screen.** A shader
flame is not a sprite flame; "uma pequena chama que vibra" drawn as a per-cell
shader effect will read differently from an authored flame sprite. The Director
should see a real one before the whole system is built on it — which is why §4's
first task is one voxel, on screen, and nothing else.

---

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

## 4. TASKS — one voxel before one system

| id | task | gate |
|---|---|---|
| **F-0** | **The look spike: ONE voxel, on screen.** Flame phase + incandescent fade + black, as per-cell data through the shader. No propagation, no destruction, no removal of anything. | The Director looks at it and says whether a shader flame can be *"uma pequena chama que vibra"*. §2's whole proposal stands or falls here, and it costs one voxel to find out. |
| **F-1** | **The state machine, CPU side**, with the frontier BFS: all directions but −Z, biased +Z, decaying strength. Still no rendering, no removal. | A selftest over a synthetic wall: propagation reaches up more than sideways, never down, and terminates. Plus the interior-slice rule of §1.3. |
| **F-2** | **Ember transmission as a committed mutation** — through `WorldDelta`, `commit()`, and `bump_world_revision()`, the seam SS-3 just built for scorch. | The **cell probe** (`INFILTRAITOR_CELL_PROBE=1`): `0 RESTORED, 0 VANISHED`. That is the gate the current fire fails 350 cells deep. |
| **F-3** | **Wire it to the blast**, soft materials only, alongside the old path behind a flag. | Both fires runnable on one build; the probe green on the new one. |
| **F-4** | **Remove the old mechanism** (§3), with the passage question answered first, not after. | Repo-wide grep with a named caller list pasted into the commit; `passage over N burnt edge(s)` still reported by the new path or explicitly retired by the Director. |
| **F-5** | **Smoke**, and the rhythm pass the Director deferred (*"o ritmo ainda precisa melhorar, mas isso a gente faz depois"*). | On video, 3× slow motion — the instrument that found every defect this session. |

**Order rationale:** F-0 first because §2's proposal is the load-bearing
assumption of everything after it and it is cheap to falsify. F-4 last because a
removal is irreversible and the replacement should be proven before the thing it
replaces is gone.

---

## 5. OPEN QUESTIONS

1. **F-0's verdict** — can a per-cell shader effect carry *"uma pequena chama que
   vibra"*? If not, §2 needs a different answer and the cost conversation
   restarts. Nothing else should be built until this is looked at.
2. **The passage** (§3) — does the new fire owe `BURN_THROUGH`'s openings, or is
   that feature retired with the old mechanism? A Director call, and it decides
   whether §1.6's transmission needs to guarantee connectivity or merely produce
   holes.
3. **Seconds or frames.** §1's durations are in SECONDS (0.5 / 1 / 1–2). This
   project has been burned both ways — `front_frames` silently retuned 5× by a
   perf change, and the burn's commit cadence deliberately pinned in seconds.
   The rule for the new system should be written down once, here, before there
   are three of them.
