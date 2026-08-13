# RESUMO_SESSAO — 2026-08-12/13 (Sectioned Dome · P-WARM · Soot Reform)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-12_WALL_GRID_AND_SHRAPNEL_FIX.md`
**VERSION:** 0.9.97 → **0.9.98**
**Commits:** 11, `c30601d`–`cb5a344`, plus this checkpoint.
**Plans touched:** `TARGETING_MASTER_PLAN` §6.2 (closed),
`PREDICTION_MASTER_PLAN` (P-WARM), `EXPLOSION_REBUILD_MASTER_PLAN`
(E-ORGANIC-02), and a new `SOOT_MASTER_PLAN`.

---

## The one-line version

Three fronts closed: the aim dome is really sectioned by walls, the blast's
playback stopped doing work it could have done during the throw (**753 ms → 84
ms**), and soot went from five mechanisms in two implementations to one. The
throughline is that **four separate claims in this session were overturned by
measuring them**, including two of my own headlines and one of the Director's
long-standing beliefs about where the time went.

---

## 1. E-BUBBLE — the dome is sectioned (§6.2 closed) · `c30601d`

The previous session built a wall-moulded grid and the Director rejected it
("mais angulosa"). Re-reading `48cf3b4` said why, and the mechanism was never the
problem: it moulded only `_draw_wall_grid()` and left `outline`/`disc` as the
full undistorted ellipses, so the **silhouette stayed a perfect round balloon
with a dented interior**. The rim ellipse is byte-identical between
`grenade_wall_grid_molded.png` and the plain build.

Now: the silhouette itself is cut, the sphere grid is not bent (only hidden where
a wall stops it), and each visible wall face carries its own grid in the WALL's
axes — the Director's own diagram.

**Why a radial sweep and not a convex hull**, since the hull is the obvious
reach: a wall is a FINITE rectangle, so a parapet leaves a region that is not
convex at all (the dome bulges back over it) and a hull would fill that notch in.
What the region always is, is star-shaped about the dome's centre, which a linear
projection preserves.

**Four defects, each found by measuring rather than looking:**

| defect | how it showed |
|---|---|
| `EdgeExtractor` works per cell PAIR, so one 7 GU wall arrived as seven 1 GU edges | six full-weight seam strokes across one flat surface |
| a solid block is a box → the scan returns FOUR walls, only one visible | three would paint grid onto the back of a solid block, through it |
| the radial sweep aliased — 96 floor samples into 180 buckets | 19 empty buckets; the comb along the floor and sawtooth down the cut |
| a wall's own EDGE casts a shadow curve onto the sphere, never sampled | nine 60 px jumps in the arc above a block the dome clears |

Verified numerically, not by eye: the radial function is smooth at all 180
buckets across three aim cells, and its extremes land on **362.04 and 367.65 px**
— exactly `IsoProjection.sphere_semi_axes(2.0)`.

`IsoProjection` gained `kernel_direction()`/`silhouette_basis()`, asserted in
`iso_projection_selftest` [11] against `sphere_semi_axes()` **by a different
route through the basis**, so the two cannot agree by construction.

Evidence: `grenade_dome_sectioned_front.png`,
`grenade_dome_parapet_overtop.png` (3 GU dome over the 2 GU block — captured with
`aim_dome_radius_gu` temporarily raised, since no map ships a parapet, and
reverted immediately).

---

## 2. P-WARM — the blast stops computing at the worst moment · `c8f9054`, `4bfe237`

The Director asked to measure before optimising. `INFILTRAITOR_THROW_PROFILE`
(new, off by default) prints one timeline from release to last wave, in **ms AND
frames** — which turned out to be the whole answer, since every beat is
frame-paced and a wall clock alone cannot tell a slow frame from an extra one.

    +0     f=0    release
    +750   f=45   prediction FINISHED — 213 ms of work over 46 frames
    +1767  f=106  fuse ends, fire lit, cooking 0 frames
    +1933  f=116  10 beat frames at 16.6 ms each
    +2703  f=122  blast over — 5 wave frames costing 753 ms

**Pre-production was never the problem** — it finishes with 1.2 s of slack and
beat 0 runs zero frames. The destruction was, at ~150 ms/frame against a 16.7 ms
baseline the same run measures everywhere else.

**My first root cause was wrong, and the correction matters more than the fix.**
The evidence pointed at "writing into the big floor layer is expensive" — frame 5
writes 18 cells into a 29 750-cell layer and still cost 117 ms. The real cause:
`_ensure_light_alt()` calls `create_alternative_tile()`, which mutates **the
TileSet every TileMapLayer shares**, so ONE new alternative forces the lot to
rebuild. The floor is simply where most damaged cells are, so it is where most
alternatives got minted — correlation, not cause. A frame minting one and a frame
minting three hundred cost the same; a frame minting none costs nothing.

Three things moved into the throw window: the 1 590-step queue flatten (8.5 ms),
the tile-alternative minting (~105 ms **per frame**), and the 2048×2048 composite
page upload (~133 ms once).

    before   5 wave frames over 753 ms   (~150 ms each)
    after    5 wave frames over  84 ms   (~17 ms each — a normal frame)

Proven not to change a pixel: **0 differing pixels, max delta 0**.

**The warm-up is deliberately NOT sliced**, and that is the trick rather than an
omission. The first version budgeted it across frames like the pump does and made
things worse — the throw stuttered for 490 ms across five frames instead of one,
because the cost is the per-frame TileSet rebuild, not the ~30 ms of CPU. Same
inversion `DetonationChoreographer`'s own header warns about, met from the other
side. It lands at ~+765 ms, past the flight, while the grenade sits cooking.

---

## 3. E-ORGANIC-02 — dents and cracks stop being re-gated by ring · `032c9be`

P-WARM's dropped-entry counter earned its keep one throw after it shipped: **18
dents planned, warmed and silently dropped on every blast**. `WAVE_TABLE` listed
`dented` at rings 0-1, matching `EXPLOSION_REBUILD_MASTER_PLAN` §4.2's FIRST-PASS
weights; the shipped `frag_grenade.json` says `dent_ring_weights[2] = 0.25`, and
§4.2 itself calls those weights tuning knobs expected to move. They moved; the
table did not.

`PLAYED_KINDS` + `wave_table_for(plan)` replace the constant. Safe because
E-RADIAL-01 sorts by radius and breaks ties on KIND, so the table's rings had
stopped carrying any order and were a pure filter — this changes what is drawn,
never when. 1 590 → 1 608 steps; the selftest reads `wave_table_for(plan)` now,
which is strictly MORE than the constant covered.

---

## 4. The soot reform — `SOOT_MASTER_PLAN`, five tasks

### What was there

Five writers, three live, the whole assembly implemented **twice** — in
`_phase_soot()` and again in `room._build_soot_snapshot()`. Already drifted in
three measurable ways (the detonation read its own literal ring count; only the
repaint scorched the revealed crater floor; room's crater-floor merge OVERWROTE
instead of min-wins and never wrote faces).

The three live mechanisms were not arbitrary — each covered a different evidence
that a surface should be scorched. Two of them were patches for one root
limitation the Director named directly: **the primary mechanism keys on
DESTRUCTION, not on EXPOSURE**, so a ring that destroys nothing can never scorch.

### The direction that was measured and rejected

I proposed promoting the stamp into a single exposure-keyed rule. Measured A/B/C
on one real throw before writing it:

    A  today: BFS + self-soot         baseline
    B  stamp + BFS + self       A vs B: 43 135 px differ
    C  stamp only               A vs C: 77 168 px differ

Director on B and C: *"muito esquisitos (...) parecendo glitch (...) fica muito
forte por GUs, mas de repente na GU do lado não tem nada."* That last complaint
is mechanism: the stamps ran once per CONTAINER — per GU — each from its own
distance ramp with no continuity to its neighbour. **The hard GU boundary is the
shape of the stamp**, and no tone table removes it. So the plan inverted: delete,
not promote.

### What shipped

| task | result |
|---|---|
| **S-FEATHER** `abf7add` | faint directional tail past the graded rings — turned out to be a parameter, since `derive_soot_rings()` already caps everything past `intensity_rings` at the faintest tone. Split into `blast_soot_feather_rings` rather than raising `blast_soot_rings`, whose 4 was pinned deliberately by PERF-02 B3-2. soot 512 → 735, +5 ms, 6 059 px / max 18 |
| **S-KILL-STAMP** `0c787d9` | both stamps, `_toward_for_carved_side()`, 3 call sites, the ctx flag, the env var, 6 selftests. 346 lines. **0 px, max delta 0** — the gate that proves a dormant deletion really was inert |
| **S-DEEP** `1a0c8b5` | revealed voxels take the blast's soot. Two fixes, because exposure has two outcomes (real deep Slab → `also_visible`; FIXED earth cells → written directly, which is what room always did and the detonation never did). 2nd blast 7 307 px; **1st blast 0 px** — precisely scoped |
| **S-DEDUP** `46c50d0` | `BlastCalculator.build_soot_field()` is the only place the sequence exists. `merge_soot_field()` replaces two byte-identical 23-line copies, verified line by line before either was deleted |
| **S-FADE** `cb5a344` | four-rung ring-code ramp. Final state **0 px** — the fade ends exactly where it started |

**S-LOCAL was dropped from the schedule**, on its own measurement: 57 ms against
1.2 s of slack is not a reason to touch the most-verified file in the project.

---

## 5. Four claims this session overturned by measuring

Recorded together because the pattern is the point.

1. **"Soot's global shape forces the 133 ms map-wide walk."** Mine, and the
   headline of the soot plan's first draft. Checked because it gated the
   recommendation: `occupancy` is genuinely map-wide, so the walk survives. Real
   share ~57 ms. Retracted in place; performance demoted from the reason to a
   side effect.
2. **"Writing into the big floor layer is what costs 120 ms."** Mine. It was
   correlation — the cause is the shared TileSet rebuild on any mint.
3. **"The ~120 ms per-frame figure is a harness artefact at ~8 fps"** —
   `detonation_choreographer.gd`'s own header caveat. The harness measures 16.7
   ms/frame everywhere outside the blast. The number was real.
4. **"One rule absorbs all three soot mechanisms."** Mine, rejected by the
   Director on the picture the A/B/C produced.

---

## 6. Verification

    project_lint.py          ✅ 204 files, 0 errors (after every commit)
    check_invariants.py      ✅ OK
    gen_codemap.py --check   ✅ OK
    run_selftests.py         34 clean, 1 failed (pre-existing)
    iso_projection_selftest  28 PASS / 0 FAIL (24 → 28, new [11])
    blast_calculator_selftest 82 PASS / 0 FAIL

The one failure is `detonation_choreographer_selftest`, unchanged all session:
one fixture frame carries 91% of the queue. It predates this work — and note the
real map is healthy at 35.8% worst frame, measured this session. It is a
fixture/real divergence, not the blast collapsing.

Hand-named captures: `grenade_dome_sectioned_front.png`,
`grenade_dome_parapet_overtop.png`, `e_soot_abc_stamp_vs_bfs.png`,
`e_soot_feather_before_after.png`, `e_soot_second_blast_deep.png`,
`e_soot_deep_before_after.png`.

---

## 7. Two gaps left open, deliberately

Both are evidence gaps, not code gaps, and both resolve with the filmstrip the
Director has queued next.

- **The fade is only proven at its final state.** That it reads well *mid-ramp*
  has not been seen by anyone. Four rungs may pop; SOOT_MASTER_PLAN §4b.1 records
  the Director's own overlay proposal as the alternative to return to.
- **The repaint path has no trustworthy pixel gate.** `weapon_fire` is NOT
  deterministic — **691 differing pixels between two runs of identical code**,
  measured after an S-DEDUP diff of 848 px looked like a regression and wasn't.
  CLAUDE.md's "a pixel-diff gate has to be EARNED" is what caught it. Spun out as
  its own task.
- **`room._crater_floor_soot`'s merge has no capture path at all** — it is only
  populated by the rotation replay, and no capture action rotates. Flagged at the
  code as reasoned, not measured.

---

## 8. Where the next session starts

1. **The filmstrip** (Director's own ordering): frame by frame of the whole
   explosion, with time and frame count, to judge the fade and the beat timing.
2. `SOOT_MASTER_PLAN` §6 Q3 — should two blasts on one spot leave a dirtier mark
   than one? Only Option B (soot as stored state) can express it, and that wants
   the segment persistence layer.
3. `detonation_choreographer_selftest`'s fixture, still red.

Nothing here blocks anything else.
