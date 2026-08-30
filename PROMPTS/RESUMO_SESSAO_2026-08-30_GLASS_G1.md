# RESUMO_SESSAO — 2026-08-30 · GLASS G1 (TRANSPARENCY) BUILT

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-30_GLASS_DESIGN.md`
**Kind:** implementation — first `.gd` work on the glass track.
**VERSION:** unchanged at 0.9.107.

> Director, opening: *"Vamos executar o plano do vidro conforme ficou planejado."*

---

## 0. What shipped

**`GLASS_MASTER_PLAN` G1 — transparency — BUILT.** Glass vertical faces no longer
render as an opaque pale-blue cube; they composite over what is behind them
(G-D1: a blend, never `opacidade pura`).

**Awaiting the Director:** the MUL-vs-ADD strength and the ADD mode are a blind
calibration pick — `tools/persistent/glass_calibration.py`, one boot, 18 variant
panels + a same-boot opaque control, shuffled, labels in a separate key file.
Kept sheet: `Screenshots/history/glass_transparency_calib_2026-08-30.png`.

## 1. The mechanism (as approved in the plan)

| Piece | Where |
|---|---|
| **Two blend sublayers per glass level** — MUL (tint + frosted pattern) and ADD (highlights). Built lazily; a map with no vertical glass builds none | `VoxelRenderer._ensure_glass_sublayers()` / `_build_glass_sublayer_node()` |
| **Shared shader body**, two `render_mode` wrappers (`blend_mul` / `blend_add`) | `godot/shaders/glass_shading.gdshaderinc` + `glass_mul.gdshader` + `glass_add.gdshader` |
| **In-memory frosted atom** — `facade_glass.png` downscaled to the 32×36 atom, silhouette from `voxel_glass.png`. No new file on disk | `VoxelRenderer._build_glass_frosted_atom()`, source id at `MATERIALS.size()` |
| **Routing** — the one write seam. `material_name == "glass" and not flat_baked` → the sublayers, and the opaque cell is erased | `VoxelRenderer._set_voxel_cell()` |
| **Erase** — mirrored on both the slice and the INTERIOR-slab dirty paths | `_process_dirty_slice_voxel()` / `_process_dirty_slab_voxel()` |
| **FACE-READ-01 kept** — the glass contribution still carries the three distinct face factors (Director's hard rule) | the shader's `glass_face_factor()` |

**Two ADD modes were both built** (Director: *"A gente consegue testar as opções
lado a lado?"*): mode 0 = the frosted facade's own bright mottling; mode 1 = a
procedural diagonal reflection band in canvas space. The strip compares them.

## 2. Scope call made during the build

**Roofs and glazed floor zones stay OPAQUE for G1.** They pass `flat_baked=true`;
routing gates on `not flat_baked`. A see-through roof is out of scope, and — the
concrete reason — routing the glass block's roof through the sublayers **failed
`roof_bake_selftest` and `roof_integration_selftest`** (border-coverage geometry
read off the opaque layer). Gating on `not flat_baked` fixed both. A transparent
glass roof is a clean follow-up if the Director wants it.

## 3. Light is unchanged on purpose

`build_occupancy()` re-adds the glass sublayer cells, so **intact glass still
blocks light and shades its neighbours exactly as before G1**. Whether an intact
pane should *transmit* light is a separate decision — G-D8 only touches the
*broken* pane. `glass_transparency_selftest` test 5 pins this.

## 4. Verification

- `project_lint.py` — clean (221 files).
- `run_selftests.py` — **39 clean, 0 failed**, incl. the new
  `glass_transparency_selftest` (9 checks: glass off the opaque layer, sublayers
  lazy, concrete untouched, destroyed glass clears both sublayers, occupancy
  intact) and the two roof suites re-verified green.
- `check_invariants.py` + `gen_codemap.py --check` — clean.
- **Real PLAYGROUND boot**, not a fixture: `glass_calibration` capture shows the
  two panes transparent over the lit floor; sublayers built on exactly 16 levels
  (the two 2-storey panes, 80–95), zero glass cells on the opaque layer.

## 5. Files

**New:** `godot/shaders/glass_shading.gdshaderinc`, `glass_mul.gdshader`,
`glass_add.gdshader` · `godot/scripts/tools/glass_transparency_selftest.gd` ·
`tools/persistent/glass_calibration.py` ·
`Screenshots/history/glass_transparency_calib_2026-08-30.png`.

**Changed:** `godot/scripts/geometry/voxel_renderer.gd` (routing, sublayer
lifecycle, frosted atom, occupancy, clear/nudge hooks) ·
`godot/scripts/world/room.gd` (`glass_calibration` capture action) ·
`PROMPTS/PLANNING/GLASS_MASTER_PLAN.md` + `MATERIALS_MASTER_PLAN.md` (status) ·
`tools/persistent/CODEMAP.md`.

## 6. NEXT SESSION — start here

1. **Director picks a letter from the strip.** `glass_calibration.py` prints a
   shuffle seed; the letter→params key is `Screenshots/glass_calib/glass_calib_KEY.txt`.
   Bake the chosen `glass_mul_strength` / `glass_add_strength` / `glass_add_mode`
   into `glass_shading.gdshaderinc`'s uniform defaults (and/or `glass.json`) in a
   short `[G1-CAL]` commit.
2. **Then G2** — `pane_id` (union-find for panels, occupancy flood fill for
   blocks, §4.2) — and **G-ART** (the art order, `check_decal.py` earned first).

**Known follow-ups, not blockers:** a transparent glass roof (scope call §2);
`classify_geometry_over_rect()` does not treat glass as an occluder (a prop
behind a pane is not "covered" — arguably correct); the frosted atom is identical
per voxel so a large pane shows a faint repeat.
