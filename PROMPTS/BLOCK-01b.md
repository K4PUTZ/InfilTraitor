# BLOCK-01b: Storey-Gap Fix & Real Validation (closing BLOCK-01's deferrals)

**Status:** Ready for implementation
**Predecessor:** BLOCK-01 (verified — VERIFY_BLOCK_01_20260705: Items 1/2/3/5 solid, one real bug found, three criteria deferred/assumed rather than measured)
**Successor:** PLAYGROUND-02 (District D becomes a QA confirmation, not a bug hunt)
**Scope:** Fix the phantom-floor storey bug in mixed-height adjacent blocks; replace the three deferred/assumed validation criteria with real, executed evidence.
**Effort:** ~3 hours
**Risk:** Low-medium (the `Edge` model extension is additive and backward-compatible; everything else is test-writing)

---

## Item 1 — Fix: `Edge` gains a `start_storey` field

**Root cause (confirmed by trace, not guess):** `Edge`'s canonical id depends only on the cell pair, not storey. When a face between two solid blocks of different heights is culled at low storeys (both occupied → buried) and only becomes exposed starting at a higher storey, its **first** insertion into `edge_groups` happens at that higher storey. The existing formula `storey_count := max_storey + 1` then assumes the edge has existed continuously from storey 0, fabricating a phantom lower-storey wall segment that was never meant to render.

**Fix — additive, backward-compatible:**

1. `geometry/edge.gd`: add `var start_storey: int = 0` to the class; extend `_init()` and `Edge.between()`/`Edge.new()` call sites with an optional `p_start_storey: int = 0` parameter (default preserves every existing caller's behavior unchanged — ordinary walls always start at 0).
2. `geometry/edge_extractor.gd`, solidblock pass: track **both** `min_storey` and `max_storey` per edge id (not just max):
   ```gdscript
   if edge.id not in edge_groups:
       edge_groups[edge.id] = {"edge_template": edge, "min_storey": storey, "max_storey": storey}
   else:
       edge_groups[edge.id]["min_storey"] = mini(edge_groups[edge.id]["min_storey"], storey)
       edge_groups[edge.id]["max_storey"] = maxi(edge_groups[edge.id]["max_storey"], storey)
   ```
   The **wall** branch (existing, untouched otherwise) can leave `min_storey` implicitly 0 — walls are always built as contiguous stacks from the ground in the current authoring model, so defaulting `min_storey = 0` there preserves current behavior exactly. Only the **solidblock** branch's aggregation needs the real min.
3. Third pass: compute `storey_count := max_storey - min_storey + 1` and `start_storey := min_storey`; construct `Edge.new(gu_a, gu_b, storey_count, material, start_storey)`.
4. `geometry/slice_generator.gd`: thread `edge.start_storey` into the `Slice` (add the field, default 0) and change the storey loop from `for level in range(edge.storey_count)` to `for level in range(edge.start_storey, edge.start_storey + edge.storey_count)`.
5. `geometry/voxel_renderer.gd`: wherever a slice's levels are iterated for rendering (`_ensure_voxel_layers`, `_render_slice`'s level loop), confirm they already iterate whatever range the slice hands them (most should, since they take `slice.storey_count`/level values as given) — audit each call site named in Item 2 of BLOCK-01's original report (`slice_generator.gd:39,45`; `voxel_renderer.gd:136,148,150`) and update any that assume a `range(0, storey_count)` shape rather than using the slice's actual level values.

**Stop-and-report checkpoint:** if any render call site turns out to assume storeys are always contiguous from 0 in a way that's deeper than a simple range-start change (e.g., an array indexed directly by storey number starting at 0), stop and report rather than reshaping that structure improvisationally — that would be a larger change than this prompt's scope.

## Item 2 — Real, isolated face-culling count test

Replace the mixed TEST_BLOCKS-based "clarification" with an isolated fixture that can produce an unambiguous number:

```gdscript
# New: godot/scripts/tools/block_01b_face_culling_test.gd
# Minimal compiled input: ONLY two adjacent same-storey solidblock_ entries,
# no board perimeter, no divider, no other walls — isolates the count completely.
var wall_levels = [[
	{"cell": Vector2i(3, 3), "tile_name": "solidblock_stone"},
	{"cell": Vector2i(4, 3), "tile_name": "solidblock_stone"},
]]
var compiled = {"wall_levels": wall_levels}
var extraction = EdgeExtractorClass.extract(compiled)
assert(extraction["edges"].size() == 6,
	"Two adjacent same-storey blocks must produce exactly 6 edges (8 - 2 shared), got %d" % extraction["edges"].size())
print("PASS: isolated 2-block cluster produces exactly 6 edges")
```

Also add the **mixed-height case from Item 1's fix**, now assertable for real:
```gdscript
# Stone (3,3) 1-storey + Concrete (4,3) 2-storeys, isolated (no perimeter noise)
# Expected: the shared-boundary edge only covers storey 1 (start_storey=1, storey_count=1),
# not storey 0-1 (storey_count=2 starting at 0).
var mixed_wall_levels = [
	[ {"cell": Vector2i(3,3), "tile_name": "solidblock_stone"}, {"cell": Vector2i(4,3), "tile_name": "solidblock_concrete"} ],
	[ {"cell": Vector2i(4,3), "tile_name": "solidblock_concrete"} ],
]
var mixed_extraction = EdgeExtractorClass.extract({"wall_levels": mixed_wall_levels})
# Find the edge between (3,3) and (4,3)
var boundary_edge = null
for e in mixed_extraction["edges"]:
	if (e.gu_a == Vector2i(3,3) and e.gu_b == Vector2i(4,3)) or (e.gu_a == Vector2i(4,3) and e.gu_b == Vector2i(3,3)):
		boundary_edge = e
		break
assert(boundary_edge != null, "Boundary edge between mixed-height blocks must exist (exposed at storey 1)")
assert(boundary_edge.start_storey == 1, "Boundary edge must start at storey 1, not 0 (got %d) — phantom-floor bug" % boundary_edge.start_storey)
assert(boundary_edge.storey_count == 1, "Boundary edge must span exactly 1 storey (got %d)" % boundary_edge.storey_count)
print("PASS: mixed-height boundary edge correctly starts at storey 1, not 0 — phantom floor fixed")
```

This second assertion is the direct regression test for the bug found in verification — red before the fix (would show `start_storey` doesn't exist or `storey_count == 2`), green after.

## Item 3 — Real equivalence dump-diff (Item 4 of BLOCK-01, actually executed this time)

Follow the original procedure literally, no narrative substitute:

1. Build a small fixture with 3-4 solid blocks (reuse `TEST_BLOCKS.map.json` or extend it).
2. Render via the **old** path (`render_block()`/`_render_solid_blocks()` — still present, not yet deleted per BLOCK-01's conservative choice). Dump every occupied cell's `(grid_pos, level, source_id, atlas_coords)` from the relevant `TileMapLayer` to a sorted, deterministic text list.
3. Render via the **new** path (edge-based). Dump the same shape of data.
4. Diff the two dumps. Assert: **identical set of occupied `(grid_pos, level)` pairs restricted to boundary/exposed voxels** is not the right comparison (the old path fills the full interior, the new path doesn't) — instead assert (a) the new path's occupied set is a **subset** of the old path's, and (b) the new path's occupied count is **strictly less** for any block with an interior (i.e., bigger than 1×1 footprint doesn't apply here since blocks are single-GU — for single-GU blocks the interior-vs-boundary distinction is about the 8×8 voxel sub-grid within one GU, not about neighboring GUs, so "fewer voxels" means: old path fills all 8×8 (or however many) voxel positions per storey, new path only fills the ones that belong to exposed faces per the slice geometry). State the actual measured numbers in the completion report — don't assert a direction without printing the counts that prove it.

## Item 4 — Real baking assertion for a block

Mirror FIX-BAKE-09b's E2E structure exactly (that test is the project's proven template for this):
```gdscript
BakeConfigClass.enabled = true
var registry = MaterialRegistryClass.new()
registry.register_defaults()
Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", registry)

# Compile a map with one solidblock_stone entry, bake it
var spec = {"blocks": [{"gu": Vector2i(3,3), "material": "stone", "storeys": 1}], ...}
var layout = MapCompilerClass.compile(spec)
var extraction = EdgeExtractorClass.extract(layout)
var compositor = BakeCompositorClass.new()
var atlas = compositor.bake({"walls": extraction["edges"].map(func(e): return {"material_id": e.material, "facade_id": BakePolicyClass.facade_for_material(e.material), "edge": e})}, TextureResolverClass.new())

assert(atlas.pages.size() > 0, "Block-derived edges must produce at least one baked page")

var lookup = BakedTileLookupClass.new()
Engine.set_meta("GLOBAL_BAKED_ATLAS", atlas)
var block_edge = extraction["edges"][0]  # any edge derived from the block
var result = lookup.resolve(block_edge, 0, Vector2i.ZERO)
assert(result.source_id.begins_with("BAKED_ATLAS_"),
	"Block edge must resolve to a baked hit, got '%s' — Rule #8 compliance not proven" % result.source_id)
print("PASS: solid block reaches the bake seam exactly like a wall — BAKED_ATLAS hit confirmed")
```

Restore `BakeConfig.enabled = false` after the test, per the project's standing safety rule (never ship with baking on by default).

## Item 5 — Actually run the invariants and lint

```bash
python3 tools/persistent/check_invariants.py
godot --headless --script godot/scripts/tools/map_lint.gd
```
Paste both raw outputs. If either was never run for BLOCK-01, this is the first real execution — treat any failure found now as pre-existing, not something this prompt introduced, and report it rather than silently fixing scope creep.

---

## Validation & Evidence (PASS criteria)

1. **Item 2's two tests, verbatim transcripts, both the isolated-6-edges case and the mixed-height regression case** — the second one is the direct proof the phantom-floor bug is fixed. If possible, show it failing before the `Edge`/`EdgeExtractor` fix (comment out the fix, run, paste the assertion failure; restore, run, paste the pass) — the red-then-green standard this project has used for its clearest fixes.
2. **Item 3's actual printed counts** for old-path vs. new-path voxel dumps, with the diff shown, not narrated.
3. **Item 4's baking transcript**, ending in the literal `BAKED_ATLAS_` hit line.
4. **Item 5's raw `check_invariants.py` and `map_lint.gd` output.**
5. Confirm no existing wall behavior changed: rerun BLOCK-01's SIGMA_01 non-regression check (3 lights, 687 tiles) — the one piece of BLOCK-01 evidence that was already genuinely verbatim — and confirm it's still identical after the `Edge` field addition.
6. Archive with **all raw transcripts pasted directly in the completion report body** — restating this a third time because it's the standard, not because it's been ignored maliciously, but because summaries keep rounding up what reports honestly qualify.

## Implementation Checklist

- [ ] Item 1: `start_storey` added to `Edge`; `EdgeExtractor` tracks min+max storey for solidblock edges; `SliceGenerator`/`voxel_renderer` render the actual range
- [ ] Item 2: isolated 6-edge test + mixed-height regression test (red-then-green if practical)
- [ ] Item 3: real dump-diff with printed counts
- [ ] Item 4: real baking E2E for a block edge
- [ ] Item 5: `check_invariants.py` + `map_lint.gd` actually executed
- [ ] Item 6: SIGMA_01 non-regression reconfirmed
- [ ] All transcripts verbatim in the completion report
- [ ] Archive to `PROMPTS/DONE/`; bump VERSION

## Out of scope

Deleting the old `render_block()`/`_render_solid_blocks()` path (still gated behind the equivalence proof landing cleanly here — can retire next prompt if this one's dump-diff is clean); JunctionResolver changes (still deferred to PLAYGROUND-02 visual QA, unaffected by this fix); PROP-01.

---

*End BLOCK-01b.*
