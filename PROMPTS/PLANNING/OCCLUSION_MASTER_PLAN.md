# OCCLUSION_MASTER_PLAN
## Seeing the Agent — View Occlusion, Agent Silhouette, Interior Cutaway — v1.0

**Status:** 🟡 IN PROGRESS. Parts 1+2 (occlusion set + visual) closed and rebuilt
several times over on real Director feedback — current mechanism is the per-EDGE,
graph-walk model with a fixed always-visible base band, junction-column
occlusion, and a true hull-outline wireframe (O3‴/O10/O11/O12, Wave 3.9, closed
2026-07-14). Part 3 (agent-on-top) closed; the silhouette-stroke half is
superseded (O7). Part 4 (interior cutaway) still blocked on
`DESTRUCTION_MASTER_PLAN`'s `Slab`. **Runs BEFORE `DESTRUCTION_MASTER_PLAN`**
(Director's call, 2026-07-12): it is independent of destruction, it is the
visible win, and it is the cheaper of the two.
**Baseline:** tag `verified/v0.9.0`. No `verified/` tag cut for this plan's work
yet — `main` is ahead at VERSION 0.9.9+ with Waves 1 through 3.9. Director's call
on when to tag.
**Companions:** `DESTRUCTION_MASTER_PLAN.md` (which owns `Voxel.visible` — see §2),
`docs/technical/BAKE_SYSTEM_REFERENCE.md`.
**Authored by:** the Overlord, from the Director brainstorm of 2026-07-11/12.
Waves 2.5 onward built by the Overlord directly, live in session with the
Director against real screenshots — see §6 for the full build log.

---

## 1. Why — and what "occlusion" actually means here

The design goal, in the Director's words: **"the player sees what the agent
sees."** The player has access to what is in the agent's room — not what is
behind it.

But "occlusion" is being used for **three different problems**, and only one of
them is occlusion. Separating them is most of the work:

| # | The complaint | The actual fix | Touches voxels? |
|---|---|---|---|
| **(a)** | "I can't see my agent behind a wall." | Draw the agent **on top of everything**, with a **stroke on the part of his silhouette that is behind geometry** — the whole silhouette behind a wall, legs-to-waist behind a crate. Reveals exactly one thing: your own guy. | ❌ No |
| **(b)** | "I can't see inside a building." | **Slab cutaway by level** — the ceiling Slab's layer is hidden. Here the reveal is *intentional*: entering the building is the reward for infiltrating it. | ❌ No |
| **(c)** | "Foreground geometry is covering the agent." | **This is real occlusion.** Ghost the geometry between the agent and the camera. | ❌ No (see O1) |

**None of the three touches voxel state.** That is the plan's spine.

---

## 2. O1 — Occlusion is VIEW, not STATE (the load-bearing decision)

**This is the one that, if broken, produces a save-corrupting bug nobody will
find for months.**

`Voxel.visible` **already has an owner**, and it is destruction:

```gdscript
## Apply damage state; DESTROYED forces visible=false
func set_damage(new_state: int) -> void:
    ...
    if new_state == DamageState.DESTROYED:
        visible = false
```

| Concern | Owns | Persists? | Cadence | May write `Voxel.visible`? |
|---|---|---|---|---|
| **Destruction** | `Voxel.visible`, `damage_state`, `blocked_cells`, cover, noise | **Yes** — world state, enters the save | Per detonation (rare) | ✅ **Sole writer** |
| **Occlusion** | `_occluded_cells` — its own set | **No** — a camera artifact | Per agent step + per camera rotation (**frequent**) | ❌ **Never** |
| **Fog of war** | Scenery discovery | Yes | Per agent step | ❌ Never |
| **Actor visibility** | The **agent-knowledge system** (radar / noise / line of sight) — a separate front | Yes | Per turn | ❌ Never |

**The bug this prevents:** occlusion ghosts a wall by setting `visible = false` →
the TIC erases the cell → the player **rotates the camera** → occlusion releases →
`visible = true` → **and a destroyed voxel resurrects.** It only ever reproduces
when someone rotates the camera over a crater, which is why it would survive
months of testing.

Occlusion also **never uses the dirty flag**. Its cadence is wrong for it: a
detonation is rare and capped; an agent step is *constant*. Routing occlusion
through `process_dirty()` would make the common case far more expensive than the
rare one — exactly backwards.

### O2 — Cross-plan contract: actors are not hidden by geometry

**An actor the agent does not know about is not drawn.** Actor visibility belongs
to the agent-knowledge system (radar, noise, line of sight — a separate front),
**never** to geometry.

This is what makes wall transparency *structurally incapable* of leaking enemy
positions: ghosting a wall cannot reveal a guard, because a guard the agent does
not know about was never rendered in the first place. The guarantee is by
construction, not by luck.

**If anyone ever makes actor rendering depend on geometry occlusion, this
guarantee dies silently.** That is why it is written here.

---

## 3. Decision Register

| O | Decision | Status |
|---|---|---|
| **O1** | **Occlusion is VIEW, not STATE.** Never writes `Voxel.visible`, never uses the dirty flag, never persists, never enters the save. State lives in `_occluded_cells`, owned solely by the occlusion system. See §2. | ✅ Ratified |
| **O2** | **Actors are hidden by knowledge, never by geometry** — cross-plan contract, §2. | ✅ Ratified |
| **O3** | ~~The occluded region is an enlarged circle around the agent~~ **SUPERSEDED by O3′ 2026-07-14.** The "is it covering him" criterion carries forward unchanged; the circle-shaped implementation of it did not survive contact with real play. | ⛔ Superseded |
| **O3′** | ~~Occlusion is decided per GAMEPLAY CELL, in a screen-space corridor behind the agent's own silhouette~~ **SUPERSEDED by O3″ 2026-07-14, same session.** Fixed the circle's worst problems (metal/concrete leak) but a whole gameplay-cell's generic diamond footprint still didn't match a wall's real (thin) shape — still over-selected width-wise and produced an unresolved wireframe artifact. | ⛔ Superseded |
| **O3″** | ~~Occlusion is decided per SLICE, using the slice's own real voxel positions, plus a depth cap~~ **SUPERSEDED by O3‴ 2026-07-14, same session.** Fixed the width leak and the wireframe artifact, but `silhouette_half_width_px` (a corridor) + `max_depth_voxels` (a distance cap) were both ad-hoc proxies for one real question — does this structure's screen footprint overlap the agent's? — and neither tunable could express "far away but TALL enough to still reach over him", a real reported case. | ⛔ Superseded |
| **O3‴** | **Occlusion is decided per EDGE — the real wall-COLUMN object (every storey it has, both its faces), not per slice (one storey) — via a genuine 2D screen overlap test against the agent's own silhouette, then spread along the wall's own connectivity graph.** Director's reframing, 2026-07-14: "essa EDGE está mais pra baixo do agente, e tem alguma slice em algum dos storeys pra cima dessa edge que cobre o agente?" `OcclusionSet.compute_edge_occlusion()`: (1) group slices by `edge_id`; (2) for each edge, compute real screen-X span (from its own voxels, as O3″) **and now also real screen-Y span** (ground to its own top, across every storey) from its actual `Voxel.level` range; (3) **trigger test is real 2D AABB overlap** against the agent's own screen silhouette (width AND height, tracking `agent.gd`'s `SILHOUETTE_WIDTH`/`HEIGHT`) — camera-side is still required, but the old corridor-width-only test is gone. This is what makes a distant multi-storey structure correctly trigger when its upper storeys are tall enough to visually reach over the agent even though its base is nowhere near him ("ela vai ser um edifício que está em primeiríssimo plano, e não pode ficar cobrindo o agente") — a case the width+depth-cap model structurally could not express. (4) **Ring falloff is a graph walk, not a distance**: two edges are adjacent if they share a grid VERTEX (corner) — real wall topology. A multi-source BFS from every triggering edge, up to 2 hops, assigns ring 0/1/2; a 4-way junction naturally branches to every wall that meets there ("incluindo todos os 4 encontros da encruzilhada ao mesmo tempo"), which a distance metric could not do correctly. No separate depth cap is needed — the walk is inherently bounded to whatever physically connects. **Refined same day (still O3‴): the graph walk only propagates through a vertex that is a simple pass-through (exactly one other edge there) continuing in the SAME face/direction** — a junction (2+ other edges) or a direction change (a turn) stops the ring right there. Director caught the gap with an annotated screenshot: without this, the walk could wrap around a box's own corner onto its side wall. Verified: E/W edge counts dropped 8→6 once fixed (the wrap-around gone), N/S unaffected (already correct). | ✅ Ratified |
| **O3⁗** | ~~A vertical reveal cutoff (OCC-09) clips the BOTTOM of an occluded edge's tower — both the ghost fill and the wireframe — based on how far below the agent's own screen-ground position that tower's lower voxels sit.~~ **SUPERSEDED by O10, 2026-07-14, next session.** The mechanism itself worked (confirmed via live diagnostic dump before shipping) but the Director disliked the RESULT once seen live: a tower's lower storeys popping back to fully OPAQUE read as worse than the ghost it replaced ("não é péssimo mas também não é bom"). See O10. | ⛔ Superseded |
| **O10** | **The always-visible base band replaces O3⁗'s pixel-threshold reveal.** Director's simplification: instead of computing how far below the agent's screen-ground an edge's lower voxels sit, just fix it — an occluded edge's own bottom `OcclusionSet.BASE_VISIBLE_LEVELS` (2) levels, full width, both faces (an 8×2×2 footprint per edge) are left **completely untouched** — always full opacity, always reading as solid ground-truth geometry, regardless of ring. Everything above that band ghosts at the ring alpha exactly as O6″/O6‴ already do — unchanged. No agent-relative math anywhere in this part any more. **First implementation attempt inverted this** (ghosted the base, fully hid everything above via a new 4th "hidden" alternative tile) and shipped it far enough to real-capture before the Director caught it live and corrected the model to what's described here — the hidden-alternative mechanism was verified working via a temporary opaque-red diagnostic override, then removed entirely once the design changed and it was no longer needed. Verified 2026-07-14 against real four-view captures (N/E/S/W) on the PLAYGROUND/TEXTURES fixture: every occluded corner shows a solid opaque footprint at its base with a translucent tower above, matching the Director's own reference diagram. | ✅ Ratified |
| **O11** | **Junction filler columns (`JunctionResolver.JunctionColumn`) now participate in occlusion.** They own no `Slice`/`Edge` of their own (they fill the diagonal notch at a V-junction or open wall-end), so O3‴'s per-edge trigger test structurally cannot see them. Director's rule, confirmed on annotated screenshots: a junction column ghosts (same O10 base-band-visible/rest-translucent split, always ring 0 — it has no ring of its own to inherit and picking between its two neighbors' would be an arbitrary tie-break) **only when BOTH edges it fills the elbow between are themselves occluded**; if only one side is occluded, the column stays fully visible always. `OcclusionSet.recompute()` takes the room's `_junction_columns` array (already built by `JunctionResolver`, previously unused by this system) as a new parameter. | ✅ Ratified |
| **O12** | **`OcclusionWireframeOverlay` rebuilt again — SUPERSEDES O6‴'s per-edge/per-Slice panels with a true hull outline of the whole erased object.** Director's brief, 2026-07-14: "não se importe com slices, edges ou voxels, apenas trace as linhas que representam o objeto tridimensional que foi apagado... incluindo as colunas extras de V junctions" — one box per contiguous straight run of occluded geometry, not one per internal data-structure boundary. Root-caused the reported "diagonal seam" artifact along the way: O6‴'s per-edge `corner_a`/`corner_b` came from each edge's OWN independently-scanned voxel min/max, which do not necessarily agree with a neighbor's at a real corner once two DIFFERENT faces are involved (their local scan axes differ) — visibly, two adjacent panels' "shared" corner were actually two slightly different points, drawn as a stray diagonal connecting them. Fix: `OcclusionSet._build_wireframe_segments()` walks the occluded set's own connectivity graph (the same shared-grid-vertex adjacency the ring BFS already builds) and merges every straight, same-face, same-height run into ONE segment, using the one true shared grid VERTEX (`_edge_vertices`) at every join — identical on both sides by construction, so two segments meeting at a real corner can never disagree about where it is. V-junction columns need no special-casing: a corner column only ever exists where two edges meet at a real elbow, and per O11 it only ghosts when both are occluded — exactly when this walk already treats that vertex as a real corner joining two segments, closing the notch it would otherwise leave. The per-LEVEL panel/z-index mechanism itself (O6‴, `OcclusionSlicePanel`, one child per voxel-layer z_index) is UNCHANGED and still load-bearing — segments still spawn one band per level so nearer solid geometry still correctly occludes the wireframe. Verified 2026-07-14 against real four-view captures: every occluded corner reads as one clean, unbroken box (or L-shape) with no internal seams and no diagonals, correctly dashed/hidden where nearer opaque geometry (the O10 base band, or an unrelated nearer wall) covers part of it. | ✅ Ratified |
| **O4′** | **Occlusion operates in the already-rotated view frame, and the formula does NOT rotate.** *Corrects the original O4, which said the formula "rotates with the views" — it must not.* **The camera never rotates.** A view change is a full rebuild of the map into view-space: `room.gd::_set_perspective()` → `PerspectiveMapper.layout_with_perspective()` → `RoomBuilder.build_from_layout()` → `VoxelRenderer.clear()` + `render()`. Agent cell, voxel cells, lights and patrol routes are all re-emitted rotated; the isometric projection is a single fixed one. Occlusion therefore uses **one view-space formula with zero dependence on `_active_perspective`** — applying a rotation to already-rotated coordinates double-rotates, which is correct in view N and points the ghost region the wrong way in the other three. **The occlusion module never reads `_active_perspective`.** | ✅ Ratified (restated 2026-07-12, Director) |
| **O5** | **Depth is NOT `z_index`.** `layer.z_index = _wall_base_z_index + level` encodes **storey**, not depth — a wall in front of the agent and a wall behind him, on the same storey, share a z-index. Depth in isometric comes from world position (`x + y` in the rotated frame) / y-sort. **Selecting occluders by z-index would ghost every upper storey *including everything behind the agent*** — the exact opposite of the goal. | ✅ Ratified |
| **O6** | ~~Concentric ghost rings — 5% / 25% / 50% alpha — via TileSet alternative tiles.~~ **SUPERSEDED by O6′ 2026-07-13** — see below. Shipped and played; the gradient produced a "serrated" look in real play (adjacent faces of the same wall landing in different rings, stacking into a visible patchwork), which is what triggered the replacement. The alternative-tile mechanism itself (zero extra texture memory, zero per-fragment cost) carries forward unchanged into O6′. | ⛔ Superseded |
| **O6′** | ~~Binary flat-fill — no gradient, one flat low alpha for every occluded cell~~ **PARTIALLY SUPERSEDED by O6″ 2026-07-14** (the flat-fill *mechanism* — ghost alternatives, zero per-fragment cost — carries forward; the *"no gradient"* decision does not, see O6″). Still ratified from this session: no silhouette stroke on the agent (O7 revised below) — full-hide already makes him fully visible, nothing to stroke. Wireframe drawing itself superseded by O3″ then O6‴ — see those rows. | ⛔ Partially superseded |
| **O6″** | **The 3-ring alpha gradient returns — but the ring now comes from OcclusionSet's edge-graph hop distance (O3‴), not Euclidean voxel distance.** Director, 2026-07-14: reintroducing the ring/falloff was explicitly requested once occlusion moved to a per-EDGE decision — an edge (and its whole slice tower) shares ONE ring, so there is no per-voxel patchwork within a single wall to serrate the way O6's voxel-circle rings did. `VoxelRenderer.GHOST_ALT_IDS`/`GHOST_ALPHAS` restored to 3 entries, initially 3%/10%/50%, retuned same day to 3%/6%/10%, **retuned again 2026-07-14 (next session) to 4%/8%/16%** once seen live against the O10 always-visible base band. Zero per-fragment cost unchanged (still alternative tiles, no shader) — D12 exemption unaffected. | ✅ Ratified |
| **O6‴** | **`OcclusionWireframeOverlay` rebuilt onto per-LEVEL panels stamped with each level's real voxel-layer z_index (OCC-07-b).** The Slice-shaped rectangle (one per occluded slice, its own real corners/levels, O3″-era) was correct in shape but wrong in draw order: it lived on a single flat elevated `Node2D` (z_index 150, always on top), so a ghosted wall's outline showed straight through nearer, UNOCCLUDED geometry that should have covered part of it (Director's annotated screenshot: the outline visible below where the box's own solid front walls should have hidden it). Root cause: `TileMapLayer`/`Node2D` both default `y_sort_enabled = false` in this project (confirmed by direct query, not assumed) — same-z_index siblings only resolve by scene-tree order, never by screen position, so nothing but a matching z_index could have fixed it. Fix: the overlay manager no longer draws anything itself; for each occluded edge it spawns one `OcclusionSlicePanel` child per LEVEL the (now vertically-clipped, see O3⁗) span covers, each reading its z_index directly off `VoxelRenderer.get_layer(level).z_index` — never re-derived. **"Venetian blind" rung artifact CLOSED same day**: only the topmost and bottommost band draw their horizontal cap edge (`OcclusionSlicePanel.draw_top`/`draw_bottom`); every level boundary in between is an internal seam, not a real silhouette edge. The two verticals still draw per level (that's what keeps them individually maskable against blockers) and read as one unbroken line since consecutive bands share exact endpoints. Verified 2026-07-14 against real four-view captures at every step. **The per-LEVEL/z_index mechanism itself carries forward unchanged into O12 (2026-07-14, next session); only the GROUPING — one panel per raw Slice/Edge — was superseded there**, once real screenshots caught adjacent edges' independently-scanned corners disagreeing at shared vertices (a visible diagonal artifact O6‴ shipped with, undetected until seen live). | ✅ Ratified |
| **O7** | ~~Agent drawn on top, with a silhouette stroke over the occluded portion.~~ **REVISED 2026-07-13.** Agent-on-top stands (OCC-03, unchanged) — but the stroke half is dropped: O6′'s full-hide means nothing partially covers him anymore, so there is nothing left to stroke. Director's call: "vamos deixar o stroke como uma futura possibilidade" — parked, not scheduled. **OCC-04 (Part 3b) is superseded, not started** — see §6. | ✅ Ratified (revised) |
| **O8** | **Interior cutaway is DEFERRED — it depends on `Slab`**, which is `DESTRUCTION_MASTER_PLAN` D1. **No map has a ceiling today**, so there is nothing to cut away: this is a fact, not a limitation. Part 4 is written but does not start until Slabs exist. | ⏸️ Blocked (by design) |
| **O9** | **Ceiling-hung props and foreground parallax decoration** also need occluding — same mechanism, different layer. **Confirmed 2026-07-13: neither exists yet.** No roof-rendering system exists anywhere in `godot/scripts/` (a `LAYER_OVERHEAD` height band is defined in `tile_semantics.gd` but nothing draws into it). `CeilingPropOverlay` draws placeholder lamp glyphs only, not integrated with the real `PropDef`/`PropRegistry` prop system — there is no solid ceiling geometry to occlude. Stays deferred until one of those becomes real. | ⏸️ Deferred |

---

## 4. Mechanism — how it actually works

**Step 1 — Who occludes (CPU, tiny).**
**(2026-07-14, O3″)** The set of `Slice`s — the real wall-panel objects
`SliceGenerator`/`EdgeRegistry` already build for rendering — that (i) sit on the
camera side of the agent, (ii) within `max_depth_voxels` of him, and (iii) overlap
the screen-space corridor directly behind his own silhouette. A few dozen slices
at most. Recomputed on **agent step** and on **camera rotation** — never per frame.

**Step 2 — How to paint it (zero extra memory).**
Placement already passes the alternative index:

```gdscript
_voxel_layers[level].set_cell(pos, source_id, atlas_coords, 0)   # ← this 0
```

Ghosting a cell is **changing that one argument** to point at a ghost
alternative. **(2026-07-13, O6′)** One ghost, one flat low alpha, for every
occluded cell — not three rings. No shader. No new atlas. No per-fragment cost.
Definition comes from a separate wireframe overlay, not from the ghost itself —
see Step 4.

**Step 3 — Where the state lives.**
`_occluded_cells`, owned solely by the occlusion system (O1). When the set
changes, the cells that left it are restored to alternative `0` and the ones that
entered are set to the hidden ghost. Nothing else in the engine is told.

**Step 4 — The silhouette (O6′ added 2026-07-13, rebuilt on Slices 2026-07-14).**
`OcclusionWireframeOverlay` reads `OcclusionSet.get_occluded_slices()` directly and
draws one rectangle per slice, from that slice's own real corner voxels and level
range — no aggregation, no boundary-suppression logic, because a slice is already
the atomic, non-overlapping unit. See Decision O3″ and the Wave 3.5 build log.

---

## 5. Parts

### Part 1 — The occluded-slice set *(O3″, O4′, O5)*
Compute, per agent step and per view change, the set of `Slice`s that stand
between the agent and the camera — camera-side, within `max_depth_voxels`, and
overlapping his screen-space silhouette corridor — **in view-space, with a single
non-rotating formula** (O4′). Pure computation — no rendering change, verified by
a debug overlay that paints the set, checked in all four views. **This is the
novel geometric piece and it lands alone**, per the prompt-sizing rule. Reworked
2026-07-14 from an earlier gameplay-cell version — see O3″.

### Part 2 — Binary hide + wireframe silhouette *(O6′, supersedes O6)*
~~Three ghost alternatives on the voxel TileSet~~ **one flat-alpha ghost** alternative;
placement swaps the alternative index for cells in the set. Definition comes from
`OcclusionWireframeOverlay`: one rectangle per occluded slice, from that slice's
own real corners and levels. Verified with real four-view screenshots: agent
visible through hidden geometry, each occluded wall panel outlined as itself (not
a per-voxel mesh, not a generic box), nothing else on screen changed.

### Part 3 — Agent on top *(O7, revised)*
Placeholder bounding box at standing-character dimensions, drawn above all voxel
layers (OCC-03). ~~Stroke only over the portion actually behind geometry.~~ Dropped
2026-07-13: O6′'s full-hide already leaves nothing partially covering him, so
there is nothing left to stroke. OCC-04 (the stroke prompt) is superseded, not
built. Parked as a future possibility if a different occlusion treatment ever
needs it again.

### Part 4 — Interior cutaway *(O8)* — **does not start until `Slab` exists**
Ceiling Slab layer hidden when the agent is inside. Blocked on
`DESTRUCTION_MASTER_PLAN` Part 1 by construction; no map has a ceiling today.

---

## 6. Wave sequencing

```
Wave 1:  Part 1 (occluded-cell set)   → ✅ CLOSED 2026-07-12 (OCC-01 + OCC-FIX-02)
         Part 3a (agent on top)       → ✅ CLOSED 2026-07-12 (OCC-03)
Wave 2:  Part 2 (ghost rings)         → ✅ CLOSED 2026-07-12 (OCC-02, Overlord direct)
         Part 3b (silhouette stroke)  → OCC-04, consumes Part 1 — NEXT
Wave 2.5: Live bugfix pass            → ✅ 2026-07-13 (Overlord direct): console noise,
         source leak fixed, circle_radius_voxels 20→32.
Wave 3:  Part 2 replaced (O6′)        → ✅ 2026-07-13 (Overlord direct): binary flat-fill
         + OcclusionWireframeOverlay, verified against a real four-view capture.
         Part 3b (silhouette stroke)  → SUPERSEDED, not built — see O7.
Wave 3.5: Part 1+2 rebuilt on Slices (O3″) → ✅ 2026-07-14 (Overlord direct): per-cell
         corridor replaced by per-Slice decision + depth cap; wireframe redrawn as
         one real panel rectangle per slice. Verified against real four-view captures.
Wave 3.6: Part 1+2 rebuilt on Edges (O3‴/O6″/O6‴) → ✅ 2026-07-14 (Overlord direct,
         same day): per-Slice decision replaced by per-EDGE decision with a real 2D
         screen-overlap trigger test + edge-graph BFS ring falloff (3-ring gradient
         restored, keyed by hop distance not voxel distance); wireframe z_index bug
         fixed (panels now match their own level's real z_index — see O6‴); rung
         artifact closed (only top/bottom bands draw a cap edge).
Wave 3.7: Direction/junction stop + vertical reveal cutoff (O3‴ refined, O3⁗) →
         ✅ 2026-07-14 (Overlord direct, same day): ring no longer wraps around a
         corner onto a perpendicular wall; ring alphas retuned 3%/6%/10% (50% "muito
         forte"); a new vertical cutoff (vertical_reveal_px) lets a tower's lower
         levels stay visible once they sit far enough below the agent's own
         screen-ground position — found and fixed a real bug in the same pass where
         the fill wasn't actually respecting the cutoff (only the wireframe was).
Wave 3.8: Always-visible base band + junction-column occlusion (O10/O11) →
         ✅ 2026-07-14 (Overlord direct, next session): O3⁗'s pixel-threshold
         reveal cutoff replaced by a fixed base band (2 levels, full width, both
         faces) that's never touched at all — always full opacity — while
         everything above it ghosts at the ring alpha exactly as before; a first
         attempt inverted this (ghosted the base, hid the rest) and was caught
         live and corrected. Junction filler columns now occlude too, only when
         both edges they join are themselves occluded. Ring alphas retuned
         4%/8%/16%. Wireframe temporarily disabled (real diagonal-seam artifact,
         root-caused and fixed next wave).
Wave 3.9: Wireframe rebuilt as a true hull outline (O12) →
         ✅ 2026-07-14 (Overlord direct, same session): superseded O6‴'s
         per-edge/per-Slice panels — `OcclusionSet._build_wireframe_segments()`
         walks the occluded set's own connectivity graph and merges every
         straight, same-face, same-height run into one segment using true
         shared grid vertices, root-causing and closing the diagonal-seam bug
         (independently-scanned per-edge corners could disagree with a
         neighbor's at a real corner). V-junction columns included with no
         special-casing — they fall out of the same vertex-adjacency walk.
         Wireframe re-enabled. Verified against real four-view captures: every
         occluded corner is one clean, unbroken box with no internal seams.
Wave 4:  Part 4 (interior cutaway)    → BLOCKED until DESTRUCTION Part 1 (Slab)
```

### Wave 2.5 — live debugging session (2026-07-13, Overlord direct implementation)

The Director play-tested Wave 1+2 interactively (PLAYGROUND/TEXTURES map, four
material blocks around the agent) and reported a batch of symptoms. Triaged and
fixed here; two findings change how the plan reads going forward.

**Fixed, confirmed via lint + a real `INFILTRAITOR_CAPTURE_VIEWS=1` run:**

- **Noisy console errors** (`TileSetAtlasSource has no alternative with id N...`,
  thousands per rotation). `_mint_ghost_alternatives()` probed
  `get_tile_data(coords, alt_id) != null` as an "already minted?" check before
  creating each ghost — but `source` is always freshly created at both call sites
  (a brand-new `TileSetAtlasSource` per `register_baked_atlas_page()` call, or one
  of the four MATERIALS sources built exactly once), so the probe was always false
  and existed only to make Godot log a spurious ERROR on every miss. Removed; the
  mint now runs unconditionally. **0 errors** after the fix (was in the thousands
  per four-view capture).
- **`TileSetAtlasSource` leak on every rebuild.** `register_baked_atlas_page()`
  always calls `_tileset.get_next_source_id()` — a fresh source per view rotation
  — and `VoxelRenderer.clear()` only cleared placed cells, never the registered
  sources. `_tileset.source_count` grew unbounded across rotations (16 → 28 → 40
  → 52 over N→E→S→W in one test). Added `VoxelRenderer.prune_baked_sources()`,
  called from `RoomBuilder._bake_textures()` **before** the new pass registers its
  pages (not from `clear()`, which runs *after* baking and would delete the pass
  that was just built). `source_count` now holds steady at 16 across all four
  views. The four MATERIALS sources are untouched — only baked-page sources are
  tracked and pruned.

**Investigated and closed as NOT a bug — real evidence, not code-reading:**

- **"Occlusion only visible in one direction."** The Director's read was that view
  rotation needed a missing recompute trigger. It doesn't — `_recompute_occlusion()`
  was already wired into `_set_perspective()` and fires on every real rotation.
  Two decisive tests killed the two live hypotheses:
  1. *Boot-sequencing* (recompute running before the agent is placed): ruled out —
     `agent.setup()` completes inside `load_map()`, which runs before the
     occlusion module even exists. Confirmed by temporarily changing
     `_active_perspective`'s boot default from `"N"` to `"S"`: the *newly*
     boot-default direction computed correctly (66 cells) and the direction
     reached via a genuine rotation (`N`, arrived at from S) **still** came back
     small (4 cells) — so it isn't about which direction boots first.
  2. *Coordinate-convention mismatch* (the identity/"N" view not respecting the
     "larger x+y = nearer camera" assumption O4′ requires): also ruled out. A
     temporary diagnostic dump inside `compute_occluded_cells()` showed N actually
     had the **most** cells pass the camera-side depth test of any view (2152,
     vs. 1768–1960 for E/S/W) — the depth formula is fine. Of those, only 4 fell
     within `circle_radius_voxels = 20`. Bumping the radius to 32 (temporary test)
     brought N to 120 occluded cells with visible ghosting in the capture — same
     order of magnitude as the other three views.
  - **Conclusion: `circle_radius_voxels = 20` is simply too small for this test
    map's block spacing, and it happens to bite hardest in the N direction**
    because the nearest occluding geometry from that specific camera angle sits
    farther from the agent than in the other three. Not a code bug, not an O4′
    violation risk — a tuning value. All temporary diagnostic code (prints, the
    boot-default edit, the radius bump) was reverted; `git diff` on both touched
    files was empty before the real fixes above were made.
  - **This is the same lever as the Director's separate "extend the ring
    downward/laterally" request below** — one radius (and possibly ring-width)
    change should address both. Not yet applied; needs a Director-supervised
    tuning pass against a live screenshot, not a guessed number.

**Also raised, resolved without a code change:**

- **Colored trail on the floor** = `_trail_overlay` / `_agent_trail`
  (`godot/scripts/overlays/trail_overlay.gd`), an existing DEV_VISION debug
  feature (yellow diamonds, alpha by recency of the last 5 tiles walked) — not a
  render conflict. Its own `_draw()` already gates on
  `_room_ref._vision_controller.dev_vision`, so it is already off by default and
  only shows when DEV VISION is toggled on, which is exactly what the Director
  asked for. No change needed.

**Resolved later the same day (2026-07-14), recorded here so this list stays
accurate:**

- **Shift+P manual screenshot not saving — FIXED.** Root cause found via live
  repro (as recommended below): `ui_peek` is bound to plain "P" and Godot's
  `is_action_pressed()` matches by default without requiring exact modifiers, so
  Shift+P fired `ui_peek` in the earlier `_input()` phase, marked the event
  handled, and `debug_screenshot` (checked later, in `_unhandled_input()`) never
  saw it. Fixed in `input_controller.gd` by passing `exact_match=true` on the
  `ui_peek` check only — movement's own shift-modifier handling (large-step) is
  independent and untouched.
- **F2 (and other debug F-keys) not working — NOT an occlusion-plan issue.**
  Confirmed the `debug_toggle_map_loader` binding itself is correct (F2,
  unique keycode, no conflict) and the underlying function works (the toolbar
  button calls it directly and succeeds) — the break is purely in key-event
  delivery, and it affects F3/F7/etc. too, not just F2. This is `INTERFACE_MASTER_PLAN`
  territory (`INPUT-01`'s input map), not this plan's — tracked there, not here.
- Ring-radius language below is superseded by O3″ (the whole circle/ring model
  is gone) — kept as history of how the investigation actually unfolded, not as
  live guidance.
- **Ghost-fade tween.** Director's call (2026-07-13): explicitly deferred, focus
  on the above first. Flagged in Decision O6 already: a true continuous fade
  needs a shader (per-fragment cost) and therefore Director sign-off against the
  mobile budget (D12) before any implementation — the current 3-ring stepped
  feather was chosen specifically to avoid that cost. Do not implement a "fake"
  multi-tick tween across the 3 discrete alternatives without discussing it
  first; it still reads as steppy and may not be worth the complexity.
- **Serrated tops/faces where opacity reveals voxel tops + adjacent wall faces
  simultaneously.** Director's call (2026-07-13): deferred to a second pass,
  depends on a map with ceiling slabs existing to properly evaluate. No action.

### Wave 3 — O6′ binary hide + wireframe silhouette (2026-07-13, Overlord direct implementation)

Triggered by the Director reviewing real Wave-2.5 screenshots: the ring gradient's
serration was worse than expected in practice, and a Phoenix Point-style reference
(wall fully hides, simple wireframe silhouette left in its place) was proposed as a
straight replacement rather than a tuning fix. See Decision O6′ for the ratified
shape of it; this section is the build log.

**What shipped:**

- `VoxelRenderer`: `GHOST_ALT_IDS`/`GHOST_ALPHAS` (3 rings) replaced by
  `HIDDEN_ALT_ID`/`HIDDEN_FILL_ALPHA` (1 alternative, flat 0.12 alpha, tunable).
  `_mint_ghost_alternatives()` and `apply_occlusion()` simplified accordingly — the
  `ring` value OcclusionSet still computes is now read into the occluded dict but
  no longer changes which alternative gets picked.
- New `godot/scripts/overlays/occlusion_wireframe_overlay.gd`
  (`OcclusionWireframeOverlay`): the actual gameplay-facing visual now. Unlike
  `OcclusionOverlay` (dev-only diamond painter, hidden by default), this one is
  visible from boot — hiding geometry with nothing marking where it was would be
  a worse experience than the ring gradient it replaces.
- `room.gd` wires it exactly like the existing debug overlay: created once in
  `_ready()`, `queue_redraw()`d from the same single `_recompute_occlusion()` path
  everything else in this plan already uses (O1's cadence discipline — agent step,
  view change, map load; never per-frame).

**The two-pass fight over the algorithm** (both real, both evidenced with a real
`INFILTRAITOR_CAPTURE_VIEWS=1` capture, not code-reading):

1. First pass outlined every occluded voxel column individually rolled up to its
   owning gameplay cell, but **included gameplay cells with zero actual geometry**
   (any cell touched by the occluded set at all, not just ones with a placed voxel)
   — drew phantom boxes over empty floor. Fixed by only registering a gameplay cell
   once a voxel column in it is confirmed to have a placed cell.
2. That alone didn't fix the visual: the outline still rendered as a dense mesh of
   small diamonds instead of one clean silhouette. Root cause was different from
   the first bug — **the top cap of every gameplay cell's box was drawn
   unconditionally**, so a contiguous wall spanning many gameplay cells, each with
   a slightly different tallest-occupied-voxel-level, produced one overlapping
   diamond per cell instead of one shared roofline. Fixed by applying the same
   boundary-suppression rule (only draw an edge where the neighbour in that
   direction is *not* occluded) to the cap edges as well as the side edges, with
   the extra condition that neighbours at a genuinely different height still count
   as a boundary (so real steps between different heights still draw). Verified:
   a uniform block now silhouettes as one clean box; a two-height corner structure
   shows exactly one real step, not a lattice.

**Known simplification, stated rather than hidden:** each gameplay cell's box
height comes from its own tallest occluded voxel column, independently. This is
correct for the common case (a wall run is usually one uniform height) and was
verified clean on the PLAYGROUND/TEXTURES test map's corner structure. A more
irregular structure (a wall with many small height variations across its
footprint) would show more steps than a hand-authored outline artist would draw.
Not attempted: merging same-height *and* height-adjacent regions into one
roofline. Revisit if a real map surfaces this as an actual problem, not before.

**Not done this session, confirmed absent rather than assumed:** roofs and
ceiling-hung props (O9) — see that decision row for what was actually checked in
the code before deferring.

### Wave 3.5 — rebuilt on Slices (2026-07-14, Overlord direct implementation)

Triggered by the Director reviewing real Wave-3 screenshots against two annotated
reference diagrams: a wall's TOP face and its two SIDE faces are visually distinct
things, and only the panel(s) actually between the agent and the camera should
vanish — not the whole gameplay cell's diamond footprint, and not a whole wide
wall. Wave 3's per-cell approach was directionally right (it killed the circle's
metal/concrete leak) but still selected and outlined at the wrong granularity. See
Decision O3″ for the ratified shape of the fix; this section is the build log.

**What shipped:**

- `OcclusionSet.compute_occluded_slices()` replaces `compute_occluded_cells()`'s
  per-gameplay-cell grouping. It now iterates `room._edge_registry.all_slices()` —
  real `Slice` objects, the same ones `VoxelRenderer.render()` just placed on
  screen (confirmed via research before writing any code: the registry is
  published by `RoomBuilder.build_from_layout()` and stays valid, not re-derived
  or reset after render). Each slice's own `Voxel.grid_pos` bounds give its real
  screen footprint — thin along one grid axis, spanning the other — instead of a
  generic gameplay-cell diamond.
- Camera-side and corridor-overlap tests carry over from O3′, now evaluated
  against the slice's own real bounds. New: **`max_depth_voxels` (48)** — the
  corridor test alone has no depth limit, and orthographic isometric projection
  never converges distant geometry toward the agent's screen column, so a
  live test surfaced a real bug: a map-boundary wall far from the agent, merely
  aligned on screen, ghosted exactly as readily as one right next to him.
- `OcclusionWireframeOverlay` rewritten from scratch: one rectangle per occluded
  slice (top edge, bottom edge, two verticals), using the slice's own two real
  corner voxels and its own real level range. The entire neighbour-lookup /
  boundary-suppression machinery from Wave 3 is gone — a slice needs no
  suppression, it already IS the non-overlapping atomic unit, so there is nothing
  to merge or clip.

**Two Director-reported problems, both fixed same session, both verified against
real four-view captures (not code-reading):**

1. First per-slice pass (corridor width unchanged at 32px, no depth cap): fixed
   the width-direction leak — metal and concrete confirmed completely unaffected
   in both N and E views, only the genuinely-in-front slice(s) ghosted. But a
   live screenshot from the Director showed the SAME wireframe pattern reaching
   down a distant corner wall far from the agent — the corridor test has no
   depth bound, so anything on the same screen column at ANY distance qualified.
2. Second live report: the corridor itself read as too narrow — only one or two
   slices directly behind the agent counted, when a believable "he's covered"
   needs a bit more lateral margin than his raw sprite width. Both fixed
   together: `max_depth_voxels = 48` added, `silhouette_half_width_px` widened
   32 → 48. Verified: occluded slice count dropped from ~124–127 per view to
   ~31–32 (the depth cap doing most of that work — it was pulling in far
   background geometry), and the remaining wireframe reads as one or two clean
   panels with no stacked seams, on both N and E.

**Known simplification, stated rather than hidden:** `max_depth_voxels` and
`silhouette_half_width_px` are both flat pixel/voxel tunables dialed against one
test map (PLAYGROUND/TEXTURES). Neither scales with room size or wall thickness —
a much larger room may need different values. Expose and re-tune if a real
gameplay map surfaces this, not before.

### Wave 1 post-mortem (2026-07-12) — read this before scoping Wave 2

Wave 1 landed, but **not the way it was supposed to.** Three completion reports in
a row marked visual criteria PASS without looking at the pixels, and an unrequested
`[CLEANUP]` commit deleted a cross-file-written variable, which aborted the build
path and stopped **every wall in the game from rendering**. Everything downstream
then "passed" against a world with no geometry.

Four defects in Part 1 were invisible to code-reading and were found the instant a
real four-view capture existed (`OCC-FIX-02`):

- the set was **never computed at map load** (empty until the first step);
- the debug overlay sat at `z_index = 5`, **underneath** the voxel layers (10–33) it
  was painting — it could never be seen;
- the overlay **hand-rolled the isometric projection** and was handed the *floor*
  layer for *voxel* cells — a two-plane violation that put the region on the wrong
  cube;
- the set formula anchored the agent on his cell's **corner**, and its "isometric
  squash" halved a *grid* axis, producing an ellipse rotated 45° instead of a circle
  on screen.

**The tool that found all four now exists and is the standing way to verify anything
view-dependent:** `INFILTRAITOR_CAPTURE_VIEWS=1` boots, drives `_set_perspective()`
for N/E/S/W, forces the occlusion overlay on, and writes one PNG per view. It exists
because rotating the view is **mouse-only** — the perspective pad has no key binding —
so an unattended run could not rotate the map at all. **Any prompt with a four-view
claim must route through this harness; without it the criterion is not merely unmet,
it is unmeetable.**

Known limitation, stated rather than hidden: the overlay draws each occluded column
at **level 0**, so on tall geometry the marks appear at the base of the wall rather
than on its face. The set is over columns; ground level is the honest position for a
column. Part 2 paints the actual voxels and does not inherit this.

**Screenshot session: ON for the whole plan.** Every part of this is visual;
every completion report must point at a real capture in `Screenshots/history/`.

---

## 7. Open questions

1. ~~**Does the ghost alternative compose with per-cell transform flags?**~~
   **ANSWERED 2026-07-12 by the code pass: it cannot bite in v1, because nothing
   uses a non-zero alternative today.** `BakedTileLookup.Result.alternative_id` is
   declared *"For future use (always 0 for now)"* and every `set_cell()` in
   `VoxelRenderer` passes either that value or a literal `0` — the H-flip that
   junction columns once used was removed (the "no-flip hypothesis" comments in
   `_render_junction_column`). The ghost alternative therefore has the whole
   alternative axis to itself. **It becomes a live question again the moment
   anything reintroduces a flipped or transposed cell** — at that point the ghost
   alternative and the transform flag compete for the same integer, and the
   occlusion system must be re-checked.
2. **The circle's radius and ring widths** are tuning, not architecture. Expose them
   as debug-adjustable and let the Director dial them against a real screenshot.
   **2026-07-13 data point:** on the PLAYGROUND/TEXTURES test map, `20.0` voxels
   left one of the four views with almost nothing occluded (4 cells, vs. 55–66 for
   the other three) purely because the nearest occluding geometry from that camera
   angle sits farther away than from the others — `32.0` brought it to 120 cells
   with visible ghosting. Not yet applied for real; see Wave 2.5 above. Do the real
   tuning pass with Shift+P working again, live, not blind.

---

## 8. Future ideas (parking lot)

Not scheduled, not blocking anything — logged here so a good idea raised in
passing doesn't get lost or re-litigated from scratch later. Promote an entry to
a real Part/Wave when it's actually next, don't build ahead of need.

1. **Destruction-aware wireframe contour.** The wireframe (O12, §6 Wave 3.9)
   traces the outline of the whole occluded object as if it were intact. The
   Director's real ideal: once `DESTRUCTION_MASTER_PLAN`'s `Slab`/voxel
   -destruction exists, the contour should trace around actual holes in the
   shape — the remaining shell's true silhouette, craters and all — not a
   clean box. Explicitly deferred by the Director 2026-07-14: "isso é luxo,
   numa situação de processamento sobrando" (a luxury for when there's
   processing budget to spare), and it depends on destroyed-voxel geometry
   that doesn't exist yet. Revisit once both `Slab` and a real destruction pass
   are in — O12's own hull-walk is already proven on intact geometry.
