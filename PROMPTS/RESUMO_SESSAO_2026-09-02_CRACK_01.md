# Session 2026-09-02 — CRACK-01: the crack, in three stages

The previous session is
[`RESUMO_SESSAO_2026-09-02_GART_DELIVERY.md`](RESUMO_SESSAO_2026-09-02_GART_DELIVERY.md),
which closed G-ART and left glass blocked on two Director decisions — §8.1 (the
CRACKED tier) and §8.2 (G-D21's mechanism). **This session got both rulings and
built the crack.** `GLASS_MASTER_PLAN` v1.20 → v1.21.

| | commit |
|---|---|
| A — §8.1 resolved: the CRACKED tier is already reachable | `e2b4ed66` |
| B — the crack renders, world-space, zero atoms minted | `d3713cbe` |
| C — the crack fires on the shot path, and crossings drop out | `a24700ed` |

---

## The two rulings

**§8.1 → glass reaches CRACKED by the route it already has.** The art order's
step 3 wanted `glass.crack_factor > 0`, which drags in `decal_crack_glass_*`
through `voxel_decal_selftest` [12] — the per-voxel family G-D21 folded into the
sheet. The Director's call: glass does not go through `crack_factor` at all. It
stays `0.0`. `ShotPunchTable.damage_state_for()` **already** returns `CRACKED`
for a sub-breach glass hit (this was verified in the code, not assumed —
`shot_punch_table.gd:403-409`), and CRACK-01's event `set_damage(CRACKED)`s the
ring around a hole directly, exactly as `_maybe_shatter_pane` sets `DESTROYED`
on the flood. No selftest edit; `[12]`/`[10]`/the blast-crack tests are all
green unchanged.

**§8.2 → G-D21 amended to world-space sampling.** Not a reanchored facade atom
page (36–144 MB, measured), not `_compute_facade_key()`'s offset. A plain
texture sampled in `glass_pane.gdshader` at `(frag − impact)`, ~2 MB, **0 atoms
minted**. The 64/32 mirror-fold that §8.2 called "the number that bites" simply
never happens — it was a property of the wall key function glass does not touch.

The "everything is blocked on `crack_factor`" reading in `GLASS_MASTER_PLAN`
§5's G-D23/G-D24 mechanics turned out to be **wrong**, and is corrected in place.

---

## Stage A — the guard

Nothing to *build*. `glass_crack_selftest.gd` (grew to 27 checks across B and C)
is the guard on §8.1: it fails if a future edit re-introduces a crack DECAL
family on any axis — the factor, either wiring list, a composed `decal_` name,
or the files on disk. It also pins the fracture sheets as the CRACKED art and
`damage_state_for`'s CRACKED-below-breach / DESTROYED-at-breach / never-DENTED
ladder for glass.

## Stage B — the render

- **`VoxelRenderer`** — a per-level **R8 crack plane** (the soot-plane pattern
  verbatim: `_glass_crack_image_for` / `write_glass_crack_cell` /
  `flush_glass_crack` / `glass_crack_group_at`, `SOOT_PLANE_ORIGIN` /
  `SOOT_TEX_SIZE` reused) holding a crack GROUP id per glass cell, and a shared
  **`GLASS_CRACK_GROUP_CAP` (16)-wide RGBAF strip** — one texel per crack event:
  impact run-coord, rel-level, `axis + 2·wide`, active. RGBAF holds the coords
  raw (no bias, no range limit). This is what solves §8.2's multiplicity — each
  pane its own impact — **without a `uniform vec3[]`**, which prints a
  shader-compiler error every boot in this shader family (V-B measured it).
- **`glass_pane.gdshader`** — recovers the fragment's cell the way
  `voxel_face_shading` does (the same affine inverse; glass atoms are small so
  the provoking-vertex corner_shift is skipped), reads the plane, and for a
  non-zero group reanchors the sheet: `fuv = 0.5 + (frag − impact) /
  sheet_voxels`. `fuv` outside `[0,1]` → no crack (G-D23). G-D19's 50% is a flat
  `mix(lit, tint·frosted, 0.5)` per grouped cell — the Director's "G-D21
  simplifies G-D19" allowance.
- **`glass_crack.gd`** — the PURE planner. `plan_pane_crack()` returns the
  standing glass cells within the crack radius (`CRACK_RADIUS_TIGHT` (6,5) /
  `_WIDE` (12,9), `static var`), the run axis, the impact run-coord.
  `wide_for_blowout(blowout) = blowout ≥ 0.5` — pistol/pellet → tight, rifle →
  wide (G-D14, off the shipped arsenal exactly).

## Stage C — the event

- **`agent_shot_controller._craze_pane_around_hole`** runs wherever a glass hit
  does **not** clear the pane: an INDESTRUCTIBLE screen ("trinca mas o tiro
  para"), a lost shatter roll, and the standing edge of a partial shatter.
- **`GlassCrack.apply(renderer, plan)`** — the shared "alloc group / write plane
  / G-D24 / set_damage" sequence, so the shot path and the demo have one
  definition. Returns the crazed/crossed counts, the touched voxels (the caller
  folds them into the shot's cell dicts → VL-PERSIST records the CRACKED state)
  and the fallen list.
- **G-D24** — `apply()` checks the plane before stamping: a cell already in a
  *different* group is `set_damage(DESTROYED)` and handed to `GlassFall`.
- **`INFILTRAITOR_CAPTURE_ACTION=glass_crack_demo`** — the on-map proof, without
  the `agent_shot` pipeline's timing. Finds the biggest pane, stamps a crack
  through the real `GlassCrack` path, saves a before/after pair. ⚠️ Needs
  `INFILTRAITOR_AUTO_SCREENSHOT=1` like every capture action (this cost two
  wasted boots to rediscover — the dispatch is gated on it).

### The render bug Stage C's capture surfaced

The first captures read as a **blocky checker**, not a web. Cause: `frag_run`
was the *floored* cell coord, so the fracture sheet was sampled once per voxel
and each voxel filled flat. Fixed: sample per FRAGMENT — the continuous
recovered grid coord, plus a sub-voxel vertical fraction from atom-local Y (the
sheet's row axis is level, which is layer-quantised, so the fraction buys
sub-level detail). Landed in commit C.

---

## Evidence

**Real `agent_shot` path** — pistol on the GLASS map, through the two-pane row:

    [GLASS-CRACK] pane=PANE_SLICE_16_10_SW group=1 width=tight crazed=129 crossed=0
    [GLASS-CRACK] pane=PANE_SLICE_15_7_SW  group=2 width=tight crazed=129 crossed=0
    [AGENT-SHOT-TIER] glass:s1  cracked=258 dented=0 destroyed=2  (resist 0.40, breach 0.30)

The round crosses both panes (G-D5 / G-D17), crazes both, makes its holes, and
continues to the concrete (`concrete:s1 cracked=1`). CRACK-01 fires from the
lost-roll hook on the real path, not a synthetic one.

**Demo:** tight crazes 143 voxels, wide 475 (G-D14's two hole sizes). A second
overlapping crack DESTROYS 33 voxels at the crossing (G-D24).

Captures (hand-named, rotation-proof): `glass_crack_demo_{tight,wide,gd24}_{before,after}.png`,
`shot_crack_realshot_3_damage.png` — the last one shows both panes crazed with a
radial web around each bullet hole, the round through to the concrete behind.

---

## Two things left open on purpose

1. **The crack RENDER does not survive a perspective flip.** The plane and the
   groups strip are on the `VoxelRenderer`, which a flip rebuilds; the CRACKED
   voxel STATE survives (VL-PERSIST records it) but the web vanishes. Rotation
   is suspended, so this is a follow-up — a re-stamp in `_reapply_base_damage()`
   from a base-coord crack registry.
2. **The LOOK is a Director calibration pass.** `glass_crack_see_through` (0.5),
   `glass_crack_ink` (0.85), the radii, and the voxel-step aliasing on the crack
   lines are all knobs; the fracture sheets regenerate from `gen_fracture_sheet.py`.

---

## State at close

| | |
|---|---|
| `GLASS_MASTER_PLAN` | **v1.21.** G1, G2, G7, G-MAP, G-D9, G3, G-VARIANT, G-ART, **CRACK-01** built |
| Unbuilt in glass | **G6** (shards on screen, G-D16b) · **G-D25** (big shards) · `plastic` · skylights (G-D16c/d) · glass cube · G-D8's last third |
| Verification | `project_lint` PASS (231) · `check_invariants` OK · CODEMAP fresh · `run_selftests` **50 clean, 0 failed** · `glass_crack_selftest` 27 checks |
| Open for the Director | the crack LOOK calibration · whether the flip-survival follow-up waits for rotation to return |
