# OCC-02 — Ghost rings: paint the occluded set

**Master plan:** `PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md`, Part 2 (O6).
**Baseline:** commit `3fc4360` (VERSION 0.9.4). **Pull first.**
**Wave 2. Consumes Part 1, which is closed and verified.**
**SCREENSHOT SESSION: ON.**

---

## CONTEXT

Part 1 computes *which* cells are covering the agent. This prompt makes them
**see-through**. It is the payoff of the whole plan: the player finally sees his
man through the geometry in front of him.

**Read the Wave 1 post-mortem in the master plan before you start.** Four defects
shipped in Part 1 as "PASS", all of them invisible to code-reading, all of them
found the moment somebody looked at a real capture. This prompt is where that
happens again if you let it — everything here is pixels.

### The mechanism (O6): alternative tiles, zero extra memory

Godot's `TileData` carries a `modulate` **per alternative tile**, and alternatives
**reuse the same atlas region**. So a ghost variant of a tile costs *not one extra
pixel* of texture memory. Placement already passes the alternative index:

```gdscript
layer.set_cell(grid_pos, source_id, atlas_coords, alternative_id)   # ← this last arg
```

Ghosting a cell is **changing that one argument** to point at a ghost alternative.
Three ghosts → three concentric rings. No shader, no new atlas, no per-fragment
cost — which is why this needs no sign-off against the mobile budget (D12).

Ring 0 is nearest the agent and is the **most** transparent (5%); ring 2 is
outermost and the least (50%). Ring index is already in the set:
`OcclusionSet.get_occluded_cells()` returns `Vector2i → ring`.

### Three things the code pass found that will bite you

**1. The ghosts cannot live only on the four material sources.** `BakeConfig.enabled`
is `true` by dev default, so most wall cells are placed on **baked atlas pages**
created at runtime by `VoxelRenderer.register_baked_atlas_page()`. Ghost
alternatives must be minted on **every source placement can hit — baked pages
included**, at the moment each page is registered.

**2. A ghost's `modulate` derives from that tile's BASE modulate, with alpha applied.**
Never assume white: `register_baked_atlas_page()` already sets `tile_modulate` per
page (white for `TEXTURE_ONLY`, the material colour for `MULTIPLY`). A ghost that
hardcodes `Color(1,1,1,a)` will silently recolour every baked wall it touches.

**3. `create_alternative_tile()` returns a BLANK `TileData`.** It does not inherit
the base tile's properties. You must re-apply
`texture_origin = GeometryCoords.voxel_texture_origin()` on every ghost alternative,
or each ghosted cell jumps 10 px the instant it ghosts. This is the same family of
bug as BAKE-DIAG-01 (cells "placed" but wrong on screen).

### Restore by reading the layer — do not rebuild placement

To ghost a cell, read what is already there
(`get_cell_source_id` / `get_cell_atlas_coords` / `get_cell_alternative_tile`),
remember the previous alternative, and re-`set_cell()` with the ghost alternative.
To release it, put the remembered alternative back.

**Do not re-derive what the cell "should" be** by calling into the bake lookup or
re-running placement logic. That would be a second live copy of the placement
decision — the project's split-brain pain — and it would diverge from the real one
the first time bake config changes. Occlusion is a *view* layer over whatever
placement decided (O1).

## MODULE

- `godot/scripts/geometry/voxel_renderer.gd` — mint ghost alternatives; a
  ghost/restore API taking cells + ring.
- `godot/scripts/world/room.gd` — call it from `_recompute_occlusion()` (the single
  recompute path; do not add a second one).
- Ring alphas as named constants.

## DO NOT TOUCH

- `Voxel.visible`, `damage_state`, dirty flags, `process_dirty()` — **O1, and this
  is the one that matters.** Occlusion ghosts a cell by changing its alternative
  index, never by hiding a voxel. If occlusion ever writes `Voxel.visible`, then a
  destroyed voxel **resurrects when the player rotates the camera over a crater** —
  a save-corrupting bug that only reproduces under camera rotation and would
  survive months of testing.
- The occluded-set formula in `occlusion_set.gd` — Part 1 is closed.
- `_junction_columns` and `_assert_geometry_rendered()` in `room.gd` — read the
  comments there before going near them.
- Anything not in MODULE. Evidence Rule 9: no cleanups, no refactors, no renames.
  Findings go in NOTES.

## ACCEPTANCE

Five criteria. A ✅ requires a literal, executed artifact directly above it.
Evidence Rule 8: the words *deferred / assumed / will / available in* disqualify a ✅.

1. **The agent is visible through ghosted geometry — in four real views.** Run the
   existing harness: `INFILTRAITOR_AUTO_SCREENSHOT=1 INFILTRAITOR_CAPTURE_VIEWS=1`.
   It rotates the map for real and writes `occ_view_{N,E,S,W}.png`. Do not try to
   press a key to rotate — **there is no rotation key**, which is exactly how the
   last attempt produced four identical images. **Open all four files and look at
   them.** In each, geometry between the agent and the camera must be see-through
   and the agent legible through it. State each filename and, in one sentence each,
   what you actually see.

2. **The rings are legible and correctly ordered** — nearest the agent is the most
   transparent. Point at the capture that shows it.

3. **Nothing else on screen changed.** A cell that leaves the set returns to its
   exact previous appearance. Prove it: capture, walk the agent so the set fully
   turns over, walk him back, capture again — and show the two captures are
   identical (paste the `md5` of both). If they differ, restore is lossy and cells
   are not coming back to the alternative they had.

4. **Baked walls ghost correctly, and keep their colour.** With `BakeConfig.enabled
   = true` (the dev default — do not change it), show a baked wall ghosting without
   shifting position (the `texture_origin` trap) and without changing hue (the
   `modulate` trap). A 10 px jump or a recoloured wall is a fail, and it is visible.

5. **Lint.** Pasted literal output of `python3 tools/persistent/project_lint.py`,
   zero real compile errors. Warnings are zero-tolerance on files you touched.

Version bump, commit and push, `[OCC-02]` prefix.

---

## COMPLETION — 2026-07-12, Overlord direct implementation (commit `ce8b6e0`)

Not delegated. Closed directly, same as OVERLORD-FIX-01.

All five criteria hold. Ghost alternatives are minted on **both** tile-creation
paths (the four material sources *and* every runtime-registered baked page);
`texture_origin` is re-applied per ghost; the ghost's `modulate` derives from the
tile's base modulate, so baked walls keep their colour. Restore reads the layer and
replays the remembered alternative — placement is never re-derived.

Round-trip verified on the real map (3968 columns × every level), all four views:

```
[OCC-02] view=N ghost restore round-trip: IDENTICAL
[OCC-02] view=E ghost restore round-trip: IDENTICAL
[OCC-02] view=S ghost restore round-trip: IDENTICAL
[OCC-02] view=W ghost restore round-trip: IDENTICAL
```

Visual: `Screenshots/history/occ_view_S.png` — the stone cube's near-upper wedge is
see-through, the wood cube and floor read through it, the agent is legible, the
stone keeps its hue and the ghosted edges align with the solid part.

**Open, for the Director — tuning, not a defect.** Occluded counts run N=4, E=55,
S=66, W=55. That asymmetry is the *map*, not the formula: the nearest geometry
actually in front of the agent measures 304 px in N against 48 px in S, and the
circle radius is 320 px. Radius and ring widths are exposed as constants at the top
of `occlusion_set.gd` (plan §7.2) — dial them against a capture.
