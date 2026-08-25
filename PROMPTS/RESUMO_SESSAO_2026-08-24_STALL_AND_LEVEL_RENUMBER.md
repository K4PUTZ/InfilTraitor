# RESUMO_SESSAO — 2026-08-24 · THE STALL WAS A WALK, AND EVERY LEVEL IS POSITIVE NOW

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-23_FIRE_PERF_AND_P3.md`
**Commits:** `ab391c76` `cdfb9203` `54d160a1` `bccdf4ca` `52b28922` `fa7ce1ca`
`6ac63e92` `f4ba0df6` `053846a0` `2fa67af0` — all pushed.
**Gates at close:** lint ✅ · selftests **39 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅ · board census byte-identical · fire end gate 0 and 0.
**VERSION:** unchanged at 0.9.107 (no tag was requested).

---

## Read this first if you are resuming

Three things landed, in this order: **the Director's soot bug is fixed**, **the
game's longest frame dropped 72%**, and **every render level is non-negative**.

**Where work resumes:** nothing is half-done. The tree is clean and pushed. The
open list at the bottom is genuinely open, not in flight.

---

## 1. §9.11a — the Director was right, and every before/after instrument was blind

Their repro, run as given: fabric at gu (31,3), then plywood at gu (35,3).

**The end state is bit-identical.** 0 of 205 162 cells changed near fire 1, and
with `INFILTRAITOR_VFX_DRAW_NOOP=1` all 50 680 differing pixels sit in fire 2's own
block. Every instrument this plan owned said nothing happened.

**The report was about the FLIGHT.** Sampled every frame through fire 2, fire 1's
settled crater shows **180 cells going near-clean and back** — soot 26 → 119 → 26
over frames 55..59, **0 of them permanently changed**.

**Mechanism:** `_phase_soot_wave()` walks the whole-map soot snapshot and admits a
cell when `alt != prev_alt` **OR** its soot moved. A blast changes shadow, so an old
crater's light bucket moves, so its cells enter the wave **with their soot
untouched** — and `_fade_in_soot()` ramps them anyway. The function's own header had
predicted exactly this failure mode and claimed the design avoided it.

**Fix:** a cell already carrying its target scorch is not ramped. **180 skipped
against 180 measured — the same cells, two independent instruments.**

§9.11c then closed the residual: the alternative id still moved for five frames, and
a **control run with a second blast that never ignites** (brick, flammability 0)
proved it is the light being correct at each instant — 184 cells changed, **0
flickered**, when no fire follows. What remains there is a look question, not a bug.

## 2. The stall — measured, not assumed

`frames during the fire: 21 · mean 88.8 ms · max 266 ms`, then
`final repaint 1 058 ms`. **The map-wide final repaint is the longest frame in the
game by a factor of four.**

`INFILTRAITOR_APPLY_SPLIT_PROBE=1` priced it:

```
205 384 cells · derivation 70 ms · apply 646 ms (96 written, 64 minted)
              · walk-only 609 ms · writes+mints 37 ms  (−3 ms on a second sample)
```

**It is the WALK.** The pass writes 96 cells out of 205 384. Every hypothesis this
plan chased for months — the TileSet rebuild, the mint count, the soot snapshot — is
priced here at 37 ms. It also retires the fire pre-cook for good (§9.12): a 16-stage
warm costs 1 201 ms to buy 50 ms, and **no amount of pre-minting shortens a walk**.

**Fix:** the apply is driven by `VoxelLightField`'s own stale set, which
`build(geometry_only)` already computed and threw away.

```
fire 1 final repaint   1 024 → 282 ms      fire 2   984 → 297 ms
whole fire             2 773 → 1 999 ms    (−28%)
gate: 0 of 205 379 and 0 of 205 156 cells differ from a map-wide ending
```

⚠️ **The pixel diff is deliberately NOT the gate.** Two boots of the same code differ
by **22 967 pixels** (`BURN_COMMIT_INTERVAL_S` is pinned in seconds, so the speed-up
itself changes which frame commits what). The 228-pixel A/B was noise wearing a
number. The CPU gate compares cell state on one boot.

**Three defects, each found by the gate refusing to pass** (the first attempt failed
by 200 cells): `_placed_by_gu` was rebuilt only by the full pass and only read by
scoped ones; `DetonationChoreographer` writes the board behind the light field's
back (**the map-wide walk WAS that bookkeeping, done by brute force**); and
`_stale_cells()` diffed the isotropic ring map but never the per-face triples the
renderer actually writes.

**§10.5 — the shot took the same route**, and there it was correctness, not speed:
`3 144 → 0` cells disagreeing with a full apply, repaint 81.7 → 75.4 ms. Verified
against a stashed HEAD so the 3 144 is not this work's doing.

## 3. The storey renumber — playable storey is 10

⚠️ **The premise needed a correction that was mine to make.** I reported §10.2's
residue as "47 of them on negative levels", which reads as the sign being at fault.
It was not — the discriminator was `indexed=false`. **Renumbering would not have
prevented that bug.** What the sign cost was a second store and paired walks
everywhere.

`PLAYABLE_STOREY = 10`, `PLAYABLE_LEVEL = 80`. Ground stack → storey 9, walls →
storeys 10/11/12, storeys 0–8 free for underground. Done in two staged commits so
the gate could isolate each.

**A render level is not a texture row**, and that cost four bugs:

| axis | cost before fixing |
|---|---|
| `BakedTileLookup` sheet rows (4 sites; the main wall path hides inside `_set_voxel_cell()`) | 2 112 cells absent, **no warning, no error** |
| `EarthVariantSelector` / `_generic_variant_for` — **B4-pinned** hashes | 52 224 floor cells, wrong source |
| light height classes (0/2/4/6 were heights) | 13 668 wrong light buckets |
| `OcclusionSet` level → screen Y | 2 112 cells wrongly ghosted |

`VoxelRenderer.relative_level()` is the one conversion. `bake_compositor`'s
`start_level` and `room_builder`'s junction `level_start` stay absolute — texture
space; the latter was shifted and reverted after reading its consumer.

## 4. What the census could NOT catch, and the selftests did

The census is a boot snapshot: it detonates nothing and moves nobody.

- **A real production bug:** `DetonationPlanBuilder` computed `base_level` unshifted,
  so `simulate_container_damage()` saw offsets of ~80, the ring lookup ran off its
  table and **a grenade damaged nothing at all**. Two siblings went the same way.
- ⚠️ **My own gate was built unable to fail.** It recorded what each cell HOLDS and
  not where its layer SITS — an absolute level in the layer's Y would have drawn the
  whole board eighty steps off screen **with a byte-identical census**. Found by
  accident. `pos=` was added and the baseline re-taken.
- ⚠️ **A blanket regex over the fixtures was wrong twice** — `_synthetic_voxels()`
  numbers its own voxels literally and keeps `base_level = 0`. The suite caught both.
- **`negative_storey_selftest` was half-migrated and PASSING** on levels eighty-odd
  below the map. A test that passes for the wrong reason is a defect; rebased.

## 5. Instruments added (all env-gated, all kept)

`INFILTRAITOR_CAPTURE_ACTION=level_census` (+ `CENSUS_OUT`, `CENSUS_LEVEL_SHIFT`) ·
`BURN_END_GATE` · `BURN_RESIDUE_PROBE` · `TWO_FIRES_ALT_PROBE` · `TWO_FIRES_GUS` ·
the per-frame watch inside `two_fires`, which is what made §9.11a visible at all.

## 6. Open, in order

1. **A look decision, yours:** the five-frame brightness wobble on a distant crater
   when a second grenade lands. Proven correct at every instant — keep or damp?
2. **§9.11** — `forget_ghost_record()`, still **not reproduced**. Needs a capture
   that WALKS the agent so occlusion ghosts the wall before the blast. The oldest
   real bug without red evidence.
3. ⚠️ **§9.11's dispatch citations are stale** — the plan records `grenade 0 → 350`,
   the capture now reports **0**. Re-measure before resting any argument on them.
4. **§9.11b residual 2** — the fire's map-wide final repaint lands inside the blast's
   own soot fade. Measured harmless (step 4 writes the true target); ordering to tidy.
5. **§8.22** — the cell recovery is not per-tile. Blocks P3, ships inside P2.
6. **P7b** — MultiMesh. Buys frame rate, ~4% of wall clock.
7. **F5** (fabric and cardboard as props) and MATERIALS **M4 glass / M5 props /
   M6 fluids**, plus the fire+destruction calibration.
