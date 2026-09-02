# Session 2026-09-02 — CRACK-01: the crack, in five stages, and its renderer ruled out

⚠️ **PART 2 IS BELOW AND IT SUPERSEDES THIS ONE'S CLOSING STATE.** Part 1 records
stages A–C as they were built. The Director then rejected the LOOK three times,
each rejection one level deeper than the last, and the third took the renderer
itself. Part 2 has D, E, the full decision list and the real state at close.
`GLASS_MASTER_PLAN` v1.20 → **v1.22**.

The previous session is
[`RESUMO_SESSAO_2026-09-02_GART_DELIVERY.md`](RESUMO_SESSAO_2026-09-02_GART_DELIVERY.md),
which closed G-ART and left glass blocked on two Director decisions — §8.1 (the
CRACKED tier) and §8.2 (G-D21's mechanism). **This session got both rulings and
built the crack.**

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

---

# Part 2 — D, E, and the renderer being ruled out

Stages A–C above shipped a working crack. The Director then rejected its LOOK
three times, and **each rejection landed one level deeper than the last.** That
progression is the useful part of this session, more than the code.

| | commit | rejected | root cause |
|---|---|---|---|
| **D** | `4f5ca09d` | a block of another material in the glass; *"as linhas não se encontram e estão todas embaralhadas"*; too big for a pistol | two causes: a FLAT frost whose silhouette is the RADIUS, and the GROUND-PLANE inverse used on a WALL face |
| **E** | `532127f0` | the opacity itself | **G-D19's premise** — any per-voxel change to transparency frames that voxel |
| — | *(planned)* | *"ainda dá pra ver muita diferença entre voxels"* | **the voxel shader drawing it at all** → CRACK-02, §13 |

## D — a wall face is not the ground plane

The sheet UV was built on `voxel_face_shading`'s inverse basis, which answers
*"which GROUND cell is this screen point"*. A pane is a vertical face, where the
vertical screen axis is LEVEL: `c.x = P.x/32 + P.y/16`, so one level down shifts
the sheet column by **exactly 1.25 voxels**. The web sheared and read as
disconnected tiles.

That basis is legitimate where `voxel_face_shading` uses it — quantised per QUAD,
one value per voxel, the shear never surfaces. **It breaks the moment anything
wants a continuous per-fragment coordinate on a face.** Replaced with the face's
own inverse (`run = sx·d.x/16`, `level = (run·8 − d.y)/20`) against the impact's
canvas position.

⚠️ **Every numeric gate was green while this shipped** — 27 selftest checks,
lint, invariants, a real-map run printing correct voxel counts. The counts were
right; only the picture was wrong. `glass_crack_selftest` **[10]** now
round-trips 13×11 offsets at 0.00000 error AND keeps the ground-plane inverse as
a **control that must be wrong** (6.25 voxels worst, 1.25 per level) — a test
that recovered everything trivially could not pass it.

Also fixed in D: the flat frost became density-driven, and
`glass_sheet_span_tight/_wide` became the compactness dial.

## E — G-D19 retracted by its own author

The Director corrected his own ruling: *"Eu estava errado […] isso automaticamente
cria uma 'moldura' porque os voxels ao lado estarão com 100% da opacidade
planejada."*

D's density-driven version was a better silhouette on a premise that had to go.
**The rule that replaced it (G-D26) generalises well past glass: any per-voxel
change to a property the eye reads CONTINUOUSLY across a surface frames that
voxel, because the untouched neighbour draws the cell boundary for you.** Such an
effect must be ADDITIVE — it adds its own light and leaves the surface's property
alone. `lit + crack_colour · crack · dim`, the same pure ADD G1's sheen already
used. Deleted rather than added: `glass_crack_frost` and the frosted-body mix.

Pinned so it cannot return renamed: the selftest bans any crack uniform that
modulates (`frost` / `see_through` / `opacity`) and asserts the source still
reads `lit + glass_crack_add_color`.

## And then the premise under THAT went too

Additive was still not *"idênticos aos outros"*, because a crack drawn by the
voxel shader inherits `dim` (1.0 / 0.78 / 0.60 by face plane), the `cover` alpha
the whole fragment is blended at, and the quad seams. The Director's proposal —
**a sprite over the pane** — is the only thing that reaches identical, and it
also pays for rotation survival and unlimited stacking. Ratified as **G-D27**,
planned as **CRACK-02 in §13**, unbuilt.

## Decisions this session, all in the register

| | |
|---|---|
| §8.1 | glass reaches CRACKED without `crack_factor` |
| §8.2 | G-D21 → world-space sampling |
| **G-D26** | the crack is additive light; **retracts G-D19** |
| **G-D27** | the crack is a SPRITE, not the voxel shader; replaces G-D21's mechanism |
| **G-D28** | four decal classes — and `armored` has an OPAQUE crushed core, not a void |
| **G-D29** | `blast` = 3 patterns × H/V flip, chosen by the B4 FNV-1a |
| **G-D30** | a destroyed voxel cuts the sprite via an occupancy plane; **the cut VALUE is still open**, to be settled by capture |

## State at close

| | |
|---|---|
| `GLASS_MASTER_PLAN` | **v1.22.** CRACK-01 built (A–E); CRACK-02 planned (§13), unbuilt |
| Verification | `project_lint` PASS · `check_invariants` OK · CODEMAP fresh · `run_selftests` **50 clean, 0 failed** · `glass_crack_selftest` **32 checks** |
| Captures | `shot_crack_add_3_damage.png` (additive, no frame) · `shot_crack_v2_3_damage.png` (basis fixed) · `glass_crack_demo_{tight,wide,gd24}_*` |
| Next session | **CRACK-02 S-1** — and read §13.3 first: the resolver + gate contract must move in the same commit, or the new art drops with no error |
| Open for the Director | G-D30's cut value (needs S-2's capture) · the `blast`/`armored` art (S-4) · `glass_crack_add` if the wide bore's bloom reads too hot |

## The transferable lessons

1. **A wall face is not the ground plane** — and the same basis can be correct
   quantised and wrong continuous. Memory: `wall-face-is-not-the-ground-plane`.
2. **Any per-voxel modulation of a continuously-read surface property makes a
   moldura.** Effects over such surfaces are additive.
3. **Three green gates and a correct count are not a correct picture.** Every
   defect this session was invisible to every numeric check that existed, and
   visible in the first frame the Director looked at. The counts were never
   wrong.
4. **A rejection can be about the premise, not the tuning** — twice in one
   session, one level deeper each time. When the second fix in a row gets
   rejected for a related reason, stop tuning and question the layer below.
