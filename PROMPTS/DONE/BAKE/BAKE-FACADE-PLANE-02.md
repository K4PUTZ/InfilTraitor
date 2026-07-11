# BAKE-FACADE-PLANE-02 — Both edge directions, TEXTURES 2.0 fixture, bake performance

**Status:** DRAFT — pending Director ratification
**Follows:** BAKE-FACADE-PLANE-01-b (commit `f7f1e6b`)
**Plane:** geometry/render grid (fine plane); plus one map file and one scene default.

---

## CONTEXT

01-b landed the isometric projection (u,v per half-face), top-face fix, run-axis
detection, and mirrored indexing. Director live verification confirms: **walls of
one edge direction now read as textured inclined slices — the method works.**
Three things remain; all three are this prompt:

1. **The other edge direction is wrong.** On the live map, walls of the second
   direction still show **repetitive per-slice banding** instead of the facade
   spreading continuously. Per Director direction: for that face direction the
   facade must be **mirrored horizontally and sheared with the opposite slope as
   a whole**, then applied across the slices — the exact counterpart of what now
   works for the first direction. Investigate where the current chain fails for
   that direction before coding: candidates are `_detect_run_axis()` /
   `_compute_column_in_run()` (column not advancing along the run for one axis →
   repeated window) and face selection (which half-face mapping and which
   sheared orientation a slice's `face` selects). The 01-b completion report
   itself flagged that the run-axis test never ran against a real two-direction
   fixture (SIGMA_01 resolved 0 combos) — this prompt's TEXTURES 2.0 provides
   that fixture; use it.

2. **Performance criterion carried — it FAILED in 01-b** (honestly reported):
   full bake ~4.8 s against the 2000 ms budget, and a "cache hit" also ~4.8 s,
   i.e. the session cache does not actually short-circuit composition. Required:
   - Implement the **pre-sheared facade approach** (allowed in 01-b, not done):
     per facade, build the sheared/scaled images once — S⁺ (first direction) and
     S⁻ (mirrored + opposite shear, item 1) — via `blit_rect` strips; per-atom
     face content then becomes an **axis-aligned crop** (the x-dependence
     cancels; see 01-b CONTEXT for the algebra). Kill the per-pixel per-atom
     facade sampling loop.
   - Fix the cache: a cache hit must not call `_bake_atom_sheet()` at all —
     hit path = fetch pages + register + place. Log `[BAKE] cache HIT/MISS`.
   - Budgets unchanged: TEXTURES full bake ≤ 2000 ms; re-entering an
     already-visited blend mode via F7 ≤ 500 ms. If CPU cannot reach the full-
     bake budget after the pre-shear rework, stop and report the measured
     breakdown (the GPU compositor remains the designed v1.1 escape hatch) —
     do not silently ship a hang.

3. **TEXTURES 2.0 — the fixture becomes the working map.** Current TEXTURES
   proved the method; Director wants it as the primary workbench now.

## MODULE

- `godot/scripts/systems/bake_compositor.gd`, `baked_tile_lookup.gd`
- `godot/scripts/geometry/voxel_renderer.gd` (face plumbing only if needed)
- `maps/TEXTURES.map.json`
- `godot/scripts/world/room.gd` + room scene (default `map_id`)
- `godot/scripts/tools/bake_fix_12_facade_2d_test.gd` (extend)

## TASK

1. **Second-direction facade mapping** (mirror + opposite shear, continuous
   along runs of BOTH grid axes), fixing the banding at its real root —
   name the root cause explicitly in the completion report.
2. **Performance rework** per CONTEXT item 2 (pre-sheared S⁺/S⁻ + crops +
   working cache + budgets).
3. **TEXTURES 2.0 map redesign:**
   - Enlarge the board (suggest ~26×26 inner; adjust to fit the layout below
     with breathing room).
   - Outer perimeter walls: **2 storeys** (reduced from current).
   - Center: **four material V-pairs** — for each material (`stone`,
     `concrete`, `metal`, `wood`): two full-facade walls, each **8 GU long ×
     4 storeys** (= one entire 1024×512 facade each), one along each grid axis
     (reading as `\\` and `//` on screen), joined at a shared corner GU so the
     pair forms a V from the default perspective.
   - The four V's sit one in front of the other (nested along the screen-depth
     diagonal) with **exactly 2 GUs of free floor** between consecutive pairs.
   - Agent start with a clear view into the open side of the V's.
   - **Make TEXTURES the boot default**: `room.gd` `@export map_id` default AND
     the value saved in the room scene (`.tscn`) — verify which one the boot
     actually reads; both must say `TEXTURES`. PLAYGROUND/SIGMA_01/TEST_BLOCKS
     remain available via `load_map()`.

## DO NOT TOUCH

- B3 alpha path; the five blend-mode side-face formulas; junction no-flip;
  generic fallback path; transform canon; existing maps other than TEXTURES.

## ACCEPTANCE

All evidence pasted literal, per Evidence & Reporting Discipline rules 1–7.

1. **Second-direction pixel identity:** ≥ 64 samples on second-direction atoms
   assert baked pixel == facade pixel via the mirrored u,v mapping (facade
   loaded independently via `load()`); 0 mismatches.
2. **Anti-banding assertion (both directions):** along one run of EACH grid
   axis on TEXTURES 2.0, consecutive placed cells resolve to strictly advancing
   facade windows (distinct sheet_col sequence, no repeated plateaus). This is
   the regression kill for the live banding.
3. **TEXTURES 2.0 boots headless as the default map** (no arguments), zero
   errors, `[BAKE-DIAG]` lines pasted; layout contains the 4 V-pairs with the
   2-GU spacing (paste the placement/extraction counts per material).
4. **Performance timings pasted:** full bake ≤ 2000 ms; F7 revisit ≤ 500 ms
   with `[BAKE] cache HIT` logged and no `_bake_atom_sheet()` call on the hit
   path (grep-provable log line or counter).
5. **Regressions:** `bake_fix_02` 3/3, `bake_fix_09` 5/5, `bake_fix_11` 7/7,
   `bake_fix_12` all-pass (updated expectations named explicitly);
   PLAYGROUND + SIGMA_01 still boot headless, bake on AND off, zero errors.
6. `python3 tools/persistent/project_lint.py` pasted, zero real compile errors.
7. Version bump; commit + push per protocol.

**Director ratification (post-Operator):** booting straight into TEXTURES 2.0,
every V shows its material's full facade spreading continuously on BOTH
directions (no banding, no postage stamps), and F6/F7 switching is fluid.
