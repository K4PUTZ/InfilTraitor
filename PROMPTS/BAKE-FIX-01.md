# BAKE-FIX-01 — Master-Strip Bake Pass (replaces live per-voxel baking)

> **Part of `PROMPTS/PLANNING/BAKING_SYSTEM_MASTER_FIX.md` (Phase 1). Depends on
> BAKE-FIX-00's `docs/production/TILE_ANATOMY.md` — read it first and use its real
> numbers (atom dimensions, visible-region split, facade dimensions, strip length).
> If BAKE-FIX-00 hasn't landed, stop and say so; do not guess these numbers.**

---

## CONTEXT

Ratified direction (`BAKING_SYSTEM_MASTER_FIX.md` §3, D-BAKE-1): baking stops being a
live, per-voxel, per-face-orientation operation and becomes a **master-strip bake**:
for each (material, facade, theme) combination actually referenced by the loaded map,
bake a contiguous strip of real 32×36 atoms **once**, straight rectangular facade crop
per atom position (no shear, no `PerFaceProjector`), alpha copied verbatim from the
real atom file. The strip is cached in a dictionary; `BAKE-FIX-02` wires the room
builder to walk it instead of baking live.

This retires the root cause diagnosed in the master plan: `bake_compositor.gd`'s
32×16 canvas (should be 32×36, per `TILE_ANATOMY.md`), and `PerFaceProjector`'s
per-face affine shear (unnecessary once crops are straight rectangular slices — the
real renderer already proves voxel shape/placement don't vary by wall orientation,
`voxel_renderer.gd:189-193`, `atlas_coords` always `Vector2i.ZERO`). It also
structurally closes invariant B3: alpha is never derived from geometry, only copied.

---

## MODULE

- `godot/scripts/systems/bake_compositor.gd` — rewritten: bakes a strip, not a
  per-edge tile
- `godot/scripts/systems/facade_strip_baker.gd` — new, or fold into
  `bake_compositor.gd` if it stays under the ~300-line module target; your call, note
  which in the completion report
- `godot/scripts/world/builders/room_builder.gd` — `_register_baked_atlas_page()`
  registration parameters
- `godot/scripts/tools/bake_selftest.gd` — B1–B6 assertions updated for new canvas/shape
- Archive (do not silently delete — move per project convention):
  `godot/scripts/systems/per_face_projector.gd`,
  `godot/scripts/systems/material_atlas_generator.gd`,
  `godot/scripts/tools/per_face_projector_test.gd`

---

## TASK

### 1. Strip bake

For each unique (material, facade, theme) triple actually referenced by the loaded
`MapSpec` (not the whole catalog):

- Bake `strip_length` (from `TILE_ANATOMY.md`) real 32×36 atoms.
- Atom *i*'s RGB = material base_color × pattern shade (existing `MaterialRegistry`
  logic, unchanged) × facade luminance sampled from a **straight rectangular crop**:
  facade plane columns `[i·W, (i+1)·W)`, rows fixed at whatever visible-region answer
  `TILE_ANATOMY.md` §2 gave (do not re-derive; use the doc's stated rows).
- Atom *i*'s alpha = the real atom file's own alpha channel, copied pixel-for-pixel,
  unmodified. No geometry, no predicate — a straight channel copy.
- Store in a dictionary keyed by `(material_id, facade_id, theme_id, strip_index)`.
  Use `FacadeSampler`'s existing `_mirror_1d`/`_mirror_2d` (unchanged — already
  correct) for any `strip_index` that falls outside `[0, strip_length)` when consumed
  later (BAKE-FIX-02); this prompt only needs to store the strip itself, not the
  mirror-consumption logic.
- Runs once per triple actually used, at map load (not per wall, not per voxel).

### 2. Atlas registration

Fix `room_builder.gd::_register_baked_atlas_page()`:
- `texture_region_size` → the real atom size from `TILE_ANATOMY.md` (32×36), not
  `Vector2i(32, 16)`.
- `texture_origin`, `y_sort_origin` → copy `build_voxel_tileset.gd`'s real values
  exactly (the tileset the generic, currently-shipping renderer already uses) — this
  is what makes a baked tile pixel-identical to its generic counterpart.
- Update any tiles-per-page math in `bake_compositor.gd` (`_render_batch()`'s
  `tiles_per_page_x/y`, currently hardcoded against 32×16) for the new atom size.

### 3. Retire `PerFaceProjector` and `material_atlas_generator.gd`

- Confirm (grep) `material_atlas_generator.gd` is still called from nowhere in
  production before archiving it — if this prompt's own changes happen to start using
  it for anything, stop and reconsider (it should not be needed).
- Archive both files + `per_face_projector_test.gd` per project convention (do not
  leave a second, unused geometry path sitting next to the real one — that's exactly
  how the original defect went unnoticed for 3 prompts).
- Remove any remaining references (grep for `PerFaceProjectorClass`,
  `MaterialAtlasGenerator` across `godot/scripts/` and update/delete call sites).

### 4. Selftest rewrite

Update `bake_selftest.gd`'s B1 (branch exclusivity), B2 (grayscale), B3 (alpha from
canonical — this is now trivially true by construction, but assert it anyway: baked
atom alpha === real atom file alpha, byte-for-byte, not just "has opaque and
transparent pixels"), B4 (FNV-1a determinism — window origins still hash-derived, just
consumed differently), B6 (loud-fail) for the new canvas size and dictionary shape.
Every "shape" assertion must compare against the real atom file's actual pixels, never
against another code path's output.

---

## DO NOT TOUCH

- `TextureResolver` / `TEX-CATALOG-01` — sound, unchanged.
- `MaterialRegistry`'s pattern algorithms (`stone_pattern.gd`, `wood_pattern.gd`,
  `metal_pattern.gd`) — the shading math itself is unaffected; only how its output
  combines with alpha changes.
- `FacadeSampler` — `_mirror_1d`/`_mirror_2d`/FNV-1a hashing are correct, keep as-is
  (BAKE-FIX-02 is what actually calls the run-mirroring path; this prompt only needs
  the plain per-atom crop, no mirroring inside the strip itself).
- `voxel_renderer.gd::_render_junction_column()` — untouched here, that's BAKE-FIX-02.
- `BakeConfig.enabled` — stays `false`.
- Anything in `junction_resolver.gd`, `edge_extractor.gd` (unrelated system).

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script res://godot/scripts/tools/bake_selftest.gd
# expected: all B1-B6 groups PASS, with B3's assertion showing byte-identical alpha
# against the real atom file (paste the literal comparison, not just PASS)

grep -rn "PerFaceProjectorClass\|MaterialAtlasGenerator" godot/scripts/ | grep -v "_archive"
# expected: no hits outside the archived files themselves

python3 tools/persistent/check_invariants.py
```

- Completion report includes the real atom's alpha histogram vs. the baked strip
  atom's alpha histogram side-by-side, showing byte-identical match — this is the
  literal evidence B3 is structurally closed, not just passing a test written this
  session.
- Bump `VERSION` per repo convention.

---

**Scope:** ~4 files rewritten/touched, 3 files archived · 1 session · unblocks
BAKE-FIX-02.
