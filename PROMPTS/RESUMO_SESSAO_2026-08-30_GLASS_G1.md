# RESUMO_SESSAO — 2026-08-30/31 · GLASS G1 (TRANSPARENCY)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-30_GLASS_DESIGN.md`
**Kind:** implementation — the first `.gd` work on the glass track.
**VERSION:** unchanged at 0.9.107.
**Commits (all pushed):** `41eee478` `3832f952` `aba572c4` `1620561e` `b3c0fd66`
`8f3e24b0` `c9c4169c`.

> Director, opening: *"Vamos executar o plano do vidro conforme ficou planejado."*
> Director, closing: *"A aparência está boa, fechamos a questão do design. Mas a
> geometria ainda não está certa. Vamos ajeitar amanhã."*

---

## 0. Status — read this first

**GLASS_MASTER_PLAN G1 (transparency):**

| Half | State |
|---|---|
| **Appearance / design** | ✅ **CLOSED by the Director.** Blue tint calibrated (blind strip → "painel 005": sheen mode, `mul 0.60 / add 0.20`, tint `[0.47, 0.63, 0.90]`), continuous world-sampled frost, dim top/side caps to read the planes, no double-tint. |
| **Geometry** | ⛔ **NOT right yet — the Director will adjust it.** The perimeter/thickness geometry and the glass-BLOCK issues below are open. |

**The pane is the priority.** Full glass blocks are a rare case (benches, an ad
panel, a vitral, redomas) — their problems are deferred.

## 1. What was built

### The pipeline
- Glass **vertical faces** leave the opaque `_layers` for **one glass `TileMapLayer`
  per level**, drawn through a **rasterising container** — a **`BackBufferCopy`**
  snapshots the scene, every glass fragment reads that snapshot and applies the
  tint + sheen ONCE (`glass_pane.gdshader` + `glass_shading.gdshaderinc`'s
  `glass_apply()`), blend_mix at coverage. Overlapping voxel faces read the same
  snapshot → **no tint²** (the Director's *"container rasterizado"*). ⚠️
  `CanvasGroup` + a blend `render_mode` was tried first and does NOT composite
  (draws an opaque white bbox) — `BackBufferCopy` is the way.
- Routing is the one `_set_voxel_cell()` write seam, gated
  `material == "glass" and not flat_baked` (roofs / glazed floor zones stay
  opaque — a see-through roof broke the roof selftests' coverage geometry).
- `build_occupancy()` re-adds the glass cells: **intact glass still blocks light
  exactly as before G1** (whether it should transmit is a separate call, G-D8).

### The atoms (8 of them: 4 faces × interior / perimeter)
- **Interior** = the face's **parallelogram** — the fundamental domain of that
  face's voxel lattice, on that face's own diamond edge. Clean diagonal edge,
  continuous frost (sampled by world position — no per-voxel "xadrez").
- **Perimeter** (ends of the face row + top level, `_glass_is_perimeter()`) = the
  same parallelogram + a **DIM top cap (0.60)** + a **DIM thickness strip (0.78)**
  (dim in the atom's RED channel). 1-voxel thickness, planes differentiated, and
  the caps self-hide on interior voxels (a neighbour's bright parallelogram covers
  them in the container).
- `glass_min_body` — a faint tinted body so glass over a black void is not a hole.

### Tooling
- `INFILTRAITOR_CAPTURE_ACTION=glass_calibration` + `tools/persistent/glass_calibration.py`
  — the one-boot blind strip (shuffled, key in a sidecar). Used it three times.
- `INFILTRAITOR_GLASS_DIAG=1` — prints the glass slices a render produces.
- `INFILTRAITOR_GLASS_ATOM_NUDGE="x,y"` — the pane atoms' texture_origin offset
  (default `0,20`), for a tuning pass.
- `godot/scripts/tools/glass_transparency_selftest.gd` — 12 checks (glass off the
  opaque layer, interior→pane atom, perimeter→perimeter atom, container exists,
  erase, occupancy). **39 selftests clean.**

## 2. NEXT SESSION — the geometry the Director will adjust

The **appearance is signed off**; what is still wrong is the geometry.

1. **The pane's thickness geometry.** The DIM thickness strip currently rides the
   `base_b → side_b` diamond edge (reads along the pane's base). The Director wants
   the **top and the LATERAL** (the left/right vertical edges) — position-0 and
   position-7 of the face row, whose outward faces face the W/S (or N/E) vertex.
   That is the per-position atom work that was skipped: an end voxel needs a
   thickness face on its *outer* end, which for one of the two ends does not fit
   in the 32×36 atom's used half.
2. **The glass BLOCK, three issues (Director's own list):**
   - the **roof-slab seam** (*"questão entre as slabs no teto"*) — glass block
     roofs stay opaque (scope call) but the seam still reads wrong;
   - the **junction corner columns** (*"as colunas extras de esquina"*) —
     `_render_junction_column()` writes straight to the opaque `_layers`, never
     through the glass branch, so a glass block's corner columns render opaque /
     absent;
   - **z-index vs walls in front** (*"o z-index com paredes que estão na frente"*)
     — the glass composite sits at `get_max_voxel_z_index()`, so a wall NEARER in
     iso depth but at a lower level draws *under* the glass and gets tinted. This
     is the "isometric depth compositing" limitation the plan flagged; a
     per-level or per-pane container is the real fix.

After the geometry is right: **G2** (`pane_id` — union-find for panels, occupancy
flood fill for blocks) and **G-ART** (the art order + `check_decal.py`).

## 3. Files

**New:** `godot/shaders/glass_pane.gdshader`, `glass_shading.gdshaderinc` ·
`godot/scripts/tools/glass_transparency_selftest.gd` ·
`tools/persistent/glass_calibration.py` ·
`Screenshots/history/glass_transparency_calib_2026-08-30.png`.

**Changed:** `godot/scripts/geometry/voxel_renderer.gd` (routing, glass layer +
`BackBufferCopy` container, 8 pane atoms, occupancy, `_glass_is_perimeter`,
clear/nudge hooks, `INFILTRAITOR_GLASS_DIAG`) · `godot/scripts/world/room.gd`
(`glass_calibration` capture action) · `PROMPTS/PLANNING/GLASS_MASTER_PLAN.md` +
`MATERIALS_MASTER_PLAN.md` (status) · `tools/persistent/CODEMAP.md`.
