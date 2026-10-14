# Session summary — 2026-10-14: RF-2, a blast under an opaque roof (concrete judged)

Resume point for the next session. Plan: `PROMPTS/PLANNING/ROOF_MASTER_PLAN.md` v0.21 (record in §5); architecture: `docs/ARCHITECTURE.md` §0.4.

## 1. The bench
ROOF_LAB room B: only its two back walls stand (x 14, y 5), the roof is 4x4 (gu 15..18 x 6..9, concrete), take `roof_blast` throws at POI
`room_b_front`, so the hole above and the rubble below are both in view (`python3 tools/persistent/capture.py --map ROOF_LAB --take roof_blast`).
To judge another material, change room B's roof `material` in `maps/ROOF_LAB.map.json`. The capture prints `[ROOF-BLAST]` (voxels destroyed
per level) and `[BLAST-RUBBLE] roof: ...` (chunks, voxels, up, crumbling blocks, rim trickles).

## 2. What a blast does to a roof now (`RubblePresets.BLAST_ROOF_HOLE_*`, `ROOF_*`)
| Step | Where | What |
|---|---|---|
| The hole | `DetonationPlanBuilder._roof_hole` (in `_phase_roofs`) | every roof voxel within the material's radius of the epicentre, every layer; radius swings with the angle (lobes hashed per blast) + ragged edge; the ring's scattered DESTROYED outside it become DENTED |
| The rubble | `WorldDelta.blast_roof_rubble` -> `Room.spawn_blast_roof_rubble` | 2x2x2 chunks, whole voxels, a few up onto the roof, a few crumbling blocks (the shot's), the rest vanishes; per-piece soot 0.45-0.85; saved as rubble piles (div 1) |
| Rim dust | `Room._roof_rim_trickles` | up to 48 voxels of the rim's lower layer trickle, starting 0.1-1.1 s after the blast |
| Soot | `_phase_soot` + `_is_roof_top` | the roof's top layer 2 tones lighter |
| Quiet | `roof_quiet` (PHASE_PACKAGE), `Room._quiet_destroy` | a roof voxel schedules no smoke / debris / plume and skips the room's per-voxel puff |

## 3. Changes that reach every blast
- **No FRESH look in a blast** (Director): `Board3DLive` mesher skips the fresh twin when the destroyed neighbour carries the blast bit; a
  blast's blocks (seeds `blast|`, `breach|`, `roof|`) skip the fresh lift. The SHOT is unchanged.
- **The burst is anchored in 3D** at the grenade (`Room.spawn_blast_burst(world_pos, ground_2d)`, `blast_burst_height_gu` 0.25): it was
  placed by `blast_burst_dust_drop_px` (44 px = ~2.2 GU on the 3D board), above any roof.
- **Smoke and moving embers stop under a roof** (`Board3DLive.ceiling_above`, CEILING slabs only; walls do not count).
- **The shrapnel is not thrown any more** (it flew through roofs). `ShrapnelOverlay` is still built and cleared: deleting it is the Director's call.

## 4. Verification
`verify.py full` on the final code against a baseline of `0fb55b94` (the first baseline attempt failed on the known GLASS g1 flake: 11 px
between two boots of the SAME code; the retry was clean). Result: see the commit message.

## 5. NEXT (Director)
1. The other roof materials on the same bench (brick, stone, wood, plywood, cardboard), then metal and fabric's sag (Q5, later).
2. Step 5: the roof shot (R-D2 / R-D10).
3. Owed: the Moto cost of a roof blast (584 pieces + 48 trickles, never measured); `_movement_edge_set()` per piece family; a pair of
   red / green specks seen in the hole on one frame (not identified); the shrapnel overlay's fate.
