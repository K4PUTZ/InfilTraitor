# BAKE-FIX-02 — Room-Build Strip Walking: Run Continuity + Junction Columns

> **Part of `PROMPTS/PLANNING/BAKING_SYSTEM_MASTER_FIX.md` (Phase 2). Depends on
> BAKE-FIX-01's master-strip dictionary. Implements D-BAKE-2 (mirror-at-the-column,
> ratified) and D-BAKE-3 (material override + `facade_enabled`, ratified) — read
> `BAKING_SYSTEM_MASTER_FIX.md` §2.1 and §3 before starting.**

---

## CONTEXT

BAKE-FIX-01 produces a per-(material, facade, theme) dictionary of pre-baked atoms.
This prompt makes the room builder actually consume it: group collinear wall edges
into runs, walk the dictionary (mirroring past its end) instead of baking live, and —
the gap the Director flagged directly — give junction extra columns (`JUNCTION-01b`'s
V-junction fillers) real facade texture for the first time. Today they get none at all:
`voxel_renderer.gd::_render_junction_column()` calls `_set_voxel_cell()` with no `edge`
argument, so the baked-lookup branch never fires regardless of `BakeConfig.enabled`,
and `room_builder.gd::_bake_textures()` never even receives the junction-column list.

Ratified behavior for junction columns (Director, 2026-07-07): **always mirror** the
neighboring wall slice's boundary atom to complete the column (D-BAKE-2 — no
extend-the-crop variant, that option was dropped). Additionally, a junction column
must support an **authored override**: a different material than either meeting wall
(e.g., an iron accent column at a corner), independently of whether that column
carries facade texture at all (`facade_enabled` toggle — plain material-only columns
must remain possible, same as any other material-only voxel today) (D-BAKE-3).

---

## MODULE

- `godot/scripts/world/builders/room_builder.gd` — run grouping, `_bake_textures()`
  signature to receive junction columns
- `godot/scripts/geometry/high_wall.gd` — wire into the real build flow (currently
  dead code, referenced only by the presence-check selftest)
- `godot/scripts/geometry/junction_resolver.gd` — `JunctionColumn` gains override
  material + `facade_enabled`; `resolve()` checks for an authored override
- `godot/scripts/geometry/voxel_renderer.gd` — `_render_junction_column()` mirror logic
- `godot/scripts/systems/baked_tile_lookup.gd` — run-aware resolution, mirrored
  boundary lookup for junction columns
- MapSpec schema (wherever map authoring data is defined/parsed — locate the real
  current shape before adding a field; do not assume its structure)
- `godot/scripts/tools/geometry_selftest.gd` and/or a new test file — real,
  non-circular assertions per TASK 4

---

## TASK

### 1. Run grouping

At build time, group consecutive collinear wall edges sharing the same
material+facade+theme into a run. Use `HighWall` (`high_wall.gd`) as the container if
its existing shape fits without distortion; if it carries fields this doesn't need,
introduce a lighter grouping step instead and say which you chose and why in the
completion report. A standalone edge (no collinear neighbor) is a run of length 1 —
same code path, no special case.

### 2. Strip walking

For each run, derive its FNV-1a start offset via `FacadeSampler.get_window_origin_run_texels()`
(exists today, called from nowhere — this is where it starts being used). Walk the
BAKE-FIX-01 dictionary one atom per wall-slice-voxel position along the run, wrapping
via the already-correct `_mirror_1d`/`_mirror_2d` for any index past the strip's
baked length. `baked_tile_lookup.gd::resolve()` becomes run-aware: given an edge,
determine its run and position within it, return the corresponding dictionary atom.

### 3. Junction columns

- **Default (no override): mirror-at-the-column.** In
  `voxel_renderer.gd::_render_junction_column()`, identify the neighboring wall slice's
  boundary voxel (the true wall voxel immediately adjacent to the extra column) and
  its resolved dictionary atom; render the column with that atom horizontally
  mirrored. The column still doesn't need an independent `edge`/run position — it
  borrows and mirrors its neighbor's.
- **Override (D-BAKE-3):** `JunctionColumn` (`junction_resolver.gd`) gains an override
  `material: String` and `facade_enabled: bool`. `resolve()` checks for an authored
  override (see TASK 4) before falling back to its current behavior (derive material
  from `edge_a`, `facade_enabled = true` by default via mirroring). When
  `facade_enabled = false`, the column renders flat material-only (today's existing
  material-only voxel path — no baked lookup attempted at all, override material used
  directly). `room_builder.gd::_bake_textures()` must start receiving
  `_junction_columns` (currently passed only to `_voxel_renderer.render()`) so mirrored
  atoms can be resolved against the correct run.

### 4. MapSpec authoring surface

Locate the real current `MapSpec` shape (read the actual parser/schema in use — do not
assume). Add an optional per-junction override: keyed the same way `WallEdgeData`
already keys edges/vertices (**stated assumption** — confirm this is the right
authoring surface once you've seen the real schema; flag if it isn't and propose the
actual right place instead of forcing this shape onto it). Absent an override, current
behavior (derive material from `edge_a`, mirror facade) is unchanged — this is
additive, not a breaking schema change.

### 5. Real tests (non-circular)

Add assertions — each against a literal expected value, not "differs from the old
broken fallback":
- Default mirror: bake a synthetic 3-edge run terminating in a V-junction; assert the
  junction column's atom equals the neighboring wall voxel's atom, horizontally
  mirrored, pixel-for-pixel.
- Override + `facade_enabled = true`: assert the column's atom comes from the
  override material's strip (mirrored), not the wall's own material.
- Override + `facade_enabled = false`: assert the column renders the override
  material flat (no baked lookup attempted — verify via the same branch-exclusivity
  mechanism B1 already checks).

---

## DO NOT TOUCH

- BAKE-FIX-01's strip-baking logic itself (`bake_compositor.gd`'s per-atom crop+alpha)
  — this prompt only consumes the dictionary, doesn't change how it's built.
- `junction_resolver.gd`'s V/T/X **detection** logic (which cells get a column, where)
  — correct, verified, not in question here. Only the column's *material/texture*
  changes.
- `TextureResolver`, `MaterialRegistry` pattern algorithms — unchanged.
- `BakeConfig.enabled` — stays `false`.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script <new/updated test file>
# expected: literal PASS lines for all 3 TASK 4 cases, each showing the actual
# pixel/material comparison, not just "PASS"

python3 tools/persistent/check_invariants.py
```

- Completion report shows: (a) a run of 3+ edges resolving to consecutive dictionary
  atoms with correct mirroring at the boundary, (b) the default junction-column mirror
  case, (c) both override cases (facade on/off) — each with literal evidence.
- If the `MapSpec` authoring surface assumption (TASK 4) didn't hold, the report says
  so explicitly and states what was actually done instead.
- Bump `VERSION` per repo convention.

---

**Scope:** ~5-6 files touched · 1 session · unblocks BAKE-FIX-03 (visual QA needs
runs + junction columns actually wired to look at).
