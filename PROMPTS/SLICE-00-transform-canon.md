# SLICE-00 — Transform Canon: Voxel Plane ↔ World Grid Alignment

> **Series:** SLICE (Engine Geometry Architecture 1.0) — first prompt.
> **Supersedes nothing; blocks everything.** SLICE-01..03 and VOXEL-08 (Baking) must not
> start before this prompt's acceptance criteria pass.
> **Nature:** Diagnostic-first. Measure, classify, then fix analytically. Do NOT apply any
> fix before the probe has classified the misalignment (§ T3).

---

## CONTEXT

The voxel wall assembly renders rigidly displaced from the playable floor grid (see the
2026-07-01 debug screenshot: the wall box sits offset from the playable area). Audit of the
render stack found the root class of the bug: **three offset conventions coexist**:

1. **Floor plane (gameplay):** `FloorLayer` node at `position = (0,0)`; the visual offset
   lives inside `tileset_blocks.tres` as per-tile `texture_origin` values (e.g. floor tiles
   at `(0, -384)` on 256×512 canvases).
2. **Overlays / agent / free sprites:** offset applied arithmetically per draw:
   `map_to_local(cell) + Vector2(0, 64) + VISUAL_GRID_OFFSET`.
3. **Voxel plane:** offset baked into the layer node transform:
   `voxel_layer[k].position = VISUAL_GRID_OFFSET - Vector2(0, VOXEL_STEP_PX * k)`, with
   voxel tiles at `texture_origin = (0, 0)`.

Any disagreement between (1)+(2) and (3) appears as a rigid displacement of ALL walls
relative to the grid — walls stay correct relative to each other. That is exactly the
observed symptom.

Closed-form analysis says the layer transform `(0, 512)` should already be consistent with
the canonical anchor table, which means the live misalignment most likely comes from either
**texture anchoring of the voxel atom** or a **cell-space offset at the compiler→geometry
seam**. This prompt instruments the running game to measure the delta, classifies it, and
applies the corresponding analytical fix. No empirical calibration: every value written must
be a derived expression, and the derivation must be enforced by a selftest.

---

## THE TRANSFORM CANON (normative — will be copied into the master plan in T5)

**Canon 1 — The gameplay plane defines the world grid.** The canonical anchor table in
`tools/persistent/QUICK_REFERENCE.md` § "Grid & Screen Coordinates" is the single source of
world-space truth:

```gdscript
tile_N_vertex(gu) = floor_layer.map_to_local(gu) + VISUAL_GRID_OFFSET
tile_center(gu)   = floor_layer.map_to_local(gu) + Vector2(0, 64) + VISUAL_GRID_OFFSET
```

The floor plane, its tileset, and the overlay convention are FROZEN. Render planes adapt to
them, never the reverse.

**Canon 2 — Render-plane layer transforms are derived equations, proven by selftest.**
For the voxel plane, the alignment requirement is:

```
For every GU g and voxel cell v = 8g + (i, j), i,j ∈ [0,8):
    voxel_layer[0].position + voxel_map_to_local(v)
        must tile the diamond whose N vertex is tile_N_vertex(g)
```

Because `VOXEL_TILE_SIZE = GU tile_size / 8` exactly, `voxel_map_to_local(8g)` equals
`floor_map_to_local(g)` term-for-term, which reduces the requirement to:

```
voxel_layer[0].position == VISUAL_GRID_OFFSET          (Equation E1)
voxel_layer[k].position == VISUAL_GRID_OFFSET - Vector2(0, VOXEL_STEP_PX * k)
```

E1 must hold as a derived expression in code AND be asserted by the selftest.

**Canon 3 — texture_origin is derived from atom canvas metrics, never calibrated.**
The voxel atom canvas is 32×36: top face rows [0,16), side face rows [16,36). The tile cell
is 32×16. The level-0 cube must stand ON the floor, i.e. its **footprint** (the top-face
diamond translated down by the side-face height) must coincide with the cell diamond. The
derived anchoring constant is:

```gdscript
## (atom_h - tile_h) / 2  →  (36 - 16) / 2 = 10
const VOXEL_TEXTURE_ORIGIN := Vector2i(0, (VOXEL_ATOM_H - VOXEL_TILE_H) / 2)
```

Sign note: Godot's draw rule is inferred once from the floor plane itself (the "Rosetta
stone": floor tiles with `texture_origin (0, -384)` on 512-tall canvases land their diamond
exactly at `tile_center`, which pins the engine's sign convention). If the probe in T1
shows the level-0 cubes displaced vertically by exactly ±20 px (one side-face height) after
applying this constant, the footprint/top-face anchor choice is inverted for our canvas
layout: negate the y component ONCE, keep the derived expression form, and record the sign
decision in the canon text. This is a one-shot convention confirmation, not calibration —
after this prompt the selftest freezes it forever.

**Canon 4 — Cell space crosses the seam untouched.** The geometry pipeline receives GU
cells in compiled (buffered) coordinates — the same cells painted on the floor. No stage
after `MapCompiler.compile()` may add or remove the buffer offset. `gu_to_voxel_origin(g)`
is `8 * g` and nothing else.

---

## MODULE

- `godot/scripts/world/room.gd` — voxel section only (`_build_voxel_tileset`,
  `_ensure_voxel_layers`, `_place_wall_voxels`) + one new debug probe function.
- `godot/scripts/tools/slice_geometry_selftest.gd` — NEW file.
- `docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md` — append canon section (T5).
- `tools/persistent/QUICK_REFERENCE.md` — add voxel-plane row to the coordinates section (T5).

One session. No other files.

---

## TASK

### T1 — Runtime alignment probe (instrument BEFORE fixing)

In `room.gd`, add an export flag and a probe function:

```gdscript
@export var debug_probe_voxel_alignment: bool = false
```

```gdscript
func _debug_probe_voxel_alignment() -> void:
	## SLICE-00: measures world-space delta between the canonical GU diamond and the
	## voxel plane's 8x8 block for a set of probe GUs. Temporary diagnostic; removed
	## in SLICE-01. Logs via print_debug only.
	if not debug_probe_voxel_alignment:
		return
	if _voxel_layers.is_empty():
		print_debug("[SLICE-00 probe] no voxel layers — nothing to measure")
		return
	var probes: Array[Vector2i] = [Vector2i(5, 5), Vector2i(10, 10), Vector2i(5, 12)]
	for gu: Vector2i in probes:
		## Canonical world N vertex of the GU (QUICK_REFERENCE table):
		var canon_n: Vector2 = floor_layer.map_to_local(gu) + VISUAL_GRID_OFFSET
		## Voxel plane world N vertex of the same GU: voxel cell 8*gu, level-0 layer.
		var vlayer: TileMapLayer = _voxel_layers[0]
		var voxel_n: Vector2 = vlayer.position + vlayer.map_to_local(gu * SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS)
		var delta: Vector2 = voxel_n - canon_n
		print_debug("[SLICE-00 probe] GU %s  canon_N=%s  voxel_N=%s  delta=%s px  (=%s voxel cells approx)"
				% [gu, canon_n, voxel_n, delta, delta / Vector2(16, 8)])
```

Call it at the end of `_place_wall_voxels()` (after `_build_high_walls()`).

**Caveat:** if `map_to_local` anchors differ between the two tile sizes in a way not
captured above, the probe deltas will show it as a constant sub-tile term — that is
expected and handled by the classification in T3. Do not "correct" the probe formula to
force zero; the probe reports, the classification decides.

Run the smoke test with the flag ON and **record the three deltas verbatim** in your
completion report. Take a screenshot of the misaligned state before any fix.

### T2 — Geometry selftest (closed-form, headless)

Create `godot/scripts/tools/slice_geometry_selftest.gd` following the structure of
`voxel_selftest.gd` (headless, exit code 0/1, per-check log). It must verify, with no
scene instantiation:

1. **E1 (layer transform):** recompute the expression used by `_ensure_voxel_layers` for
   levels 0, 1, 7 and assert equality with
   `VISUAL_GRID_OFFSET - Vector2(0, VOXEL_STEP_PX * level)`.
2. **Scale identity:** for GUs (0,0), (5,5), (12,3), (27,45) assert
   `voxel_iso_projection(8 * g) == floor_iso_projection(g)` where both are computed from
   the same closed form `((c.x - c.y) * half_w, (c.x + c.y) * half_h)` with (16,8) and
   (128,64) respectively.
3. **Derived origin:** assert the voxel tileset origin constant equals
   `Vector2i(0, (36 - 16) / 2)` up to the sign recorded in T4 — read the constant, not a
   literal copy.
4. **Canon 4 (cell space):** assert `gu_to_voxel_origin(g) == 8 * g` and
   `voxel_to_gu(8 * g + Vector2i(7, 7)) == g` for the same GU set.
5. **Floor Rosetta sanity:** load `tileset_blocks.tres`, read the `floor_SE` source, assert
   `texture_region_size == Vector2i(256, 512)` and `texture_origin == Vector2i(0, -384)`.
   This pins the frozen floor plane; if it ever changes, the selftest fails loudly instead
   of the walls silently drifting.

### T3 — Classify the measured delta (gate before fixing)

Match the T1 deltas against this table. Apply ONLY the fix row that matches. If no row
matches, STOP and report the raw numbers — do not improvise a correction.

| Delta pattern (same for all probes) | Cause | Fix |
|---|---|---|
| `(0, ±10)` or `(0, ±20)`, constant | Voxel atom texture anchoring | T4a |
| `(0, k)` with k ≈ ±512 / ±384 / ±64 / ±576, constant | Layer transform vs canon (E1 violated at runtime) | T4b |
| Multiples of one GU: `(±128·k, ±64·k)` quantized, constant | Cell-space offset at the compiler→geometry seam (Canon 4 violated) | T4c |
| Grows with GU coordinates | tile_size / projection mismatch | STOP — report; do not fix in this prompt |
| Zero within ±2 px, but walls still visibly wrong | Misalignment is not plane-level (per-slice) | STOP — report; the bug is in `_voxel_slice_positions` inputs, out of SLICE-00 scope |

### T4 — Analytical fixes (only the matched row)

**T4a — Texture anchoring.** In `_build_voxel_tileset()`, replace
`td.texture_origin = Vector2i(0, 0)` (and its `## analytically correct — no calibration`
comment, which is wrong) with the derived constant of Canon 3. Add the two constants next
to the existing voxel constants in `SubcubeCoordsClass`:

```gdscript
const VOXEL_ATOM_H: int = 36   ## top face 16 + side face 20 — see VOXEL_MASTER_PLAN §3
const VOXEL_TILE_H: int = 16
```

and in `_build_voxel_tileset()`:

```gdscript
td.texture_origin = Vector2i(0, (SubcubeCoordsClass.VOXEL_ATOM_H - SubcubeCoordsClass.VOXEL_TILE_H) / 2)
```

Apply the one-shot sign confirmation from Canon 3 if the ±20 px signature appears, then
update selftest check 3 to the recorded sign.

**T4b — Layer transform.** Do NOT tune the number. Find why the runtime value diverges
from E1 (parent node transform, double application, stale layer reuse), remove the
divergence, and keep the code as the literal E1 expression it already is.

**T4c — Cell-space seam.** Trace one probe GU from `MapCompiler.compile()` output through
`SubcubeGeometry.build()` into `_place_wall_voxels()` edge_groups, logging the cell at each
hop. Remove the stage that adds/removes the buffer offset. The fix must leave the value
`8 * g` reaching `set_cell()` with g in compiled coordinates.

After the fix: re-run the T1 probe (deltas must be `(0, 0)` within ±1 px on all probes),
re-run the selftest, take the after screenshot.

### T5 — Canonize in documentation

1. Append a new section **"Transform Canon"** to
   `docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md` containing Canons 1–4 verbatim
   (with the confirmed sign), plus the measured before/after deltas as a historical note.
2. In `tools/persistent/QUICK_REFERENCE.md` § "Grid & Screen Coordinates", add:

```gdscript
voxel_layer[k].position = VISUAL_GRID_OFFSET - Vector2(0, VOXEL_STEP_PX * k)  # E1 — proven by slice_geometry_selftest
```

Do not modify the existing floor anchor rows.

---

## DO NOT TOUCH

- `FloorLayer` node, `tileset_blocks.tres`, and every existing row of the canonical anchor
  table — the floor plane is FROZEN by Canon 1.
- All overlays, agent, FOW, lighting, camera — the arithmetic convention stays as is.
- `_voxel_slice_positions()`, WallSlice/HighWall/VoxelRegistry — identity reform is SLICE-02.
- Legacy subcube paths (`_render_subcube_geometry`, `_ensure_subcube_layers`,
  `wall_container.gd`, `subcube_geometry.gd`) — deletion is SLICE-01. Read-only this session.
- No renames of any kind this session.
- `VISUAL_GRID_OFFSET`, `WALL_FLOOR_STEP_PX`, gameplay constants — unchanged.

---

## ACCEPTANCE

- **A1:** `grep -n "debug_probe_voxel_alignment" godot/scripts/world/room.gd` → export var
  + probe function + one call site in `_place_wall_voxels`.
- **A2:** `godot/scripts/tools/slice_geometry_selftest.gd` exists; headless run exits 0;
  log shows the 5 check groups of T2, all passing.
- **A3:** `grep -n "VOXEL_ATOM_H\|VOXEL_TILE_H" godot/scripts/world/subcube_coords.gd` →
  both constants present. `grep -n "texture_origin" godot/scripts/world/room.gd` inside
  `_build_voxel_tileset` shows the derived expression — no integer literal other than the
  constants themselves; the "analytically correct" comment for `(0, 0)` is gone.
- **A4:** Completion report contains the T1 delta values BEFORE the fix, the matched
  classification row, and the AFTER deltas (all `(0, 0)` ± 1 px).
- **A5:** Smoke test screenshot pair (before/after): after — the wall ring sits exactly on
  the boundary of the playable floor area; level-0 cubes stand on the floor plane (no
  floating, no sinking).
- **A6:** `grep -n "Transform Canon" docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md`
  → section present with Canons 1–4. QUICK_REFERENCE contains the E1 row.
- **A7:** Godot loads clean — no parse errors, no new warnings; PROBLEMS tab clear per
  Verification Protocol.
- **A8:** `git status` shows ONLY: `room.gd`, `subcube_coords.gd`,
  `slice_geometry_selftest.gd` (+ its .uid), `VOXEL_MASTER_PLAN.md`, `QUICK_REFERENCE.md`.
  Anything else = abort and report.
- **A9:** If any STOP row of T3 was hit: no fix applied, raw deltas reported, A4/A5
  waived — the prompt ends as a diagnostic report for the design director.

Do not commit automatically.
