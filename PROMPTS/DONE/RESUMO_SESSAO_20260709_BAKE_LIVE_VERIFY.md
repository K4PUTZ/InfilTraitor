# RESUMO SESSÃO: Bake System — First Live Verification Round (2026-07-08/09)

**Architect:** Claude (Overlord) · **Director:** Matt
**Status:** Structural pipeline confirmed working end-to-end for the first time; facade visual calibration open, next round's starting point
**Version at session end:** 0.4.50 (boot log); `project.godot` config/version still reads the pre-alpha placeholder, not bumped this session

---

## Context for a fresh session

This session started as a routine INSPECT round (sampling ladder verification
of everything since `verified/v0.4.24`) and pivoted into a live bug-hunt when
the Director, testing the map in the running editor, found two problems no
headless synthetic test had ever caught: junction corner-filler columns
visually offset from wall corners, and — far more significant — **every wall
material rendering as flat, uniform "concrete" with no facade texture at all**
when bake (F6) was enabled. The Director framed the second issue precisely:
"O baking system nunca foi visto até agora. Estamos... no momento de conferir
ele em ação." Every prior bake closure (including B3) was headless-synthetic
only; this was the system's first real map load in the real running game.

**Working pattern this session:** heavy direct Overlord investigation —
building throwaway headless probes (`--headless --path .` real project boot,
not `--script` mode, which doesn't resolve autoloads), reading crash reports,
pixel-sampling actual baked output — rather than issuing prompts and trusting
completion reports. Two Operator-applied corrective prompts this session
(`BAKE-LIVE-VERIFY-01`, `01-b`) each reported "fixed" while the Director's
live test still showed the original symptom; both times the real fix was one
level deeper than what was reported. This reinforced the standing practice of
verifying with real evidence before accepting a completion report.

---

## Part A — Junction column misalignment: closed

Root cause: `BAKE-FIX-06` added an unconditional H-flip (`flip_h` /
`_get_or_create_h_flipped_tile()`) to junction column rendering, applied to
voxel atom art that is **not actually mirror-symmetric** (pixel-symmetry
probe: 15–34/576 alpha pixel-pairs differ per material). The underlying grid
math (`JunctionResolver.voxel_pos`) was byte-identical to the pre-bake
checkpoint and never the problem.

Fixed by removing the H-flip entirely from both `_render_junction_column()`
branches (baked-lookup-success and material-only-fallback), formalized in
`PROMPTS/JUNCTION-COLUMN-NOFLIP-01.md`, applied by the Operator (commit
`14311f5`), confirmed correct by the Director in both bake states
("As colunas estão certas nas duas versões").

---

## Part B — Bake system: four structural bugs found and fixed

All four were invisible to every existing synthetic test because each test
builds its own `map_spec`/mock state already in the shape the code under test
expects — none of them exercised the real `room_builder.gd` → `BakeCompositor`
→ `VoxelRenderer` → `TileMapLayer` chain with real map data end to end.

1. **`BakeCompositor._extract_unique_combos()` never read `map_spec["walls"]`**
   — only `map_spec["blocks"]`, a shape no production caller populates.
   Every real map load found 0 combos, baked an empty atlas, silently.
   Fixed: added a `"walls"` branch to the extraction loop
   (`bake_compositor.gd`).
2. **`BakedTileLookup.set_baked_atlas()` wrote `Engine.set_meta(...)`** — the
   GDScript-RefCounted-in-Engine-meta pattern `FIX-SHUTDOWN-CRASH-01`/`01b`
   already eliminated, reintroduced by a corrective prompt (`01-b`) that
   called this pre-existing method without auditing its internals first.
   Caused a SIGABRT (exit 134) on shutdown — confirmed via `.ips` crash
   report signature matching. Fixed by removing the `Engine.set_meta` write;
   the instance-field storage (`_baked_atlas`/`_source_ids`) already added
   alongside it was sufficient.
3. **`VoxelRenderer.register_baked_atlas_page()` never called `create_tile()`**
   on the new `TileSetAtlasSource`. A `TileSetAtlasSource` has zero valid
   tiles until `create_tile(coords)` is called per atlas coordinate — exactly
   what `_build_voxel_tileset()` already does for the material-only sources,
   never replicated here. Without it, `set_cell()` silently accepts the baked
   `source_id`/`atlas_coords` (placement-side diagnostics showed a 100%
   "baked hit" rate) but nothing draws. **This was the real cause of "walls
   vanish entirely with bake enabled"** — not a lookup/dictionary problem;
   the dictionary was, by that point, already correctly populated per bug
   #1's fix. Fixed by collecting every `atlas_coords` the compositor wrote to
   (from `baked_atlas.lookup`) in `_bake_textures()` and passing that list
   into `register_baked_atlas_page()`, which now calls `create_tile()` +
   sets `texture_origin` per tile.
4. **`BakeConfig.blend_mode` was dead config** — the enum
   (`MULTIPLY`/`TEXTURE_ONLY`/`MATERIAL_ONLY`/`OVERLAY_EXPERIMENTAL`/`LINEAR_LIGHT`)
   existed and loaded from `user://bake_config.cfg`, but
   `_bake_master_strip()` always ran a hardcoded multiply regardless.
   Measured: baked concrete averaged 95/255 brightness vs. 194/255 for the
   same material's raw voxel texture — walls read as near-black even after
   bug #3 made them visible. Fixed by implementing all 5 modes for real in
   `_apply_blend()` (measured per-mode average on the same input: MULTIPLY 95,
   TEXTURE_ONLY 155, MATERIAL_ONLY 157, OVERLAY_EXPERIMENTAL 178,
   LINEAR_LIGHT 210). Added **F7** (`DebugToolsController.cycle_blend_mode()`)
   to cycle modes + reload the map live, for in-editor A/B/C/D/E comparison.

Bugs #1–#3 confirmed fixed via real headless boot logs (`godot --headless
--path .`, not `--script`): extraction finds 151 real edges, compositor
bakes 4 materials into 36 tiles, all 36 get `create_tile()`'d, and
placement-side counters show 45184/45184 real wall-voxel cells hitting the
baked lookup with 0 generic fallbacks. Regression suite unaffected throughout
(`bake_fix_11_pixel_diff_tool.gd` 7/7 PASS — B3 still holds; `bake_fix_02_test.gd`
3/3; `bake_fix_09_e2e_test.gd` 5/5).

New diagnostic instrumentation added and left in place (`BAKE-DIAG-01`),
gated by the previously-dead `BakeConfig.debug_bake_set_dump` flag: checkpoint
prints at extraction, compositor, registration, and placement, plus
throttled *reasoned* lookup-miss logging in `BakedTileLookup._resolve_baked_strip()`
(no baked atlas / empty lookup dict / edge not in any run / edge not found in
its own run / key not in dict / no source id for page — previously a miss
just silently fell through with no trace of why). Full detail:
`docs/technical/BAKE_SYSTEM_REFERENCE.md` §"First Live Verification Round"
and §"Verbose Pipeline Diagnostics".

---

## Part C — Open at session end: facade visual calibration

Walls now render, and F7 blend-mode cycling produces genuinely different,
visible results. But the Director's stated bar ("ver a fachada/textura") is
**not yet met**: cycling blend modes changes overall tone/brightness but does
not read as a textured facade with visible pattern detail.

**Not yet investigated — starting point for next round:**
- Whether the facade source images (`res://textures/defaults/facade_*.png`
  placeholders — no `user://textures/facade_*.png` exist yet, so every
  material is resolving through the `DEFAULT` tier) carry meaningful spatial
  detail at the 32×36 voxel-atom scale in the first place.
- Whether `_bake_master_strip()`'s texel-to-facade-pixel sampling
  (`facade_col_texels`/`facade_pixel_x/y` block) preserves that detail per
  atom or averages it away.

---

## State left for next session

- **`~/Library/Application Support/Godot/app_userdata/INFILTRAITOR/bake_config.cfg`**
  (outside the repo, on the Director's machine) has `enabled=true`,
  `debug_bake_set_dump=true`, `blend_mode=4` (LINEAR_LIGHT) — left this way
  deliberately so the next round starts with bake on and `[BAKE-DIAG]`
  checkpoint logging already live. Flag this to the Director if a "clean
  default" boot is ever needed for an unrelated test.
- **New live keybinds:** F6 toggle bake enabled, F7 cycle blend mode — both
  reload the current map and print a transient on-screen label.
- **Known pre-existing, unrelated issue noticed in passing:**
  `bake_selftest.gd` crashes on shutdown (same SIGABRT signature as bug #2
  above) because the test file itself writes `Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", ...)`
  / `Engine.set_meta("BAKE_TEST_REGISTRY", ...)`. All 19/19 assertions pass
  before the crash; not a regression from this session; not yet fixed.
- Documentation updated this session: `docs/technical/BAKE_SYSTEM_REFERENCE.md`
  (new "First Live Verification Round" + "Verbose Pipeline Diagnostics"
  sections, Debug Views F6/F7, Architecture blend-mode note, Implementation
  Record entries), `tools/persistent/OVERLORD_CONTEXT.md` (NECESSIDADES note
  on the live-verification round).
