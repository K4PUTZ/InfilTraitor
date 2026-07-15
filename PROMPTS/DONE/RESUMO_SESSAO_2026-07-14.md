# RESUMO_SESSAO — 2026-07-14

**Active master plan:** `PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md` — IN PROGRESS.
**VERSION at session end:** 0.9.15 (Waves 2.5–3.14 completed and pushed — 14 wave
iterations total, 8 commits today alone).
**Mode:** Overlord direct implementation, live in session against real
`INFILTRAITOR_CAPTURE_VIEWS=1` four-view captures and the Director's own
annotated screenshots. No Operator prompts issued this session.
**Test fixture used throughout:** PLAYGROUND/TEXTURES map, the four-material
corner junction (concrete/metal/stone/wood) at the room's centre.

---

## Wave table (this session)

| Wave | What | Status |
|---|---|---|
| 2.5 | Live bugfix pass: noisy console errors (dead existence-probe), unbounded `TileSetAtlasSource` leak on rebuild, `circle_radius_voxels` 20→32 | ✅ Closed, pushed |
| 3 | O6′: ring gradient → binary flat-fill ghost + first `OcclusionWireframeOverlay` (Phoenix Point reference, Director decision) | ✅ Closed, pushed |
| 3.5 | O3″: per-gameplay-cell corridor decision replaces the circle; wireframe redrawn as one box per Slice | ✅ Closed, pushed |
| 3.6 | O3‴/O6″/O6‴: per-EDGE decision (not per-Slice), edge-graph BFS instead of distance, ring gradient returns (edge-hop keyed), wireframe rebuilt on per-level z_index-correct panels, "rung" artifact closed | ✅ Closed, pushed |
| 3.7 | Direction/junction propagation stop (kills corner wrap-around leak); ring alphas retuned 3%/6%/10%; vertical reveal cutoff (O3⁗) — a tower's lower levels stay visible once far enough below the agent's own screen-ground position; **real bug found and fixed same pass**: the cutoff only worked in the wireframe, not the ghost fill, until `min_level` was threaded into the per-cell dict | ✅ Closed, pushed 01:29 |
| 3.8 | O10/O11: always-visible base band (2 levels, full opacity, no agent math) replaces O3⁗'s pixel-threshold cutoff; junction columns occlude (only when both joined edges are occluded); ring alphas retuned 4%/8%/16%. **First attempt inverted the model** (ghosted the base, hid the rest) — caught live via real capture, corrected same session. | ✅ Closed, pushed 18:30 |
| 3.9 | O12: wireframe rebuilt as true hull outline, merging contiguous runs into one segment via vertex-adjacency walk. Root-caused and **fixed diagonal-seam artifact**: per-edge independently-scanned corners could disagree at a real shared vertex when two different faces met; now uses one true shared grid vertex (`_edge_vertices`), identical both sides by construction. | ✅ Closed, pushed 18:41 |
| 3.10 | O13: Director's diagram **walked back the merge** — wireframe is now one independent unit per edge (base + box), drawn separately, not merged. V-junction overlap explicitly expected, not a defect. Junction columns get degenerate `corner_a == corner_b` "lightsaber" line (collapses `OcclusionSlicePanel` to one vertical), no new drawing code. O12's vertex fix carries forward. | ✅ Closed, pushed 20:52 |
| 3.11 | O14: wireframe units are real **3D boxes** (width + depth), not flat planes. Director: edge panels "parecem folhas de papel," lightsaber "apenas uma linha." Each edge now `{near_a, near_b, far_a, far_b}` using the real 1-voxel gap between Slices A/B; junction column becomes genuine 1×1-voxel box. `OcclusionSlicePanel` redrawn for 8 corners (4 verticals, full-rectangle caps). | ✅ Closed, pushed 21:47 |
| 3.12 | O15: **depth corrected to 2 voxels** from O14's 1. Director caught live: box undershot the base band underneath by exactly one voxel. Root cause: center-to-center vs. outer-edge-to-outer-edge span. `depth_offset` doubled. Lightsaber already correct, untouched. | ✅ Closed, pushed 22:03 |
| 3.13 | O16: **lightsaber wireframe OFF**, A/B tested live. Director: edge units' own verticals already meet cleanly at shared vertex (O12 fix), so the extra line added little. Kept off; junction fill unchanged (still ghosts per O10/O11), only wireframe segment commented out (one-line revert available). | ✅ Closed, pushed 22:18 |
| 3.14 | O17→O18/O19: wireframe style finalized. O17 (`draw_dashed_line`, fixed pixel length) superseded same session — visually incoherent, sparse on tall axis, dense on short. **O18: dots at real voxel boundaries** (`width_voxels`/`depth_voxels` from segment's fine-voxel corners, not pixel-spaced). **O19: dots 90% alpha + 20% underline + gray-cyan glass fill** on front/top faces at `VoxelRenderer.GHOST_ALPHAS[ring]` — same alpha the ghosted material uses, not a competing value. `ring` now travels on wireframe segment. | ✅ Closed, pushed 22:39 |

Every wave above has real `Screenshots/history/auto_2026-07-14_*.png` evidence from
the matching commits (7 captures today: 18:30, 18:41, 20:52, 21:47, 22:03, 22:18,
22:40), not just code-reading claims.

## Decision register deltas

- **O3 → O3′ → O3″ → O3‴ → O3⁗ → O10** (evolution chain, all intermediate states
  superseded): circle by voxel distance → corridor by gameplay cell →
  corridor+depth-cap by Slice → real 2D screen-AABB overlap by EDGE with
  graph-walk rings → vertical reveal cutoff (pixel-threshold, agent-relative) →
  **always-visible base band** (fixed 2 levels, no agent math). **O10 is current.**
- **O6 → O6′ → O6″ → O6‴ → O19**: voxel-distance 3-ring gradient → flat single
  alpha → edge-hop 3-ring gradient returns → wireframe rebuilt z_index-correct →
  wireframe style finalized (dots + glass fill). **O6″/O19 current**; alphas now
  4%/8%/16% (tuned across three waves).
- **O12 → O13**: merged hull outline → independent per-unit wireframe. Director
  walked back the merge; **O13 current** (per-edge units, overlap at V-junctions
  expected). O12's **vertex fix carries forward** (diagonal-seam artifact closed).
- **O13 → O14 → O15**: flat planes → 3D boxes (1-voxel depth) → depth corrected
  to 2 voxels. **O15 current.**
- **O16**: lightsaber wireframe OFF (A/B test, edge verticals already meet cleanly).
- **O17 → O18 → O19**: pixel-spaced dashes → voxel-boundary dots → dots + underline
  + glass fill. **O18/O19 current.**
- **O7 revised** (unchanged from earlier waves): silhouette stroke dropped
  (full-hide already leaves agent fully visible when occluded) — parked as future
  possibility, not scheduled. OCC-04 (the stroke prompt) marked superseded.
- **O9 confirmed, not assumed** (unchanged): neither a roof-rendering system nor a
  real ceiling-prop system exists anywhere in the codebase today — checked
  directly before deferring.

## Bugs found via real evidence this session (not code-reading)

**Waves 2.5–3.7 (early session):**
1. Console spam (`TileSetAtlasSource has no alternative...`) — dead
   existence-probe, always false, Godot logs an ERROR on any miss regardless.
2. `TileSetAtlasSource` leak — `source_count` grew unbounded across view
   rotations (16→52 observed) because `clear()` never pruned baked pages.
3. Corridor bleeding into unrelated neighbouring structures (metal/concrete
   ghosting alongside a wood wall the agent stood against) — root-caused to the
   circle/corridor model, not fixable by tuning; required the edge-graph
   rewrite.
4. Distant map-boundary wall ghosting despite being nowhere near the agent —
   same root cause, same fix.
5. Wireframe showing straight through nearer, unoccluded geometry that should
   have covered it — root-caused to a flat elevated `z_index` on a single
   `Node2D`; confirmed via direct query that `y_sort_enabled` defaults `false`
   project-wide (not assumed) before concluding z_index was the only lever.
6. "Venetian blind" rung artifact from the z_index fix's own side effect
   (per-level panels each drawing a redundant internal cap edge).
7. Ring propagation wrapping around a box's own corner onto its perpendicular
   side wall — caught from an annotated Director screenshot, fixed with a
   same-direction + no-junction rule on the graph walk.
8. Vertical reveal cutoff computed correctly but only wired into the wireframe
   — the ghost fill kept covering a tower's whole column because
   `OcclusionSet`'s per-cell dict carried no level information, so
   `VoxelRenderer.apply_occlusion()` had no way to know which levels the cutoff
   was supposed to exclude. Caught by checking real numbers (a diagnostic
   dump), not by trusting the visual alone — the low new alpha (3%) made the
   bug nearly invisible on screen.

**Waves 3.8–3.14 (later session, same day):**
9. **Base-band logic inverted** (Wave 3.8, O10 first attempt) — implementation
   ghosted the BASE and fully hid everything ABOVE it, opposite of the stated
   design. Caught via real four-view capture before any commit, corrected to
   leave base at full opacity and ghost the tower above. The hidden-alternative
   mechanism was verified working via temporary opaque-red diagnostic override,
   then removed entirely once the correct model was implemented.
10. **Diagonal-seam artifact** (Wave 3.9, O12) — adjacent edges' independently-
   scanned corners disagreed at a real shared vertex when two different faces met
   (their local scan axes differ). Fixed by always using one true shared grid
   vertex (`_edge_vertices`), identical both sides by construction.
11. **Flat 2D wireframe panels** (Wave 3.10→3.11, O13→O14) — Director caught live
   after O13 shipped: edge units "parecem folhas de papel," junction lightsaber
   "apenas uma linha" (both had zero thickness). Fixed by adding real depth
   (near+far corners) using the 1-voxel gap between Slices A/B.
12. **Wireframe depth undershot base by 1 voxel** (Wave 3.12, O15) — O14's
   `depth_offset` used center-to-center gap between slices (1 unit), but the real
   physical footprint is outer-edge to outer-edge (2 units, since each slice's
   column is itself a full unit wide). Caught by Director comparing box vs. base
   band in live capture. `depth_offset` doubled.
13. **Fixed-pixel dash visually incoherent** (Wave 3.14, O17) — screen-px-per-voxel
   already differs by axis under isometric projection, so constant PIXEL length
   looked sparse on tall axis, dense on short. Superseded same session by O18
   (dots at voxel boundaries, count-driven not pixel-driven).

Also fixed, outside the occlusion algorithm itself:

- **Shift+P silently doing nothing** — `ui_peek` (bound to plain "P") was
  matching Shift+P before `debug_screenshot` ever saw the event, because
  Godot's `is_action_pressed()` doesn't require exact modifiers by default.
  Fixed with `exact_match=true` on `ui_peek` only.

## Open items for next session

- **O3⁗'s `vertical_reveal_px` constant is now dead code** — superseded by O10's
  fixed base band (Wave 3.8), not deleted yet. Safe to remove in next cleanup pass.
- **F2 and other debug F-keys (F3/F7/etc.) don't work** — confirmed NOT an
  occlusion-plan issue: the `debug_toggle_map_loader` binding itself is
  correct and the underlying function works when called directly (the toolbar
  button proves it). The break is in key-event delivery, affects multiple
  F-keys at once, and is `INTERFACE_MASTER_PLAN` (`INPUT-01`) territory — not
  investigated further this session, deliberately out of scope.
- **`INTERFACE_MASTER_PLAN` Wave 3 (`PAUSE-MENU-01`) not started.** Director
  flagged wanting to close this soon (a note was added to
  `REFERENCES/Backlog.txt` mid-session: a simple ESC-triggered menu with
  NEW GAME / LOAD / OPTIONS placeholders, wiring only, no real functionality
  yet). Explicitly deferred this session in favour of finishing the occlusion
  pass — Director's call, confirmed via AskUserQuestion.
- **`godot/scripts/tools/occlusion_set_test.gd` is stale**, written against
  OCC-01's original circle-based `compute_occluded_cells()` signature, several
  rewrites behind current. Not gating lint or CI (a standalone headless
  script, not auto-invoked). Not touched this session — real cleanup, not
  urgent, flag before anyone tries to run it expecting it to reflect current
  behaviour.
- **Serrated tops/faces where opacity reveals voxel tops + adjacent wall faces
  simultaneously** — Director's call from earlier in the plan: deferred to a
  second pass, depends on a map with ceiling slabs (`DESTRUCTION_MASTER_PLAN`)
  existing to properly evaluate.
- **Ghost-fade tween** — explicitly deferred by the Director; a true continuous
  fade needs a shader (per-fragment cost, D12 sign-off) the current
  alternative-tile mechanism was specifically chosen to avoid. Do not
  implement a "fake" multi-tick tween without discussing it first.
- **Junction-column lightsaber wireframe** is commented out (O16, Wave 3.13), not
  deleted — one-line revert available if a future map's geometry makes the gap
  visible again (e.g. real X-junction).
- **Part 1+2 (occluded-set + visual) CLOSED at Wave 3.14** — mechanism is now:
  per-EDGE decision, 2D screen-overlap trigger, edge-graph BFS rings, always-
  visible base band (2 levels), modular per-unit 3D-box wireframe with
  voxel-boundary dots + glass fill. Verified against real four-view captures.
  **Part 3 (agent-on-top) already closed** (OCC-03); silhouette-stroke half
  superseded (O7). **Part 4 (interior cutaway) still blocked on
  `DESTRUCTION_MASTER_PLAN`'s `Slab`** — no map has a ceiling today.
- **No `verified/` tag cut yet** for any of this session's work (v0.9.1–0.9.15) —
  Director's call on when.

## Commits this session (all Overlord direct implementation)

**Early waves (2026-07-13 night → 2026-07-14 early morning):**
- `958c9d3` — `[OCC-05..07]` Occlusion rebuilt: flat hide, real wireframe, per-slice corridor (2026-07-13 22:22)
- `31b612d` — `[OCC-08]` Occlusion rebuilt on edges: real 2D overlap, graph-walk rings, clean wireframe (2026-07-14 00:19)
- `88d238f` — `[OCC-09]` Direction/junction ring stop, vertical reveal cutoff, session close (2026-07-14 01:29)

**Later waves (2026-07-14, afternoon/evening):**
- `d738344` — `[OCC-10]` Always-visible base band replaces the vertical reveal cutoff; junction columns occlude (18:30)
- `b3b16b6` — `[OCC-12]` Wireframe rebuilt as a true hull outline, not per-Slice/Edge panels (18:41)
- `d007eee` — `[OCC-13]` Wireframe formalized as independent per-unit design, not a merged hull (20:52)
- `fd0a833` — `[OCC-14]` Wireframe units are real 3D boxes now, not flat planes (21:47)
- `86a0416` — `[OCC-15]` Wireframe depth corrected to two voxels, matching the real base footprint (22:03)
- `e00b1a8` — `[OCC-16]` Junction-column lightsaber wireframe off, A/B tested live (22:18)
- `84243dc` — `[OCC-18/19]` Wireframe style: dots at real voxel boundaries, plus glass fill (22:39)

**Total: 10 commits spanning 24+ hours of active session time**, 14 wave iterations
(2.5, 3, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14). Every wave has real
screenshot evidence (`Screenshots/history/auto_2026-07-14_*.png` or the earlier
four-view `occ_view_{N,E,S,W}.png` set). Version progression: 0.9.1 → 0.9.15.
