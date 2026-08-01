# RESUMO_SESSAO — 2026-08-01 (ALPHA FACE LIGHT SYSTEM FOUNDATION: FLOOR DENT, GUARANTEED FACE SEPARATION, TWO OPEN BUGS CLOSED)

**Active master plans:** `DESTRUCTION_MASTER_PLAN.md` (D26 added, closing D25's
`_top` gap), `VOXEL_LIGHT_MASTER_PLAN.md` (FACE-READ-02 added),
`WEAPON_MASTER_PLAN.md` (the flagged flood consequence closed).
**VERSION at session start:** 0.9.85
**VERSION at session end:** 0.9.86
**Mode:** Solo mode.
**Screenshot session:** not toggled; every capture via direct
`INFILTRAITOR_AUTO_SCREENSHOT=1` runs.

---

## Executive Summary

Four Director requests, worked in order, each one landing with its own evidence
before the next started:

1. **Two bugs left open by the previous session** — the floods blind to solid
   blocks, and a selftest harness that reported PASS while printing a
   `SCRIPT ERROR`.
2. **The floor dents now** (D26), with prevalence scaling from the product of
   the destruction variables already in play — closing the `_top` carved
   variant that D25 generated, wired, and left unreachable.
3. **Soot can no longer flatten a voxel's three faces** (FACE-READ-02) — the
   principle FACE-READ-01 established, now actually guaranteed rather than
   merely proportional.

The through-line of the session is that **two of the four items were only real
because they were measured first.** The floor dent silently produced zero dents
on the map it is tested against; the face separation silently collapsed on 63%
of the real value grid. Both would have "shipped" and looked done.

---

## Shipped

| ID | What | Commit |
|---|---|---|
| **FLOOD-BLOCKS** | `flood_gu_rings()`/`flood_gu_cone()` take a trailing `blocked_cells: Dictionary = {}`, checked at every BFS step alongside `blocked_edges` — an occupied cell is never entered. All three real callers wired with `room._blocked_cells`. Closes the consequence `WEAPON_MASTER_PLAN` flagged on 2026-07-30 rather than fixed. | `76a223c` |
| **HARNESS-GAP-01** | `tools/persistent/run_selftests.py` — a runtime `SCRIPT ERROR` now fails a selftest run. GDScript cannot catch its own script errors in-process, so the arbiter sits outside the Godot process, the same reasoning `project_lint.py` already applies to parse errors. | `c5c5745` |
| **D26** | The floor dents. A crater-rim survivor, and any voxel in a band one rim-width past the crater, rolls into `DENTED` with `CarvedSide.TOP`. Prevalence = material `dent_factor` × bomb radii × distance. `ground_*` materials given table rows; `VoxelRenderer.floor_damage_material()` routes every ground material's dent to the one shared carved-TOP asset. | `6f64135` |
| **FACE-READ-02** | `face_min_sep` (1.0/255), an ABSOLUTE per-face offset alongside the existing multiplies, so the three faces stay distinct where 8-bit quantisation used to merge them. Blast and firearm soot share one mechanism (D24), so both are covered at once. | `69cf175` |
| — | `INFILTRAITOR_CAPTURE_ROTATE_AFTER` — rotates AFTER a detonation, so a capture proves damage SURVIVES rotation. The existing `INFILTRAITOR_CAPTURE_PERSPECTIVE` rotates BEFORE firing and says nothing about persistence. | `6f64135` |

---

## Two things that were only real because they were measured

**1. The floor dent produced ZERO dents on the only map it is tested against.**
The implementation was complete and correct, the selftest passed with 69 dents
on a synthetic patch, and the real detonation log showed `dented=0` across all
42 affected floor slabs. Cause: PLAYGROUND's floor is a single `ground_concrete`
zone covering all 24×16 GUs, and only `earth` had a `dent_factor` row — every
real floor voxel rolled against 0.0. Giving the `ground_*` family table rows was
not a nice-to-have; without it the feature was invisible by construction.

**2. A silent fallback was one branch away from shipping.** With the zone
materials denting, a zoned floor composes `"ground_concrete_blast_dented_top"`,
which `MATERIALS` does not hold — `_set_voxel_cell()`'s `MATERIALS.find()`
returns −1 → `source_id` 0 → the voxel repaints as **flat concrete** in the
middle of the crater rim. `render_slab()`'s own comment warns about exactly this
class for `ground_*` names, which is what made it findable. The fix routes every
ground material's dent through one shared carved asset — D25's existing
decoupled-broken-face rule, not a floor-specific shortcut — and
`slab_render_selftest.gd` now asserts it at `source_id` level on BOTH render
branches, with an explicit failure message for the concrete fallback.

**The pattern both share:** the code was right and the DATA made it inert. A
selftest on synthetic fixtures cannot catch either one, because both fixtures
would be built with the material that works.

---

## FACE-READ-02 — the numbers

The Director's principle from FACE-READ-01 ("never three identical faces") was
enforced by MULTIPLIES, whose effect shrinks with the pixel value and vanishes
into 8-bit quantisation exactly where soot lives. Scanned over the real canon
grid (`bucket_luminance` × `soot_darkening` × `FLOOR_DEPTH_DIM`, art pixel
4..255) **before** changing anything:

| | collapsed to <3 distinct face values | brightest top face still collapsing |
|---|---|---|
| before | **63.0%** | **38/255** — a clearly visible mid-tone |
| after | 4.7% | 2/255 — black on screen |

The case the Director described — ring-0 soot in the darkest bucket — rendered
literally `[4, 4, 4]`. It is now `[4, 3, 2]`.

**Why an offset and not a steeper multiply:** a multiply large enough to survive
at 4/255 reads as noise at 200/255. That is the identical failure the retired
`micro_jitter_buckets` experiment hit twice on 2026-07-31, and its recorded
lesson is what chose this shape — the first time that session's structural
finding paid for itself.

**The guarantee is bounded and stated as such:** three distinct faces wherever a
voxel renders above 2/255. Below that it is black and nothing is
distinguishable anyway. No claim is made past that line.

---

## Verification at session end

```
project_lint.py            ✅ 163 files, no real compile errors
check_invariants.py        ✅ no rule violations
gen_codemap.py --check     ✅ fresh
run_selftests.py           ✅ 19 clean, 0 failed
blast_calculator_selftest  48 PASS, 0 FAIL   (+7 this session)
slab_render_selftest       12 PASS, 0 FAIL   (+4)
voxel_face_separation      3 PASS, 0 FAIL    (new)
```

**Real captures, not descriptions:**
- `auto_2026-08-01_01-05-08.png` — crater with floor dents fading outward.
- `auto_2026-08-01_01-09-55.png` — the same damage after rotating to view E.
- `auto_2026-08-01_01-16-47.png` — FACE-READ-02 live.

**The face-separation claim was measured against a noise floor**, because the
ember and flicker tweens make two captures of the same build differ anyway: two
identical-config runs differ on 13.3% of pixels but contain **zero** pixels at
delta −1 or −2, while before→after contains **375 641 px at exactly −1 and
142 215 px at exactly −2** — the SE and SW faces, 56% of the frame. Scene
brightness is unmoved (sooted-region mean 32.7 → 32.6).

**Still not verified, and it still matters:** GPU frame-time cost of the shader
stage **on device**. Headless forces the dummy driver and never rasterises.
Carried forward from the previous session, unchanged — needs
`tools/persistent/MobileTesting.md`. FACE-READ-02 adds one subtract and one max
per fragment to a stage that already existed, so it does not change the shape of
that question.

---

## Harness note — the runner found two "failures" that were not

`run_selftests.py` reproved 2 of the 18 existing selftests on first contact.
Both were investigated rather than suppressed on sight, and both are codified
with the exact observed evidence:

- **`slice_geometry_selftest`** — in `--script` mode the script compiles once
  BEFORE autoloads register, so a bare `Registries` reference fails that first
  compile; Godot retries and the suite passes for real (`SLICE-00 SELFTEST:
  PASS (44 checagens)`, exit 0). Suppressed ONLY for the autoload whitelist
  `project_lint.py` already maintains; any other identifier stays a failure.
- **`bake_selftest`** — a segfault in `Main::cleanup` (ObjectDB teardown of
  leaked GDScriptInstances) AFTER `RESULT: 19 PASS, 0 FAIL`, with a flaky exit
  code (0 or −6 across runs). Tolerated as clean-with-warning only when the
  crash is in `Main::cleanup` AND the PASS banner made it out first.

A selftest that fails to LOAD is also caught: it exits 0 having run nothing, so
a clean verdict additionally requires the suite's own PASS banner.

---

## Open, for the next session

1. **🔖 Per-FACE soot CONTENT** — still the unspiked item, and FACE-READ-02 is
   **not** it. This session guaranteed the three faces stay DISTINCT under soot;
   it did not make soot itself directional (different soot amounts per face).
   That remains the R/G/B-channel mechanism under "OPEN — Per-FACE soot and
   light" in `VOXEL_LIGHT_MASTER_PLAN.md`, with its canon cost unchanged
   (redefines `modulate` in §3.4; alternative-id space grows ~24 → 384–1536).
   Director's standing call: spike and measure first.
2. **Crack and bullet-mark mechanisms** — the Director said these get their own
   specs, analogous to D25's carved faces. Still not started, deliberately.
3. **`bake_selftest`'s teardown segfault** — tolerated by the runner, not
   diagnosed. Leaked GDScriptInstances at exit; harmless today, but it is a real
   leak and the tolerance is a workaround with a documented trigger.
4. **`project.godot`'s `config/version` is `0.1.0-pre-alpha`** while `VERSION`
   says 0.9.86. `VersionInfo` reads the `VERSION` file, so nothing is broken —
   but the two disagree, and no session has decided which is authoritative for
   an export. Noticed here, not touched.
5. **The dent band is clipped by the flood's own GU footprint.** A dent can only
   land on a floor slab the blast actually reached, so the fading band is cut
   off at the flood boundary rather than at its own radius. Not visible at
   current radii (the band stays well inside the flooded GUs); it would show if
   crater radii grow relative to ring count.

---

## Notes for whoever resumes

- **`run_selftests.py` is the arbiter for selftests now**, the way
  `project_lint.py` is for compile errors. A bare `godot --script` run of a
  selftest can still print `SCRIPT ERROR` and exit 0 — that has not changed and
  cannot be changed from inside GDScript.
- **The floor has exactly ONE damage asset**: `earth_blast_dented_top`, shared
  by every ground material through `VoxelRenderer.floor_damage_material()`. A
  per-material `broken_face_<material>.png` in `impact_marks/` overrides the
  fracture with zero code changes — the Director's drop point, unchanged from
  D25.
- **`INFILTRAITOR_CAPTURE_ROTATE_AFTER` exists now.** Any future claim that
  damage survives rotation should use it instead of being reasoned about; that
  failure class has already bitten this project once (D23, 2026-07-31).
- `ASSETS/` is gitignored; every PNG regenerates from
  `tools/asset_generation/generate_voxel.py`.
