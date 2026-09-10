# Session 2026-09-10 — the glass ramp calibrated, rim shards, and a plan for the same board

Previous session:
[`RESUMO_SESSAO_2026-09-09_THE_WORKSPACE_SPLIT.md`](RESUMO_SESSAO_2026-09-09_THE_WORKSPACE_SPLIT.md),
whose §1 named the one glass debt still open: **the G-D48 ramp values were
placeholders awaiting on-screen calibration.** This session is that calibration —
and it kept going: the calibration exposed two more things the Director wanted
(a jagged torn edge; the glass z-index), and the second turned into a full
planning pass for a renderer rework.

Four commits. `GLASS_MASTER_PLAN` v1.47 → **v1.49**; `OCCLUSION_MASTER_PLAN` gained
**§7** (the X-ray silhouette).

| | commit |
|---|---|
| G-D48 ramp calibrated — `SHOCKWAVE_REGION_MAX` 50 → 20, a big pane is no longer all-or-nothing | `e5d78790` |
| the cook's partial-break edge is jittered — a Chebyshev ball is a square | `ce6351b6` |
| CRACK-06 — rim shards on the torn glass edge, ×2 the frame remnant rate | `d5571de2` |
| the glass depth-merge + the X-ray silhouette, designed into the master plans | `cb0dbb7d` |

---

## 1. ⛔ RESUME POINT — WHAT IS NOT DONE

**Nothing is owed on glass PHYSICS.** The ramp is calibrated, the edge is jagged,
the Director signed off (*"a rampa me parece tudo ok"* · *"Vamos deixar assim por
enquanto"*).

**Owed, and planned, not built** — the Director wants the design reviewed before
any code:

- **`OCCLUSION_MASTER_PLAN` §7 — the X-ray silhouette (Part A).** Un-parks `O7`.
  A second `AgentSprite` "phantom" (shared textures, no RAM) at top-z, masked to
  the occluded portion via the occlusion *set*'s screen rects, with a new
  `agent_xray.gdshader` (tint + stripes). Guards get it gated on a vision mode;
  agent's is always-on. **Additive** — OCC-21's wall-erase and OCC-27's wireframe
  are untouched. Decisions `X1`–`X5`. §7.5 records the one open look-call
  (phantom + erased-wall on the agent may read redundant).
- **`GLASS_MASTER_PLAN` §19 — the glass merge (Part B).** Glass tiles onto the
  per-level voxel `TileMapLayer`s so y-sort resolves glass-vs-wall depth. Unified
  shader (`is_glass` custom-data branch), **one `BackBufferCopy` per glass level —
  the perf unknown, spike-gated**. `G-D18` untouched; `G-D18b` relaxed (its
  register row updated). Fallback if the spike fails: per-level glass layers at
  correct z (fixes cross-level, leaves same-level-adjacent-GU as "tinted not
  hidden").
- **Build order:** master-plan prose review → Part A → Part B spike → Part B.
- Local plan file: `/Users/mateus/.claude/plans/sorted-scribbling-hanrahan.md`.

---

## 2. What was BUILT

### 2.1 G-D48 ramp calibrated (`e5d78790`)

Director wanted damage decreasing per slice / storey / distance, and — the key —
a large pane that is never binary. The lever was **`SHOCKWAVE_REGION_MAX` 50 → 20**
(pane-lattice voxels): the Chebyshev destruction disc no longer auto-covers a
maximum panel, so a big pane at ring 2 goes **861 destroyed / 291 CRACKED** instead
of 1152 / 0. `SHOCKWAVE_REGION_MIN` 6 → 5. `GLASS_SHOCKWAVE_FALLOFF` eased at the
outer rings `[1,1,1, .90,.60,.35] → [1,1,1, .85,.55,.30]`. `GLASS_CRAZE_FALLOFF`
unchanged. `glass_shatter_selftest` [20] and [21]'s whole-break probe moved to a
normal-window fixture (a max pane at ring 0 is a partial break now, which
legitimately claims a craze the RoomStub does not model).

### 2.2 Edge jitter (`ce6351b6`)

The surviving glass had **dead-straight edges** — a Chebyshev ball is a square.
Offered the choice of jittering the flood (motor) vs. building S-6's hashed rim
mask (render); Director chose the flood. `SHOCKWAVE_EDGE_JITTER` (default 2)
perturbs the BFS boundary per 2×2 lattice bucket, range `[-j, +1]` (inward-biased
so the hole does not inflate), FNV-1a on the shatter salt (survives rotation /
F2), capped at `radius/3`, **cook path only**. Selftest [24].

### 2.3 CRACK-06 — rim shards (`d5571de2`)

The jitter alone still read as *"blocado, retangular"* and the `star_*` opening
was recognisable. Ruling: the **same `GlassShardShapes` shards that survive on
frames, but clinging to the pane's own torn glass edge**, at **×2** the frame
rate. A flood voxel held only by surviving glass (no batten) is spared as a shard
at `SHATTER_RIM_KEEP_SCALE` (2.0) × the frame keep rate, capped 0.85, floor 6.
Frame keep bumped `.10/.40 → .13/.50`. Its own path end to end
(`glass_rim_shards` on the Delta, `Room.claim_glass_rim_shards`, `_base_rim_shards`
as a 5th `SaveState` section, `GlassShatter.rim_shard_anchor_mask`) — **separate
from G4-3 so a frame remnant that loses its frame still ORPHANS (G-D45)**. Cook
path only. `16_10` from (13,13): 138 shard cells on the board, up from 7. Selftest
[25]. `star_*` opening NOT removed — Director will judge whether it still reads
once the rim shards are on screen.

---

## 3. What was PLANNED (`cb0dbb7d`, docs only)

The ramp calibration also surfaced the **glass z-index**: a back pane composites
over a wall in front of it (wood pillar, concrete wall, floor — `zidx_bug.png`,
GLASS views S/E, no blast). Confirmed pre-existing: `G-D18b` lifts the whole glass
composite to a **flat `z_index` above every opaque layer**. `OCCLUSION` `O5`
already names it — *"depth is NOT z_index"*.

Director's direction: **the robust fix — glass and walls on one depth-sorted
board** — plus his own idea, a **two-instance X-ray silhouette** for the agent
(in front of the glass *"em último caso"*) and guards (necessary for the coming
X-ray / heat vision modes). Keep the wall-occlusion mechanism; just add the X-ray.
Plan first, build later.

Written into `OCCLUSION_MASTER_PLAN` §7 and `GLASS_MASTER_PLAN` §19 (see §1).
`docs/README.md` and `technical_debt.md` updated to match.

---

## 4. ⚠️ FINDINGS worth carrying

### 4.1 A calibration pass finds the NEXT complaint, not just its own

*"Vamos seguir com a rampa do vidro"* produced the ramp, then the jagged edge,
then CRACK-06, then the z-index, then a two-part renderer plan. Each was the
Director looking at the result of the last one. The session's shape is a ladder,
not a task — budget for it when a "calibrate X" prompt lands.

### 4.2 The demo camera does not frame the storefront pane

`glass_blast_demo`'s camera (focus `pane_gu`, zoom 0.75, hardcoded) never framed
`PANE_SLICE_16_10_SW` — the panes near the agent dominated every capture. Fought it
three times. The `[GLASS-RING-DIAG]` / `[GLASS-SHATTER-BLAST]` console lines are
the precise readout; the picture is supporting only. For a glass visual
calibration, boot GLASS and eyeball it in-editor.

### 4.3 A separate anchor class needs a separate store, or it re-anchors

CRACK-06's first cut extended `remnant_anchor_mask` to see surviving glass. That
broke `glass_shatter_selftest` [23] — a frame remnant whose jamb is destroyed
re-anchored to a neighbouring spared voxel instead of orphaning (G-D45). Fixed by
giving rim shards their own `rim_shard_anchor_mask`, `glass_rim_shards` list,
`_base_rim_shards` store and claim path. The render atom
(`apply_glass_remnant_at`) is shared — it is anchor-agnostic — but the *policy*
is not.

### 4.4 `z_index` is per-STOREY, and no z scheme fixes cross-layer depth

Two sibling `CanvasItem`s at the same `z_index` resolve by tree order, never by
screen Y. So "glass layer at the same z as the wall layer" still draws all glass
after all walls. The only real fix for glass-vs-wall-at-the-same-storey is **one
shared y-sorted layer** — which is why §19 is a `voxel_renderer` rework, not a
z-index tweak.

---

## 5. Doc + instrument inventory

| | |
|---|---|
| `GLASS_MASTER_PLAN` | **v1.49** — G-D48 calibrated + CRACK-06 in the header, `SHOCKWAVE_EDGE_JITTER` / `SHATTER_RIM_*` in §5, `G-D18b` register row relaxed, **new §19 THE GLASS MERGE**, §10.1 row-audit updated |
| `OCCLUSION_MASTER_PLAN` | **new §7 THE X-RAY SILHOUETTE** (un-parks O7, decisions X1–X5); status header, §1 row (a), §5 Part 3b updated; old §7/§8 → §8/§9 |
| `glass_shatter.gd` | `SHOCKWAVE_EDGE_JITTER`, `shockwave_edge_jitter()`, `SHATTER_RIM_KEEP_SCALE/CAP`, `SHATTER_RIM_MIN_COUNT`, `pane_glass_keys()`, `rim_shard_anchor_mask()`, `_surviving_glass_anchor_mask()` |
| `glass_shatter_selftest` | [24] the jitter (wobble / flat control / determinism), [25] CRACK-06 (anchor, no-overlap, ×2 factor, bullet-path-clean) |
| `save_state.gd` | `glass_rim_shards` — 5th section, no version bump |
| `INFILTRAITOR_GLASS_RING_DIAG=1` | the per-pane ring / p / crazed_frac / outcome readout — the calibration instrument |
| `zidx_bug.png` | (scratch) the glass-over-front-wall repro, GLASS views S/E |

**Every commit:** 52 selftests clean, `project_lint.py` clean, `check_invariants.py`
clean, CODEMAP fresh.
