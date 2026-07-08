# BAKE-FIX-11 — Actually Build the SubViewport Pixel Comparison (B3 Closure, Attempt 6)

> **Corrective prompt, replaces BAKE-FIX-07. Depends on BAKE-FIX-09 (lookup must
> resolve for real) and BAKE-FIX-10 (mirroring must be exercised by a real test). An
> Overlord audit (2026-07-07) found that across three sequential commits
> (`b133b8a`, `664270e`, `8e355a3`), BAKE-FIX-07 never once created a `SubViewport`,
> never called `get_image()`, and never diffed a single pixel — every "phase" re-built
> a variant of the same config/structural-existence checks BAKE-FIX-07's own prompt
> was written to eliminate, then explicitly deferred the actual rendering work to an
> unscheduled "Phase 4" in its own code comments. This is now the sixth attempt at
> closing B3 (after FIX-BAKE-04/09/09b, BAKE-SILHOUETTE-01, and BAKE-FIX-03). To its
> credit, this round's documentation was honest about the gap (`OPERATOR_CONTEXT.md`
> says "B3 PENDING", not "CLOSED") — so this prompt starts from an honest baseline,
> which is progress. It must now finish the job.**

---

## CONTEXT

Three files exist under the BAKE-FIX-07/03 label, none of which render anything:

- `godot/scripts/tools/bake_fix_03_pixel_comparison_tool.gd` — tests
  `_test_material_registry` / `_test_bakeconfig_toggle`; ends with a printed
  "[NEXT STEP]" list describing SubViewport capture and alpha comparison as future
  work, not something it did.
- `godot/scripts/tools/bake_fix_03_live_smoke_test.gd` — tests `_test_load_map` /
  `_test_map_compilation` / `_test_bakeconfig_toggle`; ends with "For full B3 closure:
  Implement SubViewport image capture..." as a to-do.
- `godot/scripts/tools/bake_fix_03_pixel_comparison.gd` (a third, newer file) —
  compares compiled **layout dictionaries** (structural key sets) between
  `BakeConfig.enabled = true/false`, not rendered pixels. Header comment: *"NOTE:
  Pixel-by-pixel alpha comparison requires SubViewport image capture"* — again
  describing what it doesn't do.

Zero hits for `SubViewport` or `get_image` across all three files. This prompt's job
is the one thing all three predecessors deferred: actually render both paths to
`Image`s and diff them.

This only became possible to do meaningfully once BAKE-FIX-09 makes
`BakedTileLookup.resolve()` genuinely return baked results (previously it silently
always fell back to generic, so a "comparison" would have been comparing the generic
path against itself) and BAKE-FIX-10 makes junction mirroring exercised by a real
test. Do not start this prompt until both have landed with real evidence, or the
"comparison" will again be comparing nothing against nothing.

---

## MODULE

- `godot/scripts/tools/bake_fix_03_pixel_comparison_tool.gd` — rewrite to actually
  render and diff (consolidate the 3 existing files into this one if that's cleaner;
  note in the completion report if you retire the other two)
- `godot/scripts/tools/bake_fix_03_live_smoke_test.gd` — rewrite to actually capture
  real screenshots/pixel data from a live map
- `tools/persistent/OPERATOR_CONTEXT.md` — only update the B3 status line after real
  evidence exists

---

## TASK

### 1. Build the actual SubViewport-based renderer

Figure out the concrete headless-rendering mechanism this engine version supports for
capturing a rendered voxel/tile to an `Image`:
- Create a `SubViewport`, size it to fit one tile/atom (or a small cluster), add a
  `TileMapLayer` (or minimal scene) with a single cell set via the real
  `set_cell(grid_pos, source_id, atlas_coords, alternative_id)` call — the exact
  production call path, not a hand-drawn image.
- Force a render (`await RenderingServer.frame_post_draw` or the project's established
  pattern for headless capture — check if any other tool in this codebase already
  does headless rendering/screenshotting as precedent, e.g. anything under
  `godot/scripts/tools/` that isn't part of this bake-fix series).
- Call `viewport.get_texture().get_image()` to get the rendered `Image`.

### 2. Render + diff for each real case

For each of the 4 materials × 4 orientations × at least one junction case (mirrored
column, from BAKE-FIX-10):
- Render via the **generic** path (`BakeConfig.enabled = false`) into an `Image`.
- Render the **same** voxel via the **baked** path (`BakeConfig.enabled = true`) into
  another `Image`.
- Diff pixel-by-pixel. Report the literal count of matching/differing pixels — not a
  percentage alone. For any differing pixel, print its coordinates and both RGBA
  values (a silent 0.4% mismatch is exactly what slipped through as "incidental
  variance" in earlier attempts at this same closure).
- **Alpha must match exactly** — this is what B3 actually requires. If RGB differs
  (e.g. baked path legitimately applies facade luminance the generic path doesn't),
  say so explicitly per material with a reason, don't let it hide silently.
- If any test produces identical-looking numbers across materials (a red flag seen
  before with template placeholders), double check it's real captured data, not a
  copy-pasted result.

### 3. Real live smoke test

Load an actual map (PLAYGROUND or SIGMA_01), `BakeConfig.enabled = true`, and capture
real screenshots/pixel samples from: a plain wall run, a run longer than the
master-strip length (mirroring engaged mid-run), and a V-junction column. Confirm
nothing crashes and that captured output visually matches expectations (consistent
facade texture, visibly mirrored junction columns, no missing/garbage textures).

### 4. Only then update documentation

If and only if this produces a genuine 100%-alpha-match (or a fully justified,
itemized set of exceptions), update `OPERATOR_CONTEXT.md`'s B3 status with the real
numbers and a pointer to this tool's output, changing it from "PENDING" to "CLOSED".
If it does not pass, leave it PENDING and report exactly which
material/orientation/case failed and by how much.

---

## DO NOT TOUCH

- `bake_compositor.gd`, `baked_tile_lookup.gd`, `voxel_renderer.gd`'s actual
  baking/mirroring/lookup logic — this prompt only verifies. If verification reveals a
  bug (beyond what BAKE-FIX-09/10 already fixed), report it, don't silently patch it
  here.
- `BakeConfig.enabled`'s default — stays `false`.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script godot/scripts/tools/bake_fix_03_pixel_comparison_tool.gd
# expected: literal per-material, per-orientation pixel counts (matching/differing),
# produced by an actual SubViewport render + Image diff — grep the file yourself
# before reporting done: `grep -c SubViewport <file>` must be > 0
godot --headless --script godot/scripts/tools/bake_fix_03_live_smoke_test.gd
# expected: real captured evidence (screenshot paths or pixel samples) from a real map
```

- Completion report includes the actual numbers, with a note on which specific line
  of code performs the `SubViewport`/`get_image()` capture (cite file:line) — this is
  the one thing to verify most skeptically given five prior attempts skipped it.
- `OPERATOR_CONTEXT.md`'s B3 line only changes if the evidence genuinely supports it.
- Bump `VERSION` per repo convention.

---

**Scope:** ~3 files touched, but this is still the highest-stakes prompt in the
sequence — the sixth attempt at the one thing that actually closes B3. If headless
`SubViewport` rendering turns out to be infeasible in this environment, say so
explicitly and propose a concrete alternative (e.g. an offline compositing comparison
that reads the same `Image` data the renderer would consume, bypassing the viewport
but still diffing real pixels) rather than falling back to a sixth round of
structural/config checks.
