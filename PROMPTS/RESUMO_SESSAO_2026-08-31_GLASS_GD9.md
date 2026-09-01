# RESUMO_SESSAO — 2026-08-31/09-01 · GLASS: G-D9, G-D18, G-D18b, G3 (A/B/C)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-31_GLASS_G1_G2_G7.md`
**Kind:** implementation — one long session across the date boundary.
**VERSION:** unchanged at 0.9.107.
**Commits (all pushed):** `30d5cc82` (G-D9) · `eb9d96ae` (G-D18) · `4ab83289` (G-D18b)
· `7d390913` (docs) · `0d4bc677` (G3-A) · `c48ddcfd` (G3-B) · `564f31c0` (G3-C),
plus the doc commit that closes the session.

> Director: *"Vamos seguir com G-D9."* → *"Vamos seguir com G3"* → *"Vamos seguir
> pro stage C. Quando terminar atualize a documentação e encerre a sessão."*

---

## 0. Status — read this first

| Piece | State |
|---|---|
| **G-D9** — multi-material slices (`panels.bands`) | ✅ **BUILT.** GLASS map WINDOWS.png wall = brick sill (rel 0-1) + head (rel 22-23) over glass |
| **G-D18** — glass does not occlude | ✅ **BUILT.** `OcclusionSet._group_slices_by_edge` skips base-glass slices (policy O7); the wireframe was drawing over a still-solid pane |
| **G-D18b** — agent renders behind a pane | ✅ **BUILT.** `VoxelRenderer.set_glass_over_z(agent.z_index + 1)`; a pane he stands behind tints him, like a guard already did |
| **G3 Stage A** — the `P_shatter` curve | ✅ **BUILT.** `GlassShatter` — shifted logistic, arsenal selftest reads `weapons/*.json`. Director: *"Boa — fixar como está."* |
| **G3 Stage B** — the roll in the shot path | ✅ **BUILT.** `plan_pane_shatter()` (region flood + G-D13 remnants), `_maybe_shatter_pane()`, glass-VFX guard |
| **G3 Stage C** — the grenade/cook path | ✅ **BUILT.** `blast_glass_punch()`, panels out of the ring model, `_shatter_glass_panes()`, `VoxelRenderer.erase_glass_cell()` |
| **Next** | **G3 Stage D** — the G-D8 passage / movement-blocking work. Intact glass blocks no movement today; needs the movement/vision blocked-edge split G-D7 anticipates |

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

## 5b. Follow-up same session — G-D18: glass does not occlude

Director, on the G-D9 capture: *"tem algum problema com a oclusão. Podemos
considerar não fazer em materiais de vidro."*

**Cause:** a glass pane is see-through (G-D1), so ghosting it reveals nothing —
and glass renders on `_glass_layers`, which `VoxelRenderer.apply_occlusion()`
never erases (it touches `_layers` only). So `OcclusionSet` still put glass
columns in `_occluded_cells`, `_build_wireframe_geometry()` drew their run-start /
run-end verticals + far-face dots + a translucent ghost-band fill, and all of it
landed on top of a pane that was still solid on screen.

**Fix:** `OcclusionSet._group_slices_by_edge()` skips any slice whose BASE
material is glass (new policy O7, `occlusion_set.gd`). No trigger, no ring stop,
no wireframe. A mostly-opaque wall with a small glass viewport (base ≠ glass)
still occludes. `glass_transparency_selftest` test [8] — the SAME occluder cells
produce 4 occluded cells as concrete and **0** as glass (control run first), and
a G-D9 base-glass banded window is excluded whole.

**Acceptance:** `Screenshots/history/glass_occlusion_{before,after}_2026-08-31.png`
— same boot, same agent cell (behind the big pane), `occlusion_set.gd` the only
variable. Before: the pane wears the occlusion wireframe (two solid verticals, a
dotted far edge, a faint fill). After: clean transparent glass.

Recorded as **G-D18** in `GLASS_MASTER_PLAN` (v1.8 → v1.9).

## 5c. Follow-up same session — G-D18b + the movement gap

Director, on the G-D18 capture: *"o agente consegue atravessar o vidro, precisamos
implementar a questão da abertura de passagem. Além disso ele está sendo
renderizado por cima sempre … no caso do vidro ser transparente, acho que podemos
deixar o agente ser renderizado atrás e ficar parcialmente coberto pelo vidro."*

**G-D18b — the agent renders behind a pane (BUILT).** OCC-03 bumps the agent one
z above the tallest OPAQUE layer so a wall never hides him. Glass hides nothing,
so `room.gd` now calls `VoxelRenderer.set_glass_over_z(agent.z_index + 1)` — the
whole glass composite (backbuffer + every pane layer) sits one z above the agent,
and a pane he stands behind tints him, exactly as it already did for a guard
(`enemies_root.z_index = 10`, never bumped). An agent IN FRONT of a pane is
unaffected — the isometric projection draws his sprite below the pane's screen
footprint, so they never overlap (verified on a capture at gu (13,12)). Capture:
`Screenshots/history/glass_agent_behind_pane_2026-08-31.png`.

**The movement gap — NOT fixed this session, folded into G3 (Director's call).**
Half-thickness panels never enter `blocked_edges` (§2), so the agent AND the
guards walk straight through intact glass. The fix is coupled to G3 (need
"broken" before "passage opens") and needs the **movement/vision blocked-edge
split** G-D7 anticipates: `blocked_edges` feeds both `can_see_cell()` and
pathfinding today, and glass must block the body without necessarily blocking the
eye (G-D7 is a *roll*). **Director chose "juntar tudo no G3"** — one coherent
task: intact glass → the movement edge set (new split), broken glass → passage
opens (`PassageQuery`, per-turn recompute) + detection +1 + light bump. Recorded
in G-D8 and the G3 task-order row.

## 5d. G3 — the break, Stages A/B/C (2026-09-01)

Director staged it: *"Vamos seguir com G3"* → the curve, then *"Vamos seguir pro
stage C"*. Stage D (passage/movement) is NOT in this session.

**Stage A — `godot/scripts/systems/destruction/glass_shatter.gd` (`0d4bc677`).**
`p_shatter(glass_punch)` = a **shifted, renormalised logistic** — `clamp(s(p) − C, 0)`
is what makes the bottom actually reach zero (a plain logistic's tail never does).
`SHATTER_K` 1.14 · `SHATTER_X0` 3.79 · `SHATTER_C` 0.075 · `SHATTER_P_MAX` 0.98,
all `static var`. `rolls_shatter(glass_punch, salt)` = B4 FNV-1a. Curve vs the
Director's targets: smg 0.6% · pellet 2.0% · pistol 5.5% · revolver 14.3% · rifle
43.8% · sniper 81.1% · **shotgun blast 38.2%**. Director: *"Boa — fixar como está"*
(a rendered plot was shown). `glass_shatter_selftest` reads `res://weapons/*.json`
and pins the curve within ±6 pts.

**Stage B — the shot path (`c48ddcfd`).** `GlassShatter.region_radius(glass_punch)`
= `BASE(3) + GAIN(6)·(glass_punch − PIVOT(2))`. `plan_pane_shatter(pane_slices,
face, hit, glass_punch, salt)` builds the pane's own `(col, level)` lattice over
every `pane_id` slice (col = run axis: X for SW/NE, Y for SE/NW — panel panes
only, `PANE_BLOCK_*` deferred), Chebyshev-BFS-floods from the hit to the radius,
then G-D13: spares each border voxel in the flood with `lerp(0.10, 0.40, luck)`
and always keeps ≥ 4 (the ones furthest toward a corner). `agent_shot_controller._maybe_shatter_pane()`
— one roll per pellet that hit a pane, after its local hole; every flooded voxel
`set_damage(DESTROYED)` folded into the shot's own `cell_to_voxel` bookkeeping.
`room._dispatch_destruction_vfx` early-returns for `glass` — a 970-voxel shatter
was 970 smoke puffs (a haze over the map); glass debris is SHARDS (G6). Real map:
rifle takes half the GLASS big pane (647/1152), sniper 972/1152 + 180 remnants,
the round marks the concrete behind.

**Stage C — the grenade/cook path (`564f31c0`).** `GlassShatter.blast_glass_punch(ring_multipliers, ring)`
= `SHATTER_BLAST_GAIN(3.4) · ring_multipliers[ring] / RESISTANCE["glass"]` — no
per-projectile punch in the cook, so the roll runs off the blast's falloff (frag:
~98% ring 0, ~79% ring 1, ~6% ring 2, 0 past). `detonation_plan_builder._phase_slices`
pulls glass PANEL slices OUT of the ring-scatter model (glass fractures, does not
deform); `_shatter_glass_panes()` groups affected panels by `pane_id`, rolls once
per pane, floods into the Delta as blast-sourced DESTROYED, deterministic on
`(source_gu, pane_id)`. ⚠️ **`detonation_entry_writer`'s "destroy" wave only knew
`get_layer()` → the opaque stack** — a blast-shattered pane stayed on screen (a
latent gap for glass BLOCKS too). New `VoxelRenderer.erase_glass_cell(level, cell)`
(a no-op for non-glass) is now called per destroy entry. Real map: frag grenade
at a corner of the big pane → ring 0, 1131/1152 flooded, the pane gone.

**Captures:** `Screenshots/history/glass_shatter_{partial_rifle,full_sniper,grenade}_2026-09-01.png`.
**Selftest:** `glass_shatter_selftest` = 13 checks (curve, blast compound, flat
bottom, monotonic, roll frequency, region radius, small pane binary, big pane
partial→full, G-D13 never 0 border, blast falloff). 40 selftests clean throughout.

## 6. NEXT SESSION — start here

**G3 Stage D — the passage / movement-blocking work** (`GLASS_MASTER_PLAN` G-D8,
Director's "juntar tudo no G3"). This is the big architectural piece:

1. **The movement/vision blocked-edge split.** `blocked_edges` feeds BOTH
   `GuardEnemy.can_see_cell()` and pathfinding (`GuardPathfinder`, `movement_overlay`).
   Glass must block the body but not necessarily the eye (G-D7 is a *roll*, still
   deferred). Add a movement-only edge set; vision keeps `blocked_edges` as-is.
2. **Intact glass panel edges → the movement set** at compile time (like a
   `divider`, but a blocked-EDGE not a blocked-cell — `{"from": gu, "to": gu + Face.delta(face)}`).
3. **Broken glass → passage opens.** `PassageQuery` (already complete, only `print`
   call sites) → a per-turn recompute of the movement set from live voxel state.
   Then `room.report_blast_passage()` / the shot equivalent raise detection +1 and
   bump the light one step (G-D8).
4. Real-map bed = the GLASS map. Small pane (gu 4/5, 1 storey) is the binary case;
   the big pane the partial.

**Also parked:** G-ART (the crack_web / bullet_web / shard_floor / frame_remnant
decal families), G5 (the CRACKED tier + the blast crack radius), G4 (jagged
half-voxel remnant art — the remnants currently render as full glass voxels),
G-VARIANT (`glass_armored`, `glass_screen_*`), G6 (shards as a floor decal),
`plastic` (MATERIALS).
