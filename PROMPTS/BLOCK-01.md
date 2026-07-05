# BLOCK-01: Solid GU Blockers — Real Edge-Based Pipeline

**Status:** Ready for implementation
**Predecessor:** MAP_MATTRESS_MASTER_PLAN v1.1 §2.1 (D16 ratified — see above); MAPFILE-02 (verified, with one open item this prompt closes)
**Successor:** PROP-01 (parallel-safe) → PLAYGROUND-02 (District D visual QA)
**Scope:** Replace the current voxel-cube-fill solid-block implementation with a real Edge/Slice-based one, so blocks get baking/theming/exposed-face rendering for free (the master plan's original promise, which the current code does not deliver); fix a tile-name collision found during investigation; wire the `.map.json` `blocks` section all the way through.
**Effort:** ~6 hours (larger than originally estimated — investigation found the existing "solid block" code is a disconnected placeholder, not a partial implementation)
**Risk:** Medium-high (touches the edge-extraction core that walls also depend on; every change here is validated against SIGMA_01's existing dividers as a non-regression fixture)

---

## Item 0 — MANDATORY READING: ground truth is not what the master plan assumed

**Read fully before writing code.** The master plan's §2.1 said solid blocks would be "a natural extension of `EdgeExtractor`" that render via `_set_voxel_cell()` and "get baking, themes, and destructibility semantics for free." Investigation of the actual v0.4.13 code shows **none of that is true today** — the existing "solid block" path is a separate, disconnected placeholder:

### Finding A: solid blocks bypass Edge/Slice/bake entirely

`EdgeExtractor.extract()`'s `block_` branch does **not** create Edge objects. It appends a flat dict (`gu_cell`, `storey`, `material`, ...) straight to `result["solid_blocks"]`, skipping the `edge_groups` dedup dictionary that real walls go through. `room_builder._render_solid_blocks()` (the version ported from `room.gd` per our last session's decision) then calls `_voxel_renderer.render_block(gu_cell, start_level, span, material_name)`, which:
```gdscript
func render_block(gu_cell, start_level, storey_span, material_name):
	for level in range(start_level, start_level + storey_span):
		for voxel_pos in GeometryCoords.gu_voxels(gu_cell):   # ALL voxels in the GU
			_set_voxel_cell(voxel_pos, level, material_name)   # NO edge, NO voxel_xy, NO face
```
This fills **every voxel of the entire GU volume** (not just exposed boundary faces — the master plan's "exposed boundary faces only" is unimplemented) and calls `_set_voxel_cell()` with **no `edge` argument**. Recall the seam built in FIX-BAKE-05: baked lookup is only attempted when `edge != null`. **Solid blocks can never be baked or themed today, regardless of `BakeConfig.enabled`.** This isn't a bug in the sense of "wrong output" — it works, renders, blocks pathing — but it is architecturally a dead end for everything this master plan wants from materials/baking, and it wastes voxels rendering fully-solid interiors that are never visible.

### Finding B: a real tile-name collision, `block_SE` vs. the intended `block_<material>`

`MapCompiler`'s **existing divider system** (used today by SIGMA_01, unrelated to this master plan) emits `wall_tiles.append({"cell": cell, "tile_name": "block_SE"})` for every divider cell — `"SE"` here is a **sprite-style suffix** (matches the wall-tile naming convention `wall_NW`/`wall_NE`/etc.), not a material id. `EdgeExtractor`'s `block_` branch does `material := tile_name.substr(6)` — for `"block_SE"` this evaluates to `material = "SE"`, a nonsense material id that doesn't exist in `MaterialRegistry`. **Every divider cell in every existing map (including SIGMA_01, in active use) is currently being misclassified as a solid_block with a bogus material** the moment `EdgeExtractor` scans it. This has presumably been harmless so far only because the resulting bogus `solid_blocks` entries get rendered by the same blind `render_block()` path (which ignores `material_name` beyond a string lookup that probably falls through to a default) — but it means **the `block_` prefix is already ambiguous in production data**, and this prompt cannot reuse it for the new full-GU-multi-storey-material concept without deconflicting first.

**Decision (ratified now, not deferred):** the new primitive uses a **distinct prefix, `solidblock_<material>`** (e.g. `solidblock_stone`), leaving the existing `block_SE` divider convention completely untouched. Lower blast radius than trying to retrofit or rename the divider system, which is live and working. `EdgeExtractor` will recognize `solidblock_` as its own branch, separate from the legacy `block_` handling (which stays exactly as-is — do not touch it, do not "fix" its material misclassification as part of this prompt; it's out of scope and stable in its current, if oddly-named, usage).

### Finding C: JunctionResolver is probably a non-issue here (verify, don't assume)

The master plan said solid blocks would need "`solid_interior` flag so JunctionResolver treats corners as filled, not V-junctions." Reading `junction_resolver.gd`: it's explicitly scoped to **pure V-junctions only (exactly 2 edges meeting at one cell)** and does nothing for T/X junctions today (documented exclusion, not a bug). A solid block's own 4 synthesized perimeter edges meet at the block's own 4 corners **as exactly 2 edges each** — the same shape as a real 2-wall corner. This suggests solid blocks' self-corners likely resolve correctly through the **existing, unmodified** JunctionResolver with no new casing needed. Where a block's edge meets an unrelated real wall's edge at a T/X configuration, that's already outside JunctionResolver's scope for walls-only junctions too — not a regression this prompt introduces. **Do not add speculative solid-interior branching to JunctionResolver in this prompt.** Defer any actual fix to a targeted follow-up **only if** PLAYGROUND-02's District D (Blocker Field) visual QA finds a real defect. Coding around a hypothetical case that verification suggests doesn't exist would repeat this project's worst pattern (unverified assumptions compounding).

---

## Item 1 — `MapCompiler`: accept a `blocks` spec key

Mirror the existing `dividers` handling (`map_compiler.gd`, same section) — this closes the translation gap MAPFILE-02 flagged with a loud warning:

```gdscript
## --- solid GU blockers (full-cell, multi-storey, material-aware) ---------
for block: Dictionary in spec.get("blocks", []):
	var cell: Vector2i = Vector2i(block.get("gu", Vector2i.ZERO)) + offset
	if blocked_map.has(cell):
		continue
	var storeys: int = maxi(1, int(block.get("storeys", 1)))
	var material: String = String(block.get("material", "concrete"))
	for storey in range(storeys):
		while wall_levels.size() <= storey:
			wall_levels.append([])
		wall_levels[storey].append({"cell": cell, "tile_name": "solidblock_%s" % material})
	blocked_map[cell] = true
```

Place this alongside the divider loop (same section of `compile()`), after dividers so a `blocks` entry can't silently collide with a divider cell (the `blocked_map.has(cell): continue` guard handles that the same way dividers already guard against room/perimeter overlap).

**`_blocked_cells` stays single-writer (M4 intact):** this only adds to `blocked_map`, which already flows through the one existing path into `layout["blocked_cells"]` → `room_builder._cache_blocked_cells()`. No new writer introduced.

## Item 2 — `EdgeExtractor`: solid blocks become real Edges

Replace the flat-dict `block_` output for the **new** prefix only (leave the legacy `block_` branch untouched per Item 0 Finding B):

1. **First pass:** collect all `solidblock_` entries across all storeys into an occupancy map: `Dictionary[(gu_cell, storey)] -> material`. Needed before emitting any edges, so face-culling (step 2) can check neighbors regardless of scan order.
2. **Second pass, per occupied `(gu_cell, storey)`:** for each of the 4 face directions, check the neighbor cell `gu_cell + Face.delta(face)` at the same storey:
   - If the neighbor is **also** `solidblock_`-occupied at this storey → **skip this face** (buried, would never be visible; this is the "adjacent solid blocks merge" requirement — a natural byproduct of exposure culling, not a separate merge step).
   - Otherwise → synthesize `Edge.between(gu_cell, neighbor_cell, 1, material)` and feed it into the **same `edge_groups` dictionary** real walls already use (identical dedup-by-canonical-key mechanism, so a wall and a block sharing a boundary resolve exactly like two walls would).
3. Storey handling: reuse the existing `max_storey` tracking in `edge_groups` — a block's edges at storeys 0–2 register into the same group-then-max-storey machinery walls already use, so a 3-storey block produces edges with `storey_count = 3`, not three separate 1-storey edges.
4. **Non-regression guard:** the legacy `block_` (divider) branch must produce byte-identical output before and after this change — Finding B's collision is real but explicitly out of scope for repair here. Add a test that compiles SIGMA_01, extracts, and diffs the `solid_blocks`/edges output against a pre-change snapshot (see Validation Item 2).

## Item 3 — Voxel rendering: blocks route through the same pipeline walls use

With blocks now emitting real `Edge` objects into the same `EdgeRegistry`, they flow through `SliceGenerator.generate()` → `JunctionResolver.resolve()` → `_voxel_renderer.render(edge_registry, junction_columns)` → `_render_slice(slice, edge)` → `_set_voxel_cell(..., edge, voxel_xy, face)` **with zero new rendering code** — this is the entire point of Finding A's fix. `render_block()` and `room_builder._render_solid_blocks()` become dead code once this is verified equivalent (Item 4).

**This is the mechanism that finally delivers the master plan's promise:** baking, theming, and (later) per-voxel destructibility apply to solid blocks automatically, because they're now indistinguishable from walls at the rendering layer — the entire reason Rule #8 ("`_set_voxel_cell()` only") exists.

## Item 4 — Retire the old path, after proof of equivalence

Do **not** delete `render_block()` / `_render_solid_blocks()` blind. Sequence:
1. Build a small fixture map (or reuse a PLAYGROUND variant) with 3–4 solid blocks in varied configurations (isolated single, 2×2 cluster, multi-storey).
2. Render it through the **old** path, screenshot/log the resulting voxel cell grid (source_id + atlas_coords per cell, dumped via a headless script — not a visual screenshot, a data dump for exact comparison).
3. Switch to the **new** path (Items 1–3), render the same map, dump the same data.
4. Diff: the new path should show identical *occupied* cells (footprint match) and superior interior efficiency (fewer total `set_cell` calls, since interior voxels are no longer filled) — assert both.
5. Only after this comparison passes: delete `render_block()`, `room_builder._render_solid_blocks()`, and `room.gd`'s `_render_solid_blocks_DEPRECATED` (final cleanup of the split-brain from our last session — it was renamed-and-kept then; this is where it actually goes away, once nothing needs its behavior as a reference).

## Item 5 — `FileMapSource` translator: close the `blocks` warning

In `_translate_to_runtime_spec()` (MAPFILE-02), the `blocks` section currently only triggers the "no translation yet" warning. Add the real translation now that Item 1 gives it somewhere to go:

```gdscript
var blocks_section = sections.get("blocks", {})
if blocks_section.get("items", []).size() > 0:
	runtime["blocks"] = blocks_section["items"]
```
Remove `"blocks"` from the loud-warning loop's list (`["walls", "blocks", "props"]` → `["walls", "props"]`) — it's no longer untranslated. Add a golden-file regression: extend `SIGMA_01.map.json` (or a new small fixture) with one `blocks` entry, confirm it round-trips and actually produces a rendered blocker when compiled.

---

## Validation & Evidence (PASS criteria)

1. **Item 0 write-up** (Findings A/B/C) reproduced in the completion report with the `solidblock_` naming decision stated explicitly — same discipline as MAPFILE-02's Item 0.
2. **Non-regression: SIGMA_01 divider output unchanged.** Dump `EdgeExtractor.extract()`'s output for SIGMA_01 before and after this prompt's changes; diff must be empty for anything derived from `block_SE` divider tiles. This is the test that protects Finding B's untouched-scope decision.
3. **Face-culling proof (the core new behavior):** a 2-cell-wide solid block cluster (two adjacent `solidblock_stone` GUs, same storey) must produce edges only on the **outer perimeter** — for two adjacent cells that's 6 edges (4 sides each, minus the 2 shared/canceled internal ones), not 8. Assert the exact count; this is the regression trap for exposure culling silently not culling.
4. **Baking integration (Rule #8 proof):** bake a map containing one `solidblock_stone` entry with `BakeConfig.enabled = true`; assert at least one of its voxels resolves to a `BAKED_ATLAS_` hit — the same style of hard assertion used in FIX-BAKE-09b's E2E test, now proving blocks (not just walls) reach the bake seam.
5. **Equivalence proof (Item 4):** the old-path vs. new-path cell-grid dump diff, showing identical footprint and reduced total cell count for the interior-fill elimination.
6. **`blocks` section end-to-end:** a `.map.json` with a `blocks` entry loads via `MapCatalog.get_spec()`, compiles via `MapCompiler.compile()` without error, and the resulting `blocked_cells` contains the block's GU — full round-trip from file to gameplay-blocking.
7. `check_invariants.py` and `map_lint.gd` stay green.
8. **Archive completion evidence as its own reviewable content** (verbatim transcripts pasted in the completion report) — restating this explicitly per the process gap found in MAPFILE-02's verification.

## Implementation Checklist

- [ ] Item 0: findings write-up, `solidblock_` prefix decision recorded
- [ ] Item 1: `MapCompiler` accepts `blocks` spec key, mirrors divider pattern, guards against cell collision
- [ ] Item 2: `EdgeExtractor` — occupancy pre-pass, face-culling, edges fed into existing `edge_groups` dedup; legacy `block_` branch untouched
- [ ] Item 3: confirm blocks render via the existing `SliceGenerator`/`JunctionResolver`/`_render_slice` pipeline with no new rendering code
- [ ] Item 4: equivalence proof against old path; only then delete `render_block()`, both `_render_solid_blocks` copies (including the `_DEPRECATED` one)
- [ ] Item 5: `FileMapSource` translates `blocks` section; warning list updated; golden fixture extended
- [ ] All 8 validation items produce verbatim transcripts in the completion report
- [ ] Archive to `PROMPTS/DONE/`; bump VERSION

## Out of scope

Actually fixing the `block_SE`/material-id collision in the legacy divider path (Finding B — flagged, not repaired; low priority since it's cosmetically wrong but not behaviorally broken today); any JunctionResolver changes (Finding C — deferred to visual QA); PROP-01 (parallel, unrelated primitive); the cover ladder / destructibility mechanics (§2.3, next phase).

---

*End BLOCK-01.*
