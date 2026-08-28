# RESUMO_SESSAO — 2026-08-27/28 · THE CHOREOGRAPHER IS THE VILLAIN, AND HALF THE PREMISE WAS FALSE

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-27_SOOT_STORE_AND_THE_FIRE.md`
**Commits:** `8fa2b791` `e42ed20b` `00bf761a` `fb0ab51a` (+ this one) — all pushed.
**Gates at close:** lint ✅ · selftests **40 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅ · no cited PNG modified · 3 dead links, all pre-existing in one
2026-08-06 summary.
**VERSION:** unchanged at 0.9.107 (no tag requested).

---

## Read this first if you are resuming

**Where work resumes: `DETONATION_PRESENTATION_MASTER_PLAN` D-2.** It is unblocked
— the open question it was waiting on (the passage) was answered by the Director,
and all four risks raised against the follow-up task are ruled on. D-0 is built
and pushed. Nothing is half-done; the tree is clean.

The session did four things: **named §9.11e's writer** (350 = 350), **measured the
whole explosion** and found half the Director's premise false, **wrote the plan**
that reforms the choreographer, and **built D-0**, which turned out to carry half
of D-1 with it.

---

## 1. ⛔ §9.11e's writer is named — 350 of 350, one line of code

The previous session could attribute the 350 restored cells to *"the fire"* and no
further. `DetonationChoreographer._fade_in_soot()` opens by applying each soot
entry's alternative up front:

```gdscript
layer0.set_cell(entry["cell"], entry["source_id"], entry["atlas_coords"], alt0)
```

`source_id` and `atlas_coords` are read off the TileMapLayer **during the COOK**.
The fire then eats voxels for 1.38 s *after* that snapshot, and `touched_this_blast`
— the set that keeps this blast's own holes out of the soot wave — is built from
the Delta's projected state, **which does not contain the burn wave at all** (the
burn is a SCHEDULE, not damage). So every voxel the fire consumes is still a live,
placed cell as far as the plan is concerned, and the beat replays it onto a hole.

```
[E-FUME-ERASED] 350 of 1914 soot entr(ies) were applied to a cell that is EMPTY now
[CELL-PROBE]    1163 erased · 350 RESTORED · RESTORED by frame: f125:350
```

**350 = 350, one frame, same boot.** The control is free and it landed the same
day: the hard-material run reports `[E-FUME-ERASED] 0 of 879`.

⚠️ **NOT fixed, deliberately.** A guard that skips erased cells would also drop
their scorch, and the Director's §5.3 ruling is that a fire-consumed voxel SHOULD
scorch. The honest fix is the cook owning the fire's consumption — D-2.

⚠️ **And the surface is wider than that one loop.** `_apply_entry()`'s `expose`,
`dented`, `cracked` and `soot` branches all `set_cell()` with a cook-time
`source_id` too. Same class: **the waves are a replay of a snapshot, and the fire
is a second mutation stream running underneath it.**

---

## 2. ⛔ THE PREMISE WAS HALF FALSE — the explosion is not expensive, it is LONG

The Director: *"O sistema todo de explosão está caro e lento… menos é mais."*
Measured on real windowed boots with **no per-frame capture readback**
(`INFILTRAITOR_THROW_PROFILE=1`):

```
+   0 ms  f=  0   BEAT 1 — fire lit
+ 809 ms  f= 35   COMMIT — 11.3 ms, 951 voxel(s) written
+4797 ms  f=264   WAVES end — the blast is over
```

**951 voxels destroyed, dented and cracked in 11.3 ms. The event takes 4.8 s.**

| | measured |
|---|---|
| mean frame during the event | 17.4 ms |
| `_advance_burn` across ALL 77 fire frames | **12 ms** |
| every cell write of a 2 820-entry plan | **20.13 ms** (concrete 5.68) |
| TileSet alternatives minted | **0** |
| the light ramp's share | **43% of a fabric event, 70% of a concrete one** |
| the one real stall | **176 ms light derive, in a single frame** |

**"Caro" was fixed by three perf waves and nobody re-measured the FEELING
afterwards, so the word survived its own fix.** "Lento" is entirely true and
entirely SCHEDULE — 264 frames around 11.3 ms of work, and the biggest single
piece is one constant, `consequence_light_seconds = 2.0`.

---

## 3. The plan — `DETONATION_PRESENTATION_MASTER_PLAN`

Supersedes `FIRE_REBUILD_MASTER_PLAN` (written the day before; nothing retracted,
its §1 fire spec still lives there). Indexed in `docs/README.md`.

**The inversion:** today the WORLD is animated and the effects decorate it. From
here **the world changes once and the EFFECTS are what is animated.**

**What is explicitly NOT rebuilt** (§2), because both are what the Director's own
*"pre-cook the important frames"* idea needs:
- the pure `build_plan()` → `WorldDelta` → `commit()` spine — the final crater is
  **already computed before anything is shown**; it needs USING, not building;
- P3's cell plane — *"a new effect is a new CHANNEL, not a multiplier"* is already
  a property of the architecture.

**What dies** (§3): of the choreographer's four jobs, the two that exist only to
spread 20 ms across 24 frames. That kills the ordering problem **whole** —
`KIND_RADIUS_BIAS` has been re-derived three times — plus §9.11e and the fire's
second mutation stream, by construction.

⚠️ **§4.1, a constraint worth not rediscovering: a TileMapLayer cell cannot
cross-fade.** It is set or erased. So the Director's *"5 frames em alpha"* fallback
can only ever be an overlay over an already-final board — the same conclusion as
"one commit, then only drawing", reached from the other side.

---

## 4. ✅ D-0 BUILT — and it carried half of D-1 with it

Three env overrides, no architecture, fully reversible: `INFILTRAITOR_FRONT_FRAMES`,
`INFILTRAITOR_SOOT_SECONDS`, `INFILTRAITOR_LIGHT_SECONDS`. **Both pacings run from
one binary**, so a before/after needs no stash.

| flash → blast over | control | rehearsal |
|---|---|---|
| hard (concrete, no fire) | ~2 940 ms | **878 ms / 48 frames** |
| fabric (with fire) | 3 891 ms | **2 310 ms / 122 frames** |

⚠️ **`front_frames = 1` IS the collapsed commit frame.** `front_radius_for()`
returns `INF` on the last frame, so at 1 the whole queue drains on frame 1:

```
fabric  [E-WAVE] frame 1 front_r=inf cells=2820/2820 apply=18.548ms
hard    [E-WAVE] frame 1 front_r=inf cells=1559/1559 apply= 4.205ms
```

**18.55 ms against a predicted 20.13; 4.21 against 5.68 — collapsed is CHEAPER
than spread, on both materials**, and a third boot reproduced it at 18.296. That
is *"cost is per frame that WRITES, not per cell"* confirming itself: 24 flushes
became one. One commit frame lands at ~42 ms (fabric) / ~16 ms (hard).

**The finding that sets the order:** of the fabric rehearsal's remaining 122
frames, **74 are the fire's schedule**. Subtract them and fabric lands on 48 —
exactly the hard number. So **D-0 buys half and D-2 buys most of the rest**:
~880 ms projected, both materials.

Two 3× slow-motion videos were handed to the Director (`A_control_4.8s.mp4`,
`B_rehearsal_2.4s.mp4`, in the gitignored `Screenshots/filmstrip/`). The pacing
numbers are mine to pick — *"faz o que achar melhor e vamos ver como fica"* — and
they stand until the Director says otherwise. They are env vars, not a rebuild.

---

## 5. ✅ THE BUBBLE IS THE CONTRACT — the Director's ruling, and it is two proposals

> *"A passagem abre quando a área de atuação da granada (bolha da mira) acerta
> a(s) slice(s) bloqueando a passagem… independente do que o efeito decorativo ou
> voxels visíveis indicarem. De fato, toda a explosão pode ser baseada em GUs e
> Slices… um mecanismo de destruição pré-fabricado para slices e slabs."*

Split in `DETONATION_PRESENTATION` §11, because they have different values.

**§11.1 — the passage contract. Recommended without reservation.** It is not a new
idea in this engine: `OCCLUSION` O1 already says *"occlusion is VIEW, not STATE"*
and `LIGHT_MASTER_PLAN` already says *"visual brightness ≠ tactical visibility"*.
It closes what `MATERIALS` §3.2a explicitly refused to decide, and it removes a
real failure mode — a correctly placed grenade can open nothing today because the
count landed badly. The shape is already right: `aim_dome_radius_gu = 2.0` against
four blast rings, so **the bubble is the guaranteed core and the blast fades
beyond it.**

**§11.2 — the pre-fabricated pattern. Recommended, but not for the stated reason.**
Measured the same day, `INFILTRAITOR_PREDICTION_PROFILE=1`:

```
[P-SLICE] total 399.0 ms
  WALK      260.3 ms  65%   <- map-wide occupancy/soot index, decides no damage
  SLICES     34.9 ms   9%   <- the per-voxel determinism, walls
  FLOORS     12.3 ms   3%   <-  ... and floors
```

**The whole per-voxel determinism is 49.8 ms of 399 — 12.5% — of a cook that is
already 0 frames in real play.** So *"não precisamos calcular toda a
determinística"* saves an eighth of something already hidden. **The real argument
is the LOOK:** `_select_deterministic()` ranks by FNV-1a and takes the first N —
a statistical scatter, which is what the Director has been fighting for weeks
(E-CONTRAST ×3, E-CLEAN, E-ORDER). *"Menos é mais"* is expressible as an authored
mask and is **not** expressible as a count.

---

## 6. ✅ The four risks, all ruled on by the Director

1. **The ladder must exist** — a pattern per material TIER, or metal and fabric
   break the same shape. This is the design work of D-2b, not a detail.
2. **Firearms may differ** — *"as armas de fogo estão ok e não geram queima."*
   Verified: `start_burn()` has exactly one caller, the grenade path.
   ⚠️ **The Director's own correction: that is the CURRENT STATE, not a
   prohibition.** A future incendiary round is not vetoed by it.
3. **Smaller containers** — *"imagino que atender uma quantidade menor de voxels
   seja uma consequência natural do mecanismo."* Right, and it is what makes the
   mechanism cheap: a pattern applies to whatever voxels a container has. The gate
   is that panels and `JunctionColumn` still take damage at all — E-JUNCTION-01's
   exact regression.
4. **Nothing stored may be view-space** — *"queremos um mapa de fuligem bem
   planejado, simples e eficiente, que consiga lidar com as rotações."*
   ⚠️ **Half-built already:** SS-1's store is base-keyed with a six-direction
   format and SS-2 made it the source of truth at 0 px. **The unbuilt half is
   `SOOT_STORAGE_REFORM` SS-6 — prove it under rotation — and it is blocked on a
   capture action that rotates the view, which does not exist.** Now explicitly
   wanted rather than deferred.

---

## 7. Instruments built or used this session

- `[E-FUME-ERASED]` — counts soot entries applied to a cell that is empty NOW.
  The line that named §9.11e's writer. Permanent.
- `INFILTRAITOR_FRONT_FRAMES` / `SOOT_SECONDS` / `LIGHT_SECONDS` — D-0's pacing
  overrides, and `FRONT_FRAMES=1` doubles as the collapsed-commit-frame probe.
- `INFILTRAITOR_THROW_PROFILE=1` — the `[T-PROF]` beat timeline. **This is the
  instrument that overturned "caro"**, and it existed the whole time.
- `INFILTRAITOR_PREDICTION_PROFILE=1` — the `[P-SLICE]` per-phase cook profile.
- ⚠️ **Never read frame cost off a filmstrip run.** The capture's per-frame GPU
  readback put the front at 4 152 ms where the real one is 422. Every number in
  this summary comes from a run with no readback.

---

## 8. OPEN — in order

1. **D-2** — the cook owns what the fire consumes AND guarantees the passage from
   the bubble. Unblocked. Kills §9.11e at its root and removes 74 of the fabric
   event's remaining 122 frames.
2. **D-3** — the presenter, behind `INFILTRAITOR_PRESENTER=1`, old path still
   default.
3. **D-4** — the symbolic fire (the instanced ember). The one part that is genuine
   new construction rather than deletion — the shipped ellipse-with-feather is a
   different thing, not a cheaper version of the spec.
4. **D-2b** — the pre-fabricated pattern, gated on the Director looking at a
   crater, explicitly not on a millisecond.
5. **D-5 / D-6 / D-7** — the light at the end, the removal, the rhythm pass.
   **SS-6 rides with D-7.**
6. **Untouched from earlier summaries:** `SOOT_STORAGE_REFORM` SS-4/SS-5, the
   glowing edge, `INFILTRAITOR_HIDE_VOXELS` (§14.3 — it does not work and §12
   cited it), `update_docs.py`'s silent wipe, smoke separation, audio.
