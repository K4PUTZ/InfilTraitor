# Session summary — 2026-10-16: the cloth roof (flat plane, post, flaps, fire, sliced light)

Resume point for the next session. Plan: `PROMPTS/PLANNING/ROOF_MASTER_PLAN.md` v0.30 (the record has the decisions, the Moto numbers and the open list).

## What is true now
- A soft roof (fabric) is drawn as ONE flat plane per voxel (underside of its level); the voxels stay the index. The cloth's sim rests on the same plane, so the hand-over is flush.
- ROOF_LAB room C: a 1-voxel plywood post (`post_wood`) at gu (28, 9) holds the awning with the two back walls. Take `roof_post`: the grenade takes the post and the roof's hole; the cloth lets go and falls; take `roof_post_scorch` adds a second grenade on the settled cloth (not yet watched to the end: the run was interrupted).
- A blast that leaves a soft roof held by fewer (grounded) columns releases it (`Room.soft_roof_supports` / `release_soft_roofs_after_blast`, hooks in `WorldDelta.commit`).
- No fragments from cloth; the hole's rim is flaps (`ClothFlaps3D`); the fire's unfinished cells keep burning on the falling cloth (shader burn front); embers ride the cloth; a settled cloth only soots (`SoftSheet3D.scorch`).
- The release's light planes are sliced (`VoxelBoard.begin_light_apply_job`). Moto: the release costs ~7 ms/frame over the blast alone (53.5 vs 46.5 ms/frame in the fall window); still on one frame: sim build 45 ms, skin 35 ms, light field 102 ms.
- Commits: bc930c91, d512a7d7 and this session's last one, all on `main`. Verified: `verify.py` smoke PASSED (lint, invariants, codemap, selftests incl. new `cloth_flaps_selftest`, smoke boot), desktop captures (`Screenshots/takes/roof_post_*.png`, `videos/ROOF_LAB_roof_post.mp4`), Moto APK.

## NEXT (Director to choose)
1. Build the sim and the skin off the main thread (the remaining ~180 ms hitch on the Moto).
2. Watch `roof_post_scorch` to its end and judge the soot on the settled cloth.
3. Cardboard: plasticity / crease (signed), a cardboard row, a cardboard awning.
4. A floating stump of a half-destroyed post (needs "an unsupported prop remainder falls"); the flaps' tone following the rim's soot; flaps and floor.
5. Persistence of a let-go cloth across a checkpoint; prop / edge-wall colliders; shadow; Galaxy A16 and PSS.

## Traps
New class_name needs `godot --headless --path . --import`; `capture.py` drops print lines whose tag it does not know; `blast_roof_rubble` lists only the newly destroyed voxels; `Voxel.DamageState.DESTROYED` is 2; macOS `sed -i ''`; zsh errors on unmatched globs.

## Update (same day, later): RF-C C1, C2, C3 built
The "gap" was the cloth going THROUGH the walls' tops (the walls as built are bigger than the layout's GU boxes); `RoofSheetRelease.solid_grid` + `SoftSheetSim._solid_exit` / ledge pins fixed it (391 -> 4 of 4623 skin samples, selftest). Thickness: a skirt on every boundary (`thickness` 0.04 GU). Flaps: 2-3 voxels wide, 6-14 long, 15 on the lab's hole. Record: ROOF_MASTER_PLAN v0.32. NEXT: C4 (sim build 75 ms, skin 15 ms, light field 146 ms on the Moto, all to a worker), then RF-G (R-D12).
