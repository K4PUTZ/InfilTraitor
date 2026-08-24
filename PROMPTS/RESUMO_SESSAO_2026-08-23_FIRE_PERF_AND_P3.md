# RESUMO_SESSAO — 2026-08-23 · THE FIRE'S LAG WAS THE LIGHT, AND P3 IS BUILT BUT BLIND

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-22_CELL_GATE_AND_P5A.md`
**Commits:** `053b9f55` `ac5d10ea` `9258fa54` `3ad1501b` `e3d7d4ab` `2141fb4e`
`459b1ce2` `3f4a1aec` `95a679e3` `a98d8ec6` (+ capture/F8/ghost fixes) — all pushed.
**Gates at close:** lint 216 ✅ · selftests **39 clean / 0 failed** ✅ ·
invariants ✅ · CODEMAP ✅.

---

## Read this first if you are resuming

**The headline: a fabric fire went 6 276 ms → 1 885 ms (−70%), and
`_advance_burn` went 1 268 ms → 11 ms.** The destruction system was never the
cost; the light it asked for was.

**Where work resumes:** `PERFORMANCE_MASTER_PLAN` §9.11a — the Director's reported
bug, with a CORRECTED repro they gave at close: **two grenades on DIFFERENT blocks
(fabric, then plywood); the second blast changes the FIRST one's soot.** Deferred
to today at their instruction. Everything needed to test it exists (§9.10's
two-grenade filmstrip and the per-fire board captures).

## 1. The measurement arc, and a plan that falsified its own thesis

`PERFORMANCE_MASTER_PLAN` was built on "per-cell state in TileSet alternatives is
the cost centre". Read together for the first time, its own five measurements say
otherwise, and §8 re-scoped it.

Then the term was isolated properly (§8.15), by manufacturing a control group that
did not exist:

```
a committing frame that MINTS          ~360 ms
a committing frame that mints NOTHING  ~126 ms   (112 / 126 / 131, three samples)
→ the minting                          ~240 ms
```

**And it is ONE rebuild per FRAME, not per alternative** — 7 frames minting 24
alternatives between them still paid 367 ms each. That finally explains why P2 cut
mints 93% for no wall clock at all (§1.1b): it reduced the count on frames that
were going to rebuild anyway.

## 2. What actually shipped for the fire

| | original | shipped |
|---|---|---|
| fire wall clock | 6 276 ms | **1 885 ms** |
| `_advance_burn` | 1 268 ms | **11 ms** |
| span | 3.34 s | 1.31 s |
| committing frames | 13 × ~346 ms | 6 (5 × 140) |

- **F8** — the burn's OWN region stops relighting for the burn's OWN duration.
  ⚠️ **Not F1**: F1 was a GLOBAL light cadence, was built, measured (6 276 → 4 027)
  and **rejected by the Director** because the light must stay responsive.
- **F6** — faster, more volatile fire. The old span was dominated by
  `EMBER_CLIMB_DELAY_S` staggering the flame UP the wall, not by burn life.
- **F3/F4** — the blast takes 70%, the fire burns the remnant, implemented in the
  SCHEDULE (the `destroy` wave is choreography; the damage comes from
  `BlastCalculator`).
- **F7** — the agent is locked while its own grenade resolves. A turn-structure
  correction that changes what the burn's wall clock MEANS. ⚠️ Built, **not proven**
  — no run has pressed a key during a burn.
- **`FireGlowOverlay`** — one `draw_rect` and a shader, never a primitive per voxel.

**Criterion 5 passed at 0 differing pixels** — the post-fire board is unchanged.

## 3. P3 is built, and blocked by something older than itself

The bucket leaves the alternative id: the ALT-id histogram collapses to
`{11: 205704}` — **zero light alternatives**. Data verified per-cell (0 of 205 704
disagree) and on the GPU. **Default OFF.**

⚠️ **The frame is wrong: 165 754 px (18%) against a control proven at 0.** Ruled out
BY MEASUREMENT: the atlas grid (55 sources, 0 misaligned), `layer_origin` (0 drift),
float rounding at the quad origin (0 px change), the CPU data, and the arithmetic
(flat-light A/B: **0 px**).

**What it is instead (§8.22):** the cell recovery is **not per-tile**. 16.4% of
adjacent voxel fragments recover a DIFFERENT cell where a per-tile recovery would
change ~3%, and 10.8% of drawn fragments read a plane texel nothing ever wrote —
found only after the plane's fill became a SENTINEL so "never written" stopped
sharing a byte with "full lit". **This is P2's recovery too, and it ships**; soot
hid it by being sparse.

## 4. Traps and self-corrections worth carrying

- **A percentage match is not a population match.** P3's residual and the gate's
  were 17.985% and 17.99% — and only **13.7%** the same pixels. Two defects.
- **Cheaper frames buy more frames.** F1 cut committing frames 62% and the
  non-committing ones went 28 → 44. Same effect as the VFX NOOP (§8.8b).
- **Histograms matching is not per-cell agreement.** The first census compared only
  totals and read as a pass.
- **Two self-inflicted defects, both of the class under investigation:** the glow's
  `release()` ran on only one of a fire's two end paths; and the leftover context
  menu in captures was my harness bypassing the button, not a game bug.
- **A diagnostic that cannot see a defect returns matching numbers.** The
  ghost-fix's red/green run was identical both ways because that capture never
  moves the agent.

## 5. Open, in order

1. **§9.11a** — the Director's soot bug, corrected repro. Today's work.
2. **§9.11** — `forget_ghost_record()` shipped as a correctness fix, **not
   reproduced**. Needs a capture that ghosts a wall, detonates, un-ghosts, detonates.
3. **§8.22** — the cell recovery. Blocks P3; ships inside P2.
4. **F9** — the whole fire in the pre-cook. Blocked: `_build_soot_snapshot()` takes
   `predict_weapon_cells` only, and a burn's holes are BLAST provenance.
5. **F5** — fabric and cardboard authored as props (MATERIALS M3-5b).
6. **P7b** — MultiMesh. 95% of the VFX `_draw` is submission; buys frame rate, ~4%
   of wall clock.
