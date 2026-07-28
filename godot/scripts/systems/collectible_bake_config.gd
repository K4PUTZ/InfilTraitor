## ACTOR_MASTER_PLAN D17/D21/D14/D22 — shared bake/animation constants for
## every "simplification" floating collectible (FloatingCollectible +
## whichever bake tool produced its frames, e.g. actor_frame_bake_spike.gd).
## Standardized 2026-07-28 after tuning these against the shotgun so every
## future collectible starts from the same known-good baseline instead of
## re-deriving it per object.
##
## Per-object knobs (MESH_SCALE, ORTHO_SIZE, VIEWPORT_SIZE, SPRITE_SCALE) are
## deliberately NOT here — those depend on each model's own real-world size
## and stay a visual judgment call tuned per object, same convention as
## MESH_SCALE always has been.
class_name CollectibleBakeConfig

## SWEET-SPOT TUNING (Director, 2026-07-28): a baked flipbook's perceived
## smoothness is its frame-swap rate (FRAME_COUNT / rotation-period-in-sec),
## not frame count or speed in isolation. 120 frames (3° steps) at 36°/s
## (10s/rotation) swaps at 120/10 = 12Hz, clearing the ~10-12Hz threshold
## motion needs to read as continuous rather than discrete "soquinhos" jumps,
## while staying a slow, deliberate spin (not the original 1s/rotation).
## Changing either value without the other breaks the sweet spot — see
## FRAME_SWAP_HZ below.
const FRAME_COUNT := 120
const ROTATION_DEG_PER_SEC := 36.0
const FRAME_SWAP_HZ := ROTATION_DEG_PER_SEC * FRAME_COUNT / 360.0

## Fixed bake-camera convention — every collectible MUST use this exact
## elevation/azimuth/distance so its normal map is encoded in the same view
## space FloatingCollectible's world->camera light-direction math assumes
## (see that file's header). Never vary these per object.
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0
const CAMERA_DISTANCE := 12.0
