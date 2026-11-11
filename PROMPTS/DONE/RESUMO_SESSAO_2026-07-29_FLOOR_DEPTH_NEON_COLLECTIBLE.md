# RESUMO_SESSAO — 2026-07-28/29 (OVERLAY Z, NEON FLICKER, FLOOR DEPTH, COLLECTIBLE HIGHLIGHT)

**Active master plans:** `DESTRUCTION_MASTER_PLAN.md` (D19–D21 added, D13/D20
amended), `ACTOR_MASTER_PLAN.md` (D28–D29 added, D25 amended). No wave resumed —
every item was a same-session Director request.
**VERSION at session start:** 0.9.83
**VERSION at session end:** 0.9.84
**Mode:** Solo mode.
**Screenshot session:** not toggled; every capture via one-off
`INFILTRAITOR_SCREENSHOT_ONCE=1` / direct `INFILTRAITOR_AUTO_SCREENSHOT=1` runs.

---

## Executive Summary

Four Director requests, each of which turned out to rest on a premise that had
expired or a measurement nobody had taken. The heatmap was not "behind the
floor" by design — it sat in a z slot that was correct until D17's voxel floor
landed on top of it. The floor's three layers could not be told apart because
soot had crushed all of them into the same 34/255, which no amount of per-layer
dimming could fix — measured, not argued. The collectible was not inside the
wall; it was in front of it and drawn underneath, because `z_index` here encodes
height while the prop needed depth. The one request that was exactly what it
looked like — the 1px stroke — still shipped with two corrections found by
looking at real pixels.

Two rules earned this session and worth carrying forward: **a captured frame is
not a measurement** (the flickering lamp beside the crater made four "identical"
captures differ by 3× in brightness, silently invalidating the first tuning
attempt), and **a rule's premise ages faster than the rule** (two of the four
bugs were ratified decisions whose stated preconditions had changed within days).

## Wave Table

| ID | What | Status |
|---|---|---|
| HEAT-Z-01 | HEAT overlays raised above D17's voxel floor (z 0 → 1); swept the rest and found the dev cell-number overlay buried the same way (→ z 8) | ✅ |
| NEON-FLICKER-01 | Flicker replaced by a neon state machine: long lit holds, bursts of 1–4 irregular blips, per-light seeded RNG. Same repaint cost as the square wave it replaced (1.68/s vs 1.67/s) | ✅ |
| FLOOR-DEPTH-01 | Second destructible ground plane (level −2), destructible only in the blast's own GU and at half the crater radii; generated at build, rendered only on exposure (D18 respected) | ✅ |
| FLOOR-DEPTH-01b | Floor-zone bake extended below the surface; `process_dirty_slabs()` latent bug fixed (sent every FLOOR voxel down the earth path, ignoring the zone material) | ✅ |
| FLOOR-DEPTH-02 | Depth reads as tone (`FLOOR_DEPTH_DIM`), ramp chosen by measurement; soot reverted to accumulating; concrete/concrete/earth split | ✅ |
| COLLECTIBLE-OUTLINE-01 | 1px constant-colour silhouette stroke in the existing relight shader; opt-in per material | ✅ |
| FLOAT-PROP-Z-01 | Depth-aware prop sorting via `VoxelRenderer.classify_geometry_over_rect()` | ✅ |
| DOCS-01 | D19/D20/D21 (destruction), D28/D29 + D25 amendment (actor), BAKE_SYSTEM_REFERENCE §3b reversal, QUICK_REFERENCE z-slot map | ✅ |

## Decisions (Director-ratified)

1. **HEAT overlays go to z=1, dev labels to z=8** — the tint keeps losing every
   other z=1 tie (tree order) so its relationship to non-floor overlays is
   byte-identical; the labels are sparse text meant to be READ, so they go above
   the floor-plane band instead.
2. **The deep floor plane is a real `Slab`**, not a cheaper crater-narrowing
   trick — it must be real `Voxel`s to take damage, persist through rotation and
   re-render through the dirty-flag machinery. Cost accepted after measurement:
   ~30k extra `Voxel` objects, +40–100 ms on a 3.2 s PLAYGROUND build.
3. **"GU 0,0" meant the blast's own GU (ring 0)**, not the map's literal (0,0) —
   asked before building, because the three readings led to materially different
   systems.
4. **Soot accumulates downward; the layers separate by tone.** An attempt at the
   reverse (lightening the exposed crater floor so the tone steps could read
   against a brighter base) was built, measured, shown, and rejected: "não ficou
   bom clareando pra dentro". Losing the texture to shadow at the bottom is
   accepted.
5. **Two layers of concrete over earth**, and the earth half is free — the earth
   variants are already in the material atlas. A *photographic* dirt would be
   another baked ground material at ~18 MB.
6. **Props sort by real depth**, amending D25's fixed ground-level slot; the
   principle it protected (geometry hides props, props never create occlusion) is
   unchanged.

## Evidence

- `project_lint.py`: 0 real compile errors at every checkpoint.
  `check_invariants.py` / `gen_codemap.py --check`: clean at every commit.
- Selftests green at close: `floor_integration` 10/10 (was 8/1-fail — see below),
  `neon_flicker` 6/6 (new), `blast_calculator` 16/16, `floor_zone_bake` 8/8,
  `bake` 19/19, `slab_render` 8/8, `slab_geometry` 15/15, `roof_slab` 15/15,
  `roof_bake` 8/8, `roof_integration` 5/5, `negative_storey` 12/12,
  `fixed_floor` 5/5, `earth_variant` 6/6, `voxel_light_incremental` 5/5,
  `voxel_persist` 2/2, `geometry` 29/29, `texture_resolver` 6/6.
- **Red-before-green on the reported symptom**, twice: HEAT z forced back to 0
  (`auto_2026-07-28_21-20-26.png` — heatmap visible ONLY outside the map, where
  no floor voxels exist) vs fixed (`21-20-00.png`); crater bottom brown earth
  (`20-10-34.png`) vs concrete (`21-32-29.png`), same map/camera/grenade.
- **A pre-existing red found and fixed**: `floor_integration_selftest`'s cell
  round-trip had been failing 64/192 since FLOOR-BAKE-01 put concrete on
  PLAYGROUND — confirmed pre-existing by running it against the stashed tree
  before touching it, then made zone-aware.
- **Measurements, not impressions**: baked page memory instrumented on a real
  boot (17 pages, 75.9 MB RGBA8; the single `ground_concrete` page 18.0 MB) to
  answer the mobile-viability question; depth-dim ramp chosen from four captured
  candidates with the map's flicker held off; final strata sampled at verified
  coordinates (161 / 51 / 22 of 255).
- **Rotation persistence**: detonate-then-rotate through all four views, crater
  and its tone identical, no script errors.

## Process learnings

- **The flickering lamp beside the crater invalidated the first tuning pass.**
  Four captures of "the same scene" measured 161 vs 54 on the intact floor and
  358k pixels differing. Any A/B of a lit scene in this project must hold the
  temporal lights still first — the sweep harness does it by patching the map,
  in a `finally` that restores it.
- **Two ratified rules broke because their premises aged**, not because they were
  wrong: D22-FOLLOWUP's "the prop rests at floor height" (`HOVER_HEIGHT_PX` 14 →
  60 days later) and VL-D2's "the crater bottom is the most burned surface"
  (written for one ground plane, applied to three). When amending, quote the
  original premise and say what changed.
- **Instrument before theorising.** The prop-z fix took two wrong versions,
  both of which *looked* reasonable; the instrumented run that printed
  `top_level=17` for the weapon's own open-floor cell is what exposed that walls
  are 8-voxel rows, not per-GU columns.

## Commits

`1774ca4` neon flicker + selftest · `d4c415f` HEAT/label z + capture-vision knob ·
`3b6f2d6` two ground planes, bake three levels deep · `9ae7383` depth tone (first,
lightened-inward attempt) · `b612628` tone reversed to darker-downward + concrete/
concrete/earth · `44dcec8` collectible stroke · `48a2155` depth-aware prop z ·
(this close-out: docs + VERSION).

## Next Session

- **`GrenadeProp` still uses the fixed ground-level z slot** (FLOAT-PROP-Z-01
  applied to `FloatingCollectible` only). Same symptom is reachable with a
  grenade against a wall; deliberately left, not overlooked.
- **`FLOOR_DEPTH_DIM` will be wrong for D18's decorative storeys** — a lava level
  is a light SOURCE, and this ramp would dim it into mud. Those levels need their
  own tone rule when they land.
- **Ground-material budget is the mobile ceiling**, not storey count: ~18 MB of
  atlas per baked ground material against 75.9 MB today. Mitigations unexplored
  (smaller tiling period for flat pages, VRAM compression, on-demand bake).
- **Optional collectible glow** offered and not built: a procedural radial
  `GradientTexture2D` behind the sprite, additive — no asset needed. The lens
  flare option was argued against (authored asset, doesn't rotate with the piece,
  only optical effect in the game).
- Rest of `DESTRUCTION_MASTER_PLAN` Part 4 (loud-fail on MISS, shipped
  `enabled=true` default) remains open.
