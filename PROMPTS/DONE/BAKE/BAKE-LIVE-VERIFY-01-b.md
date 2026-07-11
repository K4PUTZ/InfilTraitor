# BAKE-LIVE-VERIFY-01-b — Real fix for the live baked-rendering gap

> **This is a corrective prompt.** `BAKE-LIVE-VERIFY-01`'s completion report
> claimed the live rendering gap (Finding 2) was fixed and wired end-to-end.
> The Director re-tested F6 in the running editor immediately after that
> commit landed: **still flat, uniform, no facade anywhere** — same symptom,
> unchanged. The Overlord traced this statically (git evidence below); it
> was **not** re-verified live before being reported complete. This prompt
> requires live, printed evidence at every step — no step is done until its
> own acceptance criterion is pasted, not summarized.

---

## CONTEXT — two independent bugs, both must be fixed

### Bug A (the real one): production code never populates the data
### `BakedTileLookup.resolve()` actually reads from

`BakedTileLookup._resolve_baked_strip()` needs two pieces of global state to
ever succeed, both read via legacy `Engine.get_meta()` lookups:

- `_get_baked_atlas()` (`baked_tile_lookup.gd:200`) reads
  `Engine.get_meta("GLOBAL_BAKED_ATLAS")` — returns `null` if unset.
- `_get_baked_atlas_source_id()` (`baked_tile_lookup.gd:190`) reads
  `Engine.get_meta("BAKED_ATLAS_SOURCE_IDS")` — returns `-1` if unset.

`grep -rn "BAKED_ATLAS_SOURCE_IDS\|GLOBAL_BAKED_ATLAS" godot/scripts/` shows
**every** `Engine.set_meta()` call for either key lives in a test file
(`fix_bake_09_e2e_test.gd`, `fix_bake_09b_e2e_test.gd`,
`block_01b_baking_e2e_test.gd`). `room_builder.gd::_bake_textures()` — the
only place that runs during real gameplay — never sets either. The one call
that used to do this equivalent job is commented out at
`room_builder.gd:388`: `# Registries.set_baked_atlas(baked_atlas, source_ids, ...)`,
tagged `# TODO: Fix Registries reference (FIX-SHUTDOWN-CRASH-01)` — and
never restored.

Net effect: in real gameplay, `_resolve_baked_strip()` always returns `null`
at its very first check (`_get_baked_atlas() == null`), `resolve()` always
falls through to `_resolve_generic()` (material-only), for every material,
every time — independent of anything about metal alpha or the
`set_baked_lookup()` wiring `BAKE-LIVE-VERIFY-01` added. That wiring passes
a `BakedTileLookup` instance to `voxel_renderer`, which is necessary but not
sufficient — the instance's `resolve()` still reaches for the same
never-populated globals.

**This is traced statically from the code (grep + read), not yet confirmed
with a live print during an actual map load — Part 1 below is that
confirmation, do it first and paste the real output before touching any
fix.**

### Bug B: baked atlas pages are registered on the wrong `TileSet`

`_register_baked_atlas_page()` (`room_builder.gd:414-429`) adds each baked
page as a source on `_wall_tileset` — the `TileSet` built in `room.gd` and
passed into `room_builder.setup()` (`room.gd:401`), used only by the legacy
wall-storey layers (`structure_wall_layer`, `_wall_upper_layers`), which are
explicitly hidden (`.visible = false`) once the edge/slice voxel pipeline is
active (`room_builder.gd:83-85`).

The layers that actually render voxels (`voxel_renderer.gd`'s
`_voxel_layers`) use a **separate** `TileSet` built internally in
`_build_voxel_tileset()` (`voxel_renderer.gd:75`) and assigned via
`layer.tile_set = _tileset` (`voxel_renderer.gd:356`). Confirmed via
`room.gd`: `_room_builder.setup(..., ts)` (line 401, a locally-built
`TileSet`) happens before `_voxel_renderer.setup(...)` (line 410, which
builds its own).

Even after Bug A is fixed and `resolve()` starts returning a real
`source_id_int`, that ID refers to a source registered on the wrong
`TileSet` — the voxel layers' own `TileSet` never received it, so
`layer.set_cell(pos, source_id, ...)` references a source that doesn't
exist there.

---

## MODULE

- `godot/scripts/systems/baked_tile_lookup.gd`
- `godot/scripts/world/builders/room_builder.gd`
- `godot/scripts/geometry/voxel_renderer.gd`

---

## TASK

### Part 1 — Confirm both bugs live, with real printed output, before fixing anything

Add temporary `print()` statements (or a small standalone headless trace
script, your call) that, during an **actual `room.load_map("PLAYGROUND")`
with `BakeConfig.enabled = true`**:

1. Right after `_bake_textures()` runs, print whether
   `Engine.has_meta("GLOBAL_BAKED_ATLAS")` and
   `Engine.has_meta("BAKED_ATLAS_SOURCE_IDS")` are true or false.
2. Print the `source_id` that `_register_baked_atlas_page()` actually
   registers each page under, and separately print
   `room._voxel_renderer.get_tileset().get_source_count()` vs
   `_wall_tileset.get_source_count()` right after baking — confirm they
   diverge (the baked pages show up in one but not the other).
3. Call `_baked_lookup.resolve(edge, face, voxel_xy)` for a handful of real
   wall voxels from the loaded map and print the result (`null` or the
   `TileLookupResult`'s fields).

Paste this real output in the completion report. If either bug doesn't
reproduce as described above, **stop and report** rather than proceeding
with a fix aimed at the wrong cause.

### Part 2 — Fix Bug A: thread real atlas data through the lookup instance

`BakedTileLookup` already has `set_baked_atlas(atlas)`
(`baked_tile_lookup.gd:50`) which does the right thing
(`Engine.set_meta("GLOBAL_BAKED_ATLAS", atlas)`) — it's just never called in
production. There's no equivalent setter for the source-id map yet.

1. Add to `baked_tile_lookup.gd`:
   - `var _source_ids: Dictionary = {}` (instance field)
   - `func set_source_ids(source_ids: Dictionary) -> void: _source_ids = source_ids`
   - In `_get_baked_atlas_source_id()`, check `_source_ids` first
     (`if _source_ids.has(page_idx): return _source_ids[page_idx]`), fall
     back to the existing `Engine.get_meta("BAKED_ATLAS_SOURCE_IDS")` path
     only if `_source_ids` is empty — preserves the existing test files'
     behavior (they inject via `Engine.set_meta` directly and don't call
     the new setter).
2. In `room_builder.gd::_bake_textures()`, on the **one** `BakedTileLookup`
   instance that gets passed to `voxel_renderer` (see Part 4 — there are
   currently two instances created, only one is used), call
   `lookup.set_baked_atlas(baked_atlas)` and `lookup.set_source_ids(source_ids)`
   before `room._voxel_renderer.set_baked_lookup(lookup)`.

### Part 3 — Fix Bug B: register baked pages on the renderer's own TileSet

Add a proper method to `voxel_renderer.gd` (don't reach into `_tileset` via
`get_tileset()` from outside — that getter is documented as
diagnostics/tests-only, not a mutation seam):

```gdscript
## Register a baked atlas page as a source on this renderer's own TileSet.
## Returns the assigned source_id.
func register_baked_atlas_page(page_image: Image) -> int:
    var source := TileSetAtlasSource.new()
    source.texture = ImageTexture.create_from_image(page_image)
    source.texture_region_size = Vector2i(GeometryCoords.VOXEL_ATOM_W, GeometryCoords.VOXEL_ATOM_H)
    var source_id := _tileset.get_next_source_id()
    _tileset.add_source(source, source_id)
    return source_id
```

Update `room_builder.gd::_register_baked_atlas_page()` (or its call site in
`_bake_textures()`) to call `room._voxel_renderer.register_baked_atlas_page(page_image)`
instead of registering on `_wall_tileset`. `_wall_tileset` registration can
be removed entirely for baked pages — nothing reads baked sources from it
(confirm this with a grep before deleting; if something legacy still does,
stop and report rather than silently dropping it).

### Part 4 — Remove the dead duplicate lookup

`room_builder.gd` currently creates **two** separate `BakedTileLookup`
instances: one inside `_register_runs_with_lookup()` (created, registers
runs, then discarded — the `Registries.set_baked_tile_lookup(lookup)` call
that would have kept it alive is also commented out) and one directly
inside `_bake_textures()` (the one that reaches `voxel_renderer` via
`set_baked_lookup()`). Remove `_register_runs_with_lookup()` and its call
site entirely — it does nothing that the surviving lookup instance
(now correctly populated per Part 2) doesn't already do via
`lookup.register_runs(runs)`.

---

## DO NOT TOUCH

- `JUNCTION-COLUMN-NOFLIP-01`'s changes — unrelated, already correct.
- The metal-alpha fix from `BAKE-LIVE-VERIFY-01` (`bake_compositor.gd`'s
  `_load_real_voxel_atoms()` using `load()`/`get_image()`) — re-verify it
  still passes (Part 5 below) but don't touch its logic.
- `TextureResolver`'s tier-fallback chain — not implicated.
- The legacy `Engine.get_meta()` fallback paths in `baked_tile_lookup.gd` —
  keep them as a fallback for the existing test files that inject via
  `Engine.set_meta()` directly; don't rip them out, just stop relying on
  them being the *only* path for production.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## Part 1's live trace output — paste real output, not paraphrase

## Existing suites still green
godot --headless --script res://godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd
godot --headless --script res://godot/scripts/tools/bake_selftest.gd
godot --headless --script res://godot/scripts/tools/bake_fix_02_test.gd

## Re-run Part 1's live trace AFTER the fix — this is the real acceptance
## criterion, not the isolated suites above. Must show:
##   - Engine.has_meta(...) checks are now irrelevant (data comes from the
##     instance) OR true if you kept Engine.set_meta as well — either way,
##     resolve() must return non-null, real atlas_coords for real wall voxels
##   - voxel_renderer's own get_tileset().get_source_count() includes the
##     baked pages (not just _wall_tileset)
```

**Visual smoke test — this is the actual bar, not the scripts above.** Load
PLAYGROUND, F6 to enable bake. Take a screenshot. Distinct facade
texture/pattern must be visible per material — if it still looks flat and
uniform, **this prompt is not done**, regardless of what the automated
suites report. Paste the screenshot or a precise description of what
changed, matching what the Director will see when they check themselves.

---

**Scope:** 3 files · thread real atlas/source-id data into the lookup
instance already wired by `BAKE-LIVE-VERIFY-01`, register baked pages on the
correct `TileSet`, remove one dead duplicate code path. Split into 4 ordered
parts because Part 1's live confirmation determines whether Parts 2/3 are
even still accurate by the time this runs — don't skip it.
**Version:** bump `VERSION` per repo convention.
