# RESUMO_SESSAO — 2026-07-28 (SHOTGUN LIGHTING/ROTATION/SHADOW, SESSION CLOSE)

**Active master plan:** `PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md` — closes open
question #16, adds D23-D27.
**VERSION at session start:** 0.9.82
**VERSION at session end:** see `VERSION` (bumped by `push.sh` at close).
**Mode:** Solo mode.
**Screenshot session:** not toggled; all captures via one-off
`INFILTRAITOR_SCREENSHOT_ONCE=1` / direct `INFILTRAITOR_AUTO_SCREENSHOT=1` runs.

---

## Executive Summary

Started with a one-line ask (concrete floor for PLAYGROUND, using the
FLOOR-ZONE-BAKE mechanism the previous session shipped) and turned into a
full pass over the shotgun/grenade objects track: the shotgun's volumeless
look was traced to a real bug (not the bake — the runtime light-direction
math wasn't perspective-aware), the grenade got moved onto the same
real-3D-bake pipeline that already existed for the shotgun, TEST-ZONE props
were fixed to sort by real depth instead of always rendering on top of
walls, the spin speed was retuned onto a real frame-swap-rate finding
instead of guessed numbers, and — the largest single thread — a ground
shadow was built, broken, and re-fixed three times, each iteration caught
by the Director watching the real running game, not by a screenshot alone.
The shadow work in particular is a case study in the project's own
evidence discipline: an analytic derivation that looked right on paper
(and even in one static screenshot) was proven wrong by 46° RMS error once
measured against the actual baked pixels across a full rotation — the fix
that followed was verified the same rigorous way before being trusted.

## Wave Table

| ID | What | Status |
|---|---|---|
| FLOOR-BAKE-USE | PLAYGROUND floor zone set to `ground_concrete` (uses the prior session's FLOOR-ZONE-BAKE mechanism, no new mechanism built) | ✅ |
| D23 | Perspective-aware light-direction mapping — closes ACTOR_MASTER_PLAN open question #16 | ✅ |
| D24 | Grenade re-baked onto the shotgun's real-3D-model + normal-map pipeline, replacing the old single-angle `bake_voxel_sprite_3d.gd` bake | ✅ |
| D25 (2 passes) | TEST-ZONE props (grenade, floating collectible) fixed to sort by real depth — first attempt (occlusion-ghosting) was the wrong direction per Director, reverted; final fix pulls z_index from the ground-level voxel layer | ✅ |
| Spin tuning (3 passes) | Frame count/rotation speed retuned from 24 frames @ 360°/s to 120 frames @ 36°/s on the real frame-swap-rate finding (`FRAME_COUNT / rotation-period` must clear ~10-12Hz) | ✅ |
| D26 | Bake/animation parameters standardized into `CollectibleBakeConfig`; `FloatingCollectible` made reusable (`frames_dir`/`sprite_scale` params, no longer shotgun-hardcoded) | ✅ |
| D27 (4 passes) | Ground shadow: shear bug (oblique frame reused) → true top-down bake → azimuth/angle bug (analytically wrong, empirically fixed) → depth-cue spec corrected (size+focus+opacity crossfade) → range narrowed twice | ✅ |

## Decisions (Director-ratified)

1. **Props must NOT create occlusion ghosting.** An interim fix registered
   grenade/collectible cells as `OcclusionSet` origins so walls in front of
   them would ghost transparent, mirroring how the agent is handled.
   Director rejected this explicitly — props should be hidden by geometry
   like anything else, not exempted from it. Reverted in favor of D25's
   real-depth z_index fix.
2. **The shadow must be the object's own silhouette, not a generic blob**,
   and must rotate at the same speed as the object — ruled out reusing a
   simple procedural radial blob (`ContactShadow`, built then deleted same
   session once superseded) in favor of a dedicated top-down bake pass per
   rotation frame.
3. **Depth cue is size AND focus together, not size alone.** Director
   corrected an earlier build (which only varied shadow scale) — the real
   spec is small+sharp near the floor, big+diffuse at the top of the bob,
   crossfading continuously with the bob height.
4. **Both extremes of the shadow's depth-cue range were "exagerado" and
   needed narrowing across every varying parameter** (scale, alpha, and
   the bake's own blur/dilate iteration counts) — not just a smaller swing
   on one axis.
5. **Session closes with a push labeled "Alpha Shotgun Shadow."**

## Evidence

- `project_lint.py` / `check_invariants.py` / `gen_codemap.py --check`:
  clean at every commit this session.
- Real windowed captures (not headless) at every visual change — the
  project's own screenshot toggle stayed off; every capture was a
  deliberate one-off (`INFILTRAITOR_SCREENSHOT_ONCE=1` or
  `INFILTRAITOR_AUTO_SCREENSHOT=1`), several with the test object's
  `gu_cell` temporarily moved near the agent for visibility, then reverted.
- **The shadow-angle bug was diagnosed and fixed via direct pixel
  measurement, not more hand trigonometry**, after a first analytic fix
  turned out to have a sign error: PCA (principal component analysis) over
  each baked frame's alpha-channel silhouette, at 12 yaws spanning a full
  rotation, comparing the color frame's measured angle against candidate
  runtime transforms of the shadow frame. Mirrored-transform version: 46°
  RMS error, alternating sign every few frames (the signature of a
  mirrored rotation against a normally-rotating reference) — matching both
  Director reports (angle offset AND wrong spin direction) at once.
  No-mirror version: 4.3° RMS error, consistent with PCA noise on a
  hook-shaped silhouette, not a real systematic offset.
- `floor_zone_bake_selftest.gd`: not re-run this session (no changes to
  that system); relied on the prior session's 8/8 pass.

## Commits

`4ca4628` PLAYGROUND floor→concrete · `b2e14d9` D23 perspective-aware
light-direction (closes #16) · `def6dc8` D24 grenade real-3D bake ·
`bf07065` occlusion-ghosting attempt (superseded) · `c2451d4` D25 real-depth
z_index fix · `9401aef` spin tuning pass 1 (24→72 frames) · `f27a953` spin
tuning pass 2 (frame-swap-rate sweet spot, 120 frames @ 36°/s) · `0eee324`
D26 standardize `CollectibleBakeConfig` + first shadow attempt · `a6c93aa`
shadow silhouette + depth cue (scale only) · `c36b383` D27 true top-down
shadow bake · `daaf358` shadow azimuth fix (later found to have a sign
error) · `9614ee8` shadow mirror removed (real fix, PCA-verified) ·
`54bf11c` hover height 14→60px · `8963953` shadow sharp/soft crossfade
(corrected depth-cue spec) · `3b94ec7` shadow range narrowed · (this
close-out: docs + `push.sh`).

## Next Session

- **`GrenadeProp` has no ground shadow** (§7 #19) — the shadow system only
  covers `FloatingCollectible`. Grenades sit directly on the floor so the
  need is less acute, but worth a look once another elevated collectible
  exists.
- **`MESH_SCALE`/`SPRITE_SCALE` still first-guess, unvalidated** (§7 #17,
  carried over, not touched this session).
- **No formal collectible/prop registry** (§7 #18) — `room.gd`'s
  `_populate_test_zone_if_playground()` remains the one hardcoded call
  site for both objects now on this pipeline.
- **Shadow constants tuned only against the shotgun's elongated silhouette**
  (§7 #19) — unvalidated for a rounder/smaller object.
- **`actor_frame_bake_spike.gd` reloads the GLTF model fresh per pass**
  (§7 #20) — 360 reloads for one shotgun bake (3 passes × 120 frames);
  never measured as a real bottleneck, flagged rather than silently
  normalized.
- Normal-map shader cost on a real device (§7 #13, carried over from
  2026-07-26) still unmeasured.
