# Session summary — 2026-10-14 (second half): RF-2 per material, plywood one layer

Resume point for the next session. Plan: `PROMPTS/PLANNING/ROOF_MASTER_PLAN.md` v0.22 (record in §5); architecture: `docs/ARCHITECTURE.md` §0.4.
The first half of the day is `RESUMO_SESSAO_2026-10-14_ROOF_RF2.md` (the hole, the rubble, concrete judged).

## 1. How the five materials were judged
ROOF_LAB room B, take `roof_blast`, the roof's `material` swapped per run by a scratch script (copy the map, set `sections.roofs.items[gu == [15, 6]].material`,
run `python3 tools/persistent/capture.py --map ROOF_LAB --take roof_blast --sheet 30`, keep the video, restore the map). The capture prints
`[BLAST-RUBBLE] roof <material>: ... chunk(s), voxel(s), up, crumbling block(s); piece(s), rim splinter(s), rim trickle(s)`.

## 2. Director's rulings
- The per-material proposal: approved as written (brick = concrete; stone heavier; wood splinters + a splintered rim; plywood far more pieces, darker;
  cardboard light flaps that glide, more of them up, no dust).
- **Cardboard and fabric roofs are ONE layer (the lower one)**, and **plywood (madeirite) is one layer too, in roofs AND walls** ("teto e paredes").

## 3. What is built
| Material | Hole | What falls | Rim |
|---|---|---|---|
| concrete / brick | r 6, two layers (256) | 4 chunks, 60 voxels, 8 up, 8 crumbling blocks (unchanged) | 48 dust trickles |
| stone | r 4 (118) | 8 chunks, 20 voxels, 2 blocks, nothing up | 24 trickles |
| wood | r 8 (428) | 30 voxels, 6 up, 20 of the shot's SPLINTER blocks (they fly, stamp the floor) | 320 splinter cubes attached, 16 trickles |
| plywood | r 10, ONE layer (332) | 108 voxels, 8 up, 16 splinter blocks, darker (soot 0.3-0.75) | 320 textured splinter cubes, 16 trickles |
| cardboard | r 11, ONE layer (388) | 120 voxels + 30 up, gliding (gravity 0.35, terminal 0.9 GU/s, sway 1.5) | no dust; the rim burns |

Code: `RubblePresets.ROOF_*_OF` (the table), `Room.spawn_blast_roof_rubble` (split per material), `Room._roof_rim_splinters`, `PropFragmentSim`
`gravity` / `fall_max` / `sway` / `max_time`, `EdgeExtractor.THIN_MATERIALS` + plywood, `RoomBuilder` (a thin roof builds its lower layer only).
Fixed: no splinter cube hangs in the middle of a roof hole; a roof's crumbling block keeps the facade on every cube; cardboard gets no crumbling
block from the voxel cap's overflow.

## 4. Verification
- `verify.py` (smoke tier, picked by itself): PASSED in 96 s (lint, invariants, codemap, surfaces, segment budget, selftests, smoke boot).
- `roof_entity_selftest` [thin roof]: cardboard / fabric / plywood 9 lower slabs, 0 upper, 0 panes. `prop_fragment_sim_selftest` [8]: a gliding
  piece lands in 2.47 s vs 0.75 s, never over 0.9 GU/s, all 12 land, the sway moves 12 of 12 off their line, same seed same pile.
- PLAYGROUND plywood after the one-layer change: `shot_plywood` CROUCH 61% at 40,11 (same as 2026-10-13), `blast_plywood` door STANDING.
- The red / green specks: red translucent particle discs rising through the hole; the green is the video's chroma (raw PNG: 94 red, 0 green px).

## 5. The Director's review of that round (v0.23, built the same day)
"Tá ficando muito bom." Asked and built: stone keeps its 12 x 10 hole (measured first: the `[ROOF-BLAST]` line now prints the span; the Director
kept it) but sheds a lot of dust for longer (46 rim trickles over 2.6 s); crumbs on the rim of concrete, brick and stone, like wood's splinters
(`Room._roof_rim_bits`); wood's rim splinters darker; cardboard and fabric burn longer and farther with heavy soot on the top face
(`DetonationPlanBuilder._spread_roof_fire`: the fire creeps 6 rings outward, 212 voxels charred as the front passes over 2.1 s, 119 embers on the
surface, out by ~7 s). Two traps found on the way: an ember anchored at a STANDING voxel's centre is hidden by the depth test (the creeping fire's
embers now sit on the top face, `EmberOverlay.top_face_anchor`); charring the band in the commit made it black before the fire arrived (it is now
stamped over time, `Room.spread_roof_fire`, and a save chars the rest first). Cardboard's missing rim dust was the ember wave consuming its lit
rim. `verify.py` smoke PASSED (102 s). Clips: `videos/roof_materials/clip_{cardboard,fabric,stone}.mp4`.

## 6. Second review (v0.24)
Stone smaller (10 x 8, fewer pieces) with a dust shower around the opening (120 trickles); the char of every burning material comes AFTER its
flames (`WorldDelta.fire_char`, `Room.char_after_fire`, lag 1.6 s x flammability); a roof piece the hole cut off from every support falls whole
(`DetonationPlanBuilder._roof_islands`: cardboard's front tip, 55 voxels). Clips: `videos/roof_materials/clip_{cardboard,stone}_v4.mp4`.

## 7. NEXT
1. The Director judges the v0.23 round (the clips above): is stone's dust enough from this camera, do the rim crumbs read as crumbs.
2. Re-check the GLASS roof (Director). The roof support runs in the blast only (a shot, and a crossfade like the glass collapse, are not built).
3. Metal (Q5) and fabric's sag; then step 5 (the roof shot).
4. Owed: the Moto cost of a roof blast per material (wood's splinter blocks hash a string per cube in `splinter_role`, 5 blocks per frame;
   cardboard's 150 gliding pieces run up to 4 s; the creeping fire's 119 embers and a soot upload per frame for 2.1 s); `_movement_edge_set()`
   per piece family; `ShrapnelOverlay`'s fate.
