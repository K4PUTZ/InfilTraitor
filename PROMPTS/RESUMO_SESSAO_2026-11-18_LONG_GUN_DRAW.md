# Session summary 2026-11-18 — the holster convention; the long guns' draw (shotgun first)

Picks up `RESUMO_SESSAO_2026-11-17_PROJECTILES.md` (H1 closed). The full record is `MOVEMENT_MASTER_PLAN` §11.6 steps 3 and 10 and
§11.8 Q1 / Q2; the gameplay numbers are `docs/production/milestones.md` GAMEPLAY-01.

## Rulings of the day (Director)

- **No moving with a weapon in the hands yet.** The pistol only attached to the hand of today's walk and run was tried and rejected
  (*"Claramente não vale a pena tentar só atachar a arma"*); moving with a weapon needs gaits of its own (a stealth run with the
  weapon; the bank's S2 / S3 are candidates): MOVEMENT §11.6 step 10, planned. **Until then:** *"o agente saca, atira e guarda
  automaticamente antes de andar/correr/fazer outra coisa"* (§11.8 Q1). BUILT: a move waits for the weapon to be put away, the hold
  after a shot cut short (up to 0.92 s); a kneel or a rise waits for the other posture's gun (`Agent._weapon_away`,
  `ActorPose.stow_weapon`, `ActorMesh3D.weapon_out`; takes `holster_walk`, `holster_run`, `holster_crouch`).
- **H3 opens with the shotguns.** Two shots: from the HIP (fast, misses more; standing only) and AIMED (slower, hits more; one AP
  more; the only one kneeling). The rifles have both; the SNIPERS only the aimed one. One aim for shotguns, rifles and snipers.
- **The draw of every long gun** (shotgun, rifles, sniper): hidden upright behind the coat's RIGHT flap (the pistol is behind the
  left one), the barrel up, the trigger down. From the idle: the left hand goes into the right lapel while the right hand lifts it
  (the pistol's draw mirrored); the left hand takes the barrel by its tip and pulls it out to the centre, in front of the tie, the
  hold unchanged; then it swings the muzzle from the zenith to the front while SLIDING BACK along the barrel to the fore-end, and the
  right hand takes the grip and the trigger below and lifts the gun to the waist: the hip shot. The aim (the next step, +1 AP) is
  the classic shouldered pose at the EYE: the left hand under the fore-end, palm up, the fingers round it; the right on the trigger.
- **The stockless shotguns** (Sawed Off, Short Stock) aim with both arms forward at the eyes (H2's way); their hip shot is the others'.

## Built

- `python3 tools/persistent/pose_lab.py draw_long_new [--gun shotgun] [--figure ...] [--render]` -> the STARTING timeline
  `ASSETS/MODELS/fit/SEQ_draw_shotgun_<FIG>.blend` (`tripo_pose_lab.draw_long_new`): 31 frames, idle 1, lapel 12, centre 16, hip 23,
  aim 31; the gun (`PROP_shotgun`, the pack's `Shotgun` at x0.085, ~1 m) on the LEFT hand from frame 13; the slide baked per frame
  (`_bake_slide`); the support hand (`_support_hand`, `_close_fingers`); the eye found on the head mesh for the aim; one empty
  `LongDrawFix_f<frame>` coat key per pose. Never rebuilds over an existing file.
- The read-back of a long gun's draw keeps the fingers (`LONG_GUN_SEQUENCES`), as the throw's does. Not read back yet.

## The Director's file (male)

He posed the lapel (12), added a key at 13 and set the shoulders at the hip (23); every later change of mine went into his saved
file (never a rebuild), checked by diffing his save against my last output first; the versions before each change are in
`temp/h3/`. The female is the builder's (no edit of his). **Tomorrow: his fine adjustment of the male**, then:

1. `pose_lab.py sequence draw_shotgun --figure male` (the game set), the female brought in step with his keys.
2. The engine: a second held family in `ActorMesh3D` (the long gun on the left hand, its timeline; the hip stop and the aim), the two
   shots in the shot menu (kneeling: aimed only; snipers: aimed only), the holster = the timeline backwards.
3. The kneeling long-gun draw (aimed only), the right flap's coat keys (his), the H3 family lab (size every shotgun, rifle and sniper
   in this aim), the stockless shotguns' arms-forward aim.

## Lessons

- He saves while I work: diff his saved file against my last output before every edit, and tell him to revert an open file.
- Blender interpolates a bone-parented prop's location and rotation separately: between two different holds it swings the prop off
  the hand. Bake the in-between per frame.
- At ~1 m a gun held at its tip cannot reach the waist or the shoulder with these arms (measured: the waist only at chest height,
  the aim 111 % of the arm); the slide along the barrel is what makes both reachable.
- The Tripo left hand bone: +Y to the fingers, +X to the index and thumb, the palm faces -Z.
