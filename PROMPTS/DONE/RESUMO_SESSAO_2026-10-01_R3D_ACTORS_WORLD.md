# Session 2026-10-01 — R3D-ACTORS steps 1-5 and R3D-WORLD

Branch `claude/r3d-actors-y5r8hs` (local, not pushed): `9b801b0c` (step 1), `d0d1fba4` (demo facing), `64ca9708` (steps 2-3),
`d8177c58` (step 4), `c3216776` (R3D-WORLD), `27a7ed50` (step 5), plus this record. Previous session:
`RESUMO_SESSAO_2026-10-01_R3D_ROT_CAMERA_ONLY.md`.

## Ask
Director: "Segue os passos conforme planejado, tomando as decisões recomendadas, se não tiver nenhum problema crítico. Queremos
R3D-ACTORS e R3D-WORLD preparados para o objetivo de finalizar o R3D-ROT."

## Decided (recommended readings, recorded in the plans)
- D44: gameplay keeps four facings and D47's snap; the mesh renders any yaw, so keeping four changes nothing.
- The production rig is the NORMAL model (`P3_DEV_ONLY=0`); the guard wears `agent_base_enemy_white`.
- The mesh is driven by `AgentSprite`'s decisions (`mesh_state()`), the billboard's contract; `AgentSprite` became decision-only.

## Built
See `RENDER3D_MASTER_PLAN` R3D-ACTORS ("STEPS 2-5 BUILT") and R3D-WORLD ("BUILT 2026-10-01"). In one line each:
- Rig: 18 keyed actions per model, weapons / grenade on the hand bones, the wrist levelled so the weapon never rolls (measured
  up to 146 deg before).
- `ActorMesh3D` + `ActorHeadTurn3D`; soot; GUARD_REVEAL silhouette on the mesh; contact shadow on the mesh.
- `ActorBillboard3D` and the gameplay frame bake retired; `head_offset_px()` from the rig's head bone.
- VFX positions through `Board3DLive.lattice_basis()`, no clearing on rotation; `WorldCanvas3D` (tracer, arc, lamps, dome, star);
  menus and the virtual grenade project through the 3D camera.

## Evidence
- `verify.py smoke` PASSED after every code commit.
- Captures (scratchpad, not kept; shown to the Director): billboard vs mesh in N / E / S, guard next to agent, reveal before /
  after the depth fix, glass, OCCLUSION_NEST, walk and throw filmstrips (before / after step 5: same throw landing frame), aim
  dome and star in N and E, tracer filmstrip N / E, blast mid-rotation vs started in E.
- Moto g04s (logs local): mesh +0.7-1.2 ms/frame vs billboard; PSS saving of step 5 inside boot noise; touch run passed.

## Rotation on the Moto (measured after the Director freed the handset)
Turn to E / S / W 206-212 ms main thread (all `_recompute_occlusion()`: the per-view geometry cache rebuild), back to N 13 ms;
background re-mesh 1.47 s per view. Steady state in E equals N. Recorded in `RENDER3D_MASTER_PLAN` R3D-ROT; not changed.
Step 5's deletions landed late (`3f063916`): a `git stash` round-trip had unstaged them before `27a7ed50`.

## Review pass and the closing ruling
`96e138a9`: a committed temporary diagnostic removed, ActorMesh3D / WorldCanvas3D loose ends tied, `actor_decisions_selftest`
(23 checks, red-before-green). Director, closing: ONE truth turned by the camera alone, EVERY face meshed up front (higher
initial cost accepted; blast damage will be calibrated down later), guard noise untouched except its orientation; model look
ignored (placeholder). Recorded in `RENDER3D_MASTER_PLAN` R3D-ROT ("DIRECTOR RULING" + "NEXT SESSION"). Next session starts
there: item 2 (mesh every face) and item 1 (occlusion for every view, built once).

## Not done / open
- ~~The Director's look call on the mesh~~: ignored by the Director, the model is a placeholder.
- R3D-ROT proper: the dead `_active_perspective` conversions, `layout_with_perspective` fixtures, rotation cost on the Moto.
- Still 2D: the explosion flash (full-screen, by nature), the DEV overlays, the never-shown noise indicator; grenade /
  collectible billboards are R3D-PROPS'.
- The rifle has no grip (`p2_grip_spike.GRIPS`), so it holds the shotgun; crouched / prone throws do not exist (as before).
- `agent_live*.glb` are under the git-ignored `source_assets/`: a fresh clone runs `r3d_live_rig_export.py` twice.

## Traps
- A new `class_name` is not in the global cache for headless lint: preload it, or type the var as its base.
- `verify.py` fails on a stale CODEMAP: regenerate before every run.
- The shot filmstrip writes no images unless `INFILTRAITOR_SHOT_FILM_SAVE=1`.
- The Moto must be unlocked by hand; `device_run.py --check` says so.
