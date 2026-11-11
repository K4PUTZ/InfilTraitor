# Session summary — 2026-10-15: the bending engine (study + first engine slice)

Resume point for the next session. Plan: `PROMPTS/PLANNING/ROOF_MASTER_PLAN.md` v0.28 (the study) and v0.29 (the slice, the Moto table). Lab: `tools/research/cloth_lab/`.

## What is true now
- Study: Projective Dynamics beats XPBD for bending (validated against the exact beam and the catenary); a material is one length `lb`; behaviour follows span / lb.
- Engine: `SoftSheetSim` (pure, thread-safe) + `SoftSheet3D` (one draw call) + `RoofSheetRelease` + `Room.release_roof_sheet` / scenario step `roof_gravity`; ROOF_LAB room C (fabric awning, board widened to 32), take `roof_gravity`.
- Moto g04s: step 24 ms (4 iterations); main thread = 19 ms/frame (fps 61 -> 37); one worker task = 0.5 ms/frame, real time. `SOFT_SHEET_THREAD` default on.
- Verified: `verify.py` smoke PASSED (80 selftests, incl. `soft_sheet_sim_selftest` and the real-map `roof_sheet_release_selftest`), desktop captures, E-view rotation, Moto APK. Commits d2decb4f, 776087fc on main.

## NEXT (Director to choose; recommended order)
1. The release frame: light repaint 630 ms + dirty pass 75 ms on the Moto (slice it like the blast plan, or skip it when no lamp stands above the roof). Re-measure with `python3 tools/persistent/soft_sheet_scenario.py --device ZF524T5TG5`.
2. Cardboard: plasticity (the crease, signed along the sheet normal) in `SoftSheetSim`, a cardboard row in `SoftSheetPresets`, a cardboard awning in the bench.
3. A blast's hole in a sheet (mask on the skin, nodes under the hole freed), then fire / soot on the cloth.
4. Persistence across a checkpoint; prop / edge-wall colliders; shadow; Galaxy and PSS measurements.

## Traps
New class_name needs `godot --headless --path . --import` before a headless run; pace a worker by the sum of deltas, not the wall clock; a roof at the board's border is held by the exterior wall; zsh errors on an unmatched glob.
