# Session summary — 2026-10-12: RF-S, a shot's broken voxels crumble and pile; the fresh inside of a hole

Resume point for the next session. Everything is on `main`. Plan: `PROMPTS/PLANNING/ROOF_MASTER_PLAN.md` (v0.14, records §5).

## 1. Director rulings
- **R-D9 — one rubble machine.** A shot's broken opaque voxels fly and pile through `PropFragmentSim` / `PropFragments3D` (the Tier 4
  pile), not a second pile built on `GlassVoxelFall3D`. Glass keeps `GlassVoxelFall3D`.
- **R-D10 — a roof shot is a straight ray** from the muzzle to the target roof cell, stopping at the first solid voxel (step 5, unbuilt).
- The look of RF-S was tuned frame by frame (14 takes); the final rules are in §2.

## 2. What a shot does to an opaque wall now
1. **Impact frame:** the board is remeshed on the frame the round lands (`AgentShotController`, before the render passes); every
   DESTROYED voxel is replaced in that frame by a 4×4×4 block of sub-voxels (`Room.spawn_shot_rubble`, `RubblePresets`) that wears
   the struck face's shade WITHOUT soot (`Board3DLive.face_shade`: side tone × cell light, baked in the instance colour; shader
   `prop_mesh3d` with `BAKED_LIGHT`). Layers ramp from the wall's tone (front) to the fresh concrete (back, × `FRESH_LIFT`).
2. **Crumble:** after `Room.RUBBLE_HOLD_S` (0.33 s) the whole block falls back against the shot by one of three presets (topple /
   slump / spill, FNV-hashed per cell; per-material push in `RubblePresets.SPEED`) and piles on the floor, a wall's top or an earlier
   pile (`PropFragmentSim`: `push_dir`, `hold`, `release`, `speed`, `solid`, `stack`, `shade`, `jitter`). Saved cube by cube
   (`Room._base_rubble_piles`, SaveState `rubble_piles`), laid back on a restore.
3. **Floor:** the soot under the pile darkens AS the cubes land (`PropFragments3D.landed`; `Room.RUBBLE_SOOT_STEPS`: ring by cubes per
   column, a halo one ring lighter, through the soot map, so it is saved). No contact shadow. A little floor dust in the material's tone.
4. **Inside the hole:** a face looking into a hole draws with its material's FRESH twin (`Board3DLive._fresh_twin`, tagged by the mesher
   from the destroyed claim beside it, walls only): no soot, lit by the hole cell in FRONT of it (`fresh_probe`, so a dark room keeps it
   dark), × `FRESH_LIFT` 1.3. A dent or bullet mark on such a face is drawn flat and unmarked.
5. **Soot timing:** the shot's wall soot lands 2 frames after the impact (it waited ~25 frames for the render passes).
6. **Bullet-hole sand trickle** (`DebrisOverlay.add_sand_trickle`): half the rounds (`vfx_impact_dust_chance` 0.5); an envelope (few short
   dashes, then more and longer, then stop); hair-thin; each trickle draws its own speed, release length and darkening.

## 3. Bugs found and fixed on the way
- `BlastCalculator.stamp_around`: a cell whose ragged-edge roll went below 0 was DROPPED, so a struck voxel kept no soot inside its
  own stain (one clean bright voxel; blasts too). Now clamped to 0.
- `SaveState.capture` read the soot map before finishing the falling fragments: a save during a fall lost the pile's final soot.
- Mesh lighting (`mesh_planes`) reads the FLOOR cell under a mesh; rubble seated in a wall read the floor under the wall (one block
  white, the next black). Rubble now carries its light in its colour instead.

## 4. Commits
`2f082a5a` RF-S first pass · `c4070369` sub-voxels seated on the impact frame · `0cd96394` whole block crumbles, three presets ·
`177456b4` floor soot + sand trickle · `5f04a7a3` fresh faces · `239dc687` hole interior · `5d5c0333` / `e49152b5` floor soot with the
pile, save order · `02fffd85` soot ragged-edge bug, soot timing · `f58e05a6` / `b3690d81` / `7c624f5c` / `63cb523f` rubble shade, fresh
probe · final commit: `FRESH_LIFT` 1.3 + docs.

## 5. NEXT
1. **Brick under RF-S** (Director: behaves almost the same as concrete): the PLAYGROUND brick trio, a take, the Director judges.
2. Then RF-1 **step 5, the roof shot** (R-D10), step 6 the skylight collapse, step 7 devices.
3. Owed: the Moto cost of the fresh twins (two more materials per material, three ALU ops per wall pixel) and of the rubble
   (64 cubes per broken voxel); a shot in a DARK room (the fresh face should darken with it — implied by the code, not seen);
   the fresh rule applies to a blast's breach too (its inside is no longer charred) — confirm with the Director.
- Captures: `videos/rf_s_rubble_v14_slow2x.mp4` (local, git-ignored); the recording harness used `capture.run_godot()` with a raw
  scenario and `--write-movie` (a map take for it does not exist yet).
