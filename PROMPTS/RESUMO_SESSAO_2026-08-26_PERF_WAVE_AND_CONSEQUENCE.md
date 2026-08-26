# RESUMO_SESSAO — 2026-08-26 · THE PERFORMANCE WAVE CLOSED, AND THE ENDING BECAME A BEAT

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-24_STALL_AND_LEVEL_RENUMBER.md`
**Commits:** `19c9c5a7` `011ac3c4` `621a2a93` `238db227` `c525e2d0` `1481d212`
`d2f850a8` `5b286cc6` `db219753` `cb7274cc` `9e0b9f20` — all pushed.
**Gates at close:** lint ✅ · selftests **40 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅ · cell recovery **100.000% PASS** ✅ · circle gate **0 / 921 600 px PASS** ✅ ·
soot gate **0 disagreements** ✅.
**VERSION:** unchanged at 0.9.107 (no tag requested).
**Plan:** `PROMPTS/PLANNING/PERFORMANCE_MASTER_PLAN.md` §12 and §13 are this session.

---

## Read this first if you are resuming

Two blocks landed. **§12 closed the explosion/fire performance wave** — the event
went from 2 267 ms to 1 606 ms with the worst frame cut 267 → 31 ms, and P3 and
P7b now ship ON by default. **§13 turned the ending into a deliberate beat** at
the Director's direction: clean holes, decals leading the front, then soot (0.5 s)
and light (2.0 s) as the closing statement.

**Where work resumes:** nothing is half-done. The tree is clean and pushed. The
open list at the bottom is genuinely open.

---

## 1. The ablation that started it — and three of its four results were surprises

The Director's hypothesis was *"esse problema decorre do nosso sistema de
iluminação e/ou baking system"*. Built `INFILTRAITOR_NO_LIGHT=1` (the light-side
counterpart of the existing `FAST_BOOT`) and priced each system by removing it.

- ✅ **Light is the WHOLE overshoot.** The fire is designed to span 1.38 s and
  shipped at 2 211 ms; light off, 1 319 ms — the designed span and nothing else.
  The destruction wave spent **1 021 ms to do 6 ms of its own work**.
- ❌ **The BAKE IS A SAVING.** `FAST_BOOT=1` takes the `E-PLAN` census from 386 ms
  to **1 326 ms** (+243%, four samples) — decals composite live instead of
  resolving from an atlas. **Never propose turning baking off for performance.**
- ❌ **VFX buy frame rate, not wall clock** — 5% of the duration. So simplifying
  the effects, which the Director explicitly offered, shortens nothing.
- ❌ **Textures cost no CPU**, so the "sem texturas" half was not built.

⚠️ **A correction I had to make mid-report:** I first added `E-WAVE`'s 1 021 ms to
the fire's 1 928 ms and reported a ~3 620 ms event. `start_burn()` runs before the
wave animates, so the fire's window already contains those frames. The event is
~2 597 ms.

## 2. §3.3's floor residual — closed, and three hypotheses died on the way

The blocker on P3 for two sessions. Killed by measurement, not argument:

| hypothesis | verdict | how |
|---|---|---|
| float32 precision (the shader's own recorded theory) | ❌ dead | debug paint mode 5: residue **exactly 0** on 100% of fragments |
| atlas origin off-grid | ❌ dead | read the real origin of every PLACED CELL, not source metadata |
| multi-cell atlas spans | ❌ dead | every placed tile is 1×1 |

**And the gate was exonerated.** §8.18 had suspended it for accusing both sides.
A reconstruction-free test settles it: every pixel recovering one cell must fit in
one quad — **54.1% of the floor's recovered cells were OVERSIZED**, worst 1.69
quads, against 1.7% on walls. The gate was right.

**The bug was `mod`'s discontinuity at the atlas region boundary.** The fix carries
the quad's corner as a `flat` varying and resolves the provoking-vertex ambiguity
**from the fragment's own position** — the lattice cannot decide it, because
(32, 0) is `e1 − e2`, a real cell step of (+1, −1).

```
cell recovery   82.007%  ->  100.000%   every level, floor included
oversized cells  1 325   ->  0 (floor),  8 -> 0 (walls)
empty-cell claims 28 455 px -> 0
P3 picture       415 px at max channel delta 3, against a 0-px control
```

## 3. P7b/c — one MultiMesh for every circle

⚠️ **§8.6's task order said "ember first — the largest population". It is not.**
Measured per population: smoke **puffs** 68.9%, ember 24.0%, debris 6.7%, sparks
0.1%. The puffs lead by three to one, and both leaders draw the same primitive —
so P7b became ONE shared helper (`CircleField`) instead of a per-overlay rewrite.

**The sparks are the control that names the mechanism:** 46 `draw_line` commands
at 0.4 µs each against 1 325 `draw_circle` at 10 µs. **The cost is per-VERTEX**, not
per-command — a filled circle is a polygon rebuilt on the CPU every frame.

⚠️ **It does NOT reduce overdraw**, and §8.8b's claim that MultiMesh "also removes"
the rasterization is corrected in §12.10.

## 4. Where the wave ended

| fire 1 | before | shipped |
|---|---|---|
| `E-WAVE` | 1 018 ms | **108 ms** |
| mean frame | 86.1 ms | **17.6 ms** (12 → 57 fps) |
| worst frame | 267 ms | **31 ms** |
| fire end to end | 2 267 ms | **1 606 ms** |

Two candidates the plan had reserved items for died by measurement: the voxel
layers' "19.0 ms/frame" (hiding all 32 moves the frame by nothing — P3 had already
paid it) and the overlays' `_process` walks (1.16 ms total). The ~9 ms left is the
board's IDLE baseline, not the fire.

## 5. §13 — the ending became a beat

Director's ruling: a turn-based game has no physics deadline, so the change of
scene is a closing statement rather than a stutter.

```
decals -> holes -> expose -> debris -> embers -> smoke
-> the fire burns out
-> soot arrives    (0.5 s)
-> light arrives   (2.0 s)
```

- **The soot index is incremental** — 82% of its cost was an index walk visiting
  215 432 voxels to find ~2 000 seeds. Final repaint **286 → 149 ms**.
- **The hole opens CLEAN.** `expose` and the decals were writing scorch the instant
  the front arrived, so the scene was *"nascendo suja"* and the end ramp then wiped
  and refilled it. The beat is what made that visible.
- **The decals LEAD the hole** — `KIND_RADIUS_BIAS` was inverted from what the
  Director wanted and the marks were arriving as a second wave.
- **Shrapnel**: darker, 4× faster, 4× further, subtle trail, and the metal now
  leaves BEFORE the flash instead of after all seven of its frames.
- **SAVE-01**: no save system existed. `SaveState` is the plumbing; the soot index
  is deliberately excluded because it is a cache, not state.

## 6. ⚠️ Defects found by gates refusing to pass — the pattern of this session

Every one of these was invisible in a picture and would have shipped:

- **A cell key is not unique.** Junction and slice voxels can share
  `(grid_pos, level)`; the first incremental index answered for the wrong object —
  3 destroyed voxels reported as intact.
- **The soot index was cached with PREDICTIONS folded in** — a guess about the
  future stored as the board.
- **The circle gate PASSED VACUOUSLY on its first run.** The probe was a `Node2D`
  in world space while the capture camera sat at canvas origin, so nothing was on
  screen and two frames of empty floor compared equal: **0 differing pixels,
  VERDICT PASS, nothing tested.** Found by looking at the capture. It is a
  `CanvasLayer` now and fails loudly if the probe paints under 10 000 px.

## 7. ⚠️ Instrument limits established this session

- **A frame-indexed pixel gate over a detonation is IMPOSSIBLE.** The prediction
  cook is budgeted in MILLISECONDS, so it takes 42–48 frames depending on the
  machine and the blast lands on a different frame index every boot — two identical
  filmstrip boots differ by **219 234 px**. `INFILTRAITOR_RNG_SEED` exists now and
  does not help: the RNG was never the variable. Gate VFX changes on the static
  `INFILTRAITOR_CAPTURE_ACTION=circle_gate` instead.
- **The video shows DESIGNED time, never lag.** `--fixed-fps 60` is mandatory for
  the capture, and the per-frame readback would dominate the wall clock anyway.
  Lag is read off `INFILTRAITOR_BURN_PROFILE=1`.
- **Never edit source while a capture is in flight.** A quadrant sweep was
  discarded because its second run booted against a half-written tree.

## 8. Instruments added (all env-gated, all kept)

`INFILTRAITOR_NO_LIGHT` · `INFILTRAITOR_HIDE_VOXELS` · `INFILTRAITOR_QUADRANT` ·
`INFILTRAITOR_SOOT_SPLIT` · `INFILTRAITOR_SOOT_GATE` · `INFILTRAITOR_RNG_SEED` ·
`INFILTRAITOR_P7B` (opt-OUT) · `INFILTRAITOR_P3` (opt-OUT) ·
`INFILTRAITOR_CONSEQUENCE` (opt-OUT) · `INFILTRAITOR_CAPTURE_ACTION=circle_gate` ·
debug paint modes 5 (residue) and 6 (`local`) · `VfxDrawProbe` per-overlay and
per-`_process` splits · `build_filmstrip.py --video --fps`.

---

## 9. OPEN — in order

1. **The sound effect for the new shadows.** The Director's own *"depois botamos um
   efeito sonoro pra deixar mais evidente a aparição das sombras novas"* — the one
   item explicitly deferred by them, and the natural next step now that the light
   beat exists to hang it on.
2. **Look pass on the beat.** 0.5 s soot and 2.0 s light are the ratified numbers
   but have been seen once, in one video. Both are `var` on `Room`
   (`consequence_soot_seconds`, `consequence_light_seconds`,
   `consequence_light_steps`) and are tuned on a filmstrip, not on argument.
3. **`build_occupancy()` is the same map-wide walk the soot index just fixed** —
   39 ms of the final repaint's remaining 149. `field.build` is 67 ms and is the
   larger half; neither has been split the way §13.1 split the soot.
4. **P7c's remainder**: `DebrisOverlay`'s chips still draw one
   `draw_colored_polygon` each. Small, and only worth it if a measurement asks.
5. **§9.11 — `forget_ghost_record()`**, still NOT reproduced. Needs a capture that
   WALKS the agent so occlusion ghosts the wall before the blast. The oldest real
   bug without red evidence, and untouched this session.
6. **§8.22's cell recovery is CLOSED** (§12.9), which unblocks whatever was waiting
   on it — check the P2/P3 notes before assuming anything there is still open.
7. **SaveState has no caller.** The plumbing is built and selftested; wiring it to
   an actual save/load flow (slots, UI, autosave policy) is a Director decision and
   was deliberately not guessed at.
8. **Fire + destruction calibration** and MATERIALS **M4 glass / M5 props /
   M6 fluids** — untouched this session, unchanged from the 2026-08-24 list.
