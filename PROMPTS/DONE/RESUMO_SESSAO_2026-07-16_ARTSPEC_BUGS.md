# RESUMO_SESSAO — 2026-07-16 (ART SPEC + VISUAL BUGS)

**Active master plan:** `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` —
still **PAUSED at Alpha Horizontal Bake Foundation** (unchanged; this
session was documentation + a Director-reported visual bug wave, not plan
work).
**VERSION at session start:** 0.9.48
**VERSION at session end:** 0.9.52
**Mode:** Overlord direct implementation. Third session of 2026-07-16.
**Screenshot session:** turned ON for the bug wave, OFF at close.

---

## Executive Summary

Two distinct blocks. First, the **ART-01 planning block**: the Director
ratified dedicated roof/slab art, stepped-roof "telha" profiles, a
materials dictionary, a per-voxel objects dictionary and a `.vox` import
pipeline as a future milestone (Alpha → Beta window, NOT to be built now);
the authoritative art production manual was written and versioned. Second,
a **seven-fix visual bug wave**, all Director-reported from live play, all
fixed same-session with real-capture evidence.

The load-bearing discovery of the session: the voxel earth floor
(storey −1) had been rendering at z=2..9 — ON TOP of the entire
floor-painted overlay ecosystem designed for the legacy z=0 floor plane
(shadows z=1, FOW z=2, game tiles z=3, boundary z=4, AP perimeter z=5,
path z=6, selection z=7) and on top of the occlusion wireframe's lower
panels. One z-slot change fixed two reported bugs at the root and
un-buried five other systems nobody had flagged yet.

---

## Wave table

| ID | What | Status |
|---|---|---|
| ART-SPEC-01 | `ASSETS/ART_SPECIFICATIONS.md` (authoritative art manual: canonical metrics, wall facade spec, planned roof/slab spec, stepped-roof feasibility, PropDef/objects schema, `.vox` constraints, MaterialDef shape, B2/B3/B6/D12 bindings); milestone **ART-01 — Materials & Objects Pipeline** added to `milestones.md`, gated to the Alpha→Beta window; `.gitignore` `ASSETS/` → `ASSETS/*` + negation so only the manual versions | ✅ `0b5b31b` |
| Z-SLOT-01 | Negative (floor) voxel levels render in the legacy floor slot (z = level + 1, top at 0; legacy `floor_layer` at −9) — fixes invisible AP perimeter AND the wireframe "hole at the base"; un-buries shadows/FOW/game tiles | ✅ `8939340` |
| OCC-22 | Wireframe dots as shared pre-blurred gaussian sprite (no per-frame blur, D12) | ✅ `8939340` |
| OCC-22b | Dots thinned to underline thickness (core 0.75, sigma 1.0) | ✅ `0fe9914` |
| ROOF-SIDE-01 | Roof atom right half-face mirrored from the correct left half (kills the "lid"); `BAKE_CODE_VERSION` 3→4 | ✅ `0fe9914` |
| JUNCTION-MIRROR-01 | Lateral V-junction columns: baked neighbor atoms get `TRANSFORM_FLIP_H` again (D-BAKE-2); a leftover "no-flip TEST" had them repeating the neighbor column verbatim. No-flip stays only for generic tiles | ✅ `0fe9914` |
| INPUT-SPLIT-01 | Desktop: right-click moves directly to clicked GU (`handle_move_click`), left-click selects only. Touch: tap routes to `handle_tile_click` (tap-select / tap-again-walk) — existed but was never wired | ✅ `0fe9914` |
| — | Session close: this summary, screenshot OFF | ✅ session close |

## Decisions (Director-ratified)

1. **ART-01 window**: materials/objects/art pipeline is built between
   Alpha and Beta, after scenario + gameplay — specs pre-written, zero
   implementation now. Canonical spec doc: `ASSETS/ART_SPECIFICATIONS.md`
   (dimensions inside marked "recommended" still need D-numbers at
   kickoff — 512×512 roof texture is the Overlord recommendation).
2. **Roof side faces**: mirror the correct (SW) half onto the SE half —
   Director's own prescription, confirmed geometrically (opposite shear).
3. **Desktop/mobile control split**: right-click-to-move / left-select on
   desktop; tap-tap flow on touch.

## New tooling

- `INFILTRAITOR_CAPTURE_AGENT_CELL="x,y"` capture action (room.gd):
  teleports the agent through the real cell setter + FOW reveal +
  occlusion recompute before the auto-capture — unattended reproduction
  of position-dependent visual bugs. Composes with existing actions.

## Testing evidence

| Check | Result |
|---|---|
| `negative_storey_selftest` (z expectation re-derived for Z-SLOT-01) | 12/12 |
| `fixed_floor_selftest` | 5/5 |
| `slab_render_selftest` | 8/8 |
| `floor_integration_selftest` | 9/9 |
| `roof_bake_selftest` | 8/8 |
| `bake_selftest` | 19/19 |
| `project_lint.py` | 0 real compile errors, every commit |

Visual: `auto_2026-07-16_22-00-53.png` (wireframe base reaches ground, AP
perimeter visible and depth-correct), `auto_2026-07-16_22-06-13.png`
(gaussian dots), `auto_2026-07-16_22-28-58.png` (thin dots, v4-cache
re-baked roof band + corner columns). All reproduced at the Director's
own bug position via the new capture action.

---

## Open items (next session)

1. **Director in-game visual pass, all 4 views**, on: ROOF-SIDE-01 (roof
   band sides — a tone step along the fold row may remain even with the
   correct mirror; refine the crop if he flags it), JUNCTION-MIRROR-01
   (stone shows it best), Z-SLOT-01 side effects (shadows/FOW/game tiles
   un-buried — anything that "reappeared" oddly belongs to this family).
2. Prior ROOF-BAKE items unchanged: roof occlusion participation,
   per-material roof facades (now = ART-01 deliverable 2), slab-vs-block
   overlap at storey steps (Part 3), Part 3 trigger, `usage_cells` (D3),
   depth shading (D7), D14 composite, crates get no roofs,
   `prop_01_tests.gd` criteria 4/6.
3. ART-01 kickoff (only when the window opens): ratify roof texture
   dimensions + `layers` ordering with D-numbers.

---

## Session statistics

- **Commits:** 4 (`0b5b31b`, `8939340`, `0fe9914`, + session close) — all pushed.
- **VERSION:** 0.9.48 → 0.9.52.
- **New docs:** `ASSETS/ART_SPECIFICATIONS.md`; ART-01 milestone entry.
- **New production surface:** floor z-slot branch in
  `_build_voxel_layer_node`; `SelectionController.handle_move_click`;
  touch/desktop input split; gaussian dot sprite; roof side mirror;
  junction baked-atom flip; capture agent-cell action.

## Conclusion

Documentation debt for the materials/objects future is paid before the
work exists (the ART-01 spec is written while the systems it governs are
still months out), and the visual layer is coherent again: everything
painted on the floor draws above the floor, everything occluded mirrors
and reaches the ground, and each platform gets the input scheme it
deserves. `DESTRUCTION_MASTER_PLAN` remains paused exactly where the
previous session left it — nothing in this session moved or contradicted
plan state.
