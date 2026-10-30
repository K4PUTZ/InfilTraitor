# Session record — 2026-10-29: the BASES, our textures, the belt by hand, clips in pairs

## Ratified (in the plans)
- `MOVEMENT` v1.2: the animation bank keeps clips in PAIRS, one per figure (a male clip plays on the female but looks odd).
- `MODEL_INVENTORY` 7.1: models generated BARE, pieces after; bosses unique; ~10 interchangeable humans for the rank-and-file;
  four machines per faction (eye / mobile / armed / alarm; the K9 dog is the police's mobile); traps go to the scenarios milestone.
- `ACTOR` D87: `FEMALE_BASE` / `MALE_BASE` are the source of the characters; surface = palette colour x grayscale detail per material,
  hand-painted maps as the exception; Tripo's maps are not shipped (the female's normal map draws the facets; Tripo's normals are good).
- `ACTOR` D86 amended: a base may be edited BY HAND, saved as `<NAME>_edit.glb` (+ `.blend`) beside the Tripo source. Edit in Rest, export
  in Pose (both first `_edit` exports came out with their clips frozen in the rest pose; the clips were copied back from the source).

## Built (`tools/asset_generation/tripo/tripo_assemble.py`)
- `BELT_KEEP=1`: Tripo's belt pieces stay in the trousers, the band is not flattened, our strap goes over them too.
- A belt GIVEN in the file (`Outfit_Belt` / `Outfit_Buckle`, fitted by hand) is taken as it is (implies `BELT_KEEP`).

## State of the files (`ASSETS/MODELS/`, git-ignored)
- `FEMALE_BASE_edit.glb`: belt and loops pushed into the trousers; clips restored. Assemble generates our belt over it (`BELT_KEEP=1`):
  clean at rest and in the dive.
- `MALE_BASE_edit.glb` (exported by Claude from `MALE_BASE_edit.blend`, the armature was hidden and the belt's object scale is now
  applied in the `.blend` too): our belt and buckle fitted by hand, waist closed. Clean at rest.

## OPEN — where to resume
- **The male's trousers / shirt seam come through the belt at the BACK in motion** (dive's run). Measured: at rest the belt sits only
  1.4 mm off the shirt-seam piece (`tripo_part_3`, 93 vertices under 5 mm), 2.8 mm off the trousers (`tripo_part_6`, 28 under 5 mm),
  5.1 mm off `tripo_part_5`; sampled every 3 frames of the dive, ~100 vertices come out. Giving everything within 1.5 % of H of the
  belt the belt's weights did NOT help (98 vs 100) and was reverted: what comes out is cloth that rises into the belt's height as the
  hip bends, not cloth glued to it.
- Options for the Director (none chosen): (a) MASK what lies under the belt (a `_Belted` variant of trousers / shirt, the
  `Outfit_Shirt_Coated` method of D86 (3)); (b) a little more room between belt and body (by hand in the `.blend`, or a gap knob);
  (c) re-shape the seam in Blender.
- Not yet: the T1 slot table checked on the `_edit` bases by the Director; T2-T4 of D87; the male's 9 k-tri hair vs the Moto budget.
