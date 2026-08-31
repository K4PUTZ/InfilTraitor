# RESUMO_SESSAO — 2026-08-31 · GLASS G-D9: multi-material slices

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-31_GLASS_G1_G2_G7.md`
**Kind:** implementation.
**VERSION:** unchanged at 0.9.107.

> Director, opening: *"Vamos seguir com G-D9."*

---

## 0. Status — read this first

| Piece | State |
|---|---|
| **G-D9** — multi-material slices (`panels.bands`) | ✅ **BUILT.** The GLASS map's WINDOWS.png wall renders a brick sill (rel 0-1) + head (rel 22-23) over a glass middle |
| **Next** | **G3** — the break, per `GLASS_MASTER_PLAN` §5.1's rewritten model (G-D11…G-D14). Director signed the design off at the end of the previous session |

## 1. What landed

`panels.bands` (§9.6) → a sparse per-level material override that flows through
the whole geometry pipeline:

| File | Change |
|---|---|
| `map_compiler.gd` | `_compile_panel_bands()` — expands the sparse `bands` array (`{"levels":[lo,hi],"material":…}`, inclusive, panel-relative) into a dense `{rel_level: material}` dict, ONCE. Accepts `levels` as a 2-int array OR the `Vector2i` FileMapSource's JSON converter folds it into |
| `edge.gd` / `slice.gd` | `material_bands: Dictionary` + `material_at(rel_level) -> String` + `has_material_bands()`. `rel_level` = `voxel.level − storey_level_base(start_storey)` — 0-based from the panel bottom, exactly the authoring space |
| `edge_extractor._extract_panels` | `edge.material_bands = panel.material_bands.duplicate()` (panels bypass the third-pass rebuild, so nothing drops it) |
| `slice_generator._create_slice` | copies the band map onto the Slice (side-independent) |
| `voxel_renderer._render_slice` / `_process_dirty_slice_voxel` | per-voxel `vmat = slice.material_at(rel)` drives `damage_variant_material()`, the glass-layer routing gate, the diag. `_slice_top_glass_level()` anchors the G1 top sliver to the top GLASS row (below a brick head). `_slice_is_glassy()` (base OR any band) keeps diag/geometry firing |
| `voxel_renderer._set_voxel_cell` | resolves the per-level material in RENDER space and hands it to the lookup as `material_override` — `""` for every ordinary edge |
| `baked_tile_lookup.gd` | `resolve()` / `_resolve_baked_sheet` / `_resolve_generic` take a trailing `material_override: String = ""`; when set it is the facade key's material component. Key was already `(material, facade, column, level, dir)` — no collision |
| `room_builder._bake_textures` | one extra `wall_descriptor` per `(banded edge, band material)` so the compositor bakes the brick facade page. Verified: `[BAKE] Composed sheet brick\|facade_brick` appears for the GLASS map and is ABSENT on the pre-G-D9 checkout |
| `glass_pane_grouper._is_glass_slice()` | base OR any band is glass → the GLASS map's 3 banded panels union into `PANE_SLICE_22_10_SW` |
| `glass_transparency_selftest` | test [7] — the accessor + the real render seam (brick bands opaque, glass middle on the pane sublayers, `_slice_top_glass_level` below the head) |

## 2. The one deviation from the ratified pipeline

§9.6's table listed **`_group_edges_into_runs` → per material band**. **NOT done,
and not needed:** the GLASS map's 3 banded edges share their BASE material
("glass") along the run, so they group naturally; `column_in_run` continuity is
exactly what the glass middle wants, and the brick sill/head resolve against the
fully-swept brick page folded through the same `column_in_run` → a continuous
brick cap. §9.4's failure mode (a wrong run restarting a facade mid-wall) needs a
run spanning two *different* base materials — those are already separate runs. If
a future map places a banded window mid-run against a plain wall of a different
base material and the cap misaligns, that is when the run split gets built, with
its own capture. Recorded in `GLASS_MASTER_PLAN` §9.6.

## 3. Deferred with a note (rides G3/G5, not G-D9)

`resolve_damage_swap_for(container, …)` still reads `container.material` (base),
not `material_at()`. It only matters once a brick-band voxel is CRACKED/DENTED —
which is G5 / G3 territory (glass doesn't dent; the brick cap only takes damage
in a blast). Thread a level param through it when G3 lands.

## 4. Verification

- `project_lint.py` ✅ · `check_invariants.py` ✅ · `gen_codemap.py --check` ✅
- `run_selftests.py` — **39 clean, 0 failed** (glass_transparency now 23 checks)
- `mapfile_roundtrip_test` PASS · `panel_base_test` PASS. `bake_cache_test`
  6/7 FAIL — **pre-existing** ("Failed to resolve facade", headless asset-tree),
  identical on the clean checkout.
- Real map, `INFILTRAITOR_MAP=GLASS INFILTRAITOR_GLASS_DIAG=1`: banded slices
  carry `bands={0:"brick",1:"brick",22:"brick",23:"brick"}`, union to one pane,
  no push_error, no SCRIPT ERROR, no lookup MISS.
- **Acceptance capture (same-boot):**
  `Screenshots/history/glass_bands_wall_before_2026-08-31.png` (plain glass) vs
  `…_after_2026-08-31.png` (brick sill + head, glass middle). Same camera, same
  map, code the only variable.

## 5. Files

**New:** `Screenshots/history/glass_bands_wall_{before,after}_2026-08-31.png` ·
this file.

**Changed:** `godot/scripts/geometry/edge.gd` · `slice.gd` · `edge_extractor.gd`
· `slice_generator.gd` · `glass_pane_grouper.gd` · `voxel_renderer.gd` ·
`godot/scripts/systems/baked_tile_lookup.gd` ·
`godot/scripts/world/builders/room_builder.gd` ·
`godot/scripts/world/maps/map_compiler.gd` ·
`godot/scripts/tools/glass_transparency_selftest.gd` ·
`PROMPTS/PLANNING/GLASS_MASTER_PLAN.md` (v1.7 → v1.8) ·
`docs/README.md` · `docs/production/current_state.md` ·
`tools/persistent/CODEMAP.md`.

## 6. NEXT SESSION — start here

**G3 — the break** (`GLASS_MASTER_PLAN` §5.1, rewritten). Per-projectile
`P_shatter(glass_punch)` roll pinned by an arsenal selftest; per-weapon hole size
off `WeaponDef.blowout`; region flood (BFS over the pane's voxels) on a won roll;
the G-D13 remnant floor (position 0/7, level 0/7 survivors, luck-driven). In
`build_plan()` + the shot path, `room.bump_world_revision()`. Real-map bed = the
GLASS map, cell probe (`INFILTRAITOR_CELL_PROBE=1`) not pixels.
