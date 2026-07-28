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

## GROUND SHADOW (Director, 2026-07-28): a real straight-down top-view bake,
## not the oblique ELEVATION_DEG=30 color frame reused-and-squashed. That
## first attempt distorted the silhouette's apparent angle — squashing an
## ALREADY-OBLIQUE, foreshortened view on Y is a shear, not a flatten, and
## visibly rotates diagonal edges (confirmed: the shadow's long axis no
## longer matched the object's own angle). A true top-down view has no
## directional foreshortening bias, so squashing it uniformly on Y to fit
## the isometric ground diamond is the standard, distortion-free technique.
const SHADOW_ELEVATION_DEG := 90.0
## The game's own iso diamond ratio (TILE_H/TILE_W = 0.5, sin(30°) —
## QUICK_REFERENCE.md) — this is what "flat on the ground plane" means
## everywhere else in this project, so the shadow uses the same constant
## rather than an arbitrary squash factor.
const SHADOW_SQUASH_Y := 0.5
## Bake-time softening — cheaper to do once per frame at bake time than every
## frame at runtime. Dilate widens the silhouette; blur softens the edge.
## Iteration counts, not literal pixel radii — see actor_frame_bake_spike.gd's
## _dilate_alpha()/_blur_alpha().
##
## TWO variants per frame (Director, 2026-07-28, correcting an earlier
## misread of the same request): the shadow crossfades between a small,
## SHARP/defined look at the bottom of the object's bob (close to the floor)
## and a bigger, SOFT/diffuse look at the top (far from the floor) — a real
## depth cue needs both size AND focus to change, not size alone. Baking two
## post-processed copies from the SAME raw top-down render (not re-rendering
## the 3D scene twice) keeps this cheap.
const SHADOW_SHARP_DILATE_ITERATIONS := 0
const SHADOW_SHARP_BLUR_ITERATIONS := 1
const SHADOW_SOFT_DILATE_ITERATIONS := 3
const SHADOW_SOFT_BLUR_ITERATIONS := 4
