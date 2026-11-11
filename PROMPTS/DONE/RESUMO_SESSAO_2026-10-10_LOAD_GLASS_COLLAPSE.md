# Session summary — 2026-10-09/10: segment load (Q5), PB-5/PB-7, glass look, jagged rims, G-S1 collapse

Resume point for the next session. Everything below is on `main`.

## 1. Performance budget (PERFORMANCE_BUDGET_MASTER_PLAN v0.5, §0g, §0h)
- **Q5, the segment load** (Director: ~12 s acceptable): `[LOAD-SPLIT]` lines per load phase; light index / buckets / plane writes,
  prop-shadow images and the board's claim walk on the WorkerThreadPool; one occupancy walk instead of two; facades / surfaces cached
  per run. Moto SEG_HEAVY: **cold 10.4 -> 7.6 s, reload ~6.5 -> 4.65 s** (`a38a8ef5`, `99f8f4c1`).
- **Cooked segment (option 3)**: evaluated, not built; an M7.0 note to consider an offline cook of FIXED segments (hybrid mutable
  fixed segments foreseen) (`d9932bc2`).
- **PB-5 verdict**: HEAVY fits on both handsets with no profile (Moto PSS 757 MiB, Galaxy A16 741 MiB, cycle flat).
- **PB-7**: `tools/persistent/segment_budget.py` in `verify.py quick` (maps with `meta.segment: true` held to HEAVY's counts, self-test
  first); `pb3_study.py --max-pss-mib` is the handset half (`6bca93ff`).
- **PB-8 device profiles** (ultra / high / medium / low switching features): moved to M7.0 (Director).

## 2. Glass look
- **GLASS g1 intermittent pixel-gate difference: FOUND.** PB-2's two-pass pane (multiply + add `next_pass`) tied at the same depth in an
  unstable transparent sort, so a pane was blue or white per chunk per boot. Now ONE premultiplied pass, `glass_pane3d.gdshader`, the
  white look the Director chose, reflection from `ASSETS/materials/glass/glass_sheen.png` (git-ignored; regenerate with
  `tools/persistent/gen_glass_sheen.py`), cover 0.12 (`10159bc4`).
- **Edges**: pane edge faces on a darker twin material, drawn both sides in their own per-chunk instance sorted before the pane
  (`91c8c401`); top lighter, sides darker, far edge between (`fb788501`).
- **Panes stack as world objects**: the 2D board's "tint once per pixel" stencil removed; chunk sort ties broken by a 1e-4 offset per
  chunk index (`fb788501`).

## 3. Glass destruction
- **G-D54, jagged rims** (`d9d62667`): a rim voxel (in-plane neighbour was a destroyed pane voxel) is a hashed jagged prism, skewed
  through the thickness; `GLASS_RIM=0` is the A/B. The crack decal spills ~0.7 voxel past the hole edge (`crack_edge_spill`).
  Moto: threaded post-blast remesh 270 -> 310 ms.
- **G-S1 for panes** (`4103912d`; rulings G-D50..G-D54 in GLASS_MASTER_PLAN, `3f002e08`): `GlassSupport` (support walk on a store
  snapshot, WorkerThreadPool), `Room.schedule_glass_collapse()` after every blast (2.5 s) and shot (0.8 s), three waves, landings
  planned during the delay; no light repaint per wave. Moto: wave ~5-21 ms + ~25-30 ms async.

## 4. Open — next session
1. **Adjust the fall** (Director, 2026-10-10: "precisamos ajustar ainda a questão da queda") — ask what first: timing, amounts,
   the reach / height pressure, how the waves look.
2. G-D53: glass roofs and every material's roof (stone barely, plywood easily), the fabric sag.
3. The camera-shift harness anomaly seen twice on 2026-10-09 (likely input over the test window; not proven).
4. `docs/production/current_state.md` has an uncommitted change that is not this session's.

Verification at the close: `verify.py look` PASSED on `4103912d`'s tree, baseline retaken there.
