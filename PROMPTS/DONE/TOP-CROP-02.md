# TOP-CROP-02 — Consume T: diamond crops on sheet pages

**Sequence: after TOP-SHEAR-01 is green. T exists and is proven; this prompt
only crops it.**

---

## CONTEXT

T is now a verified image where the iso ground plane is laid out in screen
space. Every atom's top face is one axis-aligned crop of it — no geometry
left to invent. Formulas (canonical, from TOP-01-b, unchanged):

- Ground window for atom (col, row): `u₀ = col·16`, `v₀ = row·16`.
- Top vertex in T: `sx₀ = u₀ − v₀ + X_OFF`, `sy₀ = (u₀ + v₀)/2 + Y_MARGIN`.
- Crop: `Rect2i(sx₀ − 16, sy₀, 32, 16)` → paste at atom (0, 0) **through the
  diamond mask** (derive the mask from `_get_diamond_overlay`'s edge
  geometry — one diamond definition in the codebase, not two). dir 1 uses T⁻.
- This replaces the flat base-color diamond when `facade_tops` is true;
  when false, output stays bit-identical to today.

Bump `BAKE_CODE_VERSION` (page output changes — standing rule).

## TASK

1. Wire the crop into `_compose_sheet_page` (sheet pages only — junctions
   are TOP-JUNCTION-03). Set `facade_tops` default back to `true`.
2. Update the top-face test expectations to the composed transform (the
   contract, not the implementation).

## ACCEPTANCE (4)

1. **Composed-transform identity:** ≥ 64 top-diamond pixels (inside mask,
   alpha > 0, ≥ 16 atoms, both dirs) match the independently-loaded facade
   through `(u,v) → (u−v+X_OFF, (u+v)/2)` inversion, ±1 texel, 0 mismatches,
   deterministic seed. Run against the OLD flat-top output first and paste
   its failure (red-before-green).
2. **Slope witness:** with `debug_marker_facade=true`, a white marker row
   line crosses one atom's diamond at screen slope −1/2 (≥ 3 sampled pixels
   per direction) — kills "upright squares" directly.
3. Baseline suite green (12 full incl. top overlap ≥ 500 px / 0 mismatches,
   11, 02, 09, selftest — one-line results pasted); `facade_tops=false`
   pages byte-identical to flat tops (sampled assert); disk cache logs MISS
   with new keys then HIT (version bump proof).
4. Report appended HERE, verdicts per criterion; lint; commit + push.

**Director visual gate:** wall tops read as a diamond-projected continuous
slab on TEXTURES before TOP-JUNCTION-03 starts.
