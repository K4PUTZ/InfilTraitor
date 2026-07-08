# BAKE-FIX-06 — Junction Column Mirroring (D-BAKE-2) and Override Authoring (D-BAKE-3): Actually Implement Them

> **Corrective prompt, replaces the unfinished part of BAKE-FIX-02. Depends on
> BAKE-FIX-05 (dictionary must actually be populated first). An Overlord audit
> (2026-07-07) found BAKE-FIX-02's own commit message ("simplify for BAKE-FIX-02")
> didn't match its scope, and the real work — landed later, uncommitted-as-such,
> bundled inside the BAKE-FIX-04 doc-reconciliation commit — left both of this
> prompt's headline requirements as stubs. Read
> `PROMPTS/DONE/BAKE-FIX-02.md` in full before starting; this prompt does not repeat
> its context, only what's still missing.**

---

## CONTEXT

`JunctionColumn` (`junction_resolver.gd`) does carry the fields BAKE-FIX-02 asked for
— `facade_enabled: bool` and `override_material: String` exist and are threaded through
the constructor. But two things that were supposed to use them don't:

**1. Mirroring is a stub.** `voxel_renderer.gd::_render_junction_column()` (around
line 154-172) has both its "no facade" and "with facade" branches call the exact same
`_set_voxel_cell(column.voxel_pos, level, actual_material)` — no edge, no mirror, no
neighbor lookup. The code's own comment admits it:
`# For now, render flat - will implement mirroring in subsequent fix after understanding atlas structure`.
This prompt is that subsequent fix.

**2. There is no authoring surface.** `JunctionResolver.resolve()`
(junction_resolver.gd:56-140) always constructs
`JunctionColumn.new(diagonal_cell, voxel_pos, junction_storey_count, min_start, edge_a.material)`
— it never reads an override from anywhere. `override_material` and `facade_enabled`
exist as fields but nothing in production ever sets them to anything but their
constructor defaults (`""` / `true`). TASK 4 from BAKE-FIX-02 (locate the real MapSpec
shape, add an optional per-junction override) was not attempted; no report explained
why it was skipped.

**3. The existing test is circular.** `godot/scripts/tools/bake_fix_02_test.gd`
re-implements run-grouping logic inline inside the test instead of calling
`room_builder.gd`'s real grouping function, and its junction-column tests set
`column.facade_enabled = false` / `column.override_material = "wood"` on a bare object
then assert those same fields equal what was just set (tautological). Test 4 is
literally titled `"Junction Default — No Override, No Mirroring (Yet)"` and prints
`"Verified: ... future mirror implementation"` — it's a documented admission embedded
inside a test that BAKE-FIX-04's docs then cited as evidence of completion. This test
must be rewritten to assert against real rendered output, not against values it just
set itself.

---

## MODULE

- `godot/scripts/geometry/voxel_renderer.gd` — `_render_junction_column()`: real
  mirror-lookup logic
- `godot/scripts/geometry/junction_resolver.gd` — `resolve()`: read an authored
  override if present
- MapSpec schema (locate the actual current parser/shape — do not assume; BAKE-FIX-02
  flagged this as an assumption to confirm, still unconfirmed)
- `godot/scripts/tools/bake_fix_02_test.gd` — rewrite non-circular

---

## TASK

### 1. Implement real mirroring (default case, no override)

In `_render_junction_column()`, when `facade_enabled = true` and no override is set:
identify the neighboring wall slice's boundary voxel — the true wall voxel immediately
adjacent to this extra column (use `column.gu_cell`/`column.voxel_pos` and the
registry/edges available at render time to find it; trace how `_render_slice()` calls
`_set_voxel_cell()` with an `edge` argument to see what's available for a normal wall
voxel, at line ~147). Resolve that neighbor's actual baked atom via
`BakedTileLookup.resolve()` (now functional per BAKE-FIX-05), then render the column's
voxel using that same atom **horizontally mirrored**. If `BakedTileLookup` exposes no
way to get a raw atom image (only atlas_coords for tile placement), determine how
mirroring should actually be expressed in this tileset-atlas world — e.g., a
pre-mirrored copy of the boundary atom placed at its own atlas coordinate the column
can point to, or an `TileData` flip flag on the tile source, whichever fits how
`_set_voxel_cell()` actually places tiles today (read it in full first,
voxel_renderer.gd ~176 onward). Do not invent a rendering mechanism unrelated to how
every other voxel gets placed.

### 2. Implement the override authoring surface (D-BAKE-3)

Locate the real current `MapSpec`/map-authoring schema (read the actual
parser/loader in use — grep for where `WallEdgeData` or junction data gets populated
from raw map files). Add an optional per-junction override, keyed consistently with
how edges/vertices are already keyed there. `JunctionResolver.resolve()` checks for
this override before falling back to current behavior (derive material from
`edge_a`, `facade_enabled = true`). If the assumed authoring surface (keyed like
`WallEdgeData`) turns out not to fit the real schema, say so explicitly in the
completion report and describe what you did instead — this was flagged as an
assumption in BAKE-FIX-02 and deferred once already; it must be resolved this time,
not deferred again.

### 3. Rewrite the test non-circularly

Replace or fix `bake_fix_02_test.gd` so each case calls the real production functions
and asserts against literal expected values:
- **Default mirror**: build a synthetic run of 3+ collinear edges terminating in a
  V-junction (real `EdgeRegistry`/`JunctionResolver.resolve()` call, not a hand-built
  column object). Render it, then assert the junction column's resolved atom equals
  the neighboring wall voxel's atom, horizontally mirrored, pixel-for-pixel (compare
  actual `Image` pixel data, not field equality).
- **Override + `facade_enabled = true`**: assert the column's resolved atom comes from
  the override material's baked strip (mirrored), not the wall edges' material.
- **Override + `facade_enabled = false`**: assert the column renders the override
  material flat via the same material-only code path every other flat voxel uses (no
  baked lookup attempted at all) — verify this by checking the branch actually taken,
  not just the final material name.

No test may set a field on a bare object and then assert that same field's value.

---

## DO NOT TOUCH

- `junction_resolver.gd`'s V/T/X **detection** logic (which cells get a column) —
  correct, not in question.
- `bake_compositor.gd`'s strip-baking or `baked_tile_lookup.gd`'s run-walking/mirror
  math for ordinary wall voxels — BAKE-FIX-05 fixes the dictionary population; this
  prompt only adds the junction-column consumer on top.
- `BakeConfig.enabled` — stays `false`.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script godot/scripts/tools/bake_fix_02_test.gd
# expected: literal PASS lines, each showing the actual pixel/material comparison
python3 tools/persistent/check_invariants.py
```

- Completion report shows literal evidence (not just "PASS") for: (a) the default
  mirror case, (b) both override cases, (c) whether the assumed MapSpec authoring
  shape held or what was done instead.
- Commit message accurately describes this as junction-column mirroring +
  override-authoring work — not filed under an unrelated label.
- Bump `VERSION` per repo convention.

---

**Scope:** ~4-5 files touched · unblocks BAKE-FIX-07 (visual QA needs junction
mirroring actually working to have something real to compare against).
