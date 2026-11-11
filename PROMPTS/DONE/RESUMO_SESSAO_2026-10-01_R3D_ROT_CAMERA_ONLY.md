# Session 2026-09-30/10-01 — R3D-ROT: the world turns by the camera alone

Commits `d4e39fa9..15fcd7d7` (`git log 9d9c9af5..HEAD`). Previous session: `RESUMO_SESSAO_2026-09-30_R3D_PROPS_MODELS_PLANS_DOCS.md`. R3D-PROPS was paused by the Director to take R3D-ROT first.

## Ask and the reversal
"Pause PROPS, implement R3D-ROT, free the rotation." The Director first chose a HYBRID (world in base coordinates, actors/overlays kept 2D behind a conversion) and then REVERSED it: everything that is not interface or flat decoration must be 3D-native and turn together. The hybrid's Room-side bridge (`_set_view_camera_only`, `INFILTRAITOR_CAMERA_ROT`, `GroundGrid` view state) was built, captured, and removed the same day (`c2bd45ed`, `c148503c`). The ratified order ACTORS -> WORLD -> ROT stands; ROT was taken first for the board only.

## Built
- **`Board3DLive.set_view(dir)`**: camera yaw (`VIEW_YAW_DEG`), a 5-face mesher (`Dir` TOP/SE/SW/NW/NE) that meshes the 3 faces the view sees (`VIEW_DIRS`) in the existing background re-mesh task (the view is snapshotted per task), shader face slots (`face_x_slot`/`face_z_slot`, `VIEW_FACE_SLOTS`) so tone and soot digit are the SCREEN side's, glass tones and sheen axes per view, quads for -x/-z wound reversed (glass is `cull_back`).
- **`Room._set_perspective()`** is now only the view change: `set_view`, shake stop, in-flight VFX cleared, agent/props recompose, `_recompute_occlusion()`. 0.6 ms main thread; no store rebuild, no replay. `Room._active_perspective` (layout orientation) stays "N"; `_view_direction` / `view_direction()` / `view_yaw_deg()` is the camera.
- **Camera pan under yaw**: `Board3DLive.lattice_delta()`.
- **Cutaway**: `OcclusionSet` stays keyed in base; `view`, `base_voxel_size`, `base_gu_size`; the trigger geometry, agent, roof stripes and the wireframe near side read turned coordinates (`PerspectiveMapper.turn_from_base`, sentinel-free). Gate `occlusion_view_selftest`: view X over the world == view N over the turned world (E/S/W); red-before-green proved (view ignored -> 5 FAIL).
- **D25 REVISED**: `carved_side_for()` = the PHYSICAL horizontal face toward the epicentre (`CarvedSide.FACE_NW` -x, `FACE_NE` -y added; tie -> x), stored once, never re-derived; the mesher dents/decals all four lateral faces; `_impact_anchor_3d` knows them. `blast_calculator_selftest` expectations updated and explained.
- **Baked sprites** read `view_direction()` and turn their light direction by `view_yaw_deg()` (agent_sprite, grenade_prop, floating_collectible, agent_probe_prop).
- **Found on the way**: `scenario_save_restore` did not claim glass openings before the replay; fixed, and `glass_crack_selftest` now checks that path's order.

## Evidence
`verify.py smoke` PASSED after every code commit (last: lint, invariants, codemap, selftests, PLAYGROUND+GLASS boot). Captures (scratchpad, not kept): GLASS and OCCLUSION_NEST in N/E/S/W, PLAYGROUND blast in N then E/S/W (one crater, one place). `verify.py full` was NOT run (no baseline taken).

## Decided
Physical carved faces (D25 revised); the 2D lattice is the N lattice for every view (billboards, lifted ground overlays, VFX anchors rotate with the world through the unchanged affine; ground overlay widths are ground-fixed, so no gap); no hybrid.

## Not done / open
- **Dead-code pass** (blocked, recorded in the plan's R3D-ROT correction): the `_base_*` records are CHECKPOINT persistence (SaveState), not rotation-only; ~77 `_active_perspective` conversions are inert; `layout_with_perspective` is still the fixture of 5 selftests. Needs a scripted pass, a Godot warnings check (the lint tool lists none) and the fixtures rewritten.
- **Moto**: the cost of a rotation and of the background re-mesh was never measured (no adb in the session); touch picking from other views untested.
- **ACTORS and WORLD proper** (live meshes, world-space overlays and VFX) are still to do; the `S` overlays (aim bubble, throw arc, tracer, cursor) are still 2D.
- Roof reveal under yaw and the `GroundCanvas3D` `S`-class overlays were only seen in captures, not gated.

## Traps
- `pgrep -f Godot` matches the shell that launched it: wait on a done-file, not on the process.
- macOS has no `timeout`; run a capture in the background and read its log.
- A symmetric map (OCCLUSION_HALL) cannot tell four views apart: pick one with an off-centre agent.
