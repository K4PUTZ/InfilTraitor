# RESUMO_SESSAO — 2026-07-14

**Active master plan:** `PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md` — IN PROGRESS.
**VERSION at session end:** 0.9.7 (Waves 2.5–3.6 pushed; Wave 3.7 pushed this
session's close — see commit list below).
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
| 3.7 | Direction/junction propagation stop (kills corner wrap-around leak); ring alphas retuned 3%/6%/10%; vertical reveal cutoff (O3⁗) — a tower's lower levels stay visible once far enough below the agent's own screen-ground position; **real bug found and fixed same pass**: the cutoff only worked in the wireframe, not the ghost fill, until `min_level` was threaded into the per-cell dict | ✅ Closed, pushed at session end |

Every wave above has real `Screenshots/history/occ_view_{N,E,S,W}.png` evidence
from the matching commit, not just code-reading claims.

## Decision register deltas

- **O3 → O3′ → O3″ → O3‴ → O3⁗** (all superseded-in-place, not deleted — see the
  Decision Register in the master plan for the full reasoning chain): circle by
  voxel distance → corridor by gameplay cell → corridor+depth-cap by Slice →
  real 2D screen-AABB overlap by EDGE with graph-walk rings → vertical reveal
  cutoff on top of that. **O3⁗ is current.**
- **O6 → O6′ → O6″ → O6‴**: voxel-distance 3-ring gradient → flat single alpha
  (Phoenix Point wireframe pivot) → 3-ring gradient returns, keyed by edge-hop
  distance → wireframe rebuilt for z_index correctness + rung fix. **O6″/O6‴
  current**, alphas now 3%/6%/10%.
- **O7 revised**: silhouette stroke dropped (full-hide already leaves the agent
  fully visible when occluded) — parked as a future possibility, not scheduled.
  OCC-04 (the stroke prompt) marked superseded in its own file.
- **O9 confirmed, not assumed**: neither a roof-rendering system nor a real
  ceiling-prop system exists anywhere in the codebase today — checked directly
  before deferring, not guessed.

## Bugs found via real evidence this session (not code-reading)

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

Also fixed, outside the occlusion algorithm itself:

- **Shift+P silently doing nothing** — `ui_peek` (bound to plain "P") was
  matching Shift+P before `debug_screenshot` ever saw the event, because
  Godot's `is_action_pressed()` doesn't require exact modifiers by default.
  Fixed with `exact_match=true` on `ui_peek` only.

## Open items for next session

- **`vertical_reveal_px` (320px) is a live-tunable estimate, not derived** —
  the Director offered two equivalent framings ("2 more GU diagonally" / "2
  more storeys") that don't reduce to the same exact pixel value on paper.
  Needs a real live-play tuning pass against a screenshot, not another guess.
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
- **No `verified/` tag cut yet** for any of this session's work — Director's
  call on when.

## Commits this session

- `958c9d3` — `[OCC-05..07] Occlusion rebuilt: flat hide, real wireframe, per-slice corridor`
- `31b612d` — `[OCC-08] Occlusion rebuilt on edges: real 2D overlap, graph-walk rings, clean wireframe`
- *(Wave 3.7 — direction/junction stop, vertical reveal cutoff, alpha retune — committed and pushed at session close, see git log for the hash)*
