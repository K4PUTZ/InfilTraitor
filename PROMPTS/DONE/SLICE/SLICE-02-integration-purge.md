# SLICE-02 — Integration + Legacy Deletion (Subcube Purge)

> **Series:** SLICE — third prompt. Requires SLICE-01 accepted (geometry module green,
> game untouched).
> **Nature:** Destructive by design, staged for safety. Stage A wires the new module and
> proves parity; Stage B deletes the legacy ONLY after Stage A's smoke test passes.
> If Stage A parity fails, STOP after reporting — do not begin Stage B.
> **Anchors:** function-level on purpose (room.gd changed in SLICE-00/01 sessions).
> Locate by function name, verify signature matches the description before editing.

---

## CONTEXT

The geometry module (`godot/scripts/geometry/`) is complete, selftested, and dormant.
This session makes it the ONLY wall-rendering path and removes the legacy: the subcube
plane, the WallContainer remnants, the old voxel identity classes, and every mention of
"subcube" outside historical archives. After this prompt, grep for "subcube" in live code
returns zero — the vocabulary reform is done and the codebase matches Engine Geometry
Architecture 1.0.

Pipeline after this session:

```
MapCompiler.compile() → EdgeExtractor.extract() → SliceGenerator.generate()
    → JunctionResolver.resolve() → VoxelRenderer.render()
TIC: room turn loop → VoxelRenderer.process_dirty(registry)
```

---

## MODULE

`godot/scripts/world/room.gd` (surgery + deletions), `room.tscn` untouched, file deletions
in `world/` and `tools/`, documentation sync. One session, two gated stages.

---

## STAGE A — Integration (parity gate)

### A-T1 — Wire the module in room.gd

1. Add member vars: `_edge_registry: EdgeRegistry`, `_junction_columns: Array`,
   `_voxel_renderer: VoxelRenderer`.
2. In `_ready()` (after the tileset loads): instantiate `_voxel_renderer`, `add_child`,
   `setup(VISUAL_GRID_OFFSET)` — pass `WALL_BASE_Z_INDEX` if the setup signature takes it.
3. In `_build_room()`, locate the block that currently branches on
   `not subcube_geometry.is_empty() and _subcube_tileset != null` (the condition has a
   second clause beyond the subcube-emptiness check — verify both before editing) and
   REPLACE the entire voxel/subcube branch with:

```gdscript
var extraction: Dictionary = EdgeExtractor.extract(layout)
_edge_registry = EdgeRegistry.new()
SliceGenerator.generate(extraction["edges"], _edge_registry)
_junction_columns = JunctionResolver.resolve(_edge_registry)
_voxel_renderer.clear()
_voxel_renderer.render(_edge_registry, _junction_columns)
_render_solid_blocks(extraction["solid_blocks"])   ## A-T2
structure_wall_layer.visible = false
for layer in _wall_upper_layers:
	layer.visible = false
```

Keep the legacy `wall_levels` else-branch INTACT during Stage A (fallback if extraction
is empty) — it dies in Stage B.

### A-T2 — Solid blocks on the voxel plane (floating-geometry ready)

`EdgeExtractor.extract()` emits `solid_blocks` as ONE ENTRY PER STOREY OCCURRENCE
(`{"gu_cell", "storey", "material", ...}` — no merging, unlike edges). This is
intentional: the legacy `_paint_subcube_descriptor` already paints blocks at their exact
storey independent of floor 0 (`layer_index = storey * SUBCUBES_PER_UNIT_AXIS +
local_level`), which is how ceiling props, chandeliers, and any future floating geometry
will be authored — a block can exist at storey 2 with nothing at storeys 0–1. The new
path must preserve this, not silently assume every block is ground-anchored.

`VoxelRenderer.render_block(gu_cell, start_level, storey_span, material_name)` now takes
an explicit `start_level` (already updated in the module — this is the one exception in
DO NOT TOUCH). New function `_render_solid_blocks(blocks: Array) -> void` in room.gd:

1. Group `blocks` by `(gu_cell, material)`.
2. Within each group, sort by `storey` ascending.
3. Split into maximal **contiguous runs** (consecutive storey values, no gaps) — e.g.
   storeys `[0,1,2]` → one run; storeys `[0,1,3]` → two runs (`[0,1]` and `[3]`), because
   a gap means the block is not physically continuous (a chandelier at storey 3 with
   nothing below it must not be rendered as if it spans 0–3).
4. For each run, call `_voxel_renderer.render_block(gu_cell, run_start_storey,
   run.size(), material)` — one call per contiguous run, not per raw entry and not one
   merged call per cell.

This replaces `_render_subcube_geometry` / `_paint_subcube_descriptor` for the `block_*`
tiles (dividers included — verify SIGMA/PLAYGROUND dividers still render, and that any
current test map with a multi-storey block still renders identically). No current map is
known to use non-contiguous blocks yet, but the grouping-by-run logic must be correct
from this session on — do not special-case "assume storey 0" anywhere in
`_render_solid_blocks`.

**Note:** `_build_wall_containers()` (and `WallContainerClass`) is confirmed DEAD CODE
already — it is only referenced by its own definition and by an archival comment in
`_place_wall_voxels` ("Substitui _build_wall_containers() (arquivada — NÃO apagar)").
It's never called. Deleting it in Stage B carries zero rendering risk.

### A-T3 — TIC rewire

Locate `_tic_voxel_system()` and replace its body with a delegation:
`_voxel_renderer.process_dirty(_edge_registry)` (plus the junction-column dirty pass if
the old body handled extras separately). Keep the function name and call site for now.

### A-T4 — Parity smoke test (GATE)

Run the game on PLAYGROUND and SIGMA_01 with `wall_height_override` 1 and 3:

- Wall ring sits exactly on the playable boundary (SLICE-00 alignment preserved — the
  SLICE-00 probe function, if still present, must log zero deltas).
- Doors are gaps; dividers and blocks render; L-corners show junction columns (no gaps);
  multi-storey walls stack at 160 px per storey.
- Toggle a voxel via registry in a debug call (`sibling_slice` of any slice →
  `get_voxel(0).set_visible(false)`) → next TIC hides exactly that voxel.
- Screenshot each configuration.
- No map today exercises a non-contiguous solid block (floor 0 empty, floor 2 occupied),
  so this can't be visually verified yet — but confirm `_render_solid_blocks`'s
  run-grouping logic (A-T2) doesn't assume storey 0 anywhere, since ceiling props and
  chandeliers will depend on it soon.

**Gate:** any parity failure → report with screenshots and STOP. Stage B forbidden.

---

## STAGE B — Deletion (only after A-T4 passes)

### B-T1 — Delete legacy files

```
godot/scripts/world/wall_container.gd        (+ .uid)
godot/scripts/world/maps/subcube_geometry.gd (+ .uid)
godot/scripts/world/wall_slice.gd            (+ .uid)
godot/scripts/world/voxel_ref.gd             (+ .uid)
godot/scripts/world/high_wall.gd             (+ .uid)
godot/scripts/world/voxel_registry.gd        (+ .uid)
godot/scripts/world/subcube_coords.gd        (+ .uid)   ## after B-T2
godot/scripts/tools/subcube_geometry_selftest.gd (+ .uid)
godot/scripts/tools/voxel_selftest.gd        (+ .uid)   ## superseded by geometry_selftest
```

### B-T2 — Purge subcube references from survivors

- **room.gd:** delete `_build_subcube_tileset`, `_ensure_subcube_layers`,
  `_render_subcube_geometry`, `_paint_subcube_descriptor`, `_place_wall_voxels`,
  `_voxel_slice_positions`, `_build_voxel_junction_extras`, `_has_any`, `_max_storey_of`,
  `_add_junction_extra`, `_build_high_walls`, `_build_voxel_tileset`,
  `_ensure_voxel_layers`, the old member vars they used (`_subcube_*`, `_voxel_layers`,
  `_voxel_tileset`, `_voxel_tile_ids`, `_voxel_wall_slices`, `_voxel_junction_extras`,
  `_voxel_registry`), the legacy `wall_levels` else-branch of A-T1, and every
  `SubcubeCoordsClass` reference (replace survivors with `GeometryCoords`). Delete the
  `_build_wall_containers` archive-comment references. Remove the SLICE-00 probe function
  and its export flag (its assertions live on in the selftests).
- **coord_selftest.gd:** port any still-valid checks to `GeometryCoords` names or fold
  them into `geometry_selftest.gd`; delete the file if fully superseded.
- **slice_geometry_selftest.gd (SLICE-00):** repoint its constant reads from
  `SubcubeCoordsClass` to `GeometryCoords`; all 5 check groups must still pass.
- **tile_registry.gd** and any other survivor flagged by the A3 grep: rename/remove
  subcube-named identifiers, preserving behavior.
- **build_tileset.gd / build_voxel_tileset.gd (tools):** if `build_voxel_tileset.gd`
  duplicates what VoxelRenderer now builds at runtime, delete it; otherwise repoint to
  GeometryCoords.

### B-T3 — Documentation sync

1. `docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md`: replace §2 (Vocabulary and
   Object Hierarchy) with the Engine Geometry Architecture 1.0 hierarchy
   (GU → Face → Slice → Voxel; Wall = logical Edge relationship; Edge Registry schema).
   Move Subcube terms to a "Superseded vocabulary" note pointing at docs/history.
2. Delete the stale duplicate `PROMPTS/VOXEL_MASTER_PLAN.md`; move
   `PROMPTS/SLICE_MASTER_PLAN.md` to `PROMPTS/DONE/` (its content now lives in the master
   plan).
3. `docs/production/current_state.md`: add a SLICE-00..02 section (transform canon,
   geometry module live, subcube plane removed).
4. `docs/history/VOXEL_IMPLEMENTATION_LOG.md`: append SLICE-00..02 entries in the
   established format.
5. Regenerate `tools/persistent/CODEMAP.md` via `gen_codemap.py` if that is its workflow.

### B-T4 — Final smoke test

Repeat A-T4's matrix. Additionally launch once with `map_id = "PROCEDURAL"` to confirm no
legacy path is reached. Console must show zero `push_warning` from removed systems.

---

## DO NOT TOUCH

- `FloorLayer`, `tileset_blocks.tres`, canonical anchor table, overlays, agent, FOW,
  lighting, guards, TicSystem scheduling, `blocked_cells` / `blocked_edges` — the gameplay
  plane is frozen (Canon 1).
- `MapCompiler`, `MapGeometry`, `MapCatalog` — the compiler still emits `wall_levels`;
  making it emit Edges natively is SLICE-03.
- `godot/scripts/geometry/` — the module is consumed, not edited, this session (if an API
  gap blocks integration, STOP and report instead of patching the module ad hoc; exception:
  `render_block` from A-T2, which is in scope).
- `docs/history/` and `PROMPTS/DONE/` contents — archives keep their subcube mentions.

---

## ACCEPTANCE

- **A1 (the purge):** `grep -rin "subcube" godot/ tools/ --include="*.gd" --include="*.py"
  --include="*.tres" --include="*.tscn"` → ZERO matches.
  `grep -rin "subcube" docs/ --exclude-dir=history` → matches only in the "Superseded
  vocabulary" note of the master plan (or zero).
- **A2:** `grep -rn "WallSlice\|VoxelRef\|VoxelRegistry\b\|SubcubeCoordsClass" godot/` →
  ZERO matches (old class names fully replaced by Slice/Voxel/EdgeRegistry/GeometryCoords).
- **A3:** `grep -n "EdgeExtractor.extract\|SliceGenerator.generate\|JunctionResolver.resolve\|_voxel_renderer.render" godot/scripts/world/room.gd` → all four present in `_build_room`.
- **A4:** Selftests: `geometry_selftest.gd` AND `slice_geometry_selftest.gd` both exit 0
  headless.
- **A5:** Parity screenshots from A-T4 and B-T4 attached; alignment intact; dirty-toggle
  demo works.
- **A6:** room.gd line count reported before/after (expect a significant reduction; report
  the numbers).
- **A7:** Godot loads clean on all three map ids; PROBLEMS tab clear; no new warnings.
- **A8:** `git status` matches the declared file set: room.gd modified, listed files
  deleted, docs updated, nothing else. Deviations = abort and report.
- **A9:** If Stage A gate failed: Stage B untouched, parity report delivered, A1/A2/A6
  waived.

Do not commit automatically.
