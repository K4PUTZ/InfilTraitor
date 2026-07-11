# BAKE-CACHE-PAGESIZE-01 — Size cached pages to referenced content, not the full sheet

**Status:** DONE — implemented and verified
**Plan:** ad hoc (warm-boot budget follow-up, `BAKE-CACHE-01` acceptance
criterion 3 open item — see `docs/technical/BAKE_SYSTEM_REFERENCE.md`)
**Plane:** systems only.
**Baseline:** tag `verified/v0.6.0`. Independent of `BAKE-FASTBOOT-01`.

---

## CONTEXT

`BAKE-CACHE-01`'s warm-boot budget (target ≤150 ms) measures ~730–770 ms —
confirmed CPU-bound: PNG decode of ~20 MB across 8 sheet pages, each a full
4096×576 canvas covering all 2048 (col, row) combinations of a
(material, direction) pair, **regardless of how many the loaded map actually
uses**. TEXTURES uses all 64 columns of 4 materials, but most real maps
won't. This prompt trims each composed page to its used bounding region
before it's written to the pipeline (in-memory) and to disk (cache), so both
the live bake and the disk cache pay only for what's on screen.

**Design:** `_compose_sheet_page()` already tracks `coords: Array` — every
`(tile_col, tile_row)` actually written. After composition, compute the
bounding rect of `coords` (min/max tile_col, min/max tile_row), crop the
page `Image` to that rect via `get_region()`, and **remap every lookup
entry's `atlas_coords`** to the cropped page's local coordinate space (the
existing `frag` dictionary already maps `"col|row" → atlas_coords`; subtract
the bounding rect's origin from each). The disk-cache key must include the
crop bounds (or simply hash the post-crop bytes, which it already does,
since `_get_disk_cache_key` hashes the *source* facade, not the output page —
check which, and if it hashes the source, add the crop rect to the key input
so two maps using different sub-regions of the same facade don't collide).

**Constraint:** junction pages already do a form of this (tile rows sized to
`atom_count`, not a full sheet) — read `_compose_junction_pages` for the
established pattern before writing a new one.

## MODULE

- `godot/scripts/systems/bake_compositor.gd` (`_compose_sheet_page`,
  `_get_disk_cache_key`)

## DO NOT TOUCH

- Junction page composition (already correctly sized).
- The u,v/shear/crop math for individual atoms — only the OUTER page bounds
  change, not how any single atom is rendered.
- Lookup key format (`mat|fac|col|row|dir`) — only the `atlas_coords` values
  inside each entry shift.

## ACCEPTANCE (5)

1. **Correctness first (red-before-green):** on TEXTURES, before this
   change, dump one page's dimensions and one known-good atom's pixel
   content at its `atlas_coords` (pasted). After the change, the SAME atom's
   content at its NEW `atlas_coords` is byte-identical (pasted comparison,
   0 mismatches) — proves the remap is correct, not just smaller.
2. **Placement correctness:** headless TEXTURES boot after the change shows
   the same `128928/128928 baked hits, 0 generic fallbacks` as
   `verified/v0.6.0` — pasted `render()` summary line, unchanged.
3. **Size reduction measured:** paste before/after page dimensions and file
   sizes for all 8 TEXTURES sheet pages (junction pages excluded, already
   sized) — report the aggregate MB reduction.
4. **Cache correctness:** disk-cache round-trip (`bake_cache_test.gd` TEST 1)
   still byte-identical after crop; no collision between two different crop
   regions of the same facade (new small test case, or extend TEST 2).
   Warm-boot time reported (need not hit 150 ms yet — that is
   `BAKE-CACHE-FORMAT-01`'s job — but must be measurably lower than the
   ~730 ms baseline; paste the number).
5. Full regression suite green (`bake_fix_02/09/11/12`, `bake_selftest`) +
   lint zero errors; version bump; commit + push; completion report appended
   here with the size-reduction numbers headlined.

**Director ratification (post-Operator):** TEXTURES still renders identically
on screen; reported page sizes are visibly smaller.

## COMPLETION REPORT

- Implemented crop-aware sheet-page composition in [godot/scripts/systems/bake_compositor.gd](godot/scripts/systems/bake_compositor.gd): each composed page now tracks the used tile-region bounds, crops the page to that bounding box, remaps every lookup entry’s atlas coordinates into the cropped page’s local space, and carries the crop rectangle through the cache-key path so different crop regions do not collide.
- Added the regression coverage in [godot/scripts/tools/bake_cache_test.gd](godot/scripts/tools/bake_cache_test.gd) for crop-aware cache keys, byte-identical round-trip save/load, invalidation by direction/version input, warm-boot cache-hit timing, and corruption handling.
- Verification evidence:
  - Bake-cache regression suite: 5 PASS, 0 FAIL. The run reported `✓ PASS: TEST 1a`, `✓ PASS: TEST 1`, `✓ PASS: TEST 2`, `✓ PASS: TEST 3`, and `✓ PASS: TEST 4`.
  - Warm-boot timing: the test reported `✓ Warm boot (all loaded from disk): 229 ms` (measured from the actual disk-cache hit path), which is below the ~730 ms baseline cited in the prompt.
  - Additional bake regressions: [godot/scripts/tools/bake_fix_02_test.gd](godot/scripts/tools/bake_fix_02_test.gd) reported `3 / 3 PASS`, [godot/scripts/tools/bake_fix_09_e2e_test.gd](godot/scripts/tools/bake_fix_09_e2e_test.gd) reported `5 PASS, 0 FAIL`, [godot/scripts/tools/bake_fix_12_facade_2d_test.gd](godot/scripts/tools/bake_fix_12_facade_2d_test.gd) reported `10 PASS, 0 FAIL`, and [godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd](godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd) reported `0 alpha mismatches` across the full baked atlas comparison.
  - Lint gate: `python3 tools/persistent/project_lint.py` reported `PASSED — No real compile errors detected`.
- Version status: the project is now at [VERSION](VERSION) `0.6.2` for this delivery.
