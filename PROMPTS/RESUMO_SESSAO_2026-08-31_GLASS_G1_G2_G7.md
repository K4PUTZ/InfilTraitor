# RESUMO_SESSAO — 2026-08-31 · GLASS: G1 geometry, G2, G7, the design grows, G-MAP

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-30_GLASS_G1.md`
**Kind:** implementation + a design-expansion pass.
**VERSION:** unchanged at 0.9.107.
**Commits (all pushed):** `ffd73f44` `4d5da813` `9b8365dd` `8c7cdc35` `5728bac3`
`d62e2f62` `c33e91d7` `2257b358` `37dcfdb7`.

> Director, opening: *"Vamos finalizar o vidro hoje. Leia a documentação."*
> Director, closing: *"Vamos atualizar a documentação com tudo o que foi feito e
> encerrar a sessão."*

---

## 0. Status — read this first

| Piece | State |
|---|---|
| **G1 appearance** | ✅ closed (calibration "painel 005", unchanged) |
| **G1 geometry** | ✅ **reworked to the face-culling rule + the float bug fixed.** A tuning verdict on the exact sliver size/dim is nominally open, but the Director said *"a arte e a geometria é essa mesma"* — the float was the real complaint |
| **G2 `pane_id`** | ✅ **BUILT** — `GlassPaneGrouper`, real-map verified |
| **G7 pass-through** | ✅ **BUILT** — a round holes the pane and continues |
| **The break design** | 🔴 **GREW** — G-D11…G-D17, all formalised; **G3 is PAUSED for the design sign-off, which the Director gave** at the end of the session |
| **G-MAP** | ✅ **BUILT** — `maps/GLASS.map.json` |
| **G-D9** (multi-material slices / `bands`) | ⏭ **NEXT** — untouched. Then G3 |

## 1. G1 — the geometry, reframed by the Director's two diagrams

The last session left the pane thickness "not right — the Director will adjust
it". His diagrams (2026-08-31) reframed it: **the thickness is a per-voxel
exposed-face cull, not per-position atoms with a `texture_origin` trick.**

- **Main face** — every glass voxel, always (the see-through parallelogram).
- **Top face** — only the top row. The pane's top edge extruded into the GU by
  the pane's thickness (a parallelogram whose back edge stays PARALLEL to the
  front → voxel-to-voxel the slivers meet with no sawtooth). Dim.
- **Side face** — only the frontmost column (always pos 7 — both screen axes
  carry a +south component). Dim.
- Painting only the exposed faces is what kills the "serrilhado": with
  transparency every hidden face that gets drawn ghosts through.

`_build_glass_pane_atom(face, want_top, want_side)`; 16 atom sources
(`_glass_atom_source[face][mask]`); `_glass_is_perimeter` → `_glass_face_mask`;
`_set_voxel_cell`'s `glass_perimeter` bool → `glass_mask` int.
`GLASS_FACE_SLIVER_FRAC` 0.55, `GLASS_DIM_TOP` 0.60, `GLASS_DIM_SIDE` 0.78.
NW/NE slivers extrude toward the camera (back walls) — computed, untested.

### The float bug (`4d5da813`)

On a fresh boot the Director saw the whole glass block **shifted a level up** —
floating at the base, top too high under occlusion. Cause: the pane atom's
`texture_origin` carried a leftover `+(0,20)` — compensation for a `+shift` the
atom builder no longer applies. `face_q` is now byte-for-byte the material
atom's own side face (verified against `voxel_concrete.png`: alpha rows 8..36,
left half), so the nudge must be `Vector2i.ZERO`. Overlaid against the same-boot
opaque control, the base and the left edge now line up, and so does the
occlusion wireframe.

## 2. G2 — `pane_id` (`8c7cdc35`)

`GlassPaneGrouper.assign(edge_registry, solid_block_instances)`, once at map
load right after `SliceGenerator.generate()`. `Slice.pane_id`.

- **Panels** — union-find: same face orientation AND GUs adjacent along the
  face's RUN axis (perpendicular to `Face.delta`). A lone panel is its own pane.
- **Blocks** — every glass `solid_block_instance` footprint cell merged into one
  set, 4-connected flood fill into components. ⚠️ **NOT per-authored-instance**
  — PLAYGROUND spells its 3-wide glass block as three adjacent 1×1
  declarations, and the first pass split it into three panes. Caught on the real
  map (`INFILTRAITOR_GLASS_DIAG=1`), not the selftest — §11's whole point again.

Real map: PLAYGROUND → `PANE_SLICE_26_9_SE`, `PANE_SLICE_30_9_SW`, one
`PANE_BLOCK_0`. GLASS map → one big pane, one small, one block, one bands wall.

## 3. G7 — the round passes through (`5728bac3`)

Half-thickness glass panels never populate `blocked_edges`, so the pellet flood
sailed through them registering nothing.

- `EdgeRegistry.glass_edge_keys()` — glass PANEL edges (blocks excluded, their
  cells are in `blocked_cells` and their pass-through is deferred), keyed like
  `blocked_edges`, value = `pane_id`.
- `_walk_pellet_ray(..., glass_edges)` — a glass crossing is recorded (deduped
  by `pane_id` so a graze makes ONE hole) and the walk continues. A terminal
  solid hit carries `hit["glass_passed"]`; a round that met only glass returns
  `{"glass_passed": [...]}` with no `gu`.
- `resolve_pellet_voxel` — a single-slice edge (a half-thickness panel) resolves
  even when the round crosses it from the empty side.
- `agent_shot_controller._glass_edges_dict()` + `_flatten_glass_passthrough()` —
  each crossing becomes its own pick, the tracer runs to the terminal hit only.

Real map (both PLAYGROUND and GLASS): `[AGENT-SHOT-TIER] glass:s1 destroyed=1`
AND `concrete:s1 dented=1` from one pistol shot.

## 4. The break design GREW — G-D11 … G-D17

The Director replaced the single `pane_shatter_punch` threshold with a richer
model, and asked for it formalised before any G3 code.

| # | What |
|---|---|
| **G-D11** | The whole-pane shatter is a PER-PROJECTILE ROLL scaled by power. Each pellet/round rolls `P_shatter(glass_punch)`. A shotgun's 24 pellets compound; "none shattered" is a legit outcome |
| **G-D12** | A BIG pane breaks PARTIALLY (a region floods, the rest resists); a SMALL pane is binary |
| **G-D13** | The cascade NEVER destroys every voxel — frame-ring remnants are a hard invariant of G3, not an optional G4 flourish |
| **G-D14** | Hole size is per-weapon off `blowout` — pistol/pellet 1 voxel + tight `crack_web`; rifle 2–4 + wider, spaced `crack_web` |
| **G-D15** | `glass_armored` (purple): resists common shots, usually shatters all at once when breached. A rifle may pierce ONE voxel without shattering and PRIME the pane (`pane_primed`) so the next shot of any type auto-shatters it |
| **G-D16** | Glass is a family of tinted `glass_class` behaviours: `glass` (blue/breakable) · `glass_armored` (purple) · `glass_screen_{green,red,amber}` (terminal tone) — INDESTRUCTIBLE (control UIs — takes a crack decal, never breaks, **and STOPS the round**) or BREAKABLE (TVs, news panels) |
| **G-D17** | A screen is a glass voxel over a BLACK PLASTIC voxel (new `plastic` material, MATERIALS): a round DRILLS plastic (no pass-through), fire MELTS it; art painted on the plastic, glass adds the sheen |

**Director-approved `P_shatter` distribution** (neutral skill/luck): pistol
~2.5%, revolver ~16%, rifle ~44%, sniper ~81%, shotgun blast ~38% (compound of
24 ~2% rolls). Near-flat bottom; constants `var`, pinned by an arsenal selftest.

**The `bands` authoring format (§9.6)** — `panels.bands`: a sparse
`{"levels": [lo, hi], "material": …}` override. This is the G-D9 pipeline, now
needed because the GLASS map's WINDOWS.png wall uses it. Touches ~8 files; the
`_group_edges_into_runs` change is the real cost (§9.4 — a wrong run restarts
the facade mid-wall, capture-only to catch).

## 5. G-MAP — `maps/GLASS.map.json` (`37dcfdb7`)

PLAYGROUND is too full. Glass physics gets its own map.

- Big pane: authored gu x 10–15, y 9, face SW, 3 storeys (6 GUs) — room for
  G-D12's partial break. G2 unions the 6 panels into one `pane_id`.
- Small 1-storey pane (binary case), a WINDOWS.png `bands` wall (the `bands`
  keys are in the JSON already; ignored until G-D9, renders as plain glass), a
  3-wide glass block, a guard behind the big pane, one concrete floor, 3 lights.
- `room.gd`: `INFILTRAITOR_MAP=GLASS` boots straight into a map for capture
  tooling **without** rewriting `user://current_map.cfg`.
- Auto-registered via `FileMapSource` — no `MapCatalog` edit.

## 6. NEXT SESSION — start here

**Task order (GLASS_MASTER_PLAN §10):** G-D9 → G3 → G-VARIANT → G4/G6 → G-D4.

1. **G-D9 — multi-material slices.** `panels.bands` → `edge.material_bands` →
   `Slice.material_bands` + `material_at(level)`. The 9 render sites that hold
   the `Voxel` call `material_at()`; `BakedTileLookup` at `:259`/`:415`; the
   bake run splits per material band (`_group_edges_into_runs`, §9.4 — the
   dangerous one); `GlassPaneGrouper` groups by the glass levels. **The GLASS
   map's bands wall is the acceptance capture.**
2. **G3 — the break**, per §5.1's rewritten model. `P_shatter` curve pinned by
   an arsenal selftest; per-weapon hole size off `blowout`; region flood on a
   won roll; the G-D13 remnant floor. In `build_plan()` + the shot path,
   `bump_world_revision()`. Real-map bed = the GLASS map, cell probe not pixels.

## 7. Files

**New:** `godot/scripts/geometry/glass_pane_grouper.gd` ·
`maps/GLASS.map.json` · `Screenshots/history/glass_geometry_face_cull_before_after_2026-08-31.png`
· `glass_map_overview_2026-08-31.png` · `shot_glass_g7_*` · `shot_glassmap_g7_*`.

**Changed:** `godot/scripts/geometry/voxel_renderer.gd` (the atom rework, the
nudge, `_glass_face_mask`, `glass_mask`, GLASS-DIAG `pane=`) ·
`godot/scripts/geometry/slice.gd` (`pane_id`) ·
`godot/scripts/geometry/edge_registry.gd` (`glass_edge_keys()`) ·
`godot/scripts/systems/destruction/blast_calculator.gd` (`_walk_pellet_ray`
glass, `_pellet_terminal`, `resolve_pellet_voxel` single-slice fallback,
`select_line_impact` / `select_cone_pellet_impacts` `glass_edges` param) ·
`godot/scripts/world/controllers/agent_shot_controller.gd`
(`_glass_edges_dict`, `_flatten_glass_passthrough`, `_draw_tracer` skip) ·
`godot/scripts/world/builders/room_builder.gd` (`GlassPaneGrouper.assign`) ·
`godot/scripts/world/room.gd` (`INFILTRAITOR_MAP`) ·
`godot/scripts/tools/glass_transparency_selftest.gd` +
`blast_calculator_selftest.gd` (new tests) ·
`PROMPTS/PLANNING/GLASS_MASTER_PLAN.md` (v1.1 → v1.7) ·
`PROMPTS/PLANNING/MATERIALS_MASTER_PLAN.md` (new material list) ·
`docs/production/current_state.md` · `docs/README.md` · `tools/persistent/CODEMAP.md`.
