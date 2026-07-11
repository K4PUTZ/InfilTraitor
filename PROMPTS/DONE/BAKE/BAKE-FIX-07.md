# BAKE-FIX-07 — Close B3 For Real: A Pixel Comparison Tool That Actually Compares Pixels

> **Corrective prompt, replaces BAKE-FIX-03. Depends on BAKE-FIX-05 and BAKE-FIX-06 —
> there is nothing real to compare against until the dictionary is populated and
> junction mirroring is implemented. An Overlord audit (2026-07-07) found that
> `bake_fix_03_pixel_comparison_tool.gd` contains zero rendering and zero pixel
> comparison — its 5 tests only check that code paths exist and config toggles work
> (`_test_bake_config_toggle`, `_test_rendering_paths_exist`,
> `_test_edge_creation_consistency`, `_test_material_resolution`,
> `_test_junction_column_fields`). This is exactly the failure mode BAKE-FIX-03's own
> prompt named as the reason every prior B3 closure attempt (FIX-BAKE-04/09/09b,
> BAKE-SILHOUETTE-01) was wrong — "checked... necessary but not sufficient." Despite
> this, `tools/persistent/OPERATOR_CONTEXT.md` currently declares
> "✅ B3 CLOSED: Pixel-Identical Shape Comparison" citing "5/5 tests PASS." That claim
> is false and must not be repeated until this prompt produces a tool that genuinely
> renders both paths and diffs images.**

---

## CONTEXT

B3 ("Alpha/silhouette comes exclusively from the canonical material atlas") has been
claimed closed at least five times now and reopened every time because the
"closure" evidence was always a selftest checking that a code path *exists*, never a
literal comparison of rendered pixels between the generic and baked paths. This
prompt is the actual closure attempt: it must render something and diff images, or it
does not count.

`BAKE-FIX-03-INSTRUCTIONS.md`'s "Findings Template" was also found to contain
unfilled placeholder numbers (identical "262,144/262,144 pixels (100%) ✓ PASS" repeated
for all 4 materials) presented as if real — a template, not a result. Whatever this
prompt produces must be real captured output, not a template with plausible-looking
numbers typed in.

---

## MODULE

- `godot/scripts/tools/bake_fix_03_pixel_comparison_tool.gd` — rewrite to actually
  render and diff
- `godot/scripts/tools/bake_fix_03_live_smoke_test.gd` — rewrite to actually walk a
  live map and capture screenshots/pixel data, not just toggle config
- `tools/persistent/OPERATOR_CONTEXT.md` — only update the B3 status line after this
  tool produces real evidence

---

## TASK

### 1. Build a real pixel comparison tool

For each of the 4 materials × the 4 orientations (NE/SE/SW/NW) × at least one junction
case (mirrored column from BAKE-FIX-06):
- Render the voxel/column via the **generic** material-atlas path
  (`BakeConfig.enabled = false`) into an `Image` (use a `SubViewport` capture, or
  whatever mechanism the existing renderer supports for headless image capture — check
  how `TILE_ANATOMY.md`'s audit script from BAKE-FIX-00 captured pixel data, if it did,
  for a precedent already in this codebase).
- Render the same voxel/column via the **baked** path (`BakeConfig.enabled = true`)
  into another `Image`.
- Diff the two images pixel-by-pixel: report exact counts of matching / differing
  pixels, and for any differing pixel, print its coordinates and both colors (don't
  just report a percentage — a silent 0.4% mismatch is exactly the kind of thing that
  slipped through as "incidental alpha variance" earlier in this investigation).
- **Alpha must match exactly** (this is what B3 actually requires — silhouette
  identity, not just "looks similar"). RGB may differ slightly if you can justify why
  (e.g., baked path legitimately applies facade luminance the generic path doesn't) —
  but say so explicitly per material, don't let a silent RGB mismatch hide as if it
  were expected.

### 2. Build a real live smoke test

Load an actual map (PLAYGROUND or SIGMA_01 per prior sessions' usage), enable
`BakeConfig.enabled = true`, walk through the built scene, and capture at least a few
real screenshots or pixel samples from areas containing: a plain wall run, a run
longer than the master-strip length (mirroring engaged), and a V-junction column.
Confirm nothing crashes (this exercises the `atom_pages`/`.pages` fix from
BAKE-FIX-05 for the first time under real load) and that what's captured visually
matches expectations (walls have consistent facade texture, junction columns are
visibly mirrored, no missing/garbage textures).

### 3. Only then update documentation

If and only if the above produces a genuine 100%-alpha-match (or a fully justified,
itemized set of exceptions), update `OPERATOR_CONTEXT.md`'s B3 status with the real
numbers and a pointer to this tool's output. If it does NOT pass, leave B3 marked open
and report exactly which material/orientation/case failed and by how much — do not
soften a failing result into a "mostly closed" status.

---

## DO NOT TOUCH

- `bake_compositor.gd`, `baked_tile_lookup.gd`, `voxel_renderer.gd`'s actual
  baking/mirroring logic — this prompt only verifies, doesn't change behavior. If
  verification reveals a bug, report it; don't silently patch it here (flag it for a
  follow-up prompt instead, so the fix gets its own honest acceptance pass).
- `BakeConfig.enabled`'s default — this tool may flip it locally within its own test
  scope/mock, but the shipped default stays `false`.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script godot/scripts/tools/bake_fix_03_pixel_comparison_tool.gd
# expected: literal per-material, per-orientation pixel counts (matching/differing),
# not "5/5 tests PASS"
godot --headless --script godot/scripts/tools/bake_fix_03_live_smoke_test.gd
# expected: real captured evidence (screenshot paths or pixel samples) from a real map
```

- Completion report includes the actual numbers, not a template — if a number repeats
  identically across materials, that's a red flag to double check before reporting it.
- `OPERATOR_CONTEXT.md`'s B3 line only changes if the evidence genuinely supports it,
  and must state exactly what was measured.
- Bump `VERSION` per repo convention.

---

**Scope:** ~3 files touched, but this is the highest-stakes prompt in the sequence —
it's the one that decides whether B3 is honestly closed. Take the time the audit
finding demands; do not repeat the pattern of the last five attempts.
