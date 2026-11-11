# Session 2026-09-10 — the render-order track: a plan rejected, rebuilt, and reopened by the Director's own question

Previous session:
[`RESUMO_SESSAO_2026-09-10_GLASS_RAMP_AND_THE_XRAY_PLAN.md`](RESUMO_SESSAO_2026-09-10_GLASS_RAMP_AND_THE_XRAY_PLAN.md),
whose §3 designed `GLASS` §19 + `OCCLUSION` §7. **This session rejected that design,
wrote a new plan, measured its way through three architectures, and ended with the
Director's own question reopening the best one.** Ten commits.

| | commit |
|---|---|
| Reject `GLASS` §19 + `OCCLUSION` §7; write `RENDER_ORDER_MASTER_PLAN` v1.0 | `2b289b7f` |
| Task 1 spike: Q1 YES, Q3 NO — the depth fix works, the container must move | `4b419084` |
| Q2 fails Y-sort, Q6 replaces it — the split-layer board | `95601822` |
| Price the container: 24–48 rect backbuffers are free, the curve bends at ~50 | `50c6a91e` |
| T2-1 — the depth board, behind `INFILTRAITOR_DEPTH_BOARD=1` | `3f979567` |
| T2-2 — the depth board broke wall occlusion; mirrored the erase | `2a94f0d8` |
| Park the GLASS guards; the sawtooth IS cross-level bleed (lift gated) | `5aaf0bed` |
| Option A's sprite clip: the mechanism is free, the look is unproven | `27375e0f` |
| `RENDER_ORDER` map — this track's own fixture | `db71bb74` |
| Render the clip's decision — and retract my own over-removal call | `8f2cf586` |

---

## 1. ⛔ RESUME POINT — WHAT THE NEXT SESSION DOES

**The Director's words, and they are the whole brief:**
*"Preciso ver as opções finais renderizadas pra poder decidir."*

He is not waiting on analysis. Everything analysable has been measured. He is
waiting on **one capture set, on ONE view, of the finished candidates**, judged
against four criteria he stated himself:

> **sem serrilhado · sem falhas nas bordas dos vidros · sem paredes de outra cor ·
> sem bugs visuais**

### What has to be built before that capture can exist

| | option | state | what it still needs |
|---|---|---|---|
| **A** | glass as an ordinary per-cell tile in the opaque layer + the crack sprite CLIPPED | **half built.** The clip is done and proven (`INFILTRAITOR_GLASS_CLIP=1`) | the other half: move the pane's cells into `_layers[level]`, unified shader with an `is_glass` branch, drop the `BackBufferCopy`. ⚠️ This is where `G-D1`'s coloured MULTIPLY is lost — one layer has one blend mode — and that loss is one of the two things he must judge |
| **B** | the front overlay | **built** (`INFILTRAITOR_DEPTH_BOARD=1`, + `INFILTRAITOR_DEPTH_FRONT_LIFT=1`) | nothing, to be *shown*. To be shipped it owes invalidation on destruction and T2-3's re-homing |

**So: build Option A's missing half, then capture A vs B vs today on `RENDER_ORDER`,
one view, and hand him the set.** Do not open a new investigation on the way.

⚠️ **Do not re-derive the options from scratch.** `RENDER_ORDER_MASTER_PLAN` §10b
holds the macro-system and the four possibilities; §10b.3 is the comparison table.

---

## 2. What was REJECTED, and why it matters

`GLASS` §19 + `OCCLUSION` §7, designed the day before, were rejected after a code
audit. Four findings (`F1`–`F5` in the plan), three of them mechanism rather than
calibration:

- **Y-sorting has never been enabled anywhere in this project** — §19 read as if it
  already was. `y_sort_origin` is set in three places and does nothing alone.
- **A `BackBufferCopy` cannot capture the layer it precedes** — merging glass into
  the opaque layer would have traded the front-wall bug for a back-wall bug.
- **One snapshot per level breaks `G-D2` inside a single pane** (atom 36 px vs a
  20 px level step ⇒ 23 double-tinted seams on a 3-storey pane).
- **`OCCLUSION` §7 was a false dependency** — §19 needed a RULING, already given,
  not code. §7 is now decoupled and deferred to the vision modes, with its mask
  flagged for re-specification in WORLD space.

---

## 3. The measurements that will not need repeating

| | |
|---|---|
| **Y-sort works** | Godot 4.6.1 merges two sibling Y-sorted `TileMapLayer`s at the same z into one depth order |
| **Y-sort costs too much** | idle board, M1: GLASS 8 307 → 28 573 draw calls (+244%); PLAYGROUND 4 222 → 25 802 (+511%), 16.7 → 22.9 ms/frame **with nothing happening**. Scoped to glass levels it still doubles them — `y_sort_enabled` is a property of a LAYER, not a region |
| **A `BackBufferCopy` is hoisted out of the ordering under Y-sort** | the glass read the bare background everywhere |
| **The container's price** | 1 copy 6.3 ms · 24 → 6.4 · 48 → 6.4 · 192 → 12.4 · 480 → 28.7 · 960 → 54.5. Flat to ~50, then ~0.05 ms each. ⚠️ M1 at 1280×720, not a phone |
| **A pane's atoms barely overlap** | 16 texels of 336 — the container buys almost nothing WITHIN a pane |
| **Q8 — the finding that reorganised everything** | **a `TileMapLayer`'s own internal draw order IS isometric depth order.** Near opaque covers far translucent AND near translucent tints far opaque, one layer, no Y-sort |

---

## 4. The Director's question, and what it changed

*"por que o vidro não pode ser um objeto do cenário comum, com transparência, no
depth certo, que é renderizado na vez dele?"*

It rested on a premise nobody had tested, and **the premise was false** (Q8). The
macro-system that falls out is now `RENDER_ORDER_MASTER_PLAN` §10b:

**Glass is SIX pieces in TWO granularities.** Per-CELL (pane voxels, rim shards,
floor pile) sorts itself for free. A **per-PANE quad** — the CRACK-02 web, the B-2
craze — has ONE place in the draw order against many depths. *That*, not the engine,
is what the composite and the flat top-z exist for.

⚠️ **A correction to the recorded history, because it changes what a change costs:**
the container did NOT fix the decals. CRACK-01 was rejected 3× because the crack was
drawn INSIDE the voxel and inherited its `dim`/`cover`/seams — fixed by lifting it to
a sprite. `G-D2`'s `BackBufferCopy` fixed overlapping FACES double-tinting.
Independent. **Dropping the container does not re-open CRACK-01.**

---

## 5. ⚠️ FINDINGS worth carrying

### 5.1 Diagnose a render by drawing the DECISION, never by reading the picture

**Four wrong diagnoses in one session, all the same shape**, and each collapsed in
minutes once the code's decision was painted instead of inferred:

1. the depth board's sawtooth — two wrong causes before the third
2. **a `z + 1` fix announced as "hypothesis confirmed" that measured 0 pixels** —
   the comparison had been between two BUILDS, not two configurations. Retracted.
3. the clip "over-removing with no identifiable occluder" — it was drawing the
   pillar's shadow volume, correctly. Retracted.
4. a diagnostic that drew NOTHING while its own counter reported 925 hits

Instruments built because of it: `INFILTRAITOR_DEPTH_DIAG=tint|hide|dump`,
`INFILTRAITOR_GLASS_CLIP=diag`. ⚠️ **A diagnostic that borrows a shader inherits its
opinions** — `glass_pane.gdshader` writes `COLOR` outright, so `modulate` on a glass
layer tints nothing. ⚠️ **Say where the instrument distorts**: the clip diagnostic
draws at top z, so hidden cells show even where a wall covers them.

### 5.2 A moving actor is noise in every pixel diff

The Director had the guards parked (*"estão só atrapalhando as medições"*) and he was
right in a way that was already costing: a patrol moves between two boots, and that
is exactly how the `z + 1` reading got past me. **`RENDER_ORDER` has no guards by
construction**; GLASS's are parked with their routes recorded in its own meta.

### 5.3 A fixture that carries three jobs contaminates all three

GLASS is the physics map. Adding render geometry to it **split its main pane** (the
crack demo's lattice went 48 × 24 → 32 × 24). Reverted, and the map got its own
fixture instead.

### 5.4 The projection makes the occluder live at a different LEVEL

`screen_y = (x + y) * 8 - level * 20`. A wall that is NEARER draws **lower** unless
it is also **higher**: covering a pane cell needs `ΔL ≈ 0.4 · Δd`. On GLASS the wall
in front of the big pane is 9 depth steps nearer, which puts the cell that actually
covers it ~4 levels up. **A same-level search finds nothing, ever** — this killed one
version of the clip and explains the pillar-height rule in the new map.

### 5.5 The tilemap is STATE, not a picture

`_layers[level]` is read by 28 internal sites and `INFILTRAITOR_CELL_PROBE` answers
"is there a voxel here" from it. That is why T2-1 redraws near cells in an overlay
instead of migrating them — Q6 (true split) and Q7 (overlay) return identical pixels,
and the overlay changes no semantics.

---

## 6. Doc + instrument inventory

| | |
|---|---|
| [`RENDER_ORDER_MASTER_PLAN`](PLANNING/RENDER_ORDER_MASTER_PLAN.md) | **NEW, the live record.** §6.1 Task 1 results · §6.4 the container's price · §7.1 T2-1 · §7.2 the occlusion defect · §7.3 the sawtooth · §10b THE MACRO-SYSTEM + the four options · §10b.4–7 the clip |
| `GLASS_MASTER_PLAN` | v1.50 — §19 kept as a **do-not-build post-mortem**; the depth task left this plan |
| `OCCLUSION_MASTER_PLAN` | §7 decoupled + deferred; its screen-space mask flagged as a defect |
| `maps/RENDER_ORDER.map.json` | **NEW fixture**, 16 × 12, no guards. Four cases; the occluder pillar is TALL by the §5.4 arithmetic |
| `maps/GLASS.map.json` | guards parked, routes in its meta |
| gates, all default OFF | `INFILTRAITOR_DEPTH_BOARD` · `DEPTH_DIAG=tint\|hide\|dump` · `DEPTH_FRONT_LIFT` · `GLASS_CLIP=1\|diag` · `YSORT=1\|2` · `GLASS_BB` · `NO_VSYNC` |
| `render_order_ysort_spike.gd` | Q1–Q9, each with its control |
| captures | `depthboard_{before,after}_{N,E,S,W}` · `occtest_*` · `sawtooth_lift_{W,N}` · `renderorder_clip_{where,zoom,decision}` |

**Every commit:** 52 selftests clean, `project_lint.py` clean, `check_invariants.py`
clean, CODEMAP fresh.
