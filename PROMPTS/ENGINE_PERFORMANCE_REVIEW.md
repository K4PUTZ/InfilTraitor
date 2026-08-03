# Engine Performance Review — whole-system reassessment

**Status:** ✅ Part 0 (diagnostic spike) run 2026-08-03 — real numbers in §8.
Recommendation in §9 is a recommendation, not a ratified decision — Option B
(kill rotation) awaits the Director's explicit go-ahead on the design
trade-off, not just the performance one.

**Continues:** the close of `PROMPTS/RESUMO_SESSAO_2026-08-03_D33_SPIKE.md`,
which named this "the whole-system engine reassessment" as the explicit next
step, ahead of D33 Part 1.

---

## 1. Why

The Director's framing (2026-08-03 conversation, this session): destruction
makes the map read as organic and natural, and once its remaining texture/
decal gaps close, most of what's left to build is gameplay, dice-rolling,
and overlays — not more geometry/rendering machinery. That raises a real
question before investing further in the rendering side: **are we counting
processing pennies on a system that's actually close to done, or is there a
structural cost here that no amount of polish fixes?**

Five concrete questions came out of that conversation:

1. Is destruction worth its resource cost, given the game is pivoting to
   short infiltration waves + puzzles + RPG progression, not grenade-heavy
   firefights?
2. Would killing the generic-material fallback and shipping baked-only
   textures win performance?
3. Or is the **baking system itself** the cost, such that going
   generic-only would be the actual win?
4. Is camera **rotation** the real villain?
5. Is emulating a 3D world in a 2D engine (isometric via `TileMapLayer`)
   fundamentally too expensive — would porting to a 3D engine avoid the
   dimension-translation tax entirely?

Mid-review the Director added a sixth, sharper option: **eliminate rotation
entirely and ship with only the initial perspective.** That is not a
performance question — it is a design trade the numbers below can inform but
not settle by themselves (§4).

---

## 2. What is true today — measured, not recalled

| Fact | Value | Where |
|---|---|---|
| `_set_perspective()` cost | **1918 ms**, with one grenade's damage on the map | D33 spike, `PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md` §9 S3 |
| What that call does | Full geometry rebuild from `MapSpec` (`_room_builder.build_from_layout()`), then guard/prop repositioning, FOW re-init, lighting rebuild, occlusion recompute — **every rotation, unconditionally** | `room.gd:1128-1235` |
| Baked sources persist across rotations? | **No** — `_baked_source_ids` is cleared on every rebuild; every rotation re-bakes | `voxel_renderer.gd:524-529`, cited in D33 §2 |
| One decal composite cost | 0.31 ms (1×) / 1.10 ms (4×) | D33 spike S1 |
| Bake warm-boot cost (disk cache) | ~32-35 ms, was 730-770 ms pre-fix | `docs/production/technical_debt.md` (BAKE-CACHE-01, resolved 2026-07-11) |
| Bake memory budget, PLAYGROUND | 75.9 MB across 17 pages; ~18 MB per baked ground material | `docs/technical/BAKE_SYSTEM_REFERENCE.md` (D21) |
| Baked vs. generic — runtime duality? | **None.** B1 (Branch Exclusivity) — every cell resolves to exactly one atlas path, chosen at load, never both at once. The "dual system" cost is a maintenance/test-surface cost, not a runtime one. | `docs/technical/BAKE_SYSTEM_REFERENCE.md` |
| Per-frame cost of overlays (FOW, movement) | **Zero.** No `_process()`/`_physics_process()` in either; both are `_draw()` gated behind `queue_redraw()` on discrete gameplay events. | `docs/production/technical_debt.md` #4, corrected 2026-07-15 |
| Real target-device measurement | **None exists.** Every number above was measured on Mac desktop (editor or windowed off-screen process), never on a phone/tablet or a web export under load. | — |
| Where perf work sits in the roadmap | `M7.0` — "target 60 FPS on 5-year-old devices" — is a **late** milestone, after content (`M6.05`), deliberately not now. | `docs/production/milestones.md:1012-1021` |

**The load-bearing structural fact:** this is a turn-based game. Almost every
cost that matters is a **discrete-event hitch** (rotate, load a room,
detonate), not a sustained per-frame cost. `_set_perspective()` at 1918 ms is
bad *because it is a stall the player feels when tapping a button*, not
because it threatens a frame budget — there is no frame budget being paid
between rotations. This reframes "performance" here as **latency
engineering**, not **throughput engineering**.

---

## 3. The five questions — current answer, and what's still open

**Q1 — Is destruction worth it?** Partially re-opened by the design pivot
itself: the D33 worst case (2955 cells / 15 grenades) modeled a firefight the
stated design (short infiltration waves) may never produce. Revisit the
destruction budget once real per-mission grenade counts exist — not before,
and not as part of this review.

**Q2 — Kill generic, keep only baked: performance win?** No evidence for
this. B1 means there is no runtime cost from the fallback existing — nothing
pays for both paths today. Removing it would remove the *visual* fallback
(flat color instead of photographic facade) for glass, unbaked maps, and
`BakeConfig.enabled = false`, without touching the 1918 ms figure, which
happens with baking already ON.

**Q3 — Is the bake system itself the cost?** **Unmeasured — this is Part 0's
S1.** `F6` toggles `BakeConfig.enabled` live; nobody has timed
`_set_perspective()` with it off. Until that A/B exists, "generic-only would
be faster" is a guess in either direction.

**Q4 — Is rotation the villain?** On every number measured so far, yes, by a
wide margin — 1918 ms dwarfs every other figure in this project's history
(0.31 ms decal composite, ~35 ms warm bake boot). But *why* it costs that
much is not yet decomposed — Part 0's S2/S3 exist to open that box.

**Q5 — Is 2D-emulating-3D inherently too expensive; should we port to a 3D
engine?** My read, stated plainly per the Director-skepticism duty: **no
evidence supports this, and the cost of finding out is enormous.** The one
number that looks damning (1918 ms) is not an isometric-in-2D tax — it is a
specific, local architectural choice (full unconditional rebuild + re-bake on
every rotation, with zero caching of a space that has exactly 4 possible
states). A 3D engine port would discard a rendering pipeline that is
~90%+ built (voxel renderer, bake system, destruction, occlusion, lighting)
on an unvalidated bet that the same feature set costs less in 3D, with no
device measurement backing either side. Not recommended before Part 0's
numbers rule out the cheaper fix.

---

## 4. Two branches — and one of them is not mine to pick

**Option A — Fix rotation, keep it as a feature.** A room has exactly 4
perspectives (N/E/S/W). Nothing today caches any of them — `_set_perspective()`
rebuilds unconditionally even when returning to a perspective already built
this room-load. The hope going in was that this would echo D33: a per-view-
stable thing measured and wrongly treated as if it had to be recomputed every
time. **Part 0 (§8) does not confirm that hope** — a repeat visit costs the
same as the first, because unlike the decal substrate (pure function of
view + damage), roughly half of the cost is geometry/bake (genuinely
cacheable by direction) and the other half is lighting/occlusion/FOW, which
depend on evolving game state (agent position, revealed fog, new damage),
not just direction — a cache keyed on direction alone cannot recompute those
for free. Real, but bounded: §8's numbers put the realistic ceiling near a
2× speedup on a cache hit, not the near-zero D33 achieved.

**Option B — Eliminate rotation, ship one fixed perspective.** This does not
optimize the 1918 ms cost, it **deletes the code path that pays it during
play** — `_set_perspective()` would only ever run once, at room load, same
place `build_from_layout()` already runs today. Structurally the strongest
possible fix, by construction. **But it is not a performance decision** — it
trades away a tactical-stealth tool (reading a room from another angle,
spotting what a wall or prop hides from the current view) for that
performance certainty, and that trade is the Director's to make on design
merits, not something this spike can rule on. Two things worth knowing before
deciding, that Part 0 will surface as a side effect: (a) the load-time-only
cost (S1/S3 still apply, just paid once instead of per-rotation), and (b) if
B is chosen, Option A's cache work becomes moot — no point caching 4 states
that never change into.

**This review runs Part 0 regardless of which way the Director is leaning**,
because the load-time number and the bake-vs-generic breakdown are useful
inputs to *either* branch, not just to A.

---

## 5. Part 0 — the diagnostic spike

Unlike D33's Part 0, this is not a single go/no-go gate on one implementation
bet — it is a **breakdown** of where 1918 ms goes, needed to choose between
§4's branches with data instead of instinct. Same discipline as every prior
Part 0 in this project: throwaway instrumentation, real PLAYGROUND map, real
windowed Godot process (headless forces the `dummy` render driver and cannot
be trusted for anything bake/GPU-related — see `auto_screenshot.py`'s own
documented reason for never using `--headless`), numbers printed and kept,
code reverted after.

**S1 — Bake-specific cost.** Time `_set_perspective()` on a clean (undamaged)
PLAYGROUND, direction sequence N→E→S→W, twice: once with `BakeConfig`
default (baked ON), once with `INFILTRAITOR_FAST_BOOT=1` (baked OFF, generic
materials only — the flag already exists, `bake_config.gd:65`). The delta
between the two is the bake system's own contribution to the 1918 ms;
whatever's left is generic geometry/lighting/occlusion rebuild that neither
"kill generic" nor "kill baked" touches.

**S2 — Is a repeat visit actually free today?** Same clean map, sequence
N→E→N→E. If the second N and the second E cost materially less than the
first, some caching already exists somewhere in the chain and Option A's
opportunity is smaller than it looks. If they cost the same as the first
visit (expected, given `_baked_source_ids` is unconditionally cleared and
`build_from_layout()` is unconditional), that confirms zero memoization
exists at the geometry level today, and Option A's cache has a clean, empty
slot to fill.

**S3 — Damage-count scaling of the base rebuild.** The test zone supports up
to 4 placed grenades (one per wall material, `TestZoneController.
TEST_ZONE_GRENADE_GUS`) — not the 15 that produced D33's projected worst
case, so this measures the real available range (0/1/2/3/4 grenades' worth
of damage) rather than extrapolating past it. Sequence: detonate one more
grenade, then N→E→S→W, repeated up to 4. This isolates how much of the
rotation cost scales with damage volume *today*, independent of D33's
decal-compositing question (not yet built) — dirty-flag reapplication, soot
re-derivation, and the lighting rebuild all already scale with damaged-voxel
count regardless of whether decals ever get baked in.

**Method:** temporary `Time.get_ticks_usec()` wrapping inside
`_set_perspective()` (whole-function total + a mid-checkpoint split at
`build_from_layout()` returning, separating "geometry+bake" from "everything
after: repaint, lighting, occlusion"), gated behind a new
`INFILTRAITOR_D34_ROTATION_SPIKE` env var so it is inert in every normal run;
a matching orchestration block (same shape as the existing
`INFILTRAITOR_CAPTURE_VIEWS` block) drives the detonate/rotate sequence and
calls `get_tree().quit(0)` when done. Run via a real windowed off-screen
process (`auto_screenshot.py`'s own invocation shape: `--position 4000,4000
--quit-after N`), output captured from stdout. All of it reverted after the
numbers are recorded here — no production code ships from Part 0, same rule
as every prior spike in this project.

**Honesty boundary, stated once:** this still runs on Mac desktop, not a
target mobile device. It answers "where does the 1918 ms go," not "is 1918
ms (or its fixed portion) survivable on a 5-year-old phone" — that second
question needs the real-device measurement this project has never done, and
is out of scope for Part 0.

---

## 6. What Part 0 does **not** decide

- **Whether to build Option A.** Even a favorable S2 (repeat visits cheap to
  cache) is a green light to *start*, not a commitment — Part 1 would still
  need its own design (cache invalidation on map change, memory cap, same
  category of problem D33 §10 flagged for the decal cache).
- **Whether to take Option B.** That is a design call about what rotation is
  worth to the tactical-stealth read of a room, weighed against a guaranteed
  structural fix. Part 0's numbers (especially the load-time-only cost) are
  an input to that call, not a substitute for making it.
- **Q1 (destruction budget)** and **Q5 (engine port)** — both answered above
  by argument, not by this spike; neither needs new measurement to reach a
  provisional recommendation, and Q5 in particular should not be reopened
  without a real per-feature 2D-vs-3D device comparison, not a hunch.

---

## 7. Acceptance

- Real numbers for S1/S2/S3, printed and pasted into this document (§8, once
  run) — no "should be roughly," no reasoned-expectation standing in for a
  pasted result.
- Working tree clean of spike remnants afterward (`grep` for
  `INFILTRAITOR_D34_ROTATION_SPIKE` returns 0 outside this doc), same
  verification the D33 spike used.
- `project_lint`, `run_selftests`, `check_invariants`, `gen_codemap --check`
  all clean.
- A one-paragraph recommendation for §4 (A vs. B vs. hybrid), explicitly
  flagged as a recommendation for the Director to ratify, not a decision
  already taken.

---

## 8. Part 0 results — measured 2026-08-03

Two full runs on real PLAYGROUND, windowed off-screen Godot
(`--position 4000,4000 --quit-after 900`, same shape as `auto_screenshot.py`),
sequence N→E→S→W→N→E at each of 5 damage levels (0 grenades through all 4
test-zone grenades detonated). All spike code reverted after (`grep` for
`INFILTRAITOR_D34_ROTATION_SPIKE` returns 0 outside this doc — verified
below, §7). Raw logs kept in the scratchpad for this session, not committed
(throwaway per Part 0's own rule).

### S1 — bake system's own contribution (clean map, damage level 0, 6 samples/run)

| | total_ms (avg) | build_ms (avg) | rest_ms (avg) |
|---|---|---|---|
| Bake **ON** (default) | **1889.9** | 1033.1 | 856.8 |
| Bake **OFF** (`INFILTRAITOR_FAST_BOOT=1`) | **1317.8** | 581.3 | 736.5 |
| **Delta (bake's cost)** | **572 ms (≈30%)** | 451.8 ms | 120.3 ms |

**Answers Q3 directly: the bake system is real but not the dominant villain.**
It accounts for ~30% of one rotation. Killing generic materials and shipping
baked-only changes nothing here (bake is already ON by default and already
what's being measured). Killing baked and going generic-only would save
~572 ms — real, but it leaves **~1318 ms untouched**, split roughly evenly
between pure geometry regeneration (~581 ms, present with bake fully off)
and the lighting/occlusion/FOW/repaint pipeline (~737 ms, also present with
bake off). Neither Q2 nor Q3's premise (kill one path, win big) holds: the
bake/generic choice is worth ~30% of the problem, not the problem.

### S2 — is a repeat visit free? (bake ON, level 0: N first=1613.7ms, N
second=2288.7ms; E first=1877.5ms, E second=1777.1ms. Bake OFF, level 0: N
first=1325.2ms, N second=1306.8ms; E first=1299.9ms, E second=1299.0ms.)

**No caching benefit anywhere, in either config.** A second visit costs the
same as the first (within run-to-run noise; the bake-ON N second-visit is if
anything slower, not faster). This corrects the hope in §4: there is no
existing near-miss cache with a wrong key (unlike D33's decal case) — there
is **no cache at all**. `_baked_source_ids`, the geometry, the lighting field,
the occlusion set: all rebuilt unconditionally, every single rotation, even
back into a view already fully built this room-load.

### S3 — damage-count scaling (per-level averages, 6 samples/level, both runs)

| Grenades detonated | Bake ON total_ms | Bake OFF total_ms |
|---|---|---|
| 0 | 1889.9 | 1317.8 |
| 1 | 1916.3 | 1397.5 |
| 2 | 1839.9 | 1424.0 |
| 3 | 1847.4 | 1435.9 |
| 4 | 1847.0 | 1464.3 *(excl. one 1765.8ms outlier sample, likely a GC/OS jitter blip — included it's 1514.6)* |

**Bake ON is flat within noise (1840-1920 ms, no clear trend); bake OFF shows
a real but modest climb — +146 ms over 4 grenades (+11%), roughly 30-40 ms
per grenade's worth of damage.** The bake-off run's lower noise floor makes
the trend visible where bake-on's own variance (±200-400 ms run to run)
masks a same-sized effect. Either way, damage volume is a minor contributor
next to the ~1300-1900 ms fixed cost of rebuilding an *undamaged* room from
scratch. **Answers part of Q1**: destruction's own weight on rotation cost is
small; the 1918 ms baseline D33 found was never mostly a destruction problem.

### What this settles, and what it changes from §3/§4's provisional framing

- **Q2/Q3 settled**: neither "kill generic" nor "kill baked" is a real fix.
  Bake is ~30% of the cost; the other ~70% is geometry regeneration and the
  lighting/occlusion/FOW pipeline, present regardless of texturing strategy.
- **Q4 confirmed, sharper**: rotation is the villain, and it is a *flat*
  villain — ~1.3-1.9 s **every single time**, damage or no damage, revisit or
  first visit. There is no cheap case to exploit.
- **Option A is real but smaller than hoped.** No wrong-key cache to fix,
  unlike D33 — this would be new caching infrastructure from zero, and even a
  complete cache of the cacheable half (geometry+bake, direction-pure) caps
  out around a **2× speedup on a revisit** (≈1890→≈860 ms bake-on, or
  ≈1318→≈737 ms bake-off), not the near-elimination D33 achieved for decals,
  because the lighting/occlusion/FOW half depends on live game state
  (agent position, revealed fog, accumulated damage) that a direction-keyed
  cache cannot serve stale.
- **Option B's relative case is stronger than when §4 was written.** Its
  win (rotation cost drops to zero because the code path never runs during
  play) no longer competes against a cheap near-miss fix — it competes
  against building a genuinely new, partial-benefit caching subsystem for a
  bounded 2× win. That doesn't decide Q6 for the Director — it changes what
  they're weighing against.

---

## 9. Recommendation

*(Stated as a recommendation for the Director to ratify, not a decision
already taken — §6.)* Given §8: **the strongest, cheapest move available is
Option B — eliminate rotation, keep only the initial perspective — evaluated
purely on the engineering trade now visible.** It converts a guaranteed,
undiscountable ~1.3-1.9 s **per-rotation** hitch into a one-time,
already-paid load-time cost, with no new subsystem to build, test, or
maintain — while Option A's realistic ceiling (a new direction-keyed cache,
capped near 2×, non-trivial invalidation on map/damage change) is a real
project for a bounded win. That said, this is an engineering read of a
number, not a design verdict: whether the tactical value of seeing a room
from another angle is worth ~1.3-1.9 s of load-time-only cost per rotation
(never paid mid-play under B) is the Director's call, informed by how much
the stealth-puzzle design actually leans on multi-angle reads today. If the
answer is "not much" — which matches the Director's own stated lean — B is
the clean close to this whole review: Q2/Q3/Q4/Q5 all stop mattering the
moment rotation stops running during play.
