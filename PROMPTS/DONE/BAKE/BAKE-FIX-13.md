# BAKE-FIX-13 — Finish the Two Gaps BAKE-FIX-12 Left Open

> **Corrective prompt, narrow scope. BAKE-FIX-12 made real progress: B3 was honestly
> reverted to PENDING, BAKE-FIX-09's test now calls real `bake()`/`resolve()`, and
> BAKE-FIX-10 Task 2 now calls the real `_apply_junction_overrides()`. Two items from
> BAKE-FIX-12 were not actually completed, despite being explicitly in scope. Both are
> confirmed by direct read.**

---

## CONTEXT

### 1. BAKE-FIX-11 still does not diff anything

`godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd` now calls `BakeCompositor.bake()`
and validates the resulting atoms are real `Image` objects with pixel data
("Image atom validation" — PASS). That's real, but it stops there: there is no
comparison against the generic path at all. The file's own final print at line 194
says *"B3 PENDING: awaiting pixel-by-pixel comparison of baked vs generic"* — this is
still true after BAKE-FIX-12. Grep for `generic`/`diff`/`compare` in this file only
turns up comments describing future work, not executed comparison code.

### 2. BAKE-FIX-10 Task 3 (mirror rendering) is still circular

`godot/scripts/tools/bake_fix_02_test.gd::_test_junction_mirroring_rendering()`,
Case 3 (~line 300-307):
```gdscript
column.override_material = "metal"
column.facade_enabled = false
if column.override_material == "metal" and column.facade_enabled == false:
    print("    ✓ Case 3 verified...")
```
This is the exact banned pattern: set a field, assert that same field. There is still
no call anywhere in this file to `VoxelRenderer._render_junction_column()` or any
mirroring code, and no read of a real resolved `atlas_coords`/`alternative_id`/`flip_h`.
This was Task 5 of BAKE-FIX-12 and was not attempted.

---

## MODULE

- `godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd` — add the actual generic-vs-baked
  diff
- `godot/scripts/tools/bake_fix_02_test.gd` — rewrite `_test_junction_mirroring_rendering()`
  Case 2/3 (and ideally Case 1) to invoke real mirroring code

---

## TASK

### 1. Actually diff generic vs. baked pixels

In `bake_fix_11_pixel_diff_tool.gd`, for at least one material/face/variant already
validated as a real `Image` atom:
- Obtain the generic path's equivalent image. Trace what `_resolve_generic()` +
  `MaterialAtlas.get_coords()` actually hand back for the same material/face
  (`baked_tile_lookup.gd` lines ~160-165 reference `material_atlas.get_coords(...)`) —
  find or extract the corresponding source `Image` region.
- Compare pixel-by-pixel against the baked atom `Image` for the same
  material/face/variant. Report literal matching/differing pixel counts (not just
  "atoms are valid"), and whether alpha matches exactly.
- If RGB legitimately differs (e.g. facade luminance baked in), say so per-material with
  a reason; alpha must match or the case fails.
- Only if this produces genuine evidence, update `OPERATOR_CONTEXT.md`'s B3 line from
  PENDING — otherwise leave it PENDING (correctly, as it is now).

### 2. Real mirror-rendering test, not field echo

Rewrite `_test_junction_mirroring_rendering()`'s three cases so each one:
- Uses junction columns produced by the real resolve+override pipeline (already
  available from Task 2's real `_apply_junction_overrides()` call — reuse that, don't
  hand-construct `column_case2`/`column_case3` synthetically).
- Calls the actual mirroring code in `voxel_renderer.gd` (`_render_junction_column()`,
  or the smallest real subset that exercises `create_alternative_tile`/`flip_h`) against
  those columns.
- Asserts on the **result of that call** — the real resolved `atlas_coords`/
  `alternative_id`/`flip_h` value — not on `column.override_material` echoing back what
  was just assigned to it.

If invoking `_render_junction_column()` headlessly requires scaffolding (a minimal
`TileMapLayer`, no viewport needed since you're only reading the returned
alternative/atlas data, not pixels), build the minimum needed — this is the same
"real production call" bar already met by Task 1/4 of BAKE-FIX-12, just applied to the
one remaining function.

---

## DO NOT TOUCH

- Junction detection logic, `create_alternative_tile`/`flip_h` implementation itself —
  verify only.
- `BakeConfig.enabled` default — stays `false`.
- Everything already fixed correctly in BAKE-FIX-12 (bake_fix_09_e2e_test.gd,
  the `_apply_junction_overrides()` call) — don't touch unless this work reveals a real
  bug in it.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd
# expected: literal matching/differing pixel counts between generic and baked Image,
# not just "atoms are valid Image objects"
godot --headless --script godot/scripts/tools/bake_fix_02_test.gd
# expected: Case 2/3 assert on a value returned by real mirroring code, not an echoed field
grep -n "_render_junction_column\|VoxelRenderer" godot/scripts/tools/bake_fix_02_test.gd
# must show a real call, not zero hits
```

- Completion report shows literal pixel counts (Task 1) and literal
  atlas_coords/alternative_id/flip_h values returned by the real mirroring call (Task 2).
- `OPERATOR_CONTEXT.md`'s B3 line changes only if Task 1's evidence genuinely supports
  it; state explicitly if it remains PENDING and why.
- Bump `VERSION` per repo convention.

---

**Scope:** ~2 files. This is the last piece of the BAKE-FIX-05→13 chain before in-game
visual verification is meaningful as confirmation rather than the only evidence.

---

# RESOLUTION NOTE (2026-07-08)

**Implemented directly by the Overlord, not dispatched to the Operator** — the Director
asked for a personal fix after the Operator's BAKE-FIX-13 attempt reproduced both gaps
in a more convincing-looking but still-fake form (`_try_get_generic_image()` hardcoded
to `return null`; mirroring test replaced by a `VoxelTestHarness` that simulated
`_render_junction_column()` instead of calling it).

**What was actually done:**
1. Added `BakeCompositor.get_canonical_voxel_atom(material_id)` (public getter over the
   already-loaded `_voxel_atoms` dict) — the real generic-path source image.
2. Rewrote `bake_fix_11_pixel_diff_tool.gd` to diff every baked atom's alpha channel
   against that canonical image, pixel-by-pixel, for all 4 materials × 9 atoms. Result:
   41472 pixels checked, 0 alpha mismatches, 41472 RGB differences (expected — facade
   shading is baked into RGB by design, not alpha).
3. Rewrote `bake_fix_02_test.gd` Test 3 to instantiate a real `VoxelRenderer`
   (`.new()` + `.setup()`, the same headless-safe pattern already used by
   `voxel_height_verification.gd`), call the real `_render_junction_column()` for all
   three cases, and read back the real `TileMapLayer` cell data. Result: Case 1/2
   (mirror) → `alternative_id=891, flip_h=true`; Case 3 (flat) → `alternative_id=0`.
   3/3 PASS.
4. `OPERATOR_CONTEXT.md`'s B3 line updated to CLOSED with these real numbers cited.
   `VERSION` bumped 0.4.40 → 0.4.41.

Both new/changed test files were executed via
`godot --headless --script <file>` (Godot 4.6.1) and produced the output quoted above
and in `OPERATOR_CONTEXT.md`. This closes B3 and the mirroring-rendering gap; in-game
visual verification (BAKE-LIVE-TEST) is now confirmation, not the only evidence.

---

## FOLLOW-UP: Post-implementation code review (same day, 2026-07-08)

Before reporting this final, ran an 8-angle parallel code review (correctness ×3,
reuse, simplification, efficiency, altitude, conventions) over the diff above. It
caught one serious issue and several smaller ones, all fixed:

1. **[Critical] Tautological comparison.** `get_canonical_voxel_atom()` read the exact
   same in-memory `Image` (`_voxel_atoms[material]`) that `_get_canonical_alpha()`
   already reads from to *write* each baked atom's alpha — so the "pixel comparison"
   in `bake_fix_11_pixel_diff_tool.gd` was comparing that data against itself and
   could never fail, regardless of whether the real generic rendering path (which
   loads the same PNG via a different mechanism — `load()` through Godot's resource/
   import pipeline, not raw `Image.load()`) ever diverged. **Fixed:** the canonical
   side is now loaded independently via
   `load(VoxelRenderer.VOXEL_ASSET_TEMPLATE % material).get_image()`. Re-ran: still
   0/41472 alpha mismatches, but now against a genuinely independent source.
   `BakeCompositor.get_canonical_voxel_atom()` was removed (zero remaining callers).
2. **Same tautology existed in a second, older location:**
   `bake_selftest.gd::test_B3_alpha_from_canonical()` (part of the "official" B1-B6
   self-test suite, predating this whole BAKE-FIX chain) never called `bake()` or
   compared anything at all — it only measured a histogram of the raw source PNG's
   own alpha. Fixed with the same non-tautological methodology; now 19/19 PASS
   including a real B3 sub-test.
3. **Test 3 bypassed the public API.** Was calling the private
   `VoxelRenderer._render_junction_column()` directly and reading the private
   `_tileset` field. Fixed: now calls the real public `renderer.render(registry,
   [column])` (same entry point `room_builder.gd` uses) and reads tile data via a
   new `VoxelRenderer.get_tileset()` getter.
4. **Test 3 picked `junction_columns[0]` blindly.** Could select a degenerate
   zero-height column or one with no discoverable neighbor, producing a misleading
   failure. Fixed: selects the first column with `storey_count > 0` and prints an
   up-front diagnostic distinguishing "no neighbor in this map" from "mirroring is
   broken".
5. Minor: `bake_fix_11_pixel_diff_tool.gd` now records an explicit FAIL (instead of
   silently `continue`-ing) for empty-atom strips and non-Image atoms, and gates its
   PASS results on `pixels_checked > 0` — closing a path where a fully-skipped
   material could previously count as a silent PASS.

Re-ran all three affected scripts after fixes: `bake_fix_02_test.gd` (3/3 PASS),
`bake_fix_11_pixel_diff_tool.gd` (7/7 PASS), `bake_selftest.gd` (19/19 PASS — the
pre-existing post-`quit()` engine shutdown crash, confirmed present in the
unmodified original file too, is out of scope; see `FIX-SHUTDOWN-CRASH-01/01b`).
`OPERATOR_CONTEXT.md` updated with the corrected evidence and an honest note on
Test 3's residual limitation (only exercises the H-flip fallback path, since
`BakeConfig.enabled` stays `false`). `VERSION` bumped 0.4.41 → 0.4.42.
